# ZIP64 Support Implementation Plan

This document describes how to add ZIP64 support to fzip. It separates ZIP64
format compatibility from true large-file/archive support because the current
ZIP APIs are synchronous and in-memory.

## Goals

- Read ZIP64 archives that are otherwise compatible with fzip's existing ZIP
  support.
- Write valid ZIP64 metadata when a ZIP archive crosses classic ZIP limits.
- Preserve the existing `zip_sync`, `unzip_sync`, and `unzip_list` APIs.
- Keep existing security behavior: path traversal rejection, size limits, and
  zip-bomb ratio checks.
- Add focused tests for ZIP64 central directory, ZIP64 extra fields, ZIP64 EOCD,
  and boundary conditions.

## Non-Goals For The First Phase

- Do not claim true 4GiB+ file processing through the current sync APIs.
- Do not add multi-disk ZIP support.
- Do not add ZIP encryption, data descriptors, unsupported compression methods,
  or filesystem extraction APIs.
- Do not refactor the DEFLATE engine unless needed for a later streaming ZIP
  writer/reader.
- Do not fix the existing `mtime` timestamp semantics. `wzh` currently stores
  the raw `mtime` value instead of converting Unix seconds to a DOS date+time
  pair (`src/zip.mbt:170-176` already flags this as "simplified"). That
  conversion bug is orthogonal to ZIP64 — track it separately so the ZIP64 PRs
  do not balloon in scope. It is still acceptable to switch the raw 4-byte field
  write from `wbytes` to `w4` while replacing ZIP metadata writes with
  fixed-width helpers.

## Current State

Relevant files:

- `src/zip.mbt`: ZIP local header, central directory, EOCD, sync read/write.
- `src/bits.mbt`: little-endian byte readers/writers.
- `src/types.mbt`: ZIP options and listing metadata.
- `src/constants.mbt`: ZIP signatures and safety constants.
- `src/zip_wbtest.mbt`: current ZIP white-box tests.

The current code already has a small ZIP64 reading path:

- `zh` reads the central directory entry and conditionally calls `z64e`.
- `z64e` reads a ZIP64 extra field.
- `unzip_sync` and `unzip_list` try to locate ZIP64 EOCD metadata when classic
  EOCD fields contain sentinel values.

That support is incomplete:

- ZIP64 detection is tied mostly to compressed size and entry count/offset
  sentinels.
- A classic archive with exactly `65535` entries can be misdetected as ZIP64
  because the current reader treats `c == 65535` as sufficient to probe ZIP64
  metadata. If no valid ZIP64 locator is present, Phase 1 must fall back to
  classic metadata rather than reading arbitrary bytes before EOCD.
- ZIP64 extra fields are treated as fixed-size instead of conditional fields.
- ZIP64 EOCD and locator parsing use 32-bit reads for fields that are 64-bit.
- The current ZIP64 EOCD locator probe reads from `eocd - 12` with `b4`, which
  points into the 8-byte ZIP64 EOCD offset field and only reads its low 32 bits.
  The locator signature itself is at `eocd - 20`, and the offset must be read as
  an 8-byte ZIP64 value before being converted to an `Int` index.
- The ZIP64 locator signature constant is named incorrectly.
- ZIP writing never emits ZIP64 EOCD, locator, or ZIP64 extra fields.
- Public metadata still uses `Int`, so values must be checked before converting
  from `Int64`.

## ZIP64 Background

Authoritative reference: PKWARE [APPNOTE.TXT][appnote], specifically:

- §4.3.14 — ZIP64 end of central directory record
- §4.3.15 — ZIP64 end of central directory locator
- §4.3.9 / §4.3.9.2 — Data descriptor (8-byte sizes when ZIP64)
- §4.4.3.2 — `version needed to extract = 45` for ZIP64
- §4.5.3 — ZIP64 extended information extra field

[appnote]: https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT

Classic ZIP uses these maximum field values:

- 16-bit entry count: `0xffff`.
- 32-bit compressed size: `0xffffffff`.
- 32-bit uncompressed size: `0xffffffff`.
- 32-bit local header offset: `0xffffffff`.
- 32-bit central directory size: `0xffffffff`.
- 32-bit central directory offset: `0xffffffff`.

ZIP64 stores overflow values in:

- ZIP64 extended information extra field, header id `0x0001`.
- ZIP64 end of central directory record, signature `0x06064b50`.
- ZIP64 end of central directory locator, signature `0x07064b50`.
- Classic EOCD remains present and uses sentinel values for overflowed fields.

The ZIP64 extra field is conditional. Its payload values appear in this order
only when the matching classic central directory field is set to its sentinel:

1. Uncompressed size, 8 bytes.
2. Compressed size, 8 bytes.
3. Local header offset, 8 bytes.
4. Disk start number, 4 bytes.

Local file headers have a stricter interoperability rule for sizes: if either
the compressed size or uncompressed size needs ZIP64, the local-header ZIP64
extra field must include **both** 8-byte size values, in uncompressed-then-
compressed order. Local headers never include the local header offset in their
ZIP64 extra field; that offset is central-directory metadata.

## Phase 1: ZIP64 Metadata Compatibility

Phase 1 should make sync APIs ZIP64-aware while still requiring archives and
entries to fit in memory.

### MoonBit Layout Note

When adding MoonBit examples or new source files, keep the package style from
`moonbit-agent-guide`: each top-level item in a package should be separated by
`///|`.

For new ZIP64 code, prefer descriptive private names such as `find_eocd`,
`read_central_directory_info`, and `read_zip64_entry_extra`. Existing terse
helpers such as `zh`, `z64e`, `wzh`, `wzf`, and `slzh` can remain until they are
touched by the ZIP64 refactor; when a helper is rewritten or gets a broader
contract, rename or wrap it with a descriptive helper in the same package.

### Step 1: Add Fixed-Width Little-Endian Helpers

Update `src/bits.mbt`:

- Add `w2(d, offset, value : Int)`.
- Add `w4(d, offset, value : UInt)`.
- Add `w8(d, offset, value : Int64)`.
- Keep `b2`, `b4`, and `b8`.
- Prefer fixed-width writers for ZIP metadata instead of `wbytes`.

