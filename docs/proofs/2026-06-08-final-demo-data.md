# Final Demo Data Proof - 2026-06-08

This document records live smoke/demo data generated after the production frontend was manually deployed to Vercel.

This is not deterministic CI. It is live Somnia testnet data using the already deployed Vigilia contracts.

## Frontend

- Final URL: https://vigilia-protocol.vercel.app/
- Reachability: HTTP 200 from Vercel on 2026-06-08.
- Production address configuration:
  - Escrow: `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9`
  - Escrow verifier: `0xdE0aC9700E591b54A418665575f2e1d329D78f3D`
  - GrantRound v0.4: `0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679`
  - Grant verifier: `0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4`

Plain `curl` against the dashboard route returns the static shell before wallet/RPC hydration, so the source of truth for the counts below is direct RPC reads from the deployed contracts using the same fields as `useDashboardStats`.

## Evidence

Generated with `VIGILIA_DASHBOARD_URL=https://vigilia-protocol.vercel.app/`.

Public evidence files:

- Escrow evidence: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/escrow-real/evidence-real-verified-complete.json`
- Grant evidence: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-verified-complete.json`

For the live agent requests below, commit-pinned URLs were used because `raw.githubusercontent.com/main` was still serving a cached copy for several minutes after the evidence refresh:

- Escrow evidence used on-chain: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/f5cf55c/demo/evidence/escrow-real/evidence-real-verified-complete.json`
- Grant evidence used on-chain: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/f5cf55c/demo/evidence/grants-real/evidence-real-verified-complete.json`

Verified facts in both generated evidence files:

```text
repo_url_valid=true; repo_exists=true; readme_exists=true; docs_url_valid=true; docs_reachable=true; proof_url_valid=true; proof_reachable=true; deployment_address_format_valid=true; deployment_has_code=true; website_url_valid=true; website_reachable=true; demo_url_valid=true; demo_url_reachable=true
```

## Escrow Milestone Data

Contract:

- Escrow: `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9`
- Verifier: `0xdE0aC9700E591b54A418665575f2e1d329D78f3D`
- Workflow: TwoAgent / JSON facts -> LLM bounded verdict
- Workflow deposit: `360000000000000000` wei
- Client: `0x8998a83a6192dD5500EEbb666cad0bC2Ab0258E7`
- Contractor: `0x110C2cfaC2Df847FBC98cc0c514A11d0e2046c13`

All four milestones used the final escrow evidence URL above. Each agent verdict reached `Complete`, and each task finished in state `Claimed` (`9`).

### Milestone A - Publish Verified Escrow Proof Package

- Task ID: `16`
- Submission ID: `13`
- Amount: `5 STT`
- Claim policy: Immediate claim
- Create tx: `0xc908fbe93d9d56c14881ac51f29c401f30fc1fbf5a9c38d489cbb05ca88d19da`
- Fund tx: `0x8e62c2efd84d61abf9295406c4b187bb3eec3a57fba4ce39ffb8bbb10b34b0e1`
- Submit tx: `0xe3f75251bed73e44a8b2b550a3c77c277b72dc835196f416dd4a072f600764ad`
- Root request ID: `0x5a71b2a85d59278353d51fd2f40bf3e6962f2c773189380f2a31679c7cebbab`
- Platform request ID: `0x56da6a`
- Claim tx: `0xe70363fcc93e03d8778b393a34e1cdad01ea0c7279fb9ff95b2fa016baff0bdc`
- Final state: `Claimed`

### Milestone B - Integrate Real Evidence Validation Tool

- Task ID: `17`
- Submission ID: `14`
- Amount: `10 STT`
- Claim policy: Client approval required
- Create tx: `0xe3422bee53395fa1a35d0e44487494858185d384ac0338ed189e179cb9599a32`
- Fund tx: `0xa84b7e24d462a28032bac666cfc4b32b8b65cf4a10c01a79b0a583e3fa97b564`
- Submit tx: `0xead71e442d64d6958a5d7af9a42ba7dad13104ca4556e4754a300d9b218a457a`
- Root request ID: `0x5a71b2a85d59278353d51fd2f40bf3e6962f2c773189380f2a31679c7cebbab`
- Platform request ID: `0x56dc15`
- Approve tx: `0x774326b20466d56ef6a886f8e1bb526df96e37416d3fd44c547395689e538ea8`
- Claim tx: `0x08ae12654c909f7950e16808569bc8ec8b69bc6aa2a6da5baf253f41a2c83710`
- Final state: `Claimed`

