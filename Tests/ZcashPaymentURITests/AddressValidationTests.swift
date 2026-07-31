//
//  AddressValidationTests.swift
//  zcash-swift-payment-uri
//
//  Two things are proven here.
//
//  1. The DELEGATION CONTRACT of the library: recipient-address validity and
//     capability classification come from the caller-supplied
//     ``AddressValidator`` and from nowhere else. The library neither
//     second-guesses an acceptance nor overrides a rejection — there is no
//     built-in check to compose with, so no "defense in depth" semantics to
//     reason about.
//
//  2. The behaviour of the TEST-ONLY ``ReferenceAddressValidator`` that the
//     rest of the suite (and the conformance runner) injects. It has to be
//     trustworthy for the corpus's checksum-corruption vectors to mean
//     anything, so its network x address-kind matrix is pinned down here.
//
//  Address provenance (every valid address is a published test vector or is
//  derived from one; none were invented):
//
//  - Sapling mainnet `zs1z7rejl…`: librustzcash
//    `components/zcash_address/src/lib.rs` doc examples.
//  - Sapling testnet `ztestsapling10yy2ex5…`: ZIP-321 spec examples /
//    librustzcash `components/zip321/src/lib.rs`; also the shared corpus
//    (`Tests/Vectors`).
//  - Sapling regtest `zregtestsapling1qqqqqq…`: ZIP-321 spec regtest example;
//    corpus vector `spec_valid_regtest_example`.
//  - Unified mainnet `u1l8xunez…`: zcash-test-vectors
//    `test-vectors/json/unified_address.json`, entry index 2, field
//    `unified_addr`.
//  - Unified testnet `utest10c5ku…` / regtest `uregtest15xk7vj…`:
//    librustzcash `components/zcash_address/src/encoding.rs` round-trip tests.
//  - TEX mainnet `tex1s2rt77…` (ZIP-320 test vector) and testnet
//    `textest1qyqszqgp…`: librustzcash
//    `components/zcash_address/src/encoding.rs`.
//  - TEX regtest `texregtest1s2rt77…`: derived — the 20-byte program of the
//    ZIP-320 mainnet vector `tex1s2rt77…` re-encoded as Bech32m with the
//    `texregtest` HRP (no regtest TEX vector is published anywhere).
//  - P2PKH mainnet `t1Hsc1LR…`, P2SH mainnet `t3JZcvsu…`, P2SH testnet
//    `t26YoyZ1…`: librustzcash `components/zcash_address/src/encoding.rs`.
//  - P2PKH testnet `tmEZhbWH…`: ZIP-321 spec examples / librustzcash
//    `components/zip321/src/lib.rs`.
//  - Sprout mainnet `zcU1Cd6z…`: known-good mainnet Sprout address (also used
//    by the corpus vector `invalid_address_sprout_mainnet`).
//  - Sprout testnet `ztJ1EWLK…`: librustzcash
//    `components/zcash_address/src/encoding.rs`.
//
//  Corrupted variants are the valid address with its last character
//  substituted within the respective charset, which is guaranteed to break
//  the checksum (BCH detects any single substitution; SHA-256d detects it
//  overwhelmingly).
//

import Testing
@testable import ZcashPaymentURI

@Suite("AddressValidation")
struct AddressValidationTests {
    // MARK: - Address fixtures

    static let saplingMainnet = "zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9slya"
    static let saplingTestnet = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
    static let saplingRegtest = "zregtestsapling1qqqqqqqqqqqqqqqqqqcguyvaw2vjk4sdyeg0lc970u659lvhqq7t0np6hlup5lusxle7505hlz3"

    static let unifiedMainnet = "u1l8xunezsvhq8fgzfl7404m450nwnd76zshscn6nfys7vyz2ywyh4cc5daaq0c7q2su5lqfh23sp7fkf3kt27ve5948mzpfdvckzaect2jtte308mkwlycj2u0eac077wu70vqcetkxf"
    static let unifiedTestnet = "utest10c5kutapazdnf8ztl3pu43nkfsjx89fy3uuff8tsmxm6s86j37pe7uz94z5jhkl49pqe8yz75rlsaygexk6jpaxwx0esjr8wm5ut7d5s"
    static let unifiedRegtest = "uregtest15xk7vj4grjkay6mnfl93dhsflc2yeunhxwdh38rul0rq3dfhzzxgm5szjuvtqdha4t4p2q02ks0jgzrhjkrav70z9xlvq0plpcjkd5z3"