Why fixed-width writers: `wbytes` writes a value as little-endian bytes and
**stops after the highest non-zero byte**. That works for the existing
classic-ZIP fields only because buffers are freshly zero-filled, but it does
not express field width. Concrete failure mode: `wbytes(d, off, 45)` for a
2-byte `version_needed` field (0x002D) writes only **one** byte and
silently relies on the destination's other byte already being zero —
flip the buffer to anything else (a streaming writer that reuses memory, a
later patch that switches allocation strategy, a hand-built test fixture)
and the field becomes garbage. ZIP64 needs writers that always emit exactly
2, 4, or 8 bytes, including any leading zero bytes. Use `w2` for 2-byte
fields such as the new `version_needed` per entry, `w4` for 4-byte fields
and sentinels like `0xffffffffU`, and `w8` for ZIP64 8-byte values; do not
rely on `wbytes` for metadata whose width is part of the format.

`w4` should take `UInt`, not `Int`, because `0xffffffff` does not fit in a
32-bit signed `Int`. Callers that have an `Int` size or offset must validate it
is in the classic range and convert with `reinterpret_as_uint()` before writing;
callers writing signatures or sentinel values should pass `UInt` constants
directly. `w8` is a raw fixed-width writer and should not perform validation;
ZIP metadata callers must validate through a separate checked helper before
calling it, because all ZIP64 sizes and offsets are unsigned logical values even
though the raw helper accepts MoonBit `Int64`.

Add a checked conversion helper for ZIP64 values:

```mbt nocheck
///|
fn zip64_to_int(v : Int64, context : String) -> Int raise FzipError {
  ...
}
```

For untrusted ZIP64 metadata, prefer an offset-specific reader that validates
before constructing a potentially overflowing signed `Int64`:

```mbt nocheck
///|
fn read_zip64_int(data : FixedArray[Byte], offset : Int, context : String) -> Int raise FzipError {
  ...
}
```

It should read the low and high 32-bit words with `b4`. Because Phase 1 rejects
anything larger than `max_int_val()`, any non-zero high word can be rejected
immediately, and the low word can then be range-checked before converting to
`Int`. Keep `b8` for small trusted fixtures or writer-side fixed-width values,
but do not depend on `b8(...).to_int()` for adversarial ZIP64 size/offset
fields.

For writer-side ZIP64 values, add a small checked helper that rejects negative
values and values that cannot be represented by the current sync API before
calling raw `w8`:

```mbt nocheck
///|
fn write_zip64_int(data : FixedArray[Byte], offset : Int, value : Int64, context : String) -> Unit raise FzipError {
  ...
}
```

Use this helper in any checked writer path. If `zip_sync` remains non-raising,
its layout calculation must guarantee these checks have already passed before
the raw writers run.

These helpers should reject negative values and values too large for safe
indexing or allocation in the current runtime. Concrete limit: MoonBit `Int`
is 32-bit signed, so the practical ceiling is `2147483647` (~2 GiB). The
codebase already has a helper for this — `max_int_val()` in
`src/deflate.mbt:3` computes it as
`((-1).reinterpret_as_uint() >> 1).reinterpret_as_int()`. Reuse it here
instead of writing a fresh idiom (and **do not** write `Int::max_value()`,
which is not a method on `Int`).

Anything larger must be rejected at the metadata boundary because:

- `FixedArray` is indexed by `Int`, so larger arrays cannot be allocated.
- `slc`, `b_off + sc`, and other arithmetic in `unzip_sync` operate on `Int`
  and would overflow silently.

#### ZIP64 values too large for sync APIs

Phase 1 should add `FzipErrorCode::Zip64ValueTooLarge` for well-formed ZIP64
metadata whose size, offset, count, or final writer layout cannot be represented
or safely indexed by the current sync APIs. This is different from
`InvalidZipData`: the archive may be structurally valid ZIP64, but the
`FixedArray`/`Int`-based API cannot process it.

Use `Zip64ValueTooLarge` when:

- `read_zip64_int` sees a non-zero high 32-bit word or a low word greater than
  `max_int_val()`.
- ZIP64 EOCD entry count, central directory size, or central directory offset
  cannot be represented as `Int`.
- ZIP64 entry compressed size, uncompressed size, or local header offset cannot
  be represented as `Int`.
- `zip_sync_checked` detects layout arithmetic overflow, a final archive size,
  or a generated size/offset that cannot fit the current sync API.

Keep `InvalidZipData` for malformed ZIP/ZIP64 structure, unsupported multi-disk
metadata, missing required ZIP64 extra fields, unsafe extraction paths, and
other security policy violations. `Zip64ValueTooLarge` is an additive public
change to the `pub(all)` `FzipErrorCode` enum; update `src/error.mbt`,
`src/pkg.generated.mbti`, README, and CHANGELOG in the same PR.

#### Public-API impact for files between 2 GiB and 4 GiB

`UnzipFileInfo.size` and `original_size` are `Int`. A ZIP64 archive whose
_entries_ fit in memory (say, a 3 GiB file on a 64-bit host) still cannot be
represented because the field type tops out at ~2 GiB. Choose one:

1. **Phase 1 default:** keep `Int` and reject sizes greater than
   `max_int_val()` with `Zip64ValueTooLarge`. Document the limit in the API
   docs.
2. Promote `size` / `original_size` to `Int64`. This is a `pub(all)` struct
   change and breaks pattern-matching callers — defer to a major bump or to
   Phase 2 when the streaming reader changes the public surface anyway.

### Step 2: Correct ZIP Constants

Update `src/constants.mbt`:

- Add `zip64_eocd_signature = 0x06064B50U` (the ZIP64 end-of-central-directory
  **record** signature).
- Add `zip64_extra_field_id = 0x0001`.
- Add classic sentinel constants:
  - `zip_uint16_max = 65535`
  - `zip_uint32_max = 0xffffffffU`
- Add a package-private `max_extra_field_length : Int = 4096` limit for the
  total extra-field bytes on a single local or central directory entry. Reject
  larger values with `ExtraFieldTooLong` before scanning individual extra
  fields.

Use `zip_uint32_max` as a `UInt` sentinel for 32-bit ZIP fields. If an `Int64`
comparison is needed, convert through an explicitly named helper or local value
such as `4294967295L`; do not mix signed `Int`, `UInt`, and `Int64` sentinel
values implicitly in the writer.