### Milestone C - Ship Somnia Agent Dashboard Update

- Task ID: `18`
- Submission ID: `15`
- Amount: `3 STT`
- Claim policy: Review-window auto-claim
- Review window: `60` seconds
- Create tx: `0xd1f925b40c7268c74630d77ba7be00f26c2b60cb19114308a9799b4a7e49ede5`
- Fund tx: `0xfcb0b26c47eed11d80ad9732d55f23a31a72ff5eb82846d517091ea3762e60c4`
- Submit tx: `0xc7cf7b412fe2f7b5691407c24b3f657da3ae321cb5406f9ec26b5afa377ee87b`
- Root request ID: `0x5a71b2a85d59278353d51fd2f40bf3e6962f2c773189380f2a31679c7cebbab`
- Platform request ID: `0x56dc2f`
- Approve tx: `0x0cbb096e9899560c0fe59cebfe39c7ea8ce3ded625d410ff639d7501e668b113`
- Claim tx: `0x7f4aa7cdf710d0d4e51eba1a6bde287b92dca9812c98851bec8bf0e18fe97114`
- Final state: `Claimed`

### Milestone D - Add GrantRound ThreeAgent Proof Docs

- Task ID: `19`
- Submission ID: `16`
- Amount: `7 STT`
- Claim policy: Immediate claim
- Create tx: `0x0dfecc041506c0347d2d95ea79a6dec9e3c421ed6577d821728cc1141d3248bd`
- Fund tx: `0x105130f835e8c6437144565399ae6d8bc59070ad40cfdf5ef788c8cf02212bda`
- Submit tx: `0x9e120465de1c89df9ef1db9395246032a80e2d6f135ec36a26a5f95934026100`
- Root request ID: `0x5a71b2a85d59278353d51fd2f40bf3e6962f2c773189380f2a31679c7cebbab`
- Platform request ID: `0x56dc4c`
- Claim tx: `0x879ef32d480731a62c510dce762e3078b8cb5ef7b30283f72e03bdb43c3b88af`
- Final state: `Claimed`

## GrantRound Data

Contract:

- GrantRound v0.4: `0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679`
- Verifier: `0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4`
- Workflow: ThreeAgent / JSON facts -> Website Parse -> LLM bounded verdict
- Workflow deposit: `810000000000000000` wei

### Grant Round A - Vigilia Builder Verification Grant

- Round ID: `15`
- Prize: `3 STT`
- Max winners: `2`
- Total pool: `6 STT`
- Screening mode: `ThreeAgent`
- Requirements URI: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/grant-requirements.md`
- Create tx: `0x321d2e1052b808849e15672b1b3ac862a781c0979e6ce8833f4b6296b089bcf2`
- Fund tx: `0x7ca87aeb26957534a4023f9d82a50879860590e2d6ed05f5ad2e6257a4dde773`
- Select finalists tx: `0x7f8778b4205d92231ebe31c0d5ef204028be63bc40eb889e07d6428aa2385d32`
- Finalize tx: `0xc56c15dc62c5cf2192d602562c62fcd6a769a5d606af4b6f4e7963eebaeb59be`
- Final round state: `Finalized`
- Selected count: `2`
- Claimed count: `2`
- Total claimed: `6 STT`

Applications:

- Application `27`
  - Applicant: `0x110C2cfaC2Df847FBC98cc0c514A11d0e2046c13`
  - Submit tx: `0xaceaca122af71b2f499930c9ce6b1b6028c23f3c03f3993463c2caf5131663b6`
  - Request screening tx: `0xe76aa293afeff0d982e94c99e78bbb8b8bfd11d1f0f52933995baab665c21859`
  - Root request ID: `0x56de28`
  - Final LLM notes: `somnia-agent-request:5693022`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0x05d264d5a7d6ac4ecb6536c640bb56e57a54bdc8f0b898db1afb4996174bd007`
- Application `28`
  - Applicant: `0x0168DC0665b98bf9ceAb6B4c1cc2b0FD687C87A9`
  - Submit tx: `0x6de03522ef3726905dff4d7ef6eaef48a8e93658b9cfc5884638aeea439f6c4e`
  - Request screening tx: `0xcbf37c0b41c539a5629e4ea65d03b6af046ebf6dc5afd802622fe1ba2a77c418`
  - Root request ID: `0x56de3d`
  - Final LLM notes: `somnia-agent-request:5693038`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0xa1f1518afd777c78cebe852b219802aa4495f93c172bb54fe2ff152186d050fa`

## Final Polished Demo Scenarios

Date: `2026-06-09`

Frontend URL:

- `https://vigilia-protocol.vercel.app/`

