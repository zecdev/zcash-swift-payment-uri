import Testing
@testable import ZcashPaymentURI
// swiftlint:disable line_length
@Suite("ZIP321")
struct ZcashSwiftPaymentUriTests {
    @Test func singleRecipient() throws {
        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            validator: ReferenceAddressValidator.testnet
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
            validator: ReferenceAddressValidator.testnet
        ))

        let payment = try Payment.create(
            recipientAddress: recipient,
            amount: try NonNegativeAmount.zec("1").get(),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: []
        ).get()

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
            try ZIP321.parse(expected, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()
            == (try PaymentRequest(payments: [payment]))
        )
    }

    @Test func multiplePaymentsRequestStartingWithNoParamIndex() throws {
        let expected = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        let payment0 = try Payment.create(
            recipientAddress: recipient0,
            amount: try NonNegativeAmount.zec("123.456").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, validator: ReferenceAddressValidator.testnet))

        let payment1 = try Payment.create(
            recipientAddress: recipient1,
            amount: try NonNegativeAmount.zec("0.789").get(),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        #expect(ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)) == expected)
    }

    @Test func parsingMultiplePaymentsRequestStartingWithNoParamIndex() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        let payment0 = try Payment.create(
            recipientAddress: recipient0,
            amount: try NonNegativeAmount.zec("123.456").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, validator: ReferenceAddressValidator.testnet))

        let payment1 = try Payment.create(
            recipientAddress: recipient1,
            amount: try NonNegativeAmount.zec("0.789").get(),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.parse(uriString, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        #expect(result == (paymentRequest))
    }

    @Test func urirequestWithInvalidCharsFails() throws {
        let invalidBase64URI = "zcash:u19spl3y4zu73twemxrzm33tm3eefepecv4zdssn0hfd4tjaqpgmlcm9nhyjqlvaytwpknqjqctvdscjmg47ex20j03cu4gx3zmy26y2hunpenvw083dmtlq4y7re5rwsygpteq57wwllr3zhs4rw43j5puxgrcqdq4f9dd38qksl4f9p2hc7x3kj582zdjxsnj8urmnc3msfjw72kej0?amount=0.01&memo=QTw+Qg"

        let result = ZIP321.parse(invalidBase64URI, expecting: .mainnet, validator: ReferenceAddressValidator.mainnet)
        guard case .failure = result else {
            Issue.record("expected failure but parsing succeeded")
            return
        }
    }

    @Test func parsingMultiplePaymentsRequestStartingWithNoParamIndexAndNoAmount() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        let payment0 = try Payment.create(
            recipientAddress: recipient0,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, validator: ReferenceAddressValidator.testnet))

        let payment1 = try Payment.create(
            recipientAddress: recipient1,
            amount: try NonNegativeAmount.zec("0.789").get(),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.parse(uriString, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        #expect(result == (paymentRequest))

        #expect(uriString == ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)))
    }

    @Test func parsingMultiplePaymentsRequestStartingWithNoParamIndexIndexedParamHasNoAmount() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        let recipient0 = try #require(RecipientAddress(value: address0, validator: ReferenceAddressValidator.testnet))

        let payment0 = try Payment.create(
            recipientAddress: recipient0,
            amount: try NonNegativeAmount.zec("123.456").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let recipient1 = try #require(RecipientAddress(value: address1, validator: ReferenceAddressValidator.testnet))

        let payment1 = try Payment.create(
            recipientAddress: recipient1,
            amount: nil,
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.parse(uriString, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        #expect(result == (paymentRequest))
        #expect(uriString == ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)))
    }

    @Test func singlePaymentRequestAcceptsNoValueOtherParams() throws {
        let expected = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase&other"

        let recipient = try #require(RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            validator: ReferenceAddressValidator.testnet
        ))

        let payment = try Payment.create(
            recipientAddress: recipient,
            amount: try NonNegativeAmount.zec("1").get(),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: [OtherParam(name: "other", value: nil)]
        ).get()

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
            try ZIP321.parse(expected, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()
            == (try PaymentRequest(payments: [payment]))
        )
    }

    /// `zcash:?` is a valid EMPTY request per the reference (an empty query
    /// marker), no longer a rejection.
    @Test func emptyQueryMarkerParsesAsEmptyRequest() throws {
        let result = try ZIP321.parse("zcash:?", expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()
        #expect(result == (try PaymentRequest(payments: [])))
    }

    /// `zcash:` (bare scheme) is a valid EMPTY request.
    @Test func bareSchemeParsesAsEmptyRequest() throws {
        let result = try ZIP321.parse("zcash:", expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()
        #expect(result == (try PaymentRequest(payments: [])))
    }

    /// invalid; amount component is above MAX_MONEY but representable
    /// 21000000.00000001 => amountExceededSupply
    @Test func throwsWhenAmountIsMaxMoney() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=21000000.00000001"
        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.amountExceededSupply(index: nil)))
    }

    /// invalid; amount component wraps beyond u64
    /// 18446744073709551624 => amountExceededSupply (overflow necessarily exceeds MAX_MONEY)
    @Test func throwsWhenAmountWrapsBeyondU64() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=18446744073709551624"
        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.amountExceededSupply(index: nil)))
    }

    /// invalid; amount component exceeds an i64
    /// 9223372036854775808 = i64::MAX + 1 => amountExceededSupply (overflow necessarily exceeds MAX_MONEY)
    @Test func throwsWhenAmountExceedsInt64() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=9223372036854775808"
        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.amountExceededSupply(index: nil)))
    }

    @Test func throwsWhenMemoIsInvalid() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgIHNqqqw222ncssspbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.memoBytesError(index: nil)))
    }

    @Test func throwsWhenMemoIsAssignedToTransparentRecipient() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&memo=eyAia2V5IjogIlRoaXMgaXMgYSBKU09OLXN0cnVjdHVyZWQgbWVtby4iIH0&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        #expect(ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet) == .failure(.transparentMemo(index: nil)))
    }

    /// invalid; `address.0=` and `amount.0=` are not permitted (leading 0s).
    @Test func throwsWhenParamIndexIsZero() {
        let invalidURI = "zcash:?address.0=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.0=2"

        let result = ZIP321.parse(invalidURI, expecting: .testnet, validator: ReferenceAddressValidator.testnet)
        guard case .failure(.invalidParamIndex) = result else {
            Issue.record("expected invalidParamIndex but got \(result)")
            return
        }
    }

    @Test(arguments: TestVectors.unifiedAddresses)
    func parserSuccessfullyParsesAllTestVectorAddresses(_ ua: String) throws {
        let request = try ZIP321.parse("zcash:\(ua)", expecting: .mainnet, validator: ReferenceAddressValidator.mainnet).get()

        #expect(request.payments.first?.recipientAddress.value == ua)
    }

    @Test func parserSuccessfullyParsesLegacySaplingPaymentRequest() throws {
        #expect(throws: Never.self) {
            try ZIP321.parse("zcash:zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9slya", expecting: .mainnet, validator: ReferenceAddressValidator.mainnet).get()
        }
    }

    @Test func parserSuccessfullyParsesLegacyOrchardOnlyUAPaymentRequest() throws {
        #expect(throws: Never.self) {
            try ZIP321.parse("zcash:u16cynw2u6nshm44gjv9vy9dvav6zvvksphexzjs3tjke8mr3p942er0pu8held7zy7wpjxzqgkpdrjzd72h7pwf34df8a0xcv0su3acx7", expecting: .mainnet, validator: ReferenceAddressValidator.mainnet).get()
        }
    }
}
