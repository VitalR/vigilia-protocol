// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title ILlmParseWebsiteAgent
/// @notice Provisional Somnia LLM Parse Website canary ABI.
/// @dev The exact production ABI must be confirmed from Agent Explorer/generated snippets and live callback receipts
/// before this kind is settlement-enabled. This interface is intentionally used for canaries only.
interface ILlmParseWebsiteAgent {
    /// @notice Requests bounded extraction from a specific public URL.
    /// @param _url Public website URL to inspect.
    /// @param _instruction Extraction instruction. For Vigilia canaries this should request one bounded verdict string.
    /// @return result Extracted string result.
    function parseWebsite(string calldata _url, string calldata _instruction) external returns (string memory result);
}
