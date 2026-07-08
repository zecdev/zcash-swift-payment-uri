//
//  Scanner.swift
//
//
//  Created by Pacu on 2026-07-08.
//

/// A minimal single-pass byte scanner over the UTF-8 view of a `Substring`, used by the
/// ZIP-321 URI grammar. It supports only forward motion with a single-byte lookahead
/// (`peek`) — there is no backtracking beyond re-inspecting the current byte — mirroring the
/// streaming, non-backtracking style of the reference `nom` parsers in librustzcash `zip321`.
///
/// The scanner works at the byte (ASCII/UTF-8) level: every ZIP-321 grammar terminal
/// (`zcash:`, `?`, `&`, `=`, `.`, `paramname`, `paramindex`, `qchar`) is ASCII, and the only
/// place arbitrary bytes flow through (a recipient address, or a value that will be
/// percent-decoded) is reconstructed by the caller via `String(decoding:as: UTF8.self)`.
struct Scanner {
    private let bytes: [UInt8]
    private(set) var currentOffset: Int = 0

    init(_ substring: Substring) {
        self.bytes = Array(substring.utf8)
    }

    init(_ string: String) {
        self.bytes = Array(string.utf8)
    }

    /// Whether the scanner has consumed all input.
    var isAtEnd: Bool {
        currentOffset >= bytes.count
    }

    /// Returns the byte at the current offset without consuming it, or `nil` at end of input.
    func peek() -> UInt8? {
        currentOffset < bytes.count ? bytes[currentOffset] : nil
    }

    /// Consumes and returns the byte at the current offset, or `nil` at end of input.
    @discardableResult
    mutating func advance() -> UInt8? {
        guard currentOffset < bytes.count else { return nil }
        defer { currentOffset += 1 }
        return bytes[currentOffset]
    }

    /// Consumes the current byte iff it equals `ascii`. Returns whether it was consumed.
    mutating func expect(ascii: UInt8) -> Bool {
        guard peek() == ascii else { return false }
        currentOffset += 1
        return true
    }

    /// Consumes and returns the maximal run of leading bytes satisfying `predicate` (possibly
    /// empty). Always succeeds.
    mutating func takeWhile(_ predicate: (UInt8) -> Bool) -> [UInt8] {
        let start = currentOffset
        while currentOffset < bytes.count, predicate(bytes[currentOffset]) {
            currentOffset += 1
        }
        return Array(bytes[start..<currentOffset])
    }

    /// Consumes `literal` iff the input at the current offset starts with it. Returns whether
    /// it was consumed; on failure the offset is unchanged.
    mutating func matchLiteral(_ literal: [UInt8]) -> Bool {
        guard currentOffset + literal.count <= bytes.count else { return false }
        for (index, byte) in literal.enumerated() where bytes[currentOffset + index] != byte {
            return false
        }
        currentOffset += literal.count
        return true
    }
}
