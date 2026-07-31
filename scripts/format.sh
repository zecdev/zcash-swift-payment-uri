#!/usr/bin/env bash
#
# format.sh — apply the project's swift-format style to Sources/.
#
# Uses the toolchain-bundled `swift format` (Apple swift-format, ships with
# the Swift 6 toolchain) with the repository's `.swift-format` configuration.
# Scoped to Sources/ only, matching .swiftlint.yml's existing `included:` /
# `excluded:` scope (Tests/ is excluded there too — its long test-vector
# string/address literals trip swift-format's line-length check without the
# `ignores_urls`/`ignores_comments` exemptions SwiftLint's `line_length` rule
# has, and formatting the corpus-derived test data isn't the point of S17).
#
# Usage:
#   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/format.sh
#
# CI (the `lint` job) instead runs `swift format lint --strict`, which fails
# the build on any finding rather than silently rewriting files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "==> Formatting Sources/ with swift-format..."
xcrun swift format format \
    --in-place \
    --recursive \
    --configuration "$REPO_ROOT/.swift-format" \
    "$REPO_ROOT/Sources"

echo "==> Done."
