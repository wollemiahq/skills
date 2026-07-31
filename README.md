# Cavuno skills

Agent skills we actually run, published as we sharpen them.

Created by the team behind [Cavuno](https://cavuno.com) and [Himalayas](https://himalayas.app). We build with coding agents every day, and this repo is where the skills we wrote ourselves get published — not a re-hosting of anyone else's set. It starts small on purpose: a skill only lands here once it has earned its keep in real work.

Skills are plain markdown. They work with Claude Code, Codex, Cursor, opencode, and anything else that reads `SKILL.md`.

## Installation

Two routes, two philosophies. The **Claude Code plugin** installs the set as a managed bundle that updates when we ship. **[skills.sh](https://skills.sh/wollemiahq/skills)** copies editable files into your project so you can hack on them. Pick one — installing both leaves you with every skill twice.

<details open>
<summary><strong>Claude Code</strong></summary>

```
/plugin marketplace add wollemiahq/skills
/plugin install cavuno-skills@cavuno
```

</details>

<details>
<summary><strong>Codex, Cursor, opencode, and other agents</strong></summary>

```bash
npx skills@latest add wollemiahq/skills
```

The installer lets you pick which skills to take and which agents to install them on.

To install only the performance skill:

```bash
npx skills@latest add wollemiahq/skills --skill optimize-performance
```

</details>

## The skills

| Skill | What it does |
| --- | --- |
| [`optimize-performance`](skills/optimize-performance) | Treats performance work as a causal experiment: define the contract, localize the dominant cost, change one mechanism, and verify the result. Covers latency, throughput, CPU, memory, allocations, code size, and contention, with historical cost data and worked examples clearly qualified. Adapted from Jeff Dean & Sanjay Ghemawat's [Performance Hints](https://abseil.io/fast/hints.html). |
| [`pr-review-loop`](skills/pr-review-loop) | Reviews and fixes a pull request until it stops finding real bugs. A finding drives another iteration only when the agent can write its **failure scenario** — a concrete input and the wrong outcome it produces. Everything else is filed as an advisory for a human, which is what stops the loop grinding through its iteration budget polishing things nobody asked it to touch. Bundles an adversarial reviewer and a code-quality reviewer; discovers language-specific reviewers through `npx skills find`. |

More are coming as we generalise them out of our own repo. If you want a say in which, open an issue.

## What makes a skill good here

A skill exists to get determinism out of a stochastic system — the agent taking the same *process* every run. Which means:

- **Steps end on a checkable criterion.** "Every applicable category considered" beats "consider the categories".
- **Progressive disclosure.** `SKILL.md` stays legible; detail lives in `references/` behind pointers, loaded only when the pointer fires.
- **No no-ops.** If the model already does it by default, saying so costs tokens and buys nothing.
- **Prompt the positive.** Naming the banned behaviour makes it more available, not less.

See [CONTRIBUTING.md](CONTRIBUTING.md) to add one.

## Made by the team behind Cavuno and Himalayas

[Cavuno](https://cavuno.com) is job board and careers page software, and [Himalayas](https://himalayas.app) helps people find remote jobs. If you build with agents, the Cavuno pieces you can point one at:

- [cavuno-mcp](https://github.com/wollemiahq/cavuno-mcp) — connect Claude, Cursor, Codex and other MCP clients to your board
- [cavuno-sdk](https://github.com/wollemiahq/cavuno-sdk) — TypeScript SDK for custom boards and careers pages
- [cavuno-cli](https://github.com/wollemiahq/cavuno-cli) — manage your board from the command line
- [cavuno-api](https://github.com/wollemiahq/cavuno-api) — the OpenAPI contract

## Licence

The repository is MIT-licensed — see [LICENSE](LICENSE). Individual skills may carry a more specific licence in their directory. Third-party material we build on is credited in [NOTICE](NOTICE).
