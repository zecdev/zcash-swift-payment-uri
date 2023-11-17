//
//  RendererTests.swift
//  
//
//  Created by Francisco Gindre on 11/13/23.
//

import XCTest
@testable import zcash_swift_payment_uri
final class RendererTests: XCTestCase {

    func testAmountRendersNoParamIndex() throws {
        let expected = "amount=123.456"
        
        let amount = try Amount(value: Decimal(123.456))

        XCTAssertEqual(Render.parameter(amount, index: nil), expected)

        XCTAssertEqual(Render.parameter(amount, index: nil), expected)
    }

    func testAmountRendersWithParamIndex() throws {
        let expected = "amount.1=123.456"

        let amount = try Amount(value: Decimal(123.456))

        XCTAssertEqual(Render.parameter(amount, index: 1), expected)
    }

    func testAddressRendersNoParamIndex() throws {
        let expected = "address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        XCTAssertEqual(Render.parameter(recipient0, index: nil), expected)
    }

    func testAddressRendersWithParamIndex() throws {
        let expected = "address.1=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        XCTAssertEqual(Render.parameter(recipient0, index: 1), expected)
    }


    func testMessageParamRendersNoParamIndex() throws {
        let expected = "message=Thank%20you%20for%20your%20purchase"

        XCTAssertEqual(Render.parameter(message: "Thank you for your purchase", index: nil), expected)
    }

    func testMessageParamRendersWithParamIndex() throws {
        let expected = "message.10=Thank%20you%20for%20your%20purchase"

        XCTAssertEqual(Render.parameter(message: "Thank you for your purchase", index: 10), expected)
    }

    func testLabelRendersNoParamIndex() throws {
        let expected = "label=Lunch%20Tab"

        XCTAssertEqual(Render.parameter(label: "Lunch Tab", index: nil), expected)
    }

    func testLabelRendersWithParamIndex() throws {
        let expected = "label.1=Lunch%20Tab"

        XCTAssertEqual(Render.parameter(label: "Lunch Tab", index: 1), expected)
    }

    func testReqParamRendersNoParamIndex() throws {
        let expected = "req-futureParam=Future%20is%20Z"

        XCTAssertEqual(Render.parameter(label: "req-futureParam", value: "Future is Z", index: nil), expected)
    }

    func testReqParamRendersWithParamIndex() throws {
        let expected = "req-futureParam.1=Future%20is%20Z"

        XCTAssertEqual(Render.parameter(label: "req-futureParam", value: "Future is Z", index: 1), expected)
    }

    func testMemoParamRendersNoParamIndex() throws {
        let expected = "memo=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        XCTAssertEqual(Render.parameter(try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"), index: nil), expected)
    }

    func testMemoParamRendersWithParamIndex() throws {
        let expected = "memo.10=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        XCTAssertEqual(Render.parameter(try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"), index: 10), expected)
    }

    // MARK: Payment

    func testPaymentRendersWithNoParamIndex() throws {
        let expected = "address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        XCTAssertEqual(Render.payment(payment0, index: nil), expected)
    }

    func testPaymentRendersWithParamIndex() throws {
        let expected = "address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        XCTAssertEqual(Render.payment(payment1, index: 1), expected)
    }

    func testPaymentRendersWithNoParamIndexAndNoAddressLabel() throws {
        let expected = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU?amount=123.456"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        XCTAssertEqual(Render.payment(payment0, index: nil, omittingAddressLabel: true), expected)
    }

    func testPaymentRendererIgnoresLabelOmissionWhenIndexIsProvided() throws {
        let expected = "address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        XCTAssertEqual(Render.payment(payment1, index: 1, omittingAddressLabel: true), expected)
    }
}
