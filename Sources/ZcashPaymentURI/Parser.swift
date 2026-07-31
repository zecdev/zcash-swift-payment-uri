//
//  Parser.swift
//
//
//  Created by Pacu on 2023-13-08.
//

import Foundation

/// Result of the URI parser. This returns a `PaymentRequest` if a compliant
/// [ZIP-321](https://zips.z.cash/zip-0321) request is parsed from
/// a URI String. This implementation accounts of legacy schemes like that preceded
/// the existence of the ZIP like `zcash:{valid_address}`.
/// See [Backward Compatibility](https://zips.z.cash/zip-0321#backward-compatibility) section
/// of the ZIP for more details.
public enum ParserResult: Equatable {
    case legacy(RecipientAddress)
    case request(PaymentRequest)
}

/// Represent an checked-param
public enum Param: Equatable {
    case address(RecipientAddress)
    case amount(LegacyAmount)
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
            return param.key.value
        }
    }
}

/// A  `paramname` encoded string according to [ZIP-321](https://zips.z.cash/zip-0321)
///
/// ZIP-321 defines:
/// ```
///  paramname       = ALPHA *( ALPHA / DIGIT / "+" / "-" )
/// ```
public struct ParamNameString: Equatable {
    public let value: String

    /// Initializes a `paramname` encoded string according to [ZIP-321](https://zips.z.cash/zip-0321)
    /// - Returns: a ``ParamNameString`` or ``nil`` if the provided string does not belong to the
    /// `paramname` charset
    public init?(value: String) {
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
public struct QcharString: Equatable {
    private let storage: String

    /// initalizes a ``QcharString`` from a non-qchar encoded value.
    /// This initilalizers will check whether decoding a this string produces any changes to avoid nested encodings
    /// - Parameter value: the string value that will be qchar-encoded. The empty string is a
    /// valid (zero-length) `*qchar` value and is accepted.
    /// - Parameter strictMode: this checks whether decoding the provided value changes it and fails if it
    /// can be assumed that the value provided is already qchar-encoded to avoid re-encoding an already
    /// qchar-encoded value
    /// - Returns: a ``QcharString`` or ``nil`` if encoding fails
    public init?(value: String, strictMode: Bool = false) {
        /// check whether value is already qchar-encoded
        if strictMode {
            guard let qcharDecode = value.qcharDecode(), value == qcharDecode else { return nil }
        }

        guard let qchar = value.qcharEncoded() else { return nil }
        self.storage = qchar
    }

    /// the qchar-decoded value of this qchar String
    public var value: String {
        // decoding cannot fail: `storage` was qchar-validated at construction.
        storage.qcharDecode() ?? storage
    }

    public var qcharValue: String {
        storage
    }
}

/// Represents a parameter that has an index.
/// - important: The index value zero means that the parameter will have no index when represented in text form
struct IndexedParameter: Equatable {
    let index: UInt
    let param: Param
}

/// A minimal hand-rolled parsing failure used internally by the ZIP-321 URI
/// parser below. Business-logic call sites always catch and re-map failures
/// from the combinators in this file into a specific `ZIP321.Errors` case;
/// callers should never rely on this concrete type leaking out uncaught.
struct ZParseError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

/// A tiny, hand-rolled substring parser combinator. This replaces the small
/// subset of swift-parsing's `Parser` protocol that this file used
/// (literal matching, greedy character-set prefixes, optional/backtracking
/// sub-parsers, and "consume the rest of the input"), while preserving the
/// exact same `.parse(_:)` calling convention every call site (including
/// tests) relies on.
struct ZParser<Output: Sendable>: Sendable {
    let run: @Sendable (inout Substring) throws -> Output

    /// Runs the parser and requires the ENTIRE input to be consumed,
    /// mirroring swift-parsing's `Parser.parse(_:)` convenience.
    /// - throws if the parser fails, or if any input remains unconsumed.
    func parse<S: StringProtocol>(_ input: S) throws -> Output {
        var substring = Substring(input)
        let output = try run(&substring)
        guard substring.isEmpty else {
            throw ZParseError("unconsumed input remains: \(substring)")
        }
        return output
    }
}

/// Parses a literal prefix, consuming it and throwing if the input does not start with it.
private func zLiteral(_ literal: String) -> ZParser<Void> {
    ZParser { input in
        guard input.hasPrefix(literal) else {
            throw ZParseError("expected literal '\(literal)'")
        }
        input.removeFirst(literal.count)
    }
}

/// Tries each literal in order, consuming the first one that matches as a prefix.
private func zOneOfLiterals(_ literals: [String]) -> ZParser<Void> {
    ZParser { input in
        for literal in literals where input.hasPrefix(literal) {
            input.removeFirst(literal.count)
            return
        }
        throw ZParseError("expected one of \(literals)")
    }
}

/// Greedily consumes characters (by `Character`, all of whose unicode scalars must belong to
/// `set`) from the front of the input. Always succeeds, possibly consuming zero characters.
private func zCharacterSet(_ set: CharacterSet) -> ZParser<Substring> {
    ZParser { input in
        let match = input.prefix { character in
            character.unicodeScalars.allSatisfy { set.contains($0) }
        }
        input.removeFirst(match.count)
        return match
    }
}

/// Greedily consumes characters while `predicate` holds. Always succeeds, possibly
/// consuming zero characters.
private func zPrefix(_ predicate: @escaping @Sendable (Character) -> Bool) -> ZParser<Substring> {
    ZParser { input in
        let match = input.prefix(while: predicate)
        input.removeFirst(match.count)
        return match
    }
}

/// Consumes 1 to `max` ASCII digit characters (greedily, up to `max`), interpreting them as
/// an `Int`. Fails if there is no digit at all at the front of the input.
private func zDigits(max: Int) -> ZParser<Int> {
    ZParser { input in
        let digitRun = input.prefix { character in
            character.unicodeScalars.allSatisfy { CharacterSet.ASCIINum.contains($0) }
        }
        let matched = digitRun.prefix(max)
        guard !matched.isEmpty, let value = Int(matched) else {
            throw ZParseError("expected at least one digit")
        }
        input.removeFirst(matched.count)
        return value
    }
}

/// Consumes and returns the entire remaining input. Fails if the input is already empty.
private func zRest() -> ZParser<Substring> {
    ZParser { input in
        guard !input.isEmpty else {
            throw ZParseError("no remaining input")
        }
        defer { input = Substring() }
        return input
    }
}

/// Attempts `parser` on a copy of the input; if it fails, the input is left completely
/// untouched (full backtracking) and `nil` is returned instead of throwing.
private func zOptionally<T>(_ parser: ZParser<T>) -> ZParser<T?> {
    ZParser { input in
        var attempt = input
        guard let value = try? parser.run(&attempt) else {
            return nil
        }
        input = attempt
        return value
    }
}

enum Parser {
    /// Allowed characters for paramName are alphanumerics (Unicode, matching Foundation's
    /// `CharacterSet.alphanumerics`) and `+` and `-`.
    /// - Note: this is intentionally more permissive than `CharacterSet.paramname` (ASCII-only):
    /// a query key containing e.g. non-ASCII letters is accepted at this low-level tokenizing
    /// stage and rejected later by `ParamNameString`/`OtherParam` validation, matching v1 behavior.
    static let parameterNameCharset = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+-"))

    static let parameterName: ZParser<Substring> = zCharacterSet(parameterNameCharset)

    /// parses characters from the `qchar` set.
    static let otherParamValue: ZParser<Substring> = zCharacterSet(.qchar)

    static let maybeLeadingAddress: ZParser<(Substring?, Substring?)> = ZParser { input in
        try zLiteral("zcash:").run(&input)
        let addressPart: Substring? = try zPrefix { $0 != "?" }.run(&input)
        let rest = try zOptionally(zRest()).run(&input)
        return (addressPart, rest)
    }

    /// parameter indexes according to ZIP-321 can't have leading zeroes and should not be more than 9999
    static let parameterIndex: ZParser<Int> = ZParser { input in
        guard
            let first = input.first,
            first.unicodeScalars.allSatisfy({ CharacterSet.nonZeroDigits.contains($0) })
        else {
            throw ZParseError("expected paramindex to start with a nonzero digit")
        }
        return try zDigits(max: 4).run(&input)
    }

    /// parser for a `paramname` that can contain an index or not.
    static let optionallyIndexedParameterName: ZParser<(Substring, Int?)> = ZParser { input in
        let name = try Parser.parameterName.run(&input)
        let index = try zOptionally(
            ZParser<Int> { inner in
                try zLiteral(".").run(&inner)
                return try Parser.parameterIndex.run(&inner)
            }
        ).run(&input)
        return (name, index)
    }

    /// Parser for query key and value
    /// supports `otherParam` and `req-` params without validation logic
    // swiftlint:disable:next large_tuple
    static let queryKeyAndValue: ZParser<(Substring, Int?, Substring?)> = ZParser { input in
        let (name, index) = try Parser.optionallyIndexedParameterName.run(&input)
        let value = try zOptionally(
            ZParser<Substring> { inner in
                try zLiteral("=").run(&inner)
                return try Parser.otherParamValue.run(&inner)
            }
        ).run(&input)
        return (name, index, value)
    }

    /// maps a parsed Query Parameter key and value into an `IndexedParameter`
    /// providing validation of Query keys and values. Recipient addresses are resolved
    /// by the caller-supplied `validator`.
    static func zcashParameter(
        // swiftlint:disable:next large_tuple
        _ input: (Substring, Int?, Substring?),
        network: Network,
        validator: any AddressValidator
    ) throws -> IndexedParameter {
        let queryKey = String(input.0)

        guard input.1 != Int?(0) else {
            throw ZIP321.Errors.invalidParamIndex("\(input).0")
        }

        guard !queryKey.hasPrefix("req-") else {
            throw ZIP321.Errors.unknownRequiredParameter(queryKey)
        }

        let index = UInt(input.1 ?? 0) // zero is not allowed in the spec but we imply no index
        let value = if let value = input.2 {
            String(value)
        } else {
            Optional<String>.none
        }

        let param = try Param.from(
            queryKey: queryKey,
            value: value,
            index: index,
            network: network,
            validator: validator
        )

        return IndexedParameter(index: index, param: param)
    }

    /// Attempts to parse the leading address and returns the rest of the input
    /// - parameter input: the input String of the URI
    /// - parameter validator: the caller-supplied authority on recipient addresses
    /// - returns a tuple containing an optional `IndexedParameter` and the rest of the remaining
    /// subsequence.
    static func leadingAddress(
        _ input: String,
        network: Network,
        validator: any AddressValidator
    ) throws -> (Substring?, IndexedParameter?) {
        guard input.starts(with: "zcash:") else {
            throw ZIP321.Errors.parseError("Not `zcash:` uri")
        }

        let partial = try maybeLeadingAddress.parse(input)

        if let maybeAddress = partial.0, !maybeAddress.isEmpty {
            guard let address = Parser.recipient(String(maybeAddress), network: network, validator: validator) else {
                throw ZIP321.Errors.invalidAddress(nil)
            }

            return (partial.1, IndexedParameter(index: 0, param: .address(address)))
        }

        return (partial.1, nil)
    }

    /// this function parses query parameters and checks that are valid internally.
    /// - parameter substring: a substring with the sequence after `?` separator
    /// - parameter leadingAddress: an optional indexed parameter with the previously parsed
    /// leading address if any
    /// - parameter validator: the caller-supplied authority on recipient addresses
    static func parseParameters(
        _ substring: Substring.SubSequence,
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
        let tokens = afterQuestionMark.split(separator: "&", omittingEmptySubsequences: false)

        indexedParameters.append(
            contentsOf: try tokens
                .map { try Parser.queryKeyAndValue.parse($0) }
                .map { try zcashParameter($0, network: network, validator: validator) }
        )

        return indexedParameters
    }

    /// maps a list of `IndexParameter` structs to `Payment` structs and validates them as individual payments and as payment requests
    /// - parameter indexedParameters: `IndexedParameter` sequence
    /// - returns a `[Payment]` or throws if errors are found.
    static func mapToPayments(_ indexedParameters: [IndexedParameter]) throws -> [Payment] {
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

        var payments: [Payment] = []

        try paramsByIndex.keys.sorted().forEach { index in
            guard let params = paramsByIndex[index] else {
                throw ZIP321.Errors.invalidParamIndex(index.description)
            }

            payments.append(
                try Payment.uniqueIndexedParameters(index: index, parameters: params)
            )
        }

        return payments
    }
}

extension Payment {
    /// creates a Payment from parameters that are proven to be unique and non-duplicate
    // swiftlint:disable:next cyclomatic_complexity
    static func uniqueIndexedParameters(
        index: UInt,
        parameters: [Param]
    ) throws -> Payment {
        guard let addressMaybe = parameters.first(where: { param in
            switch param {
            case .address:
                return true
            default:
                return false
            }
        }) else {
            throw ZIP321.Errors.recipientMissing(index == 0 ? nil : index)
        }

        let address: RecipientAddress = if case let Param.address(recipient) = addressMaybe {
            recipient
        } else {
            throw ZIP321.Errors.recipientMissing(index == 0 ? nil : index)
        }

        var amount: LegacyAmount?
        var memo: MemoBytes?
        var label: QcharString?
        var message: QcharString?
        var other: [OtherParam] = []

        for param in parameters {
            switch param {
            case .address:
                continue

            case let .amount(decimalAmount):
                amount = decimalAmount

            case let .memo(memoBytes):
                if address.isTransparent {
                    throw ZIP321.Errors.transparentMemoNotAllowed(index == 0 ? nil : index)
                }

                memo = memoBytes

            case let .label(lbl):
                label = lbl

            case let .message(msg):
                message = msg

            case let .other(param):
                other.append(param)
            }
        }

        do {
            return try Payment(
                recipientAddress: address,
                amount: amount,
                memo: memo,
                qcharLabel: label,
                qcharMessage: message,
                otherParams: other.isEmpty ? nil : other
            )
        } catch ZIP321.Errors.transparentMemoNotAllowed {
            throw ZIP321.Errors.transparentMemoNotAllowed(index)
        } catch {
            throw error
        }
    }
}

extension Param {
    private static func decodeQchar(_ value: String) throws -> String {
        guard (try? Parser.otherParamValue.parse(value)) != nil else {
            throw ZIP321.Errors.qcharDecodeFailed(value)
        }

        guard let qcharDecoded = value.qcharDecode() else {
            throw ZIP321.Errors.qcharDecodeFailed(value)
        }

        return qcharDecoded
    }

    /// Creates a `Param` enum from
    /// - parameter queryKey: `paramname` from ZIP-321
    /// - parameter value: the value fo the query key
    // Transitional v1 dispatch replaced by the Scanner grammar rewrite (#87);
    // its branching is inherent to the per-parameter dispatch it performs.
    // swiftlint:disable:next cyclomatic_complexity
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
                // Strict ZIP-321 `amountparam` grammar via `NonNegativeAmount`, bridged to the
                // still-`LegacyAmount`-typed `Payment.amount`.
                return .amount(LegacyAmount(zatoshi: try AmountParser.parse(value, index: index)))
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
            // this parser rejects any required parameters
            guard !queryKey.hasPrefix("req-") else {
                throw ZIP321.Errors.unknownRequiredParameter(queryKey)
            }

            return .other(try OtherParam(key: queryKey, value: value))
        }
    }

    static func tryDecodeQcharValue(_ value: String) throws -> QcharString {
        guard let qcharDecodedValue = value.qcharDecode(), let qcharString = QcharString(
            value: qcharDecodedValue
        ) else {
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
                if lhs.key == rhs.key {
                    return true
                }
            default: continue
            }
        }

        return false
    }
}
