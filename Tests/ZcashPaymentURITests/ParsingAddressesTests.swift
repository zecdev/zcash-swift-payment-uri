//
//  ParsingAddressesTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in  2025.
//

import Testing
@testable import ZcashPaymentURI

@Suite("ParsingAddresses")
struct ParsingAddressesTests {
    /// `zcash:<addr>` is the leading-address SPELLING of a one-payment request;
    /// it parses to an ordinary `PaymentRequest`, identical to the one produced
    /// by the labeled form (see `legacyAndLabeledSingleRecipientAreEqual`).
    @Test func parsesLegacySingleRecipient() throws {
        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let validURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let expected = try PaymentRequest(
            payments: [
                try Payment.create(
                    recipientAddress: recipient,
                    amount: nil,
                    memo: nil,
                    label: nil,
                    message: nil,
                    otherParams: []
                ).get()
            ]
        )

        #expect(try ZIP321.parse(validURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get() == expected)
    }

    /// ZIP-321 URI Semantics: `zcash:<addr>` and `zcash:?address=<addr>` denote
    /// the SAME request. Which spelling the URI used is a syntax choice and MUST
    /// NOT be observable in the parsed model — matching the reference
    /// implementation, whose `TransactionRequest` has no notion of the
    /// difference either.
    @Test func legacyAndLabeledSingleRecipientAreEqual() throws {
        let address = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let leadingForm = try ZIP321.parse(
            "zcash:\(address)",
            expecting: .testnet,
            validator: ReferenceAddressValidator.testnet
        ).get()

        let labeledForm = try ZIP321.parse(
            "zcash:?address=\(address)",
            expecting: .testnet,
            validator: ReferenceAddressValidator.testnet
        ).get()

        #expect(leadingForm == labeledForm)

        // …and the same holds once the payment carries other parameters.
        let leadingWithAmount = try ZIP321.parse(
            "zcash:\(address)?amount=1.2345",
            expecting: .testnet,
            validator: ReferenceAddressValidator.testnet
        ).get()

        let labeledWithAmount = try ZIP321.parse(
            "zcash:?address=\(address)&amount=1.2345",
            expecting: .testnet,
            validator: ReferenceAddressValidator.testnet
        ).get()

        #expect(leadingWithAmount == labeledWithAmount)
    }

    @Test func noLeadingAddressURIParses() throws {
        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let validURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let result = try ZIP321.parse(validURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        // The request's only payment sits at paramindex 1; the parsed model
        // preserves that index.
        #expect(
            result
            == (
                try PaymentRequest(
                    indexedPayments: [
                        (
                            index: 1,
                            payment: try Payment.create(
                                recipientAddress: recipient,
                                amount: try NonNegativeAmount.zec("1.0001").get(),
                                memo: nil,
                                label: nil,
                                message: "lunch",
                                otherParams: []
                            ).get()
                        )
                    ]
                )
            )
        )
    }

    // MARK: Invalid URIs
    @Test func throwsWhenParsingSproutAddressesOnIndexedParameter() throws {
        let invalidURI = "zcash:?address.1=zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y&amount.1=1.0001&message.1=lunch"
        // Sprout recipients are rejected; the sealed taxonomy folds this into
        // the generic `invalidAddress` discriminant.
        let result = ZIP321.parse(invalidURI, expecting: .mainnet, validator: ReferenceAddressValidator.mainnet)
        guard case .failure(.invalidAddress) = result else {
            Issue.record("expected invalidAddress but got \(result)")
            return
        }
    }

    @Test func throwsWhenParsingSproutAddressesOnNonIndexedParameter() throws {
        let invalidURI = "zcash:zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y?amount.1=1.0001&message.1=lunch"
        let result = ZIP321.parse(invalidURI, expecting: .mainnet, validator: ReferenceAddressValidator.mainnet)
        guard case .failure(.invalidAddress) = result else {
            Issue.record("expected invalidAddress but got \(result)")
            return
        }
    }

    @Test func throwsWhenParsingInvalidBase64() throws {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=a$bcdefg&message=Thank%20you%20for%20your%20purchase"

        let result = ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet)
        guard case .failure(.invalidBase64) = result else {
            Issue.record("expected invalidBase64 but got \(result)")
            return
        }
    }

    /// invalid; missing `address=`/
    @Test func throwsWhenRecipientIsMissingNoParamIndex() {
        let invalidURI = "zcash:?amount=3491405.05201255&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=5740296.87793245"

        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.recipientMissing(index: nil)))
    }

    /// invalid; missing `address.1=`/
    @Test func throwsWhenRecipientIsMissingWithParamIndex() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=1&amount.1=2&address.2=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        // paramindex 1 has an `amount` but no matching `address`.
        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.recipientMissing(index: 1)))
    }

    // MARK: Partial Parser - Leading Address

    @Test func maybeLeadingAddress() throws {
        let validURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1.0001&message=lunch"

        let result = Parser.splitLeadingAddress(validURI)

        #expect(result.address == "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")
        #expect(result.rest == "?amount=1.0001&message=lunch")

        let noLeadingAddressValidURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let partial = Parser.splitLeadingAddress(noLeadingAddressValidURI)

        #expect(partial.address == "")

        #expect(
            partial.rest
            == "?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"
        )
    }

    @Test func noLeadingAddressParsesPastPrefix() throws {
        let validURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let result = Parser.splitLeadingAddress(validURI)

        #expect(result.address == "")
        #expect(result.rest == "?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch")
    }

    @Test func leadingAddressWithoutQueryHasNilRest() throws {
        let legacyURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let result = Parser.splitLeadingAddress(legacyURI)

        #expect(result.address == "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")
        #expect(result.rest == nil)
    }

    @Test func thatValidLeadingAddressesAreParsed() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(
            validAddressURI,
            network: .testnet,
            validator: ReferenceAddressValidator.testnet
        )

        #expect(result.1 == expected)
    }

    @Test func thatValidLeadingAddressesAreParsedWithAdditionalParams() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let expected = IndexedParameter(index: 0, param: .address(recipient))
        let rest = "?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        let result = try Parser.leadingAddress(validAddressURI, network: .testnet, validator: ReferenceAddressValidator.testnet)

        #expect(result.1 == expected)
        #expect(result.0 == rest[...])
    }

    @Test func thatInvalidLeadingAddressesThrowError() throws {
        let invalidAddrURI = "zcash:tm000HTpdKMw5it8YDspUXSMGQyFwovpU"

        #expect(throws: (any Error).self) {
            try Parser.leadingAddress(invalidAddrURI, network: .testnet, validator: ReferenceAddressValidator.testnet)
        }
    }

    @Test func thatLeadingAddressFunctionParserLegacyURI() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(validAddressURI, network: .testnet, validator: ReferenceAddressValidator.testnet)

        #expect(result.1 == expected)
        #expect(result.0 == nil)
    }

    @Test func zcashParameterCreatesValidAddress() throws {
        let value = "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"

        let recipient = try #require(RecipientAddress(value: value, validator: ReferenceAddressValidator.mainnet))

        #expect(
            IndexedParameter(index: 0, param: .address(recipient))
            == (try Parser.zcashParameter(name: "address", index: nil, value: value, network: .mainnet, validator: ReferenceAddressValidator.mainnet))
        )
    }
}
