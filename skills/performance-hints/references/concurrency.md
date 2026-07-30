# Parallelization and synchronization

## Exploit parallelism

Modern machines have many cores and they are often underutilized. The common approach: process different items in parallel and combine results. Partition items into **batches** first, so you don't pay per-item parallelization overhead.

- Four-way parallelization of token encoding improved the encoding rate ~**3.6×** (a shared `ThreadPool(NumCPUs())` created once under a lock).
- Parallelizing per-cluster decoding improved decoding **5×**:
  ```c++
  struct SubTask { absl::Status result; absl::Notification done; };
  std::vector<SubTask> tasks(clusters->size());
  for (int c = 0; c < clusters->size(); c++) {
    options_.executor->Schedule([&, c] {
      tasks[c].result = DecodeBulkForCluster(...);
      tasks[c].done.Notify();
    });
  }
  for (int c = 0; c < clusters->size(); c++) tasks[c].done.WaitForNotification();
  for (int c = 0; c < clusters->size(); c++) RETURN_IF_ERROR(tasks[c].result);
  ```

Measure the effect on the whole system carefully: if spare CPU is not available, or memory bandwidth is saturated, parallelization may not help and may hurt.

## Amortize lock acquisition

Avoid fine-grained locking in hot paths. Freeing a tree of query nodes used a `ThreadSafeFreeList`, re-acquiring the lock per node; taking the lock once at the top and recursing through a `ReleaseLocked` helper (with `pool_lock_.AssertHeld()` in debug builds) removes the per-node cost.

Caveat: only do this if it does not increase lock **contention**.

## Keep critical sections short

Avoid expensive work inside critical sections — especially innocuous-looking code that does RPCs or touches files.

```c++
// before: RPC-ish work under the lock       // after: decide under the lock, act outside
{                                            bool should_start = false;
  MutexLock l(&lock_);                       int64 step = -1;
  model_ = model;                            { MutexLock l(&lock_);
  MaybeRecordProgress(last_global_step_);      model_ = model;
}                                              should_start = ShouldStartRecordProgress();
                                               step = last_global_step_; }
                                             if (should_start) StartRecordProgress(step);
```

Also count **cache lines** touched inside the section. Precomputing per-node-type properties as bits in `NodeItem`, and reading the destination node's `NodeItem` rather than its `Node*` for each outgoing edge, cut the critical section from ~`2 + O(num_outgoing_edges)` cache lines to 1–2 (and reduced TLB pressure) — **3.3%** on an ML training run.

Trap: expensive **destructors** run before a mutex is unlocked when the unlock is triggered by a scoped lock's destructor. Declaring objects with expensive destructors *before* the `MutexLock` may help, assuming that is thread-safe.

## Reduce contention by sharding

A mutex-protected structure with high contention can often be split into shards, each with its own mutex — provided there are **no cross-shard invariants**.

- A 16-way sharded LRU cache improved multi-threaded throughput ~**2×**:
  ```c++
  static uint32_t Shard(uint32_t hash) { return hash >> (32 - kNumShardBits); }
  Handle* Lookup(const Slice& key) {
    const uint32_t hash = HashSlice(key);
    return shard_[Shard(hash)].Lookup(key, hash);
  }
  ```
- Partitioning Spanner's `ActiveCallMap` into 64 shards behind a `LockedShard(tid)` interface gave a **69% reduction in wall-clock time** at 8192 fibers.

If the structure is a map, consider a concurrent hash map implementation instead.

**Be careful which bits select the shard.** If shard selection uses bits of a hash that are then used again by the underlying hash table, the second use sees a skewed distribution. Rehash, or combine with a constant:

```c++
ConnectionBucket* GetBucket(Index index) {
  absl::Hash<std::pair<Index, size_t>> hasher{};
  // Combine the hash with 42 to prevent shard selection using the same bits
  // as the underlying hashtable.
  return &buckets_[hasher({index, 42}) % num_buckets_];
}
```

## SIMD instructions

Explore handling multiple items at once with [SIMD](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data). See the `absl::flat_hash_map` group-match example in [`api-design.md`](api-design.md#bulk-at-the-implementation-level).

## Reduce false sharing

If different threads write different mutable data, put those items on different cache lines (`alignas(ABSL_CACHELINE_SIZE)` in C++). A histogram class moved its frequently-mutated `buckets_`, `min_`, `max_`, `count_`, `sum_`, `sum_of_squares_` onto a dedicated cache line, away from the options/boundaries/exporter fields.

Caveat: these directives are easy to misuse and can significantly increase object sizes. Justify them with measurements.

## Reduce frequency of context switches

Process small work items inline rather than dispatching to a thread pool:

```c++
if (o.size() * (sizeof(Tin) + sizeof(Tout)) < 16384) {
  o = i.template cast<Tout>();      // small cast on a CPU: do inline
} else {
  o.device(d) = i.template cast<Tout>();
}
```

## Use buffered channels for pipelining

An unbuffered channel blocks the writer until a reader is ready. That is useful when the channel is for *synchronization*, but wrong when it is there to increase *parallelism* — buffer it.

## Consider lock-free approaches

Lock-free structures sometimes beat mutex-protected ones. But direct atomic variable manipulation is [dangerous](https://abseil.io/docs/cpp/atomic_danger) — prefer higher-level abstractions.

- An RPC stub cache read thousands of times a second and modified rarely moved to a lock-free map: **3–5%** lower search latency.
- A mutex-guarded `dense_hash_map<TokenId, LocalTokenClassId>` became a `util::gtl::LockFreeHashMap`, with reads through epoch-based `EnterFast`/`LeaveFast` and writers periodically GC-ing deleted entries.
