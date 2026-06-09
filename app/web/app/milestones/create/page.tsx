"use client";

import { ArrowRight, CheckCircle, Info, Plus, X, Check } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { formatEther, parseEther } from "viem";
import {
  useAccount,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";
import { NotDeployedBanner } from "@/components/not-deployed";
import { TxButton, TxStatus } from "@/components/tx-button";
import { escrowContract, ClaimPolicy, CLAIM_POLICY_LABEL } from "@/lib/contracts";
import { extractTaskIdFromReceipt, useAgentFee, useIsDeployed } from "@/lib/hooks";
import { serializeRequirements, CRITERION_TYPES, cn, type CriterionType } from "@/lib/utils";

type Step = "create" | "fund" | "done";

export default function CreateMilestonePage() {
  const router = useRouter();
  const { address, isConnected } = useAccount();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const isDeployed = useIsDeployed();
  const agentFee = useAgentFee();

  const [step, setStep] = useState<Step>("create");
  const [createdTaskId, setCreatedTaskId] = useState<bigint | null>(null);

  // ── Form state ──────────────────────────────────────────────
  const [contractor, setContractor] = useState("");
  const [resolver, setResolver] = useState("");
  const [reviewWindowHours, setReviewWindowHours] = useState("24");
  const [amountSTT, setAmountSTT] = useState("");

  // Structured requirements
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [selectedTypes, setSelectedTypes] = useState<CriterionType[]>(["github"]);
  const [otherLabel, setOtherLabel] = useState("");
  const [refs, setRefs] = useState<string[]>([""]);
  const [allowMultiple, setAllowMultiple] = useState(true);
  const [claimPolicy, setClaimPolicy] = useState<ClaimPolicy>(ClaimPolicy.ReviewWindowAutoClaim);

  // ── Create tx ───────────────────────────────────────────────
  const {
    writeContract: createWrite,
    data: createTxHash,
    isPending: createPending,
    error: createError,
    reset: createReset,
  } = useWriteContract();

  const { isLoading: createConfirming, isSuccess: createSuccess, data: createReceipt } =
    useWaitForTransactionReceipt({ hash: createTxHash });

  // ── Fund tx ─────────────────────────────────────────────────
  const {
    writeContract: fundWrite,
    data: fundTxHash,
    isPending: fundPending,
    error: fundError,
    reset: fundReset,
  } = useWriteContract();

  const { isLoading: fundConfirming, isSuccess: fundSuccess } =
    useWaitForTransactionReceipt({ hash: fundTxHash });

  // After create confirmed — extract taskId
  const taskIdExtracted = useRef(false);
  useEffect(() => {
    if (!createSuccess || !createReceipt || taskIdExtracted.current) return;
    taskIdExtracted.current = true;
    const id = extractTaskIdFromReceipt(createReceipt.logs);
    setCreatedTaskId(id);
    setStep("fund");
  }, [createSuccess, createReceipt]);

  // After fund confirmed — redirect
  useEffect(() => {
    if (fundSuccess && createdTaskId != null) {
      setStep("done");
      setTimeout(() => router.push(`/milestones/${createdTaskId}`), 1500);
    }
  }, [fundSuccess, createdTaskId, router]);

  // ── Criteria helpers ─────────────────────────────────────────
  function toggleType(type: CriterionType) {
    setSelectedTypes((prev) =>
      prev.includes(type) ? prev.filter((t) => t !== type) : [...prev, type]
    );
  }

  // ── Handlers ────────────────────────────────────────────────
  function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!contractor || !resolver || !title || !selectedTypes.length || !reviewWindowHours || !amountSTT) return;

    const criteria = selectedTypes.map((type) => ({
      type,
      ...(type === "other" && otherLabel.trim() ? { label: otherLabel.trim() } : {}),
    }));

    const requirementsURI = serializeRequirements({
      title: title.trim(),
      ...(description.trim() ? { description: description.trim() } : {}),
      criteria,
      ...(refs.some((r) => r.trim()) ? { refs: refs.filter((r) => r.trim()) } : {}),
      allowMultiple,
    });

    createReset();
    taskIdExtracted.current = false;
    createWrite({
      ...escrowContract,
      functionName: "createTaskWithPolicy",
      args: [
        contractor as `0x${string}`,
        resolver as `0x${string}`,
        parseEther(amountSTT),
        BigInt(Math.round(Number(reviewWindowHours) * 3600)),
        requirementsURI,
        claimPolicy,
      ],
    });
  }

  function handleFund() {
    if (!createdTaskId || !amountSTT) return;
    fundReset();
    fundWrite({
      ...escrowContract,
      functionName: "fundTask",
      args: [createdTaskId],
      value: parseEther(amountSTT),
    });
  }


  if (!mounted) {
    return <div className="flex h-96 items-center justify-center text-muted">Loading…</div>;
  }

  if (!isConnected) {
    return (
      <div className="mx-auto flex h-96 max-w-3xl items-center justify-center px-4">
        <div className="rounded-lg border border-border bg-surface px-6 py-5 text-center text-sm text-muted">
          Connect wallet to create a milestone.
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-text">Create Milestone</h1>
        <p className="mt-1 text-sm text-muted">
          Fund a fixed-price task in escrow. Agent will verify submitted evidence.
        </p>
      </div>

      {/* ── Progress ─────────────────────────────────────────── */}
      <div className="mb-8 flex items-center gap-2">
        {(["create", "fund", "done"] as Step[]).map((s, i) => {
          const labels = ["Define", "Fund", "Active"];
          const isDone = step === "done" || (step === "fund" && s === "create");
          const isActive = step === s;
          return (
            <div key={s} className="flex items-center gap-2">
              <div className="flex items-center gap-1.5">
                <div
                  className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold
                  ${isDone ? "bg-green/20 text-green" : isActive ? "bg-accent/10 border border-accent/40 text-accent" : "bg-surface-2 border border-border text-muted"}`}
                >
                  {isDone ? <CheckCircle size={12} /> : i + 1}
                </div>
                <span className={`text-xs font-medium ${isActive ? "text-text" : isDone ? "text-green" : "text-muted"}`}>
                  {labels[i]}
                </span>
              </div>
              {i < 2 && <div className="h-px w-8 bg-border" />}
            </div>
          );
        })}
      </div>

      {/* ── Step 1: Create ───────────────────────────────────── */}
      {step === "create" && (
        <form onSubmit={handleCreate} className="fade-in space-y-6">

          {/* Milestone requirements */}
          <div className="rounded-xl border border-border bg-surface p-6">
            <h2 className="mb-5 font-semibold text-text">Milestone requirements</h2>

            <div className="mb-4">
              <label>Title *</label>
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Deploy and verify smart contract on Somnia"
                required
              />
            </div>

            <div className="mb-4">
              <label>Description</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="What should the contractor deliver? Any context useful for verification."
                rows={3}
                className="resize-none"
              />
            </div>

            <div className="mb-4">
              <label>Reference URLs</label>
              <div className="space-y-2">
                {refs.map((r, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <input
                      value={r}
                      onChange={(e) => setRefs((prev) => prev.map((v, idx) => idx === i ? e.target.value : v))}
                      placeholder="https://github.com/org/repo/issues/1"
                      type="url"
                      className="flex-1"
                    />
                    {refs.length > 1 && (
                      <button
                        type="button"
                        onClick={() => setRefs((prev) => prev.filter((_, idx) => idx !== i))}
                        className="shrink-0 text-subtle hover:text-red transition-colors"
                      >
                        <X size={14} />
                      </button>
                    )}
                  </div>
                ))}
              </div>
              <button
                type="button"
                onClick={() => setRefs((prev) => [...prev, ""])}
                className="mt-2 flex items-center gap-1 text-xs text-muted hover:text-accent transition-colors duration-100"
              >
                <Plus size={12} /> Add reference
              </button>
              <div className="mt-1 text-xs text-muted">
                GitHub issues, specs, docs, or any public links.
              </div>
            </div>

            <div className="mb-4">
              <label>Evidence types required *</label>
              <div className="mt-2 flex flex-wrap gap-2">
                {CRITERION_TYPES.map((t) => {
                  const active = selectedTypes.includes(t.value);
                  return (
                    <button
                      key={t.value}
                      type="button"
                      onClick={() => toggleType(t.value)}
                      className={cn(
                        "flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors",
                        active
                          ? "border-accent/40 bg-accent/10 text-accent"
                          : "border-border bg-surface-2 text-muted hover:text-text hover:border-border-2"
                      )}
                    >
                      {active && <Check size={11} />}
                      {t.label}
                    </button>
                  );
                })}
              </div>
              {selectedTypes.includes("other") && (
                <div className="mt-3">
                  <input
                    value={otherLabel}
                    onChange={(e) => setOtherLabel(e.target.value)}
                    placeholder="Describe what else needs to be delivered"
                    className="w-full"
                  />
                </div>
              )}
            </div>

            <div className="flex items-center justify-between rounded-lg border border-border bg-surface-2 px-4 py-3">
              <div>
                <div className="text-sm font-medium text-text">Allow multiple submissions</div>
                <div className="text-xs text-muted">Contractor can resubmit after rejection</div>
              </div>
              <button
                type="button"
                onClick={() => setAllowMultiple((v) => !v)}
                className={cn(
                  "relative h-6 w-11 shrink-0 overflow-hidden rounded-full transition-colors",
                  allowMultiple ? "bg-accent" : "bg-surface-2 border border-border"
                )}
              >
                <span
                  className={cn(
                    "absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform",
                    allowMultiple ? "translate-x-[22px]" : "translate-x-0"
                  )}
                />
              </button>
            </div>
          </div>

          {/* Parties */}
          <div className="rounded-xl border border-border bg-surface p-6">
            <h2 className="mb-5 font-semibold text-text">Parties</h2>

            <div className="mb-4">
              <label>Your address (client)</label>
              <input value={address ?? ""} disabled className="opacity-50 cursor-not-allowed" />
            </div>

            <div className="mb-4">
              <label>Contractor address *</label>
              <input
                value={contractor}
                onChange={(e) => setContractor(e.target.value)}
                placeholder="0x..."
                required
                pattern="^0x[0-9a-fA-F]{40}$"
              />
            </div>

            <div>
              <label>Resolver address *</label>
              <input
                value={resolver}
                onChange={(e) => setResolver(e.target.value)}
                placeholder="0x... (trusted third party for disputes)"
                required
                pattern="^0x[0-9a-fA-F]{40}$"
              />
              <div className="mt-1 flex items-center gap-1 text-xs text-muted">
                <Info size={11} />
                <span>Only called if a dispute is raised. Can be the client address for demos.</span>
              </div>
            </div>
          </div>

          {/* Terms */}
          <div className="rounded-xl border border-border bg-surface p-6">
            <h2 className="mb-5 font-semibold text-text">Terms</h2>

            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label>Amount (STT) *</label>
                <input
                  type="number"
                  value={amountSTT}
                  onChange={(e) => setAmountSTT(e.target.value)}
                  placeholder="0.1"
                  min="0.000001"
                  step="any"
                  required
                />
              </div>
              <div>
                <label>Review window (hours) *</label>
                <input
                  type="number"
                  value={reviewWindowHours}
                  onChange={(e) => setReviewWindowHours(e.target.value)}
                  placeholder="24"
                  min="0"
                  step="1"
                  required
                />
                <div className="mt-1 text-xs text-muted">
                  Contractor auto-claims after this window.
                </div>
              </div>
            </div>

            <div className="mt-4">
              <label>Claim policy *</label>
              <div className="mt-2 flex flex-col gap-2">
                {([
                  [ClaimPolicy.ReviewWindowAutoClaim, "Auto-claim after review window", "Contractor can claim once the review window expires. Client can approve early."],
                  [ClaimPolicy.ImmediateAutoClaim,    "Immediate claim",                "Contractor can claim right after agent confirms Complete. No waiting."],
                  [ClaimPolicy.ClientApprovalOnly,    "Client approval required",        "Funds are released only when the client explicitly approves."],
                ] as [ClaimPolicy, string, string][]).map(([policy, label, hint]) => (
                  <button
                    key={policy}
                    type="button"
                    onClick={() => setClaimPolicy(policy)}
                    className={cn(
                      "flex items-start gap-3 rounded-lg border px-4 py-3 text-left transition-colors",
                      claimPolicy === policy
                        ? "border-accent/40 bg-accent/10"
                        : "border-border bg-surface-2 hover:border-border-2"
                    )}
                  >
                    <span className={cn(
                      "mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-full border-2 transition-colors",
                      claimPolicy === policy ? "border-accent bg-accent" : "border-border"
                    )}>
                      {claimPolicy === policy && <span className="h-1.5 w-1.5 rounded-full bg-bg" />}
                    </span>
                    <span>
                      <span className={cn("block text-sm font-medium", claimPolicy === policy ? "text-accent" : "text-text")}>
                        {label}
                      </span>
                      <span className="mt-0.5 block text-xs text-muted">{hint}</span>
                    </span>
                  </button>
                ))}
              </div>
            </div>
          </div>

          <TxButton
            type="submit"
            loading={createPending}
            confirming={createConfirming}
            className="w-full"
          >
            {createConfirming ? "Confirming…" : createPending ? "Sign transaction…" : "Create Milestone"}
            {!createPending && !createConfirming && <ArrowRight size={14} />}
          </TxButton>
          <TxStatus error={createError} txHash={createTxHash} />
        </form>
      )}

      {/* ── Step 2: Fund ─────────────────────────────────────── */}
      {step === "fund" && createdTaskId != null && (
        <div className="fade-in rounded-xl border border-green/20 bg-surface p-6 glow-green">
          <div className="mb-4 flex items-center gap-2">
            <CheckCircle size={18} className="text-green" />
            <h2 className="font-semibold text-text">
              Milestone #{createdTaskId.toString()} created
            </h2>
          </div>
          <p className="mb-4 text-sm text-muted">
            Now deposit{" "}
            <span className="font-mono font-semibold text-text">{amountSTT} STT</span>{" "}
            into escrow to activate the milestone.
          </p>

          {agentFee != null && agentFee > 0n && (
            <div className="mb-4 rounded-lg border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-muted">
              <Info size={11} className="mr-1 inline" />
              Agent fee for verification:{" "}
              <span className="font-mono font-semibold text-yellow">
                {formatEther(agentFee)} STT
              </span>{" "}
              — paid separately when submitting evidence.
            </div>
          )}

          <div className="mb-4 rounded-lg bg-surface-2 px-4 py-3 text-sm">
            <div className="flex items-center justify-between text-muted">
              <span>Amount to lock</span>
              <span className="font-mono font-semibold text-text">{amountSTT} STT</span>
            </div>
          </div>

          <TxButton
            onClick={handleFund}
            loading={fundPending}
            confirming={fundConfirming}
            className="w-full"
          >
            {fundConfirming ? "Confirming…" : fundPending ? "Sign transaction…" : `Fund ${amountSTT} STT`}
          </TxButton>
          <TxStatus error={fundError} txHash={fundTxHash} />
        </div>
      )}

      {/* ── Step 3: Done ─────────────────────────────────────── */}
      {step === "done" && (
        <div className="fade-in rounded-xl border border-green/30 bg-green/5 p-8 text-center">
          <CheckCircle size={40} className="mx-auto mb-4 text-green" />
          <h2 className="mb-2 text-xl font-bold text-text">Milestone active</h2>
          <p className="text-sm text-muted">Redirecting to milestone detail…</p>
        </div>
      )}
    </div>
  );
}
