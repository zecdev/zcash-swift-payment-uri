//
//  RecipientTests.swift
//  
//
//  Created by Francisco Gindre on 2023-11-07.
//

import XCTest
@testable import ZcashPaymentURI
final class RecipientTests: XCTestCase {
    func testRecipientInitNilWhenValidationFails() {
        XCTAssertNil(RecipientAddress(value: "asdf", context: .mainnet, validating: { _ in false }))
        XCTAssertNil(RecipientAddress(value: "asdf", context: .testnet, validating: { _ in false }))
        XCTAssertNil(RecipientAddress(value: "asdf", context: .regtest, validating: { _ in false }))
    }

    func testRecipientInitNilWhenContextValidationFailsAndCustomValidationDoesNot() {
        let expected = "asdf"
        let recipient = RecipientAddress(value: expected, context: .mainnet, validating: { _ in true })

        XCTAssertNil(recipient)
        
    }

    func testRecipientInitNilWhenNoCustomValidationProvidedWithInvalidAddress() {
        let expected = "asdf"
        let recipient = RecipientAddress(value: expected, context: .mainnet)

        XCTAssertNil(recipient)
        
    }
    
    func testPrefixValidationRejectsSproutAddresses() {
        XCTAssertFalse(ParserContext.mainnet.isValid(address:"zc8E5gYid86n4bo2Usdq1cpr7PpfoJGzttwBHEEgGhGkLUg7SPPVFNB2AkRFXZ7usfphup5426dt1buMmY3fkYeRrQGLa8y"))
        XCTAssertFalse(ParserContext.testnet.isValid(address: "ztJ1EWLKcGwF2S4NA17pAJVdco8Sdkz4AQPxt1cLTEfNuyNswJJc2BbBqYrsRZsp31xbVZwhF7c7a2L9jsF3p3ZwRWpqqyS"))
        XCTAssertFalse(ParserContext.regtest.isValid(address:"ztJ1EWLKcGwF2S4NA17pAJVdco8Sdkz4AQPxt1cLTEfNuyNswJJc2BbBqYrsRZsp31xbVZwhF7c7a2L9jsF3p3ZwRWpqqyS"))
    }
    
    func testDetectsPossibleTransparentRecipientEncoding() {
        XCTAssertFalse(ParserContext.mainnet.isTransparent(address: "zs1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpq6d8g"))
        XCTAssertFalse(ParserContext.testnet.isTransparent(address: "ztestsapling1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqfhgwqu"))
        XCTAssertFalse(ParserContext.testnet.isTransparent(address:"zregtestsapling1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqknpr3m"))
        
        XCTAssertTrue(ParserContext.mainnet.isTransparent(address: "t1Hsc1LR8yKnbbe3twRp88p6vFfC5t7DLbs"))
        XCTAssertTrue(ParserContext.testnet.isTransparent(address: "t26YoyZ1iPgiMEWL4zGUm74eVWfhyDMXzY2"))
        XCTAssertTrue(ParserContext.mainnet.isTransparent(address: "t3JZcvsuaXE6ygokL4XUiZSTrQBUoPYFnXJ"))
        XCTAssertTrue(ParserContext.mainnet.isTransparent(address: "tex1s2rt77ggv6q989lr49rkgzmh5slsksa9khdgte"))
        XCTAssertTrue(ParserContext.testnet.isTransparent(address: "textest1qyqszqgpqyqszqgpqyqszqgpqyqszqgpfcjgfy"))
        
    }
    
    func testRecipientAddressDetectsInvalidCharacters() throws {
        XCTAssertNil(RecipientAddress(value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpUʔamount 1ꓸ234", context: .testnet))
    }
}
