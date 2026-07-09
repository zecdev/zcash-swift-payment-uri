//
//  Parser.swift
//
//
//  Created by Pacu on 2023-13-08.
//

import Foundation

/// Represent an checked-param
enum Param: Equatable {
    case address(RecipientAddress)
    case amount(NonNegativeAmount)
    case memo(MemoBytes)
    case label(QcharString)
    case message(QcharString)
    case other(OtherParam)

    var name: String {
        switch self {
        case .address:
            return ReservedParamName.address.rawValue
        case .amount:
            return ReservedParamName.amount.rawValue
        case .memo:
            return ReservedParamName.memo.rawValue
        case .label:
            return ReservedParamName.label.rawValue
        case .message:
            return ReservedParamName.message.rawValue
        case .other(let param):
            return param.name
        }
    }
}

/// A  `paramname` encoded string according to [ZIP-321](https://zips.z.cash/zip-0321)
///
/// ZIP-321 defines:
/// ```
///  paramname       = ALPHA *( ALPHA / DIGIT / "+" / "-" )
/// ```
/// - Note: internal in v2; the public surface uses plain `String` for parameter names.
struct ParamNameString: Equatable {
    let value: String

    /// Initializes a `paramname` encoded string according to [ZIP-321](https://zips.z.cash/zip-0321)
    /// - Returns: a ``ParamNameString`` or ``nil`` if the provided string does not belong to the
    /// `paramname` charset
    init?(value: String) {
        // String can't be empty
        guard !value.isEmpty else { return nil }
        // String can't start with a digit, "+" or "-"
        guard let first = value.first, first.isLetter else { return nil }
        // The whole String conforms to the character set defined in ZIP-321
        guard value.conformsToCharacterSet(.paramname) else { return nil }

        self.value = value
    }
}

/// A type-safe qchar-encoded String
/// - Note: internal in v2; the public surface uses plain (decoded) `String` for label/message.
struct QcharString: Equatable {
    private let storage: String

    /// initalizes a ``QcharString`` from a non-qchar encoded value.
    /// This initilalizers will check whether decoding a this string produces any changes to avoid nested encodings
    /// - Parameter value: the string value that will be qchar-encoded. The empty string is a
    /// valid (zero-length) `*qchar` value and is accepted.
    /// - Parameter strictMode: this checks whether decoding the provided value changes it and fails if it
    /// can be assumed that the value provided is already qchar-encoded to avoid re-encoding an already
    /// qchar-encoded value
    /// - Returns: a ``QcharString`` or ``nil`` if encoding fails
    init?(value: String, strictMode: Bool = false) {
        /// check whether value is already qchar-encoded
        if strictMode {
            guard let qcharDecode = value.qcharDecode(), value == qcharDecode else { return nil }
        }

        // `QcharCodec.encode` always succeeds (it percent-encodes every byte
        // outside the raw `qchar` set), so this is never `nil`.
        self.storage = QcharCodec.encode(value)
    }

    /// the qchar-decoded value of this qchar String
    var value: String {
        // decoding cannot fail: `storage` is always the output of `QcharCodec.encode`.
        // COVERAGE-EXEMPT: unreachable — construction-validated storage always qchar-decodes.
        storage.qcharDecode() ?? storage
    }

    var qcharValue: String {
        storage
    }
}

/// Represents a parameter that has an index.
/// - important: The index value zero means that the parameter will have no index when represented in text form
struct IndexedParameter: Equatable {
    let index: UInt
    let param: Param
}

enum Parser {
    // MARK: - ASCII terminals

    private static let questionMark: UInt8 = 0x3F  // "?"
    private static let ampersand: UInt8 = 0x26  // "&"
    private static let equals: UInt8 = 0x3D  // "="
    private static let dot: UInt8 = 0x2E  // "."
    private static let zeroDigit: UInt8 = 0x30  // "0"
    private static let schemeLiteral = Array("zcash:".utf8)

    /// ASCII letter (`ALPHA`).
    private static func isAlpha(_ byte: UInt8) -> Bool {
        (0x41 ... 0x5A).contains(byte) || (0x61 ... 0x7A).contains(byte)
    }

    /// ASCII digit (`DIGIT`).
    private static func isDigit(_ byte: UInt8) -> Bool {
        (0x30 ... 0x39).contains(byte)
    }

