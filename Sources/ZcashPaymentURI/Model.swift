//
//  Model.swift
//
//
//  Created by Pacu on 2023-11-07.
//

import Foundation

/// A [ZIP-321](https://zips.z.cash/zip-0321) transaction request: an ordered
/// collection of payments, each addressed by its `paramindex`.
///
/// Unlike v1, `PaymentRequest` **retains ZIP-321 paramindices**. Indices need
/// not be contiguous or start at zero (see ZIP-321 "URI Semantics"), so a
/// request whose only payment sits at index 5 preserves that 5 in
/// ``indexedPayments``. An empty request (zero payments) is valid.
public struct PaymentRequest: Equatable, Sendable {
    /// The maximum number of payments a single request may contain; ZIP-321
    /// `paramindex` values are limited to four digits.
    static let maxPaymentCount: UInt = 9999

    /// Payments keyed by their ZIP-321 `paramindex` (index `0` denotes the
    /// empty paramindex).
    private let paymentsByIndex: [UInt: Payment]

    /// The payments of this request, ordered by ascending `paramindex`.
    public var payments: [Payment] {
        paymentsByIndex.sorted { $0.key < $1.key }.map(\.value)
    }

    /// The payments of this request paired with their ZIP-321 `paramindex`,
    /// ordered by ascending index.
    public var indexedPayments: [(index: UInt, payment: Payment)] {
        paymentsByIndex.sorted { $0.key < $1.key }.map { (index: $0.key, payment: $0.value) }
    }

    /// Create a Payment Request from a sequence of payments, assigning
    /// sequential paramindices `0, 1, 2, …` in order.
    /// - parameter payments: a sequence of ``Payment`` structs (may be empty).
    /// - throws: ``ZIP321Error/tooManyPayments(count:)`` if more than
    /// ``maxPaymentCount`` payments are provided.
    public init(payments: [Payment]) throws {
        guard payments.count <= Int(Self.maxPaymentCount) else {
            throw ZIP321Error.tooManyPayments(count: UInt(payments.count))
        }

        var byIndex: [UInt: Payment] = [:]
        for (offset, payment) in payments.enumerated() {
            byIndex[UInt(offset)] = payment
        }
        self.paymentsByIndex = byIndex
    }

    /// Create a Payment Request from payments paired with explicit ZIP-321
    /// paramindices.
    /// - parameter indexedPayments: `(index, payment)` pairs. Indices must be
    /// unique and each `≤ 9999`.
    /// - throws: ``ZIP321Error/duplicateParameter(name:index:)`` if an index
    /// repeats, or ``ZIP321Error/tooManyPayments(count:)`` if any index exceeds
    /// ``maxPaymentCount``.
    public init(indexedPayments: [(index: UInt, payment: Payment)]) throws {
        var byIndex: [UInt: Payment] = [:]

        for pair in indexedPayments {
            guard pair.index <= Self.maxPaymentCount else {
                throw ZIP321Error.tooManyPayments(count: pair.index)
            }

            guard byIndex[pair.index] == nil else {
                throw ZIP321Error.duplicateParameter(name: "address", index: pair.index == 0 ? nil : pair.index)
            }

            byIndex[pair.index] = pair.payment
        }

        self.paymentsByIndex = byIndex
    }

    /// Create Payment Request from a single ``Payment`` struct (at the empty
    /// paramindex).
    public init(singlePayment: Payment) {
        self.paymentsByIndex = [0: singlePayment]
    }
}

/// A Single payment that will be requested
public struct Payment: Equatable, Sendable {
    /// Recipient of the payment.
    public let recipientAddress: RecipientAddress
    /// The amount of the payment, as a ``NonNegativeAmount`` count, or `nil` if unspecified.
    public let amount: NonNegativeAmount?
    /// bytes of the ZIP-302 Memo if present. Payments to addresses that are not shielded should be reported as erroneous by wallets.
    public let memo: MemoBytes?
    /// A human-readable (already decoded) label for this payment.
    public let label: String?
    /// A human-readable (already decoded) message describing this payment.
    public let message: String?
    /// The additional, non-reserved `otherparam` entries of this payment, in
    /// the order they appeared (or were added).
    ///
    /// This is always an array: there is NO distinction between "no other
    /// params" and "an empty list of other params", because ZIP-321 has no way
    /// to spell the difference and the reference implementation does not model
    /// one either. An absent list and an empty list would render identically,
    /// so representing both would make two distinct `Payment` values with the
    /// same URI — breaking the round-trip law.
    ///
    /// Names are unique within a payment; ``create(recipientAddress:amount:memo:label:message:otherParams:)``
    /// rejects duplicates.
    public let otherParams: [OtherParam]

