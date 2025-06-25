//
//  QcharStringTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-09.
//
   

import XCTest
@testable import ZcashPaymentURI
import CustomDump
final class QcharStringTests: XCTestCase {
    func testValidQcharStringIsInitialized() throws {
        let string = "valid QcharString"

        XCTAssertNotNil(QcharString(value: string))
    }

    func testThatQcharStringFromValidQcharEncodedStringIsNotInitialized() throws {
        let string = "Thank%20You!"

        let result = QcharString(value: string, strictMode: true)
        XCTAssertNil(result)
    }

    func testQcharStringFromEmptyStringFails() throws {
        XCTAssertNil(QcharString(value: ""))
    }

    func testQcharDecode() {
        XCTAssertEqual("nospecialcharacters".qcharDecode(), "nospecialcharacters")
    }

    func testQcharEncode() {
        XCTAssertEqual("nospecialcharacters".qcharEncoded(), "nospecialcharacters")
    }
}
