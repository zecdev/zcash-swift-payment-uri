//
//  ParsingTests.swift
//  
//
//  Created by Francisco Gindre on 2023-12-07.
//

import XCTest
import Parsing
import CustomDump
@testable import ZcashPaymentURI

final class ParsingTests: XCTestCase {
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
        XCTAssertThrowsError(try Parser.zcashParameter(("req-unknown-future-option"[...], nil, "true"[...]), context: .testnet))
    }


    // MARK: Partial parser - Query Key value tests
    func testZcashParameterCreatesValidAmount() throws {
        let query = "amount"[...]
        let value = "1.00020112"[...]

        XCTAssertNoDifference(
            IndexedParameter(index: 0, param: .amount(try Amount(string: String(value)))),
            try Parser.zcashParameter(
                (query, nil, value),
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

    func testZcashParameterCreatesValidMessage() throws {
        let query = "message"[...]
        let index = 1
        let value = "Thank%20You%20For%20Your%20Purchase"[...]
        guard let qcharDecodedValue = QcharString(value: String(value).qcharDecode()!) else {
            XCTFail("failed to qcharDecode value `\(value)")
            return
        }

        XCTAssertNoDifference(
            IndexedParameter(index: UInt(index), param: .message(qcharDecodedValue)),
            try Parser.zcashParameter(
                (query, index, value),
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

    func testZcashParameterCreatesValidLabel() throws {
        let query = "label"[...]
        let index = 99
        let value = "Thank%20You%20For%20Your%20Purchase"[...]

        guard let qcharDecodedValue = QcharString(value: String(value).qcharDecode()!) else {
            XCTFail("failed to qcharDecode value `\(value)")
            return
        }

        XCTAssertNoDifference(
            IndexedParameter(index: UInt(index), param: .label(qcharDecodedValue)),
            try Parser.zcashParameter(
                (query, index, value),
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

    func testZcashParameterCreatesValidMemo() throws {
        let query = "memo"[...]
        let index = 99
        let value = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"[...]

        XCTAssertNoDifference(
            IndexedParameter(index: UInt(index), param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            try Parser.zcashParameter(
                (query, index, value),
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

    func testZcashParameterCreatesSafelyIgnoredOtherParameter() throws {
        let query = "future-binary-format"[...]
        let index = 99
        let value = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"[...]


        guard let queryKey = ParamNameString(value: String(query)) else {
            XCTFail("failed to ParamName decode value `\(query)")
            return
        }

        guard let qcharDecodedValue = QcharString(value: String(value)) else {
            XCTFail("failed to qcharDecode value `\(value)")
            return
        }

        XCTAssertNoDifference(
            IndexedParameter(index: UInt(index), param: .other(try OtherParam(key: queryKey, value: qcharDecodedValue))),
            try Parser.zcashParameter(
                (query, index, value),
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

    func testZcashParameterThrowsOnInvalidLabelValue() throws {
        let query = "label"[...]
        let index = 99
        let value = "Thank%20You%20For%20Your%20Purchase"[...]

        guard let qcharEncodedValue = QcharString(value: String(value).qcharDecode()!) else {
            XCTFail("failed to qcharDecode value `\(value)")
            return
        }

        XCTAssertEqual(
            IndexedParameter(index: UInt(index), param: .label(qcharEncodedValue)),
            try Parser.zcashParameter(
                (query, index, value),
                context: .testnet,
                validating: Parser.onlyCharsetValidation
            )
        )
    }

    // MARK: Partial parser - indexed parameters

    func testThatIndexParametersAreParsedWithNoLeadingAddress() throws {
        let validAddressURI = "?address=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"[...]

        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("Failed to create valid recipient")
            return
        }

        let expected = [
            IndexedParameter(index: 0, param: .address(recipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thank you for your purchase")!))
        ]

        let result = try Parser.parseParameters(
            validAddressURI,
            leadingAddress: nil,
            context: .testnet,
            validating: Parser.onlyCharsetValidation
        )

        XCTAssertNoDifference(result, expected)
    }

    func testThatIndexParametersAreParsedWithLeadingAddress() throws {
        let validAddressURI = "?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"[...]
        
        guard let recipient = RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", context: .testnet) else {
            XCTFail("Failed to create valid recipient")
            return
        }
        
        let expected = [
            IndexedParameter(index: 0, param: .address(recipient)),
            IndexedParameter(index: 0, param: .amount(try Amount(value: 1))),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thank you for your purchase")!))
        ]
        
        let result = try Parser.parseParameters(
            validAddressURI,
            leadingAddress: IndexedParameter(
                index: 0,
                param: .address(recipient)
            ),
            context: .testnet,
            validating: Parser.onlyCharsetValidation
        )
        
        XCTAssertEqual(result, expected)
    }
}
