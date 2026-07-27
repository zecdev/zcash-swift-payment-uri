//
//  QcharCodec.swift
//
//
//  Created by Pacu on 2026-07-08.
//

import Foundation

/// The ZIP-321 `qchar` percent-encoding codec.
///
/// ZIP-321 defines the character set permitted (unescaped) in a parameter value:
/// ```
/// unreserved      = ALPHA / DIGIT / "-" / "." / "_" / "~"
/// allowed-delims  = "!" / "$" / "'" / "(" / ")" / "*" / "+" / "," / ";"
/// qchar           = unreserved / pct-encoded / allowed-delims / ":" / "@"
/// ```
///
/// `encode` percent-encodes exactly the *complement* of the raw `qchar` set, mirroring the
/// reference `QCHAR_ENCODE` `AsciiSet` in librustzcash `zip321` (`lib.rs` ~518-536): every
/// byte that is not a raw `qchar` byte — space, `"`, `#`, `%`, `&`, `/`, `<`, `=`, `>`, `?`,
/// `[`, `\`, `]`, `^`, `` ` ``, `{`, `|`, `}`, the C0 controls and DEL, and every non-ASCII
/// UTF-8 byte — is written as an uppercase `%XX` escape.
///
/// `decode` is the strict inverse used when parsing `label`/`message`/`other` values: each
/// `%XX` escape must be two hex digits (either case), each raw byte must be a `qchar` byte,
/// and the resulting decoded byte sequence must be valid UTF-8. The empty string is a valid
/// (zero-length) `*qchar` value and round-trips to itself.
enum QcharCodec {
    /// Whether `byte` is a raw (unescaped) `qchar` byte. Note that `%` is deliberately NOT a
    /// raw `qchar` byte here: it only ever appears as the leading byte of a `pct-encoded`
    /// triplet, so `encode` escapes a literal `%` and `decode` treats it as an escape marker.
    static func isQcharByte(_ byte: UInt8) -> Bool {
        switch byte {
        // ALPHA
        case 0x41...0x5A, 0x61...0x7A:
            return true
        // DIGIT
        case 0x30...0x39:
            return true
        // unreserved extras: "-" "." "_" "~"
        case 0x2D, 0x2E, 0x5F, 0x7E:
            return true
        // allowed-delims: "!" "$" "'" "(" ")" "*" "+" "," ";"
        case 0x21, 0x24, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x3B:
            return true
        // ":" "@"
        case 0x3A, 0x40:
            return true
        default:
            return false
        }
    }

    /// Whether `byte` may appear (raw) in a parameter value token: a `qchar` byte or `%`.
    /// This is the charset accepted by the reference `qchars` parser
    /// (`alphanum_or("-._~!$'()*+,;:@%")`), used by the URI tokenizer to bound a value.
    static func isValueByte(_ byte: UInt8) -> Bool {
        byte == 0x25 /* % */ || isQcharByte(byte)
    }

    private static let hexDigits = Array("0123456789ABCDEF".utf8)

    /// Percent-encodes `string` per the ZIP-321 `qchar` grammar. Always succeeds.
    static func encode(_ string: String) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(string.utf8.count)

        for byte in string.utf8 {
            if isQcharByte(byte) {
                out.append(byte)
            } else {
                out.append(0x25) // "%"
                out.append(hexDigits[Int(byte >> 4)])
                out.append(hexDigits[Int(byte & 0x0F)])
            }
        }

        // Every byte appended above is either a `qchar` byte or one of `%` and `hexDigits`, all
        // of which are ASCII, so this decoding is total: the failable `String(bytes:encoding:)`
        // would add a `nil` branch no input can reach (and that the 100% region-coverage gate
        // could not cover).
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: out, as: UTF8.self)
    }

    /// Strictly percent-decodes a `qchar` value. Returns `nil` if any `%` is not followed by
    /// two hex digits, any raw byte is not a `qchar` byte, or the decoded bytes are not valid
    /// UTF-8. The empty string decodes to the empty string.
    static func decode(_ string: String) -> String? {
        let bytes = Array(string.utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)

        var i = 0
        while i < bytes.count {
            let byte = bytes[i]
            if byte == 0x25 { // "%"
                guard i + 3 <= bytes.count,
                    let high = hexValue(bytes[i + 1]),
                    let low = hexValue(bytes[i + 2])
                else {
                    return nil
                }
                out.append(high << 4 | low)
                i += 3
            } else {
                guard isQcharByte(byte) else { return nil }
                out.append(byte)
                i += 1
            }
        }

        // The decoded bytes must form a valid UTF-8 string (this rejects overlong sequences,
        // lone continuation bytes, unpaired surrogates, and truncated multi-byte sequences).
        return String(bytes: out, encoding: .utf8)
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39: return byte - 0x30           // 0-9
        case 0x41...0x46: return byte - 0x41 + 10      // A-F
        case 0x61...0x66: return byte - 0x61 + 10      // a-f
        default: return nil
        }
    }
}
