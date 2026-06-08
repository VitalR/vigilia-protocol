#!/usr/bin/env node

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import { dirname, resolve } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../../..");
const execFileAsync = promisify(execFile);

const DEFAULTS = {
  repoURI: "https://github.com/VitalR/vigilia-protocol",
  rawBase: "https://raw.githubusercontent.com/VitalR/vigilia-protocol/main",
  explorerBase: "https://shannon-explorer.somnia.network",
  rpcURL: "https://api.infra.testnet.somnia.network/",
  escrowAddress: "0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9",
  grantRoundAddress: "0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679"
};

await loadDotEnv();

const repoURI = env("VIGILIA_REAL_REPO_URI", DEFAULTS.repoURI);
const rawBase = stripTrailingSlash(env("VIGILIA_REAL_RAW_BASE", DEFAULTS.rawBase));
const explorerBase = stripTrailingSlash(env("SOMNIA_BLOCK_EXPLORER", DEFAULTS.explorerBase));
const dashboardURI = env("VIGILIA_DASHBOARD_URL", "");
const rpcURL = env("SOMNIA_RPC_URL", DEFAULTS.rpcURL);

const configs = [
  {
    kind: "escrow",
    outDir: "demo/evidence/escrow-real",
    repoURI,
    contractAddress: env("VIGILIA_MULTI_AGENT_ESCROW", DEFAULTS.escrowAddress),
    explorerURI: `${explorerBase}/address/${env("VIGILIA_MULTI_AGENT_ESCROW", DEFAULTS.escrowAddress)}`,
    docsURI: env("VIGILIA_REAL_ESCROW_DOCS_URI", `${rawBase}/docs/13_TWO_AGENT_SETTLEMENT_RUNBOOK.md`),
    proofURI: env(
      "VIGILIA_REAL_ESCROW_PROOF_URI",
      `${rawBase}/docs/proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md`
    ),
    dashboardURI,
    websiteURI: env(
      "VIGILIA_REAL_ESCROW_WEBSITE_URI",
      `${rawBase}/demo/evidence/escrow-real/website-real-complete.html`
    ),
    summary:
      "Real Vigilia Escrow evidence built from the public repository, deployed v0.2.3 Escrow contract, runbook, and proof docs."
  },
  {
    kind: "grant",
    outDir: "demo/evidence/grants-real",
    repoURI,
    contractAddress: env("VIGILIA_GRANT_ROUND_THREE_AGENT", DEFAULTS.grantRoundAddress),
    explorerURI: `${explorerBase}/address/${env("VIGILIA_GRANT_ROUND_THREE_AGENT", DEFAULTS.grantRoundAddress)}`,
    docsURI: env("VIGILIA_REAL_GRANT_DOCS_URI", `${rawBase}/docs/15_GRANT_ROUND_RUNBOOK.md`),
    proofURI: env(
      "VIGILIA_REAL_GRANT_PROOF_URI",
      `${rawBase}/docs/proofs/2026-06-03-grant-round-three-agent-proof.md`
    ),
    dashboardURI,
    websiteURI: env(
      "VIGILIA_REAL_GRANT_WEBSITE_URI",
      `${rawBase}/demo/evidence/grants-real/website-real-complete.html`
    ),
    summary:
      "Real Vigilia GrantRound evidence built from the public repository, deployed v0.4 GrantRound contract, runbook, and proof docs."
  }
];

for (const cfg of configs) {
  const validation = await validateEvidence(cfg, rpcURL);
  await writeEvidence(cfg, validation);
  console.log(`wrote ${cfg.outDir}/evidence-real-verified-complete.json`);
  console.log(`deploymentHasCode ${validation.deploymentHasCode}`);
}

async function validateEvidence(cfg, rpcURLValue) {
  const repo = parseGithubRepoURL(cfg.repoURI);
  const repoUrlValid = repo !== null;
  const docsUrlValid = isHttpURL(cfg.docsURI);
  const proofUrlValid = isHttpURL(cfg.proofURI);
  const websiteUrlValid = isHttpURL(cfg.websiteURI);
  const dashboardConfigured = cfg.dashboardURI.trim() !== "";
  const demoUrlValid = dashboardConfigured ? boolString(isHttpURL(cfg.dashboardURI)) : "unknown";

  return {
    repoUrlValid,
    repoReachable: repoUrlValid ? await githubRepoReachable(repo) : false,
    readmeReachable: repoUrlValid ? await githubReadmeReachable(repo) : false,
    docsUrlValid,
    docsReachable: docsUrlValid ? await httpStatusOK(cfg.docsURI) : false,
    proofUrlValid,
    proofReachable: proofUrlValid ? await httpStatusOK(cfg.proofURI) : false,
    deploymentAddressFormatValid: isEVMAddress(cfg.contractAddress),
    deploymentHasCode: isEVMAddress(cfg.contractAddress) ? await rpcHasCode(rpcURLValue, cfg.contractAddress) : false,
    demoUrlValid,
    demoUrlReachable: dashboardConfigured && isHttpURL(cfg.dashboardURI) ? await httpStatusOK(cfg.dashboardURI) : "unknown",
    websiteUrlValid,
    websiteReachable: websiteUrlValid ? await httpStatusOK(cfg.websiteURI) : false
  };
}

