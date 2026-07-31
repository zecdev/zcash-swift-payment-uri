// ZIP-321 Payment Requests for The Swift Programming Language
// See Spec: https://zips.z.cash/zip-0321
// Licence: MIT
// Created by Pacu 2023-11-07
import Foundation

/// The main entry point for constructing, rendering, and parsing
/// [ZIP-321](https://zips.z.cash/zip-0321) Zcash payment request URIs.
///
/// This is a caseless enum used purely as a namespace: see
/// ``parse(_:expecting:validator:maxInputBytes:)`` to parse a URI, and
/// ``uriString(from:formattingOptions:)`` (or the `request(_:formattingOptions:)`
/// convenience overloads) to render one.
///
/// Parsing requires a caller-supplied ``AddressValidator``: this library
/// implements the ZIP-321 URI grammar and delegates recipient-address validity
/// and capability classification entirely to the caller.
public enum ZIP321 {
    /// The default maximum accepted input size for ``parse(_:expecting:validator:maxInputBytes:)``.
    public static let defaultMaxInputBytes = 8 * 1024

    /// Selects the rendered form of a ``PaymentRequest``, reconciled with v2's
    /// paramindex preservation.
    ///
    /// - ``useEmptyParamIndex(omitAddressLabel:)`` renders each payment at its
    ///   ACTUAL stored `paramindex` (the empty paramindex — stored index `0` —
    ///   renders with no `.n` suffix; index `5` renders `address.5=…`). When
    ///   `omitAddressLabel` is `true` and the request holds exactly one payment
    ///   at index `0`, the canonical single-payment leading-address form is
    ///   emitted (`zcash:<addr>?amount=…`); otherwise the general
    ///   `zcash:?address[.n]=…&…` form is used. This is the canonical reference
    ///   form and the default for ``uriString(from:formattingOptions:)``.
    /// - ``enumerateAllPayments`` is a NORMALIZATION mode: it discards the
    ///   stored paramindices and re-numbers payments SEQUENTIALLY from `1`
    ///   (`address.1=…&address.2=…`), always with explicit address labels under
    ///   `zcash:?`. Use it to canonicalize a request onto a contiguous
    ///   `1…n` index space.
    ///
    /// The empty request renders as the bare `zcash:` scheme in either mode.
    public enum FormattingOptions {
        /// A NORMALIZATION mode: discards stored paramindices and re-numbers payments
        /// sequentially from `1` (`address.1=…&address.2=…`), always with explicit address
        /// labels under `zcash:?`.
        case enumerateAllPayments
        /// Renders each payment at its ACTUAL stored `paramindex` (the empty paramindex renders
        /// with no `.n` suffix). This is the canonical reference form.
        /// - parameter omitAddressLabel: when `true` and the request holds exactly one payment
        /// at the empty paramindex, emits the canonical single-payment leading-address form
        /// (`zcash:<addr>?amount=…`) instead of `zcash:?address=…&amount=…`.
        case useEmptyParamIndex(omitAddressLabel: Bool)
    }

    /// The internal v1 error taxonomy raised by the throwing parse pipeline.
    ///
    /// - Important: this is an **internal** type in v2. The public error surface
    /// is the sealed ``ZIP321Error`` taxonomy returned by
    /// ``parse(_:expecting:validator:maxInputBytes:)``; every case below is
    /// translated by `ZIP321Error.init(_:)`.
    enum Errors: Error {
        /// There's a payment exceeding the max supply as [ZIP-321](https://zips.z.cash/zip-0321) forbids.
        case amountExceededSupply(UInt)

        /// There's a payment that is less than a decimal zatoshi as [ZIP-321](https://zips.z.cash/zip-0321) forbids.
        case amountTooSmall(UInt)

        /// Parsing encountered a duplicate [ZIP-321](https://zips.z.cash/zip-0321) URI parameter for the returned payment index.
        case duplicateParameter(String, UInt?)

        /// An invalid address query parameter was found. paramIndex is provided in the associated value.
        case invalidAddress(UInt?)

        /// A memo field in the ZIP 321 URI was not properly base-64 encoded according to [ZIP-321](https://zips.z.cash/zip-0321)
        case invalidBase64

        /// not even a Zcash URI
        case invalidURI

        /// A memo value exceeded 512 bytes in length or could not be interpreted as a UTF-8 string
        /// when using a valid UTF-8 lead byte
        case memoBytesError(Error, UInt?)

        /// The [ZIP-321](https://zips.z.cash/zip-0321) request included more payments than can be created within a single Zcash transaction. The associated value is the number of payments in the request.
        case tooManyPayments(UInt64)

        /// The payment at the associated value attempted to include a memo when sending to a transparent recipient address, which is not supported by the [Zcash protocol](https://zips.z.cash/protocol/protocol.pdf).
        case transparentMemoNotAllowed(UInt?)

