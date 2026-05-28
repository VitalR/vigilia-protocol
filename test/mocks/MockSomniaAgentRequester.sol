// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { ISomniaAgentRequester } from "../../src/interfaces/ISomniaAgentRequester.sol";

interface IMockSomniaCallback {
    function handleResponse(
        uint256 _requestId,
        ISomniaAgentRequester.Response[] memory _responses,
        ISomniaAgentRequester.ResponseStatus _status,
        ISomniaAgentRequester.Request memory _details
    ) external;
}

/// @title MockSomniaAgentRequester
/// @notice Deterministic Somnia Agent platform mock for verifier unit tests.
contract MockSomniaAgentRequester is ISomniaAgentRequester {
    /// @notice Native-token reserve returned by `getRequestDeposit`.
    uint256 public requestDeposit;

    /// @notice Native-token reserve returned by `getAdvancedRequestDeposit`.
    uint256 public advancedRequestDeposit;

    /// @notice Next platform request identifier returned by `createRequest`.
    uint256 public nextRequestId = 1;

    /// @notice Last agent identifier supplied to `createRequest`.
    uint256 public lastAgentId;

    /// @notice Last callback address supplied to `createRequest`.
    address public lastCallbackAddress;

    /// @notice Last callback selector supplied to `createRequest`.
    bytes4 public lastCallbackSelector;

    /// @notice Last payload supplied to `createRequest`.
    bytes public lastPayload;

    /// @notice Last native-token value supplied to `createRequest`.
    uint256 public lastValue;

    /// @notice When true, `createRequest` returns zero to exercise fail-closed verifier handling.
    bool public forceZeroRequestId;

    /// @notice Configures mock platform deposits.
    /// @param _requestDeposit Base platform reserve.
    /// @param _advancedRequestDeposit Advanced platform reserve.
    constructor(uint256 _requestDeposit, uint256 _advancedRequestDeposit) {
        requestDeposit = _requestDeposit;
        advancedRequestDeposit = _advancedRequestDeposit;
    }

    /// @inheritdoc ISomniaAgentRequester
    function createRequest(
        uint256 _agentId,
        address _callbackAddress,
        bytes4 _callbackSelector,
        bytes calldata _payload
    ) external payable returns (uint256 requestId) {
        lastAgentId = _agentId;
        lastCallbackAddress = _callbackAddress;
        lastCallbackSelector = _callbackSelector;
        lastPayload = _payload;
        lastValue = msg.value;

        if (forceZeroRequestId) return 0;

        requestId = nextRequestId++;
    }

    /// @notice Configures whether `createRequest` should return the invalid zero request identifier.
    /// @param _forceZeroRequestId True to force zero request identifiers.
    function setForceZeroRequestId(bool _forceZeroRequestId) external {
        forceZeroRequestId = _forceZeroRequestId;
    }

    /// @inheritdoc ISomniaAgentRequester
    function getRequestDeposit() external view returns (uint256 deposit) {
        deposit = requestDeposit;
    }

    /// @inheritdoc ISomniaAgentRequester
    function getAdvancedRequestDeposit(uint256) external view returns (uint256 deposit) {
        deposit = advancedRequestDeposit;
    }

    /// @notice Calls a verifier callback as the mock platform.
    /// @param _callback Callback contract.
    /// @param _requestId Platform request identifier.
    /// @param _responses Mock validator responses.
    /// @param _status Final platform status.
    /// @param _details Mock request details.
    function callback(
        address _callback,
        uint256 _requestId,
        Response[] memory _responses,
        ResponseStatus _status,
        Request memory _details
    ) external {
        if (_details.remainingBudget != 0) {
            (bool success,) = payable(_callback).call{ value: _details.remainingBudget }("");
            require(success);
        }

        IMockSomniaCallback(_callback).handleResponse(_requestId, _responses, _status, _details);
    }
}
