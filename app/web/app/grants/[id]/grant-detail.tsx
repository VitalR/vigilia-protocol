"use client";

import {
  ArrowLeft,
  CheckCircle,
  Cpu,
  ExternalLink,
  FileCode,
  FileText,
  Github,
  Globe,
  Monitor,
  Pencil,
  RefreshCw,
  StickyNote,
  TestTube,
  Video,
  X,
  XCircle,
} from "lucide-react";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { formatEther } from "viem";
import {
  useAccount,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";
import { TxButton, TxStatus } from "@/components/tx-button";
import {
  grantRoundContract,
  RoundState,
  ApplicationStatus,
  ScreeningMode,
  VerificationVerdict,
  APPLICATION_STATUS_LABEL,
  SCREENING_MODE_LABEL,
  VERDICT_LABEL,
  VIGILIA_GRANT_ROUND_ADDRESS,
} from "@/lib/contracts";
import {
  useGrantRound,
  useGrantAgentFee,
  useGrantIsDeployed,
  useGrantRoundTrail,
  buildDerivedGrantTrail,
  type GrantRound,
  type GrantApplication,
  type GrantTrailItem,
} from "@/lib/hooks";
import {
  CRITERION_TYPES,
  buildGrantEvidence,
  explorerAddressUrl,
  explorerTxUrl,
  formatSTT,
  formatTimestamp,
  hashEvidenceURI,
  parseEvidenceMeta,
  parseRequirementsMeta,
  truncateAddress,
  cn,
  type CriterionType,
} from "@/lib/utils";
import { validateCriterionValue, hasValidationErrors } from "@/lib/validation";
import { getSampleEvidence, getSampleUrl, isSampleConfigured, anySampleConfigured, type SampleVerdict } from "@/lib/sample-evidence";

// ─── Status pill for round ────────────────────────────────────────────────────

function RoundStatePill({ state, deadlinePassed }: { state: RoundState; deadlinePassed?: boolean }) {
  const expired = state === RoundState.Open && deadlinePassed;
  const labels: Record<RoundState, string> = {
    [RoundState.None]: "None",
    [RoundState.Created]: "Pending",
    [RoundState.Open]: expired ? "Ended" : "Active",
    [RoundState.Review]: "Review",
    [RoundState.Finalized]: "Finalized",
    [RoundState.Cancelled]: "Cancelled",
  };
  const styles: Partial<Record<RoundState, string>> = {
    [RoundState.Open]: expired
      ? "bg-surface-2 text-muted border-border"
      : "bg-green/10 text-green border-green/30",
    [RoundState.Review]: "bg-yellow/10 text-yellow border-yellow/30",
    [RoundState.Finalized]: "bg-blue/10 text-blue border-blue/30",
    [RoundState.Created]: "bg-surface-2 text-subtle border-border",
    [RoundState.Cancelled]: "bg-surface-2 text-muted border-border",
  };
  return (
    <span
      className={cn(
        "inline-flex items-center rounded border px-2 py-0.5 font-mono text-xs font-medium uppercase tracking-wider",
        styles[state] ?? "bg-surface-2 text-muted border-border"
      )}
    >
      {state === RoundState.Open && !expired && (
        <span className="mr-1.5 inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-green" />
      )}
      {labels[state]}
    </span>
  );
}

// ─── Status pill for applications ─────────────────────────────────────────────

function AppStatusPill({ status }: { status: ApplicationStatus }) {
  const label = APPLICATION_STATUS_LABEL[status] ?? String(status);
  const styles: Partial<Record<ApplicationStatus, string>> = {
    [ApplicationStatus.Claimed]: "bg-green/10 text-green border-green/30",
    [ApplicationStatus.Selected]: "bg-green/10 text-green border-green/30",
    [ApplicationStatus.Complete]: "bg-green/10 text-green border-green/30",
    [ApplicationStatus.NeedsReview]: "bg-yellow/10 text-yellow border-yellow/30",
    [ApplicationStatus.ScreeningRequested]: "bg-yellow/10 text-yellow border-yellow/30",
    [ApplicationStatus.Incomplete]: "bg-red/10 text-red border-red/30",
    [ApplicationStatus.Rejected]: "bg-red/10 text-red border-red/30",
    [ApplicationStatus.VerificationFailed]: "bg-red/10 text-red border-red/30",
    [ApplicationStatus.Submitted]: "bg-blue/10 text-blue border-blue/30",
  };
  return (
    <span
      className={cn(
        "inline-flex items-center rounded border px-1.5 py-0.5 font-mono text-[10px] font-medium uppercase tracking-wider",
        styles[status] ?? "bg-surface-2 text-muted border-border"
      )}
    >
      {status === ApplicationStatus.ScreeningRequested && (
        <span className="mr-1 inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-yellow" />
      )}
      {label}
    </span>
  );
}

// ─── Submit Application modal ─────────────────────────────────────────────────

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

function SubmitApplicationPanel({
  roundId,
  requirementsURI,
  onSuccess,
  mode = "apply",
  initialEvidenceURI,
  screeningMode = ScreeningMode.TwoAgent,
}: {
  roundId: bigint;
  requirementsURI?: string;
  onSuccess?: () => void;
  mode?: "apply" | "edit";
  initialEvidenceURI?: string;
  screeningMode?: ScreeningMode;
}) {
  const agentFee = useGrantAgentFee(screeningMode);
  const isThreeAgent = screeningMode === ScreeningMode.ThreeAgent;

  const reqMeta = requirementsURI ? parseRequirementsMeta(requirementsURI) : null;
  const criteriaTypes: CriterionType[] = reqMeta?.criteria
    ? [...new Set(reqMeta.criteria.map((c) => c.type))]
    : ["github", "demo", "docs"];

  const [open, setOpen] = useState(false);
  // "normal" = applicant fills in their own evidence
  // "sample" = demo/testing mode: pick a pre-hosted evidence URL
  const [inputMode, setInputMode] = useState<"normal" | "sample">("normal");
  const [values, setValues] = useState<Partial<Record<CriterionType, string>>>({});
  const [websiteURI, setWebsiteURI] = useState("");
  const [summary, setSummary] = useState("");
  const [selectedSample, setSelectedSample] = useState<SampleVerdict | null>(null);
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
      setSelectedSample(null);
    }
  }, [open]);

  useEffect(() => {
    if (!open || mode !== "edit") return;
    if (initialEvidenceURI && isExternalUrl(initialEvidenceURI)) {
      setManualUrl(initialEvidenceURI);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
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

  function submitUrl(url: string) {
    txReset();
    writeContract({
      ...grantRoundContract,
      functionName: "submitApplication",
      args: [roundId, url, hashEvidenceURI(url)],
    });
  }

  // Validation: block fields that have a value but fail format check
  const fieldErrors: Partial<Record<string, string>> = {};
  for (const type of criteriaTypes) {
    const val = (values as Record<string, string | undefined>)[type]?.trim() ?? "";
    if (val) {
      const result = validateCriterionValue(type, val);
      if (!result.valid) fieldErrors[type] = result.error ?? "Invalid format";
    }
  }
  if (websiteURI.trim()) {
    const result = validateCriterionValue("website", websiteURI.trim());
    if (!result.valid) fieldErrors["websiteURI"] = result.error ?? "Invalid URL";
  }
  const anyFieldError = Object.keys(fieldErrors).length > 0;

  const hasFormValues = Object.values(values).some((v) => v?.trim()) || websiteURI.trim().length > 0;
  const effectiveUrl = uploadedUrl || manualUrl;
  const busy = uploadState === "uploading" || isPending || confirming;

  async function handleNormalSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (anyFieldError) return;
    if (!hasFormValues && !isExternalUrl(manualUrl)) return;

    if (isExternalUrl(effectiveUrl) && uploadState !== "idle") {
      submitUrl(effectiveUrl);
      return;
    }

    if (hasFormValues) {
      setUploadState("uploading");
      setUploadError("");
      try {
        const json = buildGrantEvidence(
          values as Record<string, string>,
          criteriaTypes,
          summary,
          isThreeAgent ? websiteURI : undefined,
        );
        const url = await uploadEvidenceJson(json);
        setUploadedUrl(url);
        setUploadState("done");
        submitUrl(url);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        setUploadError(msg);
        setUploadState("error");
      }
      return;
    }

    submitUrl(manualUrl);
  }

  function handleSampleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedSample) return;
    const url = getSampleUrl(selectedSample);
    if (url) submitUrl(url);
  }

  const isEdit = mode === "edit";
  const samples = getSampleEvidence();
  const showSampleTab = !isEdit && anySampleConfigured();

  const modal = open && mounted && createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      onClick={(e) => { if (!busy && e.target === e.currentTarget) setOpen(false); }}
    >
      <div className="absolute inset-0 bg-black/60" />
      <div className="relative flex max-h-[90vh] w-full max-w-lg flex-col rounded-lg border border-border bg-surface shadow-xl">

        {/* Header */}
        <div className="flex items-center justify-between border-b border-border px-5 py-4 shrink-0">
          <div>
            <h2 className="text-sm font-semibold text-text">
              {isEdit ? "Edit Application" : "Submit Application"}
            </h2>
            {!isEdit && (
              <p className="mt-0.5 text-[11px] text-muted">
                {inputMode === "normal"
                  ? "Submit public evidence. The app validates basic formats, then Somnia agents screen the public evidence."
                  : "For demo/testing only. Uses prepared public evidence to demonstrate different agent verdicts."}
              </p>
            )}
          </div>
          <button type="button" onClick={() => setOpen(false)} disabled={busy} className="ml-3 shrink-0 text-muted hover:text-text transition-colors disabled:opacity-40">
            <X size={16} />
          </button>
        </div>

        {/* Mode tabs */}
        {showSampleTab && (
          <div className="flex border-b border-border shrink-0">
            {(["normal", "sample"] as const).map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => setInputMode(m)}
                disabled={busy}
                className={cn(
                  "flex-1 px-4 py-2.5 text-xs font-medium transition-colors",
                  inputMode === m
                    ? "border-b-2 border-accent text-accent"
                    : "text-muted hover:text-text",
                )}
              >
                {m === "normal" ? "Normal Mode" : "Sample Evidence"}
              </button>
            ))}
          </div>
        )}

        {/* Normal mode form */}
        {inputMode === "normal" && (
          <form onSubmit={handleNormalSubmit} className="flex-1 overflow-y-auto space-y-3 p-5">
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
                    value={(values as Record<string, string | undefined>)[type] ?? ""}
                    onChange={(e) => setValues((v) => ({ ...v, [type]: e.target.value }))}
                    placeholder={typeDef.placeholder}
                    disabled={busy}
                    className={err ? "border-red/50 focus:border-red/70" : ""}
                  />
                  {err && <p className="mt-0.5 text-[11px] text-red">{err}</p>}
                </div>
              );
            })}

            {/* ThreeAgent: additional websiteURI field */}
            {isThreeAgent && (
              <div>
                <label>
                  Project Website URL
                  <span className="ml-1 text-accent">*</span>
                  <span className="ml-1 normal-case font-normal text-subtle">(required for 3-agent screening)</span>
                </label>
                <input
                  value={websiteURI}
                  onChange={(e) => setWebsiteURI(e.target.value)}
                  placeholder="https://your-project.io"
                  disabled={busy}
                  className={fieldErrors["websiteURI"] ? "border-red/50 focus:border-red/70" : ""}
                />
                {fieldErrors["websiteURI"] && (
                  <p className="mt-0.5 text-[11px] text-red">{fieldErrors["websiteURI"]}</p>
                )}
              </div>
            )}

            <div>
              <label>Project summary</label>
              <textarea
                value={summary}
                onChange={(e) => setSummary(e.target.value)}
                placeholder="Briefly describe your project and what you're building."
                rows={2}
                className="resize-none"
                disabled={busy}
              />
            </div>

            {/* Agent fee */}
            {agentFee != null && agentFee > 0n && (
              <div className="flex items-center justify-between rounded border border-border bg-surface-2 px-3 py-2 text-xs text-muted">
                <span>Screening fee ({isThreeAgent ? "3-agent" : "2-agent"})</span>
                <span className="font-mono font-semibold text-text">{formatEther(agentFee)} STT</span>
              </div>
            )}

            {/* Upload status */}
            {uploadState === "uploading" && (
              <div className="flex items-center gap-2 rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-yellow">
                <RefreshCw size={11} className="animate-spin shrink-0" />
                Uploading evidence to GitHub Gist…
              </div>
            )}
            {uploadState === "done" && uploadedUrl && (
              <div className="rounded border border-green/20 bg-green/5 px-3 py-2 text-xs text-green">
                Evidence hosted at{" "}
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
                />
              </div>
            )}

            {isEdit && !uploadedUrl && isExternalUrl(manualUrl) && (
              <div className="rounded border border-border bg-surface-2 px-3 py-2 text-xs text-muted">
                Current URL: <span className="break-all text-text">{manualUrl}</span>
              </div>
            )}

            <TxButton
              type="submit"
              loading={isPending}
              confirming={confirming}
              className="w-full"
              disabled={anyFieldError || (isThreeAgent && !websiteURI.trim()) || (!hasFormValues && !isExternalUrl(manualUrl)) || busy}
            >
              {uploadState === "uploading"
                ? "Uploading evidence…"
                : confirming ? "Confirming…"
                : isPending ? "Sign transaction…"
                : isEdit ? "Update Application"
                : "Submit Application"}
            </TxButton>
            <TxStatus error={txError} txHash={txHash} />
          </form>
        )}

        {/* Sample Evidence mode */}
        {inputMode === "sample" && (
          <form onSubmit={handleSampleSubmit} className="flex-1 overflow-y-auto space-y-3 p-5">
            <p className="text-[11px] text-muted leading-relaxed">
              Select a pre-prepared evidence package. The URL is submitted on-chain and Somnia agents
              evaluate it — the UI never sets the verdict directly.
            </p>
            <div className="space-y-2">
              {samples.map((sample) => {
                const configured = isSampleConfigured(sample.verdict);
                const selected = selectedSample === sample.verdict;
                return (
                  <button
                    key={sample.verdict}
                    type="button"
                    disabled={!configured || busy}
                    onClick={() => setSelectedSample(sample.verdict)}
                    className={cn(
                      "w-full rounded-lg border px-4 py-3 text-left transition-colors disabled:opacity-40",
                      selected
                        ? "border-accent bg-accent/5"
                        : "border-border bg-surface-2 hover:border-accent/40",
                    )}
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-semibold text-text">{sample.label}</span>
                      {!configured && (
                        <span className="text-[10px] text-subtle">Not configured</span>
                      )}
                    </div>
                    <p className="mt-0.5 text-xs text-muted">{sample.description}</p>
                  </button>
                );
              })}
            </div>

            <TxButton
              type="submit"
              loading={isPending}
              confirming={confirming}
              className="w-full"
              disabled={!selectedSample || busy}
            >
              {confirming ? "Confirming…" : isPending ? "Sign transaction…" : "Submit Sample Evidence"}
            </TxButton>
            <TxStatus error={txError} txHash={txHash} />
          </form>
        )}
      </div>
    </div>,
    document.body
  );

  if (isEdit) {
    return (
      <>
        <button
          type="button"
          onClick={() => setOpen(true)}
          title="Edit application"
          className="rounded p-1 text-muted hover:text-accent transition-colors"
        >
          <Pencil size={13} />
        </button>
        {modal}
      </>
    );
  }

  return (
    <>
      <TxButton onClick={() => setOpen(true)} className="w-full">
        Apply to Grant
      </TxButton>
      {modal}
    </>
  );
}

