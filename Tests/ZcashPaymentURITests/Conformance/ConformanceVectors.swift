//
//  ConformanceVectors.swift
//
//  Codable models and loader for the shared ZIP-321 conformance vector corpus
//  consumed as a git submodule at `Tests/Vectors`.
//
//  See `Tests/Vectors/schema/vector-schema.md` for the authoritative field-by-field
//  description of both vector shapes and the shared error discriminants.
//

import Foundation

/// A vector from `vectors/valid/*.json`: a URI that MUST parse, together with
/// the field-level expectations for every payment it contains.
struct ConformanceValidVector: Decodable {
    struct VectorPayment: Decodable {
        /// The ZIP-321 `paramindex` (0 denotes the empty paramindex). Note that
        /// v1's parsed model (`PaymentRequest`) does not retain paramindices, so
        /// the conformance runner compares payments by array position only.
        let index: UInt
        /// Recipient address exactly as it appears in the URI.
        let address: String
        /// LegacyAmount in zatoshis (exact integer), or `nil` if no `amount` param present.
        let amountZat: Int64?
        /// The raw base64url-without-padding memo value from the URI, or `nil`
        /// if no `memo` param is present. `""` means `memo=` (a 0-byte memo).
        let memoBase64: String?
        /// Percent-decoded label value, or `nil` if absent.
        let label: String?
        /// Percent-decoded message value, or `nil` if absent.
        let message: String?
        /// `[name, decodedValue]` pairs for unrecognized non-`req-` params, in order.
        let other: [[String?]]
    }

    let name: String
    let description: String
    let uri: String
    let network: String
    let payments: [VectorPayment]
    /// Reference (librustzcash `TransactionRequest::to_uri()`) rendering of the
    /// parsed request; `nil` only for oracle-skipped vectors.
    let canonicalUri: String?
    let oracleSkip: Bool
    let oracleSkipReason: String?
}

/// A vector from `vectors/invalid/*.json`: a URI that MUST be rejected.
struct ConformanceInvalidVector: Decodable {
    let name: String
    let description: String
    let uri: String
    let network: String
    /// Shared cross-language error discriminant (see schema). The Swift v1 error
    /// taxonomy does not map 1:1 onto these, so the runner only asserts *that*
    /// parsing throws, not *which* error it throws.
    let error: String
    let oracleSkip: Bool
    let oracleSkipReason: String?
}

enum ConformanceCorpus {
    /// Root of the `Tests/Vectors` submodule, located relative to this source
    /// file (`Tests/ZcashPaymentURITests/Conformance/ConformanceVectors.swift`)
    /// via `#filePath`, so no bundle resource wiring is needed.
    static var corpusRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ConformanceVectors.swift -> Conformance/
            .deletingLastPathComponent() // Conformance/ -> ZcashPaymentURITests/
            .deletingLastPathComponent() // ZcashPaymentURITests/ -> Tests/
            .appendingPathComponent("Vectors")
    }

    static func vectorFiles(in subdirectory: String) throws -> [URL] {
        let dir = corpusRoot
            .appendingPathComponent("vectors")
            .appendingPathComponent(subdirectory)
        return try FileManager.default
            .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func validVectors() throws -> [ConformanceValidVector] {
        try vectorFiles(in: "valid").flatMap { url in
            try JSONDecoder().decode([ConformanceValidVector].self, from: Data(contentsOf: url))
        }
    }

    static func invalidVectors() throws -> [ConformanceInvalidVector] {
        try vectorFiles(in: "invalid").flatMap { url in
            try JSONDecoder().decode([ConformanceInvalidVector].self, from: Data(contentsOf: url))
        }
    }
}
