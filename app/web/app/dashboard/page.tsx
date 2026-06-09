"use client";

import { ArrowRight, BookOpen, ExternalLink, Github, Shield, Upload, Braces, Globe, Cpu, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { formatEther } from "viem";
import { useDashboardStats } from "@/lib/hooks";
import {
  TaskState,
  RoundState,
  ApplicationStatus,
  ScreeningMode,
  TASK_STATE_LABEL,
  ROUND_STATE_LABEL,
} from "@/lib/contracts";
import { parseRequirementsMeta, cn } from "@/lib/utils";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function fmtSTT(wei: bigint) {
  const n = Number(formatEther(wei));
  if (n === 0) return "0 STT";
  return `${n % 1 === 0 ? n.toFixed(0) : n.toFixed(2)} STT`;
}

function Skeleton({ className }: { className?: string }) {
  return <div className={cn("animate-pulse rounded bg-surface-2", className)} />;
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

function KPICard({
  label,
  value,
  sub,
  loading,
  accent,
}: {
  label: string;
  value: string;
  sub?: string;
  loading?: boolean;
  accent?: string;
}) {
  return (
    <div className="rounded-xl border border-border bg-surface p-5">
      <div className="text-xs text-muted">{label}</div>
      {loading ? (
        <Skeleton className="mt-2 h-7 w-24" />
      ) : (
        <div className={cn("mt-1.5 font-mono text-2xl font-bold", accent ?? "text-text")}>{value}</div>
      )}
      {sub && !loading && (
        <div className="mt-0.5 text-xs text-subtle">{sub}</div>
      )}
    </div>
  );
}

// ─── Verdict Bar ──────────────────────────────────────────────────────────────

type BarSegment = {
  label: string;
  count: number;
  pct: number;
  bg: string;
  text: string;
  border: string;
  desc: string;
};

function VerdictBar({
  complete,
  needsReview,
  incomplete,
}: {
  complete: number;
  needsReview: number;
  incomplete: number;
}) {
  const [hovered, setHovered] = useState<string | null>(null);
  const total = complete + needsReview + incomplete;

  if (total === 0) {
    return (
      <div className="flex items-center gap-2">
        <div className="h-2 flex-1 rounded-full bg-surface-2" />
        <span className="text-xs text-subtle">No verdicts yet</span>
      </div>
    );
  }

  const segments: BarSegment[] = [
    {
      label: "Complete",
      count: complete,
      pct: (complete / total) * 100,
      bg: "bg-green",
      text: "text-green",
      border: "border-green/40",
      desc: "Evidence verified — requirements fully met. Payment released or prize claimable.",
    },
    {
      label: "Needs Review",
      count: needsReview,
      pct: (needsReview / total) * 100,
      bg: "bg-yellow",
      text: "text-yellow",
      border: "border-yellow/40",
      desc: "Agent flagged ambiguity — awaits judge or client review before settlement.",
    },
    {
      label: "Incomplete",
      count: incomplete,
      pct: (incomplete / total) * 100,
      bg: "bg-red",
      text: "text-red",
      border: "border-red/40",
      desc: "Evidence did not meet requirements. Escrow retained, no payment released.",
    },
  ].filter((s) => s.count > 0);

  const active = hovered ? segments.find((s) => s.label === hovered) : null;

  return (
    <div className="space-y-2">
      {/* Bar with floating tooltip */}
      <div className="group relative">
        <div className="flex h-4 overflow-hidden rounded-full">
          {segments.map((seg) => (
            <div
              key={seg.label}
              className={cn(
                "cursor-default transition-opacity duration-150",
                seg.bg,
                hovered && hovered !== seg.label ? "opacity-30" : "opacity-100",
              )}
              style={{ width: `${seg.pct}%` }}
              onMouseEnter={() => setHovered(seg.label)}
              onMouseLeave={() => setHovered(null)}
            />
          ))}
        </div>

        {/* Floating tooltip */}
        {active && (
          <div className={cn(
            "pointer-events-none absolute bottom-full left-1/2 mb-2 w-64 -translate-x-1/2 rounded-lg border bg-bg px-3 py-2.5 shadow-lg",
            active.border,
          )}>
            {/* Arrow */}
            <div className="absolute -bottom-1.5 left-1/2 h-3 w-3 -translate-x-1/2 rotate-45 border-b border-r border-inherit bg-bg" />
            <div className="flex items-start gap-2.5">
              <span className={cn("mt-1 h-2 w-2 shrink-0 rounded-full", active.bg)} />
              <div>
                <div className="flex items-baseline gap-2">
                  <span className={cn("text-xs font-semibold", active.text)}>{active.label}</span>
                  <span className="font-mono text-xs text-text">{active.count}</span>
                  <span className="text-[10px] text-subtle">{active.pct.toFixed(1)}%</span>
                </div>
                <p className="mt-1 text-[11px] leading-relaxed text-muted">{active.desc}</p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Legend */}
      <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs">
        {segments.map((seg) => (
          <span
            key={seg.label}
            className={cn(
              "flex cursor-default items-center gap-1.5 transition-opacity duration-100",
              hovered && hovered !== seg.label ? "opacity-40" : "opacity-100"
            )}
            onMouseEnter={() => setHovered(seg.label)}
            onMouseLeave={() => setHovered(null)}
          >
            <span className={cn("h-1.5 w-1.5 rounded-full", seg.bg)} />
            <span className="font-semibold text-text">{seg.count}</span>
            <span className="text-muted">{seg.label}</span>
            <span className="text-subtle">({seg.pct.toFixed(1)}%)</span>
          </span>
        ))}
      </div>
    </div>
  );
}

// ─── Pipeline Step ────────────────────────────────────────────────────────────

function PipelineStep({
  icon,
  agent,
  role,
  count,
  countLabel,
  color,
  iconColor,
  loading,
}: {
  icon: React.ReactNode;
  agent: string;
  role: React.ReactNode;
  count: number | string;
  countLabel: string;
  color: string;
  iconColor: string;
  loading?: boolean;
}) {
  return (
    <div className={cn("flex flex-1 flex-col rounded-xl border p-4 gap-3", color)}>
      <div className={cn("flex h-8 w-8 items-center justify-center rounded-lg border", iconColor)}>
        {icon}
      </div>
      <div>
        <div className="text-xs font-semibold text-text">{agent}</div>
        <div className="mt-0.5 text-[11px] leading-relaxed text-muted">{role}</div>
      </div>
      <div className="mt-auto">
        {loading ? (
          <Skeleton className="h-6 w-12" />
        ) : (
          <div className="font-mono text-xl font-bold text-text">{count}</div>
        )}
        <div className="text-[10px] text-subtle">{countLabel}</div>
      </div>
    </div>
  );
}

// ─── Pipeline Arrow ───────────────────────────────────────────────────────────

function PipelineArrow() {
  return (
    <div className="flex items-center pt-6 shrink-0">
      <div className="h-px w-4 border-t border-dashed border-border" />
      <ArrowRight size={12} className="shrink-0 text-subtle" />
    </div>
  );
}

function taskStatusClass(_state: TaskState) {
  if (_state === TaskState.Claimed || _state === TaskState.VerifiedComplete || _state === TaskState.Approved) {
    return "border-green/30 bg-green/10 text-green";
  }
  if (_state === TaskState.NeedsReview || _state === TaskState.Submitted) {
    return "border-yellow/30 bg-yellow/10 text-yellow";
  }
  if (_state === TaskState.Incomplete || _state === TaskState.VerificationFailed) {
    return "border-red/30 bg-red/10 text-red";
  }
  return "border-border bg-surface-2 text-muted";
}

function roundStatusLabel(_round: { state: RoundState; applicationDeadline: number }) {
  const now = Math.floor(Date.now() / 1000);
  if (_round.state === RoundState.Open && now > _round.applicationDeadline) return "Ended";
  return ROUND_STATE_LABEL[_round.state] ?? String(_round.state);
}

function roundStatusClass(_round: { state: RoundState; applicationDeadline: number }) {
  const now = Math.floor(Date.now() / 1000);
  if (_round.state === RoundState.Open && now <= _round.applicationDeadline) {
    return "border-green/30 bg-green/10 text-green";
  }
  if (_round.state === RoundState.Finalized) {
    return "border-blue/30 bg-blue/10 text-blue";
  }
  if (_round.state === RoundState.Review) {
    return "border-yellow/30 bg-yellow/10 text-yellow";
  }
  return "border-border bg-surface-2 text-muted";
}

const RECENT_GRANT_ROUND_LIMIT = 3;
const RECENT_MILESTONE_LIMIT = 3;
const RECENT_VERIFICATION_LIMIT = 10;

// ─── Main dashboard ───────────────────────────────────────────────────────────

export default function DashboardPage() {
  const stats = useDashboardStats();
  const { isLoading } = stats;

  const activeGrants = stats.rounds.filter(
    ({ round }) => round.state === RoundState.Open || round.state === RoundState.Created
  );
  const activeMilestones = stats.tasks.filter(({ task }) =>
    task.state === TaskState.Funded || task.state === TaskState.Submitted
  );
  const recentGrantRounds = [...stats.rounds]
    .sort((a, b) => Number(b.id - a.id))
    .slice(0, RECENT_GRANT_ROUND_LIMIT);
  const recentMilestones = [...stats.tasks]
    .sort((a, b) => Number(b.id - a.id))
    .slice(0, RECENT_MILESTONE_LIMIT);

  // Recent verifications (tasks/apps that recently got a verdict)
  type VerificationEntry = {
    key: string;
    type: "milestone" | "grant";
    id: string;
    href: string;
    verdict: "complete" | "needs-review" | "incomplete" | "failed";
    title: string;
  };
  const recentVerifications: VerificationEntry[] = [
    ...stats.tasks
      .filter(({ task }) =>
        [
          TaskState.VerifiedComplete,
          TaskState.NeedsReview,
          TaskState.Incomplete,
          TaskState.Approved,
          TaskState.Claimed,
          TaskState.VerificationFailed,
        ].includes(task.state)
      )
      .map(({ id, task }) => {
        const meta = parseRequirementsMeta(task.requirementsURI);
        const verdictMap: Record<number, VerificationEntry["verdict"]> = {
          [TaskState.VerifiedComplete]: "complete",
          [TaskState.Approved]: "complete",
          [TaskState.Claimed]: "complete",
          [TaskState.NeedsReview]: "needs-review",
          [TaskState.Incomplete]: "incomplete",
          [TaskState.VerificationFailed]: "failed",
        };
        return {
          key: `task-${id}`,
          type: "milestone" as const,
          id: `#${id}`,
          href: `/milestones/${id}`,
          verdict: verdictMap[task.state] ?? "failed",
          title: meta?.title ?? `Milestone #${id}`,
        };
      }),
    ...stats.grantApplications
      .filter(({ application }) =>
        application.status >= ApplicationStatus.Complete &&
        application.status !== ApplicationStatus.ScreeningRequested
      )
      .map(({ id, application }) => ({
        key: `app-${id}`,
        type: "grant" as const,
        id: `App #${id}`,
        href: `/grants/${application.roundId}`,
        verdict: (
          application.status === ApplicationStatus.VerificationFailed
            ? "failed"
            : application.verdict === 1
            ? "complete"
            : application.verdict === 2
            ? "needs-review"
            : "incomplete"
        ) as VerificationEntry["verdict"],
        title: `Grant #${application.roundId} · App #${id}`,
      })),
  ].slice(0, RECENT_VERIFICATION_LIMIT);

  const verdictStyle: Record<VerificationEntry["verdict"], { label: string; cls: string }> = {
    complete:     { label: "Complete",     cls: "bg-green/10 text-green border-green/30" },
    "needs-review": { label: "Needs Review", cls: "bg-yellow/10 text-yellow border-yellow/30" },
    incomplete:   { label: "Incomplete",   cls: "bg-red/10 text-red border-red/30" },
    failed:       { label: "Verify Failed", cls: "bg-surface-2 text-muted border-border" },
  };

  const successRate =
    stats.totalVerdicts > 0
      ? `${((stats.totalComplete / stats.totalVerdicts) * 100).toFixed(0)}%`
      : "—";

  return (
    <div className="mx-auto max-w-6xl px-4 py-10 space-y-8">

      {/* ── Header ──────────────────────────────────────────────────────────── */}
      <div>
        <h1 className="text-2xl font-bold text-text">Protocol Dashboard</h1>
        <p className="mt-1 text-sm text-muted">
          Live on-chain activity — Somnia Testnet · Chain 50312
        </p>
      </div>

      {/* ── KPI row ─────────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <KPICard
          label="Milestone Contracts"
          value={stats.totalTasks.toString()}
          sub={`${activeMilestones.length} active`}
          loading={isLoading}
        />
        <KPICard
          label="Grant Rounds"
          value={stats.totalRounds.toString()}
          sub={`${activeGrants.length} accepting apps`}
          loading={isLoading}
        />
        <KPICard
          label="STT Locked"
          value={isLoading ? "—" : fmtSTT(stats.totalLocked)}
          sub={isLoading ? undefined : `${fmtSTT(stats.totalPaid)} distributed`}
          loading={isLoading}
          accent="text-accent"
        />
        <KPICard
          label="Complete Verdict Rate"
          value={isLoading ? "—" : successRate}
          sub={isLoading ? undefined : `${stats.totalVerdicts} verdicts total`}
          loading={isLoading}
          accent={stats.totalVerdicts > 0 ? "text-green" : undefined}
        />
      </div>

      {/* ── Agent Pipeline ──────────────────────────────────────────────────── */}
      <div className="rounded-xl border border-border bg-surface p-6">
        <div className="mb-2 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-text">Autonomous Agent Verification Pipeline</h2>
          <span className="rounded border border-accent/20 bg-accent/5 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-accent">
            Somnia Native
          </span>
        </div>
        <p className="mb-6 text-xs text-muted">
          Agents screen evidence against on-chain requirements — a bounded verdict is recorded immutably.
          Judges and sponsors make final selection decisions; contracts enforce payouts.
        </p>

        {/* Desktop pipeline */}
        <div className="hidden items-stretch gap-0 md:flex">
          <PipelineStep
            icon={<Upload size={15} />}
            iconColor="border-blue/20 bg-blue/10 text-blue"
            agent="Evidence Submitted"
            role={<>Public URL posted on-chain<span className="mt-1 flex flex-col gap-0.5"><span>· repo</span><span>· live demo</span><span>· docs</span><span>· deployment</span></span></>}
            count={isLoading ? "—" : stats.totalEvidenceSubmitted}
            countLabel="submissions"
            color="border-blue/20 bg-blue/5"
            loading={isLoading}
          />
          <PipelineArrow />
          <PipelineStep
            icon={<Braces size={15} />}
            iconColor="border-purple/20 bg-purple/10 text-purple"
            agent="JSON API Agent"
            role={<>Fetches evidence JSON<br />Extracts structured <code className="font-mono">facts</code> field</>}
            count={isLoading ? "—" : stats.totalVerificationsRun}
            countLabel="fetched"
            color="border-purple/20 bg-purple/5"
            loading={isLoading}
          />
          <PipelineArrow />
          <PipelineStep
            icon={<Globe size={15} />}
            iconColor="border-yellow/20 bg-yellow/10 text-yellow"
            agent="LLM Parse Website Agent"
            role={<>Fetches project website or repo<br />Adds context for LLM evaluation<br /><span className="text-subtle">3-agent mode only</span></>}
            count={isLoading ? "—" : stats.rounds.filter(({ round }) => round.screeningMode === ScreeningMode.ThreeAgent).length}
            countLabel="rounds using 3-agent"
            color="border-yellow/20 bg-yellow/5"
            loading={isLoading}
          />
          <PipelineArrow />
          <PipelineStep
            icon={<Cpu size={15} />}
            iconColor="border-green/20 bg-green/10 text-green"
            agent="LLM Inference Agent"
            role={<>Evaluates facts vs on-chain requirements<br /><span className="mt-1 flex flex-col gap-0.5"><span>· Complete</span><span>· Needs Review</span><span>· Incomplete</span></span></>}
            count={isLoading ? "—" : stats.totalVerdicts}
            countLabel="verdicts returned"
            color="border-green/20 bg-green/5"
            loading={isLoading}
          />
          <PipelineArrow />
          <PipelineStep
            icon={<ShieldCheck size={15} />}
            iconColor="border-accent/20 bg-accent/10 text-accent"
            agent="On-chain Settlement"
            role={<>Verdict triggers contract action<br />AI never moves funds directly</>}
            count={isLoading ? "—" : fmtSTT(stats.totalPaid)}
            countLabel="distributed"
            color="border-accent/20 bg-accent/5"
            loading={isLoading}
          />
        </div>

        {/* Mobile pipeline */}
        <div className="flex flex-col gap-3 md:hidden">
          {[
            { icon: <Upload size={14} />, iconColor: "text-blue", agent: "Evidence Submitted", count: isLoading ? "…" : `${stats.totalEvidenceSubmitted} submissions`, color: "border-blue/20 bg-blue/5" },
            { icon: <Braces size={14} />, iconColor: "text-purple", agent: "JSON API Agent", count: isLoading ? "…" : `${stats.totalVerificationsRun} fetched`, color: "border-purple/20 bg-purple/5" },
            { icon: <Globe size={14} />, iconColor: "text-yellow", agent: "LLM Parse Website Agent", count: "3-agent mode", color: "border-yellow/20 bg-yellow/5" },
            { icon: <Cpu size={14} />, iconColor: "text-green", agent: "LLM Inference Agent", count: isLoading ? "…" : `${stats.totalVerdicts} verdicts`, color: "border-green/20 bg-green/5" },
            { icon: <ShieldCheck size={14} />, iconColor: "text-accent", agent: "On-chain Settlement", count: isLoading ? "…" : fmtSTT(stats.totalPaid), color: "border-accent/20 bg-accent/5" },
          ].map((step, i) => (
            <div key={i} className={cn("flex items-center gap-3 rounded-lg border p-3", step.color)}>
              <span className={step.iconColor}>{step.icon}</span>
              <div className="flex-1">
                <div className="text-xs font-semibold text-text">{step.agent}</div>
                <div className="font-mono text-xs text-muted">{step.count}</div>
              </div>
              {i < 4 && <ArrowRight size={12} className="shrink-0 text-subtle rotate-90" />}
            </div>
          ))}
        </div>

        {/* Verdict bar */}
        {!isLoading && stats.totalVerdicts > 0 && (
          <div className="mt-6 rounded-lg border border-border bg-surface-2 p-4">
            <div className="mb-3 text-xs font-semibold text-muted">Verdict Distribution</div>
            <VerdictBar
              complete={stats.totalComplete}
              needsReview={stats.totalNeedsReview}
              incomplete={stats.totalIncomplete}
            />
          </div>
        )}
        {isLoading && (
          <div className="mt-6">
            <Skeleton className="h-16 w-full" />
          </div>
        )}
      </div>

      {/* ── Two columns: Recent Verifications + Active Work ──────────────────── */}
      <div className="grid gap-6 lg:grid-cols-2">

        {/* Recent Verifications */}
        <div className="rounded-xl border border-border bg-surface overflow-hidden">
          <div className="border-b border-border px-5 py-3">
            <h3 className="text-xs font-semibold uppercase tracking-wider text-muted">Recent Verifications</h3>
          </div>
          {isLoading ? (
            <div className="space-y-2 p-4">
              {[...Array(4)].map((_, i) => <Skeleton key={i} className="h-10" />)}
            </div>
          ) : recentVerifications.length === 0 ? (
            <div className="px-5 py-8 text-center text-xs text-subtle">No verifications yet</div>
          ) : (
            <div className="divide-y divide-border/50">
              {recentVerifications.map((v) => {
                const style = verdictStyle[v.verdict];
                return (
                  <div key={v.key} className="flex items-center justify-between px-5 py-3 hover:bg-surface-2 transition-colors">
                    <div className="flex items-center gap-3 min-w-0">
                      <span className={cn(
                        "shrink-0 rounded border px-1.5 py-0.5 font-mono text-[9px] font-semibold uppercase tracking-wider",
                        v.type === "milestone" ? "border-blue/30 bg-blue/5 text-blue" : "border-accent/30 bg-accent/5 text-accent"
                      )}>
                        {v.type === "milestone" ? "Milestone" : "Grant"}
                      </span>
                      <span className="truncate text-xs text-text">{v.title}</span>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      <span className={cn("rounded border px-1.5 py-0.5 text-[10px] font-semibold", style.cls)}>
                        {style.label}
                      </span>
                      <Link href={v.href} className="text-muted hover:text-text transition-colors">
                        <ArrowRight size={12} />
                      </Link>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Right column: Recent Grants + Recent Milestones */}
        <div className="space-y-6">

          {/* Recent Grants */}
          <div className="rounded-xl border border-border bg-surface overflow-hidden">
            <div className="flex items-center justify-between border-b border-border px-5 py-3">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-muted">Recent Grant Rounds</h3>
              <Link href="/grants" className="text-xs text-muted hover:text-text transition-colors">
                View all →
              </Link>
            </div>
            {isLoading ? (
              <div className="space-y-2 p-4">
                {[...Array(2)].map((_, i) => <Skeleton key={i} className="h-12" />)}
              </div>
            ) : recentGrantRounds.length === 0 ? (
              <div className="px-5 py-6 text-center text-xs text-subtle">No grant rounds yet</div>
            ) : (
              <div className="divide-y divide-border/50">
                {recentGrantRounds.map(({ id, round }) => {
                  const meta = parseRequirementsMeta(round.requirementsURI);
                  const pool = round.prizeAmount * round.maxWinners;
                  return (
                    <Link
                      key={id}
                      href={`/grants/${id}`}
                      className="flex items-center justify-between px-5 py-3 hover:bg-surface-2 transition-colors"
                    >
                      <div className="min-w-0">
                        <div className="truncate text-sm text-text">{meta?.title ?? `Grant #${id}`}</div>
                        <div className="mt-0.5 flex items-center gap-2 text-xs text-muted">
                          <span className="font-mono">{fmtSTT(pool)}</span>
                          <span>·</span>
                          <span>{round.applicationsCount.toString()} apps</span>
                          <span
                            className={cn(
                              "rounded border px-1.5 py-0.5 text-[10px] font-semibold",
                              roundStatusClass(round)
                            )}
                          >
                            {roundStatusLabel(round)}
                          </span>
                        </div>
                      </div>
                      <ArrowRight size={12} className="shrink-0 text-muted ml-3" />
                    </Link>
                  );
                })}
              </div>
            )}
          </div>

          {/* Recent Milestones */}
          <div className="rounded-xl border border-border bg-surface overflow-hidden">
            <div className="flex items-center justify-between border-b border-border px-5 py-3">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-muted">Recent Milestones</h3>
              <Link href="/milestones" className="text-xs text-muted hover:text-text transition-colors">
                View all →
              </Link>
            </div>
            {isLoading ? (
              <div className="space-y-2 p-4">
                {[...Array(2)].map((_, i) => <Skeleton key={i} className="h-12" />)}
              </div>
            ) : recentMilestones.length === 0 ? (
              <div className="px-5 py-6 text-center text-xs text-subtle">No milestones yet</div>
            ) : (
              <div className="divide-y divide-border/50">
                {recentMilestones.map(({ id, task }) => {
                  const meta = parseRequirementsMeta(task.requirementsURI);
                  return (
                    <Link
                      key={id}
                      href={`/milestones/${id}`}
                      className="flex items-center justify-between px-5 py-3 hover:bg-surface-2 transition-colors"
                    >
                      <div className="min-w-0">
                        <div className="truncate text-sm text-text">{meta?.title ?? `Milestone #${id}`}</div>
                        <div className="mt-0.5 flex items-center gap-2 text-xs text-muted">
                          <span className="font-mono">{fmtSTT(task.amount)}</span>
                          <span>·</span>
                          <span className={cn(
                            "rounded border px-1.5 py-0.5 text-[10px] font-semibold",
                            taskStatusClass(task.state)
                          )}>
                            {TASK_STATE_LABEL[task.state]}
                          </span>
                        </div>
                      </div>
                      <ArrowRight size={12} className="shrink-0 text-muted ml-3" />
                    </Link>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ── Project resources ───────────────────────────────────────────────── */}
      <div className="rounded-xl border border-border bg-surface p-6">
        <h2 className="mb-4 text-sm font-semibold text-text">Project Resources</h2>
        <div className="grid gap-3 sm:grid-cols-3">
          {([
            {
              href: "https://github.com/VitalR/vigilia-protocol",
              Icon: Github,
              label: "GitHub Repository",
              desc: "Source code, contracts, and tests",
            },
            {
              href: "https://github.com/VitalR/vigilia-protocol/tree/main/docs",
              Icon: BookOpen,
              label: "Technical Docs",
              desc: "Architecture, agent workflows, API reference",
            },
            {
              href: "https://github.com/VitalR/vigilia-protocol/tree/main/docs/proofs",
              Icon: Shield,
              label: "Live Proof Records",
              desc: "On-chain evidence and agent verdicts",
            },
          ] as const).map(({ href, Icon, label, desc }) => (
            <a
              key={href}
              href={href}
              target="_blank"
              rel="noopener noreferrer"
              className="group flex items-start gap-3 rounded-lg border border-border p-4 transition-colors hover:border-accent/30 hover:bg-surface-2"
            >
              <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-border bg-surface-2 text-muted transition-colors group-hover:border-accent/20 group-hover:text-accent">
                <Icon size={15} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1">
                  <span className="text-sm font-medium text-text">{label}</span>
                  <ExternalLink size={10} className="shrink-0 text-subtle" />
                </div>
                <p className="mt-0.5 text-xs text-muted">{desc}</p>
              </div>
            </a>
          ))}
        </div>
      </div>

    </div>
  );
}
