#!/usr/bin/env bash
# Configure, build, and install xschem into dist-install (CI / Rocky Linux 8).
set -euo pipefail

ROOT="${XSCHEM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC="$ROOT/xschem-src"
PREFIX="${INSTALL_PREFIX:-$ROOT/dist-install}"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: xschem sources not found at $SRC" >&2
  exit 1
fi

find "$SRC" -type f \( -name '*.sh' -o -name 'configure' -o -name 'Makefile' -o -name 'Makefile.in' -o -name '*.awk' \) \
  -exec sed -i 's/\r$//' {} +

(cd "$SRC" && chmod +x configure && ./configure --prefix="$PREFIX")
make -C "$SRC" -j"$(nproc)"
make -C "$SRC" install

test -x "$PREFIX/bin/xschem"
echo "Installed xschem to $PREFIX/bin/xschem"
