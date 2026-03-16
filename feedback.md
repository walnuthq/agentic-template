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

## Suggested Improvements

### New pitfalls to add to `rust-sdk-pitfalls`:
1. Note scripts cannot call `native_account::*` functions directly — must go through account procedures
2. Asset Word layout: `[amount, 0, faucet_suffix, faucet_prefix]`
3. P2ID recipient inputs: `[suffix, prefix]` (suffix first)
4. `Value::read()` always needs explicit `Word` type annotation

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

### "P2ID Output Note" pattern
Creating P2ID output notes from within account procedures for asset transfers:
```rust
let serial_num = Word::from_u64_unchecked(unique_id, 0, 0, 0);
let script_root = Digest::from_word(self.p2id_script_root.read());
let inputs = vec![recipient_suffix, recipient_prefix];
let recipient = Recipient::compute(serial_num, script_root, inputs);
let tag = Tag::from(felt!(0));
let note_type = NoteType::from(felt!(2));
let note_idx = output_note::create(tag, note_type, recipient);
native_account::remove_asset(asset.clone());
output_note::add_asset(asset, note_idx);
```
