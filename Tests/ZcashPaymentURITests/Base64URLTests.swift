//
//  Base64URLTests.swift
//
//
//  Created by Pacu on 2026-07-08.
//

import Testing
@testable import ZcashPaymentURI

@Suite("Base64URL")
struct Base64URLTests {
    // MARK: - RFC 4648 §10 test vectors, adapted to the unpadded §5 encoding.
    static let rfc4648Vectors: [(String, String)] = [
        ("", ""),
        ("f", "Zg"),
        ("fo", "Zm8"),
        ("foo", "Zm9v"),
        ("foob", "Zm9vYg"),
        ("fooba", "Zm9vYmE"),
        ("foobar", "Zm9vYmFy")
    ]

    @Test(arguments: rfc4648Vectors)
    func rfc4648VectorEncodes(_ testCase: (String, String)) {
        let (plain, encoded) = testCase

        #expect(Base64URL.encode(Array(plain.utf8)) == encoded)
    }

    @Test(arguments: rfc4648Vectors)
    func rfc4648VectorDecodes(_ testCase: (String, String)) {
        let (plain, encoded) = testCase

        #expect(Base64URL.decode(encoded) == Array(plain.utf8))
    }

    // MARK: - conformance corpus memo strings (zcash-zip321-test-vectors /
    // librustzcash zip321 lib.rs memo round-trip vectors).
    static let corpusMemoVectors: [(String, String)] = [
        ("This is a simple memo.", "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"),
        ("{ \"key\": \"This is a JSON-structured memo.\" }", "eyAia2V5IjogIlRoaXMgaXMgYSBKU09OLXN0cnVjdHVyZWQgbWVtby4iIH0"),
        ("This is a unicode memo ✨🦄🏆🎉", "VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok")
    ]

    @Test(arguments: corpusMemoVectors)
    func corpusMemoRoundTrips(_ testCase: (String, String)) throws {
        let (utf8Memo, encoded) = testCase
        let bytes = Array(utf8Memo.utf8)

        #expect(Base64URL.encode(bytes) == encoded)
        #expect(Base64URL.decode(encoded) == bytes)
    }

    /// the URL-safe alphabet uses `-` (62) and `_` (63) where classic base64
    /// uses `+` and `/`.
    @Test func urlSafeAlphabetCharacters() {
        #expect(Base64URL.encode([0xFF]) == "_w")
        #expect(Base64URL.encode([0xFB, 0xFF]) == "-_8")
        #expect(Base64URL.decode("_w") == [0xFF])
        #expect(Base64URL.decode("-_8") == [0xFB, 0xFF])
    }

    @Test func fullAlphabetRoundTrip() {
        let allChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        let expected: [UInt8] = [
            0x00, 0x10, 0x83, 0x10, 0x51, 0x87, 0x20, 0x92, 0x8b, 0x30, 0xd3, 0x8f, 0x41, 0x14, 0x93, 0x51,
            0x55, 0x97, 0x61, 0x96, 0x9b, 0x71, 0xd7, 0x9f, 0x82, 0x18, 0xa3, 0x92, 0x59, 0xa7, 0xa2, 0x9a,
            0xab, 0xb2, 0xdb, 0xaf, 0xc3, 0x1c, 0xb3, 0xd3, 0x5d, 0xb7, 0xe3, 0x9e, 0xbb, 0xf3, 0xdf, 0xbf
        ]

        #expect(Base64URL.decode(allChars) == expected)
        #expect(Base64URL.encode(expected) == allChars)
    }

    // MARK: - rejections

    static let rejectedStrings: [(String, String)] = [
        ("Zm9v+g", "classic-base64 '+' is not in the url-safe alphabet"),
        ("Zm9v/g", "classic-base64 '/' is not in the url-safe alphabet"),
        ("Zg==", "'=' padding is forbidden in the unpadded encoding"),
        ("Zm8=", "'=' padding is forbidden in the unpadded encoding"),
        ("AB=", "'=' padding is forbidden even when it fixes length % 4"),
        ("A===", "padding-only completion is forbidden"),
        ("A", "length % 4 == 1 is impossible for any byte sequence"),
        ("Zm9vY", "length % 4 == 1 is impossible for any byte sequence"),
        ("Zg Zg", "whitespace is rejected"),
        (" Zg", "leading whitespace is rejected"),
        ("Zg\n", "trailing newline is rejected"),
        ("Zg\t", "tab is rejected"),
        ("QR", "nonzero trailing bits (non-canonical encoding)"),
        ("Zm9vYh", "nonzero trailing bits (non-canonical encoding)"),
        ("Zm9vYmF!", "'!' is outside the base64url alphabet"),
        ("····", "non-ASCII characters are rejected"),
        ("QTw+Qg", "'<'-containing classic base64 probe: '+' rejected")
    ]

    @Test(arguments: rejectedStrings)
    func decodeRejects(_ testCase: (String, String)) {
        let (input, reason) = testCase

        #expect(Base64URL.decode(input) == nil, "\(reason)")
    }

    /// the empty string is the canonical encoding of zero bytes.
    @Test func emptyStringDecodesToEmptyBytes() {
        #expect(Base64URL.decode("") == [])
        #expect(Base64URL.encode([]) == "")
    }
}
