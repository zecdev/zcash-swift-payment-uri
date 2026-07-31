//
//  SHA256.swift
//  zcash-swift-payment-uri
//
//  TEST SUPPORT — not part of the shipped library.
//
//  A thin wrapper over Apple's CryptoKit SHA-256, used by the test-only
//  ``Base58Check`` reference checker to verify the double-SHA-256 checksum of
//  transparent (Base58Check) Zcash addresses.
//
//  The library itself performs NO address validation: callers supply an
//  ``AddressValidator``. These checkers exist so that the shared conformance
//  corpus — which contains deliberately checksum-corrupted address vectors —
//  stays executable against a realistic reference validator.
//
//  The hashing itself is delegated to the platform: CryptoKit ships with the
//  OS, so this adds no package dependency, and a security primitive is never
//  re-implemented here.
//

import CryptoKit
import Foundation

/// SHA-256, backed by Apple's CryptoKit. Test support only.
enum SHA256 {
    /// Computes the SHA-256 digest of `bytes`, returning the 32-byte hash.
    static func hash(_ bytes: [UInt8]) -> [UInt8] {
        Array(CryptoKit.SHA256.hash(data: Data(bytes)))
    }

    /// Computes `SHA256(SHA256(bytes))` (a.k.a. SHA-256d), as used by
    /// Base58Check checksums.
    static func doubleHash(_ bytes: [UInt8]) -> [UInt8] {
        hash(hash(bytes))
    }
}
