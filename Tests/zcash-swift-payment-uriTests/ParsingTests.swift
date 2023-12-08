//
//  ParsingTests.swift
//  
//
//  Created by Francisco Gindre on 12/7/23.
//

import XCTest
@testable import zcash_swift_payment_uri

// swiftlint:disable line_length
final class ParsingTests: XCTestCase {
    func disabled_testThrowsWhenParsingInvalidBase64() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBp;cyBhIHNpbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
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

    func disabled_testThrowsWhenMemoIsInvalid() {
        let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=1&memo=VGhpcyBpcyBhVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgVGhpcyBpcyBhIHNqqqw222ncssspbXBsZSBtZW1vLgIHNqqqw222ncssspbXBsZSBtZW1vLg&message=Thank%20you%20for%20your%20purchase"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.memoBytesError(.memoTooLong))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.memoBytesError(.memoTooLong):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.memoBytesError(.memoTooLong)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    func disabled_testThrowsWhenURIHasTooManyPayments() {}
    /// invalid; amount component exceeds an i64
    /// 9223372036854775808 = i64::MAX + 1
    func disabled_testThrowsWhenAmountExceedsSupply() {
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
    func disabled_testThrowsWhenAmountIsMaxMoney() {
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
    func disabled_testThrowsWhenAmountIsTooSmall() {
       let invalidURI = "zcash:ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez?amount=18446744073709551624"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.amountTooSmall(0))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.amountTooSmall(0):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.amountTooSmall(0)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
    /// invalid; duplicate `amount=` field/
    func disabled_testThrowsWhenThereAreDuplicateParameters() {
        let invalidURI = "zcash:?amount=1.234&amount=2.345&address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU"
        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.duplicateParameter("amount", 0))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.duplicateParameter("amount", 0):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.duplicateParameter("amount", 0)))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; duplicate `amount.1=` field
    func disabled_testThrowsWhenThereAreDuplicateParametersWithParamIndex() {
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

    func disabled_testThrowsWhenMemoIsAssignedToTransparentRecipient() {
        let invalidURI = "zcash:?address=tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU&amount=123.456&memo=eyAia2V5IjogIlRoaXMgaXMgYSBKU09OLXN0cnVjdHVyZWQgbWVtby4iIH0&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=0.789&memo.1=VGhpcyBpcyBhIHVuaWNvZGUgbWVtbyDinKjwn6aE8J-PhvCfjok"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.transparentMemoNotAllowed(0))) but none was"
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
    /// invalid; missing `address=`/
    func disabled_testThrowsWhenRecipientIsMissingNoParamIndex() {
        let invalidURI = "zcash:?amount=3491405.05201255&address.1=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.1=5740296.87793245"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.recipientMissing)) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.recipientMissing:
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.recipientMissing))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }

    /// invalid; missing `address.1=`/
    func disabled_testThrowsWhenRecipientIsMissingWithParamIndex() {
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
    func disabled_testThrowsWhenParamIndexIsZero() {
        let invalidURI = "zcash:?address.0=ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez&amount.0=2"

        XCTAssertThrowsError(
            try ZIP321.request(from: invalidURI),
            "should have thrown \(String(describing: ZIP321.Errors.invalidParamIndex("address.0"))) but none was"
        ) { err in
            switch err {
            case ZIP321.Errors.invalidParamIndex("address.0"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.invalidParamIndex("address.0")))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
}
