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
    /// @param payer Account that paid the verification deposit and receives attributable rebates.
    /// @param evidenceURIHash Hash of the submitted evidence URI.
    /// @param exists True once the platform request is tracked.
    /// @param fulfilled True after a terminal platform callback is accepted.
    struct VerificationRequest {
        uint256 taskId;
        uint256 submissionId;
        address payer;
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
    /// @param failureNotesURI Public note describing the failure class.
    event SomniaVerificationFailed(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        ISomniaAgentRequester.ResponseStatus status,
        string failureNotesURI
    );

    /// @notice Emitted when forwarding a terminal verifier result to escrow fails.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Task whose result could not be forwarded.
    /// @param submissionId Submission whose result could not be forwarded.
    /// @param returnData Raw revert data returned by escrow.
    event EscrowForwardingFailed(
        uint256 indexed platformRequestId, uint256 indexed taskId, uint256 indexed submissionId, bytes returnData
    );

    /// @notice Emitted when an old terminal callback arrives after a newer request became active.
    /// @param platformRequestId Stale Somnia platform request identifier.
    /// @param activePlatformRequestId Current active platform request for the task/submission.
    /// @param taskId Task whose old callback was ignored.
    /// @param submissionId Submission whose old callback was ignored.
    event StaleSomniaCallbackIgnored(
        uint256 indexed platformRequestId,
        uint256 indexed activePlatformRequestId,
        uint256 indexed taskId,
        uint256 submissionId
    );

    /// @notice Emitted when platform callback details attribute remaining request budget to the payer.
    /// @param payer Account that paid the original verification deposit.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param amount Native-token rebate credit attributed from callback details.
    event VerificationRebateCredited(address indexed payer, uint256 indexed platformRequestId, uint256 amount);

    /// @notice Emitted when a payer withdraws attributed verification rebate credit.
    /// @param payer Account withdrawing credited native tokens.
    /// @param amount Native-token rebate amount withdrawn.
    event VerificationRebateWithdrawn(address indexed payer, uint256 amount);

    /// @notice Emitted when the Somnia platform sends native-token rebate value back to this adapter.
    /// @param sender Account that sent the rebate.
    /// @param amount Native-token amount received.
    event SomniaRebateReceived(address indexed sender, uint256 amount);

    /// @notice Reverts when a caller attempts to decode agent bytes without going through this contract.
    error DecodeOnlySelf();

    /// @notice Reverts when the verification deposit does not match the exact configured request cost.
    /// @param required Required native-token deposit.
    /// @param actual Actual native-token amount supplied.
    error InvalidVerificationDeposit(uint256 required, uint256 actual);

    /// @notice Reverts when an account has no attributed verification rebate credit.
    /// @param account Account without rebate credit.
    error NoPendingVerificationRebate(address account);

    /// @notice Reverts when a native-token rebate transfer fails.
    /// @param recipient Intended recipient.
    /// @param amount Native-token amount that failed to transfer.
    error TransferFailed(address recipient, uint256 amount);

    /// @notice Reverts when a required address is zero.
    error InvalidAddress();
    /// @notice Reverts when a required numeric parameter is zero.
    error InvalidAmount();
    /// @notice Reverts when attempting to bind escrow more than once.
    /// @param escrow Existing bound escrow.
    error EscrowAlreadyBound(address escrow);
    /// @notice Reverts when a platform request identifier is unknown.
    /// @param requestId Unknown Somnia platform request identifier.
    error UnknownRequest(uint256 requestId);
    /// @notice Reverts when a terminal callback was already accepted.
    /// @param requestId Somnia platform request identifier.
    error RequestAlreadyFulfilled(uint256 requestId);
    /// @notice Reverts when the platform reports a non-terminal or unsupported callback status.
    /// @param status Unsupported status.
    error UnsupportedResponseStatus(ISomniaAgentRequester.ResponseStatus status);
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

    /// @notice Current platform request for each task/submission pair.
    /// @dev Used to ignore old callbacks after `VigiliaEscrow.retryVerification` creates a newer request for the same
    /// active submission. Escrow also validates request IDs defensively.
    mapping(uint256 taskId => mapping(uint256 submissionId => uint256 platformRequestId)) public activePlatformRequest;

    /// @notice Payer-attributed verification rebate credits based on terminal Somnia callback details.
    mapping(address payer => uint256 amount) public pendingVerificationRebates;

    /// @notice Total outstanding verification rebate credits.
    uint256 public totalPendingVerificationRebates;

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
    function requestVerification(uint256 _taskId, uint256 _submissionId, address _payer, string calldata _evidenceURI)
        external
        payable
        returns (bytes32 vigiliaRequestId)
    {
        if (msg.sender != escrow) revert Unauthorized(msg.sender);
        if (_payer == address(0)) revert InvalidAddress();

        uint256 requiredDeposit = minimumRequestDeposit();
        if (msg.value != requiredDeposit) revert InvalidVerificationDeposit(requiredDeposit, msg.value);

        bytes memory payload = abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _evidenceURI, verdictSelector);
        uint256 platformRequestId =
            platform.createRequest{ value: msg.value }(agentId, address(this), this.handleResponse.selector, payload);
        if (platformRequestId == 0) revert UnknownRequest(0);

        requests[platformRequestId] = VerificationRequest({
            taskId: _taskId,
            submissionId: _submissionId,
            payer: _payer,
            evidenceURIHash: keccak256(bytes(_evidenceURI)),
            exists: true,
            fulfilled: false
        });
        activePlatformRequest[_taskId][_submissionId] = platformRequestId;

        vigiliaRequestId = bytes32(platformRequestId);

        emit SomniaVerificationRequested(
            vigiliaRequestId, platformRequestId, _taskId, _submissionId, agentId, msg.value, _evidenceURI
        );
    }

    /// @notice Withdraws verification rebate credit attributed from terminal Somnia callback details.
    /// @dev Credits are cleared before transfer. Attribution is based on `_details.remainingBudget`; the platform must
    /// also deliver enough native-token rebate value for withdrawals to succeed.
    function withdrawVerificationRebate() external {
        uint256 amount = pendingVerificationRebates[msg.sender];
        if (amount == 0) revert NoPendingVerificationRebate(msg.sender);

        pendingVerificationRebates[msg.sender] = 0;
        totalPendingVerificationRebates -= amount;

        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert TransferFailed(msg.sender, amount);

        emit VerificationRebateWithdrawn(msg.sender, amount);
    }

    /// @notice Decodes ABI-encoded string agent output.
    /// @dev Externally callable only by this contract so malformed bytes can be caught with try/catch.
    /// @param _result ABI-encoded string bytes returned by the JSON API Request agent.
    /// @return decoded Decoded string.
    function decodeAgentString(bytes calldata _result) external view returns (string memory decoded) {
        if (msg.sender != address(this)) revert DecodeOnlySelf();
        decoded = abi.decode(_result, (string));
    }

    /// @notice Handles the final Somnia Agent platform callback for a tracked request.
    /// @dev Only the platform can call this function. Terminal infrastructure failures are forwarded to escrow as
    /// `VerificationFailed` so tasks remain retryable and do not get stuck in `Submitted`.
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
        if (msg.sender != address(platform)) {
            revert Unauthorized(msg.sender);
        }

        VerificationRequest storage request = requests[_requestId];
        if (!request.exists) revert UnknownRequest(_requestId);
        uint256 activeRequestId = activePlatformRequest[request.taskId][request.submissionId];
        if (activeRequestId != _requestId) {
            if (!request.fulfilled) {
                request.fulfilled = true;
                _creditRebate(_requestId, request.payer, _details.remainingBudget);
            }
            emit StaleSomniaCallbackIgnored(_requestId, activeRequestId, request.taskId, request.submissionId);
            return;
        }
        if (request.fulfilled) revert RequestAlreadyFulfilled(_requestId);

        if (
            _status == ISomniaAgentRequester.ResponseStatus.Failed
                || _status == ISomniaAgentRequester.ResponseStatus.TimedOut
        ) {
            request.fulfilled = true;
            _creditRebate(_requestId, request.payer, _details.remainingBudget);
            _forwardVerificationFailure(_requestId, request, _status, _somniaNotesUri(_requestId));
            return;
        }

        if (_status != ISomniaAgentRequester.ResponseStatus.Success) revert UnsupportedResponseStatus(_status);

        request.fulfilled = true;
        _creditRebate(_requestId, request.payer, _details.remainingBudget);

        (bool decoded, string memory result) = _decodeSuccessfulResult(_responses);
        if (!decoded) {
            _forwardVerificationFailure(_requestId, request, _status, _failureNotesUri(_requestId, "malformed"));
            return;
        }

        (bool parsed, VigiliaTypes.VerificationVerdict verdict) = _parseVerdict(result);
        if (!parsed) {
            _forwardVerificationFailure(_requestId, request, _status, _failureNotesUri(_requestId, "unknown-verdict"));
            return;
        }

        _forwardVerdict(_requestId, request, verdict, result);
    }

    /// @dev Extracts and decodes the first successful validator result from a successful platform callback.
    function _decodeSuccessfulResult(ISomniaAgentRequester.Response[] memory _responses)
        private
        view
        returns (bool decoded, string memory result)
    {
        for (uint256 i = 0; i < _responses.length; ++i) {
            if (
                _responses[i].status == ISomniaAgentRequester.ResponseStatus.Success && _responses[i].result.length != 0
            ) {
                try this.decodeAgentString(_responses[i].result) returns (string memory decodedResult) {
                    return (true, decodedResult);
                } catch {
                    return (false, "");
                }
            }
        }

        return (false, "");
    }

    /// @dev Maps exact bounded agent output strings into the shared Vigilia verdict enum.
    function _parseVerdict(string memory _result)
        private
        pure
        returns (bool parsed, VigiliaTypes.VerificationVerdict verdict)
    {
        bytes32 resultHash = keccak256(bytes(_result));

        if (resultHash == keccak256("Complete") || resultHash == keccak256("COMPLETE")) {
            return (true, VigiliaTypes.VerificationVerdict.Complete);
        }
        if (resultHash == keccak256("NeedsReview") || resultHash == keccak256("NEEDS_REVIEW")) {
            return (true, VigiliaTypes.VerificationVerdict.NeedsReview);
        }
        if (resultHash == keccak256("Incomplete") || resultHash == keccak256("INCOMPLETE")) {
            return (true, VigiliaTypes.VerificationVerdict.Incomplete);
        }

        return (false, VigiliaTypes.VerificationVerdict.Unknown);
    }

    /// @dev Credits request payer with unused budget reported by terminal platform callback details.
    function _creditRebate(uint256 _requestId, address _payer, uint256 _remainingBudget) private {
        if (_remainingBudget == 0) return;

        pendingVerificationRebates[_payer] += _remainingBudget;
        totalPendingVerificationRebates += _remainingBudget;

        emit VerificationRebateCredited(_payer, _requestId, _remainingBudget);
    }

    /// @dev Forwards terminal infrastructure failure to escrow and preserves callback finality if escrow rejects it.
    function _forwardVerificationFailure(
        uint256 _requestId,
        VerificationRequest storage _request,
        ISomniaAgentRequester.ResponseStatus _status,
        string memory _failureNotesURI
    ) private {
        try IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerificationFailure(_request.taskId, _request.submissionId, bytes32(_requestId), _failureNotesURI) {
            emit SomniaVerificationFailed(_requestId, _request.taskId, _request.submissionId, _status, _failureNotesURI);
        } catch (bytes memory returnData) {
            emit EscrowForwardingFailed(_requestId, _request.taskId, _request.submissionId, returnData);
        }
    }

    /// @dev Forwards a bounded verdict to escrow and preserves callback finality if escrow rejects it.
    function _forwardVerdict(
        uint256 _requestId,
        VerificationRequest storage _request,
        VigiliaTypes.VerificationVerdict _verdict,
        string memory _result
    ) private {
        try IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerdict(
                _request.taskId, _request.submissionId, bytes32(_requestId), _verdict, _somniaNotesUri(_requestId)
            ) {
            emit SomniaVerificationSucceeded(_requestId, _request.taskId, _request.submissionId, _verdict, _result);
        } catch (bytes memory returnData) {
            emit EscrowForwardingFailed(_requestId, _request.taskId, _request.submissionId, returnData);
        }
    }

    /// @dev Provides a deterministic on-chain note that off-chain indexers can pair with Somnia receipt APIs.
    function _somniaNotesUri(uint256 _requestId) private pure returns (string memory notesURI) {
        notesURI = string.concat("somnia-agent-request:", _uintToString(_requestId));
    }

    /// @dev Adds a compact failure reason to the deterministic Somnia request note.
    function _failureNotesUri(uint256 _requestId, string memory _reason) private pure returns (string memory notesURI) {
        notesURI = string.concat(_somniaNotesUri(_requestId), ":", _reason);
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
