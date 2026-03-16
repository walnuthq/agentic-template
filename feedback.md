# Feedback

## What Worked Well

- The repo split between `project-template/` and `frontend-template/` is clear and helped isolate contract/client work from frontend work.
- The root `AGENTS.md` captured the intended workflow well:
  - contracts first
  - local-node validation before frontend
  - explicit verification commands
- The frontend template already had enough scaffolding around `@miden-sdk/react` and the wallet adapter to get a testnet prototype moving without building the entire integration layer from scratch.
- Automated verification was useful once the implementation stabilized. Re-running `yarn test` and `yarn build` repeatedly caught regressions while debugging the SDK interop problems.

## What Was Missing, Confusing, Or Incorrect

- The biggest gap was around Miden identity forms in the frontend:
  - wallet address with routing suffix, e.g. `mtst1..._qruqqypuyph`
  - explorer/account bech32 id, e.g. `mtst1...`
  - internal `AccountId` hex/string form, e.g. `0x...`
  The current guidance does not make the boundaries between these forms explicit enough, and the agent repeatedly mixed them.
  It is especially easy for an agent to make incorrect comparisons or persistence choices here unless the docs state one canonical app-state identity and treat the others as input/display forms only.

- The repo guidance says "Contracts first, validate against local node, then frontend", but the work drifted into frontend testnet integration before the local-node path had fully de-risked the note/address model. That created a long debugging loop inside the web client.

- The Miden web SDK surface is easy to misuse:
  - `useMiden().signerAccountId` and the connected wallet address are not interchangeable.
  - `useMidenClient()` can be unsafe if used as though it were a nullable getter rather than a hook that assumes readiness.
  - private note creation, note transport, and note fetch are separate steps, but the abstraction boundaries do not make that obvious enough.

- The signer/provider lifecycle is still too opaque for wallet-connected frontends:
  - background `signBytes` prompts were difficult to attribute to a specific app action.
  - it was not clear when the wallet was being asked to sign because of explicit user intent versus provider/client bootstrap side effects.
  - this made it hard to distinguish a product bug from an SDK/provider integration bug.
  - when a signer provider wraps `MidenProvider`, the client may intentionally stay uninitialized until the wallet is connected; if the app hides the connect button behind `!isReady`, users just see `Initializing Miden client...` forever and it looks like a broken bootstrap rather than an expected pre-connect state.

- Session-wallet ergonomics were not mature enough for the messenger use case:
  - the intended "fund once, send many messages" model sounded promising, but the lifecycle was not easy to compose safely inside a chat UI.
  - it was too easy to end up with rehydration/bootstrap behavior that was hard to reason about from the app side.

- Persistence expectations were misleading for a messenger product:
  - it was easy to assume private messages could be treated like durable network-backed history.
  - in practice, usable chat history depended on a mix of local client state, note transport delivery, and browser persistence.
  - the current architecture did not give "come back tomorrow and see all messages" behavior by default.

- The note decoding/debugging path was harder than it should have been because SDK/WASM panics bubble out as low-level Rust errors (`null pointer passed to rust`, `UnknownAccountIdVersion`, `unreachable`) instead of giving a stronger TS-level API boundary.
- The JS/WASM ownership model for note objects is easy to trip over:
  - reusing the same `Note` instance across transaction construction and `sendPrivateNote()` can trigger low-level Rust ownership failures like `attempted to take ownership of Rust value while it was borrowed`
  - the frontend needs an explicit clone step (`serialize`/`deserialize`) or a second note built from the same inputs when a note is passed through multiple consuming SDK calls

## Key Issues Faced

- Wallet/provider mismatch:
  - the frontend initially mixed `MidenFiSignerProvider` with wallet-context UI components that expected a different provider stack.
  - result: disabled send button and missing provider errors.

- Identity confusion:
  - valid Miden wallet receive addresses were initially treated as malformed account ids.
  - explorer links were built from the wrong identifier.
  - sender metadata and local tracking briefly used the wrong local signer account instead of the connected wallet-derived account.

- Private note lifecycle confusion:
  - creating a private note on-chain was initially treated as if it implied recipient delivery.
  - in practice, note transport send/fetch had to be wired explicitly.

- Recipient decode/display bugs:
  - several iterations tried to reconstruct account ids manually from payload pieces.
  - this caused repeated WASM panics such as:
    - `null pointer passed to rust`
    - `array contains a value of the wrong type`
    - `UnknownAccountIdVersion(...)`
    - `InvalidLength { expected: 32, actual: ... }`
  - the note data was often already in the client store while the UI was failing on its own reconstruction logic.

