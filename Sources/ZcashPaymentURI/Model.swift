//
//  Model.swift
//
//
//  Created by Pacu on 2023-11-07.
//

import Foundation

public struct PaymentRequest: Equatable {
    public let payments: [Payment]
    
    /// Create a Payment Request from a sequence of payments
    /// - parameter payments: a sequence of ``Payment`` structs
    /// - throws: ``ZIP321.Errors.networkMismatchFound`` if more than one
    /// kind of ``RecipientAddress.Network`` payment recipients are found.
    public init(payments: [Payment]) throws {
        try payments.enforceNetworkCoherence()
        self.payments = payments
    }
    
    /// Create Payment Request from a single ``Payment`` struct
    public init(singlePayment: Payment) {
        self.payments = [singlePayment]
    }
}

/// A Single payment that will be requested
public struct Payment: Equatable {
    /// Recipient of the payment.
    public let recipientAddress: RecipientAddress
    /// The amount of the payment expressed in decimal ZEC
    public let amount: Amount?
    /// bytes of the ZIP-302 Memo if present. Payments to addresses that are not shielded should be reported as erroneous by wallets.
    public let memo: MemoBytes?
    /// A human-readable label for this payment within the larger structure of the transaction request.
    /// this will be pct-encoded
    public let label: QcharString?
    /// A human-readable message to be displayed to the user describing the purpose of this payment.
    public let message: QcharString?
    /// A list of other arbitrary key/value pairs associated with this payment.
    public let otherParams: [OtherParam]?

    /// Initializes a Payment struct. validation of the whole payment is deferred to the ZIP-321 serializer.
    /// - parameter recipientAddress: a valid Zcash recipient address
    /// - parameter amount: a valid `Amount` or `nil`i
    /// - parameter memo: valid `MemoBytes` or `nil`
    /// - parameter label: a label that wallets might show to their users as a way to label this payment.
    /// Will not be included in the blockchain
    /// - parameter message: a message that wallets might show to their users as part of this payment. 
    /// Will not be included in the blockchain
    /// - parameter otherParams: other parameters that you'd like to define. See ZIP-321 for more 
    /// information about these parameters.
    public init(
        recipientAddress: RecipientAddress,
        amount: Amount?,
        memo: MemoBytes?,
        qcharLabel: QcharString?,
        qcharMessage: QcharString?,
        otherParams: [OtherParam]?
    ) throws {
        if memo != nil && !recipientAddress.canReceiveMemos {
            throw ZIP321.Errors.transparentMemoNotAllowed(nil)
        }
        self.recipientAddress = recipientAddress
        self.amount = amount
        self.memo = memo
        self.label = qcharLabel
        self.message = qcharMessage
        self.otherParams = otherParams
    }

    /// Initializes a Payment struct. validation of the whole payment is deferred to the ZIP-321 serializer.
    /// - parameter recipientAddress: a valid Zcash recipient address
    /// - parameter amount: a valid `Amount` or `nil`i
    /// - parameter memo: valid `MemoBytes` or `nil`
    /// - parameter label: a label that wallets might show to their users as a way to label this payment.
    /// Will not be included in the blockchain
    /// - parameter message: a message that wallets might show to their users as part of this payment.
    /// Will not be included in the blockchain
    /// - parameter otherParams: other parameters that you'd like to define. See ZIP-321 for more
    /// information about these parameters.
    public init(
        recipientAddress: RecipientAddress,
        amount: Amount?,
        memo: MemoBytes?,
        label: String?,
        message: String?,
        otherParams: [OtherParam]?
    ) throws {
        if memo != nil && !recipientAddress.canReceiveMemos {
            throw ZIP321.Errors.transparentMemoNotAllowed(nil)
        }

        // compiler has a limitation and this can't be a result builder
        if let label = label {
            guard let qcharLabel = QcharString(value: label) else {
                throw ZIP321.Errors.qcharEncodeFailed(label)
            }
            self.label = qcharLabel
        } else {
            self.label = Optional<QcharString>.none
        }

        // compiler has a limitation and this can't be a result builder
        if let message = message {
            guard let qcharMessage = QcharString(value: message) else {
                throw ZIP321.Errors.qcharEncodeFailed(message)
            }
            self.message = qcharMessage
        } else {
            self.message = Optional<QcharString>.none
        }

        self.recipientAddress = recipientAddress
        self.amount = amount
        self.memo = memo
        self.otherParams = otherParams
    }

    public static func == (lhs: Payment, rhs: Payment) -> Bool {
        lhs.amount == rhs.amount &&
        lhs.label == rhs.label &&
        lhs.memo == rhs.memo &&
        lhs.message == rhs.message &&
        lhs.recipientAddress == rhs.recipientAddress &&
        lhs.otherParams == rhs.otherParams
    }
}

/// Represents the `otherparam` definition for query-keys of ZIP-321 requests
/// ```
///   otherparam      = paramname [ paramindex ] [ "=" *qchar ]
/// ```
public struct OtherParam: Equatable {
    public let key: ParamNameString
    public let value: QcharString?

