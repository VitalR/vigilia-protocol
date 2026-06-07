"use client";

import {
  AlertTriangle,
  ArrowRight,
  CheckCircle,
  ChevronRight,
  ExternalLink,
  Play,
  RefreshCw,
  RotateCcw,
  XCircle,
} from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

// ─── Demo scenario data ───────────────────────────────────────────────────────

const MOCK_TASK = {
  id: 42,
  client: "0xA1B2…C3D4",
  contractor: "0xE5F6…7890",
  resolver: "0xDEAD…BEEF",
  amount: "2.5 STT",
  requirementsURI: "https://github.com/somnia-labs/bridge-v2/issues/88",
  reviewWindow: "24h",
  submissionId: 117,
  evidenceURI: "https://github.com/somnia-labs/bridge-v2/pull/91",
  txHashes: {
    create: "0x1a2b3c…",
    fund: "0x4d5e6f…",
    submit: "0x7a8b9c…",
    verdict: "0xabcdef…",
    claim: "0x123456…",
  },
};

// ─── State machine ────────────────────────────────────────────────────────────

type DemoState =
  | "idle"
  | "created"
  | "funded"
  | "submitted"
  | "verifying"
  | "verdict"
  | "approved"
  | "claimed";

type TimelineEntry = {
  state: DemoState;
  label: string;
  sublabel: string;
  icon: React.ReactNode;
  colorClass: string;
  ts: string;
  txHash?: string;
};

const TIMELINE_META: Record<
  DemoState,
  Omit<TimelineEntry, "state" | "ts">
> = {
  idle: {
    label: "Waiting",
    sublabel: "",
    icon: null,
    colorClass: "text-muted",
  },
  created: {
    label: "Milestone created",
    sublabel: `Client defined requirements and assigned contractor`,
    icon: <span className="text-blue">✦</span>,
    colorClass: "text-blue",
    txHash: MOCK_TASK.txHashes.create,
  },
  funded: {
    label: `${MOCK_TASK.amount} locked in escrow`,
    sublabel: "Funds held by contract — no one can move them unilaterally",
    icon: <span className="text-blue">💰</span>,
    colorClass: "text-blue",
    txHash: MOCK_TASK.txHashes.fund,
  },
  submitted: {
    label: "Evidence submitted",
    sublabel: `Contractor posted GitHub PR as public evidence`,
    icon: <span className="text-yellow">📋</span>,
    colorClass: "text-yellow",
    txHash: MOCK_TASK.txHashes.submit,
  },
  verifying: {
    label: "Somnia agent verifying…",
    sublabel: "Agent fetching evidence URL, checking against requirements",
    icon: <span className="text-yellow">🤖</span>,
    colorClass: "text-yellow",
  },
  verdict: {
    label: "Verdict: Complete",
    sublabel: "Agent classified evidence as satisfying all requirements",
    icon: <CheckCircle size={14} className="text-green" />,
    colorClass: "text-green",
    txHash: MOCK_TASK.txHashes.verdict,
  },
  approved: {
    label: "Client approved early",
    sublabel: "Skipped review window — contractor can claim immediately",
    icon: <CheckCircle size={14} className="text-green" />,
    colorClass: "text-green",
  },
  claimed: {
    label: `${MOCK_TASK.amount} paid to contractor`,
    sublabel: "Pull-based settlement — contractor triggered the final transfer",
    icon: <span className="text-green">💸</span>,
    colorClass: "text-green",
    txHash: MOCK_TASK.txHashes.claim,
  },
};

const FLOW: DemoState[] = [
  "created",
  "funded",
  "submitted",
  "verifying",
  "verdict",
  "approved",
  "claimed",
];

const DELAYS: Partial<Record<DemoState, number>> = {
  verifying: 2800,
  verdict: 1200,
  approved: 900,
  claimed: 900,
};

// ─── Sub-components ───────────────────────────────────────────────────────────

