# zcash-swift-payment-uri

| Job | Status |
| --- | --- |
| `test-macos` | [![test-macos](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml) |
| `coverage` (100% gate) | [![coverage](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml) |
| `lint` (SwiftLint + swift-format) | [![lint](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml) |
| `docc` (zero warnings) | [![docc](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml) |

All four jobs are required checks on `main` and on every pull request (see `.github/workflows/ci.yml`).
The badges above all point at the same workflow run; GitHub does not support per-job badges, so
check the [Actions tab](https://github.com/zecdev/zcash-swift-payment-uri/actions/workflows/ci.yml)
for the individual job's status.

![Platforms](https://img.shields.io/badge/platforms-macOS%2013%2B%20%7C%20iOS%2016%2B-blue)
![Swift](https://img.shields.io/badge/swift-6.0%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

A small, dependency-free Swift library for constructing, rendering, and parsing
[ZIP-321](https://zips.z.cash/zip-0321) Zcash payment request URIs.

## What is it?

Quote from [ZIP-321](https://zips.z.cash/zip-0321):
> [..] a standard format for payment request URIs. Wallets that recognize this format enable users
> to construct transactions simply by clicking links on webpages or scanning QR codes.

`zcash-swift-payment-uri` implements the construction, canonical rendering, and parsing sides of
that specification:

**Example**
`zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok`

The implementation is conformant with [ZIP-321](https://zips.z.cash/zip-0321) except
[`req-asset`](https://zips.z.cash/zip-0321#custom-assets) (ZIP-321 Custom Assets / ZSA), which is
intentionally rejected pending ecosystem support — matching the
[librustzcash `zip321`](https://github.com/zcash/librustzcash/tree/main/components/zip321)
reference implementation, which rejects it likewise. Support is tracked in
[issue #96](https://github.com/zecdev/zcash-swift-payment-uri/issues/96).
Every other parse decision, exact error discriminant, and canonical re-rendering is verified
against the shared, oracle-verified conformance corpus,
[zecdev/zcash-zip321-test-vectors](https://github.com/zecdev/zcash-zip321-test-vectors) (consumed
as a test-only git submodule at `Tests/Vectors`). That same corpus is consumed identically by the
companion [Kotlin library](https://github.com/zecdev/zcash-kotlin-payment-uri), so both
implementations agree byte-for-byte on every vector.

## Quick start

The four scenarios below cover the shapes of payment request most callers need. Each snippet is
copied verbatim from the [DocC landing page](Sources/ZcashPaymentURI/Documentation.docc/ZcashPaymentURI.md)
(and is mirrored, concept-for-concept, in the [Kotlin sibling library](https://github.com/zecdev/zcash-kotlin-payment-uri))
so the two never drift; `scripts/check-readme-snippets.sh` checks that in CI. All examples assume
`import ZcashPaymentURI`.

### 1. A single address, no amount

**URI parsing requires caller-provided Zcash address validation and capability classification.**
This library implements the ZIP-321 URI grammar and nothing else; you supply an `AddressValidator`.
In a wallet this delegates to the Zcash SDK, which is the only component that can answer these
questions correctly:

```swift
struct WalletAddressValidator: AddressValidator {
    let sdk: SomeZcashSDK

    func validate(_ address: String) -> AddressDescriptor? {
        guard let parsed = sdk.parseAddress(address) else { return nil }
        // ZIP-321 forbids Sprout recipients.
        guard !parsed.isSprout else { return nil }

        return AddressDescriptor(
            network: parsed.isTestnet ? .testnet : .mainnet,
            isTransparent: parsed.isTransparent,
            canReceiveMemos: parsed.hasShieldedReceiver
        )
    }
}

let validator = WalletAddressValidator(sdk: sdk)
```

Then the simplest payment request is a bare recipient address, with no query parameters at all:

```swift
guard let recipient = RecipientAddress(
    value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
    validator: validator
) else {
    // your validator rejected the address
    return
}

let uri = ZIP321.request(recipient)
// "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
```

If the address was already validated elsewhere, wrap it together with what you know about it:

```swift
let recipient = RecipientAddress(
    value: knownAddress,
    descriptor: AddressDescriptor(network: .testnet, isTransparent: false, canReceiveMemos: true)
)
```

### 2. An amount, a memo, and other parameters

Use `Payment.Builder` to attach an amount, a memo, and a human-readable message. Fallible inputs
(`amount(zec:)`, `memo(utf8:)`) are validated lazily, at `build()`:

```swift
// (b) an amount + memo payment
let payment = try Payment.Builder(recipient: sapling)
    .amount(zec: "1.2345")
    .memo(utf8: "Thanks!")
    .message("Invoice #42")
    .build()
    .get()

let uri = ZIP321.uriString(from: PaymentRequest(singlePayment: payment))
```

### 3. Multiple recipients

`PaymentRequest.Builder` assembles several payments at once, auto-indexing them (`add(_:)`) or
pinning them to an explicit ZIP-321 `paramindex` (`add(_:at:)`):

```swift
// (c) a multi-payment request
let request = try PaymentRequest.Builder()
    .add(alicePayment)              // paramindex 0
    .add(bobPayment)                // paramindex 1
    .add(carolPayment, at: 7)       // paramindex 7
    .build()
    .get()

let uri = ZIP321.uriString(from: request)
```

The equivalent `@resultBuilder` DSL form reads:

```swift
let request = try PaymentRequest.build {
    alicePayment
    bobPayment
}.get()
```

### 4. Parsing a URI

`ZIP321.parse(_:expecting:validator:maxInputBytes:)` is total: it always returns a `Result`, never
throws. The `validator` is **required** — there is no built-in validation to fall back on (see
[Security](#security) below) — and `expecting:` names the one consensus network the request must be
for:

```swift
let result = ZIP321.parse(
    "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1.5",
    expecting: .testnet,
    validator: validator
)

switch result {
case .success(let request):
    for (index, payment) in request.indexedPayments {
        print(index, payment.recipientAddress.value, payment.amount?.decimalString() ?? "")
    }
case .failure(let error):
    // a sealed, data-leakage-free `ZIP321Error` — see Security below
    print(error)
}
```

If you already have a validating function and do not want to declare a type, wrap it with
`ClosureAddressValidator`:

```swift
let validator = ClosureAddressValidator { address in wallet.describeAddress(address) }
```

Note that a bare `zcash:<address>` URI and the labeled `zcash:?address=<address>` form are two
spellings of the same request: both parse to an equal `PaymentRequest` holding one payment. There
is no separate result shape to branch on.

See the [DocC catalog](Sources/ZcashPaymentURI/Documentation.docc/ZcashPaymentURI.md) (build it
with `xcodebuild docbuild`, or browse it in Xcode via **Product > Build Documentation**) for the
full API reference.

## Security

- **Address validation is yours, and it is authoritative.** This library owns the ZIP-321 URI
  grammar. It does **not** own Zcash address encoding: there is no Bech32, no Base58Check, no
  SHA-256, no human-readable-part table and no address prefix classification anywhere in it.
  A validator returning `nil` rejects the address (`.invalidAddress`); a returned
  `AddressDescriptor` is trusted verbatim, and its `canReceiveMemos` / `isTransparent` drive the
  transparent-memo and zero-valued-transparent-output rules. Nothing re-checks the address
  afterwards — there is no fallback, no "and also", and no defense-in-depth composition, because a
  URI parser shipping its own address tables would be a second, weaker source of truth beside your
  wallet's real one, and the two could disagree. **Delegate to your Zcash SDK** (librustzcash
  `ZcashAddress` via the mobile SDKs' FFI/JNI bindings) — it is the only component that can decode
  Unified Address receivers and decide which address kinds you are willing to pay. The one rule
  applied on top of your verdict is a comparison, not a validation: an accepted address whose
  `AddressDescriptor.network` differs from the `expecting:` network makes the request invalid.
- **Data-leakage-free errors.** The sealed `ZIP321Error` taxonomy never carries an address, memo
  bytes, an amount, or a raw slice of the input URI — every case carries only parameter names,
  payment indices, counts, or a fixed `StaticReason` value (the one bounded exception is
  `invalidParamIndex(raw:)`, capped at a few characters by the ZIP-321 grammar itself). It's safe
  to log a `ZIP321Error` directly.
- **A bounded input size.** `ZIP321.parse` rejects any input longer than `maxInputBytes`
  (`ZIP321.defaultMaxInputBytes`, 8 KiB by default) before any grammar or address-validation work
  begins.
- **No third-party runtime dependencies.** Zero supply-chain surface beyond the Swift standard
  library and the OS-provided Foundation framework.
- **100% region test coverage**, deterministic property-style round-trip tests, and conformance
  against the shared oracle-verified test-vector corpus, enforced by CI on every pull request.

## v1 -> v2 migration

v2.0.0 is a deliberate breaking-change release. Short version:

| v1 | v2 |
| --- | --- |
| `Amount` / `LegacyAmount` | `NonNegativeAmount` |
| `ParserContext` | `Network` (+ a required `AddressValidator`) |
| built-in address validation, `RecipientAddress.ValidatingClosure` | your `AddressValidator` returning an `AddressDescriptor` — it is the only authority |
| `ParserResult.legacy(_:)` / `.request(_:)` | *(gone)* — parsing returns a `PaymentRequest`; both single-recipient spellings parse equal |
| `ZIP321.Errors` | `ZIP321Error` (sealed, data-leakage-free) |
| throwing `ZIP321.request(from:context:validatingRecipients:)` | `ZIP321.parse(_:expecting:validator:) -> Result<PaymentRequest, ZIP321Error>` (the throwing shim is removed) |
| throwing `Payment.init(...)` | `Payment.create(...) -> Result<Payment, ZIP321Error>`, or `Payment.Builder` |
| `OtherParam(key: ParamNameString, value: QcharString?)` | `OtherParam(name: String, value: String?)` |
| `Payment.otherParams: [OtherParam]?` | `Payment.otherParams: [OtherParam]` (default `[]`; duplicate names rejected) |

See [`MigratingFromV1.md`](Sources/ZcashPaymentURI/Documentation.docc/MigratingFromV1.md) for the
full guide, and `CHANGELOG.md`'s `[2.0.0]` entry for the complete list of breaking changes.

## Development

Clone with the test-vector submodule:

```sh
git clone --recurse-submodules git@github.com:zecdev/zcash-swift-payment-uri.git
# or, if already cloned:
git submodule update --init --recursive
```

`Tests/Vectors` tracks [zecdev/zcash-zip321-test-vectors](https://github.com/zecdev/zcash-zip321-test-vectors)
(the URL goes live in `.gitmodules` once that repository is published).

Run the test suite (macOS):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Enforce the 100% region-coverage gate:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/coverage-gate.sh
```

Apply the project's `swift-format` style to `Sources/`:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/format.sh
```

All of the above, plus SwiftLint and a zero-warnings DocC build, run as required checks in
`.github/workflows/ci.yml` on every pull request.

## License
This project is under the MIT License. See [LICENSE](LICENSE) for more details.
