//
//  Bech32.swift
//  zcash-swift-payment-uri
//
//  TEST SUPPORT — not part of the shipped library.
//
//  The library performs NO address validation of its own: callers supply an
//  ``AddressValidator``. This reference checker exists so that the shared
//  conformance corpus — which contains deliberately checksum-corrupted address
//  vectors — stays executable against a realistic reference validator.
//
//  A dependency-free Bech32 / Bech32m decoder-verifier, per BIP-173 and
//  BIP-350. Used to structurally validate Sapling (Bech32), TEX (Bech32m) and
//  Unified (Bech32m) Zcash addresses by confirming their human-readable prefix,
//  charset and BCH checksum.
//
//  Length limit — why 1023 and not BIP-173's 90:
//  BIP-173 specifies an overall length cap of 90 characters, but that limit is
//  specific to the Bitcoin segwit use case; it is NOT a property of the Bech32
//  construction itself. Zcash addresses (in particular Unified Addresses) are
//  routinely far longer than 90 characters, so librustzcash does not apply the
//  90-char cap. `zcash_address` decodes Bech32/Bech32m via the `bech32` crate
//  (v0.11.0), whose per-`Checksum` code-length limit is:
//
//      bech32-0.11.0/src/primitives/mod.rs
//        impl Checksum for Bech32  { const CODE_LENGTH: usize = 1023; ... }
//        impl Checksum for Bech32m { const CODE_LENGTH: usize = 1023; ... }
//
//  Sapling addresses (`Bech32`) and TEX addresses (`Bech32m`) inherit this
//  1023-character limit. Unified Addresses use a custom checksum,
//  `Bech32mZip316` (zcash_address/src/kind/unified.rs), which raises the limit
//  to 4_194_368 (ZIP-316 l^MAX) but is otherwise Bech32m; real UAs are well
//  under 1023 characters in practice. We therefore mirror the standard
//  Bech32/Bech32m limit of 1023, which is the value that applies to every
//  address this verifier is intended to validate.
//

import Foundation

/// Dependency-free Bech32 / Bech32m decoder-verifier (BIP-173 / BIP-350).
///
/// Test support only; used by the reference ``AddressValidator`` that backs
/// the conformance corpus.
enum Bech32 {
    /// The two BCH checksum variants and their target residues.
    enum Variant {
        case bech32
        case bech32m

        /// Polymod constant the checksum must equal for this variant.
        var checksumConstant: UInt32 {
            switch self {
            case .bech32: return 1
            case .bech32m: return 0x2bc830a3
            }
        }
    }

    /// Maximum total encoded length we accept (see file header).
    static let maxLength = 1023

    /// Bech32 data charset (BIP-173).
    private static let charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l".utf8)

    /// Reverse lookup: ASCII byte -> 5-bit value, or 0xff if not in the charset.
    private static let charsetReverse: [UInt8] = {
        var table = [UInt8](repeating: 0xff, count: 128)
        for (value, char) in charset.enumerated() {
            table[Int(char)] = UInt8(value)
        }
        return table
    }()

    /// Decodes and checksum-verifies a Bech32 or Bech32m string.
    ///
    /// - Returns: the lowercased human-readable part, the decoded 5-bit data
    ///   values (excluding the 6 checksum characters), and which variant's
    ///   checksum matched — or `nil` if the string is not a well-formed,
    ///   checksum-valid Bech32/Bech32m encoding.
    // The branch-per-rejection-rule structure and the `(hrp, data, variant)` return shape both
    // mirror the BIP-173/BIP-350 reference decoder, so that this can be audited against it
    // line by line; the Kotlin sibling suppresses these same two findings on this same function.
    static func decode(_ s: String) -> (hrp: String, data: [UInt8], variant: Variant)? {
        // Must be ASCII and within the length limit.
        guard s.count <= maxLength else { return nil }
        let scalars = Array(s.unicodeScalars)
        for scalar in scalars where scalar.value < 33 || scalar.value > 126 {
            // Printable ASCII 33..126 only (excludes spaces and controls).
            return nil
        }

        // Reject mixed case BEFORE lowercasing (BIP-173).
        var hasLower = false
        var hasUpper = false
        for scalar in scalars {
            if scalar.value >= 0x61 && scalar.value <= 0x7a { hasLower = true }
            if scalar.value >= 0x41 && scalar.value <= 0x5a { hasUpper = true }
        }
        if hasLower && hasUpper { return nil }

        let lowered = Array(s.lowercased().utf8)

        // Separator is the LAST '1'.
        guard let sepIndex = lowered.lastIndex(of: 0x31 /* '1' */) else { return nil }

        // HRP occupies everything before the separator: 1..83 chars.
        let hrpBytes = Array(lowered[0..<sepIndex])
        guard hrpBytes.count >= 1, hrpBytes.count <= 83 else { return nil }
        for byte in hrpBytes where byte < 33 || byte > 126 {
            return nil
        }

        // Data part follows the separator and must be >= 6 (checksum) chars.
        let dataPart = Array(lowered[(sepIndex + 1)...])
        guard dataPart.count >= 6 else { return nil }

        // Map each data character to its 5-bit value.
        var values: [UInt8] = []
        values.reserveCapacity(dataPart.count)
        for byte in dataPart {
            guard byte < 128 else { return nil }
            let v = charsetReverse[Int(byte)]
            guard v != 0xff else { return nil }
            values.append(v)
        }

        // Verify the checksum and identify the variant.
        let residue = polymod(hrpExpand(hrpBytes) + values)
        let variant: Variant
        if residue == Variant.bech32.checksumConstant {
            variant = .bech32
        } else if residue == Variant.bech32m.checksumConstant {
            variant = .bech32m
        } else {
            return nil
        }

        // Every byte of `hrpBytes` was checked to be printable ASCII (33...126) above, so this
        // decoding is total; the failable `String(bytes:encoding:)` would add a `nil` branch no
        // input can reach (and that the 100% region-coverage gate could not cover).
        let hrp = String(decoding: hrpBytes, as: UTF8.self)
        // Strip the 6-character checksum from the returned data.
        let data = Array(values[0..<(values.count - 6)])
        return (hrp: hrp, data: data, variant: variant)
    }

    /// Convenience: verifies that `s` decodes as the expected variant with the
    /// expected human-readable part.
    static func verify(_ s: String, expectedHrp: String, variant: Variant) -> Bool {
        guard let decoded = decode(s) else { return false }
        return decoded.variant == variant && decoded.hrp == expectedHrp.lowercased()
    }

    // MARK: - BCH checksum primitives (BIP-173 / BIP-350)

    private static func polymod(_ values: [UInt8]) -> UInt32 {
        let generator: [UInt32] = [
            0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3
        ]
        var chk: UInt32 = 1
        for value in values {
            let top = chk >> 25
            chk = ((chk & 0x1ffffff) << 5) ^ UInt32(value)
            for i in 0..<5 where (top >> UInt32(i)) & 1 != 0 {
                chk ^= generator[i]
            }
        }
        return chk
    }

    private static func hrpExpand(_ hrp: [UInt8]) -> [UInt8] {
        var expanded: [UInt8] = []
        expanded.reserveCapacity(hrp.count * 2 + 1)
        for byte in hrp { expanded.append(byte >> 5) }
        expanded.append(0)
        for byte in hrp { expanded.append(byte & 0x1f) }
        return expanded
    }
}

// The spec-notation identifiers this file uses are confined to it; re-enabling
// the rule here bounds the disabled region to exactly this file.
