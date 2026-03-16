# Lessons Learned

## Note scripts cannot call native_account functions directly
**Problem:** `native_account::add_asset` called from a note script compiles to an account procedure call, not a kernel syscall. The generated procedure root doesn't match any procedure on the target account, causing "procedure root not in account procedure index map" error.

**Fix:** Add a wrapper procedure (e.g. `receive_asset`) to the account component that calls `native_account::add_asset` internally. Note scripts call the wrapper instead. This works because `native_account::add_asset` called from within an account procedure context compiles to a kernel syscall.

**Pattern:** Always wrap `native_account::*` calls in account procedures when they need to be invoked from note scripts.

## Value::read() requires explicit type annotation
**Problem:** `self.field.read()[0]` fails with "type annotations needed" because `Value::read()` is generic.

**Fix:** Always use `let w: Word = self.field.read();` then access `w[0]`.

## All notes must be added to MockChainBuilder before .build()
**Problem:** Notes cannot be added to a MockChain after `builder.build()`.

**Fix:** Create all notes upfront and add them via `builder.add_output_note(OutputNote::Full(note))` before calling `builder.build()`.

## Notes with same script need different inputs for unique NoteIds
**Problem:** Two notes using the same script package will have the same NoteId if their inputs are identical, since the helper uses a fixed serial number `[0,0,0,0]`.

**Fix:** Pass different `inputs` values in `NoteCreationConfig` for each note.

## Asset Word layout
Fungible asset layout is `[amount, 0, faucet_suffix, faucet_prefix]`. When constructing assets in contract code, use the faucet ID components from storage in this order.

## P2ID note inputs order
P2ID recipient inputs are `[suffix, prefix]` (suffix first, prefix second). Getting this wrong causes the P2ID note to be unclaimable by the intended recipient.

## InputNoteRecord → Note conversion for TransactionRequestBuilder
`get_consumable_notes()` returns `InputNoteRecord` but `TransactionRequestBuilder::input_notes()` expects `(Note, Option<NoteArgs>)`. Convert with `let note: Note = record.try_into()?`.

## BlockNumber is not a primitive
`sync_state().block_num` returns `BlockNumber`, not `u32`/`u64`. Use `.as_u32()` for arithmetic.

## build_mint_fungible_asset consumes the builder
`TransactionRequestBuilder::build_mint_fungible_asset()` returns `Result<TransactionRequest>` directly — it already calls `.build()` internally. Don't chain `.build()` after it.

## create_basic_fungible_faucet needs miden_standards import
Not re-exported from miden-client. Import from `miden_standards::account::faucets::create_basic_fungible_faucet`. Requires `AuthScheme::Falcon512Rpo`, not `NoAuth`.

## Contract-generated output notes need proper NoteTag for sync discovery
**Problem:** Contract code creating P2ID output notes with `Tag::from(felt!(0))` produces notes with no routing bits set. The node never serves these during `sync_state()`, so the client never discovers them. This causes `wait_for_consumable_notes()` to time out.

**Fix:** Compute a proper account-targeted tag in the contract using the recipient's account prefix:
```rust
fn compute_note_tag(account_prefix: Felt) -> Tag {
    let prefix_u64 = account_prefix.as_u64();
    let high_bits = (prefix_u64 >> 34) as u32;
    let tag_val = (high_bits & 0xFFFF0000u32) as u64;
    Tag::from(Felt::new(tag_val).unwrap())
}
```
This mirrors `NoteTag::with_account_target()` for Public/Private accounts (14-bit tag length). On the client side, register tags with `client.add_note_tag(NoteTag::with_account_target(account_id))`.

## Felt::new() returns Result, not Felt
`Felt::new(value)` returns `Result<Felt, FeltError>`, not `Felt` directly. Must use `.unwrap()` or `?` to extract the value.
