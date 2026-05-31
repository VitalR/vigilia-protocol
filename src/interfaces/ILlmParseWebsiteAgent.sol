// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title ILlmParseWebsiteAgent
/// @notice Somnia LLM Parse Website base-agent ABI used only for v0.2.0 canaries.
/// @dev Confirmed from Somnia's LLM Parse Website base-agent docs. Keep settlement disabled for this agent kind until a
/// live platform callback proves the method on testnet.
interface ILlmParseWebsiteAgent {
    /// @notice Extracts a single string field, optionally constrained by literal options.
    /// @param _key Field name to extract.
    /// @param _description Field description for the LLM extraction.
    /// @param _options Literal output options; empty array means unconstrained.
    /// @param _prompt Natural-language extraction prompt, also used as search term when resolving URLs.
    /// @param _url Base URL or direct URL.
    /// @param _resolveUrl True to search within a domain; false to scrape the direct URL.
    /// @param _numPages Maximum pages to fetch. Direct URL mode is capped at one page.
    /// @param _confidenceThreshold Minimum confidence score from 0 to 100.
    /// @return result Extracted string result.
    function ExtractString(
        string calldata _key,
        string calldata _description,
        string[] calldata _options,
        string calldata _prompt,
        string calldata _url,
        bool _resolveUrl,
        uint8 _numPages,
        uint8 _confidenceThreshold
    ) external returns (string memory result);

    /// @notice Extracts a single unsigned integer field, optionally bounded by min and max.
    /// @param _key Field name to extract.
    /// @param _description Field description for the LLM extraction.
    /// @param _min Minimum bound, or zero when bounds are disabled.
    /// @param _max Maximum bound, or zero when bounds are disabled.
    /// @param _prompt Natural-language extraction prompt, also used as search term when resolving URLs.
    /// @param _url Base URL or direct URL.
    /// @param _resolveUrl True to search within a domain; false to scrape the direct URL.
    /// @param _numPages Maximum pages to fetch. Direct URL mode is capped at one page.
    /// @param _confidenceThreshold Minimum confidence score from 0 to 100.
    /// @return result Extracted unsigned integer result.
    function ExtractANumber(
        string calldata _key,
        string calldata _description,
        uint256 _min,
        uint256 _max,
        string calldata _prompt,
        string calldata _url,
        bool _resolveUrl,
        uint8 _numPages,
        uint8 _confidenceThreshold
    ) external returns (uint256 result);
}
