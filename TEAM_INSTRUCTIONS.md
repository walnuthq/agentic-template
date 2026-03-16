# Miden Agentic Day — Team Instructions

## Goal

Each team member takes the `agentic-template` and builds something with it during the session. All work goes into a **single shared repository** — no forks, no separate repos.

## Repository

**Repo:** `0xMiden/miden-agentic-day-march-2026`

Each person gets their own folder at the root:

```
miden-agentic-day-march-2026/
├── romanm/
│   ├── feedback.md          ← required
│   ├── CLAUDE.md
│   ├── project-template/
│   └── frontend-template/
├── alice/
│   ├── feedback.md          ← required
│   ├── CLAUDE.md
│   ├── project-template/
│   └── frontend-template/
└── bob/
    ├── feedback.md          ← required
    └── ...
```

## Setup (Step by Step)

### 1. Clone the shared repo

```bash
git clone git@github.com:0xMiden/miden-agentic-day-march-2026.git
cd miden-agentic-day-march-2026
```

### 2. Copy the template into your folder

Clone the template separately, flatten it (remove submodule git history), and copy it in:

```bash
# Clone template with submodule contents
git clone --recurse-submodules git@github.com:0xMiden/agentic-template.git /tmp/agentic-template

# Remove all .git directories (flattens submodules into regular directories)
find /tmp/agentic-template -name .git -type f -delete
find /tmp/agentic-template -name .git -type d -exec rm -rf {} + 2>/dev/null

# Copy into your folder (replace YOUR_NAME with your name)
mkdir -p YOUR_NAME
cp -r /tmp/agentic-template/* YOUR_NAME/
cp -r /tmp/agentic-template/.claude YOUR_NAME/
cp -r /tmp/agentic-template/.mcp.json YOUR_NAME/

# Clean up
rm -rf /tmp/agentic-template
```

### 3. Remove files that should not be committed

```bash
cd YOUR_NAME

# Remove local state / databases
rm -rf local-node-data/ local-keystore/ local-store.sqlite3
rm -rf store.sqlite3 keystore/
rm -rf .playwright-mcp/

# Remove build artifacts
rm -rf project-template/target/
rm -rf project-template/contracts/*/target/
rm -rf frontend-template/node_modules/
rm -rf frontend-template/dist/

# Remove tasks directory (session-specific)
rm -rf tasks/
```

### 4. Install dependencies

```bash
# Frontend
cd frontend-template
yarn install
cd ..

# Contracts — verify toolchain
miden --version          # should be 0.13.x
cargo miden --version    # should work
```

### 5. Commit and push your initial copy

```bash
cd ..  # back to repo root
git add YOUR_NAME/
git commit -m "Add YOUR_NAME workspace from agentic-template"
git push
```

## Working With Claude Code

Start Claude Code from **your folder** (not the repo root):

```bash
cd YOUR_NAME
claude
```

The CLAUDE.md files in your folder will load automatically and guide the workflow.

## What to Build

Use the template to build anything — the contracts + frontend pipeline is:

1. Write smart contracts in `project-template/contracts/`
2. Test with MockChain in `project-template/integration/tests/`
3. Validate against local node in `project-template/integration/src/bin/`
4. Build frontend in `frontend-template/src/`

See `CLAUDE.md` in your folder for the full workflow.

## Required: feedback.md

Every participant **must** have a `feedback.md` at the root of their folder. Generate it after completing your project (or ask Claude to generate it). It should cover:

- What worked well with the agentic tooling (skills, hooks, CLAUDE.md)
- What was missing, confusing, or incorrect
- Suggested improvements
- Patterns that should be captured as new skills or lessons
- Any SDK gaps or bugs discovered

This is the most valuable output of the session — we use it to improve the template and the SDK.

## Rules

- **Do NOT fork** the agentic-template repo. Flatten and copy.
- **Do NOT push to someone else's folder.** Only modify `YOUR_NAME/`.
- **Do NOT commit** `.env` files with secrets, `node_modules/`, `target/`, database files, or keystore files.
- **Do** commit `.claude/` directory (hooks and skills are part of the template).
- **Do** commit contract source and test files.
- **Do** commit frontend source and test files.
- **Do** generate and commit `feedback.md` before the end of the session.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `cargo miden build` fails | Run `midenup` to install/update the toolchain |
| Frontend WASM errors | Make sure `yarn install` completed and dev server has COOP/COEP headers (handled by vite config) |
| Port 57291 in use | `lsof -ti:57291 \| xargs kill -9` |
| Submodule `.git` files left over | `find . -name .git -type f -delete` |
| Claude Code doesn't load skills | Make sure you're running from your folder, not the repo root |
