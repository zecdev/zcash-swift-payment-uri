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

    @Test func initWithStringThrows() {
        #expect(throws: (any Error).self) {
            try MemoBytes(utf8String: "")
        }

        #expect(throws: (any Error).self) {
            try MemoBytes(utf8String: String(repeating: "a", count: 513))
        }
    }

    @Test func initWithBytesThrows() {
        #expect(throws: (any Error).self) {
            try MemoBytes(bytes: [])
        }

        #expect(throws: (any Error).self) {
            try MemoBytes(bytes: [UInt8](repeating: 0xf4, count: 513))
        }
    }

    @Test func initWithInvalidTextFails() throws {
        let invalidCharactersMemo = "QTw+Qg"

        #expect(throws: (any Error).self) {
            try MemoBytes(base64URL: invalidCharactersMemo)
        }
    }
}
