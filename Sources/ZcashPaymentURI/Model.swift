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
    public let amount: LegacyAmount?
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
    /// - parameter amount: a valid `LegacyAmount` or `nil`i
    /// - parameter memo: valid `MemoBytes` or `nil`
    /// - parameter label: a label that wallets might show to their users as a way to label this payment.
    /// Will not be included in the blockchain
    /// - parameter message: a message that wallets might show to their users as part of this payment. 
    /// Will not be included in the blockchain
    /// - parameter otherParams: other parameters that you'd like to define. See ZIP-321 for more 
    /// information about these parameters.
    public init(
        recipientAddress: RecipientAddress,
        amount: LegacyAmount?,
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
    /// - parameter amount: a valid `LegacyAmount` or `nil`i
    /// - parameter memo: valid `MemoBytes` or `nil`
    /// - parameter label: a label that wallets might show to their users as a way to label this payment.
    /// Will not be included in the blockchain
    /// - parameter message: a message that wallets might show to their users as part of this payment.
    /// Will not be included in the blockchain
    /// - parameter otherParams: other parameters that you'd like to define. See ZIP-321 for more
    /// information about these parameters.
    public init(
        recipientAddress: RecipientAddress,
        amount: LegacyAmount?,
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
    mutating func appendInterpolation(_ value: LegacyAmount) {
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
    ///
    /// - Note: delegates to ``QcharCodec/encode(_:)``. The optional return type is retained for
    /// source compatibility; encoding always succeeds.
    func qcharEncoded() -> String? {
        QcharCodec.encode(self)
    }

    /// Strictly percent-decodes a `qchar` value, delegating to ``QcharCodec/decode(_:)``.
    /// Returns `nil` for malformed `%XX` escapes, non-`qchar` raw bytes, or invalid UTF-8.
    func qcharDecode() -> String? {
        QcharCodec.decode(self)
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
    /// ASCII Alphabetic
    static let ASCIIAlpha = CharacterSet(
        charactersIn: UnicodeScalar(65) ... UnicodeScalar(90)
    ).union(
        CharacterSet(charactersIn: UnicodeScalar(97) ... UnicodeScalar(122))
    )

    /// ASCII numbers
    static let ASCIINum = CharacterSet(
        charactersIn: UnicodeScalar(48) ... UnicodeScalar(57)
    )

    /// ASCII Alphanumerics
    static let ASCIIAlphaNum = ASCIIAlpha.union(.ASCIINum)

    ///  `paramname` character set according to [ZIP-321](https://zips.z.cash/zip-0321)
    static let paramname = ASCIIAlpha.union(ASCIINum).union(CharacterSet(arrayLiteral: "+", "-"))

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
        var networkSet = Set<Network>()
        
        for payment in self {
            networkSet.insert(payment.recipientAddress.network)
            
            guard networkSet.count == 1 else {
                throw ZIP321.Errors.networkMismatchFound
            }
        }
    }
}
