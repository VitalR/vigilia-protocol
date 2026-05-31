// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title ILlmInferenceAgent
/// @notice Somnia LLM Inference base-agent ABI used only for v0.2.0 canaries.
/// @dev Confirmed from Somnia's LLM Inference base-agent docs. Keep settlement disabled for this agent kind until a
/// live platform callback proves the method on testnet.
interface ILlmInferenceAgent {
    /// @notice Requests a deterministic string classification constrained by allowed values.
    /// @param _prompt Prompt supplied to the LLM Inference base agent.
    /// @param _system Optional system prompt. Pass an empty string when unused.
    /// @param _chainOfThought Whether to enable chain-of-thought reasoning.
    /// @param _allowedValues Bounded output strings accepted from the model.
    /// @return result Bounded string result.
    function inferString(
        string calldata _prompt,
        string calldata _system,
        bool _chainOfThought,
        string[] calldata _allowedValues
    ) external returns (string memory result);
}