The currently exported constant `zip64_eocd_locator_signature : UInt =
0x06064B50U` (`src/constants.mbt:27`) is misnamed — that hex value is the
ZIP64 EOCD **record** signature, not the locator. Because it appears in
`pkg.generated.mbti`, fixing it touches the public API. Phase 1 should use the
non-breaking deprecation strategy below so downstream callers keep compiling:

```mbt nocheck
///|
#alias(zip64_eocd_locator_signature, deprecated)
pub let zip64_eocd_signature : UInt = 0x06064B50U
///|
pub let zip64_locator_signature : UInt = 0x07064B50U
```

In MoonBit, `#alias(old_name, deprecated)` attaches `old_name` to the next
declaration. That means `zip64_eocd_locator_signature` becomes a deprecated
alias for `zip64_eocd_signature`, preserving the old `0x06064B50U` runtime
value while giving it the correct new name; do **not** keep a separate
`pub let zip64_eocd_locator_signature` declaration, or the identifier will be
declared twice. Existing callers keep compiling with a deprecation warning, and
new code uses `zip64_eocd_signature` for the ZIP64 EOCD record and
`zip64_locator_signature` for the locator. Drop the alias in a later major
release.

Also replace the literal `0x06064B50U` occurrences in `src/zip.mbt:376` and
`src/zip.mbt:456` with the new correctly named EOCD record constant.

Keep implementation-only sentinel constants package-private unless they are
intentionally part of the public API. `zip64_eocd_signature` and
`zip64_locator_signature` are public because they replace an already-public
constant; `zip64_extra_field_id`, `zip_uint16_max`, and `zip_uint32_max` should
start package-private unless there is a documented caller need.

### Step 3: Introduce Internal ZIP Metadata Types

Add package-private structs in `src/zip.mbt` or a new focused file such as
`src/zip64.mbt`:

```mbt nocheck
///|
struct ZipCdInfo {
  entries : Int
  offset : Int
  size : Int
  zip64 : Bool
}

///|
struct ZipEntryHeader {
  compression : Int
  compressed_size : Int
  uncompressed_size : Int
  name : String
  next_offset : Int
  local_offset : Int
}
```

Use UpperCamel for type/struct names — including private ones — to match
MoonBit conventions and the existing types in this package (`CRC32State`,
`InflateState`, `DeflateOptions`). Lowercase identifiers are reserved for
functions (`zh`, `slzh`, `z64e`, `b2`/`b4`/`b8`).

Why `entries : Int` is fine even though `size`/`offset` use `Int`:

- The ZIP spec caps the entry count field at `Int64` in ZIP64 EOCD, but no
  realistic archive comes anywhere near `max_int_val()` (~2.1 billion
  entries). At the spec-mandated minimum of 30 bytes per local header alone,
  2 billion entries would need 60 GiB of pure metadata, which the in-memory
  sync API cannot allocate anyway.
- Within `ZipCdInfo`, `size` and `offset` are byte counts/positions into the
  archive buffer — these are the values that actually constrain Phase 1 to
  ~2 GiB through the `Int` indexing of `FixedArray`. They stay `Int` for
  the same reason: anything past `max_int_val()` cannot be addressed by the
  current sync API and must be rejected at the metadata boundary.
- If/when Phase 2 introduces a streaming reader, both fields may move to
  `Int64` (or get split into "byte offset" and "stream offset" types), but
  `entries` will likely stay `Int`.

### Step 4: Refactor EOCD Discovery

Extract shared EOCD logic used by both `unzip_sync` and `unzip_list`:

```mbt nocheck
///|
fn find_eocd(data : FixedArray[Byte]) -> Int raise FzipError
///|
fn read_central_directory_info(data : FixedArray[Byte], eocd : Int) -> ZipCdInfo raise FzipError
```

`find_eocd` should keep the current max EOCD comment scan behavior:

- Start at `data.length() - 22`.
- Search backward for `zip_eocd_signature`.
- Stop after `65535 + 22 + 1` bytes.
- Treat a matching signature as a valid EOCD candidate only when the EOCD
  comment length field is internally consistent:
  `candidate + 22 + comment_length == data.length()`. This avoids accepting a
  `0x06054b50` byte sequence that appears inside the EOCD comment or earlier
  payload data.

`read_central_directory_info` should:

- Read classic EOCD disk numbers, entry count, central directory size, and
  offset. Reject non-zero classic EOCD disk numbers even when the archive does
  not need ZIP64; multi-disk ZIP is unsupported in all phases.
- If no sentinel values are present, return classic metadata.
- If any sentinel is present, probe for a valid ZIP64 locator immediately before
  EOCD. The locator is exactly 20 bytes and starts at `eocd - 20`; reject or
  fall back before reading if `eocd < 20`.
- Validate the locator signature with `b4(data, eocd - 20)` against
  `zip64_locator_signature == 0x07064B50U`. Do not use the deprecated
  `zip64_eocd_locator_signature` alias in new parser code; it intentionally
  points at the EOCD record signature for compatibility.
- If the only sentinel-like value is the classic entry count `0xffff` and no
  valid ZIP64 locator is present, do not read arbitrary bytes before EOCD as
  ZIP64 metadata. Treat the archive as classic with exactly 65535 entries for
  compatibility. This keeps the reader friendly to valid classic archives that
  sit exactly on the 16-bit entry-count boundary. If any other classic EOCD field
  is a sentinel value, missing or invalid ZIP64 metadata is an error because the
  classic EOCD cannot represent the real offset/size.
- Read the ZIP64 EOCD offset from locator bytes 8..15, i.e. from `eocd - 12`,
  with `read_zip64_int` (or `b8` followed by checked conversion in trusted test
  fixtures only), and ensure the record starts before the locator and is fully
  inside `data`.
- Reject multi-disk archives.
- Validate locator disk fields: disk containing ZIP64 EOCD must be `0`, total
  disks must be `1`, and the classic EOCD disk numbers must also be zero. Any
  other value is an unsupported multi-disk archive.
- Read the ZIP64 EOCD record using `read_zip64_int` for 64-bit count, size, and
  offset fields, validating the
  record signature against `zip64_eocd_signature` (`0x06064B50U`) — replacing
  the hard-coded literals at `src/zip.mbt:376` and `src/zip.mbt:456`.
