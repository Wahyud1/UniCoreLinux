#!/usr/bin/env bash
#
# Simple mkarchiso wrapper for building a UniCore ISO from the scaffold.
# Requires mkarchiso installed on the host.
#
set -Eeuo pipefail
PROFILE_DIR="$(cd "$(dirname "$0")" && pwd)/archiso"
WORK_DIR="$PROFILE_DIR/work"
OUT_DIR="$PROFILE_DIR/out"

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso not found. Install it from official repos or AUR."
  exit 1
fi

mkdir -p "$WORK_DIR" "$OUT_DIR"
pushd "$PROFILE_DIR" >/dev/null
echo "Running mkarchiso in: $PROFILE_DIR"
sudo mkarchiso -v .
popd >/dev/null
echo "ISO build finished. Check $OUT_DIR for output."
