//
//  ParsingTests.swift
//
//
//  Created by Francisco Gindre on 2023-12-07.
//

import Testing
@testable import ZcashPaymentURI

@Suite("ParseParameters")
struct ParsingTests {
    // MARK: Partial parsers - QueryKey parsing
    @Test func paramIndexParserRejectsLeadingZeros() throws {
        #expect(throws: (any Error).self) {
            try Parser.parameterIndex.parse("01")
        }
        #expect(throws: (any Error).self) {
            try Parser.parameterIndex.parse("0")
        }
    }

    @Test func paramIndexParserAcceptsValidIndices() throws {
        _ = try Parser.parameterIndex.parse("1")
        _ = try Parser.parameterIndex.parse("10")
        _ = try Parser.parameterIndex.parse("100")
        _ = try Parser.parameterIndex.parse("100")
        _ = try Parser.parameterIndex.parse("1000")
        _ = try Parser.parameterIndex.parse("9990")
    }

    @Test func paramIndexParserRejectsIndexAboveMaximum() throws {
        #expect(throws: (any Error).self) {
            try Parser.parameterIndex.parse("10000")
        }
    }

    @Test func anyIndexedParamNameIsParsed() throws {
        let paramName = "asdf.1"

        let result = try Parser.optionallyIndexedParameterName.parse(paramName)

        #expect(result.0 == "asdf")
        #expect(result.1 == 1)
    }

    @Test func invalidIndexedParamNameIsNotParsed() throws {
        let paramName = "%asdf.1"

        #expect(throws: (any Error).self) {
            try Parser.optionallyIndexedParameterName.parse(paramName)
        }
    }

    @Test func anySeeminglySoundParameterIsParsed() throws {
        let otherNoIndex = try Parser.queryKeyAndValue.parse("asset-id=zPOAP")
        #expect(otherNoIndex.0 == "asset-id"[...])
        #expect(otherNoIndex.1 == nil)
        #expect(otherNoIndex.2 == "zPOAP"[...])

        let otherIndexed = try Parser.queryKeyAndValue.parse("asset-id.1=zPOAP")
        #expect(otherIndexed.0 == "asset-id"[...])
        #expect(otherIndexed.1 == 1)
        #expect(otherIndexed.2 == "zPOAP"[...])

        let amountIndexed = try Parser.queryKeyAndValue.parse("amount.1=0.0001")
        #expect(amountIndexed.0 == "amount"[...])
        #expect(amountIndexed.1 == 1)
        #expect(amountIndexed.2 == "0.0001"[...])
    }

    @Test func keyValueParserNotThrowsOnUnknownRequiredParam() {
        #expect(throws: Never.self) {
            try Parser.queryKeyAndValue.parse("req-unknown-future-option=true")
        }
    }

    @Test func zcashParamParserFailsOnUnknownRequiredParam() throws {
        #expect(throws: (any Error).self) {
            try Parser.zcashParameter(("req-unknown-future-option"[...], nil, "true"[...]), network: .testnet, validator: ReferenceAddressValidator.testnet)
        }
    }

    // MARK: Partial parser - Query Key value tests
    @Test func zcashParameterCreatesValidAmount() throws {
        let query = "amount"[...]
        let value = "1.00020112"[...]

        #expect(
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(string: String(value))))
            == (try Parser.zcashParameter(
                (query, nil, value),
                network: .testnet,
validator: ReferenceAddressValidator.testnet
            ))
        )
    }

    @Test func zcashParameterCreatesValidMessage() throws {
        let query = "message"[...]
        let index = 1
        let value = "Thank%20You%20For%20Your%20Purchase"[...]
        let qcharDecodedValue = try #require(QcharString(value: String(value).qcharDecode()!))

        #expect(
            IndexedParameter(index: UInt(index), param: .message(qcharDecodedValue))
            == (try Parser.zcashParameter(
                (query, index, value),
                network: .testnet,
validator: ReferenceAddressValidator.testnet
            ))
        )
    }

    @Test func zcashParameterCreatesValidLabel() throws {
        let query = "label"[...]
        let index = 99
        let value = "Thank%20You%20For%20Your%20Purchase"[...]

        let qcharDecodedValue = try #require(QcharString(value: String(value).qcharDecode()!))

        #expect(
            IndexedParameter(index: UInt(index), param: .label(qcharDecodedValue))
            == (try Parser.zcashParameter(
                (query, index, value),
                network: .testnet,
validator: ReferenceAddressValidator.testnet
            ))
        )
    }

    @Test func zcashParameterCreatesValidMemo() throws {
        let query = "memo"[...]
        let index = 99
        let value = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"[...]

        #expect(
            IndexedParameter(index: UInt(index), param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg")))
            == (try Parser.zcashParameter(
                (query, index, value),
                network: .testnet,
validator: ReferenceAddressValidator.testnet
            ))
        )
    }

    @Test func zcashParameterCreatesSafelyIgnoredOtherParameter() throws {
        let query = "future-binary-format"[...]
        let index = 99
        let value = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"[...]

        let queryKey = try #require(ParamNameString(value: String(query)))
        let qcharDecodedValue = try #require(QcharString(value: String(value)))

        #expect(
            IndexedParameter(index: UInt(index), param: .other(try OtherParam(key: queryKey, value: qcharDecodedValue)))
            == (try Parser.zcashParameter(
                (query, index, value),
                network: .testnet,
validator: ReferenceAddressValidator.testnet
            ))
        )
    }

    @Test func zcashParameterThrowsOnInvalidLabelValue() throws {
        let query = "label"[...]
        let index = 99
        let value = "Thank%20You%20For%20Your%20Purchase"[...]

        let qcharEncodedValue = try #require(QcharString(value: String(value).qcharDecode()!))

        #expect(
            IndexedParameter(index: UInt(index), param: .label(qcharEncodedValue))
            == (try Parser.zcashParameter(
                (query, index, value),
                network: .testnet,
validator: ReferenceAddressValidator.testnet
            ))
        )
    }

    // MARK: Partial parser - indexed parameters

    @Test func thatIndexParametersAreParsedWithNoLeadingAddress() throws {
        let validAddressURI = "?address=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"[...]

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let expected = [
            IndexedParameter(index: 0, param: .address(recipient)),
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thank you for your purchase")!))
        ]

        let result = try Parser.parseParameters(
            validAddressURI,
            leadingAddress: nil,
            network: .testnet,
validator: ReferenceAddressValidator.testnet
        )

        #expect(result == expected)
    }

    @Test func thatIndexParametersAreParsedWithLeadingAddress() throws {
        let validAddressURI = "?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"[...]

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let expected = [
            IndexedParameter(index: 0, param: .address(recipient)),
            IndexedParameter(index: 0, param: .amount(try LegacyAmount(value: 1))),
            IndexedParameter(index: 0, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"))),
            IndexedParameter(index: 0, param: .message(QcharString(value: "Thank you for your purchase")!))
        ]

        let result = try Parser.parseParameters(
            validAddressURI,
            leadingAddress: IndexedParameter(
                index: 0,
                param: .address(recipient)
            ),
            network: .testnet,
validator: ReferenceAddressValidator.testnet
        )

        #expect(result == expected)
    }
}