- Validate the ZIP64 EOCD record size field: it must be at least `44`, and
  `zip64_eocd_offset + 12 + record_size` must not overflow or pass the locator.
- Validate that `offset + size <= data.length()`.

### Step 5: Parse ZIP64 Extra Fields Correctly

Replace the current fixed-layout `z64e` behavior with a conditional parser.
Prefer a named result struct over a positional tuple; compressed size,
uncompressed size, and local header offset are all integers and are easy to
swap accidentally.

**Recommended — named resolved result.** Pass the classic 32-bit values in,
return fully resolved values out, so the caller gets back exactly the three
numbers it needs without positional ambiguity:

```mbt nocheck
///|
struct ZipEntrySizes {
  compressed : Int
  uncompressed : Int
  local_offset : Int
}
```

```mbt nocheck
///|
fn read_zip64_entry_extra(
  data : FixedArray[Byte],
  extra_offset : Int,
  extra_len : Int,
  classic_compressed~ : UInt,
  classic_uncompressed~ : UInt,
  classic_local_offset~ : UInt,
) -> ZipEntrySizes raise FzipError
```

The named return type is the important part: it prevents callers from confusing
compressed size, uncompressed size, and local header offset after parsing. The
implementation must treat sentinel inputs as "look in the ZIP64 extra field"
and never return the sentinel itself as a real size. The classic values should
be labeled parameters because they all share the same `UInt` type; otherwise a
future refactor could swap compressed and uncompressed values without a compile
error.

**Alternative — optional named values.** If you need the caller to distinguish
"ZIP64 extra produced this value" from "fall back to classic", use optional
fields:

```mbt nocheck
///|
struct Zip64ExtraValues {
  compressed : Int?
  uncompressed : Int?
  local_offset : Int?
}
```

```mbt nocheck
///|
fn read_zip64_entry_extra(
  data : FixedArray[Byte],
  extra_offset : Int,
  extra_len : Int,
  needs_uncompressed~ : Bool,
  needs_compressed~ : Bool,
  needs_local_offset~ : Bool,
) -> Zip64ExtraValues raise FzipError
```

Field access (`vals.compressed`) protects against positional mistakes the
tuple form does not.

Rules (apply to either signature):

- Iterate through extra fields by `header_id` and `data_size`.
- Reject `extra_len > max_extra_field_length` with `ExtraFieldTooLong` before
  scanning. This keeps a malicious central directory from forcing long
  extra-field scans even when the overall central directory is still within the
  archive bounds.
- Bounds-check every field before reading.
- Find header id `0x0001`.
- Read only fields required by sentinels, in spec order.
- Require enough bytes for every required field.
- Never use sentinel values (`0xffffffff`) as real sizes — either resolve
  them via the ZIP64 extra field or raise `InvalidZipData`.
- Ignore disk start number unless needed for validation; reject non-zero disk
  number because multi-disk archives are unsupported.
- Raise `Zip64ValueTooLarge` for ZIP64 sizes or offsets that do not fit current
  sync API limits.

Then update the central directory parser:

- Validate the central directory file header signature before reading fields.
- Read classic compressed size, uncompressed size, and local header offset.
- Determine which fields need ZIP64 values from sentinel checks.
- If any are needed, call the ZIP64 extra parser.
- If none are needed, use classic fields.
- Validate that `46 + filename_length + extra_length + comment_length` fits in
  the input and that each `next_offset` stays within `cd.offset + cd.size`.
  Do this even for classic archives; ZIP64 support should not keep the current
  partial central-directory bounds checking.
- After all entries are parsed, require the final central-directory cursor to be
  exactly `cd.offset + cd.size`; otherwise trailing or missing bytes inside the
  declared central directory should raise `InvalidZipData`.

### Step 6: Validate Local Header And Data Bounds

Strengthen `slzh` or replace it with a bounds-checking helper:

```mbt nocheck
///|
fn local_data_offset(data : FixedArray[Byte], local_offset : Int) -> Int raise FzipError
```

Checks:

- Local offset is within the input.
- Local header signature is `zip_local_signature`.
- Filename and extra lengths fit inside `data`.
- Data range `data_offset + compressed_size` fits inside `data`.
- For entries without data descriptors, local-header CRC and classic size fields
  should agree with the central directory when those local fields are not ZIP64
  sentinels. If this is deferred, document it as an existing metadata
  consistency gap and add a regression test before accepting ZIP64 data
  descriptors.
- General-purpose bit flag bit 0 (encryption) is not set.
- General-purpose bit flag bit 3 (data descriptor) is handled deliberately:
  for Phase 1, the reader may still extract such entries using central
  directory sizes because it starts from the central directory, but tests must
  cover the case. If implementation complexity grows, explicitly reject bit 3
  with `InvalidZipData` and document that data descriptors are deferred to
  Phase 2; do not accidentally accept them without tests.

This prevents malformed ZIP64 metadata from creating invalid slices or inflater
range errors later.

`unzip_list` is intentionally metadata-only and may stop after validating the
central directory. It does not need to prove that every local header is
reachable or that every compressed data range is extractable. It should also
preserve the existing behavior of reporting entry names as archive metadata,
even if a name would be unsafe to extract. Callers must treat listed names as
untrusted metadata. `unzip_sync` remains the extraction API and must reject
unsafe paths before returning any file data. Callers that need a full archive
verifier should call `unzip_sync` or a future checked validation API, not treat
`unzip_list` as that verifier.

### Step 7: Write ZIP64 Archives When Needed

Update `zip_sync` internals to compute sizes and offsets with `Int64` before
writing headers.

Use a two-pass/fixpoint layout calculation before allocating the output buffer:

1. Compute each entry's compressed data, CRC, filename bytes, user extra length,
   and initial classic local-header size.
2. Decide which per-entry fields require ZIP64 extra fields based on sizes and
   provisional local offsets.
3. Recompute local offsets, central directory entry sizes, central directory
   offset, and central directory size including any ZIP64 extra fields.
4. Repeat the ZIP64 decision once after recomputation. A second pass should be
   enough because adding ZIP64 fields only increases sizes monotonically; assert
   in debug/test code if the layout still changes unexpectedly.
