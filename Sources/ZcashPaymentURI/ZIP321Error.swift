//
//  ZIP321Error.swift
//  zcash-swift-payment-uri
//
//  The public, sealed v2 error taxonomy for ZIP-321 parsing. It mirrors the
//  cross-language conformance-corpus error discriminants (see
//  `Tests/Vectors/schema/vector-schema.md`) rather than the internal v1
//  `ZIP321.Errors` grab-bag.
//
//  DATA-LEAKAGE POLICY (enforced by construction): error payloads carry ONLY
//  parameter names, indices, counts, or fixed ``StaticReason`` values — never
//  addresses, memo contents, amounts, or raw URI slices. The single bounded
//  exception is ``invalidParamIndex``'s raw token, which the grammar caps at a
//  handful of characters (`≤ 5` digits) by construction. `reason` payloads are
//  a closed ``StaticReason`` enum precisely so that raw input can never be
//  smuggled into an error value.
//

/// A fixed, input-independent reason for a top-level URI or structural parse
/// failure. Every case is a constant discriminant: no case carries a `String`
/// or any other channel through which raw user input could leak.
public enum StaticReason: Equatable, Sendable {
    /// The input was the empty string.
    case emptyInput
    /// The input exceeded the configured maximum byte length.
    case inputTooLarge
    /// The input did not begin with the `zcash:` scheme.
    case notZcashScheme
    /// The input included a `//` authority component, which ZIP-321 forbids.
    case invalidAuthority
    /// The URI was structurally malformed (a catch-all for grammar failures
    /// not covered by a more specific case).
    case malformedURI
    /// A query parameter's name or value violated the ZIP-321 grammar.
    case invalidParameter
}

/// Things that can go wrong when parsing a [ZIP-321](https://zips.z.cash/zip-0321)
/// payment request URI. The cases correspond one-to-one to the shared
/// cross-language error discriminants of the conformance corpus.
public enum ZIP321Error: Error, Equatable, Sendable {
    /// A `memo` value was not valid unpadded base64url.
    case invalidBase64(index: UInt?)
    /// A decoded memo exceeded 512 bytes or failed a required UTF-8 check.
    case memoBytesError(index: UInt?)
    /// A `memo` was supplied for a payment whose recipient cannot receive
    /// memos (a transparent address).
    case transparentMemo(index: UInt?)
    /// A zero-valued `amount` was requested for a transparent recipient,
    /// which is disallowed by consensus.
    case zeroValuedTransparentOutput(index: UInt?)
    /// The request specified more payments than the format allows (> 9999).
    case tooManyPayments(count: UInt)
    /// The same parameter name occurred more than once at the same `paramindex`.
    case duplicateParameter(name: String, index: UInt?)
    /// A `paramindex` carried non-address parameters but no matching address.
    case recipientMissing(index: UInt?)
    /// An address string was not a valid encoding of a supported address type
    /// (bad checksum, mixed-case bech32, wrong network, Sprout, …).
    case invalidAddress(index: UInt?)
    /// A `req-`-prefixed parameter the parser does not recognize was present.
    case unknownRequiredParameter(name: String)
    /// A `paramindex` was malformed (leading zero, or out of range). The raw
    /// token is bounded to a handful of characters by the grammar.
    case invalidParamIndex(raw: String)
    /// An `amount` parsed to a numeric value that exceeds `MAX_MONEY`.
    case amountExceededSupply(index: UInt?)
    /// An `amount` value was malformed or otherwise not a legal amount
    /// (negative, missing whole/fractional part, arithmetic overflow).
    case amountInvalid(index: UInt?)
    /// The URI violated the top-level ZIP-321 grammar itself.
    case invalidURI(reason: StaticReason)
    /// A structural parse failure not covered by a more specific case.
    case parseError(reason: StaticReason)
}

