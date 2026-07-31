# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Unreleased

A deliberate breaking-change release: the public API was reshaped to match the cross-language v2
contract shared with the companion [Kotlin library](https://github.com/zecdev/zcash-kotlin-payment-uri),
parsing became a total (non-throwing) operation, every runtime dependency was removed, and
**recipient-address validation was fully delegated to the caller** — this library now implements
the ZIP-321 URI grammar and nothing else. See
`Sources/ZcashPaymentURI/Documentation.docc/MigratingFromV1.md` for a caller-focused migration
guide.

### Added

- **`NonNegativeAmount`** (`Sources/ZcashPaymentURI/model/NonNegativeAmount.swift`): a public, `Equatable`, `Hashable`,
  `Sendable`, `Comparable` wrapper around a `UInt64` zatoshi count — unsigned,
  mirroring the reference implementation's `u64`-backed `Zatoshis`, so negative
  counts are unrepresentable by construction (`NonNegativeAmount.maxMoney` =
  `2_100_000_000_000_000`). `Result`-based factories `NonNegativeAmount.zatoshi(_:)` (raw zatoshi) and
  `NonNegativeAmount.zec(_:)` (decimal ZEC string) enforce the **strict** ZIP-321 `amountparam` grammar
  (`1*DIGIT [ "." 1*8DIGIT ]`) using checked integer arithmetic only; `decimalString()` renders
  exactly like the reference `amount_str`.
- **`ZIP321Error`**: a sealed, data-leakage-free error taxonomy (`invalidBase64`,
  `memoBytesError`, `transparentMemo`, `zeroValuedTransparentOutput`, `tooManyPayments`,
  `duplicateParameter`, `recipientMissing`, `invalidAddress`, `unknownRequiredParameter`,
  `invalidParamIndex`, `amountExceededSupply`, `amountInvalid`, `invalidURI`, `parseError`)
  mirroring the shared cross-language conformance-corpus discriminants. See Security below.
- **`AddressValidator`**, **`AddressDescriptor`**, **`ClosureAddressValidator`** and **`Network`**:
  the delegated address-validation API. `AddressValidator.validate(_:) -> AddressDescriptor?` is the
  sole authority on recipient-address validity — `nil` rejects, and a returned descriptor
  (`network`, `isTransparent`, `canReceiveMemos`) is trusted verbatim and drives the ZIP-321
  payment rules. `Network` (`mainnet`/`testnet`/`regtest`) replaces `ParserContext` as the public
  network selector. `RecipientAddress` now carries `value` + `descriptor`, built either via
  `init?(value:validator:)` or `init(value:descriptor:)`.
- **`ZIP321.parse(_:expecting:validator:maxInputBytes:)`**: a *total* parsing entry point returning
  `Result<PaymentRequest, ZIP321Error>`. The `validator` is REQUIRED — there is no built-in
  validation to default to. Input guards run before any grammar work: input above
  `maxInputBytes` (default `ZIP321.defaultMaxInputBytes` = 8 KiB) fails with
  `.invalidURI(reason: .inputTooLarge)`; empty input fails with `.parseError(reason: .emptyInput)`;
  a non-`zcash:` scheme fails with `.invalidURI(reason: .notZcashScheme)`; a `//` authority
  component fails with `.invalidURI(reason: .invalidAuthority)`.
- **`Payment.create(recipientAddress:amount:memo:label:message:otherParams:)`**: a `Result`-based
  construction factory enforcing the reference `to_payment` rules at construction time — a memo to
  a transparent recipient fails with `.transparentMemo`, and a zero-valued amount to a transparent
  recipient fails with `.zeroValuedTransparentOutput` (a new consensus check, enforced on both the
  construction and parse paths).
- **`Payment.Builder`** (`init(recipient:)` + chainable `amount(_:)`, `amount(zec:)`, `memo(_:)`,
  `memo(utf8:)`, `label(_:)`, `message(_:)`, `otherParam(name:value:)`, terminal
  `build() -> Result<Payment, ZIP321Error>`) and **`PaymentRequest.Builder`** (`add(_:)`
  auto-indexing from `0`, `add(_:at:)` for an explicit `paramindex`, terminal
  `build() -> Result<PaymentRequest, ZIP321Error>`), plus the **`@resultBuilder
  PaymentRequestBuilder`** DSL (`PaymentRequest.build { payment1; payment2 }.get()`) supporting
  `for`-loops and `if`-without-`else`. Fallible inputs are validated lazily at `build()`; when
  several fields are invalid the first error wins in field order (amount → memo → other params →
  structural rules).
- **`PaymentRequest.indexedPayments: [(index: UInt, payment: Payment)]`** and
  **`PaymentRequest.init(indexedPayments:)`**, exposing and accepting explicit, non-contiguous
  ZIP-321 `paramindex` values (validating index uniqueness via `.duplicateParameter` and the
  ≤ 9999 index bound).
- Dependency-free grammar primitives under `Sources/ZcashPaymentURI/parser/`: **`Base64URL`**
  (unpadded RFC 4648 §5 base64url, matching the reference `BASE64_URL_SAFE_NO_PAD`), a single-pass
  byte-level **`Scanner`**, and strict **`AmountParser`**/**`QcharCodec`** (percent-encoding exactly
  the ZIP-321 `qchar` complement) underpinning the URI grammar rewrite.
- Test-only reference address-encoding checkers under
  `Tests/ZcashPaymentURITests/Support/` — **`SHA256`** (a thin wrapper over Apple's CryptoKit),
  **`Base58Check`** (big-integer base58 decode + version-byte + SHA-256d checksum verification) and
  **`Bech32`** (BIP-173/BIP-350 decode-verify with the 1023-character limit matching the `bech32`
  crate v0.11.0 used by `zcash_address`) — composed into a `ReferenceAddressValidator` that the test
  suite and the conformance runner inject. **None of this ships in the library target**; it exists
  so the corpus's deliberately checksum-corrupted, mixed-case, wrong-network and Sprout address
  vectors stay executable against a realistic validator.
- The shared, oracle-verified ZIP-321 conformance corpus
  ([zecdev/zcash-zip321-test-vectors](https://github.com/zecdev/zcash-zip321-test-vectors)),
  consumed as a test-only git submodule at `Tests/Vectors` (the `.gitmodules` URL is a temporary
  local path until that repository is published), plus a conformance test runner
  (`Tests/ZcashPaymentURITests/Conformance/`) that asserts exact error-discriminant agreement and
  byte-identical canonical re-rendering against the librustzcash `zip321` reference. The expected-
  failure ledger, which started at 14 documented divergences, is now **empty**: this implementation
  matches the reference on every corpus vector.
- Deterministic property-style round-trip tests (`PropertyTests.swift`/`PropertyGenerators.swift`):
  a seeded `SplitMix64` PRNG driving eight laws over fixed-seed cases — full parse/render round
  trip, `NonNegativeAmount` decimal round trip, `MemoBytes` base64url round trip, `QcharCodec`
  round trip, `paramindex` preservation, the equality of the two single-recipient spellings, the
  always-array shape of `otherParams`, and an adversarial law asserting that a generated payment
  with a repeated other-param name is rejected by BOTH `Payment.create` and `Payment.Builder`.
  Generated recipients are resolved through the same `ReferenceAddressValidator` the parser is
  handed, so no descriptor is ever hand-written.
- `scripts/coverage-gate.sh` + `scripts/coverage-gate.py`: a machine-checkable gate that runs the
  suite with `swift test --enable-code-coverage`, computes LLVM *region* coverage restricted to
  `Sources/ZcashPaymentURI/**`, and fails, listing every uncovered range, unless coverage is exactly
  100.00%. Supports a bounded (max 3 sites) `// COVERAGE-EXEMPT: <reason>` annotation for genuinely
  unreachable defensive guards.
- A DocC documentation catalog (`Sources/ZcashPaymentURI/Documentation.docc/`): a landing page
  covering the four canonical usage scenarios, a security section, and a `MigratingFromV1.md`
  migration article. `xcodebuild docbuild` completes with **zero warnings**; every public symbol
  has a doc comment.
- `.github/workflows/ci.yml`: four required jobs on `main` and every PR — `test-macos` (macos-15 /
  Xcode 16.4 / Swift 6.1, and macos-26 / Xcode 26.5 / Swift 6.2, both via each runner's ambient
  default Xcode), `coverage` (runs
  `scripts/coverage-gate.sh`), `lint` (SwiftLint `0.65.0` + toolchain `swift format lint --strict`,
  both via plain `docker run`), and `docc` (`xcodebuild docbuild`, fails on any `warning:` line).
  `Tests/Vectors` is checked out via `submodules: recursive`. There is deliberately **no Linux
  test job**: the library target is platform-neutral, but the TEST target's reference
  address-encoding checkers use Apple's CryptoKit, which does not exist on Linux, and Linux was
  never a declared platform of this package (`Package.swift` declares macOS 13 / iOS 16 only). The
  `lint` job still runs on `ubuntu-latest`, but only inside containers — it never builds for Linux.
- `.swift-format`: a project `swift-format` configuration (4-space indent, 150-column lines) and
  `scripts/format.sh` to apply it to `Sources/`.
- `scripts/check-readme-snippets.sh`: verifies every `swift` code block in the DocC landing page
  appears verbatim in `README.md`, wired into the `lint` CI job, so the README's Quick Start
  snippets cannot silently drift from their DocC source.

### Changed

- **Public API reshape (breaking):**
  - **`ParserResult` is deleted and not replaced — parsing returns a `PaymentRequest`.** There is
    no result enum: `zcash:<addr>` and `zcash:?address=<addr>` are two spellings of the SAME
    request per ZIP-321 "URI Semantics", they parse to **equal** `PaymentRequest` values, and the
    model does not record which spelling was used (matching the reference `TransactionRequest`).
    Migration: the `.legacy`/`.request` branches collapse to one value; a bare address URI is a
    one-payment request whose payment carries only a recipient. A single payment at the empty
    paramindex still RENDERS in the leading-address form by default — that choice lives in the
    renderer's formatting options, not in the model.
  - **`ParserContext` is deleted**, along with `RecipientAddress.ValidatingClosure` and the v1
    four-method `AddressValidator` protocol (`isValid`/`isTransparent`/`isSprout`/`isShielded`).
    `Network` + the new `AddressValidator` replace them.
  - The public `ZIP321.Errors` grab-bag is replaced by the sealed `ZIP321Error` taxonomy (see
    Added/Security). Sprout rejection now surfaces as `.invalidAddress` (previously
    `sproutRecipientsNotAllowed`).
  - `Payment.amount` is now `NonNegativeAmount?` (previously `Amount?`/`LegacyAmount?`).
  - `OtherParam` is now a plain `(name: String, value: String?)` (previously `key:
    ParamNameString`, `value: QcharString?`); `label`/`message` are now plain decoded `String?`.
    `QcharString` and `ParamNameString` are no longer public; qchar encoding now happens at render
    time instead of construction time.
  - **`Payment.otherParams` is a non-optional `[OtherParam]`** (default `[]`). ZIP-321 cannot
    spell the difference between "absent" and "empty" — both render to the same URI — so modelling
    both produced two distinct `Payment` values for one URI and broke the round-trip law. Replace
    `otherParams: nil` with `otherParams: []` (or omit it) and `payment.otherParams ?? []` with
    `payment.otherParams`. `Payment.create` additionally **rejects duplicate other-param names**
    with `.duplicateParameter(name:index: nil)`, matching what the parser already enforced for a
    URI, so a `Payment` can no longer be built that renders to a URI which will not parse back.
  - `PaymentRequest` is now stored keyed by `paramindex`; `payments: [Payment]` returns them
    ordered by ascending index. `init(payments:)` still auto-indexes sequentially from `0` and
    enforces the 9999-payment cap (`.tooManyPayments`). **Empty requests are now valid**: `zcash:`
    and `zcash:?` parse to an empty `PaymentRequest` (previously rejected), and render back to
    `zcash:`. The v1 construction-time network-coherence check (`networkMismatchFound`) was
    removed; the expected network is enforced once, at the parse boundary, by comparing each
    recipient's `AddressDescriptor.network` against `expecting:`.
  - The throwing `Payment.init(...)` remains as a **deprecated** shim delegating to `create`.
    `ZIP321.request(from:context:validatingRecipients:)` is **removed** rather than deprecated:
    its result type no longer exists, so no source-compatible shim was possible.
- **Canonical renderer (breaking):** the renderer now renders from `PaymentRequest.indexedPayments`,
  preserving each payment's actual stored `paramindex` (a request whose only payment sits at index
  `5` renders `zcash:?address.5=…&amount.5=1`, previously collapsed onto the empty index). The
  default `formattingOptions` of `uriString(from:)`/`request(_:)` changed to
  `.useEmptyParamIndex(omitAddressLabel: true)` (the canonical reference form); the round-trip law
  `parse(uriString(from: r)) == r` holds under it for every corpus request. `.enumerateAllPayments`
  is now a documented NORMALIZATION mode that re-numbers payments sequentially from `1` and emits
  the mandatory `?` query separator (previously omitted for multi-payment output, producing a
  non-round-trippable URI).
- **Recipient-address validation is fully delegated** (see Security). The library contains no
  Bech32/Bech32m or Base58Check decoding, no SHA-256, no HRP or version-byte tables and no address
  prefix classification; `Parser.onlyCharsetValidation` and its per-kind charset heuristics are
  deleted along with the rest. Address validity and capability classification come from the
  caller's `AddressValidator` and are taken as final: there is no built-in check to compose with,
  and therefore no AND-composition or defense-in-depth semantics to reason about.
- **The ZIP-321 URI tokenizer was rewritten onto `Scanner`**, a single-pass grammar following the
  reference `nom` pipeline, replacing the hand-rolled substring-combinator (`ZParser`) port.
  `label`/`message`/`other` values are now percent-decoded via `QcharCodec`; `address`/`amount`/
  `memo` values are handed to their own grammars verbatim.
- **The parser enforces the strict `amountparam` grammar** via the new `AmountParser`/`NonNegativeAmount.zec`
  path: a leading/trailing decimal point, a sign, whitespace, scientific notation, or a
  percent-escape in an amount are all rejected.
- **`MemoBytes` rewritten on the strict base64url codec** (`Sources/ZcashPaymentURI/model/MemoBytes.swift`):
  `=` padding, impossible lengths, and non-canonical encodings with nonzero trailing bits are now
  rejected (previously silently accepted by Foundation's padded-base64 path). `MemoBytes` accepts
  0 to 512 bytes (consensus zero-pads memos to 512 bytes; an empty memo is well-defined).
- **The conformance claim is stated narrowly.** This implementation is conformant with ZIP-321
  except [`req-asset`](https://zips.z.cash/zip-0321#custom-assets) (ZIP-321 Custom Assets / ZSA),
  which is intentionally rejected with `.unknownRequiredParameter` pending ecosystem support —
  the behaviour ZIP-321's own forward-compatibility rule requires of a parser that does not
  implement a `req-` parameter, and the behaviour of the librustzcash `zip321` reference
  implementation, which does not implement it either. Tracked in
  [#96](https://github.com/zecdev/zcash-swift-payment-uri/issues/96).
- **Conformance corpus synced to the adjudicated revision**: integer-overflow amounts classify as
  `amountExceededSupply`; the spec's fabricated `req-asset` example addresses are documented as
  checksum-invalid; the `AmountParser` overflow special-case was removed accordingly.
- **Breaking (toolchain):** `swift-tools-version` raised to `6.0`; minimum platforms raised to
  macOS 13 / iOS 16.
- **Test suite migrated from XCTest to [swift-testing](https://github.com/swiftlang/swift-testing)**
  (`@Suite`/`@Test`/`#expect`/`#require`); the conformance suite's `XCTExpectFailure`-based
  mechanism was replaced with `withKnownIssue`. Test count was unchanged by the migration itself
  (137 tests before and after); the suite has since grown to 288 tests via the conformance,
  property-test, and coverage work above.
- **CI**: `.github/workflows/ci.yml` replaces `swift.yml` + `swiftlint.yml` (the old macos-14 /
  Swift 5.10 leg is removed outright — Xcode 15.4 cannot build a `swift-tools-version: 6.0`
  manifest at all); `release.yml`'s toolchain setup was updated to match (macos-15, ambient default
  Xcode, `submodules: recursive`). `.swiftlint.yml`'s stale `unused_capture_list` entry (removed
  from SwiftLint itself two years ago) was dropped; no other lint rules were weakened.

### Removed

- **All runtime dependencies.** `zcash-swift-payment-uri` is now a zero-dependency package:
  `swift-parsing`, `swift-case-paths`, `BigDecimal`, `BigInt`, and `swift-custom-dump` have all been
  removed. The only framework the library links is the OS-provided Foundation, which is not a
  package dependency and never enters a consumer's resolved dependency graph. (The TEST target
  additionally uses the OS-provided CryptoKit for its reference address checkers.)
  `swift-docc-plugin` was deliberately **not** added as a `Package.swift` dependency for
  the same reason (SwiftPM resolves a manifest's entire `dependencies:` array regardless of which
  products/plugins a consumer actually uses); `xcodebuild docbuild` needs no manifest change.
- **`Amount`/`LegacyAmount` removed entirely**, replaced by `NonNegativeAmount`. Migration: replace
  `try Amount(value: 1)` / `try LegacyAmount(string: "1.5")` with `try NonNegativeAmount.zec("1.5").get()` or
  `NonNegativeAmount.zatoshi(150_000_000)`.
- **`QcharString` and `ParamNameString` removed from the public surface** (see `OtherParam` above).
- Dead code identified while driving coverage to 100%: an always-succeeding guard in
  `QcharString.init`, a redundant `req-` prefix guard in `Param.from`, an unreachable
  dictionary-subscript guard in `Parser.mapToIndexedPayments`, and the unused
  `NumberFormatter.zcashNumberFormatter` / `String.asQcharString` (dead since the `Amount` removal
  above).

### Fixed

- **`otherparam` rendering now emits the `=` separator** when the parameter carries a value
  (`future-param=hello%20world`), matching the reference `str_param`; a value-less otherparam still
  renders as a bare `name`.
- **A single payment at a non-zero `paramindex` now re-renders faithfully** instead of being
  collapsed onto the empty index.
- **Regtest Sapling addresses now parse**: the parser no longer routes addresses through a
  heuristic charset switch that had no `zr` case — it no longer inspects address text at all.
- **Zero-length memos and empty `qchar` values are now valid**: `memo=`, `message=`, and `label=`
  parse to a payment with an empty (not rejected) value, matching the reference.
- **Checksum-bypassing address acceptance is gone.** v1's HRP-prefix + charset heuristic accepted
  corrupted checksums and mixed-case Bech32. The library no longer approximates address validity at
  all; the corpus's checksum-corruption vectors are now rejected by the injected validator, which
  is the point of the boundary.
- **Signed amount strings are rejected eagerly.** A sign can never begin a valid ZIP-321
  `amountparam`, so it is rejected before any digit-parsing work rather than after: a leading
  `-` fails with a negative-amount error and a leading `+` with an invalid-input error. The
  strict `NonNegativeAmount` grammar that now backs every amount rejects both forms outright.
- **The amount path is fully covered by tests, and `Sources/` is lint-clean.** Amount parsing
  is exercised across every construction and rejection shape (malformed decimal shapes,
  non-finite doubles, the zero constant, rounding, boundary and overflow values), and
  `Sources/ZcashPaymentURI` is held at 100% region coverage by `scripts/coverage-gate.sh`
  with SwiftLint and `swift-format` clean in CI.

### Security

- **Address validation is the caller's, and it is authoritative.** URI parsing requires
  caller-provided Zcash address validation and capability classification: the library implements
  the ZIP-321 URI grammar and performs no address validation of its own. A validator returning
  `nil` rejects the address (`.invalidAddress`); a returned `AddressDescriptor` is trusted verbatim
  and its `canReceiveMemos` / `isTransparent` drive the transparent-memo and
  zero-valued-transparent-output rules. Nothing re-checks the address afterwards — there is no
  fallback, no "and also", and no defense-in-depth composition, because a URI parser shipping its
  own address tables would be a second, weaker source of truth beside the wallet's real one, and
  the two could disagree. **Wallets should delegate to their Zcash SDK** (librustzcash
  `ZcashAddress` via the mobile SDKs' FFI/JNI bindings), the only component that can decode Unified
  Address receivers and decide which address kinds the wallet will pay. The one rule applied on top
  of the validator's verdict is a comparison, not a validation: an accepted address whose
  `AddressDescriptor.network` differs from the `expecting:` network makes the request invalid.
- **Errors never carry sensitive input.** The sealed `ZIP321Error` taxonomy is constructed so that
  no case can carry an address, memo contents, an amount, or a raw URI slice — only parameter
  names, indices, counts, or fixed `StaticReason` values (the one bounded exception,
  `invalidParamIndex(raw:)`, is capped at a few characters by the ZIP-321 grammar).
- **A bounded input size.** `ZIP321.parse` rejects input above `maxInputBytes` (8 KiB by default)
  before any grammar or address-validation work runs, bounding the cost of parsing adversarial
  input.
- **Zero runtime dependencies**, minimizing supply-chain surface: the library links nothing beyond
  the Swift standard library and the OS-provided Foundation framework.
- **100% region test coverage**, deterministic property-based round-trip tests, and full agreement
  with the shared, oracle-verified cross-language conformance corpus, enforced as required CI gates
  on every pull request.

## 1.0.0
This release contains several **API breaking changes**, but let not be discouraged to
update! These changes are made to add several checks to the library to ensure that your payment
requests stick to the ZIP-320 specification.

This version has been audited by Least Authority. You can find the audit results
[here](Docs/Least Authority -ZCG Kotlin and Swift Payment URI Prototypes Final Audit Report.pdf)
### Added
- Create `ParserContext` enum which enables definitions that are network-dependent 
- Create `AddressValidator` Protocol to define address validators.
0- Add `ParserContext` to RecipientAddress initializer and to parser methods that are
context-aware
- `QcharString` struct represents a String value that is validated to be a
qchar-encoded string
- `ParamNameString` struct represents a String value that is validated to be a
`paramname` string in terms of ZIP-321

### Changed
- ``ZIP321``:
  - now supports optional values on `otherparam`.
  - accepts optional ``Amount`` on payments
- ``Param`` is now an enum whose associated values are "checked" types.
- ``OtherParam`` now has key type of ``ParamNameString`` and value of ``QcharString``
- ``ZIP312.Errors`` no has error cases:
  - `case qcharEncodeFailed(String)`: when qchar encoding fails
  - `case otherParamUsesReservedKey(String)`: for catching reserved keys on `OtherParam`
  - `case otherParamEncodingError`:for encoding errors
  - `case otherParamKeyEmpty`: when an empty key is detected
- `RecipientAddress` enforces a minimum validation of the (supposedly) string-encoded Zcash addresses
that can guarantee that the correct HRPs and character sets are present in the given strings.
- `PaymentRequest` individual payments are checked to ensure they all belong to the same network.
Network is determined by the HRP of the addresses.
- HRPs of `RecipientAddress` are verified to determine whether they could belong to a certain network 
and/or Zcash pool. 
- **Important:** Formal verification still must be provided by callers. The checks included by 
``AddressValidator`` default implementation does not check Bech32 validity. 
- `Payment` has `Amount?` to represent payment requests with undefined amount by the request author.


## [0.1.0-beta.10] - 2024-11-26

- [#69] Fix: Base64URL valid characters are not properly validated
- [#67] Add SECURITY.md

## [0.1.0-beta.9] - 2024-09-03

- [#64] maintain iOS 15 compatibility
    
    Lukas Korba from ECC reported that Zashi couldn't be built since
    the latest version of BigDecimal depend on BigInt which has min
    deployment target of iOS 16.4. We temporarily locked this dependency
    until we could figure out a long term change.
    
## [0.1.0-beta.8] - 2024-07-01


- [#55] make Payment public and give it a public initializer
- [#60] Amount(value: Double) false positive tooManyFractionalDigits
- [#62] public-payments-fix by @lukaskorba 


## [0.1.0-beta.7] - 2024-06-07
- [#55] make `Payment` public and give it a public initializer
### Removed 
`PaymentContext` and other unused internals

### Added
- `Payment` public initializer
- a computed variable to access `MemoBytes` data
## [0.1.0-beta.6] - 2024-06-06
- [#51] remove dashes from product name
## [0.1.0-beta.5] - 2024-06-06
- [#49] Support iOS 15+
## [0.1.0-beta.4] - 2024-06-05
- [#42] Fix SwiftLintPlugin compile error

## [0.1.0-beta.3] - 2024-06-05

- [#40] Add TEX Address support per ZIP-320 

## [0.1.0-beta.2] - 2024-03-04
### Added 
- Dependency: `swift-custom-dump` to diff assertions in tests.

### Modified
- Bugfix: [#37] multiple recipient payments are parsed in different order every time 

## [0.1.0-beta] - 2024-01-01
- Fixed [problem with literal Decimals](https://github.com/pacu/zcash-swift-payment-uri/issues/35)
- Always favor using `BigDecimal` to avoid misrepresentations of Decimal from 
implicit conversion from `Double`.

### additions
- BigDecimal library that handles the internals of `Amount`
- `init(decimal:)` uses BigDecimal
- `init(value:)` uses Swift's Double 

## [0.1.0-beta] - 2023-12-23
- CI had to be disabled because of swift 5.9 issue with SwiftFormat
- `Parser` API
- `RequestParam` tuple typealias removed in favor of `OtherParam` 
- Changed roadmap leaving validation for third step.

### additions
- New `Errors` for parsing cases
- `static func request(from uriString: String, validatingRecipients: RecipientAddress.ValidatingClosure? = nil) throws -> ParserResult`
- New `ParserResult` API

```
public enum ParserResult: Equatable {
    case legacy(RecipientAddress)
    case request(PaymentRequest)
}
```

## [0.0.2] - 2023-12-01

- support for SwiftLint 0.54.0
- automated builds on CI with GitHub Actions

## [0.0.1] - 2023-11-17

First release of Zcash Swift Payment URI library

This project should be considered as "under development". Although we respect Semantic
Versioning, things might break.

Made ZIP321 API public and all the related types. 