    /// A `paramname` continuation byte: `ALPHA / DIGIT / "+" / "-"`. This matches the reference
    /// `namechars` (`alphanum_or("+-")`), which — like `nom`'s `AsChar` — is ASCII-only.
    private static func isNameChar(_ byte: UInt8) -> Bool {
        isAlpha(byte) || isDigit(byte) || byte == 0x2B /* + */ || byte == 0x2D /* - */
    }

    // MARK: - Leading address

    /// Splits a `zcash:` URI into its lead address and the remaining query part.
    ///
    /// Mirrors the reference `preceded(tag("zcash:"), take_till(|c| c == '?'))`: the lead address
    /// is every character after `zcash:` up to (but not including) the first `?`. The returned
    /// `address` is a (possibly empty) `Substring`; `rest` is the remainder starting at `?`, or
    /// `nil` when there is no `?` in the input.
    /// - Precondition: `input` starts with `zcash:`.
    static func splitLeadingAddress(_ input: String) -> (address: Substring, rest: Substring?) {
        let afterScheme = Substring(input).dropFirst(schemeLiteral.count)

        if let questionMarkIndex = afterScheme.firstIndex(of: "?") {
            return (afterScheme[..<questionMarkIndex], afterScheme[questionMarkIndex...])
        }

        return (afterScheme, nil)
    }

    /// Attempts to parse the leading address and returns the rest of the input.
    ///
    /// A non-empty lead address MUST validate as a recipient address (payment index 0); an empty
    /// lead address is allowed (the request's payments come entirely from query parameters, or the
    /// request is a bare `zcash:`).
    ///
    /// - parameter input: the input String of the URI
    /// - parameter network: the consensus network the request is being parsed for.
    /// - parameter validator: the caller-supplied authority on recipient addresses.
    /// - returns a tuple containing the rest of the input (the `?`-prefixed query part, or `nil`)
    /// and the optional leading `RecipientAddress` (always at payment index 0).
    static func leadingAddress(
        _ input: String,
        network: Network,
        validator: any AddressValidator
    ) throws -> (rest: Substring?, leadingAddress: RecipientAddress?) {
        guard input.hasPrefix("zcash:") else {
            throw ZIP321.Errors.parseError("Not `zcash:` uri")
        }

        let (address, rest) = splitLeadingAddress(input)

        guard !address.isEmpty else {
            return (rest, nil)
        }

        guard let recipient = Parser.recipient(String(address), network: network, validator: validator) else {
            throw ZIP321.Errors.invalidAddress(nil)
        }

        return (rest, recipient)
    }

    // MARK: - Query parameter grammar