function AgentAnimation({ active }: { active: boolean }) {
  const [dot, setDot] = useState(0);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    if (!active) { setProgress(0); return; }
    const dotTimer = setInterval(() => setDot((d) => (d + 1) % 4), 420);
    const startTime = Date.now();
    const progTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      setProgress(Math.min(95, (elapsed / 2800) * 95));
    }, 60);
    return () => { clearInterval(dotTimer); clearInterval(progTimer); };
  }, [active]);

  const checks = [
    "Fetching evidence URL",
    "Parsing GitHub PR diff",
    "Checking requirements coverage",
    "Running LLM classification",
  ];

  return (
    <div
      className={cn(
        "rounded-xl border p-5 transition-all duration-500",
        active
          ? "border-yellow/30 bg-yellow/5 glow-yellow"
          : "border-border bg-surface opacity-40"
      )}
    >
      <div className="mb-4 flex items-center gap-3">
        <div
          className={cn(
            "flex h-9 w-9 items-center justify-center rounded-full border text-lg",
            active ? "border-yellow/40 bg-yellow/10 animate-pulse-slow" : "border-border"
          )}
        >
          🤖
        </div>
        <div>
          <div className="text-sm font-semibold text-text">Somnia Agent</div>
          <div className="text-xs text-muted">
            {active ? `Verifying${".".repeat(dot)}` : "Standby"}
          </div>
        </div>
      </div>

      <div className="mb-3 space-y-2">
        {checks.map((check, i) => {
          const threshold = ((i + 1) / checks.length) * 90;
          const done = progress >= threshold;
          const current = progress >= (i / checks.length) * 90 && !done;
          return (
            <div
              key={check}
              className={cn(
                "flex items-center gap-2 text-xs transition-opacity duration-300",
                done ? "opacity-100" : current ? "opacity-70" : "opacity-20"
              )}
            >
              {done ? (
                <CheckCircle size={11} className="shrink-0 text-green" />
              ) : (
                <div
                  className={cn(
                    "h-2.5 w-2.5 shrink-0 rounded-full border",
                    current ? "border-yellow animate-pulse" : "border-border"
                  )}
                />
              )}
              <span className={done ? "text-text" : "text-muted"}>{check}</span>
            </div>
          );
        })}
      </div>

      <div className="h-1 overflow-hidden rounded-full bg-surface-2">
        <div
          className="h-full rounded-full bg-yellow transition-all duration-100"
          style={{ width: `${active ? progress : 0}%` }}
        />
      </div>
    </div>
  );
}

function VerdictCard({ visible }: { visible: boolean }) {
  return (
    <div
      className={cn(
        "rounded-xl border p-5 transition-all duration-700",
        visible
          ? "border-green/30 bg-green/5 glow-green opacity-100 translate-y-0"
          : "border-border bg-surface opacity-0 translate-y-2"
      )}
    >
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <CheckCircle size={18} className="text-green" />
          <span className="font-semibold text-text">Agent Verdict</span>
        </div>
        <span className="rounded border border-green/30 bg-green/10 px-2 py-0.5 font-mono text-xs font-bold text-green">
          COMPLETE
        </span>
      </div>
      <div className="space-y-1.5 text-xs text-muted">
        <div className="flex items-start gap-2">
          <CheckCircle size={11} className="mt-0.5 shrink-0 text-green" />
          <span>Smart contract deployed at verified address</span>
        </div>
        <div className="flex items-start gap-2">
          <CheckCircle size={11} className="mt-0.5 shrink-0 text-green" />
          <span>GitHub PR merged, all 4 acceptance criteria present</span>
        </div>
        <div className="flex items-start gap-2">
          <CheckCircle size={11} className="mt-0.5 shrink-0 text-green" />
          <span>Test coverage ≥ 80% confirmed in CI output</span>
        </div>
      </div>
      <div className="mt-3 border-t border-border pt-3 text-[10px] text-subtle">
        Bounded output · AI never moves funds · Escrow enforces policy
      </div>
    </div>
  );
}

