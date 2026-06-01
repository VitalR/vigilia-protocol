// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script, console2 } from "@forge-std/Script.sol";
import { VigiliaGrantRound } from "../../src/VigiliaGrantRound.sol";
import { VigiliaMultiAgentVerifier } from "../../src/VigiliaMultiAgentVerifier.sol";

/// @title DeployVigiliaGrantRound
/// @notice Deploys a fresh GrantRound receiver and a fresh two-agent verifier bound to that receiver.
/// @dev This script does not mutate or reuse the hardened v0.2.3 escrow/verifier deployment. GrantRound needs its own
/// verifier because `VigiliaMultiAgentVerifier` binds to one settlement receiver.
contract DeployVigiliaGrantRound is Script {
    string private constant _DEPLOYMENT_ARTIFACT = "deployments/somnia-testnet-50312-grant-round.json";
    string private constant _DEPLOYMENT_NAME = "vigilia-grant-round-two-agent-screening";
    string private constant _NETWORK = "somnia-testnet";
    string private constant _VERSION = "v0.3.0";

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
        string blockscoutApiUrl;
    }

    /// @notice Deploys GrantRound, deploys a fresh verifier, binds the verifier to GrantRound, and optionally writes an
    /// artifact.
    /// @return grantRound Fresh GrantRound receiver.
    /// @return verifier Fresh workflow-aware verifier bound to the GrantRound receiver.
    function run() external returns (VigiliaGrantRound grantRound, VigiliaMultiAgentVerifier verifier) {
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
                jsonApiSelector: config.jsonSelector,
                enableLlmInferenceSettlement: true
            })
        );
        grantRound = new VigiliaGrantRound(address(verifier));
        verifier.bindEscrow(address(grantRound));

        vm.stopBroadcast();

        console2.log("vigiliaGrantRound", address(grantRound));
        console2.log("vigiliaMultiAgentVerifier", address(verifier));
        console2.log("boundReceiver", verifier.escrow());
        console2.log("grantRoundVerifier", grantRound.verifier());

        if (_shouldWriteArtifact()) {
            _writeDeploymentArtifact(config, address(grantRound), address(verifier));
        }
    }

    /// @dev Loads deployment config without logging private values.
    function _loadConfig() private view returns (DeploymentConfig memory config) {
        config.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        config.deployer = vm.addr(config.deployerPrivateKey);
        config.chainId = vm.envOr("SOMNIA_CHAIN_ID", block.chainid);
        config.platform = vm.envAddress("SOMNIA_AGENT_PLATFORM");
        config.jsonApiAgentId = vm.envUint("SOMNIA_JSON_API_AGENT_ID");
        config.llmInferenceAgentId = vm.envUint("SOMNIA_LLM_INFERENCE_AGENT_ID");
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
        config.blockscoutApiUrl = vm.envOr("SOMNIA_BLOCKSCOUT_API", string(""));
    }

    /// @dev Allows dry-run commands to suppress artifact writes with `WRITE_DEPLOYMENT_ARTIFACT=false`.
    function _shouldWriteArtifact() private view returns (bool shouldWrite) {
        string memory flag = vm.envOr("WRITE_DEPLOYMENT_ARTIFACT", string("true"));
        shouldWrite = keccak256(bytes(flag)) != keccak256("false");
    }

    /// @dev Writes a public, non-secret deployment snapshot for demos, verification, and reviewers.
    function _writeDeploymentArtifact(DeploymentConfig memory _config, address _grantRound, address _verifier) private {
        string memory object = "deployment";

        vm.serializeString(object, "deploymentName", _DEPLOYMENT_NAME);
        vm.serializeString(object, "version", _VERSION);
        vm.serializeString(object, "network", _NETWORK);
        vm.serializeUint(object, "chainId", _config.chainId);
        vm.serializeAddress(object, "deployer", _config.deployer);
        vm.serializeAddress(object, "vigiliaGrantRound", _grantRound);
        vm.serializeAddress(object, "vigiliaMultiAgentVerifier", _verifier);
        vm.serializeAddress(object, "somniaAgentPlatform", _config.platform);
        vm.serializeString(object, "enabledGrantRoundWorkflow", "JsonFactsToLlmVerdict");
        vm.serializeString(object, "enabledGrantRoundScreeningMode", "TwoAgent");
        vm.serializeString(object, "gatedGrantRoundScreeningMode", "ThreeAgent");
        vm.serializeString(object, "enabledSettlementAgentTypes", "json-api,llm-inference");
        vm.serializeString(object, "disabledSettlementAgentTypes", "llm-parse-website");
        vm.serializeString(object, "canaryAgentTypes", _canaryAgentTypes(_config));
        vm.serializeString(
            object,
            "notes",
            "GrantRound uses a fresh verifier bound to the GrantRound receiver. TwoAgent screening is JSON API facts plus LLM Inference bounded verdict. ThreeAgent is configured at the round data-model level but request-time gated until Website Parse is proven against real HTML."
        );
        vm.serializeUint(object, "jsonApiAgentId", _config.jsonApiAgentId);
        vm.serializeUint(object, "llmInferenceAgentId", _config.llmInferenceAgentId);
        if (_config.llmParseWebsiteAgentId != 0) {
            vm.serializeUint(object, "llmParseWebsiteAgentId", _config.llmParseWebsiteAgentId);
        }
        vm.serializeString(object, "jsonSelector", _config.jsonSelector);
        vm.serializeString(object, "jsonFactsSelector", "facts");
        vm.serializeUint(object, "subcommitteeSize", _config.subcommitteeSize);
        vm.serializeUint(object, "jsonApiPricePerValidatorWei", _config.jsonApiPricePerValidator);
        vm.serializeUint(object, "llmInferencePricePerValidatorWei", _config.llmInferencePricePerValidator);
        vm.serializeUint(object, "llmParseWebsitePricePerValidatorWei", _config.llmParseWebsitePricePerValidator);
        vm.serializeUint(object, "jsonApiMinimumDepositWei", _minimumDeposit(_config, _config.jsonApiPricePerValidator));
        vm.serializeUint(
            object,
            "twoAgentWorkflowMinimumDepositWei",
            _minimumDeposit(_config, _config.jsonApiPricePerValidator)
                + _minimumDeposit(_config, _config.llmInferencePricePerValidator)
        );
        vm.serializeUint(object, "blockNumber", block.number);
        vm.serializeUint(object, "timestamp", block.timestamp);
        if (bytes(_config.explorerBaseUrl).length != 0) {
            vm.serializeString(object, "explorerBaseUrl", _config.explorerBaseUrl);
        }
        if (bytes(_config.blockscoutApiUrl).length != 0) {
            vm.serializeString(object, "blockscoutApiUrl", _config.blockscoutApiUrl);
        }

        string memory json = vm.serializeString(object, "artifactType", "vigilia-grant-round-deployment");
        vm.writeJson(json, _DEPLOYMENT_ARTIFACT);
    }

    /// @dev Logs public deployment config and computed deposits before dry-run or broadcast.
    function _printDeploymentSummary(DeploymentConfig memory _config) private pure {
        console2.log("deploymentName", _DEPLOYMENT_NAME);
        console2.log("version", _VERSION);
        console2.log("artifactPath", _DEPLOYMENT_ARTIFACT);
        console2.log("chainId", _config.chainId);
        console2.log("deployer", _config.deployer);
        console2.log("platform", _config.platform);
        console2.log("platformReserveWei", _config.platformReserveEstimate);
        console2.log("subcommitteeSize", _config.subcommitteeSize);
        console2.log("jsonApiAgentId", _config.jsonApiAgentId);
        console2.log("jsonApiPricePerValidatorWei", _config.jsonApiPricePerValidator);
        console2.log("jsonApiMinimumDepositWei", _minimumDeposit(_config, _config.jsonApiPricePerValidator));
        console2.log("jsonFactsSelector", "facts");
        console2.log("llmInferenceAgentId", _config.llmInferenceAgentId);
        console2.log("llmInferencePricePerValidatorWei", _config.llmInferencePricePerValidator);
        console2.log("llmInferenceMinimumDepositWei", _minimumDeposit(_config, _config.llmInferencePricePerValidator));
        console2.log("llmParseWebsiteAgentId", _config.llmParseWebsiteAgentId);
        console2.log("llmParseWebsitePricePerValidatorWei", _config.llmParseWebsitePricePerValidator);
        console2.log("enabledGrantRoundWorkflow", "JsonFactsToLlmVerdict");
        console2.log("enabledGrantRoundScreeningMode", "TwoAgent");
        console2.log("gatedGrantRoundScreeningMode", "ThreeAgent");
        console2.log("enabledSettlementAgentTypes", "json-api,llm-inference");
        console2.log("disabledSettlementAgentTypes", "llm-parse-website");
        console2.log(
            "twoAgentWorkflowMinimumDepositWei",
            _minimumDeposit(_config, _config.jsonApiPricePerValidator)
                + _minimumDeposit(_config, _config.llmInferencePricePerValidator)
        );
        console2.log("canaryAgentTypes", _canaryAgentTypes(_config));
    }

    /// @dev Returns a comma-delimited public list of configured canary agent types.
    function _canaryAgentTypes(DeploymentConfig memory _config) private pure returns (string memory activeTypes) {
        activeTypes = "json-api,llm-inference";
        if (_config.llmParseWebsiteAgentId != 0 && _config.llmParseWebsitePricePerValidator != 0) {
            activeTypes = string.concat(activeTypes, ",llm-parse-website");
        }
    }

    /// @dev Computes agent request deposit using the configured reserve estimate.
    function _minimumDeposit(DeploymentConfig memory _config, uint256 _pricePerValidator)
        private
        pure
        returns (uint256 deposit)
    {
        deposit = _config.platformReserveEstimate + (_pricePerValidator * _config.subcommitteeSize);
    }
}
