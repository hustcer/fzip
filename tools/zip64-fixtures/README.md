# ZIP64 cross-tool fixtures

These scripts generate ZIP64 archives with independent third-party tools
so we can test fzip's reader against bytes it never wrote itself.
**Generated archives are deliberately not committed to the repository**
— see the project root `.gitignore` for the exclusion. Generate them
locally when you need to run the cross-tool checks.

## Why two tools

Hand-built fixtures only prove that fzip parses the byte patterns the
test author hand-crafted. fzip-generated forced-ZIP64 fixtures only
prove fzip's writer and reader agree with each other. Cross-tool
fixtures catch silent disagreements with other ZIP implementations on
under-specified behavior, sentinel choices, or extra-field ordering.

The required baseline per `docs/zip64.md` is:

1. **Python `zipfile`** with `force_zip64=True` — the standard library
   path used by countless tools.
2. **Info-ZIP `zip`** — the historical reference implementation; only
   useful when the local `zip -v` build advertises `ZIP64_SUPPORT`.

7-Zip is intentionally not required: it isn't always installed on
contributor machines, and the two tools above already give us
independent coverage.

## Generating fixtures locally

```sh
cd tools/zip64-fixtures

# Python zipfile (always available wherever Python 3 is)
python3 gen-python.py output/python-force-zip64.zip

# Info-ZIP zip (skipped automatically when not built with ZIP64_SUPPORT)
sh gen-zip.sh output/infozip-zip64.zip
```

Both scripts:

- accept the output path as a single argument,
- create a small archive (well under 2 MiB) so the file size is
  reviewable even if it ever does get committed by accident, and
- print the generated archive's SHA-256 to stdout for provenance.

## Expected output (deterministic)

Both generators write the same two entries with mtimes pinned to
1980-01-01 00:00:00 so the produced bytes — and therefore the SHA-256s —
are stable across runs and across hosts (modulo Info-ZIP build flags).

| File                            | Tool                                  | Bytes | SHA-256                                                            |
| ------------------------------- | ------------------------------------- | ----- | ------------------------------------------------------------------ |
| `output/python-force-zip64.zip` | Python `zipfile` (`force_zip64=True`) | 278   | `3e15b0ee932b51a4057944292e6940f36e534b0e947135267b61bf83d9a84055` |
| `output/infozip-zip64.zip`      | Info-ZIP `zip -X -fz`                 | 378   | `94463df34e356968bfdbf20bb2cac6280bde9f799a77722d98fb7be2502ffdcd` |

Both archives store the same two entries:

| Entry       | Uncompressed bytes | Content                                           |
| ----------- | ------------------ | ------------------------------------------------- |
| `hello.txt` | 14                 | `Hello, ZIP64!\n`                                 |
| `data.bin`  | 16                 | `00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f` |

Both archives advertise `version_needed_to_extract = 0x002D` (= 45),
which is APPNOTE.txt's marker for ZIP64.

## Verifying with fzip locally

The canonical SHA-256s above are mirrored in `src/zip64_fixtures_wbtest.mbt`,
which embeds both fixtures as `FixedArray[Byte]` literals and asserts
that fzip's `unzip_list` and `unzip_sync` round-trip them correctly.
That means `moon test` already exercises both fixtures every run — you
do not need to keep generated `.zip` files on disk for CI to catch
regressions.

If you change the generators or want to refresh the embedded copies:

1. Regenerate locally with the scripts above.
2. Confirm the printed SHA-256s match the comment header at the top of
   each `let ..._fixture` block in `src/zip64_fixtures_wbtest.mbt`.
3. If they differ, re-embed the new bytes (a small helper script can
   convert binary to MoonBit byte-array literal form) and update the
   `SHA-256:` comment lines in lockstep.

The forced-ZIP64 round-trip in `src/zip_wbtest.mbt` covers
writer/reader self-consistency; the cross-tool fixtures here add the
independence check on top of that.

## Recording provenance

When adding a new cross-tool fixture, do **not** check the binary into
git. Instead append a row to `provenance.md` (created on first use)
with:

| Field            | Example                                |
| ---------------- | -------------------------------------- |
| Tool + version   | `python 3.13.1`, `zip 3.0`             |
| Generator script | `tools/zip64-fixtures/gen-python.py`   |
| Output path      | `output/python-force-zip64.zip`        |
| Approximate size | `<2 KiB`                               |
| SHA-256          | (the value the generator prints)       |
| Expected entries | `[("hello.txt", 5), ("data.bin", 16)]` |

Reviewers can regenerate locally and compare hashes to confirm the
intended bytes.

## Repository integration (future)

The current policy keeps repo size bounded: scripts in git, binaries
out. If we later want CI to run the cross-tool tests automatically,
the options are:

1. Run the generator scripts inside CI before the test step (works for
   Python; needs `apt-get install zip` for Info-ZIP).
2. Publish the fixtures to an S3 bucket / GitHub release and download
   them on demand. Provenance metadata in `provenance.md` already
   supports this — the SHA-256 verifies the download.
3. Use git-lfs. Out of scope for now; revisit when the fixture set
   grows past a handful of small archives.
