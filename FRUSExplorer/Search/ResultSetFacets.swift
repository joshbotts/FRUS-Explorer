// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FacetSection

/// The five dimensions a result set is broken down by (R-1).
///
/// Version history:
///   1.0 — R-1a: initial implementation
enum FacetSection: String, Sendable, Equatable, CaseIterable {
    /// Year of the document's start date, from `document_dates`.
    case years
    /// Volume, from `document_cache.volume_id`.
    case volumes
    /// Person, resolved through the cross-corpus rollup so one person is not split across
    /// name variants.
    case people
    /// Primary document vs editorial note.
    case documentType
    /// Archival provenance era, from the parsed source notes.
    case provenance
}

// MARK: - FacetBucket

/// One row of a facet: a value, its display label, and how many documents in the match
/// carry it.
///
/// Version history:
///   1.0 — R-1a: initial implementation
struct FacetBucket: Sendable, Equatable, Identifiable {

    /// The value a facet click filters on — a volume id, a year, a rollup id as a string.
    let key: String

    /// What to show. Often the same as `key`; different for people (a canonical name) and
    /// document type (localised copy).
    let label: String

    /// How many documents in the match carry this value.
    let count: Int

    var id: String { key }
}

// MARK: - FacetBound

/// A section's display ceiling, and the whole truth about what it is hiding.
///
/// The house rule is no silent truncation. This matters more here than the design's mock
/// suggests: measured against the real store, one common-term match spans **552** volumes
/// and **14,615** person rollups, against the mock's "top 4 of 47" and "top 4 of 214". A
/// templated "of 47" would be wrong by two orders of magnitude, so the totals are counted
/// rather than assumed.
///
/// Version history:
///   1.0 — R-1a: initial implementation
struct FacetBound: Sendable, Equatable {

    /// How many rows this section is showing.
    let shown: Int

    /// How many distinct values the match actually contains.
    let total: Int

    /// Whether anything is hidden — the condition a surface must announce.
    var isTruncated: Bool { total > shown }
}

// MARK: - ProvenanceCoverage

/// How much of the match the provenance facet can actually speak for.
///
/// Two denominators, not one. The design's caveat — "source notes parsed for 361 of 412
/// results" — conflates *parsed at all* with *named a record group*, and those are
/// different numbers: measured for `"government"` on the owner's 552-volume index
/// (2026-08-02, using this type's own aggregate), **163,821 of 195,519** matches had a parsed
/// source note and only **141,694** of those named a record group. A facet panel that reports
/// one number for both overstates its own coverage.
///
/// The three figures are a dated snapshot, not an invariant — they were 163,875 / 195,613 /
/// 141,718 when this was written and drifted purely from re-indexing. They are here to show
/// that the two denominators differ by ~22,000 documents, which is the point; do not treat a
/// small change in them as a regression.
///
/// Version history:
///   1.0 — R-1a: initial implementation
struct ProvenanceCoverage: Sendable, Equatable {

    /// Documents in the match with a parsed source note of any kind.
    let parsed: Int

    /// Documents in the match whose source note named a record group.
    let withRecordGroup: Int

    /// The match size, so a surface never has to reach elsewhere for the denominator.
    let matchCount: Int
}

// MARK: - ResultSetFacets

/// A result set broken down five ways, with every bound and coverage gap stated.
///
/// ## Computed over the match, never over the page
/// Decision R-1-2: facets describe the **whole match**, not the fetched page and not the
/// checklist-filtered subset. Otherwise the denominator shifts under the researcher as they
/// triage. The result list is separately capped (1,000 iOS / 7,500 macOS) while these counts
/// are not, which is a difference surfaces must state rather than smooth over.
///
/// Version history:
///   1.0 — R-1a: initial implementation
struct ResultSetFacets: Sendable, Equatable {

    /// How many documents the match contains — the denominator for every count here.
    let matchCount: Int

    /// Year buckets, descending by year.
    let years: [FacetBucket]

    /// How many matched documents carry no date at all, and so appear in no year bucket.
    ///
    /// Reported rather than dropped: a year histogram whose bars sum to less than the match
    /// is otherwise unexplained.
    let undatedCount: Int

    /// Volume buckets, descending by count.
    let volumes: [FacetBucket]

    /// Person buckets, descending by count, resolved through the rollup.
    let people: [FacetBucket]

    /// Primary vs editorial note.
    let documentTypes: [FacetBucket]

    /// Provenance-era buckets, descending by count.
    let provenance: [FacetBucket]

    /// How much of the match the provenance facet speaks for.
    let provenanceCoverage: ProvenanceCoverage

    /// Per-section display bounds. A section absent from this map was not truncated.
    let bounds: [FacetSection: FacetBound]

    /// The share of the match held by the top `n` volumes, as a fraction.
    ///
    /// The design's insight line is "Top 3 hold 60% of the match". That is true at mock
    /// scale (22.9% measured on a 350-match query) and wildly false at corpus scale — **1.7%**
    /// for a common term across 552 volumes. So it is computed, never templated, and a
    /// surface should think about whether to show it at all when it is this small.
    func topVolumeShare(_ n: Int = 3) -> Double? {
        guard matchCount > 0, !volumes.isEmpty else { return nil }
        let top = volumes.prefix(n).reduce(0) { $0 + $1.count }
        return Double(top) / Double(matchCount)
    }

    /// An empty breakdown, for a query with no matches.
    static func empty(matchCount: Int = 0) -> ResultSetFacets {
        ResultSetFacets(
            matchCount: matchCount, years: [], undatedCount: 0, volumes: [], people: [],
            documentTypes: [], provenance: [],
            provenanceCoverage: ProvenanceCoverage(parsed: 0, withRecordGroup: 0,
                                                   matchCount: matchCount),
            bounds: [:])
    }
}

// MARK: - FacetRequest

/// What to compute, and how much of it.
///
/// Sections are requested individually because computing them is lazy per decision R-1-1:
/// the panel asks for a section when it opens, not when the search runs. Years is included
/// in that — the plan's "years eager, it feeds the timeline" rationale does not hold, since
/// the existing timeline is built client-side from the fetched rows
/// (`SearchView.swift:758-762`) and would not consume a facet.
///
/// Version history:
///   1.0 — R-1a: initial implementation
struct FacetRequest: Sendable, Equatable {

    /// Which sections to compute.
    var sections: Set<FacetSection>

    /// How many rows to return per section before truncating.
    ///
    /// Truncation is always reported through ``ResultSetFacets/bounds``, never silent. The
    /// default is generous because the expensive part is the aggregate, not the row count —
    /// and because a section with 14,615 distinct values needs its real total known even if
    /// only 50 rows are shown.
    var limitPerSection: Int = 50

    /// Every section, at the default limit.
    static let all = FacetRequest(sections: Set(FacetSection.allCases))

    /// One section.
    static func one(_ section: FacetSection, limit: Int = 50) -> FacetRequest {
        FacetRequest(sections: [section], limitPerSection: limit)
    }
}