5. Allocate the final `FixedArray` from the converged total size after checking
   it still fits the current sync API limits.

The exact total size must include every ZIP64-induced byte:

- ZIP64 extra fields in local headers.
- ZIP64 extra fields in central directory entries.
- The ZIP64 EOCD record.
- The ZIP64 EOCD locator.
- The classic EOCD that is still written last.

ZIP64 should be enabled when any of these is true:

- Entry compressed size >= `0xffffffff`.
- Entry uncompressed size >= `0xffffffff`.
- Entry local header offset >= `0xffffffff`.
- Entry count >= `0xffff`.
- Central directory size >= `0xffffffff`.
- Central directory offset >= `0xffffffff`.

Note: the comparisons are `>=`, not `>`. A value that exactly equals the
sentinel itself (`0xffff` for the 16-bit entry count, `0xffffffff` for the
32-bit size/offset fields) must also be promoted to ZIP64. Writing the
sentinel value as a literal would be indistinguishable from the "look in the
ZIP64 extra field / ZIP64 EOCD" marker, so the only safe interpretation for
readers is "this is a ZIP64 entry whose real value lives elsewhere".
This is intentionally stricter than the reader: fzip should read legacy classic
archives with exactly 65535 entries when no ZIP64 locator is present, but it
should never write that ambiguous classic representation itself.

Implementation details:

- Add a helper to build ZIP64 extra field payloads for local and central
  headers.
- Reserve ZIP64 extra field id `0x0001` for fzip's own ZIP64 metadata. If
  `opts.extra` already contains `0x0001`, the writer must not emit duplicate or
  contradictory ZIP64 extra fields. Phase 1 should sanitize by dropping
  user-provided `0x0001` fields from both local and central headers before
  appending fzip's own ZIP64 extra field. This preserves the existing
  non-raising `zip_sync` API and avoids writing two conflicting ZIP64 extra
  fields. Document this reserved-field behavior in README and CHANGELOG.
- Enforce `max_extra_field_length` on the total emitted extra-field bytes for
  each local and central header after `0x0001` sanitization and after adding any
  fzip-generated ZIP64 extra field. `zip_sync_checked` should raise
  `ExtraFieldTooLong`; `zip_sync` must not silently truncate or emit corrupt
  length fields.
- For ZIP64 entries, classic size/offset fields should be written as
  `0xffffffff`.
- Central directory local offset should be `0xffffffff` when the ZIP64 extra
  carries the real offset.
- Local headers should include ZIP64 size values when either size crosses the
  classic limit. For interoperability, local headers must include **both**
  uncompressed size and compressed size in the ZIP64 extra field when either
  size needs ZIP64, even if the other size still fits in 32 bits. Local-header
  ZIP64 extra fields must not include the local header offset.
- Central headers should include ZIP64 size and offset values only when their
  matching classic fields use sentinels.
- Set `version needed to extract` to `45` (0x002D) for any header that uses
  ZIP64 sentinels or carries a ZIP64 extra field. Classic entries keep the
  current `20` (0x0014). Today `wzh` writes `b'\x14'` unconditionally
  (`src/zip.mbt:157-158`); the writer must compute this per entry. Other ZIP
  tools reject ZIP64 archives with `version_needed < 45`.
- For the central directory, also bump the **ZIP-spec byte** of `version
made by` to `45` when any entry is ZIP64. This field is **two bytes**, not
  one number: low byte = ZIP spec version, high byte = host OS code
  (APPNOTE §4.4.2). The current writer at `src/zip.mbt:151-155` already
  reflects this layout — it writes `b'\x14'` (= 20) into the low byte and
  `os.to_byte()` into the high byte. The change is to lift the low byte to
  `45` for ZIP64 entries while preserving `opts.os` in the high byte; do
  **not** treat the field as a single value bumped to "at least 45".
- While replacing ZIP metadata writes with fixed-width writers, also change the
  existing raw `mtime` field write from `wbytes(d, b, mtime_val)` to a fixed
  4-byte write such as `w4(d, b, mtime_val.reinterpret_as_uint())`. This does
  not fix the separate Unix-seconds-to-DOS-date conversion bug listed in
  Non-Goals; it only removes the variable-width metadata write from that
  4-byte field.
- Write ZIP64 EOCD record before classic EOCD when the archive needs ZIP64.
- Set ZIP64 EOCD `version made by` and `version needed to extract` to `45` in
  the record itself. If ZIP64 is needed only because of archive-level fields
  such as entry count or central directory offset, individual classic entries
  may still keep `version_needed = 20`, but the ZIP64 EOCD record must still
  advertise version `45`.
- Write ZIP64 EOCD locator after ZIP64 EOCD and before classic EOCD.
- Always write classic EOCD last.

For phase 1, current `FixedArray::make` allocation still limits practical output
size. The ZIP64 writing path can still be tested by forcing ZIP64 metadata in a
test-only internal helper, or by constructing small ZIP64 fixtures by hand.

The sync writer should check the converged total archive size before allocation.
To avoid turning user-controlled size/offset overflow into an internal failure,
add a checked writer entry point for recoverable failures:

```mbt nocheck
///|
pub fn zip_sync_checked(files : Array[(String, FixedArray[Byte])], opts? : ZipEntryOptions = ZipEntryOptions::default()) -> FixedArray[Byte] raise FzipError
```

Implement the writer around one shared raising builder:

```mbt nocheck
///|
fn build_zip_sync(files : Array[(String, FixedArray[Byte])], opts : ZipEntryOptions) -> FixedArray[Byte] raise FzipError
```

`zip_sync_checked` should call this builder directly and raise
`Zip64ValueTooLarge` for arithmetic overflow, final size that cannot fit in
`Int`, or metadata/layout values that cannot be represented by the current sync
API. It should raise `ExtraFieldTooLong` for emitted per-entry extra fields that
exceed `max_extra_field_length`.

The existing `zip_sync` signature remains unchanged for source compatibility,
but it must also delegate to the same builder. If the builder raises, `zip_sync`
must fail deterministically through the MoonBit runtime's standard trap/abort
mechanism with a stable message such as
`"fzip.zip_sync failed; use zip_sync_checked for recoverable errors: <code>"`.
Do not return a partial or corrupt archive from `zip_sync`. If the exact runtime
trap API is not obvious during implementation, resolve that API first and keep
the wrapper behavior documented in README.

