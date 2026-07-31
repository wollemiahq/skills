# Code quality review

Correctness and safety belong to [`adversarial-review.md`](adversarial-review.md). The question here is what the change costs to live with.

Hunt **accidental complexity** — complexity this PR added that the problem did not require. Be ambitious. Local cleanup is table stakes; the valuable findings are reframes that delete a concept, branch, mode, layer, or helper outright.

## Inputs

Read the diff from the PR base to `HEAD`, the PR title and body, the surrounding code, and the repo instructions that apply to the changed files. Follow the repo's `AGENTS.md`, `CLAUDE.md`, and local conventions when judging what is canonical and in the right layer.

Passing tests say nothing about structure — a regression can be fully green.

## What to hunt, and what to propose

Each smell pairs with the remedy that deletes it rather than rearranging it.

| Smell in the diff | Remedy to propose |
| --- | --- |
| A reframe would remove concepts, branches, or helper layers | Reframe the state model so the conditionals disappear; delete the layer of indirection |
| Special-case flags, nullable modes, one-off branches, ad-hoc conditionals bolted into unrelated flows | Make the special case the default flow, or replace the chain with an explicit typed model or dispatcher |
| A file or component crossed a healthy size boundary because of this PR | Split it into focused modules |
| Feature-specific logic leaked into a shared module, or details crossed a boundary | Move ownership to the module that already owns the concept |
| Thin wrappers, identity abstractions, or generic handling hiding a simple data shape | Delete the wrapper and let the shape show |
| Casts, `any`, `unknown`, or needless optionality obscuring an invariant | Make the type boundary explicit |
| Copy-pasted logic, duplicate branches, or a re-implemented canonical helper | Reuse the canonical helper, or extract one focused helper |
| Logic living outside its canonical package, service, or layer | Move it, and separate orchestration from business logic |
| Independent work run sequentially | Parallelize it where that also makes the orchestration clearer |
| Partial-update flows that leave state hard to reason about | Restructure the related updates so no partial state survives |

## Reporting

Prefer few high-conviction findings to a long list. Each one names the structural problem, points to a file and line, says why the shape is harder to reason about, and proposes a concrete restructuring.

Structural findings rarely carry a failure scenario, so triage will usually file them as advisories for a human rather than fixing them in the loop. Report them anyway — the summary is where they land.

Return findings to the triage step; keep them out of the PR comments.

When the structure holds up, say so and name what you examined.
