# Code size considerations

Performance is more than runtime speed. Large code size means longer compile and link times, bloated binaries, more memory use, more icache pressure, and negative effects on microarchitectural structures like branch predictors. This matters most in low-level library code used in many places, and in templated code instantiated for many types.

Techniques vary by language. These are C++ ones, where over-use of templates and inlining is the usual cause.

## Trim commonly inlined code

Widely called functions plus inlining have a dramatic effect on size.

- **`TF_CHECK_OK`** was `CHECK_EQ(Status::OK(), (val))` — constructing an `Ok` object and emitting the full formatting machinery at every call site. Rewritten so the inline part is just `if (v.ok()) return nullptr;` and the message formatting lives in an out-of-line `TfCheckOpHelperOutOfLine`.
  ```c++
  #define TF_CHECK_OK(val)                                           \
    while (tensorflow::string* _result = TfCheckOpHelper(val, #val)) \
    LOG(FATAL) << *(_result)
  ```
- **`RETURN_IF_ERROR`** shrank by **79 bytes per call site**: a dedicated adaptor class for this macro, no `StatusBuilder` construction/destruction on the fast path, some `StatusBuilder` methods no longer inlined, and one unnecessary `~Status` call removed.
- **`CHECK_GE`** got **4.5× faster and shrank from 125 to 77 bytes**: `CheckOpString` lost its destructor (if `str_` is non-null we are about to `LOG(FATAL)`, so there is no point cleaning up), and the int/int case got its own inline overload delegating to an out-of-line `MakeCheckOpStringIntInt`.

## Inline with care

Inlining often helps, but can grow code with no payoff — and can lose performance through icache pressure.

- **Stop inlining what isn't hot.** TensorFlow stopped inlining many non-performance-sensitive functions (error paths, op registration) and moved slow paths of sensitive functions out of line: **−12.2%** of TensorFlow symbol bytes in a typical binary (8,814,545 → 7,740,233).
- **Out-of-line the uncommon branch.** The protobuf library's inlined message-length encoding was replaced by `WriteVarint32ToArrayOutOfLine`, which inlines only the `value < 0x80` single-byte case and calls a helper otherwise. In one large binary that source line went from 5,454,640 bytes of generated code to 9,609 — and the binary got faster as well as smaller.
- **`absl::flat_hash_set`/`flat_hash_map` code size**: extract code that doesn't depend on the specific hash table type into common non-inlined functions, place `ABSL_ATTRIBUTE_NOINLINE` judiciously, and out-line slow paths. **~0.5%** off some large binaries.
- **Don't inline allocation paths.** `ArenaStringPtr`'s inline `new std::string()` branch became a call to an out-of-line `SetAndReturnNewString()`.
- **Add `const char*` overloads marked `NOINLINE`** so `std::string` construction code isn't emitted at every call site:
  ```c++
  OpDefBuilderWrapper& Attr(const char* spec) TF_ATTRIBUTE_NOINLINE {
    return Attr(std::string(spec));
  }
  ```

## Reduce template instantiations

Templated code is duplicated for every combination of template arguments.

- **Turn a template parameter into a regular argument** when a runtime check is fine. A large routine templated on `bool Split` used it only to pick between two string constants; taking `bool split` as an argument cut instantiations of the large routine from **287 to 143**.
- **Move bulky code into a non-templated shared base class.** `XlaSplitNDBaseOp<Device, T>`'s constructor body moved to a non-templated `XlaSplitNDShared` base, reducing instantiations from one per `<T, Device, Rank>` to one per `<T>` and one per `<Rank>`.

## Reduce container operations

Each map or container operation can generate a lot of code.

- **Bulk-insert instead of a run of insertions.** A table of emoji fallbacks assigned `(*map)[0xFE000] = &kFE000;` line by line; a single `map->insert({...})` with a `PAIR(x)` macro took the generated text from **188 KB down to 360 bytes** in a library linked into many binaries.
- **Stop inlining heavy container users.** An 80-line routine using many `InlinedVector` operations was moved from the header to the `.cc` (no real inlining benefit).
