//
//  ScannerTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu on 2026-07-08.
//

import Testing
@testable import ZcashPaymentURI

@Suite("Scanner")
struct ScannerTests {
    private static let questionMark: UInt8 = 0x3F
    private static let equals: UInt8 = 0x3D
    private static let ampersand: UInt8 = 0x26

    private static func isDigit(_ byte: UInt8) -> Bool { (0x30...0x39).contains(byte) }
    private static func isAlpha(_ byte: UInt8) -> Bool {
        (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
    }

    @Test func emptyInputIsAtEnd() {
        var scanner = Scanner("")
        #expect(scanner.isAtEnd)
        #expect(scanner.peek() == nil)
        let consumed = scanner.advance()
        #expect(consumed == nil)
        #expect(scanner.currentOffset == 0)
    }

    @Test func peekDoesNotConsume() {
        let scanner = Scanner("ab")
        #expect(scanner.peek() == 0x61) // 'a'
        #expect(scanner.peek() == 0x61)
        #expect(scanner.currentOffset == 0)
    }

    @Test func advanceConsumesOneByte() {
        var scanner = Scanner("ab")
        let first = scanner.advance()
        #expect(first == 0x61) // 'a'
        #expect(scanner.currentOffset == 1)
        let second = scanner.advance()
        #expect(second == 0x62) // 'b'
        #expect(scanner.isAtEnd)
        let third = scanner.advance()
        #expect(third == nil)
    }

    @Test func expectConsumesOnMatchOnly() {
        var scanner = Scanner("=x")
        let wrong = scanner.expect(ascii: Self.ampersand)
        #expect(wrong == false)
        #expect(scanner.currentOffset == 0)
        let right = scanner.expect(ascii: Self.equals)
        #expect(right == true)
        #expect(scanner.currentOffset == 1)
    }

    @Test func takeWhileConsumesMaximalRun() {
        var scanner = Scanner("123abc")
        let digits = scanner.takeWhile(Self.isDigit)
        #expect(digits == Array("123".utf8))
        #expect(scanner.currentOffset == 3)
        // No leading match → empty, offset unchanged.
        let more = scanner.takeWhile(Self.isDigit)
        #expect(more.isEmpty)
        #expect(scanner.currentOffset == 3)
        let letters = scanner.takeWhile(Self.isAlpha)
        #expect(letters == Array("abc".utf8))
        #expect(scanner.isAtEnd)
    }

    @Test func matchLiteralConsumesOnlyOnFullMatch() {
        var scanner = Scanner("zcash:foo")
        let matched = scanner.matchLiteral(Array("zcash:".utf8))
        #expect(matched)
        #expect(scanner.currentOffset == 6)

        var noMatch = Scanner("zcas")
        // literal longer than remaining input → no consume
        let tooShort = noMatch.matchLiteral(Array("zcash:".utf8))
        #expect(tooShort == false)
        #expect(noMatch.currentOffset == 0)

        var partial = Scanner("zXcash")
        let mismatch = partial.matchLiteral(Array("zcash:".utf8))
        #expect(mismatch == false)
        #expect(partial.currentOffset == 0)
    }

    @Test func scansMultibyteUTF8ByBytes() {
        // "é" is two UTF-8 bytes C3 A9.
        var scanner = Scanner("é")
        let b0 = scanner.advance()
        let b1 = scanner.advance()
        #expect(b0 == 0xC3)
        #expect(b1 == 0xA9)
        #expect(scanner.isAtEnd)
    }

    @Test func splitOnDelimiterViaTakeWhile() {
        var scanner = Scanner("name=value")
        let name = scanner.takeWhile { $0 != Self.equals }
        #expect(name == Array("name".utf8))
        let separator = scanner.expect(ascii: Self.equals)
        #expect(separator)
        let rest = scanner.takeWhile { _ in true }
        #expect(rest == Array("value".utf8))
        #expect(scanner.isAtEnd)
    }
}
