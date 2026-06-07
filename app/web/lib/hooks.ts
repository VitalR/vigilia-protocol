"use client";

import { useCallback, useEffect, useState } from "react";
import { usePublicClient, useReadContract, useReadContracts } from "wagmi";
import { decodeEventLog, formatEther, parseEther } from "viem";
import { truncateAddress } from "./utils";
import { VIGILIA_ESCROW_ABI, VIGILIA_GRANT_ROUND_ABI } from "./abi";
import {
  escrowContract,
  grantRoundContract,
  ClaimPolicy,
  TaskState,
  VerificationVerdict,
  ApplicationStatus,
  RoundState,
  ScreeningMode,
  VIGILIA_ESCROW_ADDRESS,
  VIGILIA_GRANT_ROUND_ADDRESS,
} from "./contracts";

// ─── Deployment guard ─────────────────────────────────────────────────────────
// If address is zero (env not set), skip all RPC calls immediately.
const ZERO = "0x0000000000000000000000000000000000000000";

export function useIsDeployed() {
  return VIGILIA_ESCROW_ADDRESS !== ZERO;
}

// ─── Task data ────────────────────────────────────────────────────────────────

export type Task = {
  client: `0x${string}`;
  contractor: `0x${string}`;
  resolver: `0x${string}`;
  amount: bigint;
  fundedAmount: bigint;
  activeSubmissionId: bigint;
  submissionCount: bigint;
  state: TaskState;
  stateBeforeDispute: TaskState;
  requirementsURI: string;
  reviewWindow: number;
  verificationTimeout: number;
};

export type Submission = {
  taskId: bigint;
  submitter: `0x${string}`;
  evidenceURI: string;
  evidenceHash: `0x${string}`;
  requestId: `0x${string}`;
  verdict: VerificationVerdict;
  submittedAt: number;
  verifiedAt: number;
};

function parseTask(raw: readonly unknown[]): Task {
  return {
    client: raw[0] as `0x${string}`,
    contractor: raw[1] as `0x${string}`,
    resolver: raw[2] as `0x${string}`,
    amount: raw[3] as bigint,
    fundedAmount: raw[4] as bigint,
    activeSubmissionId: raw[5] as bigint,
    submissionCount: raw[6] as bigint,
    state: raw[7] as TaskState,
    stateBeforeDispute: raw[8] as TaskState,
    requirementsURI: raw[9] as string,
    reviewWindow: Number(raw[10]),
    verificationTimeout: Number(raw[11]),
  };
}

function parseSubmission(raw: readonly unknown[]): Submission {
  return {
    taskId: raw[0] as bigint,
    submitter: raw[1] as `0x${string}`,
    evidenceURI: raw[2] as string,
    evidenceHash: raw[3] as `0x${string}`,
    requestId: raw[4] as `0x${string}`,
    verdict: raw[5] as VerificationVerdict,
    submittedAt: Number(raw[6]),
    verifiedAt: Number(raw[7]),
  };
}

export function useTask(taskId: bigint) {
  const isDeployed = useIsDeployed();

  const { data: taskRaw, isLoading, refetch } = useReadContract({
    ...escrowContract,
    functionName: "tasks",
    args: [taskId],
    query: { enabled: isDeployed && taskId > 0n },
  });

  const task: Task | null = taskRaw ? parseTask(taskRaw as readonly unknown[]) : null;

  const { data: submissionRaw, refetch: refetchSubmission } = useReadContract({
    ...escrowContract,
    functionName: "submissions",
    args: [task?.activeSubmissionId ?? 0n],
    query: { enabled: isDeployed && !!task && task.activeSubmissionId > 0n },
  });

  const { data: claimPolicyRaw, refetch: refetchPolicy } = useReadContract({
    ...escrowContract,
    functionName: "taskClaimPolicies",
    args: [taskId],
    query: { enabled: isDeployed && taskId > 0n },
  });

  const activeSubmission: Submission | null = submissionRaw
    ? parseSubmission(submissionRaw as readonly unknown[])
    : null;

  const claimPolicy: ClaimPolicy = claimPolicyRaw != null
    ? (Number(claimPolicyRaw) as ClaimPolicy)
    : ClaimPolicy.ReviewWindowAutoClaim;

  return {
    task,
    activeSubmission,
    claimPolicy,
    isLoading: isDeployed ? isLoading : false,
    refetch: () => { refetch(); refetchSubmission(); refetchPolicy(); },
  };
}

// ─── Milestones list ──────────────────────────────────────────────────────────

const PAGE_SIZE = 20;

