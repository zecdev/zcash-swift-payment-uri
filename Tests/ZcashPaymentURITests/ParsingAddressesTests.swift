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
    @Test func parsesLegacySingleRecipient() throws {
        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet))

        let validURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let expected = ParserResult.legacy(recipient)

        #expect(try ZIP321.request(from: validURI, context: .testnet) == expected)
    }

    @Test func noLeadingAddressURIParses() throws {
        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet))

        let validURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let result = try ZIP321.request(from: validURI, context: .testnet)

        #expect(
            result
            == ParserResult.request(
                try PaymentRequest(
                    payments: [
                        try Payment(
                            recipientAddress: recipient,
                            amount: try Amount(string: "1.0001"),
                            memo: nil,
                            label: nil,
                            message: "lunch",
                            otherParams: nil
                        )
                    ]
                )
            )
        )
    }

    // MARK: Invalid URIs
    @Test func throwsWhenParsingSproutAddressesOnIndexedParameter() throws {
        let invalidURI = "zcash:?address.1=zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y&amount.1=1.0001&message.1=lunch"
        #expect {
            try ZIP321.request(from: invalidURI, context: .mainnet, validatingRecipients: ParserContext.mainnet.isValid)
        } throws: { error in
            guard case ZIP321.Errors.sproutRecipientsNotAllowed = error else { return false }
            return true
        }
    }

    @Test func throwsWhenParsingSproutAddressesOnNonIndexedParameter() throws {
        let invalidURI = "zcash:zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y?amount.1=1.0001&message.1=lunch"
        #expect {
            try ZIP321.request(from: invalidURI, context: .mainnet, validatingRecipients: ParserContext.mainnet.isValid)
        } throws: { error in
            guard case ZIP321.Errors.sproutRecipientsNotAllowed = error else { return false }
            return true
        }
    }

    @Test func throwsWhenParsingInvalidBase64() throws {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=a$bcdefg&message=Thank%20you%20for%20your%20purchase"

        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.invalidBase64 = error else { return false }
            return true
        }
    }

    /// invalid; missing `address=`/
    @Test func throwsWhenRecipientIsMissingNoParamIndex() {
        let invalidURI = "zcash:?amount=3491405.05201255&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=5740296.87793245"

        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.recipientMissing(nil) = error else { return false }
            return true
        }
    }

    /// invalid; missing `address.1=`/
    @Test func throwsWhenRecipientIsMissingWithParamIndex() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=1&amount.1=2&address.2=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.recipientMissing(1) = error else { return false }
            return true
        }
    }

    // MARK: Partial Parser - Leading Address

    @Test func maybeLeadingAddress() throws {
        let validURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1.0001&message=lunch"

        let result = try Parser.maybeLeadingAddress.parse(validURI)

        #expect(result.0 == "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")
        #expect(result.1 == "?amount=1.0001&message=lunch")

        let noLeadingAddressValidURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let partial = try Parser.maybeLeadingAddress.parse(noLeadingAddressValidURI[...])

        #expect(partial.0 == "")

        #expect(
            partial.1
            == "?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"
        )
    }

    @Test func noLeadingAddressParsesPastPrefix() throws {
        let validURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let result = try Parser.maybeLeadingAddress.parse(validURI)

        #expect(result.0 == "")
        #expect(result.1 == "?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch")
    }

    @Test func thatValidLeadingAddressesAreParsed() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet))

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(
            validAddressURI,
            context: .testnet,
            validating: Parser.onlyCharsetValidation
        )

        #expect(result.1 == expected)
    }

    @Test func thatValidLeadingAddressesAreParsedWithAdditionalParams() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet))

        let expected = IndexedParameter(index: 0, param: .address(recipient))
        let rest = "?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        let result = try Parser.leadingAddress(validAddressURI, context: .testnet, validating: Parser.onlyCharsetValidation)

        #expect(result.1 == expected)
        #expect(result.0 == rest[...])
    }

    @Test func thatInvalidLeadingAddressesThrowError() throws {
        let invalidAddrURI = "zcash:tm000HTpdKMw5it8YDspUXSMGQyFwovpU"

        #expect(throws: (any Error).self) {
            try Parser.leadingAddress(invalidAddrURI, context: .testnet, validating: Parser.onlyCharsetValidation)
        }
    }

    @Test func thatLeadingAddressFunctionParserLegacyURI() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet))

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(validAddressURI, context: .testnet, validating: Parser.onlyCharsetValidation)

        #expect(result.1 == expected)
        #expect(result.0 == nil)
    }

    @Test func zcashParameterCreatesValidAddress() throws {
        let query = "address"[...]
        let value = "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"[...]

        let recipient = try #require(RecipientAddress(value: String(value), context: .mainnet, validating: nil))

        #expect(
            IndexedParameter(index: 0, param: .address(recipient))
            == (try Parser.zcashParameter(
                (query, nil, value),
                context: .mainnet,
                validating: Parser.onlyCharsetValidation
            ))
        )
    }
}
