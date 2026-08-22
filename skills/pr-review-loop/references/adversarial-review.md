# Adversarial review

Try to break the pull request before production does. Assume the change is wrong, unsafe, incomplete, or off-intent until the diff and surrounding code prove otherwise.

## Inputs

Read the diff from the PR base to `HEAD`, the PR title and body, the surrounding code, and the repo instructions that apply to the changed files. Judge the implementation against the author's stated intent, not just against the changed lines.

## Attack axes

For each axis, construct the concrete input, state, sequence, tenant, or runtime condition that makes the change fail. An axis you cannot break is an axis you report nothing on.

1. **Correctness vs intent** — shortcuts, half-implementations, stubs, TODO branches, dropped edge cases, wrong conditionals, mishandled empty values, and error paths that swallow or mis-propagate failures.
2. **Authorization** — the path by which one user, tenant, or organisation reads or writes another's data, or reaches an endpoint or action unauthenticated: a missing scope check, a client-supplied identifier the server trusts, a mutation that never re-checks ownership.
3. **Data layer** — full scans where an index is required, missing or wrong indexes, N+1 reads, unbounded reads, races between concurrent writes, non-idempotent mutations, schema/validator mismatches. Read the data layer's own guidelines first where it ships them; Convex generates them at `convex/_generated/ai/guidelines.md`.
4. **Resource amplification** — one call does the correct amount of work, but the code runs that call too many times. Examples: a scan inside a loop, one scheduled task per row, a cascade that repeats the same work for each item.

   Find every loop, cascade, migration, backfill, and scheduled fan-out that the diff adds or changes. For each one, calculate this and put the numbers in the finding:

   `rows read per call  ×  calls per run  ×  runs per day  =  work per day`

   Give the result in the unit the platform charges for. Examples: bytes read, function calls, requests, compute seconds.

   Report a finding if any one of these is true:
   - One of the three numbers has no upper limit.
   - The code reads the same table more than one time to complete one logical operation.
   - The work per day is large.

   Two arguments look correct but do not close this finding:
   - *"The scan is necessary."* Often true, and not the point. The problem is the number of repeats, not the scan. One pass over the whole batch usually replaces N separate passes.
   - *"One call is cheap."* Also often true today. The table grows, so use the expected future size of the table in the calculation, not the size today. This class of defect usually costs nothing on the day it merges.

   Some platforms charge for these units directly. Convex charges for database bandwidth and for function calls. Most serverless platforms and managed databases charge in a similar way. On these platforms, code that multiplies the work is a cost defect, even when the code is fast and correct.
5. **Framework and types** — client/server boundary violations, invalid server-action exports, mutations bypassing the repo's action wrapper, forms ignoring repo conventions, hidden type holes, `any`, orphaned code, dead branches.
6. **Input and secrets** — unvalidated input reaching a sink, leaked secrets, webhook double-processing, billing and order-of-operations failures.
7. **Reliability** — timeout, retry, partial-write, migration/backfill, replay, duplicate, and recovery sequences that leave bad or orphaned state.
8. **Tests** — whether the tests actually defend the new behaviour. Missing tests, assertions that would still pass if the behaviour broke, untested edge cases that matter to the change.

## Reporting

Report only what is mechanically demonstrable from code or verified runtime evidence. Each finding carries:

- **Trigger** — the concrete input, tenant, state, or sequence.
- **Path** — the file/line execution path, step by step.
- **Wrong outcome** — the specific bad result.
- **Confidence** — one sentence on what is proven and what remains uncertain.

Title each finding with the failure, not the pattern — `Cross-tenant read: team board query trusts client accountId - src/server/board.ts:42`, not `Missing auth check`.

Return findings to the triage step; keep them out of the PR comments.

When nothing breaks, say so and name the axes you attempted — otherwise an empty report and a shallow pass read identically.
