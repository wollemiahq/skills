# Wollemia Skills

Agent skills we actually run, published as we sharpen them.

We build [Cavuno](https://cavuno.com) with coding agents every day. This repo is where the skills we wrote ourselves get published — not a re-hosting of anyone else's set. It starts small on purpose: a skill only lands here once it has earned its keep in real work.

Skills are plain markdown. They work with Claude Code, Codex, Cursor, opencode, and anything else that reads `SKILL.md`.

## Installation

Two routes, two philosophies. The **Claude Code plugin** installs the set as a managed bundle that updates when we ship. **[skills.sh](https://skills.sh/wollemiahq/skills)** copies editable files into your project so you can hack on them. Pick one — installing both leaves you with every skill twice.

<details open>
<summary><strong>Claude Code</strong></summary>

```
/plugin marketplace add wollemiahq/skills
/plugin install wollemia-skills@wollemia
```

</details>

<details>
<summary><strong>Codex, Cursor, opencode, and other agents</strong></summary>

```bash
npx skills@latest add wollemiahq/skills
```

The installer lets you pick which skills to take and which agents to install them on.

</details>

## The skills

| Skill | What it does |
| --- | --- |
| [`performance-hints`](skills/performance-hints) | Makes code faster, smaller, or leaner. A four-step spine — estimate → measure → apply → verify — over a routed catalogue of techniques: fast paths, cache footprint, allocations, lock contention, binary size, protobuf. Distilled from Jeff Dean & Sanjay Ghemawat's [Performance Hints](https://abseil.io/fast/hints.html). |

More are coming as we generalise them out of our own repo. If you want a say in which, open an issue.

## What makes a skill good here

A skill exists to get determinism out of a stochastic system — the agent taking the same *process* every run. Which means:

- **Steps end on a checkable criterion.** "Every applicable category considered" beats "consider the categories".
- **Progressive disclosure.** `SKILL.md` stays legible; detail lives in `references/` behind pointers, loaded only when the pointer fires.
- **No no-ops.** If the model already does it by default, saying so costs tokens and buys nothing.
- **Prompt the positive.** Naming the banned behaviour makes it more available, not less.

See [CONTRIBUTING.md](CONTRIBUTING.md) to add one.

## Licence

MIT — see [LICENSE](LICENSE). Third-party material we build on is credited in [NOTICE](NOTICE).
