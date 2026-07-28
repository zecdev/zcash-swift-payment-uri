//
//  NonNegativeAmountTests.swift
//
//
//  Created by Pacu on 2026-07-08.
//

import Testing
@testable import ZcashPaymentURI

@Suite("NonNegativeAmount")
struct NonNegativeAmountTests {
    // MARK: - zec(_:) valid decimal strings
    //
    // Amount cases mirror the shared conformance corpus
    // (zcash-zip321-test-vectors: vectors/valid/amounts.json), hardcoded here so
    // this unit suite needs no JSON loading. Each tuple is
    // (decimalString, expectedValue, corpusVectorOrRuleName).
    static let validDecimalStrings: [(String, UInt64, String)] = [
        ("20999999.99999999", 2_099_999_999_999_999, "amount_just_below_max_money"),
        ("21000000", 2_100_000_000_000_000, "amount_max_money"),
        ("050", 5_000_000_000, "amount_leading_zeros_050"),
        ("00.500", 50_000_000, "amount_leading_and_trailing_zeros_00_500"),
        ("1", 100_000_000, "amount_one_with_empty_message"),
        ("3768769.02796286", 376_876_902_796_286, "amount_parse_simple_large_decimal"),
        ("0.00000001", 1, "amount_roundtrip_1_zat"),
        ("0.00001", 1_000, "amount_roundtrip_1000_zat"),
        ("0.001", 100_000, "amount_roundtrip_100000_zat"),
        ("1000", 100_000_000_000, "amount_roundtrip_100000000000_zat"),
        // NonNegativeAmount is amount-agnostic: zero is representable; the zero-valued
        // transparent-output policy lives at the Payment level.
        ("0", 0, "zero is valid at the NonNegativeAmount level"),
        ("0.00000000", 0, "zero with full fractional padding")
    ]

    @Test(arguments: validDecimalStrings)
    func zecParsesValidDecimalString(_ testCase: (String, UInt64, String)) throws {
        let (string, expectedValue, comment) = testCase
        let parsed = try NonNegativeAmount.zec(string).get()

        #expect(parsed.value == expectedValue, "\(comment)")
    }

    // MARK: - zec(_:) invalid decimal strings
    //
    // Rejection cases mirror the shared conformance corpus
    // (zcash-zip321-test-vectors: vectors/invalid/amounts.json) plus additional
    // strict-grammar probes. Each tuple is
    // (decimalString, expectedError, corpusVectorOrRuleName).
    static let invalidDecimalStrings: [(String, NonNegativeAmount.AmountError, String)] = [
        // i64::MAX + 1: representable in UInt64 but > MAX_MONEY; u64-wrap values overflow UInt64 itself.
        ("9223372036854775808", .exceededSupply, "invalid_amount_exceeds_i64"),
        // u64 wrap-around probe: must NOT wrap into a small positive value.
        ("18446744073709551624", .exceededSupply, "invalid_amount_overflow_wraps_positive"),
        // one zatoshi over MAX_MONEY.
        ("21000000.00000001", .exceededSupply, "invalid_amount_exceeds_max_money"),
        // a leading '-' is diagnosed as a negative amount, not as generic garbage.
        ("-1", .negativeAmount, "invalid_amount_negative"),
        ("123.", .invalidDecimalString, "invalid_amount_trailing_decimal_point"),
        (".5", .invalidDecimalString, "invalid_amount_leading_decimal_point"),
        // strict ZIP-321 grammar probes beyond the corpus:
        ("", .invalidDecimalString, "empty string"),
        ("-1.23", .negativeAmount, "negative amount with a fractional part"),
        ("-0", .negativeAmount, "negative zero is still signed"),
        ("-", .negativeAmount, "bare minus sign"),
        ("+", .invalidDecimalString, "bare plus sign"),
        ("+1", .invalidDecimalString, "explicit positive sign"),
        ("+1.23", .invalidDecimalString, "explicit positive sign with a fractional part"),
        ("1,5", .invalidDecimalString, "comma is not a decimal separator"),
        ("1e5", .invalidDecimalString, "scientific notation"),
        (" 1", .invalidDecimalString, "leading whitespace"),
        ("1 ", .invalidDecimalString, "trailing whitespace"),
        ("1.2.3", .invalidDecimalString, "second decimal point"),
        ("1.", .invalidDecimalString, "decimal point with no fractional digits"),
        (".", .invalidDecimalString, "bare decimal point"),
        ("0.123456789", .tooManyFractionalDigits, "9 fractional digits exceed the 8-digit maximum")
    ]

