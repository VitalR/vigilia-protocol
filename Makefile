SHELL := /bin/bash

-include .env
.EXPORT_ALL_VARIABLES:

DEPLOYMENT_ARTIFACT ?= deployments/somnia-testnet-50312.json
DEPLOY_SCRIPT ?= script/deploy/DeployVigiliaSystem.s.sol:DeployVigiliaSystem
MULTI_AGENT_DEPLOY_SCRIPT ?= script/deploy/DeployVigiliaMultiAgentVerifier.s.sol:DeployVigiliaMultiAgentVerifier
MULTI_SETTLEMENT_DEPLOY_SCRIPT ?= script/deploy/DeployVigiliaMultiAgentSettlement.s.sol:DeployVigiliaMultiAgentSettlement
MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT ?= deployments/somnia-testnet-50312-two-agent-settlement-hardened.json
GRANT_ROUND_DEPLOY_SCRIPT ?= script/deploy/DeployVigiliaGrantRound.s.sol:DeployVigiliaGrantRound
GRANT_ROUND_DEPLOYMENT_ARTIFACT ?= deployments/somnia-testnet-50312-grant-round.json
GRANT_ROUND_DEMO_SCRIPT ?= script/demo/VigiliaGrantRoundDemo.s.sol:VigiliaGrantRoundDemo
MULTI_SETTLEMENT_DEMO_SCRIPT ?= script/demo/VigiliaMultiAgentSettlementDemo.s.sol:VigiliaMultiAgentSettlementDemo
DEMO_SCRIPT ?= script/demo/VigiliaJsonApiSmokeDemo.s.sol:VigiliaJsonApiSmokeDemo
CANARY_SCRIPT ?= script/demo/VigiliaAgentCanary.s.sol:VigiliaAgentCanary
MULTI_SETTLEMENT_EVIDENCE_COMPLETE_URL ?= https://httpbin.org/base64/eyJmYWN0cyI6InJlcG9fZXhpc3RzPXRydWU7IHJlYWRtZV9zZXR1cD10cnVlOyBkZXBsb3ltZW50X2FkZHJlc3NfcHJlc2VudD10cnVlOyBkZW1vX3VybF9wcmVzZW50PXRydWU7IHRlc3RzX3Bhc3NlZD10cnVlIn0=
MULTI_SETTLEMENT_EVIDENCE_INCOMPLETE_URL ?= https://httpbin.org/base64/eyJmYWN0cyI6InJlcG9fZXhpc3RzPXRydWU7IHJlYWRtZV9zZXR1cD10cnVlOyBkZXBsb3ltZW50X2FkZHJlc3NfcHJlc2VudD1mYWxzZTsgZGVtb191cmxfcHJlc2VudD1mYWxzZTsgdGVzdHNfcGFzc2VkPWZhbHNlIn0=
MULTI_SETTLEMENT_EVIDENCE_NEEDS_REVIEW_URL ?= https://httpbin.org/base64/eyJmYWN0cyI6InJlcG9fZXhpc3RzPXRydWU7IHJlYWRtZV9zZXR1cD10cnVlOyBkZXBsb3ltZW50X2FkZHJlc3NfcHJlc2VudD11bmNsZWFyOyBkZW1vX3VybF9wcmVzZW50PXRydWU7IHRlc3RzX3Bhc3NlZD11bmtub3duIn0=
MULTI_SETTLEMENT_EVIDENCE_MALFORMED_URL ?= https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=
MULTI_SETTLEMENT_GAS_ESTIMATE_MULTIPLIER ?= 2000
MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER ?= 2000
GAS_ESTIMATE_MULTIPLIER ?= 200
DEMO_GAS_ESTIMATE_MULTIPLIER ?= 200
DEMO_GAS_LIMIT ?= 10000000
DEMO_CALL_GAS_LIMIT ?= 10000000

.PHONY: help fmt build test check env-check account balance platform-code platform-deposit platform-check \
	deploy-somnia deploy-somnia-dry-run show-deployment verify-somnia-escrow verify-somnia-json-verifier verify-somnia-verifier \
	deployment-addresses verifier-deposit evidence-url required-agent-deposit \
	demo-create-task demo-fund-task demo-submit-complete demo-submit-malformed demo-inspect-task demo-approve-task \
	demo-claim-task demo-retry-verification \
	multi-agent-deploy-dry-run multi-agent-deploy-somnia multi-agent-canary-json \
	multi-agent-canary-llm-inference multi-agent-canary-llm-parse multi-agent-canary-inspect \
	multi-agent-deposit-json multi-agent-deposit-llm-inference multi-agent-deposit-llm-parse \
	multi-settlement-env-check multi-settlement-deploy-dry-run multi-settlement-deploy-somnia \
	multi-settlement-enrich-artifact multi-settlement-show-deployment multi-settlement-deployment-addresses \
	multi-settlement-verifier-deposit multi-settlement-verify-verifier multi-settlement-verify-escrow \
	multi-settlement-demo-create-task multi-settlement-demo-fund-task multi-settlement-demo-submit-complete \
	multi-settlement-demo-submit-incomplete multi-settlement-demo-submit-needs-review \
	multi-settlement-demo-submit-malformed multi-settlement-demo-inspect-task multi-settlement-demo-approve-task \
	multi-settlement-demo-claim-task multi-settlement-demo-retry-verification \
	multi-settlement-demo-continue-llm-verification multi-agent-demo-create-task \
	multi-agent-demo-create-task-immediate-claim multi-agent-demo-create-task-client-approval \
	multi-agent-demo-fund-task multi-agent-demo-submit-facts-complete multi-agent-demo-submit-facts-incomplete \
	multi-agent-demo-submit-facts-needs-review multi-agent-demo-submit-facts-malformed \
	multi-agent-demo-continue-llm-verification multi-agent-demo-inspect-task multi-agent-demo-approve-task \
	multi-agent-demo-claim-task multi-agent-demo-retry-verification \
	grant-round-env-check grant-round-deploy-dry-run grant-round-deploy-somnia \
	grant-round-show-deployment grant-round-bind-verifier grant-round-verifier-deposit \
	grant-round-verify-verifier grant-round-verify-contract grant-round-verify-state \
	grant-round-verify-all \
	grant-demo grant-demo-inspect grant-demo-create-round grant-demo-fund-round \
	grant-demo-submit-application grant-demo-submit-complete grant-demo-submit-needs-review \
	grant-demo-submit-incomplete grant-demo-submit-malformed grant-demo-request-screening \
	grant-demo-request-screening-complete grant-demo-request-screening-needs-review \
	grant-demo-request-screening-incomplete grant-demo-request-screening-malformed \
	grant-demo-request-screening-cast grant-demo-request-screening-complete-cast \
	grant-demo-request-screening-needs-review-cast grant-demo-request-screening-incomplete-cast \
	grant-demo-request-screening-malformed-cast \
	grant-demo-manual-screen-complete grant-demo-manual-screen-needs-review \
	grant-demo-manual-screen-incomplete grant-demo-select-finalists grant-demo-reject-application \
	grant-demo-finalize-round grant-demo-claim-prize grant-demo-refund-unallocated \
	grant-demo-withdraw-pending grant-demo-cancel-round \
	grant-demo-full-two-agent-happy-path-prep grant-demo-full-two-agent-review-board-prep \
	require-env

