# API considerations

Many techniques in this skill change data structures and function signatures, which disrupts callers. Organize code so the improvement can be made **inside an encapsulation boundary** without touching public interfaces — easier when [modules are deep](https://web.stanford.edu/~ouster/cgi-bin/book.php) (significant functionality behind a narrow interface).

Widely used APIs come under heavy pressure to add features. Be careful: each new feature constrains future implementations and taxes users who don't need it. Example: many C++ standard-library containers promise iterator stability, which in typical implementations significantly increases allocation counts even though most users don't need it.

Weigh the performance benefit against the usability cost of each change below.

## Bulk APIs

Provide bulk operations to amortize expensive API-boundary crossings, or to unlock a better algorithm.

- **Amortize the crossing.** `MemoryManager::LookupMany(absl::Span<const LookupKey> keys, absl::Span<Tensor> tensors)` replaced per-key `Lookup`. The bulk variant also *simplified* the signature — callers only needed to know whether all keys were found, so it returns `bool` instead of a `StatusOr`.
- **Amortize locking.** `ObjectStore::DeleteRefs(absl::Span<const Ref>)` takes the mutex once and loops inside, instead of one lock per `DeleteRef`.
- **Unlock a better algorithm.** Bulk heap initialization via [Floyd's heap construction](https://en.wikipedia.org/wiki/Heapsort#Variations) is O(N); inserting one element at a time is O(N log N).

When callers are hard to migrate, **use the bulk API internally and cache**: a lexicon lookup that had to decode a whole block of K entries per call now decodes the block once into a cache and serves future lookups from it.

## Bulk at the implementation level

The same idea below the API: handle many items per operation rather than one.

- `absl::flat_hash_map` compares one hash byte for a whole group of keys with a single SIMD instruction ([Swiss Table design notes](https://abseil.io/about/design/swisstables)):
  ```c++
  // Returns a bitmask representing the positions of slots that match hash.
  BitMask<uint32_t> Match(h2_t hash) const {
    auto ctrl = _mm_loadu_si128(reinterpret_cast<const __m128i*>(pos));
    auto match = _mm_set1_epi8(hash);
    return BitMask<uint32_t>(_mm_movemask_epi8(_mm_cmpeq_epi8(match, ctrl)));
  }
  ```
- **Do one wide operation and fix up**, rather than deciding per byte. Ordered-code integer encoding replaced a byte-at-a-time shift loop with a single `BigEndian::Store` plus a computed length.
- **Process interleaved buffers in chunks** — Reed-Solomon encoding improved 10–40% by handling multiple interleaved input buffers in chunks.
- **Decode groups.** The [GroupVarInt format](https://static.googleusercontent.com/media/research.google.com/en//people/jeff/WSDM09-keynote.pdf) encodes/decodes 4 variable-length integers at a time in 5–17 bytes; decoding a group takes ~⅓ the time of decoding 4 individually varint-encoded integers. Similarly, encoding four k-bit numbers at a time lets the code assume byte alignment (even k) or nibble alignment (odd k), since K is known at compile time.

## View types

Prefer view types for function arguments unless ownership is being transferred — `std::string_view`, `absl::Span<T>`, `absl::FunctionRef<R(Args...)>`. They reduce copying and let each caller pick its own container type (one uses `std::vector`, another `absl::InlinedVector`).

## Pre-allocated / pre-computed arguments

For frequently called routines, let higher-level callers pass in a data structure they own, or information they already have, so the low-level routine need not allocate a temporary or recompute.

```c++
// before
static void RecordRPC(const Name& name, const RPC_Stats_Measurement& m);
// after — the caller already had `now`
static void RecordRPC(const Name& name, const RPC_Stats_Measurement& m, WallTime now);
```

## Thread-compatible vs thread-safe types

A type is **thread-compatible** (synchronized externally) or **thread-safe** (synchronized internally). Most generally-used types should be thread-compatible, so callers who don't need thread-safety don't pay for it.

```c++
// before: callers were already synchronized, so this lock was pure cost
TransferPhase HitlessTransferPhase::get() const {
  static CallsiteMetrics cm("HitlessTransferPhase::get");
  MonitoredMutexLock l(&cm, &mutex_);
  return phase_;
}
// after
TransferPhase HitlessTransferPhase::get() const { return phase_; }
```

Exception: if the typical use of a type *needs* synchronization, move the synchronization inside the type. Then the mechanism can be tuned — e.g. sharded to reduce contention — without affecting callers.
