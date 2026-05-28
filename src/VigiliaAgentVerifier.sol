// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IVigiliaVerifier } from "./interfaces/IVigiliaVerifier.sol";

/// @notice Minimal escrow callback surface used by VigiliaAgentVerifier.
interface IVigiliaEscrowVerdictReceiver {
    enum VerificationVerdict {
        Unknown,
        Complete,
        NeedsReview,
        Incomplete
    }

    /// @notice Records a bounded verifier verdict for an escrow submission.
    /// @param _taskId Task that was verified.
    /// @param _submissionId Submission receiving the verdict.
    /// @param _verdict Bounded verifier result.
    /// @param _verifierNotesURI Public URI with verifier notes, missing fields, or receipts.
    function recordVerdict(
        uint256 _taskId,
        uint256 _submissionId,
        VerificationVerdict _verdict,
        string calldata _verifierNotesURI
    ) external;
}

/// @title VigiliaAgentVerifier
/// @notice Task verifier adapter that bridges VigiliaEscrow to a trusted Somnia Agent callback sender.
/// @dev This is intentionally a thin adapter, not the final generated Somnia Agent gateway integration. The escrow
/// calls `requestVerification`, the configured callback sender later calls `handleAgentCallback` with a bounded
/// verdict, and this contract forwards the verdict to the escrow. It does not hold funds and cannot move escrowed
/// value.
contract VigiliaAgentVerifier is IVigiliaVerifier {
    /// @notice Emitted when the verifier is permanently bound to an escrow contract.
    /// @param escrow Escrow contract allowed to request verification and receive forwarded verdicts.
    event EscrowBound(address indexed escrow);

    /// @notice Emitted when escrow creates a verification request.
    /// @param requestId Request identifier tracked by this adapter.
    /// @param taskId Task to verify.
    /// @param submissionId Submission to verify.
    /// @param evidenceURI Public evidence URI supplied by the contractor.
    event AgentVerificationRequested(
        bytes32 indexed requestId, uint256 indexed taskId, uint256 indexed submissionId, string evidenceURI
    );

    /// @notice Emitted after a trusted callback sender resolves a verification request.
    /// @param requestId Request identifier that received the callback.
    /// @param taskId Verified task.
    /// @param submissionId Verified submission.
    /// @param verdict Bounded verdict forwarded to escrow.
    /// @param verifierNotesURI Public URI with verifier notes, missing fields, or receipts.
    event AgentVerificationCallback(
        bytes32 indexed requestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VerificationVerdict verdict,
        string verifierNotesURI
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

    enum VerificationVerdict {
        Unknown,
        Complete,
        NeedsReview,
        Incomplete
    }

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

    /// @notice Trusted Somnia Agent platform/callback sender for bounded verification results.
    address public immutable callbackSender;

    /// @notice Escrow contract allowed to request verification and receive forwarded verdicts.
    address public escrow;

    /// @notice Monotonic nonce used to derive unique request identifiers.
    uint256 public nextRequestNonce;

    /// @notice Request metadata by request identifier.
    mapping(bytes32 requestId => VerificationRequest request) public requests;

    /// @notice Creates the adapter with deployment-time binder and trusted callback sender.
    /// @param _escrowBinder Account allowed to call `bindEscrow` once after escrow deployment.
    /// @param _callbackSender Trusted Somnia Agent callback sender.
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
    function requestVerification(uint256 _taskId, uint256 _submissionId, string calldata _evidenceURI)
        external
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

        emit AgentVerificationRequested(requestId, _taskId, _submissionId, _evidenceURI);
    }

    /// @notice Handles a trusted Somnia Agent callback and forwards the bounded verdict to escrow.
    /// @param _requestId Request identifier returned by `requestVerification`.
    /// @param _verdict Bounded verdict. `Unknown` is rejected and fails closed.
    /// @param _verifierNotesURI Public URI with verifier notes, missing fields, or receipts.
    function handleAgentCallback(bytes32 _requestId, VerificationVerdict _verdict, string calldata _verifierNotesURI)
        external
    {
        if (msg.sender != callbackSender) revert Unauthorized(msg.sender);
        if (_verdict == VerificationVerdict.Unknown) revert UnknownVerdict();

        VerificationRequest storage request = requests[_requestId];
        if (!request.exists) revert UnknownRequest(_requestId);
        if (request.fulfilled) revert RequestAlreadyFulfilled(_requestId);

        request.fulfilled = true;

        IVigiliaEscrowVerdictReceiver.VerificationVerdict escrowVerdict =
            IVigiliaEscrowVerdictReceiver.VerificationVerdict(uint8(_verdict));

        IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerdict(request.taskId, request.submissionId, escrowVerdict, _verifierNotesURI);

        emit AgentVerificationCallback(_requestId, request.taskId, request.submissionId, _verdict, _verifierNotesURI);
    }
}
