import { VIGILIA_ESCROW_ABI, VIGILIA_GRANT_ROUND_ABI } from "./abi";

export const VIGILIA_ESCROW_ADDRESS = (process.env.NEXT_PUBLIC_VIGILIA_ESCROW_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const VIGILIA_VERIFIER_ADDRESS = (process.env.NEXT_PUBLIC_VIGILIA_VERIFIER_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const VIGILIA_GRANT_ROUND_ADDRESS = (process.env.NEXT_PUBLIC_VIGILIA_GRANT_ROUND_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const VIGILIA_GRANT_VERIFIER_ADDRESS = (process.env.NEXT_PUBLIC_VIGILIA_GRANT_VERIFIER_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const escrowContract = {
  address: VIGILIA_ESCROW_ADDRESS,
  abi: VIGILIA_ESCROW_ABI,
} as const;

export const grantRoundContract = {
  address: VIGILIA_GRANT_ROUND_ADDRESS,
  abi: VIGILIA_GRANT_ROUND_ABI,
} as const;

// ─── TaskState enum ───────────────────────────────────────────────────────────
export enum TaskState {
  None = 0,
  Created = 1,
  Funded = 2,
  Submitted = 3,
  VerifiedComplete = 4,
  NeedsReview = 5,
  Incomplete = 6,
  VerificationFailed = 7,
  Approved = 8,
  Claimed = 9,
  Disputed = 10,
  Resolved = 11,
  Cancelled = 12,
}

// ─── ClaimPolicy enum ─────────────────────────────────────────────────────────
export enum ClaimPolicy {
  ClientApprovalOnly = 0,
  ReviewWindowAutoClaim = 1,
  ImmediateAutoClaim = 2,
}

export const CLAIM_POLICY_LABEL: Record<ClaimPolicy, string> = {
  [ClaimPolicy.ClientApprovalOnly]: "Client approval required",
  [ClaimPolicy.ReviewWindowAutoClaim]: "Auto-claim after review window",
  [ClaimPolicy.ImmediateAutoClaim]: "Immediate claim",
};

// ─── VerificationVerdict enum ─────────────────────────────────────────────────
export enum VerificationVerdict {
  Unknown = 0,
  Complete = 1,
  NeedsReview = 2,
  Incomplete = 3,
}

export const TASK_STATE_LABEL: Record<TaskState, string> = {
  [TaskState.None]: "None",
  [TaskState.Created]: "Created",
  [TaskState.Funded]: "Funded",
  [TaskState.Submitted]: "Verifying",
  [TaskState.VerifiedComplete]: "Complete",
  [TaskState.NeedsReview]: "Needs Review",
  [TaskState.Incomplete]: "Incomplete",
  [TaskState.VerificationFailed]: "Verify Failed",
  [TaskState.Approved]: "Approved",
  [TaskState.Claimed]: "Claimed",
  [TaskState.Disputed]: "Disputed",
  [TaskState.Resolved]: "Resolved",
  [TaskState.Cancelled]: "Cancelled",
};

export const VERDICT_LABEL: Record<VerificationVerdict, string> = {
  [VerificationVerdict.Unknown]: "Pending",
  [VerificationVerdict.Complete]: "Complete",
  [VerificationVerdict.NeedsReview]: "Needs Review",
  [VerificationVerdict.Incomplete]: "Incomplete",
};

// ─── GrantRound enums ─────────────────────────────────────────────────────────
export enum RoundState {
  None = 0,
  Created = 1,
  Open = 2,
  Review = 3,
  Finalized = 4,
  Cancelled = 5,
}

export enum ApplicationStatus {
  None = 0,
  Submitted = 1,
  ScreeningRequested = 2,
  Complete = 3,
  NeedsReview = 4,
  Incomplete = 5,
  VerificationFailed = 6,
  Selected = 7,
  Rejected = 8,
  Claimed = 9,
}

export enum ScreeningMode {
  TwoAgent = 0,
  ThreeAgent = 1,
}

export const ROUND_STATE_LABEL: Record<RoundState, string> = {
  [RoundState.None]: "None",
  [RoundState.Created]: "Created",
  [RoundState.Open]: "Open",
  [RoundState.Review]: "Review",
  [RoundState.Finalized]: "Finalized",
  [RoundState.Cancelled]: "Cancelled",
};

export const APPLICATION_STATUS_LABEL: Record<ApplicationStatus, string> = {
  [ApplicationStatus.None]: "None",
  [ApplicationStatus.Submitted]: "Submitted",
  [ApplicationStatus.ScreeningRequested]: "Screening",
  [ApplicationStatus.Complete]: "Complete",
  [ApplicationStatus.NeedsReview]: "Needs Review",
  [ApplicationStatus.Incomplete]: "Incomplete",
  [ApplicationStatus.VerificationFailed]: "Verify Failed",
  [ApplicationStatus.Selected]: "Selected",
  [ApplicationStatus.Rejected]: "Rejected",
  [ApplicationStatus.Claimed]: "Claimed",
};

export const SCREENING_MODE_LABEL: Record<ScreeningMode, string> = {
  [ScreeningMode.TwoAgent]: "TwoAgent — JSON facts → LLM verdict",
  [ScreeningMode.ThreeAgent]: "ThreeAgent — JSON facts + Website Parse + LLM verdict",
};
