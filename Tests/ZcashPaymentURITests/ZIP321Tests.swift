import Testing
@testable import ZcashPaymentURI
// swiftlint:disable line_length
@Suite("ZIP321")
struct ZcashSwiftPaymentUriTests {
    @Test func singleRecipient() throws {
        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ))

        #expect(
            ZIP321.request(recipient)
            == "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        )
    }

    @Test func singlePaymentRequest() throws {
        let expected = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"

        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ))

        let payment = try Payment(
            recipientAddress: recipient,
            amount: try LegacyAmount(value: 1),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: nil
        )

        #expect(
            ZIP321.uriString(
                from: try PaymentRequest(payments: [payment]),
                formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)
            )
            == expected
        )

        #expect(ZIP321.request(payment, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)) == expected)

        // Roundtrip test
        #expect(
            try ZIP321.request(from: expected, context: .testnet, validatingRecipients: nil)
            == ParserResult.request(try PaymentRequest(payments: [payment]))
        )
    }

    @Test func multiplePaymentsRequestStartingWithNoParamIndex() throws {
        let expected = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, context: .testnet))

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try LegacyAmount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, context: .testnet))

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try LegacyAmount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        #expect(ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)) == expected)
    }

    @Test func parsingMultiplePaymentsRequestStartingWithNoParamIndex() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, context: .testnet))

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try LegacyAmount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, context: .testnet))

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try LegacyAmount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.request(from: uriString, context: .testnet)

        #expect(result == ParserResult.request(paymentRequest))
    }

    @Test func urirequestWithInvalidCharsFails() throws {
        let invalidBase64URI = "zcash:u19spl3y4zu73twemxrzm33tm3eefepecv4zdssn0hfd4tjaqpgmlcm9nhyjqlvaytwpknqjqctvdscjmg47ex20j03cu4gx3zmy26y2hunpenvw083dmtlq4y7re5rwsygpteq57wwllr3zhs4rw43j5puxgrcqdq4f9dd38qksl4f9p2hc7x3kj582zdjxsnj8urmnc3msfjw72kej0?amount=0.01&memo=QTw+Qg"

        #expect(throws: (any Error).self) {
            try ZIP321.request(from: invalidBase64URI, context: .mainnet)
        }
    }

    @Test func ensureThatAllPaymentsBelongToTheSameNetwork() throws {
        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, context: .testnet))

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try LegacyAmount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "zs10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, context: .mainnet))

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try LegacyAmount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        #expect {
            try PaymentRequest(payments: [payment0, payment1])
        } throws: { error in
            guard case ZIP321.Errors.networkMismatchFound = error else { return false }
            return true
        }
    }

    @Test func parsingMultiplePaymentsRequestStartingWithNoParamIndexAndNoAmount() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, context: .testnet))

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, context: .testnet))

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try LegacyAmount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.request(from: uriString, context: .testnet)

        #expect(result == ParserResult.request(paymentRequest))

        #expect(uriString == ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)))
    }

    @Test func parsingMultiplePaymentsRequestStartingWithNoParamIndexIndexedParamHasNoAmount() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, context: .testnet))

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try LegacyAmount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, context: .testnet))

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: nil,
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.request(from: uriString, context: .testnet)

        #expect(result == ParserResult.request(paymentRequest))
        #expect(uriString == ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)))
    }

    @Test func singlePaymentRequestAcceptsNoValueOtherParams() throws {
        let expected = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase&other"

        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ))

        let payment = try Payment(
            recipientAddress: recipient,
            amount: try LegacyAmount(value: 1),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: [OtherParam(key: "other", value: nil)]
        )

        #expect(
            ZIP321.uriString(
                from: try PaymentRequest(payments: [payment]),
                formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)
            )
            == expected
        )

        #expect(ZIP321.request(payment, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)) == expected)

        // Roundtrip test
        #expect(
            try ZIP321.request(from: expected, context: .testnet, validatingRecipients: nil)
            == ParserResult.request(try PaymentRequest(payments: [payment]))
        )
    }

    @Test func thanSeeminglyValidEmptyRequestThrows() throws {
        #expect(throws: (any Error).self) {
            try ZIP321.request(from: "zcash:?", context: .testnet)
        }
    }

    /// invalid; amount component is MAX_MONEY
    /// 21000000.00000001
    @Test func throwsWhenAmountIsMaxMoney() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=21000000.00000001"
        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.amountExceededSupply(0) = error else { return false }
            return true
        }
    }

    /// invalid; amount component wraps into a valid small positive i64
    /// 18446744073709551624
    @Test func throwsWhenAmountIsTooSmall() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=18446744073709551624"

        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.amountExceededSupply(0) = error else { return false }
            return true
        }
    }

    /// invalid; amount component exceeds an i64
    /// 9223372036854775808 = i64::MAX + 1
    @Test func throwsWhenAmountExceedsSupply() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=9223372036854775808"
        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.amountExceededSupply(0) = error else { return false }
            return true
        }
    }

    @Test func throwsWhenMemoIsInvalid() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgIHNqqqw222ncssspbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.memoBytesError(MemoBytes.MemoError.memoTooLong, nil) = error else { return false }
            return true
        }
    }

    @Test func throwsWhenMemoIsAssignedToTransparentRecipient() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&memo=eyAia2V5IjogIlRoaXMgaXMgYSBKU09OLXN0cnVjdHVyZWQgbWVtby4iIH0&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        #expect {
            try ZIP321.request(from: invalidURI, context: .testnet)
        } throws: { error in
            guard case ZIP321.Errors.transparentMemoNotAllowed(nil) = error else { return false }
            return true
        }
    }

    /// invalid; `address.0=` and `amount.0=` are not permitted (leading 0s)./
    @Test func throwsWhenParamIndexIsZero() {
        let invalidURI = "zcash:?address.0=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.0=2"

        // TODO: Fix leading address error type. (error is thrown but is not as expected)
        #expect(throws: (any Error).self) {
            try ZIP321.request(from: invalidURI, context: .testnet)
        }
    }

    @Test(arguments: TestVectors.unifiedAddresses)
    func parserSuccessfullyParsesAllTestVectorAddresses(_ ua: String) throws {
        let request = try ZIP321.request(from: "zcash:\(ua)", context: .mainnet)

        if case let .legacy(address) = request {
            #expect(address.value == ua)
        } else {
            Issue.record("Failed: Parser should have detected a 'legacy' variant of Payment request")
        }
    }

    @Test func parserSuccessfullyParsesLegacySaplingPaymentRequest() throws {
        #expect(throws: Never.self) {
            try ZIP321.request(from: "zcash:zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9slya", context: .mainnet)
        }
    }

    @Test func parserSuccessfullyParsesLegacyOrchardOnlyUAPaymentRequest() throws {
        #expect(throws: Never.self) {
            try ZIP321.request(from: "zcash:u16cynw2u6nshm44gjv9vy9dvav6zvvksphexzjs3tjke8mr3p942er0pu8held7zy7wpjxzqgkpdrjzd72h7pwf34df8a0xcv0su3acx7", context: .mainnet)
        }
    }
}
