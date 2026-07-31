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
//  As of S12 (the public API reshape) the remaining entries are two
//  render-owned divergences (owned by the S13 renderer work) plus one corpus
//  discriminant dispute pending architect adjudication.
//

/// Vector name → reason the implementation currently fails that vector.
///
/// Observed against corpus commit pinned by the `Tests/Vectors` submodule.
let conformanceExpectedFailures: [String: String] = [
    // MARK: Rendering divergences (owned by S13)
    "structure_single_address_no_query_params":
        "renderMismatch: a bare 'zcash:{addr}' now parses to an ordinary one-payment "
        + "PaymentRequest (ParsedRequest.singleAddress is gone), so it re-renders through "
        + "Render.request, which still emits a trailing '?' for a payment with no query "
        + "parameters. The render fix belongs to S13.",
    "structure_index_gap_only_address_5":
        "renderMismatch: the parser now PRESERVES paramindex 5 in indexedPayments, but the "
        + "renderer still re-emits a single-payment request at the empty index "
        + "(zcash:{addr}?amount=1) where the reference preserves address.5/amount.5. The render "
        + "fix belongs to S13.",
    "structure_unknown_param_preserved":
        "renderMismatch: otherparam values now percent-decode correctly on parse, but "
        + "Render.parameter(other:) still drops the '=' separator, rendering "
        + "'future-paramhello%20world' instead of 'future-param=hello%20world'. The render "
        + "fix belongs to S13.",

    // MARK: Corpus discriminant disputes (architect adjudication pending)
    "invalid_req_asset_two_recipients_flattened":
        "discriminant mismatch: lib says invalidAddress corpus says unknownRequiredParameter. "
        + "Both utest1… addresses in the vector FAIL bech32m checksum verification (verified "
        + "independently of this library), and 'address=' precedes 'req-asset=' in the URI, so a "
        + "left-to-right parser (this library, and the reference nom parser likewise) hits the "
        + "invalid address first. The corpus discriminant appears to assume checksum-valid "
        + "addresses."
]
