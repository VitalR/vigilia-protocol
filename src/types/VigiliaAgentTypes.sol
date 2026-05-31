// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title VigiliaAgentTypes
/// @notice Shared Somnia Agent coordinator types for v0.2.0 canary and verifier flows.
library VigiliaAgentTypes {
    /// @notice Somnia base-agent families supported by the v0.2.0 coordinator foundation.
    /// @dev `Unknown` is reserved for unset values and must fail closed.
    enum AgentKind {
        Unknown,
        JsonApi,
        LlmInference,
        LlmParseWebsite
    }

    /// @notice Settlement workflows supported by the multi-agent verifier.
    /// @dev `JsonFactsToLlmVerdict` is the first production multi-agent settlement flow.
    enum SettlementWorkflow {
        Unknown,
        JsonApiVerdict,
        LlmDirectVerdict,
        JsonFactsToLlmVerdict
    }

    /// @notice Async stage for a settlement platform request.
    /// @dev Canary requests use `Unknown`; settlement requests use the stage that determines callback handling.
    enum VerificationStage {
        Unknown,
        JsonFacts,
        LlmVerdict
    }
}
