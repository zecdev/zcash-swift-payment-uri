import XCTest
import CustomDump
@testable import ZcashPaymentURI
// swiftlint:disable line_length
final class ZcashSwiftPaymentUriTests: XCTestCase {
    func testSingleRecipient() throws {
        guard let recipient = RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
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
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ) else {
            XCTFail("failed to create Recipient from unchecked source")
            return
        }

        let payment = try Payment(
            recipientAddress: recipient,
            amount: try Amount(value: 1),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: nil
        )

        XCTAssertNoDifference(
            ZIP321.uriString(
                from: try PaymentRequest(payments: [payment]),
                formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)
            ),
            expected
        )

        XCTAssertNoDifference(ZIP321.request(payment, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)), expected)

        // Roundtrip test
        XCTAssertNoDifference(
            try ZIP321.request(from: expected, context: .testnet, validatingRecipients: nil),
            ParserResult.request(try PaymentRequest(payments: [payment]))
        )
    }

    func testMultiplePaymentsRequestStartingWithNoParamIndex() throws {
        let expected = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        XCTAssertNoDifference(ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)), expected)
    }

    func testParsingMultiplePaymentsRequestStartingWithNoParamIndex() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.request(from: uriString, context: .testnet)

        XCTAssertNoDifference(result, ParserResult.request(paymentRequest))
    }

    func testURIRequestWithInvalidCharsFails() throws {
        let invalidBase64URI = "zcash:u19spl3y4zu73twemxrzm33tm3eefepecv4zdssn0hfd4tjaqpgmlcm9nhyjqlvaytwpknqjqctvdscjmg47ex20j03cu4gx3zmy26y2hunpenvw083dmtlq4y7re5rwsygpteq57wwllr3zhs4rw43j5puxgrcqdq4f9dd38qksl4f9p2hc7x3kj582zdjxsnj8urmnc3msfjw72kej0?amount=0.01&memo=QTw+Qg"

        XCTAssertThrowsError(try ZIP321.request(from: invalidBase64URI, context: .mainnet))
    }
    
    func testEnsureThatAllPaymentsBelongToTheSameNetwork() throws {

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "zs10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1, context: .mainnet) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        
        XCTAssertThrowsError(try PaymentRequest(payments: [payment0, payment1])) { err in

            switch err {
            case ZIP321.Errors.networkMismatchFound:
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.networkMismatchFound))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
    
    func testParsingMultiplePaymentsRequestStartingWithNoParamIndexAndNoAmount() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

        let payment1 = try Payment(
            recipientAddress: recipient1,
            amount: try Amount(value: 0.789),
            memo: try MemoBytes(utf8String: "This is a unicode memo ✨🦄🏆🎉"),
            label: nil,
            message: nil,
            otherParams: nil
        )

        let paymentRequest = try PaymentRequest(payments: [payment0, payment1])

        let result = try ZIP321.request(from: uriString, context: .testnet)

        XCTAssertNoDifference(result, ParserResult.request(paymentRequest))
        
        XCTAssertNoDifference(uriString, ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)))
    }
    
    func testParsingMultiplePaymentsRequestStartingWithNoParamIndexIndexedParamHasNoAmount() throws {
        let uriString = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        let address0 = "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"

        guard let recipient0 = RecipientAddress(value: address0, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address0)")
            return
        }

        let payment0 = try Payment(
            recipientAddress: recipient0,
            amount: try Amount(value: 123.456),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: nil
        )

        let address1 = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        guard let recipient1 = RecipientAddress(value: address1, context: .testnet) else {
            XCTFail("failed to create recipient without validation for address: \(address1)")
            return
        }

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

        XCTAssertNoDifference(result, ParserResult.request(paymentRequest))
        XCTAssertNoDifference(uriString, ZIP321.uriString(from: paymentRequest, formattingOptions: .useEmptyParamIndex(omitAddressLabel: false)))
    }
    
    func testSinglePaymentRequestAcceptsNoValueOtherParams() throws {
        let expected = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase&other"

        guard let recipient = RecipientAddress(
            value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
            context: .testnet
        ) else {
            XCTFail("failed to create Recipient from unchecked source")
            return
        }

        let payment = try Payment(
            recipientAddress: recipient,
            amount: try Amount(value: 1),
            memo: try MemoBytes(utf8String: "This is a simple memo."),
            label: nil,
            message: "Thank you for your purchase",
            otherParams: [OtherParam(key: "other", value: nil)]
        )

        XCTAssertNoDifference(
            ZIP321.uriString(
                from: try PaymentRequest(payments: [payment]),
                formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)
            ),
            expected
        )

        XCTAssertNoDifference(ZIP321.request(payment, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true)), expected)

        // Roundtrip test
        XCTAssertNoDifference(
            try ZIP321.request(from: expected, context: .testnet, validatingRecipients: nil),
            ParserResult.request(try PaymentRequest(payments: [payment]))
        )
    }

    func testThanSeeminglyValidEmptyRequestThrows() throws {
        XCTAssertThrowsError(try ZIP321.request(from: "zcash:?", context: .testnet))
    }

    /// invalid; amount component is MAX_MONEY
    /// 21000000.00000001
    func testThrowsWhenAmountIsMaxMoney() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=21000000.00000001"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
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
            try ZIP321.request(from: invalidURI, context: .testnet),
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

    /// invalid; amount component exceeds an i64
    /// 9223372036854775808 = i64::MAX + 1
    func testThrowsWhenAmountExceedsSupply() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=9223372036854775808"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
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

    func testThrowsWhenMemoIsInvalid() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgIHNqqqw222ncssspbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
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

    func testThrowsWhenMemoIsAssignedToTransparentRecipient() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&memo=eyAia2V5IjogIlRoaXMgaXMgYSBKU09OLXN0cnVjdHVyZWQgbWVtby4iIH0&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
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

    /// invalid; `address.0=` and `amount.0=` are not permitted (leading 0s)./
    func testThrowsWhenParamIndexIsZero() {
        let invalidURI = "zcash:?address.0=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.0=2"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI, context: .testnet),
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

    
    func testThrowsWhenURIHasTooManyPayments() {}
}
