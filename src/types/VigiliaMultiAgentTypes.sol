// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { VigiliaAgentTypes } from "./VigiliaAgentTypes.sol";

/// @title VigiliaMultiAgentTypes
/// @notice Shared multi-agent verifier storage types.
library VigiliaMultiAgentTypes {
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
    /// @param workflow Settlement workflow that owns this request.
    /// @param stage Async verification stage for settlement requests.
    /// @param evidenceURI Public evidence URI under verification.
    /// @param requirementsURI Public task requirements URI or requirements text.
    /// @param facts Structured facts returned by the JSON API facts stage.
    /// @param websiteURI Public project or demo HTML URI returned by the JSON websiteURI stage.
    /// @param websiteExtract Website Parse result returned before final LLM classification.
    /// @param prepaidBudget Native-token budget retained for the next stage.
    /// @param parentRequestId Escrow-facing root platform request for child stage requests.
    /// @param isCanary True when this request must not touch escrow settlement.
    /// @param isSettlement True when this request may affect escrow state.
    /// @param exists True once the platform request is tracked.
    /// @param fulfilled True after a terminal platform callback is accepted.
    struct RequestContext {
        uint256 taskId;
        uint256 submissionId;
        VigiliaAgentTypes.AgentKind kind;
        address requester;
        bytes32 inputHash;
        VigiliaAgentTypes.SettlementWorkflow workflow;
        VigiliaAgentTypes.VerificationStage stage;
        string evidenceURI;
        string requirementsURI;
        string facts;
        string websiteURI;
        string websiteExtract;
        uint256 prepaidBudget;
        uint256 parentRequestId;
        bool isCanary;
        bool isSettlement;
        bool exists;
        bool fulfilled;
    }
}
