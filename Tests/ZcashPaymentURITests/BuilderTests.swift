//
//  BuilderTests.swift
//  zcash-swift-payment-uri
//
//  S14: fluent builders + result-builder sugar.
//
//  Covers the "four scenarios" cross-language construction contract (simple
//  single-address request, amount+memo payment, multi-payment, and parse with
//  an injected validator), deferred-error surfacing at `build()`, and
//  equivalence between the `@resultBuilder` DSL and the explicit
//  `PaymentRequest.Builder`.
//

import Testing
@testable import ZcashPaymentURI

@Suite("Builders")
struct BuilderTests {
    static let sapling = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
    static let sapling2 = "ztestsapling1n65uaftvs2g7075q2x2a04shfk066u3lldzxsrprfrqtzxnhc9ps73v4lhx4l9yfxj46sl0q90k"
    static let transparent = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

    private func recipient(_ value: String) throws -> RecipientAddress {
        try #require(RecipientAddress(value: value, validator: ReferenceAddressValidator.testnet))
    }

    // MARK: - (a) simple single-address request

    @Test func scenarioSimpleSingleAddress() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.sapling))
            .build()
            .get()

        let request = try PaymentRequest.Builder()
            .add(payment)
            .build()
            .get()

        #expect(request.indexedPayments.map(\.index) == [0])
        #expect(request.payments.first?.recipientAddress.value == Self.sapling)
        #expect(request.payments.first?.amount == nil)

        // Renders to the canonical leading-address form.
        #expect(ZIP321.uriString(from: request) == "zcash:\(Self.sapling)")
    }

    // MARK: - (b) amount + memo payment

    @Test func scenarioAmountAndMemoPayment() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.sapling))
            .amount(zec: "1.2345")
            .memo(utf8: "Thanks!")
            .message("Invoice #42")
            .build()
            .get()

        #expect(payment.amount == (try? NonNegativeAmount.zec("1.2345").get()))
        #expect(payment.memo?.toBase64URL() == (try MemoBytes(utf8String: "Thanks!").toBase64URL()))
        #expect(payment.message == "Invoice #42")
        #expect(payment.label == nil)

        // Equivalent to the direct factory.
        let direct = try Payment.create(
            recipientAddress: try recipient(Self.sapling),
            amount: try NonNegativeAmount.zec("1.2345").get(),
            memo: try MemoBytes(utf8String: "Thanks!"),
            label: nil,
            message: "Invoice #42",
            otherParams: []
        ).get()

        #expect(payment == direct)
    }

    // MARK: - (c) multi-payment request

    @Test func scenarioMultiPayment() throws {
        let alice = try Payment.Builder(recipient: try recipient(Self.transparent))
            .amount(zec: "123.456")
            .build()
            .get()

        let bob = try Payment.Builder(recipient: try recipient(Self.sapling))
            .amount(zec: "0.789")
            .memo(utf8: "hi bob")
            .build()
            .get()

        let request = try PaymentRequest.Builder()
            .add(alice)
            .add(bob)
            .build()
            .get()

        #expect(request.indexedPayments.map(\.index) == [0, 1])
        #expect(request.payments[0].recipientAddress.value == Self.transparent)
        #expect(request.payments[1].recipientAddress.value == Self.sapling)

        // Explicit non-sequential index is preserved.
        let pinned = try PaymentRequest.Builder()
            .add(alice)
            .add(bob, at: 7)
            .build()
            .get()
        #expect(pinned.indexedPayments.map(\.index) == [0, 7])
    }

    // MARK: - (d) parse with the caller's validator

    @Test func scenarioParseWithInjectedValidator() throws {
        let uri = "zcash:\(Self.sapling)?amount=1"

        // The validator is the sole authority: its rejection is final, even for
        // a checksum-valid address.
        let rejectAll = ZIP321.parse(uri, expecting: .testnet, validator: ClosureAddressValidator { _ in nil })
        #expect(rejectAll == .failure(.invalidAddress(index: nil)))

        // …and its acceptance is equally final. Nothing in the library
        // re-checks the address.
        let permissive = ClosureAddressValidator { address in
            address.hasPrefix("ztestsapling")
                ? AddressDescriptor(network: .testnet, isTransparent: false, canReceiveMemos: true)
                : nil
        }
        let request = try ZIP321.parse(uri, expecting: .testnet, validator: permissive).get()

        #expect(request.payments.first?.recipientAddress.value == Self.sapling)
    }

    // MARK: - deferred-error surfacing

    @Test func deferredBadZecStringSurfacesAsAmountInvalid() throws {
        let result = Payment.Builder(recipient: try recipient(Self.sapling))
            .amount(zec: "not-a-number")
            .build()

        #expect(result == .failure(.amountInvalid(index: nil)))
    }

    @Test func deferredAboveMaxMoneySurfacesAsAmountExceededSupply() throws {
        let result = Payment.Builder(recipient: try recipient(Self.sapling))
            .amount(zec: "21000000.00000001")
            .build()

        #expect(result == .failure(.amountExceededSupply(index: nil)))
    }

    @Test func deferredMemoOnTransparentRecipientSurfacesAsTransparentMemo() throws {
        let result = Payment.Builder(recipient: try recipient(Self.transparent))
            .amount(zec: "1")
            .memo(utf8: "memos not allowed to transparent")
            .build()

        #expect(result == .failure(.transparentMemo(index: nil)))
    }

    @Test func deferredReservedOtherParamKeySurfacesAtBuild() throws {
        let result = Payment.Builder(recipient: try recipient(Self.sapling))
            .otherParam(name: "amount", value: "2")
            .build()

        #expect(result == .failure(.parseError(reason: .invalidParameter)))
    }

    @Test func firstDeferredErrorWinsInFieldOrder() throws {
        // Both amount and other-param are invalid; amount (checked first) wins.
        let result = Payment.Builder(recipient: try recipient(Self.sapling))
            .amount(zec: "bogus")
            .otherParam(name: "", value: "x")
            .build()

        #expect(result == .failure(.amountInvalid(index: nil)))
    }

    @Test func duplicateIndexSurfacesAsDuplicateParameter() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.sapling)).build().get()

        let result = PaymentRequest.Builder()
            .add(payment, at: 3)
            .add(payment, at: 3)
            .build()

        #expect(result == .failure(.duplicateParameter(name: "address", index: 3)))
    }

    @Test func aboveMaxIndexSurfacesAsTooManyPayments() throws {
        let payment = try Payment.Builder(recipient: try recipient(Self.sapling)).build().get()

        let result = PaymentRequest.Builder()
            .add(payment, at: 10_000)
            .build()

        #expect(result == .failure(.tooManyPayments(count: 10_000)))
    }

    // MARK: - result-builder sugar equivalence

    @Test func sugarMatchesExplicitBuilder() throws {
        let alice = try Payment.Builder(recipient: try recipient(Self.transparent))
            .amount(zec: "123.456")
            .build()
            .get()

        let bob = try Payment.Builder(recipient: try recipient(Self.sapling))
            .amount(zec: "0.789")
            .memo(utf8: "hi bob")
            .build()
            .get()

        let sugar = try PaymentRequest.build {
            alice
            bob
        }.get()

        let explicit = try PaymentRequest.Builder()
            .add(alice)
            .add(bob)
            .build()
            .get()

        #expect(sugar == explicit)
    }

    @Test func sugarAcceptsSinglePayment() throws {
        let alice = try Payment.Builder(recipient: try recipient(Self.sapling))
            .amount(zec: "1")
            .build()
            .get()

        let sugar = try PaymentRequest.build { alice }.get()
        let explicit = try PaymentRequest.Builder().add(alice).build().get()

        #expect(sugar == explicit)
    }

    @Test func sugarAcceptsArrayOfPayments() throws {
        let payments = try [Self.sapling, Self.sapling2, Self.transparent].map { addr in
            try Payment.Builder(recipient: try recipient(addr)).amount(zec: "1").build().get()
        }

        let sugar = try PaymentRequest.build { payments }.get()
        let explicit = try PaymentRequest.Builder(payments: payments).build().get()

        #expect(sugar == explicit)
        #expect(sugar.indexedPayments.map(\.index) == [0, 1, 2])
    }

    @Test func sugarEmptyBlockProducesEmptyRequest() throws {
        let empty = try PaymentRequest.build {}.get()

        #expect(empty.payments.isEmpty)
        #expect(empty == (try PaymentRequest(payments: [])))
    }
}
