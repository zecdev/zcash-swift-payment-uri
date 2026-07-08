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
    // MARK: Partial parsers - paramindex

    @Test func paramIndexParserRejectsLeadingZeros() throws {
        #expect(throws: (any Error).self) {
            try Parser.parseParamIndex("01")
        }
        #expect(throws: (any Error).self) {
            try Parser.parseParamIndex("0")
        }
    }

    @Test func paramIndexParserAcceptsValidIndices() throws {
        #expect(try Parser.parseParamIndex("1") == 1)
        #expect(try Parser.parseParamIndex("10") == 10)
        #expect(try Parser.parseParamIndex("100") == 100)
        #expect(try Parser.parseParamIndex("1000") == 1000)
        #expect(try Parser.parseParamIndex("9990") == 9990)
    }

    @Test func paramIndexParserRejectsIndexAboveMaximum() throws {
        #expect(throws: (any Error).self) {
            try Parser.parseParamIndex("10000")
        }
    }

    // MARK: Partial parsers - name + index

    @Test func anyIndexedParamNameIsParsed() throws {
        let result = try Parser.parseNameAndIndex("asdf.1")

        #expect(result.name == "asdf")
        #expect(result.index == 1)
    }

    @Test func paramNameWithoutIndexIsParsed() throws {
        let result = try Parser.parseNameAndIndex("loyalty-id")

        #expect(result.name == "loyalty-id")
        #expect(result.index == nil)
    }

    @Test func invalidIndexedParamNameIsNotParsed() throws {
        // A percent-escaped (or otherwise non-ALPHA-leading) name is rejected.
        #expect(throws: (any Error).self) {
            try Parser.parseNameAndIndex("%asdf.1")
        }
    }

    // MARK: Partial parsers - full query segment

    @Test func anySeeminglySoundParameterIsParsed() throws {
        let otherNoIndex = try Parser.parseQueryToken("loyalty-id=gold-tier")
        #expect(otherNoIndex.name == "loyalty-id")
        #expect(otherNoIndex.index == nil)
        #expect(otherNoIndex.value == "gold-tier")

        let otherIndexed = try Parser.parseQueryToken("loyalty-id.1=gold-tier")
        #expect(otherIndexed.name == "loyalty-id")
        #expect(otherIndexed.index == 1)
        #expect(otherIndexed.value == "gold-tier")

        let amountIndexed = try Parser.parseQueryToken("amount.1=0.0001")
        #expect(amountIndexed.name == "amount")
        #expect(amountIndexed.index == 1)
        #expect(amountIndexed.value == "0.0001")
    }

    @Test func valuelessParameterIsAccepted() throws {
        // ZIP-321 `otherparam` grammar allows an absent `= *qchar`; v1 preserves this.
        let token = try Parser.parseQueryToken("future-flag")
        #expect(token.name == "future-flag")
        #expect(token.index == nil)
        #expect(token.value == nil)
    }

    @Test func emptyValueIsAccepted() throws {
        let token = try Parser.parseQueryToken("message=")
        #expect(token.name == "message")
        #expect(token.value == "")
    }

    // MARK: Grammar rejections

    @Test func percentEscapedNameIsRejected() {
        #expect(throws: (any Error).self) { try Parser.parseQueryToken("%61mount=1") }
    }

    @Test func nonQcharInValueIsRejected() {
        // A raw non-qchar byte (space) is not part of the value and leaves trailing input.
        #expect(throws: (any Error).self) { try Parser.parseQueryToken("label=a b") }
    }

    @Test func leadingZeroIndexIsRejected() {
        #expect(throws: (any Error).self) { try Parser.parseQueryToken("address.0=x") }
    }

    @Test func overlongIndexIsRejected() {
        #expect(throws: (any Error).self) { try Parser.parseQueryToken("amount.10000=1") }
    }

    @Test func keyValueParserNotThrowsOnUnknownRequiredParam() {
        // The tokenizer is name/value-agnostic; `req-` rejection happens in `zcashParameter`.
        #expect(throws: Never.self) {
            try Parser.parseQueryToken("req-unknown-future-option=true")
        }
    }

    @Test func zcashParamParserFailsOnUnknownRequiredParam() throws {
        #expect(throws: (any Error).self) {
            try Parser.zcashParameter(name: "req-unknown-future-option", index: nil, value: "true", network: .testnet, validator: ReferenceAddressValidator.testnet)
        }
    }

    // MARK: zcashParameter - reserved query keys

    @Test func zcashParameterCreatesValidAmount() throws {
        #expect(
            IndexedParameter(index: 0, param: .amount(try NonNegativeAmount.zec("1.00020112").get()))
            == (try Parser.zcashParameter(name: "amount", index: nil, value: "1.00020112", network: .testnet, validator: ReferenceAddressValidator.testnet))
        )
    }

    @Test func zcashParameterCreatesValidMessage() throws {
        let value = "Thank%20You%20For%20Your%20Purchase"
        let qcharDecodedValue = try #require(QcharString(value: value.qcharDecode()!))

        #expect(
            IndexedParameter(index: 1, param: .message(qcharDecodedValue))
            == (try Parser.zcashParameter(name: "message", index: 1, value: value, network: .testnet, validator: ReferenceAddressValidator.testnet))
        )
    }

    @Test func zcashParameterCreatesValidLabel() throws {
        let value = "Thank%20You%20For%20Your%20Purchase"
        let qcharDecodedValue = try #require(QcharString(value: value.qcharDecode()!))

        #expect(
            IndexedParameter(index: 99, param: .label(qcharDecodedValue))
            == (try Parser.zcashParameter(name: "label", index: 99, value: value, network: .testnet, validator: ReferenceAddressValidator.testnet))
        )
    }

    @Test func zcashParameterCreatesValidMemo() throws {
        #expect(
            IndexedParameter(index: 99, param: .memo(try MemoBytes(base64URL: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg")))
            == (try Parser.zcashParameter(name: "memo", index: 99, value: "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg", network: .testnet, validator: ReferenceAddressValidator.testnet))
        )
    }

    @Test func zcashParameterCreatesSafelyIgnoredOtherParameter() throws {
        let value = "VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg"

        #expect(
            IndexedParameter(index: 99, param: .other(try OtherParam(name: "future-binary-format", value: value)))
            == (try Parser.zcashParameter(name: "future-binary-format", index: 99, value: value, network: .testnet, validator: ReferenceAddressValidator.testnet))
        )
    }

    @Test func zcashParameterDecodesOtherParameterValue() throws {
        // otherparam values are percent-decoded on parse.
        let result = try Parser.zcashParameter(name: "future-param", index: nil, value: "hello%20world", network: .testnet, validator: ReferenceAddressValidator.testnet)

        guard case let .other(otherParam) = result.param else {
            Issue.record("expected an other param")
            return
        }
        #expect(otherParam.value == "hello world")
    }

    // MARK: Partial parser - indexed parameters

    @Test func thatIndexParametersAreParsedWithNoLeadingAddress() throws {
        let validAddressURI = "?address=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"[...]

        let recipient = try #require(RecipientAddress(value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez", validator: ReferenceAddressValidator.testnet))

        let expected = [
            IndexedParameter(index: 0, param: .address(recipient)),
            IndexedParameter(index: 0, param: .amount(try NonNegativeAmount.zec("1").get())),
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
            IndexedParameter(index: 0, param: .amount(try NonNegativeAmount.zec("1").get())),
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
