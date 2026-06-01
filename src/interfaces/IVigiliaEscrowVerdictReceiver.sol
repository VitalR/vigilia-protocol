// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { VigiliaTypes } from "../types/VigiliaTypes.sol";

/// @title IVigiliaEscrowVerdictReceiver
/// @notice Minimal settlement-receiver callback surface used by verifier adapters.
interface IVigiliaEscrowVerdictReceiver {
    /// @notice Records a bounded verifier verdict for a settlement submission.
    /// @param _taskId Task that was verified.
    /// @param _submissionId Submission receiving the verdict.
    /// @param _requestId Verifier request identifier that must match the active submission.
    /// @param _verdict Bounded verifier result.
    /// @param _verifierNotesURI Public URI with verifier notes, missing fields, or receipts.
    function recordVerdict(
        uint256 _taskId,
        uint256 _submissionId,
        bytes32 _requestId,
        VigiliaTypes.VerificationVerdict _verdict,
        string calldata _verifierNotesURI
    ) external;

    /// @notice Records terminal verifier infrastructure failure for a settlement submission.
    /// @param _taskId Task whose verification request failed.
    /// @param _submissionId Active submission whose request failed.
    /// @param _requestId Verifier request identifier that must match the active submission.
    /// @param _failureNotesURI Public URI or deterministic note describing the failure.
    function recordVerificationFailure(
        uint256 _taskId,
        uint256 _submissionId,
        bytes32 _requestId,
        string calldata _failureNotesURI
    ) external;
}
