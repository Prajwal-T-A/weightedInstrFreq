#!/usr/bin/env bash
# =============================================================================
# build.sh — Build the WeightedInstrFreqPass LLVM plugin
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$REPO_ROOT/build"

# ─── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Weighted Instruction Frequency Pass — Build        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ─── Detect LLVM cmake dir ───────────────────────────────────────────────────
detect_llvm_dir() {
    # 1) Explicit env variable
    if [[ -n "${LLVM_DIR:-}" ]]; then
        info "Using LLVM_DIR from environment: $LLVM_DIR"
        echo "$LLVM_DIR"
        return
    fi

    # 2) Homebrew (macOS)
    if command -v brew &>/dev/null; then
        local BREW_LLVM
        BREW_LLVM="$(brew --prefix llvm 2>/dev/null || true)"
        if [[ -n "$BREW_LLVM" && -f "$BREW_LLVM/lib/cmake/llvm/LLVMConfig.cmake" ]]; then
            info "Detected Homebrew LLVM at $BREW_LLVM"
            echo "$BREW_LLVM/lib/cmake/llvm"
            return
        fi
    fi

    # 3) llvm-config on PATH
    if command -v llvm-config &>/dev/null; then
        local PREFIX
        PREFIX="$(llvm-config --prefix)"
        if [[ -f "$PREFIX/lib/cmake/llvm/LLVMConfig.cmake" ]]; then
            info "Detected LLVM via llvm-config at $PREFIX"
            echo "$PREFIX/lib/cmake/llvm"
            return
        fi
    fi

    # 4) Common system paths
    for DIR in /usr/lib/llvm-*/lib/cmake/llvm /usr/local/lib/cmake/llvm; do
        # shellcheck disable=SC2086
        for CANDIDATE in $DIR; do
            if [[ -f "$CANDIDATE/LLVMConfig.cmake" ]]; then
                info "Found LLVM cmake files at $CANDIDATE"
                echo "$CANDIDATE"
                return
            fi
        done
    done

    error "Could not find LLVM. Set LLVM_DIR to point to your LLVMConfig.cmake directory, or install LLVM via Homebrew: brew install llvm"
}

LLVM_CMAKE_DIR="$(detect_llvm_dir)"

# ─── Configure ───────────────────────────────────────────────────────────────
info "Configuring CMake in $BUILD_DIR …"
cmake -S "$REPO_ROOT" -B "$BUILD_DIR" \
    -DLLVM_DIR="$LLVM_CMAKE_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    "$@"

# ─── Build ───────────────────────────────────────────────────────────────────
info "Building …"
cmake --build "$BUILD_DIR" --parallel "$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"

# ─── Verify output ────────────────────────────────────────────────────────────
PLUGIN=""
for EXT in dylib so dll; do
    CANDIDATE="$BUILD_DIR/WeightedInstrFreqPass.$EXT"
    if [[ -f "$CANDIDATE" ]]; then
        PLUGIN="$CANDIDATE"
        break
    fi
done

if [[ -z "$PLUGIN" ]]; then
    error "Build succeeded but plugin file not found in $BUILD_DIR"
fi

success "Plugin built: $PLUGIN"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo "  ./run.sh tests/test1.ll          # run pass on a test"
echo "  ./run.sh tests/test2.ll          # memory-heavy test"
echo "  ./run.sh --all                   # run all tests"
