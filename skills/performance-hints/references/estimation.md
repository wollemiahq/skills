# Estimation

## Why "write it simply and profile later" often fails

1. Disregarding performance across a large system produces a **flat profile** — no obvious hotspots, because performance is lost everywhere. There is no obvious place to start.
2. In a library, the people who hit the performance problem are the people least able to fix it: they must understand someone else's code and negotiate with another team about whether the fix matters.
3. Significant changes get harder once a system is in heavy use.
4. Without an estimate you cannot tell whether a cheap fix exists, so you reach for expensive ones instead — over-replication, severe overprovisioning.

The rule that follows: when writing code, choose the faster alternative if it does not significantly hurt readability or complexity.

## Triage: what kind of code is this?

- **Test code** — worry mostly about asymptotic complexity of algorithms and data structures. (Cycle time matters too: avoid slow tests.)
- **Application code** — usually easy to judge. Deciding "initialization/setup" vs "on the hot path of every request" is often enough.
- **Library code used by many applications** — you cannot tell how sensitive it will become, so this is where the cheap non-local-complexity techniques matter most. Example: if a vector usually holds few elements, use `absl::InlinedVector` rather than `std::vector` from the start. The code is higher performance from day one, and the next thing to focus on is easier to find in a profile.

## Back-of-the-envelope calculation

Rough estimates discard bad alternatives before anyone implements them.

1. Estimate how many low-level operations of each kind are required — disk seeks, network round-trips, bytes transmitted, comparisons.
2. Multiply each kind by its rough cost and sum.
3. That gives **cost** (resource usage). For **latency** with concurrency, some costs overlap and need slightly more analysis.

```
L1 cache reference                             0.5 ns
L2 cache reference                             3 ns
Branch mispredict                              5 ns
Mutex lock/unlock (uncontended)               15 ns
Main memory reference                         50 ns
Compress 1K bytes with Snappy              1,000 ns
Read 4KB from SSD                         20,000 ns
Round trip within same datacenter         50,000 ns
Read 1MB sequentially from memory         64,000 ns
Read 1MB over 100 Gbps network           100,000 ns
Read 1MB from SSD                      1,000,000 ns
Disk seek                              5,000,000 ns
Read 1MB sequentially from disk       10,000,000 ns
Send packet CA->Netherlands->CA      150,000,000 ns
```

Also track costs for the higher-level operations of your own system — a point read from your SQL database, a call to a cloud service, rendering a simple HTML page. **Without those numbers you cannot do back-of-the-envelope calculations at all.**

## Worked example: quicksort a billion 4-byte numbers

Quicksort makes ~log(N) passes over an array of size N; each pass streams the array through the processor and compares each element to a pivot.

1. **Memory bandwidth** — 4 GB of data at ~16 GB/s per core is ~0.25s per pass; N ≈ 2³⁰ so ~30 passes ⇒ ~7.5s of memory transfer.
2. **Branch mispredictions** — N·log(N) ≈ 30 billion comparisons; assume half mispredict ⇒ 15 billion × 5 ns ⇒ 75s. (Correctly predicted branches are assumed free.)
3. Total ≈ **82.5 seconds**, dominated by mispredictions.

Refinement for caches (not needed here, but illustrative): with a 32 MB L3 holding 2²³ numbers, the last 22 passes run out of L3, cutting memory transfer from 7.5s to 2.5s.

## Worked example: web page with 30 image thumbnails

Original images on disk, ~1 MB each.

1. **Serial from disk** — one seek (5 ms) + one transfer (10 ms) per image ⇒ 30 × 15 ms = **450 ms**.
2. **Parallel across K disks** — same resource cost, latency drops roughly K-fold (ignoring variance from uneven spread). On a distributed filesystem with hundreds of disks: **~15 ms**.
3. **Single SSD, serial** — 20 µs seek + ~1 ms transfer per image ⇒ **~30 ms**.
