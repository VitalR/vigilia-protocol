// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title VigiliaTypes
/// @notice Shared protocol types used across escrow and verifier adapters.
library VigiliaTypes {
    /// @notice Bounded verifier results accepted by Vigilia escrow contracts.
    /// @dev `Unknown` is reserved for unset or unsupported results and must fail closed when recording a verdict.
    enum VerificationVerdict {
        Unknown,
        Complete,
        NeedsReview,
        Incomplete
    }
}
