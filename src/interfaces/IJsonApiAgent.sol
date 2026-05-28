// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title IJsonApiAgent
/// @notice Somnia JSON API Request base-agent method selectors used for ABI payload encoding.
interface IJsonApiAgent {
    /// @notice Fetches a string value from a JSON endpoint using a selector.
    /// @param _url Public JSON endpoint.
    /// @param _selector JSON selector to extract.
    /// @return result Extracted string value.
    function fetchString(string calldata _url, string calldata _selector) external returns (string memory result);
}
