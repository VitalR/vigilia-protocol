"use client";

import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle,
  CheckCircle2,
  Cpu,
  ExternalLink,
  type LucideIcon,
  Plus,
  RefreshCw,
  Upload,
  X,
  XCircle,
} from "lucide-react";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { formatEther, parseEther } from "viem";
import {
  useAccount,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";
import { NotDeployedBanner } from "@/components/not-deployed";
import { StatusPill } from "@/components/status-pill";
import { TrailIcon } from "@/components/trail-icon";
import { TxButton, TxStatus } from "@/components/tx-button";
import {
  escrowContract,
  ClaimPolicy,
  CLAIM_POLICY_LABEL,
  TaskState,
  VerificationVerdict,
  VERDICT_LABEL,
} from "@/lib/contracts";
import { useAgentFee, useIsDeployed, useTask, useTaskTrailEvents, buildDerivedTaskEvents, type Task, type Submission } from "@/lib/hooks";
import { useRole, resolveRoles } from "@/lib/role-context";
import {
  CRITERION_TYPES,
  buildMilestoneEvidence,
  explorerAddressUrl,
  explorerTxUrl,
  formatCountdown,
  formatSTT,
  formatTimestamp,
  hashEvidenceURI,
  parseEvidenceMeta,
  parseRequirementsMeta,
  truncateAddress,
  type CriterionType,
  type EvidenceMeta,
} from "@/lib/utils";
import { validateCriterionValue } from "@/lib/validation";

// Types live in lib/hooks.ts — imported via useTask

// ─── Countdown component ─────────────────────────────────────────────────────
function Countdown({ targetTs }: { targetTs: number }) {
  const [display, setDisplay] = useState(() => formatCountdown(targetTs));
  const [expired, setExpired] = useState(false);

  useEffect(() => {
    const tick = () => {
      const now = Math.floor(Date.now() / 1000);
      if (now >= targetTs) {
        setExpired(true);
        setDisplay("Window expired");
        clearInterval(timer);
      } else {
        setDisplay(formatCountdown(targetTs));
      }
    };
    const timer = setInterval(tick, 1000);
    tick();
    return () => clearInterval(timer);
  }, [targetTs]);

  return (
    <span className={expired ? "text-green" : "text-yellow font-mono"}>
      {display}
    </span>
  );
}

// ─── Action panels ────────────────────────────────────────────────────────────

async function uploadEvidenceJson(json: string): Promise<string> {
  const res = await fetch("/api/evidence", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: json,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(err.error ?? `Upload failed (${res.status})`);
  }
  const data = await res.json() as { url: string };
  return data.url;
}

function SubmitEvidencePanel({
  taskId,
  label = "Submit Evidence",
  requirementsURI,
  onSuccess,
}: {
  taskId: bigint;
  label?: string;
  requirementsURI?: string;
  onSuccess?: () => void;
}) {
  const agentFee = useAgentFee();
  const reqMeta = requirementsURI ? parseRequirementsMeta(requirementsURI) : null;

  const criteriaTypes: CriterionType[] = reqMeta?.criteria
    ? [...new Set(reqMeta.criteria.map((c) => c.type))]
    : ["github", "contract", "demo", "docs"];

  const [open, setOpen] = useState(false);
  const [values, setValues] = useState<Partial<Record<CriterionType, string>>>({});
  const [notes, setNotes] = useState("");
  const [manualUrl, setManualUrl] = useState("");
  const [uploadState, setUploadState] = useState<"idle" | "uploading" | "done" | "error">("idle");
  const [uploadedUrl, setUploadedUrl] = useState("");
  const [uploadError, setUploadError] = useState("");
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  useEffect(() => {
    if (!open) {
      setUploadState("idle");
      setUploadedUrl("");
      setUploadError("");
      setManualUrl("");
    }
  }, [open]);

  const { writeContract, data: txHash, isPending, error: txError, reset: txReset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) { onSuccess?.(); setOpen(false); }
  }, [isSuccess, onSuccess]);

  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [open]);

  const hasAnyValue = Object.values(values).some((v) => v?.trim());
  const busy = uploadState === "uploading" || isPending || confirming;

  // Field-level validation — only filled-in fields are checked
  const fieldErrors: Partial<Record<string, string>> = {};
  for (const type of criteriaTypes) {
    const val = (values as Record<string, string | undefined>)[type]?.trim() ?? "";
    if (val) {
      const result = validateCriterionValue(type, val);
      if (!result.valid) fieldErrors[type] = result.error ?? "Invalid format";
    }
  }
  const anyFieldError = Object.keys(fieldErrors).length > 0;

  function submitWithUrl(url: string) {
    txReset();
    writeContract({
      ...escrowContract,
      functionName: "submitWork",
      args: [taskId, url, hashEvidenceURI(url)],
      value: agentFee ?? 0n,
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (anyFieldError) return;

    // Manual URL fallback path
    const manualIsUrl = manualUrl.startsWith("http://") || manualUrl.startsWith("https://");
    if (!hasAnyValue && manualIsUrl) {
      submitWithUrl(manualUrl);
      return;
    }
    if (!hasAnyValue) return;

    // Auto-upload path
    setUploadState("uploading");
    setUploadError("");
    try {
      const json = buildMilestoneEvidence(
        values as Record<string, string>,
        criteriaTypes,
        notes,
      );
      const url = await uploadEvidenceJson(json);
      setUploadedUrl(url);
      setUploadState("done");
      submitWithUrl(url);
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : String(err));
      setUploadState("error");
    }
  }

  const modal = open && mounted && createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      onClick={(e) => { if (!busy && e.target === e.currentTarget) setOpen(false); }}
    >
      <div className="absolute inset-0 bg-black/60" />
      <div className="relative flex max-h-[90vh] w-full max-w-lg flex-col rounded-lg border border-border bg-surface shadow-xl">
        <div className="flex items-center justify-between border-b border-border px-5 py-4 shrink-0">
          <h2 className="text-sm font-semibold text-text">{label}</h2>
          <button type="button" onClick={() => setOpen(false)} disabled={busy}
            className="text-muted hover:text-text transition-colors disabled:opacity-40">
            <X size={16} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto space-y-3 p-5">
          {criteriaTypes.map((type) => {
            const typeDef = CRITERION_TYPES.find((t) => t.value === type);
            if (!typeDef) return null;
            const matchingCriteria = reqMeta?.criteria.filter((c) => c.type === type) ?? [];
            const err = fieldErrors[type];
            return (
              <div key={type}>
                <label>
                  {typeDef.label}
                  {matchingCriteria.some((c) => c.label?.trim()) && (
                    <span className="ml-1 normal-case font-normal">
                      {matchingCriteria.map((c) => c.label).filter((l) => l?.trim()).join(", ")}
                    </span>
                  )}
                </label>
                <input
                  value={values[type as CriterionType] ?? ""}
                  onChange={(e) => setValues((v) => ({ ...v, [type]: e.target.value }))}
                  placeholder={typeDef.placeholder}
                  disabled={busy}
                  className={err ? "border-red/50 focus:border-red/70" : ""}
                />
                {err && <p className="mt-0.5 text-[11px] text-red">{err}</p>}
              </div>
            );
          })}
          <div>
            <label>Notes</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Brief summary of what was delivered."
              rows={2}
              className="resize-none"
              disabled={busy}
            />
          </div>

          {agentFee != null && agentFee > 0n && (
            <div className="flex items-center justify-between rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-muted">
              <span>Agent verification fee</span>
              <span className="font-mono font-semibold text-yellow">{formatEther(agentFee)} STT</span>
            </div>
          )}

          {uploadState === "uploading" && (
            <div className="flex items-center gap-2 rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-yellow">
              <RefreshCw size={11} className="animate-spin shrink-0" />
              Uploading evidence to GitHub Gist…
            </div>
          )}
          {uploadState === "done" && uploadedUrl && (
            <div className="rounded border border-green/20 bg-green/5 px-3 py-2 text-xs text-green">
              Hosted at{" "}
              <a href={uploadedUrl} target="_blank" rel="noopener noreferrer" className="underline break-all">
                {uploadedUrl}
              </a>
            </div>
          )}
          {uploadState === "error" && (
            <div className="space-y-2 rounded border border-red/20 bg-red/5 px-3 py-2 text-xs text-red">
              <p>Auto-upload failed: {uploadError}</p>
              <p className="text-muted">Paste a public URL to your evidence JSON manually:</p>
              <input
                value={manualUrl}
                onChange={(e) => setManualUrl(e.target.value)}
                placeholder="https://gist.githubusercontent.com/..."
                className="!text-text"
                disabled={busy}
              />
            </div>
          )}

          <TxButton
            type="submit"
            loading={isPending}
            confirming={confirming}
            className="w-full"
            disabled={anyFieldError || (!hasAnyValue && !(manualUrl.startsWith("http"))) || busy}
          >
            {uploadState === "uploading"
              ? "Uploading evidence…"
              : confirming ? "Confirming…"
              : isPending ? "Sign transaction…"
              : label}
          </TxButton>
          <TxStatus error={txError} txHash={txHash} />
        </form>
      </div>
    </div>,
    document.body
  );

  return (
    <>
      <TxButton onClick={() => setOpen(true)} className="w-full">
        {label}
      </TxButton>
      {modal}
    </>
  );
}

