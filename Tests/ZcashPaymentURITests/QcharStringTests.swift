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

    @Test func qcharStringFromEmptyStringSucceeds() throws {
        // The empty string is a valid zero-length `*qchar` value (ZIP-321 allows an empty
        // `message=`/`label=`). It round-trips through both the encoded and decoded views.
        let empty = try #require(QcharString(value: ""))
        #expect(empty.value == "")
        #expect(empty.qcharValue == "")
    }

    @Test func qcharDecode() {
        #expect("nospecialcharacters".qcharDecode() == "nospecialcharacters")
    }

    @Test func qcharEncode() {
        #expect("nospecialcharacters".qcharEncoded() == "nospecialcharacters")
    }
}
