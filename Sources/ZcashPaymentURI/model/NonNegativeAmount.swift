//
//  NonNegativeAmount.swift
//
//
//  Created by Pacu on 2026-07-08.
//

/// A non-negative integer count of zatoshi (1 ZEC == 100_000_000 zatoshi), the atomic unit in
/// which every ZEC amount is represented on the Zcash ledger.
///
/// The name states the invariant: a `NonNegativeAmount` is a non-negative amount bounded by
/// `MAX_MONEY` (``maxMoney``), the only shape a ZIP-321 `amountparam` can take.
///
/// `NonNegativeAmount` is intentionally amount-agnostic: it only enforces the invariant that a value is
/// representable on-chain (`0...maxMoney`). It has no opinion on whether zero is an acceptable
/// amount for a given payment — that policy (e.g. rejecting a zero-valued transparent output)
/// lives at the `Payment` level.
///
/// - Note: this type supersedes ``Amount``. Unlike `Amount`, `NonNegativeAmount` parses ZEC decimal strings
/// using the **strict** ZIP-321 `amountparam` grammar:
/// ```
/// amountparam = 1*DIGIT [ "." 1*8DIGIT ]
/// ```
/// i.e. the whole-number part must be present (leading zeros are permitted and ignored, e.g.
/// `"050"` is `50`), and if a decimal point is present it must be followed by 1 to 8 digits
/// (trailing zeros are permitted, e.g. `"00.500"` is `0.5`, but a bare trailing/leading point
/// such as `"123."` or `".5"` is rejected).
public struct NonNegativeAmount: Equatable, Hashable, Sendable, Comparable {
    /// `MAX_MONEY`: the maximum number of zatoshi that can ever exist (21_000_000 ZEC).
    public static let maxMoney: Int64 = 2_100_000_000_000_000

    /// number of zatoshi in 1 ZEC.
    static let zatoshiPerZec: Int64 = 100_000_000

    /// the maximum number of digits allowed after the decimal point in a ZEC decimal string.
    static let maxFractionalDigits: Int = 8

    /// this amount, represented as an integer count of zatoshi.
    public let value: Int64

    private init(uncheckedValue: Int64) {
        self.value = uncheckedValue
    }

    public enum AmountError: Error, Equatable {
        /// the provided value is negative.
        case negativeAmount
        /// the provided value is greater than ``NonNegativeAmount/maxMoney``.
        case exceededSupply
        /// the decimal string has more than 8 digits after the decimal point.
        case tooManyFractionalDigits
        /// the string does not conform to the strict ZIP-321 `amountparam` grammar.
        case invalidDecimalString
    }

    /// Creates a `NonNegativeAmount` from a raw zatoshi count.
    /// - parameter value: an integer count of zatoshi.
    /// - returns: `.success` wrapping the `NonNegativeAmount` if `value` is in `0...maxMoney`, otherwise
    /// `.failure` with the specific `AmountError`.
    public static func zatoshi(_ value: Int64) -> Result<NonNegativeAmount, AmountError> {
        guard value >= 0 else { return .failure(.negativeAmount) }
        guard value <= Self.maxMoney else { return .failure(.exceededSupply) }

        return .success(NonNegativeAmount(uncheckedValue: value))
    }

    /// Creates a `NonNegativeAmount` by parsing a decimal ZEC amount string using the **strict** ZIP-321
    /// `amountparam` grammar: `1*DIGIT [ "." 1*8DIGIT ]`.
    /// - parameter decimalString: a plain (non-scientific), non-negative decimal ZEC string,
    /// e.g. `"123.456"`, `"0.5"`, `"21000000"`.
    /// - returns: `.success` wrapping the parsed `NonNegativeAmount` or `.failure` with the specific
    /// `AmountError` describing why the string was rejected.
    public static func zec(_ decimalString: String) -> Result<NonNegativeAmount, AmountError> {
        var remainder = Substring(decimalString)

        let isASCIIDigit: (Character) -> Bool = { $0.isASCII && $0.isNumber }

        let wholeDigits = remainder.prefix(while: isASCIIDigit)
        guard !wholeDigits.isEmpty else { return .failure(.invalidDecimalString) }
        remainder.removeFirst(wholeDigits.count)

        var fractionDigits = Substring()
        if remainder.first == "." {
            remainder.removeFirst()

            fractionDigits = remainder.prefix(while: isASCIIDigit)
            guard !fractionDigits.isEmpty else { return .failure(.invalidDecimalString) }

            guard fractionDigits.count <= Self.maxFractionalDigits else {
                return .failure(.tooManyFractionalDigits)
            }

            remainder.removeFirst(fractionDigits.count)
        }

        // any leftover input (extra characters, whitespace, a second '.', scientific notation,
        // a sign, etc.) makes the whole string invalid: the grammar requires full consumption.
        guard remainder.isEmpty else { return .failure(.invalidDecimalString) }

        guard let whole = Int64(wholeDigits) else {
            // the whole part has more digits than fit in an `Int64` (or otherwise overflows) —
            // this is necessarily greater than `maxMoney`.
            return .failure(.exceededSupply)
        }

        // bounding `whole` here (rather than after scaling) guarantees the multiplication below
        // cannot overflow `Int64`.
        guard whole <= Self.maxMoney / Self.zatoshiPerZec else { return .failure(.exceededSupply) }

        let paddedFraction = fractionDigits + String(repeating: "0", count: Self.maxFractionalDigits - fractionDigits.count)
        let fraction = Int64(paddedFraction) ?? 0

        let total = whole * Self.zatoshiPerZec + fraction

        guard total <= Self.maxMoney else { return .failure(.exceededSupply) }

        return .success(NonNegativeAmount(uncheckedValue: total))
    }

    /// Renders this amount as a plain decimal ZEC string, matching the reference `amount_str`
    /// implementation: the whole-number part is always present, the fractional part is present
    /// only if nonzero, and trailing zeros in the fractional part are trimmed.
    public func decimalString() -> String {
        let whole = value / Self.zatoshiPerZec
        let fraction = value % Self.zatoshiPerZec

        guard fraction != 0 else {
            return String(whole)
        }

        var fractionDigits = String(fraction)
        fractionDigits = String(repeating: "0", count: Self.maxFractionalDigits - fractionDigits.count) + fractionDigits

        while fractionDigits.hasSuffix("0") {
            fractionDigits.removeLast()
        }

        return "\(whole).\(fractionDigits)"
    }

    public static func < (lhs: NonNegativeAmount, rhs: NonNegativeAmount) -> Bool {
        lhs.value < rhs.value
    }
}
