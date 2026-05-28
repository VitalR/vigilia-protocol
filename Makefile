SHELL := /bin/bash

-include .env
.EXPORT_ALL_VARIABLES:

DEPLOYMENT_ARTIFACT ?= deployments/somnia-testnet-50312.json
DEPLOY_SCRIPT ?= script/DeployVigiliaSystem.s.sol:DeployVigiliaSystem
GAS_ESTIMATE_MULTIPLIER ?= 2000

.PHONY: help fmt build test check env-check account balance platform-code platform-deposit platform-check \
	deploy-somnia deploy-somnia-dry-run show-deployment verify-somnia-escrow verify-somnia-json-verifier verify-somnia-verifier \
	evidence-url required-agent-deposit require-env

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
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-somnia-dry-run       Simulate deployment without writing deployment artifact"
	@echo "  make deploy-somnia               Broadcast deployment and write $(DEPLOYMENT_ARTIFACT)"
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

fmt:
	forge fmt

build:
	forge build

test:
	forge test -vvv

coverage:
	forge coverage --no-match-coverage script --exclude-tests -vvv

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

show-deployment:
	@if [[ -f "$(DEPLOYMENT_ARTIFACT)" ]]; then \
		cat "$(DEPLOYMENT_ARTIFACT)"; \
	else \
		echo "Deployment artifact not found: $(DEPLOYMENT_ARTIFACT)"; \
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

required-agent-deposit:
	@$(MAKE) --no-print-directory require-env VARS="SOMNIA_AGENT_PLATFORM SOMNIA_RPC_URL AGENT_SUBCOMMITTEE_SIZE AGENT_PRICE_PER_VALIDATOR"
	@RESERVE=$$(cast call "$$SOMNIA_AGENT_PLATFORM" "getRequestDeposit()(uint256)" --rpc-url "$$SOMNIA_RPC_URL"); \
	TOTAL=$$((RESERVE + (AGENT_SUBCOMMITTEE_SIZE * AGENT_PRICE_PER_VALIDATOR))); \
	echo "$$TOTAL"
