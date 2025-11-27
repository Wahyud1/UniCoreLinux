#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROFILE_DIR="$HERE/archiso"
OUT_DIR="$PROFILE_DIR/out"
WORK_DIR="$PROFILE_DIR/work"

echo "[unicore-builder] cleaning previous build..."
sudo rm -rf "$OUT_DIR" "$WORK_DIR"
mkdir -p "$OUT_DIR" "$WORK_DIR"

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso not found. Install package 'archiso' first."
  exit 1
fi

echo "[unicore-builder] running mkarchiso profile: $PROFILE_DIR"
sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
echo "[unicore-builder] finished. ISO in: $OUT_DIR"
