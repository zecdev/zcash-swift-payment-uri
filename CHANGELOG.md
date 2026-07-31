# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed
- **Recipient-address validation is FULLY DELEGATED to the caller.** This
  library implements the [ZIP-321](https://zips.z.cash/zip-0321) URI grammar
  and nothing else: it no longer contains Bech32/Bech32m or Base58Check
  decoding, SHA-256, human-readable-part tables, version-byte tables, or any
  address prefix classification.
  - New `public protocol AddressValidator { func validate(_ address: String) -> AddressDescriptor? }`.
    It is the AUTHORITY: `nil` rejects the address; a returned descriptor is
    trusted verbatim. There is no built-in check to compose with and no
    "defense in depth" AND-composition — that framing is gone.
  - New `public struct AddressDescriptor` carrying the three facts ZIP-321
    semantics need: `network`, `isTransparent`, `canReceiveMemos`. The
    transparent-memo and zero-valued-transparent-output rules are driven by
    these, not by inspecting the address string.
  - New `public struct ClosureAddressValidator` adapts a closure to the
    protocol.
  - New `public enum Network { case mainnet, testnet, regtest }` replaces
    `ParserContext` as the public network selector. **`ParserContext` is
    deleted**, along with `RecipientAddress.ValidatingClosure` and the old
    four-method `AddressValidator` protocol (`isValid`/`isTransparent`/
    `isSprout`/`isShielded`).
  - `RecipientAddress` now carries `value` + `descriptor`; its capability
    accessors read the descriptor. `init?(value:context:validating:)` is
    replaced by `init?(value:validator:)` and `init(value:descriptor:)`.
  - Parsing entry points take a REQUIRED validator:
    `ZIP321.request(from:expecting:validator:)`. Wallets should delegate to
    their SDK's own address support (librustzcash `ZcashAddress` via the
    mobile SDKs' FFI/JNI bindings), which is the only component that can
    answer these questions correctly — including Unified Address receiver
    decoding.
  - `ZIP321.Errors.sproutRecipientsNotAllowed` is deleted. Sprout rejection is
    a validator policy; the library reports `invalidAddress`.
- **The expected network is enforced at the parse boundary.** A request is
  parsed against exactly one `Network` (`expecting:`); when the validator
  accepts an address but reports a DIFFERENT `AddressDescriptor.network`, the
  request is rejected with `invalidAddress` (carrying the payment's
  `paramindex`). This is a comparison, not a validation: the library still
  learns the address's network only from the validator. ZIP-321 itself is
  network-agnostic — the librustzcash reference parses addresses without a
  network — so this is a consumer-library requirement, made explicit rather
  than implicit.

### Testing
- The Bech32/Bech32m, Base58Check and SHA-256 reference checkers now live in
  `Tests/ZcashPaymentURITests/Support/` and ship with **no** library target.
  They exist so the shared conformance corpus's deliberately
  checksum-corrupted, mixed-case, wrong-network and Sprout address vectors
  stay executable: the suite injects a `ReferenceAddressValidator` built on
  them, and those vectors are now rejected BY THE VALIDATOR — which is
  precisely the boundary this design draws.
- Conformance xfail burn-down: `invalid_address_sapling_bad_checksum`,
  `invalid_address_unified_mainnet_bad_checksum`,
  `invalid_address_transparent_bad_checksum` and `spec_valid_regtest_example`
  now pass and their expected-failure entries are removed.

### Fixed
- Signed amount strings are rejected eagerly: a leading `-` fails with
  `negativeAmount` (and `+` with `invalidTextInput`) before any digit
  parsing, per review. `Amount.AmountError` is now `Equatable`.
- `Amount` is fully covered by tests (100% regions/functions/lines),
  including the previously-untested malformed-shape, non-finite-double,
  zero-constant, and eager-rounding paths.
- SwiftLint warnings across `Sources/` resolved (whitespace, comma
  spacing, TODO format now referencing the resolving PR, multiline
  parameter brackets, redundant type annotation; one justified
  `large_tuple` disable on the transitional parser tuple).

### Changed
- `NonNegativeAmount` is backed by `UInt64` (`value`, `maxMoney`), mirroring the
  reference implementation's `u64`-backed `Zatoshis`: a ZIP-321 amount is
  non-negative by grammar, so negative counts are now unrepresentable by
  construction. `NonNegativeAmount.zatoshi(_:)` takes `UInt64`;
  `AmountError.negativeAmount` remains only for the decimal-string path's
  error taxonomy.

### Added — 100% region coverage + machine-checkable gate (S16)

- `scripts/coverage-gate.sh` + `scripts/coverage-gate.py`: runs the full test
  suite with `swift test --enable-code-coverage`, exports the LLVM coverage
  report via `xcrun llvm-cov export -format=text`, and computes *region*
  coverage restricted to `Sources/ZcashPaymentURI/**` (excluding `Tests/`),
  failing (exit 1) with every file and uncovered line range listed when
  coverage is below 100.00%. Supports a small, explicit `// COVERAGE-EXEMPT:
  <reason>` source annotation (max 3 sites) for genuinely unreachable
  defensive invariant guards; the script fails outright if that budget is
  exceeded. Usage: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  scripts/coverage-gate.sh`.
- Drove region coverage from 91.35% (786 regions, the pre-existing baseline
  plus the S16 property tests) to **100.00% (757/757)**, via:
  - Targeted tests for previously-unexercised code: `Payment.Builder`'s
    `amount(_:NonNegativeAmount)` / `memo(_:MemoBytes)` / `label(_:)` overloads and the
    `otherParam` success path; the `PaymentRequestBuilder` `for`-loop
    (`buildArray`) and `if`-without-`else` (`buildOptional`) DSL forms;
    `PaymentRequest(indexedPayments:)`'s direct duplicate-index throw; the
    deprecated `Payment.init(...)` throwing shim (silenced via
    `@available(*, deprecated)` on the test function, matching the existing
    `ZIP321.request(from:...)` shim test); `ZIP321Error.withIndex(_:)` and
    `ZIP321Error.init(_:ZIP321.Errors)` exhaustively over every case (the
    parser's only production call sites each reach a small subset);
    `ZIP321.Errors.mapFrom` exhaustively over every `MemoBytes.MemoError` /
    `NonNegativeAmount.AmountError` case; `Render.request(_:.enumerateAllPayments)`'s
    non-empty-request branch; `ZIP321.request(_:formattingOptions:)`'s
    non-default-option branch; `ParserContext.isTransparent`'s non-ASCII
    charset guard; `Bech32.verify`'s decode-failure branch; indexed
    (`paramindex > 0`) invalid-address and sprout-address query parameters;
    `otherparam`/`label`/`message` values with malformed percent-escapes;
    `NonNegativeAmount.zec`'s whole-part-exceeds-`maxMoney` bound (no fractional part
    involved, distinct from the already-covered overflow paths); several
    `Parser`-internal helpers (`leadingAddress`, `parseParamIndex`,
    `parseNameAndIndex`, `parseParameters`, `mapToIndexedPayments`,
    `mapToPayments`) exercised directly via their own documented contracts
    rather than only through the public parse path; and the generic
    `mapToErrorOrRethrow` rethrow branch, exercised directly with a
    non-matching error type.
  - Dead-code removal: an always-succeeding `qcharEncoded()` guard in
    `QcharString.init` (replaced with a direct `QcharCodec.encode` call); a
    redundant `req-` prefix guard inside `Param.from` (already rejected by
    its only caller, `zcashParameter`, before `Param.from` is ever reached);
    an unreachable dictionary-subscript guard in `Parser.mapToIndexedPayments`
    (the key is always drawn from the same dictionary); a redundant
    double-guard in `Payment.uniqueIndexedParameters` collapsed into a single
    `compactMap`-based extraction; an unreachable `byte < 128` guard in
    `Bech32.decode` (every byte is already known-ASCII by that point); the
    entirely-unused `NumberFormatter.zcashNumberFormatter` and
    `String.asQcharString` (dead since the v1→v2 `Amount` removal).
  - Restructuring for testability: `Parser.leadingAddress` now returns
    `(rest: Substring?, leadingAddress: RecipientAddress?)` instead of
    wrapping the address in an `IndexedParameter`, eliminating an
    unreachable `guard case .address(...)` in `ZIP321.parsePipeline` (the
    value was always `.address` by construction) rather than papering over
    it with an exemption.
  - Two `// COVERAGE-EXEMPT` sites remain (of the 3 allowed), both the same
    shape: a `catch { ... }` clause in a non-throwing `Result`-returning
    wrapper (`ZIP321.parse`, `PaymentRequest.Builder.build()`) around an
    untyped-`throws` call whose every actual path already throws a caught,
    specific error type — Swift requires the exhaustive catch-all anyway,
    but reaching it would need a future change to throw some third,
    untranslated error type from within the wrapped call.

### Added — deterministic property-style round-trip tests (S16)

- `Tests/ZcashPaymentURITests/PropertyGenerators.swift`: a tiny inline
  `SplitMix64` seeded PRNG plus generator functions mirroring the reference
  librustzcash `zip321::testing` proptest strategies — arbitrary valid memo
  bytes (0..512), arbitrary `NonNegativeAmount` (biased to also hit `0`/`1`/`maxMoney`
  boundaries), arbitrary unicode label/message/otherParam-value strings
  (including emoji and characters that require percent-encoding), arbitrary
  non-reserved `otherParam` names, arbitrary payments drawn from a fixed pool
  of known-checksum-valid addresses per network/kind (transparent P2PKH/P2SH,
  Sapling, Unified, TEX), and arbitrary indexed payment requests (0..20
  payments at sparse `paramindex` values 0..9999).
- `Tests/ZcashPaymentURITests/PropertyTests.swift`: five deterministic laws,
  each run over a fixed range of seeds via `@Test(arguments:)` (1,400 total
  cases, full suite runtime ~0.24s): (1) full round trip
  `parse(uriString(from: r)) == .success(.request(r))` (300 cases); (2)
  `NonNegativeAmount.zec(z.decimalString()) == z` (300 cases); (3)
  `MemoBytes(base64URL: m.toBase64URL()) == m` (300 cases); (4)
  `QcharCodec.decode(QcharCodec.encode(s)) == s` (300 cases); (5) paramindex
  preservation — a request with sparse indices round-trips preserving
  `indexedPayments` exactly (200 cases). All seeds are fixed integers; no
  `Date`/system-random seeding.

### Changed — conformance corpus sync (S15)

- Bumped the `Tests/Vectors` corpus submodule to the adjudicated revision:
  integer-overflow amounts classify as `amountExceededSupply` (any
  checked-accumulation overflow necessarily exceeds MAX_MONEY); the spec's
  fabricated req-asset example addresses are documented as checksum-invalid
  (`invalidAddress`); a new vector pairs `req-asset` with a checksum-valid UA
  to isolate `unknownRequiredParameter`.
- Removed the overflow special-case in `AmountParser` accordingly.
- The conformance expected-failure map is now **empty**: the implementation
  matches the librustzcash reference on every corpus vector — parse decision,
  exact error discriminant, and canonical re-render.

### Breaking changes — v2.0.0 public API reshape

This is the deliberate breaking-change milestone of the v2 rewrite. The public
surface now matches the cross-language v2 contract shared with the Kotlin
library.

- **`ZIP321.parse(_:expecting:validator:maxInputBytes:)` is the parsing entry
  point** and is a *total* function: it returns
  `Result<PaymentRequest, ZIP321Error>` instead of throwing. The `validator` is
  REQUIRED and has no default — the library performs no address validation of
  its own, so there is nothing sensible to default to. Input guards run
  first: input larger than `maxInputBytes` (default
  `ZIP321.defaultMaxInputBytes` = 8 KiB) fails with
  `.invalidURI(reason: .inputTooLarge)`; the empty string fails with
  `.parseError(reason: .emptyInput)`; a non-`zcash:` scheme fails with
  `.invalidURI(reason: .notZcashScheme)`; a `//` authority component fails with
  `.invalidURI(reason: .invalidAuthority)`.
  The deprecated throwing shim `ZIP321.request(from:context:validatingRecipients:)`
  is **removed**: its result type no longer exists, so it could not have been
  kept source-compatible.
- **`ParserResult` is DELETED and not replaced — parsing returns a
  `PaymentRequest`.** There is no result enum: `zcash:<addr>` and
  `zcash:?address=<addr>` are two spellings of the SAME request (ZIP-321 "URI
  Semantics"), they now parse to **equal** `PaymentRequest` values, and which
  spelling a URI used is not recorded anywhere in the model — matching the
  reference `TransactionRequest`. Migration: `case .legacy(let recipient)` /
  `case .request(let request)` collapse to a single `PaymentRequest`; a bare
  address URI is simply a one-payment request whose payment carries only a
  recipient. A single payment at the empty paramindex still RENDERS in the
  leading-address form by default; the syntax choice lives in the renderer's
  formatting options, not in the model.
- **`ZIP321.Errors` (public, v1) was replaced by the sealed `ZIP321Error`
  taxonomy**, mirroring the conformance corpus's cross-language discriminants:
  `invalidBase64`, `memoBytesError`, `transparentMemo`,
  `zeroValuedTransparentOutput`, `tooManyPayments`, `duplicateParameter`,
  `recipientMissing`, `invalidAddress`, `unknownRequiredParameter`,
  `invalidParamIndex`, `amountExceededSupply`, `amountInvalid`, `invalidURI`,
  `parseError`. **Data-leakage policy, enforced by construction**: error
  payloads carry only parameter names, indices, counts, or fixed
  `StaticReason` enum values — never addresses, memo contents, amounts, or raw
  URI slices (the single bounded exception is `invalidParamIndex`'s raw index
  token, ≤ 5 characters by grammar). Sprout rejection now surfaces as
  `invalidAddress` (previously `sproutRecipientsNotAllowed`).
- **`Amount`/`LegacyAmount` was removed entirely.** `Payment.amount` is now
  `NonNegativeAmount?`. Migration: replace `try Amount(value: 1)` /
  `try LegacyAmount(string: "1.5")` with `try NonNegativeAmount.zec("1.5").get()` (strict
  ZIP-321 `amountparam` grammar) or `NonNegativeAmount.zatoshi(150_000_000)` for raw
  integer counts. `NonNegativeAmount` exposes `value: Int64` and `decimalString()`.
- **`Payment` construction moved to a `Result` factory.**
  `Payment.create(recipientAddress:amount:memo:label:message:otherParams:)`
  returns `Result<Payment, ZIP321Error>` and enforces the reference
  `to_payment` rules at construction time: a memo to a transparent recipient
  fails with `.transparentMemo`, and a **zero-valued amount to a transparent
  recipient fails with `.zeroValuedTransparentOutput`** (new consensus check,
  also enforced on the parse path). The throwing `Payment.init` remains as a
  deprecated shim. `label`/`message` are now plain **decoded** `String?`
  (the `QcharString` wrapper and the `qcharLabel:`/`qcharMessage:` initializer
  are gone from the public surface; qchar encoding happens at render time).
- **`PaymentRequest` now preserves ZIP-321 paramindices.** Payments are stored
  by `paramindex`; `payments: [Payment]` returns them ordered by ascending
  index and the new `indexedPayments: [(index: UInt, payment: Payment)]`
  exposes the indices (e.g. a request whose only payment sits at
  `address.5`/`amount.5` retains index 5). `init(payments:)` auto-indexes
  sequentially from 0 and enforces the 9999-payment cap
  (`.tooManyPayments`); the new `init(indexedPayments:)` validates index
  uniqueness (`.duplicateParameter`) and the ≤ 9999 index bound. **Empty
  requests are now valid**: `zcash:` and `zcash:?` parse to
  an empty `PaymentRequest` (previously rejected), and an empty
  request renders back to `zcash:`. The v1 construction-time
  network-coherence check (`networkMismatchFound`) was removed — the expected
  network is enforced once, at the parse boundary, by comparing each
  recipient's `AddressDescriptor.network` against `expecting:`.
- **`OtherParam` is now `(name: String, value: String?)`** with plain decoded
  semantics (previously `key: ParamNameString`, `value: QcharString?`).
  `QcharString` and `ParamNameString` are no longer public.
- **`Payment.otherParams` is a non-optional `[OtherParam]`** (defaulting to
  `[]`). The `nil` vs. `[]` distinction is gone: ZIP-321 cannot spell the
  difference, both render to the same URI, and keeping both would give two
  distinct `Payment` values for one URI — breaking the round-trip law.
  Migration: `otherParams: nil` becomes `otherParams: []` (or is omitted), and
  `payment.otherParams ?? []` becomes `payment.otherParams`.
  `Payment.create` additionally **rejects duplicate other-param names** with
  `.duplicateParameter(name:index: nil)`, matching what the parser already
  enforces for a URI — so a `Payment` can no longer be constructed that renders
  to a URI which will not parse back.
- Rendering entry points keep their existing names and signatures:
  `uriString(from:formattingOptions:)`, `request(_:formattingOptions:)`.
- Conformance: the invalid-vector runner now asserts the **exact** error
  discriminant against the corpus. Expected-failure ledger: burned
  `structure_empty_request`, `structure_empty_request_query_marker`, and
  `spec_invalid_zero_valued_transparent_output`; one corpus discriminant
  dispute (`invalid_req_asset_two_recipients_flattened`) remains pending
  adjudication.

### Breaking changes — v2.0.0 canonical renderer

- **The renderer now renders from `PaymentRequest.indexedPayments`, preserving
  each payment's ACTUAL stored `paramindex`.** A request whose only payment
  sits at index `5` renders `zcash:?address.5=…&amount.5=1` (previously it was
  collapsed onto the empty index). Per-payment parameter order matches the
  reference exactly: address, amount, memo, label, message, then `otherParams`
  in stored order.
- **The default `formattingOptions` of `uriString(from:)` and
  `request(_ payment:)` changed to
  `.useEmptyParamIndex(omitAddressLabel: true)`** — the canonical reference
  form. A single payment at the empty paramindex renders as the leading-address
  form `zcash:<addr>?amount=…`; multi-payment (or any payment at a non-zero
  index) renders as `zcash:?address[.n]=…&…`. The round-trip law
  `parse(uriString(from: r)) == r` holds for every request `r` under the
  default options (asserted over the corpus's valid vectors).
- **`FormattingOptions.enumerateAllPayments` is now a documented NORMALIZATION
  mode**: it discards stored paramindices and re-numbers payments sequentially
  from `1` (`address.1=…&address.2=…`) under `zcash:?`. It now emits the
  mandatory `?` query separator (previously the multi-payment output omitted
  it, producing a non-round-trippable URI).

### Fixed

- **A bare `zcash:<addr>` now re-renders exactly**, without the spurious
  trailing `?` the previous renderer emitted for a payment carrying no query
  parameters. This fixes the `structure_single_address_no_query_params`
  conformance divergence, which S12 surfaced when it collapsed the
  single-address result shape into an ordinary one-payment request.
- **`otherparam` rendering now emits the `=` separator** when the parameter
  carries a value (`future-param=hello%20world`), matching the reference
  `str_param`. A value-less otherparam still renders as a bare `name`. This
  fixes the `structure_unknown_param_preserved` conformance divergence.
- **A single payment at a non-zero paramindex now re-renders faithfully**
  instead of being collapsed onto the empty index, fixing the
  `structure_index_gap_only_address_5` conformance divergence.

### Added — fluent builders

- **`Payment.Builder`** (`init(recipient:)` + chainable `amount(_:)`,
  `amount(zec:)`, `memo(_:)`, `memo(utf8:)`, `label(_:)`, `message(_:)`,
  `otherParam(name:value:)`, terminal `build() -> Result<Payment, ZIP321Error>`).
  Fallible inputs are validated LAZILY at `build()`: a bad `amount(zec:)`
  surfaces as `.amountInvalid` (or `.amountExceededSupply`), an oversized
  `memo(utf8:)` as `.memoBytesError`, an invalid `otherParam` name as
  `.parseError(.invalidParameter)`; a memo to a transparent recipient surfaces
  as `.transparentMemo` via `Payment.create`. When several fields are invalid,
  the first error wins in field order (amount → memo → other params →
  structural rules).
- **`PaymentRequest.Builder`** (`add(_:)` auto-indexing sequentially from `0`,
  `add(_:at:)` for an explicit paramindex, terminal
  `build() -> Result<PaymentRequest, ZIP321Error>`). Deferred validation:
  a duplicate index fails with `.duplicateParameter`, an index above `9999`
  with `.tooManyPayments`.
- **`@resultBuilder PaymentRequestBuilder`** with the `PaymentRequest.build { … }`
  entry point (`try PaymentRequest.build { payment1; payment2 }.get()`), a thin
  layer over `PaymentRequest.Builder` that auto-indexes block statements from
  `0` and accepts both single `Payment` expressions and `[Payment]` arrays. The
  entry point is `PaymentRequest.build` rather than a bare `PaymentRequest { … }`
  free function because Swift forbids a global function sharing a name with a
  type in the same module; `.build` preserves the Result-returning `.get()`
  totality contract.

### Added
- **Internal single-pass `Scanner`** (`Sources/ZcashPaymentURI/parser/Scanner.swift`): a
  byte-level scanner over a `Substring`'s UTF-8 view (`peek`/`advance`/`expect(ascii:)`/
  `takeWhile`/`matchLiteral`/`isAtEnd`/`currentOffset`) with single-byte lookahead and no
  backtracking, mirroring the streaming style of the reference `nom` grammar. It is the
  substrate for the ZIP-321 URI grammar rewrite.
- **Internal strict `AmountParser`** (`Sources/ZcashPaymentURI/parser/AmountParser.swift`):
  parses an `amount` value through the strict ZIP-321 `amountparam` grammar (via
  `NonNegativeAmount.zec`) and maps `NonNegativeAmount.AmountError` onto the closest v1 `ZIP321.Errors` case
  (`.exceededSupply` → `.amountExceededSupply`, `.invalidDecimalString` →
  `.invalidParamValue`, `.tooManyFractionalDigits`/`.negativeAmount` → `.amountTooSmall`).
- **Internal ZIP-321 `qchar` codec** (`Sources/ZcashPaymentURI/parser/QcharCodec.swift`):
  a self-contained `encode`/`decode` pair that percent-encodes exactly the complement of the
  ZIP-321 `qchar` set, mirroring the reference `QCHAR_ENCODE` `AsciiSet` in librustzcash
  `zip321` (space, `"`, `#`, `%`, `&`, `/`, `<`, `=`, `>`, `?`, `[`, `\`, `]`, `^`, `` ` ``,
  `{`, `|`, `}`, the C0 controls, DEL, and every non-ASCII byte via UTF-8 `%XX`, uppercase
  hex). `decode` is strict: `%XX` must be two hex digits (either case), raw bytes must be
  `qchar` bytes, and the decoded bytes must be valid UTF-8 (overlong sequences, lone
  continuation bytes and unpaired surrogates are rejected). The `String.qcharEncoded()` /
  `qcharDecode()` extensions now delegate to this codec (previously Foundation's
  `addingPercentEncoding` / `removingPercentEncoding`), so decoding is stricter than before.

### Changed
- **The ZIP-321 URI tokenizer was rewritten onto `Scanner`**, replacing the hand-rolled
  substring-combinator (`ZParser`) port with a single-pass grammar that follows the reference
  `nom` pipeline: `zcash:` scheme, `take_till('?')` lead address (empty allowed, non-empty must
  validate), then `&`-separated query segments each parsed as `name [ "." index ] [ "=" value ]`.
  Parameter names must be `ALPHA *( ALPHA / DIGIT / "+" / "-" )` (a percent-escape in a name is
  rejected); indices are `NONZERO 0*3DIGIT` (no leading zero, at most four digits); raw values
  are restricted to `qchar`-permitted bytes. `label`/`message`/`other` values are now
  percent-decoded via `QcharCodec` (previously `other` values were left raw/double-encoded),
  while `address`/`amount`/`memo` values are handed to their own grammars verbatim, so a `%` in
  them is rejected. This fixes the parse/field half of `structure_unknown_param_preserved`
  (its `renderMismatch` remains, tracked as a render-only expected failure pending the S12
  Render restructure). Grouping, duplicate detection, empty-request and legacy-URI behavior are
  unchanged. The dead `ZParser` combinators and the `CharacterSet` definitions they used were
  removed.
- **The parser now enforces the strict `amountparam` grammar.** `amount` values are parsed
  through the new `AmountParser`/`NonNegativeAmount.zec` path instead of the lenient
  `LegacyAmount(string:)`, so a leading or trailing decimal point (`amount=.5`, `amount=123.`),
  a sign, whitespace, scientific notation, or a percent-escape are rejected. `Payment.amount`
  remains `LegacyAmount`-typed (bridged from `NonNegativeAmount` via a new internal `LegacyAmount(zatoshi:)`
  initializer); the public switch to `NonNegativeAmount` is a later step. Conformance vectors
  `invalid_amount_trailing_decimal_point` and `invalid_amount_leading_decimal_point` now pass
  and were removed from the expected-failure map.

### Fixed
- **Empty `qchar` values are now valid**: `QcharString` accepts the empty string (a valid
  zero-length `*qchar` value), so a URI containing an empty `message=` or `label=` now parses
  to a payment with an empty (not rejected) value, matching the reference. The conformance
  vectors `amount_one_with_empty_message` and `amount_parse_simple_large_decimal` now pass and
  were removed from the expected-failure map.
- **Internal strict base64url codec** (`Sources/ZcashPaymentURI/parser/Base64URL.swift`):
  a pure-Swift, Foundation-free implementation of the unpadded
  [RFC 4648 §5](https://www.rfc-editor.org/rfc/rfc4648.html#section-5)
  base64url encoding used by ZIP-321 `memo` values (matching the reference
  implementation's `BASE64_URL_SAFE_NO_PAD`). `decode` strictly rejects `+`,
  `/`, `=` padding, whitespace, any character outside the base64url
  alphabet, impossible lengths (`length % 4 == 1`), and non-canonical
  encodings with nonzero trailing bits. This will replace the
  Foundation-based translate-and-pad decode path inside `MemoBytes`.
- **New public `NonNegativeAmount` value type** (`Sources/ZcashPaymentURI/model/NonNegativeAmount.swift`):
  an `Equatable`, `Hashable`, `Sendable`, `Comparable` wrapper around an
  `Int64` count of zatoshi with `NonNegativeAmount.maxMoney` (`2_100_000_000_000_000`)
  as the upper bound. `Result`-based factories `NonNegativeAmount.zatoshi(_:)` (raw
  zatoshi) and `NonNegativeAmount.zec(_:)` (decimal ZEC string) enforce the **strict**
  ZIP-321 `amountparam` grammar (`1*DIGIT [ "." 1*8DIGIT ]`): leading zeros
  in the whole part are accepted, while `"123."`, `".5"`, empty strings,
  signs, whitespace, and scientific notation are rejected, using checked
  integer arithmetic only. `decimalString()` renders exactly like the
  reference `amount_str` (whole part always, fraction only when nonzero,
  trailing zeros trimmed). `NonNegativeAmount` is amount-agnostic: zero is
  representable; zero-amount policy (e.g. zero-valued transparent outputs)
  belongs to `Payment`-level validation.

### Fixed
- **Zero-length memos are now valid** (conformance fix): `MemoBytes` accepts
  0 to 512 bytes, matching the reference implementation (consensus zero-pads
  memos to 512 bytes, so an empty memo is well-defined). A URI containing
  `memo=` now parses to a payment with an empty (not absent) memo instead of
  being rejected, and the conformance vector `structure_empty_memo_on_sapling`
  now passes — its entry has been removed from the expected-failure map.
  The `MemoBytes.MemoError.memoEmpty` case has been removed accordingly.

### Changed
- **`MemoBytes` rewritten on the strict base64url codec** (and moved to
  `Sources/ZcashPaymentURI/model/MemoBytes.swift`): `init(base64URL:)` and
  `toBase64URL()` now use the internal RFC 4648 §5 `Base64URL` codec instead
  of Foundation's padded base64 with character translation. Decoding is
  stricter than before: `=` padding, impossible lengths (`length % 4 == 1`),
  and non-canonical encodings with nonzero trailing bits are now rejected
  (previously Foundation silently accepted some of these). No other parser
  behavior changes; the remaining expected-failure entries are unchanged.
- **`Amount` is deprecated in favor of `NonNegativeAmount`.** The v1 type keeps working
  unchanged: the struct is now declared as `LegacyAmount` and `Amount` is a
  deprecated public typealias for it, so external code that spells `Amount`
  (or any of its members through that name) gets a deprecation warning while
  remaining 100% source-compatible. The library refers to the type by its
  non-deprecated `LegacyAmount` name internally (the parser's switch to
  `NonNegativeAmount` lands with the v2 parser rewrite), keeping the build warning-free.
- **Breaking (toolchain):** `swift-tools-version` raised to `6.0`; minimum
  platforms raised to macOS 13 / iOS 16.
- **Removed all runtime dependencies.** `zcash-swift-payment-uri` is now a
  zero-dependency package: `swift-parsing`, `swift-case-paths`, `BigDecimal`,
  `BigInt`, and `swift-custom-dump` have all been removed.
  - `Amount` is now backed by a checked `UInt64` zatoshi (1 ZEC =
    100_000_000 zatoshi) fixed-point representation instead of `BigDecimal`,
    mirroring the reference implementation's `u64`-backed `Zatoshis`: a
    ZIP-321 amount is non-negative by grammar, so the unsigned backing type
    makes negative values unrepresentable.
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
- **Test suite migrated from XCTest to [swift-testing](https://github.com/swiftlang/swift-testing).**
  All test files now use `@Suite`/`@Test`/`#expect`/`#require` instead of
  `XCTestCase`/`XCTAssert*`. Files that already looped over a fixed set of
  cases are parameterized with `@Test(arguments:)` (e.g. the conformance
  runner's valid/invalid vectors, the unified-address test vectors). The
  conformance suite's `XCTExpectFailure`-based expected-failure mechanism is
  replaced with `withKnownIssue`, swift-testing's equivalent strict
  expected-failure primitive; the 14-entry `conformanceExpectedFailures` map
  is unchanged and every entry still corresponds to an observed known issue.
  Test coverage is unchanged: 137 tests executed before and after.

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
