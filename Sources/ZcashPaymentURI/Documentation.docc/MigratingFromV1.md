# Migrating from 1.x

Update call sites that use the 1.x (`Amount`/`ParserResult`/throwing `ZIP321.request(from:)`) API
surface to the v2.0.0 API.

## Overview

v2.0.0 is a deliberate breaking-change milestone: the public surface was reshaped to match the
cross-language v2 contract shared with the companion Kotlin library, and to make parsing a total
(non-throwing) operation. This article summarizes the breaking changes and how to migrate; the
full details live in the `CHANGELOG.md` "Breaking changes" sections.

## You must supply an address validator

This is the largest change. v2 does **not** validate Zcash addresses: it implements the ZIP-321
URI grammar and delegates address validity and capability classification to you. `ParserContext`
is gone; ``Network`` replaces it as the network selector, and every parse takes an
``AddressValidator``:

```swift
// Before (1.x) — the library validated addresses itself, and an optional
// closure was composed AND-wise on top.
let result = try ZIP321.request(
    from: uriString,
    context: .testnet,
    validatingRecipients: { address in wallet.isKnown(address) }
)

// After (2.x) — your validator is the only authority.
struct WalletAddressValidator: AddressValidator {
    let sdk: SomeZcashSDK

    func validate(_ address: String) -> AddressDescriptor? {
        guard let parsed = sdk.parseAddress(address), !parsed.isSprout else { return nil }
        return AddressDescriptor(
            network: parsed.isTestnet ? .testnet : .mainnet,
            isTransparent: parsed.isTransparent,
            canReceiveMemos: parsed.hasShieldedReceiver
        )
    }
}

let result = ZIP321.parse(uriString, expecting: .testnet, validator: WalletAddressValidator(sdk: sdk))
```

Returning `nil` rejects the address; a returned ``AddressDescriptor`` is trusted verbatim and
drives the ZIP-321 payment rules (memo support, zero-valued transparent outputs). There is no
built-in check left to compose with. Delegate to your Zcash SDK — it is the only component that can
decode Unified Address receivers and decide which address kinds you are willing to pay.

If you only have a function, ``ClosureAddressValidator`` adapts it:

```swift
let validator = ClosureAddressValidator { address in wallet.describeAddress(address) }
```

``RecipientAddress`` follows: `init(value:context:validating:)` becomes
``RecipientAddress/init(value:validator:)``, or ``RecipientAddress/init(value:descriptor:)`` when
the address was validated elsewhere. It now carries a ``RecipientAddress/descriptor``.

An accepted address whose ``AddressDescriptor/network`` differs from the `expecting:` network makes
the request invalid (``ZIP321Error/invalidAddress(index:)``).

## Parsing is now total

`ZIP321.request(from:context:validatingRecipients:)` used to `throw`. The v2 entry point is
``ZIP321/parse(_:expecting:validator:maxInputBytes:)``, which returns
`Result<PaymentRequest, ZIP321Error>` and never throws:

```swift
// Before (1.x)
let result = try ZIP321.request(from: uriString, context: .testnet)

// After (2.x)
switch ZIP321.parse(uriString, expecting: .testnet, validator: validator) {
case .success(let request):
    // ...
case .failure(let error):
    // a sealed ZIP321Error — see below
}
```

The old throwing entry point is **removed**, not deprecated: its result type no longer exists, so
no source-compatible shim was possible.

Input guards run before any grammar work: input larger than `maxInputBytes` (default 8 KiB) fails
with ``ZIP321Error/invalidURI(reason:)`` / ``StaticReason/inputTooLarge``.

## `ParserResult` is gone — parsing returns a `PaymentRequest`

There is no result enum in v2. `zcash:<addr>` and `zcash:?address=<addr>` are two spellings of the
same request per ZIP-321 "URI Semantics", so they now parse to **equal** ``PaymentRequest`` values
and the parsed model does not record which spelling was used — matching the reference
`TransactionRequest`.

```swift
// Before (1.x)
switch try ZIP321.request(from: uriString, context: .testnet) {
case .legacy(let recipient):  useRecipient(recipient)
case .request(let request):   useRequest(request)
}

// After (2.x) — one shape
let request = try ZIP321.parse(uriString, expecting: .testnet, validator: validator).get()
useRequest(request)
```

A bare address URI is simply a one-payment request whose payment carries only a recipient. If you
had a `.legacy` branch, replace it with `request.payments.first?.recipientAddress`. A single
payment at the empty paramindex still **renders** in the leading-address form by default; that
choice lives in the renderer's formatting options, not in the model.

## The error type is now the sealed `ZIP321Error`

The old public `ZIP321.Errors` grab-bag is gone from the public surface, replaced by the sealed
``ZIP321Error`` taxonomy, whose cases mirror the shared cross-language conformance-corpus error
discriminants (`invalidBase64`, `memoBytesError`, `transparentMemo`,
`zeroValuedTransparentOutput`, `tooManyPayments`, `duplicateParameter`, `recipientMissing`,
`invalidAddress`, `unknownRequiredParameter`, `invalidParamIndex`, `amountExceededSupply`,
`amountInvalid`, `invalidURI`, `parseError`). Every case carries only parameter names, indices,
counts, or fixed ``StaticReason`` values — never addresses, memo contents, amounts, or raw URI
slices — so update any `catch`/`switch` that matched on the old case set. Sprout rejection, which
used to surface as `sproutRecipientsNotAllowed`, now surfaces as ``ZIP321Error/invalidAddress(index:)``.

