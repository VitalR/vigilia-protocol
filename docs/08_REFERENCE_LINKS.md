# Reference Links

This file collects the links discussed during ideation so future Codex/engineering/product passes can quickly inspect source material.

## Somnia / Agentathon

- Somnia Agentathon GitHub: https://github.com/somnia-chain/agentathon
- Somnia Docs: https://docs.somnia.network/
- Somnia Concepts: https://docs.somnia.network/concepts
- Somnia Agents overview: https://docs.somnia.network/agents
- Encode Club Agentathon page: https://www.encodeclub.com/my-programmes/agentathon

## Somnia Developer Docs

- Network Info: https://docs.somnia.network/developer/network-info
- Reactivity: https://docs.somnia.network/developer/reactivity
- Off-chain Reactivity: https://docs.somnia.network/developer/reactivity/reactivity-offchain
- Reactivity Tutorials: https://docs.somnia.network/developer/reactivity/tutorials
- Data Streams overview: https://docs.somnia.network/developer/data-streams/what-is-somnia-data-streams
- Deploy with Foundry: https://docs.somnia.network/developer/development-frameworks/deploy-with-foundry

## Somnia Oracles / Feeds

- Protofire Price Feeds: https://docs.somnia.network/developer/building-dapps/oracles/protofire-price-feeds
- DIA Price Feeds: https://docs.somnia.network/developer/building-dapps/oracles/dia-price-feeds

## Somnia Agents

- Agents overview / use cases: https://docs.somnia.network/agents
- Invoke Agents from Solidity: https://docs.somnia.network/agents/invoking-agents/from-solidity
- Agent Receipts: https://docs.somnia.network/agents/invoking-agents/receipts
- JSON API Request Agent: https://docs.somnia.network/agents/base-agents/json-api-request
- LLM Inference Agent: https://docs.somnia.network/agents/base-agents/llm-inference
- LLM Parse Website Agent: https://docs.somnia.network/agents/base-agents/llm-parse-website

## Existing User Reference Projects

- VaultGuard / CRE VaultGuard: https://github.com/VitalR/cre-vaultguard
- Midcontract contracts: https://github.com/midcontract/contracts
- Midcontract product site: https://www.midcontract.com/
- Midcontract docs: https://docs.midcontract.com/

## Midcontract Concepts to Reuse Carefully

- Fixed-price contracts.
- Milestone contracts.
- Hourly contracts as future work, not MVP.
- Escrow registry.
- Fee manager.
- Admin/dispute manager.
- Account recovery as possible future work.
- Review windows.
- Claim/release logic.
- Event-driven audit trail.
- Portable on-chain reputation.

## Somnia Concepts to Use in Vigilia

- Agents as evidence processors.
- Reactivity as event-driven trigger/update layer.
- Data Streams as portable proof-of-work memory.
- Foundry for Solidity development and test workflows.
- Testnet chain/explorer/RPC for hackathon demo.
- Optional Protofire/DIA feeds for USD-denominated display or fee normalization.

## Important Product Notes

- Do not position the MVP as a full freelance marketplace.
- Do not let AI directly control arbitrary payouts.
- Start with public technical work evidence.
- Use bounded verdicts.
- Keep human review and dispute fallback.
- Make core escrow safe even if Reactivity/Data Streams integration is delayed.
- Use one polished demo scenario before adding more verticals.
