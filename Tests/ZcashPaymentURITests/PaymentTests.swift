//
//  PaymentTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-14.
//

import Testing
@testable import ZcashPaymentURI

@Suite("Payment")
struct PaymentTests {
    // MARK: Param validation - no memos to transparent

    @Test func throwsWhenMemoIsPresentOnTransparentRecipient() throws {
        let recipient = try #require(RecipientAddress(
            value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
            validator: ReferenceAddressValidator.testnet
        ))

        let params: [Param] = [
            .address(recipient),
            .amount(try NonNegativeAmount.zec("1").get()),
            .message(QcharString(value: "Thanks")!),
            .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg")),
            .label(QcharString(value: "payment")!),
            .other(try OtherParam(name: "future", value: "is awesome"))
        ]

        #expect {
            try Payment.uniqueIndexedParameters(index: 1, parameters: params)
        } throws: { error in
            guard case ZIP321Error.transparentMemo(index: 1) = error else { return false }
            return true
        }
    }

    // MARK: Payment Validation
    @Test func paymentIsCreatedFromIndexedParameters() throws {
        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            validator: ReferenceAddressValidator.testnet
        ))

        let params: [Param] = [
            .address(recipient),
            .amount(try NonNegativeAmount.zec("1").get()),
            .message(QcharString(value: "Thanks")!),
            .label(QcharString(value: "payment")!),
            .other(try OtherParam(name: "future", value: "is awesome"))
        ]

        let payment = try Payment.uniqueIndexedParameters(index: 1, parameters: params)

        #expect(try Payment.create(
            recipientAddress: recipient,
            amount: try NonNegativeAmount.zec("1").get(),
            memo: nil,
            label: "payment",
            message: "Thanks",
            otherParams: [OtherParam(name: "future", value: "is awesome")]
        ).get() == payment)
    }

    // MARK: Zero-valued transparent output (to_payment consensus check)

    @Test func createRejectsZeroValuedTransparentOutput() throws {
        let recipient = try #require(RecipientAddress(
            value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
            validator: ReferenceAddressValidator.testnet
        ))

        let result = Payment.create(
            recipientAddress: recipient,
            amount: try NonNegativeAmount.zec("0").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        )

        #expect(result == .failure(.zeroValuedTransparentOutput(index: nil)))
    }

    @Test func createAllowsZeroValuedShieldedOutput() throws {
        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            validator: ReferenceAddressValidator.testnet
        ))

        #expect(throws: Never.self) {
            try Payment.create(
                recipientAddress: recipient,
                amount: try NonNegativeAmount.zec("0").get(),
                memo: nil,
                label: nil,
                message: nil,
                otherParams: []
            ).get()
        }
    }
}
