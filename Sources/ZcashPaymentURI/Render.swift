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

/// The canonical ZIP-321 renderer.
///
/// This mirrors the librustzcash `zip321` reference `mod render` and
/// `TransactionRequest::to_uri` (see `components/zip321/src/lib.rs`, lines
/// ~380-589). Rendering is driven by ``PaymentRequest/indexedPayments``, so the
/// ACTUAL stored `paramindex` of every payment is preserved (an empty
/// paramindex — stored index `0` — renders with no `.n` suffix; a payment at
/// index `5` renders `address.5=…`).
enum Render {
    /// Renders the `paramindex` suffix for a query key.
    ///
    /// Matches the reference `render::param_index`: only a POSITIVE index
    /// produces a `.n` suffix; both `nil` and the empty paramindex (`0`) render
    /// the empty string.
    static func parameterIndex(_ idx: UInt?) -> String {
        switch idx {
        case .some(let i) where i > 0:
            return ".\(i)"
        default:
            return ""
        }
    }

    /// Renders a `name[.index]=value` query parameter, qchar-encoding the provided (decoded) value.
    static func parameter(named name: String, decodedValue: String, index: UInt?) -> String {
        "\(name)\(parameterIndex(index))=\(QcharCodec.encode(decodedValue))"
    }

    static func parameter(_ amount: NonNegativeAmount, index: UInt?) -> String {
        "\(ReservedParamName.amount.rawValue)\(parameterIndex(index))=\(amount.decimalString())"
    }

    static func parameter(_ memo: MemoBytes, index: UInt?) -> String {
        "\(ReservedParamName.memo.rawValue)\(parameterIndex(index))=\(memo.toBase64URL())"
    }

    static func parameter(_ address: RecipientAddress, index: UInt?, omittingAddressLabel: Bool = false) -> String {
        if (index == nil || index == 0) && omittingAddressLabel {
            address.value
        } else {
            "\(ReservedParamName.address.rawValue)\(parameterIndex(index))=\(address.value)"
        }
    }

    static func parameter(label: String, index: UInt?) -> String {
        // TODO: [#6] Handle format issues of qchar encoding
        // https://github.com/pacu/zcash-swift-payment-uri/issues/6
        parameter(named: ReservedParamName.label.rawValue, decodedValue: label, index: index)
    }

    static func parameter(message: String, index: UInt?) -> String {
        // TODO: [#6] Handle format issues of qchar encoding
        // https://github.com/pacu/zcash-swift-payment-uri/issues/6
        parameter(named: ReservedParamName.message.rawValue, decodedValue: message, index: index)
    }

    /// Renders an `otherparam` per the ZIP-321 grammar
    /// `otherparam = paramname [ paramindex ] [ "=" *qchar ]`, matching the
    /// reference `render::str_param`. The `=` separator is emitted whenever the
    /// parameter carries a value (including an empty `""` value → `name=`); a
    /// value-less parameter renders as a bare `name` with no `=`.
    static func parameter(other: OtherParam, index: UInt?) -> String {
        var parameter = "\(other.name)\(parameterIndex(index))"

        if let value = other.value {
            parameter.append("=")
            parameter.append(QcharCodec.encode(value))
        }

        return parameter
    }

    /// The ordered non-address query parameters for a payment, in the canonical
    /// ZIP-321 order: `amount`, `memo`, `label`, `message`, then `otherParams`
    /// in stored order. Mirrors the reference `payment_params` (`lib.rs`
    /// ~381-415).
    static func paymentParams(_ payment: Payment, index: UInt?) -> [String] {
        var params: [String] = []

        if let amount = payment.amount {
            params.append(parameter(amount, index: index))
        }

        if let memo = payment.memo {
            params.append(parameter(memo, index: index))
        }

        if let label = payment.label {
            params.append(parameter(label: label, index: index))
        }

        if let message = payment.message {
            params.append(parameter(message: message, index: index))
        }

        for otherParam in payment.otherParams {
            params.append(parameter(other: otherParam, index: index))
        }

        return params
    }

    /// Renders a single ``Payment`` as a query-parameter fragment. This is not
    /// aware of the surrounding request; forming a valid ZIP-321 URI from many
    /// payments is the caller's (``request(_:formattingOptions:)``)
    /// responsibility.
    ///
    /// The parameter order is: address, amount, memo, label, message, then
    /// otherParams in stored order.
    ///
    /// When `index` is `nil`/`0` and `omittingAddressLabel` is `true`, the
    /// fragment uses the leading-address form (`<addr>?amount=…`), i.e. the bare
    /// address followed by a `?` and the query params. Otherwise the address is
    /// rendered as an `address[.n]=…` query key alongside the rest.
    /// - parameter payment: a valid `Payment` struct
    /// - parameter index: the `paramindex` for this payment (`nil`/`0` for the empty index).
    /// - parameter omittingAddressLabel: when `index` is `nil`/`0` and this is `true`,
    /// renders the address without the leading `address=` label; ignored when `index > 0`.
    static func payment(_ payment: Payment, index: UInt?, omittingAddressLabel: Bool = false) -> String {
        let params = paymentParams(payment, index: index)

        if (index == nil || index == 0) && omittingAddressLabel {
            // Leading-address form: `<addr>[?param&param…]`. No trailing `?`
            // when there are no query params (matching the reference).
            let query = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
            return payment.recipientAddress.value + query
        }

        let addressParam = parameter(payment.recipientAddress, index: index, omittingAddressLabel: false)
        return ([addressParam] + params).joined(separator: "&")
    }

    /// Renders a whole ``PaymentRequest`` to its `zcash:` URI string according
    /// to `formattingOptions`.
    ///
    /// - `.useEmptyParamIndex(omitAddressLabel:)` renders each payment at its
    ///   ACTUAL stored `paramindex` (empty suffix for index `0`, `.n`
    ///   otherwise). When `omitAddressLabel` is `true` AND the request holds
    ///   exactly one payment AND that payment sits at index `0`, the canonical
    ///   single-payment leading-address form is used (`zcash:<addr>?amount=…`);
    ///   every other shape uses `zcash:?address[.n]=…&…`.
    /// - `.enumerateAllPayments` is a NORMALIZATION mode: it discards the stored
    ///   indices and re-numbers payments SEQUENTIALLY from `1` (`address.1`,
    ///   `address.2`, …), always with explicit address labels under `zcash:?`.
    ///
    /// The empty request renders as the bare `zcash:` scheme in either mode.
    static func request(_ paymentRequest: PaymentRequest, formattingOptions: ZIP321.FormattingOptions) -> String {
        let indexed = paymentRequest.indexedPayments

        switch formattingOptions {
        case .enumerateAllPayments:
            guard !indexed.isEmpty else { return "zcash:" }

            let segments = indexed.enumerated().map { offset, pair in
                payment(pair.payment, index: UInt(offset + 1), omittingAddressLabel: false)
            }
            return "zcash:?\(segments.joined(separator: "&"))"

        case .useEmptyParamIndex(let omitAddressLabel):
            guard !indexed.isEmpty else { return "zcash:" }

            // Reference `to_uri` single-payment special case: exactly one
            // payment at the empty paramindex, rendered as the leading-address
            // form when label omission is requested.
            if omitAddressLabel, indexed.count == 1, indexed[0].index == 0 {
                return "zcash:\(payment(indexed[0].payment, index: nil, omittingAddressLabel: true))"
            }

            let segments = indexed.map { pair in
                payment(pair.payment, index: pair.index, omittingAddressLabel: false)
            }
            return "zcash:?\(segments.joined(separator: "&"))"
        }
    }
}
