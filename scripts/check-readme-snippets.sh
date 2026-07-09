#!/usr/bin/env bash
#
# check-readme-snippets.sh — verify that every ```swift code block in the
# DocC landing page (Sources/ZcashPaymentURI/Documentation.docc/ZcashPaymentURI.md)
# appears verbatim somewhere in README.md, so the README's "Quick start"
# snippets can never silently drift from the DocC source they were copied
# from.
#
# This is intentionally one-directional: README.md may contain prose and
# markup the DocC page doesn't have, but every fenced swift block in the DocC
# page must be byte-for-byte present in README.md.
#
# Usage:
#   scripts/check-readme-snippets.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOCC_SOURCE="$REPO_ROOT/Sources/ZcashPaymentURI/Documentation.docc/ZcashPaymentURI.md"
README="$REPO_ROOT/README.md"

for f in "$DOCC_SOURCE" "$README"; do
    if [[ ! -f "$f" ]]; then
        echo "error: expected file not found: $f" >&2
        exit 1
    fi
done

# Extract the Nth ```swift ... ``` fenced block (1-indexed) from a file as
# raw lines (fences excluded), using grep -n to locate fence line numbers and
# sed to slice between them. Pure grep/sed, no python/perl dependency.
extract_block() {
    local file="$1" n="$2"
    local start end
    start="$(grep -n '^```swift$' "$file" | sed -n "${n}p" | cut -d: -f1)"
    if [[ -z "$start" ]]; then
        return 1
    fi
    end="$(grep -n '^```$' "$file" | awk -F: -v s="$start" '$1 > s { print $1; exit }')"
    if [[ -z "$end" ]]; then
        return 1
    fi
    sed -n "$((start + 1)),$((end - 1))p" "$file"
}

block_count="$(grep -c '^```swift$' "$DOCC_SOURCE" || true)"
if [[ "$block_count" -eq 0 ]]; then
    echo "error: no \`\`\`swift blocks found in $DOCC_SOURCE" >&2
    exit 1
fi

missing=0
for ((i = 1; i <= block_count; i++)); do
    block="$(extract_block "$DOCC_SOURCE" "$i")"
    if [[ -z "$block" ]]; then
        echo "error: could not extract swift block #$i from $DOCC_SOURCE" >&2
        missing=$((missing + 1))
        continue
    fi

    # Write the block to a temp file and use grep -F -x -z-style whole-block
    # containment: grep -F -f treats each line of the pattern file as a
    # separate alternation, which is not what we want for a multi-line
    # verbatim match, so instead we check that the block's lines appear as a
    # contiguous run in README.md via `grep -F -x -c` over a sliding window
    # using `comm`-free plain text containment through `fgrep -c` on a
    # flattened, uniquely-joined representation.
    joined_block="$(printf '%s' "$block" | tr '\n' '\x01')"
    joined_readme="$(tr '\n' '\x01' < "$README")"

    if [[ "$joined_readme" != *"$joined_block"* ]]; then
        echo "error: DocC swift block #$i is not present verbatim in README.md:" >&2
        echo "---" >&2
        printf '%s\n' "$block" >&2
        echo "---" >&2
        missing=$((missing + 1))
    fi
done

if [[ "$missing" -gt 0 ]]; then
    echo "error: $missing of $block_count DocC swift code block(s) not found verbatim in README.md." >&2
    echo "README.md's Quick start snippets must be copied EXACTLY from" >&2
    echo "Sources/ZcashPaymentURI/Documentation.docc/ZcashPaymentURI.md." >&2
    exit 1
fi

echo "OK: all $block_count DocC swift code blocks found verbatim in README.md."
