#!/usr/bin/env python3
"""
coverage-gate.py — the computation half of scripts/coverage-gate.sh.

Reads an `llvm-cov export -format=text` JSON report and enforces 100.00%
LLVM *region* coverage over `Sources/<target>/**`, excluding everything else
(most importantly `Tests/`). Prints the resulting percentage and, when it is
below 100.00%, every file and uncovered line range, then exits 1.

A small, explicit, source-annotated exemption mechanism is supported for the
rare case of a genuinely unreachable defensive branch: a line comment of the
form

    // COVERAGE-EXEMPT: <reason>

marks the NEXT source line's region(s) as exempt from the gate. Exempted
regions are removed from BOTH the numerator and the denominator (they are
simply not counted), so the gate can still read exactly 100.00% with a
documented, auditable list of exceptions. At most 3 exemptions are permitted
across the whole target — more than that fails the gate outright, since the
mechanism exists for last-resort cases, not routine use.
"""

import json
import re
import sys
from pathlib import Path

MAX_EXEMPTIONS = 3
EXEMPT_MARKER = re.compile(r"//\s*COVERAGE-EXEMPT:\s*(.+?)\s*$")

# LLVM region "kind" values (llvm-cov export JSON schema):
#   0 = code, 1 = expansion, 2 = skipped, 3 = gap, 4 = branch.
# Region-coverage percentage (the "regions" column of `llvm-cov report`)
# counts code and gap regions; expansions and branch regions are excluded.
COUNTED_KINDS = {0, 3}


def load_exemptions(source_root: Path) -> dict:
    """Scans every .swift file under `source_root` for `COVERAGE-EXEMPT`
    comments and returns {absolute_file_path: {exempted_line_numbers}} —
    the exemption applies to the line immediately following the comment."""
    exemptions: dict[str, set[int]] = {}
    reasons: list[tuple[str, int, str]] = []

    for path in sorted(source_root.rglob("*.swift")):
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            match = EXEMPT_MARKER.search(line)
            if match:
                exempted_line = index + 2  # 1-based; the line AFTER the comment
                exemptions.setdefault(str(path), set()).add(exempted_line)
                reasons.append((str(path), exempted_line, match.group(1)))

    return exemptions, reasons


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <llvm-cov-export.json> <source-root-dir>", file=sys.stderr)
        return 2

    json_path = Path(sys.argv[1])
    source_root = Path(sys.argv[2]).resolve()

    with json_path.open() as f:
        report = json.load(f)

    exemptions, exemption_reasons = load_exemptions(source_root)
    if len(exemption_reasons) > MAX_EXEMPTIONS:
        print(f"error: {len(exemption_reasons)} COVERAGE-EXEMPT sites found, maximum is {MAX_EXEMPTIONS}:", file=sys.stderr)
        for file, line, reason in exemption_reasons:
            print(f"  {file}:{line}: {reason}", file=sys.stderr)
        return 1

    functions = report["data"][0]["functions"]

    # file -> list of (lineStart, lineEnd, executionCount)
    regions_by_file: dict[str, list[tuple[int, int, int]]] = {}

    for fn in functions:
        filename = fn["filenames"][0]
        resolved = str(Path(filename).resolve())
        if not resolved.startswith(str(source_root) + "/"):
            continue
        for region in fn["regions"]:
            line_start, _col_start, line_end, _col_end, count, _file_id, _expanded_file_id, kind = region
            if kind not in COUNTED_KINDS:
                continue
            regions_by_file.setdefault(resolved, []).append((line_start, line_end, count))

    if not regions_by_file:
        print(f"error: no coverage regions found under {source_root} — check the JSON export path/root", file=sys.stderr)
        return 2

    total_count = 0
    total_covered = 0
    uncovered_by_file: dict[str, list[tuple[int, int]]] = {}
    exempted_count = 0

    for filename, regions in sorted(regions_by_file.items()):
        exempt_lines = exemptions.get(filename, set())
        for line_start, line_end, count in regions:
            # A region may span multiple lines (e.g. a whole `catch { ... }`
            # block is often one region from its opening to closing brace);
            # the exemption applies if the exempted line falls anywhere
            # within it, not only at its exact start line.
            if any(line_start <= exempt_line <= line_end for exempt_line in exempt_lines):
                exempted_count += 1
                continue
            total_count += 1
            if count > 0:
                total_covered += 1
            else:
                uncovered_by_file.setdefault(filename, []).append((line_start, line_end))

    percent = (total_covered / total_count * 100) if total_count else 100.0

    print(f"Region coverage (Sources/ZcashPaymentURI): {total_covered}/{total_count} = {percent:.2f}%")
    if exemption_reasons:
        print(f"COVERAGE-EXEMPT sites ({len(exemption_reasons)}/{MAX_EXEMPTIONS}):")
        for file, line, reason in exemption_reasons:
            print(f"  {file}:{line}: {reason}")

    if percent < 100.0:
        print("\nUncovered regions:", file=sys.stderr)
        for filename in sorted(uncovered_by_file):
            ranges = sorted(uncovered_by_file[filename])
            range_text = ", ".join(
                f"{start}" if start == end else f"{start}-{end}" for start, end in ranges
            )
            print(f"  {filename}: lines {range_text}", file=sys.stderr)
        return 1

    print("100.00% region coverage — gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
