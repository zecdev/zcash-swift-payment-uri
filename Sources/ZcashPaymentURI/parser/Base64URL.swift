//
//  Base64URL.swift
//
//
//  Created by Pacu on 2026-07-08.
//

/// A strict [RFC 4648 §5](https://www.rfc-editor.org/rfc/rfc4648.html#section-5)
/// base64url codec **without padding**, matching the encoding ZIP-321 mandates for
/// `memo` parameter values (the reference implementation uses
/// `BASE64_URL_SAFE_NO_PAD`).
///
/// Unlike Foundation's base64 support, this codec:
/// - uses the URL-safe alphabet (`-` and `_` instead of `+` and `/`),
/// - never emits `=` padding on encode,
/// - rejects on decode: `+`, `/`, `=`, whitespace, any character outside the
///   base64url alphabet, impossible lengths (`length % 4 == 1`), and encodings
///   whose trailing bits are nonzero (non-canonical encodings).
enum Base64URL {
    /// The RFC 4648 §5 base64url alphabet.
    private static let alphabet: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)

    /// Maps an ASCII byte to its 6-bit alphabet index, or `nil` if the byte is
    /// not part of the base64url alphabet.
    private static let decodeTable: [Int8] = {
        var table = [Int8](repeating: -1, count: 256)
        for (index, char) in alphabet.enumerated() {
            table[Int(char)] = Int8(index)
        }
        return table
    }()

    /// Encodes `bytes` as an unpadded base64url string.
    static func encode(_ bytes: [UInt8]) -> String {
        var output: [UInt8] = []
        output.reserveCapacity((bytes.count * 4 + 2) / 3)

        var index = 0
        while index + 3 <= bytes.count {
            let chunk = (UInt32(bytes[index]) << 16) | (UInt32(bytes[index + 1]) << 8) | UInt32(bytes[index + 2])
            output.append(alphabet[Int((chunk >> 18) & 0x3F)])
            output.append(alphabet[Int((chunk >> 12) & 0x3F)])
            output.append(alphabet[Int((chunk >> 6) & 0x3F)])
            output.append(alphabet[Int(chunk & 0x3F)])
            index += 3
        }

        switch bytes.count - index {
        case 1:
            let chunk = UInt32(bytes[index]) << 16
            output.append(alphabet[Int((chunk >> 18) & 0x3F)])
            output.append(alphabet[Int((chunk >> 12) & 0x3F)])
        case 2:
            let chunk = (UInt32(bytes[index]) << 16) | (UInt32(bytes[index + 1]) << 8)
            output.append(alphabet[Int((chunk >> 18) & 0x3F)])
            output.append(alphabet[Int((chunk >> 12) & 0x3F)])
            output.append(alphabet[Int((chunk >> 6) & 0x3F)])
        default:
            break
        }

        return String(decoding: output, as: UTF8.self)
    }

    /// Decodes an unpadded base64url string into its bytes.
    /// - returns: the decoded bytes, or `nil` if `string` is not a canonical,
    /// unpadded base64url encoding (see the type documentation for the exact
    /// rejection rules). The empty string decodes to the empty byte array.
    static func decode(_ string: String) -> [UInt8]? {
        let input = Array(string.utf8)

        // Non-ASCII characters produce multi-byte UTF-8 sequences whose bytes are
        // >= 0x80 and therefore map to -1 in the decode table below, so they are
        // rejected by the per-character check without special-casing.

        // an unpadded base64url encoding of n bytes has length 4*(n/3) plus
        // 0, 2, or 3 characters for the final partial group; length % 4 == 1
        // is impossible.
        guard input.count % 4 != 1 else { return nil }

        var output: [UInt8] = []
        output.reserveCapacity(input.count * 3 / 4)

        var buffer: UInt32 = 0
        var bitsCollected = 0

        for char in input {
            let sextet = decodeTable[Int(char)]
            guard sextet >= 0 else { return nil }

            buffer = (buffer << 6) | UInt32(sextet)
            bitsCollected += 6

            if bitsCollected >= 8 {
                bitsCollected -= 8
                output.append(UInt8((buffer >> UInt32(bitsCollected)) & 0xFF))
            }
        }

        // a canonical encoding zero-pads the final sextet: any leftover bits
        // must be zero (e.g. "QR" is rejected because 'R' carries nonzero
        // bits beyond the single encoded byte).
        guard buffer & ((1 << UInt32(bitsCollected)) - 1) == 0 else { return nil }

        return output
    }
}
