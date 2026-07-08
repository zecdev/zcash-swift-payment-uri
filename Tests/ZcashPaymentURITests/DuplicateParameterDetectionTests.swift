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
        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.duplicateParameter(name: "amount", index: nil)))
    }

    /// invalid; duplicate `amount.1=` field
    @Test func throwsWhenThereAreDuplicateParametersWithParamIndex() {
        let invalidURI = "zcash:?amount.1=1.234&amount.1=2.345&address.1=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.duplicateParameter(name: "amount", index: 1)))
    }

    @Test func thatDuplicateParametersAreDetected() throws {
        let shieldedRecipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            validator: ReferenceAddressValidator.testnet
        ))

        let futureParam = Param.other(try OtherParam(name: "future", value: "is awesome"))
        let amountParam = Param.amount(try NonNegativeAmount.zec("1").get())
        let messageParam = Param.message(QcharString(value: "Thanks")!)
        let labelParam = Param.label(QcharString(value: "payment")!)
        let memoParam = Param.memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))

        func indexed(_ params: [Param]) -> [IndexedParameter] {
            params.map { IndexedParameter(index: 0, param: $0) }
        }

        let duplicateAddressParams = indexed([
            .address(shieldedRecipient), amountParam, messageParam, memoParam, labelParam,
            .address(shieldedRecipient), futureParam
        ])

        let duplicateAmountParams = indexed([
            .address(shieldedRecipient), amountParam, messageParam, memoParam, labelParam,
            amountParam, futureParam
        ])

        let duplicateMessageParams = indexed([
            .address(shieldedRecipient), amountParam, messageParam, memoParam, labelParam,
            messageParam, futureParam
        ])

        let duplicateMemoParams = indexed([
            .address(shieldedRecipient), amountParam, messageParam, memoParam, labelParam,
            memoParam, futureParam
        ])

        let duplicateLabelParams = indexed([
            .address(shieldedRecipient), labelParam, amountParam, messageParam, memoParam,
            labelParam, futureParam
        ])

        let duplicateOtherParams = indexed([
            .address(shieldedRecipient), labelParam, futureParam, amountParam, messageParam,
            memoParam, futureParam
        ])

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

        #expect(params.hasDuplicateParam(.address(recipient)))
    }

    @Test func duplicateParameterIsFalseWhenNoDuplication() throws {
        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            validator: ReferenceAddressValidator.testnet
        ))

        let params: [Param] = [
            .amount(try NonNegativeAmount.zec("1").get()),
            .message(QcharString(value: "Thanks")!),
            .label(QcharString(value: "payment")!),
            .other(try OtherParam(name: "future", value: "is awesome"))
        ]

        #expect(!params.hasDuplicateParam(.address(recipient)))
    }

    @Test func duplicateOtherParamsAreDetected() throws {
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

        #expect(
            params.hasDuplicateParam(.other(try OtherParam(name: "future", value: "is dystopic")))
        )
    }
}
