# Algorithmic improvements

The most critical opportunities come from algorithmic change — O(N²) to O(N log N) or O(N), or avoiding potentially exponential behaviour. These opportunities are rare in stable code but worth watching for when writing new code, and worth looking for whenever a [flat profile](measurement.md) pushes you to look higher up the call stack.

## Build the whole structure at once instead of incrementally

Adding graph nodes and edges one at a time to a cycle-detection structure required expensive work per edge. Adding the entire graph in reverse post-order made cycle detection trivial: DFS leaves nodes in reverse topological order, so ranks can be assigned as nodes are left, and no reordering is needed during initialization.

```c++
// InitFrom adds all the nodes and edges from src, returning true if
// successful, false if a cycle is encountered.
// REQUIRES: no nodes and edges have been added to GraphCycles yet.
bool InitFrom(const util_graph::Graph& src);
```

The caller collapsed from a per-node/per-edge loop with a `HasEdge` check and `InsertEdge` per edge down to a single `InitFrom` call.

## Replace the algorithm outright

A mutex implementation's deadlock detector was replaced with one based on Pearce & Kelly's dynamic topological sort for DAGs (*JEA* vol. 11, 2006, art. 1.7). ~50× faster, O(|V|+|E|) space instead of O(|V|²) bits, ~100 lines of C++ at its core. At the old 2K node limit: 0.5 µs per `InsertEdge` versus 22 µs. Because it scaled, an artificial 2K limit could be lifted — which then uncovered latent deadlocks in real programs.

## Pick the data structure that matches the actual query

- An `IntervalMap` (O(log N) lookups) was chosen because coalescing adjacent blocks "seemed to need" it — but a hash table sufficed, since the adjacent block can be found by a lookup. Storing the previous block's length in the entry made coalescing possible. `tpu::BestFitAllocator` got ~4× faster.
- Detecting whether two nodes share a common source used sorted-list intersection (O(N log N)); putting one node's sources in a hash table and iterating the other's is O(N). `BM_CompileLarge` 28.5s → 22.4s (−21.6%).

## A bad hash function makes O(1) into O(N)

A `Location` hasher that hashed only `key->address()` collapsed distinct keys into the same bucket. Replacing it with a real hash over the object's meaningful fields (flags packed into one word, shardmap, sharding, plus the strings) restored O(1) behaviour.

Note the deliberate omission in that hash: `any_of` was excluded because computing a hash insensitive to order and duplication was complicated — a reminder that hash inputs are a design choice, not an obligation to include every field.
