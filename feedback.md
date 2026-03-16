# Post-Project Feedback: Simplified Auction on Miden

## What Worked Well

- **Detailed implementation plan** made execution straightforward. The plan covered storage layouts, procedure signatures, P2ID patterns, and test cases in enough detail to implement without guesswork.
- **Source repo exploration via sub-agents** was essential for discovering correct APIs (e.g. `WellKnownNote::P2ID.script_root()`, `AccountStorage::get_item`, `MockChainBuilder` note addition pattern).
- **Incremental test execution** caught issues early. Running tests after each contract was built revealed the `native_account::add_asset` note context issue before all contracts were complete.
- **CLAUDE.md pitfalls documentation** prevented Felt arithmetic bugs. The explicit warnings about modular subtraction and comparison operators saved debugging time.
- **Skills system** provided good domain-specific context (rust-sdk-patterns, rust-sdk-testing-patterns, rust-sdk-pitfalls).

## What Was Missing or Could Be Improved

- **No transaction debugging or user trace support.** When a transaction fails, you get a generic assertion error with no indication of which assertion failed or where in the contract execution it stopped. There is no `println!`/`dbg!` in `#![no_std]` contracts, no event emission in the Rust SDK, no line numbers in assertion errors (compiled to MASM), and no way to inspect intermediate state during transaction execution. The only debugging strategy is binary search via commenting out assertions — extremely slow for complex procedures like `place_bid` and `settle_auction`. This was the biggest pain point during development.
- **No documentation on note-to-account procedure call limitations.** The fact that `native_account::add_asset` cannot be called from note script context (only from account procedures) is a critical architectural constraint not documented in any skill or CLAUDE.md. This was the single biggest debugging challenge.
- **Asset layout documentation** (`[amount, 0, faucet_suffix, faucet_prefix]`) and P2ID input ordering (`[suffix, prefix]`) should be in the pitfalls skill. Getting either wrong causes silent failures.
- **MockChain limitations** (all notes must be added before `.build()`) should be documented in the testing patterns skill.
- **`Value::read()` type annotation requirement** is a common beginner stumble that should be in the patterns skill.
- **Node/client version mismatch is a silent failure mode.** `miden-client 0.13` requires `miden-node 0.13.x`, but the node installed via `cargo install miden-node` resolves to 0.12.2 (the latest stable on crates.io). The gRPC accept header validation rejects cross-version requests with a generic "server rejected request - please check your version and network settings" error that doesn't mention version mismatch. The fix is `cargo install miden-node --git https://github.com/0xMiden/miden-node --tag v0.13.8`. This version pairing (client ↔ node) should be documented prominently — ideally in CLAUDE.md and the `local-node-validation` skill — with the exact install command.

- **NoteTag routing bits are critical but undocumented for contract developers.** Contract-generated output notes using `Tag(0)` are invisible to client sync because no routing bits are set. The node filters notes by tag during sync, and `Tag(0)` matches nothing. The fix requires computing a proper account-targeted tag using bit manipulation on the recipient's account prefix — mirroring `NoteTag::with_account_target()` from Rust. This was the second-biggest debugging challenge during local-node validation (worked fine in MockChain tests which bypass sync entirely). The NoteTag bit layout, routing semantics, and the `compute_note_tag()` pattern should be in both `rust-sdk-pitfalls` and `local-node-validation` skills.

## Suggested Improvements

### New pitfalls to add to `rust-sdk-pitfalls`:
1. Note scripts cannot call `native_account::*` functions directly — must go through account procedures
2. Asset Word layout: `[amount, 0, faucet_suffix, faucet_prefix]`
3. P2ID recipient inputs: `[suffix, prefix]` (suffix first)
4. `Value::read()` always needs explicit `Word` type annotation
5. Contract-generated output notes MUST use account-targeted tags, not `Tag(0)` — `Tag(0)` has no routing bits and notes are invisible to sync
6. `Felt::new()` returns `Result<Felt, FeltError>`, not `Felt` — must unwrap

### New testing patterns to add to `rust-sdk-testing-patterns`:
1. All notes must be added to `MockChainBuilder` before `.build()`
2. Notes with same script need different inputs for unique NoteIds
3. Pattern for multi-transaction test flows: `apply_delta` -> `add_pending_executed_transaction` -> `prove_next_block`

## Patterns Worth Capturing as Skills

### "Receive Asset" pattern
A reusable pattern for any account component that needs to accept assets from notes:
```rust
pub fn receive_asset(&mut self, a0: Felt, a1: Felt, a2: Felt, a3: Felt) {
    let asset = Asset { inner: Word::new([a0, a1, a2, a3]) };
    native_account::add_asset(asset);
}
```

### CLI binary development patterns
When building `run_auction.rs` for local-node validation:

**Faucet creation:** `create_basic_fungible_faucet()` from `miden_standards` requires `AuthScheme::Falcon512Rpo` (not NoAuth). The function is NOT re-exported from miden-client, so import directly from `miden_standards::account::faucets`.

**Consuming notes from `get_consumable_notes`:** Returns `(InputNoteRecord, Vec<NoteConsumability>)`. `TransactionRequestBuilder::input_notes()` requires `(Note, Option<NoteArgs>)`. Convert via `let note: Note = record.try_into()?`.

**BlockNumber type:** Not a primitive — use `.as_u32()` for arithmetic/comparison.

**Minting:** `TransactionRequestBuilder::build_mint_fungible_asset()` consumes the builder and returns `TransactionRequest` directly (not a builder). No `.build()` call needed after it.

**Note discovery for contract-generated output notes:** Contract-generated P2ID notes MUST use proper account-targeted tags, not `Tag(0)`. Using `Tag(0)` means no routing bits are set and the node never serves these notes during sync. In the contract, compute the tag from the recipient's account prefix: `compute_note_tag(recipient_prefix)` using `(prefix_u64 >> 34) as u32 & 0xFFFF0000`. On the client side, register tags with `client.add_note_tag(NoteTag::with_account_target(account_id))`.

### "P2ID Output Note" pattern
Creating P2ID output notes from within account procedures for asset transfers:
```rust
fn compute_note_tag(account_prefix: Felt) -> Tag {
    let prefix_u64 = account_prefix.as_u64();
    let high_bits = (prefix_u64 >> 34) as u32;
    let tag_val = (high_bits & 0xFFFF0000u32) as u64;
    Tag::from(Felt::new(tag_val).unwrap())
}

let serial_num = Word::from_u64_unchecked(unique_id, 0, 0, 0);
let script_root = Digest::from_word(self.p2id_script_root.read());
let inputs = vec![recipient_suffix, recipient_prefix];
let recipient = Recipient::compute(serial_num, script_root, inputs);
let tag = compute_note_tag(recipient_prefix); // MUST use account-targeted tag, NOT Tag(0)
let note_type = NoteType::from(felt!(2));
let note_idx = output_note::create(tag, note_type, recipient);
native_account::remove_asset(asset.clone());
output_note::add_asset(asset, note_idx);
```
