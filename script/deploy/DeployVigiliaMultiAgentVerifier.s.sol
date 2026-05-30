// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script } from "@forge-std/Script.sol";
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
        string jsonSelector;
        string explorerBaseUrl;
    }

    /// @notice Deploys the canary-first verifier and optionally writes a public deployment artifact.
    /// @return verifier Deployed v0.2.0 multi-agent verifier.
    function run() external returns (VigiliaMultiAgentVerifier verifier) {
        DeploymentConfig memory config = _loadConfig();

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
        config.jsonApiPricePerValidator = vm.envUint("JSON_API_PRICE_PER_VALIDATOR_WEI");
        config.llmInferencePricePerValidator = vm.envOr("LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI", uint256(0));
        config.llmParseWebsitePricePerValidator = vm.envOr("LLM_PARSE_PRICE_PER_VALIDATOR_WEI", uint256(0));
        config.jsonSelector = vm.envOr("JSON_CANARY_SELECTOR", string("verdict"));
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
        vm.serializeString(object, "activeAgentTypes", "json-api,llm-inference-canary,llm-parse-website-canary");
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
}
