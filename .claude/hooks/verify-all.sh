#!/bin/bash
# Stop hook: runs full verification for both templates on task completion.
# Only runs when source files have changed since last successful run.

PROJECT_HASH=$(echo "$CLAUDE_PROJECT_DIR" | md5 -q 2>/dev/null || echo "$CLAUDE_PROJECT_DIR" | md5sum 2>/dev/null | cut -c1-8 || echo "default")
LOCK_FILE="/tmp/claude-verify-all-${PROJECT_HASH}.last"

# Find the most recently modified source file timestamp
LATEST_SRC=0
for dir in "$CLAUDE_PROJECT_DIR/project-template/contracts" "$CLAUDE_PROJECT_DIR/project-template/integration" "$CLAUDE_PROJECT_DIR/frontend-template/src"; do
  if [[ -d "$dir" ]]; then
    ts=$(find "$dir" \( -name "*.rs" -o -name "*.ts" -o -name "*.tsx" \) -not -path "*/target/*" -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1)
    if [[ -n "$ts" && "$ts" -gt "$LATEST_SRC" ]]; then
      LATEST_SRC=$ts
    fi
  fi
done

# Skip if no source files changed since last run
if [[ -f "$LOCK_FILE" ]]; then
  LAST_RUN=$(cat "$LOCK_FILE")
  if [[ "$LATEST_SRC" -le "$LAST_RUN" ]]; then
    exit 0
  fi
fi

FAILED=0

# --- Project Template: contract integration tests ---
PROJECT_DIR="$CLAUDE_PROJECT_DIR/project-template"
if [[ -d "$PROJECT_DIR/contracts" ]]; then
  echo "=== Verifying project-template contracts ===" >&2
  cd "$PROJECT_DIR" || true

  if cargo test -p integration --release --tests 2>&1; then
    echo "project-template: integration tests passed" >&2
  else
    echo "project-template: integration tests FAILED" >&2
    FAILED=1
  fi
fi

# --- Frontend Template: tests + typecheck + build ---
FRONTEND_DIR="$CLAUDE_PROJECT_DIR/frontend-template"
if [[ -d "$FRONTEND_DIR/node_modules" ]]; then
  echo "=== Verifying frontend-template ===" >&2
  cd "$FRONTEND_DIR" || true

  if npx vitest --run 2>&1; then
    echo "frontend-template: tests passed" >&2
  else
    echo "frontend-template: tests FAILED" >&2
    FAILED=1
  fi

  if npx tsc -b --noEmit 2>&1; then
    echo "frontend-template: type check passed" >&2
  else
    echo "frontend-template: type check FAILED" >&2
    FAILED=1
  fi

  if npx vite build 2>&1; then
    echo "frontend-template: build passed" >&2
  else
    echo "frontend-template: build FAILED" >&2
    FAILED=1
  fi
fi

# Record timestamp on success
if [[ $FAILED -eq 0 ]]; then
  date +%s > "$LOCK_FILE"
  exit 0
else
  exit 2
fi