// ─── Evidence type chip icons (for requirements display) ──────────────────────

const EVIDENCE_ICONS: Record<string, React.ReactNode> = {
  github:   <Github size={11} />,
  contract: <FileCode size={11} />,
  demo:     <Globe size={11} />,
  docs:     <FileText size={11} />,
  video:    <Video size={11} />,
  test:     <TestTube size={11} />,
  other:    <Monitor size={11} />,
};

const EVIDENCE_LABELS: Record<string, string> = {
  github:   "GitHub repo",
  contract: "Deployed contract",
  demo:     "Live demo",
  docs:     "Docs",
  video:    "Video",
  test:     "Tests",
  other:    "Other",
};

// Generic viewer config — handles both old keys (github, demo) and URI-suffixed (repoURI, demoURI)
const EVIDENCE_FIELD_CONFIG: Record<string, { label: string; icon: React.ReactNode }> = {
  repoURI:     { label: "Repository",        icon: <Github size={14} /> },
  github:      { label: "Repository",        icon: <Github size={14} /> },
  contractURI: { label: "Deployed contract", icon: <FileCode size={14} /> },
  contract:    { label: "Deployed contract", icon: <FileCode size={14} /> },
  demoURI:     { label: "Live demo",         icon: <Globe size={14} /> },
  demo:        { label: "Live demo",         icon: <Globe size={14} /> },
  websiteURI:  { label: "Website",           icon: <Globe size={14} /> },
  projectURI:  { label: "Project page",      icon: <Monitor size={14} /> },
  videoURI:    { label: "Video",             icon: <Video size={14} /> },
  video:       { label: "Video",             icon: <Video size={14} /> },
  docsURI:     { label: "Documentation",     icon: <FileText size={14} /> },
  docs:        { label: "Documentation",     icon: <FileText size={14} /> },
  testURI:     { label: "Test results",      icon: <TestTube size={14} /> },
  test:        { label: "Test results",      icon: <TestTube size={14} /> },
  otherURI:    { label: "Other",             icon: <Monitor size={14} /> },
  other:       { label: "Other",             icon: <Monitor size={14} /> },
  summary:     { label: "Summary",           icon: <StickyNote size={14} /> },
  notes:       { label: "Notes",             icon: <StickyNote size={14} /> },
};

