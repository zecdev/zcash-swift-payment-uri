//
//  ConformanceTests.swift
//
//  Conformance runner for the shared ZIP-321 test vector corpus
//  (`Tests/Vectors` submodule, oracle-verified against librustzcash `zip321`).
//
//  For every vector in `vectors/valid/*.json` the runner asserts that
//  `ZIP321.request(from:context:)` succeeds and that the parsed model matches
//  the vector's per-payment expectations (address, zatoshi amount, memo,
//  label, message, other params), then re-renders the request and compares it
//  against the Rust-reference `canonicalUri` as a *documented expectation*
//  (v1's formatting may legitimately differ; mismatches are tracked as
//  `renderMismatch` entries in the expected-failure map, not treated as
//  hard requirements).
//
//  For every vector in `vectors/invalid/*.json` the runner asserts only that
//  parsing throws. The corpus's cross-language error discriminants do not map
//  1:1 onto v1's `ZIP321.Errors` taxonomy, so the exact error case is not
//  asserted; when a vector unexpectedly *succeeds*, the parsed result is
//  included in the failure message.
//
//  Vectors named in `conformanceExpectedFailures` are asserted to CURRENTLY
//  FAIL via a strict `withKnownIssue`: fixing the library without pruning the
//  map turns the suite red, so the gap inventory can never silently go stale.
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
        // xfail entry itself is reported as a failure (`withKnownIssue` fails
        // when its body does NOT record an issue).
        withKnownIssue("\(name): \(reason)") {
            body()
        }
    }

    // MARK: - Valid vector checks

    /// The v1 parsed model normalized for comparison. `ParserResult.legacy`
    /// (a bare `zcash:{address}` URI) is represented as a single payment with
    /// only an address, mirroring the reference's single-payment request.
    private struct NormalizedPayment {
        let address: String
        let amount: LegacyAmount?
        let memoBase64: String?
        let label: String?
        let message: String?
        let other: [(name: String, value: String?)]
    }

    private static func normalize(_ result: ParserResult) -> [NormalizedPayment] {
        switch result {
        case .legacy(let recipient):
            return [
                NormalizedPayment(
                    address: recipient.value,
                    amount: nil,
                    memoBase64: nil,
                    label: nil,
                    message: nil,
                    other: []
                )
            ]
        case .request(let request):
            return request.payments.map { payment in
                NormalizedPayment(
                    address: payment.recipientAddress.value,
                    amount: payment.amount,
                    memoBase64: payment.memo?.toBase64URL(),
                    label: payment.label?.value,
                    message: payment.message?.value,
                    other: (payment.otherParams ?? []).map { ($0.key.value, $0.value?.value) }
                )
            }
        }
    }

    private static func check(valid vector: ConformanceValidVector) {
        guard let context = parserContext(for: vector.network, vectorName: vector.name) else { return }

        let result: ParserResult
        do {
            result = try ZIP321.request(from: vector.uri, context: context)
        } catch {
            Issue.record("\(vector.name): expected successful parse but threw \(error)")
            return
        }

        let parsed = normalize(result)

        guard parsed.count == vector.payments.count else {
            Issue.record(
                "\(vector.name): payment count mismatch — expected \(vector.payments.count), got \(parsed.count)"
            )
            return
        }

        // v1's PaymentRequest does not retain ZIP-321 paramindices, so payments
        // are compared by array position (the corpus orders payments by
        // ascending paramindex, which matches v1's parse order).
        for (expected, actual) in zip(vector.payments, parsed) {
            let subject = "\(vector.name) payment[\(expected.index)]"

            #expect(actual.address == expected.address, "\(subject): address mismatch")

            checkAmount(expected: expected.amountZat, actual: actual.amount, subject: subject)

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

    /// Compares the vector's exact zatoshi amount against v1's decimal-ZEC
    /// `LegacyAmount`.
    ///
    /// Precision note: v1 stores amounts as a checked `Int64` zatoshi
    /// fixed-point value, and `LegacyAmount.toString()` renders a plain (non-
    /// scientific) decimal string, so scaling that string by 10^8 with exact
    /// integer string arithmetic is lossless — no floating point, no rounding.
    /// If a future `LegacyAmount` ever rendered scientific notation or more than 8
    /// fractional digits, the conversion returns `nil` and the test fails
    /// loudly instead of rounding silently.
    private static func checkAmount(expected: Int64?, actual: LegacyAmount?, subject: String) {
        switch (expected, actual) {
        case (.none, .none):
            return
        case (.some(let zat), .none):
            Issue.record("\(subject): expected amount of \(zat) zatoshis but v1 parsed no amount")
        case (.none, .some(let amount)):
            Issue.record("\(subject): expected no amount but v1 parsed \(amount.toString())")
        case (.some(let zat), .some(let amount)):
            let rendered = amount.toString()
            guard let actualZat = Self.zatoshis(fromDecimalZecString: rendered) else {
                Issue.record("\(subject): could not losslessly convert v1 amount '\(rendered)' to zatoshis")
                return
            }
            #expect(actualZat == zat, "\(subject): amount mismatch (v1 rendered '\(rendered)')")
        }
    }

    /// Exact decimal-ZEC-string → zatoshi conversion using integer string
    /// arithmetic only. Returns `nil` for anything that is not a plain,
    /// non-negative decimal with at most 8 fractional digits.
    static func zatoshis(fromDecimalZecString string: String) -> Int64? {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count) else { return nil }

        let integerDigits = parts[0].isEmpty ? "0" : String(parts[0])
        var fractionDigits = parts.count == 2 ? String(parts[1]) : ""

        guard fractionDigits.count <= 8 else { return nil }
        fractionDigits += String(repeating: "0", count: 8 - fractionDigits.count)

        let isASCIIDigits: (String) -> Bool = { $0.allSatisfy { $0.isASCII && $0.isNumber } }
        guard
            isASCIIDigits(integerDigits),
            isASCIIDigits(fractionDigits),
            let whole = Int64(integerDigits),
            let fraction = Int64(fractionDigits)
        else { return nil }

        return whole * 100_000_000 + fraction
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
    /// requirement — v1's default formatting may legitimately differ — so any
    /// mismatch here belongs in the expected-failure map under a
    /// `renderMismatch:` reason rather than being "fixed" in the runner.
    ///
    /// Formatting choice: the librustzcash renderer emits a single payment at
    /// the empty paramindex as `zcash:{address}?...` (address label omitted)
    /// and multi-payment requests as `zcash:?address=...&address.1=...`, so
    /// the closest v1 options are `.useEmptyParamIndex(omitAddressLabel:
    /// count == 1)`.
    private static func checkRender(vector: ConformanceValidVector, result: ParserResult) {
        guard let canonical = vector.canonicalUri else { return }

        let rendered: String
        switch result {
        case .legacy(let recipient):
            rendered = ZIP321.request(recipient, formattingOptions: .useEmptyParamIndex(omitAddressLabel: true))
        case .request(let request):
            rendered = ZIP321.uriString(
                from: request,
                formattingOptions: .useEmptyParamIndex(omitAddressLabel: request.payments.count == 1)
            )
        }

        #expect(
            rendered == canonical,
            "\(vector.name): renderMismatch — v1 re-render differs from reference canonical URI"
        )
    }

    // MARK: - Invalid vector checks

    private static func check(invalid vector: ConformanceInvalidVector) {
        guard let context = parserContext(for: vector.network, vectorName: vector.name) else { return }

        do {
            let result = try ZIP321.request(from: vector.uri, context: context)
            let message: String = "\(vector.name): expected rejection (corpus discriminant: \(vector.error)) "
                + "but parsing succeeded with \(describe(result))"
            Issue.record("\(message)")
        } catch {
            // Pass. Any thrown error counts as rejection: v1's error taxonomy
            // does not map 1:1 onto the corpus discriminants, so the exact
            // case is deliberately not asserted.
        }
    }

    private static func describe(_ result: ParserResult) -> String {
        switch result {
        case .legacy(let recipient):
            return "legacy(\(recipient.value))"
        case .request(let request):
            let payments = request.payments.map { payment in
                "(address: \(payment.recipientAddress.value), amount: \(payment.amount?.toString() ?? "nil"))"
            }
            return "request(\(payments.joined(separator: ", ")))"
        }
    }

    // MARK: - Helpers

    private static func parserContext(for network: String, vectorName: String) -> ParserContext? {
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
