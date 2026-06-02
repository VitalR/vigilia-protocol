// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script, console2 } from "@forge-std/Script.sol";
import { VigiliaAgentTypes } from "../../src/types/VigiliaAgentTypes.sol";
import { VigiliaTypes } from "../../src/types/VigiliaTypes.sol";

interface IVigiliaGrantRoundDemo {
    function createRound(
        address _judge,
        uint256 _prizeAmount,
        uint256 _maxWinners,
        uint64 _applicationDeadline,
        uint64 _reviewDeadline,
        string calldata _requirementsURI,
        uint8 _screeningMode
    ) external returns (uint256 roundId);

    function fundRound(uint256 _roundId) external payable;
    function submitApplication(uint256 _roundId, string calldata _evidenceURI, bytes32 _evidenceHash)
        external
        returns (uint256 applicationId);
    function requestApplicationScreening(uint256 _applicationId) external payable returns (bytes32 requestId);
    function recordManualScreening(
        uint256 _applicationId,
        VigiliaTypes.VerificationVerdict _verdict,
        string calldata _notesURI
    ) external;
    function selectFinalists(uint256 _roundId, uint256[] calldata _applicationIds) external;
    function rejectApplication(uint256 _applicationId, string calldata _reasonURI) external;
    function finalizeRound(uint256 _roundId) external;
    function claimPrize(uint256 _applicationId) external;
    function claimPrizeTo(uint256 _applicationId, address payable _recipient) external;
    function refundUnallocated(uint256 _roundId) external returns (uint256 refundAmount);
    function withdrawPending() external;
    function withdrawPendingTo(address payable _recipient) external;
    function cancelRound(uint256 _roundId) external;
    function requiredFunding(uint256 _roundId) external view returns (uint256 amount);
    function selectedAllocation(uint256 _roundId) external view returns (uint256 amount);
    function unallocatedAmount(uint256 _roundId) external view returns (uint256 amount);
    function getRoundApplications(uint256 _roundId) external view returns (uint256[] memory applicationIds);
    function canSelectApplication(uint256 _applicationId) external view returns (bool eligible);
    function nextRoundId() external view returns (uint256);
    function nextApplicationId() external view returns (uint256);
    function verifier() external view returns (address);
    function pendingWithdrawals(address _account) external view returns (uint256 amount);
    function rounds(uint256 _roundId)
        external
        view
        returns (
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
            uint8 screeningMode,
            uint8 state
        );
    function applications(uint256 _applicationId)
        external
        view
        returns (
            uint256 roundId,
            address applicant,
            string memory evidenceURI,
            bytes32 evidenceHash,
            bytes32 requestId,
            VigiliaTypes.VerificationVerdict verdict,
            uint8 status,
            bool selected,
            bool claimed,
            uint64 submittedAt,
            uint64 reviewedAt,
            string memory notesURI
        );
}

interface IVigiliaGrantRoundVerifierDemo {
    function escrow() external view returns (address);
    function minimumRequestDepositForWorkflow(VigiliaAgentTypes.SettlementWorkflow _workflow)
        external
        view
        returns (uint256);
}

