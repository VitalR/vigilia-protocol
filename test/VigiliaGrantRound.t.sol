// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "@forge-std/Test.sol";
import { VigiliaGrantRound } from "../src/VigiliaGrantRound.sol";
import { MockVerifier } from "../src/mocks/MockVerifier.sol";
import { VigiliaTypes } from "../src/types/VigiliaTypes.sol";

contract VigiliaGrantRoundTest is Test {
    event RoundCreated(
        uint256 indexed roundId,
        address indexed sponsor,
        address indexed judge,
        uint256 prizeAmount,
        uint256 maxWinners,
        uint64 applicationDeadline,
        uint64 reviewDeadline,
        string requirementsURI,
        VigiliaGrantRound.ScreeningMode screeningMode
    );
    event RoundFunded(uint256 indexed roundId, address indexed sponsor, uint256 amount);
    event ApplicationSubmitted(
        uint256 indexed roundId,
        uint256 indexed applicationId,
        address indexed applicant,
        string evidenceURI,
        bytes32 evidenceHash
    );
    event ApplicationScreeningRequested(
        uint256 indexed roundId, uint256 indexed applicationId, address indexed payer, bytes32 requestId
    );
    event ApplicationVerdictRecorded(
        uint256 indexed roundId,
        uint256 indexed applicationId,
        VigiliaTypes.VerificationVerdict verdict,
        string notesURI
    );
    event ApplicationVerificationFailed(
        uint256 indexed roundId, uint256 indexed applicationId, bytes32 requestId, string notesURI
    );
    event ManualScreeningRecorded(
        uint256 indexed roundId,
        uint256 indexed applicationId,
        VigiliaTypes.VerificationVerdict verdict,
        string notesURI
    );
    event FinalistSelected(uint256 indexed roundId, uint256 indexed applicationId, address indexed applicant);
    event ApplicationRejected(uint256 indexed roundId, uint256 indexed applicationId, string reasonURI);
    event RoundFinalized(uint256 indexed roundId, uint256 selectedCount);
    event PrizeClaimed(
        uint256 indexed roundId,
        uint256 indexed applicationId,
        address indexed applicant,
        address recipient,
        uint256 amount
    );
    event UnallocatedRefundCredited(uint256 indexed roundId, address indexed sponsor, uint256 amount);
    event RoundCancelled(uint256 indexed roundId, uint256 refundAmount);
    event PendingWithdrawalClaimed(address indexed account, address indexed recipient, uint256 amount);
    event StaleGrantRoundCallbackIgnored(
        uint256 indexed roundId, uint256 indexed applicationId, bytes32 expectedRequestId, bytes32 actualRequestId
    );

    VigiliaGrantRound private _grantRound;
    MockVerifier private _verifier;

    address private _sponsor = address(0x5100);
    address private _judge = address(0xBEEF);
    address private _applicant = address(0xA11CE);
    address private _applicantTwo = address(0xB0B);
    address private _applicantThree = address(0xCAFE);
    address private _attacker = address(0xA77A);
    address payable private _recipient = payable(address(0xFEED));

    uint256 private constant _PRIZE_AMOUNT = 1 ether;
    uint256 private constant _MAX_WINNERS = 3;
    uint64 private constant _APPLICATION_DEADLINE = 11 days;
    uint64 private constant _REVIEW_DEADLINE = 14 days;
    string private constant _REQUIREMENTS_URI = "ipfs://grant-requirements";
    string private constant _EVIDENCE_URI = "ipfs://application-one";
    string private constant _EVIDENCE_URI_TWO = "ipfs://application-two";
    string private constant _NOTES_URI = "ipfs://screening-notes";
    string private constant _REASON_URI = "ipfs://rejection-reason";
    bytes32 private constant _EVIDENCE_HASH = keccak256("application-one");
    bytes32 private constant _EVIDENCE_HASH_TWO = keccak256("application-two");

    function setUp() public {
        vm.warp(10 days);
        _verifier = new MockVerifier();
        _grantRound = new VigiliaGrantRound(address(_verifier));

        vm.deal(_sponsor, 100 ether);
        vm.deal(_judge, 1 ether);
        vm.deal(_applicant, 10 ether);
        vm.deal(_applicantTwo, 10 ether);
        vm.deal(_applicantThree, 10 ether);
        vm.deal(_attacker, 10 ether);
    }

    function test_CreateRound_StoresRoundConfiguration() public {
        vm.expectEmit(true, true, true, true);
        emit RoundCreated(
            1,
            _sponsor,
            _judge,
            _PRIZE_AMOUNT,
            _MAX_WINNERS,
            _APPLICATION_DEADLINE,
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            VigiliaGrantRound.ScreeningMode.TwoAgent
        );

        uint256 roundId = _createRound();

        (
            address sponsor,
            address judge,
            uint256 prizeAmount,
            uint256 maxWinners,
            uint256 totalFunded,
            uint256 selectedCount,
            uint256 claimedCount,
            uint256 totalClaimed,
            uint256 totalRefunded,
            uint256 applicationsCount,
            uint64 applicationDeadline,
            uint64 reviewDeadline,
            string memory requirementsURI,
            VigiliaGrantRound.ScreeningMode screeningMode,
            VigiliaGrantRound.RoundState state
        ) = _grantRound.rounds(roundId);

        assertEq(sponsor, _sponsor);
        assertEq(judge, _judge);
        assertEq(prizeAmount, _PRIZE_AMOUNT);
        assertEq(maxWinners, _MAX_WINNERS);
        assertEq(totalFunded, 0);
        assertEq(selectedCount, 0);
        assertEq(claimedCount, 0);
        assertEq(totalClaimed, 0);
        assertEq(totalRefunded, 0);
        assertEq(applicationsCount, 0);
        assertEq(applicationDeadline, _APPLICATION_DEADLINE);
        assertEq(reviewDeadline, _REVIEW_DEADLINE);
        assertEq(requirementsURI, _REQUIREMENTS_URI);
        assertEq(uint256(screeningMode), uint256(VigiliaGrantRound.ScreeningMode.TwoAgent));
        assertEq(uint256(state), uint256(VigiliaGrantRound.RoundState.Created));
        assertEq(_grantRound.nextRoundId(), 2);
    }

    function test_CreateRound_AcceptsThreeAgentConfiguration() public {
        uint256 roundId = _createRoundWithMode(VigiliaGrantRound.ScreeningMode.ThreeAgent);

        (,,,,,,,,,,,,, VigiliaGrantRound.ScreeningMode screeningMode,) = _grantRound.rounds(roundId);
        assertEq(uint256(screeningMode), uint256(VigiliaGrantRound.ScreeningMode.ThreeAgent));
    }

    function test_CreateRound_ZeroJudgeReverts() public {
        vm.prank(_sponsor);
        vm.expectRevert(VigiliaGrantRound.InvalidAddress.selector);
        _grantRound.createRound(
            address(0),
            _PRIZE_AMOUNT,
            _MAX_WINNERS,
            _APPLICATION_DEADLINE,
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            VigiliaGrantRound.ScreeningMode.TwoAgent
        );
    }

    function test_CreateRound_ZeroPrizeReverts() public {
        vm.prank(_sponsor);
        vm.expectRevert(VigiliaGrantRound.InvalidAmount.selector);
        _grantRound.createRound(
            _judge,
            0,
            _MAX_WINNERS,
            _APPLICATION_DEADLINE,
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            VigiliaGrantRound.ScreeningMode.TwoAgent
        );
    }

    function test_CreateRound_ZeroMaxWinnersReverts() public {
        vm.prank(_sponsor);
        vm.expectRevert(VigiliaGrantRound.InvalidAmount.selector);
        _grantRound.createRound(
            _judge,
            _PRIZE_AMOUNT,
            0,
            _APPLICATION_DEADLINE,
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            VigiliaGrantRound.ScreeningMode.TwoAgent
        );
    }

    function test_CreateRound_InvalidDeadlinesRevert() public {
        vm.prank(_sponsor);
        vm.expectRevert(VigiliaGrantRound.InvalidDeadline.selector);
        _grantRound.createRound(
            _judge,
            _PRIZE_AMOUNT,
            _MAX_WINNERS,
            uint64(block.timestamp),
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            VigiliaGrantRound.ScreeningMode.TwoAgent
        );

        vm.prank(_sponsor);
        vm.expectRevert(VigiliaGrantRound.InvalidDeadline.selector);
        _grantRound.createRound(
            _judge,
            _PRIZE_AMOUNT,
            _MAX_WINNERS,
            _APPLICATION_DEADLINE,
            _APPLICATION_DEADLINE,
            _REQUIREMENTS_URI,
            VigiliaGrantRound.ScreeningMode.TwoAgent
        );
    }

    function test_FundRound_ExactAmountOpensRound() public {
        uint256 roundId = _createRound();

        vm.expectEmit(true, true, false, true);
        emit RoundFunded(roundId, _sponsor, _PRIZE_AMOUNT * _MAX_WINNERS);

        vm.prank(_sponsor);
        _grantRound.fundRound{ value: _PRIZE_AMOUNT * _MAX_WINNERS }(roundId);

        (,,,, uint256 totalFunded,,,,,,,,,, VigiliaGrantRound.RoundState state) = _grantRound.rounds(roundId);
        assertEq(totalFunded, _PRIZE_AMOUNT * _MAX_WINNERS);
        assertEq(uint256(state), uint256(VigiliaGrantRound.RoundState.Open));
        assertEq(address(_grantRound).balance, _PRIZE_AMOUNT * _MAX_WINNERS);
    }

    function test_FundRound_WrongAmountReverts() public {
        uint256 roundId = _createRound();

        vm.prank(_sponsor);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.InvalidFundingAmount.selector, 3 ether, 2 ether));
        _grantRound.fundRound{ value: 2 ether }(roundId);
    }

    function test_FundRound_NonSponsorReverts() public {
        uint256 roundId = _createRound();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.Unauthorized.selector, _attacker));
        _grantRound.fundRound{ value: 3 ether }(roundId);
    }

    function test_FundRound_CannotFundTwice() public {
        uint256 roundId = _createAndFundRound();

        vm.prank(_sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaGrantRound.InvalidState.selector, roundId, VigiliaGrantRound.RoundState.Open)
        );
        _grantRound.fundRound{ value: 3 ether }(roundId);
    }

    function test_RequiredFunding_ReturnsPrizeTimesMaxWinners() public {
        uint256 roundId = _createRound();

        assertEq(_grantRound.requiredFunding(roundId), 3 ether);
    }

    function test_SubmitApplication_WorksBeforeDeadline() public {
        uint256 roundId = _createAndFundRound();

        vm.expectEmit(true, true, true, true);
        emit ApplicationSubmitted(roundId, 1, _applicant, _EVIDENCE_URI, _EVIDENCE_HASH);

        uint256 applicationId = _submitApplication(_applicant, roundId, _EVIDENCE_URI, _EVIDENCE_HASH);

        (
            uint256 applicationRoundId,
            address applicant,
            string memory evidenceURI,
            bytes32 evidenceHash,
            bytes32 requestId,
            VigiliaTypes.VerificationVerdict verdict,
            VigiliaGrantRound.ApplicationStatus status,
            bool selected,
            bool claimed,
            uint64 submittedAt,
            uint64 reviewedAt,
            string memory notesURI
        ) = _grantRound.applications(applicationId);

        assertEq(applicationRoundId, roundId);
        assertEq(applicant, _applicant);
        assertEq(evidenceURI, _EVIDENCE_URI);
        assertEq(evidenceHash, _EVIDENCE_HASH);
        assertEq(requestId, bytes32(0));
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Submitted));
        assertFalse(selected);
        assertFalse(claimed);
        assertEq(submittedAt, block.timestamp);
        assertEq(reviewedAt, 0);
        assertEq(notesURI, "");
        assertEq(_grantRound.applicationOf(roundId, _applicant), applicationId);

        uint256[] memory applicationIds = _grantRound.getRoundApplications(roundId);
        assertEq(applicationIds.length, 1);
        assertEq(applicationIds[0], applicationId);
    }

    function test_SubmitApplication_RejectsAfterDeadline() public {
        uint256 roundId = _createAndFundRound();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_applicant);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.ApplicationDeadlinePassed.selector, roundId, _APPLICATION_DEADLINE, block.timestamp
            )
        );
        _grantRound.submitApplication(roundId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function test_SubmitApplication_RejectsEmptyUri() public {
        uint256 roundId = _createAndFundRound();

        vm.prank(_applicant);
        vm.expectRevert(VigiliaGrantRound.EmptyEvidenceURI.selector);
        _grantRound.submitApplication(roundId, "", _EVIDENCE_HASH);
    }

    function test_SubmitApplication_RejectsZeroHash() public {
        uint256 roundId = _createAndFundRound();

        vm.prank(_applicant);
        vm.expectRevert(VigiliaGrantRound.ZeroEvidenceHash.selector);
        _grantRound.submitApplication(roundId, _EVIDENCE_URI, bytes32(0));
    }

    function test_SubmitApplication_DuplicateApplicantReverts() public {
        uint256 roundId = _createAndFundRound();
        uint256 applicationId = _submitApplication(_applicant, roundId, _EVIDENCE_URI, _EVIDENCE_HASH);

        vm.prank(_applicant);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaGrantRound.DuplicateApplication.selector, roundId, _applicant, applicationId)
        );
        _grantRound.submitApplication(roundId, _EVIDENCE_URI_TWO, _EVIDENCE_HASH_TWO);
    }

    function test_RecordManualScreening_SponsorCanRecordComplete() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();

        vm.expectEmit(true, true, false, true);
        emit ManualScreeningRecorded(roundId, applicationId, VigiliaTypes.VerificationVerdict.Complete, _NOTES_URI);

        vm.prank(_sponsor);
        _grantRound.recordManualScreening(applicationId, VigiliaTypes.VerificationVerdict.Complete, _NOTES_URI);

        (
            ,,,,,
            VigiliaTypes.VerificationVerdict verdict,
            VigiliaGrantRound.ApplicationStatus status,
            bool selected,,,,
        ) = _grantRound.applications(applicationId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Complete));
        assertFalse(selected);
        assertEq(address(_grantRound).balance, 3 ether);
    }

    function test_RecordManualScreening_JudgeCanRecordNeedsReview() public {
        (, uint256 applicationId) = _createFundAndSubmitOne();

        vm.prank(_judge);
        _grantRound.recordManualScreening(applicationId, VigiliaTypes.VerificationVerdict.NeedsReview, _NOTES_URI);

        (,,,,,, VigiliaGrantRound.ApplicationStatus status,,,,,) = _grantRound.applications(applicationId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.NeedsReview));
    }

    function test_RecordManualScreening_JudgeCanRecordIncomplete() public {
        (, uint256 applicationId) = _createFundAndSubmitOne();

        vm.prank(_judge);
        _grantRound.recordManualScreening(applicationId, VigiliaTypes.VerificationVerdict.Incomplete, _NOTES_URI);

        (,,,,,, VigiliaGrantRound.ApplicationStatus status,,,,,) = _grantRound.applications(applicationId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Incomplete));
    }

    function test_RecordManualScreening_NonActorReverts() public {
        (, uint256 applicationId) = _createFundAndSubmitOne();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.Unauthorized.selector, _attacker));
        _grantRound.recordManualScreening(applicationId, VigiliaTypes.VerificationVerdict.Complete, _NOTES_URI);
    }

    function test_RecordManualScreening_UnknownVerdictReverts() public {
        (, uint256 applicationId) = _createFundAndSubmitOne();

        vm.prank(_judge);
        vm.expectRevert(VigiliaGrantRound.UnknownVerdict.selector);
        _grantRound.recordManualScreening(applicationId, VigiliaTypes.VerificationVerdict.Unknown, _NOTES_URI);
    }

    function test_RequestApplicationScreening_TwoAgentStoresRequest() public {
        (, uint256 applicationId) = _createFundAndSubmitOne();

        vm.prank(_applicant);
        bytes32 requestId = _grantRound.requestApplicationScreening(applicationId);

        (,,,, bytes32 storedRequestId,, VigiliaGrantRound.ApplicationStatus status,,,,,) =
            _grantRound.applications(applicationId);
        assertEq(storedRequestId, requestId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.ScreeningRequested));
        assertTrue(_verifier.requests(requestId));
    }

    function test_RequestApplicationScreening_ThreeAgentRevertsUntilVerifierSupportsWebsiteWorkflow() public {
        uint256 roundId = _createRoundWithMode(VigiliaGrantRound.ScreeningMode.ThreeAgent);
        _fundRound(roundId);
        uint256 applicationId = _submitApplication(_applicant, roundId, _EVIDENCE_URI, _EVIDENCE_HASH);

        vm.prank(_applicant);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.UnsupportedScreeningMode.selector, VigiliaGrantRound.ScreeningMode.ThreeAgent
            )
        );
        _grantRound.requestApplicationScreening(applicationId);
    }

    function test_RequestApplicationScreening_ZeroVerifierReverts() public {
        VigiliaGrantRound manualDeployment = new VigiliaGrantRound(address(0));
        vm.prank(_sponsor);
        uint256 roundId = manualDeployment.createRound(
            _judge,
            _PRIZE_AMOUNT,
            _MAX_WINNERS,
            _APPLICATION_DEADLINE,
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            VigiliaGrantRound.ScreeningMode.TwoAgent
        );
        vm.prank(_sponsor);
        manualDeployment.fundRound{ value: 3 ether }(roundId);
        vm.prank(_applicant);
        uint256 applicationId = manualDeployment.submitApplication(roundId, _EVIDENCE_URI, _EVIDENCE_HASH);

        vm.prank(_applicant);
        vm.expectRevert(VigiliaGrantRound.VerifierNotConfigured.selector);
        manualDeployment.requestApplicationScreening(applicationId);
    }

    function test_RecordVerdict_OnlyVerifierCanRecord() public {
        (, uint256 applicationId, bytes32 requestId) = _createFundSubmitAndRequest();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.Unauthorized.selector, _attacker));
        _grantRound.recordVerdict(1, applicationId, requestId, VigiliaTypes.VerificationVerdict.Complete, _NOTES_URI);
    }

    function test_RecordVerdict_CompleteMapsToComplete() public {
        (uint256 roundId, uint256 applicationId, bytes32 requestId) = _createFundSubmitAndRequest();

        vm.expectEmit(true, true, false, true);
        emit ApplicationVerdictRecorded(roundId, applicationId, VigiliaTypes.VerificationVerdict.Complete, _NOTES_URI);

        vm.prank(address(_verifier));
        _grantRound.recordVerdict(
            roundId, applicationId, requestId, VigiliaTypes.VerificationVerdict.Complete, _NOTES_URI
        );

        (
            ,,,,,
            VigiliaTypes.VerificationVerdict verdict,
            VigiliaGrantRound.ApplicationStatus status,
            bool selected,,,,
        ) = _grantRound.applications(applicationId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Complete));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Complete));
        assertFalse(selected);
    }

    function test_RecordVerdict_NeedsReviewMapsToNeedsReview() public {
        (uint256 roundId, uint256 applicationId, bytes32 requestId) = _createFundSubmitAndRequest();

        vm.prank(address(_verifier));
        _grantRound.recordVerdict(
            roundId, applicationId, requestId, VigiliaTypes.VerificationVerdict.NeedsReview, _NOTES_URI
        );

        (,,,,,, VigiliaGrantRound.ApplicationStatus status,,,,,) = _grantRound.applications(applicationId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.NeedsReview));
    }

    function test_RecordVerdict_IncompleteMapsToIncomplete() public {
        (uint256 roundId, uint256 applicationId, bytes32 requestId) = _createFundSubmitAndRequest();

        vm.prank(address(_verifier));
        _grantRound.recordVerdict(
            roundId, applicationId, requestId, VigiliaTypes.VerificationVerdict.Incomplete, _NOTES_URI
        );

        (,,,,,, VigiliaGrantRound.ApplicationStatus status,,,,,) = _grantRound.applications(applicationId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Incomplete));
    }

    function test_RecordVerificationFailure_MapsToVerificationFailed() public {
        (uint256 roundId, uint256 applicationId, bytes32 requestId) = _createFundSubmitAndRequest();

        vm.expectEmit(true, true, false, true);
        emit ApplicationVerificationFailed(roundId, applicationId, requestId, _NOTES_URI);

        vm.prank(address(_verifier));
        _grantRound.recordVerificationFailure(roundId, applicationId, requestId, _NOTES_URI);

        (,,,,,, VigiliaGrantRound.ApplicationStatus status,,,,, string memory notesURI) =
            _grantRound.applications(applicationId);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.VerificationFailed));
        assertEq(notesURI, _NOTES_URI);
    }

    function test_RecordVerdict_StaleRequestDoesNotOverwriteLatestStatus() public {
        (uint256 roundId, uint256 applicationId, bytes32 requestId) = _createFundSubmitAndRequest();
        bytes32 staleRequestId = keccak256("stale");

        vm.expectEmit(true, true, false, true);
        emit StaleGrantRoundCallbackIgnored(roundId, applicationId, requestId, staleRequestId);

        vm.prank(address(_verifier));
        _grantRound.recordVerdict(
            roundId, applicationId, staleRequestId, VigiliaTypes.VerificationVerdict.Complete, _NOTES_URI
        );

        (,,,,, VigiliaTypes.VerificationVerdict verdict, VigiliaGrantRound.ApplicationStatus status,,,,,) =
            _grantRound.applications(applicationId);
        assertEq(uint256(verdict), uint256(VigiliaTypes.VerificationVerdict.Unknown));
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.ScreeningRequested));
    }

    function test_RecordVerdict_UnknownVerdictReverts() public {
        (uint256 roundId, uint256 applicationId, bytes32 requestId) = _createFundSubmitAndRequest();

        vm.prank(address(_verifier));
        vm.expectRevert(VigiliaGrantRound.UnknownVerdict.selector);
        _grantRound.recordVerdict(
            roundId, applicationId, requestId, VigiliaTypes.VerificationVerdict.Unknown, _NOTES_URI
        );
    }

    function test_SelectFinalists_CannotSelectBeforeApplicationDeadline() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        uint256[] memory applicationIds = _single(applicationId);

        vm.prank(_judge);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.ApplicationDeadlineActive.selector, roundId, _APPLICATION_DEADLINE, block.timestamp
            )
        );
        _grantRound.selectFinalists(roundId, applicationIds);
    }

    function test_SelectFinalists_JudgeCanSelectEligibleFinalist() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.expectEmit(true, true, true, true);
        emit FinalistSelected(roundId, applicationId, _applicant);

        vm.prank(_judge);
        _grantRound.selectFinalists(roundId, _single(applicationId));

        (,,,,, uint256 selectedCount,,,,,,,,, VigiliaGrantRound.RoundState state) = _grantRound.rounds(roundId);
        (,,,,,, VigiliaGrantRound.ApplicationStatus status, bool selected,,,,) = _grantRound.applications(applicationId);
        assertEq(selectedCount, 1);
        assertEq(uint256(state), uint256(VigiliaGrantRound.RoundState.Review));
        assertTrue(selected);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Selected));
    }

    function test_SelectFinalists_SponsorCanSelectEligibleFinalist() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_sponsor);
        _grantRound.selectFinalists(roundId, _single(applicationId));

        (,,,,, uint256 selectedCount,,,,,,,,,) = _grantRound.rounds(roundId);
        assertEq(selectedCount, 1);
    }

    function test_SelectFinalists_NonActorReverts() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.Unauthorized.selector, _attacker));
        _grantRound.selectFinalists(roundId, _single(applicationId));
    }

    function test_SelectFinalists_CannotSelectMoreThanMaxWinners() public {
        uint256 roundId = _createAndFundRound();
        uint256 app1 = _submitApplication(_applicant, roundId, _EVIDENCE_URI, _EVIDENCE_HASH);
        uint256 app2 = _submitApplication(_applicantTwo, roundId, _EVIDENCE_URI_TWO, _EVIDENCE_HASH_TWO);
        uint256 app3 = _submitApplication(_applicantThree, roundId, "ipfs://three", keccak256("three"));
        address applicantFour = address(0x4444);
        vm.deal(applicantFour, 1 ether);
        uint256 app4 = _submitApplication(applicantFour, roundId, "ipfs://four", keccak256("four"));
        uint256[] memory applicationIds = new uint256[](4);
        applicationIds[0] = app1;
        applicationIds[1] = app2;
        applicationIds[2] = app3;
        applicationIds[3] = app4;
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_judge);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.MaxWinnersExceeded.selector, _MAX_WINNERS));
        _grantRound.selectFinalists(roundId, applicationIds);
    }

    function test_SelectFinalists_CannotSelectSameApplicationTwice() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        uint256[] memory applicationIds = new uint256[](2);
        applicationIds[0] = applicationId;
        applicationIds[1] = applicationId;
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_judge);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.InvalidApplicationStatus.selector,
                applicationId,
                VigiliaGrantRound.ApplicationStatus.Selected
            )
        );
        _grantRound.selectFinalists(roundId, applicationIds);
    }

    function test_SelectFinalists_CannotSelectMissingApplication() public {
        uint256 roundId = _createAndFundRound();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_judge);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.ApplicationDoesNotExist.selector, 999));
        _grantRound.selectFinalists(roundId, _single(999));
    }

    function test_SelectFinalists_CannotSelectApplicationFromAnotherRound() public {
        (, uint256 applicationId) = _createFundAndSubmitOne();
        uint256 otherRoundId = _createAndFundRound();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_judge);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.ApplicationRoundMismatch.selector, otherRoundId, 1));
        _grantRound.selectFinalists(otherRoundId, _single(applicationId));
    }

    function test_SelectFinalists_CannotSelectRejectedApplication() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.prank(_judge);
        _grantRound.rejectApplication(applicationId, _REASON_URI);
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_judge);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.InvalidApplicationStatus.selector,
                applicationId,
                VigiliaGrantRound.ApplicationStatus.Rejected
            )
        );
        _grantRound.selectFinalists(roundId, _single(applicationId));
    }

    function test_SelectFinalists_CannotSelectIncompleteApplication() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.prank(_judge);
        _grantRound.recordManualScreening(applicationId, VigiliaTypes.VerificationVerdict.Incomplete, _NOTES_URI);
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_judge);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.InvalidApplicationStatus.selector,
                applicationId,
                VigiliaGrantRound.ApplicationStatus.Incomplete
            )
        );
        _grantRound.selectFinalists(roundId, _single(applicationId));
    }

    function test_FinalizeRound_JudgeCanFinalizeAfterApplicationDeadline() public {
        uint256 roundId = _createAndFundRound();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.expectEmit(true, false, false, true);
        emit RoundFinalized(roundId, 0);

        vm.prank(_judge);
        _grantRound.finalizeRound(roundId);

        (,,,,,,,,,,,,,, VigiliaGrantRound.RoundState state) = _grantRound.rounds(roundId);
        assertEq(uint256(state), uint256(VigiliaGrantRound.RoundState.Finalized));
    }

    function test_FinalizeRound_NonexistentRoundReverts() public {
        vm.prank(_judge);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.RoundDoesNotExist.selector, 99));
        _grantRound.finalizeRound(99);
    }

    function test_FinalizeRound_SponsorCanFinalizeAfterApplicationDeadline() public {
        uint256 roundId = _createAndFundRound();
        vm.warp(_APPLICATION_DEADLINE + 1);

        vm.prank(_sponsor);
        _grantRound.finalizeRound(roundId);

        (,,,,,,,,,,,,,, VigiliaGrantRound.RoundState state) = _grantRound.rounds(roundId);
        assertEq(uint256(state), uint256(VigiliaGrantRound.RoundState.Finalized));
    }

    function test_FinalizeRound_CannotSelectAfterFinalize() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.warp(_APPLICATION_DEADLINE + 1);
        vm.prank(_judge);
        _grantRound.finalizeRound(roundId);

        vm.prank(_judge);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.InvalidState.selector, roundId, VigiliaGrantRound.RoundState.Finalized
            )
        );
        _grantRound.selectFinalists(roundId, _single(applicationId));
    }

    function test_ClaimPrize_BlockedBeforeFinalize() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.warp(_APPLICATION_DEADLINE + 1);
        vm.prank(_judge);
        _grantRound.selectFinalists(roundId, _single(applicationId));

        vm.prank(_applicant);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.InvalidState.selector, roundId, VigiliaGrantRound.RoundState.Review
            )
        );
        _grantRound.claimPrize(applicationId);
    }

    function test_ClaimPrize_SelectedFinalistCanClaimExactPrize() public {
        (uint256 roundId, uint256 applicationId) = _selectAndFinalizeOne();
        uint256 applicantBalanceBefore = _applicant.balance;

        vm.expectEmit(true, true, true, true);
        emit PrizeClaimed(roundId, applicationId, _applicant, _applicant, _PRIZE_AMOUNT);

        vm.prank(_applicant);
        _grantRound.claimPrize(applicationId);

        (,,,,,, uint256 claimedCount, uint256 totalClaimed,,,,,,,) = _grantRound.rounds(roundId);
        (,,,,,, VigiliaGrantRound.ApplicationStatus status,, bool claimed,,,) = _grantRound.applications(applicationId);
        assertEq(_applicant.balance, applicantBalanceBefore + _PRIZE_AMOUNT);
        assertEq(claimedCount, 1);
        assertEq(totalClaimed, _PRIZE_AMOUNT);
        assertEq(uint256(status), uint256(VigiliaGrantRound.ApplicationStatus.Claimed));
        assertTrue(claimed);
    }

    function test_ClaimPrizeTo_WorksWithAlternateRecipient() public {
        (, uint256 applicationId) = _selectAndFinalizeOne();
        uint256 recipientBalanceBefore = _recipient.balance;

        vm.prank(_applicant);
        _grantRound.claimPrizeTo(applicationId, _recipient);

        assertEq(_recipient.balance, recipientBalanceBefore + _PRIZE_AMOUNT);
    }

    function test_ClaimPrize_NonApplicantCannotClaim() public {
        (, uint256 applicationId) = _selectAndFinalizeOne();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.Unauthorized.selector, _attacker));
        _grantRound.claimPrize(applicationId);
    }

    function test_ClaimPrize_NonFinalistCannotClaim() public {
        (uint256 roundId, uint256 applicationId) = _createFundAndSubmitOne();
        vm.warp(_APPLICATION_DEADLINE + 1);
        vm.prank(_judge);
        _grantRound.finalizeRound(roundId);

        vm.prank(_applicant);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.NotSelected.selector, applicationId));
        _grantRound.claimPrize(applicationId);
    }

    function test_ClaimPrize_CannotDoubleClaim() public {
        (, uint256 applicationId) = _selectAndFinalizeOne();
        vm.prank(_applicant);
        _grantRound.claimPrize(applicationId);

        vm.prank(_applicant);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.AlreadyClaimed.selector, applicationId));
        _grantRound.claimPrize(applicationId);
    }

    function test_RefundUnallocated_CreditsOnlyUnallocatedFunds() public {
        (uint256 roundId, uint256 applicationId) = _selectAndFinalizeOne();
        assertEq(_grantRound.selectedAllocation(roundId), 1 ether);
        assertEq(_grantRound.unallocatedAmount(roundId), 2 ether);

        vm.expectEmit(true, true, false, true);
        emit UnallocatedRefundCredited(roundId, _sponsor, 2 ether);

        vm.prank(_sponsor);
        uint256 refundAmount = _grantRound.refundUnallocated(roundId);

        assertEq(refundAmount, 2 ether);
        assertEq(_grantRound.pendingWithdrawals(_sponsor), 2 ether);
        assertEq(address(_grantRound).balance, 3 ether);

        vm.prank(_applicant);
        _grantRound.claimPrize(applicationId);
        assertEq(address(_grantRound).balance, 2 ether);
    }

    function test_RefundUnallocated_SecondCallRevertsWhenNoUnallocatedFunds() public {
        (uint256 roundId,) = _selectAndFinalizeOne();
        vm.prank(_sponsor);
        _grantRound.refundUnallocated(roundId);

        vm.prank(_sponsor);
        vm.expectRevert(VigiliaGrantRound.InvalidAmount.selector);
        _grantRound.refundUnallocated(roundId);
    }

    function test_WithdrawPending_TransfersSponsorRefund() public {
        (uint256 roundId,) = _selectAndFinalizeOne();
        vm.prank(_sponsor);
        _grantRound.refundUnallocated(roundId);
        uint256 sponsorBalanceBefore = _sponsor.balance;

        vm.expectEmit(true, true, false, true);
        emit PendingWithdrawalClaimed(_sponsor, _sponsor, 2 ether);

        vm.prank(_sponsor);
        _grantRound.withdrawPending();

        assertEq(_sponsor.balance, sponsorBalanceBefore + 2 ether);
        assertEq(_grantRound.pendingWithdrawals(_sponsor), 0);
    }

    function test_WithdrawPendingTo_WorksWithAlternateRecipient() public {
        (uint256 roundId,) = _selectAndFinalizeOne();
        vm.prank(_sponsor);
        _grantRound.refundUnallocated(roundId);
        uint256 recipientBalanceBefore = _recipient.balance;

        vm.prank(_sponsor);
        _grantRound.withdrawPendingTo(_recipient);

        assertEq(_recipient.balance, recipientBalanceBefore + 2 ether);
        assertEq(_grantRound.pendingWithdrawals(_sponsor), 0);
    }

    function test_CancelRound_SponsorCanCancelUnfundedCreatedRound() public {
        uint256 roundId = _createRound();

        vm.expectEmit(true, false, false, true);
        emit RoundCancelled(roundId, 0);

        vm.prank(_sponsor);
        _grantRound.cancelRound(roundId);

        (,,,,,,,,,,,,,, VigiliaGrantRound.RoundState state) = _grantRound.rounds(roundId);
        assertEq(uint256(state), uint256(VigiliaGrantRound.RoundState.Cancelled));
    }

    function test_CancelRound_SponsorCanCancelFundedOpenRoundWithNoApplications() public {
        uint256 roundId = _createAndFundRound();

        vm.expectEmit(true, false, false, true);
        emit RoundCancelled(roundId, 3 ether);

        vm.prank(_sponsor);
        _grantRound.cancelRound(roundId);

        assertEq(_grantRound.pendingWithdrawals(_sponsor), 3 ether);
    }

    function test_CancelRound_NonSponsorReverts() public {
        uint256 roundId = _createRound();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaGrantRound.Unauthorized.selector, _attacker));
        _grantRound.cancelRound(roundId);
    }

    function test_CancelRound_CannotCancelFinalizedRound() public {
        uint256 roundId = _createAndFundRound();
        vm.warp(_APPLICATION_DEADLINE + 1);
        vm.prank(_judge);
        _grantRound.finalizeRound(roundId);

        vm.prank(_sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(
                VigiliaGrantRound.InvalidState.selector, roundId, VigiliaGrantRound.RoundState.Finalized
            )
        );
        _grantRound.cancelRound(roundId);
    }

    function test_CancelRound_CannotCancelRoundWithApplications() public {
        (uint256 roundId,) = _createFundAndSubmitOne();

        vm.prank(_sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(VigiliaGrantRound.InvalidState.selector, roundId, VigiliaGrantRound.RoundState.Open)
        );
        _grantRound.cancelRound(roundId);
    }

    function test_Accounting_RefundDoesNotStealSelectedButUnclaimedPrizes() public {
        uint256 roundId = _createAndFundRound();
        uint256 app1 = _submitApplication(_applicant, roundId, _EVIDENCE_URI, _EVIDENCE_HASH);
        uint256 app2 = _submitApplication(_applicantTwo, roundId, _EVIDENCE_URI_TWO, _EVIDENCE_HASH_TWO);
        _submitApplication(_applicantThree, roundId, "ipfs://three", keccak256("three"));
        uint256[] memory selectedIds = new uint256[](2);
        selectedIds[0] = app1;
        selectedIds[1] = app2;
        vm.warp(_APPLICATION_DEADLINE + 1);
        vm.prank(_judge);
        _grantRound.selectFinalists(roundId, selectedIds);
        vm.prank(_judge);
        _grantRound.finalizeRound(roundId);

        vm.prank(_sponsor);
        uint256 refundAmount = _grantRound.refundUnallocated(roundId);

        assertEq(refundAmount, 1 ether);
        assertEq(_grantRound.pendingWithdrawals(_sponsor), 1 ether);
        assertEq(address(_grantRound).balance, 3 ether);

        vm.prank(_sponsor);
        _grantRound.withdrawPending();
        assertEq(address(_grantRound).balance, 2 ether);

        vm.prank(_applicant);
        _grantRound.claimPrize(app1);
        assertEq(address(_grantRound).balance, 1 ether);

        vm.prank(_applicantTwo);
        _grantRound.claimPrize(app2);
        assertEq(address(_grantRound).balance, 0);
    }

    function _createRound() private returns (uint256 roundId) {
        roundId = _createRoundWithMode(VigiliaGrantRound.ScreeningMode.TwoAgent);
    }

    function _createRoundWithMode(VigiliaGrantRound.ScreeningMode _screeningMode) private returns (uint256 roundId) {
        vm.prank(_sponsor);
        roundId = _grantRound.createRound(
            _judge,
            _PRIZE_AMOUNT,
            _MAX_WINNERS,
            _APPLICATION_DEADLINE,
            _REVIEW_DEADLINE,
            _REQUIREMENTS_URI,
            _screeningMode
        );
    }

    function _fundRound(uint256 _roundId) private {
        vm.prank(_sponsor);
        _grantRound.fundRound{ value: _PRIZE_AMOUNT * _MAX_WINNERS }(_roundId);
    }

    function _createAndFundRound() private returns (uint256 roundId) {
        roundId = _createRound();
        _fundRound(roundId);
    }

    function _submitApplication(
        address _applicantAddress,
        uint256 _roundId,
        string memory _evidenceURI,
        bytes32 _evidenceHash
    ) private returns (uint256 applicationId) {
        vm.prank(_applicantAddress);
        applicationId = _grantRound.submitApplication(_roundId, _evidenceURI, _evidenceHash);
    }

    function _createFundAndSubmitOne() private returns (uint256 roundId, uint256 applicationId) {
        roundId = _createAndFundRound();
        applicationId = _submitApplication(_applicant, roundId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }

    function _createFundSubmitAndRequest() private returns (uint256 roundId, uint256 applicationId, bytes32 requestId) {
        (roundId, applicationId) = _createFundAndSubmitOne();
        vm.prank(_applicant);
        requestId = _grantRound.requestApplicationScreening(applicationId);
    }

    function _selectAndFinalizeOne() private returns (uint256 roundId, uint256 applicationId) {
        (roundId, applicationId) = _createFundAndSubmitOne();
        vm.warp(_APPLICATION_DEADLINE + 1);
        vm.prank(_judge);
        _grantRound.selectFinalists(roundId, _single(applicationId));
        vm.prank(_judge);
        _grantRound.finalizeRound(roundId);
    }

    function _single(uint256 _value) private pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = _value;
    }
}
