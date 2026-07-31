//
//  AddressValidator.swift
//  zcash-swift-payment-uri
//

import Foundation

/// The caller-supplied authority on Zcash recipient addresses.
///
/// This library implements the [ZIP-321](https://zips.z.cash/zip-0321) URI
/// **grammar** and nothing else. It does not know how Zcash addresses are
/// encoded, which encodings exist, or which of them a given deployment
/// considers acceptable. Every one of those questions is answered here, by the
/// caller, and this library treats the answer as final:
///
/// - a `nil` return means the address is invalid and the payment request is
///   rejected with ``ZIP321Error/invalidAddress(index:)``;
/// - a non-`nil` ``AddressDescriptor`` is trusted verbatim — its
///   ``AddressDescriptor/network``, ``AddressDescriptor/isTransparent`` and
///   ``AddressDescriptor/canReceiveMemos`` drive the ZIP-321 payment rules with
///   no second opinion from this library.
///
/// There is no built-in fallback and no "and also" composition: a validator is
/// a REQUIRED argument of ``ZIP321/parse(_:expecting:validator:maxInputBytes:)``
/// precisely so that address validity can never silently come from a
/// structural approximation baked into a URI parser.
///
/// Wallets should implement this by delegating to their Zcash SDK's own address
/// support (for example librustzcash's `ZcashAddress` via the mobile SDKs'
/// FFI/JNI bindings), which is the only place that can answer these questions
/// correctly — including Unified Address receiver decoding, and which address
/// kinds the wallet is willing to pay.
///
/// ```swift
/// struct WalletAddressValidator: AddressValidator {
///     let sdk: SomeZcashSDK
///
///     func validate(_ address: String) -> AddressDescriptor? {
///         guard let parsed = sdk.parseAddress(address) else { return nil }
///         // ZIP-321 forbids Sprout recipients.
///         guard !parsed.isSprout else { return nil }
///         return AddressDescriptor(
///             network: parsed.isTestnet ? .testnet : .mainnet,
///             isTransparent: parsed.isTransparent,
///             canReceiveMemos: parsed.hasShieldedReceiver
///         )
///     }
/// }
/// ```
public protocol AddressValidator: Sendable {
    /// Decides whether `address` is a recipient this caller accepts, and
    /// describes it.
    ///
    /// - parameter address: the raw, still-undecoded address string exactly as
    /// it appeared in the URI.
    /// - returns: an ``AddressDescriptor`` when the address is valid and
    /// acceptable, or `nil` to reject it. The return value is AUTHORITATIVE;
    /// this library does not second-guess it.
    func validate(_ address: String) -> AddressDescriptor?
}

/// An ``AddressValidator`` backed by a closure, for callers that already have
/// an address-checking function and do not want to declare a type.
///
/// ```swift
/// let validator = ClosureAddressValidator { address in
///     wallet.describeAddress(address)
/// }
/// ```
public struct ClosureAddressValidator: AddressValidator {
    private let validation: @Sendable (String) -> AddressDescriptor?

    /// Wraps `validate` as an ``AddressValidator``.
    /// - parameter validate: returns `nil` to reject the address, or the
    /// ``AddressDescriptor`` describing it.
    public init(_ validate: @escaping @Sendable (String) -> AddressDescriptor?) {
        self.validation = validate
    }

    /// Forwards to the wrapped closure.
    public func validate(_ address: String) -> AddressDescriptor? {
        validation(address)
    }
}
