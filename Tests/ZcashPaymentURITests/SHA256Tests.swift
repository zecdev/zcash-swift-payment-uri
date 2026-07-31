//
//  SHA256Tests.swift
//  zcash-swift-payment-uri
//
//  Sanity vectors for the CryptoKit-backed SHA-256 wrapper.
//
//  The compression function itself is Apple's and is tested by Apple; these
//  known-answer vectors only pin down the wrapper's own contract — that bytes
//  go in and a 32-byte big-endian digest comes out, and that `doubleHash`
//  really is SHA-256d.
//

import Testing
import Foundation

@Suite("SHA256")
struct SHA256Tests {
    /// Renders a byte array as a lowercase hex string for comparison.
    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func bytes(_ string: String) -> [UInt8] {
        Array(string.utf8)
    }

    @Test func emptyString() {
        // NIST: SHA-256("") known answer.
        #expect(hex(SHA256.hash([])) ==
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test func abc() {
        // FIPS 180-4 Appendix B.1 (one-block message).
        #expect(hex(SHA256.hash(bytes("abc"))) ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func twoBlock() {
        // FIPS 180-4 Appendix B.2 (multi-block, 56 bytes -> forces a second block).
        let msg = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(hex(SHA256.hash(bytes(msg))) ==
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test func doubleHashHello() {
        // SHA-256d("hello") sanity vector.
        #expect(hex(SHA256.doubleHash(bytes("hello"))) ==
            "9595c9df90075148eb06860365df33584b75bff782a510c6cd4883a419833d50")
    }
}
