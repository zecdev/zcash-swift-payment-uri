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
//  As of S15 the map is EMPTY: the implementation agrees with the corpus on
//  every vector — parse decisions, error discriminants, and canonical
//  re-rendering. Keep the mechanism in place; any future regression or corpus
//  addition that exposes a divergence belongs here until it is resolved.
//

/// Vector name → reason the implementation currently fails that vector.
///
/// Observed against corpus commit pinned by the `Tests/Vectors` submodule.
let conformanceExpectedFailures: [String: String] = [:]
