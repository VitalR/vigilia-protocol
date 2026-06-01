// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "@forge-std/Test.sol";
import { VigiliaEscrow } from "../src/VigiliaEscrow.sol";
import { MockVerifier } from "../src/mocks/MockVerifier.sol";
import { VigiliaTypes } from "../src/types/VigiliaTypes.sol";

contract VigiliaEscrowTest is Test {
    event TaskCreated(
        uint256 indexed taskId,
        address indexed client,
        address indexed contractor,
        address resolver,
        uint256 amount,
        uint64 reviewWindow,
        uint64 verificationTimeout,
        VigiliaEscrow.ClaimPolicy claimPolicy,
        string requirementsURI
    );
    event TaskFunded(uint256 indexed taskId, address indexed client, uint256 amount);
    event WorkSubmitted(
        uint256 indexed taskId,
        uint256 indexed submissionId,
        address indexed submitter,
        string evidenceURI,
        bytes32 evidenceHash,
        bytes32 requestId
    );
    event VerdictRecorded(
        uint256 indexed taskId, uint256 indexed submissionId, uint8 verdict, bytes32 requestId, string verifierNotesURI
    );
    event VerificationFailedRecorded(
        uint256 indexed taskId, uint256 indexed submissionId, bytes32 requestId, string failureNotesURI
    );
    event VerificationRetried(
        uint256 indexed taskId, uint256 indexed submissionId, address indexed payer, bytes32 requestId
    );
    event TaskApproved(uint256 indexed taskId, address indexed client, uint256 indexed submissionId);
    event TaskClaimed(uint256 indexed taskId, address indexed recipient, uint256 amount);
    event DisputeRaised(uint256 indexed taskId, address indexed raisedBy, uint8 previousState, string reasonURI);
    event DisputeResolved(
        uint256 indexed taskId,
        address indexed resolver,
        uint256 clientRefund,
        uint256 contractorAward,
        string resolutionURI
    );
    event TaskCancelled(uint256 indexed taskId, address indexed client, uint256 refundAmount);
    event VerificationTimedOut(
        uint256 indexed taskId, uint256 indexed submissionId, bytes32 indexed requestId, uint64 timeoutAt
    );
    event PendingWithdrawalClaimed(address indexed account, uint256 amount);

    VigiliaEscrow private _escrow;
    MockVerifier private _verifier;

    address private _client = address(0xC11E47);
    address private _contractor = address(0xB011DE2);
    address private _resolver = address(0x4B17E2);
    address private _attacker = address(0xA77A);

    uint256 private constant _TASK_AMOUNT = 10 ether;
    uint64 private constant _REVIEW_WINDOW = 3 days;
    uint64 private constant _VERIFICATION_TIMEOUT = 1 hours;
    string private constant _REQUIREMENTS_URI = "ipfs://requirements";
    string private constant _EVIDENCE_URI = "ipfs://evidence";
    bytes32 private constant _EVIDENCE_HASH = keccak256("evidence");
    string private constant _VERIFIER_NOTES_URI = "ipfs://verifier-notes";
    string private constant _RESOLUTION_URI = "ipfs://resolution";

    function setUp() public {
        _verifier = new MockVerifier();
        _escrow = new VigiliaEscrow(address(_verifier));

        vm.deal(_client, 100 ether);
        vm.deal(_contractor, 1 ether);
        vm.deal(_resolver, 1 ether);
        vm.deal(_attacker, 1 ether);
    }

    function test_CreateTask_ClientCreatesTask() public {
        vm.expectEmit(true, true, true, true);
        emit TaskCreated(
            1,
            _client,
            _contractor,
            _resolver,
            _TASK_AMOUNT,
            _REVIEW_WINDOW,
            7 days,
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim,
            _REQUIREMENTS_URI
        );

        uint256 taskId = _createTask();

        (
            address client,
            address contractor,
            address resolver,
            uint256 amount,
            uint256 fundedAmount,
            uint256 activeSubmissionId,
            uint256 submissionCount,
            VigiliaEscrow.TaskState state,
            VigiliaEscrow.TaskState stateBeforeDispute,
            string memory requirementsURI,,
        ) = _escrow.tasks(taskId);

        assertEq(client, _client);
        assertEq(contractor, _contractor);
        assertEq(resolver, _resolver);
        assertEq(amount, _TASK_AMOUNT);
        assertEq(fundedAmount, 0);
        assertEq(activeSubmissionId, 0);
        assertEq(submissionCount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Created));
        assertEq(uint256(stateBeforeDispute), uint256(VigiliaEscrow.TaskState.None));
        assertEq(requirementsURI, _REQUIREMENTS_URI);
        assertEq(_taskReviewWindow(taskId), _REVIEW_WINDOW);
        assertEq(_taskVerificationTimeout(taskId), 7 days);
        assertEq(uint256(_escrow.taskClaimPolicies(taskId)), uint256(VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim));
        assertEq(_escrow.nextTaskId(), 2);
    }

    function test_Constructor_ZeroVerifierReverts() public {
        vm.expectRevert(VigiliaEscrow.InvalidAddress.selector);
        new VigiliaEscrow(address(0));
    }

    function test_CreateTask_ZeroContractorReverts() public {
        vm.prank(_client);
        vm.expectRevert(VigiliaEscrow.InvalidAddress.selector);
        _escrow.createTask(address(0), _resolver, _TASK_AMOUNT, _REVIEW_WINDOW, _REQUIREMENTS_URI);
    }

    function test_CreateTask_ZeroResolverReverts() public {
        vm.prank(_client);
        vm.expectRevert(VigiliaEscrow.InvalidAddress.selector);
        _escrow.createTask(_contractor, address(0), _TASK_AMOUNT, _REVIEW_WINDOW, _REQUIREMENTS_URI);
    }

    function test_CreateTask_ZeroAmountReverts() public {
        vm.prank(_client);
        vm.expectRevert(VigiliaEscrow.InvalidAmount.selector);
        _escrow.createTask(_contractor, _resolver, 0, _REVIEW_WINDOW, _REQUIREMENTS_URI);
    }

    function test_FundTask_ClientFundsEscrow() public {
        uint256 taskId = _createTask();

        vm.expectEmit(true, true, false, true);
        emit TaskFunded(taskId, _client, _TASK_AMOUNT);

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, _TASK_AMOUNT);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Funded));
        assertEq(address(_escrow).balance, _TASK_AMOUNT);
    }

    function test_FundTask_InvalidFundingAmountReverts() public {
        uint256 taskId = _createTask();

        vm.prank(_client);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.InvalidFundingAmount.selector, _TASK_AMOUNT, 9 ether));
        _escrow.fundTask{ value: 9 ether }(taskId);
    }

    function test_FundTask_UnauthorizedCallerReverts() public {
        uint256 taskId = _createTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.fundTask{ value: 1 ether }(taskId);
    }

    function test_SubmitWork_ContractorSubmitsEvidence() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_contractor);
        (uint256 submissionId, bytes32 requestId) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        (,,,,, uint256 activeSubmissionId, uint256 submissionCount, VigiliaEscrow.TaskState state,,,,) =
            _escrow.tasks(taskId);
        (
            uint256 submissionTaskId,
            address submitter,
            string memory evidenceURI,
            bytes32 evidenceHash,
            bytes32 storedRequestId,
            VigiliaTypes.VerificationVerdict verdict,
            uint64 submittedAt,
            uint64 verifiedAt
        ) = _escrow.submissions(submissionId);

        assertEq(submissionId, 1);
        assertTrue(requestId != bytes32(0));
        assertEq(activeSubmissionId, submissionId);
        assertEq(submissionCount, 1);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(submissionTaskId, taskId);
        assertEq(submitter, _contractor);
        assertEq(evidenceURI, _EVIDENCE_URI);
        assertEq(evidenceHash, _EVIDENCE_HASH);
        assertEq(storedRequestId, requestId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertEq(submittedAt, block.timestamp);
        assertEq(verifiedAt, 0);
        assertTrue(_verifier.requests(requestId));
    }

    function test_SubmitWork_UnauthorizedCallerReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function test_SubmitWork_ZeroEvidenceHashReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_contractor);
        vm.expectRevert(VigiliaEscrow.ZeroEvidenceHash.selector);
        _escrow.submitWork(taskId, _EVIDENCE_URI, bytes32(0));
    }

    function test_SubmitWork_EmptyEvidenceURIReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_contractor);
        vm.expectRevert(VigiliaEscrow.EmptyEvidenceURI.selector);
        _escrow.submitWork(taskId, "", _EVIDENCE_HASH);
    }

    function test_SubmitWork_BeforeFundingReverts() public {
        uint256 taskId = _createTask();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Created)
        );
        _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function test_SubmitWork_DoubleSubmitBeforeVerdictReverts() public {
        (uint256 taskId,,) = _createFundAndSubmitTask();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Submitted)
        );
        _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));
    }

    function test_SubmitWork_ZeroRequestIdRevertsAndRollsBack() public {
        uint256 taskId = _createAndFundTask();
        _verifier.setForceZeroRequestId(true);

        vm.prank(_contractor);
        vm.expectRevert(VigiliaEscrow.ZeroRequestId.selector);
        _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        (,,,,, uint256 activeSubmissionId, uint256 submissionCount, VigiliaEscrow.TaskState state,,,,) =
            _escrow.tasks(taskId);
        assertEq(activeSubmissionId, 0);
        assertEq(submissionCount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Funded));
        assertEq(_escrow.nextSubmissionId(), 1);
        assertEq(_verifier.nextRequestNonce(), 0);
    }

    function test_SubmitWork_EmitsWorkSubmitted() public {
        uint256 taskId = _createAndFundTask();
        bytes32 expectedRequestId =
            keccak256(abi.encode(address(_escrow), taskId, uint256(1), _EVIDENCE_URI, uint256(1)));

        vm.expectEmit(true, true, true, true);
        emit WorkSubmitted(taskId, 1, _contractor, _EVIDENCE_URI, _EVIDENCE_HASH, expectedRequestId);

        vm.prank(_contractor);
        _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function test_RecordVerdict_VerifierMarksComplete() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();

        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Complete);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,, uint64 verifiedAt) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
        assertEq(verifiedAt, block.timestamp);
    }

    function test_RecordVerdict_VerifierMarksNeedsReview() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();

        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.NeedsReview);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.NeedsReview));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.NeedsReview));
    }

    function test_RecordVerdict_VerifierMarksIncomplete() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();

        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Incomplete);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Incomplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Incomplete));
    }

    function test_RecordVerdict_UnauthorizedVerifierCallerReverts() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.recordVerdict(
            taskId, submissionId, requestId, VigiliaTypes.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function test_RecordVerdict_UnknownVerdictReverts() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();

        vm.prank(address(_verifier));
        vm.expectRevert(VigiliaEscrow.UnknownVerdict.selector);
        _escrow.recordVerdict(
            taskId, submissionId, requestId, VigiliaTypes.VerificationVerdict.Unknown, _VERIFIER_NOTES_URI
        );
    }

    function test_RecordVerdict_WrongSubmissionTaskReverts() public {
        (uint256 firstTaskId,,) = _createFundAndSubmitTask();
        (uint256 secondTaskId, uint256 secondSubmissionId, bytes32 secondRequestId) = _createFundAndSubmitTask();

        vm.prank(address(_verifier));
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidSubmission.selector, firstTaskId, secondSubmissionId)
        );
        _escrow.recordVerdict(
            firstTaskId,
            secondSubmissionId,
            secondRequestId,
            VigiliaTypes.VerificationVerdict.Complete,
            _VERIFIER_NOTES_URI
        );

        (,,,,,,, VigiliaEscrow.TaskState firstState,,,,) = _escrow.tasks(firstTaskId);
        (,,,,,,, VigiliaEscrow.TaskState secondState,,,,) = _escrow.tasks(secondTaskId);
        assertEq(uint256(firstState), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(uint256(secondState), uint256(VigiliaEscrow.TaskState.Submitted));
    }

    function test_RecordVerdict_StaleOldSubmissionAfterResubmissionReverts() public {
        (uint256 taskId, uint256 firstSubmissionId,) = _createFundAndSubmitTask();
        _recordVerdict(taskId, firstSubmissionId, VigiliaTypes.VerificationVerdict.Incomplete);

        vm.prank(_contractor);
        _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));

        bytes32 firstRequestId = _submissionRequestId(firstSubmissionId);
        vm.prank(address(_verifier));
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.InvalidSubmission.selector, taskId, firstSubmissionId));
        _escrow.recordVerdict(
            taskId, firstSubmissionId, firstRequestId, VigiliaTypes.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function test_RecordVerdict_TwiceForSameSubmissionReverts() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();
        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Complete);

        bytes32 requestId = _submissionRequestId(submissionId);
        vm.prank(address(_verifier));
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerifiedComplete
            )
        );
        _escrow.recordVerdict(
            taskId, submissionId, requestId, VigiliaTypes.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function test_RecordVerdict_WrongRequestIdReverts() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();
        bytes32 wrongRequestId = keccak256("wrong-request");

        vm.prank(address(_verifier));
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidRequestId.selector, taskId, submissionId, requestId, wrongRequestId
            )
        );
        _escrow.recordVerdict(
            taskId, submissionId, wrongRequestId, VigiliaTypes.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function test_RecordVerdict_EmitsVerdictRecorded() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();

        vm.expectEmit(true, true, false, true);
        emit VerdictRecorded(
            taskId, submissionId, uint8(VigiliaTypes.VerificationVerdict.Complete), requestId, _VERIFIER_NOTES_URI
        );

        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Complete);
    }

    function test_RecordVerificationFailure_VerifierRecordsFailure() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();

        vm.expectEmit(true, true, false, true);
        emit VerificationFailedRecorded(taskId, submissionId, requestId, _VERIFIER_NOTES_URI);

        _recordVerificationFailure(taskId, submissionId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,, uint64 verifiedAt) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertEq(verifiedAt, 0);
    }

    function test_RecordVerificationFailure_NonVerifierReverts() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.recordVerificationFailure(taskId, submissionId, requestId, _VERIFIER_NOTES_URI);
    }

    function test_RecordVerificationFailure_StaleOldSubmissionReverts() public {
        (uint256 taskId, uint256 firstSubmissionId,) = _createFundAndSubmitTask();
        _recordVerificationFailure(taskId, firstSubmissionId);

        vm.prank(_contractor);
        _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));

        bytes32 firstRequestId = _submissionRequestId(firstSubmissionId);
        vm.prank(address(_verifier));
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.InvalidSubmission.selector, taskId, firstSubmissionId));
        _escrow.recordVerificationFailure(taskId, firstSubmissionId, firstRequestId, _VERIFIER_NOTES_URI);
    }

    function test_RecordVerificationFailure_TwiceForSameSubmissionReverts() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();
        _recordVerificationFailure(taskId, submissionId);

        bytes32 requestId = _submissionRequestId(submissionId);
        vm.prank(address(_verifier));
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerificationFailed
            )
        );
        _escrow.recordVerificationFailure(taskId, submissionId, requestId, _VERIFIER_NOTES_URI);
    }

    function test_RecordVerificationFailure_WrongRequestIdReverts() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();
        bytes32 wrongRequestId = keccak256("wrong-request");

        vm.prank(address(_verifier));
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidRequestId.selector, taskId, submissionId, requestId, wrongRequestId
            )
        );
        _escrow.recordVerificationFailure(taskId, submissionId, wrongRequestId, _VERIFIER_NOTES_URI);
    }

    function test_ApproveTask_ClientApprovesCompleteTask() public {
        (uint256 taskId, uint256 submissionId,) = _createFundSubmitAndCompleteTask();

        vm.expectEmit(true, true, true, true);
        emit TaskApproved(taskId, _client, submissionId);

        vm.prank(_client);
        _escrow.approveTask(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Approved));
    }

    function test_ApproveTask_ClientApprovesNeedsReviewTask() public {
        (uint256 taskId, uint256 submissionId,) = _createFundSubmitAndNeedsReviewTask();

        vm.expectEmit(true, true, true, true);
        emit TaskApproved(taskId, _client, submissionId);

        vm.prank(_client);
        _escrow.approveTask(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Approved));
    }

    function test_ApproveTask_UnauthorizedCallerReverts() public {
        (uint256 taskId,,) = _createFundSubmitAndCompleteTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.approveTask(taskId);
    }

    function test_ApproveTask_ClientApprovesIncompleteTask() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();
        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Incomplete);

        vm.expectEmit(true, true, true, true);
        emit TaskApproved(taskId, _client, submissionId);

        vm.prank(_client);
        _escrow.approveTask(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Approved));
    }

    function test_ApproveTask_ClientApprovesSubmittedTask() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();

        vm.expectEmit(true, true, true, true);
        emit TaskApproved(taskId, _client, submissionId);

        vm.prank(_client);
        _escrow.approveTask(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Approved));
    }

    function test_ApproveTask_ClientApprovesVerificationFailedTask() public {
        (uint256 taskId, uint256 submissionId,) = _createFundSubmitAndVerificationFailedTask();

        vm.expectEmit(true, true, true, true);
        emit TaskApproved(taskId, _client, submissionId);

        vm.prank(_client);
        _escrow.approveTask(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Approved));
    }

    function test_ApproveTask_ForFundedReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Funded)
        );
        _escrow.approveTask(taskId);
    }

    function test_Claim_ContractorClaimsApprovedTask() public {
        (uint256 taskId,,) = _createFundSubmitApproveTask();

        uint256 contractorBalanceBefore = _contractor.balance;

        vm.expectEmit(true, true, false, true);
        emit TaskClaimed(taskId, _contractor, _TASK_AMOUNT);

        vm.prank(_contractor);
        _escrow.claim(taskId);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Claimed));
        assertEq(address(_escrow).balance, 0);
        assertEq(_contractor.balance, contractorBalanceBefore + _TASK_AMOUNT);
    }

    function test_Claim_UnauthorizedClaimReverts() public {
        (uint256 taskId,,) = _createFundSubmitApproveTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.claim(taskId);
    }

    function test_Claim_BeforeReviewWindowExpiresReverts() public {
        (uint256 taskId,,) = _createFundSubmitAndCompleteTask();
        uint256 claimableAt = block.timestamp + _REVIEW_WINDOW;

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.ReviewWindowActive.selector, taskId, claimableAt, block.timestamp)
        );
        _escrow.claim(taskId);
    }

    function test_Claim_ContractorClaimsAfterReviewWindowExpires() public {
        (uint256 taskId,,) = _createFundSubmitAndCompleteTask();
        uint256 contractorBalanceBefore = _contractor.balance;

        vm.warp(block.timestamp + _REVIEW_WINDOW);

        vm.expectEmit(true, true, false, true);
        emit TaskClaimed(taskId, _contractor, _TASK_AMOUNT);

        vm.prank(_contractor);
        _escrow.claim(taskId);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Claimed));
        assertEq(address(_escrow).balance, 0);
        assertEq(_contractor.balance, contractorBalanceBefore + _TASK_AMOUNT);
    }

    function test_Claim_ReviewWindowPolicyClientApprovalAllowsEarlyClaim() public {
        (uint256 taskId,,) = _createFundSubmitAndCompleteTaskWithPolicy(VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim);

        vm.prank(_contractor);
        vm.expectRevert();
        _escrow.claim(taskId);

        vm.prank(_client);
        _escrow.approveTask(taskId);

        uint256 contractorBalanceBefore = _contractor.balance;
        vm.prank(_contractor);
        _escrow.claim(taskId);

        assertEq(_contractor.balance, contractorBalanceBefore + _TASK_AMOUNT);
        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Claimed));
    }

    function test_Claim_NeedsReviewDoesNotAutoClaimAfterReviewWindow() public {
        (uint256 taskId,,) = _createFundSubmitAndNeedsReviewTask();

        vm.warp(block.timestamp + _REVIEW_WINDOW);

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.NeedsReview)
        );
        _escrow.claim(taskId);
    }

    function test_Claim_NeedsReviewNeverAutoClaimsUnderAnyPolicy() public {
        _assertVerdictDoesNotAutoClaim(
            VigiliaEscrow.ClaimPolicy.ClientApprovalOnly,
            VigiliaTypes.VerificationVerdict.NeedsReview,
            VigiliaEscrow.TaskState.NeedsReview
        );
        _assertVerdictDoesNotAutoClaim(
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim,
            VigiliaTypes.VerificationVerdict.NeedsReview,
            VigiliaEscrow.TaskState.NeedsReview
        );
        _assertVerdictDoesNotAutoClaim(
            VigiliaEscrow.ClaimPolicy.ImmediateAutoClaim,
            VigiliaTypes.VerificationVerdict.NeedsReview,
            VigiliaEscrow.TaskState.NeedsReview
        );
    }

    function test_Claim_IncompleteNeverAutoClaimsUnderAnyPolicy() public {
        _assertVerdictDoesNotAutoClaim(
            VigiliaEscrow.ClaimPolicy.ClientApprovalOnly,
            VigiliaTypes.VerificationVerdict.Incomplete,
            VigiliaEscrow.TaskState.Incomplete
        );
        _assertVerdictDoesNotAutoClaim(
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim,
            VigiliaTypes.VerificationVerdict.Incomplete,
            VigiliaEscrow.TaskState.Incomplete
        );
        _assertVerdictDoesNotAutoClaim(
            VigiliaEscrow.ClaimPolicy.ImmediateAutoClaim,
            VigiliaTypes.VerificationVerdict.Incomplete,
            VigiliaEscrow.TaskState.Incomplete
        );
    }

    function test_Claim_VerificationFailedNeverAutoClaimsUnderAnyPolicy() public {
        _assertVerificationFailedDoesNotAutoClaim(VigiliaEscrow.ClaimPolicy.ClientApprovalOnly);
        _assertVerificationFailedDoesNotAutoClaim(VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim);
        _assertVerificationFailedDoesNotAutoClaim(VigiliaEscrow.ClaimPolicy.ImmediateAutoClaim);
    }

    function test_Claim_VerificationFailedBlocksClaim() public {
        (uint256 taskId,,) = _createFundSubmitAndVerificationFailedTask();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerificationFailed
            )
        );
        _escrow.claim(taskId);
    }

    function test_Claim_ClientApprovalOnlyRequiresApprovalAfterComplete() public {
        (uint256 taskId, uint256 submissionId,) =
            _createFundSubmitAndCompleteTaskWithPolicy(VigiliaEscrow.ClaimPolicy.ClientApprovalOnly);

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerifiedComplete
            )
        );
        _escrow.claim(taskId);

        vm.prank(_client);
        _escrow.approveTask(taskId);

        vm.prank(_contractor);
        _escrow.claim(taskId);

        (,,,,, uint256 activeSubmissionId,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(activeSubmissionId, submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Claimed));
    }

    function test_Claim_ImmediateAutoClaimAllowsImmediatePullAfterComplete() public {
        (uint256 taskId,,) = _createFundSubmitAndCompleteTaskWithPolicy(VigiliaEscrow.ClaimPolicy.ImmediateAutoClaim);

        uint256 contractorBalanceBefore = _contractor.balance;
        vm.prank(_contractor);
        _escrow.claim(taskId);

        assertEq(_contractor.balance, contractorBalanceBefore + _TASK_AMOUNT);
        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Claimed));
    }

    function test_Claim_NeedsReviewNeverAutoClaimsWithImmediatePolicy() public {
        (uint256 taskId,,) = _createFundSubmitAndVerdictWithPolicy(
            VigiliaEscrow.ClaimPolicy.ImmediateAutoClaim, VigiliaTypes.VerificationVerdict.NeedsReview
        );

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.NeedsReview)
        );
        _escrow.claim(taskId);
    }

    function test_Claim_IncompleteNeverAutoClaimsWithImmediatePolicy() public {
        (uint256 taskId,,) = _createFundSubmitAndVerdictWithPolicy(
            VigiliaEscrow.ClaimPolicy.ImmediateAutoClaim, VigiliaTypes.VerificationVerdict.Incomplete
        );

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Incomplete)
        );
        _escrow.claim(taskId);
    }

    function test_RecordVerdict_DoesNotPushFundsDuringCallback() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();
        uint256 contractorBalanceBefore = _contractor.balance;

        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Complete);

        assertEq(_contractor.balance, contractorBalanceBefore);
        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, _TASK_AMOUNT);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
    }

    function test_Claim_DisputeBeforeReviewWindowExpiresPausesAutoClaim() public {
        (uint256 taskId,,) = _createFundSubmitAndCompleteTask();

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://dispute");

        vm.warp(block.timestamp + _REVIEW_WINDOW);

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Disputed)
        );
        _escrow.claim(taskId);
    }

    function test_Dispute_PausesClaim() public {
        (uint256 taskId,,) = _createFundSubmitApproveTask();

        vm.expectEmit(true, true, false, true);
        emit DisputeRaised(taskId, _client, uint8(VigiliaEscrow.TaskState.Approved), "ipfs://dispute");

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://dispute");

        (,,,,,,, VigiliaEscrow.TaskState state, VigiliaEscrow.TaskState previousState,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Disputed));
        assertEq(uint256(previousState), uint256(VigiliaEscrow.TaskState.Approved));

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Disputed)
        );
        _escrow.claim(taskId);
    }

    function test_RaiseDispute_ClientRaisesDisputeInDisputableState() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://client-dispute");

        (,,,,,,, VigiliaEscrow.TaskState state, VigiliaEscrow.TaskState previousState,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Disputed));
        assertEq(uint256(previousState), uint256(VigiliaEscrow.TaskState.Funded));
    }

    function test_RaiseDispute_ContractorRaisesDisputeInDisputableState() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_contractor);
        _escrow.raiseDispute(taskId, "ipfs://contractor-dispute");

        (,,,,,,, VigiliaEscrow.TaskState state, VigiliaEscrow.TaskState previousState,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Disputed));
        assertEq(uint256(previousState), uint256(VigiliaEscrow.TaskState.Funded));
    }

    function test_RaiseDispute_ClientRaisesDisputeFromVerificationFailed() public {
        (uint256 taskId,,) = _createFundSubmitAndVerificationFailedTask();

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://client-dispute");

        (,,,,,,, VigiliaEscrow.TaskState state, VigiliaEscrow.TaskState previousState,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Disputed));
        assertEq(uint256(previousState), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_RaiseDispute_ContractorRaisesDisputeFromVerificationFailed() public {
        (uint256 taskId,,) = _createFundSubmitAndVerificationFailedTask();

        vm.prank(_contractor);
        _escrow.raiseDispute(taskId, "ipfs://contractor-dispute");

        (,,,,,,, VigiliaEscrow.TaskState state, VigiliaEscrow.TaskState previousState,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Disputed));
        assertEq(uint256(previousState), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_ResolveDispute_ResolverAwardsFullContractorPayout() public {
        uint256 taskId = _createFundAndDisputeTask();

        vm.prank(_resolver);
        _escrow.resolveDispute(taskId, 0, _TASK_AMOUNT, _RESOLUTION_URI);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Resolved));
        assertEq(_escrow.pendingWithdrawals(_client), 0);
        assertEq(_escrow.pendingWithdrawals(_contractor), _TASK_AMOUNT);
        assertEq(address(_escrow).balance, _TASK_AMOUNT);

        uint256 contractorBalanceBefore = _contractor.balance;

        vm.expectEmit(true, false, false, true);
        emit PendingWithdrawalClaimed(_contractor, _TASK_AMOUNT);

        vm.prank(_contractor);
        _escrow.withdrawPending();

        assertEq(_escrow.pendingWithdrawals(_contractor), 0);
        assertEq(_contractor.balance, contractorBalanceBefore + _TASK_AMOUNT);
        assertEq(address(_escrow).balance, 0);
    }

    function test_ResolveDispute_ResolverRefundsFullClientAmount() public {
        uint256 taskId = _createFundAndDisputeTask();

        vm.prank(_resolver);
        _escrow.resolveDispute(taskId, _TASK_AMOUNT, 0, _RESOLUTION_URI);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Resolved));
        assertEq(_escrow.pendingWithdrawals(_client), _TASK_AMOUNT);
        assertEq(_escrow.pendingWithdrawals(_contractor), 0);

        uint256 clientBalanceBefore = _client.balance;

        vm.prank(_client);
        _escrow.withdrawPending();

        assertEq(_escrow.pendingWithdrawals(_client), 0);
        assertEq(_client.balance, clientBalanceBefore + _TASK_AMOUNT);
        assertEq(address(_escrow).balance, 0);
    }

    function test_ResolveDispute_ResolverSplitsSettlement() public {
        uint256 taskId = _createFundAndDisputeTask();
        uint256 clientRefund = 4 ether;
        uint256 contractorAward = 6 ether;

        vm.expectEmit(true, true, false, true);
        emit DisputeResolved(taskId, _resolver, clientRefund, contractorAward, _RESOLUTION_URI);

        vm.prank(_resolver);
        _escrow.resolveDispute(taskId, clientRefund, contractorAward, _RESOLUTION_URI);

        assertEq(_escrow.pendingWithdrawals(_client), clientRefund);
        assertEq(_escrow.pendingWithdrawals(_contractor), contractorAward);
        assertEq(address(_escrow).balance, _TASK_AMOUNT);

        uint256 clientBalanceBefore = _client.balance;
        uint256 contractorBalanceBefore = _contractor.balance;

        vm.prank(_client);
        _escrow.withdrawPending();

        vm.prank(_contractor);
        _escrow.withdrawPending();

        assertEq(_client.balance, clientBalanceBefore + clientRefund);
        assertEq(_contractor.balance, contractorBalanceBefore + contractorAward);
        assertEq(_escrow.pendingWithdrawals(_client), 0);
        assertEq(_escrow.pendingWithdrawals(_contractor), 0);
        assertEq(address(_escrow).balance, 0);
    }

    function test_ResolveDispute_UnauthorizedResolverCallerReverts() public {
        uint256 taskId = _createFundAndDisputeTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.resolveDispute(taskId, _TASK_AMOUNT, 0, _RESOLUTION_URI);
    }

    function test_ResolveDispute_NonDisputedTaskReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_resolver);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Funded)
        );
        _escrow.resolveDispute(taskId, _TASK_AMOUNT, 0, _RESOLUTION_URI);
    }

    function test_ResolveDispute_AlreadyResolvedTaskReverts() public {
        uint256 taskId = _createFundAndDisputeTask();

        vm.prank(_resolver);
        _escrow.resolveDispute(taskId, _TASK_AMOUNT, 0, _RESOLUTION_URI);

        vm.prank(_resolver);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Resolved)
        );
        _escrow.resolveDispute(taskId, _TASK_AMOUNT, 0, _RESOLUTION_URI);
    }

    function test_ResolveDispute_ResolutionAmountMismatchReverts() public {
        uint256 taskId = _createFundAndDisputeTask();

        vm.prank(_resolver);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.InvalidResolutionAmount.selector, _TASK_AMOUNT, 9 ether));
        _escrow.resolveDispute(taskId, 4 ether, 5 ether, _RESOLUTION_URI);
    }

    function test_Claim_AfterDisputeResolutionReverts() public {
        uint256 taskId = _createFundAndDisputeTask();

        vm.prank(_resolver);
        _escrow.resolveDispute(taskId, 0, _TASK_AMOUNT, _RESOLUTION_URI);

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Resolved)
        );
        _escrow.claim(taskId);
    }

    function test_WithdrawPending_NoPendingWithdrawalReverts() public {
        vm.prank(_contractor);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.NoPendingWithdrawal.selector, _contractor));
        _escrow.withdrawPending();
    }

    function test_WithdrawPendingTo_DisputeCreditCanWithdrawToAlternateRecipient() public {
        uint256 taskId = _createFundAndDisputeTask();

        vm.prank(_resolver);
        _escrow.resolveDispute(taskId, 0, _TASK_AMOUNT, _RESOLUTION_URI);

        address payable recipient = payable(address(0xDEAD));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.expectEmit(true, false, false, true);
        emit PendingWithdrawalClaimed(recipient, _TASK_AMOUNT);

        vm.prank(_contractor);
        _escrow.withdrawPendingTo(recipient);

        assertEq(_escrow.pendingWithdrawals(_contractor), 0);
        assertEq(recipient.balance, recipientBalanceBefore + _TASK_AMOUNT);
    }

    function test_WithdrawPendingTo_CancelRefundCanWithdrawToAlternateRecipient() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.cancelTask(taskId);

        address payable recipient = payable(address(0xBEEF));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.expectEmit(true, false, false, true);
        emit PendingWithdrawalClaimed(recipient, _TASK_AMOUNT);

        vm.prank(_client);
        _escrow.withdrawPendingTo(recipient);

        assertEq(_escrow.pendingWithdrawals(_client), 0);
        assertEq(recipient.balance, recipientBalanceBefore + _TASK_AMOUNT);
        assertEq(address(_escrow).balance, 0);
    }

    function test_WithdrawPendingTo_ZeroRecipientReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.cancelTask(taskId);

        vm.prank(_client);
        vm.expectRevert(VigiliaEscrow.InvalidAddress.selector);
        _escrow.withdrawPendingTo(payable(address(0)));
    }

    function test_WithdrawPendingTo_CannotWithdrawTwice() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.cancelTask(taskId);

        vm.prank(_client);
        _escrow.withdrawPending();

        vm.prank(_client);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.NoPendingWithdrawal.selector, _client));
        _escrow.withdrawPending();
    }

    function test_CancelTask_ClientCancelsFundedTaskAndReceivesRefund() public {
        uint256 taskId = _createAndFundTask();
        uint256 clientBalanceBefore = _client.balance;

        vm.expectEmit(true, true, false, true);
        emit TaskCancelled(taskId, _client, _TASK_AMOUNT);

        vm.prank(_client);
        _escrow.cancelTask(taskId);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Cancelled));
        assertEq(address(_escrow).balance, _TASK_AMOUNT);
        assertEq(_escrow.pendingWithdrawals(_client), _TASK_AMOUNT);

        vm.prank(_client);
        _escrow.withdrawPending();

        assertEq(address(_escrow).balance, 0);
        assertEq(_client.balance, clientBalanceBefore + _TASK_AMOUNT);
    }

    function test_CancelTask_ClientCancelsCreatedTaskWithZeroRefund() public {
        uint256 taskId = _createTask();
        uint256 clientBalanceBefore = _client.balance;

        vm.expectEmit(true, true, false, true);
        emit TaskCancelled(taskId, _client, 0);

        vm.prank(_client);
        _escrow.cancelTask(taskId);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Cancelled));
        assertEq(address(_escrow).balance, 0);
        assertEq(_client.balance, clientBalanceBefore);
    }

    function test_CancelTask_ClientCancelsIncompleteTaskAndReceivesRefund() public {
        (uint256 taskId, uint256 submissionId,) = _createFundAndSubmitTask();
        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Incomplete);
        uint256 clientBalanceBefore = _client.balance;

        vm.prank(_client);
        _escrow.cancelTask(taskId);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Cancelled));
        assertEq(address(_escrow).balance, _TASK_AMOUNT);
        assertEq(_escrow.pendingWithdrawals(_client), _TASK_AMOUNT);

        vm.prank(_client);
        _escrow.withdrawPending();

        assertEq(address(_escrow).balance, 0);
        assertEq(_client.balance, clientBalanceBefore + _TASK_AMOUNT);
    }

    function test_CancelTask_UnauthorizedCallerReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.cancelTask(taskId);
    }

    function test_CancelTask_CannotCancelSubmittedTask() public {
        (uint256 taskId,,) = _createFundAndSubmitTask();

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Submitted)
        );
        _escrow.cancelTask(taskId);
    }

    function test_CancelTask_CannotCancelVerificationFailedTask() public {
        (uint256 taskId,,) = _createFundSubmitAndVerificationFailedTask();

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerificationFailed
            )
        );
        _escrow.cancelTask(taskId);
    }

    function test_CancelTask_CannotCancelVerifiedCompleteTask() public {
        (uint256 taskId,,) = _createFundSubmitAndCompleteTask();

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerifiedComplete
            )
        );
        _escrow.cancelTask(taskId);
    }

    function test_CancelTask_CannotCancelApprovedTask() public {
        (uint256 taskId,,) = _createFundSubmitApproveTask();

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Approved)
        );
        _escrow.cancelTask(taskId);
    }

    function test_CancelTask_CannotCancelDisputedTask() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://dispute");

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Disputed)
        );
        _escrow.cancelTask(taskId);
    }

    function test_RaiseDispute_UnauthorizedCallerReverts() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.raiseDispute(taskId, "ipfs://dispute");
    }

    function test_RaiseDispute_NonDisputableStateReverts() public {
        uint256 taskId = _createTask();

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Created)
        );
        _escrow.raiseDispute(taskId, "ipfs://dispute");
    }

    function test_RaiseDispute_CannotBeCalledTwice() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://dispute");

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Disputed)
        );
        _escrow.raiseDispute(taskId, "ipfs://second-dispute");
    }

    function test_ResubmitWork_AfterIncompleteVerdict() public {
        (uint256 taskId, uint256 firstSubmissionId,) = _createFundAndSubmitTask();
        _recordVerdict(taskId, firstSubmissionId, VigiliaTypes.VerificationVerdict.Incomplete);

        vm.prank(_contractor);
        (uint256 secondSubmissionId,) = _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));

        (,,,,, uint256 activeSubmissionId, uint256 submissionCount, VigiliaEscrow.TaskState state,,,,) =
            _escrow.tasks(taskId);

        assertEq(secondSubmissionId, 2);
        assertEq(activeSubmissionId, secondSubmissionId);
        assertEq(submissionCount, 2);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
    }

    function test_ResubmitWork_AfterVerificationFailed() public {
        (uint256 taskId,,) = _createFundSubmitAndVerificationFailedTask();

        vm.prank(_contractor);
        (uint256 secondSubmissionId,) = _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));

        (,,,,, uint256 activeSubmissionId, uint256 submissionCount, VigiliaEscrow.TaskState state,,,,) =
            _escrow.tasks(taskId);

        assertEq(secondSubmissionId, 2);
        assertEq(activeSubmissionId, secondSubmissionId);
        assertEq(submissionCount, 2);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
    }

    function test_RetryVerification_ClientRetriesAfterVerificationFailed() public {
        (uint256 taskId, uint256 submissionId,) = _createFundSubmitAndVerificationFailedTask();
        bytes32 expectedRequestId =
            keccak256(abi.encode(address(_escrow), taskId, submissionId, _EVIDENCE_URI, uint256(2)));

        vm.expectEmit(true, true, true, true);
        emit VerificationRetried(taskId, submissionId, _client, expectedRequestId);

        vm.prank(_client);
        bytes32 requestId = _escrow.retryVerification(taskId);

        (,,,, bytes32 storedRequestId,,,) = _escrow.submissions(submissionId);
        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);

        assertEq(requestId, expectedRequestId);
        assertEq(storedRequestId, expectedRequestId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
    }

    function test_RetryVerification_ContractorRetriesAfterVerificationFailed() public {
        (uint256 taskId, uint256 submissionId,) = _createFundSubmitAndVerificationFailedTask();

        vm.prank(_contractor);
        bytes32 requestId = _escrow.retryVerification(taskId);

        (,,,, bytes32 storedRequestId,,,) = _escrow.submissions(submissionId);
        assertEq(storedRequestId, requestId);
    }

    function test_RetryVerification_NonPartyReverts() public {
        (uint256 taskId,,) = _createFundSubmitAndVerificationFailedTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.retryVerification(taskId);
    }

    function test_MarkVerificationTimedOut_ClientMarksSubmittedTaskAfterTimeout() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundSubmitWithTimeout(_VERIFICATION_TIMEOUT);
        (,,,,,, uint64 submittedAt,) = _escrow.submissions(submissionId);
        uint256 timeoutAt = uint256(submittedAt) + _VERIFICATION_TIMEOUT;

        vm.warp(timeoutAt + 1);

        vm.expectEmit(true, true, true, true);
        emit VerificationTimedOut(taskId, submissionId, requestId, uint64(timeoutAt));

        vm.prank(_client);
        _escrow.markVerificationTimedOut(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_MarkVerificationTimedOut_ContractorMarksSubmittedTaskAfterTimeout() public {
        (uint256 taskId,,) = _createFundSubmitWithTimeout(_VERIFICATION_TIMEOUT);

        vm.warp(block.timestamp + _VERIFICATION_TIMEOUT + 1);

        vm.prank(_contractor);
        _escrow.markVerificationTimedOut(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_MarkVerificationTimedOut_TooEarlyReverts() public {
        (uint256 taskId,,) = _createFundSubmitWithTimeout(_VERIFICATION_TIMEOUT);
        uint256 timeoutAt = block.timestamp + _VERIFICATION_TIMEOUT;

        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.VerificationTimeoutNotExpired.selector, taskId, timeoutAt, block.timestamp
            )
        );
        _escrow.markVerificationTimedOut(taskId);
    }

    function test_MarkVerificationTimedOut_UnauthorizedCallerReverts() public {
        (uint256 taskId,,) = _createFundSubmitWithTimeout(_VERIFICATION_TIMEOUT);

        vm.warp(block.timestamp + _VERIFICATION_TIMEOUT + 1);

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.Unauthorized.selector, _attacker));
        _escrow.markVerificationTimedOut(taskId);
    }

    function test_MarkVerificationTimedOut_DoesNotAllowDirectClaim() public {
        (uint256 taskId,,) = _createFundSubmitWithTimeout(_VERIFICATION_TIMEOUT);

        vm.warp(block.timestamp + _VERIFICATION_TIMEOUT + 1);
        vm.prank(_client);
        _escrow.markVerificationTimedOut(taskId);

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerificationFailed
            )
        );
        _escrow.claim(taskId);
    }

    function test_CreateTaskWithPolicy_AppliesDefaultVerificationTimeout() public {
        vm.prank(_client);
        uint256 taskId = _escrow.createTaskWithPolicy(
            _contractor,
            _resolver,
            _TASK_AMOUNT,
            _REVIEW_WINDOW,
            _REQUIREMENTS_URI,
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim
        );

        assertEq(_taskReviewWindow(taskId), _REVIEW_WINDOW);
        assertEq(_taskVerificationTimeout(taskId), 7 days);
    }

    function test_CreateTaskWithPolicyAndTimeout_CustomTimeoutStored() public {
        uint64 customTimeout = 2 hours;

        vm.prank(_client);
        uint256 taskId = _escrow.createTaskWithPolicyAndTimeout(
            _contractor,
            _resolver,
            _TASK_AMOUNT,
            _REVIEW_WINDOW,
            _REQUIREMENTS_URI,
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim,
            customTimeout
        );

        assertEq(_taskReviewWindow(taskId), _REVIEW_WINDOW);
        assertEq(_taskVerificationTimeout(taskId), customTimeout);
    }

    function test_CreateTaskWithPolicyAndTimeout_BelowMinTimeoutReverts() public {
        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidVerificationTimeout.selector,
                uint64(59 seconds),
                uint64(60 seconds),
                uint64(30 days)
            )
        );
        _escrow.createTaskWithPolicyAndTimeout(
            _contractor,
            _resolver,
            _TASK_AMOUNT,
            _REVIEW_WINDOW,
            _REQUIREMENTS_URI,
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim,
            uint64(59 seconds)
        );
    }

    function test_CreateTaskWithPolicyAndTimeout_AboveMaxTimeoutReverts() public {
        vm.prank(_client);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidVerificationTimeout.selector,
                uint64(30 days + 1),
                uint64(60 seconds),
                uint64(30 days)
            )
        );
        _escrow.createTaskWithPolicyAndTimeout(
            _contractor,
            _resolver,
            _TASK_AMOUNT,
            _REVIEW_WINDOW,
            _REQUIREMENTS_URI,
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim,
            uint64(30 days + 1)
        );
    }

    function test_MarkVerificationTimedOut_CustomTimeoutWorksAfterConfiguredValue() public {
        uint64 customTimeout = 2 hours;
        uint256 taskId = _createTaskWithTimeout(customTimeout);

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);

        vm.prank(_contractor);
        (uint256 submissionId,) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
        (,,,,,, uint64 submittedAt,) = _escrow.submissions(submissionId);
        uint256 timeoutAt = uint256(submittedAt) + customTimeout;

        vm.warp(timeoutAt);

        vm.prank(_contractor);
        _escrow.markVerificationTimedOut(taskId);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_VerificationTimeout_NoOwnerOrAdminControls() public {
        assertEq(_escrow.MIN_VERIFICATION_TIMEOUT(), 60 seconds);
        assertEq(_escrow.MAX_VERIFICATION_TIMEOUT(), 30 days);
        assertEq(_escrow.DEFAULT_VERIFICATION_TIMEOUT(), 7 days);

        uint256 taskId = _createTaskWithTimeout(2 hours);
        assertEq(_taskReviewWindow(taskId), _REVIEW_WINDOW);
        assertEq(_taskVerificationTimeout(taskId), 2 hours);

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);

        vm.prank(_contractor);
        _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        assertEq(_taskReviewWindow(taskId), _REVIEW_WINDOW);
        assertEq(_taskVerificationTimeout(taskId), 2 hours);
    }

    function test_ClaimTo_ContractorClaimsToAlternateRecipient() public {
        address payable payoutRecipient = payable(address(0xDEAD));
        (uint256 taskId,,) = _createFundSubmitApproveTask();
        uint256 recipientBalanceBefore = payoutRecipient.balance;

        vm.expectEmit(true, true, false, true);
        emit TaskClaimed(taskId, payoutRecipient, _TASK_AMOUNT);

        vm.prank(_contractor);
        _escrow.claimTo(taskId, payoutRecipient);

        assertEq(payoutRecipient.balance, recipientBalanceBefore + _TASK_AMOUNT);
        assertEq(_contractor.balance, 1 ether);
    }

    function test_Claim_StillPaysContractor() public {
        (uint256 taskId,,) = _createFundSubmitApproveTask();
        uint256 contractorBalanceBefore = _contractor.balance;

        vm.prank(_contractor);
        _escrow.claim(taskId);

        assertEq(_contractor.balance, contractorBalanceBefore + _TASK_AMOUNT);
    }

    function test_ClaimTo_ZeroRecipientReverts() public {
        (uint256 taskId,,) = _createFundSubmitApproveTask();

        vm.prank(_contractor);
        vm.expectRevert(VigiliaEscrow.InvalidAddress.selector);
        _escrow.claimTo(taskId, payable(address(0)));
    }

    function test_ResubmitWork_FromNeedsReview() public {
        (uint256 taskId, uint256 firstSubmissionId,) = _createFundSubmitAndNeedsReviewTask();

        vm.prank(_contractor);
        (uint256 secondSubmissionId,) = _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));

        (,,,,, uint256 activeSubmissionId, uint256 submissionCount, VigiliaEscrow.TaskState state,,,,) =
            _escrow.tasks(taskId);

        assertEq(secondSubmissionId, 2);
        assertEq(activeSubmissionId, secondSubmissionId);
        assertEq(submissionCount, 2);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(firstSubmissionId, 1);
    }

    function test_ResubmitWork_FromNeedsReviewInvalidatesOldRequest() public {
        (uint256 taskId, uint256 firstSubmissionId,) = _createFundSubmitAndNeedsReviewTask();
        bytes32 firstRequestId = _submissionRequestId(firstSubmissionId);

        vm.prank(_contractor);
        _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));

        vm.prank(address(_verifier));
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.InvalidSubmission.selector, taskId, firstSubmissionId));
        _escrow.recordVerdict(
            taskId, firstSubmissionId, firstRequestId, VigiliaTypes.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function test_ResubmitWork_FromNeedsReviewToCompleteAndClaim() public {
        (uint256 taskId, uint256 firstSubmissionId,) = _createFundSubmitAndNeedsReviewTask();

        vm.prank(_contractor);
        (uint256 secondSubmissionId,) = _escrow.submitWork(taskId, "ipfs://evidence-v2", keccak256("evidence-v2"));
        _recordVerdict(taskId, secondSubmissionId, VigiliaTypes.VerificationVerdict.Complete);

        vm.warp(block.timestamp + _REVIEW_WINDOW);

        vm.prank(_contractor);
        _escrow.claim(taskId);

        (,,,, uint256 fundedAmount,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(fundedAmount, 0);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Claimed));
        assertEq(firstSubmissionId, 1);
    }

    function test_CancelTask_RefundUsesPendingWithdrawalCredit() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.cancelTask(taskId);

        assertEq(_escrow.pendingWithdrawals(_client), _TASK_AMOUNT);
        assertEq(address(_escrow).balance, _TASK_AMOUNT);
    }

    function _createTask() private returns (uint256 taskId) {
        vm.prank(_client);
        taskId = _escrow.createTask(_contractor, _resolver, _TASK_AMOUNT, _REVIEW_WINDOW, _REQUIREMENTS_URI);
    }

    function _createTaskWithPolicy(VigiliaEscrow.ClaimPolicy _claimPolicy) private returns (uint256 taskId) {
        vm.prank(_client);
        taskId = _escrow.createTaskWithPolicy(
            _contractor, _resolver, _TASK_AMOUNT, _REVIEW_WINDOW, _REQUIREMENTS_URI, _claimPolicy
        );
    }

    function _createTaskWithTimeout(uint64 _timeout) private returns (uint256 taskId) {
        vm.prank(_client);
        taskId = _escrow.createTaskWithPolicyAndTimeout(
            _contractor,
            _resolver,
            _TASK_AMOUNT,
            _REVIEW_WINDOW,
            _REQUIREMENTS_URI,
            VigiliaEscrow.ClaimPolicy.ReviewWindowAutoClaim,
            _timeout
        );
    }

    function _createFundSubmitWithTimeout(uint64 _timeout)
        private
        returns (uint256 taskId, uint256 submissionId, bytes32 requestId)
    {
        taskId = _createTaskWithTimeout(_timeout);

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);

        vm.prank(_contractor);
        (submissionId, requestId) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function _createAndFundTask() private returns (uint256 taskId) {
        taskId = _createTask();

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);
    }

    function _createAndFundTaskWithPolicy(VigiliaEscrow.ClaimPolicy _claimPolicy) private returns (uint256 taskId) {
        taskId = _createTaskWithPolicy(_claimPolicy);

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);
    }

    function _createFundAndDisputeTask() private returns (uint256 taskId) {
        taskId = _createAndFundTask();

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://dispute");
    }

    function _createFundAndSubmitTask() private returns (uint256 taskId, uint256 submissionId, bytes32 requestId) {
        taskId = _createAndFundTask();

        vm.prank(_contractor);
        (submissionId, requestId) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function _createFundSubmitAndCompleteTask()
        private
        returns (uint256 taskId, uint256 submissionId, bytes32 requestId)
    {
        (taskId, submissionId, requestId) = _createFundAndSubmitTask();
        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.Complete);
    }

    function _createFundSubmitAndCompleteTaskWithPolicy(VigiliaEscrow.ClaimPolicy _claimPolicy)
        private
        returns (uint256 taskId, uint256 submissionId, bytes32 requestId)
    {
        (taskId, submissionId, requestId) =
            _createFundSubmitAndVerdictWithPolicy(_claimPolicy, VigiliaTypes.VerificationVerdict.Complete);
    }

    function _createFundSubmitAndVerdictWithPolicy(
        VigiliaEscrow.ClaimPolicy _claimPolicy,
        VigiliaTypes.VerificationVerdict _verdict
    ) private returns (uint256 taskId, uint256 submissionId, bytes32 requestId) {
        taskId = _createAndFundTaskWithPolicy(_claimPolicy);

        vm.prank(_contractor);
        (submissionId, requestId) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
        _recordVerdict(taskId, submissionId, _verdict);
    }

    function _createFundSubmitAndNeedsReviewTask()
        private
        returns (uint256 taskId, uint256 submissionId, bytes32 requestId)
    {
        (taskId, submissionId, requestId) = _createFundAndSubmitTask();
        _recordVerdict(taskId, submissionId, VigiliaTypes.VerificationVerdict.NeedsReview);
    }

    function _createFundSubmitAndVerificationFailedTask()
        private
        returns (uint256 taskId, uint256 submissionId, bytes32 requestId)
    {
        (taskId, submissionId, requestId) = _createFundAndSubmitTask();
        _recordVerificationFailure(taskId, submissionId);
    }

    function _createFundSubmitAndVerificationFailedTaskWithPolicy(VigiliaEscrow.ClaimPolicy _claimPolicy)
        private
        returns (uint256 taskId, uint256 submissionId, bytes32 requestId)
    {
        taskId = _createAndFundTaskWithPolicy(_claimPolicy);

        vm.prank(_contractor);
        (submissionId, requestId) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
        _recordVerificationFailure(taskId, submissionId);
    }

    function _createFundSubmitApproveTask() private returns (uint256 taskId, uint256 submissionId, bytes32 requestId) {
        (taskId, submissionId, requestId) = _createFundSubmitAndCompleteTask();

        vm.prank(_client);
        _escrow.approveTask(taskId);
    }

    function _recordVerdict(uint256 _taskId, uint256 _submissionId, VigiliaTypes.VerificationVerdict _verdict) private {
        bytes32 requestId = _submissionRequestId(_submissionId);
        vm.prank(address(_verifier));
        _escrow.recordVerdict(_taskId, _submissionId, requestId, _verdict, _VERIFIER_NOTES_URI);
    }

    function _recordVerificationFailure(uint256 _taskId, uint256 _submissionId) private {
        bytes32 requestId = _submissionRequestId(_submissionId);
        vm.prank(address(_verifier));
        _escrow.recordVerificationFailure(_taskId, _submissionId, requestId, _VERIFIER_NOTES_URI);
    }

    function _assertVerdictDoesNotAutoClaim(
        VigiliaEscrow.ClaimPolicy _claimPolicy,
        VigiliaTypes.VerificationVerdict _verdict,
        VigiliaEscrow.TaskState _expectedState
    ) private {
        (uint256 taskId,,) = _createFundSubmitAndVerdictWithPolicy(_claimPolicy, _verdict);

        vm.warp(block.timestamp + _REVIEW_WINDOW);
        vm.prank(_contractor);
        vm.expectRevert(abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, _expectedState));
        _escrow.claim(taskId);
    }

    function _assertVerificationFailedDoesNotAutoClaim(VigiliaEscrow.ClaimPolicy _claimPolicy) private {
        (uint256 taskId,,) = _createFundSubmitAndVerificationFailedTaskWithPolicy(_claimPolicy);

        vm.warp(block.timestamp + _REVIEW_WINDOW);
        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.VerificationFailed
            )
        );
        _escrow.claim(taskId);
    }

    function _submissionRequestId(uint256 _submissionId) private view returns (bytes32 requestId) {
        (,,,, requestId,,,) = _escrow.submissions(_submissionId);
    }

    function _taskReviewWindow(uint256 _taskId) private view returns (uint64 reviewWindow) {
        (,,,,,,,,,, reviewWindow,) = _escrow.tasks(_taskId);
    }

    function _taskVerificationTimeout(uint256 _taskId) private view returns (uint64 verificationTimeout) {
        (,,,,,,,,,,, verificationTimeout) = _escrow.tasks(_taskId);
    }
}