### Step 8: Keep Public APIs Stable

Do not change these existing signatures in phase 1:

```mbt nocheck
///|
pub fn zip_sync(files : Array[(String, FixedArray[Byte])], opts? : ZipEntryOptions) -> FixedArray[Byte]
///|
pub fn unzip_sync(data : FixedArray[Byte]) -> Array[(String, FixedArray[Byte])] raise FzipError
///|
pub fn unzip_list(data : FixedArray[Byte]) -> Array[UnzipFileInfo] raise FzipError
```

Phase 1 should add this new API for recoverable writer failures:

```mbt nocheck
///|
pub fn zip_sync_checked(files : Array[(String, FixedArray[Byte])], opts? : ZipEntryOptions = ZipEntryOptions::default()) -> FixedArray[Byte] raise FzipError
```

If public functions, constants, or error variants are added, run `moon info` and
commit the generated `pkg.generated.mbti` changes intentionally. Treat any
`FzipErrorCode` addition as an intentional public API change. Phase 1 adds
`Zip64ValueTooLarge`, so update `src/error.mbt`, `src/pkg.generated.mbti`,
README, and CHANGELOG in the same PR.

#### Failure semantics for partial archives

`unzip_sync` and `unzip_list` are **fail-fast and all-or-nothing** for the
validation each API performs in phase 1. When a central-directory or ZIP64
metadata entry violates the sync-API limits — value beyond `max_int_val()`,
missing required ZIP64 extra field, unsupported multi-disk metadata, malformed
central-directory header — the call must `raise FzipError` immediately and
return _no_ partial result. `unzip_sync` performs the additional extraction
checks, so malformed local headers, unsafe paths, data bounds failures, and
ratio-bomb thresholds are also fail-fast there. `unzip_list` remains a
central-directory metadata API and does not validate local headers or compressed
data ranges.

Rationale: callers cannot safely consume a partial array in either API.
`unzip_sync` returns extracted data, so a partial result would mix valid
and missing entries with no signal of where the gap is; `unzip_list`'s
metadata is cheap to compute, so retry with a different decoder is the
right recovery path. If a future caller genuinely needs entry-by-entry
streaming-with-skip behavior, that belongs in the Phase 2 streaming reader,
not in these sync APIs.

For `unzip_sync`, keep the existing decompression safety limits meaningful.
Even if a ZIP64 value fits in `Int`, reject or cap extracted output that exceeds
the configured sync limit (`default_max_output_size` today, or a future
ZIP-specific option). `unzip_list` can report any size that fits in `Int`
without allocating, but `unzip_sync` must not allocate near-`max_int_val()`
buffers just because the metadata is representable.

Also fix the current ZIP inflater limit bug while touching this code path:
`unzip_sync` currently passes `default_max_input_size` as both `max_input_size`
and `max_output_size` to `inflt`. The ZIP path should pass
`default_max_input_size` for compressed input and `default_max_output_size` for
uncompressed output, and it should check `su <= default_max_output_size` before
allocating `FixedArray::make(su, ...)`. Stored entries should be subject to the
same output-size cap before slicing and returning data.

### Step 9: Tests

Add focused tests to `src/zip_wbtest.mbt`.

Required tests:

- Classic ZIP roundtrip still passes.
- `unzip_list` reads a hand-built ZIP64 archive with:
  - ZIP64 EOCD.
  - ZIP64 locator.
  - ZIP64 extra field carrying sizes.
- `unzip_sync` extracts a small stored file from a ZIP64 archive.
- `unzip_sync` extracts a small deflated file from a ZIP64 archive.
- ZIP64 extra field parser handles:
  - only uncompressed size needed.
  - uncompressed and compressed size needed.
  - uncompressed, compressed, and local header offset needed.
  - unrelated extra fields before ZIP64 field.
- ZIP64 extra field parser rejects a single entry's total extra-field length
  above `max_extra_field_length` with `ExtraFieldTooLong`.
- Missing required ZIP64 extra field raises `InvalidZipData`.
- Truncated ZIP64 EOCD raises `InvalidZipData` or `UnexpectedEOF`.
- Wrong ZIP64 locator signature raises `InvalidZipData`.
- A classic archive with exactly `65535` entries, normal 32-bit central
  directory size/offset fields, and no ZIP64 locator is treated as classic
  metadata rather than rejected.
- If classic central directory size or offset uses `0xffffffff`, missing or
  invalid ZIP64 locator/EOCD raises `InvalidZipData`.
- EOCD-like signature bytes inside an EOCD comment are ignored unless the
  candidate's comment length exactly reaches `data.length()`.
- Multi-disk ZIP64 archive raises `InvalidZipData`.
- ZIP64 values that are structurally valid but too large for the current sync
  API raise `Zip64ValueTooLarge`.
- `unzip_sync` on a ZIP64 archive with an unsafe path still raises path
  traversal error before returning any files. `unzip_list` keeps reporting names
  as untrusted metadata and should have a separate compatibility test covering
  this behavior.
- Encrypted ZIP entry (general-purpose bit 0) raises `InvalidZipData`.
- Data-descriptor entry (general-purpose bit 3) follows the Phase 1 decision:
  either extracts/lists correctly using central-directory metadata with tests,
  or raises `InvalidZipData` consistently.
- Central directory header with bad signature or truncated filename/extra/comment
  raises `InvalidZipData` or `UnexpectedEOF` instead of panicking.
- `unzip_sync` rejects stored and deflated entries whose uncompressed size
  exceeds `default_max_output_size`, and the deflated path passes
  `default_max_output_size` to `inflt` as the output cap.
- `zip_sync` sanitizes user-provided extra field id `0x0001` according to the
  reserved-field rule and emits exactly one coherent ZIP64 extra field per
  header when ZIP64 metadata is needed.
- `zip_sync_checked` raises `ExtraFieldTooLong` when user extras plus
  generated ZIP64 extras would exceed `max_extra_field_length` for a local or
  central header.
- `zip_sync_checked` raises `Zip64ValueTooLarge` for layout arithmetic overflow
  or final archive sizes that cannot fit the current sync API.
