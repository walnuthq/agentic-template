# Agentic Template Feedback - Rock Paper Scissors Game

## What Worked Well

- **TDD workflow with automated hooks**: TypeScript type checking and test runs on every file edit caught errors immediately. The feedback loop was fast and prevented broken code from accumulating.
- **CLAUDE.md guidance**: The structured instructions in both `project-template/CLAUDE.md` and `frontend-template/CLAUDE.md` gave Claude clear context about SDK patterns, testing conventions, and pitfalls. This reduced back-and-forth significantly.
- **SDK hook patterns**: The React SDK hook reference (`useAccount`, `useImportAccount`, `useSyncState`, `useMidenFiWallet`) was accurate and made it straightforward to build the frontend hooks for commit/reveal flows.
- **Contract-first workflow**: Building and testing contracts in Rust before moving to the frontend was the right sequence. The MockChain tests validated the game logic before any network interaction.
- **Subagent exploration**: Using explore agents to investigate the SDK source code (e.g., finding `resolveRpcUrl`, understanding `WalletContext` vs `MidenFiSignerProvider`) was effective for debugging issues that weren't documented.

## What Was Missing or Confusing

### Account Deployment Gap

- **Critical issue**: `create_account_from_package` / `client.add_account()` only stores the account locally. For Network mode accounts, you MUST also submit a transaction (`submit_new_transaction`) to register the account on the node. This was not documented anywhere and caused hours of debugging "account state not found" errors.
- **Suggestion**: Add a `deploy_account` helper to `helpers.rs` that does `add_account` + `submit_new_transaction` + wait for confirmation. Document this clearly in CLAUDE.md.

### MidenFi Wallet Limitations

- **Not documented**: MidenFi wallet extension only connects to testnet. There is no way to point it to a local node. This means the "local node development" path described in CLAUDE.md is not viable for frontend work with the wallet.
- **Suggestion**: CLAUDE.md should explicitly state that frontend development with MidenFi wallet requires testnet. Local node is only for CLI-based contract validation.

### WalletMultiButton Context Mismatch

- **Issue**: `WalletMultiButton` (from `@miden-sdk/miden-wallet-adapter-reactui`) uses `useWallet()` which reads from a different `WalletContext` than what `MidenFiSignerProvider` provides. This causes "You have tried to read 'address' on a WalletContext without providing one" errors on every render.
- **Root cause**: Two separate `WalletContext` instances — one in `useWallet.ts`, one in `MidenFiSignerProvider.tsx`.
- **Suggestion**: Either fix `WalletMultiButton` to use `useMidenFiWallet()`, or document that users should create a custom wallet button. We had to create `WalletButton.tsx` as a workaround.

### gRPC Service Paths Not Documented

- **Issue**: The Vite proxy was configured to match `/miden` but the actual gRPC-web paths are `/rpc.Api/SyncState`, `/rpc.Api/GetAccount`, etc. This caused silent proxy failures.
- **Suggestion**: Document the gRPC service path prefix (`/rpc.Api/`) for anyone setting up a proxy.

### Local Setup & CLI Setup Not Documented

- **Issue**: There is no documentation for setting up the local development environment (installing the Miden CLI, configuring `miden-client.toml`, creating accounts via CLI, etc.). The CLAUDE.md assumes you already have everything installed but never walks through it. Additionally, the local node setup only works for contract/CLI validation — frontend development requires testnet because MidenFi wallet cannot connect to a local node.
- **Suggestion**: Add a "Local Environment Setup" section to CLAUDE.md covering: installing `miden-node`, `miden-client` CLI, initial account creation, `miden-client.toml` configuration for both local and testnet, genesis node setup, and data storage directory configuration. Local node setup should be possible in a single command with sensible defaults. Clearly state that CLI workflows work against both local node and testnet, but frontend workflows are testnet-only.

### Debug Trace Logs Are Useless When `in_debug_mode` Is True

