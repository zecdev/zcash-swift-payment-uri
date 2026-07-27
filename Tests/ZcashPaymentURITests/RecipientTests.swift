//
//  RecipientTests.swift
//
//
//  Created by Francisco Gindre on 2023-11-07.
//

import Testing
@testable import ZcashPaymentURI

@Suite("RecipientAddress")
struct RecipientTests {
    @Test func recipientInitNilWhenValidationFails() {
        #expect(RecipientAddress(value: "asdf", context: .mainnet, validating: { _ in false }) == nil)
        #expect(RecipientAddress(value: "asdf", context: .testnet, validating: { _ in false }) == nil)
        #expect(RecipientAddress(value: "asdf", context: .regtest, validating: { _ in false }) == nil)
    }

    @Test func recipientInitNilWhenContextValidationFailsAndCustomValidationDoesNot() {
        let expected = "asdf"
        let recipient = RecipientAddress(value: expected, context: .mainnet, validating: { _ in true })

        #expect(recipient == nil)
    }

    @Test func recipientInitNilWhenNoCustomValidationProvidedWithInvalidAddress() {
        let expected = "asdf"
        let recipient = RecipientAddress(value: expected, context: .mainnet)

        #expect(recipient == nil)
    }

    @Test func prefixValidationRejectsSproutAddresses() {
        #expect(!ParserContext.mainnet.isValid(address: "zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y"))
        #expect(!ParserContext.testnet.isValid(address: "ztJ1EWLKcGwF2S4NA17pAJVdco8Sdkz4AQPxt1cLTEfNuyNswJJc2BbBqYrsRZsp31xbVZwhF7c7a2L9jsF3p3ZwRWpqqyS"))
        #expect(!ParserContext.regtest.isValid(address: "ztJ1EWLKcGwF2S4NA17pAJVdco8Sdkz4AQPxt1cLTEfNuyNswJJc2BbBqYrsRZsp31xbVZwhF7c7a2L9jsF3p3ZwRWpqqyS"))
    }

    @Test func detectsPossibleTransparentRecipientEncoding() {
        #expect(!ParserContext.mainnet.isTransparent(address: "zs1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpq6d8g"))
        #expect(!ParserContext.testnet.isTransparent(address: "ztestsapling1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqfhgwqu"))
        #expect(!ParserContext.testnet.isTransparent(address: "zregtestsapling1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqknpr3m"))

        #expect(ParserContext.mainnet.isTransparent(address: "t1Hsc1LR8yKnbbe3twRp88p6vFfC5t7DLbs"))
        #expect(ParserContext.testnet.isTransparent(address: "t26YoyZ1iPgiMEWL4zGUm74eVWfhyDMXzY2"))
        #expect(ParserContext.mainnet.isTransparent(address: "t3JZcvsuaXE6ygokL4XUiZSTrQBUoPYFnXJ"))
        #expect(ParserContext.mainnet.isTransparent(address: "tex1s2rt77ggv6q989lr49rkgzmh5slsksa9khdgte"))
        #expect(ParserContext.testnet.isTransparent(address: "textest1qyqszqgpqyqszqgpqyqszqgpqyqszqgpfcjgfy"))
    }

    @Test func recipientAddressDetectsInvalidCharacters() throws {
        #expect(RecipientAddress(value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpUʔamount 1ꓸ234", context: .testnet) == nil)
    }

    @Test func recipientAddressDetectsOrchardOnlyAddresses() throws {
        #expect(RecipientAddress(value: "u1ddnjsdcpm36r6aq79n3s68shjweksnmwtdltrh046s8m6xcws9ygyawalxx8n6hg6vegk0wh8zjnafxgh6msppjsljvyt0ynece3lvm0", context: .mainnet) != nil)
    }

    @Test(arguments: TestVectors.unifiedAddresses)
    func recipientAddressWithUnifiedTestVector(_ ua: String) throws {
        #expect(RecipientAddress(value: ua, context: .mainnet) != nil, "Failed to create RecipientAddress for \(ua)")
    }

    @Test func recipientAddressWithSaplingMainnet() throws {
        #expect(RecipientAddress(value: "zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9slya", context: .mainnet) != nil)
    }
}
