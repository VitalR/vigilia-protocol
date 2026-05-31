// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IJsonApiAgent } from "./interfaces/IJsonApiAgent.sol";
import { ILlmInferenceAgent } from "./interfaces/ILlmInferenceAgent.sol";
import { ILlmParseWebsiteAgent } from "./interfaces/ILlmParseWebsiteAgent.sol";
import { ISomniaAgentRequester } from "./interfaces/ISomniaAgentRequester.sol";
import { IVigiliaEscrowVerdictReceiver } from "./interfaces/IVigiliaEscrowVerdictReceiver.sol";
import { IVigiliaVerifier } from "./interfaces/IVigiliaVerifier.sol";
import { VigiliaAgentTypes } from "./types/VigiliaAgentTypes.sol";
import { VigiliaTypes } from "./types/VigiliaTypes.sol";

/// @title VigiliaMultiAgentVerifier
/// @notice v0.2.0-ready Somnia Agent verifier/coordinator foundation with canary-first LLM support.
/// @dev The proven JSON API Request path can be used for escrow settlement. LLM kinds are canary-only by default; they
/// must not become settlement-critical until their exact ABI and live platform callback behavior are proven by
/// receipts.
contract VigiliaMultiAgentVerifier is IVigiliaVerifier {
    /// @notice Per-agent-kind request configuration.
    /// @param agentId Somnia Agent identifier.
    /// @param pricePerValidator Native-token reward budget per validator.
    /// @param subcommitteeSize Expected validator count used for deposit calculation.
    /// @param selector JSON selector or method metadata for off-chain indexing.
    /// @param canaryEnabled True when public canary requests may be created.
    /// @param settlementEnabled True when escrow submissions may use this kind for settlement.
    struct AgentConfig {
        uint256 agentId;
        uint256 pricePerValidator;
        uint256 subcommitteeSize;
        string selector;
        bool canaryEnabled;
        bool settlementEnabled;
    }

    /// @notice Stored metadata for a Somnia platform request.
    /// @param taskId Vigilia task being verified, or zero for canary requests.
    /// @param submissionId Vigilia submission being verified, or zero for canary requests.
    /// @param kind Somnia base-agent kind used for the request.
    /// @param requester Account that created the request and paid the deposit.
    /// @param inputHash Hash of evidence URI, prompt, or URL/instruction metadata.
    /// @param isCanary True when this request must not touch escrow settlement.
    /// @param exists True once the platform request is tracked.
    /// @param fulfilled True after a terminal platform callback is accepted.
    struct RequestContext {
        uint256 taskId;
        uint256 submissionId;
        VigiliaAgentTypes.AgentKind kind;
        address requester;
        bytes32 inputHash;
        bool isCanary;
        bool exists;
        bool fulfilled;
    }

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
    }

    /// @notice Emitted when this verifier is permanently bound to an escrow contract.
    /// @param escrow Escrow contract allowed to request settlement verification and receive forwarded verdicts.
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
    /// @param deposit Native-token amount forwarded to the platform.
    /// @param evidenceURI Public evidence URI.
    event MultiAgentVerificationRequested(
        bytes32 indexed vigiliaRequestId,
        uint256 indexed platformRequestId,
        uint256 indexed taskId,
        uint256 submissionId,
        VigiliaAgentTypes.AgentKind kind,
        uint256 agentId,
        uint256 deposit,
        string evidenceURI
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

    /// @notice Somnia Agent requester platform contract.
    ISomniaAgentRequester public immutable platform;

    /// @notice Account allowed to bind this adapter to the escrow once after deployment.
    address public immutable escrowBinder;

    /// @notice Escrow contract allowed to create settlement requests and receive forwarded verdicts.
    address public escrow;

    /// @notice Agent configuration by kind.
    mapping(VigiliaAgentTypes.AgentKind kind => AgentConfig config) public agentConfigs;

    /// @notice Request metadata by Somnia platform request identifier.
    mapping(uint256 platformRequestId => RequestContext context) public requests;

    /// @notice Current platform request for each task/submission pair.
    mapping(uint256 taskId => mapping(uint256 submissionId => uint256 platformRequestId)) public activePlatformRequest;

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
            "inferString(string,string,bool,string[])"
        );
        _configureOptionalCanary(
            VigiliaAgentTypes.AgentKind.LlmParseWebsite,
            _config.llmParseWebsiteAgentId,
            _config.llmParseWebsitePricePerValidator,
            _config.subcommitteeSize,
            "ExtractString(string,string,string[],string,bool,uint8,uint8)"
        );
    }

    /// @notice Accepts Somnia platform rebates after request finalization.
    receive() external payable {
        emit SomniaRebateReceived(msg.sender, msg.value);
    }

    /// @notice Binds this verifier to exactly one escrow contract.
    /// @dev This does not create a global admin role; escrow still owns settlement state and funds.
    /// @param _escrow Escrow contract address.
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
        AgentConfig storage config = _configured(_kind);
        deposit = platform.getRequestDeposit() + (config.pricePerValidator * config.subcommitteeSize);
    }

    /// @inheritdoc IVigiliaVerifier
    function requestVerification(uint256 _taskId, uint256 _submissionId, address _payer, string calldata _evidenceURI)
        external
        payable
        returns (bytes32 vigiliaRequestId)
    {
        if (msg.sender != escrow) revert Unauthorized(msg.sender);
        if (_payer == address(0)) revert InvalidAddress();

        VigiliaAgentTypes.AgentKind kind = VigiliaAgentTypes.AgentKind.JsonApi;
        AgentConfig storage config = _configured(kind);
        if (!config.settlementEnabled) revert SettlementDisabled(kind);

        bytes memory payload = _jsonApiPayload(_evidenceURI, config.selector);
        uint256 platformRequestId =
            _createTrackedRequest(kind, _taskId, _submissionId, _payer, keccak256(bytes(_evidenceURI)), false, payload);
        activePlatformRequest[_taskId][_submissionId] = platformRequestId;

        vigiliaRequestId = bytes32(platformRequestId);

        emit MultiAgentVerificationRequested(
            vigiliaRequestId, platformRequestId, _taskId, _submissionId, kind, config.agentId, msg.value, _evidenceURI
        );
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

        bytes memory payload = _jsonApiPayload(_url, _selector);
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

        string[] memory allowedValues = _allowedVerdictValues();
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

        string[] memory allowedValues = _allowedVerdictValues();
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
        if (msg.sender != address(platform)) {
            revert Unauthorized(msg.sender);
        }

        RequestContext storage context = requests[_requestId];
        if (!context.exists) revert UnknownRequest(_requestId);

        if (!context.isCanary) {
            uint256 activeRequestId = activePlatformRequest[context.taskId][context.submissionId];
            if (activeRequestId != _requestId) {
                if (!context.fulfilled) {
                    context.fulfilled = true;
                }
                emit StaleSomniaCallbackIgnored(_requestId, activeRequestId, context.taskId, context.submissionId);
                return;
            }
        }

        if (context.fulfilled) revert RequestAlreadyFulfilled(_requestId);
        context.fulfilled = true;

        if (
            _status == ISomniaAgentRequester.ResponseStatus.Failed
                || _status == ISomniaAgentRequester.ResponseStatus.TimedOut
        ) {
            _handleTerminalFailure(_requestId, context, _status, _somniaNotesUri(_requestId));
            return;
        }

        if (_status != ISomniaAgentRequester.ResponseStatus.Success) revert UnsupportedResponseStatus(_status);

        (bool decoded, string memory result) = _decodeSuccessfulResult(_responses);
        if (!decoded) {
            _handleTerminalFailure(_requestId, context, _status, _failureNotesUri(_requestId, "malformed"));
            return;
        }

        (bool parsed, VigiliaTypes.VerificationVerdict verdict) = _parseVerdict(result);
        if (!parsed) {
            _handleTerminalFailure(_requestId, context, _status, _failureNotesUri(_requestId, "unknown-verdict"));
            return;
        }

        if (context.isCanary) {
            emit CanarySucceeded(_requestId, context.kind, verdict, result);
        } else {
            _forwardVerdict(_requestId, context, verdict, result);
        }

        _details;
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

        agentConfigs[_kind] = AgentConfig({
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
        string memory _selector
    ) private {
        if (_agentId == 0 || _pricePerValidator == 0) {
            return;
        }

        _configure(_kind, _agentId, _pricePerValidator, _subcommitteeSize, _selector, true, false);
    }

    /// @dev Loads a configured agent kind and rejects unset/unknown kinds.
    function _configured(VigiliaAgentTypes.AgentKind _kind) private view returns (AgentConfig storage config) {
        if (_kind == VigiliaAgentTypes.AgentKind.Unknown) revert UnknownAgentKind(_kind);

        config = agentConfigs[_kind];
        if (config.agentId == 0) revert UnknownAgentKind(_kind);
    }

    /// @dev Reverts when canary requests are not enabled for a kind.
    function _requireCanaryEnabled(VigiliaAgentTypes.AgentKind _kind) private view {
        AgentConfig storage config = _configured(_kind);
        if (!config.canaryEnabled) revert CanaryDisabled(_kind);
    }

    /// @dev Builds the proven JSON API Request payload.
    function _jsonApiPayload(string calldata _url, string memory _selector)
        private
        pure
        returns (bytes memory payload)
    {
        payload = abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _url, _selector);
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
        AgentConfig storage config = _configured(_kind);
        uint256 requiredDeposit = minimumRequestDeposit(_kind);
        if (msg.value != requiredDeposit) revert InvalidVerificationDeposit(requiredDeposit, msg.value);

        platformRequestId = platform.createRequest{ value: msg.value }(
            config.agentId, address(this), this.handleResponse.selector, _payload
        );
        if (platformRequestId == 0) revert UnknownRequest(0);

        requests[platformRequestId] = RequestContext({
            taskId: _taskId,
            submissionId: _submissionId,
            kind: _kind,
            requester: _requester,
            inputHash: _inputHash,
            isCanary: _isCanary,
            exists: true,
            fulfilled: false
        });
    }

    /// @dev Extracts and decodes the first successful validator result from a successful platform callback.
    function _decodeSuccessfulResult(ISomniaAgentRequester.Response[] memory _responses)
        private
        view
        returns (bool decoded, string memory result)
    {
        for (uint256 i = 0; i < _responses.length; ++i) {
            if (
                _responses[i].status == ISomniaAgentRequester.ResponseStatus.Success && _responses[i].result.length != 0
            ) {
                try this.decodeAgentString(_responses[i].result) returns (string memory decodedResult) {
                    return (true, decodedResult);
                } catch {
                    return (false, "");
                }
            }
        }

        return (false, "");
    }

    /// @dev Maps exact bounded agent output strings into the shared Vigilia verdict enum.
    function _parseVerdict(string memory _result)
        private
        pure
        returns (bool parsed, VigiliaTypes.VerificationVerdict verdict)
    {
        bytes32 resultHash = keccak256(bytes(_result));

        if (resultHash == keccak256("Complete") || resultHash == keccak256("COMPLETE")) {
            return (true, VigiliaTypes.VerificationVerdict.Complete);
        }
        if (resultHash == keccak256("NeedsReview") || resultHash == keccak256("NEEDS_REVIEW")) {
            return (true, VigiliaTypes.VerificationVerdict.NeedsReview);
        }
        if (resultHash == keccak256("Incomplete") || resultHash == keccak256("INCOMPLETE")) {
            return (true, VigiliaTypes.VerificationVerdict.Incomplete);
        }

        return (false, VigiliaTypes.VerificationVerdict.Unknown);
    }

    /// @dev Handles terminal failures for canary and settlement requests.
    function _handleTerminalFailure(
        uint256 _requestId,
        RequestContext storage _context,
        ISomniaAgentRequester.ResponseStatus _status,
        string memory _failureNotesURI
    ) private {
        if (_context.isCanary) {
            emit CanaryFailed(_requestId, _context.kind, _status, _failureNotesURI);
        } else {
            _forwardVerificationFailure(_requestId, _context, _status, _failureNotesURI);
        }
    }

    /// @dev Forwards terminal infrastructure failure to escrow and preserves callback finality if escrow rejects it.
    function _forwardVerificationFailure(
        uint256 _requestId,
        RequestContext storage _context,
        ISomniaAgentRequester.ResponseStatus _status,
        string memory _failureNotesURI
    ) private {
        try IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerificationFailure(_context.taskId, _context.submissionId, bytes32(_requestId), _failureNotesURI) {
            emit MultiAgentVerificationFailed(
                _requestId, _context.taskId, _context.submissionId, _context.kind, _status, _failureNotesURI
            );
        } catch (bytes memory returnData) {
            emit EscrowForwardingFailed(_requestId, _context.taskId, _context.submissionId, returnData);
        }
    }

    /// @dev Forwards a bounded verdict to escrow and preserves callback finality if escrow rejects it.
    function _forwardVerdict(
        uint256 _requestId,
        RequestContext storage _context,
        VigiliaTypes.VerificationVerdict _verdict,
        string memory _result
    ) private {
        try IVigiliaEscrowVerdictReceiver(escrow)
            .recordVerdict(
                _context.taskId, _context.submissionId, bytes32(_requestId), _verdict, _somniaNotesUri(_requestId)
            ) {
            emit MultiAgentVerificationSucceeded(
                _requestId, _context.taskId, _context.submissionId, _context.kind, _verdict, _result
            );
        } catch (bytes memory returnData) {
            emit EscrowForwardingFailed(_requestId, _context.taskId, _context.submissionId, returnData);
        }
    }

    /// @dev Returns bounded values passed to the candidate LLM Inference canary method.
    function _allowedVerdictValues() private pure returns (string[] memory allowedValues) {
        allowedValues = new string[](3);
        allowedValues[0] = "Complete";
        allowedValues[1] = "NeedsReview";
        allowedValues[2] = "Incomplete";
    }

    /// @dev Provides a deterministic on-chain note that off-chain indexers can pair with Somnia receipt APIs.
    function _somniaNotesUri(uint256 _requestId) private pure returns (string memory notesURI) {
        notesURI = string.concat("somnia-agent-request:", _uintToString(_requestId));
    }

    /// @dev Adds a compact failure reason to the deterministic Somnia request note.
    function _failureNotesUri(uint256 _requestId, string memory _reason) private pure returns (string memory notesURI) {
        notesURI = string.concat(_somniaNotesUri(_requestId), ":", _reason);
    }

    /// @dev Converts a request identifier into decimal text without importing external string helpers.
    function _uintToString(uint256 _value) private pure returns (string memory result) {
        if (_value == 0) return "0";

        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            // casting to uint8 is safe because the modulo result is always a single decimal digit.
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }

        result = string(buffer);
    }
}
