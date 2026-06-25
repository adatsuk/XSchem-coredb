#!/bin/bash
set -euo pipefail

export HOME="${HOME:-/home/$(whoami)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_WIN="${XSCHEM_SRC:-$SCRIPT_DIR/xschem-src}"
SRC=$HOME/xschem-src
PREFIX=$HOME/.local

echo "==> Copying sources to WSL filesystem..."
rm -rf "$SRC"
cp -a "$SRC_WIN" "$SRC"

echo "==> Fixing Windows line endings..."
find "$SRC" -type f \( -name '*.sh' -o -name 'configure' -o -name 'Makefile.in' -o -name '*.awk' \) \
  -exec sed -i 's/\r$//' {} +

echo "==> Configuring..."
cd "$SRC"
./configure --prefix="$PREFIX"

echo "==> Building..."
make -j4

echo "==> Installing to $PREFIX ..."
make install

grep -q 'export PATH=.*\.local/bin' "$HOME/.bashrc" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

echo "==> Done."
test -x "$PREFIX/bin/xschem" && "$PREFIX/bin/xschem" -v 2>/dev/null || ls -la "$PREFIX/bin/xschem"
