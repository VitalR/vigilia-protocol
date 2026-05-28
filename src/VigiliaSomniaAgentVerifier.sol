// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IJsonApiAgent } from "./interfaces/IJsonApiAgent.sol";
import { ISomniaAgentRequester } from "./interfaces/ISomniaAgentRequester.sol";
import { IVigiliaEscrowVerdictReceiver } from "./interfaces/IVigiliaEscrowVerdictReceiver.sol";
import { IVigiliaVerifier } from "./interfaces/IVigiliaVerifier.sol";
import { VigiliaTypes } from "./types/VigiliaTypes.sol";

/// @title VigiliaSomniaAgentVerifier
/// @notice Real Somnia Agent verifier adapter for Vigilia escrow submissions.
/// @dev Uses the Somnia JSON API Request base agent. Contractor-supplied verification deposits are forwarded to the
/// Somnia Agent platform through `createRequest`; task escrow funds remain in `VigiliaEscrow`. The adapter only
/// forwards bounded verdicts and has no authority to move escrowed funds.
contract VigiliaSomniaAgentVerifier is IVigiliaVerifier {
    /// @notice Stored metadata for a Somnia platform request.
    /// @param taskId Vigilia task being verified.
    /// @param submissionId Vigilia submission being verified.
    /// @param evidenceURIHash Hash of the submitted evidence URI.
    /// @param exists True once the platform request is tracked.
    /// @param fulfilled True after a terminal platform callback is accepted.
    struct VerificationRequest {
        uint256 taskId;
        uint256 submissionId;
        bytes32 evidenceURIHash;
        bool exists;
        bool fulfilled;
    }

    /// @notice Emitted when the verifier is permanently bound to an escrow contract.
    /// @param escrow Escrow contract allowed to request verification and receive forwarded verdicts.
    event EscrowBound(address indexed escrow);

    /// @notice Emitted when escrow creates a Somnia Agent verification request.
    /// @param vigiliaRequestId Vigilia-facing request identifier returned to escrow.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Task to verify.
    /// @param submissionId Submission to verify.
    /// @param agentId Somnia Agent identifier used for the request.
    /// @param deposit Native STT amount forwarded to the platform.
    /// @param evidenceURI Public evidence JSON endpoint.
    event SomniaVerificationRequested(
        bytes32 indexed vigiliaRequestId,
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 submissionId,
        uint256 agentId,
        uint256 deposit,
        string evidenceURI
    );

    /// @notice Emitted when a successful Somnia callback records a bounded verdict.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Verified task.
    /// @param submissionId Verified submission.
    /// @param verdict Bounded verdict forwarded to escrow.
    /// @param rawResult Raw string returned by the JSON API Request agent.
    event SomniaVerificationSucceeded(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaTypes.VerificationVerdict verdict,
        string rawResult
    );

    /// @notice Emitted when a terminal platform callback does not produce an escrow verdict.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Task whose verification failed or timed out.
    /// @param submissionId Submission whose verification failed or timed out.
    /// @param status Terminal platform status.
    event SomniaVerificationFailed(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        ISomniaAgentRequester.ResponseStatus status
    );

    /// @notice Emitted when the Somnia platform sends native-token rebate value back to this adapter.
    /// @param sender Account that sent the rebate.
    /// @param amount Native-token amount received.
    event SomniaRebateReceived(address indexed sender, uint256 amount);

    /// @notice Reverts when a required address is zero.
    error InvalidAddress();
    /// @notice Reverts when a required numeric parameter is zero.
    error InvalidAmount();
    /// @notice Reverts when attempting to bind escrow more than once.
    /// @param escrow Existing bound escrow.
    error EscrowAlreadyBound(address escrow);
    /// @notice Reverts when the caller does not send enough STT for a Somnia request.
    /// @param required Minimum native-token deposit required by this adapter.
    /// @param actual Native-token amount supplied by the caller.
    error InsufficientVerificationDeposit(uint256 required, uint256 actual);
    /// @notice Reverts when a platform request identifier is unknown.
    /// @param requestId Unknown Somnia platform request identifier.
    error UnknownRequest(uint256 requestId);
    /// @notice Reverts when a terminal callback was already accepted.
    /// @param requestId Somnia platform request identifier.
    error RequestAlreadyFulfilled(uint256 requestId);
    /// @notice Reverts when the platform reports a non-terminal or unsupported callback status.
    /// @param status Unsupported status.
    error UnsupportedResponseStatus(ISomniaAgentRequester.ResponseStatus status);
    /// @notice Reverts when the successful callback has no usable response bytes.
    /// @param requestId Somnia platform request identifier.
    error MalformedAgentResponse(uint256 requestId);
    /// @notice Reverts when the agent result is not one of the bounded Vigilia verdict strings.
    /// @param result Unsupported raw result string.
    error UnknownVerdictResult(string result);
    /// @notice Reverts when caller is not authorized for an action.
    /// @param caller Unauthorized caller.
    error Unauthorized(address caller);

    /// @notice Somnia Agent requester platform contract.
    ISomniaAgentRequester public immutable platform;

    /// @notice Account allowed to bind this adapter to the escrow once after deployment.
    /// @dev Deployment-time configuration only; it has no task or fund authority after binding.
    address public immutable escrowBinder;

    /// @notice Somnia Agent identifier used for JSON API Request verification.
    uint256 public immutable agentId;

    /// @notice Expected validator count used to calculate the minimum request reward deposit.
    uint256 public immutable subcommitteeSize;

    /// @notice Native-token reward budget per validator used for the minimum deposit guard.
    uint256 public immutable pricePerValidator;

    /// @notice JSON selector extracted from the public evidence endpoint.
    string public verdictSelector;

    /// @notice Escrow contract allowed to create requests and receive forwarded verdicts.
    address public escrow;

    /// @notice Request metadata by Somnia platform request identifier.
    mapping(uint256 platformRequestId => VerificationRequest request) public requests;

    /// @notice Creates the Somnia verifier adapter.
    /// @param _platform Somnia Agent requester platform contract.
    /// @param _escrowBinder Account allowed to bind the escrow once.
    /// @param _agentId Somnia Agent identifier for the JSON API Request base agent.
    /// @param _subcommitteeSize Expected validator count used for deposit calculation.
    /// @param _pricePerValidator Native-token reward budget per validator.
    /// @param _verdictSelector JSON selector that should return `Complete`, `NeedsReview`, or `Incomplete`.
    constructor(
        address _platform,
        address _escrowBinder,
        uint256 _agentId,
        uint256 _subcommitteeSize,
        uint256 _pricePerValidator,
        string memory _verdictSelector
    ) {
        if (_platform == address(0)) revert InvalidAddress();
        if (_escrowBinder == address(0)) revert InvalidAddress();
        if (_agentId == 0) revert InvalidAmount();
        if (_subcommitteeSize == 0) revert InvalidAmount();
        if (_pricePerValidator == 0) revert InvalidAmount();
        if (bytes(_verdictSelector).length == 0) revert InvalidAmount();

        platform = ISomniaAgentRequester(_platform);
        escrowBinder = _escrowBinder;
        agentId = _agentId;
        subcommitteeSize = _subcommitteeSize;
        pricePerValidator = _pricePerValidator;
        verdictSelector = _verdictSelector;
    }

    /// @notice Accepts Somnia platform rebates after request finalization.
    receive() external payable {
        emit SomniaRebateReceived(msg.sender, msg.value);
    }

    /// @notice Binds this verifier to exactly one escrow contract.
    /// @dev Required because escrow construction also needs the verifier address. This one-time binding does not create
    /// a protocol admin role; after binding, only escrow can create requests and only the platform can finalize them.
    /// @param _escrow Escrow contract address.
    function bindEscrow(address _escrow) external {
        if (msg.sender != escrowBinder) revert Unauthorized(msg.sender);
        if (_escrow == address(0)) revert InvalidAddress();
        if (escrow != address(0)) revert EscrowAlreadyBound(escrow);

        escrow = _escrow;

        emit EscrowBound(_escrow);
    }

    /// @notice Returns the minimum native-token deposit required for a verification request.
    /// @dev Combines the platform reserve with the configured per-validator reward budget.
    /// @return deposit Minimum native STT that must accompany `requestVerification`.
    function minimumRequestDeposit() public view returns (uint256 deposit) {
        deposit = platform.getRequestDeposit() + (pricePerValidator * subcommitteeSize);
    }

    /// @inheritdoc IVigiliaVerifier
    function requestVerification(uint256 _taskId, uint256 _submissionId, string calldata _evidenceURI)
        external
        payable
        returns (bytes32 vigiliaRequestId)
    {
        if (msg.sender != escrow) revert Unauthorized(msg.sender);

        uint256 requiredDeposit = minimumRequestDeposit();
        if (msg.value < requiredDeposit) revert InsufficientVerificationDeposit(requiredDeposit, msg.value);

        bytes memory payload = abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _evidenceURI, verdictSelector);
        uint256 platformRequestId =
            platform.createRequest{ value: msg.value }(agentId, address(this), this.handleResponse.selector, payload);
        if (platformRequestId == 0) revert UnknownRequest(0);

        requests[platformRequestId] = VerificationRequest({
            taskId: _taskId,
            submissionId: _submissionId,
            evidenceURIHash: keccak256(bytes(_evidenceURI)),
            exists: true,
            fulfilled: false
        });

        vigiliaRequestId = bytes32(platformRequestId);

        emit SomniaVerificationRequested(
            vigiliaRequestId, platformRequestId, _taskId, _submissionId, agentId, msg.value, _evidenceURI
        );
    }

    /// @notice Handles the final Somnia Agent platform callback for a tracked request.
    /// @dev Only the platform can call this function. Failed and timed-out requests are terminal but do not record an
    /// escrow verdict, keeping settlement blocked until a future product flow introduces explicit retry handling.
    /// @param _requestId Somnia platform request identifier.
    /// @param _responses Validator responses supplied by the platform.
    /// @param _status Final platform status.
    /// @param _details Full platform request details. Present for ABI compatibility; core checks use tracked metadata.
    function handleResponse(
        uint256 _requestId,
        ISomniaAgentRequester.Response[] memory _responses,
        ISomniaAgentRequester.ResponseStatus _status,
        ISomniaAgentRequester.Request memory _details
    ) external {
        _details;
        if (msg.sender != address(platform)) revert Unauthorized(msg.sender);

        VerificationRequest storage request = requests[_requestId];
        if (!request.exists) revert UnknownRequest(_requestId);
        if (request.fulfilled) revert RequestAlreadyFulfilled(_requestId);

        if (
            _status == ISomniaAgentRequester.ResponseStatus.Failed
                || _status == ISomniaAgentRequester.ResponseStatus.TimedOut
        ) {
            request.fulfilled = true;
            emit SomniaVerificationFailed(_requestId, request.taskId, request.submissionId, _status);
            return;
        }

        if (_status != ISomniaAgentRequester.ResponseStatus.Success) revert UnsupportedResponseStatus(_status);

        string memory result = _decodeSuccessfulResult(_requestId, _responses);
        VigiliaTypes.VerificationVerdict verdict = _parseVerdict(result);

        request.fulfilled = true;

        IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerdict(request.taskId, request.submissionId, verdict, _somniaNotesUri(_requestId));

        emit SomniaVerificationSucceeded(_requestId, request.taskId, request.submissionId, verdict, result);
    }

    /// @dev Extracts and decodes the first successful validator result from a successful platform callback.
    function _decodeSuccessfulResult(uint256 _requestId, ISomniaAgentRequester.Response[] memory _responses)
        private
        pure
        returns (string memory result)
    {
        for (uint256 i = 0; i < _responses.length; ++i) {
            if (
                _responses[i].status == ISomniaAgentRequester.ResponseStatus.Success && _responses[i].result.length != 0
            ) {
                return abi.decode(_responses[i].result, (string));
            }
        }

        revert MalformedAgentResponse(_requestId);
    }

    /// @dev Maps exact bounded agent output strings into the shared Vigilia verdict enum.
    function _parseVerdict(string memory _result) private pure returns (VigiliaTypes.VerificationVerdict verdict) {
        bytes32 resultHash = keccak256(bytes(_result));

        if (resultHash == keccak256("Complete") || resultHash == keccak256("COMPLETE")) {
            return VigiliaTypes.VerificationVerdict.Complete;
        }
        if (resultHash == keccak256("NeedsReview") || resultHash == keccak256("NEEDS_REVIEW")) {
            return VigiliaTypes.VerificationVerdict.NeedsReview;
        }
        if (resultHash == keccak256("Incomplete") || resultHash == keccak256("INCOMPLETE")) {
            return VigiliaTypes.VerificationVerdict.Incomplete;
        }

        revert UnknownVerdictResult(_result);
    }

    /// @dev Provides a deterministic on-chain note that off-chain indexers can pair with Somnia receipt APIs.
    function _somniaNotesUri(uint256 _requestId) private pure returns (string memory notesURI) {
        notesURI = string.concat("somnia-agent-request:", _uintToString(_requestId));
    }

    /// @dev Converts a request identifier into decimal text without importing external string helpers.
    function _uintToString(uint256 _value) private pure returns (string memory result) {
        if (_value == 0) return "0";

        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            // casting to uint8 is safe because the modulo result is always a single decimal digit.
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }

        result = string(buffer);
    }
}
