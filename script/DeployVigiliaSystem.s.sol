// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script } from "@forge-std/Script.sol";
import { VigiliaEscrow } from "../src/VigiliaEscrow.sol";
import { VigiliaJsonApiVerifier } from "../src/VigiliaJsonApiVerifier.sol";

/// @title DeployVigiliaSystem
/// @notice Deploys the current JSON API smoke version of the Vigilia MVP system on Somnia testnet.
/// @dev Deploys `VigiliaJsonApiVerifier`, deploys `VigiliaEscrow`, then binds the verifier to the escrow. The
/// script can also write a public deployment artifact when `WRITE_DEPLOYMENT_ARTIFACT` is unset or set to `true`.
/// This deployment proves live Somnia platform callbacks through JSON API Request. Multi-agent verification is a later
/// deployment line.
contract DeployVigiliaSystem is Script {
    /// @notice Reverts when the active deployment agent is not the JSON API Request agent.
    /// @param activeAgentId Configured `SOMNIA_AGENT_ID`.
    /// @param jsonApiAgentId Configured `SOMNIA_JSON_API_AGENT_ID`.
    error ActiveAgentMustBeJsonApi(uint256 activeAgentId, uint256 jsonApiAgentId);

    /// @notice Reverts when `SOMNIA_AGENT_TYPE` does not identify this smoke deployment as JSON API Request.
    /// @param activeAgentType Configured active agent type.
    error ActiveAgentTypeMustBeJsonApi(string activeAgentType);

    string private constant _DEPLOYMENT_ARTIFACT = "deployments/somnia-testnet-50312.json";
    string private constant _DEPLOYMENT_NAME = "vigilia-json-api-smoke";
    string private constant _NETWORK = "somnia-testnet";
    string private constant _VERSION = "v0.1.0";
    string private constant _ACTIVE_AGENT_TYPE = "json-api-request";

    struct DeploymentConfig {
        uint256 deployerPrivateKey;
        address deployer;
        uint256 chainId;
        address platform;
        uint256 agentId;
        uint256 jsonApiAgentId;
        uint256 llmInferenceAgentId;
        uint256 llmWebAgentId;
        uint256 subcommitteeSize;
        uint256 pricePerValidator;
        string deploymentName;
        string versionName;
        string activeAgentType;
        string verdictSelector;
        string explorerBaseUrl;
    }

    /// @notice Deploys the verifier, deploys escrow, binds the verifier, and writes public deployment metadata.
    /// @dev Environment expected: DEPLOYER_PRIVATE_KEY, SOMNIA_AGENT_PLATFORM, SOMNIA_AGENT_ID,
    /// AGENT_SUBCOMMITTEE_SIZE, AGENT_PRICE_PER_VALIDATOR.
    function run() external returns (VigiliaEscrow escrow, VigiliaJsonApiVerifier verifier) {
        DeploymentConfig memory config = _loadConfig();

        vm.startBroadcast(config.deployerPrivateKey);

        verifier = new VigiliaJsonApiVerifier(
            config.platform,
            config.deployer,
            config.agentId,
            config.subcommitteeSize,
            config.pricePerValidator,
            config.verdictSelector
        );
        escrow = new VigiliaEscrow(address(verifier));
        verifier.bindEscrow(address(escrow));

        vm.stopBroadcast();

        if (_shouldWriteArtifact()) {
            _writeDeploymentArtifact(config, address(escrow), address(verifier));
        }
    }

    /// @dev Loads all public deployment configuration and derives the deployer address without exposing the key.
    function _loadConfig() private view returns (DeploymentConfig memory config) {
        config.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        config.deployer = vm.addr(config.deployerPrivateKey);
        config.chainId = vm.envOr("SOMNIA_CHAIN_ID", block.chainid);
        config.platform = vm.envAddress("SOMNIA_AGENT_PLATFORM");
        config.agentId = vm.envUint("SOMNIA_AGENT_ID");
        config.jsonApiAgentId = vm.envOr("SOMNIA_JSON_API_AGENT_ID", config.agentId);
        config.llmInferenceAgentId = vm.envOr("SOMNIA_LLM_INFERENCE_AGENT_ID", uint256(0));
        config.llmWebAgentId = vm.envOr("SOMNIA_LLM_WEB_AGENT_ID", uint256(0));
        config.subcommitteeSize = vm.envUint("AGENT_SUBCOMMITTEE_SIZE");
        config.pricePerValidator = vm.envUint("AGENT_PRICE_PER_VALIDATOR");
        config.deploymentName = vm.envOr("VIGILIA_DEPLOYMENT_NAME", _DEPLOYMENT_NAME);
        config.versionName = vm.envOr("VIGILIA_VERSION", _VERSION);
        config.activeAgentType = vm.envOr("SOMNIA_AGENT_TYPE", _ACTIVE_AGENT_TYPE);
        config.verdictSelector = vm.envOr("SOMNIA_VERDICT_SELECTOR", string("verdict"));
        config.explorerBaseUrl = vm.envOr("SOMNIA_BLOCK_EXPLORER", string(""));

        if (config.agentId != config.jsonApiAgentId) {
            revert ActiveAgentMustBeJsonApi(config.agentId, config.jsonApiAgentId);
        }
        if (keccak256(bytes(config.activeAgentType)) != keccak256(bytes(_ACTIVE_AGENT_TYPE))) {
            revert ActiveAgentTypeMustBeJsonApi(config.activeAgentType);
        }
    }

    /// @dev Allows dry-run commands to suppress artifact writes with `WRITE_DEPLOYMENT_ARTIFACT=false`.
    function _shouldWriteArtifact() private view returns (bool shouldWrite) {
        string memory flag = vm.envOr("WRITE_DEPLOYMENT_ARTIFACT", string("true"));
        shouldWrite = keccak256(bytes(flag)) != keccak256("false");
    }

    /// @dev Writes a public, non-secret deployment snapshot for demos, verification, and reviewers.
    function _writeDeploymentArtifact(DeploymentConfig memory _config, address _escrow, address _verifier) private {
        string memory object = "deployment";

        vm.serializeString(object, "deploymentName", _config.deploymentName);
        vm.serializeString(object, "version", _config.versionName);
        vm.serializeString(object, "network", _NETWORK);
        vm.serializeUint(object, "chainId", _config.chainId);
        vm.serializeAddress(object, "deployer", _config.deployer);
        vm.serializeAddress(object, "vigiliaEscrow", _escrow);
        vm.serializeAddress(object, "vigiliaJsonApiVerifier", _verifier);
        vm.serializeAddress(object, "somniaAgentPlatform", _config.platform);
        vm.serializeUint(object, "activeAgentId", _config.agentId);
        vm.serializeString(object, "activeAgentType", _config.activeAgentType);
        vm.serializeUint(object, "jsonApiAgentId", _config.jsonApiAgentId);
        if (_config.llmInferenceAgentId != 0) {
            vm.serializeUint(object, "llmInferenceAgentId", _config.llmInferenceAgentId);
        }
        if (_config.llmWebAgentId != 0) {
            vm.serializeUint(object, "llmWebAgentId", _config.llmWebAgentId);
        }
        vm.serializeString(object, "verdictSelector", _config.verdictSelector);
        vm.serializeUint(object, "subcommitteeSize", _config.subcommitteeSize);
        vm.serializeUint(object, "pricePerValidatorWei", _config.pricePerValidator);
        vm.serializeUint(object, "blockNumber", block.number);
        vm.serializeUint(object, "timestamp", block.timestamp);
        if (bytes(_config.explorerBaseUrl).length != 0) {
            vm.serializeString(object, "explorerBaseUrl", _config.explorerBaseUrl);
        }

        string memory json = vm.serializeString(object, "artifactType", "vigilia-deployment");
        vm.writeJson(json, _DEPLOYMENT_ARTIFACT);
    }
}
