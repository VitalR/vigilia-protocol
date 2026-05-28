// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title ISomniaAgentRequester
/// @notice Minimal Somnia Agent requester platform ABI used by Vigilia verifier adapters.
interface ISomniaAgentRequester {
    /// @notice Consensus policy used by an agent request.
    enum ConsensusType {
        Majority,
        Threshold
    }

    /// @notice Lifecycle status reported by the Somnia Agent platform.
    enum ResponseStatus {
        None,
        Pending,
        Success,
        Failed,
        TimedOut
    }

    /// @notice Individual validator response returned by the Somnia Agent platform.
    struct Response {
        address validator;
        bytes result;
        ResponseStatus status;
        uint256 receipt;
        uint256 timestamp;
        uint256 executionCost;
    }

    /// @notice Platform request details returned to callback handlers.
    struct Request {
        uint256 id;
        address requester;
        address callbackAddress;
        bytes4 callbackSelector;
        address[] subcommittee;
        Response[] responses;
        uint256 responseCount;
        uint256 failureCount;
        uint256 threshold;
        uint256 createdAt;
        uint256 deadline;
        ResponseStatus status;
        ConsensusType consensusType;
        uint256 remainingBudget;
        uint256 perAgentBudget;
    }

    /// @notice Creates a base Somnia Agent request.
    /// @param _agentId Agent identifier registered on the Somnia platform.
    /// @param _callbackAddress Contract receiving the final callback.
    /// @param _callbackSelector Callback selector to invoke on finalization.
    /// @param _payload ABI-encoded agent method call payload.
    /// @return requestId Platform request identifier.
    function createRequest(
        uint256 _agentId,
        address _callbackAddress,
        bytes4 _callbackSelector,
        bytes calldata _payload
    ) external payable returns (uint256 requestId);

    /// @notice Returns the platform reserve required to create a base request.
    /// @return deposit Platform request reserve denominated in native STT.
    function getRequestDeposit() external view returns (uint256 deposit);

    /// @notice Returns the platform reserve required to create an advanced request.
    /// @param _subcommitteeSize Number of validators requested.
    /// @return deposit Platform request reserve denominated in native STT.
    function getAdvancedRequestDeposit(uint256 _subcommitteeSize) external view returns (uint256 deposit);
}
