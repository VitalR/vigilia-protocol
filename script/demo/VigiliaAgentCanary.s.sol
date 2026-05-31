// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script, console2 } from "@forge-std/Script.sol";
import { VigiliaAgentTypes } from "../../src/types/VigiliaAgentTypes.sol";

interface IVigiliaMultiAgentCanary {
    function requestJsonApiCanary(string calldata _url, string calldata _selector)
        external
        payable
        returns (uint256 platformRequestId);

    function requestLlmInferenceCanary(string calldata _prompt, string calldata _system, bool _chainOfThought)
        external
        payable
        returns (uint256 platformRequestId);

    function requestLlmParseWebsiteCanary(string calldata _url, string calldata _instruction)
        external
        payable
        returns (uint256 platformRequestId);

    function requests(uint256 _platformRequestId)
        external
        view
        returns (
            uint256 taskId,
            uint256 submissionId,
            VigiliaAgentTypes.AgentKind kind,
            address requester,
            bytes32 inputHash,
            bool isCanary,
            bool exists,
            bool fulfilled
        );

    function agentConfigs(VigiliaAgentTypes.AgentKind _kind)
        external
        view
        returns (
            uint256 agentId,
            uint256 pricePerValidator,
            uint256 subcommitteeSize,
            string memory selector,
            bool canaryEnabled,
            bool settlementEnabled
        );
}

