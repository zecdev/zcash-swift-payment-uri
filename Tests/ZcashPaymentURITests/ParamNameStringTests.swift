//
//  ParamNameStringTests.swift
//  zcash-swift-payment-uri
//
//  Created by Pacu in 2025-04-09.
//

import Testing
import ZcashPaymentURI

@Suite("ParamNameString")
struct ParamNameStringTests {
    @Test func validParamNameStringIsInitialized() {
        #expect(ParamNameString(value: "address") != nil)
    }

    @Test func invalidLeadingCharacterParamNameStringIsNotInitialized() {
        #expect(ParamNameString(value: "1address") == nil)
        #expect(ParamNameString(value: "+address") == nil)
        #expect(ParamNameString(value: "-address") == nil)
    }

    @Test func invalidCharacterFailsToInitialize() {
        #expect(ParamNameString(value: "addre*ss") == nil)
    }

    @Test func emptyStringFailstoInitialize() {
        #expect(ParamNameString(value: "") == nil)
    }
}
