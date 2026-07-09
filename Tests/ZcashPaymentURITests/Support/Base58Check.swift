//
//  Base58Check.swift
//  zcash-swift-payment-uri
//
//  TEST SUPPORT — not part of the shipped library.
//
//  The library performs NO address validation of its own: callers supply an
//  ``AddressValidator``. This reference checker exists so that the shared
//  conformance corpus — which contains deliberately checksum-corrupted address
//  vectors — stays executable against a realistic reference validator.
//
//  A dependency-free Base58Check decoder-verifier used to structurally
//  validate transparent Zcash addresses (P2PKH / P2SH). Base58Check is the
//  Bitcoin/Zcash encoding of `version-bytes || payload || checksum`, where the
//  checksum is the first 4 bytes of SHA-256d over `version-bytes || payload`.
//

import Foundation

/// Dependency-free Base58Check decoder-verifier.
///
/// Test support only; used by the reference ``AddressValidator`` that backs
/// the conformance corpus.
enum Base58Check {
    /// Base58 alphabet (Bitcoin/Zcash ordering). Note the deliberately omitted
    /// visually-ambiguous characters: `0`, `O`, `I`, `l`.
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)

    /// Reverse lookup: ASCII byte -> base58 digit value, or 0xff if invalid.
    private static let alphabetReverse: [UInt8] = {
        var table = [UInt8](repeating: 0xff, count: 128)
        for (value, char) in alphabet.enumerated() {
            table[Int(char)] = UInt8(value)
        }
        return table
    }()

    /// Decodes a Base58Check string and verifies its 4-byte SHA-256d checksum.
    ///
    /// - Returns: the decoded payload (version bytes followed by data) with the
    ///   4-byte checksum removed, or `nil` if the string contains characters
    ///   outside the base58 alphabet, is too short to contain a checksum, or
    ///   fails checksum verification.
    static func decode(_ s: String) -> [UInt8]? {
        guard let raw = base58Decode(s) else { return nil }
        // Need at least the 4-byte checksum (a real address also has version
        // bytes + data, but 4 is the hard minimum to even split).
        guard raw.count >= 4 else { return nil }

        let payload = Array(raw[0 ..< (raw.count - 4)])
        let checksum = Array(raw[(raw.count - 4)...])
        let computed = Array(SHA256.doubleHash(payload)[0 ..< 4])
        guard computed == checksum else { return nil }
        return payload
    }

    /// Convenience: verifies that `s` is a valid Base58Check string whose
    /// decoded payload begins with one of the accepted version-byte prefixes.
    ///
    /// Transparent-address version bytes (from librustzcash
    /// `zcash_protocol/src/constants/{mainnet,testnet,regtest}.rs`):
    ///
    ///   | network         | P2PKH (`B58_PUBKEY_ADDRESS_PREFIX`) | P2SH (`B58_SCRIPT_ADDRESS_PREFIX`) |
    ///   |-----------------|-------------------------------------|------------------------------------|
    ///   | mainnet         | `[0x1c, 0xb8]`  (`t1…`)              | `[0x1c, 0xbd]`  (`t3…`)            |
    ///   | testnet         | `[0x1d, 0x25]`  (`tm…`)              | `[0x1c, 0xba]`  (`t2…`)            |
    ///   | regtest         | `[0x1d, 0x25]`  (same as testnet)   | `[0x1c, 0xba]`  (same as testnet) |
    static func verify(_ s: String, expectedVersionBytes: [[UInt8]]) -> Bool {
        guard let payload = decode(s) else { return false }
        for prefix in expectedVersionBytes where payload.count >= prefix.count {
            if Array(payload[0 ..< prefix.count]) == prefix {
                return true
            }
        }
        return false
    }

    // MARK: - Base58 big-integer decode (no BigInt dependency)

    /// Decodes a base58 string into its big-endian byte representation,
    /// preserving leading-zero bytes (encoded as leading `'1'` characters).
    private static func base58Decode(_ s: String) -> [UInt8]? {
        let input = Array(s.utf8)
        guard !input.isEmpty else { return nil }

        // Big-endian base-256 accumulator built up digit by digit.
        var bytes: [UInt8] = []
        for char in input {
            guard char < 128 else { return nil }
            let digit = alphabetReverse[Int(char)]
            guard digit != 0xff else { return nil }

            // bytes = bytes * 58 + digit
            var carry = Int(digit)
            var i = bytes.count - 1
            while i >= 0 {
                carry += 58 * Int(bytes[i])
                bytes[i] = UInt8(carry & 0xff)
                carry >>= 8
                i -= 1
            }
            while carry > 0 {
                bytes.insert(UInt8(carry & 0xff), at: 0)
                carry >>= 8
            }
        }

        // Each leading '1' represents a leading zero byte.
        var leadingZeros = 0
        for char in input {
            if char == 0x31 /* '1' */ { leadingZeros += 1 } else { break }
        }

        return [UInt8](repeating: 0, count: leadingZeros) + bytes
    }
}

// The spec-notation identifiers this file uses are confined to it; re-enabling
// the rule here bounds the disabled region to exactly this file.
