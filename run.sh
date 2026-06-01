#!/usr/bin/env bash
# =============================================================================
# run.sh — Run the WeightedInstrFreqPass on one or all LLVM IR test files
#
# Usage:
#   ./run.sh                        # interactive: shows help
#   ./run.sh tests/test1.ll         # run on a single file
#   ./run.sh --all                  # run on every .ll file in tests/
#   ./run.sh --all --save           # run all and save output to output/
#   ./run.sh tests/test1.ll --save  # run one and save output
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$REPO_ROOT/build"
TESTS_DIR="$REPO_ROOT/tests"
OUTPUT_DIR="$REPO_ROOT/output"

# ─── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
CYAN='\033[0;36m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ─── Print banner ─────────────────────────────────────────────────────────────
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Weighted Instruction Frequency Analysis Pass       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ─── Find plugin ─────────────────────────────────────────────────────────────
find_plugin() {
    for EXT in dylib so dll; do
        local CANDIDATE="$BUILD_DIR/WeightedInstrFreqPass.$EXT"
        if [[ -f "$CANDIDATE" ]]; then
            echo "$CANDIDATE"
            return
        fi
    done
    error "Plugin not found in $BUILD_DIR — run ./build.sh first"
}

# ─── Find opt ────────────────────────────────────────────────────────────────
find_opt() {
    # 1) LLVM_BIN env
    if [[ -n "${LLVM_BIN:-}" && -x "$LLVM_BIN/opt" ]]; then
        echo "$LLVM_BIN/opt"; return
    fi
    # 2) Homebrew
    if command -v brew &>/dev/null; then
        local BP
        BP="$(brew --prefix llvm 2>/dev/null || true)"
        if [[ -n "$BP" && -x "$BP/bin/opt" ]]; then
            echo "$BP/bin/opt"; return
        fi
    fi
    # 3) PATH
    if command -v opt &>/dev/null; then
        echo "opt"; return
    fi
    error "opt not found. Set LLVM_BIN to your LLVM bin directory, or install LLVM (brew install llvm)."
}

# ─── Parse args ───────────────────────────────────────────────────────────────
RUN_ALL=false
SAVE_OUTPUT=false
TARGET_FILE=""

for ARG in "$@"; do
    case "$ARG" in
        --all)   RUN_ALL=true ;;
        --save)  SAVE_OUTPUT=true ;;
        --help|-h)
            echo "Usage:"
            echo "  ./run.sh                       show this help"
            echo "  ./run.sh tests/test1.ll        run pass on one file"
            echo "  ./run.sh --all                 run all .ll tests"
            echo "  ./run.sh --all --save          run all and save outputs"
            echo "  ./run.sh tests/testX.ll --save run one and save output"
            exit 0 ;;
        -*)
            error "Unknown option: $ARG (use --help for usage)" ;;
        *)
            TARGET_FILE="$ARG" ;;
    esac
done

PLUGIN="$(find_plugin)"
OPT="$(find_opt)"
info "Plugin : $PLUGIN"
info "opt    : $OPT"

# ─── Run function ─────────────────────────────────────────────────────────────
run_on_file() {
    local LL_FILE="$1"
    local BASENAME
    BASENAME="$(basename "$LL_FILE" .ll)"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  Test: $LL_FILE${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if $SAVE_OUTPUT; then
        mkdir -p "$OUTPUT_DIR"
        local OUT_FILE="$OUTPUT_DIR/${BASENAME}_output.txt"
        "$OPT" \
            -load-pass-plugin "$PLUGIN" \
            -passes='function(weighted-instr-freq)' \
            -disable-output \
            "$LL_FILE" 2>"$OUT_FILE"
        cat "$OUT_FILE"
        success "Output saved: $OUT_FILE"
    else
        "$OPT" \
            -load-pass-plugin "$PLUGIN" \
            -passes='function(weighted-instr-freq)' \
            -disable-output \
            "$LL_FILE" 2>&1
    fi
}

# ─── Dispatch ────────────────────────────────────────────────────────────────
if $RUN_ALL; then
    PASS_COUNT=0
    FAIL_COUNT=0
    for LL in "$TESTS_DIR"/*.ll; do
        if run_on_file "$LL"; then
            ((PASS_COUNT++)) || true
        else
            ((FAIL_COUNT++)) || true
        fi
    done
    echo ""
    echo -e "${BOLD}Summary: ${GREEN}${PASS_COUNT} passed${RESET}${BOLD}, ${RED}${FAIL_COUNT} failed${RESET}"
elif [[ -n "$TARGET_FILE" ]]; then
    [[ -f "$TARGET_FILE" ]] || error "File not found: $TARGET_FILE"
    run_on_file "$TARGET_FILE"
else
    echo "No input specified."
    echo ""
    echo "Usage:"
    echo "  ./run.sh tests/test1.ll        # run on a single IR file"
    echo "  ./run.sh --all                 # run on all tests"
    echo "  ./run.sh --all --save          # run all and save outputs"
    echo "  ./run.sh --help                # show this help"
    echo ""
    echo "Available test files:"
    for LL in "$TESTS_DIR"/*.ll; do
        echo "  $LL"
    done
fi
