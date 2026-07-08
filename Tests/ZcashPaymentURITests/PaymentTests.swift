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
            context: .testnet
        ))

        let params: [Param] = [
            .address(recipient),
            .amount(try LegacyAmount(value: 1)),
            .message(QcharString(value: "Thanks")!),
            .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg")),
            .label(QcharString(value: "payment")!),
            .other(
                try OtherParam(
                    key: ParamNameString(
                        value: "future"
                    )!,
                    value: QcharString(
                        value: "is awesome"
                    )!
                )
            )
        ]

        #expect {
            try Payment.uniqueIndexedParameters(index: 1, parameters: params)
        } throws: { error in
            guard case ZIP321.Errors.transparentMemoNotAllowed(1) = error else { return false }
            return true
        }
    }

    // MARK: Payment Validation
    @Test func paymentIsCreatedFromIndexedParameters() throws {
        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ))

        let params: [Param] = [
            .address(recipient),
            .amount(try LegacyAmount(value: 1)),
            .message(QcharString(value: "Thanks")!),
            .label(QcharString(value: "payment")!),
            .other(
                try OtherParam(
                    key: ParamNameString(
                        value: "future"
                    )!,
                    value: QcharString(
                        value: "is awesome"
                    )!
                )
            )
        ]

        let payment = try Payment.uniqueIndexedParameters(index: 1, parameters: params)

        #expect(try Payment(
            recipientAddress: recipient,
            amount: try LegacyAmount(value: 1),
            memo: nil,
            label: "payment",
            message: "Thanks",
            otherParams: [OtherParam(key: "future", value: "is awesome")]
        ) == payment)
    }
}
