// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The #308 era-sanity table: a curated earliest-plausible year per subject NAME.
///
/// A per-volume profile entry is dropped when its subject's year here is **later than the
/// volume's coverage-end year** — i.e. the *entire* volume predates the subject, so the tag can
/// only be an anachronistic string-match error (the frus-subjects doc-level mappings are
/// ~97% raw string-match; TF-IDF then amplifies a rare anachronism into a top-ranked profile
/// entry, e.g. HIV/AIDS surfacing as a characteristic subject of a 1964–68 volume).
///
/// DELIBERATELY conservative — only **named events / organizations with a hard historical
/// boundary**. Abstract or perennial concepts are excluded ON PURPOSE, because their diplomatic
/// history predates their "modern" date, so dating them would strip legitimate content: dating
/// "Human rights" at 1948 would remove 109 pre-UDHR entries (anti-slavery, minority-rights
/// treaties); "Terrorism" was excluded for the same reason (interwar assassinations, 1940s
/// Palestine, 1950s decolonization insurgencies all predate the modern 1968 subject heading).
///
/// Owner-reviewed 2026-07-16 (#308 Phase 1, review F2). Measured impact **against the export the
/// generator now defaults to** (`frus-subject-taxonomy/exports`, source generated 2026-07-16,
/// md5 39a008d0…): **92 entries dropped**, plus 5 by the genericity floor, over 238,302 tagged
/// documents. The 14 this comment used to state was measured against the SUPERSEDED
/// `frus-subjects/data` drop, and survived the move — the same stale-number failure the
/// semantic suite's `shippingDims` had. Re-measure by reading the generator's own
/// `era-sanity tags dropped` line rather than trusting this sentence.
public enum EraSanity {

    /// Earliest plausible year keyed by exact subject name (the frus-subjects display name).
    public static let earliestPlausibleYear: [String: Int] = [
        "World War I": 1914,
        "World War II": 1939,
        "Korean War": 1950,
        "Cold War": 1947,
        "North Atlantic Treaty Organization": 1949,
        "United Nations": 1945,
        "Nuclear weapons": 1945,
        "Chemical weapons": 1915,
        "AIDS": 1981,
        "Apartheid": 1948,
        "Genocide": 1944,
        "Outer space": 1957,
        "European Economic Community": 1957,
        "Refugees": 1921,
    ]

    /// Resolves the name-keyed table against a drop's `ref → name` crosswalk.
    ///
    /// - Parameter namesByRef: subject ref → display name, from `document_subjects.json`'s
    ///   `subjectsIndex`.
    /// - Returns: `byRef` — subject ref → earliest-plausible year for the subset present in this
    ///   drop; and `unmatched` — table subject names absent from this drop (a rename or typo),
    ///   sorted, so the run can warn rather than silently disable a row.
    public static func refYearMap(namesByRef: [String: String]) -> (byRef: [String: Int], unmatched: [String]) {
        var byRef: [String: Int] = [:]
        for (ref, name) in namesByRef {
            if let year = earliestPlausibleYear[name] { byRef[ref] = year }
        }
        let present = Set(namesByRef.values)
        let unmatched = earliestPlausibleYear.keys.filter { !present.contains($0) }.sorted()
        return (byRef, unmatched)
    }
}
