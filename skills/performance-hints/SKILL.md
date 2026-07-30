---
name: performance-hints
description: Catalogue of performance techniques from Dean & Ghemawat's "Performance Hints". Use when making code faster, smaller, or leaner — optimizing a hot path, reading a profile or a flat one, estimating a design's cost back-of-the-envelope, cutting allocations or cache misses, reducing lock contention, shrinking binary size, or tuning protobuf and C++ container choices.
---

# Performance hints

Techniques for the **critical 3%**. Knuth's line is quoted out of context: the full version is *"we should forget about small efficiencies, say about 97% of the time: premature optimization is the root of all evil. Yet we should not pass up our opportunities in that critical 3%."* This skill is about that 3%.

Source: Jeffrey Dean & Sanjay Ghemawat, [Performance Hints](https://abseil.io/fast/hints.html), 2025.

Examples throughout are C++ and Google-flavored (`absl::`, `gtl::`, protobuf). The principles are language-agnostic; the named types are not. When the code at hand is not C++, name the equivalent construct in that language before recommending anything.

## 1. Estimate before writing

Decide how much performance matters *here*, and get a number for each alternative you are choosing between.

Read [`references/estimation.md`](references/estimation.md) — why "profile later" often fails, the test/application/library triage, the back-of-the-envelope method, and the latency table.

Done when you can say which of the three kinds of code this is, and — if you are picking between designs — you have a rough cost figure for each.

## 2. Measure

Get a profile or a microbenchmark that names the cost before changing anything.

Read [`references/measurement.md`](references/measurement.md) — profiling tools and tips, and the playbook for a **flat profile** (no obvious hotspot).

Done when you can point at the specific operation that dominates, or you have established the profile is flat and picked a flat-profile tactic.

## 3. Apply the techniques

Route by where the cost actually is. Walk every row that is plausibly in play — not just the first one that matches.

| The cost is… | Read |
| --- | --- |
| the algorithm — O(N²), exponential, repeated scans, a weak hash | [`references/algorithms.md`](references/algorithms.md) |
| the API shape — per-item calls, copies at the boundary, needless thread-safety | [`references/api-design.md`](references/api-design.md) |
| cache misses and memory footprint | [`references/memory-representation.md`](references/memory-representation.md) |
| the allocator, GC pressure, or copying | [`references/allocations.md`](references/allocations.md) |
| work that never needed doing | [`references/avoid-work.md`](references/avoid-work.md) |
| binary size, icache pressure, build time | [`references/code-size.md`](references/code-size.md) |
| lock contention, idle cores, false sharing | [`references/concurrency.md`](references/concurrency.md) |
| protobuf parsing, serializing, or footprint | [`references/protobuf.md`](references/protobuf.md) |
| a C++ container or `Status` choice | [`references/cpp-containers.md`](references/cpp-containers.md) |

For the mindset of attacking a bottleneck with many techniques at once, read [`references/case-studies.md`](references/case-studies.md).

Done when every plausible row has been read and each of its techniques explicitly accepted or rejected for this code — a rejection is a finished decision, a skipped row is not.

## 4. Verify

Re-run the same benchmark and report before/after numbers. A change with no measured delta is not an improvement, and several techniques here (bit-packing, `alignas`, arenas, `Cord`, inlining) can make things worse.

Done when you have paired before/after numbers from one benchmark, and the microbenchmark has been sanity-checked against whole-system behaviour if the change is going to production.

## Design rule

When writing new code, prefer the faster alternative wherever it does not significantly hurt readability or complexity. Organize code so these changes can later be made inside an encapsulation boundary without disturbing callers — which is easier when modules are deep (significant functionality behind a narrow interface).

## Further reading

- [Optimizing software in C++](https://www.agner.org/optimize/optimizing_cpp.pdf) — Agner Fog. Low-level techniques.
- [Understanding Software Dynamics](https://www.oreilly.com/library/view/understanding-software-dynamics/9780137589692/) — Richard L. Sites. Diagnosing performance problems.
- [Performance tips of the week](https://abseil.io/fast/) and [Performance Matters](https://travisdowns.github.io/).
- [Daniel Lemire's blog](https://lemire.me/blog/) — high-performance implementations of interesting algorithms.
- [Building Software Systems at Google and Lessons Learned](https://www.youtube.com/watch?v=modXC5IWTJI) — a decade of system performance issues.
- *Programming Pearls* / *More Programming Pearls* — Jon Bentley. Algorithms to simple efficient implementations.
- *Hacker's Delight* — Henry S. Warren. Bit-level and arithmetic algorithms.
- *Computer Architecture: A Quantitative Approach* — Hennessy & Patterson. Caches, branch predictors, TLBs.
