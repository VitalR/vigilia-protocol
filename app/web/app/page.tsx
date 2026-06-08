"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import {
  ArrowRight,
  Braces,
  CheckCircle2,
  Cpu,
  FileText,
  LayoutDashboard,
  Shield,
  Trophy,
  Upload,
  Users,
} from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useAccount } from "wagmi";

const FLOW_STEPS = [
  {
    n: "01",
    title: "Lock funds",
    desc: "Client or sponsor deposits STT into escrow. Nothing moves without a verified outcome",
    color: "blue",
    Icon: Shield,
  },
  {
    n: "02",
    title: "Submit evidence",
    desc: "Contractor or applicant posts a public URL — repo, live demo, deployment, docs",
    color: "purple",
    Icon: Upload,
  },
  {
    n: "03",
    title: "Agents verify",
    desc: "JSON API Agent fetches evidence, LLM Inference Agent evaluates against on-chain requirements",
    color: "yellow",
    Icon: Cpu,
  },
  {
    n: "04",
    title: "Verdict recorded",
    desc: "Bounded output only: Complete · Needs Review · Incomplete — written immutably on-chain",
    color: "green",
    Icon: Braces,
  },
  {
    n: "05",
    title: "Settlement",
    desc: "Complete → claimable by policy. Needs Review → judge decides. Incomplete → escrow retained.",
    color: "green",
    Icon: CheckCircle2,
  },
];

const colorMap: Record<string, { line: string; text: string; bg: string }> = {
  blue:   { line: "border-blue/30",   text: "text-blue",   bg: "bg-blue/10"   },
  purple: { line: "border-purple/30", text: "text-purple", bg: "bg-purple/10" },
  yellow: { line: "border-yellow/30", text: "text-yellow", bg: "bg-yellow/10" },
  green:  { line: "border-green/30",  text: "text-green",  bg: "bg-green/10"  },
};

