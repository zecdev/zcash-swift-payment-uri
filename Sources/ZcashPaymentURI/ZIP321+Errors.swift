//
//  ZIP321+Errors.swift
//
//
//  Created by Francisco Gindre on 12/22/23.
//

import Foundation

extension Error {
    func mapToErrorOrRethrow<T: Error>(_ error: T.Type) throws -> T {
        guard let err = self as? T else {
            throw self
        }

        return err
    }
}
extension ZIP321.Errors {
    static func mapFrom(_ memoError: MemoBytes.MemoError, index: UInt) -> ZIP321.Errors {
        switch memoError {
        case .invalidBase64URL:
            return ZIP321.Errors.invalidBase64
        case .memoTooLong, .notUTF8String:
            return ZIP321.Errors.memoBytesError(memoError, index == 0 ? nil : index)
        }
    }

    static func mapFrom(_ amountError: LegacyAmount.AmountError, index: UInt) -> ZIP321.Errors {
        switch amountError {
        case .greaterThanSupply:
            return .amountExceededSupply(index)
        case .invalidTextInput:
            return .invalidParamValue(param: "amount", index: index == 0 ? nil : index)
        case .negativeAmount, .tooManyFractionalDigits:
            return .amountTooSmall(index)
        }
    }

    /// Maps a strict ``NonNegativeAmount/AmountError`` onto the closest v1 `amount` error, preserving
    /// the mapping already used for the deprecated `LegacyAmount` path:
    ///   - `.exceededSupply`          → `.amountExceededSupply(index)`
    ///   - `.invalidDecimalString`    → `.invalidParamValue(param: "amount", index:)`
    ///     (the grammar-shape failure — empty whole/fraction part, sign, stray characters —
    ///     matching v1's `.invalidTextInput` mapping)
    ///   - `.tooManyFractionalDigits` → `.amountTooSmall(index)` (v1 parity)
    ///   - `.negativeAmount`          → `.amountTooSmall(index)` (v1 parity; not reachable via
    ///     `NonNegativeAmount.zec`, whose grammar has no sign, but mapped for totality)
    static func mapFrom(_ amountError: NonNegativeAmount.AmountError, index: UInt) -> ZIP321.Errors {
        switch amountError {
        case .exceededSupply:
            return .amountExceededSupply(index)
        case .invalidDecimalString:
            return .invalidParamValue(param: "amount", index: index == 0 ? nil : index)
        case .tooManyFractionalDigits, .negativeAmount:
            return .amountTooSmall(index)
        }
    }
}