help:
	@echo "Vigilia Protocol commands"
	@echo ""
	@echo "General:"
	@echo "  make fmt                         Format Solidity files"
	@echo "  make build                       Build contracts"
	@echo "  make test                        Run Foundry tests"
	@echo "  make coverage                    Run Foundry coverage"
	@echo "  make check                       Run fmt check, build, tests, and git diff --check"
	@echo ""
	@echo "Environment:"
	@echo "  make env-check                   Check required deployment env vars"
	@echo "  make account                     Print deployer address derived from DEPLOYER_PRIVATE_KEY"
	@echo "  make balance                     Print deployer STT balance"
	@echo "  make platform-check              Check Somnia platform code and request deposit"
	@echo "  make deployment-addresses        Print deployed v0.1.0 addresses"
	@echo "  make verifier-deposit            Print VigiliaJsonApiVerifier minimumRequestDeposit"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-somnia-dry-run       Simulate deployment without writing deployment artifact"
	@echo "  make deploy-somnia               Broadcast deployment and write $(DEPLOYMENT_ARTIFACT)"
	@echo "  make multi-agent-deploy-dry-run  Simulate v0.2.0 canary verifier deployment"
	@echo "  make multi-agent-deploy-somnia   Broadcast v0.2.0 canary verifier deployment"
	@echo "  make grant-round-deploy-dry-run  Simulate GrantRound + fresh verifier deployment"
	@echo "  make grant-round-deploy-somnia   Broadcast GrantRound + fresh verifier deployment"
	@echo "  make show-deployment             Print deployment artifact"
	@echo ""
	@echo "Verification:"
	@echo "  make verify-somnia-json-verifier Verify VigiliaJsonApiVerifier on Blockscout"
	@echo "  make verify-somnia-verifier      Alias for verify-somnia-json-verifier"
	@echo "  make verify-somnia-escrow        Verify VigiliaEscrow on Blockscout"
	@echo ""
	@echo "Demo helpers:"
	@echo "  make evidence-url                Print configured evidence JSON URL"
	@echo "  make required-agent-deposit      Print expected request deposit in wei"
	@echo "  make demo-create-task            Create a JSON API smoke task"
	@echo "  make demo-fund-task              Fund DEMO_TASK_ID"
	@echo "  make demo-submit-complete        Submit current VIGILIA_EVIDENCE_JSON_URL"
	@echo "  make demo-submit-malformed       Submit current malformed VIGILIA_EVIDENCE_JSON_URL"
	@echo "  make demo-inspect-task           Inspect DEMO_TASK_ID"
	@echo "  make demo-approve-task           Approve DEMO_TASK_ID"
	@echo "  make demo-claim-task             Claim DEMO_TASK_ID"
	@echo "  make demo-retry-verification     Retry active failed submission for DEMO_TASK_ID"
	@echo "  make multi-agent-canary-json     Request JSON API canary"
	@echo "  make multi-agent-canary-llm-inference Request LLM Inference canary"
	@echo "  make multi-agent-canary-llm-parse Request LLM Parse Website canary"
	@echo "  make multi-agent-canary-inspect  Inspect CANARY_REQUEST_ID"
	@echo "  make multi-agent-deposit-json    Print JSON canary deposit"
	@echo "  make multi-agent-deposit-llm-inference Print LLM Inference canary deposit"
	@echo "  make multi-agent-deposit-llm-parse Print LLM Parse Website canary deposit"
	@echo ""
	@echo "v0.2.2 two-agent settlement:"
	@echo "  make multi-settlement-env-check  Check v0.2.2 settlement env vars"
	@echo "  make multi-settlement-deploy-dry-run Simulate fresh settlement deployment"
	@echo "  make multi-settlement-deploy-somnia Broadcast fresh settlement deployment"
	@echo "  make multi-settlement-show-deployment Print settlement artifact"
	@echo "  make multi-settlement-verify-verifier Verify new VigiliaMultiAgentVerifier"
	@echo "  make multi-settlement-verify-escrow Verify new VigiliaEscrow"
	@echo "  make multi-settlement-demo-create-task Create settlement demo task"
	@echo "  make multi-settlement-demo-fund-task Fund DEMO_TASK_ID on settlement escrow"
	@echo "  make multi-settlement-demo-submit-complete Submit Complete evidence URL"
	@echo "  make multi-settlement-demo-continue-llm-verification Continue LLM stage if automatic callback continuation was unavailable"
	@echo "  make multi-settlement-demo-inspect-task Inspect DEMO_TASK_ID"
	@echo "  make multi-settlement-demo-approve-task Approve DEMO_TASK_ID"
	@echo "  make multi-settlement-demo-claim-task Claim DEMO_TASK_ID"
	@echo ""
	@echo "GrantRound:"
	@echo "  make grant-round-env-check       Check GrantRound deployment env vars"
	@echo "  make grant-round-show-deployment Print GrantRound deployment artifact"
	@echo "  make grant-round-bind-verifier   Bind a fresh verifier to a GrantRound receiver"
	@echo "  make grant-round-verifier-deposit Print GrantRound two-agent workflow deposit"
	@echo "  make grant-round-verify-all      Verify GrantRound contracts and live binding"
	@echo ""
	@echo "GrantRound demo:"
	@echo "  make grant-demo-inspect          Inspect GrantRound/verifier, round, and application state"
	@echo "  make grant-demo-create-round     Create a TwoAgent grant round by default"
	@echo "  make grant-demo-fund-round       Fund GRANT_ROUND_ID exactly"
	@echo "  make grant-demo-submit-complete  Submit public Complete facts evidence"
	@echo "  make grant-demo-request-screening-complete Request async TwoAgent screening"
	@echo "  make grant-demo-request-screening-cast Direct cast fallback for live request screening"
	@echo "  make grant-demo-select-finalists Select GRANT_APPLICATION_IDS after deadline"
	@echo "  make grant-demo-finalize-round   Finalize so selected finalists can claim"
	@echo "  make grant-demo-claim-prize      Claim selected GRANT_APPLICATION_ID as applicant"
	@echo "  make grant-demo-refund-unallocated Credit unallocated sponsor refund"
	@echo "  make grant-demo-withdraw-pending Withdraw pending sponsor refund"
	@echo ""
	@echo "GrantRound current fallback campaign order:"
	@echo "  make grant-demo-create-round && export GRANT_ROUND_ID=<id>"
	@echo "  make grant-demo-fund-round"
	@echo '  export GRANT_APPLICANT_INDEX=1 GRANT_EVIDENCE_URI=$$GRANT_COMPLETE_EVIDENCE_URI; make grant-demo-submit-complete'
	@echo '  export COMPLETE_APP_ID=<id> GRANT_APPLICATION_ID=$$COMPLETE_APP_ID; make grant-demo-request-screening-complete-cast'
	@echo '  export GRANT_APPLICANT_INDEX=2 GRANT_EVIDENCE_URI=$$GRANT_NEEDS_REVIEW_EVIDENCE_URI; make grant-demo-submit-needs-review'
	@echo '  export NEEDS_REVIEW_APP_ID=<id> GRANT_APPLICATION_ID=$$NEEDS_REVIEW_APP_ID; make grant-demo-request-screening-needs-review-cast'
	@echo '  export GRANT_APPLICANT_INDEX=3 GRANT_EVIDENCE_URI=$$GRANT_COMPLETE_EVIDENCE_URI; make grant-demo-submit-complete'
	@echo '  export COMPLETE_APP_ID_2=<id> GRANT_APPLICATION_ID=$$COMPLETE_APP_ID_2; make grant-demo-request-screening-complete-cast'
	@echo '  export GRANT_APPLICANT_INDEX=4 GRANT_EVIDENCE_URI=$$GRANT_INCOMPLETE_EVIDENCE_URI; make grant-demo-submit-incomplete'
	@echo '  export INCOMPLETE_APP_ID=<id> GRANT_APPLICATION_ID=$$INCOMPLETE_APP_ID; make grant-demo-request-screening-incomplete-cast'
	@echo "  # Wait for async callbacks, then make grant-demo-inspect"
	@echo '  export GRANT_APPLICATION_IDS=$$COMPLETE_APP_ID,$$NEEDS_REVIEW_APP_ID,$$COMPLETE_APP_ID_2; make grant-demo-select-finalists'
	@echo "  make grant-demo-finalize-round"
	@echo "  export GRANT_APPLICATION_ID=<finalist id>; make grant-demo-claim-prize"
	@echo "  make grant-demo-refund-unallocated && make grant-demo-withdraw-pending"

