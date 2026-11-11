---
name: panel
description: Ask a blind panel (Codex, Claude, Gemini) the same prompt in parallel, then compare their answers. Add --expert to build the prompt with expert-prompt first.
disable-model-invocation: true
---

A **blind panel**: three models from three labs get the identical prompt with no repo, no conversation and no hint of each other. Their agreement is signal; their disagreement is where the thinking is.

Panelists, set in [scripts/ask.sh](scripts/ask.sh) and overridable with `PANEL_*` env vars: Codex `gpt-6.1-sol` xhigh, Claude `claude-fable-5-2` xhigh, Gemini `gemini-4-carbon`. Needs the `codex`, `claude` and `gemini` CLIs signed in; Gemini reads `GEMINI_API_KEY`, or on macOS the Keychain item `gemini-api-key`.

## 1. Get the prompt

Pick the first branch that fits:

- **`--expert <goal>`**: find the installed `expert-prompt` skill's `SKILL.md` and follow it in full on the goal. The fenced prompt it produces is the panel prompt. If it isn't installed, say so and use the plain-question branch.
- **An expert prompt is already in this conversation** (from a recent `/expert-prompt`) and the user gave no new question: use that fenced prompt verbatim.
- **Plain question**: use the user's words verbatim. Add only facts the panel can't answer without (their situation, constraints), since panelists see nothing else. Never add your own opinion or framing.

Panelists are blind, so the prompt must stand alone: no "this repo", "the above", or file paths they can't read. If it needs code, paste the relevant excerpt in.

Done when: the prompt is written to `<run-dir>/input.md`, where run-dir is `~/.panel-runs/<YYYY-MM-DD-HHMM>-<short-slug>`, and you've shown the user the prompt in one fenced block.

## 2. Ask the panel

Run in the background (xhigh runs can take 10+ minutes), and tell the user it's running:

```sh
<this skill's directory>/scripts/ask.sh <run-dir>/input.md <run-dir>
```

Done when: the background task has finished and `status.txt` has a line for all three. A non-zero exit or empty `.md` means that panelist failed: read its `.log`, report it in one line, and continue with the rest.

## 3. Compare

Read every answer in full before writing. Then reply:

1. **TLDR:** the panel's answer in one or two lines, plus how unanimous it was.
2. **Agree:** the points all three made. Highest confidence.
3. **Split:** each real disagreement as one line per panelist, with the mechanism behind each position.
4. **Only one said it:** points a single panelist raised that matter. Often the most useful part.
5. **My read:** which side you'd back on each split, and why. Label it as your view.

Attribute every point by name (Codex, Claude, Gemini). Don't invent consensus: if two of three agree, say 2-1. End with the run-dir path so the user can read the raw answers.