UX polish included in this final pass:

- The Create Milestone disconnected state now gives the explicit disabled reason:
  `Connect wallet to create a milestone.`
- The Create Grant modal remains reachable while disconnected and gives the explicit disabled reason:
  `Connect wallet to create a grant.`
- Create Milestone and Create Grant surfaces now use a consistent `max-w-3xl` form width.
- The grant list continues to display the title from structured `requirementsURI` metadata when available.

Evidence URLs used:

- Escrow: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/escrow-real/evidence-real-verified-complete.json`
- Grant: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-verified-complete.json`
- Grant Website Parse input: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/website-real-complete.html`

Evidence validation facts included:

- `demo_url_valid=true`
- `demo_url_reachable=true`
- `deployment_has_code=true`
- `repo_exists=true`
- `docs_reachable=true`
- `proof_reachable=true`

### Final Milestone A - Ship Agent Proof Dashboard for Somnia

- Task ID: `20`
- Submission ID: `17`
- Amount: `3 STT`
- Claim policy: Immediate claim
- Create tx: `0xa34fa1cea323a541d5ce4e629f9f7c2d584b0f0acc99577f7ad8453f6e5cf67b`
- Fund tx: `0xe4b56242b62a5ba6e45eae9b8aaddd3d7742f58ccf2d0c8c8e2be730909e9830`
- Submit tx: `0x6bd53a6225f1d922e47c2d8dfc90d18c43795f48d517fd38578ac34139b0aeb7`
- Evidence hash: `0x88b4ab1ea9205d04a9f30a1538a4e9de687b2bfa7057721cee258e9c551488fa`
- Request ID: `0x573176`
- Verdict callback tx: `0x005cd99be208ae5f2e0c58a987fef4fd90284ca5f72e1f6915840df4775c0d3b`
- Final LLM notes: `somnia-agent-request:5714304`
- Claim tx: `0xf3edffae91069d30f8c00f298db17d7591734eab292688141b590a712c4f46bd`
- Final verdict: `Complete`
- Final state: `Claimed`

### Final Milestone B - Finalize Three Agent Workflow

- Task ID: `21`
- Submission ID: `18`
- Amount: `8 STT`
- Claim policy: Client approval required
- Create tx: `0x1a6959849e4a3cba82ea66eab54b4cacdd8741e7fba2965f0286b782d4798cf5`
- Fund tx: `0x1067d208c3d21da26a09e1f162ca51e4b05f5a3e46c9fd70dd1f20b67785ff0a`
- Submit tx: `0x2da7eabd4de58ce513bae9f1c71db4099ef6be894547ba92007ab6b20d252aa6`
- Evidence hash: `0x88b4ab1ea9205d04a9f30a1538a4e9de687b2bfa7057721cee258e9c551488fa`
- Request ID: `0x573193`
- Verdict callback tx: `0xd29b8759152eae046c1f831679bcc3472af9fdb5d94b83ed85b774ffdb556093`
- Final LLM notes: `somnia-agent-request:5714330`
- Approve tx: `0x85d99791a314f779a677b97fae189f1e2431a442bbd381486dd396256d19dac5`
- Claim tx: `0xceedb2fbba8539ad7c42970cb64c25e564f004433edf07a2d0db575f969252f6`
- Final verdict: `Complete`
- Final state: `Claimed`

### Final Grant Round - Somnia Agent Builders Final Demo Round

- Round ID: `16`
- Prize: `2.5 STT`
- Max winners: `2`
- Total pool: `5 STT`
- Screening mode: `ThreeAgent`
- Requirements title: `Somnia Agent Builders Final Demo Round`
- Create tx: `0x4f593d3e2c5db6de1d0286df149606a91da85e001d52e672512c79b5280ef076`
- Fund tx: `0xee5ce4c6dcbdf4da23abc8a9289d2af56fe5749491dc3549dc5af08a24934730`
- Select finalists tx: `0xc464e1375de2a317eb8067ee0fc4bfdf54139fd1579430a558953c8931f02517`
- Finalize tx: `0xa830f8a36de685e1f2fc58d5660ad13968c054cad70b12eecfb238c5ca4d50ed`
- Final round state: `Finalized`
- Selected count: `2`
- Claimed count: `2`
- Total claimed: `5 STT`

Applications:

- Application `29`
  - Applicant: `0x110C2cfaC2Df847FBC98cc0c514A11d0e2046c13`
  - Submit tx: `0x455e1d8aeaf7cf8d172eebff2aa10e23b7356e9b19acd282d0e92ce3246fdccf`
  - Request screening tx: `0x04de0ef308e8008257aa789de174e5bf7b01c9eb8047921c2e76f2c030a28617`
  - Root request ID: `0x5733da`
  - Verdict callback tx: `0x4944d68415c8659e072d45c584c970ffa9ecda57482c84b72d3907b2427c82ec`
  - Final LLM notes: `somnia-agent-request:5714960`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0xa48e7b3d7233a44a8422aa8aa7053f08cb0f556f0e2b94df9402501c20656b61`