    /// initialized `OtherParam` with a key an Optional value
    /// - returns `nil` when the key collides with reserved queryparam keys,
    /// key is empty or if either key or value do not conform to the `CharacterSet.qchar` set
    public init(key: String, value: String?) throws {
        guard !key.isEmpty else { throw ZIP321.Errors.otherParamKeyEmpty }
        guard !Self.isReservedKey(key) else { throw ZIP321.Errors.otherParamUsesReservedKey("\(key)") }
        
        guard let qcharKey = ParamNameString(value: key) else {
            throw ZIP321.Errors.otherParamEncodingError("\(key)")
        }

        var qcharValue: QcharString?

        if let value = value {
            guard let unwrappedValue = QcharString(value: value) else {
                throw ZIP321.Errors.otherParamEncodingError(value)
            }

            qcharValue = unwrappedValue
        }

        try self.init(key: qcharKey, value: qcharValue)
    }

    public init(key: ParamNameString, value: QcharString?) throws {
        guard !Self.isReservedKey(key.value) else { throw ZIP321.Errors.otherParamUsesReservedKey("\(key.value)") }

        self.key = key
        self.value = value
    }

    static func isReservedKey(_ key: String) -> Bool {
        key == "address" ||
        key == "amount" ||
        key == "label" ||
        key == "memo" ||
        key == "message" ||
        key == "req-"
    }
}

public struct MemoBytes: Equatable {
    public enum MemoError: Error {
        case memoTooLong
        case memoEmpty
        case notUTF8String
        case invalidBase64URL
    }
    
    public let maxLength = 512
    let data: Data
    
    public init(bytes: [UInt8]) throws {
        guard !bytes.isEmpty else {
            throw MemoError.memoEmpty
        }
        guard bytes.count <= maxLength else {
            throw MemoError.memoTooLong
        }
        
        self.data = Data(bytes)
    }
    /// Initializes a Memo from a UTF8 String.
    /// - Important: use [`MemoBytes.init(base64URL:)`] to initialize a memo from base64URL
    public init(utf8String: String) throws {
        guard !utf8String.isEmpty else {
            throw MemoError.memoEmpty
        }
        
        guard let memoStringData = utf8String.data(using: .utf8) else {
            throw MemoError.notUTF8String
        }
        
        guard memoStringData.count <= maxLength else {
            throw MemoError.memoTooLong
        }
        
        self.data = memoStringData
    }

    /// Initializes a [`MemoBytes`] from an [RFC-4648 Base64URL](https://datatracker.ietf.org/doc/html/rfc4648#section-5)
    /// string.
    /// - parameter base64URL: a String confirming to the Base64URL specification
    /// - throws [`MemoBytes.MemoError.invalidBase64URL`] if an invalid string is found.
    public init(base64URL: String) throws {
        guard base64URL.unicodeScalars.allSatisfy({ character in
            CharacterSet.base64URL.contains(character)
        }) else {
            throw MemoBytes.MemoError.invalidBase64URL
        }

        var base64 = base64URL.replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        
        if base64.utf8.count % 4 != 0 {
            base64.append(
                String(repeating: "=", count: 4 - base64.utf8.count % 4)
            )
        }
        guard let data = Data(base64Encoded: base64) else {
            throw MemoBytes.MemoError.invalidBase64URL
        }

        try self.init(bytes: [UInt8](data))
    }

    /// Conversion of the present bytes to Base64URL
    /// - Notes: According to https://en.wikipedia.org/wiki/Base64#Variants_summary_table
    public func toBase64URL() -> String {
        self.data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}

public extension MemoBytes {
    var memoData: Data {
        self.data
    }
}

extension NumberFormatter {
    static let zcashNumberFormatter: NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.maximumFractionDigits = 8
        formatter.maximumIntegerDigits = 8
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        formatter.roundingMode = .halfUp

        return formatter
    }()
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: Amount) {
        appendLiteral(value.toString())
    }
}

extension String {
    /// Encode this string as qchar.
    /// As defined on ZIP-321
    /// qchar           = unreserved / pct-encoded / allowed-delims / ":" / "@"
    /// allowed-delims  = "!" / "$" / "'" / "(" / ")" / "*" / "+" / "," / ";"
    ///
    /// from  RPC-3986: https://www.rfc-editor.org/rfc/rfc3986.html#appendix-A
    /// unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
    /// pct-encoded   = "%" HEXDIG HEXDIG
    func qcharEncoded() -> String? {
        let qcharEncodeAllowed = CharacterSet.qchar.subtracting(.qcharComplement)
        
        return self.addingPercentEncoding(withAllowedCharacters: qcharEncodeAllowed)
    }

    func qcharDecode() -> String? {
        self.removingPercentEncoding
    }

    var asQcharString: QcharString? {
        QcharString(value: self)
    }

