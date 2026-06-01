// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "@forge-std/Test.sol";
import { IJsonApiAgent } from "../src/interfaces/IJsonApiAgent.sol";
import { ISomniaAgentRequester } from "../src/interfaces/ISomniaAgentRequester.sol";
import { VigiliaEscrow } from "../src/VigiliaEscrow.sol";
import { VigiliaJsonApiVerifier } from "../src/VigiliaJsonApiVerifier.sol";
import { VigiliaTypes } from "../src/types/VigiliaTypes.sol";
import { MockSomniaAgentRequester } from "./mocks/MockSomniaAgentRequester.sol";

contract VigiliaJsonApiVerifierTest is Test {
    event SomniaVerificationRequested(
        bytes32 indexed vigiliaRequestId,
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 submissionId,
        uint256 agentId,
        uint256 deposit,
        string evidenceURI
    );

    event SomniaVerificationSucceeded(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaTypes.VerificationVerdict verdict,
        string rawResult
    );

    event SomniaVerificationFailed(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        ISomniaAgentRequester.ResponseStatus status,
        string failureNotesURI
    );

    event VerificationRebateCredited(address indexed payer, uint256 indexed platformRequestId, uint256 amount);
    event VerificationRebateWithdrawn(address indexed payer, uint256 amount);
    event EscrowForwardingFailed(
        uint256 indexed platformRequestId, uint256 indexed taskId, uint256 indexed submissionId, bytes returnData
    );
    event StaleSomniaCallbackIgnored(
        uint256 indexed platformRequestId,
        uint256 indexed activePlatformRequestId,
        uint256 indexed taskId,
        uint256 submissionId
    );
    event SomniaRebateReceived(address indexed sender, uint256 amount);

    uint256 private constant _AGENT_ID = 42;
    uint256 private constant _SUBCOMMITTEE_SIZE = 3;
    uint256 private constant _PRICE_PER_VALIDATOR = 0.02 ether;
    uint256 private constant _PLATFORM_DEPOSIT = 0.01 ether;
    uint256 private constant _TASK_AMOUNT = 10 ether;
    uint64 private constant _REVIEW_WINDOW = 3 days;

    string private constant _VERDICT_SELECTOR = "verdict";
    string private constant _REQUIREMENTS_URI = "ipfs://requirements";
    string private constant _EVIDENCE_URI = "https://example.com/vigilia-evidence.json";
    bytes32 private constant _EVIDENCE_HASH = keccak256("evidence");

    MockSomniaAgentRequester private _platform;
    VigiliaJsonApiVerifier private _verifier;
    VigiliaEscrow private _escrow;

    address private _binder = address(0xB10D);
    address private _client = address(0xC11E47);
    address private _contractor = address(0xB011DE2);
    address private _resolver = address(0x4B17E2);
    address private _attacker = address(0xA77A);

    function setUp() public {
        _platform = new MockSomniaAgentRequester(_PLATFORM_DEPOSIT, _PLATFORM_DEPOSIT);
        _verifier = new VigiliaJsonApiVerifier(
            address(_platform), _binder, _AGENT_ID, _SUBCOMMITTEE_SIZE, _PRICE_PER_VALIDATOR, _VERDICT_SELECTOR
        );
        _escrow = new VigiliaEscrow(address(_verifier));

        vm.prank(_binder);
        _verifier.bindEscrow(address(_escrow));

        vm.deal(_client, 100 ether);
        vm.deal(_contractor, 100 ether);
    }

    function test_Constructor_ZeroPlatformReverts() public {
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAddress.selector);
        new VigiliaJsonApiVerifier(
            address(0), _binder, _AGENT_ID, _SUBCOMMITTEE_SIZE, _PRICE_PER_VALIDATOR, _VERDICT_SELECTOR
        );
    }

    function test_Constructor_ZeroBinderReverts() public {
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAddress.selector);
        new VigiliaJsonApiVerifier(
            address(_platform), address(0), _AGENT_ID, _SUBCOMMITTEE_SIZE, _PRICE_PER_VALIDATOR, _VERDICT_SELECTOR
        );
    }

    function test_Constructor_ZeroAgentIdReverts() public {
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAmount.selector);
        new VigiliaJsonApiVerifier(
            address(_platform), _binder, 0, _SUBCOMMITTEE_SIZE, _PRICE_PER_VALIDATOR, _VERDICT_SELECTOR
        );
    }

    function test_Constructor_ZeroSubcommitteeSizeReverts() public {
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAmount.selector);
        new VigiliaJsonApiVerifier(address(_platform), _binder, _AGENT_ID, 0, _PRICE_PER_VALIDATOR, _VERDICT_SELECTOR);
    }

    function test_Constructor_ZeroPricePerValidatorReverts() public {
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAmount.selector);
        new VigiliaJsonApiVerifier(address(_platform), _binder, _AGENT_ID, _SUBCOMMITTEE_SIZE, 0, _VERDICT_SELECTOR);
    }

    function test_Constructor_EmptyVerdictSelectorReverts() public {
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAmount.selector);
        new VigiliaJsonApiVerifier(address(_platform), _binder, _AGENT_ID, _SUBCOMMITTEE_SIZE, _PRICE_PER_VALIDATOR, "");
    }

    function test_BindEscrow_UnauthorizedCallerReverts() public {
        VigiliaJsonApiVerifier verifier = new VigiliaJsonApiVerifier(
            address(_platform), _binder, _AGENT_ID, _SUBCOMMITTEE_SIZE, _PRICE_PER_VALIDATOR, _VERDICT_SELECTOR
        );

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaJsonApiVerifier.Unauthorized.selector, _attacker));
        verifier.bindEscrow(address(_escrow));
    }

    function test_BindEscrow_ZeroEscrowReverts() public {
        VigiliaJsonApiVerifier verifier = new VigiliaJsonApiVerifier(
            address(_platform), _binder, _AGENT_ID, _SUBCOMMITTEE_SIZE, _PRICE_PER_VALIDATOR, _VERDICT_SELECTOR
        );

        vm.prank(_binder);
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAddress.selector);
        verifier.bindEscrow(address(0));
    }

    function test_BindEscrow_AlreadyBoundReverts() public {
        vm.prank(_binder);
        vm.expectRevert(abi.encodeWithSelector(VigiliaJsonApiVerifier.EscrowAlreadyBound.selector, address(_escrow)));
        _verifier.bindEscrow(address(0xE5C));
    }

    function test_MinimumRequestDeposit_ReturnsPlatformReservePlusValidatorBudget() public view {
        assertEq(_verifier.minimumRequestDeposit(), _requiredDeposit());
    }

    function test_SubmitWork_ForwardsVerificationDepositToPlatform() public {
        uint256 taskId = _createAndFundTask();
        uint256 deposit = _requiredDeposit();

        vm.prank(_contractor);
        (uint256 submissionId, bytes32 requestId) =
            _escrow.submitWork{ value: deposit }(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        assertEq(submissionId, 1);
        assertEq(uint256(requestId), 1);
        assertEq(_platform.lastValue(), deposit);
        assertEq(address(_platform).balance, deposit);
        assertEq(address(_escrow).balance, _TASK_AMOUNT);
    }

    function test_SubmitWork_UnderpaymentVerificationDepositReverts() public {
        uint256 taskId = _createAndFundTask();
        uint256 requiredDeposit = _requiredDeposit();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaJsonApiVerifier.InvalidVerificationDeposit.selector, requiredDeposit, requiredDeposit - 1
            )
        );
        _escrow.submitWork{ value: requiredDeposit - 1 }(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Funded));
    }

    function test_SubmitWork_OverpaymentVerificationDepositReverts() public {
        uint256 taskId = _createAndFundTask();
        uint256 requiredDeposit = _requiredDeposit();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaJsonApiVerifier.InvalidVerificationDeposit.selector, requiredDeposit, requiredDeposit + 1
            )
        );
        _escrow.submitWork{ value: requiredDeposit + 1 }(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function test_RequestVerification_UnauthorizedCallerReverts() public {
        vm.deal(_attacker, _requiredDeposit());

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaJsonApiVerifier.Unauthorized.selector, _attacker));
        _verifier.requestVerification{ value: _requiredDeposit() }(1, 1, _attacker, _EVIDENCE_URI);
    }

    function test_RequestVerification_ZeroPayerReverts() public {
        vm.deal(address(_escrow), _requiredDeposit());

        vm.prank(address(_escrow));
        vm.expectRevert(VigiliaJsonApiVerifier.InvalidAddress.selector);
        _verifier.requestVerification{ value: _requiredDeposit() }(1, 1, address(0), _EVIDENCE_URI);
    }

    function test_SubmitWork_ZeroPlatformRequestIdRevertsAndRollsBack() public {
        uint256 taskId = _createAndFundTask();
        _platform.setForceZeroRequestId(true);

        vm.prank(_contractor);
        vm.expectRevert(abi.encodeWithSelector(VigiliaJsonApiVerifier.UnknownRequest.selector, 0));
        _escrow.submitWork{ value: _requiredDeposit() }(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Funded));
        assertEq(_escrow.nextSubmissionId(), 1);
        assertEq(address(_escrow).balance, _TASK_AMOUNT);
    }

    function test_SubmitWork_CreatesExpectedSomniaRequest() public {
        uint256 taskId = _createAndFundTask();
        uint256 deposit = _requiredDeposit();

        bytes memory expectedPayload =
            abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _EVIDENCE_URI, _VERDICT_SELECTOR);

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit SomniaVerificationRequested(bytes32(uint256(1)), 1, taskId, 1, _AGENT_ID, deposit, _EVIDENCE_URI);

        vm.prank(_contractor);
        _escrow.submitWork{ value: deposit }(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        assertEq(_platform.lastAgentId(), _AGENT_ID);
        assertEq(_platform.lastCallbackAddress(), address(_verifier));
        assertEq(_platform.lastCallbackSelector(), _verifier.handleResponse.selector);
        assertEq(keccak256(_platform.lastPayload()), keccak256(expectedPayload));
    }

    function test_HandleResponse_SuccessRecordsComplete() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        _callbackSuccess("Complete");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,, uint64 verifiedAt) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
        assertEq(verifiedAt, block.timestamp);
    }

    function test_HandleResponse_SuccessRecordsNeedsReview() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        _callbackSuccess("NeedsReview");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.NeedsReview));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.NeedsReview));
    }

    function test_HandleResponse_SuccessRecordsIncomplete() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        _callbackSuccess("Incomplete");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Incomplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Incomplete));
    }

    function test_HandleResponse_SuccessAcceptsUppercaseComplete() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        _callbackSuccess("COMPLETE");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
    }

    function test_HandleResponse_SuccessAcceptsUppercaseNeedsReview() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        _callbackSuccess("NEEDS_REVIEW");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.NeedsReview));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.NeedsReview));
    }

    function test_HandleResponse_SuccessAcceptsUppercaseIncomplete() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        _callbackSuccess("INCOMPLETE");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Incomplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Incomplete));
    }

    function test_HandleResponse_UsesFirstSuccessfulNonEmptyValidatorResult() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](3);
        responses[0] = ISomniaAgentRequester.Response({
            validator: address(0xAA),
            result: abi.encode("Incomplete"),
            status: ISomniaAgentRequester.ResponseStatus.Failed,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });
        responses[1] = ISomniaAgentRequester.Response({
            validator: address(0xBB),
            result: "",
            status: ISomniaAgentRequester.ResponseStatus.Success,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });
        responses[2] = ISomniaAgentRequester.Response({
            validator: address(0xCC),
            result: abi.encode("Complete"),
            status: ISomniaAgentRequester.ResponseStatus.Success,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });
        ISomniaAgentRequester.Request memory details;

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
    }

    function test_HandleResponse_NoSuccessfulResultFailsClosed() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](1);
        responses[0] = ISomniaAgentRequester.Response({
            validator: address(0xAA),
            result: abi.encode("Complete"),
            status: ISomniaAgentRequester.ResponseStatus.Failed,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });
        ISomniaAgentRequester.Request memory details;

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_HandleResponse_UnknownVerdictFailsClosed() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = _responses("Unknown");
        ISomniaAgentRequester.Request memory details;

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_HandleResponse_MalformedResultFailsClosed() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](1);
        responses[0] = ISomniaAgentRequester.Response({
            validator: address(0xAA),
            result: hex"1234",
            status: ISomniaAgentRequester.ResponseStatus.Success,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });
        ISomniaAgentRequester.Request memory details;

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_HandleResponse_NonPlatformCallerReverts() public {
        _submitWork();
        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaJsonApiVerifier.Unauthorized.selector, _attacker));
        _verifier.handleResponse(1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_HandleResponse_UnknownRequestReverts() public {
        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.expectRevert(abi.encodeWithSelector(VigiliaJsonApiVerifier.UnknownRequest.selector, 99));
        _platform.callback(address(_verifier), 99, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_HandleResponse_DuplicateCallbackReverts() public {
        _submitWork();
        _callbackSuccess("Complete");

        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.expectRevert(abi.encodeWithSelector(VigiliaJsonApiVerifier.RequestAlreadyFulfilled.selector, 1));
        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_HandleResponse_PendingStatusRevertsAndDoesNotFulfillRequest() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaJsonApiVerifier.UnsupportedResponseStatus.selector, ISomniaAgentRequester.ResponseStatus.Pending
            )
        );
        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Pending, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, bool fulfilled) = _verifier.requests(1);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertFalse(fulfilled);
    }

    function test_DecodeAgentString_DirectCallerReverts() public {
        vm.expectRevert(VigiliaJsonApiVerifier.DecodeOnlySelf.selector);
        _verifier.decodeAgentString(abi.encode("Complete"));
    }

    function test_HandleResponse_FailedStatusDoesNotMarkComplete() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit SomniaVerificationFailed(
            1, taskId, 1, ISomniaAgentRequester.ResponseStatus.Failed, "somnia-agent-request:1"
        );

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Failed, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, bool fulfilled) = _verifier.requests(1);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertTrue(fulfilled);
    }

    function test_HandleResponse_TimedOutStatusDoesNotMarkComplete() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.TimedOut, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, bool fulfilled) = _verifier.requests(1);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertTrue(fulfilled);
    }

    function test_HandleResponse_WhenEscrowRejectsFailureEmitsForwardingFailure() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://dispute-before-callback");

        bytes memory returnData =
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Disputed);

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit EscrowForwardingFailed(1, taskId, 1, returnData);

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Failed, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, bool fulfilled) = _verifier.requests(1);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Disputed));
        assertTrue(fulfilled);
    }

    function test_HandleResponse_WhenEscrowRejectsVerdictEmitsForwardingFailure() public {
        (uint256 taskId,,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.prank(_client);
        _escrow.raiseDispute(taskId, "ipfs://dispute-before-callback");

        bytes memory returnData =
            abi.encodeWithSelector(VigiliaEscrow.InvalidState.selector, taskId, VigiliaEscrow.TaskState.Disputed);

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit EscrowForwardingFailed(1, taskId, 1, returnData);

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, bool fulfilled) = _verifier.requests(1);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Disputed));
        assertTrue(fulfilled);
    }

    function test_HandleResponse_LateSuccessForOldRequestAfterRetryIsIgnored() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _forceEscrowVerificationFailed(taskId, submissionId, bytes32(uint256(1)));

        vm.prank(_contractor);
        bytes32 retryRequestId = _escrow.retryVerification{ value: _requiredDeposit() }(taskId);
        assertEq(uint256(retryRequestId), 2);

        ISomniaAgentRequester.Response[] memory oldResponses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit StaleSomniaCallbackIgnored(1, 2, taskId, submissionId);

        _platform.callback(address(_verifier), 1, oldResponses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        (,,,,, bool oldFulfilled) = _verifier.requests(1);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertTrue(oldFulfilled);

        ISomniaAgentRequester.Response[] memory newResponses = _responses("Complete");
        _platform.callback(address(_verifier), 2, newResponses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, state,,,,) = _escrow.tasks(taskId);
        (,,,,, verdict,,) = _escrow.submissions(submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
    }

    function test_HandleResponse_LateFailureForOldRequestAfterRetryIsIgnored() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _forceEscrowVerificationFailed(taskId, submissionId, bytes32(uint256(1)));

        vm.prank(_contractor);
        _escrow.retryVerification{ value: _requiredDeposit() }(taskId);

        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit StaleSomniaCallbackIgnored(1, 2, taskId, submissionId);

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Failed, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
    }

    function test_HandleResponse_StaleUnfulfilledCallbackCreditsRebateWithoutChangingTask() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _forceEscrowVerificationFailed(taskId, submissionId, bytes32(uint256(1)));

        vm.prank(_contractor);
        _escrow.retryVerification{ value: _requiredDeposit() }(taskId);

        uint256 rebate = 0.008 ether;
        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details = _details(rebate);
        vm.deal(address(_platform), rebate);

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit VerificationRebateCredited(_contractor, 1, rebate);
        vm.expectEmit(true, true, true, true, address(_verifier));
        emit StaleSomniaCallbackIgnored(1, 2, taskId, submissionId);

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        (,,,,, bool oldFulfilled) = _verifier.requests(1);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertTrue(oldFulfilled);
        assertEq(_verifier.pendingVerificationRebates(_contractor), rebate);
    }

    function test_HandleResponse_StaleAlreadyFulfilledCallbackDoesNotDoubleCreditRebate() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Failed, details);

        vm.prank(_contractor);
        _escrow.retryVerification{ value: _requiredDeposit() }(taskId);

        uint256 rebate = 0.008 ether;
        details = _details(rebate);
        vm.deal(address(_platform), rebate);

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit StaleSomniaCallbackIgnored(1, 2, taskId, submissionId);

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Failed, details);

        assertEq(_verifier.pendingVerificationRebates(_contractor), 0);
        assertEq(_verifier.totalPendingVerificationRebates(), 0);
    }

    function test_RequestVerification_StoresPayer() public {
        _submitWork();

        (,, address payer,, bool exists, bool fulfilled) = _verifier.requests(1);

        assertEq(payer, _contractor);
        assertTrue(exists);
        assertFalse(fulfilled);
    }

    function test_HandleResponse_RemainingBudgetCreditsPayerRebate() public {
        _submitWork();
        uint256 rebate = 0.012 ether;
        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details = _details(rebate);
        vm.deal(address(_platform), rebate);

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit VerificationRebateCredited(_contractor, 1, rebate);

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        assertEq(_verifier.pendingVerificationRebates(_contractor), rebate);
        assertEq(_verifier.totalPendingVerificationRebates(), rebate);
        assertEq(address(_verifier).balance, rebate);
        assertEq(address(_escrow).balance, _TASK_AMOUNT);
    }

    function test_WithdrawVerificationRebate_TransfersCreditAndClearsAccounting() public {
        _submitWork();
        uint256 rebate = 0.012 ether;
        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details = _details(rebate);
        vm.deal(address(_platform), rebate);
        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        uint256 contractorBalanceBefore = _contractor.balance;

        vm.expectEmit(true, false, false, true, address(_verifier));
        emit VerificationRebateWithdrawn(_contractor, rebate);

        vm.prank(_contractor);
        _verifier.withdrawVerificationRebate();

        assertEq(_verifier.pendingVerificationRebates(_contractor), 0);
        assertEq(_verifier.totalPendingVerificationRebates(), 0);
        assertEq(_contractor.balance, contractorBalanceBefore + rebate);
    }

    function test_WithdrawVerificationRebate_NoPendingCreditReverts() public {
        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaJsonApiVerifier.NoPendingVerificationRebate.selector, _contractor)
        );
        _verifier.withdrawVerificationRebate();
    }

    function test_Receive_AcceptsPlatformRebate() public {
        vm.deal(address(_platform), 1 ether);

        vm.expectEmit(true, false, false, true, address(_verifier));
        emit SomniaRebateReceived(address(_platform), 1 ether);

        vm.prank(address(_platform));
        (bool success,) = address(_verifier).call{ value: 1 ether }("");

        assertTrue(success);
        assertEq(address(_verifier).balance, 1 ether);
    }

    function test_SubmitWork_EscrowFundsNotMixedWithVerificationFee() public {
        uint256 taskId = _createAndFundTask();
        uint256 escrowBefore = address(_escrow).balance;
        uint256 platformBefore = address(_platform).balance;
        uint256 deposit = _requiredDeposit();

        vm.prank(_contractor);
        _escrow.submitWork{ value: deposit }(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        assertEq(address(_escrow).balance, escrowBefore);
        assertEq(address(_platform).balance, platformBefore + deposit);
        assertEq(_verifier.totalPendingVerificationRebates(), 0);
        assertEq(_contractor.balance, 100 ether - deposit);
    }

    function _createAndFundTask() private returns (uint256 taskId) {
        vm.prank(_client);
        taskId = _escrow.createTask(_contractor, _resolver, _TASK_AMOUNT, _REVIEW_WINDOW, _REQUIREMENTS_URI);

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);
    }

    function _submitWork() private returns (uint256 taskId, uint256 submissionId, bytes32 requestId) {
        taskId = _createAndFundTask();

        vm.prank(_contractor);
        (submissionId, requestId) =
            _escrow.submitWork{ value: _requiredDeposit() }(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function _callbackSuccess(string memory _result) private {
        ISomniaAgentRequester.Response[] memory responses = _responses(_result);
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit SomniaVerificationSucceeded(1, 1, 1, _expectedVerdict(_result), _result);

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function _forceEscrowVerificationFailed(uint256 _taskId, uint256 _submissionId, bytes32 _requestId) private {
        vm.prank(address(_verifier));
        _escrow.recordVerificationFailure(_taskId, _submissionId, _requestId, "somnia-agent-request:1");
    }

    function _responses(string memory _result)
        private
        view
        returns (ISomniaAgentRequester.Response[] memory responses)
    {
        responses = new ISomniaAgentRequester.Response[](1);
        responses[0] = ISomniaAgentRequester.Response({
            validator: address(0xAA),
            result: abi.encode(_result),
            status: ISomniaAgentRequester.ResponseStatus.Success,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });
    }

    function _details(uint256 _remainingBudget) private pure returns (ISomniaAgentRequester.Request memory details) {
        details.remainingBudget = _remainingBudget;
    }

    function _requiredDeposit() private pure returns (uint256 deposit) {
        deposit = _PLATFORM_DEPOSIT + (_SUBCOMMITTEE_SIZE * _PRICE_PER_VALIDATOR);
    }

    function _expectedVerdict(string memory _result) private pure returns (VigiliaTypes.VerificationVerdict verdict) {
        bytes32 resultHash = keccak256(bytes(_result));
        if (resultHash == keccak256("Complete") || resultHash == keccak256("COMPLETE")) {
            return VigiliaTypes.VerificationVerdict.Complete;
        }
        if (resultHash == keccak256("NeedsReview") || resultHash == keccak256("NEEDS_REVIEW")) {
            return VigiliaTypes.VerificationVerdict.NeedsReview;
        }
        return VigiliaTypes.VerificationVerdict.Incomplete;
    }
}