async function writeEvidence(cfg, validation) {
  const outDir = resolve(repoRoot, cfg.outDir);
  await mkdir(outDir, { recursive: true });

  await writeFile(resolve(outDir, "evidence-real-verified-complete.json"), evidenceJSON(cfg, validation));
  await writeFile(resolve(outDir, "website-real-complete.html"), websiteHTML(cfg, validation));
  await writeFile(resolve(outDir, "validation-report-web.md"), validationReport(cfg, validation));
}

function evidenceJSON(cfg, v) {
  const payload = {
    schema: "vigilia-real-evidence-v1",
    kind: cfg.kind,
    raw: {
      repoURI: cfg.repoURI,
      contractAddress: cfg.contractAddress,
      explorerURI: cfg.explorerURI,
      docsURI: cfg.docsURI,
      proofURI: cfg.proofURI,
      dashboardURI: cfg.dashboardURI,
      summary: cfg.summary
    },
    facts: facts(v),
    websiteURI: cfg.websiteURI,
    validation: {
      repoUrlValid: v.repoUrlValid,
      repoReachable: value(v.repoReachable),
      readmeReachable: value(v.readmeReachable),
      docsUrlValid: v.docsUrlValid,
      docsReachable: value(v.docsReachable),
      proofUrlValid: v.proofUrlValid,
      proofReachable: value(v.proofReachable),
      deploymentAddressFormatValid: v.deploymentAddressFormatValid,
      deploymentHasCode: value(v.deploymentHasCode),
      demoUrlValid: value(v.demoUrlValid),
      demoUrlReachable: value(v.demoUrlReachable),
      websiteUrlValid: v.websiteUrlValid,
      websiteReachable: value(v.websiteReachable)
    }
  };

  return `${JSON.stringify(payload, null, 2)}\n`;
}

function facts(v) {
  return [
    `repo_url_valid=${boolString(v.repoUrlValid)}`,
    `repo_exists=${factValue(v.repoReachable)}`,
    `readme_exists=${factValue(v.readmeReachable)}`,
    `docs_url_valid=${boolString(v.docsUrlValid)}`,
    `docs_reachable=${factValue(v.docsReachable)}`,
    `proof_url_valid=${boolString(v.proofUrlValid)}`,
    `proof_reachable=${factValue(v.proofReachable)}`,
    `deployment_address_format_valid=${boolString(v.deploymentAddressFormatValid)}`,
    `deployment_has_code=${factValue(v.deploymentHasCode)}`,
    `website_url_valid=${boolString(v.websiteUrlValid)}`,
    `website_reachable=${factValue(v.websiteReachable)}`,
    `demo_url_valid=${factValue(v.demoUrlValid)}`,
    `demo_url_reachable=${factValue(v.demoUrlReachable)}`
  ].join("; ");
}

function websiteHTML(cfg, v) {
  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Vigilia ${escapeHTML(cfg.kind)} real evidence</title></head>
<body><main>
<h1>Vigilia ${escapeHTML(cfg.kind)} real evidence</h1>
<p>${escapeHTML(cfg.summary)}</p>
<ul>
<li>Repository: <a href="${escapeHTML(cfg.repoURI)}">${escapeHTML(cfg.repoURI)}</a></li>
<li>Deployed contract: <a href="${escapeHTML(cfg.explorerURI)}">${escapeHTML(cfg.contractAddress)}</a></li>
<li>Runbook: <a href="${escapeHTML(cfg.docsURI)}">${escapeHTML(cfg.docsURI)}</a></li>
<li>Proof doc: <a href="${escapeHTML(cfg.proofURI)}">${escapeHTML(cfg.proofURI)}</a></li>
</ul>
<pre>${escapeHTML(facts(v))}</pre>
</main></body>
</html>
`;
}

function validationReport(cfg, v) {
  return `# Web Validation Report

This report was generated by \`app/evidence-tool/scripts/build-real-evidence.mjs\`.

## Raw Inputs

- repoURI: ${cfg.repoURI}
- contractAddress: ${cfg.contractAddress}
- docsURI: ${cfg.docsURI}
- proofURI: ${cfg.proofURI}
- websiteURI: ${cfg.websiteURI}
- dashboardURI: ${cfg.dashboardURI || "not configured"}

## Validation

- repoUrlValid: ${boolString(v.repoUrlValid)}
- repoReachable: ${factValue(v.repoReachable)}
- readmeReachable: ${factValue(v.readmeReachable)}
- docsUrlValid: ${boolString(v.docsUrlValid)}
- docsReachable: ${factValue(v.docsReachable)}
- proofUrlValid: ${boolString(v.proofUrlValid)}
- proofReachable: ${factValue(v.proofReachable)}
- deploymentAddressFormatValid: ${boolString(v.deploymentAddressFormatValid)}
- deploymentHasCode: ${factValue(v.deploymentHasCode)}
- websiteUrlValid: ${boolString(v.websiteUrlValid)}
- websiteReachable: ${factValue(v.websiteReachable)}
- demoUrlValid: ${factValue(v.demoUrlValid)}
- demoUrlReachable: ${factValue(v.demoUrlReachable)}

Positive facts are marked \`true\` only when the matching HTTP/GitHub/RPC check succeeded. Failed checks are \`false\`; skipped checks are \`unknown\`.
`;
}

