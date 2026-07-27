//
//  OtherParamsTests.swift
//  zcash-swift-payment-uri
//
//  Created by pacu on 2025-03-27.
//

import Testing
@testable import ZcashPaymentURI

@Suite("OtherParam")
struct OtherParamsTests {
    @Test func properParameterDoesIsNotNil() throws {
        let key = "otherParam".asParamNameString!
        let value = "otherValue".asQcharString!

        let result = try OtherParam(key: key, value: value)

        #expect(result.key == key)
        #expect(result.value == value)
    }

    @Test func properKeyOnlyParameterDoesNotThrow() throws {
        #expect(throws: Never.self) {
            try OtherParam(key: "properkey".asParamNameString!, value: nil)
        }
    }

    @Test func reservedKeywordKeyedParametersFail() throws {
        #expect {
            try OtherParam(key: "address".asParamNameString!, value: "asdf".asQcharString!)
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("address") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "amount", value: "asdf")
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("amount") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "label", value: "asdf")
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("label") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "memo", value: "asdf")
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("memo") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "message", value: "asdf")
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("message") = error else { return false }
            return true
        }
    }

    @Test func reservedKeywordKeyedKeyOnlyParametersFail() throws {
        #expect {
            try OtherParam(key: "address", value: nil)
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("address") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "amount", value: nil)
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("amount") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "label", value: nil)
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("label") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "memo", value: nil)
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("memo") = error else { return false }
            return true
        }

        #expect {
            try OtherParam(key: "message", value: nil)
        } throws: { error in
            guard case ZIP321.Errors.otherParamUsesReservedKey("message") = error else { return false }
            return true
        }
    }

    @Test func nonQcharKeyOnlyFails() throws {
        #expect {
            try OtherParam(key: "ke#y", value: nil)
        } throws: { error in
            guard case ZIP321.Errors.otherParamEncodingError("ke#y") = error else { return false }
            return true
        }
    }

    @Test func nonQcharKeyWithValidValueFails() throws {
        #expect {
            try OtherParam(key: "ke#y", value: "validValue")
        } throws: { error in
            guard case ZIP321.Errors.otherParamEncodingError("ke#y") = error else { return false }
            return true
        }
    }
}
