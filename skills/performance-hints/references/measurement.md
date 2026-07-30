# Measurement

Being able to measure effectively is the number one tool for performance work. Measure or estimate the benefit before making improvements, and certainly before trading away simplicity for speed.

Aside: profiling code you are unfamiliar with is a good way to learn a codebase. Reading the heavily-involved routines in the dynamic call graph gives a high-level sense of "what happens" when the program runs, which builds confidence to change it.

## Tools

- [pprof](https://github.com/google/pprof/blob/main/doc/README.md) — reach for it first. Good high-level information, easy to use locally and in production. Its [annotated source view](https://github.com/google/pprof/blob/main/doc/README.md#annotated-source-code) interleaves source, disassembly and performance data.
- [perf](https://perf.wiki.kernel.org/index.php/Main_Page) — more detailed insight.
- ML profilers (e.g. xprof/TensorBoard) for machine learning work.

## Tips

- Build production binaries with appropriate debugging information *and* optimization flags.
- Write a **microbenchmark** covering the code you are improving. It shortens turnaround, verifies the impact, and guards against future regressions. Libraries: [google/benchmark](https://github.com/google/benchmark/blob/main/README.md) (C++), [testing](https://pkg.go.dev/testing#hdr-Benchmarks) (Go), [JMH](https://github.com/openjdk/jmh) (Java).
- Microbenchmarks have pitfalls that make them non-representative of full-system performance — confirm big wins at system level.
- Have the benchmark library emit **hardware performance counter** readings, both for precision and for insight into program behaviour.
- **Lock contention can artificially lower CPU usage** — low CPU is not proof of efficiency. Some mutex implementations support contention profiling.
- Gather allocation/heap profiles, not just CPU profiles.

## When the profile is flat

A flat profile — no obvious big contributor — usually means the low-hanging fruit is gone. Tactics:

- **Don't discount many small optimizations.** Twenty separate 1% improvements in a subsystem are often achievable and add up. This kind of work depends on stable, high-quality microbenchmarks.
- **Find loops near the top of call stacks** (a flame graph view helps). Restructuring the loop, or what it calls, can pay off. One example: code that built a graph incrementally by looping over nodes and edges was changed to build it in one shot from the whole input, removing per-edge internal checks.
- **Look higher up the stack for structural changes** instead of micro-optimizing. See [`algorithms.md`](algorithms.md).
- **Look for overly general code** and replace it with a customized or lower-level implementation — e.g. a regular expression match where a prefix match would do.
- **Attack allocation count.** Get an allocation profile and pick away at the biggest contributors. Two effects: less time in the allocator (and GC), and fewer cache misses, since in a long-running program using tcmalloc every allocation tends to land on a different cache line.
- **Gather other profile types**, especially hardware-performance-counter profiles, which can point at functions with high cache-miss rates.
