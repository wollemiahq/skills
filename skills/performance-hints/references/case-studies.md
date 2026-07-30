# Changes that combine many techniques

Real bottleneck work rarely applies one technique. These are the mindset: once a subsystem is identified as the bottleneck, sweep it with everything.

## GPU memory allocator, ~40% faster (36–48% on alloc/dealloc)

1. Identify chunks by a **handle** (index into a `vector<Chunk>`) rather than a `Chunk*` — `next`/`prev` shrink from 8 bytes to 4. ([indices instead of pointers](memory-representation.md#indices-instead-of-pointers))
2. Keep a free list of `Chunk` objects threaded through `Chunk->next`, so chunk objects are never heap-allocated except when the vector grows — and all chunk memory is contiguous.
3. Replace a `std::set` of bins + `lower_bound` with an **array of bins** indexed by `log₂(byte_size/256)`: a few bit operations instead of a tree search, and all bin storage contiguous — fewer cache lines moving between cores under multi-threaded allocation.
4. Add a **fast path** to `AllocateRaw` that tries allocating without the retry helper, avoiding several call levels plus a `std::function` allocation.
5. Comment out most `VLOG` calls.

`BM_Allocation` 347 → 184 ns (+47%); threaded variants +20% at 16 threads.

## Pathways throughput, ~20%

- Unify special-case descriptor parsing into one `ParsedDescriptor` class, used in more places to avoid full parse calls.
- Change several protobuf fields from `string` to `bytes` (avoids UTF-8 checks and their error handling).
- Downgrade one field from `Cord` to `string` where the payloads are small.
- Use `flat_hash_map` instead of `std::unordered_map` in a few places.
- Add `MemoryManager::LookupMany` so the Stack op stops calling `Lookup` per batch element — less setup overhead like locking.
- Remove unnecessary string creation.

227 → 272 steps/sec for a batch of 1000 1 KB tensors.

## XLA compiler, ~15%

1. Return early in a comparator when `a == b`, avoiding serializing and fingerprinting long computation strings.
2. Turn a `CHECK` into a `DCHECK` to avoid touching an extra cache line.
3. Avoid an expensive copy of a front instruction.
4. Do the bulk of `ToString`/`ToCord` work by appending to `std::string` rather than to a `Cord`.
5. Make an increment do one hash lookup rather than two.
6. Streamline a scoreboard update.

## XLA shape handling, ~31% compile time

- Store raw array pointers instead of `absl::Span` objects in `ForEachState`; pre-form the index span once instead of per iteration; keep a pointer to the index vector's backing store; cache `minor_to_major` in the constructor; inline the constructor and `IncrementDim`.
- Add `ForEachIndexNoStatus` so the visitor returns `bool` rather than `StatusOr<bool>` — the latter runs an expensive destructor per element.
- In `Broadcast`: a templated `BroadcastHelper` specialized per primitive byte size (so the compiler doesn't emit the general large-memcpy path for a 1/2/4/8-byte copy); one `shape()` call at the top instead of ~(5 + dims + elements) virtual calls; a special case for source dimensions being one; raw pointers into scratch instead of `vector::operator[]`; a three-argument index routine taking `minor_to_major` so it's computed once per broadcast, not per element.
- Defer `GetSubSharding` into the branch that needs it: 43.7s → 2.0s in one compilation.

`BM_BroadcastVectorToMatrix` +57–59%. A whole ahead-of-time compile of a large language model went 573s → 465s (+19%), with the two largest XLA programs going 284s → 194s (+31%).

## Plaque compilation, ~22%

1. Hash-table lookup instead of sorted intersection for shared-source detection.
2. Reuse the same scratch hash table across calls.
3. One btree keyed by `pair<package, opname>` instead of a btree of btrees.
4. Store a pointer to the opdef in that btree instead of copying the opdef in.

## MapReduce, ~2× on a wordcount benchmark

1. Replace `hash_multimap<Key, StringPiece>` (an entry per key/value) with `hash_map<Key, ValuePtr*>`, where `ValuePtr` is a linked list of values with repetition counts. Three wins: much less memory per value, so the reducer buffer flushes less often; faster inserts for existing keys (hook into the list rather than create a hash entry); and repeated identical values collapse to one entry with a count.
2. Test for `nshards == 1` in the default sharding function, skipping key fingerprinting entirely.
3. Turn `VLOG(3)` into `DVLOG(3)` on the per-key/value combiner path.

12.56s → 6.55s.

## SelectServer alarms, 771 ns → 271 ns

1. `AdjustablePriorityQueue<Alarm>` instead of `set<Alarm*>` — avoids an allocation per alarm setup (the red-black tree node) and gives much better locality, since the queue is a heap in a vector.
2. `dense_hash_map` instead of `hash_map` for the alarm list — another allocation removed per add/delete.
3. Remove the `num_alarms_stat_` and `num_closures_stat_` exported variables. Keeping them even as plain `Atomic32` would have cost 281 → 340 ns.

## In-memory index serving, 3.3× (2001)

150 → 500+ queries/sec for a 2 GB in-memory index. A catalogue of the techniques in this skill applied at once:

- Block decoding speed 8.9 → 13.1 MB/s.
- Checksum the block during decoding, which lets every `getsymbol` operation skip bounds checking.
- Hold `BitDecoder` fields in local variables across entire loops, storing back at the end.
- Inline assembly for `bsf` (index of first set bit) in `getUnary`.
- Resize the output vector outside the loop and walk a pointer, instead of bounds-checked stores.
- Keep docids in local docid space during decoding; convert to global (multiply by `num_shards_`, add `my_shard_`) only when the value is actually needed. `AdvanceToDocid` lets scanning stay in local space.
- Decode position data on demand rather than eagerly for the whole block.
- If a block ends within 4 bytes of a page boundary, copy it to a local buffer — so the decoder can always do a 4-byte load without risking a segfault past an mmapped page.
- Initialize only the first `nterms_` elements of scoring structures rather than all `MAX_TERMS` (this was memsetting 20–100 KB per document scored).
- Skip `round_to_int` and its follow-on computation when the value is 0 — the common case, where the computation just wrote 0 over an already-zeroed field.
- Demote a bounds check on scoring structures to a debug-mode assertion.
