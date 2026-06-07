/**
 * Field-level format validators for evidence submission.
 *
 * IMPORTANT — validation ≠ agent verification:
 * These checks only confirm that a value looks like the right kind of thing
 * (a real GitHub URL, a real contract address, a real public URL).
 * They do NOT confirm that the repo exists, that the contract is deployed,
 * or that the demo works. That is the agent's job.
 *
 * Why this matters:
 * - Generating `repo_exists=true` from a string like "my project" is misleading.
 *   The agent will fetch the URL and find nothing. The fact was never true.
 * - To simulate an Incomplete verdict, do not submit invalid raw strings.
 *   Use Sample Evidence Mode with the pre-configured Incomplete sample URL instead.
 */

export type ValidationResult = { valid: boolean; error?: string };

/** Must be a full GitHub URL with at least owner/repo. */
export function validateGithubRepo(value: string): ValidationResult {
  const v = value.trim();
  if (!v) return { valid: true };
  if (!v.startsWith("https://github.com/")) {
    return { valid: false, error: "Must be a full GitHub URL (https://github.com/...)" };
  }
  const parts = v.replace("https://github.com/", "").split("/").filter(Boolean);
  if (parts.length < 2) {
    return { valid: false, error: "Must include owner and repo (https://github.com/owner/repo)" };
  }
  return { valid: true };
}

/** Must be a valid EVM address: 0x followed by exactly 40 hex characters. */
export function validateContractAddress(value: string): ValidationResult {
  const v = value.trim();
  if (!v) return { valid: true };
  if (!/^0x[0-9a-fA-F]{40}$/.test(v)) {
    return { valid: false, error: "Must be a valid EVM address (0x + 40 hex digits)" };
  }
  return { valid: true };
}

/** Must be an accessible public URL (http/https, parseable). */
export function validatePublicUrl(value: string): ValidationResult {
  const v = value.trim();
  if (!v) return { valid: true };
  if (!v.startsWith("https://") && !v.startsWith("http://")) {
    return { valid: false, error: "Must be a public URL starting with https://" };
  }
  try {
    new URL(v);
    return { valid: true };
  } catch {
    return { valid: false, error: "Not a valid URL" };
  }
}

/** Dispatch to the right validator for the given criterion type. */
export function validateCriterionValue(type: string, value: string): ValidationResult {
  if (!value.trim()) return { valid: true }; // empty fields are always OK
  switch (type) {
    case "github":
      return validateGithubRepo(value);
    case "contract":
      return validateContractAddress(value);
    case "demo":
    case "video":
    case "docs":
    case "test":
    case "website":
      return validatePublicUrl(value);
    default:
      return { valid: true }; // "other" and unknown: no format constraint
  }
}

/**
 * Returns true only if a fact flag (repo_exists=true, etc.) should be
 * generated for this field. Requires a non-empty value that passes format validation.
 *
 * Invalid strings — e.g. "my repo" for a github field — return false here,
 * so they are stored as raw input but never generate a misleading fact.
 */
export function canGenerateFact(type: string, value: string): boolean {
  const v = value.trim();
  if (!v) return false;
  return validateCriterionValue(type, v).valid;
}

/** Returns true if any filled-in field fails validation (blocks form submit). */
export function hasValidationErrors(
  values: Record<string, string | undefined>,
  types: string[],
): boolean {
  return types.some((type) => {
    const v = values[type]?.trim() ?? "";
    if (!v) return false;
    return !validateCriterionValue(type, v).valid;
  });
}