- Debugging friction:
  - browser-console logs were necessary because the terminal dev server output did not expose client-side behavior.
  - extension noise (`impersonator.js`, `app.onchainden.com`, Intercom content scripts) polluted the console and made signal extraction harder.
  - the debugging loop depended on a mix of partial tools:
    - terminal-side RPC/account checks to confirm whether an account existed or the network was reachable
    - local SDK source inspection in `node_modules` to understand signer/provider behavior
    - an ad hoc in-app diagnostics panel to expose wallet/signer/client state
    - repeated user copy-paste of browser console output because the agent had no direct access to the live wallet-extension/browser session
  - that combination was enough to narrow issues down eventually, but it was slow and brittle for wallet-driven frontend debugging.

- Wallet prompt spam:
  - repeated signature prompts appeared even without pressing "Send".
  - the error surface pointed at `signBytes` / signer-bridge behavior rather than explicit transaction submission.
  - this created a poor UX and consumed a lot of debugging time because the prompts were not obviously tied to one code path.

## Tangent / Process Failure

- A subagent drifted to web search (`docs.rs` and related queries) instead of grounding itself first in repository-provided resources and local installed sources.
- This was the wrong move in this repo for two reasons:
  - the root `AGENTS.md` and local package sources already provided the primary workflow constraints
  - the installed `node_modules` and local Rust crate sources were more authoritative for the exact SDK versions actually in use than ad hoc web search
- Why it likely happened:
  - the task mixed fast-changing SDK behavior, Rust APIs, and frontend wrappers
  - the agent reached for online API discovery before exhausting the local sources
  - the local-vs-remote authority rule was not enforced tightly enough in execution
- What should have happened instead:
  - read root `AGENTS.md`
  - read local `CLAUDE.md` / package docs in the active subproject
  - inspect installed `node_modules/@miden-sdk/*`
  - inspect local Cargo registry sources for the exact `miden-client` version
  - only browse externally if those sources were insufficient

## Suggested Improvements

- Add a short repo note that explicitly defines the three identity forms and where each should be used:
  - wallet address
  - account bech32 id
  - internal `AccountId`

- Add a local-node validation example specifically for private custom-note transport, not only standard asset sends.

- Add a frontend-specific note in guidance that says:
  - do not manually reconstruct `AccountId` values from payload felts unless an official helper exists
  - prefer preserving typed SDK objects (`Address`, `AccountId`) instead of converting to strings and back

- Add guidance for wallet-connected frontend architecture:
  - when to mount `MidenProvider` relative to signer/wallet providers
  - which operations can trigger background signing
  - how to debug repeated `signBytes` prompts

- Add guidance for persistence expectations in private-note apps:
  - what the network proves
  - what note transport provides
  - what the local client persists
  - when the app still needs its own durable message journal

- Add a troubleshooting section for common Miden web-client failure signatures:
  - provider mismatch
  - signer vs wallet identity mismatch
  - private note not fetched because tag not tracked
  - transport delivered note but UI failed during decode

- Add better debugging support for wallet-connected frontend work:
  - a browser verification workflow that can access the real wallet extension and console directly
  - a first-class way to stream/filter app console logs without extension noise
  - a CLI or scripted harness that mirrors the signer-account + private-note wallet flow, not just raw RPC/account checks
  - guidance on when terminal-side RPC probing is useful and when it cannot answer frontend/extension questions

- Add a process rule or checklist item:
  - for version-specific SDK debugging, inspect local installed sources before web search

## Patterns To Capture As New Skills Or Lessons

- Miden web identity handling:
  - how to distinguish wallet addresses, explorer ids, and `AccountId` strings
  - how to derive the correct sender/recipient identity for custom notes

- Miden private note debugging:
  - prove chain commit
  - prove note transport send
  - prove recipient fetch
  - prove decode/render
  - avoid string round-trips through WASM account-id constructors

- Miden signer/provider debugging:
  - trace explicit transaction prompts vs background signer prompts
  - isolate provider bootstrap effects from application logic
  - verify whether repeated wallet prompts come from send flows, note fetch, or signer-context initialization

- Private-note persistence model:
  - how much history can be recovered from chain metadata alone
  - what requires note transport and local client state
  - when app-level persistence is still required for messenger UX

- Agent workflow discipline:
  - when AGENTS/resources point to local authority, prefer local source inspection over web browsing
