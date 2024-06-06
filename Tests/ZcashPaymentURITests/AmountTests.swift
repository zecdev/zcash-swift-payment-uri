//
//  AmountTests.swift
//  
//
//  Created by Francisco Gindre on 2023-11-14
//

import XCTest
import BigDecimal
@testable import ZcashPaymentURI
final class AmountTests: XCTestCase {
    func testAmountStringDecimals() throws {
        XCTAssertEqual(try Amount(value: 123.456).toString(), "123.456")

        XCTAssertEqual("\(try Amount(value: 123.456))", "123.456")
        
        let stringDecimal = try Amount(string: "123.456")
        let literalDecimal = try Amount(value: 123.456)
        XCTAssertEqual(stringDecimal, literalDecimal)
    }

    func testAmountTrailing() throws {
        XCTAssertEqual(try Amount(value: 50.000).toString(), "50")
    }

    func testAmountLeadingZeros() throws {
        XCTAssertEqual(try Amount(value: 0000.5).toString(), "0.5")
    }

    func testAmountMaxDecimals() throws {
        XCTAssertEqual(try Amount(value: 0.12345678).toString(), "0.12345678")
    }

    func testAmountThrowsIfMaxSupply() throws {
        XCTAssertThrowsError(try Amount(decimal: BigDecimal(21_000_000.00000001)).toString())
        XCTAssertThrowsError(try Amount(value: 21_000_000.00000001).toString())
        XCTAssertThrowsError(try Amount(string: "21_000_000.00000001").toString())
    }

    func testAmountThrowsIfNegativeAmount() throws {
        XCTAssertThrowsError(try Amount(value: -1).toString())
    }

    // MARK: Text Conversion Tests

    func testAmountThrowsIfTooManyFractionalDigits() throws {
        XCTAssertThrowsError(try Amount(string: "0.123456789"))
    }

    func testAmountParsesMaxFractionalDigits() throws {
        XCTAssertEqual(try Amount(string: "0.12345678").toString(), try Amount(value: 0.12345678).toString())
    }

    func testAmountParsesMaxAmount() throws {
        XCTAssertEqual(try Amount(string: "21000000").toString(), try Amount(value: 21_000_000).toString())
    }
}
