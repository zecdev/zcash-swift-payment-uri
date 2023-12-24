//
//  Model.swift
//
//
//  Created by Pacu on 2023-11-07.
//

import Foundation

public struct PaymentRequest: Equatable {
    let payments: [Payment]
}

/// A Single payment that will be requested
public struct Payment: Equatable {
    struct PaymentContext {
        var params: [Param]
        var paramIndex: UInt?
    }

    typealias PaymentValidation = (PaymentContext) throws -> Void
    
    /// Recipient of the payment.
    let recipientAddress: RecipientAddress
    /// The amount of the payment expressed in decimal ZEC
    let amount: Amount
    /// bytes of the ZIP-302 Memo if present. Payments to addresses that are not shielded should be reported as erroneous by wallets.
    let memo: MemoBytes?
    /// A human-readable label for this payment within the larger structure of the transaction request.
    /// this will be pct-encoded
    let label: String?
    /// A human-readable message to be displayed to the user describing the purpose of this payment.
    let message: String?
    /// A list of other arbitrary key/value pairs associated with this payment.
    let otherParams: [OtherParam]?

    public static func == (lhs: Payment, rhs: Payment) -> Bool {
        lhs.amount == rhs.amount &&
        lhs.label == rhs.label &&
        lhs.memo == rhs.memo &&
        lhs.message == rhs.message &&
        lhs.recipientAddress == rhs.recipientAddress &&
        lhs.otherParams == rhs.otherParams
    }
}

public struct OtherParam: Equatable {
    public let key: String
    public let value: String
}

/// An *non-negative* decimal ZEC amount represented as specified in ZIP-321.
/// Amount can be from 1 zatoshi (0.00000001) to the `maxSupply` of 21M ZEC (`21_000_000`)
public struct Amount: Equatable {
    public enum AmountError: Error {
        case negativeAmount
        case greaterThanSupply
        case tooManyFractionalDigits
        case invalidTextInput
    }
    
    static let maxFractionalDecimalDigits: Int16 = 8
    static let decimalHandler = NSDecimalNumberHandler(
        roundingMode: NSDecimalNumber.RoundingMode.bankers,
        scale: Self.maxFractionalDecimalDigits,
        raiseOnExactness: true,
        raiseOnOverflow: true,
        raiseOnUnderflow: true,
        raiseOnDivideByZero: true
    )
    
    static let maxSupply: Decimal = 21_000_000

    static let zero = Amount(unchecked: 0)
    
    let value: Decimal
    /// Initializes an Amount from a `Decimal` number
    /// - parameter value: decimal representation of the desired amount. **Important:** `Decimal` values with more than 8 fractional digits ** will be rounded** using bankers rounding.
    /// - returns A valid ZEC amount
    /// - throws `Amount.AmountError` then the provided value can't represent or can't be rounded to a non-negative  ZEC decimal amount.
    public init(value: Decimal) throws {
        guard value >= 0 else { throw AmountError.negativeAmount }

        guard value <= Self.maxSupply else { throw AmountError.greaterThanSupply }
        
        self.value = value
    }
    
    public init(string: String) throws {
        let formatter = NumberFormatter.zcashNumberFormatter
        
        guard let decimalAmount = formatter.number(from: string)?.decimalValue else {
            throw AmountError.invalidTextInput
        }
        
        guard decimalAmount.significantFractionalDecimalDigits <= Self.maxFractionalDecimalDigits else {
            throw AmountError.tooManyFractionalDigits
        }
        
        try self.init(value: decimalAmount)
    }

    init(unchecked: Decimal) {
        self.value = unchecked
    }

    public func toString() -> String {
        let formatter = NumberFormatter.zcashNumberFormatter
        
        let decimal = NSDecimalNumber(decimal: self.value)
        
        return formatter.string(from: decimal.rounding(accordingToBehavior: Self.decimalHandler)) ?? "" // this value is already validated.
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

    public init(base64URL: String) throws {
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

extension NumberFormatter {
    static let zcashNumberFormatter: NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.maximumFractionDigits = 8
        formatter.maximumIntegerDigits = 8
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        
        return formatter
    }()
}

extension Decimal {
    var significantFractionalDecimalDigits: Int {
        return max(-exponent, 0)
    }
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
    /// from  RPC-3968: https://www.rfc-editor.org/rfc/rfc3986.html#appendix-A
    /// unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
    /// pct-encoded   = "%" HEXDIG HEXDIG
    func qcharEncoded() -> String? {
        let qcharEncodeAllowed = CharacterSet.qchar.subtracting(.qcharComplement)
        
        return self.addingPercentEncoding(withAllowedCharacters: qcharEncodeAllowed)
    }

    func qcharDecode() -> String? {
        self.removingPercentEncoding
    }
}

extension CharacterSet {
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
}
