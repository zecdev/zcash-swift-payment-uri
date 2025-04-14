//
//  PaymentTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-14.
//    
   

import XCTest
import Parsing
import CustomDump
@testable import ZcashPaymentURI

final class PaymentTests: XCTestCase {
    // MARK: Param validation - no memos to transparent

    func testThrowsWhenMemoIsPresentOnTransparentRecipient() throws {
        guard let recipient = RecipientAddress(
            value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
            context: .testnet
        ) else {
            XCTFail("failed to create recipient")
            return
        }

        let params: [Param] = [
            .address(recipient),
            .amount(try Amount(value: 1)),
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

        XCTAssertThrowsError(try Payment.uniqueIndexedParameters(index: 1, parameters: params)) { err in

            switch err {
            case ZIP321.Errors.transparentMemoNotAllowed(1):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.transparentMemoNotAllowed(1)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    // MARK: Payment Validation
    func testPaymentIsCreatedFromIndexedParameters() throws {
        guard let recipient = RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ) else {
            XCTFail("failed to create recipient")
            return
        }

        let params: [Param] = [
            .address(recipient),
            .amount(try Amount(value: 1)),
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

        XCTAssertNoDifference(try Payment(
            recipientAddress: recipient,
            amount: try Amount(value: 1),
            memo: nil,
            label: "payment",
            message: "Thanks",
            otherParams: [OtherParam(key: "future", value: "is awesome")]
        ), payment)
    }
}