- Application `30`
  - Applicant: `0x0168DC0665b98bf9ceAb6B4c1cc2b0FD687C87A9`
  - Submit tx: `0xe7241643ef157d09326190c7bc3ef0794587ec3eac62a85539176094aada08d6`
  - Request screening tx: `0x32c1839686501662521bde573e7ae71f3b84e3d912f924138285c39377364f8b`
  - Root request ID: `0x5733fb`
  - Verdict callback tx: `0x262e5a3c55d8827d2d4e604139c18b4a2552d4e98bf86b27e7736d465bf0159c`
  - Final LLM notes: `somnia-agent-request:5714988`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0xc592633b0411ecae7187d5f71357ec19661fb257130095101d93cc078bbf0a8d`

## Final Top-of-List Scenarios

Date: `2026-06-09`

This final pass generated fresh high-quality on-chain rows for the top of the Milestones, Grants, Trail, and Recent Verifications views. Public on-chain titles avoid the word "Demo".

Dashboard layout change:

- Recent Grant Rounds: newest `3`
- Recent Milestones: newest `3`
- Recent Verifications: newest `10`

Evidence URLs used:

- Escrow: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/escrow-real/evidence-real-verified-complete.json`
- Grant: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-verified-complete.json`

### Grant A - Somnia Agent Tooling Grant

- Round ID: `17`
- Prize: `2 STT`
- Max winners: `2`
- Total pool: `4 STT`
- Screening mode: `ThreeAgent`
- Requirements title: `Somnia Agent Tooling Grant`
- Create tx: `0x9463f47f098fe695496f8d688cd4d8b915f4c820ac0b2d7c86e53df908bf2b91`
- Fund tx: `0x6692fa2a6bbdeaa578a1cb2161550d1c103e8c1c61f7ae899c4833bff84f1d45`
- Select finalists tx: `0x4b83063c8997c61dffbdb62d916c87330bafe4314413d118c0b247a269c81fd4`
- Finalize tx: `0x01817ddd1f6ccd967c72deee2bf27aa4e885e58ac536f5bc8e8efea751cd9638`
- Final round state: `Finalized`
- Selected count: `2`
- Claimed count: `2`
- Total claimed: `4 STT`

Applications:

- Application `31`
  - Submit tx: `0x4bb952ce956423effd4d01cb861538a246850a84fa25b48ef859a65fa3f5e3e7`
  - Request screening tx: `0xc2644c824bae88b63796a738f08dad986404cfcd36cb609a8a614c36c3ca4bc0`
  - Root request ID: `0x59f520`
  - Verdict callback tx: `0x4fe5edf13c56c9bf8fcbd682d249186a69b2d951f6627abf68c37a873cab34d3`
  - Final LLM notes: `somnia-agent-request:5895463`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0x1cac74c747cc9beff99054f94f05894ee7048462260acbd4e06464ea4978a7cf`
