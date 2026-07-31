//
//  Builders.swift
//  zcash-swift-payment-uri
//
//  The fluent builder layer (S14) for constructing ``Payment`` and
//  ``PaymentRequest`` values, plus a `@resultBuilder` DSL that mirrors the
//  cross-language v2 construction contract shared with the Kotlin library.
//
//  Every builder DEFERS validation to its terminal `build()`, which returns a
//  `Result<…, ZIP321Error>` (never throws, never traps). This keeps chaining
//  ergonomic — `amount(zec:)`, `memo(utf8:)`, and `otherParam(name:value:)`
//  accept raw inputs and surface any conversion failure at `build()` time.
//

import Foundation

// MARK: - Payment.Builder

public extension Payment {
    /// A fluent builder for a single ``Payment``.
    ///
    /// The recipient is required up front; every other field is optional and
    /// chainable. Inputs that can fail to convert (`amount(zec:)`,
    /// `memo(utf8:)`, `otherParam(name:value:)`) are validated LAZILY: the
    /// builder stores the conversion outcome and the first failure surfaces at
    /// ``build()``. When several fields are invalid, the first error wins in a
    /// fixed field order (amount, then memo, then other params, then the
    /// ``Payment/create(recipientAddress:amount:memo:label:message:otherParams:)``
    /// structural rules — e.g. a memo on a transparent recipient).
    ///
    /// ```swift
    /// // (b) an amount + memo payment
    /// let payment = try Payment.Builder(recipient: sapling)
    ///     .amount(zec: "1.2345")
    ///     .memo(utf8: "Thanks!")
    ///     .message("Invoice #42")
    ///     .build()
    ///     .get()
    /// ```
    struct Builder: Sendable {
        private let recipient: RecipientAddress
        private var deferredAmount: Result<NonNegativeAmount?, ZIP321Error> = .success(nil)
        private var deferredMemo: Result<MemoBytes?, ZIP321Error> = .success(nil)
        private var storedLabel: String?
        private var storedMessage: String?
        private var deferredOtherParams: Result<[OtherParam], ZIP321Error> = .success([])

        /// Starts a builder for a payment to `recipient`.
        /// - parameter recipient: the (already validated) recipient address.
        public init(recipient: RecipientAddress) {
            self.recipient = recipient
        }

        /// Sets the payment amount from a ``NonNegativeAmount`` count.
        public func amount(_ amount: NonNegativeAmount) -> Self {
            var copy = self
            copy.deferredAmount = .success(amount)
            return copy
        }

        /// Sets the payment amount from a decimal ZEC string (strict ZIP-321
        /// `amountparam` grammar). Invalid strings surface at ``build()`` as
        /// ``ZIP321Error/amountInvalid(index:)`` (or
        /// ``ZIP321Error/amountExceededSupply(index:)`` when the value is above
        /// `MAX_MONEY`).
        public func amount(zec: String) -> Self {
            var copy = self
            copy.deferredAmount = NonNegativeAmount.zec(zec)
                .map { Optional($0) }
                .mapError { error in
                    switch error {
                    case .exceededSupply: return ZIP321Error.amountExceededSupply(index: nil)
                    default: return ZIP321Error.amountInvalid(index: nil)
                    }
                }
            return copy
        }

        /// Attaches a ``MemoBytes`` memo.
        public func memo(_ memo: MemoBytes) -> Self {
            var copy = self
            copy.deferredMemo = .success(memo)
            return copy
        }

        /// Attaches a memo from a UTF-8 string. A string that encodes to more
        /// than 512 bytes surfaces at ``build()`` as
        /// ``ZIP321Error/memoBytesError(index:)``.
        public func memo(utf8: String) -> Self {
            var copy = self
            copy.deferredMemo = Result { try MemoBytes(utf8String: utf8) }
                .map { Optional($0) }
                .mapError { _ in ZIP321Error.memoBytesError(index: nil) }
            return copy
        }

        /// Sets the (plain, decoded) label. It is qchar-encoded at render time.
        public func label(_ label: String) -> Self {
            var copy = self
            copy.storedLabel = label
            return copy
        }

        /// Sets the (plain, decoded) message. It is qchar-encoded at render time.
        public func message(_ message: String) -> Self {
            var copy = self
            copy.storedMessage = message
            return copy
        }

        /// Appends an arbitrary (non-reserved) `otherparam`. An empty name, a
        /// reserved key, or a name that is not a valid `paramname` surfaces at
        /// ``build()`` as ``ZIP321Error/parseError(reason:)``; repeating a name
        /// already added surfaces as
        /// ``ZIP321Error/duplicateParameter(name:index:)`` (enforced by
        /// ``Payment/create(recipientAddress:amount:memo:label:message:otherParams:)``).
        /// - parameter name: the (plain) parameter name.
        /// - parameter value: the (plain, decoded) value, or `nil` for a
        /// value-less parameter.
        public func otherParam(name: String, value: String?) -> Self {
            var copy = self
            copy.deferredOtherParams = deferredOtherParams.flatMap { existing in
                Result { try OtherParam(name: name, value: value) }
                    .map { existing + [$0] }
                    .mapError { _ in ZIP321Error.parseError(reason: .invalidParameter) }
            }
            return copy
        }

