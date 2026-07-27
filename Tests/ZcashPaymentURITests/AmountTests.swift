//
//  AmountTests.swift
//  
//
//  Created by Francisco Gindre on 2023-11-14
//

import XCTest
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
        XCTAssertThrowsError(try Amount(decimal: Decimal(21_000_000.00000001)).toString())
        XCTAssertThrowsError(try Amount(value: 21_000_000.00000001).toString())
        XCTAssertThrowsError(try Amount(string: "21_000_000.00000001").toString())
    }

    func testAmountThrowsIfNegativeAmount() throws {
        XCTAssertThrowsError(try Amount(value: -1).toString())
    }

    /// Negative amounts are not part of the ZIP-321 grammar and must be rejected
    /// **eagerly** by every construction path, with `AmountError.negativeAmount`
    /// for a leading `-` before any digit parsing happens.
    func testNegativeAmountsAreRejectedEagerlyOnEveryPath() throws {
        // string path: sign is rejected before digits, bounds, or precision are examined.
        for negative in ["-1", "-0", "-0.5", "-21000001", "-0.123456789", "-", "-."] {
            XCTAssertThrowsError(try Amount(string: negative), "expected rejection for \(negative)") { error in
                XCTAssertEqual(error as? Amount.AmountError, Amount.AmountError.negativeAmount, "for input \(negative)")
            }
        }

        // an explicit `+` sign is equally outside the grammar (but is not "negative").
        XCTAssertThrowsError(try Amount(string: "+1")) { error in
            XCTAssertEqual(error as? Amount.AmountError, Amount.AmountError.invalidTextInput)
        }

        // Double path.
        XCTAssertThrowsError(try Amount(value: -0.00000001)) { error in
            XCTAssertEqual(error as? Amount.AmountError, Amount.AmountError.negativeAmount)
        }

        // Decimal path.
        XCTAssertThrowsError(try Amount(decimal: Decimal(-1))) { error in
            XCTAssertEqual(error as? Amount.AmountError, Amount.AmountError.negativeAmount)
        }
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

    func testDoubleToDecimal() throws {

        var result = Decimal()
        var number = Decimal(10_000.00002)

        NSDecimalRound(&result, &number, Amount.maxFractionalDecimalDigits, .bankers)
        
        let amount = try Amount(value: 10_000.00002)
        XCTAssertEqual(amount.toString(), "10000.00002")
    }

    func testFractionsOfZecFromDouble() throws {
       // XCTAssertEqual(try Amount(value: 0.2).toString(), "0.2")
        XCTAssertEqual(try Amount(value: 0.02).toString(), "0.02")
        XCTAssertEqual(try Amount(value: 0.002).toString(), "0.002")
        XCTAssertEqual(try Amount(value: 0.0002).toString(), "0.0002")
        XCTAssertEqual(try Amount(value: 0.00002).toString(), "0.00002")
        XCTAssertEqual(try Amount(value: 0.000002).toString(), "0.000002")
        XCTAssertEqual(try Amount(value: 0.0000002).toString(), "0.0000002")
        XCTAssertEqual(try Amount(value: 0.00000002).toString(), "0.00000002")
        XCTAssertEqual(try Amount(value: 0.2).toString(), "0.2")
        XCTAssertEqual(try Amount(value: 10.02).toString(), "10.02")
        XCTAssertEqual(try Amount(value: 100.002).toString(), "100.002")
        XCTAssertEqual(try Amount(value: 1_000.0002).toString(), "1000.0002")
        XCTAssertEqual(try Amount(value: 10_000.00002).toString(), "10000.00002")
        XCTAssertEqual(try Amount(value: 100_000.000002).toString(), "100000.000002")
        XCTAssertEqual(try Amount(value: 1_000_000.0000002).toString(), "1000000.0000002")
        XCTAssertEqual(try Amount(value: 10_000_000.00000002).toString(), "10000000.00000002")
    }

    func testTooManyFractionsThrows() throws {
        //more digits than supposed to
        XCTAssertThrowsError(try Amount(decimal: Decimal(0.000000002)).toString())
        XCTAssertThrowsError(try Amount(decimal: Decimal(10_000_000.000000002)))
    }
}
