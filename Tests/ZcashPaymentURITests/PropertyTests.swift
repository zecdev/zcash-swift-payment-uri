//
//  PropertyTests.swift
//  zcash-swift-payment-uri
//
//  Deterministic property-style round-trip tests (S16). Each law is run over
//  a fixed range of PRNG seeds via `@Test(arguments:)`; the same seeds
//  produce the same generated values on every run and every platform (see
//  `PropertyGenerators.swift`'s `SplitMix64`) — there is no `Date`/system
//  randomness anywhere in this file.
//
//  Reference inspiration: librustzcash `components/zip321/src/lib.rs`
//  `pub mod testing` (`arb_valid_memo`, `arb_zip321_payment`,
//  `arb_zip321_request`, lines ~864-955).
//

import Testing
@testable import ZcashPaymentURI

@Suite("PropertyRoundTrip")
struct PropertyTests {
    // A fixed, arbitrary offset per law so that distinct laws draw from
    // non-overlapping SplitMix64 streams even when their seed integers
    // coincide.
    private static func rng(law: UInt64, seed: Int) -> SplitMix64 {
        SplitMix64(seed: law &* 0x1000_0000_0000_0 &+ UInt64(seed))
    }

    // MARK: - Law 1: full round trip
    //
    // parse(uriString(from: r, default options)) == .success(r)
    // for every generated PaymentRequest r — including the shapes that render
    // in the leading-address form, which are no longer a separate result kind.

