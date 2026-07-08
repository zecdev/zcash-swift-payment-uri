# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed
- **Breaking (toolchain):** `swift-tools-version` raised to `6.0`; minimum
  platforms raised to macOS 13 / iOS 16.
- **Removed all runtime dependencies.** `zcash-swift-payment-uri` is now a
  zero-dependency package: `swift-parsing`, `swift-case-paths`, `BigDecimal`,
  `BigInt`, and `swift-custom-dump` have all been removed.
  - `Amount` is now backed by a checked `Int64` zatoshi (1 ZEC =
    100_000_000 zatoshi) fixed-point representation instead of `BigDecimal`.
    `init(decimal:)` now takes a Foundation `Decimal` (the `BigDecimal`
    overload is gone). All other `Amount` initializers keep their existing
    signatures and v1 parsing leniency (e.g. `"123."` and `".5"` are still
    accepted; grammar tightening is deferred to a later change).
  - The ZIP-321 URI parser (`Parser.swift`) is now a small hand-rolled
    substring-combinator implementation instead of `swift-parsing`, with
    behavior verified to match v1 exactly against the full test suite and the
    shared conformance corpus (the 14-entry expected-failure map is
    unchanged).
  - Test assertions using `swift-custom-dump`'s `expectNoDifference`/
    `XCTAssertNoDifference` have been replaced with `XCTAssertEqual`.

### Added
- The shared ZIP-321 conformance vector corpus
  ([zcash-zip321-test-vectors](https://github.com/zecdev/zcash-zip321-test-vectors),
  oracle-verified against the librustzcash `zip321` reference implementation) is
  now consumed as a test-only git submodule at `Tests/Vectors`. The `.gitmodules`
  URL is a temporary local path until the corpus repository is published.
- A conformance test runner (`Tests/ZcashPaymentURITests/Conformance/`) that
  parses every corpus vector with `ZIP321.request(from:context:)`, asserts
  field-level agreement (addresses, exact zatoshi amounts, memos, labels,
  messages, other params) for valid vectors, rejection for invalid vectors, and
  compares re-rendered URIs against the Rust reference `canonicalUri`.
  Known divergences of the current implementation from the reference semantics
  are enumerated in a strict expected-failure map
  (`ConformanceExpectedFailures.swift`, checked via `XCTExpectFailure`), so the
  suite is green today while every gap stays machine-checked: fixing a gap
  without pruning its map entry turns the suite red. The map currently
  documents 14 divergences (missing address checksum validation, lenient
  amount grammar, missing zero-valued-transparent-output check, rejection of
  empty `memo=`/`message=` values, rejection of regtest Sapling addresses,
  rejection of empty requests, otherparam decoding/rendering issues, and
  paramindex loss on re-render).

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
