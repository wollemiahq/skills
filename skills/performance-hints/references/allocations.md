# Reduce allocations

Allocation costs three ways:

1. Time in the allocator.
2. Newly allocated objects may need expensive initialization, and expensive destruction later.
3. Every allocation tends to land on a new cache line, so data spread across many allocations has a larger cache footprint than the same data in fewer allocations.

Garbage-collected runtimes sometimes obviate #3 by placing consecutive allocations sequentially.

## Avoid unnecessary allocations

- **Share one static instance instead of allocating a fresh empty object.** A constructor that did `std::make_shared<DeviceInfo>()` whenever the caller passed none was changed to fall back to a lazily-created static empty `shared_ptr`. **+21% benchmark throughput.**
  ```c++
  static const std::shared_ptr<DeviceInfo>& empty_device_info() {
    static std::shared_ptr<DeviceInfo>* result =
        new std::shared_ptr<DeviceInfo>(new DeviceInfo);
    return *result;
  }
  ```
- **Use a statically allocated zero buffer** instead of allocating and memsetting one. An embedding lookup allocated `quint8[max_embedding_width]` and zeroed it on every call; it now uses a 256-byte static all-zero array when the width fits, and allocates only for the rare wide case.
- **Prefer stack allocation** when the object's lifetime is bounded by the scope — while watching stack frame sizes for large objects.

## Resize or reserve containers

When the maximum or expected maximum size is known, pre-size the backing store (`resize`, `reserve`).

```c++
// before: N push_back calls
for (int i = 0; i < ndocs-1; i++) { ...; docs_.push_back(DocId(...)); }
docs_.push_back(last_docid_);
// after: size once, then walk a pointer
docs_.resize(ndocs);
DocId* docptr = &docs_[0];
for (int i = 0; i < ndocs-1; i++) { ...; *docptr = DocId(...); docptr++; }
*docptr = last_docid_;
```

Caveats:
- Do **not** `resize`/`reserve` to grow one element at a time — that can be quadratic.
- If element construction is expensive, prefer one `reserve` followed by `push_back`/`emplace_back` over `resize`, since `resize` doubles the number of constructor calls.

## Avoid copying

- Prefer **moving** to copying. `Create(opts)` → `Create(std::move(opts))` for a large options struct.
- Store **pointers or indices** rather than copies in transient data structures, when lifetime allows. If a local map selects protos from an incoming list, store pointers to the incoming protos instead of copying deeply nested data. Similarly, sort a vector of *indices* rather than a vector of large objects.
- Avoid a copy at protocol boundaries — one change removing an extra copy when receiving ~400 KB tensors over gRPC sped the benchmark **10–15%**.
- Prefer `std::sort` to `std::stable_sort` where stability isn't required — stable sort makes an internal copy. When you need a deterministic order, encode the tiebreak in `operator<` instead:
  ```c++
  bool operator<(const HitWithPayloadOffset& other) const {
    return (docid < other.docid) ||
           (docid == other.docid && first_payload_offset < other.first_payload_offset);
  }
  ```

## Reuse temporary objects

An object declared inside a loop is recreated every iteration — construction, destruction, and re-growth each time. Hoisting the declaration out enables reuse. Compilers usually cannot do this for you, because of language semantics or an inability to prove equivalence.

```c++
// before                            // after
while (!iterator->done()) {          T profile;
  T profile;                         while (!iterator->done()) {
  profile.ParseFromString(...);        profile.ParseFromString(...);
  ...                                  ...
}                                    }
```

Same pattern for protobufs (hoist and `record.Clear()` per iteration) and for serialization scratch space:

```c++
// serialize into a caller-owned scratch string and return a view into it
absl::string_view DeterministicSerializationTo(const proto2::Message& m,
                                               std::string* scratch);
```

Caveat: protobufs, strings, vectors and containers grow to the size of the largest value ever stored. Reconstructing them periodically (say every N uses) keeps memory and reinitialization cost down.
