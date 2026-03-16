# Sealed-Bid Auction — Feedback & Gap Findings

## What Worked Well

### Agentic Tooling
- **Skills system**: The `rust-sdk-pitfalls`, `rust-sdk-patterns`, and `local-node-validation` skills were highly valuable. They prevented known pitfalls (Felt arithmetic, `assert(Felt)` vs `assert!(bool)`, `felt!()` vs `Felt::new()`) before hitting them.
- **CLAUDE.md guidance**: The layered CLAUDE.md files (root, project-template, frontend-template) provided clear workflow instructions and the "contracts first, validate, then frontend" pipeline worked well.
- **Build hooks**: Auto-building contracts on edit (PostToolUse hooks) caught compile errors immediately, shortening the feedback loop.
- **Frontend test hooks**: TypeScript checking and test running on edit kept the frontend consistently passing.
- **Pattern files**: The existing `counter-account`, `increment-note`, and `counter_test.rs` provided solid templates for the auction implementation.

### Miden SDK
- **MockChain**: Fast, effective for testing 7 auction scenarios. `prove_until_block()` made block advancement straightforward.
- **Storage slots**: `Value` type with `.read()` / `.write()` is clean and intuitive for simple state.
- **Cross-component calls**: Note scripts calling account component methods via WIT bindings works smoothly once the Cargo.toml dependency sections are set up.
- **`WellKnownNote::P2ID`**: Having standard note scripts available via miden-standards is excellent.

### Frontend SDK
- **React hooks**: `useAccount`, `useSyncState`, `useImportAccount` etc. provide clean state management.
- **NoteScript.fromPackage**: Loading .masp artifacts at runtime is straightforward.
- **Mock infrastructure**: The pre-built mocks and fixtures in the test patterns made TDD very fast.

---

## Gap Findings

### 1. P2ID Output Notes — NoteType Must Be Private (Critical)
**Gap**: When creating P2ID output notes from within a contract using `output_note::create()`, using `NoteType::Public` (`felt!(1)`) causes a runtime error: "public note with metadata ... is missing details in the advice provider". The fix is to use `NoteType::Private` (`felt!(2)`).

**Why it's a gap**: There's no documentation or compile-time warning about this. The error message doesn't suggest the fix. A developer would need to understand the advice provider internals to debug this.

**Suggestion**: Add a warning in the `rust-sdk-pitfalls` skill about NoteType for dynamically-created output notes. Or better, provide a compile-time or runtime hint.

### 2. No Cheat Codes for Block Advancement
**Gap**: MockChain has `prove_until_block(n)` which works but requires proving empty blocks one at a time. There's no `set_block_number(n)` to jump directly to a target block.

**Impact**: Minor — `prove_until_block()` is adequate for testing. But for tests that need to advance hundreds of blocks (e.g., epoch-based logic), this would be slow.

**Suggestion**: Add a `MockChain::set_block_number(n)` or `advance_to_block(n)` that skips proof generation.

### 3. No Transaction Simulation Mode
**Gap**: There's no way to dry-run a transaction to check if it would succeed without committing. The only option is `tx_context.execute()` which fully runs it.

**Impact**: For frontend UX (showing "will this bid succeed?" before submitting), simulation would be valuable.

### 4. Error Message Quality for Contract Assertions
**Gap**: When `assert(felt!(0))` fires in a contract, the error contains a VM execution trace but doesn't include the custom assertion context (e.g., "Auction has ended" or "Bid below minimum"). The error is a generic assertion failure.

**Impact**: Debugging which assertion failed requires reading the instruction pointer and mapping it back to source code manually.

**Suggestion**: Support string-like assertion messages that appear in error traces, similar to Solidity's `require(condition, "message")`.

### 5. Local Chain Fork (Anvil-Equivalent)
**Gap**: There's no way to fork testnet/mainnet state into a local node. `miden-node bundled start` always bootstraps from genesis. No `--fork-url` equivalent.

**Impact**: Developers can't test against real-world state locally. They must either use testnet directly or recreate all state manually in MockChain.

**Suggestion**: This is a significant DX gap vs. Ethereum's Anvil `--fork-url`. Even a snapshot import/export mechanism would help.

### 6. Storage Slot Name Discovery
**Gap**: The storage slot naming convention `miden::component::<package_name>::<field_name>` (with hyphens converted to underscores) is not documented. Discovering the correct names requires trial and error or reading generated WIT files.

**Suggestion**: Add this convention to the SDK documentation. Or provide a `cargo miden inspect` command that lists storage slot names for a compiled package.

### 7. MockChain Builder vs MockChain API Split
**Gap**: Notes must be added via `builder.add_output_note()` before `MockChain::build()`. The `MockChain` itself doesn't have `add_output_note()`. This is confusing when multi-step tests need to create notes between transactions.

**Impact**: Tests with sequential transactions (bid1, then bid2) must create ALL notes upfront in the builder, even though they'll be consumed at different times.

### 8. `AccountId` to `Felt` Conversion
**Gap**: Converting `AccountId` to its prefix/suffix Felts requires `<[Felt; 2]>::from(id)` — the turbofish syntax is not intuitive. `AccountIdPrefix::as_felt()` works but requires extracting the prefix first.

**Suggestion**: Add `account_id.prefix_felt()` and `account_id.suffix_felt()` convenience methods.

### 9. Frontend: FungibleAsset Constructor Differences
**Gap**: The Rust SDK's `FungibleAsset::new(faucet_id, amount)` takes a `u64`, but the TypeScript SDK's `new FungibleAsset(faucetId, amount)` takes a `bigint`. The `NoteAssets` constructor also differs (Rust: `NoteAssets::new(vec![asset])`, TS: `new NoteAssets([asset])`). These API differences aren't documented.

**Suggestion**: Maintain a cross-SDK API comparison table for common operations.

---

## Patterns That Should Be Captured as New Skills

1. **P2ID Output Note Creation from Contracts**: The full pattern (Recipient::compute, output_note::create with Private NoteType, remove_asset, add_asset) should be a standalone skill with working code.

2. **Multi-Step MockChain Tests**: Pattern for tests that execute multiple transactions sequentially with state verification between each step.

3. **Auction/Escrow Pattern**: Time-locked operations with conditional refunds — this is a common DeFi primitive that could be a skill template.

---

## Summary

The agentic template is strong for simple contracts (counter-like). The sealed-bid auction pushed beyond basic patterns into:
- Dynamic P2ID output note creation (the NoteType::Private discovery was the hardest bug)
- Multi-step test scenarios with block advancement
- Cross-contract storage verification

The main gaps are in **error message quality** (assertion debugging), **missing documentation** (NoteType for output notes, storage slot naming), and **tooling** (no fork mode, no simulation). These are all solvable and would significantly improve the developer experience.

---

## Full Project Implementation

A sealed-bid auction system built on Miden during Miden Day March 2026: three smart contracts (auction account, bid note, finalize note), MockChain integration tests covering 7 scenarios, local-node deployment binaries, and a React frontend replacing the starter counter template.

| Repository | Branch |
|---|---|
| [project-template](https://github.com/walnuthq/project-template/tree/romanm/miden-day-march-2026) | `romanm/miden-day-march-2026` |
| [frontend-template](https://github.com/walnuthq/frontend-template/tree/romanm/miden-day-march-2026) | `romanm/miden-day-march-2026` |
| [agentic-template](https://github.com/walnuthq/agentic-template/tree/romanm/miden-day-march-2026) | `romanm/miden-day-march-2026` |
