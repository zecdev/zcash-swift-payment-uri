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
        let result = try OtherParam(name: "otherParam", value: "otherValue")

        #expect(result.name == "otherParam")
        #expect(result.value == "otherValue")
    }

    @Test func properKeyOnlyParameterDoesNotThrow() throws {
        #expect(throws: Never.self) {
            try OtherParam(name: "properkey", value: nil)
        }
    }

    @Test func reservedKeywordKeyedParametersFail() throws {
        for reserved in ["address", "amount", "label", "memo", "message"] {
            #expect {
                try OtherParam(name: reserved, value: "asdf")
            } throws: { error in
                guard case ZIP321.Errors.otherParamUsesReservedKey(reserved) = error else { return false }
                return true
            }
        }
    }

    @Test func reservedKeywordKeyedKeyOnlyParametersFail() throws {
        for reserved in ["address", "amount", "label", "memo", "message"] {
            #expect {
                try OtherParam(name: reserved, value: nil)
            } throws: { error in
                guard case ZIP321.Errors.otherParamUsesReservedKey(reserved) = error else { return false }
                return true
            }
        }
    }

    @Test func nonQcharKeyOnlyFails() throws {
        #expect {
            try OtherParam(name: "ke#y", value: nil)
        } throws: { error in
            guard case ZIP321.Errors.otherParamEncodingError("ke#y") = error else { return false }
            return true
        }
    }

    @Test func nonQcharKeyWithValidValueFails() throws {
        #expect {
            try OtherParam(name: "ke#y", value: "validValue")
        } throws: { error in
            guard case ZIP321.Errors.otherParamEncodingError("ke#y") = error else { return false }
            return true
        }
    }

    @Test func emptyKeyFails() throws {
        #expect {
            try OtherParam(name: "", value: "validValue")
        } throws: { error in
            guard case ZIP321.Errors.otherParamKeyEmpty = error else { return false }
            return true
        }
    }

    // MARK: - `otherParams` is an always-present array

    /// There is no nil/empty distinction to observe: a payment built with no
    /// other params reports an EMPTY array, not `nil`.
    @Test func aPaymentWithoutOtherParamsHasAnEmptyArray() throws {
        let recipient = RecipientAddress(
            value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
            descriptor: AddressDescriptor(network: .testnet, isTransparent: true, canReceiveMemos: false)
        )

        let implicit = try Payment.create(
            recipientAddress: recipient,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil
        ).get()

        let explicit = try Payment.create(
            recipientAddress: recipient,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        #expect(implicit.otherParams.isEmpty)
        #expect(implicit == explicit)
    }

    /// construct -> render -> parse is the invariant that motivates the
    /// always-array shape: an empty other-param list must survive a round trip
    /// unchanged (and could not, if `nil` and `[]` were distinguishable).
    ///
    /// - Note: the canonical leading-address form is requested explicitly here;
    /// the default rendering mode only becomes the canonical one in S13.
    @Test func emptyOtherParamsSurviveTheRoundTrip() throws {
        let recipient = try #require(
            RecipientAddress(
                value: "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez",
                validator: ReferenceAddressValidator.testnet
            )
        )

        let payment = try Payment.create(
            recipientAddress: recipient,
            amount: try NonNegativeAmount.zec("1.2345").get(),
            memo: nil,
            label: nil,
            message: nil,
            otherParams: []
        ).get()

        let request = try PaymentRequest(payments: [payment])
        let uri = ZIP321.uriString(from: request, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true))
        let reparsed = try ZIP321.parse(uri, expecting: .testnet, validator: ReferenceAddressValidator.testnet).get()

        #expect(reparsed == request)
        #expect(reparsed.payments.first?.otherParams.isEmpty == true)
    }

    /// The parse side agrees: a URI WITHOUT other params yields an empty array,
    /// and one WITH them yields exactly those, in order. Nothing anywhere
    /// reports "absent".
    @Test func parsedOtherParamsAreAlwaysAnArray() throws {
        let address = "ztestsapling10yy2ex5dcqkclhc7z7yrnjq2z6feyjad56ptwlfgmy77dmaqqrl9gyhprdx59qgmsnyfska2kez"

        let withoutOthers = try ZIP321.parse(
            "zcash:\(address)?amount=1",
            expecting: .testnet,
            validator: ReferenceAddressValidator.testnet
        ).get()

        #expect(withoutOthers.payments.first?.otherParams == [])

        let withOthers = try ZIP321.parse(
            "zcash:\(address)?amount=1&invoice=42&flag",
            expecting: .testnet,
            validator: ReferenceAddressValidator.testnet
        ).get()

        #expect(
            withOthers.payments.first?.otherParams
            == [try OtherParam(name: "invoice", value: "42"), try OtherParam(name: "flag", value: nil)]
        )
    }

    // MARK: - Duplicate other-param names are rejected at construction

    /// The parser already rejects `?foo=1&foo=2` as a duplicate parameter.
    /// Programmatic construction must agree, or a `Payment` could be built that
    /// renders to a URI that will not parse back.
    @Test func duplicateOtherParamNamesAreRejected() throws {
        let recipient = RecipientAddress(
            value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
            descriptor: AddressDescriptor(network: .testnet, isTransparent: true, canReceiveMemos: false)
        )

        let result = Payment.create(
            recipientAddress: recipient,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: [
                try OtherParam(name: "invoice", value: "42"),
                try OtherParam(name: "invoice", value: "43"),
            ]
        )

        #expect(result == .failure(.duplicateParameter(name: "invoice", index: nil)))
    }

    /// The first repeat wins, and a repeat with a DIFFERENT value is rejected
    /// just the same as one with an identical value.
    @Test func duplicateOtherParamNamesAreRejectedRegardlessOfValue() throws {
        let recipient = RecipientAddress(
            value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
            descriptor: AddressDescriptor(network: .testnet, isTransparent: true, canReceiveMemos: false)
        )

        for values in [(String?("x"), String?("x")), (String?("x"), String?(nil))] {
            let result = Payment.create(
                recipientAddress: recipient,
                amount: nil,
                memo: nil,
                label: nil,
                message: nil,
                otherParams: [
                    try OtherParam(name: "dup", value: values.0),
                    try OtherParam(name: "other", value: "keep"),
                    try OtherParam(name: "dup", value: values.1),
                ]
            )

            #expect(result == .failure(.duplicateParameter(name: "dup", index: nil)))
        }
    }

    /// Distinct names are fine, including names that only differ in case.
    @Test func distinctOtherParamNamesAreAccepted() throws {
        let recipient = RecipientAddress(
            value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpU",
            descriptor: AddressDescriptor(network: .testnet, isTransparent: true, canReceiveMemos: false)
        )

        let result = Payment.create(
            recipientAddress: recipient,
            amount: nil,
            memo: nil,
            label: nil,
            message: nil,
            otherParams: [
                try OtherParam(name: "dup", value: "1"),
                try OtherParam(name: "Dup", value: "2"),
            ]
        )

        #expect(try result.get().otherParams.count == 2)
    }
}
