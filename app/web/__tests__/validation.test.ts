import { describe, it, expect } from "vitest";
import {
  validateGithubRepo,
  validateContractAddress,
  validatePublicUrl,
  validateCriterionValue,
  canGenerateFact,
  hasValidationErrors,
} from "@/lib/validation";

// ─── Normal mode: invalid inputs block upload ─────────────────────────────────

describe("validateGithubRepo", () => {
  it("accepts a valid GitHub repo URL", () => {
    expect(validateGithubRepo("https://github.com/owner/repo").valid).toBe(true);
  });

  it("accepts a PR URL", () => {
    expect(validateGithubRepo("https://github.com/owner/repo/pull/42").valid).toBe(true);
  });

  it("rejects a plain string", () => {
    const r = validateGithubRepo("my project");
    expect(r.valid).toBe(false);
    expect(r.error).toBeDefined();
  });

  it("rejects a non-GitHub URL", () => {
    expect(validateGithubRepo("https://gitlab.com/owner/repo").valid).toBe(false);
  });

  it("rejects a GitHub URL with only owner (no repo)", () => {
    expect(validateGithubRepo("https://github.com/owner").valid).toBe(false);
  });

  it("rejects empty string as a no-op (valid: true — field is optional)", () => {
    expect(validateGithubRepo("").valid).toBe(true);
  });
});

describe("validateContractAddress", () => {
  it("accepts a valid checksummed EVM address", () => {
    expect(validateContractAddress("0xAbCdEf0123456789AbCdEf0123456789AbCdEf01").valid).toBe(true);
  });

  it("accepts a lowercase EVM address", () => {
    expect(validateContractAddress("0x1fa22e3a97dabb9a8c6de3a5b59ef6ccd5b2f4b9").valid).toBe(true);
  });

  it("rejects a plain string", () => {
    expect(validateContractAddress("my-contract").valid).toBe(false);
  });

  it("rejects an address that is too short", () => {
    expect(validateContractAddress("0x1234").valid).toBe(false);
  });

  it("rejects an address without 0x prefix", () => {
    expect(validateContractAddress("1fa22e3a97dabb9a8c6de3a5b59ef6ccd5b2f4b9").valid).toBe(false);
  });

  it("rejects empty string as a no-op (valid: true — field is optional)", () => {
    expect(validateContractAddress("").valid).toBe(true);
  });
});

describe("validatePublicUrl (demo / docs / video / test)", () => {
  it("accepts https URL", () => {
    expect(validatePublicUrl("https://example.com/demo").valid).toBe(true);
  });

  it("accepts http URL", () => {
    expect(validatePublicUrl("http://localhost:3000").valid).toBe(true);
  });

  it("rejects a plain string", () => {
    expect(validatePublicUrl("my demo").valid).toBe(false);
  });

  it("rejects a URL without protocol", () => {
    expect(validatePublicUrl("example.com/demo").valid).toBe(false);
  });

  it("rejects empty string as a no-op (valid: true — field is optional)", () => {
    expect(validatePublicUrl("").valid).toBe(true);
  });
});

// ─── Invalid values must not generate fact flags ───────────────────────────────

describe("canGenerateFact", () => {
  it("invalid repo string cannot generate repo_exists=true", () => {
    expect(canGenerateFact("github", "my project")).toBe(false);
    expect(canGenerateFact("github", "github.com/owner/repo")).toBe(false); // missing https://
  });

  it("valid repo URL generates repo_exists=true", () => {
    expect(canGenerateFact("github", "https://github.com/owner/repo")).toBe(true);
  });

  it("invalid contract string cannot generate deployment_address_present=true", () => {
    expect(canGenerateFact("contract", "my contract")).toBe(false);
    expect(canGenerateFact("contract", "0x1234")).toBe(false);
  });

  it("valid contract address generates deployment_address_present=true", () => {
    expect(canGenerateFact("contract", "0x1fa22e3a97dabb9a8c6de3a5b59ef6ccd5b2f4b9")).toBe(true);
  });

  it("invalid demo URL cannot generate demo_url_present=true", () => {
    expect(canGenerateFact("demo", "my demo site")).toBe(false);
    expect(canGenerateFact("demo", "example.com")).toBe(false); // missing https://
  });

  it("valid demo URL generates demo_url_present=true", () => {
    expect(canGenerateFact("demo", "https://my-project.vercel.app")).toBe(true);
  });

  it("empty string never generates a fact", () => {
    expect(canGenerateFact("github", "")).toBe(false);
    expect(canGenerateFact("contract", "")).toBe(false);
    expect(canGenerateFact("demo", "")).toBe(false);
  });

  it("unknown/other criterion type passes without fact restriction", () => {
    // "other" type: any non-empty string is valid
    expect(canGenerateFact("other", "some description")).toBe(true);
  });
});

describe("hasValidationErrors", () => {
  it("returns false when all values are empty", () => {
    expect(hasValidationErrors({}, ["github", "demo"])).toBe(false);
  });

  it("returns false when all filled values are valid", () => {
    expect(
      hasValidationErrors(
        { github: "https://github.com/owner/repo", demo: "https://demo.example.com" },
        ["github", "demo"],
      ),
    ).toBe(false);
  });

  it("returns true when any filled value is invalid", () => {
    expect(
      hasValidationErrors({ github: "not a url", demo: "https://demo.example.com" }, ["github", "demo"]),
    ).toBe(true);
  });
});