/// @title VigiliaAgentCanary
/// @notice Configurable runner for v0.2.0 Somnia Agent canary requests.
/// @dev Canaries are async. Run a request action, wait for the platform callback, then inspect receipts/logs by RPC.
contract VigiliaAgentCanary is Script {
    error MissingEnv(string name);
    error UnsupportedCanaryAction(string action);

    string private constant _ACTION_JSON = "json-canary";
    string private constant _ACTION_LLM_INFERENCE = "llm-inference-canary";
    string private constant _ACTION_LLM_PARSE = "llm-parse-canary";
    string private constant _ACTION_INSPECT = "inspect-canary";
    string private constant _ACTION_DEPOSIT = "deposit";

    struct CanaryConfig {
        uint256 deployerPrivateKey;
        address verifier;
        string action;
    }

    /// @notice Executes the selected canary action from `CANARY_ACTION`.
    function run() external {
        CanaryConfig memory config = _loadConfig();
        IVigiliaMultiAgentCanary verifier = IVigiliaMultiAgentCanary(config.verifier);

        bytes32 actionHash = keccak256(bytes(config.action));
        if (actionHash == keccak256(bytes(_ACTION_JSON))) {
            _requestJsonCanary(config, verifier);
        } else if (actionHash == keccak256(bytes(_ACTION_LLM_INFERENCE))) {
            _requestLlmInferenceCanary(config, verifier);
        } else if (actionHash == keccak256(bytes(_ACTION_LLM_PARSE))) {
            _requestLlmParseCanary(config, verifier);
        } else if (actionHash == keccak256(bytes(_ACTION_INSPECT))) {
            _inspectCanary(verifier);
        } else if (actionHash == keccak256(bytes(_ACTION_DEPOSIT))) {
            _printDeposit(verifier);
        } else {
            revert UnsupportedCanaryAction(config.action);
        }
    }

    /// @dev Loads shared config without logging secret values.
    function _loadConfig() private view returns (CanaryConfig memory config) {
        config.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        config.verifier = vm.envAddress("VIGILIA_MULTI_AGENT_VERIFIER");
        config.action = vm.envString("CANARY_ACTION");
    }

    /// @dev Sends a JSON API Request canary.
    function _requestJsonCanary(CanaryConfig memory _config, IVigiliaMultiAgentCanary _verifier) private {
        string memory url = vm.envString("JSON_CANARY_URL");
        if (bytes(url).length == 0) revert MissingEnv("JSON_CANARY_URL");
        string memory selector = vm.envOr("JSON_CANARY_SELECTOR", string("verdict"));
        uint256 deposit = _computedDeposit(_verifier, VigiliaAgentTypes.AgentKind.JsonApi);

        vm.startBroadcast(_config.deployerPrivateKey);
        uint256 requestId = _verifier.requestJsonApiCanary{ value: deposit }(url, selector);
        vm.stopBroadcast();

        console2.log("jsonCanaryRequestId", requestId);
        console2.log("jsonCanaryUrl", url);
        console2.log("jsonCanarySelector", selector);
        console2.log("depositWei", deposit);
    }

    /// @dev Sends an LLM Inference canary.
    function _requestLlmInferenceCanary(CanaryConfig memory _config, IVigiliaMultiAgentCanary _verifier) private {
        string memory prompt = vm.envString("LLM_CANARY_PROMPT");
        if (bytes(prompt).length == 0) revert MissingEnv("LLM_CANARY_PROMPT");
        string memory system = vm.envOr("LLM_CANARY_SYSTEM", string(""));
        bool chainOfThought = vm.envOr("LLM_CANARY_CHAIN_OF_THOUGHT", false);
        uint256 deposit = _computedDeposit(_verifier, VigiliaAgentTypes.AgentKind.LlmInference);

        vm.startBroadcast(_config.deployerPrivateKey);
        uint256 requestId = _verifier.requestLlmInferenceCanary{ value: deposit }(prompt, system, chainOfThought);
        vm.stopBroadcast();

        console2.log("llmInferenceCanaryRequestId", requestId);
        console2.log("llmInferenceSystem", system);
        console2.log("llmInferenceChainOfThought", chainOfThought);
        console2.log("depositWei", deposit);
    }

    /// @dev Sends an LLM Parse Website canary.
    function _requestLlmParseCanary(CanaryConfig memory _config, IVigiliaMultiAgentCanary _verifier) private {
        string memory url = vm.envString("WEBSITE_CANARY_URL");
        if (bytes(url).length == 0) revert MissingEnv("WEBSITE_CANARY_URL");
        string memory instruction = vm.envString("WEBSITE_CANARY_INSTRUCTION");
        if (bytes(instruction).length == 0) revert MissingEnv("WEBSITE_CANARY_INSTRUCTION");
        uint256 deposit = _computedDeposit(_verifier, VigiliaAgentTypes.AgentKind.LlmParseWebsite);

        vm.startBroadcast(_config.deployerPrivateKey);
        uint256 requestId = _verifier.requestLlmParseWebsiteCanary{ value: deposit }(url, instruction);
        vm.stopBroadcast();

        console2.log("llmParseWebsiteCanaryRequestId", requestId);
        console2.log("websiteCanaryUrl", url);
        console2.log("depositWei", deposit);
    }

    /// @dev Prints request context for a canary request.
    function _inspectCanary(IVigiliaMultiAgentCanary _verifier) private view {
        uint256 requestId = vm.envUint("CANARY_REQUEST_ID");
        if (requestId == 0) revert MissingEnv("CANARY_REQUEST_ID");

        (
            uint256 taskId,
            uint256 submissionId,
            VigiliaAgentTypes.AgentKind kind,
            address requester,
            bytes32 inputHash,
            bool isCanary,
            bool exists,
            bool fulfilled
        ) = _verifier.requests(requestId);

        console2.log("requestId", requestId);
        console2.log("taskId", taskId);
        console2.log("submissionId", submissionId);
        console2.log("kind", _kindName(kind));
        console2.log("requester", requester);
        console2.logBytes32(inputHash);
        console2.log("isCanary", isCanary);
        console2.log("exists", exists);
        console2.log("fulfilled", fulfilled);
    }

    /// @dev Prints the current minimum request deposit for `CANARY_AGENT_KIND`.
    function _printDeposit(IVigiliaMultiAgentCanary _verifier) private view {
        VigiliaAgentTypes.AgentKind kind = _kindFromEnv();
        (
            uint256 agentId,
            uint256 pricePerValidator,
            uint256 subcommitteeSize,
            string memory selector,
            bool canaryEnabled,
            bool settlementEnabled
        ) = _verifier.agentConfigs(kind);

        console2.log("kind", _kindName(kind));
        console2.log("agentId", agentId);
        console2.log("pricePerValidator", pricePerValidator);
        console2.log("subcommitteeSize", subcommitteeSize);
        console2.log("selector", selector);
        console2.log("canaryEnabled", canaryEnabled);
        console2.log("settlementEnabled", settlementEnabled);
        console2.log("platformReserveWei", _platformReserveEstimate());
        console2.log("minimumRequestDepositWei", _computedDeposit(_verifier, kind));
    }

    /// @dev Computes the canary deposit without calling platform getters, which can fail in local script simulation.
    function _computedDeposit(IVigiliaMultiAgentCanary _verifier, VigiliaAgentTypes.AgentKind _kind)
        private
        view
        returns (uint256 deposit)
    {
        (, uint256 pricePerValidator, uint256 subcommitteeSize,,,) = _verifier.agentConfigs(_kind);
        deposit = _platformReserveEstimate() + (pricePerValidator * subcommitteeSize);
    }

    /// @dev Informational estimate matching the current Somnia default floor.
    function _platformReserveEstimate() private view returns (uint256 reserve) {
        reserve = vm.envOr("AGENT_PLATFORM_RESERVE_WEI", uint256(0.03 ether));
    }

    /// @dev Reads `CANARY_AGENT_KIND`; defaults to JSON API for deposit commands.
    function _kindFromEnv() private view returns (VigiliaAgentTypes.AgentKind kind) {
        string memory raw = vm.envOr("CANARY_AGENT_KIND", string("json-api"));
        bytes32 value = keccak256(bytes(raw));
        if (value == keccak256("json-api")) return VigiliaAgentTypes.AgentKind.JsonApi;
        if (value == keccak256("llm-inference")) return VigiliaAgentTypes.AgentKind.LlmInference;
        if (value == keccak256("llm-parse-website")) return VigiliaAgentTypes.AgentKind.LlmParseWebsite;
        revert UnsupportedCanaryAction(raw);
    }

    /// @dev Human-readable agent kind names for logs.
    function _kindName(VigiliaAgentTypes.AgentKind _kind) private pure returns (string memory name) {
        if (_kind == VigiliaAgentTypes.AgentKind.JsonApi) return "JsonApi";
        if (_kind == VigiliaAgentTypes.AgentKind.LlmInference) return "LlmInference";
        if (_kind == VigiliaAgentTypes.AgentKind.LlmParseWebsite) return "LlmParseWebsite";
        return "Unknown";
    }
}
