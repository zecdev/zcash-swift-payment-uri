//
//  MemoBytesTests.swift
//
//
//  Created by Francisco Gindre on 2023-11-07
//

import Testing
@testable import ZcashPaymentURI

@Suite("MemoBytes")
struct MemoBytesTests {
    @Test func initWithString() throws {
        let expectedBase64 = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"
        let memoBytes = try MemoBytes(utf8String: "This is a simple memo.")

        #expect(memoBytes.toBase64URL() == expectedBase64)
    }

    @Test func initWithBase64URL() throws {
        let base64 = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"

        let memoBytes = try MemoBytes(base64URL: base64)
        let expectedMemo = try MemoBytes(utf8String: "This is a simple memo.")

        #expect(memoBytes == expectedMemo)
    }

    @Test func initWithBytes() throws {
        let bytes: [UInt8] = [
            0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20,
            0x61, 0x20, 0x73, 0x69, 0x6d, 0x70, 0x6c, 0x65,
            0x20, 0x6d, 0x65, 0x6d, 0x6f, 0x2e
        ]

        let expectedBase64 = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"

        let memo = try MemoBytes(bytes: bytes)

        #expect(memo.toBase64URL() == expectedBase64)
    }

    /// Cross-check using all Base64URL characters and do a round-trip
    @Test func roundTripWithAllBase64URLCharacters() throws {
        let base64URLCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        let e: [UInt8] = [
            0x00, 0x10, 0x83, 0x10, 0x51, 0x87, 0x20, 0x92, 0x8b, 0x30, 0xd3, 0x8f, 0x41, 0x14, 0x93, 0x51,
            0x55, 0x97, 0x61, 0x96, 0x9b, 0x71, 0xd7, 0x9f, 0x82, 0x18, 0xa3, 0x92, 0x59, 0xa7, 0xa2, 0x9a,
            0xab, 0xb2, 0xdb, 0xaf, 0xc3, 0x1c, 0xb3, 0xd3, 0x5d, 0xb7, 0xe3, 0x9e, 0xbb, 0xf3, 0xdf, 0xbf
        ]

        let memo = try MemoBytes(base64URL: base64URLCharacters)
        let memoFromBytes = try MemoBytes(bytes: e)

        #expect(memo == memoFromBytes)
        #expect(memo.toBase64URL() == base64URLCharacters)
    }

    @Test func unicodeMemo() throws {
        let memoUTF8Text = "This is a unicode memo ✨🦄🏆🎉"
        let expectedBase64 = "VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let memo = try MemoBytes(utf8String: memoUTF8Text)

        #expect(memo.toBase64URL() == expectedBase64)
    }

    @Test func utf8StringRoundTrip() throws {
        let memo = try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉")
        let decoded = try MemoBytes(base64URL: memo.toBase64URL())

        #expect(decoded == memo)
        #expect(String(decoding: decoded.memoData, as: UTF8.self) == "This is a unicode memo ✨🦄🏆🎉")
    }

    @Test func rawBytesRoundTrip() throws {
        let bytes: [UInt8] = [0x00, 0xFF, 0x10, 0x80, 0x7F]

        let memo = try MemoBytes(bytes: bytes)
        let decoded = try MemoBytes(base64URL: memo.toBase64URL())

        #expect(decoded == memo)
        #expect([UInt8](decoded.memoData) == bytes)
    }

    // MARK: - length boundaries: 0...512 bytes are valid, 513 is not.

    @Test func emptyMemoIsValidAndRoundTrips() throws {
        // consensus zero-pads memos to 512 bytes, so a zero-length memo is a
        // well-defined empty memo (`memo=` in a ZIP-321 URI).
        let fromBytes = try MemoBytes(bytes: [])
        let fromString = try MemoBytes(utf8String: "")
        let fromBase64 = try MemoBytes(base64URL: "")

        #expect(fromBytes == fromString)
        #expect(fromBytes == fromBase64)
        #expect(fromBytes.toBase64URL() == "")
        #expect(fromBytes.memoData.isEmpty)
    }

    @Test func lengthBoundaries() throws {
        #expect(try MemoBytes(bytes: []).memoData.count == 0)
        #expect(try MemoBytes(bytes: [0x61]).memoData.count == 1)
        #expect(try MemoBytes(bytes: [UInt8](repeating: 0x61, count: 512)).memoData.count == 512)

        #expect(throws: MemoBytes.MemoError.memoTooLong) {
            try MemoBytes(bytes: [UInt8](repeating: 0x61, count: 513))
        }

        #expect(try MemoBytes(utf8String: String(repeating: "a", count: 512)).memoData.count == 512)

        #expect(throws: MemoBytes.MemoError.memoTooLong) {
            try MemoBytes(utf8String: String(repeating: "a", count: 513))
        }

        // 513 bytes of valid base64url decode fine but exceed the memo limit.
        let oversized = Base64URL.encode([UInt8](repeating: 0x61, count: 513))
        #expect(throws: MemoBytes.MemoError.memoTooLong) {
            try MemoBytes(base64URL: oversized)
        }
    }

    // MARK: - base64url rejections (strict unpadded RFC 4648 §5 decoding)

    static let rejectedBase64URLStrings: [(String, String)] = [
        ("QTw+Qg", "'+' belongs to classic base64, not base64url"),
        ("QTw/Qg", "'/' belongs to classic base64, not base64url"),
        ("Zg==", "'=' padding is forbidden"),
        ("AB=", "'=' padding is forbidden"),
        ("A===", "'=' padding is forbidden"),
        ("A", "length % 4 == 1 is impossible"),
        ("Zg Zg", "whitespace is rejected"),
        ("Zg\n", "whitespace is rejected"),
        ("QR", "nonzero trailing bits (non-canonical encoding)"),
        ("····", "non-ASCII characters are rejected")
    ]

    @Test(arguments: rejectedBase64URLStrings)
    func initWithInvalidBase64URLFails(_ testCase: (String, String)) {
        let (input, reason) = testCase

        #expect(throws: MemoBytes.MemoError.invalidBase64URL, "\(reason)") {
            try MemoBytes(base64URL: input)
        }
    }
}