extension ZIP321Error {
    /// Returns a copy of this error with `index` set on the index-bearing
    /// cases. Non-index cases are returned unchanged. Used by the parser to
    /// tag payment-construction errors (which are produced index-agnostically
    /// by ``Payment/create(recipientAddress:amount:memo:label:message:otherParams:)``)
    /// with the concrete payment index once it is known.
    func withIndex(_ index: UInt?) -> ZIP321Error {
        switch self {
        case .invalidBase64:                 return .invalidBase64(index: index)
        case .memoBytesError:                return .memoBytesError(index: index)
        case .transparentMemo:               return .transparentMemo(index: index)
        case .zeroValuedTransparentOutput:   return .zeroValuedTransparentOutput(index: index)
        case .recipientMissing:              return .recipientMissing(index: index)
        case .invalidAddress:                return .invalidAddress(index: index)
        case .amountExceededSupply:          return .amountExceededSupply(index: index)
        case .amountInvalid:                 return .amountInvalid(index: index)
        case let .duplicateParameter(name, _): return .duplicateParameter(name: name, index: index)
        case .tooManyPayments,
             .unknownRequiredParameter,
             .invalidParamIndex,
             .invalidURI,
             .parseError:
            return self
        }
    }
}

extension ZIP321Error {
    /// Maps the internal v1 ``ZIP321/Errors`` taxonomy onto the public sealed
    /// v2 taxonomy. This is the single exhaustive translation point; the
    /// throwing parse pipeline continues to raise v1 errors internally and
    /// ``ZIP321/parse(_:context:validating:maxInputBytes:)`` funnels them
    /// through here.
    ///
    /// Index convention: the v1 pipeline already uses `nil` for the empty
    /// paramindex; the few v1 cases that carry a raw `UInt` (`0` for the empty
    /// index) are normalized to `nil` here.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(_ legacy: ZIP321.Errors) {
        // Normalizes the sentinel index `0` (the empty paramindex) to `nil`.
        func norm(_ i: UInt) -> UInt? { i == 0 ? nil : i }

        switch legacy {
        case let .amountExceededSupply(i):
            self = .amountExceededSupply(index: norm(i))

        case let .amountTooSmall(i):
            // v1 `amountTooSmall` covers negative / too-many-fractional-digits,
            // both of which are "malformed amount" in the corpus taxonomy.
            self = .amountInvalid(index: norm(i))

        case let .duplicateParameter(name, i):
            self = .duplicateParameter(name: name, index: i)

        case let .invalidAddress(i):
            self = .invalidAddress(index: i)

        case .invalidBase64:
            self = .invalidBase64(index: nil)

        case .invalidURI:
            self = .invalidURI(reason: .malformedURI)

        case let .memoBytesError(_, i):
            self = .memoBytesError(index: i)

        case let .tooManyPayments(count):
            self = .tooManyPayments(count: UInt(count))

        case let .transparentMemoNotAllowed(i):
            self = .transparentMemo(index: i)

        case let .recipientMissing(i):
            self = .recipientMissing(index: i)

        case let .invalidParamIndex(raw):
            self = .invalidParamIndex(raw: raw)

        case let .invalidParamValue(param, i):
            // The only sub-grammar that reports `invalidParamValue` is `amount`
            // (a malformed decimal / percent-escape / overflow); everything else
            // is a structural parse failure.
            if param == ReservedParamName.amount.rawValue {
                self = .amountInvalid(index: i)
            } else {
                self = .parseError(reason: .invalidParameter)
            }

        case .parseError:
            self = .parseError(reason: .malformedURI)

        case .qcharDecodeFailed, .qcharEncodeFailed:
            self = .parseError(reason: .invalidParameter)

        case let .unknownRequiredParameter(name):
            self = .unknownRequiredParameter(name: name)

        case let .sproutRecipientsNotAllowed(i):
            // ZIP-321 forbids Sprout recipients; the corpus folds this into the
            // generic `invalidAddress` discriminant.
            self = .invalidAddress(index: i)

        case let .zeroValuedTransparentOutput(i):
            self = .zeroValuedTransparentOutput(index: i)

        case .otherParamUsesReservedKey, .otherParamEncodingError, .otherParamKeyEmpty:
            // Construction-time `OtherParam` errors; not reachable from the parse
            // path, mapped for totality.
            self = .parseError(reason: .invalidParameter)
        }
    }
}
