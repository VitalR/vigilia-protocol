SHELL := /bin/bash

-include .env
.EXPORT_ALL_VARIABLES:

DEPLOYMENT_ARTIFACT ?= deployments/somnia-testnet-50312.json
DEPLOY_SCRIPT ?= script/deploy/DeployVigiliaSystem.s.sol:DeployVigiliaSystem
MULTI_AGENT_DEPLOY_SCRIPT ?= script/deploy/DeployVigiliaMultiAgentVerifier.s.sol:DeployVigiliaMultiAgentVerifier
MULTI_SETTLEMENT_DEPLOY_SCRIPT ?= script/deploy/DeployVigiliaMultiAgentSettlement.s.sol:DeployVigiliaMultiAgentSettlement
MULTI_SETTLEMENT_DEPLOYMENT_ARTIFACT ?= deployments/somnia-testnet-50312-two-agent-settlement.json
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
	multi-agent-demo-claim-task multi-agent-demo-retry-verification require-env

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

fmt:
	forge fmt

build:
	forge build

test:
	forge test -vvv

coverage:
	@# VigiliaMultiAgentVerifier requires production via_ir; Foundry coverage disables that and hits solc stack limits.
	@# Full multi-agent behavior is covered by `forge test`; this target reports coverage for the remaining core contracts.
	forge coverage --ir-minimum --exclude-tests --skip VigiliaMultiAgentVerifier --skip script --no-match-coverage "(^script/|Deploy|Demo|Smoke|Canary)" -vvv

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
	DEMO_ACTION=create forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv

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
	DEMO_ACTION=approve forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv

multi-settlement-demo-claim-task:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=claim forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy -vvvv

multi-settlement-demo-retry-verification:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_TASK_ID"
	DEMO_ACTION=retry forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-settlement-demo-continue-llm-verification:
	@$(MAKE) --no-print-directory require-env VARS="DEPLOYER_PRIVATE_KEY SOMNIA_RPC_URL VIGILIA_MULTI_AGENT_ESCROW VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER DEMO_PARENT_REQUEST_ID"
	DEMO_ACTION=continue-llm forge script $(MULTI_SETTLEMENT_DEMO_SCRIPT) --rpc-url "$$SOMNIA_RPC_URL" --gas-limit $(DEMO_GAS_LIMIT) --gas-estimate-multiplier $(MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER) --broadcast --legacy --skip-simulation -vvvv

multi-agent-demo-create-task: multi-settlement-demo-create-task
multi-agent-demo-create-task-immediate-claim:
	DEMO_CLAIM_POLICY=2 $(MAKE) --no-print-directory multi-settlement-demo-create-task
multi-agent-demo-create-task-client-approval:
	DEMO_CLAIM_POLICY=0 $(MAKE) --no-print-directory multi-settlement-demo-create-task
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