function MilestoneCard({ state }: { state: DemoState }) {
  const stateConfig: Record<string, { label: string; color: string; dot?: boolean }> = {
    idle:     { label: "None",      color: "text-muted" },
    created:  { label: "Created",   color: "text-blue" },
    funded:   { label: "Funded",    color: "text-blue" },
    submitted:{ label: "Verifying", color: "text-yellow", dot: true },
    verifying:{ label: "Verifying", color: "text-yellow", dot: true },
    verdict:  { label: "Complete",  color: "text-green" },
    approved: { label: "Approved",  color: "text-green" },
    claimed:  { label: "Claimed",   color: "text-green" },
  };
  const s = stateConfig[state] ?? stateConfig.idle;

  return (
    <div className="rounded-xl border border-border bg-surface p-5">
      <div className="mb-4 flex items-center justify-between">
        <span className="font-mono text-sm font-bold text-text">
          Milestone #{MOCK_TASK.id}
        </span>
        <span
          className={cn(
            "inline-flex items-center gap-1.5 rounded border px-2 py-0.5 font-mono text-xs font-bold uppercase",
            s.color === "text-green"
              ? "border-green/30 bg-green/10 text-green"
              : s.color === "text-yellow"
              ? "border-yellow/30 bg-yellow/10 text-yellow"
              : s.color === "text-blue"
              ? "border-blue/30 bg-blue/10 text-blue"
              : "border-border bg-surface-2 text-muted"
          )}
        >
          {s.dot && (
            <span className="h-1.5 w-1.5 rounded-full bg-yellow animate-pulse" />
          )}
          {s.label}
        </span>
      </div>

      <div className="space-y-2 text-xs">
        {[
          { label: "Client",      value: MOCK_TASK.client },
          { label: "Contractor",  value: MOCK_TASK.contractor },
          { label: "Resolver",    value: MOCK_TASK.resolver },
        ].map(({ label, value }) => (
          <div key={label} className="flex items-center justify-between">
            <span className="text-muted">{label}</span>
            <span className="font-mono text-text">{value}</span>
          </div>
        ))}
        <div className="flex items-center justify-between">
          <span className="text-muted">Amount locked</span>
          <span className={cn("font-mono font-semibold", state === "claimed" ? "text-muted line-through" : "text-text")}>
            {MOCK_TASK.amount}
          </span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-muted">Requirements</span>
          <a
            href={MOCK_TASK.requirementsURI}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-green hover:underline"
          >
            GitHub Issue <ExternalLink size={10} />
          </a>
        </div>
        {(state === "submitted" || state === "verifying" || state === "verdict" || state === "approved" || state === "claimed") && (
          <div className="flex items-center justify-between border-t border-border pt-2">
            <span className="text-muted">Evidence</span>
            <a
              href={MOCK_TASK.evidenceURI}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 text-green hover:underline"
            >
              GitHub PR <ExternalLink size={10} />
            </a>
          </div>
        )}
      </div>

      {state === "claimed" && (
        <div className="mt-4 rounded-lg border border-green/20 bg-green/5 px-3 py-2 text-center">
          <span className="text-sm font-semibold text-green">
            ✓ {MOCK_TASK.amount} paid to contractor
          </span>
        </div>
      )}
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function DemoPage() {
  const [currentState, setCurrentState] = useState<DemoState>("idle");
  const [timeline, setTimeline] = useState<TimelineEntry[]>([]);
  const [isAuto, setIsAuto] = useState(false);
  const [autoIndex, setAutoIndex] = useState(0);
  const autoTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const addToTimeline = useCallback((state: DemoState) => {
    const meta = TIMELINE_META[state];
    if (!meta.label) return;
    setTimeline((prev) => [
      {
        state,
        label: meta.label,
        sublabel: meta.sublabel,
        icon: meta.icon,
        colorClass: meta.colorClass,
        ts: new Date().toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false }),
        txHash: (meta as TimelineEntry).txHash,
      },
      ...prev,
    ]);
  }, []);

  const advanceTo = useCallback(
    (state: DemoState) => {
      setCurrentState(state);
      addToTimeline(state);
    },
    [addToTimeline]
  );

  // Manual next step
  const nextState = FLOW[FLOW.indexOf(currentState) + 1];
  const isComplete = currentState === "claimed";

  function handleNext() {
    if (!nextState || isComplete) return;
    advanceTo(nextState);
  }

  function handleReset() {
    if (autoTimerRef.current) clearTimeout(autoTimerRef.current);
    setCurrentState("idle");
    setTimeline([]);
    setIsAuto(false);
    setAutoIndex(0);
  }

  // Auto play
  useEffect(() => {
    if (!isAuto) return;
    const idx = autoIndex;
    if (idx >= FLOW.length) { setIsAuto(false); return; }

    const state = FLOW[idx];
    const delay = DELAYS[state] ?? 1400;

    autoTimerRef.current = setTimeout(() => {
      advanceTo(state);
      setAutoIndex(idx + 1);
    }, delay);

    return () => { if (autoTimerRef.current) clearTimeout(autoTimerRef.current); };
  }, [isAuto, autoIndex, advanceTo]);

  function handleAutoPlay() {
    handleReset();
    setTimeout(() => {
      setIsAuto(true);
      setAutoIndex(0);
    }, 50);
  }

  const progressPct = currentState === "idle"
    ? 0
    : ((FLOW.indexOf(currentState) + 1) / FLOW.length) * 100;

  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      {/* ── Header ──────────────────────────────────────────────── */}
      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="mb-1 inline-flex items-center gap-2 rounded-full border border-yellow/20 bg-yellow/5 px-3 py-1">
            <span className="h-1.5 w-1.5 rounded-full bg-yellow animate-pulse" />
            <span className="text-xs font-medium text-yellow">Demo Mode · No wallet needed</span>
          </div>
          <h1 className="text-2xl font-bold text-text">End-to-end flow</h1>
          <p className="mt-1 text-sm text-muted">
            Live walkthrough of an agent-verified milestone settlement
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleReset}
            className="flex h-9 items-center gap-2 rounded-lg border border-border bg-surface px-3 text-sm text-muted transition-colors hover:text-text"
          >
            <RotateCcw size={13} /> Reset
          </button>
          <button
            onClick={handleAutoPlay}
            disabled={isAuto}
            className="flex h-9 items-center gap-2 rounded-md bg-accent px-4 text-sm font-medium text-white transition-colors duration-100 hover:bg-accent-hover disabled:opacity-50"
          >
            {isAuto ? (
              <><RefreshCw size={13} className="animate-spin" /> Playing…</>
            ) : (
              <><Play size={13} /> Auto-play</>
            )}
          </button>
        </div>
      </div>

      {/* ── Progress bar ────────────────────────────────────────── */}
      <div className="mb-8">
        <div className="mb-2 flex items-center justify-between text-xs text-muted">
          <span>Start</span>
          <span className={cn("font-semibold", isComplete ? "text-green" : "text-text")}>
            {isComplete ? "Complete ✓" : currentState === "idle" ? "Press a step to begin" : TIMELINE_META[currentState].label}
          </span>
          <span>Settlement</span>
        </div>
        <div className="h-1.5 overflow-hidden rounded-full bg-surface-2">
          <div
            className={cn(
              "h-full rounded-full transition-all duration-700",
              isComplete ? "bg-green" : "bg-green/70"
            )}
            style={{ width: `${progressPct}%` }}
          />
        </div>

        {/* Step pills */}
        <div className="mt-3 hidden items-center justify-between sm:flex">
          {FLOW.map((s) => {
            const idx = FLOW.indexOf(s);
            const currentIdx = currentState === "idle" ? -1 : FLOW.indexOf(currentState);
            const done = idx <= currentIdx;
            const active = idx === currentIdx;
            const labels: Record<DemoState, string> = {
              idle: "",
              created: "Create",
              funded: "Fund",
              submitted: "Submit",
              verifying: "Verify",
              verdict: "Verdict",
              approved: "Approve",
              claimed: "Claim",
            };
            return (
              <button
                key={s}
                onClick={() => !isAuto && advanceTo(s)}
                disabled={isAuto}
                className={cn(
                  "rounded px-2 py-1 text-xs transition-all",
                  active ? "font-bold text-text" : done ? "text-green" : "text-subtle hover:text-muted",
                  "disabled:cursor-default"
                )}
              >
                {labels[s]}
              </button>
            );
          })}
        </div>
      </div>

      {/* ── Main grid ───────────────────────────────────────────── */}
      <div className="grid gap-4 lg:grid-cols-3">
        {/* Left: Contract state */}
        <div className="space-y-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-muted">
            Contract state
          </div>
          <MilestoneCard state={currentState} />

          {/* Agent panel */}
          <AgentAnimation
            active={currentState === "verifying" || currentState === "submitted"}
          />

          {/* Verdict card */}
          <VerdictCard
            visible={["verdict", "approved", "claimed"].includes(currentState)}
          />
        </div>

        {/* Middle: Action / narration */}
        <div className="space-y-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-muted">
            Current action
          </div>
          <ActionPanel state={currentState} />

          {/* Next step button */}
          {!isAuto && !isComplete && currentState !== "verifying" && (
            <button
              onClick={handleNext}
              disabled={!nextState}
              className={cn(
                "flex w-full h-10 items-center justify-center gap-2 rounded-lg border text-sm font-medium transition-all",
                nextState
                  ? "border-green/30 bg-green/10 text-green hover:bg-green/20"
                  : "border-border text-muted opacity-40"
              )}
            >
              {currentState === "idle" ? "Start demo" : "Next step"}
              <ChevronRight size={15} />
            </button>
          )}

          {isComplete && (
            <button
              onClick={handleReset}
              className="flex w-full h-10 items-center justify-center gap-2 rounded-lg border border-border bg-surface text-sm text-muted transition-colors hover:text-text"
            >
              <RotateCcw size={13} /> Run again
            </button>
          )}
        </div>

        {/* Right: Timeline */}
        <div className="space-y-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-muted">
            On-chain trail
          </div>
          {timeline.length === 0 ? (
            <div className="flex h-32 items-center justify-center rounded-xl border border-dashed border-border text-xs text-muted">
              Events will appear here
            </div>
          ) : (
            <div className="space-y-2">
              {timeline.map((entry, i) => (
                <div
                  key={i}
                  className="fade-in flex gap-3 rounded-lg border border-border bg-surface p-3"
                >
                  <div className="mt-0.5 text-base leading-none">{entry.icon}</div>
                  <div className="min-w-0 flex-1">
                    <div className={cn("text-xs font-semibold", entry.colorClass)}>
                      {entry.label}
                    </div>
                    <div className="mt-0.5 text-xs leading-relaxed text-muted">
                      {entry.sublabel}
                    </div>
                    <div className="mt-1 flex items-center gap-2">
                      <span className="font-mono text-[10px] text-subtle">{entry.ts}</span>
                      {entry.txHash && (
                        <span className="font-mono text-[10px] text-subtle">
                          tx: {entry.txHash}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Key principles footer ────────────────────────────────── */}
      <div className="mt-10 grid gap-3 sm:grid-cols-3">
        {[
          {
            icon: "🔒",
            title: "AI never moves funds",
            desc: "Agent returns a bounded verdict. The smart contract enforces what happens next.",
          },
          {
            icon: "⚡",
            title: "400ms Somnia finality",
            desc: "Verification feedback feels real-time. No waiting for slow block confirmations.",
          },
          {
            icon: "📋",
            title: "Public execution trail",
            desc: "Every step is on-chain. Immutable proof — no disputes over what happened.",
          },
        ].map((p) => (
          <div
            key={p.title}
            className="rounded-xl border border-border bg-surface p-4"
          >
            <div className="mb-2 text-xl">{p.icon}</div>
            <div className="mb-1 text-sm font-semibold text-text">{p.title}</div>
            <div className="text-xs leading-relaxed text-muted">{p.desc}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Action panel per state ───────────────────────────────────────────────────

function ActionPanel({ state }: { state: DemoState }) {
  const panels: Record<DemoState, React.ReactNode> = {
    idle: (
      <div className="flex h-48 flex-col items-center justify-center rounded-xl border border-dashed border-border text-center">
        <Play size={28} className="mb-3 text-muted" />
        <p className="text-sm font-medium text-text">Ready to demo</p>
        <p className="mt-1 text-xs text-muted">
          Press "Start demo" or "Auto-play" to begin
        </p>
      </div>
    ),
    created: (
      <Panel
        role="Client"
        roleColor="text-blue"
        action="createTask()"
        title="Milestone defined"
        fields={[
          { label: "Contractor", value: MOCK_TASK.contractor },
          { label: "Resolver",   value: MOCK_TASK.resolver },
          { label: "Amount",     value: MOCK_TASK.amount },
          { label: "Review window", value: MOCK_TASK.reviewWindow },
          { label: "Requirements", value: "github.com/…/issues/88", link: true },
        ]}
        note="Task created but NOT yet funded. Funds are not locked yet."
      />
    ),
    funded: (
      <Panel
        role="Client"
        roleColor="text-blue"
        action="fundTask()"
        title={`${MOCK_TASK.amount} locked in escrow`}
        fields={[
          { label: "Deposited", value: MOCK_TASK.amount },
          { label: "Held by", value: "VigiliaEscrow contract" },
          { label: "Releasable to", value: "Contractor (on approval)" },
        ]}
        note="Client cannot unilaterally withdraw. Contractor cannot claim yet."
        highlight
      />
    ),
    submitted: (
      <Panel
        role="Contractor"
        roleColor="text-yellow"
        action="submitWork()"
        title="Evidence submitted"
        fields={[
          { label: "Evidence URI", value: "github.com/…/pull/91", link: true },
          { label: "Evidence hash", value: "keccak256(URI)" },
          { label: "Agent fee", value: "0.09 STT (3 validators)" },
        ]}
        note="Verification request sent to Somnia Agent platform."
      />
    ),
    verifying: (
      <div className="rounded-xl border border-yellow/20 bg-yellow/5 p-5">
        <div className="mb-3 flex items-center gap-2">
          <div className="h-2 w-2 rounded-full bg-yellow animate-pulse" />
          <span className="text-sm font-semibold text-yellow">Agent running</span>
        </div>
        <p className="mb-4 text-xs text-muted">
          Somnia Agent validators are independently fetching and classifying the evidence.
          No single party controls this step.
        </p>
        <div className="space-y-2 text-xs">
          <div className="rounded bg-surface-2 px-3 py-2 font-mono text-muted">
            GET {MOCK_TASK.evidenceURI}
          </div>
          <div className="rounded bg-surface-2 px-3 py-2 font-mono text-muted">
            {"$.verdict"} → waiting…
          </div>
        </div>
        <div className="mt-3 text-[10px] text-subtle">
          Subcommittee: 3 validators · Timeout: 30s · Fail-closed on error
        </div>
      </div>
    ),
    verdict: (
      <Panel
        role="Somnia Agent"
        roleColor="text-green"
        action="recordVerdict(Complete)"
        title="Verdict recorded on-chain"
        fields={[
          { label: "Result",    value: "Complete ✓" },
          { label: "Caller",   value: "VigiliaJsonApiVerifier" },
          { label: "State",    value: "VerifiedComplete" },
          { label: "Claimable after", value: "24h review window" },
        ]}
        note="AI verdict is bounded. Contract enforces policy — agent cannot move funds."
        highlight
      />
    ),
    approved: (
      <Panel
        role="Client"
        roleColor="text-green"
        action="approveTask()"
        title="Approved early"
        fields={[
          { label: "Review window", value: "Waived by client" },
          { label: "New state", value: "Approved" },
          { label: "Next", value: "Contractor can claim immediately" },
        ]}
        note="Client can also raise a dispute instead — resolver allocates funds."
      />
    ),
    claimed: (
      <div className="rounded-xl border border-green/30 bg-green/5 p-5 glow-green">
        <CheckCircle size={32} className="mb-3 text-green" />
        <h3 className="mb-1 text-lg font-bold text-text">Settlement complete</h3>
        <p className="mb-4 text-sm text-muted">
          Contractor pulled{" "}
          <span className="font-mono font-semibold text-text">{MOCK_TASK.amount}</span>{" "}
          from escrow. On-chain proof is permanent.
        </p>
        <div className="space-y-1.5 text-xs text-muted">
          <div className="flex items-center gap-2">
            <CheckCircle size={11} className="text-green" />
            <span>Evidence publicly verifiable on Somnia Explorer</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle size={11} className="text-green" />
            <span>Agent verdict immutable on-chain</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle size={11} className="text-green" />
            <span>Pull-based payout — no push risk, no reentrancy</span>
          </div>
        </div>
        <div className="mt-4 flex items-center gap-2 text-xs text-muted">
          <span className="font-mono">{MOCK_TASK.txHashes.claim}</span>
          <ExternalLink size={11} className="text-green" />
        </div>
      </div>
    ),
  };

  return <>{panels[state]}</>;
}

function Panel({
  role,
  roleColor,
  action,
  title,
  fields,
  note,
  highlight,
}: {
  role: string;
  roleColor: string;
  action: string;
  title: string;
  fields: { label: string; value: string; link?: boolean }[];
  note?: string;
  highlight?: boolean;
}) {
  return (
    <div
      className={cn(
        "rounded-xl border p-5 fade-in",
        highlight ? "border-green/20 bg-green/5" : "border-border bg-surface"
      )}
    >
      <div className="mb-3 flex items-center justify-between">
        <span className={cn("text-xs font-bold uppercase tracking-wider", roleColor)}>
          {role}
        </span>
        <span className="rounded bg-surface-2 px-2 py-0.5 font-mono text-[10px] text-muted">
          {action}
        </span>
      </div>
      <h3 className="mb-3 text-sm font-semibold text-text">{title}</h3>
      <div className="mb-3 space-y-1.5">
        {fields.map(({ label, value, link }) => (
          <div key={label} className="flex items-center justify-between text-xs">
            <span className="text-muted">{label}</span>
            {link ? (
              <span className="font-mono text-green">{value} ↗</span>
            ) : (
              <span className="font-mono text-text">{value}</span>
            )}
          </div>
        ))}
      </div>
      {note && (
        <div className="rounded border border-border bg-surface-2 px-3 py-2 text-[11px] leading-relaxed text-muted">
          {note}
        </div>
      )}
    </div>
  );
}
