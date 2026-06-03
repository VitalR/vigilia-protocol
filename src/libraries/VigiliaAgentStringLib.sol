// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { VigiliaTypes } from "../types/VigiliaTypes.sol";

/// @title VigiliaAgentStringLib
/// @notice Pure helpers for bounded Somnia agent string parsing and deterministic notes URIs.
library VigiliaAgentStringLib {
    /// @notice Maps exact bounded agent output strings into the shared Vigilia verdict enum.
    /// @param _result Raw agent string to classify.
    /// @return parsed True when the string maps to a supported verdict.
    /// @return verdict Parsed verdict, or `Unknown` when parsing fails.
    function parseVerdict(string memory _result)
        internal
        pure
        returns (bool parsed, VigiliaTypes.VerificationVerdict verdict)
    {
        bytes32 resultHash = keccak256(_trimAsciiWhitespace(bytes(_result)));

        if (resultHash == keccak256("Complete") || resultHash == keccak256("COMPLETE")) {
            return (true, VigiliaTypes.VerificationVerdict.Complete);
        }
        if (resultHash == keccak256("NeedsReview") || resultHash == keccak256("NEEDS_REVIEW")) {
            return (true, VigiliaTypes.VerificationVerdict.NeedsReview);
        }
        if (resultHash == keccak256("Incomplete") || resultHash == keccak256("INCOMPLETE")) {
            return (true, VigiliaTypes.VerificationVerdict.Incomplete);
        }

        return (false, VigiliaTypes.VerificationVerdict.Unknown);
    }

    /// @dev Returns a copied slice with leading/trailing ASCII whitespace removed.
    function _trimAsciiWhitespace(bytes memory _input) private pure returns (bytes memory trimmed) {
        uint256 start;
        uint256 end = _input.length;

        while (start < end && _isAsciiWhitespace(_input[start])) {
            start++;
        }
        while (end > start && _isAsciiWhitespace(_input[end - 1])) {
            end--;
        }

        trimmed = new bytes(end - start);
        for (uint256 i = 0; i < trimmed.length; ++i) {
            trimmed[i] = _input[start + i];
        }
    }

    /// @dev Matches the common ASCII whitespace characters produced around short model outputs.
    function _isAsciiWhitespace(bytes1 _char) private pure returns (bool isWhitespace) {
        return _char == 0x09 || _char == 0x0a || _char == 0x0b || _char == 0x0c || _char == 0x0d || _char == 0x20;
    }

    /// @notice Returns bounded values passed to LLM Inference settlement and canary methods.
    /// @return allowedValues Supported verdict strings.
    function allowedVerdictValues() internal pure returns (string[] memory allowedValues) {
        allowedValues = new string[](3);
        allowedValues[0] = "Complete";
        allowedValues[1] = "NeedsReview";
        allowedValues[2] = "Incomplete";
    }

    /// @notice Builds the settlement LLM prompt from task requirements and extracted JSON facts.
    /// @param _requirementsURI Task requirements text or URI stored on the parent request.
    /// @param _facts Structured facts returned by the JSON API facts stage.
    /// @return prompt Prompt forwarded to `inferString`.
    function llmVerdictPrompt(string memory _requirementsURI, string memory _facts)
        internal
        pure
        returns (string memory prompt)
    {
        prompt = string.concat(
            "Task requirements:\n",
            _requirementsURI,
            "\n\nEvidence facts:\n",
            _facts,
            "\n\nClassify whether the submitted work satisfies the requirements.\nReturn exactly one allowed value."
        );
    }

    /// @notice Builds the final ThreeAgent grant-screening prompt from requirements, JSON facts, and Website Parse.
    /// @param _requirementsURI Grant requirements text or URI stored on the parent request.
    /// @param _facts Structured facts returned by the JSON API facts stage.
    /// @param _websiteExtract Website Parse evidence returned from the project HTML page.
    /// @param _evidenceURI Original evidence bundle URI.
    /// @param _websiteURI Project HTML URI parsed by Website Parse.
    /// @return prompt Prompt forwarded to `inferString`.
    function threeAgentGrantVerdictPrompt(
        string memory _requirementsURI,
        string memory _facts,
        string memory _websiteExtract,
        string memory _evidenceURI,
        string memory _websiteURI
    ) internal pure returns (string memory prompt) {
        prompt = string.concat(
            "Grant requirements URI or text:\n",
            _requirementsURI,
            "\n\nStructured JSON facts:\n",
            _facts,
            "\n\nWebsite Parse evidence:\n",
            _websiteExtract,
            "\n\nEvidence bundle URI:\n",
            _evidenceURI,
            "\n\nWebsite URI:\n",
            _websiteURI,
            "\n\nClassify this grant application based only on the supplied requirements, JSON facts, and website evidence.\n",
            "Complete means all required evidence appears present.\n",
            "NeedsReview means important evidence is unclear, ambiguous, or partially present.\n",
            "Incomplete means required evidence is missing or contradicted.\n",
            "Return exactly one allowed value."
        );
    }

    /// @notice Provides a deterministic on-chain note that off-chain indexers can pair with Somnia receipt APIs.
    /// @param _requestId Somnia platform request identifier.
    /// @return notesURI Deterministic notes URI prefix.
    function somniaNotesUri(uint256 _requestId) internal pure returns (string memory notesURI) {
        notesURI = string.concat("somnia-agent-request:", uintToString(_requestId));
    }

    /// @notice Adds a compact failure reason to the deterministic Somnia request note.
    /// @param _requestId Somnia platform request identifier.
    /// @param _reason Compact failure reason suffix.
    /// @return notesURI Deterministic failure notes URI.
    function failureNotesUri(uint256 _requestId, string memory _reason) internal pure returns (string memory notesURI) {
        notesURI = string.concat(somniaNotesUri(_requestId), ":", _reason);
    }

    /// @notice Converts an identifier into decimal text without importing external string helpers.
    /// @param _value Integer to stringify.
    /// @return result Decimal string representation.
    function uintToString(uint256 _value) internal pure returns (string memory result) {
        if (_value == 0) return "0";

        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            // casting to uint8 is safe because the modulo result is always a single decimal digit.
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }

        result = string(buffer);
    }
}
