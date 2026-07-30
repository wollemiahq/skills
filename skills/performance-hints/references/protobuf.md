# Protocol buffer advice

Protobufs are convenient, especially for data sent over the wire or stored persistently, but they carry real cost. Filling a list of 1000 points and summing the Y coordinates is **20× faster** with a `std::vector` of structs than with a protobuf:

```
name                old time/op  new time/op  delta
BenchmarkIteration  17.4µs ± 5%   0.8µs ± 1%  -95.30%
```

The protobuf version also adds a few kilobytes of code and data to the binary. That seems small, but adds up across many message types and creates icache and dcache pressure.

## Don't use protobufs unnecessarily

If data is never serialized or parsed, it probably should not be in a protocol buffer. Their purpose is easy serialization/deserialization; do not use them just for `DebugString` and copyability.

## Avoid unnecessary message hierarchies

Each level of message hierarchy costs memory allocations, function calls, cache misses, and a larger serialized message — a tag plus a payload length on the wire and a generated class in C++.

```proto
// avoid                        // prefer
message Foo { optional Bar bar = 1; }      message Foo { optional int32 count = 1; }
message Bar { optional Baz baz = 1; }
message Baz { optional int32 count = 1; }
```

Every protobuf operation (parsing, serialization, size) must traverse the message tree, so the flat form is cheaper across the board.

## Use small field numbers for frequently occurring fields

The field number and wire type are encoded together as a varint: **1 byte for field numbers 1–15**, 2 bytes for 16–2047. (Avoid 2048 and above.) Consider pre-reserving some small field numbers for future extensions of performance-sensitive messages.

## Choose the integer type deliberately

Generally use `int32`/`int64`, but:
- `fixed32`/`fixed64` for large values like hash codes — smaller *and* much cheaper to encode/decode than a varint at that magnitude.
- `sint32`/`sint64` for values that are often negative (varints encode negatives badly).

## Pack repeated numeric fields

In proto2, repeated values serialize as a sequence of (tag, value) pairs — a tag decoded per element. Annotate with `[packed=true]`: the payload length comes first, then untagged values. (Proto3 packs by default.)

Packing works best with fixed-width values (`fixed32`, `fixed64`, `float`, `double`), where the encoded length is elements × width, so parsing can size the buffer up front with no reallocation. With varints the count is still unknown, so reallocation cost may remain.

## Use `bytes` instead of `string` for binary data and large values

`string` holds UTF-8 text and can require validation; `bytes` holds an arbitrary byte sequence and is often both more appropriate and more efficient.

## `string_type = VIEW` to avoid copying

Copying a big string or bytes field during parsing is expensive.

```proto
message Image {
  bytes jpeg_encoding = 4 [features.(pb.cpp).string_type = VIEW];
}
```

Without `VIEW`, parsing copies the field contents out of the serialized buffer into a string object. Routines like `ParseFromStringWithAliasing` instead reference the original backing string via `absl::string_view` — which **must outlive** the protobuf instance holding the alias.

## `Cord` for large fields

`[ctype = CORD]` changes the field representation from `std::string` to `absl::Cord`, which uses reference counting and tree-based storage to reduce copying and appending costs. If the protobuf is serialized to a cord, parsing such a field can avoid copying entirely.

```proto
message Document { bytes html = 4 [ctype = CORD]; }
```

Performance depends on length distribution and access patterns — validate with benchmarks.

## Use arenas in C++

Message and string fields are heap-allocated even when the top-level object is on the stack. For messages with many sub-message and string fields, arenas amortize allocation, make deallocation virtually free, and improve locality by allocating from contiguous chunks. See also [`memory-representation.md`](memory-representation.md#arenas).

## Keep .proto files small

Once you rely on anything in a `.proto` file, the linker pulls in the entire file even if mostly unused — worse build times and bigger binaries. Use extensions and `Any` to avoid hard dependencies on big `.proto` files with many message types.

## Consider storing protobufs serialized, even in memory

In-memory protobuf objects have a large footprint — often **5× the wire-format size** — potentially spread across many cache lines. If the application keeps many protobufs live for long periods, store them serialized.

## Avoid protobuf map fields

Their performance problems usually outweigh the syntactic convenience. Prefer a repeated message and build a non-protobuf map from it:

```proto
// avoid                                 // prefer
map<string, bytes> env_variables = 5;    message Var { string key = 1; bytes value = 2; }
                                         repeated Var env_variables = 5;
```

## Parse into a subset message definition

To read a few fields of a large message, define your own message that mirrors the original but declares only the fields you need. Parsing a serialized `FullMessage` into it parses only those fields; the rest become unknown fields.

```proto
message SubsetMessage {
  optional int32 field3 = 3;
  optional int32 field88 = 88;
}
```

Consider APIs that discard unknown fields for a further gain.

## Reuse protobuf objects

Declare them outside loops so allocated storage is reused across iterations — see [`allocations.md`](allocations.md#reuse-temporary-objects).