- Application `32`
  - Submit tx: `0xfc3262f2ed590e4eb0022fd6502d048513b04c8c4bacd05ff802f7ef8e027dce`
  - Request screening tx: `0xe79951728900ff9d866ea701632bec5233fa02aa5ed6003c0e52bcced0821159`
  - Root request ID: `0x59f523`
  - Verdict callback tx: `0x221428ae91713b3a55a2721b6fee7602579daeddfb1a7c026c53535a5d7d2141`
  - Final LLM notes: `somnia-agent-request:5895466`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0xc588198d05b98e2e43eac232f3b87b1284c423c1edd307a5b5809886503987e0`

### Grant B - Somnia Data & Oracle Infrastructure Grant

- Round ID: `18`
- Prize: `1.5 STT`
- Max winners: `3`
- Total pool: `4.5 STT`
- Screening mode: `ThreeAgent`
- Requirements title: `Somnia Data & Oracle Infrastructure Grant`
- Create tx: `0xc091d5f9a5e760fd26cc23fac9e89acfa2406c449a30ce6cec562a7d7363ec40`
- Fund tx: `0xaf561a7880e9525e6381a13ad9b2b3cde63956b961b9accb91b1ba9941b11a6b`
- Select finalists tx: `0x758875ef1119c0203e28637bcdd8c374b1c083003eed2157957e3b1e1f9d9c62`
- Finalize tx: `0xddf28dec6160f21aa19d2a702a9c7e265631819d30a069b01fc1019648c5ca34`
- Final round state: `Finalized`
- Selected count: `3`
- Claimed count: `3`
- Total claimed: `4.5 STT`

Applications:

- Application `33`
  - Submit tx: `0x0e3493f6f3389ea4ab4cdbd51eb7df313c80f85f5645c32fbcf86870afc592e2`
  - Request screening tx: `0x6d151146ef2110274d46047caa604fcf6461ad67450a448c3842cec32bc88942`
  - Root request ID: `0x59f526`
  - Verdict callback tx: `0x26b055c61455a64357d3e5a390208adeca125c06c7e341bb8f34af99e8bddaff`
  - Final LLM notes: `somnia-agent-request:5895473`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0x0bcb97370ffabb77b00be577829f57bbea46623028858adcce16d693fa61fd54`
- Application `34`
  - Submit tx: `0xaf309813824897d39ab8f46ecef5d7f6a287a083b4600fb06369027272264089`
  - Request screening tx: `0xf163715a4b3d4fbf5914bcb67f2d34da574e68d79c2c82df2a9472b0a80f748a`
  - Root request ID: `0x59f52b`
  - Verdict callback tx: `0x639ae34d017203192553ff90a64cc74429dbc3af7cfca250ea8333ffacbe58da`
  - Final LLM notes: `somnia-agent-request:5895477`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0x974377fec3b1e04ea04f5e22da0d1f1f6a0ae91b201337daee32b14c9fb88a89`
- Application `35`
  - Submit tx: `0xa4729256f7b69ffe75edea43dc3f637a77298767db6116244f6b4cf95f0c859a`
  - Request screening tx: `0x5be267ceada803379f1606dbbfbdb7bb27cb8273e9379f876cfb5b0fae0c2c08`
  - Root request ID: `0x59f52e`
  - Verdict callback tx: `0x14ef026873799ab418e3ed5bd2a3faa768ce32e72ffdf1a204e35f16421e8a10`
  - Final LLM notes: `somnia-agent-request:5895478`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0x5a8db482ec5b55ff3bf0165f966ac87f80a77066e5f230bd25a7dd4cf049afe8`
- Application `36`
  - Submit tx: `0xd474cb4f96855227cbd9e25623bd51d0b84745ce891d4673bec8dc93dad5c9db`
  - Request screening tx: `0x731c82f2943faa194421f94e0923fb56796d87b79e98ec7d8027a605ef2a6179`
  - Root request ID: `0x59f532`
  - Verdict callback tx: `0xa289cf89a5d7a18a7ca038e8a87f4f8ec1fb2a9aec8b221b80cfa8a4325b6899`
  - Final LLM notes: `somnia-agent-request:5895480`
  - Verdict: `Complete`
  - Final status: `Complete`
  - Selected: `false`
  - Claimed: `false`
  - Note: only three applications were selected because `maxWinners = 3`.

### Milestone A - Build Autonomous Lending Agent MVP

- Task ID: `22`
- Submission ID: `19`
- Amount: `5 STT`
- Claim policy: Immediate claim
- Create tx: `0x9275cf48b019064695eb1e21e902577c10500209bc3f6b85a6a26cda595bf79c`
- Fund tx: `0x31acd7cd53f0a5577d6dc973e27d08c0de0fd53582002c950a80c64a6fc910e1`
- Submit tx: `0x46f190e73afd982aef507241f156cb9fc705aee8169111b5b757c47be789f365`
- Request ID: `0x59f539`
- Verdict callback tx: `0xe6b5ed2d46a9c56bed1af61b88f8c020fca154151eb20b8fe6c91a912f422691`
- Final LLM notes: `somnia-agent-request:5895482`
- Claim tx: `0xdb9c94d5915bfe932e1f97120cf908c7298415c8c78df67601f713bf1489ef04`
- Final verdict: `Complete`
- Final state: `Claimed`

### Milestone B - Migrate Verification Flow Onchain

