// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "@forge-std/Test.sol";
import { IJsonApiAgent } from "../src/interfaces/IJsonApiAgent.sol";
import { ILlmInferenceAgent } from "../src/interfaces/ILlmInferenceAgent.sol";
import { ILlmParseWebsiteAgent } from "../src/interfaces/ILlmParseWebsiteAgent.sol";
import { ISomniaAgentRequester } from "../src/interfaces/ISomniaAgentRequester.sol";
import { VigiliaAgentTypes } from "../src/types/VigiliaAgentTypes.sol";
import { VigiliaEscrow } from "../src/VigiliaEscrow.sol";
import { VigiliaMultiAgentVerifier } from "../src/VigiliaMultiAgentVerifier.sol";
import { VigiliaTypes } from "../src/types/VigiliaTypes.sol";
import { MockSomniaAgentRequester } from "./mocks/MockSomniaAgentRequester.sol";

contract VigiliaMultiAgentVerifierTest is Test {
    event CanaryRequested(
        uint256 indexed platformRequestId,
        VigiliaAgentTypes.AgentKind indexed kind,
        address indexed requester,
        uint256 agentId,
        uint256 deposit,
        bytes32 inputHash
    );
    event CanarySucceeded(
        uint256 indexed platformRequestId,
        VigiliaAgentTypes.AgentKind indexed kind,
        VigiliaTypes.VerificationVerdict verdict,
        string rawResult
    );
    event CanaryFailed(
        uint256 indexed platformRequestId,
        VigiliaAgentTypes.AgentKind indexed kind,
        ISomniaAgentRequester.ResponseStatus status,
        string failureNotesURI
    );
    event MultiAgentVerificationSucceeded(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaAgentTypes.AgentKind kind,
        VigiliaAgentTypes.SettlementWorkflow workflow,
        VigiliaTypes.VerificationVerdict verdict,
        string rawResult
    );
    event MultiAgentVerificationFailed(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaAgentTypes.AgentKind kind,
        VigiliaAgentTypes.SettlementWorkflow workflow,
        ISomniaAgentRequester.ResponseStatus status,
        string failureNotesURI
    );
    event JsonFactsReceived(
        uint256 indexed platformRequestId, uint256 indexed taskId, uint256 indexed submissionId, string facts
    );
    event LlmVerdictRequested(
        uint256 indexed parentRequestId,
        uint256 indexed llmRequestId,
        uint256 indexed taskId,
        uint256 submissionId,
        uint256 deposit
    );
    event LlmVerdictContinuationRequired(
        uint256 indexed parentRequestId, uint256 indexed taskId, uint256 indexed submissionId
    );
    event StaleSomniaCallbackIgnored(
        uint256 indexed platformRequestId,
        uint256 indexed activePlatformRequestId,
        uint256 indexed taskId,
        uint256 submissionId
    );
    event VerificationBudgetRefundCredited(uint256 indexed requestId, address indexed requester, uint256 amount);
    event VerificationBudgetRefundWithdrawn(address indexed recipient, uint256 amount);

    uint256 private constant _JSON_AGENT_ID = 42;
    uint256 private constant _LLM_INFERENCE_AGENT_ID = 43;
    uint256 private constant _LLM_PARSE_WEBSITE_AGENT_ID = 44;
    uint256 private constant _SUBCOMMITTEE_SIZE = 3;
    uint256 private constant _JSON_PRICE_PER_VALIDATOR = 0.02 ether;
    uint256 private constant _LLM_INFERENCE_PRICE_PER_VALIDATOR = 0.07 ether;
    uint256 private constant _LLM_PARSE_PRICE_PER_VALIDATOR = 0.1 ether;
    uint256 private constant _PLATFORM_DEPOSIT = 0.01 ether;
    uint256 private constant _TASK_AMOUNT = 10 ether;
    uint64 private constant _REVIEW_WINDOW = 3 days;

    string private constant _JSON_SELECTOR = "verdict";
    string private constant _FACTS_SELECTOR = "facts";
    string private constant _JSON_URL = "https://example.com/complete.json";
    string private constant _FACTS = "repo_exists=true; readme_setup=true; tests_passed=true";
    string private constant _LLM_PROMPT = "The milestone is complete. Return exactly one allowed value.";
    string private constant _LLM_SYSTEM = "You are a strict Vigilia verifier. Return only one allowed value.";
    string private constant _WORKFLOW_LLM_SYSTEM =
        "You are a strict Vigilia work verifier. Return exactly one allowed value. Do not explain.";
    string private constant _WEBSITE_URL = "https://example.com/";
    string private constant _WEBSITE_INSTRUCTION = "Return Complete, NeedsReview, or Incomplete.";
    string private constant _WEBSITE_KEY = "verdict";
    string private constant _WEBSITE_DESCRIPTION = "Vigilia milestone verification verdict. Return one bounded value.";
    string private constant _REQUIREMENTS_URI = "ipfs://requirements";
    bytes32 private constant _EVIDENCE_HASH = keccak256("evidence");

    MockSomniaAgentRequester private _platform;
    VigiliaMultiAgentVerifier private _verifier;
    VigiliaEscrow private _escrow;

    address private _binder = address(0xB10D);
    address private _client = address(0xC11E47);
    address private _contractor = address(0xB011DE2);
    address private _resolver = address(0x4B17E2);
    address private _requester = address(0xCA11A2);
    address private _attacker = address(0xA77A);

    function setUp() public {
        _platform = new MockSomniaAgentRequester(_PLATFORM_DEPOSIT, _PLATFORM_DEPOSIT);
        _verifier = _newVerifier(true, true);
        _escrow = new VigiliaEscrow(address(_verifier));

        vm.prank(_binder);
        _verifier.bindEscrow(address(_escrow));

        vm.deal(_client, 100 ether);
        vm.deal(_contractor, 100 ether);
        vm.deal(_requester, 100 ether);
    }

    function test_RequestJsonApiCanary_EncodesFetchStringPayload() public {
        uint256 deposit = _jsonDeposit();

        vm.prank(_requester);
        vm.expectEmit(true, true, true, true, address(_verifier));
        emit CanaryRequested(
            1,
            VigiliaAgentTypes.AgentKind.JsonApi,
            _requester,
            _JSON_AGENT_ID,
            deposit,
            keccak256(abi.encode(_JSON_URL, _JSON_SELECTOR))
        );
        uint256 requestId = _verifier.requestJsonApiCanary{ value: deposit }(_JSON_URL, _JSON_SELECTOR);

        assertEq(requestId, 1);
        assertEq(_platform.lastAgentId(), _JSON_AGENT_ID);
        assertEq(_platform.lastCallbackAddress(), address(_verifier));
        assertEq(_platform.lastCallbackSelector(), _verifier.handleResponse.selector);
        assertEq(
            _platform.lastPayload(),
            abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _JSON_URL, _JSON_SELECTOR)
        );
        assertEq(_platform.lastValue(), deposit);
    }

    function test_RequestLlmInferenceCanary_EncodesIntendedPayload() public {
        uint256 deposit = _llmInferenceDeposit();
        string[] memory allowedValues = _allowedValues();

        vm.prank(_requester);
        uint256 requestId = _verifier.requestLlmInferenceCanary{ value: deposit }(_LLM_PROMPT, _LLM_SYSTEM, false);

        assertEq(requestId, 1);
        assertEq(_platform.lastAgentId(), _LLM_INFERENCE_AGENT_ID);
        assertEq(
            _platform.lastPayload(),
            abi.encodeWithSelector(
                ILlmInferenceAgent.inferString.selector, _LLM_PROMPT, _LLM_SYSTEM, false, allowedValues
            )
        );
        assertEq(_platform.lastValue(), deposit);
    }

    function test_RequestLlmParseWebsiteCanary_EncodesIntendedPayload() public {
        uint256 deposit = _llmParseWebsiteDeposit();
        string[] memory allowedValues = _allowedValues();

        vm.prank(_requester);
        uint256 requestId = _verifier.requestLlmParseWebsiteCanary{ value: deposit }(_WEBSITE_URL, _WEBSITE_INSTRUCTION);

        assertEq(requestId, 1);
        assertEq(_platform.lastAgentId(), _LLM_PARSE_WEBSITE_AGENT_ID);
        assertEq(
            _platform.lastPayload(),
            abi.encodeWithSelector(
                ILlmParseWebsiteAgent.ExtractString.selector,
                _WEBSITE_KEY,
                _WEBSITE_DESCRIPTION,
                allowedValues,
                _WEBSITE_INSTRUCTION,
                _WEBSITE_URL,
                false,
                uint8(1),
                uint8(70)
            )
        );
        assertEq(_platform.lastValue(), deposit);
    }

    function test_MinimumRequestDeposit_UnknownAgentKindReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaMultiAgentVerifier.UnknownAgentKind.selector, VigiliaAgentTypes.AgentKind.Unknown
            )
        );
        _verifier.minimumRequestDeposit(VigiliaAgentTypes.AgentKind.Unknown);
    }

    function test_RequestLlmInferenceCanary_DisabledAgentKindReverts() public {
        VigiliaMultiAgentVerifier verifier = _newVerifier(false, false);

        vm.prank(_requester);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaMultiAgentVerifier.UnknownAgentKind.selector, VigiliaAgentTypes.AgentKind.LlmInference
            )
        );
        verifier.requestLlmInferenceCanary{ value: _llmInferenceDeposit() }(_LLM_PROMPT, _LLM_SYSTEM, false);
    }

    function test_RequestJsonApiCanary_InsufficientDepositReverts() public {
        uint256 requiredDeposit = _jsonDeposit();

        vm.prank(_requester);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaMultiAgentVerifier.InvalidVerificationDeposit.selector, requiredDeposit, requiredDeposit - 1
            )
        );
        _verifier.requestJsonApiCanary{ value: requiredDeposit - 1 }(_JSON_URL, _JSON_SELECTOR);
    }

    function test_RequestJsonApiCanary_ExactDepositAccepted() public {
        vm.prank(_requester);
        uint256 requestId = _verifier.requestJsonApiCanary{ value: _jsonDeposit() }(_JSON_URL, _JSON_SELECTOR);

        assertEq(requestId, 1);
        assertEq(address(_platform).balance, _jsonDeposit());
    }

    function test_RequestVerification_JsonFactsToLlmVerdictRequiresTotalDeposit() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaMultiAgentVerifier.InvalidVerificationDeposit.selector,
                _workflowDeposit(),
                _workflowDeposit() - 1
            )
        );
        _escrow.submitWork{ value: _workflowDeposit() - 1 }(taskId, _JSON_URL, _EVIDENCE_HASH);
    }

    function test_RequestVerification_JsonFactsToLlmVerdictRejectsSingleAgentDeposit() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaMultiAgentVerifier.InvalidVerificationDeposit.selector, _workflowDeposit(), _jsonDeposit()
            )
        );
        _escrow.submitWork{ value: _jsonDeposit() }(taskId, _JSON_URL, _EVIDENCE_HASH);
    }

    function test_RequestVerification_JsonFactsToLlmVerdictRejectsOverpayment() public {
        uint256 taskId = _createAndFundTask();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaMultiAgentVerifier.InvalidVerificationDeposit.selector,
                _workflowDeposit(),
                _workflowDeposit() + 1
            )
        );
        _escrow.submitWork{ value: _workflowDeposit() + 1 }(taskId, _JSON_URL, _EVIDENCE_HASH);
    }

    function test_MinimumRequestDepositForWorkflow_SumsJsonAndLlmDeposits() public view {
        assertEq(
            _verifier.minimumRequestDepositForWorkflow(VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict),
            _jsonDeposit() + _llmInferenceDeposit()
        );
    }

    function test_SubmitWork_JsonFactsRequestUsesFactsSelectorAndKeepsLlmBudget() public {
        _submitWork();

        assertEq(_platform.lastAgentId(), _JSON_AGENT_ID);
        assertEq(
            _platform.lastPayload(),
            abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _JSON_URL, _FACTS_SELECTOR)
        );
        assertEq(_platform.lastValue(), _jsonDeposit());
        (,,,,,,,,,, uint256 prepaidBudget,,,,,) = _verifier.requests(1);
        assertEq(prepaidBudget, _llmInferenceDeposit());
    }

    function test_HandleResponse_JsonFactsStartsLlmWithFactsAndRequirements() public {
        _submitWork();

        _callback(1, _FACTS);

        string[] memory allowedValues = _allowedValues();
        string memory expectedPrompt = string.concat(
            "Task requirements:\n",
            _REQUIREMENTS_URI,
            "\n\nEvidence facts:\n",
            _FACTS,
            "\n\nClassify whether the submitted work satisfies the requirements.\nReturn exactly one allowed value."
        );
        assertEq(_platform.lastAgentId(), _LLM_INFERENCE_AGENT_ID);
        assertEq(
            _platform.lastPayload(),
            abi.encodeWithSelector(
                ILlmInferenceAgent.inferString.selector, expectedPrompt, _WORKFLOW_LLM_SYSTEM, false, allowedValues
            )
        );
        assertEq(_platform.lastValue(), _llmInferenceDeposit());
        (,,,,,,, string memory evidenceURI, string memory requirementsURI, string memory facts,,,,,,) =
            _verifier.requests(2);
        assertEq(evidenceURI, _JSON_URL);
        assertEq(requirementsURI, _REQUIREMENTS_URI);
        assertEq(facts, _FACTS);
    }

    function test_HandleResponse_JsonFactsCreateRequestFailureAllowsContinuation() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _platform.setForceZeroRequestId(true);

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit JsonFactsReceived(1, taskId, submissionId, _FACTS);
        vm.expectEmit(true, true, true, true, address(_verifier));
        emit LlmVerdictContinuationRequired(1, taskId, submissionId);
        _callback(1, _FACTS);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,,,,,,, uint256 prepaidBudget,,,,, bool fulfilled) = _verifier.requests(1);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(prepaidBudget, _llmInferenceDeposit());
        assertTrue(fulfilled);

        _platform.setForceZeroRequestId(false);
        uint256 llmRequestId = _verifier.continueLlmVerification(1);
        assertEq(llmRequestId, 2);

        _callback(2, "Complete");

        (,,,,,,, state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
    }

    function test_HandleResponse_NonPlatformCallerReverts() public {
        _requestJsonCanary();

        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaMultiAgentVerifier.Unauthorized.selector, _attacker));
        _verifier.handleResponse(1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_HandleResponse_UnknownRequestReverts() public {
        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.expectRevert(abi.encodeWithSelector(VigiliaMultiAgentVerifier.UnknownRequest.selector, 99));
        _platform.callback(address(_verifier), 99, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_HandleResponse_DuplicateCallbackReverts() public {
        _requestJsonCanary();
        _callback(1, "Complete");

        ISomniaAgentRequester.Response[] memory responses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.expectRevert(abi.encodeWithSelector(VigiliaMultiAgentVerifier.RequestAlreadyFulfilled.selector, 1));
        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_HandleResponse_CanarySuccessEmitsBoundedResult() public {
        _requestJsonCanary();

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit CanarySucceeded(
            1, VigiliaAgentTypes.AgentKind.JsonApi, VigiliaTypes.VerificationVerdict.Complete, "Complete"
        );

        _callback(1, "Complete");
    }

    function test_HandleResponse_CanaryUnknownResultFailsClosed() public {
        _requestJsonCanary();

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit CanaryFailed(
            1,
            VigiliaAgentTypes.AgentKind.JsonApi,
            ISomniaAgentRequester.ResponseStatus.Success,
            "somnia-agent-request:1:unknown-verdict"
        );

        _callback(1, "Maybe");
    }

    function test_HandleResponse_CanaryMalformedResultFailsClosed() public {
        _requestJsonCanary();

        ISomniaAgentRequester.Response[] memory responses = _malformedResponses();
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit CanaryFailed(
            1,
            VigiliaAgentTypes.AgentKind.JsonApi,
            ISomniaAgentRequester.ResponseStatus.Success,
            "somnia-agent-request:1:malformed"
        );

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_HandleResponse_CanaryFailedStatusEmitsFailure() public {
        _requestJsonCanary();

        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit CanaryFailed(
            1,
            VigiliaAgentTypes.AgentKind.JsonApi,
            ISomniaAgentRequester.ResponseStatus.Failed,
            "somnia-agent-request:1"
        );

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Failed, details);
    }

    function test_HandleResponse_CanaryTimedOutStatusEmitsFailure() public {
        _requestJsonCanary();

        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit CanaryFailed(
            1,
            VigiliaAgentTypes.AgentKind.JsonApi,
            ISomniaAgentRequester.ResponseStatus.TimedOut,
            "somnia-agent-request:1"
        );

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.TimedOut, details);
    }

    function test_HandleResponse_ParseKindMalformedBytesFailsClosed() public {
        vm.prank(_requester);
        _verifier.requestLlmParseWebsiteCanary{ value: _llmParseWebsiteDeposit() }(_WEBSITE_URL, _WEBSITE_INSTRUCTION);

        ISomniaAgentRequester.Response[] memory responses = _malformedResponses();
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit CanaryFailed(
            1,
            VigiliaAgentTypes.AgentKind.LlmParseWebsite,
            ISomniaAgentRequester.ResponseStatus.Success,
            "somnia-agent-request:1:malformed"
        );

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);
    }

    function test_SubmitWork_EscrowPathRecordsBoundedVerdict() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit JsonFactsReceived(1, taskId, submissionId, _FACTS);
        vm.expectEmit(true, true, true, true, address(_verifier));
        emit LlmVerdictRequested(1, 2, taskId, submissionId, _llmInferenceDeposit());
        _callback(1, _FACTS);

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit MultiAgentVerificationSucceeded(
            2,
            taskId,
            submissionId,
            VigiliaAgentTypes.AgentKind.LlmInference,
            VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict,
            VigiliaTypes.VerificationVerdict.Complete,
            "Complete"
        );

        _callback(2, "Complete");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
    }

    function test_HandleResponse_LlmNeedsReviewRecordsNeedsReview() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _callback(1, _FACTS);
        _callback(2, "NeedsReview");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.NeedsReview));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.NeedsReview));
    }

    function test_HandleResponse_LlmIncompleteRecordsIncomplete() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _callback(1, _FACTS);
        _callback(2, "Incomplete");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Incomplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Incomplete));
    }

    function test_HandleResponse_LlmWhitespaceTrimmedCompleteRecordsComplete() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _callback(1, _FACTS);
        _callback(2, " \nComplete\r\n");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
    }

    function test_HandleResponse_EscrowUnknownResultRecordsVerificationFailed() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _callback(1, _FACTS);

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit MultiAgentVerificationFailed(
            2,
            taskId,
            submissionId,
            VigiliaAgentTypes.AgentKind.LlmInference,
            VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict,
            ISomniaAgentRequester.ResponseStatus.Success,
            "somnia-agent-request:2:unknown-verdict"
        );

        _callback(2, "Maybe");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
    }

    function test_HandleResponse_JsonFailedStatusRecordsVerificationFailed() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();

        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit MultiAgentVerificationFailed(
            1,
            taskId,
            submissionId,
            VigiliaAgentTypes.AgentKind.JsonApi,
            VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict,
            ISomniaAgentRequester.ResponseStatus.Failed,
            "somnia-agent-request:1"
        );

        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Failed, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertEq(_verifier.pendingVerificationRefunds(_contractor), _llmInferenceDeposit());
        (,,,,,,,,,, uint256 prepaidBudget,,,,,) = _verifier.requests(1);
        assertEq(prepaidBudget, 0);
    }

    function test_HandleResponse_JsonTimedOutStatusRecordsVerificationFailed() public {
        (uint256 taskId,,) = _submitWork();

        _statusCallback(1, ISomniaAgentRequester.ResponseStatus.TimedOut);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_HandleResponse_JsonEmptyFactsRecordsVerificationFailed() public {
        (uint256 taskId,,) = _submitWork();

        _callback(1, "");

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,,,,,,, uint256 prepaidBudget,,,,,) = _verifier.requests(1);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertEq(prepaidBudget, 0);
        assertEq(_verifier.pendingVerificationRefunds(_contractor), _llmInferenceDeposit());
        assertEq(_platform.nextRequestId(), 2);
    }

    function test_HandleResponse_LlmFailedStatusRecordsVerificationFailed() public {
        (uint256 taskId,,) = _submitWork();
        _callback(1, _FACTS);

        _statusCallback(2, ISomniaAgentRequester.ResponseStatus.Failed);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_HandleResponse_LlmTimedOutStatusRecordsVerificationFailed() public {
        (uint256 taskId,,) = _submitWork();
        _callback(1, _FACTS);

        _statusCallback(2, ISomniaAgentRequester.ResponseStatus.TimedOut);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_HandleResponse_LlmMalformedResultRecordsVerificationFailed() public {
        (uint256 taskId,,) = _submitWork();
        _callback(1, _FACTS);

        ISomniaAgentRequester.Response[] memory responses = _malformedResponses();
        ISomniaAgentRequester.Request memory details;
        _platform.callback(address(_verifier), 2, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
    }

    function test_HandleResponse_JsonMalformedResultCreditsUnusedLlmBudget() public {
        (uint256 taskId,,) = _submitWork();

        vm.expectEmit(true, true, false, true, address(_verifier));
        emit VerificationBudgetRefundCredited(1, _contractor, _llmInferenceDeposit());

        ISomniaAgentRequester.Response[] memory responses = _malformedResponses();
        ISomniaAgentRequester.Request memory details;
        _platform.callback(address(_verifier), 1, responses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertEq(_verifier.pendingVerificationRefunds(_contractor), _llmInferenceDeposit());
        (,,,,,,,,,, uint256 prepaidBudget,,,,,) = _verifier.requests(1);
        assertEq(prepaidBudget, 0);
    }

    function test_HandleResponse_LlmStageFailureDoesNotCreditUnusedLlmBudget() public {
        (uint256 taskId,,) = _submitWork();
        _callback(1, _FACTS);

        _statusCallback(2, ISomniaAgentRequester.ResponseStatus.Failed);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerificationFailed));
        assertEq(_verifier.pendingVerificationRefunds(_contractor), 0);
        (,,,,,,,,,, uint256 prepaidBudget,,,,,) = _verifier.requests(1);
        assertEq(prepaidBudget, 0);
    }

    function test_WithdrawVerificationRefund_TransfersCreditAndClearsAccounting() public {
        _submitWork();
        _statusCallback(1, ISomniaAgentRequester.ResponseStatus.Failed);

        address payable recipient = payable(address(0xDEAD));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.expectEmit(true, false, false, true, address(_verifier));
        emit VerificationBudgetRefundWithdrawn(recipient, _llmInferenceDeposit());

        vm.prank(_contractor);
        _verifier.withdrawVerificationRefundTo(recipient);

        assertEq(_verifier.pendingVerificationRefunds(_contractor), 0);
        assertEq(recipient.balance, recipientBalanceBefore + _llmInferenceDeposit());
    }

    function test_WithdrawVerificationRefund_ZeroRecipientReverts() public {
        _submitWork();
        _statusCallback(1, ISomniaAgentRequester.ResponseStatus.Failed);

        vm.prank(_contractor);
        vm.expectRevert(VigiliaMultiAgentVerifier.InvalidAddress.selector);
        _verifier.withdrawVerificationRefundTo(payable(address(0)));
    }

    function test_WithdrawVerificationRefund_NoPendingCreditReverts() public {
        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaMultiAgentVerifier.NoPendingVerificationRefund.selector, _contractor)
        );
        _verifier.withdrawVerificationRefund();
    }

    function test_WithdrawVerificationRefund_CannotWithdrawTwice() public {
        _submitWork();
        _statusCallback(1, ISomniaAgentRequester.ResponseStatus.Failed);

        vm.prank(_contractor);
        _verifier.withdrawVerificationRefund();

        vm.prank(_contractor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaMultiAgentVerifier.NoPendingVerificationRefund.selector, _contractor)
        );
        _verifier.withdrawVerificationRefund();
    }

    function test_HandleResponse_StaleRequestIdCannotOverwriteActiveSubmission() public {
        (uint256 taskId, uint256 submissionId,) = _submitWork();
        _forceEscrowVerificationFailed(taskId, submissionId, bytes32(uint256(1)));

        vm.prank(_contractor);
        bytes32 retryRequestId = _escrow.retryVerification{ value: _workflowDeposit() }(taskId);
        assertEq(uint256(retryRequestId), 2);

        ISomniaAgentRequester.Response[] memory oldResponses = _responses("Complete");
        ISomniaAgentRequester.Request memory details;

        vm.expectEmit(true, true, true, true, address(_verifier));
        emit StaleSomniaCallbackIgnored(1, 2, taskId, submissionId);

        _platform.callback(address(_verifier), 1, oldResponses, ISomniaAgentRequester.ResponseStatus.Success, details);

        (,,,,,,, VigiliaEscrow.TaskState state,,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaTypes.VerificationVerdict verdict,,) = _escrow.submissions(submissionId);
        (,,,,,,,,,,,,,,, bool oldFulfilled) = _verifier.requests(1);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.Submitted));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertTrue(oldFulfilled);

        _callback(2, _FACTS);
        _callback(3, "Complete");

        (,,,,,,, state,,,,) = _escrow.tasks(taskId);
        (,,,,, verdict,,) = _escrow.submissions(submissionId);
        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
    }

    function _newVerifier(bool _enableLlmInference, bool _enableLlmParseWebsite)
        private
        returns (VigiliaMultiAgentVerifier verifier)
    {
        verifier = new VigiliaMultiAgentVerifier(
            VigiliaMultiAgentVerifier.ConstructorConfig({
                platform: address(_platform),
                escrowBinder: _binder,
                jsonApiAgentId: _JSON_AGENT_ID,
                llmInferenceAgentId: _enableLlmInference ? _LLM_INFERENCE_AGENT_ID : 0,
                llmParseWebsiteAgentId: _enableLlmParseWebsite ? _LLM_PARSE_WEBSITE_AGENT_ID : 0,
                subcommitteeSize: _SUBCOMMITTEE_SIZE,
                jsonApiPricePerValidator: _JSON_PRICE_PER_VALIDATOR,
                llmInferencePricePerValidator: _enableLlmInference ? _LLM_INFERENCE_PRICE_PER_VALIDATOR : 0,
                llmParseWebsitePricePerValidator: _enableLlmParseWebsite ? _LLM_PARSE_PRICE_PER_VALIDATOR : 0,
                jsonApiSelector: _JSON_SELECTOR,
                enableLlmInferenceSettlement: _enableLlmInference
            })
        );
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
        (submissionId, requestId) = _escrow.submitWork{ value: _workflowDeposit() }(taskId, _JSON_URL, _EVIDENCE_HASH);
    }

    function _requestJsonCanary() private returns (uint256 requestId) {
        vm.prank(_requester);
        requestId = _verifier.requestJsonApiCanary{ value: _jsonDeposit() }(_JSON_URL, _JSON_SELECTOR);
    }

    function _callback(uint256 _requestId, string memory _result) private {
        ISomniaAgentRequester.Response[] memory responses = _responses(_result);
        ISomniaAgentRequester.Request memory details;
        _platform.callback(
            address(_verifier), _requestId, responses, ISomniaAgentRequester.ResponseStatus.Success, details
        );
    }

    function _statusCallback(uint256 _requestId, ISomniaAgentRequester.ResponseStatus _status) private {
        ISomniaAgentRequester.Response[] memory responses = new ISomniaAgentRequester.Response[](0);
        ISomniaAgentRequester.Request memory details;
        _platform.callback(address(_verifier), _requestId, responses, _status, details);
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

    function _malformedResponses() private view returns (ISomniaAgentRequester.Response[] memory responses) {
        responses = new ISomniaAgentRequester.Response[](1);
        responses[0] = ISomniaAgentRequester.Response({
            validator: address(0xAA),
            result: abi.encode(uint256(123)),
            status: ISomniaAgentRequester.ResponseStatus.Success,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });
    }

    function _allowedValues() private pure returns (string[] memory allowedValues) {
        allowedValues = new string[](3);
        allowedValues[0] = "Complete";
        allowedValues[1] = "NeedsReview";
        allowedValues[2] = "Incomplete";
    }

    function _jsonDeposit() private pure returns (uint256 deposit) {
        deposit = _PLATFORM_DEPOSIT + (_SUBCOMMITTEE_SIZE * _JSON_PRICE_PER_VALIDATOR);
    }

    function _llmInferenceDeposit() private pure returns (uint256 deposit) {
        deposit = _PLATFORM_DEPOSIT + (_SUBCOMMITTEE_SIZE * _LLM_INFERENCE_PRICE_PER_VALIDATOR);
    }

    function _llmParseWebsiteDeposit() private pure returns (uint256 deposit) {
        deposit = _PLATFORM_DEPOSIT + (_SUBCOMMITTEE_SIZE * _LLM_PARSE_PRICE_PER_VALIDATOR);
    }

    function _workflowDeposit() private pure returns (uint256 deposit) {
        deposit = _jsonDeposit() + _llmInferenceDeposit();
    }
}
