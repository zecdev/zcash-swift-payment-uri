//
//  RecipientTests.swift
//
//
//  Created by Francisco Gindre on 2023-11-07.
//

import Testing
@testable import ZcashPaymentURI

@Suite("RecipientAddress")
struct RecipientTests {
    // MARK: The validator is the sole authority

    @Test func recipientInitIsNilWhenTheValidatorRejects() {
        let rejectEverything = ClosureAddressValidator { _ in nil }

        #expect(RecipientAddress(value: "asdf", validator: rejectEverything) == nil)
        #expect(
            RecipientAddress(
                value: "zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9slya",
                validator: rejectEverything
            ) == nil,
            "a validator's rejection is final even for a well-formed address"
        )
    }

    @Test func recipientTakesTheDescriptorFromTheValidatorVerbatim() throws {
        // Deliberately nonsensical: 'asdf' is not a Zcash address at all, and
        // the descriptor claims memo capability for a transparent recipient.
        // The library has no opinion — the validator is authoritative.
        let descriptor = AddressDescriptor(network: .regtest, isTransparent: true, canReceiveMemos: true)
        let recipient = try #require(
            RecipientAddress(value: "asdf", validator: ClosureAddressValidator { _ in descriptor })
        )

        #expect(recipient.value == "asdf")
        #expect(recipient.descriptor == descriptor)
        #expect(recipient.network == .regtest)
        #expect(recipient.isTransparent)
        #expect(recipient.canReceiveMemos)
    }

    @Test func recipientCanBeBuiltFromAnAlreadyValidatedAddress() {
        let descriptor = AddressDescriptor(network: .mainnet, isTransparent: false, canReceiveMemos: true)
        let recipient = RecipientAddress(value: "u1abc", descriptor: descriptor)

        #expect(recipient.value == "u1abc")
        #expect(recipient.network == .mainnet)
        #expect(!recipient.isTransparent)
        #expect(recipient.canReceiveMemos)
    }

    @Test func recipientsAreEqualWhenValueAndDescriptorAgree() {
        let descriptor = AddressDescriptor(network: .mainnet, isTransparent: true, canReceiveMemos: false)
        let other = AddressDescriptor(network: .testnet, isTransparent: true, canReceiveMemos: false)

        #expect(RecipientAddress(value: "t1a", descriptor: descriptor) == RecipientAddress(value: "t1a", descriptor: descriptor))
        #expect(RecipientAddress(value: "t1a", descriptor: descriptor) != RecipientAddress(value: "t1b", descriptor: descriptor))
        #expect(RecipientAddress(value: "t1a", descriptor: descriptor) != RecipientAddress(value: "t1a", descriptor: other))
    }

    // MARK: Sanity checks against the reference (test-only) validator

    @Test func recipientInitIsNilWhenTheReferenceValidatorRejectsGarbage() {
        #expect(RecipientAddress(value: "asdf", validator: ReferenceAddressValidator.mainnet) == nil)
    }

    @Test func recipientAddressDetectsInvalidCharacters() throws {
        #expect(
            RecipientAddress(
                value: "tmEZhbWHTpdKMw5it8YDspUXSMGQyFwovpUʔamount 1ꓸ234",
                validator: ReferenceAddressValidator.testnet
            ) == nil
        )
    }

    @Test func recipientAddressDetectsOrchardOnlyAddresses() throws {
        let orchardOnly = "u1ddnjsdcpm36r6aq79n3s68shjweksnmwtdltrh046s8m6xcws9ygyawalxx8n6hg6vegk0wh8zjnafxgh6msppjsljvyt0ynece3lvm0"

        #expect(RecipientAddress(value: orchardOnly, validator: ReferenceAddressValidator.mainnet) != nil)
    }

    @Test(arguments: TestVectors.unifiedAddresses)
    func recipientAddressWithUnifiedTestVector(_ ua: String) throws {
        #expect(
            RecipientAddress(value: ua, validator: ReferenceAddressValidator.mainnet) != nil,
            "Failed to create RecipientAddress for \(ua)"
        )
    }

    @Test func recipientAddressWithSaplingMainnet() throws {
        let sapling = "zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9slya"

        #expect(RecipientAddress(value: sapling, validator: ReferenceAddressValidator.mainnet) != nil)
    }
}
