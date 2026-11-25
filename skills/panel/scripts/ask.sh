#!/usr/bin/env bash
# Send one prompt to a blind panel (Codex 6.1 Sol, Codex 6.2 Astra, Claude, Gemini Neon) in parallel.
# Usage: ask.sh <prompt-file> <run-dir>
# Each panelist runs in an empty folder with no repo, no conversation and read-only tools.
set -uo pipefail

PROMPT_FILE="$1"; RUN_DIR="$2"
CODEX_MODEL="${PANEL_CODEX_MODEL:-gpt-6.1-sol}";     CODEX_EFFORT="${PANEL_CODEX_EFFORT:-xhigh}"
CODEX2_MODEL="${PANEL_CODEX2_MODEL:-gpt-6.2-astra}"; CODEX2_EFFORT="${PANEL_CODEX2_EFFORT:-xhigh}"
CLAUDE_MODEL="${PANEL_CLAUDE_MODEL:-claude-fable-5-2}"; CLAUDE_EFFORT="${PANEL_CLAUDE_EFFORT:-xhigh}"
GEMINI_MODEL="${PANEL_GEMINI_MODEL:-gemini-4-neon-high}"

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

run codex codex --search exec -m "$CODEX_MODEL" -c model_reasoning_effort="$CODEX_EFFORT" \
  -s read-only --skip-git-repo-check --ephemeral -C "$BLIND" "$PROMPT" &

run codex-6.2 codex --search exec -m "$CODEX2_MODEL" -c model_reasoning_effort="$CODEX2_EFFORT" \
  -s read-only --skip-git-repo-check --ephemeral -C "$BLIND" "$PROMPT" &

run claude claude -p --model "$CLAUDE_MODEL" --effort "$CLAUDE_EFFORT" \
  --tools "WebSearch,WebFetch" --strict-mcp-config --no-session-persistence "$PROMPT" &

# Gemini through the Antigravity CLI. Plan mode is read-only and keeps web search.
# Flags must come before --print, and the prompt attaches with '='. Print mode can't approve
# shell commands, so the suffix tells it not to try. Never add --dangerously-skip-permissions.
run gemini agy --model "$GEMINI_MODEL" --mode plan --new-project --print-timeout 0 \
  --print="$PROMPT

(Answer in your reply. Do not run shell commands or write files.)" &

wait
rm -rf "$BLIND"
cat "$RUN_DIR/status.txt"
