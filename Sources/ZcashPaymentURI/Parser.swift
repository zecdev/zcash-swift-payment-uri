//
//  Parser.swift
//
//
//  Created by Francisco Gindre on 2023-13-08.
//

import Foundation
import Parsing

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

public enum Param: Equatable {
    case address(RecipientAddress)
    case amount(Amount)
    case memo(MemoBytes)
    case label(String)
    case message(String)
    case other(String, String)

    var name: String {
        switch self {
        case .address:
            return ParamName.address.rawValue
        case .amount:
            return ParamName.amount.rawValue
        case .memo:
            return ParamName.memo.rawValue
        case .label:
            return ParamName.label.rawValue
        case .message:
            return ParamName.message.rawValue
        case .other(let name, _):
            return name
        }
    }
}

struct IndexedParameter: Equatable {
    let index: UInt
    let param: Param
}

enum Parser {
    /// Allowed characters for paramName are alphanumerics and `+` and `-`
    static let parameterName = Parse {
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+-")).eraseToAnyParser()
    }

    /// parses characters from the `qchar` set.
    static let otherParamValue = Parse {
        CharacterSet.qchar.eraseToAnyParser()
    }

    static let maybeLeadingAddress = Parse(input: Substring.self) {
        "zcash:"
        Optionally {
            Prefix { $0 != "?" }
        }
        Optionally {
            Rest()
        }
    }
    
    /// parameter indexes according to ZIP-321 can't have leading zeroes and should not be more than 9999
    static let parameterIndex = Parse(input: Substring.self) {
        Peek {
            Prefix(1...1) {
                !CharacterSet.nonZeroDigits.isDisjoint(
                    with: CharacterSet(charactersIn: String($0))
                )
            }
        }
        Digits(1...4)
    }

    /// parser for a `paramname` that can contain an index or not.
    static let optionallyIndexedParameterName = Parse {
        parameterName
        Optionally {
            "."
            parameterIndex
        }
    }

    /// Parser for query key and value
    /// supports `otherParam` and `req-` params without validation logic
    static let queryKeyAndValue = Parse {
        optionallyIndexedParameterName
        "="
        CharacterSet.qchar.eraseToAnyParser()
    }
    
    /// Parser that splits a sapling address human readable and Bech32 parts and verifies that
    /// HRP is any of the accepted networks (main, test, regtest) and that the supposedly Bech32
    /// part contains valid Bech32 characters
    static let saplingEncodingCharsetParser = Parse {
        OneOf {
            "ztestsapling1"
            "zregtestsapling1"
            "zs1"
        }
        CharacterSet.bech32.eraseToAnyParser()
    }
    
    /// Parser that splits a unified address human readable and Bech32 parts and verifies that
    /// HRP is any of the accepted networks (main, test, regtest) and that the supposedly Bech32
    /// part contains valid Bech32 characters
    static let unifiedEncodingCharsetParser = Parse {
        OneOf {
            "u1"
            "utest1"
            "uregtest1"
        }
        CharacterSet.bech32.eraseToAnyParser()
    }

    static let texEncodingCharsetParser = Parse {
        OneOf {
            "tex1"
            "textest1"
        }
        CharacterSet.bech32.eraseToAnyParser()
    }

    static let transparentEncodingCharsetParser = Parse {
        OneOf {
            texEncodingCharsetParser
            CharacterSet.base58.eraseToAnyParser()
        }
    }

    /// maps a parsed Query Parameter key and value into an `IndexedParameter`
    /// providing validation of Query keys and values. An address validation can be provided.
    static func zcashParameter(
        // swiftlint:disable:next large_tuple
        _ input: (Substring, Int?, Substring),
        validating: @escaping RecipientAddress.ValidatingClosure = Parser.onlyCharsetValidation
    ) throws -> IndexedParameter {
        let queryKey = String(input.0)

        guard input.1 != Int?(0) else {
            throw ZIP321.Errors.invalidParamIndex("\(input).0")
        }
        
        guard !queryKey.hasPrefix("req-") else {
            throw ZIP321.Errors.unknownRequiredParameter(queryKey)
        }

        let index = UInt(input.1 ?? 0) // zero is not allowed in the spec but we imply no index
        let value = String(input.2)

        let param = try Param.from(
            queryKey: queryKey,
            value: value,
            index: index,
            validating: validating
        )

        return IndexedParameter(index: index, param: param)
    }