function RaiseDisputePanel({ taskId, onSuccess }: { taskId: bigint; onSuccess?: () => void }) {
  const [reasonURI, setReasonURI] = useState("");
  const { writeContract, data: txHash, isPending, error, reset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) onSuccess?.();
  }, [isSuccess, onSuccess]);

  return (
    <div className="rounded-lg border border-red/20 bg-red/5 p-4">
      <h4 className="mb-3 text-sm font-semibold text-red">Raise Dispute</h4>
      <div className="mb-3">
        <label>Reason URI (optional)</label>
        <input
          value={reasonURI}
          onChange={(e) => setReasonURI(e.target.value)}
          placeholder="https://... (link to dispute evidence)"
        />
      </div>
      <TxButton
        variant="danger"
        onClick={() => {
          reset();
          writeContract({
            ...escrowContract,
            functionName: "raiseDispute",
            args: [taskId, reasonURI],
          });
        }}
        loading={isPending}
        confirming={confirming}
        className="w-full"
      >
        {confirming ? "Confirming…" : "Raise Dispute"}
      </TxButton>
      <TxStatus error={error} txHash={txHash} />
    </div>
  );
}

// ─── Main detail component ────────────────────────────────────────────────────
export function MilestoneDetail({ taskId }: { taskId: bigint }) {
  const { address } = useAccount();
  const isDeployed = useIsDeployed();
  const { role } = useRole();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  // ── Shared hook: task + submission ──────────────────────────
  const { task, activeSubmission, claimPolicy, isLoading: taskLoading, refetch } = useTask(taskId);
  const agentFee = useAgentFee();

  const { data: pendingBalance, refetch: refetchPending } = useReadContract({
    ...escrowContract,
    functionName: "pendingWithdrawals",
    args: [address ?? "0x0000000000000000000000000000000000000000"],
    query: { enabled: isDeployed && !!address },
  });

  // ── Role detection (respects demo role switcher) ────────────
  const { isClient, isContractor, isResolver } = task
    ? resolveRoles(role, address, task.client, task.contractor, task.resolver)
    : { isClient: false, isContractor: false, isResolver: false };
  const isParticipant = isClient || isContractor || isResolver;

  const allowMultiple = task
    ? (parseRequirementsMeta(task.requirementsURI)?.allowMultiple ?? true)
    : true;

  const refresh = useCallback(() => refetch(), [refetch]);

  // Auto-poll every 5 s while agent verification is in progress
  const refreshRef = useRef(refresh);
  useEffect(() => { refreshRef.current = refresh; });
  useEffect(() => {
    if (task?.state !== TaskState.Submitted) return;
    const id = setInterval(() => refreshRef.current(), 5000);
    return () => clearInterval(id);
  }, [task?.state]);

  // ── Verification timeout state ───────────────────────────────
  const verificationTimeoutAt =
    activeSubmission?.submittedAt && task?.verificationTimeout
      ? activeSubmission.submittedAt + task.verificationTimeout
      : 0;
  const verificationTimedOut =
    verificationTimeoutAt > 0 &&
    Math.floor(Date.now() / 1000) > verificationTimeoutAt;

  // ── Review window state ─────────────────────────────────────
  const reviewWindowExpiry =
    activeSubmission?.verifiedAt && task?.reviewWindow
      ? activeSubmission.verifiedAt + task.reviewWindow
      : 0;
  const reviewWindowActive =
    task?.state === TaskState.VerifiedComplete &&
    reviewWindowExpiry > Math.floor(Date.now() / 1000);

  // ── Write hooks: approveTask ────────────────────────────────
  const {
    writeContract: approveWrite,
    data: approveTxHash,
    isPending: approvePending,
    error: approveError,
    reset: approveReset,
  } = useWriteContract();
  const { isLoading: approveConfirming, isSuccess: approveSuccess } =
    useWaitForTransactionReceipt({ hash: approveTxHash });
  useEffect(() => { if (approveSuccess) refresh(); }, [approveSuccess, refresh]);

  // ── Write hooks: claim ──────────────────────────────────────
  const {
    writeContract: claimWrite,
    data: claimTxHash,
    isPending: claimPending,
    error: claimError,
    reset: claimReset,
  } = useWriteContract();
  const { isLoading: claimConfirming, isSuccess: claimSuccess } =
    useWaitForTransactionReceipt({ hash: claimTxHash });
  useEffect(() => { if (claimSuccess) refresh(); }, [claimSuccess, refresh]);

  // ── Write hooks: fundTask ───────────────────────────────────
  const {
    writeContract: fundWrite,
    data: fundTxHash,
    isPending: fundPending,
    error: fundError,
    reset: fundReset,
  } = useWriteContract();
  const { isLoading: fundConfirming, isSuccess: fundSuccess } =
    useWaitForTransactionReceipt({ hash: fundTxHash });
  useEffect(() => { if (fundSuccess) refresh(); }, [fundSuccess, refresh]);

  // ── Write hooks: cancel ─────────────────────────────────────
  const {
    writeContract: cancelWrite,
    data: cancelTxHash,
    isPending: cancelPending,
    error: cancelError,
    reset: cancelReset,
  } = useWriteContract();
  const { isLoading: cancelConfirming, isSuccess: cancelSuccess } =
    useWaitForTransactionReceipt({ hash: cancelTxHash });
  useEffect(() => { if (cancelSuccess) refresh(); }, [cancelSuccess, refresh]);

  // ── Write hooks: markVerificationTimedOut ──────────────────
  const {
    writeContract: timeoutWrite,
    data: timeoutTxHash,
    isPending: timeoutPending,
    error: timeoutError,
    reset: timeoutReset,
  } = useWriteContract();
  const { isLoading: timeoutConfirming, isSuccess: timeoutSuccess } =
    useWaitForTransactionReceipt({ hash: timeoutTxHash });
  useEffect(() => { if (timeoutSuccess) refresh(); }, [timeoutSuccess, refresh]);

  // ── Write hooks: retryVerification ─────────────────────────
  const {
    writeContract: retryWrite,
    data: retryTxHash,
    isPending: retryPending,
    error: retryError,
    reset: retryReset,
  } = useWriteContract();
  const { isLoading: retryConfirming, isSuccess: retrySuccess } =
    useWaitForTransactionReceipt({ hash: retryTxHash });
  useEffect(() => { if (retrySuccess) refresh(); }, [retrySuccess, refresh]);

  // ── Write hooks: resolveDispute ─────────────────────────────
  const {
    writeContract: resolveWrite,
    data: resolveTxHash,
    isPending: resolvePending,
    error: resolveError,
    reset: resolveReset,
  } = useWriteContract();
  const { isLoading: resolveConfirming, isSuccess: resolveSuccess } =
    useWaitForTransactionReceipt({ hash: resolveTxHash });
  useEffect(() => { if (resolveSuccess) refresh(); }, [resolveSuccess, refresh]);

  // ── Write hooks: withdrawPending ────────────────────────────
  const {
    writeContract: withdrawWrite,
    data: withdrawTxHash,
    isPending: withdrawPending,
    error: withdrawError,
    reset: withdrawReset,
  } = useWriteContract();
  const { isLoading: withdrawConfirming, isSuccess: withdrawSuccess } =
    useWaitForTransactionReceipt({ hash: withdrawTxHash });
  useEffect(() => { if (withdrawSuccess) { refresh(); refetchPending(); } }, [withdrawSuccess, refresh, refetchPending]);

  // ── Dispute resolution form state ───────────────────────────
  const [clientRefundPct, setClientRefundPct] = useState("50");
  const [resolutionURI, setResolutionURI] = useState("");

  // ── Render ──────────────────────────────────────────────────
  if (!isDeployed) return <NotDeployedBanner />;

  if (taskLoading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-10">
        <div className="space-y-3">
          <div className="h-8 w-48 animate-pulse rounded bg-surface-2" />
          <div className="h-64 animate-pulse rounded-xl bg-surface" />
        </div>
      </div>
    );
  }

  if (!task || task.state === TaskState.None) {
    return (
      <div className="flex h-96 flex-col items-center justify-center gap-3 text-muted">
        <XCircle size={32} />
        <p>Milestone #{taskId.toString()} not found</p>
        <Link href="/milestones" className="text-sm text-accent hover:underline">
          ← Back to milestones
        </Link>
      </div>
    );
  }

  const clientRefundWei = task.fundedAmount
    ? (task.fundedAmount * BigInt(Math.round(Number(clientRefundPct)))) / 100n
    : 0n;
  const contractorAwardWei = task.fundedAmount ? task.fundedAmount - clientRefundWei : 0n;

  return (
    <div className="mx-auto max-w-4xl px-4 py-10 fade-in">
      {/* ── Header ────────────────────────────────────────────── */}
      <div className="mb-6">
        <Link
          href="/milestones"
          className="mb-4 inline-flex items-center gap-1 text-sm text-muted hover:text-text transition-colors"
        >
          <ArrowLeft size={14} /> Back
        </Link>
        {(() => {
          const reqMeta = parseRequirementsMeta(task.requirementsURI);
          return (
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="flex items-center gap-3">
                  <h1 className="font-mono text-2xl font-bold text-text">
                    #{taskId.toString()}
                  </h1>
                  <StatusPill state={task.state} />
                </div>
                {reqMeta ? (
                  <p className="mt-1 text-base font-medium text-text">{reqMeta.title}</p>
                ) : task.requirementsURI ? (
                  <a
                    href={task.requirementsURI}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-1 inline-flex items-center gap-1 text-sm text-muted hover:text-accent transition-colors"
                  >
                    <ExternalLink size={12} />
                    {task.requirementsURI.length > 60
                      ? task.requirementsURI.slice(0, 60) + "…"
                      : task.requirementsURI}
                  </a>
                ) : null}
              </div>
              {(() => {
                const ACTIVE_STATES = [
                  TaskState.Funded,
                  TaskState.Submitted,
                  TaskState.VerifiedComplete,
                  TaskState.NeedsReview,
                  TaskState.Incomplete,
                  TaskState.VerificationFailed,
                  TaskState.Approved,
                  TaskState.Disputed,
                ];
                const displayAmount = ACTIVE_STATES.includes(task.state)
                  ? task.fundedAmount
                  : task.amount;
                const amountLabel =
                  task.state === TaskState.Created
                    ? "requested"
                    : task.state === TaskState.Claimed
                    ? "paid out"
                    : task.state === TaskState.Cancelled || task.state === TaskState.Resolved
                    ? "agreed value"
                    : "in escrow";
                return (
                  <div className="text-right">
                    <div className="font-mono text-2xl font-bold text-text">
                      {formatSTT(displayAmount)}
                    </div>
                    <div className="text-xs text-muted">{amountLabel}</div>
                  </div>
                );
              })()}
            </div>
          );
        })()}
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        {/* ── Left: Info + Timeline ─────────────────────────────── */}
        <div className="space-y-4 lg:col-span-2">
          {/* Parties */}
          <div className="rounded-xl border border-border bg-surface p-5">
            <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">
              Parties
            </h3>
            <div className="space-y-2">
              {[
                { label: "Client", addr: task.client, highlight: isClient },
                { label: "Contractor", addr: task.contractor, highlight: isContractor },
                { label: "Resolver", addr: task.resolver, highlight: isResolver },
              ].map(({ label, addr, highlight }) => (
                <div key={label} className="flex items-center justify-between">
                  <span className="text-xs text-muted">{label}</span>
                  <div className="flex items-center gap-2">
                    {highlight && (
                      <span className="rounded border border-accent/30 bg-accent/10 px-1.5 py-0.5 text-[10px] font-bold text-accent">
                        YOU
                      </span>
                    )}
                    <a
                      href={explorerAddressUrl(addr)}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="font-mono text-xs text-muted hover:text-text transition-colors"
                    >
                      {truncateAddress(addr)}
                    </a>
                  </div>
                </div>
              ))}
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted">Claim policy</span>
                <span className="text-xs text-text">{CLAIM_POLICY_LABEL[claimPolicy]}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted">Review window</span>
                <span className="font-mono text-xs text-text">
                  {task.reviewWindow >= 3600
                    ? `${Math.round(task.reviewWindow / 3600)}h`
                    : `${task.reviewWindow}s`}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted">Submissions</span>
                <span className="font-mono text-xs text-text">
                  {task.submissionCount.toString()}
                </span>
              </div>
            </div>
          </div>

          {/* Requirements detail */}
          {(() => {
            const reqMeta = parseRequirementsMeta(task.requirementsURI);
            if (!reqMeta) return null;
            return (
              <div className="rounded-xl border border-border bg-surface p-5">
                <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">
                  Requirements
                </h3>
                {reqMeta.description && (
                  <p className="mb-3 text-sm text-muted">{reqMeta.description}</p>
                )}
                {reqMeta.refs && reqMeta.refs.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {reqMeta.refs.map((r, i) => (
                      <a
                        key={i}
                        href={r}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 text-xs text-muted hover:text-accent transition-colors"
                      >
                        <ExternalLink size={11} />
                        {r.replace(/^https?:\/\//, "").split("/").slice(0, 3).join("/")}
                      </a>
                    ))}
                  </div>
                )}
              </div>
            );
          })()}

          {/* Active submission */}
          {activeSubmission && task.activeSubmissionId > 0n && (
            <div className="rounded-xl border border-border bg-surface p-5">
              <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">
                Latest Submission #{task.activeSubmissionId.toString()}
              </h3>
              <div className="space-y-2">
                {(() => {
                  const evMeta = parseEvidenceMeta(activeSubmission.evidenceURI);
                  if (evMeta) {
                    const links: { label: string; value: string; isAddress?: boolean }[] = [
                      ...(evMeta.github ? [{ label: "GitHub PR / repo", value: evMeta.github }] : []),
                      ...(evMeta.contract ? [{ label: "Deployed contract", value: evMeta.contract, isAddress: true }] : []),
                      ...(evMeta.demo ? [{ label: "Live demo", value: evMeta.demo }] : []),
                      ...(evMeta.docs ? [{ label: "Docs / test report", value: evMeta.docs }] : []),
                    ];
                    return (
                      <div className="space-y-2">
                        {links.map(({ label, value, isAddress }) => (
                          <div key={label}>
                            <div className="mb-0.5 text-xs text-muted">{label}</div>
                            <a
                              href={isAddress ? explorerAddressUrl(value) : value}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center gap-1 text-sm text-accent hover:underline break-all"
                            >
                              <ExternalLink size={11} className="shrink-0" />
                              {isAddress ? value : value.replace(/^https?:\/\//, "")}
                            </a>
                          </div>
                        ))}
                        {evMeta.notes && (
                          <div>
                            <div className="mb-0.5 text-xs text-muted">Notes</div>
                            <p className="text-sm text-text">{evMeta.notes}</p>
                          </div>
                        )}
                      </div>
                    );
                  }
                  // fallback: plain URI
                  return (
                    <div>
                      <div className="mb-1 text-xs text-muted">Evidence URI</div>
                      <a
                        href={activeSubmission.evidenceURI}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 break-all text-sm text-accent hover:underline"
                      >
                        <ExternalLink size={11} className="shrink-0" />
                        {activeSubmission.evidenceURI}
                      </a>
                    </div>
                  );
                })()}
                <div className="flex items-center justify-between">
                  <span className="text-xs text-muted">Submitted</span>
                  <span className="text-xs text-text">
                    {formatTimestamp(activeSubmission.submittedAt)}
                  </span>
                </div>
                {activeSubmission.verifiedAt > 0 && (
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-muted">Verified</span>
                    <span className="text-xs text-text">
                      {formatTimestamp(activeSubmission.verifiedAt)}
                    </span>
                  </div>
                )}
                {activeSubmission.verdict !== VerificationVerdict.Unknown && (
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-muted">Verdict</span>
                    <span
                      className={`font-mono text-xs font-bold ${
                        activeSubmission.verdict === VerificationVerdict.Complete
                          ? "text-green"
                          : activeSubmission.verdict === VerificationVerdict.NeedsReview
                          ? "text-yellow"
                          : "text-red"
                      }`}
                    >
                      {VERDICT_LABEL[activeSubmission.verdict]}
                    </span>
                  </div>
                )}
                <div className="flex items-center justify-between">
                  <span className="text-xs text-muted">Evidence hash</span>
                  <span className="font-mono text-[10px] text-subtle">
                    {activeSubmission.evidenceHash.slice(0, 18)}…
                  </span>
                </div>
              </div>

              {/* Review window countdown */}
              {task.state === TaskState.VerifiedComplete && reviewWindowExpiry > 0 && (
                <div className="mt-4 rounded-lg border border-yellow/20 bg-yellow/5 px-3 py-2">
                  <div className="text-xs text-muted">Review window</div>
                  <Countdown targetTs={reviewWindowExpiry} />
                </div>
              )}
            </div>
          )}

          {/* State: Submitted — verifying spinner */}
          {task.state === TaskState.Submitted && (
            <div className="rounded-xl border border-yellow/20 bg-yellow/5 p-5 glow-yellow">
              <div className="flex items-center gap-3">
                <div className="h-8 w-8 animate-spin rounded-full border-2 border-yellow/30 border-t-yellow" />
                <div>
                  <div className="font-semibold text-text">Agent verifying…</div>
                  <div className="text-xs text-muted">
                    Somnia agent is checking evidence against requirements
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* State: Claimed / Done ───────────────────────────── */}
          {task.state === TaskState.Claimed && (
            <div className="rounded-xl border border-green/30 bg-green/5 p-6 text-center glow-green">
              <CheckCircle size={36} className="mx-auto mb-3 text-green" />
              <div className="text-lg font-bold text-text">Milestone complete</div>
              <div className="mt-1 text-sm text-muted">
                {formatSTT(task.amount)} paid to{" "}
                <a
                  href={explorerAddressUrl(task.contractor)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-mono text-green hover:underline"
                >
                  {truncateAddress(task.contractor)}
                </a>
              </div>
            </div>
          )}

          {task.state === TaskState.Cancelled && (
            <div className="rounded-xl border border-border bg-surface p-6 text-center">
              <XCircle size={36} className="mx-auto mb-3 text-muted" />
              <div className="text-lg font-bold text-text">Milestone cancelled</div>
              <div className="mt-1 text-sm text-muted">
                {pendingBalance != null && pendingBalance > 0n
                  ? "Refund available — withdraw below"
                  : task.amount > 0n
                  ? "Refunded"
                  : "No funds were deposited"}
              </div>
            </div>
          )}

          {task.state === TaskState.Resolved && (
            <div className="rounded-xl border border-border bg-surface p-6">
              <CheckCircle size={24} className="mb-3 text-muted" />
              <div className="font-semibold text-text">Dispute resolved</div>
              <div className="mt-1 text-sm text-muted">
                Funds allocated. Parties can withdraw their credits.
              </div>
            </div>
          )}
        </div>

        {/* ── Right: Actions ────────────────────────────────────── */}
        <div className="space-y-3">
          {/* Viewer note — not a participant */}
          {mounted && !isParticipant && !address && (
            <div className="rounded-xl border border-border bg-surface p-4 text-center text-xs text-muted">
              Connect as client or contractor to take action
            </div>
          )}
          {mounted && !isParticipant && !!address && ![TaskState.Claimed, TaskState.Cancelled, TaskState.Resolved].includes(task.state) && (
            <div className="rounded-xl border border-border bg-surface p-4 text-center text-xs text-muted">
              You are not a participant in this milestone
            </div>
          )}
          {/* CREATED → client funds */}
          {task.state === TaskState.Created && isClient && (
            <div className="rounded-xl border border-border bg-surface p-5">
              <h3 className="mb-1 text-xs font-semibold uppercase tracking-wider text-muted">
                Fund Milestone
              </h3>
              <p className="mb-4 text-xs text-muted">
                Deposit {formatSTT(task.amount)} to activate this milestone and allow the contractor to submit work.
              </p>
              <TxButton
                onClick={() => {
                  fundReset();
                  fundWrite({
                    ...escrowContract,
                    functionName: "fundTask",
                    args: [taskId],
                    value: task.amount,
                  });
                }}
                loading={fundPending}
                confirming={fundConfirming}
                className="w-full"
              >
                {fundConfirming ? "Confirming…" : `Fund ${formatSTT(task.amount)}`}
              </TxButton>
              <TxStatus error={fundError} txHash={fundTxHash} />
              {fundSuccess && (
                <div className="mt-2 rounded border border-green/30 bg-green/10 px-3 py-2 text-xs text-green">
                  Funded. Contractor can now submit work.
                </div>
              )}
              <div className="mt-3 border-t border-border pt-3">
                <TxButton
                  variant="danger"
                  onClick={() => {
                    cancelReset();
                    cancelWrite({ ...escrowContract, functionName: "cancelTask", args: [taskId] });
                  }}
                  loading={cancelPending}
                  confirming={cancelConfirming}
                  className="w-full"
                >
                  Cancel Milestone
                </TxButton>
                <TxStatus error={cancelError} txHash={cancelTxHash} />
              </div>
            </div>
          )}

          {task.state === TaskState.Created && isContractor && (
            <div className="rounded-xl border border-border bg-surface p-4 text-center text-xs text-muted">
              Awaiting client to fund {formatSTT(task.amount)}
            </div>
          )}

          {/* FUNDED → contractor submits */}
          {task.state === TaskState.Funded && isContractor && (
            <div className="rounded-xl border border-border bg-surface p-5">
              <SubmitEvidencePanel taskId={taskId} requirementsURI={task.requirementsURI} onSuccess={refresh} />
            </div>
          )}

          {task.state === TaskState.Funded && isClient && (
            <div className="rounded-xl border border-border bg-surface p-5">
              <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">
                Client Actions
              </h3>
              <TxButton
                variant="danger"
                onClick={() => {
                  cancelReset();
                  cancelWrite({ ...escrowContract, functionName: "cancelTask", args: [taskId] });
                }}
                loading={cancelPending}
                confirming={cancelConfirming}
                className="w-full"
              >
                Cancel & Refund
              </TxButton>
              <TxStatus error={cancelError} txHash={cancelTxHash} />
            </div>
          )}

          {/* SUBMITTED → waiting / timeout */}
          {task.state === TaskState.Submitted && (isClient || isContractor) && (
            <div className="rounded-xl border border-yellow/20 bg-surface p-5">
              <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted">
                Awaiting Verdict
              </h3>
              {!verificationTimedOut && (
                <p className="text-xs text-muted">
                  Somnia agent is verifying submitted evidence. No action required.
                </p>
              )}
              {verificationTimedOut && (
                <div className="space-y-3">
                  <p className="text-xs text-yellow">
                    Verification timeout elapsed. Either party can mark this as timed out.
                  </p>
                  <TxButton
                    variant="secondary"
                    onClick={() => {
                      timeoutReset();
                      timeoutWrite({ ...escrowContract, functionName: "markVerificationTimedOut", args: [taskId] });
                    }}
                    loading={timeoutPending}
                    confirming={timeoutConfirming}
                    className="w-full"
                  >
                    Mark Timed Out
                  </TxButton>
                  <TxStatus error={timeoutError} txHash={timeoutTxHash} />
                </div>
              )}
            </div>
          )}

          {/* VERIFIED_COMPLETE → contractor claims / client approves */}
          {task.state === TaskState.VerifiedComplete && (
            <div className="rounded-xl border border-green/20 bg-surface p-5 glow-green">
              <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">
                Agent: Complete
              </h3>
              {isContractor && claimPolicy === ClaimPolicy.ClientApprovalOnly && (
                <p className="text-xs text-muted">Awaiting client approval to release funds.</p>
              )}
              {isContractor && claimPolicy !== ClaimPolicy.ClientApprovalOnly && (
                <div className="space-y-2">
                  <TxButton
                    onClick={() => {
                      claimReset();
                      claimWrite({ ...escrowContract, functionName: "claim", args: [taskId] });
                    }}
                    loading={claimPending}
                    confirming={claimConfirming}
                    disabled={claimPolicy === ClaimPolicy.ReviewWindowAutoClaim && reviewWindowActive}
                    className="w-full"
                  >
                    Claim {formatSTT(task.fundedAmount)}
                  </TxButton>
                  {claimPolicy === ClaimPolicy.ReviewWindowAutoClaim && reviewWindowActive && (
                    <p className="text-xs text-muted text-center">
                      Available after review window · <Countdown targetTs={reviewWindowExpiry} />
                    </p>
                  )}
                  <TxStatus error={claimError} txHash={claimTxHash} />
                </div>
              )}
              {isClient && (
                <div className="space-y-2">
                  <TxButton
                    onClick={() => {
                      approveReset();
                      approveWrite({ ...escrowContract, functionName: "approveTask", args: [taskId] });
                    }}
                    loading={approvePending}
                    confirming={approveConfirming}
                    className="w-full"
                  >
                    {claimPolicy === ClaimPolicy.ClientApprovalOnly ? "Approve & Release" : "Approve Early"}
                  </TxButton>
                  <TxStatus error={approveError} txHash={approveTxHash} />
                  <RaiseDisputePanel taskId={taskId} onSuccess={refresh} />
                </div>
              )}
            </div>
          )}

          {/* NEEDS_REVIEW → client decides */}
          {task.state === TaskState.NeedsReview && (
            <div className="rounded-xl border border-yellow/20 bg-surface p-5 glow-yellow">
              <div className="mb-3 flex items-center gap-2">
                <AlertTriangle size={16} className="text-yellow" />
                <h3 className="text-sm font-semibold text-yellow">Agent: Needs Review</h3>
              </div>
              <p className="mb-4 text-xs text-muted">
                Agent found ambiguity. Human decision required.
              </p>
              {isClient && (
                <div className="space-y-2">
                  <TxButton
                    onClick={() => {
                      approveReset();
                      approveWrite({ ...escrowContract, functionName: "approveTask", args: [taskId] });
                    }}
                    loading={approvePending}
                    confirming={approveConfirming}
                    className="w-full"
                  >
                    Approve & Release
                  </TxButton>
                  <TxStatus error={approveError} txHash={approveTxHash} />
                  <RaiseDisputePanel taskId={taskId} onSuccess={refresh} />
                </div>
              )}
              {isContractor && allowMultiple && (
                <SubmitEvidencePanel
                  taskId={taskId}
                  label="Resubmit Evidence"
                  requirementsURI={task.requirementsURI}
                  onSuccess={refresh}
                />
              )}
              {isContractor && !allowMultiple && (
                <p className="text-xs text-muted">Awaiting client decision.</p>
              )}
            </div>
          )}

          {/* INCOMPLETE → contractor resubmits */}
          {task.state === TaskState.Incomplete && (
            <div className="rounded-xl border border-red/20 bg-surface p-5 glow-red">
              <div className="mb-3 flex items-center gap-2">
                <XCircle size={16} className="text-red" />
                <h3 className="text-sm font-semibold text-red">Agent: Incomplete</h3>
              </div>
              <p className="mb-4 text-xs text-muted">
                Evidence was insufficient. Revise and resubmit.
              </p>
              {isContractor && allowMultiple && (
                <SubmitEvidencePanel
                  taskId={taskId}
                  label="Resubmit Evidence"
                  requirementsURI={task.requirementsURI}
                  onSuccess={refresh}
                />
              )}
              {isContractor && !allowMultiple && (
                <p className="text-xs text-muted">
                  This milestone allows only one submission. Resubmission is disabled.
                </p>
              )}
              {isClient && (
                <div className="space-y-2">
                  <TxButton
                    variant="secondary"
                    onClick={() => {
                      approveReset();
                      approveWrite({ ...escrowContract, functionName: "approveTask", args: [taskId] });
                    }}
                    loading={approvePending}
                    confirming={approveConfirming}
                    className="w-full"
                  >
                    Override & Approve
                  </TxButton>
                  <TxStatus error={approveError} txHash={approveTxHash} />
                  <TxButton
                    variant="danger"
                    onClick={() => {
                      cancelReset();
                      cancelWrite({ ...escrowContract, functionName: "cancelTask", args: [taskId] });
                    }}
                    loading={cancelPending}
                    confirming={cancelConfirming}
                    className="w-full"
                  >
                    Cancel & Refund
                  </TxButton>
                  <TxStatus error={cancelError} txHash={cancelTxHash} />
                </div>
              )}
            </div>
          )}

          {/* VERIFICATION_FAILED → retry */}
          {task.state === TaskState.VerificationFailed && (
            <div className="rounded-xl border border-red/20 bg-surface p-5">
              <div className="mb-3 flex items-center gap-2">
                <RefreshCw size={16} className="text-red" />
                <h3 className="text-sm font-semibold text-text">Verification Failed</h3>
              </div>
              <p className="mb-3 text-xs text-muted">
                Agent infrastructure failure. Retry without changing evidence.
              </p>
              {agentFee != null && agentFee > 0n && (
                <div className="mb-4 flex items-center justify-between rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-muted">
                  <span>New verification deposit required</span>
                  <span className="font-mono font-semibold text-yellow">{formatEther(agentFee)} STT</span>
                </div>
              )}
              {(isClient || isContractor) && (
                <div className="space-y-2">
                  <TxButton
                    variant="secondary"
                    onClick={() => {
                      retryReset();
                      retryWrite({ ...escrowContract, functionName: "retryVerification", args: [taskId], value: agentFee ?? 0n });
                    }}
                    loading={retryPending}
                    confirming={retryConfirming}
                    className="w-full"
                  >
                    Retry Verification
                  </TxButton>
                  <TxStatus error={retryError} txHash={retryTxHash} />
                  {isClient && (
                    <TxButton
                      onClick={() => {
                        approveReset();
                        approveWrite({ ...escrowContract, functionName: "approveTask", args: [taskId] });
                      }}
                      loading={approvePending}
                      confirming={approveConfirming}
                      className="w-full"
                    >
                      Override & Approve
                    </TxButton>
                  )}
                </div>
              )}
            </div>
          )}

          {/* APPROVED → contractor claims */}
          {task.state === TaskState.Approved && isContractor && (
            <div className="rounded-xl border border-green/20 bg-surface p-5 glow-green">
              <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">
                Approved
              </h3>
              <TxButton
                onClick={() => {
                  claimReset();
                  claimWrite({ ...escrowContract, functionName: "claim", args: [taskId] });
                }}
                loading={claimPending}
                confirming={claimConfirming}
                className="w-full"
              >
                Claim {formatSTT(task.fundedAmount)}
              </TxButton>
              <TxStatus error={claimError} txHash={claimTxHash} />
            </div>
          )}

          {/* DISPUTED → resolver resolves */}
          {task.state === TaskState.Disputed && (
            <div className="rounded-xl border border-red/20 bg-surface p-5 glow-red">
              <div className="mb-3 flex items-center gap-2">
                <AlertTriangle size={16} className="text-red" />
                <h3 className="text-sm font-semibold text-red">Dispute in Progress</h3>
              </div>
              {isResolver ? (
                <div className="space-y-3">
                  <p className="text-xs text-muted">
                    Allocate {formatSTT(task.fundedAmount)} between parties.
                  </p>
                  <div>
                    <label>Client refund %</label>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={clientRefundPct}
                      onChange={(e) => setClientRefundPct(e.target.value)}
                      className="w-full cursor-pointer bg-transparent"
                    />
                    <div className="mt-1 flex justify-between text-xs text-muted">
                      <span>
                        Client: {formatEther(clientRefundWei)} STT ({clientRefundPct}%)
                      </span>
                      <span>
                        Contractor: {formatEther(contractorAwardWei)} STT ({100 - Number(clientRefundPct)}%)
                      </span>
                    </div>
                  </div>
                  <div>
                    <label>Resolution URI (optional)</label>
                    <input
                      value={resolutionURI}
                      onChange={(e) => setResolutionURI(e.target.value)}
                      placeholder="https://... rationale"
                    />
                  </div>
                  <TxButton
                    variant="danger"
                    onClick={() => {
                      resolveReset();
                      resolveWrite({
                        ...escrowContract,
                        functionName: "resolveDispute",
                        args: [taskId, clientRefundWei, contractorAwardWei, resolutionURI],
                      });
                    }}
                    loading={resolvePending}
                    confirming={resolveConfirming}
                    className="w-full"
                  >
                    Resolve Dispute
                  </TxButton>
                  <TxStatus error={resolveError} txHash={resolveTxHash} />
                </div>
              ) : (
                <p className="text-xs text-muted">
                  Awaiting resolver ({truncateAddress(task.resolver)}) decision.
                </p>
              )}
            </div>
          )}

          {/* RESOLVED / CANCELLED / pending withdrawal */}
          {(task.state === TaskState.Resolved || task.state === TaskState.Claimed || task.state === TaskState.Cancelled) &&
            pendingBalance != null &&
            pendingBalance > 0n && (
              <div className="rounded-xl border border-green/20 bg-surface p-5">
                <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted">
                  Pending Withdrawal
                </h3>
                <p className="mb-3 text-sm font-semibold text-green">
                  {formatSTT(pendingBalance)} available
                </p>
                <TxButton
                  onClick={() => {
                    withdrawReset();
                    withdrawWrite({ ...escrowContract, functionName: "withdrawPending" });
                  }}
                  loading={withdrawPending}
                  confirming={withdrawConfirming}
                  className="w-full"
                >
                  Withdraw
                </TxButton>
                <TxStatus error={withdrawError} txHash={withdrawTxHash} />
              </div>
            )}

          {/* Dispute option for active milestones not yet disputed */}
          {[
            TaskState.Funded,
            TaskState.Submitted,
            TaskState.VerifiedComplete,
            TaskState.Incomplete,
            TaskState.VerificationFailed,
            TaskState.Approved,
          ].includes(task.state) &&
            (isClient || isContractor) &&
            task.state !== TaskState.Funded &&
            task.state !== TaskState.Incomplete &&
            !(isContractor && task.state === TaskState.Submitted) && (
              <div className="pt-1">
                <RaiseDisputePanel taskId={taskId} onSuccess={refresh} />
              </div>
            )}
        </div>
      </div>

      {/* ── Agent Pipeline (TODO: re-enable) ─────────────────── */}
      {/* <AgentPipeline task={task} activeSubmission={activeSubmission} /> */}

      {/* ── Trail ─────────────────────────────────────────────── */}
      <MilestoneTrail taskId={taskId} task={task} activeSubmission={activeSubmission} />
    </div>
  );
}

// ─── Agent Pipeline panel ────────────────────────────────────────────────────

function AgentPipeline({
  task,
  activeSubmission,
}: {
  task: Task;
  activeSubmission: Submission | null;
}) {
  const isVerifying = task.state === TaskState.Submitted;
  const failed = task.state === TaskState.VerificationFailed;
  const hasVerdict =
    activeSubmission != null &&
    activeSubmission.verdict !== VerificationVerdict.Unknown;

  if (task.submissionCount === 0n && !activeSubmission) return null;

  const verdict = hasVerdict ? activeSubmission!.verdict : null;
  const verdictLabel = verdict != null ? VERDICT_LABEL[verdict as keyof typeof VERDICT_LABEL] : null;
  const verdictStyle = verdict != null
    ? verdict === VerificationVerdict.Complete
      ? "text-green border-green/30 bg-green/5"
      : verdict === VerificationVerdict.NeedsReview
      ? "text-yellow border-yellow/30 bg-yellow/5"
      : "text-red border-red/30 bg-red/5"
    : null;

  type Step = { label: string; Icon: LucideIcon; done: boolean; active: boolean; fail: boolean };
  const steps: Step[] = [
    { label: "Evidence on-chain", Icon: Upload, done: true, active: false, fail: false },
    { label: "Agent evaluating", Icon: Cpu, done: hasVerdict || failed, active: isVerifying, fail: false },
    { label: "Verdict", Icon: CheckCircle2, done: hasVerdict, active: false, fail: failed },
  ];

  return (
    <div className="mt-6 rounded-xl border border-border bg-surface p-5">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-muted">Agent Pipeline</h3>
        {task.submissionCount > 1n && (
          <span className="text-[11px] text-subtle">
            {task.submissionCount.toString()} submissions
          </span>
        )}
      </div>

      {/* Steps */}
      <div className="mb-4 flex items-start">
        {steps.map((step, i) => {
          const Icon = step.Icon;
          const stepColor = step.fail
            ? "border-red/30 bg-red/10 text-red"
            : step.done
            ? "border-green/30 bg-green/10 text-green"
            : step.active
            ? "border-yellow/30 bg-yellow/10 text-yellow"
            : "border-border bg-surface-2 text-subtle";
          const lineColor = steps[i - 1]?.done ? "bg-green/30" : "bg-border";

          return (
            <div key={step.label} className="flex flex-1 items-start">
              {i > 0 && (
                <div className={`mt-4 h-px flex-1 shrink-0 ${lineColor}`} />
              )}
              <div className="flex flex-col items-center gap-1.5">
                <div
                  className={`flex h-8 w-8 items-center justify-center rounded-full border ${stepColor}`}
                >
                  {step.active ? (
                    <RefreshCw size={13} className="animate-spin" />
                  ) : (
                    <Icon size={13} />
                  )}
                </div>
                <span className="max-w-[72px] text-center font-mono text-[9px] leading-tight text-muted">
                  {step.label}
                </span>
              </div>
              {i < steps.length - 1 && (
                <div className={`mt-4 h-px flex-1 shrink-0 ${step.done ? "bg-green/30" : "bg-border"}`} />
              )}
            </div>
          );
        })}
      </div>

      {/* Verdict result */}
      {hasVerdict && verdictStyle && (
        <div
          className={`flex items-center justify-between rounded border px-3 py-2 ${verdictStyle}`}
        >
          <span className="text-xs text-muted">Verdict</span>
          <span className="font-mono text-sm font-bold">{verdictLabel}</span>
        </div>
      )}
      {failed && (
        <div className="flex items-center justify-between rounded border border-red/20 bg-red/5 px-3 py-2">
          <span className="text-xs text-muted">Status</span>
          <span className="font-mono text-sm font-bold text-red">Verification Failed</span>
        </div>
      )}
      {isVerifying && (
        <div className="flex items-center gap-2 rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-yellow">
          <RefreshCw size={11} className="animate-spin shrink-0" />
          Somnia agents are evaluating the submitted evidence…
        </div>
      )}
    </div>
  );
}

function MilestoneTrail({
  taskId,
  task,
  activeSubmission,
}: {
  taskId: bigint;
  task: Task | null;
  activeSubmission: Submission | null;
}) {
  const { events, isScanning } = useTaskTrailEvents(taskId);

  // Show real on-chain events when available; fall back to state-derived events
  // while the block scan is in progress.
  const derivedEvents = task ? buildDerivedTaskEvents(task, activeSubmission, taskId) : [];
  const displayEvents = events.length > 0 ? events : derivedEvents;
  const isDerived = events.length === 0;

  return (
    <div className="mt-6">
      <div className="mb-3 flex items-center gap-2">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-muted">
          Execution Trail
        </h3>
        {isScanning && (
          <span className="flex items-center gap-1 text-xs text-subtle">
            <RefreshCw size={10} className="animate-spin" />
            {isDerived ? "fetching on-chain data…" : "scanning older blocks…"}
          </span>
        )}
        {isDerived && displayEvents.length > 0 && (
          <span className="rounded bg-surface px-1.5 py-0.5 text-[10px] text-subtle">
            estimated from state
          </span>
        )}
      </div>

      {displayEvents.length === 0 && isScanning && (
        <div className="space-y-1.5">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="h-10 animate-pulse rounded-lg bg-surface" />
          ))}
        </div>
      )}

      {displayEvents.length === 0 && !isScanning && (
        <p className="text-xs text-subtle">No on-chain events yet.</p>
      )}

      {displayEvents.length > 0 && (
        <div className={`overflow-hidden rounded-xl border border-border bg-surface${isDerived ? " opacity-70" : ""}`}>
          <table className="w-full">
            <thead>
              <tr className="border-b border-border">
                <th className="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wider text-muted">Event</th>
                <th className="hidden px-4 py-2 text-left text-xs font-semibold uppercase tracking-wider text-muted sm:table-cell">Details</th>
                <th className="hidden px-4 py-2 text-left text-xs font-semibold uppercase tracking-wider text-muted lg:table-cell">From</th>
                <th className="hidden px-4 py-2 text-right text-xs font-semibold uppercase tracking-wider text-muted sm:table-cell">Amount</th>
                <th className="px-4 py-2 text-right text-xs font-semibold uppercase tracking-wider text-muted">Tx</th>
              </tr>
            </thead>
            <tbody>
              {displayEvents.map((ev) => (
                <tr key={ev.key} className="border-b border-border/40 last:border-0 hover:bg-surface-2 transition-colors">
                  <td className="px-4 py-2.5">
                    <div className="flex items-center gap-2">
                      <TrailIcon name={ev.name} className={ev.colorClass} />
                      <span className="text-xs font-medium text-text">
                        {ev.name.replace(/([A-Z])/g, " $1").trim()}
                      </span>
                      {ev.state != null && <StatusPill state={ev.state} size="sm" />}
                    </div>
                  </td>
                  <td className="hidden px-4 py-2.5 sm:table-cell">
                    <span className="text-xs text-muted">{ev.details}</span>
                  </td>
                  <td className="hidden px-4 py-2.5 lg:table-cell">
                    {ev.address ? (
                      <a
                        href={explorerAddressUrl(ev.address)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="font-mono text-xs text-muted hover:text-text transition-colors"
                      >
                        {truncateAddress(ev.address)}
                      </a>
                    ) : (
                      <span className="text-xs text-subtle">—</span>
                    )}
                  </td>
                  <td className="hidden px-4 py-2.5 text-right sm:table-cell">
                    {ev.amount != null && ev.amount > 0n ? (
                      <span className="font-mono text-xs text-text">{formatSTT(ev.amount)}</span>
                    ) : (
                      <span className="text-xs text-subtle">—</span>
                    )}
                  </td>
                  <td className="px-4 py-2.5 text-right">
                    {ev.txHash ? (
                      <a
                        href={explorerTxUrl(ev.txHash)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 font-mono text-xs text-accent hover:text-accent-hover transition-colors"
                      >
                        {ev.txHash.slice(0, 8)}…
                        <ExternalLink size={10} />
                      </a>
                    ) : (
                      <span className="font-mono text-xs text-subtle">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
