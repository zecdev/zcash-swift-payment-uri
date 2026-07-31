//
//  MemoBytes.swift
//
//
//  Created by Pacu on 2026-07-08.
//

import Foundation

/// The raw bytes of a ZIP-302 memo attached to a payment, as carried by the ZIP-321 `memo`
/// parameter.
///
/// Any byte sequence of **0 to 512 bytes** is valid: consensus zero-pads memos to 512 bytes,
/// so a zero-length memo is a well-defined (empty) memo — matching the reference
/// implementation, which accepts an empty byte slice. Note the distinction between an
/// *omitted* memo (`Payment.memo == nil`) and an *empty* memo (`memo=` in a URI, 0 bytes).
public struct MemoBytes: Equatable, Sendable {
    /// Reasons a candidate memo could not be represented as `MemoBytes`.
    public enum MemoError: Error {
        /// The memo content is longer than ``MemoBytes/maxLength`` (512) bytes.
        case memoTooLong
        /// The memo content is not a valid UTF-8 string.
        case notUTF8String
        /// The `memo` value is not a canonical unpadded base64url string.
        case invalidBase64URL
    }

    /// The maximum number of bytes a memo may contain (512, per ZIP-302).
    public let maxLength = 512
    let data: Data

    /// Initializes a `MemoBytes` from raw bytes.
    /// - parameter bytes: 0 to 512 bytes of memo content.
    /// - throws: `MemoError.memoTooLong` if more than 512 bytes are provided.
    public init(bytes: [UInt8]) throws {
        guard bytes.count <= maxLength else {
            throw MemoError.memoTooLong
        }

        self.data = Data(bytes)
    }

    /// Initializes a Memo from a UTF8 String.
    /// - Important: use [`MemoBytes.init(base64URL:)`] to initialize a memo from base64URL
    public init(utf8String: String) throws {
        // A native Swift `String` is always valid Unicode text, so its UTF-8 view is total —
        // hence `Data(_:)` over that view rather than the failable, and here unfailable,
        // `String.data(using: .utf8)`. `MemoError.notUTF8String` exists for the
        // `MemoBytes.MemoError` taxonomy's totality (mapped by `ZIP321.Errors.mapFrom`) but this
        // initializer can never produce it.
        let memoStringData = Data(utf8String.utf8)

        guard memoStringData.count <= maxLength else {
            throw MemoError.memoTooLong
        }

        self.data = memoStringData
    }

    /// Initializes a [`MemoBytes`] from an unpadded
    /// [RFC-4648 §5 base64url](https://datatracker.ietf.org/doc/html/rfc4648#section-5)
    /// string, as mandated by ZIP-321 for `memo` parameter values.
    /// - parameter base64URL: an unpadded base64url string.
    /// - throws: [`MemoBytes.MemoError.invalidBase64URL`] if the string is not a canonical
    /// unpadded base64url encoding (`+`, `/`, `=` padding, whitespace, out-of-alphabet
    /// characters, impossible lengths, and nonzero trailing bits are all rejected), or
    /// [`MemoBytes.MemoError.memoTooLong`] if it decodes to more than 512 bytes.
    public init(base64URL: String) throws {
        guard let bytes = Base64URL.decode(base64URL) else {
            throw MemoError.invalidBase64URL
        }

        try self.init(bytes: bytes)
    }

    /// Conversion of the present bytes to an unpadded RFC-4648 §5 base64url string.
    public func toBase64URL() -> String {
        Base64URL.encode([UInt8](self.data))
    }
}

public extension MemoBytes {
    /// The raw bytes of this memo, as `Foundation.Data`.
    var memoData: Data {
        self.data
    }
}
