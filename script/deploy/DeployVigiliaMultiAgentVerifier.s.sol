// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script, console2 } from "@forge-std/Script.sol";
import { VigiliaMultiAgentVerifier } from "../../src/VigiliaMultiAgentVerifier.sol";

/// @title DeployVigiliaMultiAgentVerifier
/// @notice Deploys the v0.2.0 canary-first multi-agent verifier on Somnia testnet.
/// @dev This deployment intentionally does not replace the proven v0.1.0 JSON API verifier or escrow deployment.
contract DeployVigiliaMultiAgentVerifier is Script {
    string private constant _DEPLOYMENT_ARTIFACT = "deployments/somnia-testnet-50312-multi-agent-canary.json";
    string private constant _DEPLOYMENT_NAME = "vigilia-multi-agent-canary";
    string private constant _NETWORK = "somnia-testnet";
    string private constant _VERSION = "v0.2.0";

    struct DeploymentConfig {
        uint256 deployerPrivateKey;
        address deployer;
        uint256 chainId;
        address platform;
        uint256 jsonApiAgentId;
        uint256 llmInferenceAgentId;
        uint256 llmParseWebsiteAgentId;
        uint256 subcommitteeSize;
        uint256 jsonApiPricePerValidator;
        uint256 llmInferencePricePerValidator;
        uint256 llmParseWebsitePricePerValidator;
        uint256 platformReserveEstimate;
        string jsonSelector;
        string explorerBaseUrl;
    }

    /// @notice Deploys the canary-first verifier and optionally writes a public deployment artifact.
    /// @return verifier Deployed v0.2.0 multi-agent verifier.
    function run() external returns (VigiliaMultiAgentVerifier verifier) {
        DeploymentConfig memory config = _loadConfig();
        _printDeploymentSummary(config);

        vm.startBroadcast(config.deployerPrivateKey);
        verifier = new VigiliaMultiAgentVerifier(
            VigiliaMultiAgentVerifier.ConstructorConfig({
                platform: config.platform,
                escrowBinder: config.deployer,
                jsonApiAgentId: config.jsonApiAgentId,
                llmInferenceAgentId: config.llmInferenceAgentId,
                llmParseWebsiteAgentId: config.llmParseWebsiteAgentId,
                subcommitteeSize: config.subcommitteeSize,
                jsonApiPricePerValidator: config.jsonApiPricePerValidator,
                llmInferencePricePerValidator: config.llmInferencePricePerValidator,
                llmParseWebsitePricePerValidator: config.llmParseWebsitePricePerValidator,
                jsonApiSelector: config.jsonSelector
            })
        );
        vm.stopBroadcast();

        if (_shouldWriteArtifact()) {
            _writeDeploymentArtifact(config, address(verifier));
        }
    }

    /// @dev Loads deployment config without logging private values.
    function _loadConfig() private view returns (DeploymentConfig memory config) {
        config.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        config.deployer = vm.addr(config.deployerPrivateKey);
        config.chainId = vm.envOr("SOMNIA_CHAIN_ID", block.chainid);
        config.platform = vm.envAddress("SOMNIA_AGENT_PLATFORM");
        config.jsonApiAgentId = vm.envUint("SOMNIA_JSON_API_AGENT_ID");
        config.llmInferenceAgentId = vm.envOr("SOMNIA_LLM_INFERENCE_AGENT_ID", uint256(0));
        config.llmParseWebsiteAgentId = vm.envOr("SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID", uint256(0));
        if (config.llmParseWebsiteAgentId == 0) {
            config.llmParseWebsiteAgentId = vm.envOr("SOMNIA_LLM_WEB_AGENT_ID", uint256(0));
        }
        config.subcommitteeSize = vm.envUint("AGENT_SUBCOMMITTEE_SIZE");
        config.jsonApiPricePerValidator =
            vm.envOr("JSON_API_PRICE_PER_VALIDATOR_WEI", vm.envOr("AGENT_PRICE_PER_VALIDATOR", uint256(0.03 ether)));
        config.llmInferencePricePerValidator = vm.envOr("LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI", uint256(0.07 ether));
        config.llmParseWebsitePricePerValidator = vm.envOr("LLM_PARSE_PRICE_PER_VALIDATOR_WEI", uint256(0.1 ether));
        config.platformReserveEstimate = vm.envOr("AGENT_PLATFORM_RESERVE_WEI", uint256(0.03 ether));
        config.jsonSelector = vm.envOr("JSON_CANARY_SELECTOR", vm.envOr("SOMNIA_VERDICT_SELECTOR", string("verdict")));
        config.explorerBaseUrl = vm.envOr("SOMNIA_BLOCK_EXPLORER", string(""));
    }

    /// @dev Allows dry-run commands to suppress artifact writes with `WRITE_DEPLOYMENT_ARTIFACT=false`.
    function _shouldWriteArtifact() private view returns (bool shouldWrite) {
        string memory flag = vm.envOr("WRITE_DEPLOYMENT_ARTIFACT", string("true"));
        shouldWrite = keccak256(bytes(flag)) != keccak256("false");
    }

    /// @dev Writes a public, non-secret deployment snapshot for demos, verification, and reviewers.
    function _writeDeploymentArtifact(DeploymentConfig memory _config, address _verifier) private {
        string memory object = "deployment";

        vm.serializeString(object, "deploymentName", _DEPLOYMENT_NAME);
        vm.serializeString(object, "version", _VERSION);
        vm.serializeString(object, "network", _NETWORK);
        vm.serializeUint(object, "chainId", _config.chainId);
        vm.serializeAddress(object, "deployer", _config.deployer);
        vm.serializeAddress(object, "vigiliaMultiAgentVerifier", _verifier);
        vm.serializeAddress(object, "somniaAgentPlatform", _config.platform);
        vm.serializeString(object, "activeAgentTypes", _activeAgentTypes(_config));
        vm.serializeUint(object, "jsonApiAgentId", _config.jsonApiAgentId);
        if (_config.llmInferenceAgentId != 0) {
            vm.serializeUint(object, "llmInferenceAgentId", _config.llmInferenceAgentId);
        }
        if (_config.llmParseWebsiteAgentId != 0) {
            vm.serializeUint(object, "llmParseWebsiteAgentId", _config.llmParseWebsiteAgentId);
        }
        vm.serializeString(object, "jsonSelector", _config.jsonSelector);
        vm.serializeUint(object, "subcommitteeSize", _config.subcommitteeSize);
        vm.serializeUint(object, "jsonApiPricePerValidatorWei", _config.jsonApiPricePerValidator);
        vm.serializeUint(object, "llmInferencePricePerValidatorWei", _config.llmInferencePricePerValidator);
        vm.serializeUint(object, "llmParseWebsitePricePerValidatorWei", _config.llmParseWebsitePricePerValidator);
        vm.serializeUint(object, "blockNumber", block.number);
        vm.serializeUint(object, "timestamp", block.timestamp);
        if (bytes(_config.explorerBaseUrl).length != 0) {
            vm.serializeString(object, "explorerBaseUrl", _config.explorerBaseUrl);
        }

        string memory json = vm.serializeString(object, "artifactType", "vigilia-multi-agent-canary-deployment");
        vm.writeJson(json, _DEPLOYMENT_ARTIFACT);
    }

    /// @dev Logs public deployment config and computed deposits before dry-run or broadcast.
    function _printDeploymentSummary(DeploymentConfig memory _config) private pure {
        uint256 platformReserve = _config.platformReserveEstimate;

        console2.log("deploymentName", _DEPLOYMENT_NAME);
        console2.log("version", _VERSION);
        console2.log("chainId", _config.chainId);
        console2.log("deployer", _config.deployer);
        console2.log("platform", _config.platform);
        console2.log("platformReserveWei", platformReserve);
        console2.log("subcommitteeSize", _config.subcommitteeSize);
        console2.log("jsonApiAgentId", _config.jsonApiAgentId);
        console2.log("jsonApiPricePerValidatorWei", _config.jsonApiPricePerValidator);
        console2.log(
            "jsonApiMinimumDepositWei", platformReserve + (_config.jsonApiPricePerValidator * _config.subcommitteeSize)
        );
        console2.log("llmInferenceAgentId", _config.llmInferenceAgentId);
        console2.log("llmInferencePricePerValidatorWei", _config.llmInferencePricePerValidator);
        console2.log(
            "llmInferenceMinimumDepositWei",
            _minimumOptionalDeposit(
                platformReserve,
                _config.llmInferenceAgentId,
                _config.llmInferencePricePerValidator,
                _config.subcommitteeSize
            )
        );
        console2.log("llmParseWebsiteAgentId", _config.llmParseWebsiteAgentId);
        console2.log("llmParseWebsitePricePerValidatorWei", _config.llmParseWebsitePricePerValidator);
        console2.log(
            "llmParseWebsiteMinimumDepositWei",
            _minimumOptionalDeposit(
                platformReserve,
                _config.llmParseWebsiteAgentId,
                _config.llmParseWebsitePricePerValidator,
                _config.subcommitteeSize
            )
        );
        console2.log("enabledCanaries", _activeAgentTypes(_config));
        console2.log("enabledSettlementKinds", "json-api");
    }

    /// @dev Returns a comma-delimited public list of configured canary agent types.
    function _activeAgentTypes(DeploymentConfig memory _config) private pure returns (string memory activeTypes) {
        activeTypes = "json-api";
        if (_config.llmInferenceAgentId != 0 && _config.llmInferencePricePerValidator != 0) {
            activeTypes = string.concat(activeTypes, ",llm-inference-canary");
        }
        if (_config.llmParseWebsiteAgentId != 0 && _config.llmParseWebsitePricePerValidator != 0) {
            activeTypes = string.concat(activeTypes, ",llm-parse-website-canary");
        }
    }

    /// @dev Returns zero when an optional agent kind is not configured.
    function _minimumOptionalDeposit(
        uint256 _platformReserve,
        uint256 _agentId,
        uint256 _pricePerValidator,
        uint256 _subcommitteeSize
    ) private pure returns (uint256 deposit) {
        if (_agentId == 0 || _pricePerValidator == 0) return 0;
        deposit = _platformReserve + (_pricePerValidator * _subcommitteeSize);
    }
}