    @Test(arguments: 0..<300)
    func fullRoundTrip(_ seed: Int) throws {
        var rng = Self.rng(law: 1, seed: seed)
        let network = rng.choice(Gen.allNetworks)
        let request = Gen.indexedPaymentRequest(&rng, network: network)

        let uri = ZIP321.uriString(from: request)
        let parsed = ZIP321.parse(uri, expecting: network, validator: ReferenceAddressValidator.of(network))

        #expect(
            parsed == .success(request),
            "seed \(seed) (\(network)): round-trip law violated for uri: \(uri)"
        )
    }

    // MARK: - Law 2: NonNegativeAmount decimal round trip
    //
    // NonNegativeAmount.zec(z.decimalString()) == z for every generated NonNegativeAmount z.

    @Test(arguments: 0..<300)
    func zatoshiDecimalRoundTrip(_ seed: Int) throws {
        var rng = Self.rng(law: 2, seed: seed)
        let z = Gen.zatoshi(&rng)

        let reparsed = try NonNegativeAmount.zec(z.decimalString()).get()

        #expect(reparsed == z, "seed \(seed): NonNegativeAmount round-trip failed for \(z.decimalString())")
    }

    // MARK: - Law 3: MemoBytes base64url round trip
    //
    // MemoBytes(base64URL: m.toBase64URL()) == m for every generated MemoBytes m.

    @Test(arguments: 0..<300)
    func memoBytesBase64URLRoundTrip(_ seed: Int) throws {
        var rng = Self.rng(law: 3, seed: seed)
        let memo = Gen.memoBytes(&rng)

        let reparsed = try MemoBytes(base64URL: memo.toBase64URL())

        #expect(reparsed == memo, "seed \(seed): MemoBytes round-trip failed")
    }

    // MARK: - Law 4: QcharCodec round trip
    //
    // QcharCodec.decode(QcharCodec.encode(s)) == s for arbitrary unicode strings.

    @Test(arguments: 0..<300)
    func qcharCodecRoundTrip(_ seed: Int) {
        var rng = Self.rng(law: 4, seed: seed)
        let s = Gen.unicodeString(&rng)

        let decoded = QcharCodec.decode(QcharCodec.encode(s))

        #expect(decoded == s, "seed \(seed): qchar round-trip failed for \(s.debugDescription)")
    }

    // MARK: - Law 5: paramindex preservation
    //
    // A request with sparse indices round-trips preserving indexedPayments
    // exactly — both the set of indices and, at each index, the payment.

    @Test(arguments: 0..<200)
    func paramIndexPreservation(_ seed: Int) throws {
        var rng = Self.rng(law: 5, seed: seed)
        let network = rng.choice(Gen.allNetworks)
        let request = Gen.indexedPaymentRequest(&rng, network: network)

        let uri = ZIP321.uriString(from: request)
        let reparsedRequest = try ZIP321.parse(uri, expecting: network, validator: ReferenceAddressValidator.of(network)).get()

        let originalIndices = request.indexedPayments.map(\.index)
        let reparsedIndices = reparsedRequest.indexedPayments.map(\.index)
        #expect(originalIndices == reparsedIndices, "seed \(seed): paramindex set/order not preserved")

        for (original, reparsed) in zip(request.indexedPayments, reparsedRequest.indexedPayments) {
            #expect(original.index == reparsed.index)
            #expect(original.payment == reparsed.payment, "seed \(seed): payment at index \(original.index) changed across round trip")
        }
    }

    // MARK: - Law 6: the parsed model never distinguishes the two spellings
    //
    // parse("zcash:<addr>") == parse("zcash:?address=<addr>") for every
    // generated recipient. The URI syntax is a rendering choice; it must not
    // leak into the model.

    @Test(arguments: 0..<200)
    func singleRecipientSpellingsAgree(_ seed: Int) throws {
        var rng = Self.rng(law: 6, seed: seed)
        let network = rng.choice(Gen.allNetworks)
        let validator = ReferenceAddressValidator.of(network)
        let recipient = Gen.recipient(&rng, network: network)

        let leading = ZIP321.parse("zcash:\(recipient.value)", expecting: network, validator: validator)
        let labeled = ZIP321.parse("zcash:?address=\(recipient.value)", expecting: network, validator: validator)

        #expect(
            leading == labeled,
            "seed \(seed) (\(network)): the two single-recipient spellings parsed differently for \(recipient.value)"
        )
    }

    // MARK: - Law 7: `otherParams` is always an array
    //
    // Every payment of every generated request reports an ARRAY of other
    // params. There is no absent/empty split left to observe, at construction
    // or after a round trip.

    @Test(arguments: 0..<200)
    func otherParamsAreAlwaysAnArray(_ seed: Int) throws {
        var rng = Self.rng(law: 7, seed: seed)
        let network = rng.choice(Gen.allNetworks)
        let request = Gen.indexedPaymentRequest(&rng, network: network)

        let uri = ZIP321.uriString(from: request)
        let reparsed = try ZIP321.parse(uri, expecting: network, validator: ReferenceAddressValidator.of(network)).get()

        for (original, roundTripped) in zip(request.payments, reparsed.payments) {
            // Same count, same order, same contents — and never "absent".
            #expect(original.otherParams == roundTripped.otherParams, "seed \(seed): other params changed across the round trip")
        }
    }

    // MARK: - Law 8 (adversarial): duplicate other-param names never construct
    //
    // A `Payment` whose other-param names repeat must be rejected, so that no
    // `Payment` can exist which renders to a URI the parser would reject as a
    // duplicate parameter.

    @Test(arguments: 0..<200)
    func duplicateOtherParamNamesNeverConstruct(_ seed: Int) throws {
        var rng = Self.rng(law: 8, seed: seed)
        let network = rng.choice(Gen.allNetworks)
        let recipient = Gen.recipient(&rng, network: network)
        let (params, repeated) = Gen.duplicatedOtherParams(&rng)

        let result = Payment.create(
            recipientAddress: recipient,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: params
        )

        #expect(
            result == .failure(.duplicateParameter(name: repeated, index: nil)),
            "seed \(seed): duplicate other-param '\(repeated)' was accepted (params: \(params.map(\.name)))"
        )

        // The builder path must agree: it feeds the same list to Payment.create.
        var builder = Payment.Builder(recipient: recipient)
        for param in params {
            builder = builder.otherParam(name: param.name, value: param.value)
        }

        #expect(
            builder.build() == .failure(.duplicateParameter(name: repeated, index: nil)),
            "seed \(seed): the builder accepted duplicate other-param '\(repeated)'"
        )
    }
}
