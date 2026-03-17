# Rock-Paper-Scissors on Miden

A full-stack two-player Rock-Paper-Scissors game built on Miden, demonstrating the **commitment-reveal pattern**. Players commit hashed moves, reveal them, and the game account determines the winner on-chain.

## How It Works

1. **Commit phase** -- Each player picks Rock, Paper, or Scissors. The move is hashed with a random nonce (`RPO_hash(move, nonce)`) and the hash is submitted to the game account via a commit note. Neither player can see the other's move.
2. **Reveal phase** -- After both players have committed, each player reveals their original move and nonce. The game account re-computes the hash and verifies it matches the stored commitment.
3. **Resolution** -- Once both reveals are verified, the contract determines the winner (or draw) and stores the result on-chain.

## Prerequisites

- [Rust](https://rustup.rs/) (nightly toolchain)
- [midenup](https://github.com/0xMiden/midenup) toolchain (provides `cargo-miden`)
- [Node.js](https://nodejs.org/) (v18+)
- [Yarn](https://yarnpkg.com/) (v1)
- [Google Chrome](https://www.google.com/chrome/) (required for the frontend -- Arc/Safari won't work due to WASM SharedArrayBuffer requirements)
- [MidenFi wallet](https://chromewebstore.google.com/) Chrome extension (search "MidenFi" in the Chrome Web Store)

## Project Structure

```
agentic-template/
  project-template/                  # Smart contracts + tests (Rust SDK)
    contracts/
      rps-game-account/              # Game state account component
      rps-commit-note/               # Commit move note script
      rps-reveal-note/               # Reveal move note script
      rps-reset-note/                # Reset game note script
    integration/
      tests/rps_test.rs              # Integration tests (MockChain)
      src/bin/
        deploy_rps.rs                # Deploy game account to testnet
        play_rps.rs                  # Play a full game via CLI
  frontend-template/                 # Web frontend (React + TypeScript)
    src/
      hooks/                         # useRpsGame, useCommitMove, useRevealMove
      components/                    # RpsGame, MoveSelector, GameStatus
    public/packages/                 # Compiled .masp artifacts
```

## Setup

### 1. Clone and install

```bash
git clone --recurse-submodules https://github.com/0xMiden/agentic-template.git
cd agentic-template
```

### 2. Build all contracts

```bash
cd project-template
cargo miden build --manifest-path contracts/rps-game-account/Cargo.toml --release
cargo miden build --manifest-path contracts/rps-commit-note/Cargo.toml --release
cargo miden build --manifest-path contracts/rps-reveal-note/Cargo.toml --release
cargo miden build --manifest-path contracts/rps-reset-note/Cargo.toml --release
```

### 3. Run integration tests

```bash
cargo test -p integration --release --test rps_test
```

### 4. Deploy the game account to testnet

```bash
cargo run --bin deploy_rps --release
```

This prints a game account ID (hex). Copy it for the next steps.

### 5. Set the game address in the frontend

Open `frontend-template/src/config.ts` and set `RPS_GAME_ADDRESS` to the deployed account ID.

### 6. Copy contract artifacts to the frontend

The frontend loads compiled `.masp` packages at runtime from `public/packages/`. Copy them after building:

```bash
cp contracts/rps-commit-note/target/miden/release/rps_commit_note.masp ../frontend-template/public/packages/
cp contracts/rps-reveal-note/target/miden/release/rps_reveal_note.masp ../frontend-template/public/packages/
cp contracts/rps-game-account/target/miden/release/rps_game_account.masp ../frontend-template/public/packages/
```

### 7. Start the frontend

```bash
cd ../frontend-template
yarn install
yarn dev
```

Open `http://localhost:5173` in **Google Chrome** (not Arc or Safari).

## Playing the Game (Browser)

Two players take turns using the same game account. Each player needs the MidenFi wallet extension installed in Chrome.

### Setting up two wallets

To simulate two players, you need two separate Chrome profiles, each with its own MidenFi wallet:

1. **Create Chrome Profile 1** (Player 1):
   - Click your profile icon in Chrome's top-right corner > "Add" to create a new profile
   - Install the MidenFi wallet extension in this profile
   - Create a new wallet (this is Player 1's account)

2. **Create Chrome Profile 2** (Player 2):
   - Create another Chrome profile the same way
   - Install the MidenFi wallet extension in this profile
   - Create a new wallet (this is Player 2's account)

### Playing a match

1. **Player 1 commits**: Open `http://localhost:5173` in Profile 1, connect the wallet, and pick Rock/Paper/Scissors. This submits a commit note to the game account.

2. **Player 2 commits**: Open `http://localhost:5173` in Profile 2, connect the wallet, and pick a move. After both commits, the game advances to the reveal phase.

3. **Player 1 reveals**: Back in Profile 1, click "Reveal Move". The stored move and nonce are sent to the game account for verification.

4. **Player 2 reveals**: In Profile 2, click "Reveal Move". After both reveals, the game determines the winner.

5. **Play again**: Click "Refresh Game" to see the result. The game account can be reset for another round.

## Playing via CLI (no browser needed)

You can also play a complete game from the command line:

```bash
cd project-template

# Deploy a game account (if you haven't already)
cargo run --bin deploy_rps --release

# Play a game: <game_account_hex> <p1_move> <p2_move>
# Moves: 1=Rock, 2=Paper, 3=Scissors
cargo run --bin play_rps --release -- 0xYOUR_GAME_ACCOUNT 1 3
```

The CLI binary handles both players automatically -- it creates temporary wallets, commits both moves, reveals both, and announces the winner. The game account is automatically reset before each match.

## Development Workflow

1. **Build contracts** in `project-template/contracts/`
2. **Test contracts** with `cargo test -p integration --release --test rps_test`
3. **Deploy game account** with `cargo run --bin deploy_rps --release`
4. **Play via CLI** to validate: `cargo run --bin play_rps --release -- <game_hex> 1 3`
5. **Copy artifacts** to `frontend-template/public/packages/`
6. **Set game address** in `frontend-template/src/config.ts`
7. **Run frontend** with `cd frontend-template && yarn dev`

## AI Developer Experience

This template is designed for AI-assisted development. Open Claude Code at the repository root and describe what you want to build.

- `CLAUDE.md` at root provides the monorepo overview and workflow
- Each sub-template has its own `CLAUDE.md` with detailed instructions
- Skills load automatically when working in either template
- Hooks verify contract builds and frontend type safety on every edit
