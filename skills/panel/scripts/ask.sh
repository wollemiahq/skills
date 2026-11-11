#!/usr/bin/env bash
# Send one prompt to a blind panel (Codex, Claude, Gemini) in parallel.
# Usage: ask.sh <prompt-file> <run-dir>
# Each panelist runs in an empty folder with no repo, no conversation and read-only tools.
set -uo pipefail

PROMPT_FILE="$1"; RUN_DIR="$2"
CODEX_MODEL="${PANEL_CODEX_MODEL:-gpt-6.1-sol}";   CODEX_EFFORT="${PANEL_CODEX_EFFORT:-xhigh}"
CLAUDE_MODEL="${PANEL_CLAUDE_MODEL:-claude-fable-5-2}"; CLAUDE_EFFORT="${PANEL_CLAUDE_EFFORT:-xhigh}"
GEMINI_MODEL="${PANEL_GEMINI_MODEL:-gemini-4-carbon}"

mkdir -p "$RUN_DIR"
BLIND="$(mktemp -d)"            # empty working folder: nothing to read
PROMPT="$(cat "$PROMPT_FILE")"
cp "$PROMPT_FILE" "$RUN_DIR/prompt.md"
cd "$BLIND"

run() { # name, then command
  local name="$1"; shift
  local start=$SECONDS
  "$@" > "$RUN_DIR/$name.md" 2> "$RUN_DIR/$name.log"
  echo "$name: exit $? in $((SECONDS-start))s" >> "$RUN_DIR/status.txt"
}

run codex codex exec -m "$CODEX_MODEL" -c model_reasoning_effort="$CODEX_EFFORT" \
  -s read-only --skip-git-repo-check --ephemeral -C "$BLIND" "$PROMPT" &

run claude claude -p --model "$CLAUDE_MODEL" --effort "$CLAUDE_EFFORT" \
  --tools "WebSearch,WebFetch" --strict-mcp-config --no-session-persistence "$PROMPT" &

# Gemini key: $GEMINI_API_KEY, else the macOS Keychain item "gemini-api-key".
if [ -z "${GEMINI_API_KEY:-}" ] && command -v security >/dev/null; then
  GEMINI_API_KEY="$(security find-generic-password -a "$USER" -s gemini-api-key -w 2>/dev/null)"
fi
GEMINI_API_KEY="${GEMINI_API_KEY:-}" \
  run gemini gemini -m "$GEMINI_MODEL" --skip-trust --approval-mode plan -p "$PROMPT" &

wait
rm -rf "$BLIND"
cat "$RUN_DIR/status.txt"
