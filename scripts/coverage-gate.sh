#!/usr/bin/env bash
#
# coverage-gate.sh — enforce 100.00% LLVM region coverage on
# Sources/ZcashPaymentURI (Tests/ is excluded).
#
# Usage (from anywhere; the script cd's to the repo root itself):
#   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/coverage-gate.sh
#
# Runs the full test suite with `--enable-code-coverage`, exports the LLVM
# coverage report via `xcrun llvm-cov export -format=text`, and hands it to
# coverage-gate.py, which computes region coverage restricted to
# Sources/ZcashPaymentURI/** and fails (exit 1), listing every file and
# uncovered line range, unless region coverage is exactly 100.00%.
#
# A short, source-annotated exemption mechanism (`// COVERAGE-EXEMPT: …`,
# max 3 sites) is documented in coverage-gate.py.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

CODECOV_DIR="$REPO_ROOT/.build/debug/codecov"

# Discard any coverage state from a previous (possibly filtered/partial)
# `swift test` run — a stale profraw could otherwise silently inflate the
# reported percentage.
rm -rf "$CODECOV_DIR"

echo "==> Running full test suite with code coverage instrumentation..."
swift test --enable-code-coverage

BIN_PATH="$(swift build --show-bin-path)"

XCTEST_BUNDLE="$(find "$BIN_PATH" -maxdepth 1 -name '*PackageTests.xctest' | head -n 1)"
if [[ -z "$XCTEST_BUNDLE" ]]; then
    echo "error: no *PackageTests.xctest bundle found under $BIN_PATH" >&2
    exit 1
fi
BUNDLE_NAME="$(basename "$XCTEST_BUNDLE" .xctest)"
TEST_BINARY="$XCTEST_BUNDLE/Contents/MacOS/$BUNDLE_NAME"

PROFDATA="$BIN_PATH/codecov/default.profdata"
if [[ ! -f "$PROFDATA" ]]; then
    echo "error: no merged profile data found at $PROFDATA" >&2
    exit 1
fi

echo "==> Exporting LLVM coverage report..."
COVERAGE_JSON="$(mktemp -t zcash-swift-payment-uri-coverage).json"
trap 'rm -f "$COVERAGE_JSON"' EXIT

xcrun llvm-cov export -format=text -instr-profile "$PROFDATA" "$TEST_BINARY" > "$COVERAGE_JSON"

echo "==> Computing region coverage for Sources/ZcashPaymentURI..."
python3 "$SCRIPT_DIR/coverage-gate.py" "$COVERAGE_JSON" "$REPO_ROOT/Sources/ZcashPaymentURI"
