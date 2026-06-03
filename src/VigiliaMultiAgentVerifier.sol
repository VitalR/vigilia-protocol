// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { ILlmInferenceAgent } from "./interfaces/ILlmInferenceAgent.sol";
import { ILlmParseWebsiteAgent } from "./interfaces/ILlmParseWebsiteAgent.sol";
import { ISomniaAgentRequester } from "./interfaces/ISomniaAgentRequester.sol";
import { IVigiliaEscrowVerdictReceiver } from "./interfaces/IVigiliaEscrowVerdictReceiver.sol";
import { IVigiliaVerifier } from "./interfaces/IVigiliaVerifier.sol";
import { VigiliaAgentTypes } from "./types/VigiliaAgentTypes.sol";
import { VigiliaTypes } from "./types/VigiliaTypes.sol";
import { VigiliaAgentStringLib } from "./libraries/VigiliaAgentStringLib.sol";
import { VigiliaMultiAgentPlatformLib } from "./libraries/VigiliaMultiAgentPlatformLib.sol";
import { VigiliaMultiAgentTypes } from "./types/VigiliaMultiAgentTypes.sol";

/// @title VigiliaMultiAgentVerifier
/// @notice Somnia Agent verifier/coordinator with canaries and a two-agent settlement workflow.
/// @dev The proven JSON API Request path remains available. LLM Inference can be settlement-enabled only by constructor
/// config; LLM Parse Website remains canary-only until live platform callbacks are reliable.
contract VigiliaMultiAgentVerifier is IVigiliaVerifier {
    /// @dev JSON selector used by the two-agent workflow to fetch structured facts before LLM classification.
    string private constant _FACTS_SELECTOR = "facts";
    /// @dev JSON selector used by the three-agent workflow to fetch the Website Parse target.
    string private constant _WEBSITE_URI_SELECTOR = "websiteURI";
    /// @dev Fixed system prompt for settlement LLM verdict requests.
    string private constant _LLM_SYSTEM_PROMPT =
        "You are a strict Vigilia work verifier. Return exactly one allowed value. Do not explain.";
    /// @dev Fixed system prompt for ThreeAgent final grant-screening verdict requests.
    string private constant _THREE_AGENT_LLM_SYSTEM_PROMPT =
        "You are a strict grant application screening classifier. Return exactly one allowed value: Complete, NeedsReview, or Incomplete. Do not explain.";

    /// @notice Constructor configuration for the v0.2.0 canary coordinator.
    /// @param platform Somnia Agent requester platform.
    /// @param escrowBinder Account allowed to bind escrow once.
    /// @param jsonApiAgentId Proven JSON API Request agent ID.
    /// @param llmInferenceAgentId LLM Inference agent ID, or zero to leave its canary disabled.
    /// @param llmParseWebsiteAgentId LLM Parse Website agent ID, or zero to leave its canary disabled.
    /// @param subcommitteeSize Expected validator count for all configured kinds.
    /// @param jsonApiPricePerValidator JSON API per-validator budget.
    /// @param llmInferencePricePerValidator LLM Inference per-validator budget.
    /// @param llmParseWebsitePricePerValidator LLM Parse Website per-validator budget.
    /// @param jsonApiSelector JSON selector used by escrow settlement and JSON canaries.
    struct ConstructorConfig {
        address platform;
        address escrowBinder;
        uint256 jsonApiAgentId;
        uint256 llmInferenceAgentId;
        uint256 llmParseWebsiteAgentId;
        uint256 subcommitteeSize;
        uint256 jsonApiPricePerValidator;
        uint256 llmInferencePricePerValidator;
        uint256 llmParseWebsitePricePerValidator;
        string jsonApiSelector;
        bool enableLlmInferenceSettlement;
    }

    /// @notice Emitted when this verifier is permanently bound to a settlement receiver contract.
    /// @param escrow Settlement receiver allowed to request settlement verification and receive forwarded verdicts.
    event EscrowBound(address indexed escrow);

    /// @notice Emitted once per configured agent kind at deployment.
    /// @param kind Configured agent kind.
    /// @param agentId Somnia Agent identifier.
    /// @param pricePerValidator Native-token reward budget per validator.
    /// @param subcommitteeSize Expected validator count.
    /// @param selector Selector or method metadata.
    /// @param canaryEnabled Whether canary requests are enabled.
    /// @param settlementEnabled Whether escrow settlement requests are enabled.
    event AgentConfigured(
        VigiliaAgentTypes.AgentKind indexed kind,
        uint256 indexed agentId,
        uint256 pricePerValidator,
        uint256 subcommitteeSize,
        string selector,
        bool canaryEnabled,
        bool settlementEnabled
    );

    /// @notice Emitted when a canary request is sent to the Somnia Agent platform.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param kind Agent kind under test.
    /// @param requester Account that paid for the canary.
    /// @param agentId Somnia Agent identifier.
    /// @param deposit Native-token amount forwarded to the platform.
    /// @param inputHash Hash of URL, prompt, or parse metadata.
    event CanaryRequested(
        uint256 indexed platformRequestId,
        VigiliaAgentTypes.AgentKind indexed kind,
        address indexed requester,
        uint256 agentId,
        uint256 deposit,
        bytes32 inputHash
    );

    /// @notice Emitted when a canary callback returns a bounded verdict string.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param kind Agent kind that succeeded.
    /// @param verdict Bounded result parsed from the callback.
    /// @param rawResult Raw string returned by the agent.
    event CanarySucceeded(
        uint256 indexed platformRequestId,
        VigiliaAgentTypes.AgentKind indexed kind,
        VigiliaTypes.VerificationVerdict verdict,
        string rawResult
    );

    /// @notice Emitted when a canary callback fails, times out, or returns malformed/unknown output.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param kind Agent kind that failed.
    /// @param status Terminal platform status.
    /// @param failureNotesURI Deterministic failure note.
    event CanaryFailed(
        uint256 indexed platformRequestId,
        VigiliaAgentTypes.AgentKind indexed kind,
        ISomniaAgentRequester.ResponseStatus status,
        string failureNotesURI
    );

    /// @notice Emitted when escrow creates a settlement verification request.
    /// @param vigiliaRequestId Vigilia-facing request identifier returned to escrow.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Task to verify.
    /// @param submissionId Submission to verify.
    /// @param kind Agent kind used for settlement.
    /// @param agentId Somnia Agent identifier.
    /// @param deposit Native-token amount forwarded with this request. For `JsonFactsToLlmVerdict` this is the total
    /// workflow deposit: the JSON stage platform value plus the LLM stage budget retained in `prepaidBudget`.
    /// @param evidenceURI Public evidence URI.
    event MultiAgentVerificationRequested(
        bytes32 indexed vigiliaRequestId,
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 submissionId,
        VigiliaAgentTypes.AgentKind kind,
        VigiliaAgentTypes.SettlementWorkflow workflow,
        VigiliaAgentTypes.VerificationStage stage,
        uint256 agentId,
        uint256 deposit,
        string evidenceURI
    );

    /// @notice Emitted when the JSON API facts stage returns structured facts.
    /// @param platformRequestId JSON facts platform request identifier.
    /// @param taskId Task being verified.
    /// @param submissionId Submission being verified.
    /// @param facts Structured facts extracted from the evidence URI.
    event JsonFactsReceived(
        uint256 indexed platformRequestId, uint256 indexed taskId, uint256 indexed submissionId, string facts
    );

    /// @notice Emitted when the verifier creates the LLM Inference verdict stage.
    /// @param parentRequestId Escrow-facing JSON facts request identifier.
    /// @param llmRequestId LLM Inference platform request identifier.
    /// @param taskId Task being verified.
    /// @param submissionId Submission being verified.
    /// @param deposit Native-token budget forwarded to the LLM stage.
    event LlmVerdictRequested(
        uint256 indexed parentRequestId,
        uint256 indexed llmRequestId,
        uint256 indexed taskId,
        uint256 submissionId,
        uint256 deposit
    );

    /// @notice Emitted when the ThreeAgent workflow reads a public website URI from the evidence bundle.
    /// @param platformRequestId JSON websiteURI platform request identifier.
    /// @param taskId Task or round being verified.
    /// @param submissionId Submission or application being verified.
    /// @param websiteURI Public HTML URL used by Website Parse.
    event JsonWebsiteURIReceived(
        uint256 indexed platformRequestId, uint256 indexed taskId, uint256 indexed submissionId, string websiteURI
    );

    /// @notice Emitted when the verifier creates the Website Parse stage.
    /// @param parentRequestId Escrow-facing root workflow request identifier.
    /// @param websiteParseRequestId Website Parse platform request identifier.
    /// @param taskId Task or round being verified.
    /// @param submissionId Submission or application being verified.
    /// @param deposit Native-token budget forwarded to Website Parse.
    /// @param websiteURI Public HTML URL parsed by the agent.
    event WebsiteParseRequested(
        uint256 indexed parentRequestId,
        uint256 indexed websiteParseRequestId,
        uint256 indexed taskId,
        uint256 submissionId,
        uint256 deposit,
        string websiteURI
    );

    /// @notice Emitted when the Website Parse stage returns extracted project evidence.
    /// @param platformRequestId Website Parse platform request identifier.
    /// @param taskId Task or round being verified.
    /// @param submissionId Submission or application being verified.
    /// @param websiteExtract Extracted website evidence passed to the final LLM stage.
    event WebsiteParseEvidenceReceived(
        uint256 indexed platformRequestId, uint256 indexed taskId, uint256 indexed submissionId, string websiteExtract
    );

    /// @notice Emitted when the JSON callback could not automatically start the prepaid LLM stage.
    /// @param parentRequestId Escrow-facing JSON facts request identifier.
    /// @param taskId Task whose continuation is pending.
    /// @param submissionId Submission whose continuation is pending.
    event LlmVerdictContinuationRequired(
        uint256 indexed parentRequestId, uint256 indexed taskId, uint256 indexed submissionId
    );

    /// @notice Emitted when a settlement callback records a bounded verdict in escrow.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Verified task.
    /// @param submissionId Verified submission.
    /// @param kind Agent kind that produced the result.
    /// @param verdict Bounded verdict forwarded to escrow.
    /// @param rawResult Raw string returned by the agent.
    event MultiAgentVerificationSucceeded(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaAgentTypes.AgentKind kind,
        VigiliaAgentTypes.SettlementWorkflow workflow,
        VigiliaTypes.VerificationVerdict verdict,
        string rawResult
    );

    /// @notice Emitted when a settlement callback fails closed.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Task whose verification failed.
    /// @param submissionId Submission whose verification failed.
    /// @param kind Agent kind that failed.
    /// @param status Terminal platform status.
    /// @param failureNotesURI Deterministic failure note.
    event MultiAgentVerificationFailed(
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        VigiliaAgentTypes.AgentKind kind,
        VigiliaAgentTypes.SettlementWorkflow workflow,
        ISomniaAgentRequester.ResponseStatus status,
        string failureNotesURI
    );

    /// @notice Emitted when forwarding a terminal verifier result to escrow fails.
    /// @param platformRequestId Somnia platform request identifier.
    /// @param taskId Task whose result could not be forwarded.
    /// @param submissionId Submission whose result could not be forwarded.
    /// @param returnData Raw revert data returned by escrow.
    event EscrowForwardingFailed(
        uint256 indexed platformRequestId, uint256 indexed taskId, uint256 indexed submissionId, bytes returnData
    );

    /// @notice Emitted when an old terminal callback arrives after a newer request became active.
    /// @param platformRequestId Stale Somnia platform request identifier.
    /// @param activePlatformRequestId Current active platform request for the task/submission.
    /// @param taskId Task whose old callback was ignored.
    /// @param submissionId Submission whose old callback was ignored.
    event StaleSomniaCallbackIgnored(
        uint256 indexed platformRequestId,
        uint256 indexed activePlatformRequestId,
        uint256 indexed taskId,
        uint256 submissionId
    );

    /// @notice Emitted when the Somnia platform sends native-token rebate value back to this coordinator.
    /// @param sender Account that sent the rebate.
    /// @param amount Native-token amount received.
    event SomniaRebateReceived(address indexed sender, uint256 amount);

    /// @notice Emitted when unused prepaid LLM budget is credited after JSON-stage failure in a two-agent workflow.
    /// @param requestId Platform request identifier whose unused LLM budget was credited.
    /// @param requester Account that paid the workflow deposit and receives the credit.
    /// @param amount Native-token amount credited for later withdrawal.
    event VerificationBudgetRefundCredited(uint256 indexed requestId, address indexed requester, uint256 amount);

    /// @notice Emitted when a verification refund credit is withdrawn.
    /// @param recipient Account receiving the withdrawn native tokens.
    /// @param amount Native-token amount withdrawn.
    event VerificationBudgetRefundWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Reverts when a caller attempts to decode agent bytes without going through this contract.
    error DecodeOnlySelf();
    /// @notice Reverts when a required address is zero.
    error InvalidAddress();
    /// @notice Reverts when a required numeric parameter is zero.
    error InvalidAmount();
    /// @notice Reverts when the supplied agent kind is unknown or unsupported.
    /// @param kind Unsupported agent kind.
    error UnknownAgentKind(VigiliaAgentTypes.AgentKind kind);
    /// @notice Reverts when canary requests are disabled for an agent kind.
    /// @param kind Disabled agent kind.
    error CanaryDisabled(VigiliaAgentTypes.AgentKind kind);
    /// @notice Reverts when settlement requests are disabled for an agent kind.
    /// @param kind Disabled agent kind.
    error SettlementDisabled(VigiliaAgentTypes.AgentKind kind);
    /// @notice Reverts when the supplied settlement workflow is unknown or unsupported.
    /// @param workflow Unsupported workflow.
    error UnknownSettlementWorkflow(VigiliaAgentTypes.SettlementWorkflow workflow);
    /// @notice Reverts when a continuation is not available for the supplied request.
    /// @param requestId Platform request identifier.
    error ContinuationUnavailable(uint256 requestId);
    /// @notice Reverts when the exact required request deposit is not supplied.
    /// @param required Required native-token deposit.
    /// @param actual Actual native-token amount supplied.
    error InvalidVerificationDeposit(uint256 required, uint256 actual);
    /// @notice Reverts when attempting to bind escrow more than once.
    /// @param escrow Existing bound escrow.
    error EscrowAlreadyBound(address escrow);
    /// @notice Reverts when a platform request identifier is unknown.
    /// @param requestId Unknown Somnia platform request identifier.
    error UnknownRequest(uint256 requestId);
    /// @notice Reverts when a terminal callback was already accepted.
    /// @param requestId Somnia platform request identifier.
    error RequestAlreadyFulfilled(uint256 requestId);
    /// @notice Reverts when the platform reports a non-terminal or unsupported callback status.
    /// @param status Unsupported status.
    error UnsupportedResponseStatus(ISomniaAgentRequester.ResponseStatus status);
    /// @notice Reverts when caller is not authorized for an action.
    /// @param caller Unauthorized caller.
    error Unauthorized(address caller);
    /// @notice Reverts when an account has no pending verification refund credit.
    /// @param account Account without pending credit.
    error NoPendingVerificationRefund(address account);
    /// @notice Reverts when a native-token transfer fails.
    /// @param recipient Intended recipient.
    /// @param amount Native-token amount that failed to transfer.
    error TransferFailed(address recipient, uint256 amount);

    /// @notice Somnia Agent requester platform contract.
    ISomniaAgentRequester public immutable platform;

    /// @notice Account allowed to bind this adapter to the escrow once after deployment.
    address public immutable escrowBinder;

    /// @notice Escrow settlement receiver allowed to create settlement requests and receive forwarded verdicts.
    /// @dev Future GrantRound contracts can implement `IVigiliaEscrowVerdictReceiver` and be bound here.
    address public escrow;

    /// @notice Agent configuration by kind.
    mapping(VigiliaAgentTypes.AgentKind kind => VigiliaMultiAgentTypes.AgentConfig config) public agentConfigs;

    /// @notice Request metadata by Somnia platform request identifier.
    mapping(uint256 platformRequestId => VigiliaMultiAgentTypes.RequestContext context) public requests;

    /// @notice Current platform request for each task/submission pair.
    mapping(uint256 taskId => mapping(uint256 submissionId => uint256 platformRequestId)) public activePlatformRequest;

    /// @notice Native-token credits from unused prepaid LLM budgets after JSON-stage failures.
    mapping(address requester => uint256 amount) public pendingVerificationRefunds;

    /// @notice Creates the v0.2.0 canary-first multi-agent verifier.
    /// @param _config Deployment configuration.
    constructor(ConstructorConfig memory _config) {
        if (_config.platform == address(0) || _config.escrowBinder == address(0)) revert InvalidAddress();
        if (
            _config.jsonApiAgentId == 0 || _config.subcommitteeSize == 0 || _config.jsonApiPricePerValidator == 0
                || bytes(_config.jsonApiSelector).length == 0
        ) revert InvalidAmount();

        platform = ISomniaAgentRequester(_config.platform);
        escrowBinder = _config.escrowBinder;

        _configure(
            VigiliaAgentTypes.AgentKind.JsonApi,
            _config.jsonApiAgentId,
            _config.jsonApiPricePerValidator,
            _config.subcommitteeSize,
            _config.jsonApiSelector,
            true,
            true
        );
        _configureOptionalCanary(
            VigiliaAgentTypes.AgentKind.LlmInference,
            _config.llmInferenceAgentId,
            _config.llmInferencePricePerValidator,
            _config.subcommitteeSize,
            "inferString(string,string,bool,string[])",
            _config.enableLlmInferenceSettlement
        );
        _configureOptionalCanary(
            VigiliaAgentTypes.AgentKind.LlmParseWebsite,
            _config.llmParseWebsiteAgentId,
            _config.llmParseWebsitePricePerValidator,
            _config.subcommitteeSize,
            "ExtractString(string,string,string[],string,string,bool,uint8,uint8)",
            _config.enableLlmInferenceSettlement
        );
    }

    /// @notice Accepts Somnia platform rebates after request finalization.
    receive() external payable {
        emit SomniaRebateReceived(msg.sender, msg.value);
    }

    /// @notice Binds this verifier to exactly one settlement receiver contract.
    /// @dev This does not create a global admin role; the receiver still owns settlement state and funds.
    /// @param _escrow Settlement receiver contract address implementing `IVigiliaEscrowVerdictReceiver`.
    function bindEscrow(address _escrow) external {
        if (msg.sender != escrowBinder) revert Unauthorized(msg.sender);
        if (_escrow == address(0)) revert InvalidAddress();
        if (escrow != address(0)) revert EscrowAlreadyBound(escrow);

        escrow = _escrow;

        emit EscrowBound(_escrow);
    }

    /// @notice Returns the minimum native-token deposit required for a kind.
    /// @param _kind Agent kind being requested.
    /// @return deposit Required native-token deposit.
    function minimumRequestDeposit(VigiliaAgentTypes.AgentKind _kind) public view returns (uint256 deposit) {
        VigiliaMultiAgentTypes.AgentConfig storage config = _configured(_kind);
        deposit = platform.getRequestDeposit() + (config.pricePerValidator * config.subcommitteeSize);
    }

    /// @notice Returns the minimum native-token deposit required for a settlement workflow.
    /// @param _workflow Settlement workflow.
    /// @return deposit Required native-token deposit.
    function minimumRequestDepositForWorkflow(VigiliaAgentTypes.SettlementWorkflow _workflow)
        public
        view
        returns (uint256 deposit)
    {
        if (_workflow == VigiliaAgentTypes.SettlementWorkflow.JsonApiVerdict) {
            return minimumRequestDeposit(VigiliaAgentTypes.AgentKind.JsonApi);
        }
        if (_workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict) {
            return minimumRequestDeposit(VigiliaAgentTypes.AgentKind.JsonApi)
                + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference);
        }
        if (_workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict) {
            return minimumRequestDeposit(VigiliaAgentTypes.AgentKind.JsonApi)
                + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.JsonApi)
                + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmParseWebsite)
                + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference);
        }
        revert UnknownSettlementWorkflow(_workflow);
    }

    /// @inheritdoc IVigiliaVerifier
    function requestVerification(uint256 _taskId, uint256 _submissionId, address _payer, string calldata _evidenceURI)
        external
        payable
        returns (bytes32 vigiliaRequestId)
    {
        vigiliaRequestId = _requestVerification(
            _taskId, _submissionId, _payer, _evidenceURI, "", VigiliaAgentTypes.SettlementWorkflow.JsonApiVerdict
        );
    }

    /// @inheritdoc IVigiliaVerifier
    function requestVerification(
        uint256 _taskId,
        uint256 _submissionId,
        address _payer,
        string calldata _evidenceURI,
        string calldata _requirementsURI,
        VigiliaAgentTypes.SettlementWorkflow _workflow
    ) external payable returns (bytes32 vigiliaRequestId) {
        vigiliaRequestId = _requestVerification(
            _taskId, _submissionId, _payer, _evidenceURI, _requirementsURI, _workflow
        );
    }

    /// @notice Continues a two-agent settlement workflow if automatic LLM request creation was unavailable.
    /// @param _parentRequestId Escrow-facing JSON facts request identifier.
    /// @return llmRequestId New LLM Inference platform request identifier.
    function continueLlmVerification(uint256 _parentRequestId) external returns (uint256 llmRequestId) {
        VigiliaMultiAgentTypes.RequestContext storage context = requests[_parentRequestId];
        if (!_canContinueLlm(_parentRequestId, context)) revert ContinuationUnavailable(_parentRequestId);

        llmRequestId = _startLlmVerdictStage(_parentRequestId, context);
    }

    /// @notice Withdraws verification refund credit to the caller.
    function withdrawVerificationRefund() external {
        withdrawVerificationRefundTo(payable(msg.sender));
    }

    /// @notice Withdraws verification refund credit to an explicit recipient.
    /// @dev Credits are cleared before transfer, so a reverting recipient cannot corrupt accounting or reenter for the
    /// same funds.
    /// @param _recipient Native-token recipient chosen by the credited requester.
    function withdrawVerificationRefundTo(address payable _recipient) public {
        if (_recipient == address(0)) revert InvalidAddress();

        uint256 amount = pendingVerificationRefunds[msg.sender];
        if (amount == 0) revert NoPendingVerificationRefund(msg.sender);

        pendingVerificationRefunds[msg.sender] = 0;

        (bool success,) = _recipient.call{ value: amount }("");
        if (!success) revert TransferFailed(_recipient, amount);

        emit VerificationBudgetRefundWithdrawn(_recipient, amount);
    }

    /// @notice Creates a JSON API Request canary without touching escrow settlement.
    /// @param _url Public JSON endpoint.
    /// @param _selector JSON selector to extract.
    /// @return platformRequestId Somnia platform request identifier.
    function requestJsonApiCanary(string calldata _url, string calldata _selector)
        external
        payable
        returns (uint256 platformRequestId)
    {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.JsonApi;
        _requireCanaryEnabled(kind);

        bytes memory payload = VigiliaMultiAgentPlatformLib.jsonApiPayload(_url, _selector);
        platformRequestId =
            _createTrackedRequest(kind, 0, 0, msg.sender, keccak256(abi.encode(_url, _selector)), true, payload);

        emit CanaryRequested(
            platformRequestId,
            kind,
            msg.sender,
            agentConfigs[kind].agentId,
            msg.value,
            keccak256(abi.encode(_url, _selector))
        );
    }

    /// @notice Creates an LLM Inference canary without touching escrow settlement.
    /// @dev The prompt should instruct the model to return exactly one of the bounded verdict strings.
    /// @param _prompt Prompt supplied to the LLM Inference method.
    /// @param _system Optional system prompt. Pass an empty string when unused.
    /// @param _chainOfThought Whether to request chain-of-thought reasoning from the base agent.
    /// @return platformRequestId Somnia platform request identifier.
    function requestLlmInferenceCanary(string calldata _prompt, string calldata _system, bool _chainOfThought)
        public
        payable
        returns (uint256 platformRequestId)
    {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.LlmInference;
        _requireCanaryEnabled(kind);

        string[] memory allowedValues = VigiliaAgentStringLib.allowedVerdictValues();
        bytes memory payload = abi.encodeWithSelector(
            ILlmInferenceAgent.inferString.selector, _prompt, _system, _chainOfThought, allowedValues
        );
        platformRequestId =
            _createTrackedRequest(kind, 0, 0, msg.sender, keccak256(abi.encode(_prompt, _system)), true, payload);

        emit CanaryRequested(
            platformRequestId,
            kind,
            msg.sender,
            agentConfigs[kind].agentId,
            msg.value,
            keccak256(abi.encode(_prompt, _system))
        );
    }

    /// @notice Creates an LLM Parse Website canary without touching escrow settlement.
    /// @dev Uses the documented `ExtractString` direct URL mode with bounded verdict options.
    /// @param _url Public website URL to inspect.
    /// @param _instruction Extraction instruction asking for one bounded verdict string.
    /// @return platformRequestId Somnia platform request identifier.
    function requestLlmParseWebsiteCanary(string calldata _url, string calldata _instruction)
        external
        payable
        returns (uint256 platformRequestId)
    {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.LlmParseWebsite;
        _requireCanaryEnabled(kind);

        string[] memory allowedValues = VigiliaAgentStringLib.allowedVerdictValues();
        bytes memory payload = abi.encodeWithSelector(
            ILlmParseWebsiteAgent.ExtractString.selector,
            "verdict",
            "Vigilia milestone verification verdict. Return one bounded value.",
            allowedValues,
            _instruction,
            _url,
            false,
            uint8(1),
            uint8(70)
        );
        platformRequestId =
            _createTrackedRequest(kind, 0, 0, msg.sender, keccak256(abi.encode(_url, _instruction)), true, payload);

        emit CanaryRequested(
            platformRequestId,
            kind,
            msg.sender,
            agentConfigs[kind].agentId,
            msg.value,
            keccak256(abi.encode(_url, _instruction))
        );
    }

    /// @notice Decodes ABI-encoded string agent output.
    /// @dev Externally callable only by this contract so malformed bytes can be caught with try/catch.
    /// @param _result ABI-encoded string bytes returned by an agent.
    /// @return decoded Decoded string.
    function decodeAgentString(bytes calldata _result) external view returns (string memory decoded) {
        if (msg.sender != address(this)) revert DecodeOnlySelf();
        decoded = abi.decode(_result, (string));
    }

    /// @notice Starts the LLM verdict stage from inside a JSON facts callback.
    /// @dev External self-call allows `handleResponse` to catch platform createRequest failures and fall back to
    /// `continueLlmVerification`.
    /// @param _parentRequestId Escrow-facing JSON facts request identifier.
    /// @return llmRequestId New LLM platform request identifier.
    function startLlmVerdictStageFromCallback(uint256 _parentRequestId) external returns (uint256 llmRequestId) {
        if (msg.sender != address(this)) revert DecodeOnlySelf();
        VigiliaMultiAgentTypes.RequestContext storage context = requests[_parentRequestId];
        if (!_canContinueLlm(_parentRequestId, context)) revert ContinuationUnavailable(_parentRequestId);
        llmRequestId = _startLlmVerdictStage(_parentRequestId, context);
    }

    /// @notice Starts the JSON websiteURI stage from inside a ThreeAgent JSON facts callback.
    /// @dev External self-call lets `handleResponse` catch platform createRequest failures and fail closed.
    /// @param _parentRequestId Receiver-facing JSON facts root request identifier.
    /// @return websiteUriRequestId New JSON API platform request identifier.
    function startJsonWebsiteURIStageFromCallback(uint256 _parentRequestId)
        external
        returns (uint256 websiteUriRequestId)
    {
        if (msg.sender != address(this)) revert DecodeOnlySelf();
        VigiliaMultiAgentTypes.RequestContext storage context = requests[_parentRequestId];
        if (!_canContinueWebsiteURI(_parentRequestId, context)) revert ContinuationUnavailable(_parentRequestId);
        websiteUriRequestId = _startJsonWebsiteURIStage(_parentRequestId, context);
    }

    /// @notice Starts the Website Parse stage from inside a ThreeAgent websiteURI callback.
    /// @dev External self-call lets `handleResponse` catch platform createRequest failures and fail closed.
    /// @param _websiteUriRequestId JSON websiteURI platform request identifier.
    /// @return websiteParseRequestId New Website Parse platform request identifier.
    function startWebsiteParseStageFromCallback(uint256 _websiteUriRequestId)
        external
        returns (uint256 websiteParseRequestId)
    {
        if (msg.sender != address(this)) revert DecodeOnlySelf();
        VigiliaMultiAgentTypes.RequestContext storage context = requests[_websiteUriRequestId];
        if (!_canContinueWebsiteParse(context)) revert ContinuationUnavailable(_websiteUriRequestId);
        websiteParseRequestId = _startWebsiteParseStage(_websiteUriRequestId, context);
    }

    /// @notice Starts the final ThreeAgent LLM verdict stage from inside a Website Parse callback.
    /// @dev External self-call lets `handleResponse` catch platform createRequest failures and fail closed.
    /// @param _websiteParseRequestId Website Parse platform request identifier.
    /// @return llmRequestId New LLM Inference platform request identifier.
    function startThreeAgentLlmVerdictStageFromCallback(uint256 _websiteParseRequestId)
        external
        returns (uint256 llmRequestId)
    {
        if (msg.sender != address(this)) revert DecodeOnlySelf();
        VigiliaMultiAgentTypes.RequestContext storage context = requests[_websiteParseRequestId];
        if (!_canContinueThreeAgentLlm(context)) revert ContinuationUnavailable(_websiteParseRequestId);
        llmRequestId = _startThreeAgentLlmVerdictStage(_websiteParseRequestId, context);
    }

    /// @notice Handles a final Somnia Agent platform callback for canary or settlement requests.
    /// @param _requestId Somnia platform request identifier.
    /// @param _responses Validator responses supplied by the platform.
    /// @param _status Final platform status.
    /// @param _details Full platform request details. Present for ABI compatibility.
    function handleResponse(
        uint256 _requestId,
        ISomniaAgentRequester.Response[] memory _responses,
        ISomniaAgentRequester.ResponseStatus _status,
        ISomniaAgentRequester.Request memory _details
    ) external {
        _handleResponse(_requestId, _responses, _status);
        _details;
    }

    /// @dev Validates and processes a Somnia platform callback.
    function _handleResponse(
        uint256 _requestId,
        ISomniaAgentRequester.Response[] memory _responses,
        ISomniaAgentRequester.ResponseStatus _status
    ) private {
        if (msg.sender != address(platform)) {
            revert Unauthorized(msg.sender);
        }

        VigiliaMultiAgentTypes.RequestContext storage context = requests[_requestId];
        if (!context.exists) revert UnknownRequest(_requestId);

        if (_rejectStaleSettlementCallback(_requestId, context)) return;

        if (context.fulfilled) revert RequestAlreadyFulfilled(_requestId);
        context.fulfilled = true;

        if (
            _status == ISomniaAgentRequester.ResponseStatus.Failed
                || _status == ISomniaAgentRequester.ResponseStatus.TimedOut
        ) {
            _handleTerminalFailure(_requestId, context, _status, VigiliaAgentStringLib.somniaNotesUri(_requestId));
            return;
        }

        if (_status != ISomniaAgentRequester.ResponseStatus.Success) revert UnsupportedResponseStatus(_status);

        _handleSuccessfulResponse(_requestId, context, _responses);
    }

    /// @dev Ignores stale settlement callbacks once a newer active request exists for the task/submission.
    /// @return stale True when the callback was stale and processing should stop.
    function _rejectStaleSettlementCallback(uint256 _requestId, VigiliaMultiAgentTypes.RequestContext storage context)
        private
        returns (bool stale)
    {
        if (!context.isSettlement) return false;

        uint256 rootRequestId = _rootRequestId(_requestId, context);
        uint256 activeRequestId = activePlatformRequest[context.taskId][context.submissionId];
        if (activeRequestId == rootRequestId) return false;

        if (!context.fulfilled) {
            context.fulfilled = true;
        }
        emit StaleSomniaCallbackIgnored(rootRequestId, activeRequestId, context.taskId, context.submissionId);
        return true;
    }

    /// @dev Routes escrow settlement requests to the configured workflow implementation.
    /// @param _taskId Task identifier supplied by escrow.
    /// @param _submissionId Submission identifier supplied by escrow.
    /// @param _payer Account that paid the verification deposit forwarded by escrow.
    /// @param _evidenceURI Public evidence URI under verification.
    /// @param _requirementsURI Task requirements URI required by the two-agent workflow.
    /// @param _workflow Settlement workflow selected by escrow.
    /// @return vigiliaRequestId Escrow-facing request identifier derived from the platform request ID.
    function _requestVerification(
        uint256 _taskId,
        uint256 _submissionId,
        address _payer,
        string calldata _evidenceURI,
        string memory _requirementsURI,
        VigiliaAgentTypes.SettlementWorkflow _workflow
    ) private returns (bytes32 vigiliaRequestId) {
        if (msg.sender != escrow) revert Unauthorized(msg.sender);
        if (_payer == address(0)) revert InvalidAddress();

        if (_workflow == VigiliaAgentTypes.SettlementWorkflow.JsonApiVerdict) {
            vigiliaRequestId = _requestJsonApiVerdict(_taskId, _submissionId, _payer, _evidenceURI);
        } else if (_workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict) {
            vigiliaRequestId =
                _requestJsonFactsToLlmVerdict(_taskId, _submissionId, _payer, _evidenceURI, _requirementsURI);
        } else if (_workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict) {
            vigiliaRequestId = _requestJsonFactsAndWebsiteToLlmVerdict(
                _taskId, _submissionId, _payer, _evidenceURI, _requirementsURI
            );
        } else {
            revert UnknownSettlementWorkflow(_workflow);
        }
    }

    /// @dev Starts the proven single-agent JSON API settlement path.
    /// @param _taskId Task identifier supplied by escrow.
    /// @param _submissionId Submission identifier supplied by escrow.
    /// @param _payer Account that paid the verification deposit forwarded by escrow.
    /// @param _evidenceURI Public evidence URI whose configured selector must return a bounded verdict string.
    /// @return vigiliaRequestId Escrow-facing request identifier derived from the platform request ID.
    function _requestJsonApiVerdict(
        uint256 _taskId,
        uint256 _submissionId,
        address _payer,
        string calldata _evidenceURI
    ) private returns (bytes32 vigiliaRequestId) {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.JsonApi;
        VigiliaMultiAgentTypes.AgentConfig storage config = _configured(kind);
        if (!config.settlementEnabled) revert SettlementDisabled(kind);
        uint256 requiredDeposit = minimumRequestDepositForWorkflow(VigiliaAgentTypes.SettlementWorkflow.JsonApiVerdict);
        if (msg.value != requiredDeposit) revert InvalidVerificationDeposit(requiredDeposit, msg.value);

        uint256 platformRequestId = _createPlatformRequest(
            kind, requiredDeposit, VigiliaMultiAgentPlatformLib.jsonApiPayload(_evidenceURI, config.selector)
        );
        _initSettlementContext(
            requests[platformRequestId],
            _taskId,
            _submissionId,
            kind,
            _payer,
            keccak256(bytes(_evidenceURI)),
            VigiliaAgentTypes.SettlementWorkflow.JsonApiVerdict,
            VigiliaAgentTypes.VerificationStage.LlmVerdict,
            _evidenceURI
        );
        activePlatformRequest[_taskId][_submissionId] = platformRequestId;
        vigiliaRequestId = bytes32(platformRequestId);
        _emitSettlementRequested(platformRequestId, _evidenceURI);
    }

    /// @dev Starts the two-agent workflow by fetching structured facts before the prepaid LLM verdict stage.
    /// @param _taskId Task identifier supplied by escrow.
    /// @param _submissionId Submission identifier supplied by escrow.
    /// @param _payer Account that paid the combined JSON + LLM deposit forwarded by escrow.
    /// @param _evidenceURI Public evidence URI whose `facts` selector output is passed to the LLM stage.
    /// @param _requirementsURI Task requirements text or URI included in the LLM prompt.
    /// @return vigiliaRequestId Escrow-facing request identifier derived from the JSON facts platform request ID.
    function _requestJsonFactsToLlmVerdict(
        uint256 _taskId,
        uint256 _submissionId,
        address _payer,
        string calldata _evidenceURI,
        string memory _requirementsURI
    ) private returns (bytes32 vigiliaRequestId) {
        VigiliaAgentTypes.AgentKind jsonKind = VigiliaAgentTypes.AgentKind.JsonApi;
        VigiliaMultiAgentTypes.AgentConfig storage jsonConfig = _configured(jsonKind);
        if (!jsonConfig.settlementEnabled) revert SettlementDisabled(jsonKind);
        if (!_configured(VigiliaAgentTypes.AgentKind.LlmInference).settlementEnabled) {
            revert SettlementDisabled(VigiliaAgentTypes.AgentKind.LlmInference);
        }

        uint256 requiredDeposit =
            minimumRequestDepositForWorkflow(VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict);
        if (msg.value != requiredDeposit) revert InvalidVerificationDeposit(requiredDeposit, msg.value);

        uint256 platformRequestId = _createPlatformRequest(
            jsonKind,
            minimumRequestDeposit(jsonKind),
            VigiliaMultiAgentPlatformLib.jsonApiPayload(_evidenceURI, _FACTS_SELECTOR)
        );
        VigiliaMultiAgentTypes.RequestContext storage context = requests[platformRequestId];
        _initSettlementContext(
            context,
            _taskId,
            _submissionId,
            jsonKind,
            _payer,
            keccak256(abi.encode(_evidenceURI, _requirementsURI)),
            VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict,
            VigiliaAgentTypes.VerificationStage.JsonFacts,
            _evidenceURI
        );
        context.requirementsURI = _requirementsURI;
        context.prepaidBudget = minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference);
        activePlatformRequest[_taskId][_submissionId] = platformRequestId;
        vigiliaRequestId = bytes32(platformRequestId);
        _emitSettlementRequested(platformRequestId, _evidenceURI);
    }

    /// @dev Starts the ThreeAgent workflow by fetching JSON facts before website URI, Website Parse, and final LLM.
    /// @param _taskId Task or round identifier supplied by the settlement receiver.
    /// @param _submissionId Submission or application identifier supplied by the settlement receiver.
    /// @param _payer Account that paid the combined workflow deposit forwarded by the receiver.
    /// @param _evidenceURI Public evidence bundle URI whose `facts` and `websiteURI` fields are fetched.
    /// @param _requirementsURI Task or grant requirements text or URI included in the final LLM prompt.
    /// @return vigiliaRequestId Receiver-facing request identifier derived from the JSON facts platform request ID.
    function _requestJsonFactsAndWebsiteToLlmVerdict(
        uint256 _taskId,
        uint256 _submissionId,
        address _payer,
        string calldata _evidenceURI,
        string memory _requirementsURI
    ) private returns (bytes32 vigiliaRequestId) {
        VigiliaAgentTypes.AgentKind jsonKind = VigiliaAgentTypes.AgentKind.JsonApi;
        VigiliaMultiAgentTypes.AgentConfig storage jsonConfig = _configured(jsonKind);
        if (!jsonConfig.settlementEnabled) revert SettlementDisabled(jsonKind);
        if (!_configured(VigiliaAgentTypes.AgentKind.LlmInference).settlementEnabled) {
            revert SettlementDisabled(VigiliaAgentTypes.AgentKind.LlmInference);
        }
        if (!_configured(VigiliaAgentTypes.AgentKind.LlmParseWebsite).settlementEnabled) {
            revert SettlementDisabled(VigiliaAgentTypes.AgentKind.LlmParseWebsite);
        }

        uint256 requiredDeposit =
            minimumRequestDepositForWorkflow(VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict);
        if (msg.value != requiredDeposit) revert InvalidVerificationDeposit(requiredDeposit, msg.value);

        uint256 platformRequestId = _createPlatformRequest(
            jsonKind,
            minimumRequestDeposit(jsonKind),
            VigiliaMultiAgentPlatformLib.jsonApiPayload(_evidenceURI, _FACTS_SELECTOR)
        );
        VigiliaMultiAgentTypes.RequestContext storage context = requests[platformRequestId];
        _initSettlementContext(
            context,
            _taskId,
            _submissionId,
            jsonKind,
            _payer,
            keccak256(abi.encode(_evidenceURI, _requirementsURI, _WEBSITE_URI_SELECTOR)),
            VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict,
            VigiliaAgentTypes.VerificationStage.JsonFacts,
            _evidenceURI
        );
        context.requirementsURI = _requirementsURI;
        context.prepaidBudget = minimumRequestDeposit(jsonKind)
            + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmParseWebsite)
            + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference);
        activePlatformRequest[_taskId][_submissionId] = platformRequestId;
        vigiliaRequestId = bytes32(platformRequestId);
        _emitSettlementRequested(platformRequestId, _evidenceURI);
    }

    /// @dev Parses a successful platform callback, advances multi-stage workflows, or forwards a bounded verdict.
    /// @param _requestId Somnia platform request identifier receiving the callback.
    /// @param context Stored request context for the callback target.
    /// @param _responses Validator responses supplied by the platform.
    function _handleSuccessfulResponse(
        uint256 _requestId,
        VigiliaMultiAgentTypes.RequestContext storage context,
        ISomniaAgentRequester.Response[] memory _responses
    ) private {
        (bool decoded, string memory result) = _decodeSuccessfulResult(_responses);
        if (!decoded) {
            _handleTerminalFailure(
                _requestId,
                context,
                ISomniaAgentRequester.ResponseStatus.Success,
                VigiliaAgentStringLib.failureNotesUri(_requestId, "malformed")
            );
            return;
        }

        if (
            context.workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict
                && context.stage == VigiliaAgentTypes.VerificationStage.JsonFacts
        ) {
            if (bytes(result).length == 0) {
                _handleTerminalFailure(
                    _requestId,
                    context,
                    ISomniaAgentRequester.ResponseStatus.Success,
                    VigiliaAgentStringLib.failureNotesUri(_requestId, "empty-facts")
                );
                return;
            }

            context.facts = result;
            emit JsonFactsReceived(_requestId, context.taskId, context.submissionId, result);

            try this.startLlmVerdictStageFromCallback(_requestId) returns (uint256) { }
            catch {
                emit LlmVerdictContinuationRequired(_requestId, context.taskId, context.submissionId);
            }
            return;
        }

        if (
            context.workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict
                && context.stage == VigiliaAgentTypes.VerificationStage.JsonFacts
        ) {
            if (bytes(result).length == 0) {
                _handleTerminalFailure(
                    _requestId,
                    context,
                    ISomniaAgentRequester.ResponseStatus.Success,
                    VigiliaAgentStringLib.failureNotesUri(_requestId, "empty-facts")
                );
                return;
            }

            context.facts = result;
            emit JsonFactsReceived(_requestId, context.taskId, context.submissionId, result);

            try this.startJsonWebsiteURIStageFromCallback(_requestId) returns (uint256) { }
            catch {
                _handleTerminalFailure(
                    _requestId,
                    context,
                    ISomniaAgentRequester.ResponseStatus.Success,
                    VigiliaAgentStringLib.failureNotesUri(_requestId, "website-uri-continuation")
                );
            }
            return;
        }

        if (
            context.workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict
                && context.stage == VigiliaAgentTypes.VerificationStage.JsonWebsiteURI
        ) {
            if (bytes(result).length == 0) {
                _handleTerminalFailure(
                    _requestId,
                    context,
                    ISomniaAgentRequester.ResponseStatus.Success,
                    VigiliaAgentStringLib.failureNotesUri(_requestId, "missing-website-uri")
                );
                return;
            }

            context.websiteURI = result;
            emit JsonWebsiteURIReceived(_requestId, context.taskId, context.submissionId, result);

            try this.startWebsiteParseStageFromCallback(_requestId) returns (uint256) { }
            catch {
                _handleTerminalFailure(
                    _requestId,
                    context,
                    ISomniaAgentRequester.ResponseStatus.Success,
                    VigiliaAgentStringLib.failureNotesUri(_requestId, "website-parse-continuation")
                );
            }
            return;
        }

        if (
            context.workflow == VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict
                && context.stage == VigiliaAgentTypes.VerificationStage.WebsiteParse
        ) {
            if (bytes(result).length == 0) {
                _handleTerminalFailure(
                    _requestId,
                    context,
                    ISomniaAgentRequester.ResponseStatus.Success,
                    VigiliaAgentStringLib.failureNotesUri(_requestId, "empty-website-parse")
                );
                return;
            }

            context.websiteExtract = result;
            emit WebsiteParseEvidenceReceived(_requestId, context.taskId, context.submissionId, result);

            try this.startThreeAgentLlmVerdictStageFromCallback(_requestId) returns (uint256) { }
            catch {
                _handleTerminalFailure(
                    _requestId,
                    context,
                    ISomniaAgentRequester.ResponseStatus.Success,
                    VigiliaAgentStringLib.failureNotesUri(_requestId, "llm-continuation")
                );
            }
            return;
        }

        (bool parsed, VigiliaTypes.VerificationVerdict verdict) = VigiliaAgentStringLib.parseVerdict(result);
        if (!parsed) {
            _handleTerminalFailure(
                _requestId,
                context,
                ISomniaAgentRequester.ResponseStatus.Success,
                VigiliaAgentStringLib.failureNotesUri(_requestId, "unknown-verdict")
            );
            return;
        }

        if (context.isCanary) {
            emit CanarySucceeded(_requestId, context.kind, verdict, result);
        } else {
            _forwardVerdict(_requestId, context, verdict, result);
        }
    }

    /// @dev Configures a required or optional agent kind.
    function _configure(
        VigiliaAgentTypes.AgentKind _kind,
        uint256 _agentId,
        uint256 _pricePerValidator,
        uint256 _subcommitteeSize,
        string memory _selector,
        bool _canaryEnabled,
        bool _settlementEnabled
    ) private {
        if (_kind == VigiliaAgentTypes.AgentKind.Unknown) revert UnknownAgentKind(_kind);
        if (_agentId == 0 || _pricePerValidator == 0 || _subcommitteeSize == 0) revert InvalidAmount();

        agentConfigs[_kind] = VigiliaMultiAgentTypes.AgentConfig({
            agentId: _agentId,
            pricePerValidator: _pricePerValidator,
            subcommitteeSize: _subcommitteeSize,
            selector: _selector,
            canaryEnabled: _canaryEnabled,
            settlementEnabled: _settlementEnabled
        });

        emit AgentConfigured(
            _kind, _agentId, _pricePerValidator, _subcommitteeSize, _selector, _canaryEnabled, _settlementEnabled
        );
    }

    /// @dev Configures an optional canary-only agent kind when both ID and price are supplied.
    function _configureOptionalCanary(
        VigiliaAgentTypes.AgentKind _kind,
        uint256 _agentId,
        uint256 _pricePerValidator,
        uint256 _subcommitteeSize,
        string memory _selector,
        bool _settlementEnabled
    ) private {
        if (_agentId == 0 || _pricePerValidator == 0) {
            return;
        }

        _configure(_kind, _agentId, _pricePerValidator, _subcommitteeSize, _selector, true, _settlementEnabled);
    }

    /// @dev Loads a configured agent kind and rejects unset/unknown kinds.
    function _configured(VigiliaAgentTypes.AgentKind _kind)
        private
        view
        returns (VigiliaMultiAgentTypes.AgentConfig storage config)
    {
        if (_kind == VigiliaAgentTypes.AgentKind.Unknown) revert UnknownAgentKind(_kind);

        config = agentConfigs[_kind];
        if (config.agentId == 0) revert UnknownAgentKind(_kind);
    }

    /// @dev Reverts when canary requests are not enabled for a kind.
    function _requireCanaryEnabled(VigiliaAgentTypes.AgentKind _kind) private view {
        VigiliaMultiAgentTypes.AgentConfig storage config = _configured(_kind);
        if (!config.canaryEnabled) revert CanaryDisabled(_kind);
    }

    /// @dev Returns whether a fulfilled JSON facts request may start its prepaid LLM verdict stage.
    /// @param _parentRequestId Escrow-facing JSON facts platform request identifier.
    /// @param _context Stored parent request context.
    /// @return canContinue True when continuation preconditions are satisfied.
    function _canContinueLlm(uint256 _parentRequestId, VigiliaMultiAgentTypes.RequestContext storage _context)
        private
        view
        returns (bool canContinue)
    {
        if (!_context.exists || !_context.isSettlement || !_context.fulfilled) return false;
        if (_context.workflow != VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict) return false;
        if (_context.stage != VigiliaAgentTypes.VerificationStage.JsonFacts) return false;
        if (_context.prepaidBudget != minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference)) return false;
        if (bytes(_context.facts).length == 0) return false;
        uint256 activeRequestId = activePlatformRequest[_context.taskId][_context.submissionId];
        return activeRequestId == _parentRequestId;
    }

    /// @dev Returns whether a fulfilled ThreeAgent facts request may start the JSON websiteURI stage.
    function _canContinueWebsiteURI(uint256 _parentRequestId, VigiliaMultiAgentTypes.RequestContext storage _context)
        private
        view
        returns (bool canContinue)
    {
        if (!_context.exists || !_context.isSettlement || !_context.fulfilled) return false;
        if (_context.workflow != VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict) return false;
        if (_context.stage != VigiliaAgentTypes.VerificationStage.JsonFacts) return false;
        if (bytes(_context.facts).length == 0) return false;
        uint256 expectedBudget = minimumRequestDeposit(VigiliaAgentTypes.AgentKind.JsonApi)
            + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmParseWebsite)
            + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference);
        if (_context.prepaidBudget != expectedBudget) return false;
        uint256 activeRequestId = activePlatformRequest[_context.taskId][_context.submissionId];
        return activeRequestId == _parentRequestId;
    }

    /// @dev Returns whether a fulfilled ThreeAgent websiteURI request may start Website Parse.
    function _canContinueWebsiteParse(VigiliaMultiAgentTypes.RequestContext storage _context)
        private
        view
        returns (bool canContinue)
    {
        if (!_context.exists || !_context.isSettlement || !_context.fulfilled) return false;
        if (_context.workflow != VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict) return false;
        if (_context.stage != VigiliaAgentTypes.VerificationStage.JsonWebsiteURI) return false;
        if (bytes(_context.facts).length == 0 || bytes(_context.websiteURI).length == 0) return false;
        uint256 expectedBudget = minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmParseWebsite)
            + minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference);
        if (_context.prepaidBudget != expectedBudget) return false;
        uint256 rootRequestId = _rootRequestId(0, _context);
        uint256 activeRequestId = activePlatformRequest[_context.taskId][_context.submissionId];
        return activeRequestId == rootRequestId;
    }

    /// @dev Returns whether a fulfilled ThreeAgent Website Parse request may start final LLM classification.
    function _canContinueThreeAgentLlm(VigiliaMultiAgentTypes.RequestContext storage _context)
        private
        view
        returns (bool canContinue)
    {
        if (!_context.exists || !_context.isSettlement || !_context.fulfilled) return false;
        if (_context.workflow != VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict) return false;
        if (_context.stage != VigiliaAgentTypes.VerificationStage.WebsiteParse) return false;
        if (
            bytes(_context.facts).length == 0 || bytes(_context.websiteURI).length == 0
                || bytes(_context.websiteExtract).length == 0
        ) return false;
        if (_context.prepaidBudget != minimumRequestDeposit(VigiliaAgentTypes.AgentKind.LlmInference)) return false;
        uint256 rootRequestId = _rootRequestId(0, _context);
        uint256 activeRequestId = activePlatformRequest[_context.taskId][_context.submissionId];
        return activeRequestId == rootRequestId;
    }

    /// @dev Creates the prepaid LLM Inference request for the second stage of the two-agent workflow.
    /// @param _parentRequestId Escrow-facing JSON facts platform request identifier.
    /// @param _parent Stored parent request context with retained facts and LLM budget.
    /// @return llmRequestId New LLM Inference platform request identifier.
    function _startLlmVerdictStage(uint256 _parentRequestId, VigiliaMultiAgentTypes.RequestContext storage _parent)
        private
        returns (uint256 llmRequestId)
    {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.LlmInference;
        VigiliaMultiAgentTypes.AgentConfig storage config = _configured(kind);
        if (!config.settlementEnabled) revert SettlementDisabled(kind);

        uint256 llmDeposit = _parent.prepaidBudget;
        _parent.prepaidBudget = 0;

        string memory prompt = VigiliaAgentStringLib.llmVerdictPrompt(_parent.requirementsURI, _parent.facts);
        string[] memory allowedValues = VigiliaAgentStringLib.allowedVerdictValues();
        bytes memory payload = abi.encodeWithSelector(
            ILlmInferenceAgent.inferString.selector, prompt, _LLM_SYSTEM_PROMPT, false, allowedValues
        );

        llmRequestId = _createPlatformRequest(kind, llmDeposit, payload);
        _initLlmVerdictChildContext(llmRequestId, _parent, _parentRequestId);

        emit LlmVerdictRequested(_parentRequestId, llmRequestId, _parent.taskId, _parent.submissionId, llmDeposit);
    }

    /// @dev Creates the JSON API websiteURI request for the second stage of the ThreeAgent workflow.
    function _startJsonWebsiteURIStage(uint256 _parentRequestId, VigiliaMultiAgentTypes.RequestContext storage _parent)
        private
        returns (uint256 websiteUriRequestId)
    {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.JsonApi;
        uint256 jsonDeposit = minimumRequestDeposit(kind);
        uint256 remainingBudget = _parent.prepaidBudget - jsonDeposit;
        _parent.prepaidBudget = 0;

        websiteUriRequestId = _createPlatformRequest(
            kind, jsonDeposit, VigiliaMultiAgentPlatformLib.jsonApiPayload(_parent.evidenceURI, _WEBSITE_URI_SELECTOR)
        );
        _initThreeAgentChildContext(
            websiteUriRequestId,
            _parent,
            _parentRequestId,
            kind,
            VigiliaAgentTypes.VerificationStage.JsonWebsiteURI,
            remainingBudget
        );

        emit MultiAgentVerificationRequested(
            bytes32(_parentRequestId),
            websiteUriRequestId,
            _parent.taskId,
            _parent.submissionId,
            kind,
            _parent.workflow,
            VigiliaAgentTypes.VerificationStage.JsonWebsiteURI,
            agentConfigs[kind].agentId,
            jsonDeposit,
            _parent.evidenceURI
        );
    }

    /// @dev Creates the Website Parse request for the third stage of the ThreeAgent workflow.
    function _startWebsiteParseStage(
        uint256 _websiteUriRequestId,
        VigiliaMultiAgentTypes.RequestContext storage _parent
    ) private returns (uint256 websiteParseRequestId) {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.LlmParseWebsite;
        VigiliaMultiAgentTypes.AgentConfig storage config = _configured(kind);
        if (!config.settlementEnabled) revert SettlementDisabled(kind);

        uint256 parseDeposit = minimumRequestDeposit(kind);
        uint256 remainingBudget = _parent.prepaidBudget - parseDeposit;
        _parent.prepaidBudget = 0;

        string[] memory emptyOptions = new string[](0);
        bytes memory payload = abi.encodeWithSelector(
            ILlmParseWebsiteAgent.ExtractString.selector,
            "grantEvidence",
            "Extract concise grant evidence: repo, README/setup docs, deployment address, demo URL, and tests/proof.",
            emptyOptions,
            "Extract project evidence from this HTML page for a grant eligibility screen. Include whether repo, setup docs, deployment address, demo URL, and tests/proof appear present.",
            _parent.websiteURI,
            false,
            uint8(1),
            uint8(50)
        );

        websiteParseRequestId = _createPlatformRequest(kind, parseDeposit, payload);
        _initThreeAgentChildContext(
            websiteParseRequestId,
            _parent,
            _rootFromParent(_websiteUriRequestId, _parent),
            kind,
            VigiliaAgentTypes.VerificationStage.WebsiteParse,
            remainingBudget
        );
        requests[websiteParseRequestId].websiteURI = _parent.websiteURI;

        emit WebsiteParseRequested(
            _rootFromParent(_websiteUriRequestId, _parent),
            websiteParseRequestId,
            _parent.taskId,
            _parent.submissionId,
            parseDeposit,
            _parent.websiteURI
        );
    }

    /// @dev Creates the final LLM Inference request for the fourth stage of the ThreeAgent workflow.
    function _startThreeAgentLlmVerdictStage(
        uint256 _websiteParseRequestId,
        VigiliaMultiAgentTypes.RequestContext storage _parent
    ) private returns (uint256 llmRequestId) {
        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.LlmInference;
        VigiliaMultiAgentTypes.AgentConfig storage config = _configured(kind);
        if (!config.settlementEnabled) revert SettlementDisabled(kind);

        uint256 llmDeposit = _parent.prepaidBudget;
        _parent.prepaidBudget = 0;

        string memory prompt = VigiliaAgentStringLib.threeAgentGrantVerdictPrompt(
            _parent.requirementsURI, _parent.facts, _parent.websiteExtract, _parent.evidenceURI, _parent.websiteURI
        );
        string[] memory allowedValues = VigiliaAgentStringLib.allowedVerdictValues();
        bytes memory payload = abi.encodeWithSelector(
            ILlmInferenceAgent.inferString.selector, prompt, _THREE_AGENT_LLM_SYSTEM_PROMPT, false, allowedValues
        );

        llmRequestId = _createPlatformRequest(kind, llmDeposit, payload);
        _initThreeAgentChildContext(
            llmRequestId,
            _parent,
            _rootFromParent(_websiteParseRequestId, _parent),
            kind,
            VigiliaAgentTypes.VerificationStage.LlmVerdict,
            0
        );

        emit LlmVerdictRequested(
            _rootFromParent(_websiteParseRequestId, _parent),
            llmRequestId,
            _parent.taskId,
            _parent.submissionId,
            llmDeposit
        );
    }

    /// @dev Returns the escrow-facing root request ID for child stage callbacks.
    /// @param _requestId Platform request identifier for the current callback.
    /// @param _context Stored request context for the callback target.
    /// @return root Escrow-facing platform request identifier.
    function _rootRequestId(uint256 _requestId, VigiliaMultiAgentTypes.RequestContext storage _context)
        private
        view
        returns (uint256 root)
    {
        root = _context.parentRequestId == 0 ? _requestId : _context.parentRequestId;
    }

    /// @dev Returns the existing root request ID from a parent context.
    function _rootFromParent(uint256 _requestId, VigiliaMultiAgentTypes.RequestContext storage _context)
        private
        view
        returns (uint256 root)
    {
        root = _rootRequestId(_requestId, _context);
    }

    /// @dev Creates a platform request, validates exact deposit, and stores context.
    function _createTrackedRequest(
        VigiliaAgentTypes.AgentKind _kind,
        uint256 _taskId,
        uint256 _submissionId,
        address _requester,
        bytes32 _inputHash,
        bool _isCanary,
        bytes memory _payload
    ) private returns (uint256 platformRequestId) {
        uint256 requiredDeposit = minimumRequestDeposit(_kind);
        if (msg.value != requiredDeposit) revert InvalidVerificationDeposit(requiredDeposit, msg.value);

        platformRequestId = _createPlatformRequest(_kind, msg.value, _payload);

        _initCanaryContext(
            requests[platformRequestId], _taskId, _submissionId, _kind, _requester, _inputHash, _isCanary
        );
    }

    /// @dev Initializes shared settlement request fields on a freshly created platform request.
    function _initSettlementContext(
        VigiliaMultiAgentTypes.RequestContext storage _context,
        uint256 _taskId,
        uint256 _submissionId,
        VigiliaAgentTypes.AgentKind _kind,
        address _payer,
        bytes32 _inputHash,
        VigiliaAgentTypes.SettlementWorkflow _workflow,
        VigiliaAgentTypes.VerificationStage _stage,
        string calldata _evidenceURI
    ) private {
        _context.taskId = _taskId;
        _context.submissionId = _submissionId;
        _context.kind = _kind;
        _context.requester = _payer;
        _context.inputHash = _inputHash;
        _context.workflow = _workflow;
        _context.stage = _stage;
        _context.evidenceURI = _evidenceURI;
        _context.isSettlement = true;
        _context.exists = true;
    }

    /// @dev Initializes the child LLM verdict request created by the two-agent workflow.
    function _initLlmVerdictChildContext(
        uint256 _llmRequestId,
        VigiliaMultiAgentTypes.RequestContext storage _parent,
        uint256 _parentRequestId
    ) private {
        VigiliaMultiAgentTypes.RequestContext storage child = requests[_llmRequestId];
        child.taskId = _parent.taskId;
        child.submissionId = _parent.submissionId;
        child.kind = VigiliaAgentTypes.AgentKind.LlmInference;
        child.requester = _parent.requester;
        child.inputHash = keccak256(abi.encode(_parent.requirementsURI, _parent.facts));
        child.workflow = VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict;
        child.stage = VigiliaAgentTypes.VerificationStage.LlmVerdict;
        child.evidenceURI = _parent.evidenceURI;
        child.requirementsURI = _parent.requirementsURI;
        child.facts = _parent.facts;
        child.parentRequestId = _parentRequestId;
        child.isSettlement = true;
        child.exists = true;
    }

    /// @dev Initializes a ThreeAgent child request while preserving the receiver-facing root request ID.
    function _initThreeAgentChildContext(
        uint256 _requestId,
        VigiliaMultiAgentTypes.RequestContext storage _parent,
        uint256 _parentRequestId,
        VigiliaAgentTypes.AgentKind _kind,
        VigiliaAgentTypes.VerificationStage _stage,
        uint256 _prepaidBudget
    ) private {
        VigiliaMultiAgentTypes.RequestContext storage child = requests[_requestId];
        child.taskId = _parent.taskId;
        child.submissionId = _parent.submissionId;
        child.kind = _kind;
        child.requester = _parent.requester;
        child.inputHash = keccak256(abi.encode(_parent.evidenceURI, _parent.requirementsURI, _stage));
        child.workflow = VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict;
        child.stage = _stage;
        child.evidenceURI = _parent.evidenceURI;
        child.requirementsURI = _parent.requirementsURI;
        child.facts = _parent.facts;
        child.websiteURI = _parent.websiteURI;
        child.websiteExtract = _parent.websiteExtract;
        child.prepaidBudget = _prepaidBudget;
        child.parentRequestId = _parentRequestId;
        child.isSettlement = true;
        child.exists = true;
    }

    /// @dev Initializes canary or settlement request fields for `_createTrackedRequest`.
    function _initCanaryContext(
        VigiliaMultiAgentTypes.RequestContext storage _context,
        uint256 _taskId,
        uint256 _submissionId,
        VigiliaAgentTypes.AgentKind _kind,
        address _requester,
        bytes32 _inputHash,
        bool _isCanary
    ) private {
        _context.taskId = _taskId;
        _context.submissionId = _submissionId;
        _context.kind = _kind;
        _context.requester = _requester;
        _context.inputHash = _inputHash;
        _context.isCanary = _isCanary;
        _context.isSettlement = !_isCanary;
        _context.exists = true;
    }

    /// @dev Emits the settlement request event shared by workflow entrypoints.
    /// @param _platformRequestId Somnia platform request identifier whose stored context is emitted.
    /// @param _evidenceURI Public evidence URI included in the event payload.
    function _emitSettlementRequested(uint256 _platformRequestId, string calldata _evidenceURI) private {
        VigiliaMultiAgentTypes.RequestContext storage context = requests[_platformRequestId];
        emit MultiAgentVerificationRequested(
            bytes32(_platformRequestId),
            _platformRequestId,
            context.taskId,
            context.submissionId,
            context.kind,
            context.workflow,
            context.stage,
            agentConfigs[context.kind].agentId,
            msg.value,
            _evidenceURI
        );
    }

    /// @dev Forwards value and payload to the Somnia Agent platform for a configured agent kind.
    /// @param _kind Agent kind whose configured ID receives the request.
    /// @param _value Native-token value forwarded to the platform for this request.
    /// @param _payload Encoded agent method payload.
    /// @return platformRequestId Somnia platform request identifier.
    function _createPlatformRequest(VigiliaAgentTypes.AgentKind _kind, uint256 _value, bytes memory _payload)
        private
        returns (uint256 platformRequestId)
    {
        platformRequestId = VigiliaMultiAgentPlatformLib.createPlatformRequest(
            platform, address(this), this.handleResponse.selector, agentConfigs, _kind, _value, _payload
        );
    }

    /// @dev Extracts and decodes the first successful validator result from a successful platform callback.
    function _decodeSuccessfulResult(ISomniaAgentRequester.Response[] memory _responses)
        private
        view
        returns (bool decoded, string memory result)
    {
        return VigiliaMultiAgentPlatformLib.decodeSuccessfulResult(address(this), _responses);
    }

    /// @dev Handles terminal failures for canary and settlement requests.
    function _handleTerminalFailure(
        uint256 _requestId,
        VigiliaMultiAgentTypes.RequestContext storage _context,
        ISomniaAgentRequester.ResponseStatus _status,
        string memory _failureNotesURI
    ) private {
        _creditUnusedPrepaidBudget(_requestId, _context);

        if (_context.isCanary) {
            emit CanaryFailed(_requestId, _context.kind, _status, _failureNotesURI);
        } else {
            _forwardVerificationFailure(_requestId, _context, _status, _failureNotesURI);
        }
    }

    /// @dev Credits unused prepaid workflow budget when a multi-stage workflow fails before a later stage starts.
    function _creditUnusedPrepaidBudget(uint256 _requestId, VigiliaMultiAgentTypes.RequestContext storage _context)
        private
    {
        if (
            (_context.workflow != VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict
                    && _context.workflow != VigiliaAgentTypes.SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict)
                || _context.prepaidBudget == 0
        ) {
            return;
        }

        uint256 refundAmount = _context.prepaidBudget;
        _context.prepaidBudget = 0;
        pendingVerificationRefunds[_context.requester] += refundAmount;

        emit VerificationBudgetRefundCredited(_requestId, _context.requester, refundAmount);
    }

    /// @dev Forwards terminal infrastructure failure to escrow and preserves callback finality if escrow rejects it.
    function _forwardVerificationFailure(
        uint256 _requestId,
        VigiliaMultiAgentTypes.RequestContext storage _context,
        ISomniaAgentRequester.ResponseStatus _status,
        string memory _failureNotesURI
    ) private {
        uint256 rootRequestId = _rootRequestId(_requestId, _context);
        try IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerificationFailure(
                _context.taskId, _context.submissionId, bytes32(rootRequestId), _failureNotesURI
            ) {
            emit MultiAgentVerificationFailed(
                _requestId,
                _context.taskId,
                _context.submissionId,
                _context.kind,
                _context.workflow,
                _status,
                _failureNotesURI
            );
        } catch (bytes memory returnData) {
            emit EscrowForwardingFailed(_requestId, _context.taskId, _context.submissionId, returnData);
        }
    }

    /// @dev Forwards a bounded verdict to escrow and preserves callback finality if escrow rejects it.
    function _forwardVerdict(
        uint256 _requestId,
        VigiliaMultiAgentTypes.RequestContext storage _context,
        VigiliaTypes.VerificationVerdict _verdict,
        string memory _result
    ) private {
        uint256 rootRequestId = _rootRequestId(_requestId, _context);
        try IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerdict(
                _context.taskId,
                _context.submissionId,
                bytes32(rootRequestId),
                _verdict,
                VigiliaAgentStringLib.somniaNotesUri(_requestId)
            ) {
            emit MultiAgentVerificationSucceeded(
                _requestId, _context.taskId, _context.submissionId, _context.kind, _context.workflow, _verdict, _result
            );
        } catch (bytes memory returnData) {
            emit EscrowForwardingFailed(_requestId, _context.taskId, _context.submissionId, returnData);
        }
    }
}
