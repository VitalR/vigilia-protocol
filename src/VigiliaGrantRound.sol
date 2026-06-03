// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IVigiliaEscrowVerdictReceiver } from "./interfaces/IVigiliaEscrowVerdictReceiver.sol";
import { IVigiliaVerifier } from "./interfaces/IVigiliaVerifier.sol";
import { VigiliaAgentTypes } from "./types/VigiliaAgentTypes.sol";
import { VigiliaTypes } from "./types/VigiliaTypes.sol";

/// @title VigiliaGrantRound
/// @notice Native-token grant and bounty round module with Somnia-agent screening and manual finalist selection.
/// @dev Round funds are controlled only by the round state machine. Agent callbacks record screening metadata but never
/// select winners or move funds. Judges and sponsors select finalists, finalists pull prizes, and sponsors pull
/// unallocated refunds.
contract VigiliaGrantRound is IVigiliaEscrowVerdictReceiver {
    event RoundCreated(
        uint256 indexed roundId,
        address indexed sponsor,
        address indexed judge,
        uint256 prizeAmount,
        uint256 maxWinners,
        uint64 applicationDeadline,
        uint64 reviewDeadline,
        string requirementsURI,
        ScreeningMode screeningMode
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

    error InvalidAddress();
    error InvalidAmount();
    error InvalidDeadline();
    error InvalidState(uint256 roundId, RoundState state);
    error InvalidApplicationStatus(uint256 applicationId, ApplicationStatus status);
    error RoundDoesNotExist(uint256 roundId);
    error ApplicationDoesNotExist(uint256 applicationId);
    error ApplicationRoundMismatch(uint256 expectedRoundId, uint256 actualRoundId);
    error Unauthorized(address caller);
    error EmptyEvidenceURI();
    error ZeroEvidenceHash();
    error DuplicateApplication(uint256 roundId, address applicant, uint256 applicationId);
    error InvalidFundingAmount(uint256 expected, uint256 actual);
    error MaxWinnersExceeded(uint256 maxWinners);
    error AlreadySelected(uint256 applicationId);
    error AlreadyClaimed(uint256 applicationId);
    error NotSelected(uint256 applicationId);
    error ApplicationDeadlineActive(uint256 roundId, uint256 deadline, uint256 currentTime);
    error ApplicationDeadlinePassed(uint256 roundId, uint256 deadline, uint256 currentTime);
    error ReviewDeadlinePassed(uint256 roundId, uint256 deadline, uint256 currentTime);
    error UnknownVerdict();
    error VerifierNotConfigured();
    error NoPendingWithdrawal(address account);
    error TransferFailed(address recipient, uint256 amount);
    error UnsupportedScreeningMode(ScreeningMode screeningMode);
    error ZeroRequestId();

    /// @notice Round lifecycle state.
    /// @dev `None` is reserved for missing rounds. `Review` begins when finalist selection starts, and `Finalized`
    /// enables selected applicants to claim. No settlement authority is granted to agents in any state.
    enum RoundState {
        None,
        Created,
        Open,
        Review,
        Finalized,
        Cancelled
    }

    /// @notice Application review and prize-claim status.
    /// @dev `VerificationFailed` means verifier infrastructure failed and remains reviewable. `Incomplete` is not
    /// selectable through the normal finalist path. `Selected` reserves a prize; `Claimed` consumes that reservation.
    enum ApplicationStatus {
        None,
        Submitted,
        ScreeningRequested,
        Complete,
        NeedsReview,
        Incomplete,
        VerificationFailed,
        Selected,
        Rejected,
        Claimed
    }

    /// @notice Agent screening workflow chosen by the sponsor for a specific round.
    /// @dev Manual screening is intentionally not a round mode; it is a recovery path.
    enum ScreeningMode {
        TwoAgent,
        ThreeAgent
    }

    /// @notice Grant or bounty round configuration and accounting.
    /// @param sponsor Account that created the round, funds the pool, may select/finalize, and may refund unallocated
    /// funds.
    /// @param judge Round-scoped reviewer account allowed to screen, reject, select, and finalize.
    /// @param prizeAmount Equal native-token prize paid to each selected finalist.
    /// @param maxWinners Maximum finalist count and funding multiplier.
    /// @param totalFunded Native-token amount deposited by the sponsor. MVP funding is exact and one-time.
    /// @param selectedCount Number of applications selected as finalists.
    /// @param claimedCount Number of selected finalists that have claimed.
    /// @param totalClaimed Native-token amount paid to finalists through pull claims.
    /// @param totalRefunded Native-token amount credited to the sponsor as unallocated or cancellation refund.
    /// @param applicationsCount Number of submitted applications for this round.
    /// @param applicationDeadline Last timestamp when applications may be submitted.
    /// @param reviewDeadline Last timestamp for normal finalist selection.
    /// @param requirementsURI Public URI describing eligibility, evidence format, and round requirements.
    /// @param screeningMode Per-round Somnia-agent workflow mode.
    /// @param state Current round lifecycle state.
    struct Round {
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
        ScreeningMode screeningMode;
        RoundState state;
    }

    /// @notice Builder application and agent screening metadata.
    /// @param roundId Parent round identifier.
    /// @param applicant Builder account that submitted evidence and is the only account allowed to claim its prize.
    /// @param evidenceURI Public URI containing application evidence metadata or links.
    /// @param evidenceHash Hash of the submitted evidence bundle or metadata.
    /// @param requestId Active verifier request identifier. Stale callbacks with older IDs are ignored.
    /// @param verdict Bounded verifier or manual screening verdict, or `Unknown` before screening.
    /// @param status Current application review and claim status.
    /// @param selected Whether this application has a reserved finalist prize.
    /// @param claimed Whether the reserved prize has been claimed.
    /// @param submittedAt Submission timestamp.
    /// @param reviewedAt Latest screening/review timestamp, or zero before screening.
    /// @param notesURI Public URI with verifier notes, manual review notes, failure notes, or rejection reason.
    struct Application {
        uint256 roundId;
        address applicant;
        string evidenceURI;
        bytes32 evidenceHash;
        bytes32 requestId;
        VigiliaTypes.VerificationVerdict verdict;
        ApplicationStatus status;
        bool selected;
        bool claimed;
        uint64 submittedAt;
        uint64 reviewedAt;
        string notesURI;
    }

    /// @notice Workflow-aware verifier used for agent screening. Zero address disables request/callback paths.
    /// @dev GrantRound should use a fresh verifier instance bound to this receiver. The hardened v0.2.3 escrow verifier
    /// deployment should not be reused, because it is bound to the fixed-work escrow receiver and product proof.
    address public immutable verifier;

    /// @notice Next round identifier. Starts at one so zero remains a missing sentinel.
    uint256 public nextRoundId = 1;

    /// @notice Next application identifier. Starts at one so zero remains a missing sentinel.
    uint256 public nextApplicationId = 1;

    /// @notice Round storage by round identifier.
    mapping(uint256 roundId => Round round) public rounds;

    /// @notice Application storage by application identifier.
    mapping(uint256 applicationId => Application application) public applications;

    /// @notice Applicant's application identifier for a round.
    /// @dev Enforces one application per address per round. Zero means no application.
    mapping(uint256 roundId => mapping(address applicant => uint256 applicationId)) public applicationOf;

    /// @notice Native-token credits withdrawable by sponsors after refunds or cancellation.
    /// @dev Credits are cleared before transfer in `withdrawPendingTo`.
    mapping(address account => uint256 amount) public pendingWithdrawals;

    /// @notice Application identifiers submitted to each round in submission order.
    /// @dev Kept private to avoid returning an unbounded dynamic array from an auto-generated getter; exposed through
    /// `getRoundApplications`.
    mapping(uint256 roundId => uint256[] applicationIds) private _roundApplications;

    /// @notice Creates a GrantRound module.
    /// @param _verifier Workflow-aware Somnia verifier for application screening, or zero for deployment before
    /// binding.
    /// @dev A zero verifier is allowed so the contract can be deployed before a GrantRound-specific verifier exists.
    /// In that mode, `requestApplicationScreening` and verifier callbacks fail closed, while manual fallback/recovery
    /// remains available.
    constructor(address _verifier) {
        verifier = _verifier;
    }

    /// @notice Creates an unfunded grant or bounty round.
    /// @param _judge Round-scoped judge allowed to screen, select, reject, and finalize.
    /// @param _prizeAmount Native-token prize paid to each selected finalist.
    /// @param _maxWinners Maximum number of finalists that may claim prizes.
    /// @param _applicationDeadline Last timestamp when applications are accepted.
    /// @param _reviewDeadline Last timestamp when normal finalist selection is open.
    /// @param _requirementsURI Public URI describing eligibility and evidence requirements.
    /// @param _screeningMode Per-round Somnia agent screening mode.
    /// @return roundId New round identifier.
    function createRound(
        address _judge,
        uint256 _prizeAmount,
        uint256 _maxWinners,
        uint64 _applicationDeadline,
        uint64 _reviewDeadline,
        string calldata _requirementsURI,
        ScreeningMode _screeningMode
    ) external returns (uint256 roundId) {
        if (_judge == address(0)) revert InvalidAddress();
        if (_prizeAmount == 0 || _maxWinners == 0) revert InvalidAmount();
        if (_applicationDeadline <= block.timestamp || _reviewDeadline <= _applicationDeadline) {
            revert InvalidDeadline();
        }
        _requireSupportedRoundMode(_screeningMode);

        roundId = nextRoundId++;
        Round storage round = rounds[roundId];
        round.sponsor = msg.sender;
        round.judge = _judge;
        round.prizeAmount = _prizeAmount;
        round.maxWinners = _maxWinners;
        round.applicationDeadline = _applicationDeadline;
        round.reviewDeadline = _reviewDeadline;
        round.requirementsURI = _requirementsURI;
        round.screeningMode = _screeningMode;
        round.state = RoundState.Created;

        emit RoundCreated(
            roundId,
            msg.sender,
            _judge,
            _prizeAmount,
            _maxWinners,
            _applicationDeadline,
            _reviewDeadline,
            _requirementsURI,
            _screeningMode
        );
    }

    /// @notice Funds a created round with the exact full prize pool and opens applications.
    /// @param _roundId Round to fund.
    function fundRound(uint256 _roundId) external payable {
        Round storage round = _existingRound(_roundId);
        _onlySponsor(round);
        if (round.state != RoundState.Created) revert InvalidState(_roundId, round.state);

        uint256 expected = requiredFunding(_roundId);
        if (msg.value != expected) revert InvalidFundingAmount(expected, msg.value);

        round.totalFunded = msg.value;
        round.state = RoundState.Open;

        emit RoundFunded(_roundId, msg.sender, msg.value);
    }

    /// @notice Submits one public evidence bundle to an open round.
    /// @param _roundId Round receiving the application.
    /// @param _evidenceURI Public URI containing application evidence metadata.
    /// @param _evidenceHash Hash of the evidence bundle or metadata.
    /// @return applicationId New application identifier.
    function submitApplication(uint256 _roundId, string calldata _evidenceURI, bytes32 _evidenceHash)
        external
        returns (uint256 applicationId)
    {
        Round storage round = _existingRound(_roundId);
        if (round.state != RoundState.Open) revert InvalidState(_roundId, round.state);
        if (block.timestamp > round.applicationDeadline) {
            revert ApplicationDeadlinePassed(_roundId, round.applicationDeadline, block.timestamp);
        }
        if (bytes(_evidenceURI).length == 0) revert EmptyEvidenceURI();
        if (_evidenceHash == bytes32(0)) revert ZeroEvidenceHash();

        uint256 existingApplicationId = applicationOf[_roundId][msg.sender];
        if (existingApplicationId != 0) revert DuplicateApplication(_roundId, msg.sender, existingApplicationId);

        applicationId = nextApplicationId++;
        applications[applicationId] = Application({
            roundId: _roundId,
            applicant: msg.sender,
            evidenceURI: _evidenceURI,
            evidenceHash: _evidenceHash,
            requestId: bytes32(0),
            verdict: VigiliaTypes.VerificationVerdict.Unknown,
            status: ApplicationStatus.Submitted,
            selected: false,
            claimed: false,
            submittedAt: uint64(block.timestamp),
            reviewedAt: 0,
            notesURI: ""
        });
        applicationOf[_roundId][msg.sender] = applicationId;
        _roundApplications[_roundId].push(applicationId);
        round.applicationsCount++;

        emit ApplicationSubmitted(_roundId, applicationId, msg.sender, _evidenceURI, _evidenceHash);
    }

    /// @notice Requests Somnia-agent screening for an application using its round's configured screening mode.
    /// @dev The callback can only update screening metadata. Finalist selection and fund movement remain manual
    /// judge/sponsor actions.
    /// @param _applicationId Application to screen.
    /// @return requestId Verifier request identifier stored on the application.
    function requestApplicationScreening(uint256 _applicationId) external payable returns (bytes32 requestId) {
        if (verifier == address(0)) revert VerifierNotConfigured();

        Application storage application = _existingApplication(_applicationId);
        Round storage round = _existingRound(application.roundId);
        if (!_isRoundActor(round) && msg.sender != application.applicant) revert Unauthorized(msg.sender);
        _requireMutableApplication(_applicationId, application);

        VigiliaAgentTypes.SettlementWorkflow workflow = _workflowFor(round.screeningMode);
        requestId = IVigiliaVerifier(verifier).requestVerification{ value: msg.value }(
            application.roundId, _applicationId, msg.sender, application.evidenceURI, round.requirementsURI, workflow
        );
        if (requestId == bytes32(0)) revert ZeroRequestId();

        application.requestId = requestId;
        application.status = ApplicationStatus.ScreeningRequested;
        application.verdict = VigiliaTypes.VerificationVerdict.Unknown;
        application.notesURI = "";
        application.reviewedAt = 0;

        emit ApplicationScreeningRequested(application.roundId, _applicationId, msg.sender, requestId);
    }

    /// @inheritdoc IVigiliaEscrowVerdictReceiver
    function recordVerdict(
        uint256 _roundId,
        uint256 _applicationId,
        bytes32 _requestId,
        VigiliaTypes.VerificationVerdict _verdict,
        string calldata _notesURI
    ) external {
        _onlyVerifier();
        if (_verdict == VigiliaTypes.VerificationVerdict.Unknown) revert UnknownVerdict();

        Application storage application = _existingApplication(_applicationId);
        _requireApplicationRound(_roundId, application);
        if (application.requestId != _requestId) {
            emit StaleGrantRoundCallbackIgnored(_roundId, _applicationId, application.requestId, _requestId);
            return;
        }
        _requireMutableApplication(_applicationId, application);

        application.verdict = _verdict;
        application.status = _statusForVerdict(_verdict);
        application.notesURI = _notesURI;
        application.reviewedAt = uint64(block.timestamp);

        emit ApplicationVerdictRecorded(_roundId, _applicationId, _verdict, _notesURI);
    }

    /// @inheritdoc IVigiliaEscrowVerdictReceiver
    function recordVerificationFailure(
        uint256 _roundId,
        uint256 _applicationId,
        bytes32 _requestId,
        string calldata _failureNotesURI
    ) external {
        _onlyVerifier();

        Application storage application = _existingApplication(_applicationId);
        _requireApplicationRound(_roundId, application);
        if (application.requestId != _requestId) {
            emit StaleGrantRoundCallbackIgnored(_roundId, _applicationId, application.requestId, _requestId);
            return;
        }
        _requireMutableApplication(_applicationId, application);

        application.status = ApplicationStatus.VerificationFailed;
        application.notesURI = _failureNotesURI;
        application.reviewedAt = uint64(block.timestamp);

        emit ApplicationVerificationFailed(_roundId, _applicationId, _requestId, _failureNotesURI);
    }

    /// @notice Records a judge or sponsor fallback screening result without invoking Somnia agents.
    /// @dev Manual screening is a recovery path only. It cannot select finalists or move funds.
    /// @param _applicationId Application receiving the manual screening metadata.
    /// @param _verdict Bounded verdict recorded by the round actor.
    /// @param _notesURI Public URI with review notes or recovery rationale.
    function recordManualScreening(
        uint256 _applicationId,
        VigiliaTypes.VerificationVerdict _verdict,
        string calldata _notesURI
    ) external {
        if (_verdict == VigiliaTypes.VerificationVerdict.Unknown) {
            revert UnknownVerdict();
        }

        Application storage application = _existingApplication(_applicationId);
        Round storage round = _existingRound(application.roundId);
        _onlyRoundActor(round);
        _requireMutableApplication(_applicationId, application);

        application.verdict = _verdict;
        application.status = _statusForVerdict(_verdict);
        application.notesURI = _notesURI;
        application.reviewedAt = uint64(block.timestamp);

        emit ManualScreeningRecorded(application.roundId, _applicationId, _verdict, _notesURI);
    }

    /// @notice Selects eligible finalists after applications close and before review selection closes.
    /// @param _roundId Round whose finalists are being selected.
    /// @param _applicationIds Application identifiers to select.
    function selectFinalists(uint256 _roundId, uint256[] calldata _applicationIds) external {
        Round storage round = _existingRound(_roundId);
        _onlyRoundActor(round);
        if (round.state != RoundState.Open && round.state != RoundState.Review) {
            revert InvalidState(_roundId, round.state);
        }
        if (block.timestamp <= round.applicationDeadline) {
            revert ApplicationDeadlineActive(_roundId, round.applicationDeadline, block.timestamp);
        }
        if (block.timestamp > round.reviewDeadline) {
            revert ReviewDeadlinePassed(_roundId, round.reviewDeadline, block.timestamp);
        }

        uint256 newSelectedCount = round.selectedCount + _applicationIds.length;
        if (newSelectedCount > round.maxWinners) revert MaxWinnersExceeded(round.maxWinners);
        if (newSelectedCount * round.prizeAmount > round.totalFunded) revert MaxWinnersExceeded(round.maxWinners);

        if (round.state == RoundState.Open) round.state = RoundState.Review;

        for (uint256 i = 0; i < _applicationIds.length; i++) {
            uint256 applicationId = _applicationIds[i];
            Application storage application = _existingApplication(applicationId);
            _requireApplicationRound(_roundId, application);
            if (!canSelectApplication(applicationId)) {
                revert InvalidApplicationStatus(applicationId, application.status);
            }

            application.selected = true;
            application.status = ApplicationStatus.Selected;
            round.selectedCount++;

            emit FinalistSelected(_roundId, applicationId, application.applicant);
        }
    }

    /// @notice Rejects a non-selected application for review UI clarity.
    /// @param _applicationId Application to reject.
    /// @param _reasonURI Public URI with rejection or review notes.
    function rejectApplication(uint256 _applicationId, string calldata _reasonURI) external {
        Application storage application = _existingApplication(_applicationId);
        Round storage round = _existingRound(application.roundId);
        _onlyRoundActor(round);
        if (application.selected) revert AlreadySelected(_applicationId);
        if (application.claimed) revert AlreadyClaimed(_applicationId);
        if (application.status == ApplicationStatus.Rejected) {
            revert InvalidApplicationStatus(_applicationId, application.status);
        }

        application.status = ApplicationStatus.Rejected;
        application.notesURI = _reasonURI;
        application.reviewedAt = uint64(block.timestamp);

        emit ApplicationRejected(application.roundId, _applicationId, _reasonURI);
    }

    /// @notice Finalizes a round after applications close so selected finalists can claim.
    /// @param _roundId Round to finalize.
    function finalizeRound(uint256 _roundId) external {
        Round storage round = _existingRound(_roundId);
        _onlyRoundActor(round);
        _finalizeRound(_roundId, round);
    }

    /// @notice Claims a selected finalist prize to the applicant.
    /// @param _applicationId Selected application to claim.
    function claimPrize(uint256 _applicationId) external {
        claimPrizeTo(_applicationId, payable(msg.sender));
    }

    /// @notice Claims a selected finalist prize to an explicit recipient.
    /// @param _applicationId Selected application to claim.
    /// @param _recipient Native-token recipient chosen by the applicant.
    function claimPrizeTo(uint256 _applicationId, address payable _recipient) public {
        if (_recipient == address(0)) revert InvalidAddress();

        Application storage application = _existingApplication(_applicationId);
        Round storage round = _existingRound(application.roundId);
        if (round.state != RoundState.Finalized) revert InvalidState(application.roundId, round.state);
        if (msg.sender != application.applicant) revert Unauthorized(msg.sender);
        if (!application.selected) revert NotSelected(_applicationId);
        if (application.claimed) revert AlreadyClaimed(_applicationId);

        uint256 amount = round.prizeAmount;
        application.claimed = true;
        application.status = ApplicationStatus.Claimed;
        round.claimedCount++;
        round.totalClaimed += amount;

        (bool success,) = _recipient.call{ value: amount }("");
        if (!success) revert TransferFailed(_recipient, amount);

        emit PrizeClaimed(application.roundId, _applicationId, application.applicant, _recipient, amount);
    }

    /// @notice Credits the sponsor with unallocated prize-pool funds without touching selected finalist reservations.
    /// @param _roundId Round whose unallocated funds should be credited.
    /// @return refundAmount Native-token amount credited to the sponsor for later withdrawal.
    function refundUnallocated(uint256 _roundId) external returns (uint256 refundAmount) {
        Round storage round = _existingRound(_roundId);
        _onlySponsor(round);
        if (round.state != RoundState.Finalized) {
            if (block.timestamp <= round.reviewDeadline) revert InvalidState(_roundId, round.state);
            _finalizeRound(_roundId, round);
        }

        refundAmount = unallocatedAmount(_roundId);
        if (refundAmount == 0) revert InvalidAmount();

        round.totalRefunded += refundAmount;
        pendingWithdrawals[round.sponsor] += refundAmount;

        emit UnallocatedRefundCredited(_roundId, round.sponsor, refundAmount);
    }

    /// @notice Withdraws pending refund credit to the caller.
    function withdrawPending() external {
        withdrawPendingTo(payable(msg.sender));
    }

    /// @notice Withdraws pending refund credit to an explicit recipient.
    /// @param _recipient Native-token recipient chosen by the credited account.
    function withdrawPendingTo(address payable _recipient) public {
        if (_recipient == address(0)) revert InvalidAddress();

        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NoPendingWithdrawal(msg.sender);

        pendingWithdrawals[msg.sender] = 0;

        (bool success,) = _recipient.call{ value: amount }("");
        if (!success) revert TransferFailed(_recipient, amount);

        emit PendingWithdrawalClaimed(msg.sender, _recipient, amount);
    }

    /// @notice Cancels a safely cancellable round and credits any funded pool to the sponsor.
    /// @param _roundId Round to cancel.
    function cancelRound(uint256 _roundId) external {
        Round storage round = _existingRound(_roundId);
        _onlySponsor(round);
        if (round.state == RoundState.Created) {
            if (round.totalFunded != 0) revert InvalidState(_roundId, round.state);
        } else if (round.state == RoundState.Open) {
            if (round.applicationsCount != 0) revert InvalidState(_roundId, round.state);
        } else {
            revert InvalidState(_roundId, round.state);
        }
        if (round.selectedCount != 0 || round.claimedCount != 0) revert InvalidState(_roundId, round.state);

        uint256 refundAmount = round.totalFunded - round.totalRefunded;
        round.totalRefunded += refundAmount;
        round.state = RoundState.Cancelled;
        if (refundAmount != 0) pendingWithdrawals[round.sponsor] += refundAmount;

        emit RoundCancelled(_roundId, refundAmount);
    }

    /// @notice Returns the exact native-token funding required to open a round.
    /// @param _roundId Round being inspected.
    /// @return amount Prize amount multiplied by maximum winners.
    function requiredFunding(uint256 _roundId) public view returns (uint256 amount) {
        Round storage round = _existingRoundView(_roundId);
        amount = round.prizeAmount * round.maxWinners;
    }

    /// @notice Returns the native-token allocation reserved for selected finalists.
    /// @param _roundId Round being inspected.
    /// @return amount Selected count multiplied by prize amount.
    function selectedAllocation(uint256 _roundId) public view returns (uint256 amount) {
        Round storage round = _existingRoundView(_roundId);
        amount = round.selectedCount * round.prizeAmount;
    }

    /// @notice Returns unallocated sponsor-refundable funds while preserving selected finalist reservations.
    /// @param _roundId Round being inspected.
    /// @return amount Sponsor-refundable native-token amount not already credited.
    function unallocatedAmount(uint256 _roundId) public view returns (uint256 amount) {
        Round storage round = _existingRoundView(_roundId);
        uint256 reservedForSelected = selectedAllocation(_roundId);
        if (round.totalFunded <= reservedForSelected + round.totalRefunded) return 0;
        amount = round.totalFunded - reservedForSelected - round.totalRefunded;
    }

    /// @notice Returns all application identifiers submitted to a round.
    /// @param _roundId Round being inspected.
    /// @return applicationIds Application identifiers in submission order.
    function getRoundApplications(uint256 _roundId) external view returns (uint256[] memory applicationIds) {
        _existingRoundView(_roundId);
        applicationIds = _roundApplications[_roundId];
    }

    /// @notice Returns whether an application is eligible for normal finalist selection.
    /// @param _applicationId Application being inspected.
    /// @return eligible True when normal selection can mark the application as selected.
    function canSelectApplication(uint256 _applicationId) public view returns (bool eligible) {
        Application storage application = _existingApplicationView(_applicationId);
        if (application.selected || application.claimed) return false;

        ApplicationStatus status = application.status;
        return status == ApplicationStatus.Submitted || status == ApplicationStatus.ScreeningRequested
            || status == ApplicationStatus.Complete || status == ApplicationStatus.NeedsReview
            || status == ApplicationStatus.VerificationFailed;
    }

    /// @notice Moves an open or review round to finalized after applications close.
    /// @dev Shared by `finalizeRound` and late `refundUnallocated`. Finalization only enables claims/refunds; it does
    /// not select finalists or move funds.
    /// @param _roundId Round being finalized.
    /// @param _round Storage pointer for the round.
    function _finalizeRound(uint256 _roundId, Round storage _round) private {
        if (_round.state != RoundState.Open && _round.state != RoundState.Review) {
            revert InvalidState(_roundId, _round.state);
        }
        if (block.timestamp <= _round.applicationDeadline) {
            revert ApplicationDeadlineActive(_roundId, _round.applicationDeadline, block.timestamp);
        }

        _round.state = RoundState.Finalized;

        emit RoundFinalized(_roundId, _round.selectedCount);
    }

    /// @notice Maps a GrantRound screening mode to a verifier settlement workflow.
    /// @dev `TwoAgent` keeps the proven JSON facts -> LLM workflow. `ThreeAgent` uses the fresh verifier workflow that
    /// enriches JSON facts with Website Parse before final LLM classification.
    /// @param _screeningMode Round screening mode.
    /// @return workflow Verifier workflow to request.
    function _workflowFor(ScreeningMode _screeningMode)
        internal
        pure
        returns (VigiliaAgentTypes.SettlementWorkflow workflow)
    {
        if (_screeningMode == ScreeningMode.TwoAgent) {
            return VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict;
        }
        if (_screeningMode == ScreeningMode.ThreeAgent) {
            return VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict;
        }
        revert UnsupportedScreeningMode(_screeningMode);
    }

    /// @notice Maps a bounded verifier verdict to an application status.
    /// @param _verdict Bounded Vigilia verdict.
    /// @return status Application status corresponding to the verdict.
    function _statusForVerdict(VigiliaTypes.VerificationVerdict _verdict)
        private
        pure
        returns (ApplicationStatus status)
    {
        if (_verdict == VigiliaTypes.VerificationVerdict.Complete) return ApplicationStatus.Complete;
        if (_verdict == VigiliaTypes.VerificationVerdict.NeedsReview) return ApplicationStatus.NeedsReview;
        if (_verdict == VigiliaTypes.VerificationVerdict.Incomplete) return ApplicationStatus.Incomplete;
        revert UnknownVerdict();
    }

    /// @notice Checks that a round can be created with the supplied screening mode.
    /// @dev Solidity enum values can be ABI-decoded from arbitrary integers, so this guard rejects values outside the
    /// declared MVP modes.
    /// @param _screeningMode Candidate screening mode.
    function _requireSupportedRoundMode(ScreeningMode _screeningMode) private pure {
        if (_screeningMode == ScreeningMode.TwoAgent || _screeningMode == ScreeningMode.ThreeAgent) return;
        revert UnsupportedScreeningMode(_screeningMode);
    }

    /// @notice Reverts when an application is no longer mutable by screening or fallback review.
    /// @dev Selected, rejected, and claimed applications are terminal for screening metadata updates.
    /// @param _applicationId Application being checked.
    /// @param _application Storage pointer for the application.
    function _requireMutableApplication(uint256 _applicationId, Application storage _application) private view {
        if (
            _application.status == ApplicationStatus.Selected || _application.status == ApplicationStatus.Rejected
                || _application.status == ApplicationStatus.Claimed || _application.selected || _application.claimed
        ) {
            revert InvalidApplicationStatus(_applicationId, _application.status);
        }
    }

    /// @notice Reverts unless an application belongs to the expected round.
    /// @param _roundId Expected parent round identifier.
    /// @param _application Application storage pointer being checked.
    function _requireApplicationRound(uint256 _roundId, Application storage _application) private view {
        if (_application.roundId != _roundId) revert ApplicationRoundMismatch(_roundId, _application.roundId);
    }

    /// @notice Reverts unless the caller is the configured GrantRound verifier.
    /// @dev A zero verifier fails closed. Verifier callbacks are receiver-only metadata writes and never move funds.
    function _onlyVerifier() private view {
        if (verifier == address(0)) revert VerifierNotConfigured();
        if (msg.sender != verifier) revert Unauthorized(msg.sender);
    }

    /// @notice Reverts unless the caller is the round sponsor.
    /// @param _round Round storage pointer being checked.
    function _onlySponsor(Round storage _round) private view {
        if (msg.sender != _round.sponsor) revert Unauthorized(msg.sender);
    }

    /// @notice Reverts unless the caller is the round sponsor or judge.
    /// @param _round Round storage pointer being checked.
    function _onlyRoundActor(Round storage _round) private view {
        if (!_isRoundActor(_round)) revert Unauthorized(msg.sender);
    }

    /// @notice Returns whether the caller is the round sponsor or judge.
    /// @param _round Round storage pointer being checked.
    /// @return authorized True when `msg.sender` is a round actor.
    function _isRoundActor(Round storage _round) private view returns (bool authorized) {
        return msg.sender == _round.sponsor || msg.sender == _round.judge;
    }

    /// @notice Loads an existing round from storage.
    /// @param _roundId Round identifier to load.
    /// @return round Storage pointer for the round.
    function _existingRound(uint256 _roundId) private view returns (Round storage round) {
        round = rounds[_roundId];
        if (round.state == RoundState.None) revert RoundDoesNotExist(_roundId);
    }

    /// @notice Loads an existing round from storage for view helpers.
    /// @param _roundId Round identifier to load.
    /// @return round Storage pointer for the round.
    function _existingRoundView(uint256 _roundId) private view returns (Round storage round) {
        round = rounds[_roundId];
        if (round.state == RoundState.None) revert RoundDoesNotExist(_roundId);
    }

    /// @notice Loads an existing application from storage.
    /// @param _applicationId Application identifier to load.
    /// @return application Storage pointer for the application.
    function _existingApplication(uint256 _applicationId) private view returns (Application storage application) {
        application = applications[_applicationId];
        if (application.status == ApplicationStatus.None) revert ApplicationDoesNotExist(_applicationId);
    }

    /// @notice Loads an existing application from storage for view helpers.
    /// @param _applicationId Application identifier to load.
    /// @return application Storage pointer for the application.
    function _existingApplicationView(uint256 _applicationId) private view returns (Application storage application) {
        application = applications[_applicationId];
        if (application.status == ApplicationStatus.None) revert ApplicationDoesNotExist(_applicationId);
    }
}
