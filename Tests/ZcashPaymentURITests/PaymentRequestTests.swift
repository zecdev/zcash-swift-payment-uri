//
//  PaymentRequestTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2026-07.
//
//  Tests for the v2 `PaymentRequest` model: paramindex preservation,
//  the 9999-payment cap, index uniqueness, and empty requests.
//

import Testing
@testable import ZcashPaymentURI

@Suite("PaymentRequest")
struct PaymentRequestTests {
    static let saplingTestnet = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

    private func addressOnlyPayment() throws -> Payment {
        let recipient = try #require(RecipientAddress(value: Self.saplingTestnet, validator: ReferenceAddressValidator.testnet))
        return try Payment.create(
            recipientAddress: recipient,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()
    }

    // MARK: paramindex preservation

    /// Parsing a request whose ONLY payment sits at paramindex 5 preserves
    /// that index in `indexedPayments` (the index-gap corpus vector's parse
    /// side; its render side remains an S13 xfail).
    @Test func parsePreservesNonSequentialParamIndex() throws {
        let uri = "zcash:?address.5=\(Self.saplingTestnet)&amount.5=1"

        let request = try ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        let indexed = request.indexedPayments
        #expect(indexed.count == 1)
        #expect(indexed.first?.index == 5)
        #expect(indexed.first?.payment.recipientAddress.value == Self.saplingTestnet)
        #expect(indexed.first?.payment.amount == (try? NonNegativeAmount.zec("1").get()))

        // the flat accessor still exposes the payment.
        #expect(request.payments.count == 1)
    }

    @Test func indexedPaymentsAreSortedByIndex() throws {
        let payment = try addressOnlyPayment()

        let request = try PaymentRequest(indexedPayments: [
            (index: 7, payment: payment),
            (index: 0, payment: payment),
            (index: 3, payment: payment)
        ])

        #expect(request.indexedPayments.map(\.index) == [0, 3, 7])
        #expect(request.payments.count == 3)
    }

    @Test func sequentialInitAutoIndexesFromZero() throws {
        let payment = try addressOnlyPayment()

        let request = try PaymentRequest(payments: [payment, payment, payment])

        #expect(request.indexedPayments.map(\.index) == [0, 1, 2])
    }

    // MARK: empty requests

    @Test func emptyRequestIsValidAndRendersBareScheme() throws {
        let request = try PaymentRequest(payments: [])
        #expect(request.payments.isEmpty)
        #expect(request.indexedPayments.isEmpty)

        #expect(
            ZIP321.uriString(from: request, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true))
            == "zcash:"
        )
        #expect(ZIP321.uriString(from: request, formattingOptions: .enumerateAllPayments) == "zcash:")
    }

    // MARK: 9999-payment cap
    //
    // NOTE (mirroring the reference `TransactionRequest`): the cap is only
    // reachable through the constructors. The parse path can never hit it,
    // because the `paramindex` grammar (`NONZERO 0*3DIGIT`) already rejects
    // any index above 9999 with `invalidParamIndex` before payments are built.

    @Test func sequentialInitRejectsMoreThanMaxPayments() throws {
        let payment = try addressOnlyPayment()
        let payments = Array(repeating: payment, count: 10_000)

        #expect {
            try PaymentRequest(payments: payments)
        } throws: { error in
            guard case ZIP321Error.tooManyPayments(count: 10_000) = error else { return false }
            return true
        }
    }

    @Test func sequentialInitAcceptsExactlyMaxPayments() throws {
        let payment = try addressOnlyPayment()
        let payments = Array(repeating: payment, count: 9_999)

        #expect(throws: Never.self) {
            try PaymentRequest(payments: payments)
        }
    }

    @Test func indexedInitRejectsIndexAboveMaximum() throws {
        let payment = try addressOnlyPayment()

        #expect {
            try PaymentRequest(indexedPayments: [(index: 10_000, payment: payment)])
        } throws: { error in
            guard case ZIP321Error.tooManyPayments(count: 10_000) = error else { return false }
            return true
        }
    }

    @Test func indexedInitAcceptsMaximumIndex() throws {
        let payment = try addressOnlyPayment()

        #expect(throws: Never.self) {
            try PaymentRequest(indexedPayments: [(index: 9_999, payment: payment)])
        }
    }

    // MARK: index uniqueness

    @Test func indexedInitRejectsDuplicateIndices() throws {
        let payment = try addressOnlyPayment()

        #expect {
            try PaymentRequest(indexedPayments: [
                (index: 1, payment: payment),
                (index: 1, payment: payment)
            ])
        } throws: { error in
            guard case ZIP321Error.duplicateParameter(name: "address", index: 1) = error else { return false }
            return true
        }
    }

    // MARK: input guards on parse()

    @Test func parseRejectsEmptyInput() {
        #expect(ZIP321.parse("", expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.parseError(reason: .emptyInput)))
    }

    @Test func parseRejectsOversizedInput() {
        let uri = "zcash:" + String(repeating: "a", count: ZIP321.defaultMaxInputBytes)
        #expect(ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.invalidURI(reason: .inputTooLarge)))
    }

    @Test func parseRespectsCustomMaxInputBytes() {
        let uri = "zcash:\(Self.saplingTestnet)"
        #expect(
            ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet, maxInputBytes: 8)
            == .failure(.invalidURI(reason: .inputTooLarge))
        )
    }

    @Test func parseRejectsNonZcashScheme() {
        #expect(
            ZIP321.parse("bitcoin:whatever", expecting: .testnet, validator: ReferenceAddressValidator.testnet)
            == .failure(.invalidURI(reason: .notZcashScheme))
        )
    }

    @Test func parseRejectsAuthorityComponent() {
        #expect(
            ZIP321.parse("zcash://tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU?amount=1", expecting: .testnet, validator: ReferenceAddressValidator.testnet)
            == .failure(.invalidURI(reason: .invalidAuthority))
        )
    }

    // MARK: totality

    @Test func parseIsTotalOverBothSingleRecipientSpellings() throws {
        let uri = "zcash:\(Self.saplingTestnet)"
        let request = try ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        #expect(request.payments.first?.recipientAddress.value == Self.saplingTestnet)

        #expect(
            ZIP321.parse("", expecting: .testnet, validator: ReferenceAddressValidator.testnet)
            == .failure(.parseError(reason: .emptyInput))
        )
    }
}
