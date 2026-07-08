//
//  Amount.swift
//
//
//  Created by Pacu on 2024-01-01.
//

import Foundation

/// An *non-negative* decimal ZEC amount represented as specified in ZIP-321.
/// Amount can be from 1 zatoshi (0.00000001) to the `maxSupply` of 21M ZEC (`21_000_000`)
///
/// - Note: internally this is represented as a checked `Int64` count of zatoshi
/// (1 ZEC == 100_000_000 zatoshi) fixed-point value rather than an arbitrary-precision
/// decimal type. This is sufficient because `maxSupply` (`MAX_MONEY` = 2_100_000_000_000_000
/// zatoshi) is comfortably representable by `Int64` (max ~9.2 * 10^18).
public struct Amount: Equatable, Sendable {
    public enum AmountError: Error {
        case negativeAmount
        case greaterThanSupply
        case tooManyFractionalDigits
        case invalidTextInput
    }

    static let maxFractionalDecimalDigits: Int = 8

    /// number of zatoshi in 1 ZEC
    static let zatoshiPerZec: Int64 = 100_000_000

    /// `MAX_MONEY` expressed in whole ZEC
    static let maxSupplyZec: Int64 = 21_000_000

    /// `MAX_MONEY` expressed in zatoshi (2_100_000_000_000_000)
    static let maxSupplyZatoshi: Int64 = maxSupplyZec * zatoshiPerZec

    static let zero = Amount(unchecked: 0)

    /// this amount, represented as an integer count of zatoshi.
    let zatoshi: Int64

    /// Initializes an Amount from a `Double` number
    /// - parameter value: double representation of the desired amount. **Important:** `Double` values with more than 8 fractional digits ** will be rounded** using bankers rounding.
    /// - returns A valid ZEC amount
    /// - throws `Amount.AmountError` then the provided value can't represent or can't be rounded to a non-negative  ZEC decimal amount.
    /// - important: Apparently sound `Double` values like `0.02` will result into invalid ZEC amounts if not rounded properly. Therefore all `Double` inputs are rounded to prevent further errors or undesired values.
    /// - note: this is a convenience initializer. when possible favor the use of other initializer with safer input values
    /// - warning: **deprecated for v2**: prefer `init(string:)` or `init(decimal:)`. `Double` cannot exactly represent
    /// most decimal ZEC amounts, so this initializer performs a lossy `Double` -> `Decimal` conversion before rounding.
    public init(value: Double) throws {
        guard value.isFinite else { throw AmountError.invalidTextInput }
        guard value >= 0 else { throw AmountError.negativeAmount }

        guard value <= Double(Self.maxSupplyZec) else { throw AmountError.greaterThanSupply }

        let rounded = Decimal(value).zecBankersRounding()

        try self.init(decimal: rounded)
    }

    /// Initializes an Amount from a `Decimal` number
    /// - parameter decimal: decimal representation of the desired amount. **Important:** `Decimal` values with more than 8 fractional digits ** will be rounded** using bankers rounding.
    /// - parameter rounding: whether this initializer should eagerly perform a bankers rounding to at most 8 fractional digits.
    /// - returns A valid ZEC amount
    /// - throws `Amount.AmountError` then the provided value can't represent or can't be rounded to a non-negative  ZEC decimal amount.
    public init(decimal: Decimal, rounding: Bool = false) throws {
        guard decimal >= 0 else { throw AmountError.negativeAmount }

        guard decimal <= Decimal(Self.maxSupplyZec) else { throw AmountError.greaterThanSupply }

        guard decimal.significantFractionalDecimalDigits <= Self.maxFractionalDecimalDigits else {
            throw AmountError.tooManyFractionalDigits
        }

        let normalized = rounding ? decimal.zecBankersRounding() : decimal

        self.zatoshi = try Self.zatoshi(fromValidatedDecimal: normalized)
    }

    /// Initializes an `Amount` by manually parsing a plain decimal `String`.
    /// - parameter string: a plain (non-scientific) decimal string, e.g. `"123.456"`, `"0.5"`, `"21000000"`.
    /// - Note: this preserves v1 leniency: a leading or trailing decimal point (e.g. `"123."`, `".5"`) is
    /// accepted. Grammar tightening to reject those forms is deferred to a later parser revision.
    public init(string: String) throws {
        self.zatoshi = try Self.parseZatoshi(from: string)
    }

    init(unchecked: Int64) {
        self.zatoshi = unchecked
    }