async function githubRepoReachable(repo) {
  return httpStatusOK(`https://api.github.com/repos/${repo.owner}/${repo.name}`);
}

async function githubReadmeReachable(repo) {
  return httpStatusOK(`https://api.github.com/repos/${repo.owner}/${repo.name}/readme`);
}

async function httpStatusOK(url) {
  try {
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "User-Agent": "vigilia-evidence-tools"
      },
      redirect: "follow"
    });
    return response.status >= 200 && response.status < 300;
  } catch {
    return httpStatusOKWithCurl(url);
  }
}

async function rpcHasCode(rpcURLValue, address) {
  if (!isHttpURL(rpcURLValue)) return "unknown";

  try {
    const response = await fetch(rpcURLValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "eth_getCode",
        params: [address, "latest"]
      })
    });

    if (!response.ok) return "unknown";
    const json = await response.json();
    if (typeof json.result !== "string") return "unknown";
    return json.result !== "0x";
  } catch {
    return rpcHasCodeWithCurl(rpcURLValue, address);
  }
}

async function httpStatusOKWithCurl(url) {
  try {
    const { stdout } = await execFileAsync("curl", [
      "-L",
      "-sS",
      "-o",
      "/dev/null",
      "-w",
      "%{http_code}",
      url
    ]);
    const status = Number(stdout.trim());
    return status >= 200 && status < 300;
  } catch {
    return "unknown";
  }
}

async function rpcHasCodeWithCurl(rpcURLValue, address) {
  try {
    const { stdout } = await execFileAsync("curl", [
      "-sS",
      "-H",
      "Content-Type: application/json",
      "-d",
      JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "eth_getCode",
        params: [address, "latest"]
      }),
      rpcURLValue
    ]);
    const json = JSON.parse(stdout);
    if (typeof json.result !== "string") return "unknown";
    return json.result !== "0x";
  } catch {
    return "unknown";
  }
}

async function loadDotEnv() {
  try {
    const content = await readFile(resolve(repoRoot, ".env"), "utf8");
    for (const rawLine of content.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (line === "" || line.startsWith("#")) continue;
      const eq = line.indexOf("=");
      if (eq === -1) continue;
      const key = line.slice(0, eq).trim();
      const rawValue = line.slice(eq + 1).trim();
      if (!(key in process.env)) process.env[key] = unquote(rawValue);
    }
  } catch {
    // .env is optional. Public defaults cover the canonical evidence files.
  }
}

function env(name, fallback) {
  const valueToRead = process.env[name];
  return valueToRead === undefined || valueToRead === "" ? fallback : valueToRead;
}

function parseGithubRepoURL(valueToParse) {
  try {
    const url = new URL(valueToParse);
    if (url.protocol !== "https:" || url.hostname !== "github.com") return null;
    const segments = url.pathname.split("/").filter(Boolean);
    if (segments.length < 2) return null;
    return { owner: segments[0], name: segments[1].replace(/\.git$/, "") };
  } catch {
    return null;
  }
}

function isHttpURL(valueToCheck) {
  try {
    const url = new URL(valueToCheck);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

function isEVMAddress(valueToCheck) {
  return /^0x[a-fA-F0-9]{40}$/.test(valueToCheck);
}

function stripTrailingSlash(valueToStrip) {
  return valueToStrip.endsWith("/") ? valueToStrip.slice(0, -1) : valueToStrip;
}

function factValue(valueToFormat) {
  if (valueToFormat === "unknown") return "unknown";
  return valueToFormat ? "true" : "false";
}

function value(valueToFormat) {
  return valueToFormat === "unknown" ? "unknown" : Boolean(valueToFormat);
}

function boolString(valueToFormat) {
  return valueToFormat ? "true" : "false";
}

function unquote(valueToUnquote) {
  if (
    (valueToUnquote.startsWith("\"") && valueToUnquote.endsWith("\""))
    || (valueToUnquote.startsWith("'") && valueToUnquote.endsWith("'"))
  ) {
    return valueToUnquote.slice(1, -1);
  }
  return valueToUnquote;
}

function escapeHTML(valueToEscape) {
  return valueToEscape
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
