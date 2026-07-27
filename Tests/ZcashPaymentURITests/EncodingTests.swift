//
//  EncodingTests.swift
//
//
//  Created by Francisco Gindre on 2023-11-13
//

import Testing
@testable import ZcashPaymentURI

@Suite("Encoding")
struct EncodingTests {
    @Test func qcharEncodedStringContainsAllowedCharactersOnly() {
        let message = "sk8:forever@!"

        #expect(message == message.qcharEncoded())
    }

    @Test func qcharEncodedStringHasPercentEncodedDisallowedCharecters() throws {
        #expect(
            "Thank you for your purchase".qcharEncoded()
            == "Thank%20you%20for%20your%20purchase"
        )

        #expect(
            "Use Coupon [ZEC4LIFE] to get a 20% discount on your next purchase!!".qcharEncoded()
            == "Use%20Coupon%20%5BZEC4LIFE%5D%20to%20get%20a%2020%25%20discount%20on%20your%20next%20purchase!!"
        )

        #expect("Order #321".qcharEncoded() == "Order%20%23321")

        #expect("Your Ben & Jerry's Order".qcharEncoded() == "Your%20Ben%20%26%20Jerry's%20Order")

        #expect(" ".qcharEncoded() == "%20")
        #expect("\"".qcharEncoded() == "%22")
        #expect("#".qcharEncoded() == "%23")
        #expect("%".qcharEncoded() == "%25")
        #expect("&".qcharEncoded() == "%26")
        #expect("/".qcharEncoded() == "%2F")
        #expect("<".qcharEncoded() == "%3C")
        #expect("=".qcharEncoded() == "%3D")
        #expect(">".qcharEncoded() == "%3E")
        #expect("?".qcharEncoded() == "%3F")
        #expect("[".qcharEncoded() == "%5B")
        #expect("\\".qcharEncoded() == "%5C")
        #expect("]".qcharEncoded() == "%5D")
        #expect("^".qcharEncoded() == "%5E")
        #expect("`".qcharEncoded() == "%60")
        #expect("{".qcharEncoded() == "%7B")
        #expect("|".qcharEncoded() == "%7C")
        #expect("}".qcharEncoded() == "%7D")
    }

    @Test func thatUnallowedCharactersAreEscaped() {
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

        for unallowed in unallowedCharacters {
            guard let qcharEncoded = unallowed.qcharEncoded() else {
                Issue.record("Character '\(unallowed)' should have been qchar-encoded but returned `nil`.")
                continue
            }

            #expect(
                qcharEncoded.contains(where: { $0 == "%" }),
                "Character '\(unallowed) should have been percent-encoded but it was not."
            )
        }

        for controlChar in (0x00...0x1F).map({ UnicodeScalar($0) }).map({ String($0) }) {
            guard let qcharEncoded = controlChar.qcharEncoded() else {
                Issue.record("Control character '\(controlChar)' should have been qchar-encoded but returned `nil`.")
                continue
            }

            #expect(
                qcharEncoded.contains(where: { $0 == "%" }),
                "Control character '\(controlChar) should have been percent-encoded but it was not."
            )
        }
    }

    @Test func thatCharacterEnsuringFunctionWorks() {
        #expect("asdfghjklqwrtyuiopzxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM".conformsToCharacterSet(.ASCIIAlphaNum))
        #expect(!"asd fghjklqwrtyuiopzxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM".conformsToCharacterSet(.ASCIIAlphaNum))
        #expect("1234567890".conformsToCharacterSet(.ASCIINum))
        #expect(!"1234a567890".conformsToCharacterSet(.ASCIINum))
    }
}