    static let texMainnet = "tex1s2rt77ggv6q989lr49rkgzmh5slsksa9khdgte"
    static let texTestnet = "textest1qyqszqgpqyqszqgpqyqszqgpqyqszqgpfcjgfy"
    static let texRegtest = "texregtest1s2rt77ggv6q989lr49rkgzmh5slsksa990zqpk"

    static let p2pkhMainnet = "t1Hsc1LR8yKnbbe3twRp88p6vFfC5t7DLbs"
    static let p2shMainnet = "t3JZcvsuaXE6ygokL4XUiZSTrQBUoPYFnXJ"
    static let p2pkhTestnet = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
    static let p2shTestnet = "t26YoyZ1iPgiMEWL4zGUm74eVWfhyDMXzY2"

    static let sproutMainnet = "zcU1Cd6zYyZCd2VJF8yKgmzjxdiiU1rgTTjEwoN1CGUWCziPkUTXUjXmX7TMqdMNsTfuiGN1jQoVN4kGxUR4sAPN4XZ7pxb"
    static let sproutTestnet = "ztJ1EWLKcGwF2S4NA17pAJVdco8Sdkz4AQPxt1cLTEfNuyNswJJc2BbBqYrsRZsp31xbVZwhF7c7a2L9jsF3p3ZwRWpqqyS"

    static let allNetworks: [Network] = [.mainnet, .testnet, .regtest]

    // MARK: - The delegation contract

    /// The library owns the URI grammar and nothing else: a string that is not
    /// remotely a Zcash address parses fine when the caller's validator says it
    /// is a recipient. Nothing in the library gets a second opinion.
    @Test func theValidatorCanAcceptWhatIsNotEvenAnAddress() throws {
        let validator = ClosureAddressValidator { _ in
            AddressDescriptor(network: .mainnet, isTransparent: false, canReceiveMemos: true)
        }

        let result = try ZIP321.request(from: "zcash:not-an-address?amount=1", expecting: .mainnet, validator: validator)

        guard case .request(let request) = result else {
            Issue.record("expected a payment request")
            return
        }
        #expect(request.payments.first?.recipientAddress.value == "not-an-address")
    }

