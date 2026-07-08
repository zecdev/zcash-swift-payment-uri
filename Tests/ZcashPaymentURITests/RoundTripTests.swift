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

    /// The round-trip law for the DEFAULT rendering options:
    /// `parse(uriString(from: r)) == r` for every request `r`.
    ///
    /// Exercised over EVERY request produced by the shared conformance
    /// corpus's valid vectors (which are oracle-verified against the
    /// librustzcash `zip321` reference) — including the bare `zcash:<addr>`
    /// vectors, which are ordinary one-payment requests now that the parsed
    /// model no longer distinguishes the two single-recipient spellings.
    @Test(arguments: try ConformanceCorpus.validVectors())
    func defaultRenderRoundTripsForCorpusRequests(_ vector: ConformanceValidVector) throws {
        let network: Network
        switch vector.network {
        case "main": network = .mainnet
        case "test": network = .testnet
        case "regtest": network = .regtest
        default:
            Issue.record("\(vector.name): unknown network '\(vector.network)'")
            return
        }

        let validator = ReferenceAddressValidator.of(network)
        let request = try ZIP321.parse(vector.uri, expecting: network, validator: validator).get()

        // Render with the DEFAULT options, then parse back and assert equality.
        let rendered = ZIP321.uriString(from: request)
        let reparsed = try ZIP321.parse(rendered, expecting: network, validator: validator).get()

        #expect(
            reparsed == request,
            "\(vector.name): round-trip law violated — parse(uriString(from: r)) != r (rendered: \(rendered))"
        )
    }
}
