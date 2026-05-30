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
}