- Task ID: `23`
- Submission ID: `20`
- Amount: `3 STT`
- Claim policy: Client approval required
- Create tx: `0xacde2fb79161ee285610cb8e2c57d076d5a1442f8c1428d24e84b3f262fd713b`
- Fund tx: `0xdd92e2884f7a9d634492181eb720d29674eb80e7a51e10d766993e87e89f5061`
- Submit tx: `0x6ce18b039acd391d3bbbfab6186ba34fca2379049e38a4d087941a33c5768ce9`
- Request ID: `0x59f53b`
- Verdict callback tx: `0xd8a72073622e2df5d2c8aefb0bb947341370aac72877bcfb94e92176c73b3949`
- Final LLM notes: `somnia-agent-request:5895484`
- Approve tx: `0x89b1e0899d5adb64b6894c9ba1bce8269c2b00c0bdc73b9e19db510a75f04718`
- Claim tx: `0xcf025dd2176037473c2530fbacdd2a93e88704861f4c1b44e6a4eb6fe60ee7f6`
- Final verdict: `Complete`
- Final state: `Claimed`

### Milestone C - Build Somnia Native Bridge Prototype

- Task ID: `24`
- Submission ID: `21`
- Amount: `10 STT`
- Claim policy: Immediate claim
- Create tx: `0x15db1fd551ab94870dfa3d121bf50f0e4fb9e900317f62b7aebaa075c63f79c4`
- Fund tx: `0x595d69ae1940b8689b1b976e97ceeb2d29940e369083025a7d86d1445760dd3b`
- Submit tx: `0x5f8934aa45c2b8bc858c4496690558d18cbabefe8182017a499bc44ed8b9af9e`
- Request ID: `0x59f53d`
- Verdict callback tx: `0x5970bd618b2965e2c8e5ab304846cbc6792374e4c0fcf9e4f96dfc3d8d01789e`
- Final LLM notes: `somnia-agent-request:5895486`
- Claim tx: `0x73dd3c16b43fc78f47560dda2004d6d65e7a469120988912562cf76c8ef9bbfa`
- Final verdict: `Complete`
- Final state: `Claimed`

## Final Protocol Volume Scenarios

Date: `2026-06-09`

This final pass clarified dashboard KPI labels and added one last small set of polished top-of-list live rows. No dashboard statistics were hardcoded; values below come from direct contract reads.

Dashboard metric label changes:

- `Milestone Contracts` now uses subtext `N open milestones`.
- `Grant Rounds` now uses subtext `N open rounds`.
- `STT Locked` was renamed to `Protocol Volume`.
- `Protocol Volume` now shows the current distributed/settled total as the main value and the current locked/pool total as subtext.

### Grant A - Somnia Agent Tooling Grant Phase 2

- Round ID: `19`
- Prize: `2.5 STT`
- Max winners: `2`
- Total pool: `5 STT`
- Screening mode: `ThreeAgent`
- Create tx: `0x21adb1828427e22bba5b32a8f8dfbf10f9c5153f0c5d53f45fe91a9db26a6751`
- Fund tx: `0x937ccfb2d5516d8d8690235f8174632d767d21bcb4679f6dc34e4712feffd66e`
- Select finalists tx: `0x674af66fadda0cd75454e0b4cfbc9ce2a810f38c0cc48e76ff6784b9d3b99b65`
- Finalize tx: `0x585128ddbcf53bd43e6ae2b40358cef5dc0989fa3568ac513139cc04e50e4c0c`
- Final round state: `Finalized`
- Selected count: `2`
- Claimed count: `2`
- Total claimed: `5 STT`

Applications:

- Application `37`
  - Submit tx: `0xb9e8253fd0e46fd24f3cf9704c1cf09aa000b143fd8d865ef127816058e4e67b`
  - Request screening tx: `0x4df56f523896cb36cbedc8cd28edf2265ee28bc05e730e559765603fb54c542a`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5ba`
  - Verdict callback tx: `0x73a707932bcad76a4ac8d8d7d39302d6622d670ada560102c1b9589d365f7fa7`
  - Final LLM notes: `somnia-agent-request:5895619`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0x0f7ee0d58097f5d5ab8df469e6aef12d660c07de899aedb9e1783e84bb51265f`
