//
//  Network.swift
//  zcash-swift-payment-uri
//

import Foundation

/// A Zcash consensus network.
///
/// A [ZIP-321](https://zips.z.cash/zip-0321) request is always parsed against
/// ONE expected network: every recipient address the URI carries must be an
/// address for that network, or the request is rejected. Which network an
/// address belongs to is decided by the caller-supplied ``AddressValidator``,
/// not by this library — see ``AddressDescriptor/network``.
public enum Network: Hashable, Sendable {
    /// The Zcash production consensus network.
    case mainnet
    /// The public Zcash test network.
    case testnet
    /// A local/private regression-testing network.
    case regtest
}
