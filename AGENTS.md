# Repository Guidelines

## Project Structure & Module Organization
- `contracts/`: Foundry project for Solidity.
  - `contracts/src/`: core contracts (e.g., `FGO*.sol`).
  - `contracts/test/`: Foundry tests (`*.t.sol`).
  - `contracts/script/`: deployment scripts (e.g., `DeployCore.s.sol`).
  - `contracts/foundry.toml`: Foundry config.
- `subgraph/`: The Graph subgraph for indexing contracts.
  - `subgraph/src/`: AssemblyScript/TypeScript handlers.
  - `subgraph/tests/`: Matchstick unit tests (`*.test.ts`, `*-utils.ts`).
  - `subgraph/subgraph.yaml`: data sources/entities.
  - `subgraph/docker-compose.yml`: local Graph Node/IPFS setup.

## Build, Test, and Development Commands
- Contracts (Foundry):
  - `forge build`: compile Solidity (IR enabled via config).
  - `forge test -vv`: run unit tests with verbose logs.
  - `forge fmt`: format Solidity sources.
  - `forge script script/DeployCore.s.sol --rpc-url $RPC_URL --broadcast`: deploy script (set `PRIVATE_KEY`).
- Subgraph:
  - `cd subgraph && npm ci`: install dependencies.
  - `npm run codegen && npm run build`: generate types, compile mappings.
  - `docker-compose up -d`: start local Graph Node + IPFS.
  - `npm run create-local && npm run deploy-local`: create and deploy locally.
  - `npm test`: run Matchstick tests.

## Coding Style & Naming Conventions
- Solidity: 4‑space indent; PascalCase contracts; file names match contract names; constants `UPPER_CASE`; events PascalCase; functions camelCase.
- Tests: Solidity tests in `*.t.sol`; name tests descriptively (e.g., `testMint_RevertsWithoutRole`).
- Subgraph TS: camelCase for functions/vars; handler names `on<Event>`; keep modules small and cohesive.

## Testing Guidelines
- Frameworks: Foundry (contracts) and Matchstick (subgraph).
- Include positive + revert paths; assert events and state transitions.
- No strict coverage threshold; prioritize critical flows and edge cases.

## Commit & Pull Request Guidelines
- Commits: imperative mood, focused scope (e.g., `contracts: add role checks`, `subgraph: index PrintZone events`).
- PRs: clear summary, linked issues, test output/screenshots; include deployment notes for contract changes and steps to validate subgraph indexing locally.

## Security & Configuration Tips
- Never commit secrets; use env vars (`ETH_RPC_URL`/`RPC_URL`, `PRIVATE_KEY`).
- Review access control changes carefully; prefer least privilege and explicit role checks.