export default function LandingPage() {
  const { isConnected } = useAccount();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  return (
    <div className="mx-auto max-w-6xl px-4 pb-24">

      {/* ── Hero ─────────────────────────────────────────────────────── */}
      <section className="flex flex-col items-center pt-24 pb-16 text-center">
        <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-accent/20 bg-accent/5 px-3 py-1">
          <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-accent" />
          <span className="text-xs font-medium text-accent">Live on Somnia Testnet · Chain 50312</span>
        </div>

        <h1
          className="mb-4 max-w-2xl text-5xl font-bold leading-tight text-text"
          style={{ letterSpacing: "-0.02em" }}
        >
          Agent-verified work settlement,
          <br />
          <span className="text-accent">powered by Somnia agents</span>
        </h1>

        <p className="mb-4 max-w-xl text-lg leading-relaxed text-muted">
          Submit evidence on-chain. Agents screen it against requirements.
          A bounded verdict drives settlement policy, while ambiguous cases remain reviewable.
        </p>
        <p className="mb-6 max-w-lg text-sm text-subtle">
          Agents screen evidence. Judges and sponsors select finalists. Contracts enforce payouts.
        </p>
        <div className="mb-10 flex flex-wrap justify-center gap-2">
          {[
            "No middlemen",
            "Agent-assisted review",
            "400ms finality",
            "Immutable execution trail",
          ].map((tag) => (
            <span
              key={tag}
              className="rounded-full border border-border bg-surface px-3 py-1 text-xs text-muted"
            >
              {tag}
            </span>
          ))}
        </div>

        <div className="flex flex-wrap items-center justify-center gap-3">
          {!mounted || !isConnected ? (
            <ConnectButton label="Connect Wallet to Start" />
          ) : null}
          <Link
            href="/dashboard"
            className="inline-flex items-center gap-2 rounded-xl border border-border bg-surface px-4 py-2 text-sm text-muted transition-colors hover:border-accent/30 hover:text-text"
          >
            <LayoutDashboard size={14} />
            View live dashboard
          </Link>
        </div>
      </section>

      {/* ── Product selector ─────────────────────────────────────────── */}
      <section className="mb-20">
        <p className="mb-6 text-center text-xs font-semibold uppercase tracking-widest text-muted">
          Two products, one protocol
        </p>
        <div className="grid gap-4 sm:grid-cols-2">

          {/* Grant Rounds */}
          <Link
            href="/grants"
            className="group relative flex flex-col overflow-hidden rounded-2xl border border-border bg-surface p-8 transition-all duration-200 hover:border-accent/40 hover:bg-surface-2"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-accent/5 to-transparent opacity-0 transition-opacity duration-200 group-hover:opacity-100" />
            <div className="relative">
              <div className="mb-5 flex items-start justify-between">
                <div className="flex h-12 w-12 items-center justify-center rounded-xl border border-accent/20 bg-accent/10">
                  <Trophy size={22} className="text-accent" />
                </div>
                <span className="rounded-full border border-accent/20 bg-accent/5 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wider text-accent">
                  Grant Rounds
                </span>
              </div>

              <h2 className="mb-2 text-xl font-bold text-text">
                Fund builders at scale.
                <br />
                Agents screen every applicant.
              </h2>
              <p className="mb-6 text-sm leading-relaxed text-muted">
                Sponsor locks a prize pool, sets on-chain criteria, and opens applications.
                Each applicant submits a public evidence URL — agents fetch it, extract facts,
                and return a verdict. You pick finalists from a pre-screened shortlist.
              </p>

              <div className="mb-6 space-y-2">
                {[
                  { role: "Sponsor", action: "Create round, set criteria, fund the prize pool" },
                  { role: "Judge", action: "Select finalists from agent-screened shortlist" },
                  { role: "Applicant", action: "Submit evidence URL, receive agent verdict" },
                ].map((r) => (
                  <div key={r.role} className="flex items-start gap-2.5 text-xs">
                    <Users size={12} className="mt-0.5 shrink-0 text-accent/60" />
                    <span>
                      <span className="font-semibold text-text">{r.role}</span>
                      <span className="text-muted"> — {r.action}</span>
                    </span>
                  </div>
                ))}
              </div>

              <div className="flex items-center gap-1.5 text-sm font-medium text-accent">
                Explore Grant Rounds
                <ArrowRight size={15} className="transition-transform duration-150 group-hover:translate-x-1" />
              </div>
            </div>
          </Link>

          {/* Milestone Contracts */}
          <Link
            href="/milestones"
            className="group relative flex flex-col overflow-hidden rounded-2xl border border-border bg-surface p-8 transition-all duration-200 hover:border-blue/40 hover:bg-surface-2"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-blue/5 to-transparent opacity-0 transition-opacity duration-200 group-hover:opacity-100" />
            <div className="relative">
              <div className="mb-5 flex items-start justify-between">
                <div className="flex h-12 w-12 items-center justify-center rounded-xl border border-blue/20 bg-blue/10">
                  <FileText size={22} className="text-blue" />
                </div>
                <span className="rounded-full border border-blue/20 bg-blue/5 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wider text-blue">
                  Milestone Contracts
                </span>
              </div>

              <h2 className="mb-2 text-xl font-bold text-text">
                Commit to deliverables.
                <br />
                Escrow releases on verified proof.
              </h2>
              <p className="mb-6 text-sm leading-relaxed text-muted">
                Client defines requirements and locks payment. Contractor delivers,
                posts evidence, and agents verify autonomously.
                Complete verdict makes payment claimable — claim policy set at creation.
              </p>

              <div className="mb-6 space-y-2">
                {[
                  { role: "Client", action: "Define requirements, lock payment in escrow" },
                  { role: "Contractor", action: "Submit evidence URL, claim when policy allows after Complete." },
                  { role: "Resolver", action: "Arbitrate disputes if verdict is contested" },
                ].map((r) => (
                  <div key={r.role} className="flex items-start gap-2.5 text-xs">
                    <Users size={12} className="mt-0.5 shrink-0 text-blue/60" />
                    <span>
                      <span className="font-semibold text-text">{r.role}</span>
                      <span className="text-muted"> — {r.action}</span>
                    </span>
                  </div>
                ))}
              </div>

              <div className="flex items-center gap-1.5 text-sm font-medium text-blue">
                Explore Milestone Contracts
                <ArrowRight size={15} className="transition-transform duration-150 group-hover:translate-x-1" />
              </div>
            </div>
          </Link>
        </div>
      </section>

      {/* ── How it works ─────────────────────────────────────────────── */}
      <section className="mb-20">
        <div className="rounded-xl border border-border bg-surface p-8">
          <p className="mb-8 text-center text-xs font-semibold uppercase tracking-widest text-muted">
            How it works
          </p>

          {/* Desktop */}
          <div className="hidden items-start gap-0 md:flex">
            {FLOW_STEPS.map((step, i) => {
              const c = colorMap[step.color];
              const Icon = step.Icon;
              return (
                <div key={step.n} className="flex flex-1 items-start">
                  <div className="flex flex-col items-center">
                    <div className={`flex h-12 w-12 items-center justify-center rounded-xl border ${c.line} ${c.bg}`}>
                      <Icon size={20} className={c.text} />
                    </div>
                    <div className="mt-3 px-2 text-center">
                      <div className={`mb-0.5 font-mono text-xs font-bold ${c.text}`}>{step.n}</div>
                      <div className="mb-1 text-sm font-semibold text-text">{step.title}</div>
                      <div className="max-w-[130px] text-xs leading-relaxed text-muted">{step.desc}</div>
                    </div>
                  </div>
                  {i < FLOW_STEPS.length - 1 && (
                    <div className="flex flex-1 items-center justify-center pt-6">
                      <div className="h-px flex-1 border-t border-dashed border-border" />
                      <ArrowRight size={12} className="mx-1 shrink-0 text-subtle" />
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* Mobile */}
          <div className="flex flex-col gap-4 md:hidden">
            {FLOW_STEPS.map((step) => {
              const c = colorMap[step.color];
              const Icon = step.Icon;
              return (
                <div key={step.n} className={`flex gap-3 rounded-lg border ${c.line} ${c.bg} p-4`}>
                  <Icon size={18} className={`mt-0.5 shrink-0 ${c.text}`} />
                  <div>
                    <div className={`font-mono text-xs font-bold ${c.text}`}>{step.n}</div>
                    <div className="font-semibold text-text">{step.title}</div>
                    <div className="mt-0.5 text-xs text-muted">{step.desc}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ── Value props ───────────────────────────────────────────────── */}
      <section className="grid gap-4 sm:grid-cols-3">
        {[
          {
            icon: <Cpu size={18} className="text-accent" />,
            title: "Three-agent pipeline",
            desc: "JSON API Agent fetches evidence · LLM Parse Agent reads project context · LLM Inference Agent returns verdict. Each step is auditable",
          },
          {
            icon: <Shield size={18} className="text-yellow" />,
            title: "Bounded verdicts only",
            desc: "Agents can only return Complete, Needs Review, or Incomplete — never move funds. Settlement logic lives entirely in the smart contract",
          },
          {
            icon: <CheckCircle2 size={18} className="text-blue" />,
            title: "Immutable proof trail",
            desc: "Every submission, agent request, verdict, and payout is recorded on-chain. Any party can verify the full history at any time",
          },
        ].map((prop) => (
          <div key={prop.title} className="rounded-xl border border-border bg-surface p-6">
            <div className="mb-3 flex h-8 w-8 items-center justify-center rounded-lg bg-surface-2">
              {prop.icon}
            </div>
            <h3 className="mb-2 font-semibold text-text">{prop.title}</h3>
            <p className="text-sm leading-relaxed text-muted">{prop.desc}</p>
          </div>
        ))}
      </section>

    </div>
  );
}
