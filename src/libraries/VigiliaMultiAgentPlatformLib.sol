// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IJsonApiAgent } from "../interfaces/IJsonApiAgent.sol";
import { ISomniaAgentRequester } from "../interfaces/ISomniaAgentRequester.sol";
import { VigiliaAgentTypes } from "../types/VigiliaAgentTypes.sol";
import { VigiliaMultiAgentTypes } from "../types/VigiliaMultiAgentTypes.sol";

/// @title VigiliaMultiAgentPlatformLib
/// @notice Platform payload and callback decoding helpers for the multi-agent verifier.
library VigiliaMultiAgentPlatformLib {
    /// @notice Reverts when a required address is zero.
    error InvalidAddress();
    /// @notice Reverts when a required numeric parameter is zero.
    error InvalidAmount();
    /// @notice Reverts when the supplied agent kind is unknown or unsupported.
    /// @param kind Unsupported agent kind.
    error UnknownAgentKind(VigiliaAgentTypes.AgentKind kind);
    /// @notice Reverts when a platform request identifier is unknown.
    /// @param requestId Unknown Somnia platform request identifier.
    error UnknownRequest(uint256 requestId);
    /// @notice Reverts when caller is not authorized for an action.
    /// @param caller Unauthorized caller.
    error Unauthorized(address caller);

    /// @dev Builds the proven JSON API Request payload.
    function jsonApiPayload(string calldata _url, string memory _selector)
        internal
        pure
        returns (bytes memory payload)
    {
        payload = abi.encodeWithSelector(IJsonApiAgent.fetchString.selector, _url, _selector);
    }

    /// @dev Forwards value and payload to the Somnia Agent platform for a configured agent kind.
    function createPlatformRequest(
        ISomniaAgentRequester _platform,
        address _callbackReceiver,
        bytes4 _callbackSelector,
        mapping(VigiliaAgentTypes.AgentKind => VigiliaMultiAgentTypes.AgentConfig) storage _agentConfigs,
        VigiliaAgentTypes.AgentKind _kind,
        uint256 _value,
        bytes memory _payload
    ) internal returns (uint256 platformRequestId) {
        VigiliaMultiAgentTypes.AgentConfig storage config = _configured(_agentConfigs, _kind);
        platformRequestId =
            _platform.createRequest{ value: _value }(config.agentId, _callbackReceiver, _callbackSelector, _payload);
        if (platformRequestId == 0) revert UnknownRequest(0);
    }

    /// @dev Extracts and decodes the first successful validator result from a successful platform callback.
    function decodeSuccessfulResult(address _self, ISomniaAgentRequester.Response[] memory _responses)
        internal
        view
        returns (bool decoded, string memory result)
    {
        for (uint256 i = 0; i < _responses.length; ++i) {
            if (
                _responses[i].status == ISomniaAgentRequester.ResponseStatus.Success && _responses[i].result.length != 0
            ) {
                try IVigiliaAgentStringDecoder(_self).decodeAgentString(_responses[i].result) returns (
                    string memory decodedResult
                ) {
                    return (true, decodedResult);
                } catch {
                    return (false, "");
                }
            }
        }

        return (false, "");
    }

    /// @dev Loads a configured agent kind and rejects unset/unknown kinds.
    function _configured(
        mapping(VigiliaAgentTypes.AgentKind => VigiliaMultiAgentTypes.AgentConfig) storage _agentConfigs,
        VigiliaAgentTypes.AgentKind _kind
    ) private view returns (VigiliaMultiAgentTypes.AgentConfig storage config) {
        if (_kind == VigiliaAgentTypes.AgentKind.Unknown) revert UnknownAgentKind(_kind);

        config = _agentConfigs[_kind];
        if (config.agentId == 0) revert UnknownAgentKind(_kind);
    }
}

/// @notice Minimal decoder surface used by the platform callback helper library.
interface IVigiliaAgentStringDecoder {
    function decodeAgentString(bytes calldata _result) external view returns (string memory decoded);
}
