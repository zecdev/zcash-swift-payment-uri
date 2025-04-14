//
//  ParsingAddressEncodingTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in  2025.
//    
   

import XCTest
import Parsing
import CustomDump
@testable import ZcashPaymentURI

final class ParsingAddressEncodingTests: XCTestCase {

    // MARK: Partial Parsers - Recipient Addresses
    func testParserThrowsOnInvalidRecipientCharsetBech32() throws {
        XCTAssertThrowsError(try Param.from(queryKey: "address", value: "ztestsapling10yy211111qkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", index: 0, context: .testnet, validating: Parser.onlyCharsetValidation))
    }

    func testParserThrowsOnInvalidRecipientCharsetBase58() throws {
        XCTAssertThrowsError(try Param.from(queryKey: "address", value: "tm000HTpdKMw5it8YDspUXSMGQyFwovpU", index: 0, context: .testnet, validating: Parser.onlyCharsetValidation))

        XCTAssertThrowsError(try Param.from(queryKey: "address", value: "u1bbbbfl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", index: 0, context: .testnet, validating: Parser.onlyCharsetValidation))
    }

    func testValidCharsetBase58AreParsed() throws {
        guard let recipientT = RecipientAddress(value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU", context: .testnet) else {
            XCTFail("Recipient could not be created")
            return
        }

        XCTAssertNoDifference(
            try Param.from(
                queryKey: "address",
                value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
                index: 0,
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            ),
            Param.address(recipientT)
        )

        guard let recipientU = RecipientAddress(value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", context: .mainnet) else {
            XCTFail("Unified Recipient couldn't be created")
            return
        }

        XCTAssertNoDifference(
            try Param.from(
                queryKey: "address",
                value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je",
                index: 0, context: .mainnet,
                validating: Parser.onlyCharsetValidation
            ),
            Param.address(recipientU)
        )
    }

    func testValidCharsetBech32AreParsed() throws {
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("Recipient could not be created")
            return
        }

        XCTAssertNoDifference(
            try Param.from(
                queryKey: "address",
                value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                index: 0, context: .testnet,
                validating: Parser.onlyCharsetValidation
            ),
            Param.address(recipient)
        )
    }

    func testCharsetValidationFailsOnInvalidUnifiedAddress() throws {
        XCTAssertThrowsError(try Parser.unifiedEncodingCharsetParser
            .parse("u1bbbbbfl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"))
    }

    func testCharsetValidationFailsOnInvalidSaplingAddress() throws {
        XCTAssertThrowsError(try Parser.saplingEncodingCharsetParser
            .parse("ztestsapling10yy211111qkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"))
    }

    func testCharsetValidationFailsOnInvalidTransparentAddress() throws {
        XCTAssertThrowsError(try Parser.saplingEncodingCharsetParser
            .parse("tm000HTpdKMw5it8YDspUXSMGQyFwovpU"))
    }

    func testCharsetValidationPassesOnValidTransparentAddress() throws {
        let address = try Parser.transparentEncodingCharsetParser
            .parse("tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU")
        XCTAssertNoDifference("tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU", address)
    }

    func testCharsetValidationPassesOnValidSaplingAddress() throws {
        let expected = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        let address = try Parser.saplingEncodingCharsetParser
            .parse(expected)

        XCTAssertNoDifference("0yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", address)
    }

    func testCharsetValidationPassesOnValidUnifiedAddress() throws {
        let expected = "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"
        let address = try Parser.unifiedEncodingCharsetParser
            .parse(expected)

        XCTAssertNoDifference("fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", address)
    }

    func testThatTEXAddressCharsetIsValidated() throws {
        let tex = "tex1s2rt77ggv6q989lr49rkgzmh5slsksa9khdgte"

        XCTAssertNotNil(
            RecipientAddress(
                value: tex,
                context: .mainnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

    func testThatCharactedAllowCharacterSetIsCheckedForAddresses() throws {
        let invalidRequest = "zcash:tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpUʔamount 1ꓸ234?message=Thanks%20for%20your%20payment%20for%20the%20correct%20&amount=20&Have=%20a%20nice%20day"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidRequest, context: .testnet),
            "should have thrown \(String(describing: ZIP321.Errors.invalidAddress(nil))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.invalidAddress(nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.invalidAddress(nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

}