        /// A zero-valued amount was requested for a transparent recipient, which is disallowed by consensus.
        case zeroValuedTransparentOutput(UInt?)

        /// The payment which index is included in the associated value did not include a recipient address.
        case recipientMissing(UInt?)

        /// The payment request includes a `paramIndex` that is invalid according to [ZIP-321](https://zips.z.cash/zip-0321) specs
        case invalidParamIndex(String)

        /// Some invalid value was found at a query parameter that a specific index
        case invalidParamValue(param: String, index: UInt?)

        /// The [ZIP-321](https://zips.z.cash/zip-0321) URI was malformed and failed to parse.
        case parseError(String)

        /// A value was expected to be qchar-encoded but its decoding failed. Associated type has the value that failed.
        case qcharDecodeFailed(String)

        /// An attempt to qchar-encode a value failed.  The associated type has the value that failed.
        case qcharEncodeFailed(String)

        /// The parser found a required parameter it does not recognize. Associated string contains the unrecognized input.
        /// See [Forward compatibilty](https://zips.z.cash/zip-0321#forward-compatibility)
        case unknownRequiredParameter(String)

        /// The parser found a Sprout recipient and these are explicitly not allowed by the ZIP-321 specification
        case sproutRecipientsNotAllowed(UInt?)

        /// Attempt to use a reserved keyword on `otherparams` key
        case otherParamUsesReservedKey(String)

        /// found invalid enconding on Key or value
        case otherParamEncodingError(String)

        /// attempt to create ``OtherParam`` with an empty key
        case otherParamKeyEmpty
    }
}

public extension ZIP321 {
    /// Transforms this `PaymentRequest` struct into a [ZIP-321](https://zips.z.cash/zip-0321)
    /// payment request `String`.
    ///
    /// The default `formattingOptions` is the canonical reference form
    /// (``FormattingOptions/useEmptyParamIndex(omitAddressLabel:)`` with
    /// `omitAddressLabel: true`): a single payment at the empty paramindex
    /// renders as `zcash:<addr>?amount=…`, and the round-trip law
    /// `parse(uriString(from: r)) == r` holds for every request `r`.
    /// - parameter request: a `PaymentRequest` struct
    /// - parameter formattingOptions: the rendered form; defaults to the
    /// canonical reference form.
    static func uriString(
        from request: PaymentRequest,
        formattingOptions: FormattingOptions = .useEmptyParamIndex(omitAddressLabel: true)
    ) -> String {
        Render.request(request, formattingOptions: formattingOptions)
    }

    /// Convenience function that allows to generate a [ZIP-321](https://zips.z.cash/zip-0321)
    /// payment URI for a single recipient with no amount
    ///  - parameter recipient: A recipient address
    ///  - parameter formattingOptions: the rendered form; defaults to the canonical reference form.
    ///  - returns a URI string of the sort `zcash:{recipient_address_string}` if default formatting is specified, or a
    ///  labeled form (`zcash:?address={recipient_address_string}` /
    ///  `zcash:?address.1={recipient_address_string}`) otherwise. Every form parses back.
    static func request(_ recipient: RecipientAddress, formattingOptions: FormattingOptions = .useEmptyParamIndex(omitAddressLabel: true)) -> String {
        switch formattingOptions {
        case .useEmptyParamIndex(omitAddressLabel: true):
            "zcash:".appending(Render.parameter(recipient, index: nil, omittingAddressLabel: true))
        case .useEmptyParamIndex(omitAddressLabel: false):
            "zcash:?".appending(Render.parameter(recipient, index: nil, omittingAddressLabel: false))
        case .enumerateAllPayments:
            "zcash:?".appending(Render.parameter(recipient, index: 1, omittingAddressLabel: false))
        }
    }

    /// Renders a single-payment [ZIP-321](https://zips.z.cash/zip-0321) request
    /// to a URI string. Defaults to the canonical leading-address form
    /// (`zcash:<addr>?amount=…`).
    static func request(
        _ payment: Payment,
        formattingOptions: FormattingOptions = .useEmptyParamIndex(omitAddressLabel: true)
    ) -> String {
        uriString(from: PaymentRequest(singlePayment: payment), formattingOptions: formattingOptions)
    }

