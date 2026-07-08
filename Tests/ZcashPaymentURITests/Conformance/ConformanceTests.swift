//
//  ConformanceTests.swift
//
//  Conformance runner for the shared ZIP-321 test vector corpus
//  (`Tests/Vectors` submodule, oracle-verified against librustzcash `zip321`).
//
//  For every vector in `vectors/valid/*.json` the runner asserts that
//  `ZIP321.parse(_:expecting:validator:)` succeeds — with the test-only
//  `ReferenceAddressValidator` supplying recipient-address validity and
//  capabilities — and that the parsed model matches the
//  vector's per-payment expectations (address, zatoshi amount, memo, label,
//  message, other params), then re-renders the request and compares it against
//  the Rust-reference `canonicalUri` as a *documented expectation* (render
//  fixes are S13; mismatches are tracked as `renderMismatch` entries in the
//  expected-failure map).
//
//  For every vector in `vectors/invalid/*.json` the runner now asserts the
//  EXACT sealed ``ZIP321Error`` discriminant against the corpus's shared
//  cross-language error string.
//
//  Vectors named in `conformanceExpectedFailures` are asserted to CURRENTLY
//  FAIL via a strict `withKnownIssue`.
//
//  The suite is fully deterministic: no network, no clocks, JSON loaded from
//  the submodule via `#filePath`.
//

import Testing
@testable import ZcashPaymentURI

@Suite("Zip321Conformance")
struct Zip321ConformanceTests {
    // MARK: - Suite

    @Test(arguments: try ConformanceCorpus.validVectors())
    func validVectors(_ vector: ConformanceValidVector) throws {
        runVector(named: vector.name) { Self.check(valid: vector) }
    }

    @Test(arguments: try ConformanceCorpus.invalidVectors())
    func invalidVectors(_ vector: ConformanceInvalidVector) throws {
        runVector(named: vector.name) { Self.check(invalid: vector) }
    }

