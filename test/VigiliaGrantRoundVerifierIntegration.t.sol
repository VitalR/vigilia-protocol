// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "@forge-std/Test.sol";
import { IJsonApiAgent } from "../src/interfaces/IJsonApiAgent.sol";
import { ILlmInferenceAgent } from "../src/interfaces/ILlmInferenceAgent.sol";
import { ISomniaAgentRequester } from "../src/interfaces/ISomniaAgentRequester.sol";
import { VigiliaAgentStringLib } from "../src/libraries/VigiliaAgentStringLib.sol";
import { VigiliaGrantRound } from "../src/VigiliaGrantRound.sol";
import { VigiliaMultiAgentVerifier } from "../src/VigiliaMultiAgentVerifier.sol";
import { VigiliaTypes } from "../src/types/VigiliaTypes.sol";
import { MockSomniaAgentRequester } from "./mocks/MockSomniaAgentRequester.sol";

contract VigiliaGrantRoundVerifierIntegrationTest is Test {
    uint256 private constant _JSON_AGENT_ID = 42;
    uint256 private constant _LLM_INFERENCE_AGENT_ID = 43;
    uint256 private constant _LLM_PARSE_WEBSITE_AGENT_ID = 44;
    uint256 private constant _SUBCOMMITTEE_SIZE = 3;
    uint256 private constant _JSON_PRICE_PER_VALIDATOR = 0.02 ether;
    uint256 private constant _LLM_INFERENCE_PRICE_PER_VALIDATOR = 0.07 ether;
    uint256 private constant _LLM_PARSE_PRICE_PER_VALIDATOR = 0.1 ether;
    uint256 private constant _PLATFORM_DEPOSIT = 0.01 ether;
    uint256 private constant _PRIZE_AMOUNT = 1 ether;
    uint256 private constant _MAX_WINNERS = 3;
    uint64 private constant _APPLICATION_DEADLINE = 11 days;
    uint64 private constant _REVIEW_DEADLINE = 14 days;

    string private constant _JSON_SELECTOR = "verdict";
    string private constant _FACTS_SELECTOR = "facts";
    string private constant _EVIDENCE_URI = "https://example.com/grant-application.json";
    string private constant _WEBSITE_URI = "https://example.com/grant-application.html";
    string private constant _WEBSITE_EXTRACT =
        "repo present; setup docs present; deployment address present; demo URL present; tests pass";
    string private constant _FACTS = "repo_exists=true; readme_setup=true; deployed_contract=true; demo_tx=true";
    string private constant _REQUIREMENTS_URI = "ipfs://grant-round-requirements";
    string private constant _WORKFLOW_LLM_SYSTEM =
        "You are a strict Vigilia work verifier. Return exactly one allowed value. Do not explain.";
    bytes32 private constant _EVIDENCE_HASH = keccak256("grant-application");

    MockSomniaAgentRequester private _platform;
    VigiliaMultiAgentVerifier private _verifier;
    VigiliaGrantRound private _grantRound;

    address private _binder = address(0xB10D);
    address private _sponsor = address(0x5100);
    address private _judge = address(0xBEEF);
    address private _applicant = address(0xA11CE);

    function setUp() public {
        vm.warp(10 days);
        _platform = new MockSomniaAgentRequester(_PLATFORM_DEPOSIT, _PLATFORM_DEPOSIT);
        _verifier = _newVerifier();
        _grantRound = new VigiliaGrantRound(address(_verifier));

        vm.prank(_binder);
        _verifier.bindEscrow(address(_grantRound));

        vm.deal(_sponsor, 100 ether);
        vm.deal(_applicant, 100 ether);
    }

    function test_RequestApplicationScreening_FreshVerifierUsesTwoAgentFactsWorkflow() public {
        uint256 applicationId = _createFundAndSubmitApplication();

        vm.prank(_applicant);
        bytes32 requestId = _grantRound.requestApplicationScreening{ value: _workflowDeposit() }(applicationId);

        assertEq(uint256(requestId), 1);
        assertEq(_platform.lastAgentId(), _JSON_AGENT_ID);
        assertEq(
            _platform.lastPayload(),
            abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _EVIDENCE_URI, _FACTS_SELECTOR)
        );
        assertEq(_platform.lastValue(), _jsonDeposit());

        (,,,, bytes32 storedRequestId,, VigiliaGrantRound.ApplicationStatus status,,,,,) =
            _grantRound.applications(applicationId);
        assertEq(storedRequestId, requestId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.ScreeningRequested));

        (,,,,,,,,,,,, uint256 prepaidBudget,,,,,) = _verifier.requests(1);
        assertEq(prepaidBudget, _llmInferenceDeposit());
    }

    function test_HandleResponse_TwoAgentCompleteUpdatesApplicationOnly() public {
        uint256 applicationId = _requestScreening();
        uint256 contractBalanceBefore = address(_grantRound).balance;

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

        _callback(2, "Complete");

        (
            ,,,,,
            VigiliaTypes.VerificationVerdict verdict,
            VigiliaGrantRound.ApplicationStatus status,
            bool selected,
            bool claimed,,
            uint64 reviewedAt,
            string memory notesURI
        ) = _grantRound.applications(applicationId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Complete));
        assertFalse(selected);
        assertFalse(claimed);
        assertEq(reviewedAt, block.timestamp);
        assertEq(notesURI, "somnia-agent-request:2");
        assertEq(address(_grantRound).balance, contractBalanceBefore);
    }

    function test_HandleResponse_TwoAgentNeedsReviewUpdatesApplication() public {
        uint256 applicationId = _requestScreening();
        _callback(1, _FACTS);
        _callback(2, "NeedsReview");

        (,,,,, VigiliaTypes.VerificationVerdict verdict, VigiliaGrantRound.ApplicationStatus status,,,,,) =
            _grantRound.applications(applicationId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.NeedsReview));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.NeedsReview));
    }

    function test_HandleResponse_JsonFailureMarksVerificationFailedAndRefundsUnusedLlmBudget() public {
        uint256 applicationId = _requestScreening();

        _statusCallback(1, ISomniaAgentRequester.ResponseStatus.Failed);

        (,,,,,, VigiliaGrantRound.ApplicationStatus status,,,,, string memory notesURI) =
            _grantRound.applications(applicationId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.VerificationFailed));
        assertEq(notesURI, "somnia-agent-request:1");
        assertEq(_verifier.pendingVerificationRefunds(_applicant), _llmInferenceDeposit());
        assertEq(_platform.nextRequestId(), 2);
    }

    function test_HandleResponse_UnknownLlmVerdictMarksVerificationFailed() public {
        uint256 applicationId = _requestScreening();
        _callback(1, _FACTS);

        _callback(2, "Maybe");

        (,,,,, VigiliaTypes.VerificationVerdict verdict, VigiliaGrantRound.ApplicationStatus status,,,,,) =
            _grantRound.applications(applicationId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.VerificationFailed));
    }

    function test_HandleResponse_ThreeAgentCompleteThenJudgeSelectsAndApplicantClaims() public {
        uint256 roundId = _createRoundWithMode(_grantRound, VigiliaGrantRound.ScreeningMode.ThreeAgent);
        vm.prank(_sponsor);
        _grantRound.fundRound{ value: _PRIZE_AMOUNT * _MAX_WINNERS }(roundId);
        vm.prank(_applicant);
        uint256 applicationId = _grantRound.submitApplication(roundId, _EVIDENCE_URI, _EVIDENCE_HASH);

        vm.prank(_applicant);
        bytes32 requestId = _grantRound.requestApplicationScreening{ value: _threeAgentDeposit() }(applicationId);
        assertEq(requestId, bytes32(uint256(1)));

        _callback(1, _FACTS);
        _callback(2, _WEBSITE_URI);
        _callback(3, _WEBSITE_EXTRACT);

        string memory expectedPrompt = VigiliaAgentStringLib.threeAgentGrantVerdictPrompt(
            _REQUIREMENTS_URI, _FACTS, _WEBSITE_EXTRACT, _EVIDENCE_URI, _WEBSITE_URI
        );
        assertEq(_platform.lastAgentId(), _LLM_INFERENCE_AGENT_ID);
        assertEq(
            _platform.lastPayload(),
            abi.encodeWithSelector(
                ILlmInferenceAgent.inferString.selector,
                expectedPrompt,
                "You are a strict grant application screening classifier. Return exactly one allowed value: Complete, NeedsReview, or Incomplete. Do not explain.",
                false,
                _allowedValues()
            )
        );

        uint256 balanceBeforeVerdict = address(_grantRound).balance;
        _callback(4, "Complete");

        (
            ,,,,,
            VigiliaTypes.VerificationVerdict verdict,
            VigiliaGrantRound.ApplicationStatus status,
            bool selected,,,,
        ) = _grantRound.applications(applicationId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Complete));
        assertFalse(selected);
        assertEq(address(_grantRound).balance, balanceBeforeVerdict);

        vm.warp(_APPLICATION_DEADLINE + 1);
        uint256[] memory selectedIds = new uint256[](1);
        selectedIds[0] = applicationId;
        vm.prank(_judge);
        _grantRound.selectFinalists(roundId, selectedIds);
        vm.prank(_judge);
        _grantRound.finalizeRound(roundId);

        uint256 applicantBalanceBefore = _applicant.balance;
        vm.prank(_applicant);
        _grantRound.claimPrize(applicationId);

        bool claimed;
        (,,,,,, status, selected, claimed,,,) = _grantRound.applications(applicationId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Claimed));
        assertTrue(selected);
        assertTrue(claimed);
        assertEq(_applicant.balance, applicantBalanceBefore + _PRIZE_AMOUNT);
    }

    function test_RequestApplicationScreening_UnboundFreshVerifierReverts() public {
        VigiliaMultiAgentVerifier unboundVerifier = _newVerifier();
        VigiliaGrantRound unboundGrantRound = new VigiliaGrantRound(address(unboundVerifier));
        uint256 roundId = _createRound(unboundGrantRound);
        vm.prank(_sponsor);
        unboundGrantRound.fundRound{ value: _PRIZE_AMOUNT * _MAX_WINNERS }(roundId);
        vm.prank(_applicant);
        uint256 applicationId = unboundGrantRound.submitApplication(roundId, _EVIDENCE_URI, _EVIDENCE_HASH);

        vm.prank(_applicant);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaMultiAgentVerifier.Unauthorized.selector, address(unboundGrantRound))
        );
        unboundGrantRound.requestApplicationScreening{ value: _workflowDeposit() }(applicationId);
    }

    function _newVerifier() private returns (VigiliaMultiAgentVerifier verifier) {
        verifier = new VigiliaMultiAgentVerifier(
            VigiliaMultiAgentVerifier.ConstructorConfig({
                platform: address(_platform),
                escrowBinder: _binder,
                jsonApiAgentId: _JSON_AGENT_ID,
                llmInferenceAgentId: _LLM_INFERENCE_AGENT_ID,
                llmParseWebsiteAgentId: _LLM_PARSE_WEBSITE_AGENT_ID,
                subcommitteeSize: _SUBCOMMITTEE_SIZE,
                jsonApiPricePerValidator: _JSON_PRICE_PER_VALIDATOR,
                llmInferencePricePerValidator: _LLM_INFERENCE_PRICE_PER_VALIDATOR,
                llmParseWebsitePricePerValidator: _LLM_PARSE_PRICE_PER_VALIDATOR,
                jsonApiSelector: _JSON_SELECTOR,
                enableLlmInferenceSettlement: true
            })
        );
    }

    function _createRound(VigiliaGrantRound _target) private returns (uint256 roundId) {
        roundId = _createRoundWithMode(_target, VigiliaGrantRound.ScreeningMode.TwoAgent);
    }

    function _createRoundWithMode(VigiliaGrantRound _target, VigiliaGrantRound.ScreeningMode _screeningMode)
        private
        returns (uint256 roundId)
    {
        vm.prank(_sponsor);
        roundId = _target.createRound(
            _judge,
            _PRIZE_AMOUNT,
            _MAX_WINNERS,
            _APPLICATION_DEADLINE,
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            _screeningMode
        );
    }

    function _createFundAndSubmitApplication() private returns (uint256 applicationId) {
        uint256 roundId = _createRound(_grantRound);

        vm.prank(_sponsor);
        _grantRound.fundRound{ value: _PRIZE_AMOUNT * _MAX_WINNERS }(roundId);

        vm.prank(_applicant);
        applicationId = _grantRound.submitApplication(roundId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function _requestScreening() private returns (uint256 applicationId) {
        applicationId = _createFundAndSubmitApplication();

        vm.prank(_applicant);
        _grantRound.requestApplicationScreening{ value: _workflowDeposit() }(applicationId);
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

    function _threeAgentDeposit() private pure returns (uint256 deposit) {
        deposit = _jsonDeposit() + _jsonDeposit() + _llmParseWebsiteDeposit() + _llmInferenceDeposit();
    }
}
