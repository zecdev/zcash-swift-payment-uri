//
//  AmountParser.swift
//
//
//  Created by Pacu on 2026-07-08.
//

/// Parses a ZIP-321 `amountparam` value using the **strict** grammar
/// `amountparam = 1*DIGIT [ "." 1*8DIGIT ]`, delegating to ``NonNegativeAmount/zec(_:)`` (which already
/// implements the grammar with checked integer arithmetic) and mapping its
/// ``NonNegativeAmount/AmountError`` onto the closest v1 ``ZIP321/Errors`` case.
///
/// Unlike the deprecated `LegacyAmount(string:)` path this rejects a leading or trailing
/// decimal point (`".5"`, `"123."`), a sign, whitespace, scientific notation, and any `%`
/// escape (amount values are never percent-decoded), matching the reference `parse_amount`.
enum AmountParser {
    /// Parses `string` into a ``NonNegativeAmount``.
    /// - parameter string: the raw `amount` parameter value.
    /// - parameter index: the ZIP-321 payment index (0 meaning "no index"), used to tag the
    /// thrown error.
    /// - throws: a ``ZIP321/Errors`` value describing why the amount was rejected.
    static func parse(_ string: String, index: UInt) throws -> NonNegativeAmount {
        switch NonNegativeAmount.zec(string) {
        case .success(let zatoshi):
            return zatoshi
        case .failure(let error):
            throw ZIP321.Errors.mapFrom(error, index: index)
        }
    }
}
