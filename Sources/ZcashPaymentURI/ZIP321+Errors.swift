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
        case .memoTooLong, .memoEmpty, .notUTF8String:
            return ZIP321.Errors.memoBytesError(memoError, index == 0 ? nil : index)
        }
    }

    static func mapFrom(_ amountError: Amount.AmountError, index: UInt) -> ZIP321.Errors {
        switch amountError {
        case .greaterThanSupply:
            return .amountExceededSupply(index)
        case .invalidTextInput:
            return .invalidParamValue(param: "amount", index: index == 0 ? nil : index)
        case .negativeAmount, .tooManyFractionalDigits:
            return .amountTooSmall(index)
        }
    }
}
