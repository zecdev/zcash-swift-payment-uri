# Releasing this library

## Pre-release checklist

Before tagging a release, confirm all of the following on the commit you intend to tag:

1. **All CI jobs are green on `main`** for that commit — `test-macos` (both matrix legs),
   `coverage` (the 100% region-coverage gate), `lint` (SwiftLint + swift-format +
   `scripts/check-readme-snippets.sh`), and `docc` (zero-warnings `xcodebuild docbuild`). See
   `.github/workflows/ci.yml`.
2. **`Tests/Vectors` is pinned to a tagged commit** of
   [zecdev/zcash-zip321-test-vectors](https://github.com/zecdev/zcash-zip321-test-vectors) —
   not a branch tip. Check with `git -C Tests/Vectors describe --tags` (or `git submodule status`
   from the repo root) and update the submodule pointer first if it is not pinned to a tag.
3. **`CHANGELOG.md` is finalized**: the `## [<version>] - Unreleased` heading has its date filled
   in (`## [<version>] - YYYY-MM-DD`), and every breaking change, added/changed/removed/fixed item,
   and security note for the release is present under Keep-a-Changelog categories
   (Added/Changed/Removed/Fixed/Security).
4. **DocC builds clean**: `xcodebuild docbuild -scheme zcash-swift-payment-uri -destination
   'generic/platform=macOS'` produces no `warning:` lines (this is also enforced by the `docc` CI
   job, but re-check locally if you touched documentation right before tagging).
5. `README.md`'s Quick Start snippets still match the DocC landing page
   (`scripts/check-readme-snippets.sh`, also enforced by the `lint` CI job).

## With GitHub Workflows

Create an annotated tag following Semantic Versioning. `.github/workflows/release.yml` runs on any
`*.*.*` tag push: it checks out the tag (with submodules), runs `swift test` on `macos-15`'s
ambient Xcode toolchain (the oldest ambient toolchain that supports this package's
`swift-tools-version: 6.0` manifest), and then publishes a GitHub release via
[`ghalactic/github-release-from-tag`](https://github.com/ghalactic/github-release-from-tag#example-release-stabilities),
which produces a pre-release for alpha/beta tags and a full release for SemVer-compliant tags,
using generated release notes.

**Example**

Creating `2.0.0`:

```sh
git tag --annotate --cleanup=whitespace --edit --message "" 2.0.0
git push origin 2.0.0
```

The `--edit` flag opens your editor for the tag message; its content follows the logic
[documented here](https://github.com/ghalactic/github-release-from-tag#release-name-and-body). For
a major version like `2.0.0`, summarize the breaking-change highlights from `CHANGELOG.md` (the
public API reshape, dependency removal, and platform floor bump) in the tag message so the
generated release notes carry that context even before a reader opens the CHANGELOG.

## After releasing

Once `Tests/Vectors` is re-pointed at the published `zecdev/zcash-zip321-test-vectors` repository
(see the note in `.gitmodules`), pin the submodule to the tagged corpus revision that this release
was verified against, rather than tracking a moving branch.