fmt:
	forge fmt

build:
	forge build

test:
	forge test -vvv

coverage:
	@# VigiliaMultiAgentVerifier requires production via_ir; Foundry coverage uses --ir-minimum and still hits solc stack limits.
	@# Skip every test file that imports it so coverage compiles only the remaining core contracts.
	@# Full multi-agent behavior is covered by `forge test`.
	forge coverage --ir-minimum --exclude-tests \
		--skip VigiliaMultiAgentVerifier \
		--skip VigiliaGrantRoundVerifierIntegration \
		--skip script \
		--no-match-coverage "(^script/|Deploy|Demo|Smoke|Canary)" -vvv

check:
	forge fmt --check
	forge build
	forge test
	git diff --check

env-check:
	@missing=0; \
	for var in DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL SOMNIA_CHAIN_ID SOMNIA_AGENT_PLATFORM SOMNIA_AGENT_ID SOMNIA_VERDICT_SELECTOR AGENT_SUBCOMMITTEE_SIZE AGENT_PRICE_PER_VALIDATOR; do \
		if [[ -z "$${!var}" ]]; then \
			echo "MISSING $$var"; \
			missing=1; \
		else \
			echo "OK $$var"; \
		fi; \
	done; \
	if [[ "$$SOMNIA_AGENT_TYPE" != "json-api-request" ]]; then \
		echo "INVALID SOMNIA_AGENT_TYPE: expected json-api-request"; \
		missing=1; \
	else \
		echo "OK SOMNIA_AGENT_TYPE"; \
	fi; \
	if [[ -n "$$SOMNIA_JSON_API_AGENT_ID" && "$$SOMNIA_AGENT_ID" != "$$SOMNIA_JSON_API_AGENT_ID" ]]; then \
		echo "INVALID SOMNIA_AGENT_ID: must equal SOMNIA_JSON_API_AGENT_ID for vigilia-json-api-smoke"; \
		missing=1; \
	else \
		echo "OK SOMNIA_AGENT_ID matches JSON API smoke config"; \
	fi; \
	exit $$missing

require-env:
	@missing=0; \
	for var in $(VARS); do \
		if [[ -z "$${!var}" ]]; then \
			echo "Missing required env var: $$var"; \
			missing=1; \
		fi; \
	done; \
	exit $$missing

account:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY"
	@cast wallet address --private-key "$$DEPLOYER_PRIVATE_KEY"

balance:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL"
	@ADDRESS=$${DEPLOYER_ADDRESS:-$$(cast wallet address --private-key "$$DEPLOYER_PRIVATE_KEY")}; \
	cast balance "$$ADDRESS" --rpc-url "$$SOMNIA_RPC_URL" --ether

platform-code:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_AGENT_PLATFORM SOMNIA_RPC_URL"
	@cast code "$$SOMNIA_AGENT_PLATFORM" --rpc-url "$$SOMNIA_RPC_URL"

platform-deposit:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_AGENT_PLATFORM SOMNIA_RPC_URL"
	@cast call "$$SOMNIA_AGENT_PLATFORM" "getRequestDeposit()(uint256)" --rpc-url "$$SOMNIA_RPC_URL"

platform-check: platform-code platform-deposit