    /// Parses a [ZIP-321](https://zips.z.cash/zip-0321) payment request from a URI string.
    ///
    /// This is a **total** function: every input maps to a `Result`, never a
    /// thrown error or a trap.
    ///
    /// Both spellings of a single recipient — the leading-address form
    /// `zcash:<addr>` and the labeled form `zcash:?address=<addr>` — parse to
    /// the SAME ``PaymentRequest``. Which of the two the URI used is a syntax
    /// choice and is not encoded in the parsed model, matching the reference
    /// implementation.
    ///
    /// - parameter uri: the `zcash:` URI to parse.
    /// - parameter network: the consensus network this request is expected to
    /// be for. Every recipient the `validator` accepts must report this network
    /// in its ``AddressDescriptor``, or the request is rejected with
    /// ``ZIP321Error/invalidAddress(index:)``.
    /// - parameter validator: the caller-supplied authority on recipient
    /// addresses. This is REQUIRED: the library performs NO address validation
    /// of its own, so an address is valid exactly when this validator says so,
    /// and the ``AddressDescriptor`` it returns is what drives the ZIP-321
    /// payment rules (memo support, zero-valued transparent outputs).
    /// - parameter maxInputBytes: the maximum accepted UTF-8 byte length of
    /// `uri`. Inputs above this are rejected with ``ZIP321Error/invalidURI(reason:)``
    /// / ``StaticReason/inputTooLarge`` before any parsing work happens.
    /// - returns: `.success` with the parsed ``PaymentRequest`` or `.failure`
    /// with a sealed ``ZIP321Error``.
    static func parse(
        _ uri: String,
        expecting network: Network,
        validator: any AddressValidator,
        maxInputBytes: Int = ZIP321.defaultMaxInputBytes
    ) -> Result<PaymentRequest, ZIP321Error> {
        // Input guards run FIRST, before any grammar work.
        guard uri.utf8.count <= maxInputBytes else {
            return .failure(.invalidURI(reason: .inputTooLarge))
        }

        guard !uri.isEmpty else {
            // The corpus classifies the empty string (which has no `zcash:`
            // prefix to even begin parsing) as `parseError`.
            return .failure(.parseError(reason: .emptyInput))
        }

        guard uri.hasPrefix("zcash:") else {
            return .failure(.invalidURI(reason: .notZcashScheme))
        }

        // A `//` authority component is forbidden by ZIP-321's top-level grammar.
        if uri.dropFirst("zcash:".count).hasPrefix("//") {
            return .failure(.invalidURI(reason: .invalidAuthority))
        }

        do {
            return .success(try parsePipeline(uri, network: network, validator: validator))
        } catch let error as ZIP321Error {
            // Raised directly by `PaymentRequest`/`Payment` construction.
            return .failure(error)
        } catch let error as ZIP321.Errors {
            return .failure(ZIP321Error(error))
        } catch {
            // `parse` is a non-throwing `Result`-returning wrapper around
            // `parsePipeline`, which is declared as untyped `throws`; Swift
            // requires this exhaustive catch-all even though every path
            // `parsePipeline` can actually take only ever throws
            // `ZIP321Error` or `ZIP321.Errors` (both already caught above).
            // COVERAGE-EXEMPT: unreachable without a future change that throws a third error type from the parse pipeline.
            return .failure(.parseError(reason: .malformedURI))
        }
    }
}

extension ZIP321 {
    /// The throwing parse core wrapped by ``parse(_:expecting:validator:maxInputBytes:)``.
    /// Precondition: `uri` has already passed the input guards (`zcash:` prefix,
    /// non-empty, no `//` authority, within the size limit).
    static func parsePipeline(
        _ uri: String,
        network: Network,
        validator: any AddressValidator
    ) throws -> PaymentRequest {
        let (rest, leadingAddress) = try Parser.leadingAddress(uri, network: network, validator: validator)

        switch (rest, leadingAddress) {
        case (.none, .none):
            // Bare `zcash:` — a valid empty request.
            return try PaymentRequest(payments: [])

        case let (.none, .some(recipient)):
            // Bare `zcash:<address>`. This is the leading-address SPELLING of a
            // one-payment request, not a distinct kind of result: it goes
            // through exactly the same construction as `zcash:?address=<addr>`,
            // so both produce an EQUAL `PaymentRequest` (ZIP-321 URI Semantics;
            // matches the reference implementation).
            return try PaymentRequest(
                indexedPayments: Parser.mapToIndexedPayments(
                    [IndexedParameter(index: 0, param: .address(recipient))]
                )
            )

        case let (.some(rest), addressMaybe):
            let leadingParam = addressMaybe.map { IndexedParameter(index: 0, param: .address($0)) }
            let indexedParameters = try Parser.parseParameters(
                rest,
                leadingAddress: leadingParam,
                network: network,
                validator: validator
            )

            // `zcash:?` (empty query, no leading address) is a valid empty request.
            guard !indexedParameters.isEmpty else {
                return try PaymentRequest(payments: [])
            }

            let indexedPayments = try Parser.mapToIndexedPayments(indexedParameters)

            // NOTE (mirroring the reference `TransactionRequest`): the
            // 9999-payment cap enforced by this constructor is unreachable from
            // the parse path — the `paramindex` grammar (`NONZERO 0*3DIGIT`)
            // already rejects any index above 9999 with `invalidParamIndex`.
            // The cap only bites for programmatic construction.
            return try PaymentRequest(indexedPayments: indexedPayments)
        }
    }
}