    @Test(arguments: invalidDecimalStrings)
    func zecRejectsInvalidDecimalString(_ testCase: (String, NonNegativeAmount.AmountError, String)) {
        let (string, expectedError, comment) = testCase

        switch NonNegativeAmount.zec(string) {
        case .success(let zatoshi):
            Issue.record("expected rejection of '\(string)' (\(comment)) but got \(zatoshi.value) zatoshi")
        case .failure(let error):
            #expect(error == expectedError, "\(comment)")
        }
    }

    // MARK: - zatoshi(_:) integer factory

    @Test func zatoshiFactoryAcceptsBounds() throws {
        #expect(try NonNegativeAmount.zatoshi(0).get().value == 0)
        #expect(try NonNegativeAmount.zatoshi(1).get().value == 1)
        #expect(try NonNegativeAmount.zatoshi(NonNegativeAmount.maxMoney).get().value == 2_100_000_000_000_000)
    }

    @Test func zatoshiFactoryRejectsOutOfRange() {
        #expect(NonNegativeAmount.zatoshi(NonNegativeAmount.maxMoney + 1) == .failure(.exceededSupply))
        #expect(NonNegativeAmount.zatoshi(UInt64.max) == .failure(.exceededSupply))
        // negative zatoshi counts are unrepresentable by construction: the factory takes
        // `UInt64`, so `NonNegativeAmount.zatoshi(-1)` is a compile-time error rather than a runtime
        // rejection. The decimal-string path rejects signed strings via the grammar.
    }

    // MARK: - decimalString() rendering
    //
    // Expected renderings match the reference `amount_str` (librustzcash
    // zip321): whole part always present, fraction only if nonzero, trailing
    // zeros trimmed. Corpus `canonicalUri` amounts are covered by the pairs
    // whose input string differs from the canonical rendering ("050" -> "50",
    // "00.500" -> "0.5").
    static let renderedDecimalStrings: [(UInt64, String)] = [
        (0, "0"),
        (1, "0.00000001"),
        (1_000, "0.00001"),
        (100_000, "0.001"),
        (50_000_000, "0.5"),
        (100_000_000, "1"),
        (5_000_000_000, "50"),
        (100_000_000_000, "1000"),
        (376_876_902_796_286, "3768769.02796286"),
        (2_099_999_999_999_999, "20999999.99999999"),
        (2_100_000_000_000_000, "21000000")
    ]

    @Test(arguments: renderedDecimalStrings)
    func decimalStringRendersCanonically(_ testCase: (UInt64, String)) throws {
        let (zats, expected) = testCase
        let amount = try NonNegativeAmount.zatoshi(zats).get()

        #expect(amount.decimalString() == expected)
    }

    @Test(arguments: renderedDecimalStrings)
    func decimalStringRoundTrips(_ testCase: (UInt64, String)) throws {
        let (zats, rendered) = testCase
        let reparsed = try NonNegativeAmount.zec(rendered).get()

        #expect(reparsed.value == zats)
        #expect(reparsed.decimalString() == rendered)
    }

    // MARK: - Comparable / Hashable

    @Test func comparableOrdersByValue() throws {
        let one = try NonNegativeAmount.zatoshi(1).get()
        let two = try NonNegativeAmount.zatoshi(2).get()

        #expect(one < two)
        #expect(!(two < one))
        #expect(one == (try NonNegativeAmount.zec("0.00000001").get()))
    }

    @Test func hashableAgreesWithEquality() throws {
        let a = try NonNegativeAmount.zec("1").get()
        let b = try NonNegativeAmount.zatoshi(100_000_000).get()

        #expect(Set([a, b]).count == 1)
    }
}
