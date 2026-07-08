//
//  DuplicateParameterDetectionTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-14.
//

import Testing
@testable import ZcashPaymentURI

@Suite("DuplicateParameterDetection")
struct DuplicateParameterDetectionTests {
    /// invalid; duplicate `amount=` field/
    @Test func throwsWhenThereAreDuplicateParameters() {
        let invalidURI = "zcash:?amount=1.234&amount=2.345&address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("amount", nil) = error else { return false }
            return true
        }
    }

    /// invalid; duplicate `amount.1=` field
    @Test func throwsWhenThereAreDuplicateParametersWithParamIndex() {
        let invalidURI = "zcash:?amount.1=1.234&amount.1=2.345&address.1=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("amount", 1) = error else { return false }
            return true
        }
    }

    @Test func thatDuplicateParametersAreDetected() throws {
        let shieldedRecipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ))

        let duplicateAddressParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(
                index: 0,
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
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(
                index: 0,
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
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(
                index: 0,
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
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(
                index: 0,
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
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label(QcharString(value: "payment")!)),
            IndexedParameter(
                index: 0,
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
                index: 0,
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
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thanks")!)),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(
                index: 0,
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

        #expect {
            try Parser.mapToPayments(duplicateAddressParams)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("address", nil) = error else { return false }
            return true
        }

        #expect {
            try Parser.mapToPayments(duplicateAmountParams)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("amount", nil) = error else { return false }
            return true
        }

        #expect {
            try Parser.mapToPayments(duplicateMessageParams)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("message", nil) = error else { return false }
            return true
        }

        #expect {
            try Parser.mapToPayments(duplicateMemoParams)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("memo", nil) = error else { return false }
            return true
        }

        #expect {
            try Parser.mapToPayments(duplicateLabelParams)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("label", nil) = error else { return false }
            return true
        }

        #expect {
            try Parser.mapToPayments(duplicateOtherParams)
        } throws: { error in
            guard case ZIP321.Errors.duplicateParameter("future", nil) = error else { return false }
            return true
        }
    }

    @Test func duplicateAddressParamsAreDetected() throws {
        let params: [Param] = [
            .address(
                RecipientAddress(
                    value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                    context: .testnet
                )!
            ),
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

        #expect(params.hasDuplicateParam(.address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet)!)))
    }

    @Test func duplicateParameterIsFalseWhenNoDuplication() throws {
        let params: [Param] = [
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

        #expect(!params.hasDuplicateParam(.address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet)!)))
    }

    @Test func duplicateOtherParamsAreDetected() throws {
        let params: [Param] = [
            .address(
                RecipientAddress(
                    value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                    context: .testnet
                )!
            ),
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

        #expect(
            params.hasDuplicateParam(
                .other(
                    try OtherParam(
                        key: ParamNameString(
                            value: "future"
                        )!,
                        value: QcharString(
                            value: "is dystopic"
                        )!
                    )
                )
            )
        )
    }
}
