// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script, console2 } from "forge-std/Script.sol";

/// @title BuildRealEvidence
/// @notice Builds conservative real-data evidence JSON for Escrow and GrantRound live sanity scenarios.
/// @dev This is intentionally Foundry-native. It validates URL/address formats and deployed bytecode through the
/// active RPC context. Foundry scripts do not perform HTTP requests without FFI, so HTTP reachability is marked
/// `unknown` rather than `true`.
contract BuildRealEvidence is Script {
    string private constant _DEFAULT_REPO = "https://github.com/VitalR/vigilia-protocol";
    string private constant _DEFAULT_RAW_BASE = "https://raw.githubusercontent.com/VitalR/vigilia-protocol/main";
    string private constant _DEFAULT_EXPLORER = "https://shannon-explorer.somnia.network/";

    address private constant _DEFAULT_ESCROW = 0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9;
    address private constant _DEFAULT_GRANT_ROUND = 0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679;

    struct EvidenceConfig {
        string kind;
        string outDir;
        string repoURI;
        address contractAddress;
        string explorerURI;
        string docsURI;
        string proofURI;
        string dashboardURI;
        string websiteURI;
        string summary;
    }

    struct Validation {
        bool repoUrlValid;
        string repoReachable;
        bool docsUrlValid;
        string docsReachable;
        bool proofUrlValid;
        string proofReachable;
        bool deploymentAddressFormatValid;
        bool deploymentHasCode;
        string demoUrlValid;
        string demoUrlReachable;
        bool websiteUrlValid;
        string websiteReachable;
    }

    function run() external {
        string memory repoURI = vm.envOr("VIGILIA_REAL_REPO_URI", _DEFAULT_REPO);
        string memory rawBase = vm.envOr("VIGILIA_REAL_RAW_BASE", _DEFAULT_RAW_BASE);
        string memory explorerBase = vm.envOr("SOMNIA_BLOCK_EXPLORER", _DEFAULT_EXPLORER);
        string memory dashboardURI = vm.envOr("VIGILIA_DASHBOARD_URL", string(""));

        address escrowAddress = vm.envOr("VIGILIA_MULTI_AGENT_ESCROW", _DEFAULT_ESCROW);
        address grantRoundAddress = vm.envOr("VIGILIA_GRANT_ROUND", _DEFAULT_GRANT_ROUND);

        _writeEvidence(
            EvidenceConfig({
                kind: "escrow",
                outDir: "demo/evidence/escrow-real",
                repoURI: repoURI,
                contractAddress: escrowAddress,
                explorerURI: _explorerURI(explorerBase, escrowAddress),
                docsURI: vm.envOr(
                    "VIGILIA_REAL_ESCROW_DOCS_URI", string.concat(rawBase, "/docs/13_TWO_AGENT_SETTLEMENT_RUNBOOK.md")
                ),
                proofURI: vm.envOr(
                    "VIGILIA_REAL_ESCROW_PROOF_URI",
                    string.concat(rawBase, "/docs/proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md")
                ),
                dashboardURI: dashboardURI,
                websiteURI: vm.envOr(
                    "VIGILIA_REAL_ESCROW_WEBSITE_URI",
                    string.concat(rawBase, "/demo/evidence/escrow-real/website-real-complete.html")
                ),
                summary: "Real Vigilia Escrow evidence built from the public repository, deployed v0.2.3 Escrow contract, runbook, and proof docs."
            })
        );

        _writeEvidence(
            EvidenceConfig({
                kind: "grant",
                outDir: "demo/evidence/grants-real",
                repoURI: repoURI,
                contractAddress: grantRoundAddress,
                explorerURI: _explorerURI(explorerBase, grantRoundAddress),
                docsURI: vm.envOr(
                    "VIGILIA_REAL_GRANT_DOCS_URI", string.concat(rawBase, "/docs/15_GRANT_ROUND_RUNBOOK.md")
                ),
                proofURI: vm.envOr(
                    "VIGILIA_REAL_GRANT_PROOF_URI",
                    string.concat(rawBase, "/docs/proofs/2026-06-03-grant-round-three-agent-proof.md")
                ),
                dashboardURI: dashboardURI,
                websiteURI: vm.envOr(
                    "VIGILIA_REAL_GRANT_WEBSITE_URI",
                    string.concat(rawBase, "/demo/evidence/grants-real/website-real-complete.html")
                ),
                summary: "Real Vigilia GrantRound evidence built from the public repository, deployed v0.4 GrantRound contract, runbook, and proof docs."
            })
        );
    }

    function _writeEvidence(EvidenceConfig memory _cfg) private {
        Validation memory validation = Validation({
            repoUrlValid: _isGithubRepoURL(_cfg.repoURI),
            repoReachable: "unknown",
            docsUrlValid: _isHttpURL(_cfg.docsURI),
            docsReachable: "unknown",
            proofUrlValid: _isHttpURL(_cfg.proofURI),
            proofReachable: "unknown",
            deploymentAddressFormatValid: _cfg.contractAddress != address(0),
            deploymentHasCode: _cfg.contractAddress.code.length != 0,
            demoUrlValid: bytes(_cfg.dashboardURI).length == 0 ? "unknown" : _boolString(_isHttpURL(_cfg.dashboardURI)),
            demoUrlReachable: "unknown",
            websiteUrlValid: _isHttpURL(_cfg.websiteURI),
            websiteReachable: "unknown"
        });

        vm.createDir(_cfg.outDir, true);
        string memory evidence = _evidenceJSON(_cfg, validation);
        vm.writeFile(string.concat(_cfg.outDir, "/evidence-real-conservative.json"), evidence);
        vm.writeFile(string.concat(_cfg.outDir, "/evidence-real-complete.json"), evidence);
        vm.writeFile(string.concat(_cfg.outDir, "/website-real-complete.html"), _websiteHTML(_cfg, validation));
        vm.writeFile(string.concat(_cfg.outDir, "/validation-notes.md"), _validationNotes(_cfg, validation));
        vm.writeFile(string.concat(_cfg.outDir, "/README.md"), _readme(_cfg.kind));

        console2.log("wrote", string.concat(_cfg.outDir, "/evidence-real-conservative.json"));
        console2.log("deploymentHasCode", validation.deploymentHasCode);
    }

    function _evidenceJSON(EvidenceConfig memory _cfg, Validation memory _v) private pure returns (string memory) {
        return string.concat(
            "{\n",
            '  "schema": "vigilia-real-evidence-v1",\n',
            '  "kind": "',
            _cfg.kind,
            '",\n',
            '  "raw": {\n',
            '    "repoURI": "',
            _cfg.repoURI,
            '",\n',
            '    "contractAddress": "',
            vm.toString(_cfg.contractAddress),
            '",\n',
            '    "explorerURI": "',
            _cfg.explorerURI,
            '",\n',
            '    "docsURI": "',
            _cfg.docsURI,
            '",\n',
            '    "proofURI": "',
            _cfg.proofURI,
            '",\n',
            '    "dashboardURI": "',
            _cfg.dashboardURI,
            '",\n',
            '    "summary": "',
            _cfg.summary,
            '"\n',
            "  },\n",
            '  "facts": "',
            _facts(_v),
            '",\n',
            '  "websiteURI": "',
            _cfg.websiteURI,
            '",\n',
            '  "validation": ',
            _validationJSON(_v),
            "\n}\n"
        );
    }

    function _validationJSON(Validation memory _v) private pure returns (string memory) {
        return string.concat(
            "{\n",
            '    "repoUrlValid": ',
            _boolString(_v.repoUrlValid),
            ",\n",
            '    "repoReachable": "',
            _v.repoReachable,
            '",\n',
            '    "docsUrlValid": ',
            _boolString(_v.docsUrlValid),
            ",\n",
            '    "docsReachable": "',
            _v.docsReachable,
            '",\n',
            '    "proofUrlValid": ',
            _boolString(_v.proofUrlValid),
            ",\n",
            '    "proofReachable": "',
            _v.proofReachable,
            '",\n',
            '    "deploymentAddressFormatValid": ',
            _boolString(_v.deploymentAddressFormatValid),
            ",\n",
            '    "deploymentHasCode": ',
            _boolString(_v.deploymentHasCode),
            ",\n",
            '    "demoUrlValid": "',
            _v.demoUrlValid,
            '",\n',
            '    "demoUrlReachable": "',
            _v.demoUrlReachable,
            '",\n',
            '    "websiteUrlValid": ',
            _boolString(_v.websiteUrlValid),
            ",\n",
            '    "websiteReachable": "',
            _v.websiteReachable,
            '"\n',
            "  }"
        );
    }

    function _facts(Validation memory _v) private pure returns (string memory) {
        return string.concat(
            "repo_url_valid=",
            _boolString(_v.repoUrlValid),
            "; repo_exists=",
            _v.repoReachable,
            "; docs_url_valid=",
            _boolString(_v.docsUrlValid),
            "; docs_reachable=",
            _v.docsReachable,
            "; proof_url_valid=",
            _boolString(_v.proofUrlValid),
            "; proof_reachable=",
            _v.proofReachable,
            "; deployment_address_format_valid=",
            _boolString(_v.deploymentAddressFormatValid),
            "; deployment_has_code=",
            _boolString(_v.deploymentHasCode),
            "; demo_url_valid=",
            _v.demoUrlValid,
            "; demo_url_reachable=",
            _v.demoUrlReachable,
            "; website_url_valid=",
            _boolString(_v.websiteUrlValid),
            "; website_reachable=",
            _v.websiteReachable
        );
    }

    function _websiteHTML(EvidenceConfig memory _cfg, Validation memory _v) private pure returns (string memory) {
        return string.concat(
            "<!doctype html>\n<html lang=\"en\">\n<head><meta charset=\"utf-8\"><title>Vigilia ",
            _cfg.kind,
            " real evidence</title></head>\n<body><main>\n<h1>Vigilia ",
            _cfg.kind,
            " real evidence</h1>\n<p>",
            _cfg.summary,
            "</p>\n<ul>\n<li>Repository: <a href=\"",
            _cfg.repoURI,
            "\">",
            _cfg.repoURI,
            "</a></li>\n<li>Deployed contract: <a href=\"",
            _cfg.explorerURI,
            "\">",
            vm.toString(_cfg.contractAddress),
            "</a></li>\n<li>Runbook: <a href=\"",
            _cfg.docsURI,
            "\">",
            _cfg.docsURI,
            "</a></li>\n<li>Proof doc: <a href=\"",
            _cfg.proofURI,
            "\">",
            _cfg.proofURI,
            "</a></li>\n</ul>\n<pre>",
            _facts(_v),
            "</pre>\n</main></body>\n</html>\n"
        );
    }

    function _validationNotes(EvidenceConfig memory _cfg, Validation memory _v) private pure returns (string memory) {
        return string.concat(
            "# Validation Notes\n\n",
            "`evidence-real-conservative.json` is generated only after Foundry validation checks. The legacy ",
            "`evidence-real-complete.json` path is kept as a compatibility copy, but it is conservative and does not ",
            "guarantee a Complete verdict.\n\n",
            "## Raw Inputs\n\n",
            "- repoURI: ",
            _cfg.repoURI,
            "\n- contractAddress: ",
            vm.toString(_cfg.contractAddress),
            "\n- docsURI: ",
            _cfg.docsURI,
            "\n- proofURI: ",
            _cfg.proofURI,
            "\n- dashboardURI: ",
            bytes(_cfg.dashboardURI).length == 0 ? "not configured" : _cfg.dashboardURI,
            "\n\n## Validation\n\n",
            "- repoUrlValid: ",
            _boolString(_v.repoUrlValid),
            "\n- repoReachable: ",
            _v.repoReachable,
            "\n- docsUrlValid: ",
            _boolString(_v.docsUrlValid),
            "\n- docsReachable: ",
            _v.docsReachable,
            "\n- proofUrlValid: ",
            _boolString(_v.proofUrlValid),
            "\n- proofReachable: ",
            _v.proofReachable,
            "\n- deploymentAddressFormatValid: ",
            _boolString(_v.deploymentAddressFormatValid),
            "\n- deploymentHasCode: ",
            _boolString(_v.deploymentHasCode),
            "\n- demoUrlValid: ",
            _v.demoUrlValid,
            "\n- demoUrlReachable: ",
            _v.demoUrlReachable,
            "\n- websiteUrlValid: ",
            _boolString(_v.websiteUrlValid),
            "\n- websiteReachable: ",
            _v.websiteReachable,
            "\n\nFoundry-native scripts do not perform HTTP requests without FFI. HTTP reachability is `unknown`, never `true`.\n"
        );
    }

    function _readme(string memory _kind) private pure returns (string memory) {
        string memory title =
            keccak256(bytes(_kind)) == keccak256("grant") ? "GrantRound Real Evidence" : "Escrow Real Evidence";
        return string.concat(
            "# ",
            title,
            "\n\n",
            "This folder contains real-data evidence for live Somnia-agent sanity scenarios.\n\n",
            "Unlike deterministic demo fixtures, these files are built from public Vigilia repository artifacts and deployed contract code checks.\n\n",
            "Run:\n\n```bash\n",
            "forge script script/demo/BuildRealEvidence.s.sol:BuildRealEvidence --rpc-url \"$SOMNIA_RPC_URL\"\n",
            "```\n\n",
            "The Foundry builder writes `evidence-real-conservative.json` and marks deployed code facts as `true` only after RPC bytecode validation. HTTP reachability remains `unknown` in this Foundry-native script.\n\n",
            "For public HTTP/GitHub reachability checks, run `make build-web-validated-evidence` and use `evidence-real-verified-complete.json`.\n"
        );
    }

    function _explorerURI(string memory _base, address _address) private pure returns (string memory) {
        bytes memory base = bytes(_base);
        if (base.length != 0 && base[base.length - 1] == "/") {
            return string.concat(_base, "address/", vm.toString(_address));
        }
        return string.concat(_base, "/address/", vm.toString(_address));
    }

    function _isGithubRepoURL(string memory _value) private pure returns (bool) {
        return _startsWith(_value, "https://github.com/") && _pathSegmentCount(_value, "https://github.com/") >= 2;
    }

    function _isHttpURL(string memory _value) private pure returns (bool) {
        return _startsWith(_value, "https://") || _startsWith(_value, "http://");
    }

    function _startsWith(string memory _value, string memory _prefix) private pure returns (bool) {
        bytes memory value = bytes(_value);
        bytes memory prefix = bytes(_prefix);
        if (value.length < prefix.length) return false;
        for (uint256 i = 0; i < prefix.length; ++i) {
            if (value[i] != prefix[i]) return false;
        }
        return true;
    }

    function _pathSegmentCount(string memory _value, string memory _prefix) private pure returns (uint256 count) {
        bytes memory value = bytes(_value);
        uint256 start = bytes(_prefix).length;
        bool inSegment;
        for (uint256 i = start; i < value.length; ++i) {
            if (value[i] == "/") {
                inSegment = false;
            } else if (!inSegment) {
                inSegment = true;
                ++count;
            }
        }
    }

    function _boolString(bool _value) private pure returns (string memory) {
        return _value ? "true" : "false";
    }
}