        /// Builds the ``Payment``, surfacing the first deferred conversion error
        /// (amount → memo → other params) and then the structural rules enforced
        /// by ``Payment/create(recipientAddress:amount:memo:label:message:otherParams:)``.
        public func build() -> Result<Payment, ZIP321Error> {
            let amount: NonNegativeAmount?
            switch deferredAmount {
            case .success(let value): amount = value
            case .failure(let error): return .failure(error)
            }

            let memo: MemoBytes?
            switch deferredMemo {
            case .success(let value): memo = value
            case .failure(let error): return .failure(error)
            }

            let otherParams: [OtherParam]
            switch deferredOtherParams {
            case .success(let value): otherParams = value
            case .failure(let error): return .failure(error)
            }

            return Payment.create(
                recipientAddress: recipient,
                amount: amount,
                memo: memo,
                label: storedLabel,
                message: storedMessage,
                otherParams: otherParams
            )
        }
    }
}

// MARK: - PaymentRequest.Builder

public extension PaymentRequest {
    /// A fluent builder for a ``PaymentRequest``.
    ///
    /// ``add(_:)`` assigns sequential paramindices `0, 1, 2, …` in call order;
    /// ``add(_:at:)`` pins a payment to an explicit `paramindex`. Validation is
    /// deferred to ``build()``: a repeated index fails with
    /// ``ZIP321Error/duplicateParameter(name:index:)`` and an index above
    /// `9999` fails with ``ZIP321Error/tooManyPayments(count:)``.
    ///
    /// ```swift
    /// // (c) a multi-payment request
    /// let request = try PaymentRequest.Builder()
    ///     .add(alicePayment)              // paramindex 0
    ///     .add(bobPayment)                // paramindex 1
    ///     .add(carolPayment, at: 7)       // paramindex 7
    ///     .build()
    ///     .get()
    /// ```
    struct Builder: Sendable {
        private var indexed: [(index: UInt, payment: Payment)] = []
        private var autoIndex: UInt = 0

        /// Starts an empty request builder.
        public init() {}

        /// Seeds the builder with `payments` auto-indexed sequentially from `0`.
        public init(payments: [Payment]) {
            for (offset, payment) in payments.enumerated() {
                indexed.append((index: UInt(offset), payment: payment))
            }
            autoIndex = UInt(payments.count)
        }

        /// Adds a payment at the next sequential auto-assigned `paramindex`.
        public func add(_ payment: Payment) -> Self {
            var copy = self
            copy.indexed.append((index: copy.autoIndex, payment: payment))
            copy.autoIndex += 1
            return copy
        }

        /// Adds a payment pinned to an explicit `paramindex`.
        public func add(_ payment: Payment, at index: UInt) -> Self {
            var copy = self
            copy.indexed.append((index: index, payment: payment))
            return copy
        }

        /// Builds the ``PaymentRequest``, validating index uniqueness and the
        /// `9999` cap.
        public func build() -> Result<PaymentRequest, ZIP321Error> {
            do {
                return .success(try PaymentRequest(indexedPayments: indexed))
            } catch let error as ZIP321Error {
                return .failure(error)
            } catch {
                // `PaymentRequest.init(indexedPayments:)` is declared as
                // untyped `throws` but only ever throws `ZIP321Error` (caught
                // above); Swift requires this exhaustive catch-all anyway.
                // COVERAGE-EXEMPT: unreachable unless that initializer starts throwing some other error type.
                return .failure(.parseError(reason: .malformedURI))
            }
        }
    }
}

// MARK: - Result-builder sugar

/// A `@resultBuilder` DSL for assembling a ``PaymentRequest`` from a block of
/// ``Payment`` values. It is a thin layer over ``PaymentRequest/Builder``:
/// payments are collected in source order and auto-indexed sequentially from
/// `0`, and the block evaluates to a `Result<PaymentRequest, ZIP321Error>`.
///
/// Use ``PaymentRequest/build(_:)`` to open a block:
///
/// ```swift
/// // (c) a multi-payment request, DSL form
/// let request = try PaymentRequest.build {
///     alicePayment
///     bobPayment
/// }.get()
/// ```
///
/// Both single ``Payment`` expressions and `[Payment]` arrays are accepted as
/// statements.
///
/// - Note: the DSL entry point is `PaymentRequest.build { … }` rather than a
/// bare `PaymentRequest { … }` free function: Swift forbids a global function
/// sharing a name with a type in the same module. The `.build` factory
/// preserves the Result-returning (`.get()`) totality contract.
@resultBuilder
public enum PaymentRequestBuilder {
    /// Lifts a single ``Payment`` statement into the partial result.
    public static func buildExpression(_ payment: Payment) -> [Payment] { [payment] }

    /// Lifts a `[Payment]` statement (e.g. a spread of payments) into the partial result.
    public static func buildExpression(_ payments: [Payment]) -> [Payment] { payments }

    /// Concatenates the statements of a block in source order.
    public static func buildBlock(_ components: [Payment]...) -> [Payment] {
        components.flatMap { $0 }
    }

    /// Flattens the iterations of a `for` loop.
    public static func buildArray(_ components: [[Payment]]) -> [Payment] {
        components.flatMap { $0 }
    }

    /// Yields the payments of an `if` without `else` (or an empty list when absent).
    public static func buildOptional(_ component: [Payment]?) -> [Payment] {
        component ?? []
    }

    /// Delegates to ``PaymentRequest/Builder`` to produce the final result.
    public static func buildFinalResult(_ component: [Payment]) -> Result<PaymentRequest, ZIP321Error> {
        PaymentRequest.Builder(payments: component).build()
    }
}

public extension PaymentRequest {
    /// Opens a ``PaymentRequestBuilder`` block and returns the assembled
    /// `Result<PaymentRequest, ZIP321Error>`:
    ///
    /// ```swift
    /// let request = try PaymentRequest.build {
    ///     payment1
    ///     payment2
    /// }.get()
    /// ```
    static func build(
        @PaymentRequestBuilder _ content: () -> Result<PaymentRequest, ZIP321Error>
    ) -> Result<PaymentRequest, ZIP321Error> {
        content()
    }
}
