// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title ILlmInferenceAgent
/// @notice Candidate Somnia LLM Inference base-agent ABI used only for v0.2.0 canaries.
/// @dev Somnia's public guide names `inferString` as the constrained single-turn classification method. Keep settlement
/// disabled for this agent kind until a live Agent Explorer/generated-snippet canary proves the exact ABI and callback.
interface ILlmInferenceAgent {
    /// @notice Requests a deterministic string classification constrained by allowed values.
    /// @param _prompt Prompt supplied to the LLM Inference base agent.
    /// @param _allowedValues Bounded output strings accepted from the model.
    /// @return result Bounded string result.
    function inferString(string calldata _prompt, string[] calldata _allowedValues)
        external
        returns (string memory result);
}
