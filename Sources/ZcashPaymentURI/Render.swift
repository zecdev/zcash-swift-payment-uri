//
//  Render.swift
//
//
//  Created by Francisco Gindre on 2023-11-13.
//

import Foundation

enum ReservedParamName: String {
    case address
    case amount
    case label
    case memo
    case message
}
enum Render {
    // TODO [#5]: validate the idx, since zero is not a valid number
    // see: https://github.com/pacu/zcash-swift-payment-uri/issues/5
    static func parameterIndex(_ idx: UInt?) -> String {
        switch idx {
        case .some(let i):
            ".\(i)"
        case .none:
            ""
        }
    }

    static func parameter(label: String, value: QcharString, index: UInt?) -> String? {
        return "\(label)\(parameterIndex(index))=\(value.qcharValue)"
    }

    static func parameter(_ amount: Amount, index: UInt?) -> String {
        "\(ReservedParamName.amount.rawValue)\(parameterIndex(index))=\(amount)"
    }

    static func parameter(_ memo: MemoBytes, index: UInt?) -> String {
        "\(ReservedParamName.memo.rawValue)\(parameterIndex(index))=\(memo.toBase64URL())"
    }

    static func parameter(_ address: RecipientAddress, index: UInt?, omittingAddressLabel: Bool = false) -> String {
        if index == nil && omittingAddressLabel {
            address.value
        } else {
            "\(ReservedParamName.address.rawValue)\(parameterIndex(index))=\(address.value)"
        }
    }

    static func parameter(label: QcharString, index: UInt?) -> String {
        // TODO: [#6] Handle format issues of qchar encoding
        // https://github.com/pacu/zcash-swift-payment-uri/issues/6
        parameter(label: ReservedParamName.label.rawValue, value: label, index: index) ?? ""
    }

    static func parameter(message: QcharString, index: UInt?) -> String {
        // TODO: [#6] Handle format issues of qchar encoding
        // https://github.com/pacu/zcash-swift-payment-uri/issues/6
        parameter(label: ReservedParamName.message.rawValue, value: message, index: index) ?? ""
    }

    static func parameter(other: OtherParam, index: UInt?) -> String {
        var parameter = "\(other.key.value)\(parameterIndex(index))"

        if let value = other.value {
            parameter.append(value.qcharValue)
        }

        return parameter
    }

    /// Creates a query parameter string for this `Payment`. This is not
    /// aware of the context of the composing payment request. This function
    /// will deterministically turn the payment into query parameters.
    /// the order of the paramenters is: address, amount, memo, label, message.
    /// - Note: Forming a valid ZIP-321 with many Payment parameters is not the responsibility of this rendering function. Bad ordering of the paramenters may form an invalid ZIP-321 request.
    /// When `index` is `nil` and `omittingAddressLabel` the function will return the address without the leading `address=` query param.
    /// - parameter payment: a valid `Payment` struct
    /// - parameter index: the index of the `paramindex` as defined by [ZIP-321](https://zips.z.cash/zip-0321). note that passing `zero` will generate an invalid request.
    /// - parameter omittingAddressLabel: When `index` is `nil` and `omittingAddressLabel` the function will return the address without the leading `address=` query param. if index is not nil this parameter will be ignored.
    static func payment(_ payment: Payment, index: UInt?, omittingAddressLabel: Bool = false) -> String {
        var result = ""

        result.append(parameter(payment.recipientAddress, index: index, omittingAddressLabel: omittingAddressLabel))
        
        if index == nil && omittingAddressLabel {
            // mark the start of the query params. Otherwise this will marked by caller
            result.append("?")
        }
        
        if let amount = payment.amount {
            if !result.hasSuffix("?") {
                result.append("&")
            }
            result.append(parameter(amount, index: index))
        }
        

        if let memo = payment.memo {
            if !result.hasSuffix("?") {
                result.append("&")
            }
            result.append(parameter(memo, index: index))
        }

        if let label = payment.label {
            if !result.hasSuffix("?") {
                result.append("&")
            }
            result.append(parameter(label: label, index: index))
        }

        if let message = payment.message {
            if !result.hasSuffix("?") {
                result.append("&")
            }
            result.append((parameter(message: message, index: index)))
        }

        if let otherParams = payment.otherParams {
            for otherParam in otherParams {
                if !result.hasSuffix("?") {
                    result.append("&")
                }
                result.append(parameter(other: otherParam, index: index))
            }
        }

        return result
    }

    static func request(_ paymentRequest: PaymentRequest, startIndex: UInt?, omittingFirstAddressLabel: Bool = false) -> String {
        var result = "zcash:"

        // we want this to be a contiguous array so we can trust the `enumerated()` iterator to have contiguous indices.
        var payments = ContiguousArray(paymentRequest.payments)
        
        // this is the offset that will give the paramindex number from what their real position in the array is.
        let paramIndexOffset = startIndex ?? 1

        if startIndex == nil {
            // this is the special case where the URI String can start either with `zcash:` or `zcash:?`
            result.append(omittingFirstAddressLabel ? "" : "?")

            result.append(
                payment(payments[0], index: startIndex, omittingAddressLabel: omittingFirstAddressLabel)
            )

            payments.removeFirst()

            if !payments.isEmpty {
                result.append("&")
            }
        }
        
        let count = payments.count

        for (elementIndex, element) in payments.enumerated() {
            let paramIndex = UInt(elementIndex) + paramIndexOffset

            result.append(payment(element, index: paramIndex))

            if paramIndex < count {
                result.append("&")
            }
        }

        return result
    }
}