    /// Internal designated initializer; performs no validation. Use
    /// ``create(recipientAddress:amount:memo:label:message:otherParams:)`` for
    /// the validated public factory.
    init(
        unchecked recipientAddress: RecipientAddress,
        amount: NonNegativeAmount?,
        memo: MemoBytes?,
        label: String?,
        message: String?,
        otherParams: [OtherParam]
    ) {
        self.recipientAddress = recipientAddress
        self.amount = amount
        self.memo = memo
        self.label = label
        self.message = message
        self.otherParams = otherParams
    }

    /// The first `otherparam` name that appears more than once in `params`, or
    /// `nil` when every name is unique.
    static func firstDuplicateName(in params: [OtherParam]) -> String? {
        var seen: Set<String> = []

        for param in params {
            guard seen.insert(param.name).inserted else { return param.name }
        }

        return nil
    }

    /// Creates a validated ``Payment``, enforcing the ZIP-321 structural rules
    /// that apply to an individual payment (matching the reference
    /// `to_payment`):
    ///
    /// - a `memo` may not be attached to a recipient that cannot receive memos
    ///   (a transparent address) — ``ZIP321Error/transparentMemo(index:)``;
    /// - a zero-valued `amount` may not be sent to a transparent recipient —
    ///   ``ZIP321Error/zeroValuedTransparentOutput(index:)``.
    ///
    /// Errors are produced index-agnostically (`index: nil`); the parser tags
    /// them with the concrete payment index via ``ZIP321Error/withIndex(_:)``.
    ///
    /// - parameter label: a plain (decoded) label, or `nil`. Wallets may show
    /// this; it is not included in the blockchain.
    /// - parameter message: a plain (decoded) message, or `nil`. Wallets may
    /// show this; it is not included in the blockchain.
    public static func create(
        recipientAddress: RecipientAddress,
        amount: NonNegativeAmount?,
        memo: MemoBytes?,
        label: String?,
        message: String?,
        otherParams: [OtherParam] = []
    ) -> Result<Payment, ZIP321Error> {
        if let duplicate = Self.firstDuplicateName(in: otherParams) {
            return .failure(.duplicateParameter(name: duplicate, index: nil))
        }

        if memo != nil && !recipientAddress.canReceiveMemos {
            return .failure(.transparentMemo(index: nil))
        }

        if let amount = amount, amount.value == 0, recipientAddress.isTransparent {
            return .failure(.zeroValuedTransparentOutput(index: nil))
        }

        return .success(
            Payment(
                unchecked: recipientAddress,
                amount: amount,
                memo: memo,
                label: label,
                message: message,
                otherParams: otherParams
            )
        )
    }

    /// Initializes a Payment struct.
    /// - Warning: **Deprecated.** Prefer
    /// ``create(recipientAddress:amount:memo:label:message:otherParams:)``,
    /// which returns a `Result` consistent with v2 totality.
    @available(*, deprecated, message: "Use Payment.create(...) which returns a Result<Payment, ZIP321Error>.")
    public init(
        recipientAddress: RecipientAddress,
        amount: NonNegativeAmount?,
        memo: MemoBytes?,
        label: String?,
        message: String?,
        otherParams: [OtherParam] = []
    ) throws {
        let result = Payment.create(
            recipientAddress: recipientAddress,
            amount: amount,
            memo: memo,
            label: label,
            message: message,
            otherParams: otherParams
        )
        self = try result.get()
    }
}

/// Represents the `otherparam` definition for query-keys of ZIP-321 requests
/// ```
///   otherparam      = paramname [ paramindex ] [ "=" *qchar ]
/// ```
///
/// Both fields carry plain, already-decoded values: `name` is the `paramname`,
/// and `value` is the percent-decoded `*qchar` value (or `nil` when the
/// parameter had no `= value`).
public struct OtherParam: Equatable, Sendable {
    public let name: String
    public let value: String?

    /// Initializes an `OtherParam` with a plain (decoded) name and optional
    /// (decoded) value.
    /// - throws: an internal error when the name is empty, collides with a
    /// reserved query key, or is not a valid `paramname`.
    public init(name: String, value: String?) throws {
        guard !name.isEmpty else { throw ZIP321.Errors.otherParamKeyEmpty }
        guard !Self.isReservedKey(name) else { throw ZIP321.Errors.otherParamUsesReservedKey(name) }
        guard name.asParamNameString != nil else {
            throw ZIP321.Errors.otherParamEncodingError(name)
        }

        self.name = name
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
