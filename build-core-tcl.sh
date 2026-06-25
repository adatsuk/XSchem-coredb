#!/bin/bash
# Build coretcl.so (in-process CORE API for Xschem) inside WSL.
set -euo pipefail

export HOME="${HOME:-/home/$(whoami)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XSCHEM_ROOT="${XSCHEM_ROOT:-$SCRIPT_DIR}"
XSCHEM_INT="${XSCHEM_ROOT}/integrations"
CORE_ROOT="${COMMONDB_ROOT:-${CORE_ROOT:-$(cd "$XSCHEM_ROOT/../CommonDB" && pwd)}}"
BUILD="$CORE_ROOT/build-wsl"
CAPNP_LINUX="$CORE_ROOT/third_party/capnp-install-linux"

echo "==> Xschem root:  $XSCHEM_ROOT"
echo "==> CommonDB root: $CORE_ROOT"

echo "==> Checking build dependencies..."
missing=()
command -v cmake >/dev/null || missing+=("cmake")
command -v g++ >/dev/null || missing+=("g++")
command -v make >/dev/null || missing+=("make")
pkg-config --exists tcl 2>/dev/null || [ -f /usr/include/tcl.h ] || missing+=("tcl-dev")
if ((${#missing[@]})); then
  echo "Missing packages: ${missing[*]}" >&2
  echo "Install: sudo apt install cmake build-essential tcl-dev git" >&2
  exit 1
fi

if [[ ! -x "$CAPNP_LINUX/bin/capnp" ]]; then
  echo "==> Bootstrapping Cap'n Proto for Linux (first run may take a few minutes)..."
  sed -i 's/\r$//' "$CORE_ROOT/scripts/build_capnp_linux.sh"
  CAPNP_SKIP_CHECK=1 bash "$CORE_ROOT/scripts/build_capnp_linux.sh" \
    "https://github.com/capnproto/capnproto.git" branch master "" "" \
    "$CORE_ROOT/third_party/capnproto-linux" "$CAPNP_LINUX"
fi

echo "==> Configuring CORE (WSL, Tcl extension)..."
cmake -S "$CORE_ROOT" -B "$BUILD" \
  -DCORE_BUILD_XSCHEM_TCL=ON \
  -DCORE_BUILD_EXAMPLES=OFF \
  -DCORE_BOOTSTRAP_CAPNP=OFF \
  -DCAPNP_ROOT="$CAPNP_LINUX" \
  -DCMAKE_BUILD_TYPE=Release

echo "==> Building coretcl.so..."
cmake --build "$BUILD" --target coretcl -j"$(nproc)"

SO="$BUILD/integrations/xschem_tcl/coretcl.so"
if [[ ! -f "$SO" ]]; then
  echo "coretcl.so not found at $SO" >&2
  exit 1
fi

echo "==> Installing to Xschem integrations..."
cp -f "$SO" "$XSCHEM_INT/coretcl.so"

echo "==> Done: $XSCHEM_INT/coretcl.so"
ls -la "$XSCHEM_INT/coretcl.so"
