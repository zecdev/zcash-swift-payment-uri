//
//  RendererTests.swift
//
//
//  Created by Francisco Gindre on 2023-11-13.
//

import Testing
@testable import ZcashPaymentURI

@Suite("Render")
struct RendererTests {
    @Test func amountRendersNoParamIndex() throws {
        let expected = "amount=123.456"

        let amount = try NonNegativeAmount.zec("123.456").get()

        #expect(Render.parameter(amount, index: nil) == expected)
        #expect(Render.parameter(amount, index: nil) == expected)
    }

    @Test func amountRendersWithParamIndex() throws {
        let expected = "amount.1=123.456"

        let amount = try NonNegativeAmount.zec("123.456").get()

        #expect(Render.parameter(amount, index: 1) == expected)
    }

    @Test func addressRendersNoParamIndex() throws {
        let expected = "address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        #expect(Render.parameter(recipient0, index: nil) == expected)
    }

    @Test func addressRendersWithParamIndex() throws {
        let expected = "address.1=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        #expect(Render.parameter(recipient0, index: 1) == expected)
    }

    @Test func messageParamRendersNoParamIndex() throws {
        let expected = "message=Thank%20you%20for%20your%20purchase"

        #expect(Render.parameter(message: "Thank you for your purchase", index: nil) == expected)
    }

    @Test func messageParamRendersWithParamIndex() throws {
        let expected = "message.10=Thank%20you%20for%20your%20purchase"

        #expect(Render.parameter(message: "Thank you for your purchase", index: 10) == expected)
    }

    @Test func labelRendersNoParamIndex() throws {
        let expected = "label=Lunch%20Tab"

        #expect(Render.parameter(label: "Lunch Tab", index: nil) == expected)
    }

    @Test func labelRendersWithParamIndex() throws {
        let expected = "label.1=Lunch%20Tab"

        #expect(Render.parameter(label: "Lunch Tab", index: 1) == expected)
    }

    @Test func reqParamRendersNoParamIndex() throws {
        let expected = "req-futureParam=Future%20is%20Z"

        #expect(Render.parameter(named: "req-futureParam", decodedValue: "Future is Z", index: nil) == expected)
    }

    @Test func reqParamRendersWithParamIndex() throws {
        let expected = "req-futureParam.1=Future%20is%20Z"

        #expect(Render.parameter(named: "req-futureParam", decodedValue: "Future is Z", index: 1) == expected)
    }

    @Test func memoParamRendersNoParamIndex() throws {
        let expected = "memo=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        #expect(Render.parameter(try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"), index: nil) == expected)
    }

    @Test func memoParamRendersWithParamIndex() throws {
        let expected = "memo.10=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        #expect(Render.parameter(try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"), index: 10) == expected)
    }

    // MARK: Payment

    @Test func paymentRendersWithNoParamIndex() throws {
        let expected = "address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        let payment0 = try Payment.create(
            recipientAddress: recipient0,
            amount: try NonNegativeAmount.zec("123.456").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        #expect(Render.payment(payment0, index: nil) == expected)
    }

    @Test func paymentRendersWithParamIndex() throws {
        // swiftlint:disable:next line_length
        let expected = "address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, validator: ReferenceAddressValidator.testnet))

        let payment1 = try Payment.create(
            recipientAddress: recipient1,
            amount: try NonNegativeAmount.zec("0.789").get(),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        #expect(Render.payment(payment1, index: 1) == expected)
    }

    @Test func paymentRendersWithNoParamIndexAndNoAddressLabel() throws {
        let expected = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU?amount=123.456"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        let payment0 = try Payment.create(
            recipientAddress: recipient0,
            amount: try NonNegativeAmount.zec("123.456").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        #expect(Render.payment(payment0, index: nil, omittingAddressLabel: true) == expected)
    }

    @Test func paymentRendererIgnoresLabelOmissionWhenIndexIsProvided() throws {
        // swiftlint:disable:next line_length
        let expected = "address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, validator: ReferenceAddressValidator.testnet))

        let payment1 = try Payment.create(
            recipientAddress: recipient1,
            amount: try NonNegativeAmount.zec("0.789").get(),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        #expect(Render.payment(payment1, index: 1, omittingAddressLabel: true) == expected)
    }
}
