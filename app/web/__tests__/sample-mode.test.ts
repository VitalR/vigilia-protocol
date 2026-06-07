import { describe, it, expect, beforeEach, afterEach } from "vitest";
import {
  getSampleUrl,
  isSampleConfigured,
  getSampleEvidence,
  anySampleConfigured,
  SAMPLE_VERDICTS,
  type SampleVerdict,
} from "@/lib/sample-evidence";

// Sample URLs used in tests — these represent pre-hosted public evidence files.
const TEST_URLS: Record<SampleVerdict, string> = {
  Complete:    "https://gist.githubusercontent.com/test/complete/raw/evidence.json",
  NeedsReview: "https://gist.githubusercontent.com/test/needs-review/raw/evidence.json",
  Incomplete:  "https://gist.githubusercontent.com/test/incomplete/raw/evidence.json",
  Malformed:   "https://gist.githubusercontent.com/test/malformed/raw/evidence.json",
};

beforeEach(() => {
  process.env.NEXT_PUBLIC_SAMPLE_COMPLETE_URL     = TEST_URLS.Complete;
  process.env.NEXT_PUBLIC_SAMPLE_NEEDS_REVIEW_URL = TEST_URLS.NeedsReview;
  process.env.NEXT_PUBLIC_SAMPLE_INCOMPLETE_URL   = TEST_URLS.Incomplete;
  process.env.NEXT_PUBLIC_SAMPLE_MALFORMED_URL    = TEST_URLS.Malformed;
});

afterEach(() => {
  delete process.env.NEXT_PUBLIC_SAMPLE_COMPLETE_URL;
  delete process.env.NEXT_PUBLIC_SAMPLE_NEEDS_REVIEW_URL;
  delete process.env.NEXT_PUBLIC_SAMPLE_INCOMPLETE_URL;
  delete process.env.NEXT_PUBLIC_SAMPLE_MALFORMED_URL;
});

// ─── Sample URL resolution ─────────────────────────────────────────────────────

describe("getSampleUrl", () => {
  it("Complete sample resolves to expected public URL", () => {
    expect(getSampleUrl("Complete")).toBe(TEST_URLS.Complete);
  });

  it("NeedsReview sample resolves to expected public URL", () => {
    expect(getSampleUrl("NeedsReview")).toBe(TEST_URLS.NeedsReview);
  });

  it("Incomplete sample resolves to expected public URL", () => {
    expect(getSampleUrl("Incomplete")).toBe(TEST_URLS.Incomplete);
  });

  it("Malformed sample resolves to expected public URL", () => {
    expect(getSampleUrl("Malformed")).toBe(TEST_URLS.Malformed);
  });

  it("returns empty string when env var is not set", () => {
    delete process.env.NEXT_PUBLIC_SAMPLE_COMPLETE_URL;
    expect(getSampleUrl("Complete")).toBe("");
  });
});

// ─── Sample configuration checks ──────────────────────────────────────────────

describe("isSampleConfigured", () => {
  it("returns true when the URL is a valid https address", () => {
    expect(isSampleConfigured("Complete")).toBe(true);
  });

  it("returns false when the env var is not set", () => {
    delete process.env.NEXT_PUBLIC_SAMPLE_COMPLETE_URL;
    expect(isSampleConfigured("Complete")).toBe(false);
  });
});

describe("anySampleConfigured", () => {
  it("returns true when at least one URL is configured", () => {
    delete process.env.NEXT_PUBLIC_SAMPLE_NEEDS_REVIEW_URL;
    delete process.env.NEXT_PUBLIC_SAMPLE_INCOMPLETE_URL;
    delete process.env.NEXT_PUBLIC_SAMPLE_MALFORMED_URL;
    expect(anySampleConfigured()).toBe(true);
  });

  it("returns false when no URLs are configured", () => {
    for (const key of Object.keys(TEST_URLS)) {
      delete process.env[`NEXT_PUBLIC_SAMPLE_${key.replace(/([A-Z])/g, "_$1").toUpperCase()}_URL`];
    }
    delete process.env.NEXT_PUBLIC_SAMPLE_COMPLETE_URL;
    delete process.env.NEXT_PUBLIC_SAMPLE_NEEDS_REVIEW_URL;
    delete process.env.NEXT_PUBLIC_SAMPLE_INCOMPLETE_URL;
    delete process.env.NEXT_PUBLIC_SAMPLE_MALFORMED_URL;
    expect(anySampleConfigured()).toBe(false);
  });
});

// ─── Sample mode contract submission flow ─────────────────────────────────────

describe("getSampleEvidence", () => {
  it("returns all four sample entries", () => {
    const samples = getSampleEvidence();
    expect(samples).toHaveLength(4);
    const verdicts = samples.map((s) => s.verdict);
    expect(verdicts).toContain("Complete");
    expect(verdicts).toContain("NeedsReview");
    expect(verdicts).toContain("Incomplete");
    expect(verdicts).toContain("Malformed");
  });

  it("each sample entry exposes only a URL — no preset verdict value for the contract", () => {
    const samples = getSampleEvidence();
    // The UI submits the URL to the contract; the agent decides the verdict.
    // We verify that the sample object only has the URL field, not a 'contractVerdict'.
    for (const sample of samples) {
      expect(sample.url).toBeDefined();
      expect((sample as Record<string, unknown>).contractVerdict).toBeUndefined();
    }
  });

  it("selecting a Complete sample uses the pre-configured URL (not a hardcoded verdict)", () => {
    const sample = getSampleEvidence().find((s) => s.verdict === "Complete")!;
    // The URL is what gets submitted to the contract — the agent evaluates it
    expect(sample.url).toBe(TEST_URLS.Complete);
    // The verdict field on the SampleEvidence object is metadata for the UI label only
    expect(sample.verdict).toBe("Complete");
  });

  it("selecting a NeedsReview sample uses the pre-configured URL", () => {
    const sample = getSampleEvidence().find((s) => s.verdict === "NeedsReview")!;
    expect(sample.url).toBe(TEST_URLS.NeedsReview);
  });

  it("selecting an Incomplete sample uses the pre-configured URL", () => {
    const sample = getSampleEvidence().find((s) => s.verdict === "Incomplete")!;
    expect(sample.url).toBe(TEST_URLS.Incomplete);
  });

  it("selecting a Malformed sample uses the pre-configured URL", () => {
    const sample = getSampleEvidence().find((s) => s.verdict === "Malformed")!;
    expect(sample.url).toBe(TEST_URLS.Malformed);
  });
});

// ─── Round mode: ThreeAgent requires websiteURI ───────────────────────────────
// (Workflow constants and fee amounts come from the contract's verifier address;
//  these tests verify the config plumbing, not the live contract values.)

describe("ThreeAgent sample evidence", () => {
  it("ThreeAgent sample entries exist for all verdicts", () => {
    // In sample mode, the same four samples cover ThreeAgent rounds too —
    // the pre-hosted evidence JSON should include websiteURI for ThreeAgent agents.
    const samples = getSampleEvidence();
    expect(samples.length).toBeGreaterThan(0);
    // All verdicts covered
    for (const v of SAMPLE_VERDICTS) {
      expect(samples.find((s) => s.verdict === v)).toBeDefined();
    }
  });
});