- Application `38`
  - Submit tx: `0x068745cc6c44a3ef1d3c975ae6580c102852818ad55f349de2963f84772f0a4d`
  - Request screening tx: `0x7b212315d0da82a7ff51e0ea35fdcbb844c7bcb41b5fca63de3ea6889525515f`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5bd`
  - Verdict callback tx: `0x3f5635d3a8f9205f19ed47d94ec49a711b70cdef7060fdd8c22b05865783e1e1`
  - Final LLM notes: `somnia-agent-request:5895623`
  - Verdict: `Complete`
  - Final status: `Claimed`
  - Claim tx: `0x6c89541066c429a6c54c6ff7b2ec6c1d3445b33518abfc6447498d7208984fd1`
- Application `39`
  - Submit tx: `0xdbf471e3233c3c14e0362516f0492bc6eb8f038748d95f97241e55973b9feae3`
  - Request screening tx: `0x55ad65215b831e2556a8521cbc3d484b4643d0dad983e581ab4afbe11d57696a`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5c0`
  - Verdict callback tx: `0xb57c2678b82f8e4759c71f19a91f1099729ebdbd2acd47a5388ae039a8aec650`
  - Final LLM notes: `somnia-agent-request:5895627`
  - Verdict: `Complete`
  - Final status: `Complete`, unselected because `maxWinners = 2`
- Application `40`
  - Submit tx: `0x8698d3dca32ba4f6a11a8651ede0231daf5700063c978e71ee20ebb35a03492c`
  - Request screening tx: `0xf1e0f8f6750456083d2a659a3f39b16417c1523ccd16ae42cb140c2f8adb481b`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5c4`
  - Verdict callback tx: `0x2f038769dde6fc7a9b6143f3b7c167105b54f559d87340eca0d6779b0bc79df2`
  - Final LLM notes: `somnia-agent-request:5895631`
  - Verdict: `Complete`
  - Final status: `Complete`, unselected because `maxWinners = 2`

### Grant B - Somnia Cross-Chain Infrastructure Grant

- Round ID: `20`
- Prize: `3 STT`
- Max winners: `3`
- Total pool: `9 STT`
- Screening mode: `ThreeAgent`
- Create tx: `0x439bbd5fa564754ad7ea523a98f4651aa0a7a429e4c8282d2a81ca77c266a9e5`
- Fund tx: `0x50101d8c9a43331c9af01365b770df2621183044b2e32f68d854248e868b5ef4`
- Select finalists tx: `0xf5a1fec96b6f90cca41b5ba6e3776dd675abc7df6bbc4c70c800da8a35e681c2`
- Finalize tx: `0x2c8cd5aa79029096df02c88396bac887dee30aa2b1664fe1feb97de1075a62e4`
- Final round state: `Finalized`
- Selected count: `3`
- Claimed count: `3`
- Total claimed: `9 STT`

Applications:

- Application `41`
  - Submit tx: `0x88f4b70d1ac4a33e94e47ea967aa0913e54f8582a00c0bb2ebd025a1aa7b0753`
  - Request screening tx: `0x2397eb49b6a6c7494e4decde876b99edfa428e0764a91dc8fa90fca0d4869c45`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5c8`
  - Verdict callback tx: `0xa550eb988c97cce11aec687ca41da7f5229340c2ac993baf292ad3909be597b4`
  - Final LLM notes: `somnia-agent-request:5895636`
  - Final status: `Claimed`
  - Claim tx: `0xcb78744fae442e632470b636e88de3f3ea10095400274d4cc5f929420293e2e6`
- Application `42`
  - Submit tx: `0x61ed0c6f95715ee8414c35cf9e794b44aa7202ee2923df87d51cc7e93d7d3e0b`
  - Request screening tx: `0x51efae8539591ce1fd058872c779d1068e463478e0fa3e3155c5beea9881b26b`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5cd`
  - Verdict callback tx: `0x90b77b610c0462ec6c451a160db75be45b32250f526174782828bff05d2f537a`
  - Final LLM notes: `somnia-agent-request:5895640`
  - Final status: `Claimed`
  - Claim tx: `0xc11dbfb6472ddd36286eea382132e330936d5e3e7d3e358beb46dc3da309c530`
- Application `43`
  - Submit tx: `0x43b5714973abf7a9f9f7025742c7f6395e6e6c7720c4e3344ae96af5a3e662fb`
  - Request screening tx: `0x498e8b9285c3bd78458fbea6772f745a9a06c662022b477f24a70eff7ccb4b11`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5d1`
  - Verdict callback tx: `0xf8de28c9880f0e8c4ae587914bb9316a6f798eed933b66bc569c91893db1ec85`
  - Final LLM notes: `somnia-agent-request:5895642`
  - Final status: `Claimed`
  - Claim tx: `0xa547376a276fe4aa426554b976878c397ae005ce65d9e962f68928e1a9699c4f`
