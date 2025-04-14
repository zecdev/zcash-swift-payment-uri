//
//  ParsingAddressesTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in  2025.
//    
   

import XCTest
import Parsing
import CustomDump
@testable import ZcashPaymentURI

final class ParsingAddressesTests: XCTestCase {
    func testParsesLegacySingleRecipient() throws {
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("failed to create valid recipient")
            return
        }

        let validURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let expected = ParserResult.legacy(recipient)

        XCTAssertEqual(
            try ZIP321.request(from: validURI, context: .testnet),
            expected
        )
    }

    func testNoLeadingAddressURIParses() throws {
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("unable to create Recipient")
            return
        }

        let validURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let result = try ZIP321.request(from: validURI, context: .testnet)

        XCTAssertEqual(
            result,
            ParserResult.request(
                try PaymentRequest(
                    payments: [
                        try Payment(
                            recipientAddress: recipient,
                            amount: try Amount(string:"1.0001"),
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
    func testThrowsWhenParsingSproutAddressesOnIndexedParameter() throws {
        let invalidURI = "zcash:?address.1=zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y&amount.1=1.0001&message.1=lunch"
        XCTAssertThrowsError(
            try ZIP321
                .request(from: invalidURI, context: .mainnet, validatingRecipients: ParserContext.mainnet.isValid),
            "should have thrown \(String(describing: ZIP321.Errors.sproutRecipientsNotAllowed)) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.sproutRecipientsNotAllowed:
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.sproutRecipientsNotAllowed))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    func testThrowsWhenParsingSproutAddressesOnNonIndexedParameter() throws {
        let invalidURI = "zcash:zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y?amount.1=1.0001&message.1=lunch"
        XCTAssertThrowsError(
            try ZIP321
                .request(from: invalidURI, context: .mainnet, validatingRecipients: ParserContext.mainnet.isValid),
            "should have thrown \(String(describing: ZIP321.Errors.sproutRecipientsNotAllowed)) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.sproutRecipientsNotAllowed:
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.sproutRecipientsNotAllowed))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    func testThrowsWhenParsingInvalidBase64() throws {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=a$bcdefg&message=Thank%20you%20for%20your%20purchase"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
            "should have thrown \(String(describing: ZIP321.Errors.invalidBase64)) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.invalidBase64:
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.invalidBase64))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; missing `address=`/
    func testThrowsWhenRecipientIsMissingNoParamIndex() {
        let invalidURI = "zcash:?amount=3491405.05201255&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=5740296.87793245"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
            "should have thrown \(String(describing: ZIP321.Errors.recipientMissing(nil))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.recipientMissing(nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.recipientMissing(nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; missing `address.1=`/
    func testThrowsWhenRecipientIsMissingWithParamIndex() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=1&amount.1=2&address.2=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
            "should have thrown \(String(describing: ZIP321.Errors.recipientMissing(1))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.recipientMissing(1):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.recipientMissing(1)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    // MARK: Partial Parser - Leading Address

    func testMaybeLeadingAddress() throws {
        let validURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1.0001&message=lunch"

        let result = try Parser.maybeLeadingAddress.parse(validURI)

        XCTAssertEqual(result.0, "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")
        XCTAssertEqual(result.1, "?amount=1.0001&message=lunch")

        let noLeadingAddressValidURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let partial = try Parser.maybeLeadingAddress.parse(noLeadingAddressValidURI[...])

        XCTAssertEqual(partial.0, "")

        XCTAssertNoDifference(
            partial.1,  "?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch")

    }

    func testNoLeadingAddressParsesPastPrefix() throws {
        let validURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let result = try Parser.maybeLeadingAddress.parse(validURI)

        XCTAssertEqual(result.0, "")
        XCTAssertEqual(result.1, "?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch")
    }

    func testThatValidLeadingAddressesAreParsed() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(
            validAddressURI,
            context: .testnet,
            validating: Parser.onlyCharsetValidation
        )

        XCTAssertEqual(result.1, expected)
    }

    func testThatValidLeadingAddressesAreParsedWithAdditionalParams() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = IndexedParameter(index: 0, param: .address(recipient))
        let rest = "?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        let result = try Parser.leadingAddress(validAddressURI, context: .testnet, validating: Parser.onlyCharsetValidation)

        XCTAssertEqual(result.1, expected)
        XCTAssertEqual(result.0, rest[...])
    }

    func testThatInvalidLeadingAddressesThrowError() throws {
        let invalidAddrURI = "zcash:tm000HTpdKMw5it8YDspUXSMGQyFwovpU"

        XCTAssertThrowsError(try Parser.leadingAddress(invalidAddrURI, context: .testnet, validating: Parser.onlyCharsetValidation))
    }

    func testThatLeadingAddressFunctionParserLegacyURI() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(validAddressURI,context: .testnet, validating: Parser.onlyCharsetValidation)

        XCTAssertNoDifference(result.1, expected)
        XCTAssertEqual(result.0, nil)
    }

    func testZcashParameterCreatesValidAddress() throws {
        let query = "address"[...]
        let value = "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"[...]

        guard let recipient = RecipientAddress(value: String(value), context: .mainnet, validating: nil) else {
            XCTFail("could not create recipient address")
            return
        }

        XCTAssertNoDifference(
            IndexedParameter(index: 0, param: .address(recipient)),
            try Parser.zcashParameter(
                (query, nil, value),
                context: .mainnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

}
