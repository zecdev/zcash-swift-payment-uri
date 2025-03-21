// ZIP-321 Payment Requests for The Swift Programming Language
// See Spec: https://zips.z.cash/zip-0321
// Licence: MIT
// Created by Pacu 2023-11-07
import Foundation

public enum ZIP321 {
    /// Allows to specify the resulting URI String to match the possible variants specified by [ZIP-321](https://zips.z.cash/zip-0321)
    ///
    /// `.enumerateAllPayments` will generate a URI where all of its `queryparams` have an index indicating it payment index starting with the index 1
    ///
    /// `.useEmptyParamIndex(false)` will generate a URI where the first parameter will contain an empty parameter index `zcash:address=zs1...`
    ///
    /// `.useEmptyParamIndex(false)` will generate a URI where the first parameter will contain an empty parameter index and the address label will be omitted for the first payment `zcash:zs1...&amount=0.1`
    public enum FormattingOptions {
        case enumerateAllPayments
        case useEmptyParamIndex(omitAddressLabel: Bool)
    }

    /// Things that can go wrong when handling ZIP-321 URI Payment requests
    public enum Errors: Error {
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

        /// The payment which index is included in the associated value did not include a recipient address.
        case recipientMissing(UInt?)

        /// The payment request includes a `paramIndex` that is invalid according to [ZIP-321](https://zips.z.cash/zip-0321) specs
        case invalidParamIndex(String)

        /// Some invalid value was fount at a query parameter that a specific index
        case invalidParamValue(param: String, index: UInt?)

        /// The [ZIP-321](https://zips.z.cash/zip-0321) URI was malformed and failed to parse.
        case parseError(String)
        
        /// A value was expected to be qchar-encoded but its decoding failed. Associated type has the value that failed.
        case qcharDecodeFailed(String)

        /// The parser found a required parameter it does not recognize. Associated string contains the unrecognized input.
        /// See [Forward compatibilty](https://zips.z.cash/zip-0321#forward-compatibility)
        /// Variables which are prefixed with a req- are considered required. If a parser does not recognize any
        /// variables which are prefixed with req-, it MUST consider the entire URI invalid. Any other variables that
        /// are not recognized, but that are not prefixed with a req-, SHOULD be ignored.)
        case unknownRequiredParameter(String)

        /// The parser found a Sprout recipient and these are explicitly not allowed by the ZIP-321 specification
        case sproutRecipientsNotAllowed(UInt?)
    }
}

extension ZIP321 {
    static func legacyURI(from indexedParameter: IndexedParameter) throws -> ParserResult {
        guard indexedParameter.index == 0,
            case let Param.address(recipient) = indexedParameter.param
        else {
            throw ZIP321.Errors.recipientMissing(nil)
        }

        return ParserResult.legacy(recipient)
    }
}

public extension ZIP321 {
    /// Transforms this `PaymentRequest` struct into a [ZIP-321](https://zips.z.cash/zip-0321)
    /// payment request `String`
    /// - parameter request: a `PaymentRequest` struct
    static func uriString(from request: PaymentRequest, formattingOptions: FormattingOptions = .enumerateAllPayments) -> String {
        switch formattingOptions {
        case .enumerateAllPayments:
            Render.request(request, startIndex: 1, omittingFirstAddressLabel: false)
        case .useEmptyParamIndex(let omitAddressLabel):
            Render.request(request, startIndex: nil, omittingFirstAddressLabel: omitAddressLabel)
        }
    }

    /// Convenience function that allows to generate a [ZIP-321](https://zips.z.cash/zip-0321)
    /// payment URI for a single recipient with no amount
    ///  - parameter recipient: A recipient address
    ///  - returns a URI string of the sort `zcash:{recipient_address_string}` if default formatting is specified, or `zcash:address={recipient_address_string}` otherwise
    static func request(_ recipient: RecipientAddress, formattingOptions: FormattingOptions = .useEmptyParamIndex(omitAddressLabel: true)) -> String {
        switch formattingOptions {
        case .useEmptyParamIndex(omitAddressLabel: true):
            "zcash:".appending(Render.parameter(recipient, index: nil, omittingAddressLabel: true))
        default:
            "zcash:".appending(Render.parameter(recipient, index: nil, omittingAddressLabel: false))
        }
    }

    static func request(_ payment: Payment, formattingOptions: FormattingOptions = .enumerateAllPayments) -> String {
        uriString(from: PaymentRequest(payments: [payment]), formattingOptions: formattingOptions)
    }

    static func request(
        from uriString: String,
        context: ParserContext,
        validatingRecipients: RecipientAddress.ValidatingClosure? = nil) throws -> ParserResult {
        let partialResult = try Parser.leadingAddress(
            uriString,
            context: context,
            validating: validatingRecipients ?? Parser.onlyCharsetValidation
        )

        switch partialResult {
        case (.none, .none):
            throw ZIP321.Errors.invalidURI
        case (.none, .some(let param)):
            return try Self.legacyURI(from: param)
        case let (.some(rest), optionalParam):
            return ParserResult.request(
                PaymentRequest(
                    payments: try Parser
                        .mapToPayments(
                            try Parser
                                .parseParameters(
                                    rest,
                                    leadingAddress: optionalParam,
                                    context: context,
                            validating: validatingRecipients ?? Parser.onlyCharsetValidation
                        )
                    )
                )
            )
        }
    }
}
