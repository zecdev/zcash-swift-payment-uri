//
//  RoundTripTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in  2025.
//

import Testing
@testable import ZcashPaymentURI

@Suite("RoundTrip")
struct RoundTripTests {
    @Test func example() throws {
        let url = "zcash:tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU?amount=123.45&label=apple+banana"
        let parserResult = try ZIP321.request(from: url, expecting: .testnet, validator: ReferenceAddressValidator.testnet)
        guard case ParserResult.request(let request) = parserResult else {
            Issue.record("Expected Request type, found \(parserResult)")
            return
        }

        let roundTrip = ZIP321.uriString(from: request, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true))
        #expect(roundTrip == url)
    }
}
