//
//  OtherParamsTests.swift
//  zcash-swift-payment-uri
//
//  Created by pacu on 2025-03-27.
//

import XCTest
@testable import ZcashPaymentURI
final class OtherParamsTests: XCTestCase {

    func testProperParameterDoesIsNotNil() throws {
        let key = "otherParam".asParamNameString!
        let value = "otherValue".asQcharString!

        let result = try OtherParam(key: key, value: value)

        
        XCTAssertEqual(result.key, key)
        XCTAssertEqual(result.value, value)
    }
    
    func testProperKeyOnlyParameterDoesNotThrow() throws {
        XCTAssertNoThrow(try OtherParam(key: "properkey".asParamNameString!, value: nil))
    }
    
    func testReservedKeywordKeyedParametersFail() throws {
        XCTAssertThrowsError(try OtherParam(key: "address".asParamNameString!, value: "asdf".asQcharString!)) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("address"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("address=asdf")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "amount", value: "asdf")) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("amount"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("amount")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "label", value: "asdf")) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("label"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("label")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "memo", value: "asdf")) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("memo"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("memo")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "message", value: "asdf")) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("message"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("message")))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
    
    func testReservedKeywordKeyedKeyOnlyParametersFail() throws {
        XCTAssertThrowsError(try OtherParam(key: "address", value: nil)) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("address"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("address")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "amount", value: nil)) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("amount"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("amount")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "label", value: nil)) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("label"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("label")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "memo", value: nil)) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("memo"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("memo")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

        XCTAssertThrowsError(try OtherParam(key: "message", value: nil)) { err in

            switch err {
            case ZIP321.Errors.otherParamUsesReservedKey("message"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamUsesReservedKey("message")))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
    
    func testNonQcharKeyOnlyFails() throws {
        XCTAssertThrowsError(try OtherParam(key: "ke#y", value: nil)) { err in

            switch err {
            case ZIP321.Errors.otherParamEncodingError("ke#y"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamEncodingError("ke#y")))
                        but \(err) was thrown instead
                        """
                )
            }
        }
    }
    
    func testNonQcharKeyWithValidValueFails() throws {
        XCTAssertThrowsError(try OtherParam(key: "ke#y", value: "validValue")) { err in

            switch err {
            case ZIP321.Errors.otherParamEncodingError("ke#y"):
                XCTAssert(true)
            default:
                XCTFail(
                        """
                        Expected \(String(describing: ZIP321.Errors.otherParamEncodingError("ke#y")))
                        but \(err) was thrown instead
                        """
                )
            }
        }

    }
}
