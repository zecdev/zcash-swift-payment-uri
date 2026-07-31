//
//  CoverageGapTests.swift
//  zcash-swift-payment-uri
//
//  S16: targeted tests closing the region-coverage gaps identified by
//  `scripts/coverage-gate.sh` that weren't naturally exercised by the
//  existing behavioral test suites — mostly internal helpers, builder
//  overloads nobody had called yet, and total (exhaustive-switch) mapping
//  functions whose only production call site never reaches every case.
//

import Testing
@testable import ZcashPaymentURI

@Suite("CoverageGaps")
struct CoverageGapTests {
    static let saplingTestnet = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
    static let transparentTestnet = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
    static let p2pkhMainnet = "t1Hsc1LR8yKnbbe3twRp88p6vFfC5t7DLbs"

    private func recipient(_ value: String, network: Network = .testnet) throws -> RecipientAddress {
        try #require(RecipientAddress(value: value, validator: ReferenceAddressValidator.of(network)))
    }

    // MARK: - Payment.Builder overloads nobody had called

    @Test func builderAcceptsPrebuiltAmount() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.saplingTestnet))
            .amount(try NonNegativeAmount.zatoshi(50).get())
            .build()
            .get()

        #expect(payment.amount == (try NonNegativeAmount.zatoshi(50).get()))
    }

    @Test func builderAcceptsPrebuiltMemoBytes() throws {
        let memo = try MemoBytes(utf8String: "hi")
        let payment = try Payment.Builder(recipient: try recipient(Self.saplingTestnet))
            .memo(memo)
            .build()
            .get()

        #expect(payment.memo == memo)
    }

    @Test func builderMemoUtf8TooLongSurfacesAsMemoBytesError() throws {
        let result = Payment.Builder(recipient: try recipient(Self.saplingTestnet))
            .memo(utf8: String(repeating: "a", count: 513))
            .build()

        #expect(result == .failure(.memoBytesError(index: nil)))
    }

    @Test func builderLabelIsStoredVerbatim() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.saplingTestnet))
            .label("a label")
            .build()
            .get()

        #expect(payment.label == "a label")
    }

    @Test func builderOtherParamSucceedsWithValidNameAndValue() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.saplingTestnet))
            .otherParam(name: "foo", value: "bar")
            .otherParam(name: "novalue", value: nil)
            .build()
            .get()

        #expect(payment.otherParams.map(\.name) == ["foo", "novalue"])
        #expect(payment.otherParams.map(\.value) == [Optional("bar"), nil])
    }

    // MARK: - PaymentRequestBuilder DSL: for-loops and if-without-else

    @Test func resultBuilderSupportsForLoops() throws {
        let payments = try [Self.saplingTestnet, Self.transparentTestnet].map { addr in
            try Payment.Builder(recipient: try recipient(addr)).amount(zec: "1").build().get()
        }

        let request = try PaymentRequest.build {
            for payment in payments {
                payment
            }
        }.get()

        #expect(request.indexedPayments.map(\.index) == [0, 1])
    }

    @Test func resultBuilderSupportsIfWithoutElse() throws {
        let alice = try Payment.Builder(recipient: try recipient(Self.saplingTestnet)).amount(zec: "1").build().get()
        let bob = try Payment.Builder(recipient: try recipient(Self.transparentTestnet)).amount(zec: "2").build().get()

        let includeBob = true
        let withBob = try PaymentRequest.build {
            alice
            if includeBob {
                bob
            }
        }.get()
        #expect(withBob.indexedPayments.map(\.index) == [0, 1])

        let includeCarol = false
        let withoutCarol = try PaymentRequest.build {
            alice
            if includeCarol {
                bob
            }
        }.get()
        #expect(withoutCarol.indexedPayments.map(\.index) == [0])
    }

    // MARK: - PaymentRequest(indexedPayments:) direct duplicate-index throw

    @Test func paymentRequestIndexedPaymentsRejectsDuplicateIndex() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.transparentTestnet)).build().get()

        #expect(throws: ZIP321Error.duplicateParameter(name: "address", index: nil)) {
            try PaymentRequest(indexedPayments: [(index: 0, payment: payment), (index: 0, payment: payment)])
        }
    }

    // MARK: - Deprecated Payment.init(...)

    @available(*, deprecated) // silences the deprecation warning inside the test body
    @Test func deprecatedPaymentInitConstructsSuccessfully() throws {
        let address = try recipient(Self.saplingTestnet)
        let payment = try Payment(
            recipientAddress: address,
            amount: try NonNegativeAmount.zec("1").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        )

        #expect(payment.recipientAddress == address)
    }

    @available(*, deprecated) // silences the deprecation warning inside the test body
    @Test func deprecatedPaymentInitPropagatesStructuralError() throws {
        let address = try recipient(Self.transparentTestnet)

        #expect(throws: ZIP321Error.transparentMemo(index: nil)) {
            try Payment(
                recipientAddress: address,
                amount: nil,
                memo: try MemoBytes(utf8String: "not allowed on transparent"),
                label: nil,
                message: nil,
                otherParams: []
            )
        }
    }

    // MARK: - Parser internal helpers reachable directly (not via the public parse path)

    @Test func qcharStringStrictModeRejectsUndecodablePercentEscape() {
        // "%ZZ" is not a valid hex escape, so `value.qcharDecode()` itself
        // returns `nil` (distinct from the already-covered case where decode
        // succeeds but round-trips to a different string).
        #expect(QcharString(value: "abc%ZZ", strictMode: true) == nil)
    }

    @Test func qcharStringStrictModeAcceptsAlreadyEncodedValue() {
        // A value with no characters needing escaping round-trips through
        // `qcharDecode()` unchanged, so `strictMode` accepts it (the guard's
        // success path — as opposed to either strictMode failure mode above).
        let alreadyEncoded = "alreadyPlainAsciiNoEscapesNeeded"
        #expect(QcharString(value: alreadyEncoded, strictMode: true)?.value == alreadyEncoded)
    }

    @Test func leadingAddressWithNonZcashPrefixThrows() {
        #expect(throws: (any Error).self) {
            try Parser.leadingAddress("http://example.com", network: .mainnet, validator: ReferenceAddressValidator.mainnet)
        }
    }

    @Test func parseParamIndexRejectsTrailingGarbage() {
        #expect(throws: (any Error).self) {
            try Parser.parseParamIndex("12x"[...])
        }
    }

    @Test func parseNameAndIndexRejectsTrailingGarbage() {
        #expect(throws: (any Error).self) {
            try Parser.parseNameAndIndex("name.5!"[...])
        }
    }

    @Test func parseParametersRequiresLeadingQuestionMark() {
        #expect(throws: (any Error).self) {
            try Parser.parseParameters("amount=1"[...], leadingAddress: nil, network: .mainnet, validator: ReferenceAddressValidator.mainnet)
        }
    }

    @Test func mapToIndexedPaymentsRejectsEmptyParameterList() {
        #expect(throws: (any Error).self) {
            try Parser.mapToIndexedPayments([])
        }
    }

    @Test func mapToPaymentsSucceedsAndDiscardsIndices() throws {
        // Every other `mapToPayments` call site in the suite exercises a
        // duplicate-parameter failure; this covers its success path
        // (`mapToIndexedPayments(...).map(\.payment)` actually completing).
        let address = try recipient(Self.saplingTestnet)
        let indexed = [IndexedParameter(index: 0, param: .address(address))]

        let payments = try Parser.mapToPayments(indexed)

        #expect(payments.count == 1)
        #expect(payments[0].recipientAddress == address)
    }

    @Test func sproutAddressAtPositiveIndexSurfacesAsInvalidAddress() {
        let sproutMainnet = "zcU1Cd6zYyZCd2VJF8yKgmzjxdiiU1rgTTjEwoN1CGUWCziPkUTXUjXmX7TMqdMNsTfuiGN1jQoVN4kGxUR4sAPN4XZ7pxb"

        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: sproutMainnet, index: 3, network: .mainnet, validator: ReferenceAddressValidator.mainnet)
        }

        let uri = "zcash:?address.3=\(sproutMainnet)&amount.3=1"
        #expect(ZIP321.parse(uri, expecting: .mainnet, validator: ReferenceAddressValidator.mainnet) == .failure(.invalidAddress(index: 3)))
    }

    @Test func sproutAddressAsQueryParamAtEmptyIndexSurfacesAsInvalidAddress() {
        // Distinct from the positive-index case above: `address=` with no
        // `.N` suffix resolves to index 0, exercising the ternary's `nil`
        // (as opposed to `index`) branch in `Param.from`'s sprout check.
        let sproutMainnet = "zcU1Cd6zYyZCd2VJF8yKgmzjxdiiU1rgTTjEwoN1CGUWCziPkUTXUjXmX7TMqdMNsTfuiGN1jQoVN4kGxUR4sAPN4XZ7pxb"

        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: sproutMainnet, index: 0, network: .mainnet, validator: ReferenceAddressValidator.mainnet)
        }

        let uri = "zcash:?address=\(sproutMainnet)&amount=1"
        #expect(ZIP321.parse(uri, expecting: .mainnet, validator: ReferenceAddressValidator.mainnet) == .failure(.invalidAddress(index: nil)))
    }

    @Test func mapToErrorOrRethrowRethrowsWhenCastFails() {
        struct OtherError: Error, Equatable {}

        #expect(throws: OtherError()) {
            try OtherError().mapToErrorOrRethrow(MemoBytes.MemoError.self)
        }
    }

    @Test func indexedInvalidNonSproutAddressSurfacesAsInvalidAddress() throws {
        // Checksum-corrupted (last char changed), NOT a Sprout address, at a
        // positive `paramindex` — exercises the `invalidAddress(index > 0 ?
        // index : nil)` branch specifically (as opposed to the sprout branch,
        // already covered elsewhere).
        let corrupted = String(Self.p2pkhMainnet.dropLast()) + "t"

        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: corrupted, index: 3, network: .mainnet, validator: ReferenceAddressValidator.mainnet)
        }

        let uri = "zcash:?address.3=\(corrupted)&amount.3=1"
        #expect(ZIP321.parse(uri, expecting: .mainnet, validator: ReferenceAddressValidator.mainnet) == .failure(.invalidAddress(index: 3)))
    }

    @Test func otherParamValueWithInvalidPercentEscapeFailsToParse() {
        let uri = "zcash:\(Self.saplingTestnet)?amount=1&customparam=abc%ZZ"
        #expect(ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.parseError(reason: .invalidParameter)))
    }

    @Test func labelWithInvalidPercentEscapeFailsToParse() {
        let uri = "zcash:\(Self.transparentTestnet)?amount=1&label=abc%ZZ"
        #expect(ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.parseError(reason: .invalidParameter)))
    }

    @Test func messageWithInvalidPercentEscapeFailsToParse() {
        let uri = "zcash:\(Self.transparentTestnet)?amount=1&message=abc%ZZ"
        #expect(ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.parseError(reason: .invalidParameter)))
    }

    // MARK: - NonNegativeAmount.zec whole-part-exceeds-maxMoney guard (no fractional part)

    @Test func zecRejectsWholePartAboveMaxMoneyWithoutFraction() {
        // "21000001" parses cleanly as an Int64 (unlike the huge-digit-run
        // overflow vectors elsewhere) but its whole-ZEC part alone already
        // exceeds `maxMoney / zatoshiPerZec` (21,000,000) — this exercises
        // that specific bound, distinct from the Int64-parse-failure path and
        // the fractional-part total-overflow path (both already covered).
        #expect(NonNegativeAmount.zec("21000001") == .failure(.exceededSupply))
    }

    // MARK: - Render.request(.enumerateAllPayments) non-empty branch

    @Test func enumerateAllPaymentsRendersSequentialIndicesFromOne() throws {
        let recipientA = try recipient(Self.transparentTestnet)
        let recipientB = try recipient(Self.saplingTestnet)

        let paymentA = try Payment.create(
            recipientAddress: recipientA, amount: try NonNegativeAmount.zec("1").get(),
            memo: nil, label: nil, message: nil, otherParams: []
        ).get()
        let paymentB = try Payment.create(
            recipientAddress: recipientB, amount: try NonNegativeAmount.zec("2").get(),
            memo: nil, label: nil, message: nil, otherParams: []
        ).get()

        // Sparse, non-contiguous stored indices — enumerateAllPayments
        // discards them and renumbers sequentially from 1.
        let request = try PaymentRequest(indexedPayments: [(index: 5, payment: paymentA), (index: 9, payment: paymentB)])

        let uri = ZIP321.uriString(from: request, formattingOptions: .enumerateAllPayments)
        #expect(
            uri == "zcash:?address.1=\(Self.transparentTestnet)&amount.1=1"
            + "&address.2=\(Self.saplingTestnet)&amount.2=2"
        )
    }

    // MARK: - ZIP321.request(_:formattingOptions:) default branch

    @Test func requestWithExplicitAddressLabelUsesAddressEqualsForm() throws {
        let address = try recipient(Self.saplingTestnet)

        let payment = try Payment.create(
            recipientAddress: address, amount: nil,
            memo: nil, label: nil, message: nil, otherParams: []
        ).get()

        // Regression (found via Kotlin parity review): both labeled forms previously
        // omitted the mandatory "?" and rendered unparsable URIs.
        let labeled = ZIP321.request(address, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false))
        #expect(labeled == "zcash:?address=\(Self.saplingTestnet)")
        #expect(
            try ZIP321.parse(labeled, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()
            == PaymentRequest(singlePayment: payment)
        )

        let enumerated = ZIP321.request(address, formattingOptions: .enumerateAllPayments)
        #expect(enumerated == "zcash:?address.1=\(Self.saplingTestnet)")
        #expect(
            try ZIP321.parse(enumerated, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()
            == (try PaymentRequest(indexedPayments: [(index: 1, payment: payment)]))
        )
    }

    // MARK: - Bech32.verify's decode-failure branch

    @Test func bech32VerifyReturnsFalseWhenDecodeFails() {
        #expect(!Bech32.verify("not a valid bech32 string!!", expectedHrp: "zs", variant: .bech32))
    }

    // MARK: - ZIP321Error.withIndex(_:) — exhaustive over every case

    @Test func withIndexRetagsEveryIndexBearingCase() {
        #expect(ZIP321Error.invalidBase64(index: nil).withIndex(3) == .invalidBase64(index: 3))
        #expect(ZIP321Error.memoBytesError(index: nil).withIndex(3) == .memoBytesError(index: 3))
        #expect(ZIP321Error.transparentMemo(index: nil).withIndex(3) == .transparentMemo(index: 3))
        #expect(ZIP321Error.zeroValuedTransparentOutput(index: nil).withIndex(3) == .zeroValuedTransparentOutput(index: 3))
        #expect(ZIP321Error.recipientMissing(index: nil).withIndex(3) == .recipientMissing(index: 3))
        #expect(ZIP321Error.invalidAddress(index: nil).withIndex(3) == .invalidAddress(index: 3))
        #expect(ZIP321Error.amountExceededSupply(index: nil).withIndex(3) == .amountExceededSupply(index: 3))
        #expect(ZIP321Error.amountInvalid(index: nil).withIndex(3) == .amountInvalid(index: 3))
        #expect(
            ZIP321Error.duplicateParameter(name: "address", index: nil).withIndex(3)
            == .duplicateParameter(name: "address", index: 3)
        )
    }

    @Test func withIndexIsIdentityForNonIndexBearingCases() {
        #expect(ZIP321Error.tooManyPayments(count: 5).withIndex(3) == .tooManyPayments(count: 5))
        #expect(
            ZIP321Error.unknownRequiredParameter(name: "req-x").withIndex(3)
            == .unknownRequiredParameter(name: "req-x")
        )
        #expect(ZIP321Error.invalidParamIndex(raw: "12345").withIndex(3) == .invalidParamIndex(raw: "12345"))
        #expect(ZIP321Error.invalidURI(reason: .malformedURI).withIndex(3) == .invalidURI(reason: .malformedURI))
        #expect(ZIP321Error.parseError(reason: .malformedURI).withIndex(3) == .parseError(reason: .malformedURI))
    }

    // MARK: - ZIP321Error.init(_ legacy:) — exhaustive over every ZIP321.Errors case

    @Test func legacyErrorTranslationCoversEveryCase() {
        #expect(ZIP321Error(ZIP321.Errors.amountExceededSupply(5)) == .amountExceededSupply(index: 5))
        #expect(ZIP321Error(ZIP321.Errors.amountExceededSupply(0)) == .amountExceededSupply(index: nil))
        #expect(ZIP321Error(ZIP321.Errors.amountTooSmall(5)) == .amountInvalid(index: 5))
        #expect(ZIP321Error(ZIP321.Errors.amountTooSmall(0)) == .amountInvalid(index: nil))
        #expect(
            ZIP321Error(ZIP321.Errors.duplicateParameter("address", 3))
            == .duplicateParameter(name: "address", index: 3)
        )
        #expect(ZIP321Error(ZIP321.Errors.invalidAddress(3)) == .invalidAddress(index: 3))
        #expect(ZIP321Error(ZIP321.Errors.invalidBase64) == .invalidBase64(index: nil))
        #expect(ZIP321Error(ZIP321.Errors.invalidURI) == .invalidURI(reason: .malformedURI))
        #expect(
            ZIP321Error(ZIP321.Errors.memoBytesError(MemoBytes.MemoError.memoTooLong, 3))
            == .memoBytesError(index: 3)
        )
        #expect(ZIP321Error(ZIP321.Errors.tooManyPayments(20_000)) == .tooManyPayments(count: 20_000))
        #expect(ZIP321Error(ZIP321.Errors.transparentMemoNotAllowed(3)) == .transparentMemo(index: 3))
        #expect(ZIP321Error(ZIP321.Errors.recipientMissing(3)) == .recipientMissing(index: 3))
        #expect(ZIP321Error(ZIP321.Errors.invalidParamIndex("12345")) == .invalidParamIndex(raw: "12345"))
        #expect(
            ZIP321Error(ZIP321.Errors.invalidParamValue(param: "amount", index: 3))
            == .amountInvalid(index: 3)
        )
        #expect(
            ZIP321Error(ZIP321.Errors.invalidParamValue(param: "somethingelse", index: 3))
            == .parseError(reason: .invalidParameter)
        )
        #expect(ZIP321Error(ZIP321.Errors.parseError("x")) == .parseError(reason: .malformedURI))
        #expect(ZIP321Error(ZIP321.Errors.qcharDecodeFailed("x")) == .parseError(reason: .invalidParameter))
        #expect(ZIP321Error(ZIP321.Errors.qcharEncodeFailed("x")) == .parseError(reason: .invalidParameter))
        #expect(
            ZIP321Error(ZIP321.Errors.unknownRequiredParameter("req-x"))
            == .unknownRequiredParameter(name: "req-x")
        )
        #expect(ZIP321Error(ZIP321.Errors.sproutRecipientsNotAllowed(3)) == .invalidAddress(index: 3))
        #expect(
            ZIP321Error(ZIP321.Errors.zeroValuedTransparentOutput(3))
            == .zeroValuedTransparentOutput(index: 3)
        )
        #expect(
            ZIP321Error(ZIP321.Errors.otherParamUsesReservedKey("x"))
            == .parseError(reason: .invalidParameter)
        )
        #expect(
            ZIP321Error(ZIP321.Errors.otherParamEncodingError("x"))
            == .parseError(reason: .invalidParameter)
        )
        #expect(ZIP321Error(ZIP321.Errors.otherParamKeyEmpty) == .parseError(reason: .invalidParameter))
    }

    // MARK: - ZIP321.Errors.mapFrom — exhaustive over every MemoError / AmountError case

    @Test func memoErrorMapFromCoversEveryCase() {
        guard case .invalidBase64 = ZIP321.Errors.mapFrom(MemoBytes.MemoError.invalidBase64URL, index: 3) else {
            Issue.record("expected .invalidBase64")
            return
        }
        guard case let .memoBytesError(_, i1) = ZIP321.Errors.mapFrom(MemoBytes.MemoError.memoTooLong, index: 3) else {
            Issue.record("expected .memoBytesError")
            return
        }
        #expect(i1 == 3)
        guard case let .memoBytesError(_, i2) = ZIP321.Errors.mapFrom(MemoBytes.MemoError.notUTF8String, index: 0) else {
            Issue.record("expected .memoBytesError")
            return
        }
        #expect(i2 == nil)
    }

    @Test func amountErrorMapFromCoversEveryCase() {
        guard case let .amountExceededSupply(i1) = ZIP321.Errors.mapFrom(NonNegativeAmount.AmountError.exceededSupply, index: 3) else {
            Issue.record("expected .amountExceededSupply")
            return
        }
        #expect(i1 == 3)

        guard case let .invalidParamValue(param, i2) = ZIP321.Errors.mapFrom(NonNegativeAmount.AmountError.invalidDecimalString, index: 3) else {
            Issue.record("expected .invalidParamValue")
            return
        }
        #expect(param == "amount")
        #expect(i2 == 3)

        guard case let .amountTooSmall(i3) = ZIP321.Errors.mapFrom(NonNegativeAmount.AmountError.tooManyFractionalDigits, index: 3) else {
            Issue.record("expected .amountTooSmall")
            return
        }
        #expect(i3 == 3)

        // `.negativeAmount` is not reachable via `NonNegativeAmount.zec` (the grammar has
        // no sign), but the total mapping function still handles it — tested
        // directly here for that reason.
        guard case let .amountTooSmall(i4) = ZIP321.Errors.mapFrom(NonNegativeAmount.AmountError.negativeAmount, index: 3) else {
            Issue.record("expected .amountTooSmall")
            return
        }
        #expect(i4 == 3)
    }
}