export function useMilestones(page = 0) {
  const isDeployed = useIsDeployed();

  const { data: nextTaskIdRaw, isLoading: loadingCount } = useReadContract({
    ...escrowContract,
    functionName: "nextTaskId",
    query: { enabled: isDeployed },
  });

  const totalTasks = nextTaskIdRaw ? Number(nextTaskIdRaw) - 1 : 0;
  const totalPages = Math.ceil(totalTasks / PAGE_SIZE);

  // Most recent tasks first — show newest page by default
  const start = Math.max(1, totalTasks - page * PAGE_SIZE - PAGE_SIZE + 1);
  const end = Math.max(0, totalTasks - page * PAGE_SIZE);
  const taskIds = Array.from({ length: end - start + 1 }, (_, i) => end - i).filter(
    (id) => id >= 1
  );

  const { data: tasksData, isLoading: loadingTasks } = useReadContracts({
    contracts: taskIds.map((id) => ({
      ...escrowContract,
      functionName: "tasks" as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: isDeployed && taskIds.length > 0 },
  });

  const tasks = tasksData
    ?.map((result, i) => {
      if (result.status !== "success" || !result.result) return null;
      return { id: taskIds[i], task: parseTask(result.result as readonly unknown[]) };
    })
    .filter(Boolean) as { id: number; task: Task }[] | undefined;

  return {
    tasks,
    totalTasks,
    totalPages,
    isLoading: isDeployed ? loadingCount || loadingTasks : false,
    isDeployed,
  };
}

// ─── Agent fee ────────────────────────────────────────────────────────────────

const VERIFIER_ABI = [
  // v0.2.x multi-agent: deposit for a full settlement workflow
  {
    name: "minimumRequestDepositForWorkflow",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "_workflow", type: "uint8" }],
    outputs: [{ name: "deposit", type: "uint256" }],
  },
  // v0.1.x fallback (single-agent verifier)
  {
    name: "minimumRequestDeposit",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

// SettlementWorkflow.JsonFactsToLlmVerdict = 3
const JSON_FACTS_TO_LLM_VERDICT = 3;

export function useAgentFee() {
  const isDeployed = VIGILIA_ESCROW_ADDRESS !== ZERO;

  // Read verifier address directly from the escrow contract (no env var needed)
  const { data: verifierAddress } = useReadContract({
    ...escrowContract,
    functionName: "verifier",
    query: { enabled: isDeployed },
  });
  const verifier = verifierAddress as `0x${string}` | undefined;

  // Try multi-agent workflow deposit first (v0.2.x)
  const { data: workflowFee } = useReadContract({
    address: verifier,
    abi: VERIFIER_ABI,
    functionName: "minimumRequestDepositForWorkflow",
    args: [JSON_FACTS_TO_LLM_VERDICT],
    query: { enabled: !!verifier },
  });

  // Fallback: single-agent (v0.1.x)
  const { data: singleFee } = useReadContract({
    address: verifier,
    abi: VERIFIER_ABI,
    functionName: "minimumRequestDeposit",
    query: { enabled: !!verifier && !workflowFee },
  });

  return (workflowFee ?? singleFee) as bigint | undefined;
}

// ─── GrantRound hooks ─────────────────────────────────────────────────────────

export function useGrantIsDeployed() {
  return VIGILIA_GRANT_ROUND_ADDRESS !== "0x0000000000000000000000000000000000000000";
}

export type GrantRound = {
  sponsor: `0x${string}`;
  judge: `0x${string}`;
  prizeAmount: bigint;
  maxWinners: bigint;
  totalFunded: bigint;
  selectedCount: bigint;
  claimedCount: bigint;
  totalClaimed: bigint;
  totalRefunded: bigint;
  applicationsCount: bigint;
  applicationDeadline: number;
  reviewDeadline: number;
  requirementsURI: string;
  screeningMode: ScreeningMode;
  state: RoundState;
};

export type GrantApplication = {
  roundId: bigint;
  applicant: `0x${string}`;
  evidenceURI: string;
  evidenceHash: `0x${string}`;
  requestId: `0x${string}`;
  verdict: VerificationVerdict;
  status: ApplicationStatus;
  selected: boolean;
  claimed: boolean;
  submittedAt: number;
  reviewedAt: number;
  notesURI: string;
};

function parseGrantRound(raw: readonly unknown[]): GrantRound {
  return {
    sponsor: raw[0] as `0x${string}`,
    judge: raw[1] as `0x${string}`,
    prizeAmount: raw[2] as bigint,
    maxWinners: raw[3] as bigint,
    totalFunded: raw[4] as bigint,
    selectedCount: raw[5] as bigint,
    claimedCount: raw[6] as bigint,
    totalClaimed: raw[7] as bigint,
    totalRefunded: raw[8] as bigint,
    applicationsCount: raw[9] as bigint,
    applicationDeadline: Number(raw[10]),
    reviewDeadline: Number(raw[11]),
    requirementsURI: raw[12] as string,
    screeningMode: Number(raw[13]) as ScreeningMode,
    state: Number(raw[14]) as RoundState,
  };
}

function parseGrantApplication(raw: readonly unknown[]): GrantApplication {
  return {
    roundId: raw[0] as bigint,
    applicant: raw[1] as `0x${string}`,
    evidenceURI: raw[2] as string,
    evidenceHash: raw[3] as `0x${string}`,
    requestId: raw[4] as `0x${string}`,
    verdict: Number(raw[5]) as VerificationVerdict,
    status: Number(raw[6]) as ApplicationStatus,
    selected: raw[7] as boolean,
    claimed: raw[8] as boolean,
    submittedAt: Number(raw[9]),
    reviewedAt: Number(raw[10]),
    notesURI: raw[11] as string,
  };
}

const GRANT_PAGE_SIZE = 20;

export function useGrantRounds(page = 0) {
  const isDeployed = useGrantIsDeployed();

  const { data: nextRoundIdRaw, isLoading: loadingCount, refetch: refetchCount } = useReadContract({
    ...grantRoundContract,
    functionName: "nextRoundId",
    query: { enabled: isDeployed },
  });

  const totalRounds = nextRoundIdRaw ? Number(nextRoundIdRaw) - 1 : 0;
  const totalPages = Math.ceil(totalRounds / GRANT_PAGE_SIZE);
  const start = Math.max(1, totalRounds - page * GRANT_PAGE_SIZE - GRANT_PAGE_SIZE + 1);
  const end = Math.max(0, totalRounds - page * GRANT_PAGE_SIZE);
  const roundIds = Array.from({ length: end - start + 1 }, (_, i) => end - i).filter((id) => id >= 1);

  const { data: roundsData, isLoading: loadingRounds, refetch: refetchRounds } = useReadContracts({
    contracts: roundIds.map((id) => ({
      ...grantRoundContract,
      functionName: "rounds" as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: isDeployed && roundIds.length > 0 },
  });

  const rounds = roundsData
    ?.map((result, i) => {
      if (result.status !== "success" || !result.result) return null;
      return { id: roundIds[i], round: parseGrantRound(result.result as readonly unknown[]) };
    })
    .filter(Boolean) as { id: number; round: GrantRound }[] | undefined;

  return {
    rounds,
    totalRounds,
    totalPages,
    isLoading: isDeployed ? loadingCount || loadingRounds : false,
    isDeployed,
    refetch: async () => { await refetchCount(); await refetchRounds(); },
  };
}

export function useGrantRound(roundId: bigint) {
  const isDeployed = useGrantIsDeployed();

  const { data: roundRaw, isLoading, refetch } = useReadContract({
    ...grantRoundContract,
    functionName: "rounds",
    args: [roundId],
    query: { enabled: isDeployed && roundId > 0n },
  });

  const round: GrantRound | null = roundRaw ? parseGrantRound(roundRaw as readonly unknown[]) : null;

  const { data: applicationIds, refetch: refetchIds } = useReadContract({
    ...grantRoundContract,
    functionName: "getRoundApplications",
    args: [roundId],
    query: { enabled: isDeployed && roundId > 0n },
  });

  const { data: applicationsData, refetch: refetchApps } = useReadContracts({
    contracts: (applicationIds ?? []).map((id) => ({
      ...grantRoundContract,
      functionName: "applications" as const,
      args: [id] as const,
    })),
    query: { enabled: isDeployed && !!applicationIds && applicationIds.length > 0 },
  });

  const applications = applicationsData
    ?.map((result, i) => {
      if (result.status !== "success" || !result.result) return null;
      return {
        id: (applicationIds as bigint[])[i],
        application: parseGrantApplication(result.result as readonly unknown[]),
      };
    })
    .filter(Boolean) as { id: bigint; application: GrantApplication }[] | undefined;

  return {
    round,
    applications: applications ?? [],
    applicationIds: (applicationIds ?? []) as bigint[],
    isLoading: isDeployed ? isLoading : false,
    refetch: () => { refetch(); refetchIds(); refetchApps(); },
  };
}

// SettlementWorkflow.JsonFactsAndWebsiteToLlmVerdict = 4
const THREE_AGENT_WORKFLOW = 4;

export function useGrantAgentFee(screeningMode: ScreeningMode) {
  const isDeployed = VIGILIA_GRANT_ROUND_ADDRESS !== ZERO;
  const workflow = screeningMode === ScreeningMode.ThreeAgent ? THREE_AGENT_WORKFLOW : JSON_FACTS_TO_LLM_VERDICT;

  // Read verifier address directly from the grant round contract (no env var needed)
  const { data: verifierAddress } = useReadContract({
    ...grantRoundContract,
    functionName: "verifier",
    query: { enabled: isDeployed },
  });
  const verifier = verifierAddress as `0x${string}` | undefined;

  const { data: fee } = useReadContract({
    address: verifier,
    abi: VERIFIER_ABI,
    functionName: "minimumRequestDepositForWorkflow",
    args: [workflow],
    query: { enabled: !!verifier },
  });

  return fee as bigint | undefined;
}

// ─── Robust taskId extraction from tx receipt ─────────────────────────────────

export function extractTaskIdFromReceipt(
  logs: readonly { topics: readonly string[]; data: string }[]
): bigint | null {
  for (const log of logs) {
    try {
      const decoded = decodeEventLog({
        abi: VIGILIA_ESCROW_ABI,
        eventName: "TaskCreated",
        topics: log.topics as [`0x${string}`, ...`0x${string}`[]],
        data: log.data as `0x${string}`,
      });
      if (decoded.args.taskId != null) return decoded.args.taskId;
    } catch {
      // not this log
    }
  }
  return null;
}

// ─── Trail events ─────────────────────────────────────────────────────────────

export type TrailEvent = {
  key: string;
  name: string;
  taskId?: bigint;
  details: string;
  address?: string;
  amount?: bigint;
  txHash?: `0x${string}`;
  blockNumber: bigint;
  timestamp?: number;
  state?: TaskState;
  icon: string;
  colorClass: string;
  isDerived?: boolean;
};

export const TRAIL_EVENT_META: Record<string, { icon: string; colorClass: string }> = {
  TaskCreated:                { icon: "✦", colorClass: "text-blue" },
  TaskFunded:                 { icon: "💰", colorClass: "text-blue" },
  WorkSubmitted:              { icon: "📋", colorClass: "text-yellow" },
  VerdictRecorded:            { icon: "✓",  colorClass: "text-green" },
  VerificationFailedRecorded: { icon: "✗",  colorClass: "text-red" },
  VerificationTimedOut:       { icon: "⏱",  colorClass: "text-red" },
  VerificationRetried:        { icon: "↺",  colorClass: "text-yellow" },
  TaskApproved:               { icon: "✓",  colorClass: "text-green" },
  TaskClaimed:                { icon: "💸", colorClass: "text-green" },
  DisputeRaised:              { icon: "⚡", colorClass: "text-red" },
  DisputeResolved:            { icon: "⚖", colorClass: "text-muted" },
  TaskCancelled:              { icon: "✕",  colorClass: "text-muted" },
  PendingWithdrawalClaimed:   { icon: "↓",  colorClass: "text-green" },
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function parseTrailLog(eventName: string, log: any): TrailEvent {
  const meta = TRAIL_EVENT_META[eventName] ?? { icon: "·", colorClass: "text-muted" };
  const args = (log.args ?? {}) as Record<string, unknown>;
  let details = "";
  let taskId: bigint | undefined;
  let address: string | undefined;
  let amount: bigint | undefined;
  let state: TaskState | undefined;

  if ("taskId" in args) taskId = args.taskId as bigint;

  switch (eventName) {
    case "TaskCreated":
      address = args.client as string;
      amount = args.amount as bigint;
      details = `${truncateAddress(args.contractor as string)} assigned`;
      break;
    case "TaskFunded":
      address = args.client as string;
      amount = args.amount as bigint;
      details = "Funded";
      state = TaskState.Funded;
      break;
    case "WorkSubmitted":
      address = args.submitter as string;
      details = "Evidence submitted";
      state = TaskState.Submitted;
      break;
    case "VerdictRecorded": {
      const v = Number(args.verdict);
      const verdictMap: Record<number, string> = { 1: "Complete", 2: "Needs Review", 3: "Incomplete" };
      details = `Verdict: ${verdictMap[v] ?? "Unknown"}`;
      state = v === 1 ? TaskState.VerifiedComplete : v === 2 ? TaskState.NeedsReview : TaskState.Incomplete;
      break;
    }
    case "VerificationFailedRecorded":
      details = "Verification failed";
      state = TaskState.VerificationFailed;
      break;
    case "VerificationTimedOut":
      details = "Verification timed out";
      state = TaskState.VerificationFailed;
      break;
    case "VerificationRetried":
      address = args.payer as string;
      details = "Verification retried";
      break;
    case "TaskApproved":
      address = args.client as string;
      details = "Approved by client";
      state = TaskState.Approved;
      break;
    case "TaskClaimed":
      address = args.contractor as string;
      amount = args.amount as bigint;
      details = "Payment claimed";
      state = TaskState.Claimed;
      break;
    case "DisputeRaised":
      address = args.raisedBy as string;
      details = "Dispute raised";
      state = TaskState.Disputed;
      break;
    case "DisputeResolved":
      address = args.resolver as string;
      details = "Dispute resolved";
      state = TaskState.Resolved;
      break;
    case "TaskCancelled":
      address = args.client as string;
      amount = args.refundAmount as bigint;
      details = "Cancelled";
      state = TaskState.Cancelled;
      break;
    case "PendingWithdrawalClaimed":
      address = args.account as string;
      amount = args.amount as bigint;
      details = "Withdrawal claimed";
      break;
  }

  return {
    key: `${log.transactionHash}-${log.logIndex}`,
    name: eventName,
    taskId,
    details,
    address,
    amount,
    txHash: log.transactionHash as `0x${string}`,
    blockNumber: log.blockNumber ?? 0n,
    state,
    ...meta,
  };
}

// ─── Shared scan helper ───────────────────────────────────────────────────────

const CHUNK_SIZE = 1000n;
const PAGE_BLOCKS = 500_000n; // 500 chunks × 1000 — one "page"
const BATCH_SIZE  = 50;       // parallel requests per round (10 rounds for 500k)

async function scanRange(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  publicClient: any,
  from: bigint,
  to: bigint,
  filterTaskId?: bigint,
): Promise<TrailEvent[]> {
  const chunks: { from: bigint; to: bigint }[] = [];
  for (let f = from; f <= to; f += CHUNK_SIZE) {
    chunks.push({ from: f, to: f + CHUNK_SIZE - 1n < to ? f + CHUNK_SIZE - 1n : to });
  }

  const parsed: TrailEvent[] = [];
  for (let i = 0; i < chunks.length; i += BATCH_SIZE) {
    const batch = chunks.slice(i, i + BATCH_SIZE);
    const results = await Promise.allSettled(
      batch.map(({ from, to }) =>
        publicClient.getLogs({ address: VIGILIA_ESCROW_ADDRESS, fromBlock: from, toBlock: to })
      )
    );
    for (const r of results) {
      if (r.status !== "fulfilled") continue;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      for (const log of r.value as any[]) {
        try {
          const decoded = decodeEventLog({ abi: VIGILIA_ESCROW_ABI, data: log.data, topics: log.topics });
          if (!decoded.eventName || !(decoded.eventName in TRAIL_EVENT_META)) continue;
          const ev = parseTrailLog(decoded.eventName, { ...log, args: decoded.args });
          if (filterTaskId != null && ev.taskId !== filterTaskId) continue;
          parsed.push(ev);
        } catch { /* unknown log */ }
      }
    }
  }
  return parsed;
}

// ─── General trail (auto-scan backwards, newest-first) ───────────────────────

// Scan backwards up to this many pages before stopping.
const MAX_AUTO_PAGES = 20;
// Keep scanning if fewer than this many new events were found so far.
const MIN_NEW_EVENTS = 15;

export function useTrailEvents() {
  const publicClient = usePublicClient();
  const isDeployed = useIsDeployed();
  const [events, setEvents] = useState<TrailEvent[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [scanHead, setScanHead] = useState<bigint | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [lastFetched, setLastFetched] = useState<Date | null>(null);
  const [scanProgress, setScanProgress] = useState<string | null>(null);

  // Initial load: scan backwards page by page until events are found.
  // Stops as soon as the first page with events is found, then exposes
  // loadMore for further manual pagination.
  useEffect(() => {
    if (!publicClient || !isDeployed) return;
    let cancelled = false;
    (async () => {
      setIsLoading(true);
      setScanProgress(null);
      try {
        const latest = await publicClient.getBlockNumber();
        let head = latest;
        let lastFrom = latest;
        let pagesScanned = 0;
        const accumulated: TrailEvent[] = [];

        while (head > 0n && !cancelled && pagesScanned < MAX_AUTO_PAGES) {
          const from = head > PAGE_BLOCKS ? head - PAGE_BLOCKS : 0n;
          lastFrom = from;
          setScanProgress(
            `blocks ${(Number(from) / 1_000_000).toFixed(1)}M – ${(Number(head) / 1_000_000).toFixed(1)}M`
          );
          const found = await scanRange(publicClient, from, head);
          if (cancelled) break;
          pagesScanned++;
          accumulated.push(...found);

          if (accumulated.length >= MIN_NEW_EVENTS || from === 0n) break;
          head = from - 1n;
        }

        if (!cancelled) {
          if (accumulated.length > 0) {
            accumulated.sort((a, b) => (a.blockNumber > b.blockNumber ? -1 : 1));
            setEvents(accumulated);
            setLastFetched(new Date());
          }
          const nextHead = lastFrom > 0n ? lastFrom - 1n : null;
          setScanHead(nextHead);
          setHasMore(nextHead !== null);
        }
      } catch (e) {
        console.error("Trail initial load failed:", e);
      } finally {
        if (!cancelled) { setIsLoading(false); setScanProgress(null); }
      }
    })();
    return () => { cancelled = true; };
  }, [publicClient, isDeployed]);

  const loadMore = useCallback(async () => {
    if (!publicClient || !isDeployed || !scanHead || isLoadingMore) return;
    setIsLoadingMore(true);
    setScanProgress(null);
    try {
      let head = scanHead;
      let lastFrom = head;
      const accumulated: TrailEvent[] = [];
      let pagesScanned = 0;

      // Scan backwards, accumulating events, until we have MIN_NEW_EVENTS or
      // exhaust MAX_AUTO_PAGES — so a single click never returns empty.
      while (head > 0n && pagesScanned < MAX_AUTO_PAGES) {
        const from = head > PAGE_BLOCKS ? head - PAGE_BLOCKS : 0n;
        lastFrom = from;
        setScanProgress(
          `blocks ${(Number(from) / 1_000_000).toFixed(1)}M – ${(Number(head) / 1_000_000).toFixed(1)}M`
        );
        const found = await scanRange(publicClient, from, head);
        accumulated.push(...found);
        pagesScanned++;

        if (accumulated.length >= MIN_NEW_EVENTS || from === 0n) break;
        head = from - 1n;
      }

      if (accumulated.length > 0) {
        setEvents((prev) => {
          const merged = [...prev, ...accumulated];
          merged.sort((a, b) => (a.blockNumber > b.blockNumber ? -1 : 1));
          return merged;
        });
        setLastFetched(new Date());
      }
      const nextHead = lastFrom > 0n ? lastFrom - 1n : null;
      setScanHead(nextHead);
      setHasMore(nextHead !== null);
    } catch (e) {
      console.error("Trail loadMore failed:", e);
    } finally {
      setIsLoadingMore(false);
      setScanProgress(null);
    }
  }, [publicClient, isDeployed, scanHead, isLoadingMore]);

  return { events, isLoading, isLoadingMore, hasMore, loadMore, lastFetched, scanProgress };
}

// ─── Per-milestone trail (streams backwards, stops at TaskCreated) ────────────

export function useTaskTrailEvents(taskId: bigint) {
  const publicClient = usePublicClient();
  const isDeployed = useIsDeployed();
  const [events, setEvents] = useState<TrailEvent[]>([]);
  const [isScanning, setIsScanning] = useState(false);

  useEffect(() => {
    if (!publicClient || !isDeployed || !taskId) return;
    let cancelled = false;
    setEvents([]);
    setIsScanning(true);
    (async () => {
      try {
        const latest = await publicClient.getBlockNumber();
        let head = latest;
        while (head > 0n && !cancelled) {
          const from = head > PAGE_BLOCKS ? head - PAGE_BLOCKS : 0n;
          const found = await scanRange(publicClient, from, head, taskId);
          if (cancelled) break;
          if (found.length > 0) {
            setEvents((prev) => {
              const merged = [...prev, ...found];
              merged.sort((a, b) => (a.blockNumber > b.blockNumber ? -1 : 1));
              return merged;
            });
            // TaskCreated is the earliest possible event — stop scanning
            if (found.some((e) => e.name === "TaskCreated")) break;
          }
          if (from === 0n) break;
          head = from - 1n;
        }
      } catch (e) {
        console.error("Task trail scan failed:", e);
      } finally {
        if (!cancelled) setIsScanning(false);
      }
    })();
    return () => { cancelled = true; };
  }, [publicClient, isDeployed, taskId]);

  return { events, isScanning };
}

// ─── Grant round execution trail ──────────────────────────────────────────────

export type GrantTrailItem = {
  key: string;
  dot: "green" | "blue" | "yellow" | "muted";
  title: string;
  subtitle: string;
  txHash?: `0x${string}`;
  blockNumber: bigint;
};

type RawGrantLog = {
  eventName: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  args: any;
  blockNumber: bigint;
  transactionHash: `0x${string}`;
};

async function scanGrantChunks(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  publicClient: any,
  from: bigint,
  to: bigint,
): Promise<RawGrantLog[]> {
  const chunks: { from: bigint; to: bigint }[] = [];
  for (let f = from; f <= to; f += CHUNK_SIZE) {
    chunks.push({ from: f, to: f + CHUNK_SIZE - 1n < to ? f + CHUNK_SIZE - 1n : to });
  }
  const parsed: RawGrantLog[] = [];
  for (let i = 0; i < chunks.length; i += BATCH_SIZE) {
    const batch = chunks.slice(i, i + BATCH_SIZE);
    const results = await Promise.allSettled(
      batch.map(({ from: f, to: t }) =>
        publicClient.getLogs({ address: VIGILIA_GRANT_ROUND_ADDRESS, fromBlock: f, toBlock: t })
      )
    );
    for (const r of results) {
      if (r.status !== "fulfilled") continue;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      for (const log of r.value as any[]) {
        try {
          const decoded = decodeEventLog({ abi: VIGILIA_GRANT_ROUND_ABI, data: log.data, topics: log.topics });
          if (!decoded.eventName) continue;
          parsed.push({
            eventName: decoded.eventName as string,
            args: decoded.args,
            blockNumber: log.blockNumber as bigint,
            transactionHash: log.transactionHash as `0x${string}`,
          });
        } catch { /* unknown log */ }
      }
    }
  }
  return parsed;
}

function fmtSTT(wei: bigint): string {
  const n = Number(formatEther(wei));
  return `${n % 1 === 0 ? n.toFixed(0) : n.toFixed(2)} STT`;
}

function buildGrantTrail(rawLogs: RawGrantLog[], roundId: bigint): GrantTrailItem[] {
  // Group by event name, filtering to this roundId
  const byType: Record<string, RawGrantLog[]> = {};
  for (const log of rawLogs) {
    if (log.args.roundId !== undefined && log.args.roundId !== roundId) continue;
    if (!byType[log.eventName]) byType[log.eventName] = [];
    byType[log.eventName].push(log);
  }

  const trail: GrantTrailItem[] = [];
  const last = (evs: RawGrantLog[]) => evs.reduce((a, b) => (a.blockNumber > b.blockNumber ? a : b));

  if (byType.RoundCreated?.length) {
    const e = byType.RoundCreated[0];
    const a = e.args;
    trail.push({
      key: "created",
      dot: "muted",
      title: "Grant Created",
      subtitle: `Prize: ${fmtSTT(a.prizeAmount)} × ${a.maxWinners} winners`,
      txHash: e.transactionHash,
      blockNumber: e.blockNumber,
    });
  }

  if (byType.RoundFunded?.length) {
    const e = byType.RoundFunded[0];
    trail.push({
      key: "funded",
      dot: "green",
      title: "Grant Funded",
      subtitle: `${fmtSTT(e.args.amount)} locked · applications open`,
      txHash: e.transactionHash,
      blockNumber: e.blockNumber,
    });
  }

  if (byType.ApplicationSubmitted?.length) {
    const evs = byType.ApplicationSubmitted;
    const l = last(evs);
    trail.push({
      key: "apps-submitted",
      dot: "blue",
      title: `${evs.length} Application${evs.length !== 1 ? "s" : ""} Submitted`,
      subtitle: "Evidence attached · awaiting screening",
      txHash: l.transactionHash,
      blockNumber: l.blockNumber,
    });
  }

  if (byType.ApplicationScreeningRequested?.length) {
    const evs = byType.ApplicationScreeningRequested;
    const l = last(evs);
    trail.push({
      key: "screening",
      dot: "blue",
      title: `${evs.length} Screening Request${evs.length !== 1 ? "s" : ""} Sent`,
      subtitle: "Somnia agent review triggered",
      txHash: l.transactionHash,
      blockNumber: l.blockNumber,
    });
  }

  const verdictEvs = [...(byType.ApplicationVerdictRecorded ?? []), ...(byType.ApplicationVerificationFailed ?? [])];
  if (verdictEvs.length) {
    const l = verdictEvs.reduce((a, b) => (a.blockNumber > b.blockNumber ? a : b));
    const appIds = verdictEvs.map((e) => `#${e.args.applicationId}`).join(", ");
    trail.push({
      key: "verdicts",
      dot: "blue",
      title: "Agent Verdicts Returned",
      subtitle: `${verdictEvs.length} application${verdictEvs.length !== 1 ? "s" : ""} screened · app ${appIds}`,
      txHash: l.transactionHash,
      blockNumber: l.blockNumber,
    });
  }

  if (byType.FinalistSelected?.length) {
    const evs = byType.FinalistSelected;
    const l = last(evs);
    const appIds = evs.map((e) => `#${e.args.applicationId}`).join(", ");
    trail.push({
      key: "finalists",
      dot: "green",
      title: "Finalists Selected",
      subtitle: `App ${appIds}`,
      txHash: l.transactionHash,
      blockNumber: l.blockNumber,
    });
  }

  if (byType.RoundFinalized?.length) {
    const e = byType.RoundFinalized[0];
    trail.push({
      key: "finalized",
      dot: "green",
      title: "Grant Finalized",
      subtitle: `${e.args.selectedCount} finalist${e.args.selectedCount !== 1n ? "s" : ""} eligible to claim`,
      txHash: e.transactionHash,
      blockNumber: e.blockNumber,
    });
  }

  if (byType.PrizeClaimed?.length) {
    const evs = byType.PrizeClaimed;
    const l = last(evs);
    const total = evs.reduce((sum: bigint, e) => sum + BigInt(e.args.amount ?? 0n), 0n);
    trail.push({
      key: "claimed",
      dot: "green",
      title: `${evs.length} Prize${evs.length !== 1 ? "s" : ""} Claimed`,
      subtitle: `${fmtSTT(total)} distributed`,
      txHash: l.transactionHash,
      blockNumber: l.blockNumber,
    });
  }

  if (byType.RoundCancelled?.length) {
    const e = byType.RoundCancelled[0];
    trail.push({
      key: "cancelled",
      dot: "muted",
      title: "Grant Cancelled",
      subtitle: `${fmtSTT(e.args.refundAmount)} refunded to sponsor`,
      txHash: e.transactionHash,
      blockNumber: e.blockNumber,
    });
  }

  trail.sort((a, b) => (a.blockNumber < b.blockNumber ? -1 : 1));
  return trail;
}

export function useGrantRoundTrail(roundId: bigint) {
  const publicClient = usePublicClient();
  const isDeployed = useGrantIsDeployed();
  const [items, setItems] = useState<GrantTrailItem[]>([]);
  const [isScanning, setIsScanning] = useState(false);

  useEffect(() => {
    if (!publicClient || !isDeployed || !roundId) return;
    let cancelled = false;
    setItems([]);
    setIsScanning(true);

    (async () => {
      try {
        const latest = await publicClient.getBlockNumber();
        const allRaw: RawGrantLog[] = [];
        // Scan backwards, stopping once we find RoundCreated for this round
        let head = latest;
        while (head > 0n && !cancelled) {
          const from = head > PAGE_BLOCKS ? head - PAGE_BLOCKS : 0n;
          const found = await scanGrantChunks(publicClient, from, head);
          allRaw.push(...found);
          const hasCreated = found.some(
            (e) => e.eventName === "RoundCreated" && e.args.roundId === roundId
          );
          if (hasCreated || from === 0n) break;
          head = from - 1n;
        }
        if (cancelled) return;
        const trail = buildGrantTrail(allRaw, roundId);
        setItems(trail);
      } catch (e) {
        console.error("Grant round trail scan failed:", e);
      } finally {
        if (!cancelled) setIsScanning(false);
      }
    })();

    return () => { cancelled = true; };
  }, [publicClient, isDeployed, roundId]);

  return { items, isScanning };
}

// ─── Derived trail builders (state → synthetic events, no tx scan needed) ────

/**
 * Build a best-effort trail from task state alone — no block scanning required.
 * Events have isDerived=true and no txHash; shown as placeholders while scanning.
 */
export function buildDerivedTaskEvents(
  task: Task,
  activeSubmission: Submission | null,
  taskId: bigint,
): TrailEvent[] {
  const events: TrailEvent[] = [];
  const s = task.state;

  events.push({
    key: "derived-created",
    name: "TaskCreated",
    taskId,
    details: `${truncateAddress(task.contractor)} assigned`,
    address: task.client,
    amount: task.amount,
    blockNumber: 0n,
    state: TaskState.Created,
    isDerived: true,
    ...TRAIL_EVENT_META.TaskCreated,
  });

  if (s >= TaskState.Funded) {
    events.push({
      key: "derived-funded",
      name: "TaskFunded",
      taskId,
      details: "Funded",
      address: task.client,
      amount: task.fundedAmount,
      blockNumber: 0n,
      state: TaskState.Funded,
      isDerived: true,
      ...TRAIL_EVENT_META.TaskFunded,
    });
  }

  if (s >= TaskState.Submitted) {
    events.push({
      key: "derived-submitted",
      name: "WorkSubmitted",
      taskId,
      details: "Evidence submitted",
      address: activeSubmission?.submitter ?? task.contractor,
      blockNumber: 0n,
      state: TaskState.Submitted,
      isDerived: true,
      ...TRAIL_EVENT_META.WorkSubmitted,
    });
  }

  const verdictStates = [
    TaskState.VerifiedComplete,
    TaskState.NeedsReview,
    TaskState.Incomplete,
    TaskState.Approved,
    TaskState.Claimed,
  ];
  if (verdictStates.includes(s)) {
    const v = activeSubmission?.verdict ?? VerificationVerdict.Unknown;
    const verdictMap: Record<number, string> = { 1: "Complete", 2: "Needs Review", 3: "Incomplete" };
    const verdictState =
      s === TaskState.VerifiedComplete ? TaskState.VerifiedComplete
      : s === TaskState.NeedsReview ? TaskState.NeedsReview
      : TaskState.Incomplete;
    events.push({
      key: "derived-verdict",
      name: "VerdictRecorded",
      taskId,
      details: `Verdict: ${verdictMap[v] ?? "Unknown"}`,
      blockNumber: 0n,
      state: verdictState,
      isDerived: true,
      ...TRAIL_EVENT_META.VerdictRecorded,
    });
  }

  if (s === TaskState.VerificationFailed) {
    events.push({
      key: "derived-verfailed",
      name: "VerificationFailedRecorded",
      taskId,
      details: "Verification failed",
      blockNumber: 0n,
      state: TaskState.VerificationFailed,
      isDerived: true,
      ...TRAIL_EVENT_META.VerificationFailedRecorded,
    });
  }

  if (s === TaskState.Approved || s === TaskState.Claimed) {
    events.push({
      key: "derived-approved",
      name: "TaskApproved",
      taskId,
      details: "Approved by client",
      address: task.client,
      blockNumber: 0n,
      state: TaskState.Approved,
      isDerived: true,
      ...TRAIL_EVENT_META.TaskApproved,
    });
  }

  if (s === TaskState.Claimed) {
    events.push({
      key: "derived-claimed",
      name: "TaskClaimed",
      taskId,
      details: "Payment claimed",
      address: task.contractor,
      amount: task.amount,
      blockNumber: 0n,
      state: TaskState.Claimed,
      isDerived: true,
      ...TRAIL_EVENT_META.TaskClaimed,
    });
  }

  if (s === TaskState.Disputed) {
    events.push({
      key: "derived-disputed",
      name: "DisputeRaised",
      taskId,
      details: "Dispute raised",
      blockNumber: 0n,
      state: TaskState.Disputed,
      isDerived: true,
      ...TRAIL_EVENT_META.DisputeRaised,
    });
  }

  if (s === TaskState.Resolved) {
    events.push({
      key: "derived-disputed",
      name: "DisputeRaised",
      taskId,
      details: "Dispute raised",
      blockNumber: 0n,
      state: TaskState.Disputed,
      isDerived: true,
      ...TRAIL_EVENT_META.DisputeRaised,
    });
    events.push({
      key: "derived-resolved",
      name: "DisputeResolved",
      taskId,
      details: "Dispute resolved",
      address: task.resolver,
      blockNumber: 0n,
      state: TaskState.Resolved,
      isDerived: true,
      ...TRAIL_EVENT_META.DisputeResolved,
    });
  }

  if (s === TaskState.Cancelled) {
    events.push({
      key: "derived-cancelled",
      name: "TaskCancelled",
      taskId,
      details: "Cancelled",
      address: task.client,
      blockNumber: 0n,
      state: TaskState.Cancelled,
      isDerived: true,
      ...TRAIL_EVENT_META.TaskCancelled,
    });
  }

  return events;
}

/**
 * Build a best-effort grant trail from round + application state alone.
 * Items have no txHash; shown as placeholders while scanning.
 */
export function buildDerivedGrantTrail(
  round: GrantRound,
  _roundId: bigint,
  applications: { id: bigint; application: GrantApplication }[],
): GrantTrailItem[] {
  const items: GrantTrailItem[] = [];

  items.push({
    key: "derived-created",
    dot: "muted",
    title: "Grant Created",
    subtitle: `Prize: ${fmtSTT(round.prizeAmount)} × ${round.maxWinners} winners`,
    blockNumber: 0n,
  });

  if (round.totalFunded > 0n) {
    items.push({
      key: "derived-funded",
      dot: "green",
      title: "Grant Funded",
      subtitle: `${fmtSTT(round.totalFunded)} locked · applications open`,
      blockNumber: 0n,
    });
  }

  if (applications.length > 0) {
    items.push({
      key: "derived-apps",
      dot: "blue",
      title: `${applications.length} Application${applications.length !== 1 ? "s" : ""} Submitted`,
      subtitle: "Evidence attached · awaiting screening",
      blockNumber: 0n,
    });
  }

  const screened = applications.filter(
    (a) => a.application.status >= ApplicationStatus.ScreeningRequested,
  );
  if (screened.length > 0) {
    items.push({
      key: "derived-screening",
      dot: "blue",
      title: `${screened.length} Screening Request${screened.length !== 1 ? "s" : ""} Sent`,
      subtitle: "Somnia agent review triggered",
      blockNumber: 0n,
    });
  }

  const verdicted = applications.filter(
    (a) =>
      a.application.verdict !== VerificationVerdict.Unknown ||
      a.application.status === ApplicationStatus.VerificationFailed,
  );
  if (verdicted.length > 0) {
    const appIds = verdicted.map((a) => `#${a.id}`).join(", ");
    items.push({
      key: "derived-verdicts",
      dot: "blue",
      title: "Agent Verdicts Returned",
      subtitle: `${verdicted.length} application${verdicted.length !== 1 ? "s" : ""} screened · app ${appIds}`,
      blockNumber: 0n,
    });
  }

  const selected = applications.filter((a) => a.application.selected);
  if (selected.length > 0) {
    const appIds = selected.map((a) => `#${a.id}`).join(", ");
    items.push({
      key: "derived-finalists",
      dot: "green",
      title: "Finalists Selected",
      subtitle: `App ${appIds}`,
      blockNumber: 0n,
    });
  }

  if (round.state === RoundState.Finalized) {
    items.push({
      key: "derived-finalized",
      dot: "green",
      title: "Grant Finalized",
      subtitle: `${round.selectedCount} finalist${round.selectedCount !== 1n ? "s" : ""} eligible to claim`,
      blockNumber: 0n,
    });
  }

  if (round.totalClaimed > 0n) {
    const claimedCount = applications.filter((a) => a.application.claimed).length;
    items.push({
      key: "derived-claimed",
      dot: "green",
      title: `${claimedCount} Prize${claimedCount !== 1 ? "s" : ""} Claimed`,
      subtitle: `${fmtSTT(round.totalClaimed)} distributed`,
      blockNumber: 0n,
    });
  }

  if (round.state === RoundState.Cancelled) {
    items.push({
      key: "derived-cancelled",
      dot: "muted",
      title: "Grant Cancelled",
      subtitle:
        round.totalRefunded > 0n
          ? `${fmtSTT(round.totalRefunded)} refunded to sponsor`
          : "Refund pending",
      blockNumber: 0n,
    });
  }

  return items;
}

// ─── Dashboard aggregate stats ────────────────────────────────────────────────

export type DashboardStats = {
  // Counts
  totalTasks: number;
  totalRounds: number;
  // Milestones
  tasks: { id: number; task: Task }[];
  milestoneLocked: bigint;
  milestonePaid: bigint;
  // Grants
  rounds: { id: number; round: GrantRound }[];
  grantApplications: { id: bigint; application: GrantApplication }[];
  grantPoolTotal: bigint;
  grantPaid: bigint;
  // Pipeline
  totalEvidenceSubmitted: number;
  totalVerificationsRun: number;
  totalVerdicts: number;
  totalComplete: number;
  totalNeedsReview: number;
  totalIncomplete: number;
  totalVerificationFailed: number;
  // Combined financials
  totalLocked: bigint;
  totalPaid: bigint;
  // Loading
  isLoading: boolean;
};

export function useDashboardStats(): DashboardStats {
  const escrowDeployed = VIGILIA_ESCROW_ADDRESS !== ZERO;
  const grantDeployed = VIGILIA_GRANT_ROUND_ADDRESS !== ZERO;

  // ── All milestone IDs ────────────────────────────────────────────────────────
  const { data: nextTaskIdRaw, isLoading: loadingTaskCount } = useReadContract({
    ...escrowContract,
    functionName: "nextTaskId",
    query: { enabled: escrowDeployed },
  });
  const totalTasks = nextTaskIdRaw ? Number(nextTaskIdRaw) - 1 : 0;
  const taskIds = Array.from({ length: Math.min(totalTasks, 50) }, (_, i) => totalTasks - i).filter((id) => id >= 1);

  const { data: tasksData, isLoading: loadingTasks } = useReadContracts({
    contracts: taskIds.map((id) => ({
      ...escrowContract,
      functionName: "tasks" as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: escrowDeployed && taskIds.length > 0 },
  });

  const tasks = (tasksData ?? [])
    .map((r, i) => {
      if (r.status !== "success" || !r.result) return null;
      return { id: taskIds[i], task: parseTask(r.result as readonly unknown[]) };
    })
    .filter(Boolean) as { id: number; task: Task }[];

  // ── All grant rounds ─────────────────────────────────────────────────────────
  const { data: nextRoundIdRaw, isLoading: loadingRoundCount } = useReadContract({
    ...grantRoundContract,
    functionName: "nextRoundId",
    query: { enabled: grantDeployed },
  });
  const totalRounds = nextRoundIdRaw ? Number(nextRoundIdRaw) - 1 : 0;
  const roundIds = Array.from({ length: Math.min(totalRounds, 50) }, (_, i) => totalRounds - i).filter((id) => id >= 1);

  const { data: roundsData, isLoading: loadingRounds } = useReadContracts({
    contracts: roundIds.map((id) => ({
      ...grantRoundContract,
      functionName: "rounds" as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: grantDeployed && roundIds.length > 0 },
  });

  const rounds = (roundsData ?? [])
    .map((r, i) => {
      if (r.status !== "success" || !r.result) return null;
      return { id: roundIds[i], round: parseGrantRound(r.result as readonly unknown[]) };
    })
    .filter(Boolean) as { id: number; round: GrantRound }[];

  // ── All grant application IDs (batch) ────────────────────────────────────────
  const { data: appIdsData, isLoading: loadingAppIds } = useReadContracts({
    contracts: rounds.map(({ id }) => ({
      ...grantRoundContract,
      functionName: "getRoundApplications" as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: grantDeployed && rounds.length > 0 },
  });

  const allGrantAppIds: bigint[] = (appIdsData ?? []).flatMap((r) =>
    r.status === "success" && r.result ? (r.result as bigint[]) : []
  );

  // ── All grant applications (batch) ───────────────────────────────────────────
  const { data: grantAppsData, isLoading: loadingApps } = useReadContracts({
    contracts: allGrantAppIds.map((id) => ({
      ...grantRoundContract,
      functionName: "applications" as const,
      args: [id] as const,
    })),
    query: { enabled: grantDeployed && allGrantAppIds.length > 0 },
  });

  const grantApplications = (grantAppsData ?? [])
    .map((r, i) => {
      if (r.status !== "success" || !r.result) return null;
      return { id: allGrantAppIds[i], application: parseGrantApplication(r.result as readonly unknown[]) };
    })
    .filter(Boolean) as { id: bigint; application: GrantApplication }[];

  // ── Compute aggregate stats ──────────────────────────────────────────────────

  // Milestone financials
  const milestoneLocked = tasks.reduce((sum, { task }) =>
    [TaskState.Funded, TaskState.Submitted, TaskState.NeedsReview].includes(task.state)
      ? sum + task.fundedAmount : sum, 0n);
  const milestonePaid = tasks.reduce((sum, { task }) =>
    task.state === TaskState.Claimed ? sum + task.amount : sum, 0n);

  // Milestone pipeline counts
  const milestoneEvidenceSubmitted = tasks.filter(({ task }) => task.state >= TaskState.Submitted).length;
  const milestoneVerificationsRun = milestoneEvidenceSubmitted; // every submission triggers agent
  const milestoneComplete = tasks.filter(({ task }) =>
    [TaskState.VerifiedComplete, TaskState.Approved, TaskState.Claimed].includes(task.state)).length;
  const milestoneNeedsReview = tasks.filter(({ task }) => task.state === TaskState.NeedsReview).length;
  const milestoneIncomplete = tasks.filter(({ task }) => task.state === TaskState.Incomplete).length;
  const milestoneVerificationFailed = tasks.filter(({ task }) => task.state === TaskState.VerificationFailed).length;

  // Grant financials
  const grantPoolTotal = rounds.reduce((sum, { round }) => sum + round.prizeAmount * round.maxWinners, 0n);
  const grantPaid = rounds.reduce((sum, { round }) => sum + round.totalClaimed, 0n);

  // Grant pipeline counts (application-level)
  const grantEvidenceSubmitted = grantApplications.length;
  const grantVerificationsRun = grantApplications.filter(({ application }) =>
    application.status >= ApplicationStatus.ScreeningRequested).length;
  const grantComplete = grantApplications.filter(({ application }) =>
    application.verdict === VerificationVerdict.Complete).length;
  const grantNeedsReview = grantApplications.filter(({ application }) =>
    application.verdict === VerificationVerdict.NeedsReview).length;
  const grantIncomplete = grantApplications.filter(({ application }) =>
    application.verdict === VerificationVerdict.Incomplete).length;
  const grantVerificationFailed = grantApplications.filter(({ application }) =>
    application.status === ApplicationStatus.VerificationFailed).length;

  // Totals
  const totalEvidenceSubmitted = milestoneEvidenceSubmitted + grantEvidenceSubmitted;
  const totalVerificationsRun = milestoneVerificationsRun + grantVerificationsRun;
  const totalComplete = milestoneComplete + grantComplete;
  const totalNeedsReview = milestoneNeedsReview + grantNeedsReview;
  const totalIncomplete = milestoneIncomplete + grantIncomplete;
  const totalVerificationFailed = milestoneVerificationFailed + grantVerificationFailed;
  const totalVerdicts = totalComplete + totalNeedsReview + totalIncomplete;

  return {
    totalTasks,
    totalRounds,
    tasks,
    milestoneLocked,
    milestonePaid,
    rounds,
    grantApplications,
    grantPoolTotal,
    grantPaid,
    totalEvidenceSubmitted,
    totalVerificationsRun,
    totalVerdicts,
    totalComplete,
    totalNeedsReview,
    totalIncomplete,
    totalVerificationFailed,
    totalLocked: milestoneLocked + grantPoolTotal,
    totalPaid: milestonePaid + grantPaid,
    isLoading:
      (escrowDeployed && (loadingTaskCount || loadingTasks)) ||
      (grantDeployed && (loadingRoundCount || loadingRounds || loadingAppIds || loadingApps)),
  };
}
