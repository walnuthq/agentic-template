# Lessons

- Do not ship placeholder branding into user-facing surfaces; use the agreed product name consistently.
- Distinguish Miden wallet addresses from AccountIds; user-facing recipient inputs may contain valid addresses with routing parameters and must not be rejected as malformed account IDs.
- On Miden, creating a private output note is not enough for cross-account delivery; custom private-note flows must also send and fetch note details through the note transport layer, and explorer links should use the account bech32 form expected by Midenscan.
- When AGENTS.md and local installed package/crate sources are available, use those local resources first; do not drift to web/API search for version-specific SDK behavior until the local authority has been exhausted.
- When a signer provider wraps `MidenProvider`, a disconnected wallet can legitimately leave `useMiden().isReady` false; do not gate the wallet connect UI behind `!isReady` or the app will look permanently stuck on initialization.
- In the Miden web bindings, `sendPrivateNote(note, address)` takes ownership of the Rust `Note`. Do not reuse the same `Note` object after wiring it into another SDK object; clone it first with `serialize`/`deserialize` or rebuild it from the same data.
- For wallet-extension bugs, terminal-side RPC checks and ad hoc frontend diagnostics are only partial tools; get direct browser/extension console access or an equivalent automation bridge early, otherwise debugging turns into repeated user log copy-paste and guesswork.