    /// Attempts to parse the leading address and returns the rest of the input
    /// - parameter input: the input String of the URI
    /// - parameter validating a validation closure for all detected addressses
    /// - returns a tuple containing an optional `IndexedParameter` and the rest of the remaining
    /// subsequence.
    static func leadingAddress(
        _ input: String,
        validating: @escaping RecipientAddress.ValidatingClosure = Parser.onlyCharsetValidation
    ) throws -> (Substring?, IndexedParameter?) {
        guard input.starts(with: "zcash:") else {
            throw ZIP321.Errors.parseError("Not `zcash:` uri")
        }

        let partial = try maybeLeadingAddress.parse(input)

        if let maybeAddress = partial.0, !maybeAddress.isEmpty {
            guard let address = RecipientAddress(value: String(maybeAddress), validating: validating) else {
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
    /// - parameter validating: a closure that validates any recipients addresses found
    static func parseParameters(
        _ substring: Substring.SubSequence,
        leadingAddress: IndexedParameter?,
        validating: @escaping RecipientAddress.ValidatingClosure = onlyCharsetValidation
    ) throws -> [IndexedParameter] {
        var indexedParameters: [IndexedParameter] = []

        if let leadingAddress = leadingAddress {
            indexedParameters.append(leadingAddress)
        }

        indexedParameters.append(
            contentsOf: try Parse {
                "?"
                Many {
                    Parser.queryKeyAndValue
                } separator: {
                    "&"
                }
            }
            .parse(substring)
            .map { try zcashParameter($0, validating: validating) }
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

        var amount: Amount?
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
                if address.isTransparent {
                    throw ZIP321.Errors.transparentMemoNotAllowed(index == 0 ? nil : index)
                }

                memo = memoBytes

            case let .label(lbl):
                label = lbl

            case let .message(msg):
                message = msg

            case let .other(key, value):
                other.append(OtherParam(key: key, value: value))
            }
        }

        return Payment(
            recipientAddress: address,
            amount: amount ?? .zero,
            memo: memo,
            label: label,
            message: message,
            otherParams: other.isEmpty ? nil : other
        )
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
    static func from(
        queryKey: String,
        value: String,
        index: UInt,
        validating: @escaping RecipientAddress.ValidatingClosure
    ) throws -> Param {
        let paramName = ParamName(rawValue: queryKey)

        switch paramName {
        case .address:
            guard let addr = RecipientAddress(value: value, validating: validating) else {
                throw ZIP321.Errors.invalidAddress(index > 0 ? index : nil)
            }

            return .address(addr)
        case .amount:
            do {
                return .amount(try Amount(string: value))
            } catch {
                let amountError = try error.mapToErrorOrRethrow(Amount.AmountError.self)

                throw ZIP321.Errors.mapFrom(amountError, index: index)
            }
        case .label:
            let qcharDecoded = try Self.decodeQchar(value)

            return .label(qcharDecoded)
        case .memo:
            do {
                return .memo(try MemoBytes(base64URL: value))
            } catch {
                let memoError = try error.mapToErrorOrRethrow(MemoBytes.MemoError.self)

                throw ZIP321.Errors.mapFrom(memoError, index: index)
            }
        case .message:
            let qcharDecoded = try Self.decodeQchar(value)

            return .message(qcharDecoded)
        case .none:
            guard !queryKey.hasPrefix("req-") else {
                throw ZIP321.Errors.unknownRequiredParameter(queryKey)
            }

            let qcharDecoded = try Self.decodeQchar(value)

            return .other(queryKey, qcharDecoded)
        }
    }
}

// MARK: character sets

extension CharacterSet {
    static let nonZeroDigits = CharacterSet(charactersIn: "123456789")
    static let bech32 = CharacterSet(charactersIn: "qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    static let base58 = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
}

// MARK: recipient validation
extension Parser {
    static let onlyCharsetValidation: RecipientAddress.ValidatingClosure = { address in
        guard !address.isEmpty else { return false }

        guard let firstCharacter = address.first else { return false }
        switch firstCharacter {
        case "z":
            return (try? Parser.saplingEncodingCharsetParser.parse(address)) != nil
        case "u":
            return (try? Parser.unifiedEncodingCharsetParser.parse(address)) != nil
        case "t":
            return (try? Parser.transparentEncodingCharsetParser.parse(address)) != nil
        default:
            return false
        }
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
            case let (.other(lhs, _), .other(rhs, _)):
                if lhs == rhs {
                    return true
                }
            default: continue
            }
        }

        return false
    }
}
