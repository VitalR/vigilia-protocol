"use client";

import { ArrowRight, Check, ChevronLeft, ChevronRight, Plus, X } from "lucide-react";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { parseEther } from "viem";
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import { TxButton, TxStatus } from "@/components/tx-button";
import { useGrantRounds, useGrantIsDeployed, useGrantAgentFee } from "@/lib/hooks";
import {
  grantRoundContract,
  RoundState,
  ScreeningMode,
  ROUND_STATE_LABEL,
  SCREENING_MODE_LABEL,
} from "@/lib/contracts";
import {
  CRITERION_TYPES,
  formatSTT,
  formatTimestamp,
  parseRequirementsMeta,
  type CriterionType,
  type RequirementsMeta,
} from "@/lib/utils";
import { cn } from "@/lib/utils";

// ─── Round state pill ─────────────────────────────────────────────────────────

function RoundStatePill({ state, applicationDeadline }: { state: RoundState; applicationDeadline?: number }) {
  const now = Math.floor(Date.now() / 1000);
  const expired = state === RoundState.Open && applicationDeadline != null && now > applicationDeadline;
  const label = expired ? "Ended" : (ROUND_STATE_LABEL[state] ?? String(state));
  const styles: Partial<Record<RoundState, string>> = {
    [RoundState.Open]: expired
      ? "bg-surface-2 text-muted border-border"
      : "bg-green/10 text-green border-green/30",
    [RoundState.Review]: "bg-yellow/10 text-yellow border-yellow/30",
    [RoundState.Finalized]: "bg-blue/10 text-blue border-blue/30",
    [RoundState.Created]: "bg-surface-2 text-muted border-border",
    [RoundState.Cancelled]: "bg-surface-2 text-muted border-border",
  };
  return (
    <span
      className={cn(
        "inline-flex items-center rounded border font-mono text-xs font-medium uppercase tracking-wider px-2 py-0.5",
        styles[state] ?? "bg-surface-2 text-muted border-border"
      )}
    >
      {state === RoundState.Open && !expired && (
        <span className="mr-1.5 inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-green" />
      )}
      {label}
    </span>
  );
}

// ─── Create Round modal ───────────────────────────────────────────────────────

