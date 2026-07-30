# Avoid unnecessary work

Perhaps the most effective category: don't do the work at all. Specialized paths for common cases, precomputation, deferral, hoisting work into less-frequently executed code.

## Fast paths for common cases

Code is often written to cover all cases when some subset is much simpler and much more common. `vector::push_back` usually has room; the resize branch is rare. Structure code so the common case is fast without badly hurting the rare one.

- **Widen the fast path to cover more of the common case.** A UTF-8 scanner handled ASCII 8 bytes at a time, then fell into the generic state-table routine for the remainder — so an all-ASCII 5-byte string still paid for the slow routine. Adding a trailing single-byte ASCII loop kept it on the fast path.
- **Simplify the fast path.** `InlinedVector::Resize` computed three span variables and set up allocation/construction transactions before branching. Rewritten to branch first (`new_size <= size`, `new_size <= capacity`, else grow) and do only the work each branch needs.
- **Special-case the common shapes.** Tensor shape construction fell into a generic `AddDim` loop; the rewrite checks whether every dimension fits in 16 bits and then switch-cases ranks 1–4 with straight-line code.
- **Sometimes a *narrower* fast path is faster.** A varint parser inlined both the 1-byte and 2-byte cases; cutting it to just the 1-byte case reduced inlined code size and icache pressure, improving performance. (The slow-path loops start one index earlier to compensate.)
- **Track a flag so the loop can be skipped entirely.** `RPC_Stats_Measurement::operator+=` looped over `errors[NUM_ERRORS]` every time. Making the array private behind `set_errors()` allowed an `any_errors_set` bool, so the loop runs only when some error is non-zero.
- **Cheap filter before the expensive test.** `IsSoftToken` fingerprinted every token and looked it up in a hash set. Adding `bool filter_[256]` — true iff any soft token starts with that byte — turns the common case into one array lookup, with the fingerprinting moved to an out-of-line fallback.

## Precompute expensive information once

- **Precompute properties as bits.** TensorFlow's `NodeItem` gained `is_enter`, `is_exit`, `is_control_trigger`, `is_sink` and a combined `is_enter_exit_or_next_iter` as `: 1` bitfields, so the executor's inner branch is a single bit test with a fast path for the normal case, instead of repeated `IsEnter(node)`/`IsExit(node)` calls.
- **Precompute a lookup table.** A trigram classifier called `Prob(log_probs[cls])` per class per trigram; hoisting a 256-element `fast_prob[]` table (the log-prob type is one byte) turns each call into an array index.

General rule: **check for malformed inputs at module boundaries** instead of repeating checks internally.

## Move expensive computations outside loops

Hoist bound computations and repeated data-pointer lookups:

```c++
// before
for (int64 i = 0; i < src_shape.dimensions(dimension_numbers.front()); ++i) {
// after
int64 dim_front = src_shape.dimensions(dimension_numbers.front());
const uint8* src_buffer_data = src_buffer.data();
uint8* dst_buffer_data = dst_buffer.data();
for (int64 i = 0; i < dim_front; ++i) {
```

## Defer expensive computation

- **Compute inside the branch that needs it.** `GetSubSharding` was called before the `if` that decided whether the result mattered. Moving it inside took that routine from **43 seconds of CPU time to 2 seconds**.
- **Compute stats on demand.** Don't update statistics on every allocation/deallocation; compute them when the far less frequent `Stats()` method is called.
- **Don't preallocate for the worst case.** A query-node pool preallocated 200 nodes; changing the initial size to 10 reduced Google's **web server CPU usage by 7.5%**.
- **Reorder work so later work can be skipped.** An early search system searched a small title/anchor index tier before the full-text tier. Counter-intuitively, searching the *larger* full-text tier first was cheaper: reaching the end of it lets you skip the title/anchor tier entirely (it is a subset), cutting average disk seeks. **19% throughput improvement.**

## Specialize code

A performance-sensitive call site may not need the generality of the general-purpose library.