    /// Conversely, a rejection is final: a perfectly well-formed, checksum-valid
    /// address is invalid if the caller's validator says so.
    @Test func theValidatorCanRejectAWellFormedAddress() throws {
        let uri = "zcash:\(Self.saplingTestnet)?amount=1"

        #expect {
            try ZIP321.request(from: uri, expecting: .testnet, validator: ClosureAddressValidator { _ in nil })
        } throws: { error in
            guard case ZIP321.Errors.invalidAddress = error else { return false }
            return true
        }
    }

    /// The capabilities the library enforces (memo support, zero-valued
    /// transparent outputs) are read off the descriptor the validator returned,
    /// not derived from the address string.
    @Test func paymentRulesConsumeTheDescriptorNotTheAddressString() throws {
        // A `t1…`-looking string the validator declares memo-capable: the memo
        // is accepted, because the descriptor is what counts.
        let asShielded = ClosureAddressValidator { _ in
            AddressDescriptor(network: .mainnet, isTransparent: false, canReceiveMemos: true)
        }
        let memoURI = "zcash:\(Self.p2pkhMainnet)?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"

        #expect(throws: Never.self) {
            try ZIP321.request(from: memoURI, expecting: .mainnet, validator: asShielded)
        }

        // The same URI with a validator that reports a transparent recipient is
        // rejected by the ZIP-321 transparent-memo rule.
        let asTransparent = ClosureAddressValidator { _ in
            AddressDescriptor(network: .mainnet, isTransparent: true, canReceiveMemos: false)
        }

        #expect {
            try ZIP321.request(from: memoURI, expecting: .mainnet, validator: asTransparent)
        } throws: { error in
            guard case ZIP321.Errors.transparentMemoNotAllowed = error else { return false }
            return true
        }
    }

    /// Every address in the URI is offered to the validator, including the
    /// leading (unlabeled) one.
    @Test func everyRecipientIsOfferedToTheValidator() throws {
        let seen = Seen()
        let validator = ClosureAddressValidator { address in
            seen.record(address)
            return AddressDescriptor(network: .testnet, isTransparent: false, canReceiveMemos: true)
        }

        let uri = "zcash:\(Self.saplingTestnet)?amount=1&address.1=\(Self.p2pkhTestnet)&amount.1=2"
        _ = try ZIP321.request(from: uri, expecting: .testnet, validator: validator)

        #expect(seen.addresses == [Self.saplingTestnet, Self.p2pkhTestnet])
    }

    /// A tiny recorder for the address strings a validator was asked about.
    final class Seen: @unchecked Sendable {
        private(set) var addresses: [String] = []
        func record(_ address: String) { addresses.append(address) }
    }

    // MARK: - The expected network

    /// The library asks for ONE expected network. A validator that accepts an
    /// address but places it on another network makes the request invalid: the
    /// library compares `descriptor.network` against `expecting:` and reports
    /// `invalidAddress`.
    @Test func addressOnAnotherNetworkIsRejected() throws {
        // The validator accepts and reports testnet; the request expects mainnet.
        let testnetSayingValidator = ClosureAddressValidator { _ in
            AddressDescriptor(network: .testnet, isTransparent: false, canReceiveMemos: true)
        }

        #expect {
            try ZIP321.request(
                from: "zcash:\(Self.saplingTestnet)?amount=1",
                expecting: .mainnet,
                validator: testnetSayingValidator
            )
        } throws: { error in
            guard case ZIP321.Errors.invalidAddress = error else { return false }
            return true
        }

        // The same URI and validator against the matching network parses.
        #expect(throws: Never.self) {
            try ZIP321.request(
                from: "zcash:\(Self.saplingTestnet)?amount=1",
                expecting: .testnet,
                validator: testnetSayingValidator
            )
        }
    }

    /// The mismatch is reported for indexed recipients too, carrying the index.
    @Test func addressOnAnotherNetworkIsRejectedAtItsParamIndex() throws {
        let mixedNetworkValidator = ClosureAddressValidator { address in
            AddressDescriptor(
                network: address == Self.saplingTestnet ? .testnet : .mainnet,
                isTransparent: false,
                canReceiveMemos: true
            )
        }

        let uri = "zcash:?address=\(Self.saplingTestnet)&amount=1"
            + "&address.1=\(Self.saplingMainnet)&amount.1=2"

        #expect {
            try ZIP321.request(from: uri, expecting: .testnet, validator: mixedNetworkValidator)
        } throws: { error in
            guard case ZIP321.Errors.invalidAddress(.some(1)) = error else { return false }
            return true
        }
    }

    // MARK: - The reference (test-only) validator: valid matrix

    /// Every checksum-valid address of the matrix, the ONLY network on which it
    /// must validate, and the capabilities it must be reported with.
    static let validMatrix: [(address: String, network: Network, isTransparent: Bool, canReceiveMemos: Bool)] = [
        (saplingMainnet, .mainnet, false, true),
        (saplingTestnet, .testnet, false, true),
        (saplingRegtest, .regtest, false, true),
        (unifiedMainnet, .mainnet, false, true),
        (unifiedTestnet, .testnet, false, true),
        (unifiedRegtest, .regtest, false, true),
        (texMainnet, .mainnet, true, false),
        (texTestnet, .testnet, true, false),
        (texRegtest, .regtest, true, false),
        (p2pkhMainnet, .mainnet, true, false),
        (p2shMainnet, .mainnet, true, false),
        (p2pkhTestnet, .testnet, true, false),
        (p2shTestnet, .testnet, true, false),
        // Regtest transparent addresses use the TESTNET version bytes
        // (librustzcash zcash_protocol/src/constants/regtest.rs).
        (p2pkhTestnet, .regtest, true, false),
        (p2shTestnet, .regtest, true, false),
    ]

    @Test(arguments: validMatrix.indices)
    func validAddressAcceptedOnItsNetwork(_ index: Int) throws {
        let entry = Self.validMatrix[index]
        let descriptor = try #require(
            ReferenceAddressValidator.of(entry.network).validate(entry.address),
            "\(entry.address) should be valid on \(entry.network)"
        )

        #expect(descriptor.network == entry.network)
        #expect(descriptor.isTransparent == entry.isTransparent)
        #expect(descriptor.canReceiveMemos == entry.canReceiveMemos)
    }

    /// A checksum-valid address must be rejected by every network it does not
    /// belong to. (Transparent testnet addresses belong to BOTH testnet and
    /// regtest, which share version bytes.)
    @Test(arguments: allNetworks)
    func wrongNetworkRejected(_ network: Network) {
        let allowed = Set(
            Self.validMatrix
                .filter { $0.network == network }
                .map(\.address)
        )

        for entry in Self.validMatrix where !allowed.contains(entry.address) {
            #expect(
                ReferenceAddressValidator.of(network).validate(entry.address) == nil,
                "\(entry.address) must be invalid on \(network)"
            )
        }
    }

    // MARK: - The reference validator: rejections

    /// Valid addresses with the last character substituted within their
    /// charset: the structure and HRP/leading symbols remain plausible but
    /// the checksum no longer verifies.
    static let corrupted: [(address: String, network: Network)] = [
        // last char z → q (corpus vector invalid_address_sapling_bad_checksum)
        ("ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2keq", .testnet),
        // last char a → q
        (String(saplingMainnet.dropLast() + "q"), .mainnet),
        // last char 3 → q
        (String(saplingRegtest.dropLast() + "q"), .regtest),
        // last char f → q (corpus vector invalid_address_unified_mainnet_bad_checksum)
        (String(unifiedMainnet.dropLast() + "q"), .mainnet),
        (String(unifiedTestnet.dropLast() + "q"), .testnet),
        (String(unifiedRegtest.dropLast() + "q"), .regtest),
        // last char e → q
        (String(texMainnet.dropLast() + "q"), .mainnet),
        (String(texTestnet.dropLast() + "q"), .testnet),
        (String(texRegtest.dropLast() + "q"), .regtest),
        // last char U → 1 (corpus vector invalid_address_transparent_bad_checksum)
        ("tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovp1", .testnet),
        // last char s → t
        (String(p2pkhMainnet.dropLast() + "t"), .mainnet),
        // last char J → K
        (String(p2shMainnet.dropLast() + "K"), .mainnet),
        // last char 2 → 3
        (String(p2shTestnet.dropLast() + "3"), .testnet),
    ]

    @Test(arguments: corrupted.indices)
    func corruptedChecksumRejected(_ index: Int) {
        let (address, network) = Self.corrupted[index]
        #expect(
            ReferenceAddressValidator.of(network).validate(address) == nil,
            "corrupted \(address) must be invalid on \(network)"
        )
    }

    /// Sprout addresses have VALID Base58Check checksums and must still be
    /// rejected on every network: ZIP-321 disallows Sprout recipients.
    @Test(arguments: allNetworks)
    func sproutRejectedEvenWithValidChecksum(_ network: Network) {
        #expect(ReferenceAddressValidator.of(network).validate(Self.sproutMainnet) == nil)
        #expect(ReferenceAddressValidator.of(network).validate(Self.sproutTestnet) == nil)
    }

    @Test func mixedCaseBech32Rejected() {
        // Corpus vector invalid_address_sapling_mixed_case: '0yy' → '0YY'.
        let mixedSapling = "ztestsapling10YY2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        #expect(ReferenceAddressValidator.testnet.validate(mixedSapling) == nil)

        let mixedUnified = String(Self.unifiedMainnet.dropLast()) + "F"
        #expect(ReferenceAddressValidator.mainnet.validate(mixedUnified) == nil)

        // ALL-uppercase Bech32 is permitted by BIP-173 and by the reference
        // zcash_address parser.
        #expect(ReferenceAddressValidator.mainnet.validate(Self.texMainnet.uppercased()) != nil)
    }

    @Test(arguments: [
        "",
        "asdf",
        "zs1",
        "u1",
        "t1",
        "not an address at all",
        // valid bech32 checksum but an HRP no Zcash network uses (BIP-173 vector)
        "a12uel5l",
    ])
    func garbageRejectedOnAllNetworks(_ input: String) {
        for network in Self.allNetworks {
            #expect(
                ReferenceAddressValidator.of(network).validate(input) == nil,
                "'\(input)' must be invalid on \(network)"
            )
        }
    }

    // MARK: - RecipientAddress through the reference validator

    @Test func recipientAddressRejectsBadChecksum() {
        let corrupted = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2keq"
        #expect(RecipientAddress(value: corrupted, validator: ReferenceAddressValidator.testnet) == nil)
    }

    @Test func recipientAddressAcceptsChecksumValidAddress() {
        #expect(RecipientAddress(value: Self.saplingRegtest, validator: ReferenceAddressValidator.regtest) != nil)
        #expect(RecipientAddress(value: Self.texTestnet, validator: ReferenceAddressValidator.testnet) != nil)
    }
}
