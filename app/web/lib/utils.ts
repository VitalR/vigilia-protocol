import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { formatEther, keccak256, toBytes } from "viem";
import { TaskState } from "./contracts";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function truncateAddress(address: string, chars = 6): string {
  if (!address) return "";
  return `${address.slice(0, chars + 2)}…${address.slice(-chars)}`;
}

export function formatSTT(wei: bigint, decimals = 4): string {
  const eth = formatEther(wei);
  const num = parseFloat(eth);
  if (num === 0) return "0 STT";
  if (num < 0.0001) return `<0.0001 STT`;
  return `${num.toFixed(decimals).replace(/\.?0+$/, "")} STT`;
}

export function formatTimestamp(ts: number | bigint): string {
  if (!ts) return "—";
  const date = new Date(Number(ts) * 1000);
  return date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

export function formatRelativeTime(ts: number | bigint): string {
  const now = Math.floor(Date.now() / 1000);
  const diff = now - Number(ts);
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function formatCountdown(targetTs: number): string {
  const now = Math.floor(Date.now() / 1000);
  const remaining = targetTs - now;
  if (remaining <= 0) return "Window closed";
  const h = Math.floor(remaining / 3600);
  const m = Math.floor((remaining % 3600) / 60);
  const s = remaining % 60;
  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

export function explorerTxUrl(txHash: string): string {
  return `https://shannon-explorer.somnia.network/tx/${txHash}`;
}

export function explorerAddressUrl(address: string): string {
  return `https://shannon-explorer.somnia.network/address/${address}`;
}

export function hashEvidenceURI(evidenceURI: string): `0x${string}` {
  return keccak256(toBytes(evidenceURI));
}

export type TaskStateCategory =
  | "active"
  | "pending"
  | "success"
  | "warning"
  | "error"
  | "neutral";

export function getStateCategory(state: TaskState): TaskStateCategory {
  switch (state) {
    case TaskState.Claimed:
    case TaskState.Approved:
    case TaskState.VerifiedComplete:
      return "success";
    case TaskState.NeedsReview:
    case TaskState.Submitted:
      return "warning";
    case TaskState.Incomplete:
    case TaskState.Disputed:
    case TaskState.VerificationFailed:
      return "error";
    case TaskState.Funded:
    case TaskState.Created:
      return "active";
    case TaskState.Resolved:
    case TaskState.Cancelled:
      return "neutral";
    default:
      return "neutral";
  }
}

export function isTerminalState(state: TaskState): boolean {
  return (
    state === TaskState.Claimed ||
    state === TaskState.Cancelled ||
    state === TaskState.Resolved
  );
}

// ─── Structured metadata (stored as JSON in on-chain URI fields) ──────────────

export const CRITERION_TYPES = [
  { value: "github",   label: "GitHub PR / repo",  placeholder: "e.g. PR merged to main with all tests passing" },
  { value: "contract", label: "Deployed contract",  placeholder: "e.g. Contract deployed and verified on Somnia Testnet" },
  { value: "demo",     label: "Live demo",          placeholder: "e.g. Live demo accessible at public URL" },
  { value: "video",    label: "Video / recording",  placeholder: "e.g. Screen recording of working feature" },
  { value: "docs",     label: "Docs / spec",        placeholder: "e.g. Documentation published and up to date" },
  { value: "test",     label: "Test report / CI",   placeholder: "e.g. Test coverage ≥ 80% confirmed in CI" },
  { value: "other",    label: "Other",              placeholder: "Describe what needs to be delivered" },
] as const;

export type CriterionType = typeof CRITERION_TYPES[number]["value"];

export type Criterion = {
  type: CriterionType;
  label?: string;
};

export type RequirementsMeta = {
  title: string;
  description?: string;
  criteria: Criterion[];
  refs?: string[];
  allowMultiple?: boolean;
};

export type EvidenceMeta = {
  github?: string;
  contract?: string;
  demo?: string;
  video?: string;
  docs?: string;
  test?: string;
  other?: string;
  notes?: string;
  websiteURI?: string;
};

// ─── Evidence field mappings (used by both grant and milestone builders) ───────

/** Maps criterion type → key written into the evidence JSON. */
export const CRITERION_TO_FIELD: Record<string, string> = {
  github:   "repoURI",
  contract: "contractURI",
  demo:     "demoURI",
  video:    "videoURI",
  docs:     "docsURI",
  test:     "testURI",
  website:  "websiteURI",
  other:    "otherURI",
};

/** Maps criterion type → fact flag written into the facts string. */
export const CRITERION_TO_FACT: Record<string, string> = {
  github:   "repo_exists",
  contract: "deployment_address_present",
  demo:     "demo_url_present",
  video:    "video_present",
  docs:     "docs_present",
  test:     "tests_passed",
  website:  "website_present",
  other:    "other_present",
};

// ─── Pure evidence builders (imported by components and tested in isolation) ──

import { canGenerateFact } from "./validation";

/**
 * Build the evidence JSON for a grant application.
 * Raw inputs are always preserved. Facts are only generated for values that
 * pass format validation — invalid strings are stored but never generate
 * misleading fact flags like repo_exists=true.
 */
export function buildGrantEvidence(
  values: Partial<Record<string, string>>,
  criteriaTypes: string[],
  summary?: string,
  websiteURI?: string,
): string {
  const evidence: Record<string, string> = {};
  const factParts: string[] = [];

  for (const type of criteriaTypes) {
    const fieldKey = CRITERION_TO_FIELD[type] ?? type;
    const val = values[type]?.trim();
    if (val) {
      evidence[fieldKey] = val;
      if (canGenerateFact(type, val)) {
        const factKey = CRITERION_TO_FACT[type];
        if (factKey) factParts.push(`${factKey}=true`);
      }
    }
  }

  // ThreeAgent: websiteURI is an additional required field beyond criteria
  if (websiteURI?.trim()) {
    evidence.websiteURI = websiteURI.trim();
    if (canGenerateFact("website", websiteURI.trim())) {
      if (!factParts.includes("website_present=true")) {
        factParts.push("website_present=true");
      }
    }
  }

  if (summary?.trim()) evidence.summary = summary.trim();
  if (factParts.length) evidence.facts = factParts.join("; ");

  return JSON.stringify(evidence);
}

/**
 * Build the evidence JSON for a milestone submission.
 * Same conservative fact policy — only valid values generate facts.
 */
export function buildMilestoneEvidence(
  values: Partial<Record<string, string>>,
  criteriaTypes: string[],
  notes?: string,
): string {
  const evidence: Record<string, string> = {};
  const factParts: string[] = [];

  for (const type of criteriaTypes) {
    const val = values[type]?.trim();
    if (val) {
      evidence[type] = val;
      if (canGenerateFact(type, val)) {
        const factKey = CRITERION_TO_FACT[type] ?? `${type}_present`;
        factParts.push(`${factKey}=true`);
      }
    }
  }

  if (notes?.trim()) evidence.notes = notes.trim();
  if (factParts.length) evidence.facts = factParts.join("; ");

  return JSON.stringify(evidence);
}

export function serializeRequirements(meta: RequirementsMeta): string {
  return JSON.stringify(meta);
}

export function serializeEvidence(meta: EvidenceMeta): string {
  return JSON.stringify(meta);
}

export function parseRequirementsMeta(uri: string): RequirementsMeta | null {
  if (!uri) return null;
  try {
    const parsed = JSON.parse(uri);
    if (parsed && typeof parsed.title === "string") return parsed as RequirementsMeta;
  } catch {
    // plain URL or free text — not structured JSON
  }
  return null;
}

export function parseEvidenceMeta(uri: string): EvidenceMeta | null {
  if (!uri) return null;
  try {
    const parsed = JSON.parse(uri);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed as EvidenceMeta;
    }
  } catch {
    // plain URL — not structured JSON
  }
  return null;
}
