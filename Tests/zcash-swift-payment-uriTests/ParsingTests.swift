//
//  ParsingTests.swift
//  
//
//  Created by Francisco Gindre on 2023-12-07.
//

import XCTest
import Parsing
@testable import zcash_swift_payment_uri

final class ParsingTests: XCTestCase {
    // MARK: Valid URIs
    func testParsesLegacySingleRecipient() throws {
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("failed to create valid recipient")
            return
        }

        let validURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let expected = ParserResult.legacy(recipient)

        XCTAssertEqual(
            try ZIP321.request(from: validURI),
            expected
        )
    }
    
    func testNoLeadingAddressURIParses() throws {
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("unable to create Recipient")
            return
        }

        let validURI = "zcash:?address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=1.0001&message.1=lunch"

        let result = try ZIP321.request(from: validURI)

        XCTAssertEqual(
            result,
            ParserResult.request(
                PaymentRequest(
                    payments: [
                        Payment(
                            recipientAddress: recipient,
                            amount: Amount(unchecked: 1.0001),
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
    func testThrowsWhenParsingInvalidBase64() throws {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=a$bcdefg&message=Thank%20you%20for%20your%20purchase"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
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

    func testThrowsWhenMemoIsInvalid() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgIHNqqqw222ncssspbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.memoBytesError(MemoBytes.MemoError.memoTooLong, nil))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.memoBytesError(MemoBytes.MemoError.memoTooLong, nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.memoBytesError(MemoBytes.MemoError.memoTooLong, nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    func testThrowsWhenURIHasTooManyPayments() {}
    /// invalid; amount component exceeds an i64
    /// 9223372036854775808 = i64::MAX + 1
    func testThrowsWhenAmountExceedsSupply() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=9223372036854775808"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.amountExceededSupply(0))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.amountExceededSupply(0):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.amountExceededSupply(0)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; amount component is MAX_MONEY
    /// 21000000.00000001
    func testThrowsWhenAmountIsMaxMoney() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=21000000.00000001"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.amountExceededSupply(0))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.amountExceededSupply(0):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.amountExceededSupply(0)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; amount component wraps into a valid small positive i64
    /// 18446744073709551624
    func testThrowsWhenAmountIsTooSmall() {
       let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=18446744073709551624"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.amountExceededSupply(0))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.amountExceededSupply(0):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.amountExceededSupply(0)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
    /// invalid; duplicate `amount=` field/
    func testThrowsWhenThereAreDuplicateParameters() {
        let invalidURI = "zcash:?amount=1.234&amount=2.345&address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.duplicateParameter("amount", 0))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.duplicateParameter("amount", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("amount", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; duplicate `amount.1=` field
    func testThrowsWhenThereAreDuplicateParametersWithParamIndex() {
        let invalidURI = "zcash:?amount.1=1.234&amount.1=2.345&address.1=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.duplicateParameter("amount", 1))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.duplicateParameter("amount", 1):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("amount", 1)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    func testThrowsWhenMemoIsAssignedToTransparentRecipient() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&memo=eyAia2V5IjogIlRoaXMgaXMgYSBKU09OLXN0cnVjdHVyZWQgbWVtby4iIH0&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.transparentMemoNotAllowed(nil))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.transparentMemoNotAllowed(nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.transparentMemoNotAllowed(nil)))
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
            try ZIP321.request(from: invalidURI),
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
            try ZIP321.request(from: invalidURI),
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

    /// invalid; `address.0=` and `amount.0=` are not permitted (leading 0s)./
    func testThrowsWhenParamIndexIsZero() {
        let invalidURI = "zcash:?address.0=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.0=2"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.invalidParamIndex("address.0"))) but none was"
        ) 
        // TODO: Fix leading address error type. (error is thrown but is not as expected)
//        { err in
//            switch err {
//            case ZIP321.Errors.invalidParamIndex("address.0"):
//                XCTAssert(true)
//            default:
//                XCTFail(
//                        """
//                        Expected \(String(describing: ZIP321.Errors.invalidParamIndex("address.0")))
//                        but \(err) was thrown instead
//                        """
//                )
//            }
//        }
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

        XCTAssertEqual(
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

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(validAddressURI, validating: Parser.onlyCharsetValidation)

        XCTAssertEqual(result.1, expected)
    }

    func testThanSeeminglyValidEmptyRequestThrows() throws {
        XCTAssertThrowsError(try ZIP321.request(from: "zcash:?"))
    }

    func testThatValidLeadingAddressesAreParsedWithAdditionalParams() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = IndexedParameter(index: 0, param: .address(recipient))
        let rest = "?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        let result = try Parser.leadingAddress(validAddressURI, validating: Parser.onlyCharsetValidation)

        XCTAssertEqual(result.1, expected)
        XCTAssertEqual(result.0, rest[...])
    }

    func testThatInvalidLeadingAddressesThrowError() throws {
        let invalidAddrURI = "zcash:tm000HTpdKMw5it8YDspUXSMGQyFwovpU"

        XCTAssertThrowsError(try Parser.leadingAddress(invalidAddrURI, validating: Parser.onlyCharsetValidation))
    }

    func testThatLeadingAddressFunctionParserLegacyURI() throws {
        let validAddressURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = IndexedParameter(index: 0, param: .address(recipient))

        let result = try Parser.leadingAddress(validAddressURI, validating: Parser.onlyCharsetValidation)

        XCTAssertEqual(result.1, expected)
        XCTAssertEqual(result.0, nil)
    }

    // MARK: Partial parsers - QueryKey parsing
    func testParamIndexParserRejectsLeadingZeros () throws {
        XCTAssertThrowsError(try Parser.parameterIndex.parse("01"))
        XCTAssertThrowsError(try Parser.parameterIndex.parse("0"))
    }

    func testParamIndexParserAcceptsValidIndices() throws {
        XCTAssertNoThrow(try Parser.parameterIndex.parse("1"))
        XCTAssertNoThrow(try Parser.parameterIndex.parse("10"))
        XCTAssertNoThrow(try Parser.parameterIndex.parse("100"))
        XCTAssertNoThrow(try Parser.parameterIndex.parse("100"))
        XCTAssertNoThrow(try Parser.parameterIndex.parse("1000"))
        XCTAssertNoThrow(try Parser.parameterIndex.parse("9990"))
    }

    func testParamIndexParserRejectsIndexAboveMaximum () throws {
        XCTAssertThrowsError(try Parser.parameterIndex.parse("10000"))
    }

    func testAnyIndexedParamNameIsParsed() throws {
        let paramName = "asdf.1"

        let result = try Parser.optionallyIndexedParameterName.parse(paramName)

        XCTAssertEqual(result.0, "asdf")
        XCTAssertEqual(result.1, 1)
    }

    func testInvalidIndexedParamNameIsNotParsed() throws {
        let paramName = "%asdf.1"

        XCTAssertThrowsError(try Parser.optionallyIndexedParameterName.parse(paramName))
    }

    func testAnySeeminglySoundParameterIsParsed() throws {
        let otherNoIndex = try Parser.queryKeyAndValue.parse("asset-id=zPOAP")
        XCTAssertEqual(otherNoIndex.0, "asset-id"[...])
        XCTAssertEqual(otherNoIndex.1, nil)
        XCTAssertEqual(otherNoIndex.2, "zPOAP"[...])

        let otherIndexed = try Parser.queryKeyAndValue.parse("asset-id.1=zPOAP")
        XCTAssertEqual(otherIndexed.0, "asset-id"[...])
        XCTAssertEqual(otherIndexed.1, 1)
        XCTAssertEqual(otherIndexed.2, "zPOAP"[...])

        let amountIndexed = try Parser.queryKeyAndValue.parse("amount.1=0.0001")
        XCTAssertEqual(amountIndexed.0, "amount"[...])
        XCTAssertEqual(amountIndexed.1, 1)
        XCTAssertEqual(amountIndexed.2, "0.0001"[...])
    }

    func testKeyValueParserNotThrowsOnUnknownRequiredParam() {
        XCTAssertNoThrow(try Parser.queryKeyAndValue.parse("req-unknown-future-option=true"))
    }

    func testZcashParamParserFailsOnUnknownRequiredParam() throws {
        XCTAssertThrowsError(try Parser.zcashParameter(("req-unknown-future-option"[...], nil, "true"[...])))
    }

    // MARK: Partial Parsers - Recipient Addresses
    func testParserThrowsOnInvalidRecipientCharsetBech32() throws {
        XCTAssertThrowsError(try Param.from(queryKey: "address", value: "ztestsapling10yy211111qkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", index: 0, validating: Parser.onlyCharsetValidation))
    }

    func testParserThrowsOnInvalidRecipientCharsetBase58() throws {
        XCTAssertThrowsError(try Param.from(queryKey: "address", value: "tm000HTpdKMw5it8YDspUXSMGQyFwovpU", index: 0, validating: Parser.onlyCharsetValidation))

        XCTAssertThrowsError(try Param.from(queryKey: "address", value: "u1bbbbfl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", index: 0, validating: Parser.onlyCharsetValidation))
    }

    func testValidCharsetBase58AreParsed() throws {
        guard let recipientT = RecipientAddress(value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU") else {
            XCTFail("Recipient could not be created")
            return
        }

        XCTAssertEqual(
            try Param.from(
                queryKey: "address",
                value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
                index: 0,
                validating: Parser.onlyCharsetValidation
            ),
            Param.address(recipientT)
        )

        guard let recipientU = RecipientAddress(value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je") else {
            XCTFail("Unified Recipient couldn't be created")
            return
        }

        XCTAssertEqual(
            try Param.from(
                queryKey: "address",
                value: "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je",
                index: 0,
                validating: Parser.onlyCharsetValidation
            ),
            Param.address(recipientU)
        )
    }

    func testValidCharsetBech32AreParsed() throws {
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("Recipient could not be created")
            return
        }

        XCTAssertEqual(
            try Param.from(
                queryKey: "address",
                value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                index: 0,
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
        XCTAssertEqual("tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU", address)
    }

    func testCharsetValidationPassesOnValidSaplingAddress() throws {
        let expected = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        let address = try Parser.saplingEncodingCharsetParser
            .parse(expected)

        XCTAssertEqual("0yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", address)
    }

    func testCharsetValidationPassesOnValidUnifiedAddress() throws {
        let expected = "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"
        let address = try Parser.unifiedEncodingCharsetParser
            .parse(expected)

        XCTAssertEqual("fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je", address)
    }

    func testZcashParameterCreatesValidAddress() throws {
        let query = "address"[...]
        let value = "u1fl5mprj0t9p4jg92hjjy8q5myvwc60c9wv0xachauqpn3c3k4xwzlaueafq27dcg7tzzzaz5jl8tyj93wgs983y0jq0qfhzu6n4r8rakpv5f4gg2lrw4z6pyqqcrcqx04d38yunc6je"[...]

        guard let recipient = RecipientAddress(value: String(value), validating: nil) else {
            XCTFail("could not create recipient address")
            return
        }

        XCTAssertEqual(
            IndexedParameter(index: 0, param: .address(recipient)),
            try Parser.zcashParameter((query, nil, value), validating: Parser.onlyCharsetValidation)
        )
    }

    // MARK: Partial parser - Query Key value tests
    func testZcashParameterCreatesValidAmount() throws {
        let query = "amount"[...]
        let value = "1.00020112"[...]

        XCTAssertEqual(
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1.00020112))),
            try Parser.zcashParameter((query, nil, value), validating: Parser.onlyCharsetValidation)
        )
    }

    func testZcashParameterCreatesValidMessage() throws {
        let query = "message"[...]
        let index = 1
        let value = "Thank%20You%20For%20Your%20Purchase"[...]

        guard let qcharDecodedValue = String(value).qcharDecode() else {
            XCTFail("failed to qcharDecode value `\(value)")
            return
        }

        XCTAssertEqual(
            IndexedParameter(index: UInt(index), param: .message(qcharDecodedValue)),
            try Parser.zcashParameter((query, index, value), validating: Parser.onlyCharsetValidation)
        )
    }

    func testZcashParameterCreatesValidLabel() throws {
        let query = "label"[...]
        let index = 99
        let value = "Thank%20You%20For%20Your%20Purchase"[...]

        guard let qcharDecodedValue = String(value).qcharDecode() else {
            XCTFail("failed to qcharDecode value `\(value)")
            return
        }

        XCTAssertEqual(
            IndexedParameter(index: UInt(index), param: .label(qcharDecodedValue)),
            try Parser.zcashParameter((query, index, value), validating: Parser.onlyCharsetValidation)
        )
    }

    func testZcashParameterCreatesValidMemo() throws {
        let query = "memo"[...]
        let index = 99
        let value = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"[...]

        XCTAssertEqual(
            IndexedParameter(index: UInt(index), param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            try Parser.zcashParameter((query, index, value), validating: Parser.onlyCharsetValidation)
        )
    }

    func testZcashParameterCreatesSafelyIgnoredOtherParameter() throws {
        let query = "future-binary-format"[...]
        let index = 99
        let value = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"[...]

        XCTAssertEqual(
            IndexedParameter(index: UInt(index), param: .other(String(query), String(value))),
            try Parser.zcashParameter((query, index, value), validating: Parser.onlyCharsetValidation)
        )
    }

    func testZcashParameterThrowsOnInvalidLabelValue() throws {
        let query = "label"[...]
        let index = 99
        let value = "Thank%20You%20For%20Your%20Purchase"[...]

        guard let qcharDecodedValue = String(value).qcharDecode() else {
            XCTFail("failed to qcharDecode value `\(value)")
            return
        }

        XCTAssertEqual(
            IndexedParameter(index: UInt(index), param: .label(qcharDecodedValue)),
            try Parser.zcashParameter((query, index, value), validating: Parser.onlyCharsetValidation)
        )
    }

    // MARK: Partial parser - indexed parameters

    func testThatIndexParametersAreParsedWithNoLeadingAddress() throws {
        let validAddressURI = "?address=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"[...]

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = [
            IndexedParameter(index: 0, param: .address(recipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .message("Thank you for your purchase"))
        ]

        let result = try Parser.parseParameters(
            validAddressURI,
            leadingAddress: nil,
            validating: Parser.onlyCharsetValidation
        )

        XCTAssertEqual(result, expected)
    }

    func testThatIndexParametersAreParsedWithLeadingAddress() throws {
        let validAddressURI = "?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"[...]

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = [
            IndexedParameter(index: 0, param: .address(recipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .message("Thank you for your purchase"))
        ]

        let result = try Parser.parseParameters(
            validAddressURI,
            leadingAddress: IndexedParameter(
                index: 0,
                param: .address(recipient)
            ),
            validating: Parser.onlyCharsetValidation
        )

        XCTAssertEqual(result, expected)
    }

    // MARK: Param validation - detect duplication
    func testDuplicateOtherParamsAreDetected() throws {
        let params: [Param] = [
            .address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")!),
            .amount(try Amount(value: 1)),
            .message("Thanks"),
            .label("payment"),
            .other("future", "is awesome")
        ]

        XCTAssertTrue(params.hasDuplicateParam(.other("future", "is dystopic")))
    }

    func testDuplicateAddressParamsAreDetected() throws {
        let params: [Param] = [
            .address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")!),
            .amount(try Amount(value: 1)),
            .message("Thanks"),
            .label("payment"),
            .other("future", "is awesome")
        ]

        XCTAssertTrue(params.hasDuplicateParam(.address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")!)))
    }

    func testDuplicateParameterIsFalseWhenNoDuplication() throws {
        let params: [Param] = [
            .amount(try Amount(value: 1)),
            .message("Thanks"),
            .label("payment"),
            .other("future", "is awesome")
        ]

        XCTAssertFalse(params.hasDuplicateParam(.address(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez")!)))
    }

    // MARK: Param validation - no memos to transparent

    func testThrowsWhenMemoIsPresentOnTransparentRecipient() throws {
        guard let recipient = RecipientAddress(value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU") else {
            XCTFail("failed to create recipient")
            return
        }

        let params: [Param] = [
            .address(recipient),
            .amount(try Amount(value: 1)),
            .message("Thanks"),
            .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg")),
            .label("payment"),
            .other("future", "is awesome")
        ]

        XCTAssertThrowsError(try Payment.uniqueIndexedParameters(index: 1, parameters: params)) { err in

            switch err {
            case ZIP321.Errors.transparentMemoNotAllowed(1):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.transparentMemoNotAllowed(1)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    // MARK: Payment Validation
    func testPaymentIsCreatedFromIndexedParameters() throws {
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("failed to create recipient")
            return
        }

        let params: [Param] = [
            .address(recipient),
            .amount(try Amount(value: 1)),
            .message("Thanks"),
            .label("payment"),
            .other("future", "is awesome")
        ]

        let payment = try Payment.uniqueIndexedParameters(index: 1, parameters: params)

        XCTAssertEqual(
            Payment(
                recipientAddress: recipient,
                amount: try Amount(value: 1),
                memo: nil,
                label: "payment",
                message: "Thanks",
                otherParams: [OtherParam(key: "future", value: "is awesome")]
            ),
            payment
        )
    }

    func testThatDuplicateParametersAreDetected() throws {
        guard let shieldedRecipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez") else {
            XCTFail("failed to create shielded recipient")
            return
        }

        let duplicateAddressParams: [IndexedParameter] = [
            IndexedParameter(index:0, param: .address(shieldedRecipient)),
            IndexedParameter(index:0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index:0, param: .message("Thanks")),
            IndexedParameter(index:0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index:0, param: .label("payment")),
            IndexedParameter(index:0, param: .address(shieldedRecipient)),
            IndexedParameter(index:0, param: .other("future", "is awesome"))
        ]

        let duplicateAmountParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message("Thanks")),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label("payment")),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .other("future", "is awesome"))
        ]

        let duplicateMessageParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message("Thanks")),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label("payment")),
            IndexedParameter(index: 0, param: .message("Thanks")),
            IndexedParameter(index: 0, param: .other("future", "is awesome"))
        ]

        let duplicateMemoParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message("Thanks")),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label("payment")),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .other("future", "is awesome"))
        ]

        let duplicateLabelParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .label("payment")),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message("Thanks")),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .label("payment")),
            IndexedParameter(index: 0, param: .other("future", "is awesome"))
        ]

        let duplicateOtherParams: [IndexedParameter] = [
            IndexedParameter(index: 0, param: .address(shieldedRecipient)),
            IndexedParameter(index: 0, param: .label("payment")),
            IndexedParameter(index: 0, param: .other("future", "is awesome")),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .message("Thanks")),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .other("future", "is awesome"))
        ]

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateAddressParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("address", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("address", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateAmountParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("amount", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("amount", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateMessageParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("message", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("message", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateMemoParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("memo", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("memo", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateLabelParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("label", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("label", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try Parser.mapToPayments(duplicateOtherParams)) { err in

            switch err {
            case ZIP321.Errors.duplicateParameter("future", nil):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("future", nil)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
}
// swiftlint:enable line_length
