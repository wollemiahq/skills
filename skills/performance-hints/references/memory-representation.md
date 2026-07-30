# Better memory representation

Careful attention to the memory and **cache footprint** of important data structures often yields big savings. The goal is to support common operations while touching fewer cache lines, which (a) avoids expensive cache misses and (b) reduces memory bus traffic — speeding up both this program and everything else on the machine.

## Compact data structures

Use compact representations for data that is accessed often or that makes up a large share of the application's memory. Fewer cache lines touched, less bandwidth used. Watch out for [cache-line contention](concurrency.md#reduce-false-sharing).

## Memory layout

For types with a large memory or cache footprint:

- **Reorder fields to reduce padding** between fields with different alignment requirements.
- **Use smaller numeric types** where the data fits.
- **Shrink enums** — enum values sometimes take a whole word. Use `enum class OpType : uint8_t { ... }`.
- **Group fields accessed together** so common operations touch fewer cache lines.
- **Separate hot read-only fields from hot mutable fields**, so writes to the mutable ones don't evict the read-only ones from nearby caches.
- **Move cold data away from hot data** — at the end of the struct, behind an indirection, or in a separate array.
- **Bit/byte-level packing** is possible but complicated. Only do it when the data is encapsulated in a well-tested module and the memory saving is significant. Watch for side effects: under-alignment of frequently used data, more expensive access code. Validate with benchmarks.

## Indices instead of pointers

Pointers are 64 bits on modern machines, so pointer-rich structures chew memory through indirection. Integer indices into an array `T[]` are smaller (often 32 bits or fewer) *and* the `T` elements are contiguous, giving better cache locality.

## Batched storage

Avoid data structures that allocate a separate object per element (`std::map`, `std::unordered_map`). Prefer chunked or flat representations that store multiple elements close together (`std::vector`, `absl::flat_hash_{map,set}`) — better cache behaviour and less allocator overhead.

Partitioning elements into fixed-size chunks can cut a structure's cache footprint significantly while preserving asymptotic behaviour. For some structures one chunk holds everything (strings, vectors); others like `absl::flat_hash_map` use the technique internally.

## Inlined storage

Some container types reserve space for a few elements at the top level and avoid allocation entirely when the count is small — e.g. `absl::InlinedVector`. Very helpful when instances are constructed often (stack variables in hot code) or many are live at once.

Caveat: if `sizeof(T)` is large, the inlined backing store is large too, and inlined storage may be the wrong choice.

## Unnecessarily nested maps

A nested map can often become a single-level map with a compound key, cutting lookup and insertion cost:

```c++
// before
absl::btree_map<std::string, absl::btree_map<std::string, OpDef>> ops;
// after — the btree maps from {package_name, op_name} to const OpDef*
absl::btree_map<std::pair<absl::string_view, absl::string_view>, const OpDef*> ops;
```

Caveat — go the other way when the first key is big. A single-level hash table keyed by (path, numeric sub-keys), where each path occurred in ~1000 keys, was split into two levels: first by path, then sub-key → data. That cut path storage by a factor of 1000 and sped up access patterns that touch many sub-keys of the same path. **76% improvement in a microbenchmark.**

## Arenas

Arenas reduce allocation cost, pack independently allocated items into fewer cache lines, and eliminate most destruction cost. Most effective for complex data structures with many sub-objects. Give the arena a sensible initial size.

Caveat: it is easy to misuse arenas by putting many short-lived objects into a long-lived arena, bloating memory footprint.

## Arrays instead of maps

If the map's domain is a small integer or an enum, or the map will have very few elements, replace it with an array or vector:

```c++
// before
const gtl::flat_map<int, int> payload_type_to_clock_frequency_;
// after — a map implemented as a simple array indexed by payload_type
struct PayloadTypeToClockRateMap { int map[128]; };
const PayloadTypeToClockRateMap payload_type_to_clock_frequency_;
```

## Bit vectors instead of sets

If the set's domain is a small integer, use a bit vector (`util::bitmap::InlinedBitVector` is often a good choice). Set operations become bitwise booleans — OR for union, AND for intersection.

Spanner's placement system replaced `dense_hash_set<ZoneId>` with `InlinedBitVector<256>`, one bit per zone:

```c++
bool ContainsZone(ZoneId zone) const {
  return zone < b_.size() && b_.get_bit(zone);
}
```

`BM_Evaluate` improved 26–31% across all sizes.

Likewise, a `unordered_map<HloInstruction*, unordered_set<HloInstruction*>>` tracking transitive reachability became a dense id assignment plus a bit matrix where `matrix_(a,b)` is true iff `b` is reachable from `a`.