- **Issue**: When `in_debug_mode` is set to `true`, the trace log output is effectively useless — it produces massive, unstructured output that doesn't help diagnose issues. The signal-to-noise ratio is too low to identify actual problems.
- **Suggestion**: Improve the debug trace formatting to highlight relevant events (failed assertions, state transitions, errors), or provide a filtered/summary mode. Trace logs should be structured and actionable — currently they are text that make debugging harder, not easier. At minimum, document that `in_debug_mode` traces are not useful for debugging and suggest alternative approaches (e.g., targeted logging in test code).

### Version Mismatch Between Rust and JS SDKs

- **Issue**: `miden-client` Rust crate at 0.13.0 couldn't connect to testnet because the node expected 0.13.2. The frontend SDK was already at 0.13.2. The "accept header validation failed" error was cryptic.
- **Suggestion**: Pin both Rust and JS SDK versions together, or document the required version alignment.

### Playwright MCP Assumes Chrome — Fails for Arc Users

- **Issue**: As an Arc browser user, Playwright could not connect to the browser, and Claude never asked about the browser preference — it just failed silently. Had to install Chrome separately to get Playwright MCP working.
- **Suggestion**: Claude should detect or ask the user which browser they use before launching Playwright. Document that Playwright MCP requires Chrome/Chromium and does not work with Arc out of the box.

### Stale SQLite Store Blocks Network Switching

- **Issue**: The SQLite store caches genesis hash from the first network connection. Switching from local node to testnet (or vice versa) fails with "accept header validation failed" until you delete `store.sqlite3`.
- **Suggestion**: Document this clearly, or have the client detect genesis mismatch and offer to reset.

## Suggested Improvements

### Skills

- **`deploy-account` skill**: Step-by-step guide for deploying accounts to testnet, including the transaction submission step that's currently missing.
- **`network-debugging` skill**: Checklist for diagnosing "account not found", version mismatches, and CORS issues.

### Hooks

- **Post-deploy verification hook**: After running a deploy binary, verify the account exists on the target network by querying the RPC endpoint.

### Documentation

- Add a "Known Limitations" section to `frontend-template/CLAUDE.md`:
  - MidenFi wallet is testnet-only
  - `WalletMultiButton` needs `WalletProvider` (or use custom button with `useMidenFiWallet`)
  - WASM concurrent access crashes require sequential client method calls
- Add gRPC path prefix (`/rpc.Api/`) to Vite proxy documentation.

### Lessons Captured

- Always submit a transaction after `add_account` for Network mode accounts
- Delete `store.sqlite3` when switching between networks
- Use `useMidenFiWallet()` not `useWallet()` with `MidenFiSignerProvider`
- gRPC-web paths are `/rpc.Api/*`, not `/miden*`
- `cargo update -p miden-client` before deploying to testnet to match node version

## Patterns Worth Capturing as Skills

1. **Commitment-reveal pattern**: The RPS game's commit/reveal flow (hash commitment with nonce, store in localStorage, reveal later) is reusable for any game or auction.
2. **Network account polling**: The `useRpsGame` pattern of importing a network account, polling with `sync()` + `refetch()`, and reading `StorageMap` entries is a general pattern for reading any on-chain account state.
3. **Custom wallet button**: The `WalletButton.tsx` pattern using `useMidenFiWallet()` should replace `WalletMultiButton` in the template.

## Full Project Implementation

A Rock Paper Scissors game built on Miden during Miden Day March 2026: smart contracts with commit/reveal pattern, MockChain integration tests, testnet deployment, and a React frontend with Miden wallet integration.

| Repository                                                                                      | Branch                    |
| ----------------------------------------------------------------------------------------------- | ------------------------- |
| [project-template](https://github.com/walnuthq/project-template/tree/marijam/simple-rcs-game)   | `marijam/simple-rcs-game` |
| [frontend-template](https://github.com/walnuthq/frontend-template/tree/marijam/simple-rcs-game) | `marijam/simple-rcs-game` |
| [agentic-template](https://github.com/walnuthq/agentic-template/tree/marijam/simple-rcs-game)   | `marijam/simple-rcs-game` |
