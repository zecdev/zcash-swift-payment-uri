import XCTest
import CustomDump
@testable import ZcashPaymentURI
// swiftlint:disable line_length
final class ZcashSwiftPaymentUriTests: XCTestCase {
    func testSingleRecipient() throws {
        guard let recipient = RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        ) else {
            XCTFail("failed to create Recipient from unchecked source")
            return
        }

        XCTAssertNoDifference(
            ZIP321.request(recipient),
            "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        )
    }

    func testSinglePaymentRequest() throws {
        let expected = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"

        guard let recipient = RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"
        ) else {
            XCTFail("failed to create Recipient from unchecked source")
            return
        }

        let payment = Payment(
            recipientAddress: recipient,
            amount: try Amount(value: 1),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: nil
        )

        XCTAssertNoDifference(
            ZIP321.uriString(
                from: PaymentRequest(payments: [payment]),
                formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)
            ),
            expected
        )

        XCTAssertNoDifference(ZIP321.request(payment, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)), expected)

        // Roundtrip test
        XCTAssertNoDifference(
            try ZIP321.request(from: expected, validatingRecipients: nil),
            ParserResult.request(PaymentRequest(payments: [payment]))
        )
    }

    func testMultiplePaymentsRequestStartingWithNoParamIndex() throws {
        let expected = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = PaymentRequest(payments: [payment0, payment1])

        XCTAssertNoDifference(ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)), expected)
    }

    func testParsingMultiplePaymentsRequestStartingWithNoParamIndex() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.request(from: uriString)

        XCTAssertNoDifference(result, ParserResult.request(paymentRequest))
    }

    func testURIRequestWithInvalidCharsFails() throws {
        let invalidBase64URI = "zcash:u19spl3y4zu73twemxrzm33tm3eefepecv4zdssn0hfd4tjaqpgmlcm9nhyjqlvaytwpknqjqctvdscjmg47ex20j03cu4gx3zmy26y2hunpenvw083dmtlq4y7re5rwsygpteq57wwllr3zhs4rw43j5puxgrcqdq4f9dd38qksl4f9p2hc7x3kj582zdjxsnj8urmnc3msfjw72kej0?amount=0.01&memo=QTw+Qg"

        XCTAssertThrowsError(try ZIP321.request(from: invalidBase64URI))
    }
}
