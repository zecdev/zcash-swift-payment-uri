//
//  EncodingTests.swift
//  
//
//  Created by Francisco Gindre on 2023-11-13
//

import XCTest
@testable import ZcashPaymentURI
final class EncodingTests: XCTestCase {
    func test_qcharEncodedStringContainsAllowedCharactersOnly() {
        let message = "sk8:forever@!"

        XCTAssertEqual(message, message.qcharEncoded())
    }

    func test_qcharEncodedStringHasPercentEncodedDisallowedCharecters() throws {
        XCTAssertEqual(
            "Thank you for your purchase".qcharEncoded(),
            "Thank%20you%20for%20your%20purchase"
        )

        XCTAssertEqual(
            "Use Coupon [ZEC4LIFE] to get a 20% discount on your next purchase!!".qcharEncoded(),
            "Use%20Coupon%20%5BZEC4LIFE%5D%20to%20get%20a%2020%25%20discount%20on%20your%20next%20purchase!!"
        )

        XCTAssertEqual("Order #321".qcharEncoded(), "Order%20%23321")

        XCTAssertEqual("Your Ben & Jerry's Order".qcharEncoded(), "Your%20Ben%20%26%20Jerry's%20Order")

        XCTAssertEqual(" ".qcharEncoded(), "%20")
        XCTAssertEqual("\"".qcharEncoded(), "%22")
        XCTAssertEqual("#".qcharEncoded(), "%23")
        XCTAssertEqual("%".qcharEncoded(), "%25")
        XCTAssertEqual("&".qcharEncoded(), "%26")
        XCTAssertEqual("/".qcharEncoded(), "%2F")
        XCTAssertEqual("<".qcharEncoded(), "%3C")
        XCTAssertEqual("=".qcharEncoded(), "%3D")
        XCTAssertEqual(">".qcharEncoded(), "%3E")
        XCTAssertEqual("?".qcharEncoded(), "%3F")
        XCTAssertEqual("[".qcharEncoded(), "%5B")
        XCTAssertEqual("\\".qcharEncoded(), "%5C")
        XCTAssertEqual("]".qcharEncoded(), "%5D")
        XCTAssertEqual("^".qcharEncoded(), "%5E")
        XCTAssertEqual("`".qcharEncoded(), "%60")
        XCTAssertEqual("{".qcharEncoded(), "%7B")
        XCTAssertEqual("|".qcharEncoded(), "%7C")
        XCTAssertEqual("}".qcharEncoded(), "%7D")
    }

    func test_thatUnallowedCharactersAreEscaped() {
        let unallowedCharacters = [
            " ",    /// "0x20"
            "\"",   /// "0x22"
            "#",    /// "0x23"
            "%",    /// "0x25"
            "&",    /// "0x26"
            "/",    /// "0x2F"
            "<",    /// "0x3C"
            "=",    /// "0x3D"
            ">",    /// "0x3E"
            "?",    /// "0x3F"
            "[",    /// "0x5B"
            "\\",   /// "0x5C"
            "]",    /// "0x5D"
            "^",    /// "0x5E"
            "`",    /// "0x60"
            "{",    /// "0x7B"
            "|",    /// "0x7C"
            "}"     /// "0x7D"
        ]

        unallowedCharacters.forEach { unallowed in
            guard let qcharEncoded = unallowed.qcharEncoded() else {
                XCTFail("Character '\(unallowed)' should have been qchar-encoded but returned `nil`.")
                return
            }

            XCTAssert(qcharEncoded.contains(where: { $0 == "%" }), "Character '\(unallowed) should have been percent-encoded but it was not.")
        }

        (0x00...0x1F)
            .map { UnicodeScalar($0) }
            .map { String($0) }
            .forEach { controlChar in
                guard let qcharEncoded = controlChar.qcharEncoded() else {
                    XCTFail("Control character '\(controlChar)' should have been qchar-encoded but returned `nil`.")
                    return
                }

                XCTAssert(
                    qcharEncoded.contains(where: { $0 == "%" }),
                    "Control character '\(controlChar) should have been percent-encoded but it was not."
                )
            }
    }
}
