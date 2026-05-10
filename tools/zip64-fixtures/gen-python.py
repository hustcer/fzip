#!/usr/bin/env python3
# Generate a small ZIP64 archive using Python's zipfile module with
# force_zip64=True. The output is intentionally tiny (<2 KiB) so the
# emitted archive is easy to inspect by hand or with a hex editor.
#
# Usage:  python3 gen-python.py output/python-force-zip64.zip
#
# The script prints the archive's SHA-256 to stdout so the value can be
# recorded in provenance.md. Generated archives are NOT committed to the
# repository — see the project root .gitignore.

from __future__ import annotations

import hashlib
import os
import struct
import sys
import zipfile


def build_archive(out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    # ZIP_STORED keeps the bytes recognisable; force_zip64=True makes
    # zipfile emit ZIP64 metadata even though the entries are tiny.
    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_STORED) as z:
        with z.open(zipfile.ZipInfo("hello.txt"), "w", force_zip64=True) as fp:
            fp.write(b"Hello, ZIP64!\n")
        with z.open(zipfile.ZipInfo("data.bin"), "w", force_zip64=True) as fp:
            # Sixteen bytes of recognisable counter data.
            fp.write(struct.pack("<16B", *range(16)))


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fp:
        for chunk in iter(lambda: fp.read(64 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <output-path>", file=sys.stderr)
        return 2
    out_path = argv[1]
    build_archive(out_path)
    size = os.path.getsize(out_path)
    digest = sha256(out_path)
    print(f"wrote {out_path} ({size} bytes)")
    print(f"sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
