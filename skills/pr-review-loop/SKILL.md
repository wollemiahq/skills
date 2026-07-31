---
name: pr-review-loop
description: Run a bounded review-and-fix loop on a pull request, fixing only findings that carry a failure scenario. Use when the user asks for a PR review loop, asks to keep reviewing and fixing until clean, or right after a pull request has been created.
---

# PR Review Loop

Review and fix the open pull request on the current branch, up to 4 iterations. A finding drives the loop only when it carries a **failure scenario**; everything else is recorded as an advisory for a human.

## Prerequisites

1. Confirm the branch has an open PR with `gh pr view --json number,url,headRefOid`.
2. If no PR exists, create one only when the user asked for that; otherwise ask before continuing.
3. Read repo instructions that apply to the changed files before reviewing or editing.

## Loop

For each iteration, announce `Iteration N/4`.

### 1. Review

Review the diff from the PR base to `HEAD`, running independent reviewers in parallel when subagents are available. Reviewer output feeds triage; post it to the PR only when the user asks.

Re-run the reviewers every iteration — a self-read of the delta is not a review. Give each one the commits added since the last round, what changed and why, and the findings already dropped or filed as advisories with their reasons, so they don't relitigate. Ask for the full base-to-`HEAD` diff re-reviewed with attention to the new delta, since fixes carry their own bugs.

Run both of these against every changed file:

- [`references/adversarial-review.md`](references/adversarial-review.md) — correctness, authorization, security, reliability, tests.
- [`references/code-quality-review.md`](references/code-quality-review.md) — structure, abstraction, layering, simplification.

Then add stack-specific review for the languages and frameworks the diff actually touches:

1. **Use what is already installed.** A matching skill in this session or repo is the first choice — React/Next.js diffs want `vercel-react-best-practices`; Convex diffs want `convex-rules` plus the repo's generated `convex/_generated/ai/guidelines.md`.
2. **Otherwise search.** `npx skills find <language or framework> </dev/null` — the redirect stops it waiting on the interactive picker. Results carry install counts, sorted high to low.
3. **Judge by installs.** Take a skill only when it clears roughly 10K installs. That bar admits established publishers and keeps out one-off personal repos, which are unvetted and often abandoned.
4. **Apply it without installing.** `npx skills use <owner>/<repo>@<skill> </dev/null` prints its guidance for this run and changes nothing on disk. Installing it permanently alters the user's setup — ask before doing that, and only when they want it kept.
5. **When nothing clears the bar**, say so and review that stack on general principles.

### 2. External Feedback

Collect PR comments, reviews, and check results newer than the last commit, letting any running review bot finish before reading its silence as approval.

Follow [`references/external-feedback.md`](references/external-feedback.md) for this step. Its timestamp filtering and bot-polling rules are exact; improvising them silently drops feedback that lands a few minutes late.

### 3. Triage

A finding drives the loop only when you can write its **failure scenario** — a concrete input or state, and the wrong outcome it produces in code this PR changed:

> An account with no active membership hits the admin route and gets a 500 instead of a 403.

A repo instruction the diff breaks, cited by file and line, counts as a scenario. A reviewer's own severity label does not — that is a claim made without sight of the whole PR. Apply the test yourself.

Everything else is an **advisory**: possibly real, but undemonstrated. Advisories go in the final summary rather than driving the loop. Drop findings that are stale, relitigate a previous rejection, or guard an impossible state.

Judge the fix as well as the finding. If they propose a fix, don't take it at face value; there's often a **KISS** solution that avoids overcomplicating things. A **contrived** scenario, or a remedy that costs more to live with than the problem does, is better recorded than applied.

```markdown
| # | Source | Finding | Failure scenario — blank means advisory |
|---|--------|---------|------------------------------------------|
```

### 4. Fix

Fix what has a scenario. Advisories wait for a human.

A review loop ships **patches**, not designs. If a finding needs a new mechanism, or reaches beyond the surface of this PR, bring it up with the human as a new PR.

1. Make the smallest change that removes the scenario. Complexity added here is complexity the next round reviews and someone later maintains.
2. Add or update tests when the issue changes behavior.
3. Run focused tests first.
4. Run touched-file lint/format checks.
5. Run broader verification when practical; report unrelated failures or skipped checks.
6. Commit with `Address review feedback (iteration N)` or a more specific message.
7. Push the branch.

Leave unrelated user changes alone. If a test is wrong, restart that issue's red/green loop rather than editing the test to pass.

### 5. Exit

- Stop when an iteration produces no scenarios, and report `All clean -- N advisories recorded`. An iteration counts as clean only once the reviewers have re-run against the current `HEAD` and every review-bot check for that commit has completed.
- When a round's findings are mostly regressions in the previous round's fix, the fix is the problem, not the code it touched. Revert it, record what it was trying to solve, and hand it over.
- If iteration 4 still has scenarios, fix them, verify, commit, push, then stop and report `Max iterations reached`.
- Close any subagents opened for the loop.

## Final Summary

- PR URL and final head commit.
- Total iterations run.
- Issues fixed, by iteration.
- Advisories, in one list — the handover a human would otherwise re-derive.
- Dropped findings with reasons.
- Verification commands and results.
- External check caveats, including unavailable services or quota failures.

Created by the team behind [Cavuno](https://cavuno.com) and [Himalayas](https://himalayas.app).