- `zip_sync` delegates to the same raising builder as `zip_sync_checked`; when
  that builder raises, `zip_sync` fails deterministically with the documented
  trap/abort message and never emits corrupt output.
- A test-only forced-ZIP64 `zip_sync` output can be fed directly into
  `unzip_sync`, and the extracted filenames and bytes match the original input
  exactly. This catches writer/reader disagreement on sentinels and extra-field
  ordering before cross-tool golden fixtures are added.
- `zip_sync` writes valid ZIP64 EOCD and locator when a test-only path forces
  ZIP64 metadata.
- `zip_sync` emits ZIP64 metadata when entry count is exactly `0xffff`; it does
  not write an ambiguous classic EOCD with literal `0xffff` counts.
- `zip_sync` stamps `version_needed = 45` (low byte) for any header that
  carries ZIP64 sentinels or a ZIP64 extra field, and stamps the central
  directory `version made by` low byte to `45` while preserving `opts.os` in
  the high byte. Classic (non-ZIP64) entries still stamp `20` in `version
needed` and in the **low byte** of `version made by`; the high byte of
  `version made by` always carries `opts.os` regardless of ZIP64. This
  protects the per-entry version logic from regressing during future
  refactors of `wzh`.
- `zip_sync` writes the raw `mtime` field with a fixed-width 4-byte writer while
  preserving the existing simplified timestamp semantics.

Preferred fixture strategy:

Use three fixture layers, and introduce the relevant layer with the PR that
first needs it rather than deferring all interop evidence to a final fixture PR.

1. **Hand-built boundary fixtures.** Build small byte arrays directly in test
   helpers using fixed-width writers. Keep them readable by composing local
   header, file bytes, central directory, ZIP64 EOCD, locator, and classic EOCD
   in named helper functions. Use these for malformed signatures, truncated
   records, missing ZIP64 extra fields, `Zip64ValueTooLarge`, EOCD comment
   false positives, multi-disk rejection, and the classic 65535-entry
   compatibility case. Avoid allocating huge buffers.
2. **fzip forced-ZIP64 fixtures.** Add a test-only internal helper that forces
   small archives to use ZIP64 metadata. Use this to prove the fzip writer and
   reader agree on sentinels, local/central ZIP64 extra-field ordering,
   ZIP64 EOCD/locator emission, and version bytes before cross-tool fixtures
   are added.
3. **Cross-tool golden archives.** Commit a small set of fixed reference ZIP64
   archives generated by other tools and assert fzip can list/extract them
   byte-for-byte. Hand-built fixtures only prove the parser handles specific
   byte patterns; fzip-generated fixtures only prove internal self-consistency.
   Cross-tool golden archives catch interop issues caused by under-specified
   behavior or differing field-order interpretations. Required baseline:
   - One Python `zipfile` fixture generated with `force_zip64=True` on
     `ZipFile.open(..., 'w')`.
   - One independent third-party fixture from 7-Zip (`7z a -tzip`) or Info-ZIP
     when the local `zip -v` build reports `ZIP64_SUPPORT`.
   - A generator script or documented command, tool version, fixture SHA-256,
     expected filenames/sizes/content hashes, and maximum fixture size so binary
     archives remain reproducible and reviewable.

### Step 10: Validation Commands

Run these after phase 1 implementation:

```bash
moon check --warn-list +73
moon test src --filter '*zip*'
moon test
moon fmt
moon info
git diff -- src/pkg.generated.mbti src/error.mbt src/zip.mbt src/bits.mbt src/constants.mbt src/types.mbt src/zip_wbtest.mbt README.md CHANGELOG.md
```

If `moon info` changes public interfaces, verify they are expected.

## Phase 2: True Large File And Archive Support

Phase 2 should introduce streaming ZIP APIs. This is required for real large
files because the current sync APIs allocate complete input/output buffers.

### Prerequisites

Full deflated ZIP streaming cannot land before the DEFLATE engine itself
supports streaming. The current `dflt` (`src/deflate.mbt`) and `inflt`
(`src/inflate.mbt`) are one-shot: they take the full input as a
`FixedArray[Byte]` and return the full output. A streaming `ZipWriter` for
deflated entries needs:

1. A streaming compressor that accepts incremental chunks and emits compressed
   bytes incrementally — likely an `IncrementalDeflate` state object built on
   top of the existing LZ77 hash chain plus block writers.
2. A streaming inflater for the reader path. Although `InflateState` exists for
   the one-shot `inflt` implementation, the current `InflateStream` API buffers
   chunks and calls `inflate_sync` at the final push. Phase 2 needs a real
   incremental inflater that can pause mid-block, resume with later chunks, and
   produce output without first concatenating the whole compressed input.

These are sizable pieces of work (each comparable to the current `dflt` /
`inflt` modules). Plan them as separate prerequisite PRs before adding
deflated streaming to `ZipWriter`. The first version of `ZipWriter` may
legitimately ship with **stored entries only** to unblock the ZIP64 streaming
path, and add deflated streaming once the prerequisites are in place.

### Streaming Writer API Sketch

```mbt nocheck
///|
pub(all) struct ZipWriter {
  mut ondata : FlateStreamHandler?
  ...
}

///|
pub fn ZipWriter::new(opts? : ZipWriterOptions = ZipWriterOptions::default()) -> ZipWriter
///|
pub fn ZipWriter::add_file_begin(self : ZipWriter, name : String, opts? : ZipEntryOptions) -> Unit raise FzipError
///|
pub fn ZipWriter::add_file_chunk(self : ZipWriter, chunk : FixedArray[Byte]) -> Unit raise FzipError
///|
pub fn ZipWriter::add_file_end(self : ZipWriter) -> Unit raise FzipError
///|
pub fn ZipWriter::finish(self : ZipWriter) -> Unit raise FzipError
```

Implementation requirements:

- Track archive offsets with `Int64`.
- Track per-entry compressed and uncompressed sizes with `Int64`.
- Update CRC-32 incrementally.
- Emit local header before file data.
- Emit central directory and EOCD on `finish`.
- Use ZIP64 automatically when offsets, counts, or sizes cross classic limits.
- Avoid buffering complete files.
- Use **data descriptors** (APPNOTE §4.3.9) when the entry size is unknown at
  the time the local header is written — which is the common streaming case.
  Set general-purpose bit flag bit 3 (`0x0008`) in the local header, write
  zeros for `crc32` / `compressed_size` / `uncompressed_size`, then emit the
  data descriptor (optional `0x08074B50` signature + CRC + sizes) immediately
  after the compressed data. **For ZIP64 entries the data descriptor sizes are
  8 bytes each, not 4** (APPNOTE §4.3.9.2). The central directory still
  contains the real CRC and sizes.