- **Custom formatting.** A `Histogram` export path built keys with `StringPrintf`. A specialized `FormatNumber` that handles the integer case with `StrAppend`, special-cases infinity, and skips escaping when the format cannot produce a `.`, was **4× as fast as sprintf** — plus hoisting the key prefix and the option booleans out of the loop.
- **Specialize on a call-site constant.** `VLOG(1)`, `VLOG(2)` etc. almost always pass a literal level. Guarding on `__builtin_constant_p(level)` and dispatching to `SlowIsEnabled1`, `SlowIsEnabled2`, … avoids passing an extra integer constant at nearly every call site, saving code space.
- **Detect the degenerate regexp.** A matcher used RE2 for every pattern; adding `MATCH_TYPE_PREFIX` for the regexp suffix `.*` bypasses `RE2::FullMatch` entirely.
- **`StrCat` over `StringPrintf`.** `IPAddress::ToString` used `inet_ntop`, and callers used `StringPrintf("[%s]", ...)`. Formatting the four octets by hand with `StrCat` and using `StrCat` for the brackets and port removed the printf machinery from the path.

## Use caching to avoid repeated work

Cache keyed on a **precomputed fingerprint** so you needn't touch the large value to decide. An op parsed a large `InputOutputMappingProto` on every construction; it now looks up a fingerprint of the serialized proto in a `flat_hash_map<uint64, unique_ptr<ProgramIOMetadata>>` and parses only on a miss.

## Make the compiler's job easier

The compiler must make conservative assumptions across abstraction layers, and may make the wrong speed/size tradeoff. You know more about the system than it does — **but only do this when profiles show an issue**, since compilers usually get it right. Reading the generated assembly for critical routines tells you whether it did.

1. **Avoid function calls in hot functions** — lets the compiler avoid frame setup costs.
2. **Move slow-path code into a separate tail-called function.**
3. **Copy small amounts of data into local variables** before heavy use — lets the compiler assume no aliasing, improving auto-vectorization and register allocation.
4. **Hand-unroll very hot loops.**

Examples:

- `ShapeUtil::ForEachState` stored three `absl::Span` members; storing raw `const int64_t* const` pointers to the underlying arrays (and defaulting the destructor inline) sped it up.
- CRC computation processed 4 bytes per iteration; a `STEP` macro repeated 4× processes 16 bytes at a time, with the 4-at-a-time loop kept for the remainder.
- Spanner key parsing replaced `memchr` with a hand-unrolled scan checking four characters per iteration, run **backwards** from the end — the leading directory name is long and contains no `#` separators.
- `ABSL_LOG(FATAL)` in a `default:` case forced frame setup in an always-inline function; `ABSL_DCHECK(false)` removed it.

## Reduce stats collection costs

Balance the value of stats against their cost. Stats that aren't useful can be dropped outright — removing two `MinuteTenMinuteHourStat` counters was part of taking alarm setup from **771 ns to 271 ns**.

Otherwise, **sample**. Maintain stats for a sample of requests/records/users (as tcmalloc allocation tracking and Dapper do). One leaf server avoided touching 39 histograms on most requests by taking a lock only for sampled requests.

And **reduce the sampling rate**. Google Meet's per-packet performance measurement called `base::ThreadCPUUsage()` (>400 ns, ~30× `absl::Now`) on 1 in 10 closures; moving to 1 in 32, using a power-of-two modulus for a cheaper sampling decision, and recording execution time only for sampled events took `BM_PacketOverhead` from **224 ns to 85 ns (+62%)**.

## Avoid logging on hot code paths

Logging statements cost even when nothing is logged — `ABSL_VLOG` needs at least a load and a comparison — and their presence can inhibit compiler optimizations. Consider dropping logging from hot paths entirely (the guts of a memory allocator had its `VLOG(6)` calls removed).

Where the logging must stay, **hoist the enabled check**:

```c++
const bool vlog_3 = DEBUG_MODE ? VLOG_IS_ON(3) : false;
for (int j = 0; ...) { for (int i = 0; ...) { if (vlog_3) { ... } } }
```

That gave **8–10%** across an image-similarity benchmark. The same technique extends across call boundaries: compute `const bool vlog_1 = VLOG_IS_ON(1);` once and thread it through the helper routines as a parameter.
