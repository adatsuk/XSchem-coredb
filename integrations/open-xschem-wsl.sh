#!/bin/bash
# Open a schematic/symbol view in Xschem (WSL).
# Called from Windows LibMan via open-xschem-wsl.bat
#
# Usage:
#   open-xschem-wsl.sh <windows-or-wsl-path>
#
# Paths: derived from this script's location (parent dir = Xschem repo root).
# Optional overrides: XSCHEM_ROOT, XSCHEM_HOME, XSCHEM_RC, COMMONDB_ROOT
#
# Tiny window (1x1 title bar only): corrupted ~/.xschem/geometry — remove
# lines with "1x1+" or set initial_geometry in xschemrc (already set in repo).

set -euo pipefail

export HOME="${HOME:-/home/$(whoami)}"
export PATH="$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XSCHEM_ROOT="${XSCHEM_ROOT:-${XSCHEM_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}}"
XSCHEM_RC="${XSCHEM_RC:-$XSCHEM_ROOT/xschemrc}"

export XSCHEM_ROOT
if [[ -n "${COMMONDB_ROOT:-}" ]]; then
  export COMMONDB_ROOT
fi

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <sch|sym|schematic.core|symbol.core>" >&2
  exit 1
fi

if [[ ! -f "$XSCHEM_RC" ]]; then
  echo "xschemrc not found: $XSCHEM_RC" >&2
  echo "Set XSCHEM_ROOT or XSCHEM_RC if the repo is not next to this script." >&2
  exit 1
fi

INPUT="$1"

# If LibMan passed a Windows path, normalize to WSL (/mnt/c/...).
if [[ "$INPUT" =~ ^[A-Za-z]:[/\\] ]]; then
  if command -v wslpath >/dev/null 2>&1; then
    INPUT="$(wslpath -u "$INPUT")"
  else
    drive="${INPUT:0:1}"
    rest="${INPUT:2}"
    rest="${rest//\\//}"
    INPUT="/mnt/${drive,,}/${rest}"
  fi
fi

INPUT="$(readlink -f "$INPUT" 2>/dev/null || realpath "$INPUT" 2>/dev/null || echo "$INPUT")"

if [[ ! -f "$INPUT" ]]; then
  echo "file not found: $INPUT" >&2
  exit 1
fi

case "$(basename "$INPUT")" in
  *.schematic.core|*.symbol.core)
    export XSCHEM_OPEN_CORE="$INPUT"
    exec xschem --rcfile "$XSCHEM_RC"
    ;;
  *.sch|*.sym)
    export XSCHEM_OPEN_FILE="$INPUT"
    exec xschem --rcfile "$XSCHEM_RC"
    ;;
  *)
    echo "unsupported schematic view: $INPUT" >&2
    exit 2
    ;;
esac
