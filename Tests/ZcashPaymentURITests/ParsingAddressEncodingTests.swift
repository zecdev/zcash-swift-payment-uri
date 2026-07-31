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
    // MARK: Address parameters resolve through the injected validator
    @Test func parserThrowsWhenTheValidatorRejectsABech32Address() throws {
        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: "ztestsapling10yy211111qkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", index: 0, network: .testnet, validator: ReferenceAddressValidator.testnet)
        }
    }

    @Test func parserThrowsWhenTheValidatorRejectsABase58Address() throws {
        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: "tm000HTpdKMw5it8YDspUXSMGQyFwovpU", index: 0, network: .testnet, validator: ReferenceAddressValidator.testnet)
        }

        #expect(throws: (any Error).self) {
            try Param.from(queryKey: "address", value: "u1bbbbfl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", index: 0, network: .testnet, validator: ReferenceAddressValidator.testnet)
        }
    }

    @Test func validatorAcceptedBase58AddressesAreParsed() throws {
        let recipientT = try #require(RecipientAddress(value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU", validator: ReferenceAddressValidator.testnet))

        #expect(
            try Param.from(
                queryKey: "address",
                value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
                index: 0,
                network: .testnet,
                validator: ReferenceAddressValidator.testnet
            )
            == Param.address(recipientT)
        )

        let recipientU = try #require(RecipientAddress(value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", validator: ReferenceAddressValidator.mainnet))

        #expect(
            try Param.from(
                queryKey: "address",
                value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je",
                index: 0,
                network: .mainnet,
                validator: ReferenceAddressValidator.mainnet
            )
            == Param.address(recipientU)
        )
    }

    @Test func validatorAcceptedBech32AddressesAreParsed() throws {
        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        #expect(
            try Param.from(
                queryKey: "address",
                value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                index: 0,
                network: .testnet,
                validator: ReferenceAddressValidator.testnet
            )
            == Param.address(recipient)
        )
    }

    @Test func thatTEXAddressesAreAcceptedByTheReferenceValidator() throws {
        let tex = "tex1s2rt77ggv6q989lr49rkgzmh5slsksa9khdgte"

        #expect(
            RecipientAddress(value: tex, validator: ReferenceAddressValidator.mainnet) != nil
        )
    }

    @Test func thatNonAddressGarbageIsRejectedByTheValidator() throws {
        let invalidRequest = "zcash:tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpUʔamount 1ꓸ234?message=Thanks%20for%20your%20payment%20for%20the%20correct%20&amount=20&Have=%20a%20nice%20day"

        #expect {
            try ZIP321.request(from: invalidRequest, expecting: .testnet, validator: ReferenceAddressValidator.testnet)
        } throws: { error in
            guard case ZIP321.Errors.invalidAddress(nil) = error else { return false }
            return true
        }
    }
}
