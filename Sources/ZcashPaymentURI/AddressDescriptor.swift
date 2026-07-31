//
//  AddressDescriptor.swift
//  zcash-swift-payment-uri
//

import Foundation

/// What an ``AddressValidator`` reports about a recipient address it accepts.
///
/// This library performs **no** address validation and knows **nothing** about
/// Zcash address encodings: no Bech32, no Base58Check, no human-readable-part
/// tables, no receiver decoding. Everything it needs in order to apply the
/// [ZIP-321](https://zips.z.cash/zip-0321) payment rules is stated here by the
/// validator, and is taken as authoritative.
///
/// The three facts are exactly the ones ZIP-321 semantics depend on:
///
/// - ``network`` decides whether the address belongs to the network the request
///   is being parsed for (see ``ZIP321/parse(_:expecting:validator:maxInputBytes:)``).
/// - ``canReceiveMemos`` decides whether a `memo` parameter may accompany this
///   recipient. A shielded (Sapling / Unified with a shielded receiver)
///   recipient can; a transparent one cannot.
/// - ``isTransparent`` decides whether a zero-valued output to this recipient is
///   permitted. Zero-valued transparent outputs are disallowed by consensus.
///
/// ``isTransparent`` and ``canReceiveMemos`` are two independent facts rather
/// than one enum on purpose: address kinds that are neither plainly
/// "transparent" nor plainly "shielded" (a TEX address, a Unified Address whose
/// receiver set the caller resolves itself) are describable without this library
/// having to enumerate address kinds it deliberately does not model.
public struct AddressDescriptor: Equatable, Sendable {
    /// The consensus network this address belongs to.
    public let network: Network

    /// Whether funds sent to this address land in the transparent pool.
    ///
    /// Used to enforce ZIP-321's rejection of a zero-valued amount for a
    /// transparent recipient.
    public let isTransparent: Bool

    /// Whether this recipient can receive a ZIP-302 memo.
    ///
    /// Used to enforce ZIP-321's rejection of a `memo` parameter attached to a
    /// recipient that cannot receive one.
    public let canReceiveMemos: Bool

    /// Describes an address a validator has accepted.
    /// - parameter network: the consensus network the address belongs to.
    /// - parameter isTransparent: `true` when funds sent to it land in the transparent pool.
    /// - parameter canReceiveMemos: `true` when the recipient can receive a ZIP-302 memo.
    public init(network: Network, isTransparent: Bool, canReceiveMemos: Bool) {
        self.network = network
        self.isTransparent = isTransparent
        self.canReceiveMemos = canReceiveMemos
    }
}