/// @title VigiliaGrantRoundDemo
/// @notice Configurable Somnia testnet runner for GrantRound campaign demos.
/// @dev Each run executes one `DEMO_ACTION`. Agent callbacks are asynchronous; request screening, wait for callbacks,
/// then inspect/select/finalize in later runs.
contract VigiliaGrantRoundDemo is Script {
    error MissingEnv(string name);
    error UnsupportedDemoAction(string action);
    error InvalidVerifierBinding(address expectedGrantRound, address actualGrantRound);
    error InvalidCsv(string value);
    error InvalidApplicantIndex(uint256 index);
    error EmptyApplicationIds();
    error NoConfiguredApplicantKey(address applicant);

    struct DemoConfig {
        uint256 deployerPrivateKey;
        uint256 sponsorPrivateKey;
        uint256 judgePrivateKey;
        uint256 applicantPrivateKey;
        uint256 applicantOnePrivateKey;
        uint256 applicantTwoPrivateKey;
        uint256 applicantThreePrivateKey;
        uint256 applicantFourPrivateKey;
        address grantRoundAddress;
        address verifierAddress;
        string action;
    }

    struct RoundView {
        address sponsor;
        address judge;
        uint256 prizeAmount;
        uint256 maxWinners;
        uint256 totalFunded;
        uint256 selectedCount;
        uint256 claimedCount;
        uint256 totalClaimed;
        uint256 totalRefunded;
        uint256 applicationsCount;
        uint64 applicationDeadline;
        uint64 reviewDeadline;
        string requirementsURI;
        uint8 screeningMode;
        uint8 state;
    }

    struct ApplicationView {
        uint256 roundId;
        address applicant;
        string evidenceURI;
        bytes32 evidenceHash;
        bytes32 requestId;
        VigiliaTypes.VerificationVerdict verdict;
        uint8 status;
        bool selected;
        bool claimed;
        uint64 submittedAt;
        uint64 reviewedAt;
        string notesURI;
    }

    function run() external {
        DemoConfig memory config = _loadConfig();
        IVigiliaGrantRoundDemo grantRound = IVigiliaGrantRoundDemo(config.grantRoundAddress);
        IVigiliaGrantRoundVerifierDemo verifier = IVigiliaGrantRoundVerifierDemo(config.verifierAddress);

        _assertVerifierBinding(config.grantRoundAddress, grantRound, verifier);

        bytes32 actionHash = keccak256(bytes(config.action));
        if (actionHash == keccak256("inspect")) {
            _inspect(config, grantRound, verifier);
        } else if (actionHash == keccak256("create-round")) {
            _createRound(config, grantRound);
        } else if (actionHash == keccak256("fund-round")) {
            _fundRound(config, grantRound);
        } else if (actionHash == keccak256("submit-application")) {
            (uint256 applicantKey, string memory applicantLabel) =
                _selectedApplicantKey(config, config.applicantPrivateKey, "APPLICANT_PRIVATE_KEY");
            _warnIfSingleWalletApplicant(applicantLabel, applicantKey, config);
            _submitApplication(grantRound, _evidenceURIFromEnv("GRANT_EVIDENCE_URI"), applicantKey, applicantLabel);
        } else if (actionHash == keccak256("submit-application-complete")) {
            (uint256 applicantKey, string memory applicantLabel) =
                _selectedApplicantKey(config, config.applicantOnePrivateKey, "APPLICANT_ONE_PRIVATE_KEY");
            _warnIfSingleWalletApplicant(applicantLabel, applicantKey, config);
            _submitApplication(
                grantRound, _scenarioEvidenceURI("GRANT_COMPLETE_EVIDENCE_URI"), applicantKey, applicantLabel
            );
        } else if (actionHash == keccak256("submit-application-needs-review")) {
            (uint256 applicantKey, string memory applicantLabel) =
                _selectedApplicantKey(config, config.applicantTwoPrivateKey, "APPLICANT_TWO_PRIVATE_KEY");
            _warnIfSingleWalletApplicant(applicantLabel, applicantKey, config);
            _submitApplication(
                grantRound, _scenarioEvidenceURI("GRANT_NEEDS_REVIEW_EVIDENCE_URI"), applicantKey, applicantLabel
            );
        } else if (actionHash == keccak256("submit-application-incomplete")) {
            (uint256 applicantKey, string memory applicantLabel) =
                _selectedApplicantKey(config, config.applicantFourPrivateKey, "APPLICANT_FOUR_PRIVATE_KEY");
            _warnIfSingleWalletApplicant(applicantLabel, applicantKey, config);
            _submitApplication(
                grantRound, _scenarioEvidenceURI("GRANT_INCOMPLETE_EVIDENCE_URI"), applicantKey, applicantLabel
            );
        } else if (actionHash == keccak256("submit-application-malformed")) {
            (uint256 applicantKey, string memory applicantLabel) =
                _selectedApplicantKey(config, config.applicantFourPrivateKey, "APPLICANT_FOUR_PRIVATE_KEY");
            _warnIfSingleWalletApplicant(applicantLabel, applicantKey, config);
            _submitApplication(
                grantRound, _scenarioEvidenceURI("GRANT_MALFORMED_EVIDENCE_URI"), applicantKey, applicantLabel
            );
        } else if (actionHash == keccak256("request-screening")) {
            (uint256 requesterKey, string memory requesterLabel) =
                _selectedApplicantKey(config, config.applicantPrivateKey, "APPLICANT_PRIVATE_KEY");
            _requestScreening(config, grantRound, requesterKey, requesterLabel);
        } else if (actionHash == keccak256("request-screening-complete")) {
            (uint256 requesterKey, string memory requesterLabel) =
                _selectedApplicantKey(config, config.applicantOnePrivateKey, "APPLICANT_ONE_PRIVATE_KEY");
            _requestScreening(config, grantRound, requesterKey, requesterLabel);
        } else if (actionHash == keccak256("request-screening-needs-review")) {
            (uint256 requesterKey, string memory requesterLabel) =
                _selectedApplicantKey(config, config.applicantTwoPrivateKey, "APPLICANT_TWO_PRIVATE_KEY");
            _requestScreening(config, grantRound, requesterKey, requesterLabel);
        } else if (actionHash == keccak256("request-screening-incomplete")) {
            (uint256 requesterKey, string memory requesterLabel) =
                _selectedApplicantKey(config, config.applicantFourPrivateKey, "APPLICANT_FOUR_PRIVATE_KEY");
            _requestScreening(config, grantRound, requesterKey, requesterLabel);
        } else if (actionHash == keccak256("request-screening-malformed")) {
            (uint256 requesterKey, string memory requesterLabel) =
                _selectedApplicantKey(config, config.applicantFourPrivateKey, "APPLICANT_FOUR_PRIVATE_KEY");
            _requestScreening(config, grantRound, requesterKey, requesterLabel);
        } else if (actionHash == keccak256("manual-screen-complete")) {
            _manualScreen(config, grantRound, VigiliaTypes.VerificationVerdict.Complete);
        } else if (actionHash == keccak256("manual-screen-needs-review")) {
            _manualScreen(config, grantRound, VigiliaTypes.VerificationVerdict.NeedsReview);
        } else if (actionHash == keccak256("manual-screen-incomplete")) {
            _manualScreen(config, grantRound, VigiliaTypes.VerificationVerdict.Incomplete);
        } else if (actionHash == keccak256("select-finalists")) {
            _selectFinalists(config, grantRound);
        } else if (actionHash == keccak256("reject-application")) {
            _rejectApplication(config, grantRound);
        } else if (actionHash == keccak256("finalize-round")) {
            _finalizeRound(config, grantRound);
        } else if (actionHash == keccak256("claim-prize")) {
            _claimPrize(config, grantRound);
        } else if (actionHash == keccak256("refund-unallocated")) {
            _refundUnallocated(config, grantRound);
        } else if (actionHash == keccak256("withdraw-pending")) {
            _withdrawPending(config, grantRound);
        } else if (actionHash == keccak256("cancel-round")) {
            _cancelRound(config, grantRound);
        } else if (actionHash == keccak256("full-two-agent-happy-path-prep")) {
            _fullTwoAgentHappyPathPrep(config, grantRound);
        } else if (actionHash == keccak256("full-two-agent-review-board-prep")) {
            _fullTwoAgentReviewBoardPrep(config, grantRound);
        } else {
            revert UnsupportedDemoAction(config.action);
        }
    }

    function _loadConfig() private view returns (DemoConfig memory config) {
        config.deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0));
        config.sponsorPrivateKey = _optionalUint("SPONSOR_PRIVATE_KEY", config.deployerPrivateKey);
        config.judgePrivateKey = _optionalUint("JUDGE_PRIVATE_KEY", config.sponsorPrivateKey);
        config.applicantPrivateKey = _optionalUint("APPLICANT_PRIVATE_KEY", config.deployerPrivateKey);
        config.applicantOnePrivateKey = _optionalUint("APPLICANT_ONE_PRIVATE_KEY", config.deployerPrivateKey);
        config.applicantTwoPrivateKey = _optionalUint("APPLICANT_TWO_PRIVATE_KEY", config.deployerPrivateKey);
        config.applicantThreePrivateKey = _optionalUint("APPLICANT_THREE_PRIVATE_KEY", config.deployerPrivateKey);
        config.applicantFourPrivateKey = _optionalUint("APPLICANT_FOUR_PRIVATE_KEY", config.deployerPrivateKey);
        config.grantRoundAddress = vm.envAddress("VIGILIA_GRANT_ROUND");
        config.verifierAddress = vm.envAddress("VIGILIA_GRANT_ROUND_VERIFIER");
        config.action = vm.envString("DEMO_ACTION");
    }

    function _assertVerifierBinding(
        address _expectedGrantRound,
        IVigiliaGrantRoundDemo _grantRound,
        IVigiliaGrantRoundVerifierDemo _verifier
    ) private view {
        address boundGrantRound = _verifier.escrow();
        if (boundGrantRound != _expectedGrantRound) {
            revert InvalidVerifierBinding(_expectedGrantRound, boundGrantRound);
        }
        address configuredVerifier = _grantRound.verifier();
        if (configuredVerifier != address(_verifier)) {
            revert InvalidVerifierBinding(address(_verifier), configuredVerifier);
        }
    }

    function _createRound(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound)
        private
        returns (uint256 roundId)
    {
        address judge = _optionalAddress("GRANT_JUDGE", vm.addr(_config.judgePrivateKey));
        uint256 prizeAmount = vm.envOr("GRANT_PRIZE_AMOUNT_WEI", uint256(1 ether));
        uint256 maxWinners = vm.envOr("GRANT_MAX_WINNERS", uint256(3));
        bool fastDeadlines = vm.envOr("GRANT_FAST_DEADLINES", false);
        uint256 applicationWindow = fastDeadlines
            ? vm.envOr("GRANT_FAST_APPLICATION_WINDOW_SECONDS", uint256(300))
            : vm.envOr("GRANT_APPLICATION_WINDOW_SECONDS", uint256(300));
        uint256 reviewWindow = fastDeadlines
            ? vm.envOr("GRANT_FAST_REVIEW_WINDOW_SECONDS", uint256(900))
            : vm.envOr("GRANT_REVIEW_WINDOW_SECONDS", uint256(600));
        string memory requirementsURI =
            vm.envOr("GRANT_REQUIREMENTS_URI", string("https://example.com/vigilia/grant-requirements.md"));
        uint8 screeningMode = uint8(vm.envOr("GRANT_SCREENING_MODE", uint256(0)));
        uint64 applicationDeadline = uint64(block.timestamp + applicationWindow);
        uint64 reviewDeadline = uint64(uint256(applicationDeadline) + reviewWindow);
        uint256 predictedRoundId = _grantRound.nextRoundId();

        vm.startBroadcast(_config.sponsorPrivateKey);
        roundId = _grantRound.createRound(
            judge, prizeAmount, maxWinners, applicationDeadline, reviewDeadline, requirementsURI, screeningMode
        );
        vm.stopBroadcast();

        console2.log("created roundId", roundId);
        console2.log("predictedRoundId", predictedRoundId);
        console2.log("sponsor", vm.addr(_config.sponsorPrivateKey));
        console2.log("judge", judge);
        console2.log("screeningMode", _screeningModeName(screeningMode));
        console2.log("prizeAmountWei", prizeAmount);
        console2.log("maxWinners", maxWinners);
        console2.log("requiredFundingWei", prizeAmount * maxWinners);
        console2.log("applicationDeadline", applicationDeadline);
        console2.log("reviewDeadline", reviewDeadline);
        console2.log("next: export GRANT_ROUND_ID=%s", vm.toString(roundId));
        console2.log("next: make grant-demo-fund-round");
    }

    function _fundRound(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 roundId = _roundIdFromEnv();
        uint256 requiredFunding = _grantRound.requiredFunding(roundId);

        vm.startBroadcast(_config.sponsorPrivateKey);
        _grantRound.fundRound{ value: requiredFunding }(roundId);
        vm.stopBroadcast();

        console2.log("funded roundId", roundId);
        console2.log("amountWei", requiredFunding);
        console2.log("next: submit applications with public evidence URLs");
    }

    function _submitApplication(
        IVigiliaGrantRoundDemo _grantRound,
        string memory _evidenceURI,
        uint256 _applicantPrivateKey,
        string memory _applicantLabel
    ) private {
        uint256 roundId = _roundIdFromEnv();
        _submitApplicationForRound(_grantRound, roundId, _evidenceURI, _applicantPrivateKey, _applicantLabel);
    }

    function _submitApplicationForRound(
        IVigiliaGrantRoundDemo _grantRound,
        uint256 _roundId,
        string memory _evidenceURI,
        uint256 _applicantPrivateKey,
        string memory _applicantLabel
    ) private returns (uint256 applicationId) {
        bytes32 evidenceHash = _optionalBytes32("GRANT_EVIDENCE_HASH", keccak256(bytes(_evidenceURI)));
        uint256 predictedApplicationId = _grantRound.nextApplicationId();

        vm.startBroadcast(_applicantPrivateKey);
        applicationId = _grantRound.submitApplication(_roundId, _evidenceURI, evidenceHash);
        vm.stopBroadcast();

        console2.log("submitted applicationId", applicationId);
        console2.log("predictedApplicationId", predictedApplicationId);
        console2.log("roundId", _roundId);
        console2.log("applicant", vm.addr(_applicantPrivateKey));
        console2.log("applicantKey", _applicantLabel);
        console2.log("evidenceURI", _evidenceURI);
        console2.logBytes32(evidenceHash);
        console2.log("next: export GRANT_APPLICATION_ID=%s", vm.toString(applicationId));
        console2.log("next: make grant-demo-request-screening");
    }

    function _requestScreening(
        DemoConfig memory,
        IVigiliaGrantRoundDemo _grantRound,
        uint256 _requesterPrivateKey,
        string memory _requesterLabel
    ) private {
        uint256 applicationId = _applicationIdFromEnv();
        uint256 deposit = vm.envUint("GRANT_ROUND_WORKFLOW_DEPOSIT_WEI");

        vm.startBroadcast(_requesterPrivateKey);
        bytes32 requestId = _grantRound.requestApplicationScreening{ value: deposit }(applicationId);
        vm.stopBroadcast();

        console2.log("screening requested applicationId", applicationId);
        console2.log("workflow", "TwoAgent / JsonFactsToLlmVerdict");
        console2.log("requester", vm.addr(_requesterPrivateKey));
        console2.log("requesterKey", _requesterLabel);
        console2.log("verificationDepositWei", deposit);
        console2.logBytes32(requestId);
        console2.log("Somnia callbacks are async. Wait, then inspect:");
        console2.log("next: make grant-demo-inspect GRANT_APPLICATION_ID=%s", vm.toString(applicationId));
    }

    function _manualScreen(
        DemoConfig memory _config,
        IVigiliaGrantRoundDemo _grantRound,
        VigiliaTypes.VerificationVerdict _verdict
    ) private {
        uint256 applicationId = _applicationIdFromEnv();
        string memory notesURI = vm.envOr("GRANT_NOTES_URI", string("ipfs://grant-round/manual-fallback-review"));

        console2.log("manual screening is fallback/recovery only; it is not the primary Somnia-powered flow");
        vm.startBroadcast(_config.judgePrivateKey);
        _grantRound.recordManualScreening(applicationId, _verdict, notesURI);
        vm.stopBroadcast();

        console2.log("manual screening recorded applicationId", applicationId);
        console2.log("verdict", _verdictName(uint8(_verdict)));
        console2.log("notesURI", notesURI);
    }

    function _selectFinalists(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 roundId = _roundIdFromEnv();
        uint256[] memory applicationIds = _applicationIdsFromEnv();

        vm.startBroadcast(_config.judgePrivateKey);
        _grantRound.selectFinalists(roundId, applicationIds);
        vm.stopBroadcast();

        console2.log("selected finalists roundId", roundId);
        console2.log("selectedCountInThisCall", applicationIds.length);
        console2.log("selectedAllocationWei", _grantRound.selectedAllocation(roundId));
        console2.log("next: make grant-demo-finalize-round");
    }

    function _rejectApplication(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 applicationId = _applicationIdFromEnv();
        string memory reasonURI = vm.envOr("GRANT_NOTES_URI", string("ipfs://grant-round/rejection-notes"));

        vm.startBroadcast(_config.judgePrivateKey);
        _grantRound.rejectApplication(applicationId, reasonURI);
        vm.stopBroadcast();

        console2.log("rejected applicationId", applicationId);
        console2.log("reasonURI", reasonURI);
    }

    function _finalizeRound(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 roundId = _roundIdFromEnv();

        vm.startBroadcast(_config.judgePrivateKey);
        _grantRound.finalizeRound(roundId);
        vm.stopBroadcast();

        console2.log("finalized roundId", roundId);
        console2.log("claims are now enabled for selected finalists");
    }

    function _claimPrize(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 applicationId = _applicationIdFromEnv();
        address recipient = _optionalAddress("GRANT_PRIZE_RECIPIENT", address(0));
        ApplicationView memory application = _applicationView(_grantRound, applicationId);
        (uint256 applicantKey, string memory applicantLabel) =
            _configuredKeyForApplicant(_config, application.applicant);

        vm.startBroadcast(applicantKey);
        if (recipient == address(0)) {
            _grantRound.claimPrize(applicationId);
            recipient = vm.addr(applicantKey);
        } else {
            _grantRound.claimPrizeTo(applicationId, payable(recipient));
        }
        vm.stopBroadcast();

        console2.log("claimed applicationId", applicationId);
        console2.log("applicant", application.applicant);
        console2.log("matchedApplicantKey", applicantLabel);
        console2.log("recipient", recipient);
    }

    function _refundUnallocated(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 roundId = _roundIdFromEnv();

        vm.startBroadcast(_config.sponsorPrivateKey);
        uint256 refundAmount = _grantRound.refundUnallocated(roundId);
        vm.stopBroadcast();

        console2.log("credited unallocated refund roundId", roundId);
        console2.log("refundAmountWei", refundAmount);
        console2.log("next: make grant-demo-withdraw-pending");
    }

    function _withdrawPending(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        address recipient = _optionalAddress("GRANT_REFUND_RECIPIENT", address(0));

        vm.startBroadcast(_config.sponsorPrivateKey);
        if (recipient == address(0)) {
            _grantRound.withdrawPending();
            recipient = vm.addr(_config.sponsorPrivateKey);
        } else {
            _grantRound.withdrawPendingTo(payable(recipient));
        }
        vm.stopBroadcast();

        console2.log("withdrew pending refund");
        console2.log("recipient", recipient);
    }

    function _cancelRound(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 roundId = _roundIdFromEnv();

        vm.startBroadcast(_config.sponsorPrivateKey);
        _grantRound.cancelRound(roundId);
        vm.stopBroadcast();

        console2.log("cancelled roundId", roundId);
    }

    function _fullTwoAgentHappyPathPrep(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        _createRound(configWithAction(_config, "create-round"), _grantRound);
        console2.log(
            "Grouped prep created the round only. Fund and submit/request in separate commands for clean logs."
        );
    }

    function _fullTwoAgentReviewBoardPrep(DemoConfig memory _config, IVigiliaGrantRoundDemo _grantRound) private {
        uint256 roundId = _createRound(configWithAction(_config, "create-round"), _grantRound);
        uint256 requiredFunding = _grantRound.requiredFunding(roundId);

        vm.startBroadcast(_config.sponsorPrivateKey);
        _grantRound.fundRound{ value: requiredFunding }(roundId);
        vm.stopBroadcast();

        console2.log("review-board prep funded roundId", roundId);
        console2.log("requiredFundingWei", requiredFunding);

        _warnIfSingleWalletApplicant("APPLICANT_ONE_PRIVATE_KEY", _config.applicantOnePrivateKey, _config);
        uint256 completeAppId = _submitApplicationForRound(
            _grantRound,
            roundId,
            _scenarioEvidenceURI("GRANT_COMPLETE_EVIDENCE_URI"),
            _config.applicantOnePrivateKey,
            "APPLICANT_ONE_PRIVATE_KEY"
        );

        _warnIfSingleWalletApplicant("APPLICANT_TWO_PRIVATE_KEY", _config.applicantTwoPrivateKey, _config);
        uint256 needsReviewAppId = _submitApplicationForRound(
            _grantRound,
            roundId,
            _scenarioEvidenceURI("GRANT_NEEDS_REVIEW_EVIDENCE_URI"),
            _config.applicantTwoPrivateKey,
            "APPLICANT_TWO_PRIVATE_KEY"
        );

        _warnIfSingleWalletApplicant("APPLICANT_THREE_PRIVATE_KEY", _config.applicantThreePrivateKey, _config);
        uint256 secondCompleteAppId = _submitApplicationForRound(
            _grantRound,
            roundId,
            _scenarioEvidenceURI("GRANT_COMPLETE_EVIDENCE_URI"),
            _config.applicantThreePrivateKey,
            "APPLICANT_THREE_PRIVATE_KEY"
        );

        _warnIfSingleWalletApplicant("APPLICANT_FOUR_PRIVATE_KEY", _config.applicantFourPrivateKey, _config);
        uint256 incompleteAppId = _submitApplicationForRound(
            _grantRound,
            roundId,
            _scenarioEvidenceURI("GRANT_INCOMPLETE_EVIDENCE_URI"),
            _config.applicantFourPrivateKey,
            "APPLICANT_FOUR_PRIVATE_KEY"
        );

        console2.log("review-board prep submitted four applications");
        console2.log("COMPLETE_APP_ID", completeAppId);
        console2.log("NEEDS_REVIEW_APP_ID", needsReviewAppId);
        console2.log("COMPLETE_APP_ID_2", secondCompleteAppId);
        console2.log("INCOMPLETE_APP_ID", incompleteAppId);
        console2.log("next: request screening per application; callbacks are async");
    }

    function configWithAction(DemoConfig memory _config, string memory _action)
        private
        pure
        returns (DemoConfig memory config)
    {
        config = _config;
        config.action = _action;
    }

    function _inspect(
        DemoConfig memory _config,
        IVigiliaGrantRoundDemo _grantRound,
        IVigiliaGrantRoundVerifierDemo _verifier
    ) private view {
        console2.log("GrantRound", _config.grantRoundAddress);
        console2.log("Verifier", _config.verifierAddress);
        console2.log("verifier.escrow", _verifier.escrow());
        console2.log("grantRound.verifier", _grantRound.verifier());
        console2.log("threeAgentRequestPath", "gated until verifier exposes Website Parse workflow proof");
        try _verifier.minimumRequestDepositForWorkflow(
            VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict
        ) returns (
            uint256 deposit
        ) {
            console2.log("minimumRequestDepositForWorkflow(3)", deposit);
        } catch {
            console2.log("minimumRequestDepositForWorkflow(3) unavailable in local script simulation");
            console2.log(
                "configuredGrantRoundWorkflowDepositWei", vm.envOr("GRANT_ROUND_WORKFLOW_DEPOSIT_WEI", uint256(0))
            );
        }
        _logRole("sponsor", _config.sponsorPrivateKey);
        _logRole("judge", _config.judgePrivateKey);
        _logRole("applicant", _config.applicantPrivateKey);
        if (_config.sponsorPrivateKey != 0) {
            console2.log("pendingSponsorWithdrawal", _grantRound.pendingWithdrawals(vm.addr(_config.sponsorPrivateKey)));
        }

        uint256 roundId = _optionalEnvUint("GRANT_ROUND_ID", 0);
        if (roundId != 0) _inspectRound(_grantRound, roundId);

        uint256 applicationId = _optionalEnvUint("GRANT_APPLICATION_ID", 0);
        if (applicationId != 0) _inspectApplication(_grantRound, applicationId);
    }

    function _inspectRound(IVigiliaGrantRoundDemo _grantRound, uint256 _roundId) private view {
        RoundView memory round = _roundView(_grantRound, _roundId);
        console2.log("roundId", _roundId);
        console2.log("round.state", _roundStateName(round.state));
        console2.log("round.stateIndex", round.state);
        console2.log("round.sponsor", round.sponsor);
        console2.log("round.judge", round.judge);
        console2.log("round.prizeAmount", round.prizeAmount);
        console2.log("round.maxWinners", round.maxWinners);
        console2.log("round.totalFunded", round.totalFunded);
        console2.log("round.selectedCount", round.selectedCount);
        console2.log("round.claimedCount", round.claimedCount);
        console2.log("round.totalClaimed", round.totalClaimed);
        console2.log("round.totalRefunded", round.totalRefunded);
        console2.log("round.applicationsCount", round.applicationsCount);
        console2.log("round.applicationDeadline", round.applicationDeadline);
        console2.log("round.reviewDeadline", round.reviewDeadline);
        console2.log("round.requirementsURI", round.requirementsURI);
        console2.log("round.screeningMode", _screeningModeName(round.screeningMode));
        console2.log("round.screeningModeIndex", round.screeningMode);
        if (round.screeningMode == 0) {
            console2.log("round.screeningModeStatus", "current proven fallback: JsonFactsToLlmVerdict");
        } else if (round.screeningMode == 1) {
            console2.log("round.screeningModeStatus", "gated: Website Parse workflow is not live in this verifier");
        }
        console2.log("requiredFunding", _grantRound.requiredFunding(_roundId));
        console2.log("selectedAllocation", _grantRound.selectedAllocation(_roundId));
        console2.log("unallocatedAmount", _grantRound.unallocatedAmount(_roundId));

        uint256[] memory applicationIds = _grantRound.getRoundApplications(_roundId);
        console2.log("round.applicationIds.length", applicationIds.length);
        for (uint256 i = 0; i < applicationIds.length; i++) {
            console2.log("round.applicationId", applicationIds[i]);
        }
    }

    function _inspectApplication(IVigiliaGrantRoundDemo _grantRound, uint256 _applicationId) private view {
        ApplicationView memory application = _applicationView(_grantRound, _applicationId);
        console2.log("applicationId", _applicationId);
        console2.log("application.roundId", application.roundId);
        console2.log("application.applicant", application.applicant);
        console2.log("application.evidenceURI", application.evidenceURI);
        console2.logBytes32(application.evidenceHash);
        console2.logBytes32(application.requestId);
        console2.log("application.verdict", _verdictName(uint8(application.verdict)));
        console2.log("application.verdictIndex", uint8(application.verdict));
        console2.log("application.status", _applicationStatusName(application.status));
        console2.log("application.statusIndex", application.status);
        console2.log("application.selected", application.selected);
        console2.log("application.claimed", application.claimed);
        console2.log("application.submittedAt", application.submittedAt);
        console2.log("application.reviewedAt", application.reviewedAt);
        console2.log("application.notesURI", application.notesURI);
        console2.log("application.canSelect", _grantRound.canSelectApplication(_applicationId));
    }

    function _roundView(IVigiliaGrantRoundDemo _grantRound, uint256 _roundId)
        private
        view
        returns (RoundView memory round)
    {
        (
            round.sponsor,
            round.judge,
            round.prizeAmount,
            round.maxWinners,
            round.totalFunded,
            round.selectedCount,
            round.claimedCount,
            round.totalClaimed,
            round.totalRefunded,
            round.applicationsCount,
            round.applicationDeadline,
            round.reviewDeadline,
            round.requirementsURI,
            round.screeningMode,
            round.state
        ) = _grantRound.rounds(_roundId);
    }

    function _applicationView(IVigiliaGrantRoundDemo _grantRound, uint256 _applicationId)
        private
        view
        returns (ApplicationView memory application)
    {
        (
            application.roundId,
            application.applicant,
            application.evidenceURI,
            application.evidenceHash,
            application.requestId,
            application.verdict,
            application.status,
            application.selected,
            application.claimed,
            application.submittedAt,
            application.reviewedAt,
            application.notesURI
        ) = _grantRound.applications(_applicationId);
    }

    function _roundIdFromEnv() private view returns (uint256 roundId) {
        roundId = vm.envUint("GRANT_ROUND_ID");
    }

    function _applicationIdFromEnv() private view returns (uint256 applicationId) {
        applicationId = vm.envUint("GRANT_APPLICATION_ID");
    }

    function _applicationIdsFromEnv() private view returns (uint256[] memory applicationIds) {
        string memory csv = vm.envString("GRANT_APPLICATION_IDS");
        bytes memory data = bytes(csv);
        if (data.length == 0) revert EmptyApplicationIds();

        uint256 count = 1;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == ",") count++;
        }

        applicationIds = new uint256[](count);
        uint256 cursor;
        uint256 value;
        bool hasDigit;
        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == ",") {
                if (!hasDigit) revert InvalidCsv(csv);
                applicationIds[cursor++] = value;
                value = 0;
                hasDigit = false;
            } else if (uint8(data[i]) >= 48 && uint8(data[i]) <= 57) {
                value = value * 10 + uint256(uint8(data[i]) - 48);
                hasDigit = true;
            } else {
                revert InvalidCsv(csv);
            }
        }
    }

    function _evidenceURIFromEnv(string memory _name) private view returns (string memory evidenceURI) {
        evidenceURI = vm.envString(_name);
        if (bytes(evidenceURI).length == 0) revert MissingEnv(_name);
    }

    function _scenarioEvidenceURI(string memory _specificName) private view returns (string memory evidenceURI) {
        evidenceURI = vm.envOr(_specificName, string(""));
        if (bytes(evidenceURI).length == 0) {
            evidenceURI = vm.envOr("GRANT_EVIDENCE_URI", string(""));
            console2.log("scenario evidence URL missing; falling back to GRANT_EVIDENCE_URI");
            console2.log("missingEnv", _specificName);
        }
        if (bytes(evidenceURI).length == 0) revert MissingEnv(_specificName);
    }

    function _optionalUint(string memory _name, uint256 _fallback) private view returns (uint256 value) {
        value = vm.envOr(_name, _fallback);
        if (value == 0) value = _fallback;
    }

    function _optionalEnvUint(string memory _name, uint256 _fallback) private view returns (uint256 value) {
        value = vm.envOr(_name, _fallback);
    }

    function _optionalAddress(string memory _name, address _fallback) private view returns (address value) {
        value = vm.envOr(_name, _fallback);
        if (value == address(0)) value = _fallback;
    }

    function _optionalBytes32(string memory _name, bytes32 _fallback) private view returns (bytes32 value) {
        value = vm.envOr(_name, _fallback);
        if (value == bytes32(0)) value = _fallback;
    }

    function _selectedApplicantKey(DemoConfig memory _config, uint256 _defaultPrivateKey, string memory _defaultLabel)
        private
        view
        returns (uint256 privateKey, string memory label)
    {
        uint256 applicantIndex = vm.envOr("GRANT_APPLICANT_INDEX", uint256(0));
        if (applicantIndex == 0) return (_defaultPrivateKey, _defaultLabel);
        return _applicantKeyFromIndex(_config, applicantIndex);
    }

    function _applicantKeyFromIndex(DemoConfig memory _config, uint256 _index)
        private
        pure
        returns (uint256 privateKey, string memory label)
    {
        if (_index == 1) return (_config.applicantOnePrivateKey, "APPLICANT_ONE_PRIVATE_KEY");
        if (_index == 2) return (_config.applicantTwoPrivateKey, "APPLICANT_TWO_PRIVATE_KEY");
        if (_index == 3) return (_config.applicantThreePrivateKey, "APPLICANT_THREE_PRIVATE_KEY");
        if (_index == 4) return (_config.applicantFourPrivateKey, "APPLICANT_FOUR_PRIVATE_KEY");
        revert InvalidApplicantIndex(_index);
    }

    function _configuredKeyForApplicant(DemoConfig memory _config, address _applicant)
        private
        pure
        returns (uint256 privateKey, string memory label)
    {
        if (_config.applicantPrivateKey != 0 && vm.addr(_config.applicantPrivateKey) == _applicant) {
            return (_config.applicantPrivateKey, "APPLICANT_PRIVATE_KEY");
        }
        if (_config.applicantOnePrivateKey != 0 && vm.addr(_config.applicantOnePrivateKey) == _applicant) {
            return (_config.applicantOnePrivateKey, "APPLICANT_ONE_PRIVATE_KEY");
        }
        if (_config.applicantTwoPrivateKey != 0 && vm.addr(_config.applicantTwoPrivateKey) == _applicant) {
            return (_config.applicantTwoPrivateKey, "APPLICANT_TWO_PRIVATE_KEY");
        }
        if (_config.applicantThreePrivateKey != 0 && vm.addr(_config.applicantThreePrivateKey) == _applicant) {
            return (_config.applicantThreePrivateKey, "APPLICANT_THREE_PRIVATE_KEY");
        }
        if (_config.applicantFourPrivateKey != 0 && vm.addr(_config.applicantFourPrivateKey) == _applicant) {
            return (_config.applicantFourPrivateKey, "APPLICANT_FOUR_PRIVATE_KEY");
        }
        if (_config.deployerPrivateKey != 0 && vm.addr(_config.deployerPrivateKey) == _applicant) {
            return (_config.deployerPrivateKey, "DEPLOYER_PRIVATE_KEY");
        }
        revert NoConfiguredApplicantKey(_applicant);
    }

    function _warnIfSingleWalletApplicant(string memory _envName, uint256 _applicantKey, DemoConfig memory _config)
        private
        pure
    {
        if (_applicantKey == _config.deployerPrivateKey) {
            console2.log("warning: applicant role fell back to DEPLOYER_PRIVATE_KEY for smoke testing");
            console2.log("set a separate key for real demos", _envName);
        }
    }

    function _logRole(string memory _label, uint256 _privateKey) private pure {
        if (_privateKey == 0) {
            console2.log(_label, "not configured");
            return;
        }
        console2.log(_label, vm.addr(_privateKey));
    }

    function _roundStateName(uint8 _state) private pure returns (string memory name) {
        if (_state == 0) return "None";
        if (_state == 1) return "Created";
        if (_state == 2) return "Open";
        if (_state == 3) return "Review";
        if (_state == 4) return "Finalized";
        if (_state == 5) return "Cancelled";
        return "Unknown";
    }

    function _applicationStatusName(uint8 _status) private pure returns (string memory name) {
        if (_status == 0) return "None";
        if (_status == 1) return "Submitted";
        if (_status == 2) return "ScreeningRequested";
        if (_status == 3) return "Complete";
        if (_status == 4) return "NeedsReview";
        if (_status == 5) return "Incomplete";
        if (_status == 6) return "VerificationFailed";
        if (_status == 7) return "Selected";
        if (_status == 8) return "Rejected";
        if (_status == 9) return "Claimed";
        return "Unknown";
    }

    function _screeningModeName(uint8 _mode) private pure returns (string memory name) {
        if (_mode == 0) return "TwoAgent";
        if (_mode == 1) return "ThreeAgent";
        return "Unknown";
    }

    function _verdictName(uint8 _verdict) private pure returns (string memory name) {
        if (_verdict == 0) return "Unknown";
        if (_verdict == 1) return "Complete";
        if (_verdict == 2) return "NeedsReview";
        if (_verdict == 3) return "Incomplete";
        return "Unknown";
    }
}
