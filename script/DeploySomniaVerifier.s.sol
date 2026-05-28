// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script } from "@forge-std/Script.sol";
import { VigiliaEscrow } from "../src/VigiliaEscrow.sol";
import { VigiliaSomniaAgentVerifier } from "../src/VigiliaSomniaAgentVerifier.sol";

/// @title DeploySomniaVerifier
/// @notice Deploys Vigilia escrow with the real Somnia Agent verifier adapter.
contract DeploySomniaVerifier is Script {
    /// @notice Deploys the verifier, deploys escrow, and binds the verifier to escrow.
    /// @dev Environment expected: PRIVATE_KEY, SOMNIA_AGENT_PLATFORM, SOMNIA_AGENT_ID,
    /// AGENT_SUBCOMMITTEE_SIZE, AGENT_PRICE_PER_VALIDATOR.
    function run() external returns (VigiliaEscrow escrow, VigiliaSomniaAgentVerifier verifier) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address platform = vm.envAddress("SOMNIA_AGENT_PLATFORM");
        uint256 agentId = vm.envUint("SOMNIA_AGENT_ID");
        uint256 subcommitteeSize = vm.envUint("AGENT_SUBCOMMITTEE_SIZE");
        uint256 pricePerValidator = vm.envUint("AGENT_PRICE_PER_VALIDATOR");
        string memory verdictSelector = vm.envOr("SOMNIA_VERDICT_SELECTOR", string("verdict"));

        vm.startBroadcast(deployerPrivateKey);

        verifier = new VigiliaSomniaAgentVerifier(
            platform, deployer, agentId, subcommitteeSize, pricePerValidator, verdictSelector
        );
        escrow = new VigiliaEscrow(address(verifier));
        verifier.bindEscrow(address(escrow));

        vm.stopBroadcast();
    }
}
