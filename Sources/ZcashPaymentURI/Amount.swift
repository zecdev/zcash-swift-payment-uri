//
//  Amount.swift
//
//
//  Created by Pacu on 2024-01-01.
//

import Foundation
import BigDecimal
/// An *non-negative* decimal ZEC amount represented as specified in ZIP-321.
/// Amount can be from 1 zatoshi (0.00000001) to the `maxSupply` of 21M ZEC (`21_000_000`)
public struct Amount: Equatable {
    public enum AmountError: Error {
        case negativeAmount
        case greaterThanSupply
        case tooManyFractionalDigits
        case invalidTextInput
    }

    static let maxFractionalDecimalDigits: Int = 8

    static let zecRounding = Rounding(.toNearestOrEven, maxFractionalDecimalDigits)

    static let decimalHandler = NSDecimalNumberHandler(
        roundingMode: NSDecimalNumber.RoundingMode.bankers,
        scale: Int16(Self.maxFractionalDecimalDigits),
        raiseOnExactness: true,
        raiseOnOverflow: true,
        raiseOnUnderflow: true,
        raiseOnDivideByZero: true
    )

    static let maxSupply: BigDecimal = 21_000_000

    static let zero = Amount(unchecked: 0)

    let value: BigDecimal

    /// Initializes an Amount from a `Decimal` number
    /// - parameter value: decimal representation of the desired amount. **Important:** `Decimal` values with more than 8 fractional digits ** will be rounded** using bankers rounding.
    /// - returns A valid ZEC amount
    /// - throws `Amount.AmountError` then the provided value can't represent or can't be rounded to a non-negative  ZEC decimal amount.
    public init(value: Double) throws {
        guard value >= 0 else { throw AmountError.negativeAmount }

        guard value <= Self.maxSupply.asDouble() else { throw AmountError.greaterThanSupply }
        
        try self.init(decimal: BigDecimal(value).round(Self.zecRounding))
    }

    /// Initializes an Amount from a `BigDecimal` number
    /// - parameter decimal: decimal representation of the desired amount. **Important:** `Decimal` values with more than 8 fractional digits ** will be rounded** using bankers rounding.
    /// - returns A valid ZEC amount
    /// - throws `Amount.AmountError` then the provided value can't represent or can't be rounded to a non-negative  ZEC decimal amount.
    public init(decimal: BigDecimal) throws {
        guard decimal >= 0 else { throw AmountError.negativeAmount }

        guard decimal <= Self.maxSupply else { throw AmountError.greaterThanSupply }

        guard decimal.significantFractionalDecimalDigits <= Self.maxFractionalDecimalDigits else {
            throw AmountError.tooManyFractionalDigits
        }

        guard decimal <= Self.maxSupply else { throw AmountError.greaterThanSupply }

        self.value = decimal
    }

    /// Initializes an Amount from a `BigDecimal` number
    /// - parameter decimal: decimal representation of the desired amount. **Important:** `Decimal` values with more than 8 fractional digits ** will be rounded** using bankers rounding.
    /// - returns A valid ZEC amount
    /// - throws `Amount.AmountError` then the provided value can't represent or can't be rounded to a non-negative  ZEC decimal amount.
    public init(decimal: Decimal) throws {
        guard decimal >= 0 else { throw AmountError.negativeAmount }

        guard decimal.significantFractionalDecimalDigits <= Self.maxFractionalDecimalDigits else {
            throw AmountError.tooManyFractionalDigits
        }

        guard decimal <= Self.maxSupply.asDecimal() else { throw AmountError.greaterThanSupply }
        
        self.value = BigDecimal(decimal).round(Self.zecRounding).trim
    }

    public init(string: String) throws {
        let decimalAmount = BigDecimal(string).trim

        guard !decimalAmount.isNaN else {
            throw AmountError.invalidTextInput
        }

        guard decimalAmount.significantFractionalDecimalDigits <= Self.maxFractionalDecimalDigits else {
            throw AmountError.tooManyFractionalDigits
        }

        try self.init(decimal: decimalAmount)
    }

    init(unchecked: BigDecimal) {
        self.value = unchecked
    }

    public func toString() -> String {
        let decimal = value.round(Rounding(.toNearestOrEven, Self.maxFractionalDecimalDigits)).trim

        return decimal.asString(.plain) // this value is already validated.
    }
}

extension BigDecimal {
    var significantFractionalDecimalDigits: Int {
        return max(-exponent, 0)
    }
}

extension Decimal {
    var significantFractionalDecimalDigits: Int {
        return max(-exponent, 0)
    }
}