function CreateRoundModal({ onSuccess, onClose }: { onSuccess: () => void; onClose: () => void }) {
  const { address } = useAccount();

  // Requirements
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [selectedCriteria, setSelectedCriteria] = useState<{ type: CriterionType; label: string }[]>([]);
  const [refs, setRefs] = useState<string[]>([""]);

  // Round settings
  const [judgeAddress, setJudgeAddress] = useState("");
  const [prizeSTT, setPrizeSTT] = useState("");
  const [maxWinners, setMaxWinners] = useState("3");
  const [appDeadline, setAppDeadline] = useState("");
  const [reviewDeadline, setReviewDeadline] = useState("");
  const [screeningMode, setScreeningMode] = useState<ScreeningMode>(ScreeningMode.ThreeAgent);

  const twoAgentFee = useGrantAgentFee(ScreeningMode.TwoAgent);
  const threeAgentFee = useGrantAgentFee(ScreeningMode.ThreeAgent);
  function fmtFee(wei: bigint | undefined) {
    if (!wei) return null;
    const n = Number(wei) / 1e18;
    return `${n % 1 === 0 ? n.toFixed(0) : n.toFixed(2)} STT`;
  }

  const { writeContract, data: txHash, isPending, error, reset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  // On success: refresh list, keep modal open to show confirmation
  useEffect(() => {
    if (isSuccess) {
      // Small delay so the node has time to index the new round
      setTimeout(() => onSuccess(), 800);
    }
  }, [isSuccess, onSuccess]);

  useEffect(() => {
    // Block Escape while confirming so the modal isn't closed mid-tx
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !confirming && !isPending) onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose, confirming, isPending]);

  function toggleCriterion(type: CriterionType) {
    setSelectedCriteria((prev) => {
      const exists = prev.find((c) => c.type === type);
      if (exists) return prev.filter((c) => c.type !== type);
      return [...prev, { type, label: "" }];
    });
  }

  function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !prizeSTT || !appDeadline || !reviewDeadline || selectedCriteria.length === 0) return;

    const judge = ((judgeAddress.trim() || address) ?? "0x0000000000000000000000000000000000000000") as `0x${string}`;
    const prize = parseEther(prizeSTT);
    const winners = BigInt(maxWinners || "1");
    const appTs = BigInt(Math.floor(new Date(appDeadline).getTime() / 1000));
    const reviewTs = BigInt(Math.floor(new Date(reviewDeadline).getTime() / 1000));

    const reqMeta: RequirementsMeta = {
      title: title.trim(),
      description: description.trim() || undefined,
      criteria: selectedCriteria.map((c) => ({
        type: c.type,
        ...(c.label.trim() ? { label: c.label.trim() } : {}),
      })),
      refs: refs.filter((r) => r.trim()).length > 0
        ? refs.filter((r) => r.trim())
        : undefined,
    };
    const requirementsURI = JSON.stringify(reqMeta);

    reset();
    writeContract({
      ...grantRoundContract,
      functionName: "createRound",
      args: [judge, prize, winners, appTs, reviewTs, requirementsURI, screeningMode],
    });
  }

  const totalPool = prizeSTT && maxWinners
    ? (Number(prizeSTT) * Number(maxWinners)).toFixed(2).replace(/\.?0+$/, "")
    : null;

  const canCreate = title.trim() && prizeSTT && appDeadline && reviewDeadline && selectedCriteria.length > 0;

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      onClick={(e) => { if (e.target === e.currentTarget && !confirming && !isPending) onClose(); }}
    >
      <div className="absolute inset-0 bg-black/60" />
      <div className="relative flex max-h-[90vh] w-full max-w-xl flex-col rounded-lg border border-border bg-surface shadow-xl">
        {/* Sticky header */}
        <div className="flex shrink-0 items-center justify-between border-b border-border px-5 py-4">
          <h2 className="text-sm font-semibold text-text">Create Grant</h2>
          <button
            type="button"
            onClick={onClose}
            disabled={confirming || isPending}
            className="text-muted hover:text-text transition-colors disabled:opacity-30"
          >
            <X size={16} />
          </button>
        </div>

        {/* Success screen */}
        {isSuccess && (
          <div className="flex flex-1 flex-col items-center justify-center gap-4 p-10 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full border border-green/30 bg-green/10">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="text-green">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </div>
            <div>
              <p className="text-base font-semibold text-text">Grant created</p>
              <p className="mt-1 text-sm text-muted">
                Transaction confirmed. Fund it to open applications.
              </p>
              {txHash && (
                <a
                  href={`https://somnia-testnet.socialscan.io/tx/${txHash}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-2 inline-flex items-center gap-1 font-mono text-xs text-subtle hover:text-accent transition-colors"
                >
                  {txHash.slice(0, 12)}…{txHash.slice(-6)} ↗
                </a>
              )}
            </div>
            <button
              type="button"
              onClick={onClose}
              className="mt-2 rounded-lg border border-border px-4 py-2 text-sm text-muted transition-colors hover:border-accent/40 hover:text-text"
            >
              View grants
            </button>
          </div>
        )}

        {/* Scrollable form (hidden after success) */}
        <form onSubmit={handleCreate} className={`flex-1 overflow-y-auto ${isSuccess ? "hidden" : ""}`}>
          <div className="space-y-5 p-5">

            {/* ── Requirements ── */}
            <div>
              <p className="mb-3 text-[10px] font-semibold uppercase tracking-wider text-subtle">Requirements</p>
              <div className="space-y-3">
                <div>
                  <label>Grant title <span className="font-normal text-red">*</span></label>
                  <input
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="e.g. Somnia DeFi Hackathon"
                    required
                  />
                </div>
                <div>
                  <label>Description</label>
                  <textarea
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="What are you looking for? What will be evaluated?"
                    rows={2}
                    className="resize-none"
                  />
                </div>
                <div>
                  <label>Evidence types required <span className="font-normal text-red">*</span></label>
                  <div className="mt-2 flex flex-wrap gap-2">
                    {CRITERION_TYPES.map((ct) => {
                      const sel = !!selectedCriteria.find((c) => c.type === ct.value);
                      return (
                        <button
                          key={ct.value}
                          type="button"
                          onClick={() => toggleCriterion(ct.value)}
                          className={cn(
                            "flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs transition-colors",
                            sel
                              ? "border-accent/40 bg-accent/10 text-accent"
                              : "border-border bg-surface text-muted hover:border-accent/30 hover:text-text"
                          )}
                        >
                          {sel && <Check size={11} />}
                          {ct.label}
                        </button>
                      );
                    })}
                  </div>
                  {selectedCriteria.find((c) => c.type === "other") && (
                    <input
                      value={selectedCriteria.find((c) => c.type === "other")?.label ?? ""}
                      onChange={(e) => setSelectedCriteria((prev) =>
                        prev.map((c) => c.type === "other" ? { ...c, label: e.target.value } : c)
                      )}
                      placeholder="Describe what needs to be delivered"
                      className="mt-2"
                    />
                  )}
                </div>
                <div>
                  <label>Reference links <span className="font-normal text-muted">(optional)</span></label>
                  {refs.map((ref, i) => (
                    <div key={i} className="mt-1.5 flex gap-2">
                      <input
                        value={ref}
                        onChange={(e) => setRefs((prev) => { const n = [...prev]; n[i] = e.target.value; return n; })}
                        placeholder="https://…"
                        className="flex-1"
                      />
                      {refs.length > 1 && (
                        <button
                          type="button"
                          onClick={() => setRefs((prev) => prev.filter((_, j) => j !== i))}
                          className="text-muted hover:text-red transition-colors"
                        >
                          <X size={14} />
                        </button>
                      )}
                    </div>
                  ))}
                  <button
                    type="button"
                    onClick={() => setRefs((prev) => [...prev, ""])}
                    className="mt-1.5 text-xs text-muted hover:text-accent transition-colors"
                  >
                    + Add link
                  </button>
                </div>
              </div>
            </div>

            <div className="border-t border-border" />

            {/* ── Round settings ── */}
            <div>
              <p className="mb-3 text-[10px] font-semibold uppercase tracking-wider text-subtle">Grant Settings</p>
              <div className="space-y-3">
                <div>
                  <label>
                    Judge address{" "}
                    <span className="font-normal text-muted">(defaults to your wallet)</span>
                  </label>
                  <input
                    value={judgeAddress}
                    onChange={(e) => setJudgeAddress(e.target.value)}
                    placeholder={address ?? "0x…"}
                    className="font-mono"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label>Prize per winner (STT) <span className="font-normal text-red">*</span></label>
                    <input
                      type="number"
                      min="0"
                      step="any"
                      value={prizeSTT}
                      onChange={(e) => setPrizeSTT(e.target.value)}
                      placeholder="100"
                      required
                    />
                  </div>
                  <div>
                    <label>Max winners</label>
                    <input
                      type="number"
                      min="1"
                      value={maxWinners}
                      onChange={(e) => setMaxWinners(e.target.value)}
                      placeholder="3"
                    />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label>Application deadline <span className="font-normal text-red">*</span></label>
                    <input
                      type="datetime-local"
                      value={appDeadline}
                      onChange={(e) => setAppDeadline(e.target.value)}
                      required
                    />
                  </div>
                  <div>
                    <label>Review deadline <span className="font-normal text-red">*</span></label>
                    <input
                      type="datetime-local"
                      value={reviewDeadline}
                      onChange={(e) => setReviewDeadline(e.target.value)}
                      required
                    />
                  </div>
                </div>
                <div>
                  <label>Screening mode</label>
                  <div className="mt-2 grid grid-cols-2 gap-2">
                    {([
                      {
                        mode: ScreeningMode.ThreeAgent,
                        name: "ThreeAgent",
                        desc: "JSON facts + website → LLM verdict",
                        fee: fmtFee(threeAgentFee),
                        badge: "Recommended",
                      },
                      {
                        mode: ScreeningMode.TwoAgent,
                        name: "TwoAgent",
                        desc: "JSON facts → LLM verdict",
                        fee: fmtFee(twoAgentFee),
                        badge: null,
                      },
                    ] as const).map(({ mode, name, desc, fee, badge }) => {
                      const active = screeningMode === mode;
                      return (
                        <button
                          key={mode}
                          type="button"
                          onClick={() => setScreeningMode(mode)}
                          className={cn(
                            "relative flex flex-col items-start gap-0.5 rounded-lg border px-3 py-2.5 text-left transition-colors",
                            active
                              ? "border-accent/40 bg-accent/8 text-text"
                              : "border-border bg-surface text-muted hover:border-accent/20 hover:text-text"
                          )}
                        >
                          {badge && (
                            <span className="absolute right-2 top-2 rounded bg-accent/15 px-1.5 py-px text-[9px] font-semibold uppercase tracking-wider text-accent">
                              {badge}
                            </span>
                          )}
                          <span className="text-[11px] font-semibold text-text">{name}</span>
                          <span className="text-[10px] leading-tight text-muted">{desc}</span>
                          {fee && (
                            <span className="mt-1 font-mono text-[10px] text-subtle">{fee} / screening</span>
                          )}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Pool summary */}
                {totalPool && (
                  <div className="rounded border border-border bg-surface-2 px-3 py-2 text-xs text-muted">
                    Total pool:{" "}
                    <span className="font-semibold text-text">{totalPool} STT</span>
                    {" "}· {maxWinners} winner{Number(maxWinners) !== 1 ? "s" : ""} × {prizeSTT} STT each.
                    You will need to fund this after creation.
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Sticky footer */}
          <div className="sticky bottom-0 border-t border-border bg-surface px-5 py-4 space-y-2">
            {!canCreate && (
              <ul className="space-y-0.5 text-[11px] text-muted">
                {!title.trim() && <li>· Grant title is required</li>}
                {!prizeSTT && <li>· Prize per winner is required</li>}
                {!appDeadline && <li>· Application deadline is required</li>}
                {!reviewDeadline && <li>· Review deadline is required</li>}
                {selectedCriteria.length === 0 && <li>· Select at least one evidence type</li>}
              </ul>
            )}
            <TxButton
              type="submit"
              loading={isPending}
              confirming={confirming}
              className="w-full"
              disabled={!canCreate}
            >
              {confirming ? "Confirming…" : "Create Grant"}
            </TxButton>
            <TxStatus error={error} txHash={txHash} />
          </div>
        </form>
      </div>
    </div>,
    document.body
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function GrantsPage() {
  const [page, setPage] = useState(0);
  const [showCreate, setShowCreate] = useState(false);
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const { address } = useAccount();
  const { rounds, totalRounds, totalPages, isLoading, isDeployed, refetch } = useGrantRounds(page);
  const refresh = useCallback(() => refetch(), [refetch]);

  const isEmpty = !isLoading && (!rounds || rounds.length === 0);

  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text">Grants</h1>
          {!isLoading && isDeployed && (
            <p className="mt-1 text-sm text-muted">
              {totalRounds} {totalRounds === 1 ? "grant" : "grants"} on-chain
            </p>
          )}
        </div>
        {mounted && isDeployed && !!address && (
          <button
            onClick={() => setShowCreate(true)}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border bg-surface px-3 py-2 text-sm text-muted transition-colors hover:border-accent/40 hover:text-text"
          >
            <Plus size={14} />
            Create Grant
          </button>
        )}
      </div>

      {!isDeployed && (
        <div className="rounded-xl border border-border bg-surface p-6 text-center text-sm text-muted">
          Grant contract address not configured.
        </div>
      )}

      {isLoading && (
        <div className="flex flex-col gap-2">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="h-16 animate-pulse rounded-lg border border-border bg-surface" />
          ))}
        </div>
      )}

      {isEmpty && isDeployed && (
        <div className="flex flex-col items-center justify-center rounded-xl border border-dashed border-border py-24 text-center">
          <p className="mb-1 font-semibold text-text">No grants yet</p>
          <p className="text-sm text-muted">Grants will appear here once created on-chain</p>
        </div>
      )}

      {!isLoading && rounds && rounds.length > 0 && (
        <>
          <div className="overflow-hidden rounded-xl border border-border bg-surface">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border">
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted">ID</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted">Grant / Status</th>
                  <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted md:table-cell">Prize</th>
                  <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted md:table-cell">Pool</th>
                  <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted lg:table-cell">Mode</th>
                  <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted lg:table-cell">App Deadline</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {rounds.map(({ id, round }) => {
                  const meta = parseRequirementsMeta(round.requirementsURI);
                  const pool = round.prizeAmount * round.maxWinners;
                  return (
                    <tr key={id} className="border-b border-border/50 transition-colors hover:bg-surface-2">
                      <td className="px-4 py-4">
                        <span className="font-mono text-sm font-semibold text-text">#{id}</span>
                      </td>
                      <td className="px-4 py-4">
                        <div className="flex flex-col gap-1">
                          {meta?.title && (
                            <span className="text-sm text-text">{meta.title}</span>
                          )}
                          <div className="flex items-center gap-2">
                            <RoundStatePill state={round.state} applicationDeadline={round.applicationDeadline} />
                            <span className="text-xs text-muted">
                              {round.applicationsCount.toString()} app{round.applicationsCount !== 1n ? "s" : ""}
                            </span>
                          </div>
                        </div>
                      </td>
                      <td className="hidden px-4 py-4 md:table-cell">
                        <span className="font-mono text-sm text-text">{formatSTT(round.prizeAmount)}</span>
                        <span className="ml-1 text-xs text-muted">×{round.maxWinners.toString()}</span>
                      </td>
                      <td className="hidden px-4 py-4 md:table-cell">
                        <span className="font-mono text-sm text-text">{formatSTT(pool)}</span>
                      </td>
                      <td className="hidden px-4 py-4 lg:table-cell">
                        <span className="text-xs text-muted">{SCREENING_MODE_LABEL[round.screeningMode]}</span>
                      </td>
                      <td className="hidden px-4 py-4 lg:table-cell">
                        <span className="font-mono text-xs text-muted">
                          {formatTimestamp(round.applicationDeadline)}
                        </span>
                      </td>
                      <td className="px-4 py-4 text-right">
                        <Link
                          href={`/grants/${id}`}
                          className="inline-flex items-center gap-1 rounded px-2 py-1 text-xs text-muted transition-colors hover:text-text"
                        >
                          View <ArrowRight size={11} />
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-between text-sm">
              <span className="text-muted">
                Page {page + 1} of {totalPages}
              </span>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setPage((p) => Math.max(0, p - 1))}
                  disabled={page === 0}
                  className="flex h-8 w-8 items-center justify-center rounded border border-border text-muted transition-colors hover:text-text disabled:opacity-30"
                >
                  <ChevronLeft size={14} />
                </button>
                <button
                  onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
                  disabled={page >= totalPages - 1}
                  className="flex h-8 w-8 items-center justify-center rounded border border-border text-muted transition-colors hover:text-text disabled:opacity-30"
                >
                  <ChevronRight size={14} />
                </button>
              </div>
            </div>
          )}
        </>
      )}

      {showCreate && mounted && (
        <CreateRoundModal
          onSuccess={refresh}
          onClose={() => setShowCreate(false)}
        />
      )}
    </div>
  );
}
