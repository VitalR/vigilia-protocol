// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title IVigiliaVerifier
/// @notice Minimal verifier interface used by VigiliaEscrow before the real Somnia Agent adapter exists.
interface IVigiliaVerifier {
    /// @notice Requests verification for a submitted public evidence bundle.
    /// @param _taskId Vigilia task being verified.
    /// @param _submissionId Submission tied to the task.
    /// @param _evidenceURI Public URI containing evidence metadata for the verifier to inspect.
    /// @return requestId Verifier request identifier later referenced by the bounded verdict.
    function requestVerification(uint256 _taskId, uint256 _submissionId, string calldata _evidenceURI)
        external
        returns (bytes32 requestId);
}