    /// Scans a `paramname` (`ALPHA *( ALPHA / DIGIT / "+" / "-" )`) from the current position.
    /// Returns `nil` (consuming nothing) if the first byte is not an `ALPHA`.
    private static func scanName(_ scanner: inout Scanner) -> String? {
        guard let first = scanner.peek(), isAlpha(first) else { return nil }

        scanner.advance()
        var bytes: [UInt8] = [first]
        bytes.append(contentsOf: scanner.takeWhile(isNameChar))

        // `bytes` is an `ALPHA` followed by `isNameChar` bytes, all ASCII, so this decoding is
        // total; the failable `String(bytes:encoding:)` would add an unreachable `nil` branch.
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Scans a `paramindex` digit run (no leading `.`): `NONZERO 0*3DIGIT`, i.e. 1 to 4 digits
    /// with no leading zero. Throws ``ZIP321/Errors/invalidParamIndex(_:)`` on an empty run, a
    /// leading zero, or more than four digits.
    private static func scanIndexDigits(_ scanner: inout Scanner) throws -> UInt {
        let digits = scanner.takeWhile(isDigit)
        // `digits` holds only `isDigit` bytes, all ASCII, so this decoding is total; the failable
        // `String(bytes:encoding:)` would add an unreachable `nil` branch.
        // swiftlint:disable:next optional_data_string_conversion
        let text = String(decoding: digits, as: UTF8.self)

        guard !digits.isEmpty, digits.count <= 4, digits[0] != zeroDigit, let value = UInt(text) else {
            throw ZIP321.Errors.invalidParamIndex(text)
        }

        return value
    }

    /// Scans an optional `"." paramindex`. Returns `nil` (consuming nothing) when the next byte is
    /// not `.`; throws when a `.` is present but not followed by a valid index.
    private static func scanIndex(_ scanner: inout Scanner) throws -> UInt? {
        guard scanner.peek() == dot else { return nil }
        scanner.advance()
        return try scanIndexDigits(&scanner)
    }

    /// Parses a single `&`-delimited query segment into its `(name, index, value)` components.
    ///
    /// Grammar (per ZIP-321, with v1's preserved leniency that the `"=" value` is optional):
    /// ```
    /// name  = ALPHA *( ALPHA / DIGIT / "+" / "-" )
    /// index = [ "." NONZERO 0*3DIGIT ]
    /// value = [ "=" *qchar ]
    /// ```
    /// The raw value is charset-restricted to `qchar`-permitted bytes/percent-escapes here; its
    /// interpretation (percent-decoding vs. sub-grammar parsing) happens later in ``Param/from``.
    /// Throws ``ZIP321/Errors/parseError(_:)`` if the name is missing/invalid (e.g. empty, or
    /// containing a percent-escape) or if any byte in the segment is left unconsumed.
    // The `(name, index, value)` triple is exactly the ZIP-321 `otherparam` production this
    // scans; splitting it into a named type would add a model shape the grammar does not have.
    // swiftlint:disable:next large_tuple
    static func parseQueryToken(_ token: Substring) throws -> (name: String, index: UInt?, value: String?) {
        var scanner = Scanner(token)

        guard let name = scanName(&scanner) else {
            throw ZIP321.Errors.parseError("invalid or empty parameter name in query segment '\(token)'")
        }

        let index = try scanIndex(&scanner)

        var value: String?
        if scanner.expect(ascii: equals) {
            let valueBytes = scanner.takeWhile(QcharCodec.isValueByte)
            // `valueBytes` holds only `QcharCodec.isValueByte` bytes, all ASCII, so this decoding
            // is total; the failable `String(bytes:encoding:)` would add an unreachable branch.
            // swiftlint:disable:next optional_data_string_conversion
            value = String(decoding: valueBytes, as: UTF8.self)
        }

        guard scanner.isAtEnd else {
            throw ZIP321.Errors.parseError("unexpected characters in query segment '\(token)'")
        }

        return (name, index, value)
    }

    /// Test-facing helper: parses a standalone `paramindex` digit run, requiring full consumption.
    static func parseParamIndex(_ input: Substring) throws -> UInt {
        var scanner = Scanner(input)
        let value = try scanIndexDigits(&scanner)
        guard scanner.isAtEnd else {
            throw ZIP321.Errors.invalidParamIndex(String(input))
        }
        return value
    }

    /// Test-facing helper: parses a `paramname` with optional `.paramindex`, requiring full
    /// consumption.
    static func parseNameAndIndex(_ input: Substring) throws -> (name: String, index: UInt?) {
        var scanner = Scanner(input)

        guard let name = scanName(&scanner) else {
            throw ZIP321.Errors.parseError("invalid parameter name '\(input)'")
        }

        let index = try scanIndex(&scanner)

        guard scanner.isAtEnd else {
            throw ZIP321.Errors.parseError("unexpected characters in parameter name '\(input)'")
        }

        return (name, index)
    }

    /// Validates a parsed `(name, index, value)` triple and maps it into an `IndexedParameter`.
    ///
    /// Address validation semantics: every recipient address is resolved by the
    /// caller-supplied `validator`, which is AUTHORITATIVE — this library performs
    /// no address validation of its own.
    static func zcashParameter(
        name: String,
        index: UInt?,
        value: String?,
        network: Network,
        validator: any AddressValidator
    ) throws -> IndexedParameter {
        guard !name.hasPrefix("req-") else {
            throw ZIP321.Errors.unknownRequiredParameter(name)
        }

        // zero is not a valid explicit index; the grammar (no leading zero) already prevents it,
        // and `index == nil` maps to the "no index" sentinel 0.
        let resolvedIndex = index ?? 0

        let param = try Param.from(
            queryKey: name,
            value: value,
            index: resolvedIndex,
            network: network,
            validator: validator
        )

        return IndexedParameter(index: resolvedIndex, param: param)
    }

    /// Parses the query parameters and checks that they are individually valid.
    /// - parameter substring: a substring beginning with the `?` query separator
    /// - parameter leadingAddress: an optional indexed parameter with the previously parsed
    /// leading address if any
    /// - parameter network: the consensus network the request is being parsed for
    /// - parameter validator: the caller-supplied authority on recipient addresses
    static func parseParameters(
        _ substring: Substring,
        leadingAddress: IndexedParameter?,
        network: Network,
        validator: any AddressValidator
    ) throws -> [IndexedParameter] {
        var indexedParameters: [IndexedParameter] = []

        if let leadingAddress = leadingAddress {
            indexedParameters.append(leadingAddress)
        }

        guard substring.first == "?" else {
            throw ZIP321.Errors.parseError("expected '?' to start query parameters")
        }

        let afterQuestionMark = substring.dropFirst()

        // A completely empty query (`zcash:?` or `zcash:<addr>?`) contributes no
        // parameters — it is NOT an empty-named parameter. The reference treats
        // `zcash:?` as a valid empty request.
        guard !afterQuestionMark.isEmpty else {
            return indexedParameters
        }

        let tokens = afterQuestionMark.split(separator: "&", omittingEmptySubsequences: false)

        for token in tokens {
            let (name, index, value) = try parseQueryToken(token)
            indexedParameters.append(
                try zcashParameter(
                    name: name,
                    index: index,
                    value: value,
                    network: network,
                    validator: validator
                )
            )
        }

        return indexedParameters
    }

    /// Groups a flat list of `IndexedParameter` values by `paramindex`, checking each group for
    /// duplicate parameters, and maps each group to a validated ``Payment`` **retaining its
    /// paramindex**.
    /// - parameter indexedParameters: `IndexedParameter` sequence (must be non-empty)
    /// - returns a `[(index, payment)]` ordered by ascending index, or throws if errors are found.
    static func mapToIndexedPayments(_ indexedParameters: [IndexedParameter]) throws -> [(index: UInt, payment: Payment)] {
        guard !indexedParameters.isEmpty else {
            throw ZIP321.Errors.recipientMissing(nil)
        }

        var paramsByIndex: [UInt: [Param]] = [:]

        for idxParam in indexedParameters {
            if var paramVecByIndex = paramsByIndex[idxParam.index] {
                if paramVecByIndex.hasDuplicateParam(idxParam.param) {
                    throw ZIP321.Errors.duplicateParameter(idxParam.param.name, idxParam.index == 0 ? nil : idxParam.index)
                } else {
                    paramVecByIndex.append(idxParam.param)
                    paramsByIndex[idxParam.index] = paramVecByIndex
                }
            } else {
                paramsByIndex[idxParam.index] = [idxParam.param]
            }
        }

        var payments: [(index: UInt, payment: Payment)] = []

        // Sorting the elements (rather than the keys, then subscripting back) carries each
        // parameter list along with its index, so no lookup — and no unwrap — is needed.
        for (index, params) in paramsByIndex.sorted(by: { $0.key < $1.key }) {
            payments.append(
                (index: index, payment: try Payment.uniqueIndexedParameters(index: index, parameters: params))
            )
        }

        return payments
    }

    /// Maps a list of `IndexedParameter` structs to `Payment` structs, discarding paramindices.
    /// - Note: retained for internal/test use; prefer ``mapToIndexedPayments(_:)`` which preserves
    /// the ZIP-321 paramindices.
    static func mapToPayments(_ indexedParameters: [IndexedParameter]) throws -> [Payment] {
        try mapToIndexedPayments(indexedParameters).map(\.payment)
    }
}

extension Payment {
    /// creates a Payment from parameters that are proven to be unique and non-duplicate
    // The branching here is inherent to the per-parameter dispatch this function performs: one
    // arm per ZIP-321 `paramname`, plus the index-tagging of each structural failure.
    // swiftlint:disable:next cyclomatic_complexity
    static func uniqueIndexedParameters(
        index: UInt,
        parameters: [Param]
    ) throws -> Payment {
        guard
            let address = parameters.lazy.compactMap({ param -> RecipientAddress? in
                guard case let .address(recipient) = param else { return nil }
                return recipient
            }).first
        else {
            throw ZIP321.Errors.recipientMissing(index == 0 ? nil : index)
        }

        var amount: NonNegativeAmount?
        var memo: MemoBytes?
        var label: String?
        var message: String?
        var other: [OtherParam] = []

        for param in parameters {
            switch param {
            case .address:
                continue

            case let .amount(decimalAmount):
                amount = decimalAmount

            case let .memo(memoBytes):
                memo = memoBytes

            case let .label(lbl):
                label = lbl.value

            case let .message(msg):
                message = msg.value

            case let .other(param):
                other.append(param)
            }
        }

        // `Payment.create` enforces the structural rules (memo-to-transparent,
        // zero-valued transparent output) index-agnostically; tag the concrete
        // paramindex onto any resulting error.
        switch Payment.create(
            recipientAddress: address,
            amount: amount,
            memo: memo,
            label: label,
            message: message,
            otherParams: other
        ) {
        case .success(let payment):
            return payment
        case .failure(let error):
            throw error.withIndex(index == 0 ? nil : index)
        }
    }
}

extension Param {
    /// Creates a `Param` enum from
    /// - parameter queryKey: `paramname` from ZIP-321
    /// - parameter value: the value fo the query key
    /// - parameter validator: the caller-supplied authority on recipient
    /// addresses; it is the ONLY source of address validity here
    ///
    /// Percent-decoding policy (matching the reference `to_indexed_param`): `label`, `message`
    /// and `other` values are percent-decoded via ``QcharCodec``; `address`, `amount` and `memo`
    /// values are handed to their own grammars verbatim (a `%` in them is therefore rejected).
    static func from(
        queryKey: String,
        value: String?,
        index: UInt,
        network: Network,
        validator: any AddressValidator
    ) throws -> Param {
        if let paramName = ReservedParamName(rawValue: queryKey), let value = value {
            switch paramName {
            case .address:
                guard let addr = Parser.recipient(value, network: network, validator: validator) else {
                    throw ZIP321.Errors.invalidAddress(index > 0 ? index : nil)
                }

                return .address(addr)
            case .amount:
                // Strict ZIP-321 `amountparam` grammar via `NonNegativeAmount`.
                return .amount(try AmountParser.parse(value, index: index))
            case .label:
                let qcharDecoded = try tryDecodeQcharValue(value)

                return .label(qcharDecoded)
            case .memo:
                do {
                    return .memo(try MemoBytes(base64URL: value))
                } catch {
                    let memoError = try error.mapToErrorOrRethrow(MemoBytes.MemoError.self)

                    throw ZIP321.Errors.mapFrom(memoError, index: index)
                }
            case .message:
                let qcharDecoded = try tryDecodeQcharValue(value)

                return .message(qcharDecoded)
            }
        } else {
            // Note: a `req-`-prefixed key is already rejected by the only
            // caller, `zcashParameter`, before `Param.from` is ever reached.

            // `otherparam` values are percent-decoded per the `qchar` grammar (matching the
            // reference), then preserved. An absent value (no `=`) is carried through as `nil`.
            let decodedValue: String?
            if let value = value {
                guard let decoded = QcharCodec.decode(value) else {
                    throw ZIP321.Errors.qcharDecodeFailed(value)
                }
                decodedValue = decoded
            } else {
                decodedValue = nil
            }

            return .other(try OtherParam(name: queryKey, value: decodedValue))
        }
    }