deploy-somnia-dry-run:
	@$(MAKE) --no-print-directory env-check
	WRITE_DEPLOYMENT_ARTIFACT=false forge script $(DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-estimate-multiplier $(GAS_ESTIMATE_MULTIPLIER) -vvvv

deploy-somnia:
	@$(MAKE) --no-print-directory env-check
	forge script $(DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-estimate-multiplier $(GAS_ESTIMATE_MULTIPLIER) --broadcast -vvvv

multi-agent-deploy-dry-run:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL SOMNIA_AGENT_PLATFORM SOMNIA_JSON_API_AGENT_ID AGENT_SUBCOMMITTEE_SIZE"
	WRITE_DEPLOYMENT_ARTIFACT=false forge script $(MULTI_AGENT_DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(GAS_ESTIMATE_MULTIPLIER) -vvvv

multi-agent-deploy-somnia:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL SOMNIA_AGENT_PLATFORM SOMNIA_JSON_API_AGENT_ID AGENT_SUBCOMMITTEE_SIZE"
	forge script $(MULTI_AGENT_DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv

show-deployment:
	@if [[ -f "$(DEPLOYMENT_ARTIFACT)" ]]; then \
		cat "$(DEPLOYMENT_ARTIFACT)"; \
	else \
		echo "Deployment artifact not found: $(DEPLOYMENT_ARTIFACT)"; \
		exit 1; \
	fi

deployment-addresses:
	@if [[ -n "$$VIGILIA_ESCROW" ]]; then echo "VIGILIA_ESCROW=$$VIGILIA_ESCROW"; fi
	@if [[ -n "$$VIGILIA_JSON_API_VERIFIER" ]]; then echo "VIGILIA_JSON_API_VERIFIER=$$VIGILIA_JSON_API_VERIFIER"; fi
	@if command -v jq >/dev/null 2>&1 && [[ -f "$(DEPLOYMENT_ARTIFACT)" ]]; then \
		jq -r '"artifact=" + input_filename, "vigiliaEscrow=" + .vigiliaEscrow, "vigiliaJsonApiVerifier=" + .vigiliaJsonApiVerifier, "deploymentName=" + .deploymentName, "version=" + .version, "activeAgentType=" + .activeAgentType' "$(DEPLOYMENT_ARTIFACT)"; \
	elif [[ -z "$$VIGILIA_ESCROW" || -z "$$VIGILIA_JSON_API_VERIFIER" ]]; then \
		echo "Set VIGILIA_ESCROW and VIGILIA_JSON_API_VERIFIER or install jq to read $(DEPLOYMENT_ARTIFACT)"; \
		exit 1; \
	fi

verify-somnia-json-verifier:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_CHAIN_ID SOMNIA_BLOCKSCOUT_API SOMNIA_AGENT_PLATFORM SOMNIA_AGENT_ID AGENT_SUBCOMMITTEE_SIZE AGENT_PRICE_PER_VALIDATOR SOMNIA_VERDICT_SELECTOR VIGILIA_JSON_API_VERIFIER"
	@DEPLOYER=$${DEPLOYER_ADDRESS:-$$(cast wallet address --private-key "$$DEPLOYER_PRIVATE_KEY")}; \
	ARGS=$$(cast abi-encode "constructor(address,address,uint256,uint256,uint256,string)" "$$SOMNIA_AGENT_PLATFORM" "$$DEPLOYER" "$$SOMNIA_AGENT_ID" "$$AGENT_SUBCOMMITTEE_SIZE" "$$AGENT_PRICE_PER_VALIDATOR" "$$SOMNIA_VERDICT_SELECTOR"); \
	forge verify-contract "$$VIGILIA_JSON_API_VERIFIER" src/VigiliaJsonApiVerifier.sol:VigiliaJsonApiVerifier --chain-id "$$SOMNIA_CHAIN_ID" --verifier blockscout --verifier-url "$$SOMNIA_BLOCKSCOUT_API" --constructor-args "$$ARGS"

verify-somnia-verifier: verify-somnia-json-verifier

verify-somnia-escrow:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_CHAIN_ID SOMNIA_BLOCKSCOUT_API VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER"
	@ARGS=$$(cast abi-encode "constructor(address)" "$$VIGILIA_JSON_API_VERIFIER"); \
	forge verify-contract "$$VIGILIA_ESCROW" src/VigiliaEscrow.sol:VigiliaEscrow --chain-id "$$SOMNIA_CHAIN_ID" --verifier blockscout --verifier-url "$$SOMNIA_BLOCKSCOUT_API" --constructor-args "$$ARGS"

evidence-url:
	@$(MAKE) --no-print-directory require-env VARS="VIGILIA_EVIDENCE_JSON_URL"
	@echo "$$VIGILIA_EVIDENCE_JSON_URL"

verifier-deposit:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_JSON_API_VERIFIER"
	@cast call "$$VIGILIA_JSON_API_VERIFIER" "minimumRequestDeposit()(uint256)" --rpc-url "$$SOMNIA_RPC_URL"

required-agent-deposit:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_AGENT_PLATFORM SOMNIA_RPC_URL AGENT_SUBCOMMITTEE_SIZE AGENT_PRICE_PER_VALIDATOR"
	@RESERVE=$$(cast call "$$SOMNIA_AGENT_PLATFORM" "getRequestDeposit()(uint256)" --rpc-url "$$SOMNIA_RPC_URL"); \
	TOTAL=$$((RESERVE + (AGENT_SUBCOMMITTEE_SIZE * AGENT_PRICE_PER_VALIDATOR))); \
	echo "$$TOTAL"

demo-create-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_AMOUNT_WEI DEMO_REVIEW_WINDOW"
	DEMO_ACTION=create forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast -vvvv

demo-fund-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=fund forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast -vvvv

demo-submit-complete:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_ID VIGILIA_EVIDENCE_JSON_URL AGENT_REQUEST_DEPOSIT_WEI"
	DEMO_ACTION=submit forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --skip-simulation -vvvv

demo-submit-malformed:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_ID VIGILIA_EVIDENCE_JSON_URL AGENT_REQUEST_DEPOSIT_WEI"
	DEMO_ACTION=submit forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --skip-simulation -vvvv

demo-inspect-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=inspect forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast -vvvv

demo-approve-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=approve forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast -vvvv

demo-claim-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=claim forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast -vvvv

demo-retry-verification:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_ESCROW VIGILIA_JSON_API_VERIFIER DEMO_TASK_ID AGENT_REQUEST_DEPOSIT_WEI"
	DEMO_ACTION=retry forge script $(DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --skip-simulation -vvvv

multi-agent-canary-json:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_VERIFIER JSON_CANARY_URL AGENT_SUBCOMMITTEE_SIZE"
	@RESERVE=$${AGENT_PLATFORM_RESERVE_WEI:-30000000000000000}; \
	PRICE=$${JSON_API_PRICE_PER_VALIDATOR_WEI:-$${AGENT_PRICE_PER_VALIDATOR:-30000000000000000}}; \
	SELECTOR=$${JSON_CANARY_SELECTOR:-$${SOMNIA_VERDICT_SELECTOR:-verdict}}; \
	DEPOSIT=$$((RESERVE + (AGENT_SUBCOMMITTEE_SIZE * PRICE))); \
	echo "Sending JSON API canary with deposit $$DEPOSIT wei"; \
	cast send "$$VIGILIA_MULTI_AGENT_VERIFIER" "requestJsonApiCanary(string,string)(uint256)" "$$JSON_CANARY_URL" "$$SELECTOR" --value "$$DEPOSIT" --gas-limit $(DEMO_GAS_LIMIT) --legacy --rpc-url "$$SOMNIA_RPC_URL" --private-key "$$DEPLOYER_PRIVATE_KEY"

multi-agent-canary-llm-inference:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_VERIFIER LLM_CANARY_PROMPT AGENT_SUBCOMMITTEE_SIZE"
	@RESERVE=$${AGENT_PLATFORM_RESERVE_WEI:-30000000000000000}; \
	PRICE=$${LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI:-70000000000000000}; \
	SYSTEM=$${LLM_CANARY_SYSTEM:-}; \
	CHAIN_OF_THOUGHT=$${LLM_CANARY_CHAIN_OF_THOUGHT:-false}; \
	DEPOSIT=$$((RESERVE + (AGENT_SUBCOMMITTEE_SIZE * PRICE))); \
	echo "Sending LLM Inference canary with deposit $$DEPOSIT wei"; \
	cast send "$$VIGILIA_MULTI_AGENT_VERIFIER" "requestLlmInferenceCanary(string,string,bool)(uint256)" "$$LLM_CANARY_PROMPT" "$$SYSTEM" "$$CHAIN_OF_THOUGHT" --value "$$DEPOSIT" --gas-limit $(DEMO_GAS_LIMIT) --legacy --rpc-url "$$SOMNIA_RPC_URL" --private-key "$$DEPLOYER_PRIVATE_KEY"

multi-agent-canary-llm-parse:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_VERIFIER WEBSITE_CANARY_URL WEBSITE_CANARY_INSTRUCTION AGENT_SUBCOMMITTEE_SIZE"
	@RESERVE=$${AGENT_PLATFORM_RESERVE_WEI:-30000000000000000}; \
	PRICE=$${LLM_PARSE_PRICE_PER_VALIDATOR_WEI:-100000000000000000}; \
	DEPOSIT=$$((RESERVE + (AGENT_SUBCOMMITTEE_SIZE * PRICE))); \
	echo "Sending LLM Parse Website canary with deposit $$DEPOSIT wei"; \
	cast send "$$VIGILIA_MULTI_AGENT_VERIFIER" "requestLlmParseWebsiteCanary(string,string)(uint256)" "$$WEBSITE_CANARY_URL" "$$WEBSITE_CANARY_INSTRUCTION" --value "$$DEPOSIT" --gas-limit $(DEMO_GAS_LIMIT) --legacy --rpc-url "$$SOMNIA_RPC_URL" --private-key "$$DEPLOYER_PRIVATE_KEY"

multi-agent-canary-inspect:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_VERIFIER CANARY_REQUEST_ID"
	CANARY_ACTION=inspect-canary forge script $(CANARY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) -vvvv

multi-agent-deposit-json:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_VERIFIER"
	CANARY_ACTION=deposit CANARY_AGENT_KIND=json-api forge script $(CANARY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) -vvvv

multi-agent-deposit-llm-inference:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_VERIFIER"
	CANARY_ACTION=deposit CANARY_AGENT_KIND=llm-inference forge script $(CANARY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) -vvvv

multi-agent-deposit-llm-parse:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_VERIFIER"
	CANARY_ACTION=deposit CANARY_AGENT_KIND=llm-parse-website forge script $(CANARY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) -vvvv

multi-settlement-env-check:
	@missing=0; \
	for var in DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL SOMNIA_CHAIN_ID SOMNIA_AGENT_PLATFORM SOMNIA_JSON_API_AGENT_ID SOMNIA_LLM_INFERENCE_AGENT_ID AGENT_SUBCOMMITTEE_SIZE; do \
		if [[ -z "$${!var}" ]]; then \
			echo "MISSING $$var"; \
			missing=1; \
		else \
			echo "OK $$var"; \
		fi; \
	done; \
	exit $$missing

multi-settlement-deploy-dry-run:
	@$(MAKE) --no-print-directory multi-settlement-env-check
	WRITE_DEPLOYMENT_ARTIFACT=false forge script $(MULTI_SETTLEMENT_DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_GAS_ESTIMATE_MULTIPLIER) -vvvv

multi-settlement-deploy-somnia:
	@$(MAKE) --no-print-directory multi-settlement-env-check
	forge script $(MULTI_SETTLEMENT_DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv
	@$(MAKE) --no-print-directory multi-settlement-enrich-artifact

multi-settlement-enrich-artifact:
	@if command -v jq >/dev/null 2>&1 && [[ -f "broadcast/DeployVigiliaMultiAgentSettlement.s.sol/50312/run-latest.json" && -f "$(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)" ]]; then \
		VERIFIER_TX=$$(jq -r '.transactions[] | select(.contractName=="VigiliaMultiAgentVerifier") | .hash' broadcast/DeployVigiliaMultiAgentSettlement.s.sol/50312/run-latest.json | head -1); \
		ESCROW_TX=$$(jq -r '.transactions[] | select(.contractName=="VigiliaEscrow") | .hash' broadcast/DeployVigiliaMultiAgentSettlement.s.sol/50312/run-latest.json | head -1); \
		BIND_TX=$$(jq -r '.transactions[] | select(.function=="bindEscrow(address)") | .hash' broadcast/DeployVigiliaMultiAgentSettlement.s.sol/50312/run-latest.json | head -1); \
		tmp=$$(mktemp); \
		jq --arg v "$$VERIFIER_TX" --arg e "$$ESCROW_TX" --arg b "$$BIND_TX" \
			'. + {vigiliaMultiAgentVerifierTransactionHash: $$v, vigiliaEscrowTransactionHash: $$e, bindTransactionHash: $$b}' \
			"$(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)" > "$$tmp"; \
		mv "$$tmp" "$(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)"; \
		echo "Updated $(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT) with broadcast tx hashes"; \
	else \
		echo "Skipping tx-hash enrichment; need jq, broadcast trace, and $(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)"; \
	fi

multi-settlement-show-deployment:
	@if [[ -f "$(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)" ]]; then \
		cat "$(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)"; \
	else \
		echo "Deployment artifact not found: $(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)"; \
		exit 1; \
	fi

multi-settlement-deployment-addresses:
	@if [[ -n "$$VIGILIA_MULTI_AGENT_ESCROW" ]]; then echo "VIGILIA_MULTI_AGENT_ESCROW=$$VIGILIA_MULTI_AGENT_ESCROW"; fi
	@if [[ -n "$$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER" ]]; then echo "VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER=$$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER"; fi
	@if command -v jq >/dev/null 2>&1 && [[ -f "$(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)" ]]; then \
		jq -r '"artifact=" + input_filename, "vigiliaEscrow=" + .vigiliaEscrow, "vigiliaMultiAgentVerifier=" + .vigiliaMultiAgentVerifier, "deploymentName=" + .deploymentName, "version=" + .version, "enabledSettlementAgentTypes=" + .enabledSettlementAgentTypes' "$(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)"; \
	elif [[ -z "$$VIGILIA_MULTI_AGENT_ESCROW" || -z "$$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER" ]]; then \
		echo "Set VIGILIA_MULTI_AGENT_ESCROW and VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER or install jq to read $(MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT)"; \
		exit 1; \
	fi

grant-round-env-check:
	@missing=0; \
	for var in DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL SOMNIA_CHAIN_ID SOMNIA_AGENT_PLATFORM SOMNIA_JSON_API_AGENT_ID SOMNIA_LLM_INFERENCE_AGENT_ID AGENT_SUBCOMMITTEE_SIZE; do \
		if [[ -z "$${!var}" ]]; then \
			echo "MISSING $$var"; \
			missing=1; \
		else \
			echo "OK $$var"; \
		fi; \
	done; \
	exit $$missing

grant-round-deploy-dry-run:
	@$(MAKE) --no-print-directory grant-round-env-check
	WRITE_DEPLOYMENT_ARTIFACT=false forge script $(GRANT_ROUND_DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_GAS_ESTIMATE_MULTIPLIER) -vvvv

grant-round-deploy-somnia:
	@$(MAKE) --no-print-directory grant-round-env-check
	forge script $(GRANT_ROUND_DEPLOY_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --slow -vvvv

grant-round-show-deployment:
	@if [[ -f "$(GRANT_ROUND_DEPLOYMENT_ARTIFACT)" ]]; then \
		cat "$(GRANT_ROUND_DEPLOYMENT_ARTIFACT)"; \
	else \
		echo "Deployment artifact not found: $(GRANT_ROUND_DEPLOYMENT_ARTIFACT)"; \
		exit 1; \
	fi

grant-round-bind-verifier:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_GRANT_ROUND VIGILIA_GRANT_ROUND_VERIFIER"
	cast send "$$VIGILIA_GRANT_ROUND_VERIFIER" "bindEscrow(address)" "$$VIGILIA_GRANT_ROUND" --gas-limit $(DEMO_GAS_LIMIT) --legacy --rpc-url "$$SOMNIA_RPC_URL" --private-key "$$DEPLOYER_PRIVATE_KEY"

grant-round-verifier-deposit:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_GRANT_ROUND_VERIFIER"
	@cast call "$$VIGILIA_GRANT_ROUND_VERIFIER" "minimumRequestDepositForWorkflow(uint8)(uint256)" 3 --rpc-url "$$SOMNIA_RPC_URL"

grant-round-verify-verifier:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_CHAIN_ID SOMNIA_BLOCKSCOUT_API SOMNIA_AGENT_PLATFORM SOMNIA_JSON_API_AGENT_ID SOMNIA_LLM_INFERENCE_AGENT_ID AGENT_SUBCOMMITTEE_SIZE VIGILIA_GRANT_ROUND_VERIFIER"
	@DEPLOYER=$${DEPLOYER_ADDRESS:-$$(cast wallet address --private-key "$$DEPLOYER_PRIVATE_KEY")}; \
	LLM_PARSE_ID=$${SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID:-$${SOMNIA_LLM_WEB_AGENT_ID:-0}}; \
	JSON_PRICE=$${JSON_API_PRICE_PER_VALIDATOR_WEI:-30000000000000000}; \
	LLM_PRICE=$${LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI:-70000000000000000}; \
	PARSE_PRICE=$${LLM_PARSE_PRICE_PER_VALIDATOR_WEI:-100000000000000000}; \
	SELECTOR=$${SOMNIA_VERDICT_SELECTOR:-verdict}; \
	ARGS=$$(cast abi-encode "constructor((address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,string,bool))" "($$SOMNIA_AGENT_PLATFORM,$$DEPLOYER,$$SOMNIA_JSON_API_AGENT_ID,$$SOMNIA_LLM_INFERENCE_AGENT_ID,$$LLM_PARSE_ID,$$AGENT_SUBCOMMITTEE_SIZE,$$JSON_PRICE,$$LLM_PRICE,$$PARSE_PRICE,$$SELECTOR,true)"); \
	forge verify-contract "$$VIGILIA_GRANT_ROUND_VERIFIER" src/VigiliaMultiAgentVerifier.sol:VigiliaMultiAgentVerifier --chain-id "$$SOMNIA_CHAIN_ID" --verifier blockscout --verifier-url "$$SOMNIA_BLOCKSCOUT_API" --constructor-args "$$ARGS"

grant-round-verify-contract:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_CHAIN_ID SOMNIA_BLOCKSCOUT_API VIGILIA_GRANT_ROUND VIGILIA_GRANT_ROUND_VERIFIER"
	@ARGS=$$(cast abi-encode "constructor(address)" "$$VIGILIA_GRANT_ROUND_VERIFIER"); \
	forge verify-contract "$$VIGILIA_GRANT_ROUND" src/VigiliaGrantRound.sol:VigiliaGrantRound --chain-id "$$SOMNIA_CHAIN_ID" --verifier blockscout --verifier-url "$$SOMNIA_BLOCKSCOUT_API" --constructor-args "$$ARGS"

grant-round-verify-state:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_GRANT_ROUND VIGILIA_GRANT_ROUND_VERIFIER"
	@BOUND=$$(cast call "$$VIGILIA_GRANT_ROUND_VERIFIER" "escrow()(address)" --rpc-url "$$SOMNIA_RPC_URL"); \
	CONFIGURED=$$(cast call "$$VIGILIA_GRANT_ROUND" "verifier()(address)" --rpc-url "$$SOMNIA_RPC_URL"); \
	DEPOSIT=$$(cast call "$$VIGILIA_GRANT_ROUND_VERIFIER" "minimumRequestDepositForWorkflow(uint8)(uint256)" 3 --rpc-url "$$SOMNIA_RPC_URL"); \
	BOUND_LC=$$(printf "%s" "$$BOUND" | tr '[:upper:]' '[:lower:]'); \
	CONFIGURED_LC=$$(printf "%s" "$$CONFIGURED" | tr '[:upper:]' '[:lower:]'); \
	ROUND_LC=$$(printf "%s" "$$VIGILIA_GRANT_ROUND" | tr '[:upper:]' '[:lower:]'); \
	VERIFIER_LC=$$(printf "%s" "$$VIGILIA_GRANT_ROUND_VERIFIER" | tr '[:upper:]' '[:lower:]'); \
	echo "grantRound=$$VIGILIA_GRANT_ROUND"; \
	echo "verifier=$$VIGILIA_GRANT_ROUND_VERIFIER"; \
	echo "verifier.escrow=$$BOUND"; \
	echo "grantRound.verifier=$$CONFIGURED"; \
	echo "twoAgentWorkflowDeposit=$$DEPOSIT"; \
	if [[ "$$BOUND_LC" != "$$ROUND_LC" ]]; then echo "GrantRound binding mismatch"; exit 1; fi; \
	if [[ "$$CONFIGURED_LC" != "$$VERIFIER_LC" ]]; then echo "GrantRound verifier mismatch"; exit 1; fi

grant-round-verify-all: grant-round-verify-verifier grant-round-verify-contract grant-round-verify-state

grant-demo:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_GRANT_ROUND VIGILIA_GRANT_ROUND_VERIFIER"
	forge script $(GRANT_ROUND_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --broadcast --legacy --skip-simulation --gas-limit $(DEMO_GAS_LIMIT) -vvvv

grant-demo-inspect:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_GRANT_ROUND VIGILIA_GRANT_ROUND_VERIFIER"
	DEMO_ACTION=inspect forge script $(GRANT_ROUND_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" -vvvv

grant-demo-create-round:
	DEMO_ACTION=create-round $(MAKE) --no-print-directory grant-demo

grant-demo-fund-round:
	DEMO_ACTION=fund-round $(MAKE) --no-print-directory grant-demo

grant-demo-submit-application:
	DEMO_ACTION=submit-application $(MAKE) --no-print-directory grant-demo

grant-demo-submit-complete:
	DEMO_ACTION=submit-application-complete $(MAKE) --no-print-directory grant-demo

grant-demo-submit-needs-review:
	DEMO_ACTION=submit-application-needs-review $(MAKE) --no-print-directory grant-demo

grant-demo-submit-incomplete:
	DEMO_ACTION=submit-application-incomplete $(MAKE) --no-print-directory grant-demo

grant-demo-submit-malformed:
	DEMO_ACTION=submit-application-malformed $(MAKE) --no-print-directory grant-demo

grant-demo-request-screening:
	DEMO_ACTION=request-screening $(MAKE) --no-print-directory grant-demo

grant-demo-request-screening-complete:
	DEMO_ACTION=request-screening-complete $(MAKE) --no-print-directory grant-demo

grant-demo-request-screening-needs-review:
	DEMO_ACTION=request-screening-needs-review $(MAKE) --no-print-directory grant-demo

grant-demo-request-screening-incomplete:
	DEMO_ACTION=request-screening-incomplete $(MAKE) --no-print-directory grant-demo

grant-demo-request-screening-malformed:
	DEMO_ACTION=request-screening-malformed $(MAKE) --no-print-directory grant-demo

grant-demo-request-screening-cast:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_GRANT_ROUND GRANT_APPLICATION_ID GRANT_ROUND_WORKFLOW_DEPOSIT_WEI"
	@REQUESTER_KEY="$${GRANT_REQUESTER_PRIVATE_KEY:-$${SPONSOR_PRIVATE_KEY:-$$DEPLOYER_PRIVATE_KEY}}"; \
	if [[ -z "$$REQUESTER_KEY" ]]; then echo "Missing required env var: GRANT_REQUESTER_PRIVATE_KEY, SPONSOR_PRIVATE_KEY, or DEPLOYER_PRIVATE_KEY"; exit 1; fi; \
	echo "Direct cast requestApplicationScreening for GRANT_APPLICATION_ID=$$GRANT_APPLICATION_ID"; \
	echo "Requester key selection: GRANT_REQUESTER_PRIVATE_KEY, else SPONSOR_PRIVATE_KEY, else DEPLOYER_PRIVATE_KEY"; \
	cast send "$$VIGILIA_GRANT_ROUND" "requestApplicationScreening(uint256)" "$$GRANT_APPLICATION_ID" \
		--value "$$GRANT_ROUND_WORKFLOW_DEPOSIT_WEI" \
		--rpc-url "$$SOMNIA_RPC_URL" \
		--private-key "$$REQUESTER_KEY" \
		--legacy \
		--gas-limit "$(DEMO_GAS_LIMIT)"

grant-demo-request-screening-complete-cast: grant-demo-request-screening-cast

grant-demo-request-screening-needs-review-cast: grant-demo-request-screening-cast

grant-demo-request-screening-incomplete-cast: grant-demo-request-screening-cast

grant-demo-request-screening-malformed-cast: grant-demo-request-screening-cast

grant-demo-manual-screen-complete:
	DEMO_ACTION=manual-screen-complete $(MAKE) --no-print-directory grant-demo

grant-demo-manual-screen-needs-review:
	DEMO_ACTION=manual-screen-needs-review $(MAKE) --no-print-directory grant-demo

grant-demo-manual-screen-incomplete:
	DEMO_ACTION=manual-screen-incomplete $(MAKE) --no-print-directory grant-demo

grant-demo-select-finalists:
	DEMO_ACTION=select-finalists $(MAKE) --no-print-directory grant-demo

grant-demo-reject-application:
	DEMO_ACTION=reject-application $(MAKE) --no-print-directory grant-demo

grant-demo-finalize-round:
	DEMO_ACTION=finalize-round $(MAKE) --no-print-directory grant-demo

grant-demo-claim-prize:
	DEMO_ACTION=claim-prize $(MAKE) --no-print-directory grant-demo

grant-demo-refund-unallocated:
	DEMO_ACTION=refund-unallocated $(MAKE) --no-print-directory grant-demo

grant-demo-withdraw-pending:
	DEMO_ACTION=withdraw-pending $(MAKE) --no-print-directory grant-demo

grant-demo-cancel-round:
	DEMO_ACTION=cancel-round $(MAKE) --no-print-directory grant-demo

grant-demo-full-two-agent-happy-path-prep:
	DEMO_ACTION=full-two-agent-happy-path-prep $(MAKE) --no-print-directory grant-demo

grant-demo-full-two-agent-review-board-prep:
	DEMO_ACTION=full-two-agent-review-board-prep $(MAKE) --no-print-directory grant-demo

multi-settlement-verifier-deposit:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER"
	@cast call "$$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER" "minimumRequestDepositForWorkflow(uint8)(uint256)" 3 --rpc-url "$$SOMNIA_RPC_URL"

multi-settlement-verify-verifier:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_CHAIN_ID SOMNIA_BLOCKSCOUT_API SOMNIA_AGENT_PLATFORM SOMNIA_JSON_API_AGENT_ID SOMNIA_LLM_INFERENCE_AGENT_ID AGENT_SUBCOMMITTEE_SIZE JSON_API_PRICE_PER_VALIDATOR_WEI LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI LLM_PARSE_PRICE_PER_VALIDATOR_WEI SOMNIA_VERDICT_SELECTOR VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER"
	@DEPLOYER=$${DEPLOYER_ADDRESS:-$$(cast wallet address --private-key "$$DEPLOYER_PRIVATE_KEY")}; \
	LLM_PARSE_ID=$${SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID:-$$SOMNIA_LLM_WEB_AGENT_ID}; \
	ARGS=$$(cast abi-encode "constructor((address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,string,bool))" "($$SOMNIA_AGENT_PLATFORM,$$DEPLOYER,$$SOMNIA_JSON_API_AGENT_ID,$$SOMNIA_LLM_INFERENCE_AGENT_ID,$$LLM_PARSE_ID,$$AGENT_SUBCOMMITTEE_SIZE,$$JSON_API_PRICE_PER_VALIDATOR_WEI,$$LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI,$$LLM_PARSE_PRICE_PER_VALIDATOR_WEI,$$SOMNIA_VERDICT_SELECTOR,true)"); \
	forge verify-contract "$$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER" src/VigiliaMultiAgentVerifier.sol:VigiliaMultiAgentVerifier --chain-id "$$SOMNIA_CHAIN_ID" --verifier blockscout --verifier-url "$$SOMNIA_BLOCKSCOUT_API" --constructor-args "$$ARGS"

multi-settlement-verify-escrow:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_CHAIN_ID SOMNIA_BLOCKSCOUT_API VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER"
	@ARGS=$$(cast abi-encode "constructor(address)" "$$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER"); \
	forge verify-contract "$$VIGILIA_MULTI_AGENT_ESCROW" src/VigiliaEscrow.sol:VigiliaEscrow --chain-id "$$SOMNIA_CHAIN_ID" --verifier blockscout --verifier-url "$$SOMNIA_BLOCKSCOUT_API" --constructor-args "$$ARGS"

multi-settlement-demo-create-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_AMOUNT_WEI DEMO_REVIEW_WINDOW"
	@claim_policy=$${DEMO_CLAIM_POLICY:-1}; \
	if [ -n "$$DEMO_CREATE_CLAIM_POLICY" ]; then claim_policy=$$DEMO_CREATE_CLAIM_POLICY; fi; \
	DEMO_CLAIM_POLICY=$$claim_policy DEMO_ACTION=create forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv

multi-settlement-demo-fund-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=fund forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv

multi-settlement-demo-submit-complete:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	VIGILIA_EVIDENCE_JSON_URL=$${VIGILIA_EVIDENCE_JSON_URL:-$(MULTI_SETTLEMENT_EVIDENCE_COMPLETE_URL)} DEMO_ACTION=submit forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-settlement-demo-submit-incomplete:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	VIGILIA_EVIDENCE_JSON_URL=$${VIGILIA_EVIDENCE_JSON_URL:-$(MULTI_SETTLEMENT_EVIDENCE_INCOMPLETE_URL)} DEMO_ACTION=submit forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-settlement-demo-submit-needs-review:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	VIGILIA_EVIDENCE_JSON_URL=$${VIGILIA_EVIDENCE_JSON_URL:-$(MULTI_SETTLEMENT_EVIDENCE_NEEDS_REVIEW_URL)} DEMO_ACTION=submit forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-settlement-demo-submit-malformed:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	VIGILIA_EVIDENCE_JSON_URL=$${VIGILIA_EVIDENCE_JSON_URL:-$(MULTI_SETTLEMENT_EVIDENCE_MALFORMED_URL)} DEMO_ACTION=submit forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-settlement-demo-inspect-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=inspect forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv

multi-settlement-demo-approve-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	cast send "$$VIGILIA_MULTI_AGENT_ESCROW" "approveTask(uint256)" "$$DEMO_TASK_ID" --gas-limit $(DEMO_GAS_LIMIT) --legacy --rpc-url "$$SOMNIA_RPC_URL" --private-key "$$DEPLOYER_PRIVATE_KEY"

multi-settlement-demo-claim-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	cast send "$$VIGILIA_MULTI_AGENT_ESCROW" "claim(uint256)" "$$DEMO_TASK_ID" --gas-limit $(DEMO_GAS_LIMIT) --legacy --rpc-url "$$SOMNIA_RPC_URL" --private-key "$$DEPLOYER_PRIVATE_KEY"

multi-settlement-demo-retry-verification:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=retry forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-settlement-demo-continue-llm-verification:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_PARENT_REQUEST_ID"
	DEMO_ACTION=continue-llm forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-agent-demo-create-task: multi-settlement-demo-create-task
multi-agent-demo-create-task-immediate-claim:
	DEMO_CREATE_CLAIM_POLICY=2 $(MAKE) --no-print-directory multi-settlement-demo-create-task
multi-agent-demo-create-task-client-approval:
	DEMO_CREATE_CLAIM_POLICY=0 $(MAKE) --no-print-directory multi-settlement-demo-create-task
multi-agent-demo-fund-task: multi-settlement-demo-fund-task
multi-agent-demo-submit-facts-complete: multi-settlement-demo-submit-complete
multi-agent-demo-submit-facts-incomplete: multi-settlement-demo-submit-incomplete
multi-agent-demo-submit-facts-needs-review: multi-settlement-demo-submit-needs-review
multi-agent-demo-submit-facts-malformed: multi-settlement-demo-submit-malformed
multi-agent-demo-continue-llm-verification: multi-settlement-demo-continue-llm-verification
multi-agent-demo-inspect-task: multi-settlement-demo-inspect-task
multi-agent-demo-approve-task: multi-settlement-demo-approve-task
multi-agent-demo-claim-task: multi-settlement-demo-claim-task
multi-agent-demo-retry-verification: multi-settlement-demo-retry-verification
