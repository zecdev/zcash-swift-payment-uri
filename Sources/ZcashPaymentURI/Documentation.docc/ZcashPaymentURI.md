# ``ZcashPaymentURI``

Construct, render, and parse ZIP-321 Zcash payment request URIs.

## Overview

[ZIP-321](https://zips.z.cash/zip-0321) defines a standard `zcash:` URI format for payment
requests, so that wallets can turn a link or a scanned QR code directly into a transaction the
user only has to confirm. This library is a small, dependency-free, cross-platform (macOS / iOS)
implementation of that specification:

- **Construction**: fluent builders (``Payment/Builder-swift.struct`` and
  ``PaymentRequest/Builder-swift.struct``) and a `@resultBuilder` DSL
  (``PaymentRequestBuilder``) assemble a ``PaymentRequest`` from one or more ``Payment`` values.
- **Rendering**: ``ZIP321/uriString(from:formattingOptions:)`` turns a ``PaymentRequest`` back
  into its canonical `zcash:` URI string.
- **Parsing**: ``ZIP321/parse(_:expecting:validator:maxInputBytes:)`` is a **total** function —
  every input, well-formed or not, maps to a `Result<PaymentRequest, ZIP321Error>`. Parsing never
  throws and never traps.

The library has **zero runtime dependencies** and enforces the ZIP-321 grammar strictly: amounts
and memos are validated against the spec grammar.

**URI parsing requires caller-provided Zcash address validation and capability
classification.** This library implements the ZIP-321 URI grammar and nothing else: it does not
know how Zcash addresses are encoded and performs no address validation of its own. You supply an
``AddressValidator``; whatever it accepts is a valid recipient, and the ``AddressDescriptor`` it
returns is what drives the ZIP-321 payment rules. See <doc:#Security> below.

## Usage

The four scenarios below cover the shapes of payment request most callers need. All examples
assume `import ZcashPaymentURI`.

### 1. A single address, no amount

The simplest payment request is a bare recipient address, with no query parameters at all.

First, wire up your address validator. In a wallet this delegates to the Zcash SDK, which is the
only component that can answer these questions correctly:

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

Use ``Payment/Builder-swift.struct`` to attach an amount, a memo, and a human-readable message.
Fallible inputs (`amount(zec:)`, `memo(utf8:)`) are validated lazily, at `build()`:

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

``PaymentRequest/Builder-swift.struct`` assembles several payments at once, auto-indexing them
(`add(_:)`) or pinning them to an explicit ZIP-321 `paramindex` (`add(_:at:)`):

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

``ZIP321/parse(_:expecting:validator:maxInputBytes:)`` is total: it always returns a `Result`,
never throws. The `validator` is **required** — there is no built-in validation to fall back on —
and `expecting:` names the one consensus network the request must be for:

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
``ClosureAddressValidator``:

```swift
let validator = ClosureAddressValidator { address in wallet.describeAddress(address) }
```

Note that a bare `zcash:<address>` URI and the labeled `zcash:?address=<address>` form are two
spellings of the same request: both parse to an equal ``PaymentRequest`` holding one payment.
There is no separate result shape to branch on.

## Security

### Address validation is yours, and it is authoritative

This library owns the ZIP-321 URI grammar. It does **not** own Zcash address encoding: there is no
Bech32, no Base58Check, no SHA-256, no human-readable-part table and no address prefix
classification anywhere in it. Address validity and capability classification come from the
``AddressValidator`` you supply, and the answer is final:

- returning `nil` rejects the address — the request fails with
  ``ZIP321Error/invalidAddress(index:)``;
- returning an ``AddressDescriptor`` accepts it, and that descriptor is trusted verbatim. Its
  ``AddressDescriptor/canReceiveMemos`` decides whether a `memo` may accompany the recipient, and
  its ``AddressDescriptor/isTransparent`` decides whether a zero-valued output to it is allowed.

Nothing re-checks the address afterwards. This is deliberate: a URI parser that shipped its own
address tables would be a second, weaker source of truth sitting next to your wallet's real one,
and the two could disagree — so there is no "and also", no fallback, and no defense-in-depth
composition to reason about. **Implement this by delegating to your Zcash SDK** (librustzcash's
`ZcashAddress` via the mobile SDKs' FFI/JNI bindings), which is the only component that can decode
Unified Address receivers and decide which address kinds your wallet is willing to pay.

The one rule applied on top of your verdict is a comparison, not a validation: an accepted address
whose ``AddressDescriptor/network`` differs from the `expecting:` network makes the request invalid
(``ZIP321Error/invalidAddress(index:)``). ZIP-321 itself is network-agnostic — the librustzcash
reference parses addresses without a network — so network enforcement is a consumer-library
requirement, made explicit here rather than implicit.

### Data-leakage-free errors

Parsing failures surface as the sealed ``ZIP321Error`` taxonomy, whose payloads are constructed to
never leak raw user input: every case carries only parameter names, payment indices, counts, or a
fixed ``StaticReason`` value. No case carries an address, a memo's contents, an amount, or a raw
slice of the input URI — the single bounded exception is
``ZIP321Error/invalidParamIndex(raw:)``, whose raw token is capped at a handful of characters by
the ZIP-321 grammar itself (`paramindex` is at most 4 digits). This makes it safe to log a
`ZIP321Error` value directly (e.g. for diagnostics or crash reports) without an additional
redaction step.

### A bounded input size

``ZIP321/parse(_:expecting:validator:maxInputBytes:)`` rejects any input longer than
`maxInputBytes` (``ZIP321/defaultMaxInputBytes``, 8 KiB by default) with
``ZIP321Error/invalidURI(reason:)`` / ``StaticReason/inputTooLarge`` **before** any grammar or
address-validation work begins, so parsing an oversized or adversarially crafted string does only
constant work rather than scanning the whole input.

## Topics

### Essentials

- ``ZIP321``
- ``PaymentRequest``
- ``Payment``
- ``RecipientAddress``
- ``Network``

### Address validation

- ``AddressValidator``
- ``AddressDescriptor``
- ``ClosureAddressValidator``

### Building requests

- ``Payment/Builder-swift.struct``
- ``PaymentRequest/Builder-swift.struct``
- ``PaymentRequestBuilder``

### Values

- ``NonNegativeAmount``
- ``MemoBytes``
- ``OtherParam``

### Errors

- ``ZIP321Error``
- ``StaticReason``

### Migrating

- <doc:MigratingFromV1>
