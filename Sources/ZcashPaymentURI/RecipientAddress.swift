//
//  RecipientAddress.swift
//
//
//  Created by Francisco Gindre on 2023-12-08.
//

import Foundation

/// Represents a Zcash recipient address.
public struct RecipientAddress: Equatable {
    public typealias ValidatingClosure = ((String) -> Bool)
    
    public let value: String

    /// Initialize an opaque Recipient address that's conversible to a String with or without a validating function.
    /// - Parameter value: the string representing the recipient
    /// - Parameter validating: a closure that validates the given input.
    /// - Returns: `nil` if the validating function resolves the input as invalid, or a `RecipientAddress` if the input is valid or no validating closure is passed.
    public init?(value: String, validating: ValidatingClosure? = nil) {
        switch validating?(value) {
        case .none, .some(true):
            self.value = value
        case .some(false):
            return nil
        }
    }
}

extension RecipientAddress {
    var isTransparent: Bool {
        self.value.starts(with: "t")
    }
}
