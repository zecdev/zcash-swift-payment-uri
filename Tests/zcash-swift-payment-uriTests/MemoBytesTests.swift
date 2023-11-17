//
//  MemoBytesTests.swift
//  
//
//  Created by Francisco Gindre on 11/7/23.
//

import XCTest
@testable import zcash_swift_payment_uri
final class MemoBytesTests: XCTestCase {

    func testInitWithString() throws {
        let expectedBase64 = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"
        let memoBytes = try MemoBytes(utf8String: "This is a simple memo.")

        XCTAssertEqual(memoBytes.toBase64URL(), expectedBase64)
    }

    func testInitWithBytes() throws {
        let bytes: [UInt8] = [0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x73, 0x69, 0x6d, 0x70, 0x6c, 0x65, 0x20, 0x6d, 0x65, 0x6d, 0x6f, 0x2e]

        let expectedBase64 = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"

        let memo = try MemoBytes(bytes: bytes)

        XCTAssertEqual(memo.toBase64URL(), expectedBase64)
    }

    func testUnicodeMemo() throws {
        let memoUTF8Text = "This is a unicode memo ✨🦄🏆🎉"
        let expectedBase64 = "VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"
        
        let memo = try MemoBytes(utf8String: memoUTF8Text)

        XCTAssertEqual(memo.toBase64URL(), expectedBase64)

    }
    
    func testInitWithStringThrows() {

        XCTAssertThrowsError(try MemoBytes(utf8String: ""))

        XCTAssertThrowsError(try MemoBytes(utf8String: String(repeating: "a", count: 513)))
    }

    func testInitWithBytesThrows() {
        XCTAssertThrowsError(try MemoBytes(bytes: []))
        
        XCTAssertThrowsError(try MemoBytes(bytes: [UInt8](repeating: 0xf4, count: 513)))
    }
}