- Application `44`
  - Submit tx: `0x4ff9508dd5ddaa6bc424eabf479049db0b63d29a50a5e7297e8af64c58c4b3c2`
  - Request screening tx: `0x9d7c9075e894b960aa8806a7f1c1f8f00141023136970db7206e715a8154668c`
  - Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5d5`
  - Verdict callback tx: `0x45ae92b159ebf9d2f5d45eabf70fdfbd2e81b85b705455961ad8224018050e70`
  - Final LLM notes: `somnia-agent-request:5895644`
  - Final status: `Complete`, unselected because `maxWinners = 3`

### Milestone A - Implement Agent Request Monitoring

- Task ID: `25`
- Submission ID: `22`
- Amount: `4 STT`
- Claim policy: Immediate claim
- Create tx: `0x0ec59317a4eadf92045531b494f329a6e3f248a8d3ea5101ad3a724a05c7e883`
- Fund tx: `0xb950c5644f6c4a4253bff4108e9697cdb3c25c5abe1e83f303e71440c9aad214`
- Submit tx: `0x2bbae14f172d89d7046d8c3f9560d9cda7c862c2b0e2e4c684cb5d0f84c4631c`
- Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5d9`
- Verdict callback tx: `0xef60834cf11a13284caef0b0ed7ea266da1a5c6e2a24a4817a3f5fe24c50e892`
- Final LLM notes: `somnia-agent-request:5895643`
- Claim tx: `0x787ff661c7df8afc160fc737e7fa7cdf689a33f4bac87bc55fed4cb13992b785`
- Final verdict: `Complete`
- Final state: `Claimed`

### Milestone B - Ship Cross-Chain Evidence Indexer

- Task ID: `26`
- Submission ID: `23`
- Amount: `7 STT`
- Claim policy: Client approval required
- Create tx: `0xdd460aa00c332362f4a3999699ee1fd1a4a25cd414e079c57c0d433b2c682533`
- Fund tx: `0x21ada532d06b4ee1eb2f2ab9d6b1183fbcd864064df5ad108fdee07773595f39`
- Submit tx: `0xeb716d9996da837634ecdd90f82e64158ed4cfba45e3a9d2c6a13d5901f5b573`
- Root request ID: `0x000000000000000000000000000000000000000000000000000000000059f5dd`
- Verdict callback tx: `0xc1304c8941d99ec6255f2aa44b3dfdf9a8b0bcf5d8020cf5cb55f1a0092ecf82`
- Final LLM notes: `somnia-agent-request:5895646`
- Approve tx: `0xd534b4b1da74aba079825c8ae31b73c7e979427187c481557f5bd414bbe604af`
- Claim tx: `0x03e78b7a3675f4e8d47b4ac77ee0f3e4bca85f570d8c6d1210214dceb0194e8f`
- Final verdict: `Complete`
- Final state: `Claimed`

## Dashboard-Equivalent Aggregate Reads

Computed from direct RPC reads using the same fields as `app/web/lib/hooks.ts::useDashboardStats`.

- Milestone Contracts: `26`
- Grant Rounds: `20`
- Grant Applications: `44`
- Open milestones: `6`
- Open rounds: `6`
- Milestone locked: `4.8 STT`
- Milestone paid: `70.5 STT`
- Grant pool total: `65.74 STT`
- Grant paid: `46.74 STT`
- Protocol Volume / distributed total: `117.24 STT`
- Currently locked / pool total: `70.54 STT`
- Complete verdicts: `47`
- NeedsReview verdicts: `4`
- Incomplete verdicts: `3`
- Total bounded verdicts: `54`
- Verification failures: `7`
- Complete Verdict Rate: `87.0%`
- Milestone evidence submitted: `20`
- Grant applications screened: `41`

This improved the prior approximate dashboard rate from about `76%` to `87.0%` through real successful on-chain Complete verdicts, not manual stat edits.

## Limitations And Caveats

- The frontend was already deployed manually. Local copy polish and evidence refresh were pushed, but Vercel production may require a redeploy before the landing page text update is visible.
- `raw.githubusercontent.com/main` served a cached previous evidence body immediately after push. Commit-pinned raw URLs were used for live agent requests to avoid cache ambiguity.
- Some local Foundry `forge`/`cast` commands hit the macOS system-proxy panic. Direct explicit-RPC `cast` calls outside the sandbox were used for live transactions.
- Final polished scenario callback transaction hashes are enumerated above. Earlier historical scenario callback hashes remain summarized by final contract state, request IDs, and final LLM notes.
- Agents screen evidence and record bounded verdict metadata. They do not choose winners and do not move funds directly.