    public func toString() -> String {
        let whole = self.zatoshi / Self.zatoshiPerZec
        let fraction = self.zatoshi % Self.zatoshiPerZec

        guard fraction != 0 else {
            return String(whole)
        }

        var fractionDigits = String(fraction)
        fractionDigits = String(repeating: "0", count: Self.maxFractionalDecimalDigits - fractionDigits.count) + fractionDigits

        while fractionDigits.hasSuffix("0") {
            fractionDigits.removeLast()
        }

        return "\(whole).\(fractionDigits)"
    }
}

extension Amount {
    /// Converts an already-range/precision-validated non-negative `Decimal` (`<= maxSupplyZec`,
    /// at most 8 fractional digits) into its exact zatoshi `Int64` representation.
    /// - Important: callers must validate bounds and fractional digit count *before* calling this,
    /// since scaling by `zatoshiPerZec` assumes no overflow can occur.
    static func zatoshi(fromValidatedDecimal decimal: Decimal) throws -> Int64 {
        let scaled = decimal * Decimal(Self.zatoshiPerZec)
        let number = NSDecimalNumber(decimal: scaled)

        // `scaled` is guaranteed to be a whole number in [0, maxSupplyZatoshi] given the
        // preconditions above, so this conversion cannot overflow `Int64`.
        return number.int64Value
    }

    /// Manually parses a plain decimal `String` into its exact zatoshi `Int64` representation,
    /// using only checked integer arithmetic (no floating point, no arbitrary-precision decimal type).
    ///
    /// Accepted grammar (intentionally lenient, matching v1 behavior):
    /// `["-"] 1*DIGIT ["." *8DIGIT]` or `["-"] *DIGIT "." 1*8DIGIT`
    /// i.e. at least one of the whole/fractional parts must be present, but either may be empty
    /// (`"123."` and `".5"` are both accepted) — ZIP-321 grammar tightening is deferred.
    static func parseZatoshi(from string: String) throws -> Int64 {
        var text = Substring(string)

        var isNegative = false
        if text.first == "-" {
            isNegative = true
            text = text.dropFirst()
        }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)

        guard (1...2).contains(parts.count) else {
            throw AmountError.invalidTextInput
        }

        let wholePart = parts[0]
        let fractionPart = parts.count == 2 ? parts[1] : Substring()

        // at least one side of the decimal point must be non-empty.
        guard !(wholePart.isEmpty && fractionPart.isEmpty) else {
            throw AmountError.invalidTextInput
        }

        let isASCIIDigits: (Substring) -> Bool = { $0.allSatisfy { $0.isASCII && $0.isNumber } }

        guard
            (wholePart.isEmpty || isASCIIDigits(wholePart)),
            (fractionPart.isEmpty || isASCIIDigits(fractionPart))
        else {
            throw AmountError.invalidTextInput
        }

        // `Int64(_:)` returns `nil` on overflow (e.g. a whole part with far more digits
        // than fit in an `Int64`), which is mapped to `greaterThanSupply` below — matching
        // the ZIP-321 conformance corpus's `amountInvalid`-but-throws contract for those vectors.
        let whole: Int64?
        if wholePart.isEmpty {
            whole = 0
        } else {
            whole = Int64(wholePart)
        }

        guard let whole else {
            throw isNegative ? AmountError.negativeAmount : AmountError.greaterThanSupply
        }

        // negative amounts are rejected before any other bounds/precision check,
        // mirroring the original `decimal >= 0` guard's priority.
        guard !isNegative else {
            throw AmountError.negativeAmount
        }

        guard whole <= Self.maxSupplyZec else {
            throw AmountError.greaterThanSupply
        }

        guard fractionPart.count <= Self.maxFractionalDecimalDigits else {
            throw AmountError.tooManyFractionalDigits
        }

        // `whole` is now bounded by `maxSupplyZec`, so this scaling cannot overflow `Int64`.
        let paddedFraction = fractionPart + String(repeating: "0", count: Self.maxFractionalDecimalDigits - fractionPart.count)
        let fraction: Int64 = paddedFraction.isEmpty ? 0 : (Int64(paddedFraction) ?? 0)

        let zatoshi = whole * Self.zatoshiPerZec + fraction

        guard zatoshi <= Self.maxSupplyZatoshi else {
            throw AmountError.greaterThanSupply
        }

        return zatoshi
    }
}

extension Decimal {
    var significantFractionalDecimalDigits: Int {
        return max(-exponent, 0)
    }

    func zecBankersRounding() -> Decimal {
        var result = Decimal()
        var number = self

        NSDecimalRound(&result, &number, Amount.maxFractionalDecimalDigits, .bankers)
        return result
    }
}