    static func tryDecodeQcharValue(_ value: String) throws -> QcharString {
        guard let qcharDecodedValue = value.qcharDecode(),
            let qcharString = QcharString(
                value: qcharDecodedValue
            )
        else {
            throw ZIP321.Errors
                .qcharDecodeFailed(
                    value
                )
        }

        return qcharString
    }
}

// MARK: - Recipient resolution

extension Parser {
    /// Resolves a raw address string into a ``RecipientAddress`` using the
    /// caller-supplied ``AddressValidator``.
    ///
    /// The validator is AUTHORITATIVE: this library performs no address
    /// validation of its own, so a `nil` return here means the caller rejected
    /// the address and the request is invalid.
    ///
    /// The one rule the library applies on top of the validator's verdict is a
    /// comparison, not a validation: the accepted address must belong to the
    /// network the request is being parsed FOR. A request is parsed against one
    /// expected network, so a recipient the validator places on another network
    /// makes the request invalid — reported as `invalidAddress`, since from the
    /// caller's point of view that address cannot be paid in this context.
    /// ZIP-321 itself is network-agnostic (the librustzcash reference parses
    /// addresses without a network), so this enforcement is a consumer-library
    /// requirement, deliberately made explicit through `expecting:`.
    /// - parameter value: the raw address string as it appeared in the URI.
    /// - parameter network: the network the request is being parsed for.
    /// - parameter validator: the caller-supplied authority on addresses.
    static func recipient(_ value: String, network: Network, validator: any AddressValidator) -> RecipientAddress? {
        guard let descriptor = validator.validate(value) else { return nil }

        guard descriptor.network == network else { return nil }

        return RecipientAddress(value: value, descriptor: descriptor)
    }
}

extension Array where Element == Param {
    func hasDuplicateParam(_ param: Param) -> Bool {
        for i in self {
            switch (i, param) {
            case (.address, .address): return true
            case (.amount, .amount): return true
            case (.memo, .memo): return true
            case (.label, .label): return true
            case (.message, .message): return true
            case let (.other(lhs), .other(rhs)):
                if lhs.name == rhs.name {
                    return true
                }
            default: continue
            }
        }

        return false
    }
}
