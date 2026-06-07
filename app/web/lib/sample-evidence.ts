/**
 * Sample Evidence Mode
 *
 * Sample Evidence Mode is for demo and testing only.
 * It uses pre-prepared public evidence JSON files hosted at known URLs.
 * When a tester selects a sample, the same contract submission flow runs —
 * the URL is submitted on-chain and Somnia agents fetch and evaluate it
 * just like normal evidence. The sample content is crafted to produce a
 * predictable verdict, but the UI never sets the verdict directly.
 *
 * Configure sample URLs in your .env.local (or Vercel env settings):
 *   NEXT_PUBLIC_SAMPLE_COMPLETE_URL=https://...
 *   NEXT_PUBLIC_SAMPLE_NEEDS_REVIEW_URL=https://...
 *   NEXT_PUBLIC_SAMPLE_INCOMPLETE_URL=https://...
 *   NEXT_PUBLIC_SAMPLE_MALFORMED_URL=https://...
 *
 * If a URL is not configured, that sample option will be disabled in the UI.
 */

export type SampleVerdict = "Complete" | "NeedsReview" | "Incomplete" | "Malformed";

export type SampleEvidence = {
  verdict: SampleVerdict;
  label: string;
  description: string;
  url: string;
};

export function getSampleUrl(verdict: SampleVerdict): string {
  switch (verdict) {
    case "Complete":    return process.env.NEXT_PUBLIC_SAMPLE_COMPLETE_URL ?? "";
    case "NeedsReview": return process.env.NEXT_PUBLIC_SAMPLE_NEEDS_REVIEW_URL ?? "";
    case "Incomplete":  return process.env.NEXT_PUBLIC_SAMPLE_INCOMPLETE_URL ?? "";
    case "Malformed":   return process.env.NEXT_PUBLIC_SAMPLE_MALFORMED_URL ?? "";
  }
}

export function isSampleConfigured(verdict: SampleVerdict): boolean {
  const url = getSampleUrl(verdict);
  return url.startsWith("https://") || url.startsWith("http://");
}

export const SAMPLE_VERDICTS: SampleVerdict[] = [
  "Complete",
  "NeedsReview",
  "Incomplete",
  "Malformed",
];

export const SAMPLE_EVIDENCE_META: Record<SampleVerdict, { label: string; description: string }> = {
  Complete: {
    label: "Complete",
    description: "All criteria met — agent returns Complete verdict",
  },
  NeedsReview: {
    label: "Needs Review",
    description: "Partial evidence — agent returns Needs Review",
  },
  Incomplete: {
    label: "Incomplete",
    description: "Missing or insufficient evidence — agent returns Incomplete",
  },
  Malformed: {
    label: "Malformed",
    description: "Evidence cannot be parsed — agent pipeline fails",
  },
};

export function getSampleEvidence(): SampleEvidence[] {
  return SAMPLE_VERDICTS.map((verdict) => ({
    verdict,
    ...SAMPLE_EVIDENCE_META[verdict],
    url: getSampleUrl(verdict),
  }));
}

export function anySampleConfigured(): boolean {
  return SAMPLE_VERDICTS.some(isSampleConfigured);
}
