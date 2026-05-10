#!/bin/sh
# Generate a small ZIP64 archive with Info-ZIP `zip`. Only runs when the
# local build advertises ZIP64_SUPPORT (some Linux distros ship a
# minimal build that omits it).
#
# Usage:  sh gen-zip.sh output/infozip-zip64.zip
#
# The script prints the archive's SHA-256 to stdout so the value can be
# recorded in provenance.md. Generated archives are NOT committed to the
# repository — see the project root .gitignore.

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <output-path>" >&2
    exit 2
fi

out_path="$1"
out_dir="$(dirname "$out_path")"
mkdir -p "$out_dir"

# Resolve to an absolute path before the script `cd`s into the temp dir
# below — zip writes relative to its CWD, so an absolute target keeps
# the output where the caller asked for it regardless of CWD changes.
case "$out_path" in
    /*) abs_out="$out_path" ;;
    *)  abs_out="$(pwd)/$out_path" ;;
esac

if ! command -v zip >/dev/null 2>&1; then
    echo "skip: 'zip' is not installed" >&2
    exit 0
fi

if ! zip -v 2>&1 | grep -q ZIP64_SUPPORT; then
    echo "skip: Info-ZIP zip on this host was built without ZIP64_SUPPORT" >&2
    exit 0
fi

# Build a temporary tree, then ask Info-ZIP to force ZIP64 entries with -fz.
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zip64-fixtures)"
trap 'rm -rf "$tmp_dir"' EXIT

printf 'Hello, ZIP64!\n' > "$tmp_dir/hello.txt"
# Sixteen bytes of recognisable counter data (mirrors gen-python.py).
printf '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f' \
    > "$tmp_dir/data.bin"

# Pin both source mtimes to 1980-01-01 00:00:00 so the embedded DOS
# timestamps are reproducible across runs (matches the gen-python.py
# default, which uses ZipInfo's default date_time of 1980-01-01).
touch -t 198001010000.00 "$tmp_dir/hello.txt" "$tmp_dir/data.bin"

# -X strips OS-specific extras so the archive bytes are reproducible.
# -fz forces ZIP64 entries even though the data is tiny.
(cd "$tmp_dir" && zip -X -fz "$abs_out" hello.txt data.bin >/dev/null)

size=$(wc -c < "$out_path" | tr -d ' ')
if command -v sha256sum >/dev/null 2>&1; then
    digest=$(sha256sum "$out_path" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    digest=$(shasum -a 256 "$out_path" | awk '{print $1}')
else
    digest="(no sha256sum/shasum available)"
fi

echo "wrote $out_path ($size bytes)"
echo "sha256=$digest"
