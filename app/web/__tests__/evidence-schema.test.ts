import { describe, it, expect } from "vitest";
import { buildGrantEvidence, buildMilestoneEvidence } from "@/lib/utils";

// ─── Evidence schema: raw inputs preserved, facts conservative ────────────────

describe("buildGrantEvidence", () => {
  it("preserves raw input values in evidence JSON", () => {
    const json = buildGrantEvidence(
      { github: "https://github.com/owner/repo" },
      ["github"],
    );
    const parsed = JSON.parse(json);
    expect(parsed.repoURI).toBe("https://github.com/owner/repo");
  });

  it("generates repo_exists=true for a valid GitHub URL", () => {
    const json = buildGrantEvidence(
      { github: "https://github.com/owner/repo" },
      ["github"],
    );
    const parsed = JSON.parse(json);
    expect(parsed.facts).toContain("repo_exists=true");
  });

  it("preserves an invalid repo string but does NOT generate repo_exists=true", () => {
    const json = buildGrantEvidence({ github: "my project" }, ["github"]);
    const parsed = JSON.parse(json);
    // raw value is stored
    expect(parsed.repoURI).toBe("my project");
    // fact is not generated
    expect(parsed.facts ?? "").not.toContain("repo_exists=true");
  });

  it("preserves an invalid contract string but does NOT generate deployment_address_present=true", () => {
    const json = buildGrantEvidence({ contract: "0x123" }, ["contract"]);
    const parsed = JSON.parse(json);
    expect(parsed.contractURI).toBe("0x123");
    expect(parsed.facts ?? "").not.toContain("deployment_address_present=true");
  });

  it("preserves an invalid demo string but does NOT generate demo_url_present=true", () => {
    const json = buildGrantEvidence({ demo: "my live site" }, ["demo"]);
    const parsed = JSON.parse(json);
    expect(parsed.demoURI).toBe("my live site");
    expect(parsed.facts ?? "").not.toContain("demo_url_present=true");
  });

  it("unknown values are not converted to fact=true (unknown field type passthrough)", () => {
    // A value in an unexpected field type doesn't accidentally generate facts
    const json = buildGrantEvidence({ github: "not-a-url" }, ["github"]);
    const parsed = JSON.parse(json);
    expect(parsed.facts ?? "").not.toContain("repo_exists=true");
  });

  it("generates multiple facts when multiple valid fields are provided", () => {
    const json = buildGrantEvidence(
      {
        github: "https://github.com/owner/repo",
        demo: "https://demo.example.com",
      },
      ["github", "demo"],
    );
    const parsed = JSON.parse(json);
    expect(parsed.facts).toContain("repo_exists=true");
    expect(parsed.facts).toContain("demo_url_present=true");
  });

  it("includes summary field when provided", () => {
    const json = buildGrantEvidence({}, [], "My project summary");
    const parsed = JSON.parse(json);
    expect(parsed.summary).toBe("My project summary");
  });

  it("ThreeAgent: includes websiteURI in evidence JSON", () => {
    const json = buildGrantEvidence({}, [], undefined, "https://myproject.io");
    const parsed = JSON.parse(json);
    expect(parsed.websiteURI).toBe("https://myproject.io");
  });

  it("ThreeAgent: generates website_present=true for a valid website URL", () => {
    const json = buildGrantEvidence({}, [], undefined, "https://myproject.io");
    const parsed = JSON.parse(json);
    expect(parsed.facts).toContain("website_present=true");
  });

  it("ThreeAgent: invalid websiteURI is stored but does not generate website_present=true", () => {
    const json = buildGrantEvidence({}, [], undefined, "not a url");
    const parsed = JSON.parse(json);
    expect(parsed.websiteURI).toBe("not a url");
    expect(parsed.facts ?? "").not.toContain("website_present=true");
  });

  it("produces no facts field when all values are invalid", () => {
    const json = buildGrantEvidence({ github: "bad", demo: "also bad" }, ["github", "demo"]);
    const parsed = JSON.parse(json);
    expect(parsed.facts).toBeUndefined();
  });
});

describe("buildMilestoneEvidence", () => {
  it("preserves raw input values in evidence JSON", () => {
    const json = buildMilestoneEvidence(
      { github: "https://github.com/owner/repo" },
      ["github"],
    );
    const parsed = JSON.parse(json);
    expect(parsed.github).toBe("https://github.com/owner/repo");
  });

  it("invalid repo string does not generate repo_exists=true", () => {
    const json = buildMilestoneEvidence({ github: "my project" }, ["github"]);
    const parsed = JSON.parse(json);
    expect(parsed.facts ?? "").not.toContain("repo_exists=true");
  });

  it("includes notes when provided", () => {
    const json = buildMilestoneEvidence({}, [], "Delivered the feature as spec'd");
    const parsed = JSON.parse(json);
    expect(parsed.notes).toBe("Delivered the feature as spec'd");
  });

  it("produces no facts for an all-invalid form", () => {
    const json = buildMilestoneEvidence(
      { github: "banana", contract: "0x123", demo: "not a url" },
      ["github", "contract", "demo"],
    );
    const parsed = JSON.parse(json);
    expect(parsed.facts).toBeUndefined();
  });
});
