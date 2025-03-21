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
    /// - Parameter context: the context in which this address should be evaluated (mainnet, testnet, regtest)
    /// - Parameter validating: a closure that validates the given input. If none is provided, default validations will be performed.
    /// - Returns: `nil` if the validating function resolves the input as invalid, or a `RecipientAddress` if the input is valid or no validating closure is passed.
    public init?(value: String, context: ParserContext, validating: ValidatingClosure? = nil) {
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

/// Expected behavior for an address validator. Implementors should be able to
/// receive a string-encoded address and determine some validity
public protocol AddressValidator {
    /// determines whether the ``address`` is valid in the context of the ZIP-321
    /// payment request specification. Example: Sprout addresses are not allowed
    func isValid(address: String) -> Bool
    /// determines whether the address corresponds to a transparent recipient
    func isTransparent(address: String) -> Bool
    /// determines whether this adderss is Sprout receiver
    func isSprout(address: String) -> Bool
    /// determines whether this address is a **non-sprout** shielded address.
    /// - Note: Unified addreses are assumed to be Revision 0 which should always
    /// contain a shielded address and therefore they are considered shielded.
    func isShielded(address: String) -> Bool
}