## `Amount` / `LegacyAmount` is gone — use `NonNegativeAmount`

`Payment.amount` is now `NonNegativeAmount?` instead of `Amount?`/`LegacyAmount?`. Replace:

```swift
// Before (1.x)
let amount = try Amount(value: 1)
let amount = try LegacyAmount(string: "1.5")

// After (2.x)
let amount = try NonNegativeAmount.zec("1.5").get()  // strict ZIP-321 amountparam grammar
let amount = NonNegativeAmount.zatoshi(150_000_000) // raw zatoshi count
```

``NonNegativeAmount`` exposes `value: UInt64` (the raw zatoshi count; unsigned, mirroring the reference `u64`-backed `Zatoshis`) and `decimalString()` (the canonical
decimal ZEC rendering). Its decimal-string parsing (``NonNegativeAmount/zec(_:)``) is **strict**: a leading
or trailing decimal point, a sign, whitespace, or scientific notation are all rejected, unlike the
old lenient `Amount`/`LegacyAmount` parsing.

## `Payment` construction moved to a `Result` factory

Prefer ``Payment/create(recipientAddress:amount:memo:label:message:otherParams:)`` (returns
`Result<Payment, ZIP321Error>`) or the fluent ``Payment/Builder-swift.struct`` over the old
throwing initializer, which remains only as a deprecated shim:

```swift
// Before (1.x)
let payment = try Payment(
    recipientAddress: recipient,
    amount: try Amount(value: 1),
    memo: try MemoBytes(utf8String: "Thanks!"),
    label: nil,
    message: "Thank you",
    otherParams: nil
)

// After (2.x) — Result factory
let payment = try Payment.create(
    recipientAddress: recipient,
    amount: try NonNegativeAmount.zec("1").get(),
    memo: try MemoBytes(utf8String: "Thanks!"),
    label: nil,
    message: "Thank you"
).get()

// After (2.x) — fluent builder
let payment = try Payment.Builder(recipient: recipient)
    .amount(zec: "1")
    .memo(utf8: "Thanks!")
    .message("Thank you")
    .build()
    .get()
```

`Payment.create` additionally enforces, at construction time, that a zero-valued `amount` may not
be sent to a transparent recipient (``ZIP321Error/zeroValuedTransparentOutput(index:)``) — a new
consensus check also enforced on the parse path.

`label`/`message` are now plain **decoded** `String?` — the `QcharString` wrapper and the
`qcharLabel:`/`qcharMessage:` initializer parameters are gone; qchar encoding now happens at
render time instead of at construction time.

## `PaymentRequest` now preserves ZIP-321 paramindices

`PaymentRequest.payments` still returns `[Payment]`, but payments are now stored keyed by their
ZIP-321 `paramindex`, and a new ``PaymentRequest/indexedPayments`` property exposes the
`(index: UInt, payment: Payment)` pairs. `init(payments:)` still auto-indexes sequentially from
`0`; a new ``PaymentRequest/init(indexedPayments:)`` accepts explicit, non-contiguous indices.

**Empty requests are now valid**: `zcash:` and `zcash:?` parse to an empty ``PaymentRequest``
(previously rejected). The old construction-time same-network check across a request's payments
(`networkMismatchFound`) was removed — the expected network is enforced once, at the parse
boundary, by comparing each recipient's ``AddressDescriptor/network`` against `expecting:`.

## `OtherParam` is now a plain `(name: String, value: String?)`

`OtherParam.key: ParamNameString` / `OtherParam.value: QcharString?` are now plain, already-decoded
`name: String` / `value: String?`. `QcharString` and `ParamNameString` are no longer public.

## `Payment.otherParams` is a non-optional array

`[OtherParam]?` became `[OtherParam]`, defaulting to `[]`. ZIP-321 cannot spell the difference
between "absent" and "empty" — both render to the same URI — so modelling both produced two
distinct ``Payment`` values for one URI. Replace `otherParams: nil` with `otherParams: []` (or omit
the argument), and `payment.otherParams ?? []` with `payment.otherParams`.

``Payment/create(recipientAddress:amount:memo:label:message:otherParams:)`` also **rejects
duplicate other-param names** with ``ZIP321Error/duplicateParameter(name:index:)``, matching what
the parser already enforced for a URI.

## Renderer defaults changed to the canonical reference form

`ZIP321.uriString(from:formattingOptions:)` and `ZIP321.request(_:formattingOptions:)` now default
to `.useEmptyParamIndex(omitAddressLabel: true)` — the canonical reference form. A single payment
at the empty paramindex renders as `zcash:<addr>?amount=…`; anything else (multiple payments, or
any payment at a non-zero index) renders as `zcash:?address[.n]=…&…`. If your code relied on the
previous default (which collapsed a non-zero-indexed single payment onto the empty index), pass
`formattingOptions` explicitly, or use `.enumerateAllPayments` to re-number payments sequentially
from `1`.
