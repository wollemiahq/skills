# C++-specific advice

## `absl::flat_hash_map` / `flat_hash_set`

[Abseil hash tables](https://abseil.io/docs/cpp/guides/container) usually out-perform `std::map` and `std::unordered_map`. Swapping a `__gnu_cxx::hash_map` for `absl::flat_hash_map` in a language-code lookup:

```
name               old time/op  new time/op  delta
BM_CodeToLanguage  19.4ns ± 1%  10.2ns ± 3%  -47.47%
```

(Older changes in the same spirit used `dense_hash_map`, which predates `flat_hash_map` — write new code with `absl::flat_hash_map`.)

## `absl::btree_map` / `absl::btree_set`

Multiple entries per tree node. Versus ordered standard-library containers: less child-pointer overhead, and entries stored consecutively within a node, so much better cache efficiency. A heavily used work-queue moved from `std::set<WorklistItem>` to `absl::btree_set<WorklistItem>`.

## `util::bitmap::InlinedBitVector`

Stores short bit-vectors inline — often better than `std::vector<bool>` or other bitmap types. It also offers bit-scan operations, so iteration skips unset entries entirely:

```c++
// before                                  // after
vector<bool> live_reads(nreads);           util::bitmap::InlinedBitVector<4096> live_reads(nreads);
for (int r = 0; r < nreads; r++)           for (size_t r = 0; live_reads.FindNextSetBit(&r); r++)
  if (live_reads[r]) ...                     ...
```

## `absl::InlinedVector`

Stores a configurable number of elements inline: better cache efficiency for small vectors and no backing-store allocation at all when the count stays under the bound. E.g. `absl::InlinedVector<InstructionRecord, 2>` in place of `std::vector<InstructionRecord>`.

## `gtl::vector32`

A vector type supporting only sizes that fit in 32 bits. A single type change on one Spanner field (`std::vector<FamilyId>` → `gtl::vector32<FamilyId>`, exposed as `absl::Span<const FamilyId>`) saved **~8 TiB of memory**.

## `gtl::small_map`

An inline array up to a threshold, upgrading automatically to a user-specified map type when it runs out of space: `gtl::small_map<gtl::flat_hash_map<int, TFLiteContext*>>`.

## `gtl::small_ordered_set`

The same idea for associative containers (`std::set`, `absl::btree_multiset`): a fixed array first, reverting to the set when full. For sets that are typically small this is considerably faster than a `set` (which is optimized for large data sets), shrinking cache footprint and shortening critical sections — e.g. `gtl::small_ordered_set<std::set<ParsedRtpTransport*>, 10>` for a listener set.

## `gtl::intrusive_list`

A doubly-linked list with the link pointers embedded in the elements. Saves one cache line plus an indirection per element versus `std::list<T*>`. Used to track in-flight requests where a `std::set<int64>` had been.

## Limit `absl::Status` and `absl::StatusOr` usage

Both are fairly efficient but have non-zero cost even on the success path. Avoid them in hot routines that need no meaningful error detail — or that never fail.

- `StatusOr<int64> RoundUpToAlignment(int64)` became a plain `int64` with the preconditions moved to `DCHECK`s and documented as REQUIRES.
- `ShapeUtil::ForEachIndexNoStatus` was added alongside `ForEachIndex`, taking a visitor returning `bool` instead of `StatusOr<bool>` — the latter costs an expensive destructor **per element iterated**.
- `TF_CHECK_OK` avoided constructing an `Ok` object just to test `ok()` (see [`code-size.md`](code-size.md#trim-commonly-inlined-code)).
- Removing `StatusOr` from an RPC hot path eliminated a **14% CPU regression** in RPC benchmarks. The replacement returns a plain enum plus an out-parameter:
  ```c++
  enum class Result { kSuccess, kNoRootScopedData, kNoPrivacyContext, ... };
  Result GetRawPrivacyContext(const CensusHandle& h, PrivacyContext* privacy_context);
  ```

## Bulk operations

Handling many items per operation is covered in [`api-design.md`](api-design.md#bulk-at-the-implementation-level) — Swiss-table SIMD group matching, wide store-and-fix-up encoding, chunked Reed-Solomon, and GroupVarInt.
