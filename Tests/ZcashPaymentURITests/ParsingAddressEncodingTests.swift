//
//  ParsingAddressEncodingTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in  2025.
//

import Testing
@testable import ZcashPaymentURI

@Suite("ParsingAddressEncoding")
struct ParsingAddressEncodingTests {
    // MARK: Partial Parsers - Recipient Addresses
    @Test func parserThrowsOnInvalidRecipientCharsetBech32() throws {
        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: "ztestsapling10yy211111qkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", index: 0, context: .testnet, validating: Parser.onlyCharsetValidation)
        }
    }

    @Test func parserThrowsOnInvalidRecipientCharsetBase58() throws {
        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: "tm000HTpdKMw5it8YDspUXSMGQyFwovpU", index: 0, context: .testnet, validating: Parser.onlyCharsetValidation)
        }

        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: "u1bbbbfl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", index: 0, context: .testnet, validating: Parser.onlyCharsetValidation)
        }
    }

    @Test func validCharsetBase58AreParsed() throws {
        let recipientT = try #require(RecipientAddress(value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU", context: .testnet))

        #expect(
            try Param.from(
                queryKey: "address",
                value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
                index: 0,
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
            == Param.address(recipientT)
        )

        let recipientU = try #require(RecipientAddress(value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", context: .mainnet))

        #expect(
            try Param.from(
                queryKey: "address",
                value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je",
                index: 0, context: .mainnet,
                validating: Parser.onlyCharsetValidation
            )
            == Param.address(recipientU)
        )
    }

    @Test func validCharsetBech32AreParsed() throws {
        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet))

        #expect(
            try Param.from(
                queryKey: "address",
                value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                index: 0, context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
            == Param.address(recipient)
        )
    }

    @Test func charsetValidationFailsOnInvalidUnifiedAddress() throws {
        #expect(throws: (any Error).self) {
            try Parser.unifiedEncodingCharsetParser
                .parse("u1bbbbbfl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je")
        }
    }

    @Test func charsetValidationFailsOnInvalidSaplingAddress() throws {
        #expect(throws: (any Error).self) {
            try Parser.saplingEncodingCharsetParser
                .parse("ztestsapling10yy211111qkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")
        }
    }

    @Test func charsetValidationFailsOnInvalidTransparentAddress() throws {
        #expect(throws: (any Error).self) {
            try Parser.saplingEncodingCharsetParser
                .parse("tm000HTpdKMw5it8YDspUXSMGQyFwovpU")
        }
    }

    @Test func charsetValidationPassesOnValidTransparentAddress() throws {
        let address = try Parser.transparentEncodingCharsetParser
            .parse("tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU")
        #expect("tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU" == address)
    }

    @Test func charsetValidationPassesOnValidSaplingAddress() throws {
        let expected = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        let address = try Parser.saplingEncodingCharsetParser
            .parse(expected)

        #expect("0yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez" == address)
    }

    @Test func charsetValidationPassesOnValidUnifiedAddress() throws {
        let expected = "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"
        let address = try Parser.unifiedEncodingCharsetParser
            .parse(expected)

        #expect("fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je" == address)
    }

    @Test func thatTEXAddressCharsetIsValidated() throws {
        let tex = "tex1s2rt77ggv6q989lr49rkgzmh5slsksa9khdgte"

        #expect(
            RecipientAddress(
                value: tex,
                context: .mainnet,
                validating: Parser.onlyCharsetValidation
            ) != nil
        )
    }

    @Test func thatCharactedAllowCharacterSetIsCheckedForAddresses() throws {
        let invalidRequest = "zcash:tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpUʔamount 1ꓸ234?message=Thanks%20for%20your%20payment%20for%20the%20correct%20&amount=20&Have=%20a%20nice%20day"

        #expect {
            try ZIP321.request(from: invalidRequest, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.invalidAddress(nil) = error else { return false }
            return true
        }
    }
}
