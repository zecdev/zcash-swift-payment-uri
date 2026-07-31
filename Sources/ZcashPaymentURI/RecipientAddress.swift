//
//  RecipientAddress.swift
//
//
//  Created by Pacu on 2023-12-08.
//

import Foundation

/// A Zcash recipient address that some ``AddressValidator`` has accepted,
/// carried together with what that validator said about it.
///
/// A `RecipientAddress` is an opaque string plus a ``descriptor``. This library
/// never inspects ``value`` — it does not decode, re-check or classify the
/// address in any way. Every capability question it needs to answer while
/// applying the [ZIP-321](https://zips.z.cash/zip-0321) payment rules is read
/// off the descriptor the validator produced.
public struct RecipientAddress: Equatable, Sendable {
    /// The string-encoded address, verbatim as the validator saw it.
    public let value: String

    /// What the ``AddressValidator`` reported about ``value``.
    public let descriptor: AddressDescriptor

    /// Wraps an address a caller has ALREADY validated, together with its
    /// description.
    ///
    /// Use this when the address came from somewhere other than a URI — a
    /// wallet's own address book, a QR scan the wallet has already resolved,
    /// a test fixture. The descriptor is trusted as-is.
    /// - parameter value: the string-encoded address.
    /// - parameter descriptor: what the address is (network and capabilities).
    public init(value: String, descriptor: AddressDescriptor) {
        self.value = value
        self.descriptor = descriptor
    }

    /// Validates `value` with `validator` and, if accepted, wraps it.
    /// - parameter value: the string-encoded address.
    /// - parameter validator: the authority on this address. Returning `nil`
    /// from ``AddressValidator/validate(_:)`` rejects the address.
    /// - returns: `nil` when the validator rejects `value`.
    public init?(value: String, validator: any AddressValidator) {
        guard let descriptor = validator.validate(value) else { return nil }

        self.value = value
        self.descriptor = descriptor
    }
}

public extension RecipientAddress {
    /// The consensus network this address belongs to, as reported by the
    /// validator that accepted it.
    var network: Network { descriptor.network }
}

extension RecipientAddress {
    /// Whether funds sent here land in the transparent pool. Read straight off
    /// the validator's descriptor.
    var isTransparent: Bool { descriptor.isTransparent }

    /// Whether this recipient can receive a ZIP-302 memo. Read straight off the
    /// validator's descriptor.
    var canReceiveMemos: Bool { descriptor.canReceiveMemos }
}
