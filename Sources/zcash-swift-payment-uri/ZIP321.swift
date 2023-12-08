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
        /// A memo field in the ZIP 321 URI was not properly base-64 encoded according to [ZIP-321](https://zips.z.cash/zip-0321)
        case invalidBase64
        /// A memo value exceeded 512 bytes in length or could not be interpreted as a UTF-8 string
        /// when using a valid UTF-8 lead byte
        case memoBytesError(MemoBytes.MemoError)
        /// The [ZIP-321](https://zips.z.cash/zip-0321) request included more payments than can be created within a single Zcash transaction. The associated value is the number of payments in the request.
        case tooManyPayments(UInt64)
        /// Parsing encountered a duplicate [ZIP-321](https://zips.z.cash/zip-0321) URI parameter for the returned payment index.
        case duplicateParameter(String, UInt64)
        /// The payment at the associated value attempted to include a memo when sending to a transparent recipient address, which is not supported by the [Zcash protocol](https://zips.z.cash/protocol/protocol.pdf).
        case transparentMemoNotAllowed(UInt64)
        /// The payment which index is included in the associated value did not include a recipient address.
        case recipientMissing(UInt64)
        /// The payment request includes a `paramIndex` that is invalid according to [ZIP-321](https://zips.z.cash/zip-0321) specs
        case invalidParamIndex(String)
        /// The [ZIP-321](https://zips.z.cash/zip-0321) URI was malformed and failed to parse.
        case parseError(String)
        /// TODO: Remove
        case unimplemented
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

    static func request(from uriString: String) throws -> PaymentRequest {
        throw Errors.unimplemented
    }
}