### Streaming Reader API Sketch

```mbt nocheck
///|
pub fn unzip_iter(data_source : ZipReaderSource, onentry : ZipEntryHandler) -> Unit raise FzipError
```

Reader options:

- Central-directory-first reading for seekable sources.
- Sequential local-header reading for non-seekable sources.
- Entry-level callbacks for metadata and chunks.
- Per-entry and total output limits.

This should be designed separately from phase 1 because it affects public API,
error handling, and memory behavior.

## Security Considerations

- Keep path traversal checks before returning extracted data from `unzip_sync`.
  `unzip_list` reports archive metadata only; callers must treat listed names as
  untrusted until they validate or extract through `unzip_sync`.
- Keep compression ratio checks for deflated entries.
- Add explicit checks for `offset + size` overflow before slicing or inflating.
- Reject multi-disk archives.
- Reject encrypted entries unless support is intentionally added.
- Make the data-descriptor policy explicit for Phase 1 and test it. Do not
  silently accept bit 3 without either parsing the descriptor or proving the
  central-directory-first reader does not need it for bounds and checksum
  safety.
- Reject unsupported compression methods as today.
- Consider adding ZIP-specific options later:
  - `max_entries`
  - `max_entry_size`
  - `max_extra_field_length`
  - `max_archive_size`
  - `max_central_directory_size`

## Documentation Updates

After phase 1:

- Update `README.md` to say ZIP64 metadata is supported by sync APIs for
  archives that fit memory.
- Avoid saying fzip supports arbitrary large files until phase 2 exists.
- Add a changelog entry with exact scope:
  - ZIP64 EOCD/locator parsing.
  - ZIP64 extra field parsing.
  - ZIP64 writing for classic ZIP limit overflow.
  - New `zip_sync_checked` checked writer API.
  - `zip_sync` now shares the checked writer builder and traps with a stable
    message instead of returning corrupt output when the builder reports a
    recoverable writer error.
  - Sanitization of user-provided ZIP64 extra field id `0x0001` in `zip_sync`.
  - New `Zip64ValueTooLarge` error code for valid ZIP64 values that exceed the
    sync API's `Int`/`FixedArray` limits.
  - Explicit unsupported behavior for multi-disk ZIP64.

After phase 2:

- Document streaming ZIP writer/reader APIs.
- Document large-file behavior and limits.
- Add examples for stored and deflated large entries.

## Suggested PR Breakdown

Each PR is annotated with the Step(s) it covers from Phase 1.

1. **ZIP constants and fixed-width byte helpers** — Steps 1 + 2.
   `w2`/`w4`/`w8` in `bits.mbt`, `zip64_to_int` / `read_zip64_int` helpers,
   `write_zip64_int`, `Zip64ValueTooLarge`, and the non-breaking constant alias
   migration.
2. **Shared EOCD and ZIP64 EOCD parsing** — Steps 3 + 4.
   Introduces `ZipCdInfo` / `ZipEntryHeader` (Step 3) plus `find_eocd` and
   `read_central_directory_info` (Step 4); folds the new structs in here so
   they ship with their first consumer rather than as orphans. Include
   hand-built EOCD/locator boundary fixtures and at least one cross-tool golden
   archive that exercises ZIP64 EOCD discovery.
3. **ZIP64 central directory extra field parsing** — Step 5.
   `ZipEntrySizes`, `read_zip64_entry_extra`, and the `zh` rewrite that calls it.
   Include hand-built conditional extra-field fixtures and a Python
   `force_zip64=True` golden archive that proves fzip handles real local/central
   ZIP64 extra-field layout.
4. **Bounds checks for local headers and compressed data ranges** — Step 6.
   `local_data_offset` and the surrounding validation.
   5a. **Writer layout refactor without ZIP64 emission** — first slice of Step 7.
   Convert `zip_sync`'s internal layout calculation to `Int64`, split the
   layout/build phases, and keep emitted archives byte-for-byte classic ZIP
   compatible for existing test cases.
   5b. **Writer fixed-width metadata cleanup** — second slice of Step 7. Add
   per-entry version-needed/version-made-by byte handling, switch remaining ZIP
   metadata fields such as raw `mtime` to fixed-width writers, and sanitize
   reserved user-provided `0x0001` extra fields while still emitting classic ZIP
   metadata only.
   5c. **ZIP64 writer emission** — final slice of Step 7. Emit sentinels,
   local/central ZIP64 extra payloads, ZIP64 EOCD/locator records, add the
   shared raising builder, expose `zip_sync_checked`, define the non-raising
   `zip_sync` trap/abort wrapper behavior, include the forced-ZIP64 write-read
   round-trip test, and verify the emitted archive with at least one external
   tool fixture/check when available.
5. **Fixture reproducibility and README/CHANGELOG updates** — Step 9 + Step 10
   validation, plus generator scripts, SHA-256 metadata, fixture size notes, and
   documentation updates. This PR should polish fixture provenance, not be the
   first place cross-tool ZIP64 evidence appears.
6. **Separate PR for streaming writer design and implementation** — Phase 2.
   See the Phase 2 prerequisites section before starting.

## Acceptance Criteria For Phase 1

- `moon test` passes.
- Existing classic ZIP archives still roundtrip.
- Hand-built ZIP64 fixtures list and extract correctly.
- Cross-tool golden ZIP64 fixtures from Python `zipfile` and at least one
  independent ZIP tool list/extract correctly, with fixture provenance and
  SHA-256 recorded.
- Malformed ZIP64 metadata returns `FzipError` instead of panicking.
- Multi-disk ZIP64 archives are rejected.
- Existing public sync API function signatures remain source-compatible.
- Additive public API changes such as `zip_sync_checked`, new public constants,
  or `Zip64ValueTooLarge` are documented because downstream exhaustive pattern
  matches without a wildcard may need updating.
- Documentation clearly states that true large-file streaming support is future
  work.
