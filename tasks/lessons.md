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
