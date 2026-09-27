#!/usr/bin/env bash
# Export a single Windows x64 executable. Requires Godot 4.7.2 and the matching
# Windows export templates installed for the current user.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-${HOME}/godot/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot4 || command -v godot || true)"
fi
if [[ -z "$GODOT" ]]; then
  echo "Set GODOT to a Godot 4.7.2 binary." >&2
  exit 1
fi
mkdir -p "$ROOT/build/windows"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$ROOT/build/windows/ConvoyCommand.exe"
echo "Exported $ROOT/build/windows/ConvoyCommand.exe"
