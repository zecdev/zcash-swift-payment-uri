//
//  AmountTests.swift
//
//
//  Created by Francisco Gindre on 2023-11-14
//

import Foundation
import Testing
@testable import ZcashPaymentURI

@Suite("Amount")
struct AmountTests {
    @Test func amountStringDecimals() throws {
        #expect(try Amount(value: 123.456).toString() == "123.456")

        #expect("\(try Amount(value: 123.456))" == "123.456")

        let stringDecimal = try Amount(string: "123.456")
        let literalDecimal = try Amount(value: 123.456)
        #expect(stringDecimal == literalDecimal)
    }

    @Test func amountTrailing() throws {
        #expect(try Amount(value: 50.000).toString() == "50")
    }

    @Test func amountLeadingZeros() throws {
        #expect(try Amount(value: 0000.5).toString() == "0.5")
    }

    @Test func amountMaxDecimals() throws {
        #expect(try Amount(value: 0.12345678).toString() == "0.12345678")
    }

    @Test func amountThrowsIfMaxSupply() throws {
        #expect(throws: (any Error).self) {
            try Amount(decimal: Decimal(21_000_000.00000001)).toString()
        }
        #expect(throws: (any Error).self) {
            try Amount(value: 21_000_000.00000001).toString()
        }
        #expect(throws: (any Error).self) {
            try Amount(string: "21_000_000.00000001").toString()
        }
    }

    @Test func amountThrowsIfNegativeAmount() throws {
        #expect(throws: (any Error).self) {
            try Amount(value: -1).toString()
        }
    }

    /// Negative amounts are not part of the ZIP-321 grammar and must be rejected
    /// **eagerly** by every construction path, with `AmountError.negativeAmount`
    /// for a leading `-` before any digit parsing happens.
    @Test func negativeAmountsAreRejectedEagerlyOnEveryPath() throws {
        // string path: sign is rejected before digits, bounds, or precision are examined.
        for negative in ["-1", "-0", "-0.5", "-21000001", "-0.123456789", "-", "-."] {
            #expect(throws: Amount.AmountError.negativeAmount, "for input \(negative)") {
                try Amount(string: negative)
            }
        }

        // an explicit `+` sign is equally outside the grammar (but is not "negative").
        #expect(throws: Amount.AmountError.invalidTextInput) {
            try Amount(string: "+1")
        }

        // Double path.
        #expect(throws: Amount.AmountError.negativeAmount) {
            try Amount(value: -0.00000001)
        }

        // Decimal path.
        #expect(throws: Amount.AmountError.negativeAmount) {
            try Amount(decimal: Decimal(-1))
        }
    }

    /// Malformed decimal shapes are rejected with `invalidTextInput`.
    @Test(arguments: ["1.2.3", "..", ".", "", "1,5", "1e5", " 1", "0x1"])
    func malformedDecimalStringsAreRejected(malformed: String) throws {
        #expect(throws: Amount.AmountError.invalidTextInput, "for input \(malformed)") {
            try Amount(string: malformed)
        }
    }

    /// Non-finite doubles cannot be amounts.
    @Test(arguments: [Double.infinity, -Double.infinity, Double.nan])
    func nonFiniteDoublesAreRejected(nonFinite: Double) throws {
        #expect(throws: Amount.AmountError.invalidTextInput) {
            try Amount(value: nonFinite)
        }
    }

    /// The internal zero constant renders canonically and equals a parsed zero.
    @Test func zeroAmount() throws {
        #expect(Amount.zero.toString() == "0")
        #expect(try Amount.zero == Amount(string: "0"))
        #expect(try Amount.zero == Amount(string: "0.0"))
    }

    /// The `rounding:` parameter's eager-rounding arm. Note the fractional-digit
    /// guard runs before normalization, so a >8-digit decimal is rejected whether
    /// or not rounding was requested; for in-range inputs the rounding is a no-op.
    @Test func decimalInitWithEagerRounding() throws {
        let inRange = try #require(Decimal(string: "0.12345678"))
        #expect(try Amount(decimal: inRange, rounding: true).toString() == "0.12345678")

        let tooPrecise = try #require(Decimal(string: "0.123456789"))
        #expect(throws: Amount.AmountError.tooManyFractionalDigits) {
            try Amount(decimal: tooPrecise, rounding: true)
        }
    }

    // MARK: Text Conversion Tests

    @Test func amountThrowsIfTooManyFractionalDigits() throws {
        #expect(throws: (any Error).self) {
            try Amount(string: "0.123456789")
        }
    }

    @Test func amountParsesMaxFractionalDigits() throws {
        #expect(try Amount(string: "0.12345678").toString() == (try Amount(value: 0.12345678).toString()))
    }

    @Test func amountParsesMaxAmount() throws {
        #expect(try Amount(string: "21000000").toString() == (try Amount(value: 21_000_000).toString()))
    }

    @Test func doubleToDecimal() throws {
        var result = Decimal()
        var number = Decimal(10_000.00002)

        NSDecimalRound(&result, &number, Amount.maxFractionalDecimalDigits, .bankers)

        let amount = try Amount(value: 10_000.00002)
        #expect(amount.toString() == "10000.00002")
    }

    @Test(
        arguments: [
            (0.02, "0.02"),
            (0.002, "0.002"),
            (0.0002, "0.0002"),
            (0.00002, "0.00002"),
            (0.000002, "0.000002"),
            (0.0000002, "0.0000002"),
            (0.00000002, "0.00000002"),
            (0.2, "0.2"),
            (10.02, "10.02"),
            (100.002, "100.002"),
            (1_000.0002, "1000.0002"),
            (10_000.00002, "10000.00002"),
            (100_000.000002, "100000.000002"),
            (1_000_000.0000002, "1000000.0000002"),
            (10_000_000.00000002, "10000000.00000002")
        ] as [(Double, String)]
    )
    func fractionsOfZecFromDouble(value: Double, expected: String) throws {
        #expect(try Amount(value: value).toString() == expected)
    }

    @Test func tooManyFractionsThrows() throws {
        // more digits than supposed to
        #expect(throws: (any Error).self) {
            try Amount(decimal: Decimal(0.000000002)).toString()
        }
        #expect(throws: (any Error).self) {
            try Amount(decimal: Decimal(10_000_000.000000002))
        }
    }
}
