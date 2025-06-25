//
//  RoundTripTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in  2025.
//    
   

import XCTest
@testable import ZcashPaymentURI
final class RoundTripTests: XCTestCase {


    func testExample() throws {
        let url = "zcash:tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU?amount=123.45&label=apple+banana"
        let parserResult = try ZIP321.request(from: url, context: .testnet)
        guard case ParserResult.request(let request) = parserResult else {
            XCTFail("Expected Request type, foudn \(parserResult)")
            return
        }


        let roundTrip = ZIP321.uriString(from: request, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true))
        XCTAssertEqual(roundTrip, url)

    
    }



}
