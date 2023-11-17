// ZIP-321 Payment Requests for The Swift Programming Language
// See Spec: https://zips.z.cash/zip-0321
// Licence: MIT
// Created by Pacu 2023-11-07
import Foundation

enum ZIP321 {
    /// Allows to specify the resulting URI String to match the possible variants specified by [ZIP-321](https://zips.z.cash/zip-0321)
    ///
    /// `.enumerateAllPayments` will generate a URI where all of its `queryparams` have an index indicating it payment index starting with the index 1
    ///
    /// `.useEmptyParamIndex(false)` will generate a URI where the first parameter will contain an empty parameter index `zcash:address=zs1...`
    ///
    /// `.useEmptyParamIndex(false)` will generate a URI where the first parameter will contain an empty parameter index and the address label will be omitted for the first payment `zcash:zs1...&amount=0.1`
    enum FormattingOptions {
        case enumerateAllPayments
        case useEmptyParamIndex(omitAddressLabel: Bool)
    }
}


extension ZIP321 {
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
        uriString(from: PaymentRequest(payments: [payment]),formattingOptions: formattingOptions)
    }
}

