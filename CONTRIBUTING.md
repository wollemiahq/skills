# Contributing

## Adding a skill

```
skills/<name>/
├── SKILL.md          # required
└── references/       # optional, one file per branch of the skill
```

`SKILL.md` needs YAML frontmatter with `name` (matching the directory) and `description`:

```markdown
---
name: my-skill
description: What it is, then the triggers — "Use when the user wants…, mentions…". One trigger per distinct branch; synonyms for the same branch are duplication.
---
```

Add the directory to `skills` in [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) and a row to the table in [README.md](README.md). Run `node scripts/validate.mjs` before opening a PR — CI runs the same check.

If a skill is only ever invoked by hand, set `disable-model-invocation: true`; its description then leaves the model's context entirely and costs nothing per turn.

## What we look for

A skill exists to wrangle determinism out of a stochastic system. Predictability — the agent taking the same *process* every run, not producing the same output — is the point.

- **Checkable completion criteria.** Each step ends on a condition the agent can test. Vague criteria invite it to stop early, its attention slipping to *being done*.
- **Progressive disclosure.** Inline what every run needs; push behind a pointer what only some runs reach. A pointer's wording, not its target, decides how reliably the agent follows it.
- **Single source of truth.** One authoritative place per meaning, so changing behaviour is a one-place edit. Repeating a rule also inflates its apparent importance.
- **No no-ops.** Test every sentence: does it change behaviour versus the default? "Be thorough" usually doesn't. Delete rather than reword.
- **Prompt the positive.** *Don't think of an elephant* names the elephant. State the target behaviour; keep prohibitions only as hard guardrails, paired with what to do instead.

## Attribution

We publish skills we wrote. If a skill builds on someone else's material, say so in `SKILL.md` and add an entry to [NOTICE](NOTICE) with the source and its licence. Don't open a PR that re-hosts another author's skill — point people at their repo instead.