function isExternalUrl(value: string) {
  return value.startsWith("http://") || value.startsWith("https://");
}

// ─── Trail component ──────────────────────────────────────────────────────────

function ExecutionTrail({
  items,
  isScanning,
  derivedItems = [],
}: {
  items: GrantTrailItem[];
  isScanning: boolean;
  derivedItems?: GrantTrailItem[];
}) {
  // Real on-chain events take priority; fall back to state-derived while scanning.
  const isDerived = items.length === 0;
  const activeItems = isDerived ? derivedItems : items;

  if (activeItems.length === 0 && isScanning) {
    return (
      <div className="flex items-center gap-2 py-6 text-xs text-muted">
        <RefreshCw size={12} className="animate-spin" />
        Scanning on-chain events…
      </div>
    );
  }
  if (activeItems.length === 0 && !isScanning) {
    return (
      <p className="py-6 text-xs text-subtle">No on-chain events found for this round.</p>
    );
  }

  // Display newest first (reverse chronological)
  const display = [...activeItems].reverse();

  const dotColor: Record<GrantTrailItem["dot"], string> = {
    green: "bg-green",
    blue: "bg-blue",
    yellow: "bg-yellow",
    muted: "bg-subtle",
  };

  return (
    <div className={`relative${isDerived ? " opacity-70" : ""}`}>
      {/* Derived badge */}
      {isDerived && (
        <p className="mb-3 text-[10px] text-subtle">estimated from state · fetching on-chain data…</p>
      )}
      {/* Vertical line */}
      <div className="absolute left-[5px] top-2 bottom-2 w-px bg-border" />
      <div className="space-y-5">
        {display.map((item) => (
          <div key={item.key} className="relative flex gap-4">
            {/* Dot */}
            <div className={cn("relative z-10 mt-1 h-3 w-3 shrink-0 rounded-full ring-2 ring-surface-2", dotColor[item.dot])} />
            {/* Content */}
            <div className="flex min-w-0 flex-1 items-start justify-between gap-4">
              <div className="min-w-0">
                <p className="text-[13px] font-medium leading-tight text-text">{item.title}</p>
                {item.subtitle && (
                  <p className="mt-0.5 text-xs text-muted">{item.subtitle}</p>
                )}
                {item.txHash && (
                  <a
                    href={explorerTxUrl(item.txHash)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-0.5 inline-flex items-center gap-1 font-mono text-[10px] text-subtle hover:text-accent transition-colors"
                  >
                    {item.txHash.slice(0, 10)}…{item.txHash.slice(-6)}
                    <ExternalLink size={9} />
                  </a>
                )}
              </div>
              {item.blockNumber > 0n && (
                <div className="shrink-0 font-mono text-[11px] text-subtle">
                  #{item.blockNumber.toString()}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
      {isScanning && (
        <div className="mt-4 flex items-center gap-2 text-xs text-muted">
          <RefreshCw size={10} className="animate-spin" />
          {isDerived ? "Fetching on-chain events…" : "Scanning older blocks…"}
        </div>
      )}
    </div>
  );
}

// ─── Main detail component ────────────────────────────────────────────────────

export function GrantDetail({ roundId }: { roundId: bigint }) {
  const { address } = useAccount();
  const isDeployed = useGrantIsDeployed();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const { round, applications, isLoading, refetch } = useGrantRound(roundId);
  const refresh = useCallback(() => refetch(), [refetch]);

  // Auto-poll every 5 s while any application is in ScreeningRequested state
  const refreshRef = useRef(refresh);
  useEffect(() => { refreshRef.current = refresh; });
  const anyScreening = applications.some(
    (a) => a.application.status === ApplicationStatus.ScreeningRequested
  );
  useEffect(() => {
    if (!anyScreening) return;
    const id = setInterval(() => refreshRef.current(), 5000);
    return () => clearInterval(id);
  }, [anyScreening]);

  // Immediately hide apply form on submit before query refetch settles
  const [locallyApplied, setLocallyApplied] = useState(false);
  const handleApplySuccess = useCallback(() => {
    setLocallyApplied(true);
    refetch();
  }, [refetch]);

  const agentFee = useGrantAgentFee(round?.screeningMode ?? ScreeningMode.TwoAgent);

  const { items: trailItems, isScanning: trailScanning } = useGrantRoundTrail(roundId);
  const derivedTrailItems = round
    ? buildDerivedGrantTrail(round, roundId, applications)
    : [];

  // My application for this round — find by address in the refreshed list
  // (the separate applicationOf query can be stale right after submission)
  const myEntry = address
    ? applications.find((a) => a.application.applicant.toLowerCase() === address.toLowerCase())
    : null;
  const myApp: GrantApplication | null = myEntry?.application ?? null;
  const myAppId: bigint = myEntry?.id ?? 0n;

  // Pending withdrawal for sponsor
  const { data: pendingBalance, refetch: refetchPending } = useReadContract({
    ...grantRoundContract,
    functionName: "pendingWithdrawals",
    args: [address ?? "0x0000000000000000000000000000000000000000"],
    query: { enabled: isDeployed && !!address },
  });

  // Roles
  const isSponsor = !!address && !!round && round.sponsor.toLowerCase() === address.toLowerCase();
  const isJudge = !!address && !!round && round.judge.toLowerCase() === address.toLowerCase();
  const isRoundActor = isSponsor || isJudge;
  const isApplicant = !!myApp || myAppId > 0n;

  // Deadlines
  const now = Math.floor(Date.now() / 1000);
  const applicationDeadlinePassed = round ? now > round.applicationDeadline : false;
  const reviewDeadlinePassed = round ? now > round.reviewDeadline : false;
  const canApply = !!address && round?.state === RoundState.Open && !applicationDeadlinePassed && !isApplicant && !isRoundActor && !locallyApplied;
  const canSelectFinalists =
    isRoundActor &&
    (round?.state === RoundState.Open || round?.state === RoundState.Review) &&
    applicationDeadlinePassed &&
    !reviewDeadlinePassed;
  const canFinalize =
    isRoundActor &&
    (round?.state === RoundState.Open || round?.state === RoundState.Review) &&
    applicationDeadlinePassed;

  // Finalist selection state
  const [selectedIds, setSelectedIds] = useState<Set<bigint>>(new Set());

  // ── Write hooks ──────────────────────────────────────────────────────────────
  const { writeContract: fundWrite, data: fundTxHash, isPending: fundPending, error: fundError, reset: fundReset } = useWriteContract();
  const { isLoading: fundConfirming, isSuccess: fundSuccess } = useWaitForTransactionReceipt({ hash: fundTxHash });
  useEffect(() => { if (fundSuccess) refresh(); }, [fundSuccess, refresh]);

  const { writeContract: screenWrite, data: screenTxHash, isPending: screenPending, error: screenError, reset: screenReset } = useWriteContract();
  const { isLoading: screenConfirming, isSuccess: screenSuccess } = useWaitForTransactionReceipt({ hash: screenTxHash });

  // Show spinner for at least 4 s after tx confirms so the user always sees
  // "screening in progress" even when the agent responds instantly.
  const [screeningInProgress, setScreeningInProgress] = useState(false);
  useEffect(() => {
    if (!screenSuccess) return;
    setScreeningInProgress(true);
    refresh();
    const t = setTimeout(() => setScreeningInProgress(false), 4000);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [screenSuccess]); // intentionally omit refresh — its identity is unstable

  const { writeContract: selectWrite, data: selectTxHash, isPending: selectPending, error: selectError, reset: selectReset } = useWriteContract();
  const { isLoading: selectConfirming, isSuccess: selectSuccess } = useWaitForTransactionReceipt({ hash: selectTxHash });
  useEffect(() => { if (selectSuccess) { refresh(); setSelectedIds(new Set()); } }, [selectSuccess, refresh]);

  const { writeContract: finalizeWrite, data: finalizeTxHash, isPending: finalizePending, error: finalizeError, reset: finalizeReset } = useWriteContract();
  const { isLoading: finalizeConfirming, isSuccess: finalizeSuccess } = useWaitForTransactionReceipt({ hash: finalizeTxHash });
  useEffect(() => { if (finalizeSuccess) refresh(); }, [finalizeSuccess, refresh]);

  const { writeContract: claimWrite, data: claimTxHash, isPending: claimPending, error: claimError, reset: claimReset } = useWriteContract();
  const { isLoading: claimConfirming, isSuccess: claimSuccess } = useWaitForTransactionReceipt({ hash: claimTxHash });
  useEffect(() => { if (claimSuccess) refresh(); }, [claimSuccess, refresh]);

  const { writeContract: refundWrite, data: refundTxHash, isPending: refundPending, error: refundError, reset: refundReset } = useWriteContract();
  const { isLoading: refundConfirming, isSuccess: refundSuccess } = useWaitForTransactionReceipt({ hash: refundTxHash });
  useEffect(() => { if (refundSuccess) { refresh(); refetchPending(); } }, [refundSuccess, refresh, refetchPending]);

  const { writeContract: withdrawWrite, data: withdrawTxHash, isPending: withdrawPending, error: withdrawError, reset: withdrawReset } = useWriteContract();
  const { isLoading: withdrawConfirming, isSuccess: withdrawSuccess } = useWaitForTransactionReceipt({ hash: withdrawTxHash });
  useEffect(() => { if (withdrawSuccess) { refresh(); refetchPending(); } }, [withdrawSuccess, refresh, refetchPending]);

  // ── Render guards ────────────────────────────────────────────────────────────
  if (!isDeployed) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-10">
        <div className="rounded-xl border border-border bg-surface p-6 text-center text-sm text-muted">
          Grant contract address not configured.
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-10 space-y-4">
        <div className="h-10 w-64 animate-pulse rounded bg-surface-2" />
        <div className="grid grid-cols-4 gap-3">
          {[...Array(4)].map((_, i) => <div key={i} className="h-16 animate-pulse rounded-md bg-surface-2" />)}
        </div>
        <div className="h-48 animate-pulse rounded-xl bg-surface" />
      </div>
    );
  }

  if (!round || round.state === RoundState.None) {
    return (
      <div className="flex h-96 flex-col items-center justify-center gap-3 text-muted">
        <XCircle size={32} />
        <p>Grant #{roundId.toString()} not found</p>
        <Link href="/grants" className="text-sm text-accent hover:underline">← Back to grants</Link>
      </div>
    );
  }

  const reqMeta = parseRequirementsMeta(round.requirementsURI);
  const pool = round.prizeAmount * round.maxWinners;
  const allClaimed = round.claimedCount > 0n && round.claimedCount >= round.selectedCount;
  const eligibleForSelection = applications.filter(
    (a) =>
      !a.application.selected &&
      !a.application.claimed &&
      [
        ApplicationStatus.Submitted,
        ApplicationStatus.ScreeningRequested,
        ApplicationStatus.Complete,
        ApplicationStatus.NeedsReview,
        ApplicationStatus.VerificationFailed,
      ].includes(a.application.status)
  );
  const remainingSlots = Number(round.maxWinners) - Number(round.selectedCount);

  // Evidence type chips from criteria
  const evidenceTypes: CriterionType[] = reqMeta?.criteria
    ? [...new Set(reqMeta.criteria.map((c) => c.type))]
    : [];

  // Determine if there are any actions to show
  const sponsorOpenState = isSponsor && round.state === RoundState.Open;
  const hasActions =
    mounted &&
    (canApply ||
      locallyApplied ||
      (isApplicant && myApp) ||
      canFinalize ||
      sponsorOpenState ||
      (round.state === RoundState.Created && isSponsor) ||
      (round.state === RoundState.Finalized && isSponsor && round.selectedCount < round.maxWinners) ||
      (pendingBalance != null && (pendingBalance as bigint) > 0n));

  return (
    <div className="mx-auto max-w-5xl px-4 py-10 fade-in space-y-6">

      {/* ── 1. Header ──────────────────────────────────────────────────────────── */}
      <div>
        <Link
          href="/grants"
          className="mb-4 inline-flex items-center gap-1 text-sm text-muted hover:text-text transition-colors"
        >
          <ArrowLeft size={14} /> Back
        </Link>
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-bold text-text">
                {reqMeta?.title ?? `Grant #${roundId.toString()}`}
              </h1>
              <RoundStatePill state={round.state} deadlinePassed={applicationDeadlinePassed} />
            </div>
            <p className="mt-1 font-mono text-xs text-subtle">Grant #{roundId.toString()}</p>
          </div>
          <div className="text-right">
            <div className="font-mono text-3xl font-bold text-text">{formatSTT(pool)}</div>
            <div className="mt-0.5 text-xs text-muted">
              {formatSTT(round.prizeAmount)} × {round.maxWinners.toString()} winners
              {round.state === RoundState.Finalized && allClaimed && (
                <span className="ml-1 text-green">· fully distributed</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* ── 2. Metric cards ────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-md bg-surface-2 px-4 py-3">
          <div className="text-xs text-muted">Applications</div>
          <div className="mt-1 font-mono text-xl font-bold text-text">
            {round.applicationsCount.toString()}
          </div>
        </div>
        <div className="rounded-md bg-surface-2 px-4 py-3">
          <div className="text-xs text-muted">Selected</div>
          <div className={cn(
            "mt-1 font-mono text-xl font-bold",
            round.selectedCount >= round.maxWinners ? "text-green" : "text-text"
          )}>
            {round.selectedCount.toString()}
            <span className="ml-1 text-sm font-normal text-subtle">/ {round.maxWinners.toString()}</span>
          </div>
        </div>
        <div className="rounded-md bg-surface-2 px-4 py-3">
          <div className="text-xs text-muted">Claimed</div>
          <div className={cn(
            "mt-1 font-mono text-xl font-bold",
            allClaimed ? "text-green" : "text-text"
          )}>
            {round.claimedCount.toString()}
            <span className="ml-1 text-sm font-normal text-subtle">/ {round.selectedCount.toString()}</span>
          </div>
        </div>
        <div className="rounded-md bg-surface-2 px-4 py-3">
          <div className="text-xs text-muted">Screening</div>
          <div className="mt-1 text-sm font-semibold text-text">
            {SCREENING_MODE_LABEL[round.screeningMode]}
          </div>
        </div>
      </div>

      {/* ── 3. Two-column info row ─────────────────────────────────────────────── */}
      <div className="grid gap-4 md:grid-cols-2">
        {/* Left: Round info */}
        <div className="rounded-xl border border-border bg-surface p-5">
          <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">Grant Info</h3>
          <div className="divide-y divide-border">
            {[
              { label: "Sponsor", addr: round.sponsor, isYou: isSponsor },
              { label: "Judge", addr: round.judge, isYou: isJudge },
            ].map(({ label, addr, isYou }) => (
              <div key={label} className="flex items-center justify-between py-2">
                <span className="text-xs text-muted">{label}</span>
                <div className="flex items-center gap-2">
                  {isYou && (
                    <span className="rounded border border-accent/30 bg-accent/10 px-1.5 py-0.5 text-[10px] font-bold text-accent">YOU</span>
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
            <div className="flex items-center justify-between py-2">
              <span className="text-xs text-muted">Contract</span>
              <a
                href={explorerAddressUrl(VIGILIA_GRANT_ROUND_ADDRESS)}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 font-mono text-xs text-muted hover:text-accent transition-colors"
              >
                {truncateAddress(VIGILIA_GRANT_ROUND_ADDRESS)}
                <ExternalLink size={9} />
              </a>
            </div>
            <div className="flex items-center justify-between py-2">
              <span className="text-xs text-muted">App deadline</span>
              <span className="font-mono text-xs text-muted">
                {formatTimestamp(round.applicationDeadline)}
                {applicationDeadlinePassed && <span className="ml-1 text-subtle">· passed</span>}
              </span>
            </div>
            <div className="flex items-center justify-between py-2">
              <span className="text-xs text-muted">Review deadline</span>
              <span className="font-mono text-xs text-muted">
                {formatTimestamp(round.reviewDeadline)}
                {reviewDeadlinePassed && <span className="ml-1 text-subtle">· passed</span>}
              </span>
            </div>
          </div>
        </div>

        {/* Right: Requirements */}
        <div className="rounded-xl border border-border bg-surface p-5">
          <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">Requirements</h3>
          {reqMeta?.description ? (
            <p className="mb-4 text-sm text-muted leading-relaxed">{reqMeta.description}</p>
          ) : (
            <p className="mb-4 text-sm text-subtle italic">No description available.</p>
          )}
          {evidenceTypes.length > 0 && (
            <div className="mb-4 flex flex-wrap gap-2">
              {evidenceTypes.map((type) => (
                <span
                  key={type}
                  className="inline-flex items-center gap-1.5 rounded bg-surface-2 px-2 py-1 font-mono text-xs text-muted"
                >
                  {EVIDENCE_ICONS[type] ?? <FileText size={11} />}
                  {EVIDENCE_LABELS[type] ?? type}
                </span>
              ))}
            </div>
          )}
          {round.requirementsURI && isExternalUrl(round.requirementsURI) && (
            <a
              href={round.requirementsURI}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 text-xs text-accent hover:underline"
            >
              View full requirements <ExternalLink size={10} />
            </a>
          )}
        </div>
      </div>

      {/* ── 4. Connect wallet prompt (open grant, no wallet) ─────────────────── */}
      {mounted && !address && round.state === RoundState.Open && !applicationDeadlinePassed && (
        <div className="rounded-xl border border-border bg-surface px-5 py-4 flex items-center justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-text">This grant is accepting applications</p>
            <p className="mt-0.5 text-xs text-muted">Connect your wallet to apply</p>
          </div>
          <span className="shrink-0 rounded border border-border px-3 py-1.5 text-xs text-muted">
            Wallet required
          </span>
        </div>
      )}

      {/* ── 4. Actions (context-aware, only shown when relevant) ────────────── */}
      {hasActions && (
        <div className="rounded-xl border border-border bg-surface p-5">
          <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-muted">Actions</h3>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">

            {/* CREATED → sponsor funds */}
            {round.state === RoundState.Created && isSponsor && (
              <div className="space-y-2">
                <p className="text-xs text-muted">Deposit {formatSTT(pool)} to open the grant for applications.</p>
                <TxButton
                  onClick={() => { fundReset(); fundWrite({ ...grantRoundContract, functionName: "fundRound", args: [roundId], value: pool }); }}
                  loading={fundPending}
                  confirming={fundConfirming}
                  className="w-full"
                >
                  {fundConfirming ? "Confirming…" : `Fund ${formatSTT(pool)}`}
                </TxButton>
                <TxStatus error={fundError} txHash={fundTxHash} />
              </div>
            )}

            {/* OPEN → sponsor overview */}
            {sponsorOpenState && (
              <div className="space-y-2 rounded-lg border border-green/20 bg-green/5 p-4">
                <div className="flex items-center gap-2 text-xs font-semibold text-green uppercase tracking-wider">
                  <span className="h-1.5 w-1.5 rounded-full bg-green" />
                  Grant is Live
                </div>
                <p className="text-xs text-muted">
                  Accepting applications until{" "}
                  <span className="text-text font-medium">
                    {formatTimestamp(round.applicationDeadline)}
                  </span>
                  . After the deadline, select finalists from the table below and finalize the grant.
                </p>
                <div className="flex items-center gap-1 text-xs text-muted">
                  <span className="font-mono font-semibold text-text">{applications.length}</span> application{applications.length !== 1 ? "s" : ""} received
                </div>
              </div>
            )}

            {/* OPEN → applicant applies */}
            {canApply && (
              <div className="space-y-2">
                <p className="text-xs text-muted">Grant is open — submit your application.</p>
                <SubmitApplicationPanel roundId={roundId} requirementsURI={round.requirementsURI} onSuccess={handleApplySuccess} screeningMode={round.screeningMode} />
              </div>
            )}

            {/* My application */}
            {isApplicant && myApp && (
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs text-muted">My App #{myAppId.toString()}</span>
                  <AppStatusPill status={myApp.status} />
                </div>

                {myApp.status === ApplicationStatus.Submitted && round.state === RoundState.Open && (
                  <>
                    {agentFee != null && agentFee > 0n && (
                      <div className="flex items-center justify-between rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-muted">
                        <span>Screening fee</span>
                        <span className="font-mono font-semibold text-yellow">{formatEther(agentFee)} STT</span>
                      </div>
                    )}
                    <TxButton
                      onClick={() => { screenReset(); screenWrite({ ...grantRoundContract, functionName: "requestApplicationScreening", args: [myAppId], value: agentFee ?? 0n }); }}
                      loading={screenPending}
                      confirming={screenConfirming}
                      className="w-full"
                    >
                      {screenConfirming ? "Confirming…" : "Request Screening"}
                    </TxButton>
                    <TxStatus error={screenError} txHash={screenTxHash} />
                  </>
                )}

                {(myApp.status === ApplicationStatus.ScreeningRequested || screeningInProgress) && (
                  <div className="flex items-center gap-2 rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-yellow">
                    <RefreshCw size={12} className="animate-spin shrink-0" />
                    Somnia agents screening your application…
                  </div>
                )}

                {myApp.status === ApplicationStatus.VerificationFailed &&
                  !screeningInProgress &&
                  round.state === RoundState.Open &&
                  !applicationDeadlinePassed && (
                  <>
                    <div className="rounded border border-red/20 bg-red/5 px-3 py-2 text-xs text-red">
                      <p>Verification failed — inspect your evidence before retrying.</p>
                      {myApp.evidenceURI && (
                        <div className="mt-2">
                          <EvidenceViewer evidenceURI={myApp.evidenceURI} appId={myAppId} failed />
                        </div>
                      )}
                    </div>
                    {agentFee != null && agentFee > 0n && (
                      <div className="flex items-center justify-between rounded border border-yellow/20 bg-yellow/5 px-3 py-2 text-xs text-muted">
                        <span>Retry fee</span>
                        <span className="font-mono font-semibold text-yellow">{formatEther(agentFee)} STT</span>
                      </div>
                    )}
                    <TxButton
                      onClick={() => { screenReset(); screenWrite({ ...grantRoundContract, functionName: "requestApplicationScreening", args: [myAppId], value: agentFee ?? 0n }); }}
                      loading={screenPending}
                      confirming={screenConfirming}
                      className="w-full"
                    >
                      {screenConfirming ? "Confirming…" : "Retry Verification"}
                    </TxButton>
                    <TxStatus error={screenError} txHash={screenTxHash} />
                  </>
                )}

                {myApp.verdict !== VerificationVerdict.Unknown && (
                  <div className="flex items-center justify-between rounded border border-border px-3 py-2 text-xs">
                    <span className="text-muted">Agent verdict</span>
                    <span className={cn("font-mono font-semibold",
                      myApp.verdict === VerificationVerdict.Complete ? "text-green" :
                      myApp.verdict === VerificationVerdict.NeedsReview ? "text-yellow" : "text-red"
                    )}>
                      {VERDICT_LABEL[myApp.verdict]}
                    </span>
                  </div>
                )}

                {myApp.status === ApplicationStatus.Selected && round.state === RoundState.Finalized && (
                  <>
                    <p className="text-xs text-green">Selected as finalist — claim your prize.</p>
                    <TxButton
                      onClick={() => { claimReset(); claimWrite({ ...grantRoundContract, functionName: "claimPrize", args: [myAppId] }); }}
                      loading={claimPending}
                      confirming={claimConfirming}
                      className="w-full"
                    >
                      {claimConfirming ? "Confirming…" : `Claim ${formatSTT(round.prizeAmount)}`}
                    </TxButton>
                    <TxStatus error={claimError} txHash={claimTxHash} />
                  </>
                )}

                {myApp.status === ApplicationStatus.Claimed && (
                  <div className="rounded border border-green/30 bg-green/10 px-3 py-2 text-xs text-green">
                    Prize claimed. Congratulations!
                  </div>
                )}
              </div>
            )}

            {/* Sponsor / judge: finalize */}
            {canFinalize && (
              <div className="space-y-2">
                <p className="text-xs text-muted">Application deadline passed — finalize the grant to unlock claims.</p>
                <TxButton
                  variant="secondary"
                  onClick={() => { finalizeReset(); finalizeWrite({ ...grantRoundContract, functionName: "finalizeRound", args: [roundId] }); }}
                  loading={finalizePending}
                  confirming={finalizeConfirming}
                  className="w-full"
                >
                  {finalizeConfirming ? "Confirming…" : "Finalize Grant"}
                </TxButton>
                <TxStatus error={finalizeError} txHash={finalizeTxHash} />
              </div>
            )}

            {/* Sponsor: refund unallocated */}
            {round.state === RoundState.Finalized && isSponsor && round.selectedCount < round.maxWinners && (
              <div className="space-y-2">
                <p className="text-xs text-muted">
                  {Number(round.maxWinners) - Number(round.selectedCount)} prize slot(s) unused. Reclaim unallocated pool.
                </p>
                <TxButton
                  variant="secondary"
                  onClick={() => { refundReset(); refundWrite({ ...grantRoundContract, functionName: "refundUnallocated", args: [roundId] }); }}
                  loading={refundPending}
                  confirming={refundConfirming}
                  className="w-full"
                >
                  {refundConfirming ? "Confirming…" : "Refund Unallocated"}
                </TxButton>
                <TxStatus error={refundError} txHash={refundTxHash} />
              </div>
            )}

            {/* Pending withdrawal */}
            {pendingBalance != null && (pendingBalance as bigint) > 0n && (
              <div className="space-y-2">
                <div className="text-sm font-semibold text-green">{formatSTT(pendingBalance as bigint)} available</div>
                <TxButton
                  onClick={() => { withdrawReset(); withdrawWrite({ ...grantRoundContract, functionName: "withdrawPending" }); }}
                  loading={withdrawPending}
                  confirming={withdrawConfirming}
                  className="w-full"
                >
                  Withdraw
                </TxButton>
                <TxStatus error={withdrawError} txHash={withdrawTxHash} />
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── 5. Applications table ─────────────────────────────────────────────── */}
      {applications.length > 0 && (
        <div className="rounded-xl border border-border bg-surface overflow-hidden">
          <div className="border-b border-border px-5 py-3 flex items-center justify-between">
            <h3 className="text-xs font-semibold uppercase tracking-wider text-muted">Applications</h3>
            <span className="text-xs text-subtle">{applications.length} total</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border">
                  {canSelectFinalists && <th className="w-8 px-4 py-2.5" />}
                  <th className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wider text-muted">ID</th>
                  <th className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wider text-muted">Applicant</th>
                  <th className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wider text-muted">Status</th>
                  <th className="hidden px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wider text-muted sm:table-cell">Agent verdict</th>
                  <th className="hidden px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wider text-muted md:table-cell">Prize</th>
                  <th className="px-4 py-2.5 text-right text-xs font-semibold uppercase tracking-wider text-muted">Evidence</th>
                </tr>
              </thead>
              <tbody>
                {applications.map(({ id, application: app }) => {
                  const isMe = address && app.applicant.toLowerCase() === address.toLowerCase();
                  const isEligible = eligibleForSelection.some((a) => a.id === id);
                  return (
                    <tr key={id.toString()} className="border-b border-border/40 last:border-0 hover:bg-surface-2 transition-colors">
                      {canSelectFinalists && (
                        <td className="px-4 py-3">
                          {isEligible && (
                            <input
                              type="checkbox"
                              checked={selectedIds.has(id)}
                              onChange={(e) => {
                                setSelectedIds((prev) => {
                                  const next = new Set(prev);
                                  if (e.target.checked) next.add(id); else next.delete(id);
                                  return next;
                                });
                              }}
                              className="cursor-pointer accent-accent"
                            />
                          )}
                        </td>
                      )}
                      <td className="px-4 py-3">
                        <span className="font-mono text-xs text-muted">#{id.toString()}</span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          {isMe && (
                            <span className="rounded border border-accent/30 bg-accent/10 px-1.5 py-0.5 text-[10px] font-bold text-accent">YOU</span>
                          )}
                          <a
                            href={explorerAddressUrl(app.applicant)}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="font-mono text-xs text-muted hover:text-text transition-colors"
                          >
                            {truncateAddress(app.applicant)}
                          </a>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <AppStatusPill status={app.status} />
                      </td>
                      <td className="hidden px-4 py-3 sm:table-cell">
                        {app.verdict !== VerificationVerdict.Unknown ? (
                          <span className={cn(
                            "font-mono text-xs font-semibold",
                            app.verdict === VerificationVerdict.Complete ? "text-green" :
                            app.verdict === VerificationVerdict.NeedsReview ? "text-yellow" : "text-red"
                          )}>
                            {VERDICT_LABEL[app.verdict]}
                          </span>
                        ) : (
                          <span className="text-xs text-subtle">—</span>
                        )}
                      </td>
                      <td className="hidden px-4 py-3 md:table-cell">
                        {app.claimed ? (
                          <span className="font-mono text-xs text-green">{formatSTT(round.prizeAmount)}</span>
                        ) : (
                          <span className="text-xs text-subtle">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center justify-end gap-2">
                          {isMe &&
                            round.state === RoundState.Open &&
                            !applicationDeadlinePassed &&
                            app.status === ApplicationStatus.Submitted && (
                              <SubmitApplicationPanel
                                roundId={roundId}
                                requirementsURI={round.requirementsURI}
                                onSuccess={refresh}
                                mode="edit"
                                initialEvidenceURI={app.evidenceURI}
                                screeningMode={round.screeningMode}
                              />
                          )}
                          {app.evidenceURI && (
                      <EvidenceViewer
                        evidenceURI={app.evidenceURI}
                        appId={id}
                        failed={app.status === ApplicationStatus.VerificationFailed}
                      />
                    )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Select finalists action row */}
          {canSelectFinalists && selectedIds.size > 0 && (
            <div className="border-t border-border px-4 py-3 flex items-center justify-between bg-surface-2">
              <span className="text-xs text-muted">
                {selectedIds.size} selected · {remainingSlots} slot{remainingSlots !== 1 ? "s" : ""} remaining
              </span>
              <div className="flex items-center gap-2">
                <TxStatus error={selectError} txHash={selectTxHash} />
                <TxButton
                  onClick={() => { selectReset(); selectWrite({ ...grantRoundContract, functionName: "selectFinalists", args: [roundId, Array.from(selectedIds)] }); }}
                  loading={selectPending}
                  confirming={selectConfirming}
                  disabled={selectedIds.size > remainingSlots}
                >
                  {selectConfirming ? "Confirming…" : `Select ${selectedIds.size} Finalist${selectedIds.size !== 1 ? "s" : ""}`}
                </TxButton>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── 6. Agent Screening Activity (TODO: re-enable) ───────────────────────── */}
      {false && (() => {
        const screened = applications.filter(
          ({ application: app }) => app.status >= ApplicationStatus.ScreeningRequested
        );
        if (screened.length === 0) return null;

        const complete = screened.filter(({ application: app }) => app.verdict === VerificationVerdict.Complete).length;
        const needsReview = screened.filter(({ application: app }) => app.verdict === VerificationVerdict.NeedsReview).length;
        const incomplete = screened.filter(({ application: app }) => app.verdict === VerificationVerdict.Incomplete).length;
        const pending = screened.filter(({ application: app }) => app.status === ApplicationStatus.ScreeningRequested).length;

        return (
          <div className="rounded-xl border border-border bg-surface p-5">
            <div className="mb-4 flex items-center gap-2">
              <Cpu size={14} className="text-muted" />
              <h3 className="text-xs font-semibold uppercase tracking-wider text-muted">Agent Screening</h3>
            </div>

            {/* Stats */}
            <div className="mb-5 grid grid-cols-4 gap-2">
              {[
                { label: "Screened", value: screened.length, color: "text-text" },
                { label: "Complete", value: complete, color: complete > 0 ? "text-green" : "text-subtle" },
                { label: "Needs Review", value: needsReview, color: needsReview > 0 ? "text-yellow" : "text-subtle" },
                { label: "Incomplete", value: incomplete, color: incomplete > 0 ? "text-red" : "text-subtle" },
              ].map(({ label, value, color }) => (
                <div key={label} className="rounded-md bg-surface-2 px-3 py-2 text-center">
                  <div className={cn("font-mono text-xl font-bold", color)}>{value}</div>
                  <div className="mt-0.5 text-[10px] text-muted">{label}</div>
                </div>
              ))}
            </div>

            {/* Per-application verdict list */}
            <div className="divide-y divide-border/50 rounded-lg border border-border overflow-hidden">
              {screened.map(({ id, application: app }) => {
                const isMe = address && app.applicant.toLowerCase() === address.toLowerCase();
                const verdictColor =
                  app.verdict === VerificationVerdict.Complete ? "text-green" :
                  app.verdict === VerificationVerdict.NeedsReview ? "text-yellow" :
                  app.verdict === VerificationVerdict.Incomplete ? "text-red" :
                  "text-muted";
                return (
                  <div key={id.toString()} className="flex items-center justify-between px-4 py-2.5 hover:bg-surface-2 transition-colors">
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-xs text-subtle">#{id.toString()}</span>
                      {isMe && (
                        <span className="rounded border border-accent/30 bg-accent/10 px-1.5 py-0.5 text-[9px] font-bold text-accent">YOU</span>
                      )}
                      <a
                        href={explorerAddressUrl(app.applicant)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="font-mono text-xs text-muted hover:text-text transition-colors"
                      >
                        {truncateAddress(app.applicant)}
                      </a>
                    </div>
                    {app.verdict !== VerificationVerdict.Unknown ? (
                      <span className={cn("font-mono text-xs font-semibold", verdictColor)}>
                        {VERDICT_LABEL[app.verdict]}
                      </span>
                    ) : app.status === ApplicationStatus.ScreeningRequested ? (
                      <span className="flex items-center gap-1.5 text-xs text-yellow">
                        <RefreshCw size={10} className="animate-spin" />
                        Screening…
                      </span>
                    ) : app.status === ApplicationStatus.VerificationFailed ? (
                      <span className="font-mono text-xs font-semibold text-red">Failed</span>
                    ) : (
                      <span className="text-xs text-subtle">—</span>
                    )}
                  </div>
                );
              })}
            </div>

            {pending > 0 && (
              <p className="mt-3 text-[11px] text-muted">
                {pending} application{pending !== 1 ? "s" : ""} screening in progress
              </p>
            )}
          </div>
        );
      })(/* TODO: re-enable agent screening panel */)}

      {/* ── 7. Execution Trail ────────────────────────────────────────────────── */}
      <div className="rounded-xl border border-border bg-surface p-5">
        <h3 className="mb-5 text-xs font-semibold uppercase tracking-wider text-muted">Execution Trail</h3>
        <ExecutionTrail items={trailItems} isScanning={trailScanning} derivedItems={derivedTrailItems} />
      </div>

    </div>
  );
}

// ─── Evidence viewer modal (generic — reads any JSON key) ────────────────────

// ─── Evidence fetch hook ──────────────────────────────────────────────────────

function useEvidenceFetch(uri: string, enabled: boolean) {
  const [data, setData] = useState<Record<string, string> | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!enabled || !isExternalUrl(uri)) return;
    let cancelled = false;
    setLoading(true);
    setError(null);
    setData(null);
    fetch(uri)
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((json) => {
        if (!cancelled && json && typeof json === "object" && !Array.isArray(json))
          setData(json as Record<string, string>);
      })
      .catch((e: unknown) => {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [uri, enabled]);

  return { data, loading, error };
}

// ─── Evidence field diagnostics (shown on VerificationFailed) ─────────────────

function evidenceDiagnostics(parsed: Record<string, string>): string[] {
  const warnings: string[] = [];
  const facts = parsed.facts ?? "";

  if (parsed.repoURI) {
    const isGh = /^https:\/\/github\.com\/[^/]+\/[^/]+/.test(parsed.repoURI);
    if (!isGh) warnings.push(`repoURI is not a valid GitHub URL — repo_exists=true won't hold`);
  }
  if (parsed.contractURI && !/^0x[0-9a-fA-F]{40}$/.test(parsed.contractURI) && !isExternalUrl(parsed.contractURI)) {
    warnings.push(`contractURI is neither a valid 0x address nor a URL`);
  }
  const urlFields = ["demoURI", "videoURI", "docsURI", "testURI", "websiteURI"];
  const placeholders = urlFields.filter((k) => {
    const v = parsed[k];
    return v && /^https?:\/\/(www\.)?google\.com/.test(v);
  });
  if (placeholders.length > 0)
    warnings.push(`${placeholders.join(", ")} point to google.com — agent will not accept these as valid project URLs`);

  if (facts) {
    const claimed = facts.split(";").map((f) => f.trim()).filter(Boolean);
    const repoOk = parsed.repoURI && /^https:\/\/github\.com\/[^/]+\/[^/]+/.test(parsed.repoURI);
    if (claimed.includes("repo_exists=true") && !repoOk)
      warnings.push(`facts claim repo_exists=true but repoURI is invalid`);
    if (claimed.includes("website_present=true") && !isExternalUrl(parsed.websiteURI ?? ""))
      warnings.push(`facts claim website_present=true but websiteURI is missing or invalid`);
  }
  return warnings;
}

// ─── Evidence viewer modal ────────────────────────────────────────────────────

function EvidenceViewer({
  evidenceURI,
  appId,
  failed = false,
}: {
  evidenceURI: string;
  appId: bigint;
  failed?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [mounted, setMounted] = useState(false);
  const [showFacts, setShowFacts] = useState(false);
  useEffect(() => setMounted(true), []);

  useEffect(() => {
    if (!open) { setShowFacts(false); return; }
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [open]);

  // If evidenceURI is an external URL, fetch the JSON from it.
  // Otherwise try to parse it directly (legacy inline JSON).
  const isUrl = isExternalUrl(evidenceURI);
  const { data: fetched, loading: fetching, error: fetchError } = useEvidenceFetch(evidenceURI, open && isUrl);

  let inlineParsed: Record<string, string> | null = null;
  if (!isUrl) {
    try {
      const p = JSON.parse(evidenceURI);
      if (p && typeof p === "object" && !Array.isArray(p)) inlineParsed = p as Record<string, string>;
    } catch {}
  }

  const parsed = fetched ?? inlineParsed;
  const warnings = parsed ? evidenceDiagnostics(parsed) : [];

  const allEntries = parsed ? Object.entries(parsed) : [];
  const factsEntry = allEntries.find(([k]) => k === "facts");
  const mainEntries = allEntries.filter(([k]) => k !== "facts");
  const sorted = [
    ...mainEntries.filter(([, v]) => isExternalUrl(v)),
    ...mainEntries.filter(([, v]) => !isExternalUrl(v)),
  ];

  const modal = open && mounted && createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      onClick={(e) => { if (e.target === e.currentTarget) setOpen(false); }}
    >
      <div className="absolute inset-0 bg-black/60" />
      <div className="relative flex max-h-[90vh] w-full max-w-md flex-col rounded-lg border border-border bg-surface shadow-xl">
        <div className="flex shrink-0 items-center justify-between border-b border-border px-5 py-4">
          <div>
            <h2 className="text-sm font-semibold text-text">Evidence</h2>
            <p className="mt-0.5 font-mono text-[10px] text-muted">Application #{appId.toString()}</p>
          </div>
          <div className="flex items-center gap-3">
            {isUrl && (
              <a href={evidenceURI} target="_blank" rel="noopener noreferrer"
                className="inline-flex items-center gap-1 text-xs text-muted hover:text-accent transition-colors"
                title="Open raw JSON">
                <ExternalLink size={12} />
                Raw
              </a>
            )}
            <button type="button" onClick={() => setOpen(false)} className="text-muted hover:text-text transition-colors">
              <X size={16} />
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-5">
          {/* Diagnostic warnings (shown when VerificationFailed) */}
          {failed && warnings.length > 0 && (
            <div className="mb-4 rounded border border-red/20 bg-red/5 p-3 space-y-1">
              <p className="text-[10px] font-semibold uppercase tracking-wider text-red">Likely issues</p>
              {warnings.map((w, i) => (
                <p key={i} className="text-xs text-red/80">· {w}</p>
              ))}
            </div>
          )}

          {fetching && (
            <div className="flex items-center gap-2 py-4 text-xs text-muted">
              <RefreshCw size={12} className="animate-spin" />
              Fetching evidence…
            </div>
          )}

          {fetchError && (
            <div className="rounded border border-red/20 bg-red/5 px-3 py-2 text-xs text-red">
              Could not fetch evidence: {fetchError}
            </div>
          )}

          {!fetching && !fetchError && !parsed && isUrl && (
            <div className="space-y-2">
              <p className="text-xs text-muted">Evidence URL:</p>
              <a href={evidenceURI} target="_blank" rel="noopener noreferrer"
                className="block break-all rounded border border-border bg-surface-2 px-3 py-2 font-mono text-xs text-accent hover:underline">
                {evidenceURI}
              </a>
            </div>
          )}

          {!fetching && !isUrl && !parsed && (
            <pre className="break-all rounded border border-border bg-surface-2 px-3 py-2 font-mono text-xs text-muted whitespace-pre-wrap">
              {evidenceURI}
            </pre>
          )}

          {parsed && sorted.length === 0 && !factsEntry && (
            <p className="text-xs text-subtle">No evidence fields found.</p>
          )}

          {parsed && (
            <div className="space-y-0.5">
              {sorted.map(([key, value]) => {
                const cfg = EVIDENCE_FIELD_CONFIG[key];
                const label = cfg?.label ?? key;
                const icon = cfg?.icon ?? <ExternalLink size={14} />;
                const asUrl = isExternalUrl(value);
                return (
                  <div key={key} className="flex items-start gap-3 rounded-md px-3 py-2.5 hover:bg-surface-2 transition-colors">
                    <div className="mt-0.5 shrink-0 text-muted">{icon}</div>
                    <div className="min-w-0 flex-1">
                      <div className="mb-0.5 text-[10px] font-semibold uppercase tracking-wider text-subtle">{label}</div>
                      {asUrl ? (
                        <a href={value} target="_blank" rel="noopener noreferrer"
                          className="break-all text-xs text-accent hover:underline">
                          {value}
                        </a>
                      ) : (
                        <p className="text-xs text-text leading-relaxed whitespace-pre-wrap">{value}</p>
                      )}
                    </div>
                  </div>
                );
              })}

              {factsEntry && (
                <div className="mt-2 border-t border-border pt-2">
                  <button
                    type="button"
                    onClick={() => setShowFacts((v) => !v)}
                    className="flex w-full items-center justify-between rounded px-3 py-2 text-xs text-muted hover:bg-surface-2 hover:text-text transition-colors"
                  >
                    <span className="flex items-center gap-2">
                      <FileText size={12} />
                      Agent facts
                    </span>
                    <span className="font-mono text-[10px]">{showFacts ? "▲" : "▼"}</span>
                  </button>
                  {showFacts && (
                    <div className="mx-3 mb-1 rounded border border-border bg-surface-2 px-3 py-2">
                      {factsEntry[1].split(";").map((f, i) => (
                        <div key={i} className="font-mono text-[11px] text-muted">{f.trim()}</div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>,
    document.body
  );

  return (
    <>
      <button type="button" onClick={() => setOpen(true)}
        className={cn(
          "inline-flex items-center gap-1 text-xs hover:underline transition-colors",
          failed ? "text-red/80 hover:text-red" : "text-accent"
        )}>
        <ExternalLink size={10} />
        {failed ? "Inspect evidence" : "Evidence"}
      </button>
      {modal}
    </>
  );
}
