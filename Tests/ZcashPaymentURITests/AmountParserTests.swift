//
//  AmountParserTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu on 2026-07-08.
//
//  Accept/reject table drawn from the shared conformance corpus
//  (Tests/Vectors/vectors/{valid,invalid}/amounts.json), which is oracle-verified
//  against the librustzcash `zip321` reference `parse_amount`. Provenance for each
//  case is noted inline.
//

import Testing
@testable import ZcashPaymentURI

@Suite("AmountParser")
struct AmountParserTests {
    // MARK: Accepted (valid/amounts.json)

    @Test(arguments: [
        // (input, expected zatoshi)
        ("20999999.99999999", Int64(2_099_999_999_999_999)), // amount_just_below_max_money
        ("21000000", Int64(2_100_000_000_000_000)),          // amount_max_money (== MAX_MONEY)
        ("050", Int64(5_000_000_000)),                       // amount_leading_zeros_050
        ("00.500", Int64(50_000_000)),                       // amount_leading_and_trailing_zeros_00_500
        ("0.00000001", Int64(1)),                            // amount_roundtrip_1_zat
        ("0.00001", Int64(1_000)),                           // amount_roundtrip_1000_zat
        ("0.001", Int64(100_000)),                           // amount_roundtrip_100000_zat
        ("1", Int64(100_000_000)),                           // amount_roundtrip_100000000_zat
        ("1000", Int64(100_000_000_000))                     // amount_roundtrip_100000000000_zat
    ])
    func acceptsValidAmounts(input: String, expected: Int64) throws {
        let zatoshi = try AmountParser.parse(input, index: 0)
        #expect(zatoshi.value == expected)
    }

    // MARK: Rejected (invalid/amounts.json + grammar edges)

    @Test func rejectsAmountExceedingI64() {
        // invalid_amount_exceeds_i64: i64::MAX + 1
        #expect(throwsAmountError { try AmountParser.parse("9223372036854775808", index: 0) })
    }

    @Test func rejectsAmountOverflowWrapsPositive() {
        // invalid_amount_overflow_wraps_positive
        #expect(throwsAmountError { try AmountParser.parse("18446744073709551624", index: 0) })
    }

    @Test func rejectsAmountExceedingMaxMoney() throws {
        // invalid_amount_exceeds_max_money: one zatoshi over MAX_MONEY
        #expect {
            try AmountParser.parse("21000000.00000001", index: 3)
        } throws: { error in
            guard case ZIP321.Errors.amountExceededSupply(3) = error else { return false }
            return true
        }
    }

    @Test func rejectsNegativeAmount() {
        // invalid_amount_negative: "-1" is not representable by the amountparam grammar
        #expect(throwsAmountError { try AmountParser.parse("-1", index: 0) })
    }

    @Test func rejectsTrailingDecimalPoint() throws {
        // invalid_amount_trailing_decimal_point: "123." has no fractional digits
        #expect {
            try AmountParser.parse("123.", index: 0)
        } throws: { error in
            guard case ZIP321.Errors.invalidParamValue(param: "amount", index: nil) = error else { return false }
            return true
        }
    }

    @Test func rejectsLeadingDecimalPoint() {
        // invalid_amount_leading_decimal_point: ".5" has no whole-number part
        #expect(throwsAmountError { try AmountParser.parse(".5", index: 0) })
    }

    @Test func rejectsPercentEscapeInAmount() {
        // invalid_percent_encoded_amount: amount values are never percent-decoded
        #expect(throwsAmountError { try AmountParser.parse("1%30", index: 0) })
    }

    @Test func rejectsMoreThanEightFractionalDigits() throws {
        #expect {
            try AmountParser.parse("1.123456789", index: 2)
        } throws: { error in
            guard case ZIP321.Errors.amountTooSmall(2) = error else { return false }
            return true
        }
    }

    @Test func rejectsEmptyAndGarbage() {
        #expect(throwsAmountError { try AmountParser.parse("", index: 0) })
        #expect(throwsAmountError { try AmountParser.parse("abc", index: 0) })
        #expect(throwsAmountError { try AmountParser.parse("1.2.3", index: 0) })
        #expect(throwsAmountError { try AmountParser.parse(" 1", index: 0) })
        #expect(throwsAmountError { try AmountParser.parse("1e8", index: 0) })
    }

    // MARK: helpers

    private func throwsAmountError(_ body: () throws -> NonNegativeAmount) -> Bool {
        do {
            _ = try body()
            return false
        } catch is ZIP321.Errors {
            return true
        } catch {
            return false
        }
    }
}
