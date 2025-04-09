//
//  ParamNameStringTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-09.
//
   

import XCTest
import ZcashPaymentURI
final class ParamNameStringTests: XCTestCase {
    func testValidParamNameStringIsInitialized() {
        XCTAssertNotNil(ParamNameString(value: "address"))
    }

    func testInvalidLeadingCharacterParamNameStringIsNotInitialized() {
        XCTAssertNil(ParamNameString(value: "1address"))
        XCTAssertNil(ParamNameString(value: "+address"))
        XCTAssertNil(ParamNameString(value: "-address"))
    }

    func testInvalidCharacterFailsToInitialize() {
        XCTAssertNil(ParamNameString(value: "addre*ss"))
    }

    func testEmptyStringFailstoInitialize() {
        XCTAssertNil(ParamNameString(value: ""))
    }
}
