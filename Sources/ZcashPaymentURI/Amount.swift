//
//  Amount.swift
//
//
//  Created by Pacu on 2024-01-01.
//

import Foundation

/// The deprecated public name of ``LegacyAmount``: any code that spells `Amount` gets a
/// deprecation warning pointing at ``NonNegativeAmount``, while the underlying type (and its whole v1
/// API) keeps working unchanged. The library itself refers to the type by its non-deprecated
/// `LegacyAmount` name so it builds warning-free until the parser moves to ``NonNegativeAmount``
/// (planned for a later change in the v2 rewrite).
@available(*, deprecated, message: "Use NonNegativeAmount")
public typealias Amount = LegacyAmount

/// An *non-negative* decimal ZEC amount represented as specified in ZIP-321.
/// Amount can be from 1 zatoshi (0.00000001) to the `maxSupply` of 21M ZEC (`21_000_000`)
///
/// - Note: internally this is represented as a checked `UInt64` count of zatoshi
/// (1 ZEC == 100_000_000 zatoshi) fixed-point value rather than an arbitrary-precision
/// decimal type, mirroring the reference implementation's `Zatoshis` (a `u64` newtype):
/// a ZIP-321 amount is non-negative by grammar, so the unsigned type makes negative
/// values unrepresentable, and `maxSupply` (`MAX_MONEY` = 2_100_000_000_000_000
/// zatoshi) is comfortably representable by `UInt64` (max ~1.8 * 10^19).
///
/// - Important: prefer ``NonNegativeAmount``. This is the v1 amount type, kept working (under its
/// deprecated public name ``Amount``) until the parser adopts ``NonNegativeAmount``.
///
/// **Lifespan — this type is transitional scaffolding, not a compatibility promise.** It exists
/// only so that each step of the v2 rewrite stays individually reviewable: the parser still
/// consumes `LegacyAmount`, so removing it here would mean folding the entire parser conversion
/// into the change that introduces ``NonNegativeAmount``. `LegacyAmount` (and the deprecated
/// ``Amount`` alias) is deleted outright later in the same v2 series, once the parser produces
/// ``NonNegativeAmount`` directly. No v2.0.0 release ships this type.
public struct LegacyAmount: Equatable, Sendable {
    public enum AmountError: Error, Equatable {
        case negativeAmount
        case greaterThanSupply
        case tooManyFractionalDigits
        case invalidTextInput
    }

    static let maxFractionalDecimalDigits: Int = 8

    /// number of zatoshi in 1 ZEC
    static let zatoshiPerZec: UInt64 = 100_000_000

    /// `MAX_MONEY` expressed in whole ZEC
    static let maxSupplyZec: UInt64 = 21_000_000

    /// `MAX_MONEY` expressed in zatoshi (2_100_000_000_000_000)
    static let maxSupplyNonNegativeAmount: UInt64 = maxSupplyZec * zatoshiPerZec

    static let zero = LegacyAmount(unchecked: 0)

    /// this amount, represented as an integer count of zatoshi.
    let zatoshi: UInt64

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
        self.zatoshi = try Self.parseNonNegativeAmount(from: string)
    }

    init(unchecked: UInt64) {
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

extension LegacyAmount {
    /// Converts an already-range/precision-validated non-negative `Decimal` (`<= maxSupplyZec`,
    /// at most 8 fractional digits) into its exact zatoshi `UInt64` representation.
    /// - Important: callers must validate bounds and fractional digit count *before* calling this,
    /// since scaling by `zatoshiPerZec` assumes no overflow can occur.
    static func zatoshi(fromValidatedDecimal decimal: Decimal) throws -> UInt64 {
        let scaled = decimal * Decimal(Self.zatoshiPerZec)
        let number = NSDecimalNumber(decimal: scaled)

        // `scaled` is guaranteed to be a whole number in [0, maxSupplyNonNegativeAmount] given the
        // preconditions above, so this conversion cannot overflow `UInt64`.
        return number.uint64Value
    }

    /// Splits an amount string into its whole and fractional digit runs, validating shape and
    /// charset. Signs are rejected **eagerly**, before any other work: ZIP-321 amounts are
    /// non-negative by grammar, so a leading `-` fails immediately with
    /// ``AmountError/negativeAmount`` (and `+`, which the grammar equally forbids, fails
    /// with ``AmountError/invalidTextInput``).
    private static func splitValidatedParts(of text: Substring) throws -> (Substring, Substring) {
        guard text.first != "-" else {
            throw AmountError.negativeAmount
        }
        guard text.first != "+" else {
            throw AmountError.invalidTextInput
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

        guard wholePart.isEmpty || isASCIIDigits(wholePart),
            fractionPart.isEmpty || isASCIIDigits(fractionPart)
        else {
            throw AmountError.invalidTextInput
        }

        return (wholePart, fractionPart)
    }

    /// Manually parses a plain decimal `String` into its exact zatoshi `UInt64` representation,
    /// using only checked integer arithmetic (no floating point, no arbitrary-precision decimal type).
    ///
    /// Accepted grammar (intentionally lenient, matching v1 behavior):
    /// `1*DIGIT ["." *8DIGIT]` or `*DIGIT "." 1*8DIGIT`
    /// i.e. at least one of the whole/fractional parts must be present, but either may be empty
    /// (`"123."` and `".5"` are both accepted) — ZIP-321 grammar tightening is deferred.
    static func parseNonNegativeAmount(from string: String) throws -> UInt64 {
        let (wholePart, fractionPart) = try splitValidatedParts(of: Substring(string))

        // `UInt64(_:)` returns `nil` on overflow (e.g. a whole part with far more digits
        // than fit in a `UInt64`), which is mapped to `greaterThanSupply` below — matching
        // the ZIP-321 conformance corpus's contract for those vectors.
        let whole: UInt64?
        if wholePart.isEmpty {
            whole = 0
        } else {
            whole = UInt64(wholePart)
        }

        guard let whole else {
            throw AmountError.greaterThanSupply
        }

        guard whole <= Self.maxSupplyZec else {
            throw AmountError.greaterThanSupply
        }

        guard fractionPart.count <= Self.maxFractionalDecimalDigits else {
            throw AmountError.tooManyFractionalDigits
        }

        // `whole` is now bounded by `maxSupplyZec`, so this scaling cannot overflow `UInt64`.
        // The fraction is accumulated digit-by-digit over scalars already verified to be ASCII
        // digits, so no fallible conversion (and no untestable fallback branch) is involved.
        let paddedFraction = fractionPart + String(repeating: "0", count: Self.maxFractionalDecimalDigits - fractionPart.count)
        var fraction: UInt64 = 0
        for scalar in paddedFraction.unicodeScalars {
            fraction = fraction * 10 + UInt64(scalar.value - UnicodeScalar("0").value)
        }

        let zatoshi = whole * Self.zatoshiPerZec + fraction

        guard zatoshi <= Self.maxSupplyNonNegativeAmount else {
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

        NSDecimalRound(&result, &number, LegacyAmount.maxFractionalDecimalDigits, .bankers)
        return result
    }
}
