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
        let request = try ZIP321.parse(url, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        let roundTrip = ZIP321.uriString(from: request, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true))
        #expect(roundTrip == url)
    }
}
