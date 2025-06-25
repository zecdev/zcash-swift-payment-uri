//
//  DuplicateParameterDetectionTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-14.
//    
   

import XCTest
import Parsing
import CustomDump
@testable import ZcashPaymentURI

final class DuplicateParameterDetectionTests: XCTestCase {
    /// invalid; duplicate `amount=` field/
    func testThrowsWhenThereAreDuplicateParameters() {
        let invalidURI = "zcash:?amount=1.234&amount=2.345&address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
            "should have thrown \(String(describing: ZIP321.Errors.duplicateParameter("amount", 0))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.duplicateParameter("amount", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("amount", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; duplicate `amount.1=` field
    func testThrowsWhenThereAreDuplicateParametersWithParamIndex() {
        let invalidURI = "zcash:?amount.1=1.234&amount.1=2.345&address.1=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
            "should have thrown \(String(describing: ZIP321.Errors.duplicateParameter("amount", 1))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.duplicateParameter("amount", 1):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("amount", 1)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    func testThatDuplicateParametersAreDetected() throws {
        guard let shieldedRecipient = RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ) else {
            XCTFail("failed to create shielded recipient")
            return
        }

        let duplicateAddressParams: [IndexedParameter] = [
            IndexedParameter(index:0, param: .address(shieldedRecipient)),
            IndexedParameter(index:0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index:0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index:0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index:0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index:0, param: .address(shieldedRecipient)),
            IndexedParameter(
                index:0,
                param: .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is awesome"
                        )!
                    )
                )
            )
        ]

        let duplicateAmountParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(
                index:0,
                param: .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is awesome"
                        )!
                    )
                )
            )
        ]

        let duplicateMessageParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(
                index:0,
                param: .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is awesome"
                        )!
                    )
                )
            )
        ]

        let duplicateMemoParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(
                index:0,
                param: .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is awesome"
                        )!
                    )
                )
            )
        ]

        let duplicateLabelParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(
                index:0,
                param: .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is awesome"
                        )!
                    )
                )
            )
        ]

        let duplicateOtherParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(
                index:0,
                param: .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is awesome"
                        )!
                    )
                )
            ),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(
                index:0,
                param: .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is awesome"
                        )!
                    )
                )
            )
        ]

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateAddressParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("address", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("address", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateAmountParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("amount", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("amount", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateMessageParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("message", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("message", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateMemoParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("memo", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("memo", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateLabelParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("label", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("label", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateOtherParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("future", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("future", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    func testDuplicateAddressParamsAreDetected() throws {
        let params: [Param] = [
            .address(
                RecipientAddress(
                    value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                    context: .testnet
                )!
            ),
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

        XCTAssertTrue(params.hasDuplicateParam(.address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet)!)))
    }

    func testDuplicateParameterIsFalseWhenNoDuplication() throws {
        let params: [Param] = [
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

        XCTAssertFalse(params.hasDuplicateParam(.address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet)!)))
    }

    func testDuplicateOtherParamsAreDetected() throws {
        let params: [Param] = [
            .address(
                RecipientAddress(
                    value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                    context: .testnet
                )!
            ),
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

        XCTAssertTrue(
            params.hasDuplicateParam(
                .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value:  QcharString(
                            value: "is dystopic"
                        )!
                    )
                )
            )
        )
    }
}
