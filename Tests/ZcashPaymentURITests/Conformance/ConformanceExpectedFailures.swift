//
//  ConformanceExpectedFailures.swift
//
//  The v2 gap inventory against the shared ZIP-321 conformance corpus
//  (`Tests/Vectors`). Every entry maps a corpus vector `name` to the precise
//  reason the current implementation diverges from the librustzcash `zip321`
//  reference semantics for that vector.
//
//  Semantics: a vector listed here is asserted to CURRENTLY FAIL via a strict
//  `withKnownIssue`. If a library fix makes the vector pass, the strict
//  expectation itself fails, flagging the stale entry so it can be deleted.
//  A vector NOT listed here must pass outright.
//
//  As of S13 (the canonical renderer) the two render-owned divergences are
//  fixed and their entries removed; the sole remaining entry is one corpus
//  discriminant dispute pending architect adjudication.
//

/// Vector name → reason the implementation currently fails that vector.
///
/// Observed against corpus commit pinned by the `Tests/Vectors` submodule.
let conformanceExpectedFailures: [String: String] = [
    // MARK: Corpus discriminant disputes (architect adjudication pending)
    "invalid_req_asset_two_recipients_flattened":
        "discriminant mismatch: lib says invalidAddress corpus says unknownRequiredParameter. "
        + "Both utest1… addresses in the vector FAIL bech32m checksum verification (verified "
        + "independently of this library), and 'address=' precedes 'req-asset=' in the URI, so a "
        + "left-to-right parser (this library, and the reference nom parser likewise) hits the "
        + "invalid address first. The corpus discriminant appears to assume checksum-valid "
        + "addresses."
]