    var asParamNameString: ParamNameString? {
        ParamNameString(value: self)
    }
}

// MARK: character sets

extension CharacterSet {
    /// non-zero digits
    static let nonZeroDigits = CharacterSet(charactersIn: "123456789")

    /// characters in Bech32 encoding
    static let bech32 = CharacterSet(charactersIn: "qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    /// characters in Base58 encoding
    static let base58 = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    
    /// All ASCII characters from 0 to 127
    static let ASCIICharacters = CharacterSet(
        charactersIn: UnicodeScalar(0) ... UnicodeScalar(127)
    )

    /// ASCII Alphabetic
    static let ASCIIAlpha = CharacterSet(
        charactersIn: UnicodeScalar(65) ... UnicodeScalar(90)
    ).union(
        CharacterSet(charactersIn: UnicodeScalar(97) ... UnicodeScalar(122))
    )

    /// ASCII non-zero numbers
    static let ASCIINonZeroNum = CharacterSet(
        charactersIn: UnicodeScalar(49) ... UnicodeScalar(57)
    )

    /// ASCII numbers
    static let ASCIINum = CharacterSet(
        charactersIn: UnicodeScalar(48) ... UnicodeScalar(57)
    )

    /// ASCII Alphanumerics
    static let ASCIIAlphaNum = ASCIIAlpha.union(.ASCIINum)

    /// ASCII Hexadecimal digits
    static let ASCIIHexDigits = ASCIINum.union(
        CharacterSet(charactersIn: UnicodeScalar(65) ... UnicodeScalar(70))
            .union(
                CharacterSet(charactersIn: UnicodeScalar(97) ... UnicodeScalar(102))
            )
    )

    ///  `paramname` character set according to [ZIP-321](https://zips.z.cash/zip-0321)
    static let paramname = ASCIIAlpha.union(ASCIINum).union(CharacterSet(arrayLiteral: "+","-"))

    /// `paramindex` character set according to [ZIP-321](https://zips.z.cash/zip-0321)
    static let paramindex = ASCIINum.union(CharacterSet(arrayLiteral: "."))

    /// the query key part of `otherparam` character set according to [ZIP-321](https://zips.z.cash/zip-0321)
    static let otherParamsKey = paramname.union(paramindex)

    /// `unreserved`character set defined on [rfc3986](https://www.rfc-editor.org/rfc/rfc3986.html#appendix-A)
    static let unreserved = CharacterSet
        .ASCIIAlphaNum
        .union(CharacterSet(arrayLiteral: "-", ".", "_", "~"))
    
    /// `pct-encoded` charset according to [rfc3986](https://www.rfc-editor.org/rfc/rfc3986.html#appendix-A)
    static let pctEncoded = CharacterSet.ASCIIHexDigits.union(CharacterSet(charactersIn: "%"))

    /// `allowed-delims` character set as defined on [ZIP-321](https://zips.z.cash/zip-0321)
    static let allowedDelims = CharacterSet(charactersIn: "-._~!$'()*+,;:@%")
    
    /// ASCII control characters from 0x00 to 0x1F
    static let ASCIIControl = CharacterSet((0x00...0x1F).map { UnicodeScalar($0) })

    /// All characters of qchar as defined on [ZIP-321](https://zips.z.cash/zip-0321)
    static let qchar = CharacterSet()
        .union(.ASCIIAlphaNum)
        .union(.unreserved)
        .union(.allowedDelims)
        .union(CharacterSet(arrayLiteral: "@", ":"))
    
    static let qcharComplement = CharacterSet.ASCIIControl
        .union(
            CharacterSet(
                arrayLiteral: " ",
                "\"",
                "#",
                "%",
                "&",
                "/",
                "<",
                "=",
                ">",
                "?",
                "[",
                "\\",
                "]",
                "^",
                "`",
                "{",
                "|",
                "}"
            )
        )

    /// [RFC 4648  Base64URL](https://www.rfc-editor.org/rfc/rfc4648.html#section-5) Character Set.
    /// A-Z, a-z, 0-9, _, -
    /// - Note: a Base64URL value can be defined using the following regular expression:
    /// ^[A-Za-z0-9_-]+$
    static let base64URL = ASCIINum
        .union(.ASCIIAlpha)
        .union(CharacterSet(arrayLiteral: "-", "_"))
    
}

extension String {
    func conformsToCharacterSet(_ characterSet: CharacterSet) -> Bool {
        guard self.unicodeScalars.allSatisfy({ character in
            characterSet.contains(character)
        }) else {
            return false
        }
        
        return true
    }
}


extension Array where Element == Payment {
    func enforceNetworkCoherence() throws {
        var networkSet = Set<RecipientAddress.Network>()
        
        for payment in self {
            networkSet.insert(payment.recipientAddress.network)
            
            guard networkSet.count == 1 else {
                throw ZIP321.Errors.networkMismatchFound
            }
        }
    }
}
