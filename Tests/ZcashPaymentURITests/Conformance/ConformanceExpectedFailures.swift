//
//  ConformanceExpectedFailures.swift
//
//  The v1 gap inventory against the shared ZIP-321 conformance corpus
//  (`Tests/Vectors`). Every entry maps a corpus vector `name` to the precise
//  reason the current (v1) implementation diverges from the librustzcash
//  `zip321` reference semantics for that vector.
//
//  Semantics: a vector listed here is asserted to CURRENTLY FAIL via a strict
//  `XCTExpectFailure`. If a library fix makes the vector pass, the strict
//  expectation itself fails, flagging the stale entry so it can be deleted.
//  A vector NOT listed here must pass outright. The conformance suite is
//  therefore green today while every known divergence stays enumerated and
//  machine-checked.
//
//  This map is intentionally the burn-down list for the v2 rewrite. Entries
//  must only ever be added from OBSERVED test failures, never speculatively.
//

/// Vector name → reason the v1 implementation currently fails that vector.
///
/// Observed against corpus commit pinned by the `Tests/Vectors` submodule.
/// Categories used in reasons:
///   - "v1 accepts": an invalid vector that v1 fails to reject.
///   - "v1 rejects": a valid vector that v1 fails to parse.
///   - "fieldMismatch": v1 parses but a decoded field differs from the reference.
///   - "renderMismatch": v1 parses correctly but its re-rendered URI differs
///     from the Rust reference `canonicalUri` (documented expectation only).
let conformanceExpectedFailures: [String: String] = [
    // MARK: Amount grammar — BigDecimal(string:) is more lenient than the ZIP-321 grammar
    "invalid_amount_trailing_decimal_point":
        "v1 accepts: 'amount=123.' parses via BigDecimal to 123; ZIP-321 grammar requires "
        + "at least one digit after the decimal point",
    "invalid_amount_leading_decimal_point":
        "v1 accepts: 'amount=.5' parses via BigDecimal to 0.5; ZIP-321 grammar requires "
        + "a whole-number part before the decimal point",

    // MARK: Missing consensus check
    "spec_invalid_zero_valued_transparent_output":
        "v1 accepts: no check that a zero-valued amount to a transparent recipient is "
        + "disallowed by consensus; Amount permits 0 and Payment never rejects it",

    // MARK: Zero-payment requests — v1 cannot represent an empty request
    "structure_empty_request":
        "v1 rejects: 'zcash:' (a valid empty request per the reference) throws invalidURI; "
        + "v1's model requires at least one payment",
    "structure_empty_request_query_marker":
        "v1 rejects: 'zcash:?' throws otherParamKeyEmpty (the empty query string is parsed "
        + "as an empty otherparam key); reference parses it as an empty request",

    // MARK: Parsed-model / rendering divergences
    "structure_index_gap_only_address_5":
        "renderMismatch: v1's PaymentRequest does not retain ZIP-321 paramindices, so a "
        + "request whose only payment sits at paramindex 5 re-renders at the empty index "
        + "(zcash:{addr}?amount=1) where the reference preserves address.5/amount.5",
    "structure_unknown_param_preserved":
        "fieldMismatch + renderMismatch: v1 does not percent-decode otherparam values on "
        + "parse (exposes 'hello%20world' where reference decodes 'hello world'), and "
        + "Render.parameter(other:) drops the '=' separator and re-encodes the raw value, "
        + "rendering 'future-paramhello%2520world' instead of 'future-param=hello%20world'"
]
