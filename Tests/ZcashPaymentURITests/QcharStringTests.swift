//
//  QcharStringTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-09.
//

import Testing
@testable import ZcashPaymentURI

@Suite("QcharString")
struct QcharStringTests {
    @Test func validQcharStringIsInitialized() throws {
        let string = "valid QcharString"

        #expect(QcharString(value: string) != nil)
    }

    @Test func thatQcharStringFromValidQcharEncodedStringIsNotInitialized() throws {
        let string = "Thank%20You!"

        let result = QcharString(value: string, strictMode: true)
        #expect(result == nil)
    }

    @Test func qcharStringFromEmptyStringFails() throws {
        #expect(QcharString(value: "") == nil)
    }

    @Test func qcharDecode() {
        #expect("nospecialcharacters".qcharDecode() == "nospecialcharacters")
    }

    @Test func qcharEncode() {
        #expect("nospecialcharacters".qcharEncoded() == "nospecialcharacters")
    }
}