    /// Guards the expected-failure map against typos and against corpus bumps
    /// that rename or remove a vector: every key must name a corpus vector.
    @Test func expectedFailureEntriesExistInCorpus() throws {
        let knownNames = Set(try ConformanceCorpus.validVectors().map(\.name))
            .union(try ConformanceCorpus.invalidVectors().map(\.name))

        for name in conformanceExpectedFailures.keys.sorted() {
            #expect(
                knownNames.contains(name),
                "expectedFailures entry '\(name)' does not match any corpus vector name"
            )
        }
    }

    // MARK: - Expected-failure wrapper

    /// Runs a single vector's checks, wrapped in a strict `withKnownIssue`
    /// when the vector is listed in `conformanceExpectedFailures`.
    private func runVector(named name: String, _ body: () -> Void) {
        guard let reason = conformanceExpectedFailures[name] else {
            body()
            return
        }

        // Strict (the default): if the vector unexpectedly passes, the stale
        // xfail entry itself is reported as a failure.
        withKnownIssue("\(name): \(reason)") {
            body()
        }
    }

    // MARK: - Valid vector checks

    /// The parsed model normalized for comparison. A bare `zcash:{address}` URI
    /// parses to an ordinary one-payment request carrying only an address —
    /// there is no separate "single address" result shape.
    private struct NormalizedPayment {
        let address: String
        let amountZat: UInt64?
        let memoBase64: String?
        let label: String?
        let message: String?
        let other: [(name: String, value: String?)]
    }

    private static func normalize(_ request: PaymentRequest) -> [NormalizedPayment] {
        request.payments.map { payment in
            NormalizedPayment(
                address: payment.recipientAddress.value,
                amountZat: payment.amount?.value,
                memoBase64: payment.memo?.toBase64URL(),
                label: payment.label,
                message: payment.message,
                other: payment.otherParams.map { ($0.name, $0.value) }
            )
        }
    }

    private static func check(valid vector: ConformanceValidVector) {
        guard let network = network(for: vector.network, vectorName: vector.name) else { return }

        let result: PaymentRequest
        switch ZIP321.parse(vector.uri, expecting: network, validator: ReferenceAddressValidator.of(network)) {
        case .success(let parsed):
            result = parsed
        case .failure(let error):
            Issue.record("\(vector.name): expected successful parse but failed with \(error)")
            return
        }

        let parsed = normalize(result)

        guard parsed.count == vector.payments.count else {
            Issue.record(
                "\(vector.name): payment count mismatch — expected \(vector.payments.count), got \(parsed.count)"
            )
            return
        }

        // The corpus orders payments by ascending paramindex, which matches the
        // parser's `payments` accessor order.
        for (expected, actual) in zip(vector.payments, parsed) {
            let subject = "\(vector.name) payment[\(expected.index)]"

            #expect(actual.address == expected.address, "\(subject): address mismatch")

            #expect(actual.amountZat == expected.amountZat, "\(subject): amount mismatch")

            #expect(
                actual.memoBase64 == expected.memoBase64,
                "\(subject): memo mismatch (comparing base64url re-encoding of parsed bytes)"
            )

            #expect(actual.label == expected.label, "\(subject): label mismatch")
            #expect(actual.message == expected.message, "\(subject): message mismatch")

            checkOtherParams(expected: expected.other, actual: actual.other, subject: subject)
        }

        checkRender(vector: vector, result: result)
    }

    private static func checkOtherParams(
        expected: [[String?]],
        actual: [(name: String, value: String?)],
        subject: String
    ) {
        guard expected.count == actual.count else {
            Issue.record(
                "\(subject): otherparam count mismatch — expected \(expected.count) (\(expected)), got \(actual.count) (\(actual))"
            )
            return
        }

        for (index, (expectedPair, actualPair)) in zip(expected, actual).enumerated() {
            let expectedName = expectedPair.first ?? nil
            let expectedValue = expectedPair.count > 1 ? expectedPair[1] : nil

            #expect(actualPair.name == expectedName, "\(subject): otherparam[\(index)] name mismatch")
            #expect(actualPair.value == expectedValue, "\(subject): otherparam[\(index)] value mismatch")
        }
    }

    /// Re-renders the parsed request and compares against the Rust reference's
    /// `canonicalUri`. This is a *documented expectation*, not a spec
    /// requirement — v2's renderer is fixed in S13 — so any mismatch belongs in
    /// the expected-failure map under a `renderMismatch:` reason.
    private static func checkRender(vector: ConformanceValidVector, result: PaymentRequest) {
        guard let canonical = vector.canonicalUri else { return }

        let rendered = ZIP321.uriString(
            from: result,
            formattingOptions: .useEmptyParamIndex(omitAddressLabel: result.payments.count == 1)
        )

        #expect(
            rendered == canonical,
            "\(vector.name): renderMismatch — v2 re-render differs from reference canonical URI"
        )
    }

    // MARK: - Invalid vector checks

    private static func check(invalid vector: ConformanceInvalidVector) {
        guard let network = network(for: vector.network, vectorName: vector.name) else { return }

        switch ZIP321.parse(vector.uri, expecting: network, validator: ReferenceAddressValidator.of(network)) {
        case .success(let result):
            let message = "\(vector.name): expected rejection (corpus discriminant: \(vector.error)) "
                + "but parsing succeeded with \(describe(result))"
            Issue.record("\(message)")
        case .failure(let error):
            let actual = discriminant(of: error)
            #expect(
                actual == vector.error,
                "\(vector.name): discriminant mismatch — lib says \(actual), corpus says \(vector.error) (\(error))"
            )
        }
    }

    /// Maps a sealed ``ZIP321Error`` onto the shared cross-language corpus
    /// discriminant string. This is the single source of truth for the
    /// case-name comparison performed by ``check(invalid:)``.
    static func discriminant(of error: ZIP321Error) -> String {
        switch error {
        case .invalidBase64:               return "invalidBase64"
        case .memoBytesError:              return "memoBytesError"
        case .transparentMemo:             return "transparentMemo"
        case .zeroValuedTransparentOutput: return "zeroValuedTransparentOutput"
        case .tooManyPayments:             return "tooManyPayments"
        case .duplicateParameter:          return "duplicateParameter"
        case .recipientMissing:            return "recipientMissing"
        case .invalidAddress:              return "invalidAddress"
        case .unknownRequiredParameter:    return "unknownRequiredParameter"
        case .invalidParamIndex:           return "invalidParamIndex"
        case .amountExceededSupply:        return "amountExceededSupply"
        case .amountInvalid:               return "amountInvalid"
        case .invalidURI:                  return "invalidURI"
        case .parseError:                  return "parseError"
        }
    }

    private static func describe(_ request: PaymentRequest) -> String {
        let payments = request.payments.map { payment in
            "(address: \(payment.recipientAddress.value), amount: \(payment.amount?.value.description ?? "nil"))"
        }
        return "request(\(payments.joined(separator: ", ")))"
    }

    // MARK: - Helpers

    /// Maps the corpus vector's `network` field onto the `expecting:` argument
    /// of the parser.
    private static func network(for network: String, vectorName: String) -> Network? {
        switch network {
        case "main": return .mainnet
        case "test": return .testnet
        case "regtest": return .regtest
        default:
            Issue.record("\(vectorName): unknown network '\(network)' in corpus vector")
            return nil
        }
    }
}
