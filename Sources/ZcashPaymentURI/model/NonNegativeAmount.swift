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
/// `MAX_MONEY` (``maxMoney``), the only shape a ZIP-321 `amountparam` can take. It is backed by
/// an unsigned `UInt64`, mirroring the reference implementation's `u64`-backed `Zatoshis`, so a
/// negative amount is unrepresentable by construction rather than rejected at runtime.
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
    ///
    /// - Note: the backing type is `UInt64`, mirroring the reference implementation's
    /// `Zatoshis` (a `u64` newtype): a ZIP-321 amount is non-negative by grammar, so
    /// negative values are unrepresentable by construction.
    public static let maxMoney: UInt64 = 2_100_000_000_000_000

    /// number of zatoshi in 1 ZEC.
    static let zatoshiPerZec: UInt64 = 100_000_000

    /// `MAX_MONEY` expressed in whole ZEC: the largest whole-number part a ZEC decimal string
    /// may carry before the fractional digits are added in.
    // == maxMoney / zatoshiPerZec (2_100_000_000_000_000 / 100_000_000)
    static let maxWholeZec: UInt64 = 21_000_000

    /// the maximum number of digits allowed after the decimal point in a ZEC decimal string.
    static let maxFractionalDigits: Int = 8

    /// this amount, represented as an integer count of zatoshi.
    public let value: UInt64

    private init(uncheckedValue: UInt64) {
        self.value = uncheckedValue
    }

    public enum AmountError: Error, Equatable {
        /// the decimal string carries a leading `-`, i.e. it denotes a negative amount.
        ///
        /// Reported only by ``zec(_:)``: the `amountparam` grammar requires a non-empty
        /// whole-number part, and when that part is empty ``zec(_:)`` distinguishes a leading
        /// `-` from every other malformed shape, so a negative input is named as such instead
        /// of being lumped in with arbitrary garbage. Unreachable from ``zatoshi(_:)``, whose
        /// `UInt64` parameter cannot represent a negative count.
        case negativeAmount
        /// the provided value is greater than ``NonNegativeAmount/maxMoney``.
        case exceededSupply
        /// the decimal string has more than 8 digits after the decimal point.
        case tooManyFractionalDigits
        /// the string does not conform to the strict ZIP-321 `amountparam` grammar.
        case invalidDecimalString
    }

    /// Creates a `NonNegativeAmount` from a raw zatoshi count.
    /// - parameter value: an unsigned integer count of zatoshi (negative counts are
    /// unrepresentable by construction).
    /// - returns: `.success` wrapping the `NonNegativeAmount` if `value` is at most `maxMoney`,
    /// otherwise `.failure(.exceededSupply)`.
    public static func zatoshi(_ value: UInt64) -> Result<NonNegativeAmount, AmountError> {
        guard value <= Self.maxMoney else { return .failure(.exceededSupply) }

        return .success(NonNegativeAmount(uncheckedValue: value))
    }

    /// Creates a `NonNegativeAmount` by parsing a decimal ZEC amount string using the **strict** ZIP-321
    /// `amountparam` grammar: `1*DIGIT [ "." 1*8DIGIT ]`.
    /// - parameter decimalString: a plain (non-scientific), non-negative decimal ZEC string,
    /// e.g. `"123.456"`, `"0.5"`, `"21000000"`.
    /// - returns: `.success` wrapping the parsed `NonNegativeAmount` or `.failure` with the specific
    /// `AmountError` describing why the string was rejected.
    ///
    /// ## Signed input
    /// The `amountparam` grammar admits no sign, so any signed string is rejected — but the two
    /// signs are distinguished rather than lumped together:
    /// - a leading `-` (e.g. `"-1.23"`, `"-0"`, `"-"`) yields `.failure(.negativeAmount)`: the
    /// input reads as an amount, and it is a negative one.
    /// - a leading `+` (e.g. `"+1.23"`) yields `.failure(.invalidDecimalString)`: an explicit
    /// positive sign is simply not part of the grammar.
    ///
    /// This mirrors the v1 amount type's eager rejection of signed input and makes
    /// ``AmountError/negativeAmount`` reachable from this entry point.
    public static func zec(_ decimalString: String) -> Result<NonNegativeAmount, AmountError> {
        var remainder = Substring(decimalString)

        let isASCIIDigit: (Character) -> Bool = { $0.isASCII && $0.isNumber }

        // an empty whole-number part means the string did not begin with a digit; the leading
        // character decides whether that is a negative amount or plain malformed input.
        let wholeDigits = remainder.prefix(while: isASCIIDigit)
        guard !wholeDigits.isEmpty else {
            return .failure(Self.emptyWholePartError(leading: remainder.first))
        }
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
        // a trailing sign, etc.) makes the whole string invalid: the grammar requires full
        // consumption. A leading sign cannot reach here — it leaves the whole-digit run empty
        // and is rejected by the guard above.
        guard remainder.isEmpty else { return .failure(.invalidDecimalString) }

        guard let whole = UInt64(wholeDigits) else {
            // the whole part has more digits than fit in a `UInt64` (or otherwise overflows) —
            // this is necessarily greater than `maxMoney`.
            return .failure(.exceededSupply)
        }

        // bounding `whole` here (rather than after scaling) guarantees the multiplication below
        // cannot overflow `UInt64`.
        guard whole <= Self.maxWholeZec else { return .failure(.exceededSupply) }

        let paddedFraction = fractionDigits + String(repeating: "0", count: Self.maxFractionalDigits - fractionDigits.count)
        let fraction = UInt64(paddedFraction) ?? 0

        let total = whole * Self.zatoshiPerZec + fraction

        guard total <= Self.maxMoney else { return .failure(.exceededSupply) }

        return .success(NonNegativeAmount(uncheckedValue: total))
    }

    /// The rejection reason for a decimal string whose whole-number part is empty.
    ///
    /// A leading `-` is reported as ``AmountError/negativeAmount`` so that a negative amount is
    /// named as such; every other shape (`+`, `.5`, the empty string, stray characters) is a
    /// plain ``AmountError/invalidDecimalString``.
    private static func emptyWholePartError(leading: Character?) -> AmountError {
        leading == "-" ? .negativeAmount : .invalidDecimalString
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
