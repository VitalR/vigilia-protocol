// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IVigiliaVerifier } from "./interfaces/IVigiliaVerifier.sol";
import { IVigiliaEscrowVerdictReceiver } from "./interfaces/IVigiliaEscrowVerdictReceiver.sol";
import { VigiliaAgentTypes } from "./types/VigiliaAgentTypes.sol";
import { VigiliaTypes } from "./types/VigiliaTypes.sol";

/// @title VigiliaTrustedCallbackVerifier
/// @notice Task verifier adapter that bridges VigiliaEscrow to a trusted manual callback sender.
/// @dev This is intentionally a thin adapter, not the final generated Somnia Agent gateway integration. The escrow
/// calls `requestVerification`, the configured callback sender later calls `handleAgentCallback` with a bounded
/// verdict, and this contract forwards the verdict to the escrow. It does not hold funds and cannot move escrowed
/// value.
contract VigiliaTrustedCallbackVerifier is IVigiliaVerifier {
    /// @notice Emitted when the verifier is permanently bound to an escrow contract.
    /// @param escrow Escrow contract allowed to request verification and receive forwarded verdicts.
    event EscrowBound(address indexed escrow);

    /// @notice Emitted when escrow creates a verification request.
    /// @param requestId Request identifier tracked by this adapter.
    /// @param taskId Task to verify.
    /// @param submissionId Submission to verify.
    /// @param evidenceURI Public evidence URI supplied by the contractor.
    event TrustedVerificationRequested(
        bytes32 indexed requestId, uint256 indexed taskId, uint256 indexed submissionId, string evidenceURI
    );

    /// @notice Emitted after a trusted callback sender resolves a verification request.
    /// @param requestId Request identifier that received the callback.
    /// @param taskId Verified task.
    /// @param submissionId Verified submission.
    /// @param verdict Bounded verdict forwarded to escrow.
    /// @param verifierNotesURI Public URI with verifier notes, missing fields, or receipts.
    event TrustedVerificationCallback(
        bytes32 indexed requestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaTypes.VerificationVerdict verdict,
        string verifierNotesURI
    );

    /// @notice Emitted when an old trusted callback arrives after a newer request became active.
    /// @param requestId Stale trusted request identifier.
    /// @param activeRequestId Current active request for the task/submission.
    /// @param taskId Task whose old callback was ignored.
    /// @param submissionId Submission whose old callback was ignored.
    event StaleTrustedCallbackIgnored(
        bytes32 indexed requestId, bytes32 indexed activeRequestId, uint256 indexed taskId, uint256 submissionId
    );

    /// @notice Reverts when a required address is zero.
    error InvalidAddress();
    /// @notice Reverts when attempting to bind escrow more than once.
    error EscrowAlreadyBound(address escrow);
    /// @notice Reverts when a request identifier is unknown.
    error UnknownRequest(bytes32 requestId);
    /// @notice Reverts when a request already received a callback.
    error RequestAlreadyFulfilled(bytes32 requestId);
    /// @notice Reverts when the callback sender supplies `Unknown`.
    error UnknownVerdict();
    /// @notice Reverts when caller is not authorized for an action.
    /// @param caller Unauthorized caller.
    error Unauthorized(address caller);

    /// @notice Stored metadata for a trusted callback verification request.
    struct VerificationRequest {
        uint256 taskId;
        uint256 submissionId;
        bytes32 evidenceURIHash;
        bool exists;
        bool fulfilled;
    }

    /// @notice Account allowed to bind this adapter to the escrow once after deployment.
    /// @dev This is deployment-time configuration only. It has no authority over task settlement or verdicts.
    address public immutable escrowBinder;

    /// @notice Trusted manual callback sender for bounded verification results.
    address public immutable callbackSender;

    /// @notice Escrow contract allowed to request verification and receive forwarded verdicts.
    address public escrow;

    /// @notice Monotonic nonce used to derive unique request identifiers.
    uint256 public nextRequestNonce;

    /// @notice Request metadata by request identifier.
    mapping(bytes32 requestId => VerificationRequest request) public requests;

    /// @notice Current trusted request for each task/submission pair.
    /// @dev Old callbacks are ignored after retry creates a newer request for the same active submission.
    mapping(uint256 taskId => mapping(uint256 submissionId => bytes32 requestId)) public activeRequest;

    /// @notice Creates the adapter with deployment-time binder and trusted callback sender.
    /// @param _escrowBinder Account allowed to call `bindEscrow` once after escrow deployment.
    /// @param _callbackSender Trusted manual callback sender.
    constructor(address _escrowBinder, address _callbackSender) {
        if (_escrowBinder == address(0)) revert InvalidAddress();
        if (_callbackSender == address(0)) revert InvalidAddress();

        escrowBinder = _escrowBinder;
        callbackSender = _callbackSender;
    }

    /// @notice Binds this verifier to exactly one escrow contract.
    /// @dev Required because escrow construction also needs the verifier address. This one-time binding does not create
    /// a protocol admin role; after binding, only escrow can create requests and only the callback sender can resolve
    /// them.
    /// @param _escrow Escrow contract address.
    function bindEscrow(address _escrow) external {
        if (msg.sender != escrowBinder) revert Unauthorized(msg.sender);
        if (_escrow == address(0)) revert InvalidAddress();
        if (escrow != address(0)) revert EscrowAlreadyBound(escrow);

        escrow = _escrow;

        emit EscrowBound(_escrow);
    }

    /// @inheritdoc IVigiliaVerifier
    function requestVerification(uint256 _taskId, uint256 _submissionId, address, string calldata _evidenceURI)
        external
        payable
        returns (bytes32 requestId)
    {
        requestId = _requestVerification(_taskId, _submissionId, _evidenceURI);
    }

    /// @inheritdoc IVigiliaVerifier
    function requestVerification(
        uint256 _taskId,
        uint256 _submissionId,
        address,
        string calldata _evidenceURI,
        string calldata,
        VigiliaAgentTypes.SettlementWorkflow
    ) external payable returns (bytes32 requestId) {
        requestId = _requestVerification(_taskId, _submissionId, _evidenceURI);
    }

    /// @notice Handles a trusted manual callback and forwards the bounded verdict to escrow.
    /// @param _requestId Request identifier returned by `requestVerification`.
    /// @param _verdict Bounded verdict. `Unknown` is rejected and fails closed.
    /// @param _verifierNotesURI Public URI with verifier notes, missing fields, or receipts.
    function handleAgentCallback(
        bytes32 _requestId,
        VigiliaTypes.VerificationVerdict _verdict,
        string calldata _verifierNotesURI
    ) external {
        if (msg.sender != callbackSender) revert Unauthorized(msg.sender);
        if (_verdict == VigiliaTypes.VerificationVerdict.Unknown) revert UnknownVerdict();

        VerificationRequest storage request = requests[_requestId];
        if (!request.exists) revert UnknownRequest(_requestId);
        bytes32 currentRequestId = activeRequest[request.taskId][request.submissionId];
        if (currentRequestId != _requestId) {
            request.fulfilled = true;
            emit StaleTrustedCallbackIgnored(_requestId, currentRequestId, request.taskId, request.submissionId);
            return;
        }
        if (request.fulfilled) revert RequestAlreadyFulfilled(_requestId);

        request.fulfilled = true;

        IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerdict(request.taskId, request.submissionId, _requestId, _verdict, _verifierNotesURI);

        emit TrustedVerificationCallback(_requestId, request.taskId, request.submissionId, _verdict, _verifierNotesURI);
    }

    /// @dev Records a trusted verification request for the bound escrow and marks it active for the task/submission.
    /// @dev Workflow-specific overloads ignore requirements and workflow because this adapter uses manual callbacks
    /// only. @param _taskId Task identifier supplied by escrow.
    /// @param _submissionId Submission identifier supplied by escrow.
    /// @param _evidenceURI Public evidence URI whose hash is stored for off-chain auditability.
    /// @return requestId Deterministic request identifier returned to escrow.
    function _requestVerification(uint256 _taskId, uint256 _submissionId, string calldata _evidenceURI)
        private
        returns (bytes32 requestId)
    {
        if (msg.sender != escrow) revert Unauthorized(msg.sender);

        nextRequestNonce++;
        requestId = keccak256(abi.encode(block.chainid, address(this), _taskId, _submissionId, nextRequestNonce));

        requests[requestId] = VerificationRequest({
            taskId: _taskId,
            submissionId: _submissionId,
            evidenceURIHash: keccak256(bytes(_evidenceURI)),
            exists: true,
            fulfilled: false
        });
        activeRequest[_taskId][_submissionId] = requestId;

        emit TrustedVerificationRequested(requestId, _taskId, _submissionId, _evidenceURI);
    }
}
