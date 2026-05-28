// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IVigiliaVerifier } from "./interfaces/IVigiliaVerifier.sol";
import { VigiliaTypes } from "./types/VigiliaTypes.sol";

/// @title VigiliaEscrow
/// @notice Compact MVP escrow for agent-verified public work settlement.
/// @dev Native-token only for the first pass. Verifier output is bounded and never transfers funds directly.
/// @dev This MVP is permissionless and ownerless. Task authority is scoped to each task's client, contractor,
/// task-specific resolver, and configured verifier; there is no global admin that can move funds, approve work, or
/// resolve disputes.
contract VigiliaEscrow {
    /// @notice Emitted when a client creates a new unfunded task.
    /// @param taskId New task identifier.
    /// @param client Account that created the task and controls client-only actions.
    /// @param contractor Account allowed to submit evidence and claim approved escrow.
    /// @param resolver Task-specific account allowed to resolve disputes.
    /// @param amount Exact native-token escrow amount required to fund the task.
    /// @param reviewWindow Seconds the client can use to approve or dispute a complete submission before auto-claim.
    /// @param requirementsURI Public URI describing task requirements.
    event TaskCreated(
        uint256 indexed taskId,
        address indexed client,
        address indexed contractor,
        address resolver,
        uint256 amount,
        uint64 reviewWindow,
        string requirementsURI
    );

    /// @notice Emitted when a client deposits the exact task amount into escrow.
    /// @param taskId Funded task identifier.
    /// @param client Funding client.
    /// @param amount Native-token amount deposited.
    event TaskFunded(uint256 indexed taskId, address indexed client, uint256 amount);

    /// @notice Emitted when a contractor submits public evidence and a verifier request is created.
    /// @param taskId Task receiving the submission.
    /// @param submissionId New submission identifier.
    /// @param submitter Contractor account that submitted evidence.
    /// @param evidenceURI Public URI containing evidence metadata or links.
    /// @param evidenceHash Hash of the submitted evidence bundle or metadata.
    /// @param requestId Verifier request identifier returned by the configured verifier.
    event WorkSubmitted(
        uint256 indexed taskId,
        uint256 indexed submissionId,
        address indexed submitter,
        string evidenceURI,
        bytes32 evidenceHash,
        bytes32 requestId
    );

    /// @notice Emitted when the verifier records a bounded verdict for the active submission.
    /// @param taskId Verified task identifier.
    /// @param submissionId Active submission that received the verdict.
    /// @param verdict Bounded verifier result applied by the escrow state machine.
    /// @param requestId Verifier request identifier associated with the submission.
    /// @param verifierNotesURI Optional public URI with verifier notes, receipts, or missing fields.
    event VerdictRecorded(
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaTypes.VerificationVerdict verdict,
        bytes32 requestId,
        string verifierNotesURI
    );

    /// @notice Emitted when verifier infrastructure fails without producing a work-quality verdict.
    /// @param taskId Task whose verification request failed.
    /// @param submissionId Active submission whose request failed.
    /// @param requestId Verifier request identifier associated with the failed request.
    /// @param failureNotesURI Public URI or deterministic note describing the failure.
    event VerificationFailedRecorded(
        uint256 indexed taskId, uint256 indexed submissionId, bytes32 requestId, string failureNotesURI
    );

    /// @notice Emitted when an active failed submission is sent back to the verifier without replacing evidence.
    /// @param taskId Task whose active submission is being retried.
    /// @param submissionId Active submission receiving a new verifier request.
    /// @param payer Account that paid the retry verification deposit.
    /// @param requestId New verifier request identifier.
    event VerificationRetried(
        uint256 indexed taskId, uint256 indexed submissionId, address indexed payer, bytes32 requestId
    );

    /// @notice Emitted when a client approves a task for contractor claim.
    /// @param taskId Approved task identifier.
    /// @param client Client account approving settlement.
    /// @param submissionId Active submission approved for settlement.
    event TaskApproved(uint256 indexed taskId, address indexed client, uint256 indexed submissionId);

    /// @notice Emitted when the contractor pulls approved escrow funds.
    /// @param taskId Claimed task identifier.
    /// @param contractor Contractor account receiving funds.
    /// @param amount Native-token payout amount.
    event TaskClaimed(uint256 indexed taskId, address indexed contractor, uint256 amount);

    /// @notice Emitted when a client or contractor freezes an active task in dispute.
    /// @param taskId Disputed task identifier.
    /// @param raisedBy Account that raised the dispute.
    /// @param previousState State before dispute freeze.
    /// @param reasonURI Public URI describing the dispute or challenge reason.
    event DisputeRaised(uint256 indexed taskId, address indexed raisedBy, TaskState previousState, string reasonURI);

    /// @notice Emitted when the task-specific resolver allocates disputed escrow.
    /// @param taskId Resolved task identifier.
    /// @param resolver Task-specific resolver account.
    /// @param clientRefund Native-token credit allocated to the client.
    /// @param contractorAward Native-token credit allocated to the contractor.
    /// @param resolutionURI Public URI describing the resolution rationale.
    event DisputeResolved(
        uint256 indexed taskId,
        address indexed resolver,
        uint256 clientRefund,
        uint256 contractorAward,
        string resolutionURI
    );

    /// @notice Emitted when a client cancels a safely cancellable task.
    /// @param taskId Cancelled task identifier.
    /// @param client Client receiving any escrow refund.
    /// @param refundAmount Native-token amount refunded to the client.
    event TaskCancelled(uint256 indexed taskId, address indexed client, uint256 refundAmount);

    /// @notice Emitted when an account withdraws pending dispute-resolution credit.
    /// @param account Account withdrawing credited native tokens.
    /// @param amount Native-token amount withdrawn.
    event PendingWithdrawalClaimed(address indexed account, uint256 amount);

    /// @notice Reverts when evidence URI is empty.
    error EmptyEvidenceURI();
    /// @notice Reverts when a required address is zero.
    error InvalidAddress();
    /// @notice Reverts when a required amount is zero.
    error InvalidAmount();
    /// @notice Reverts when task funding does not exactly match the configured task amount.
    /// @param expected Required funding amount.
    /// @param actual Native-token amount sent.
    error InvalidFundingAmount(uint256 expected, uint256 actual);
    /// @notice Reverts when dispute resolution allocations do not exactly consume the task escrow.
    /// @param expected Task funded amount that must be fully allocated.
    /// @param actual Sum of client refund and contractor award supplied by resolver.
    error InvalidResolutionAmount(uint256 expected, uint256 actual);
    /// @notice Reverts when a task action is not valid from the current task state.
    /// @param taskId Task that failed the state guard.
    /// @param current Current state observed by the guard.
    error InvalidState(uint256 taskId, TaskState current);
    /// @notice Reverts when an account has no pending withdrawal credit.
    /// @param account Account without pending credit.
    error NoPendingWithdrawal(address account);
    /// @notice Reverts when a contractor tries to claim a verified-complete task before the review window expires.
    /// @param taskId Task being claimed.
    /// @param claimableAt Earliest timestamp when review-window claim is allowed.
    /// @param currentTime Current block timestamp.
    error ReviewWindowActive(uint256 taskId, uint256 claimableAt, uint256 currentTime);
    /// @notice Reverts when a submission is not the active submission for the supplied task.
    /// @param taskId Task being checked.
    /// @param submissionId Submission being checked.
    error InvalidSubmission(uint256 taskId, uint256 submissionId);
    /// @notice Reverts when a task identifier has not been created.
    /// @param taskId Missing task identifier.
    error TaskDoesNotExist(uint256 taskId);
    /// @notice Reverts when a native-token transfer fails.
    /// @param recipient Intended recipient.
    /// @param amount Native-token amount that failed to transfer.
    error TransferFailed(address recipient, uint256 amount);
    /// @notice Reverts when the caller is not authorized for the requested action.
    /// @param caller Unauthorized caller.
    error Unauthorized(address caller);
    /// @notice Reverts when the verifier attempts to record an unknown verdict.
    error UnknownVerdict();
    /// @notice Reverts when evidence hash is zero.
    error ZeroEvidenceHash();
    /// @notice Reverts when the verifier returns or references a zero request identifier.
    error ZeroRequestId();

    /// @notice Task lifecycle states enforced by the escrow state machine.
    /// @dev `None` is reserved for missing tasks. `VerificationFailed` is infrastructure failure, not work failure.
    /// `Disputed` freezes settlement until the task-specific resolver allocates the escrow into pending withdrawal
    /// credits.
    enum TaskState {
        None,
        Created,
        Funded,
        Submitted,
        VerifiedComplete,
        NeedsReview,
        Incomplete,
        VerificationFailed,
        Approved,
        Claimed,
        Disputed,
        Resolved,
        Cancelled
    }

    /// @notice Fixed-price task tracked by the MVP escrow.
    /// @param client Client account that created and funded the task.
    /// @param contractor Contractor account assigned to submit evidence and claim.
    /// @param resolver Task-specific account trusted by both parties to resolve disputes.
    /// @param amount Required funding amount for the task.
    /// @param fundedAmount Native-token amount currently held for this task.
    /// @param activeSubmissionId Latest submission eligible for verdict recording.
    /// @param submissionCount Number of submissions made for this task.
    /// @param state Current task lifecycle state.
    /// @param stateBeforeDispute Last state before a dispute freeze.
    /// @param requirementsURI Public URI describing task requirements.
    /// @param reviewWindow Seconds after a complete verdict before contractor auto-claim is allowed.
    struct Task {
        address client;
        address contractor;
        address resolver;
        uint256 amount;
        uint256 fundedAmount;
        uint256 activeSubmissionId;
        uint256 submissionCount;
        TaskState state;
        TaskState stateBeforeDispute;
        string requirementsURI;
        uint64 reviewWindow;
    }

    /// @notice Public evidence submission associated with a task.
    /// @param taskId Parent task identifier.
    /// @param submitter Contractor account that submitted evidence.
    /// @param evidenceURI Public URI containing evidence metadata or links.
    /// @param evidenceHash Hash of the submitted evidence bundle or metadata.
    /// @param requestId Verifier request identifier for this submission.
    /// @param verdict Bounded verifier result, or `Unknown` before verification.
    /// @param submittedAt Submission timestamp.
    /// @param verifiedAt Verdict timestamp, or zero before verification.
    struct Submission {
        uint256 taskId;
        address submitter;
        string evidenceURI;
        bytes32 evidenceHash;
        bytes32 requestId;
        VigiliaTypes.VerificationVerdict verdict;
        uint64 submittedAt;
        uint64 verifiedAt;
    }

    /// @notice Verifier adapter authorized to record bounded verdicts.
    /// @dev Immutable and set once at construction; no owner can replace it in this MVP.
    IVigiliaVerifier public immutable verifier;

    /// @notice Next task identifier to be assigned.
    uint256 public nextTaskId = 1;

    /// @notice Next submission identifier to be assigned.
    uint256 public nextSubmissionId = 1;

    /// @notice Task storage by task identifier.
    mapping(uint256 taskId => Task task) public tasks;

    /// @notice Submission storage by submission identifier.
    mapping(uint256 submissionId => Submission submission) public submissions;

    /// @notice Native-token credits allocated by dispute resolution and withdrawable by each account.
    mapping(address account => uint256 amount) public pendingWithdrawals;

    /// @notice Initializes the escrow with the verifier adapter allowed to request and record verification results.
    /// @param _verifier Verifier contract address. In MVP tests this is MockVerifier; later it can be a Somnia adapter.
    constructor(address _verifier) {
        if (_verifier == address(0)) revert InvalidAddress();

        verifier = IVigiliaVerifier(_verifier);
    }

    /// @notice Creates an unfunded fixed-price task for a known contractor.
    /// @param _contractor Contractor wallet allowed to submit evidence and claim approved funds.
    /// @param _resolver Task-specific resolver wallet allowed to allocate disputed escrow.
    /// @param _amount Exact native-token amount the client must later escrow for this task.
    /// @param _reviewWindow Seconds after a complete verdict before the contractor can claim without approval.
    /// @param _requirementsURI Public URI describing task requirements and expected evidence.
    /// @return taskId Newly created task identifier.
    function createTask(
        address _contractor,
        address _resolver,
        uint256 _amount,
        uint64 _reviewWindow,
        string calldata _requirementsURI
    ) external returns (uint256 taskId) {
        if (_contractor == address(0)) revert InvalidAddress();
        if (_resolver == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        taskId = nextTaskId++;
        Task storage task = tasks[taskId];
        task.client = msg.sender;
        task.contractor = _contractor;
        task.resolver = _resolver;
        task.amount = _amount;
        task.state = TaskState.Created;
        task.requirementsURI = _requirementsURI;
        task.reviewWindow = _reviewWindow;

        emit TaskCreated(taskId, msg.sender, _contractor, _resolver, _amount, _reviewWindow, _requirementsURI);
    }

    /// @notice Funds a created task with the exact required native-token amount.
    /// @param _taskId Task to fund.
    function fundTask(uint256 _taskId) external payable {
        Task storage task = _existingTask(_taskId);
        _onlyClient(task);
        _requireState(_taskId, task, TaskState.Created);

        if (msg.value != task.amount) revert InvalidFundingAmount(task.amount, msg.value);

        task.fundedAmount = msg.value;
        task.state = TaskState.Funded;

        emit TaskFunded(_taskId, msg.sender, msg.value);
    }

    /// @notice Submits public evidence for a funded, incomplete, or verification-failed task.
    /// @param _taskId Task receiving the evidence submission.
    /// @param _evidenceURI Public URI containing evidence metadata, links, and artifacts.
    /// @param _evidenceHash Hash of the evidence bundle or metadata for off-chain integrity checks.
    /// @return submissionId Newly created submission identifier.
    /// @return requestId Verifier request identifier returned by the configured verifier.
    function submitWork(uint256 _taskId, string calldata _evidenceURI, bytes32 _evidenceHash)
        external
        payable
        returns (uint256 submissionId, bytes32 requestId)
    {
        Task storage task = _existingTask(_taskId);
        _onlyContractor(task);
        _requireSubmittable(_taskId, task);

        if (bytes(_evidenceURI).length == 0) revert EmptyEvidenceURI();
        if (_evidenceHash == bytes32(0)) revert ZeroEvidenceHash();

        submissionId = nextSubmissionId++;
        task.submissionCount++;
        task.activeSubmissionId = submissionId;
        task.state = TaskState.Submitted;

        Submission storage submission = submissions[submissionId];
        submission.taskId = _taskId;
        submission.submitter = msg.sender;
        submission.evidenceURI = _evidenceURI;
        submission.evidenceHash = _evidenceHash;
        submission.submittedAt = uint64(block.timestamp);

        requestId = verifier.requestVerification{ value: msg.value }(_taskId, submissionId, msg.sender, _evidenceURI);
        if (requestId == bytes32(0)) revert ZeroRequestId();
        submission.requestId = requestId;

        emit WorkSubmitted(_taskId, submissionId, msg.sender, _evidenceURI, _evidenceHash, requestId);
    }

    /// @notice Records a bounded verifier verdict for the active submission and updates task state deterministically.
    /// @param _taskId Task that was verified.
    /// @param _submissionId Submission receiving the verdict.
    /// @param _verdict Bounded verifier result. Unknown is rejected and fails closed.
    /// @param _verifierNotesURI Optional public URI with verifier summary, missing fields, or receipt metadata.
    function recordVerdict(
        uint256 _taskId,
        uint256 _submissionId,
        VigiliaTypes.VerificationVerdict _verdict,
        string calldata _verifierNotesURI
    ) external {
        if (msg.sender != address(verifier)) revert Unauthorized(msg.sender);
        if (_verdict == VigiliaTypes.VerificationVerdict.Unknown) revert UnknownVerdict();

        Task storage task = _existingTask(_taskId);
        _requireState(_taskId, task, TaskState.Submitted);
        _requireActiveSubmission(task, _taskId, _submissionId);

        Submission storage submission = submissions[_submissionId];
        if (submission.requestId == bytes32(0)) revert ZeroRequestId();

        submission.verdict = _verdict;
        submission.verifiedAt = uint64(block.timestamp);

        if (_verdict == VigiliaTypes.VerificationVerdict.Complete) {
            task.state = TaskState.VerifiedComplete;
        } else if (_verdict == VigiliaTypes.VerificationVerdict.NeedsReview) {
            task.state = TaskState.NeedsReview;
        } else {
            task.state = TaskState.Incomplete;
        }

        emit VerdictRecorded(_taskId, _submissionId, _verdict, submission.requestId, _verifierNotesURI);
    }

    /// @notice Records terminal verifier infrastructure failure for the active submission.
    /// @dev This is distinct from an `Incomplete` work verdict. It leaves the submission verdict unchanged and moves
    /// the task into a retryable/manual-review state.
    /// @param _taskId Task whose verification request failed.
    /// @param _submissionId Active submission whose request failed.
    /// @param _failureNotesURI Public URI or deterministic note describing the failure.
    function recordVerificationFailure(uint256 _taskId, uint256 _submissionId, string calldata _failureNotesURI)
        external
    {
        if (msg.sender != address(verifier)) revert Unauthorized(msg.sender);

        Task storage task = _existingTask(_taskId);
        _requireState(_taskId, task, TaskState.Submitted);
        _requireActiveSubmission(task, _taskId, _submissionId);

        Submission storage submission = submissions[_submissionId];
        if (submission.requestId == bytes32(0)) revert ZeroRequestId();

        task.state = TaskState.VerificationFailed;

        emit VerificationFailedRecorded(_taskId, _submissionId, submission.requestId, _failureNotesURI);
    }

    /// @notice Retries verifier inspection for the active verification-failed submission.
    /// @dev Either task party can pay for retry. This does not alter evidence, verdict, or submission count.
    /// @param _taskId Task whose active failed submission should be retried.
    /// @return requestId New verifier request identifier returned by the configured verifier.
    function retryVerification(uint256 _taskId) external payable returns (bytes32 requestId) {
        Task storage task = _existingTask(_taskId);
        if (msg.sender != task.client && msg.sender != task.contractor) revert Unauthorized(msg.sender);
        _requireState(_taskId, task, TaskState.VerificationFailed);

        uint256 submissionId = task.activeSubmissionId;
        Submission storage submission = submissions[submissionId];

        task.state = TaskState.Submitted;

        requestId = verifier.requestVerification{ value: msg.value }(
            _taskId, submissionId, msg.sender, submission.evidenceURI
        );
        if (requestId == bytes32(0)) revert ZeroRequestId();
        submission.requestId = requestId;

        emit VerificationRetried(_taskId, submissionId, msg.sender, requestId);
    }

    /// @notice Approves a submitted, complete, incomplete, or verification-failed task so the contractor can pull
    /// payment. @param _taskId Task to approve.
    function approveTask(uint256 _taskId) external {
        Task storage task = _existingTask(_taskId);
        _onlyClient(task);

        if (
            task.state != TaskState.Submitted && task.state != TaskState.VerifiedComplete
                && task.state != TaskState.NeedsReview && task.state != TaskState.Incomplete
                && task.state != TaskState.VerificationFailed
        ) {
            revert InvalidState(_taskId, task.state);
        }

        task.state = TaskState.Approved;

        emit TaskApproved(_taskId, msg.sender, task.activeSubmissionId);
    }

    /// @notice Claims escrow funds after client approval or after a complete verdict review window expires.
    /// @param _taskId Task to claim.
    function claim(uint256 _taskId) external {
        Task storage task = _existingTask(_taskId);
        _onlyContractor(task);

        if (task.state == TaskState.VerifiedComplete) {
            _requireReviewWindowExpired(_taskId, task);
        } else if (task.state != TaskState.Approved) {
            revert InvalidState(_taskId, task.state);
        }

        uint256 payout = task.fundedAmount;
        task.fundedAmount = 0;
        task.state = TaskState.Claimed;

        (bool success,) = msg.sender.call{ value: payout }("");
        if (!success) revert TransferFailed(msg.sender, payout);

        emit TaskClaimed(_taskId, msg.sender, payout);
    }

    /// @notice Raises a basic dispute and freezes claim/cancellation paths until the task resolver allocates escrow.
    /// @param _taskId Task to dispute.
    /// @param _reasonURI Public URI describing the dispute reason or challenge evidence.
    function raiseDispute(uint256 _taskId, string calldata _reasonURI) external {
        Task storage task = _existingTask(_taskId);
        if (msg.sender != task.client && msg.sender != task.contractor) revert Unauthorized(msg.sender);

        TaskState previousState = task.state;
        if (!_isDisputable(previousState)) revert InvalidState(_taskId, previousState);

        task.stateBeforeDispute = previousState;
        task.state = TaskState.Disputed;

        emit DisputeRaised(_taskId, msg.sender, previousState, _reasonURI);
    }

    /// @notice Resolves a disputed task by allocating escrow between client refund and contractor award.
    /// @dev Only the task-specific resolver can call this function. Resolution is ownerless at the protocol level:
    /// the resolver is selected per task and the contract only enforces exact accounting plus pull-based withdrawal.
    /// @param _taskId Disputed task to resolve.
    /// @param _clientRefund Native-token amount credited to the client.
    /// @param _contractorAward Native-token amount credited to the contractor.
    /// @param _resolutionURI Public URI describing the resolution rationale.
    function resolveDispute(
        uint256 _taskId,
        uint256 _clientRefund,
        uint256 _contractorAward,
        string calldata _resolutionURI
    ) external {
        Task storage task = _existingTask(_taskId);
        if (msg.sender != task.resolver) revert Unauthorized(msg.sender);
        _requireState(_taskId, task, TaskState.Disputed);

        uint256 resolvedAmount = _clientRefund + _contractorAward;
        uint256 fundedAmount = task.fundedAmount;
        if (resolvedAmount != fundedAmount) revert InvalidResolutionAmount(fundedAmount, resolvedAmount);

        task.fundedAmount = 0;
        task.state = TaskState.Resolved;

        pendingWithdrawals[task.client] += _clientRefund;
        pendingWithdrawals[task.contractor] += _contractorAward;

        emit DisputeResolved(_taskId, msg.sender, _clientRefund, _contractorAward, _resolutionURI);
    }

    /// @notice Withdraws native-token credit allocated by dispute resolution.
    /// @dev Credits are cleared before transfer, so a reverting recipient cannot corrupt accounting or reenter for the
    /// same funds.
    function withdrawPending() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NoPendingWithdrawal(msg.sender);

        pendingWithdrawals[msg.sender] = 0;

        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert TransferFailed(msg.sender, amount);

        emit PendingWithdrawalClaimed(msg.sender, amount);
    }

    /// @notice Cancels a task and refunds escrow when no valid payable submission is pending or approved.
    /// @param _taskId Task to cancel.
    function cancelTask(uint256 _taskId) external {
        Task storage task = _existingTask(_taskId);
        _onlyClient(task);

        TaskState currentState = task.state;
        if (
            currentState != TaskState.Created && currentState != TaskState.Funded
                && currentState != TaskState.Incomplete
        ) {
            revert InvalidState(_taskId, currentState);
        }

        uint256 refundAmount = task.fundedAmount;
        task.fundedAmount = 0;
        task.state = TaskState.Cancelled;

        if (refundAmount != 0) {
            (bool success,) = task.client.call{ value: refundAmount }("");
            if (!success) revert TransferFailed(task.client, refundAmount);
        }

        emit TaskCancelled(_taskId, task.client, refundAmount);
    }

    /// @dev Loads an existing task and rejects the reserved `None` state used for missing records.
    function _existingTask(uint256 _taskId) private view returns (Task storage task) {
        task = tasks[_taskId];
        if (task.state == TaskState.None) revert TaskDoesNotExist(_taskId);
    }

    /// @dev Enforces task-scoped client authority; there is no global owner fallback.
    function _onlyClient(Task storage _task) private view {
        if (msg.sender != _task.client) revert Unauthorized(msg.sender);
    }

    /// @dev Enforces task-scoped contractor authority.
    function _onlyContractor(Task storage _task) private view {
        if (msg.sender != _task.contractor) revert Unauthorized(msg.sender);
    }

    /// @dev Centralizes exact-state guards so reverts consistently expose the observed state.
    function _requireState(uint256 _taskId, Task storage _task, TaskState _expected) private view {
        if (_task.state != _expected) revert InvalidState(_taskId, _task.state);
    }

    /// @dev Allows initial submission from `Funded` and revised evidence after a work or infrastructure failure.
    function _requireSubmittable(uint256 _taskId, Task storage _task) private view {
        if (
            _task.state != TaskState.Funded && _task.state != TaskState.Incomplete
                && _task.state != TaskState.VerificationFailed
        ) {
            revert InvalidState(_taskId, _task.state);
        }
    }

    /// @dev Prevents stale verifier callbacks from older submissions or mismatched task/submission pairs.
    function _requireActiveSubmission(Task storage _task, uint256 _taskId, uint256 _submissionId) private view {
        Submission storage submission = submissions[_submissionId];
        if (_task.activeSubmissionId != _submissionId || submission.taskId != _taskId) {
            revert InvalidSubmission(_taskId, _submissionId);
        }
    }

    /// @dev Defines the states that can be frozen by either task party in the MVP dispute model.
    function _isDisputable(TaskState _state) private pure returns (bool) {
        return _state == TaskState.Funded || _state == TaskState.Submitted || _state == TaskState.VerifiedComplete
            || _state == TaskState.NeedsReview || _state == TaskState.Incomplete
            || _state == TaskState.VerificationFailed || _state == TaskState.Approved;
    }

    /// @dev Enforces the client review period for verified-complete auto-claim.
    function _requireReviewWindowExpired(uint256 _taskId, Task storage _task) private view {
        Submission storage submission = submissions[_task.activeSubmissionId];
        uint256 claimableAt = uint256(submission.verifiedAt) + uint256(_task.reviewWindow);
        if (block.timestamp < claimableAt) revert ReviewWindowActive(_taskId, claimableAt, block.timestamp);
    }
}
