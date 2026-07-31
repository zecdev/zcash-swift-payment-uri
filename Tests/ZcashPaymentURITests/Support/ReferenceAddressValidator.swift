//
//  ReferenceAddressValidator.swift
//  zcash-swift-payment-uri
//
//  TEST SUPPORT — not part of the shipped library.
//
//  An `AddressValidator` implemented on top of the test-only Bech32 /
//  Base58Check reference checkers. It plays, for the test suite, the role a
//  wallet SDK plays in production: it is the authority on which address strings
//  are acceptable recipients, which network they belong to, and what they can
//  receive.
//
//  It exists because the shared conformance corpus contains vectors whose whole
//  point is checksum corruption, mixed-case Bech32, wrong-network addresses and
//  Sprout recipients. Those vectors are only meaningful against a validator that
//  actually verifies encodings — and the library, by design, no longer contains
//  one. Putting it here is exactly the boundary the design intends: the corpus
//  proves the library rejects what the VALIDATOR rejects.
//
//  Every constant below (HRPs, Base58Check version bytes) is taken from
//  librustzcash `zcash_protocol/src/constants/{mainnet,testnet,regtest}.rs`,
//  ZIP-316 (Unified) and ZIP-320 (TEX).
//

import Foundation
@testable import ZcashPaymentURI

/// Verifies Zcash address encodings for ONE network and reports ZIP-321
/// capabilities. Test support only.
///
/// Accepts, for its `network`:
///
/// - **Sapling** payment addresses: Bech32 (classic) checksum with the
///   network's HRP (`zs` / `ztestsapling` / `zregtestsapling`). Shielded:
///   can receive memos.
/// - **Unified** addresses: Bech32m checksum with the network's HRP
///   (`u` / `utest` / `uregtest`). The payload is opaque here; no ZIP-316
///   receiver decoding is performed, and a Revision 0 UA always carries a
///   shielded receiver, so these are reported as memo-capable.
/// - **TEX** addresses ([ZIP-320](https://zips.z.cash/zip-0320)): Bech32m
///   checksum with the network's HRP (`tex` / `textest` / `texregtest`).
///   Transparent-source-only: transparent, no memos.
/// - **Transparent** P2PKH / P2SH: Base58Check (SHA-256d) whose decoded payload
///   starts with the network's version bytes. Regtest reuses the testnet bytes.
///
/// **Sprout addresses are always rejected** — even with a valid Base58Check
/// checksum — because ZIP-321 disallows Sprout recipients. Mixed-case Bech32
/// strings are rejected per BIP-173. A checksum-valid address of another
/// network is rejected: this validator only speaks for `network`.
struct ReferenceAddressValidator: AddressValidator {
    let network: Network

    init(_ network: Network) {
        self.network = network
    }

    func validate(_ address: String) -> AddressDescriptor? {
        // Sprout is checked by prefix BEFORE any generic Base58Check matching,
        // so that a checksum-valid Sprout address is still rejected.
        guard !isSprout(address) else { return nil }

        // Bech32/Bech32m kinds: one decode both verifies the checksum and
        // rejects mixed case; the (HRP, variant) pair must then match one of
        // this network's shielded/TEX encodings exactly.
        if let decoded = Bech32.decode(address) {
            switch (decoded.hrp, decoded.variant) {
            case (saplingHRP, .bech32):
                return AddressDescriptor(network: network, isTransparent: false, canReceiveMemos: true)
            case (unifiedHRP, .bech32m):
                return AddressDescriptor(network: network, isTransparent: false, canReceiveMemos: true)
            case (texHRP, .bech32m):
                return AddressDescriptor(network: network, isTransparent: true, canReceiveMemos: false)
            default:
                // Checksum-valid but wrong HRP for this network, or the wrong
                // checksum variant for the kind its HRP claims.
                return nil
            }
        }

        // Transparent kinds: Base58Check with this network's version bytes.
        guard Base58Check.verify(address, expectedVersionBytes: [p2pkhVersionBytes, p2shVersionBytes]) else {
            return nil
        }

        return AddressDescriptor(network: network, isTransparent: true, canReceiveMemos: false)
    }

    // MARK: - Network constants

    /// Sprout HRPs. `zt` collides with `ztestsapling`, hence the exclusion.
    private func isSprout(_ address: String) -> Bool {
        switch network {
        case .mainnet:
            return address.hasPrefix("zc")
        case .testnet, .regtest:
            return address.hasPrefix("zt") && !address.hasPrefix("ztestsapling")
        }
    }

    /// Bech32 human-readable part of Sapling payment addresses, per the Zcash
    /// protocol specification (§5.6.4) and `HRP_SAPLING_PAYMENT_ADDRESS`.
    private var saplingHRP: String {
        switch network {
        case .mainnet: return "zs"
        case .testnet: return "ztestsapling"
        case .regtest: return "zregtestsapling"
        }
    }

    /// Bech32m human-readable part of Unified Addresses, per ZIP-316.
    private var unifiedHRP: String {
        switch network {
        case .mainnet: return "u"
        case .testnet: return "utest"
        case .regtest: return "uregtest"
        }
    }

    /// Bech32m human-readable part of TEX addresses, per ZIP-320.
    private var texHRP: String {
        switch network {
        case .mainnet: return "tex"
        case .testnet: return "textest"
        case .regtest: return "texregtest"
        }
    }

    /// `B58_PUBKEY_ADDRESS_PREFIX` version bytes (P2PKH). Regtest reuses
    /// testnet's.
    private var p2pkhVersionBytes: [UInt8] {
        switch network {
        case .mainnet: return [0x1c, 0xb8]  // t1…
        case .testnet, .regtest: return [0x1d, 0x25]  // tm…
        }
    }

    /// `B58_SCRIPT_ADDRESS_PREFIX` version bytes (P2SH). Regtest reuses
    /// testnet's.
    private var p2shVersionBytes: [UInt8] {
        switch network {
        case .mainnet: return [0x1c, 0xbd]  // t3…
        case .testnet, .regtest: return [0x1c, 0xba]  // t2…
        }
    }
}

extension ReferenceAddressValidator {
    /// The mainnet reference validator.
    static let mainnet = ReferenceAddressValidator(.mainnet)
    /// The testnet reference validator.
    static let testnet = ReferenceAddressValidator(.testnet)
    /// The regtest reference validator.
    static let regtest = ReferenceAddressValidator(.regtest)

    /// The reference validator for `network`.
    static func of(_ network: Network) -> ReferenceAddressValidator {
        ReferenceAddressValidator(network)
    }
}
