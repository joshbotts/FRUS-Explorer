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
///   1.1 — Session 2026-08-07: `hasBoundedDomain` (#586)
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

    /// Whether the section's domain is bounded and small enough to show whole (#586).
    ///
    /// Years can hold one bucket per year the corpus covers — **203** on the shipped index,
    /// growing by roughly one a year. Document type is a boolean, so two. Provenance is the
    /// nine parsed citation eras. None of these can reach a length that needs triage, so none
    /// of them should open onto a page-1-of-9.
    ///
    /// Volumes (552) and people (**16,385** distinct rollups on a whole-corpus match) are the
    /// two that genuinely need it.
    var hasBoundedDomain: Bool {
        switch self {
        case .years, .documentType, .provenance: return true
        case .volumes, .people: return false
        }
    }
}

// MARK: - FacetSort

/// How a facet section's rows are ordered (#586).
///
/// ## Why ordering happens in Swift and not in `ORDER BY`
/// Two measurements, both on the owner's 316,839-document index:
///
/// 1. **Re-querying to re-sort is not affordable, and does not need to be.** The people
///    aggregate over a whole-corpus match costs ~0.80 s, and that cost is the `GROUP BY` —
///    cache-controlled, `LIMIT 50` measured 0.798 s / 0.811 s and `LIMIT 20000` measured
///    0.894 s / 0.802 s while returning 16,385 rows. Fetching the section whole is free, so a
///    sort, a page turn, and a filter keystroke are all local and instant. `OFFSET` paging
///    would have re-paid the 0.8 s on every page.
/// 2. **SQLite's default collation gets names wrong.** `ORDER BY canonical_name` uses BINARY,
///    which sorts every non-ASCII initial after `Z`: `Ágústsson, Einar` and 21 other rollups
///    would be exiled past the end of the alphabet, and 1,041 names carry an internal
///    diacritic that misplaces them too. `localizedStandardCompare` puts them where a reader
///    looks for them, and also orders `frus1952-54v05` before `frus1952-54v10` rather than
///    lexically.
///
/// Version history:
///   1.0 — Session 2026-08-07: #586
enum FacetSort: String, Sendable, Equatable, CaseIterable, Codable {

    /// Largest bucket first — the familiar facet ordering.
    case count

    /// By label, A→Z. For years this is oldest-first; for people it is alphabetical, which on
    /// this data is **last-name** order for 94.4% of rollups (17,062 of 18,078 canonical names
    /// are stored `Last, First`). The other 1,016 have no comma — initials-first
    /// transliterations like `A. Ya. Vyshinski` and titled or single names like
    /// `Abbas Hilmi Pasha` — and will interleave by whatever their first token is. There is no
    /// surname to extract from `Abbas Hilmi Pasha`, so the control is labelled by what it
    /// actually does rather than promising a last name it cannot always find.
    case labelAscending

    /// By label, Z→A. For years this is newest-first, which is the shipped default.
    case labelDescending

    /// The ordering a section starts in.
    ///
    /// Years keeps reverse-chronological, which is what it has always done — the issue's
    /// premise that facets are "displayed by count" was never true of this one. Everything
    /// else keeps count-first.
    static func standard(for section: FacetSection) -> FacetSort {
        section == .years ? .labelDescending : .count
    }

    /// The orderings worth offering for `section`, or empty when the choice is meaningless.
    ///
    /// Document type has two rows and provenance nine eras whose keys carry a chronological
    /// sense that alphabetising would scramble; neither gets a picker.
    static func choices(for section: FacetSection) -> [FacetSort] {
        switch section {
        case .years, .volumes, .people: return [.count, .labelAscending, .labelDescending]
        case .documentType, .provenance: return []
        }
    }

    /// The control's label, which differs by section because "A→Z" means "oldest first" on a
    /// column of years and nothing useful on a column of names.
    func title(for section: FacetSection) -> String {
        switch (self, section) {
        case (.count, _):
            return String(localized: "facets.sort.count", defaultValue: "Most documents")
        case (.labelAscending, .years):
            return String(localized: "facets.sort.oldest", defaultValue: "Oldest first")
        case (.labelDescending, .years):
            return String(localized: "facets.sort.newest", defaultValue: "Newest first")
        case (.labelAscending, _):
            return String(localized: "facets.sort.az", defaultValue: "A–Z")
        case (.labelDescending, _):
            return String(localized: "facets.sort.za", defaultValue: "Z–A")
        }
    }
}

// MARK: - FacetPageSize

/// How many rows of a section to show at once (#586).
///
/// The issue's own list. `all` is the point of the control rather than an escape hatch: it is
/// what the bounded sections open in, and what "view all" resolves to elsewhere.
///
/// Version history:
///   1.0 — Session 2026-08-07: #586
enum FacetPageSize: String, Sendable, Equatable, CaseIterable, Codable {
    case top5, top10, top25, all

    /// Rows per page, or `nil` for no limit.
    var rowCount: Int? {
        switch self {
        case .top5: return 5
        case .top10: return 10
        case .top25: return 25
        case .all: return nil
        }
    }

    /// The size a section opens in.
    ///
    /// Bounded sections open **whole**, and years is the reason this exists. It is ordered
    /// newest-first, so a fixed 50-row cut kept only the 50 most recent years: on the shipped
    /// index the histogram began at **1953** — 88,720 of 314,676 dated rows, 28% — and the
    /// remaining 72%, including both World Wars and the entire nineteenth century, was hidden
    /// behind a caption reading "Showing the top 50 of 203". The count in that caption was
    /// honest; "top" was the wrong word for a cut that kept the *latest*, not the largest.
    static func standard(for section: FacetSection) -> FacetPageSize {
        section.hasBoundedDomain ? .all : .top25
    }

    /// The control's label.
    var title: String {
        switch self {
        case .top5:  return String(localized: "facets.page.top5", defaultValue: "Top 5")
        case .top10: return String(localized: "facets.page.top10", defaultValue: "Top 10")
        case .top25: return String(localized: "facets.page.top25", defaultValue: "Top 25")
        case .all:   return String(localized: "facets.page.all", defaultValue: "Show all")
        }
    }
}

// MARK: - FacetDisplayState

/// One section's sort, page size, page, and filter text (#586).
///
/// Version history:
///   1.0 — Session 2026-08-07: #586
struct FacetDisplayState: Sendable, Equatable {

    /// How the rows are ordered.
    var sort: FacetSort

    /// How many rows a page holds.
    var pageSize: FacetPageSize

    /// The zero-based page currently shown.
    var pageIndex: Int = 0

    /// A substring the labels must contain, or empty for no filtering.
    var filterText: String = ""

    /// The state a section opens in.
    static func standard(for section: FacetSection) -> FacetDisplayState {
        FacetDisplayState(sort: .standard(for: section),
                          pageSize: .standard(for: section))
    }
}

// MARK: - FacetPage

/// The rows a section is showing, and everything needed to say so honestly (#586).
///
/// Version history:
///   1.0 — Session 2026-08-07: #586
struct FacetPage: Sendable, Equatable {

    /// The rows to render.
    let rows: [FacetBucket]

    /// How many rows survived the filter — the denominator for the page indicator.
    let matchingCount: Int

    /// How many rows the section holds before any filtering, so a filtered view can say what
    /// it narrowed from.
    let totalCount: Int

    /// The zero-based page shown, already clamped into range.
    let pageIndex: Int

    /// How many pages the filtered rows make. Always at least 1.
    let pageCount: Int

    /// The 1-based number of the first row on this page, for "Showing 26–50 of 203".
    ///
    /// Stored rather than derived from `pageIndex * rows.count`: the last page is usually
    /// short, so that arithmetic understates the offset on exactly the page a reader is most
    /// likely to be checking.
    let firstRowNumber: Int

    /// Whether a page control is worth rendering at all.
    var hasMultiplePages: Bool { pageCount > 1 }

    /// Whether the filter is hiding anything.
    var isFiltered: Bool { matchingCount != totalCount }
}

// MARK: - FacetPaging

/// Sorts, filters, and pages a section's rows (#586).
///
/// A free function over plain values rather than a method on the view, so the ordering rules —
/// which are the whole substance of the feature — can be tested without a view hierarchy.
///
/// Version history:
///   1.0 — Session 2026-08-07: #586
enum FacetPaging {

    /// Applies `state` to `buckets`.
    ///
    /// `state.pageIndex` is **clamped**, not trusted: shrinking the filter or the page size can
    /// leave a stored index past the end, and an out-of-range page should show the last page
    /// rather than an empty one that reads as "no results".
    static func page(_ buckets: [FacetBucket], with state: FacetDisplayState) -> FacetPage {
        let filtered = filter(buckets, matching: state.filterText)
        let ordered = sorted(filtered, by: state.sort)

        guard let size = state.pageSize.rowCount, size > 0 else {
            return FacetPage(rows: ordered, matchingCount: ordered.count,
                             totalCount: buckets.count, pageIndex: 0, pageCount: 1,
                             firstRowNumber: ordered.isEmpty ? 0 : 1)
        }
        let pageCount = max(1, (ordered.count + size - 1) / size)
        let index = min(max(0, state.pageIndex), pageCount - 1)
        let start = index * size
        let rows = start < ordered.count
            ? Array(ordered[start..<min(start + size, ordered.count)])
            : []
        return FacetPage(rows: rows, matchingCount: ordered.count,
                         totalCount: buckets.count, pageIndex: index, pageCount: pageCount,
                         firstRowNumber: rows.isEmpty ? 0 : start + 1)
    }

    /// Rows whose label contains `text`, case- and diacritic-insensitively.
    ///
    /// Diacritic-insensitive on purpose: a researcher typing `Agustsson` should find
    /// `Ágústsson, Einar`, and requiring the accent would make the filter useless on exactly
    /// the names that are hardest to type.
    static func filter(_ buckets: [FacetBucket], matching text: String) -> [FacetBucket] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return buckets }
        return buckets.filter {
            $0.label.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Rows in `sort` order.
    ///
    /// Every case sorts explicitly rather than trusting the SQL order, because the sections do
    /// not arrive in the same one — years comes back year-descending and the rest
    /// count-descending — so a `count` case that returned the input unchanged would be right
    /// for four sections and wrong for the fifth.
    static func sorted(_ buckets: [FacetBucket], by sort: FacetSort) -> [FacetBucket] {
        switch sort {
        case .count:
            return buckets.sorted {
                $0.count != $1.count ? $0.count > $1.count : compareLabels($0, $1) == .orderedAscending
            }
        case .labelAscending:
            return buckets.sorted { compareLabels($0, $1) == .orderedAscending }
        case .labelDescending:
            return buckets.sorted { compareLabels($0, $1) == .orderedDescending }
        }
    }

    /// Label comparison, falling back to the key so the order is total and deterministic.
    ///
    /// `Array.sorted(by:)` is not documented as stable, so two rows sharing a label — possible
    /// when a rollup has no canonical name and both fall back — would otherwise be free to
    /// swap between renders.
    private static func compareLabels(_ a: FacetBucket, _ b: FacetBucket) -> ComparisonResult {
        let byLabel = a.label.localizedStandardCompare(b.label)
        return byLabel == .orderedSame ? a.key.compare(b.key) : byLabel
    }
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
///   1.1 — Session 2026-08-07: `shown` now describes the fetch, not the screen (#586)
struct FacetBound: Sendable, Equatable {

    /// How many rows the **fetch** returned.
    ///
    /// Since #586 this is a statement about the query, not the screen: the section is fetched
    /// whole up to ``FacetRequest/fetchCeiling`` and ``FacetPaging`` decides what is displayed.
    /// So `isTruncated` now means "the ceiling bit", which on real data it never should — and
    /// the far more common "you are on page 2 of 9" is ``FacetPage``'s job to say.
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
///   1.1 — Session 2026-08-07: sections fetched whole; display cut moved to `FacetPaging` (#586)
struct FacetRequest: Sendable, Equatable {

    /// Which sections to compute.
    var sections: Set<FacetSection>

    /// How many rows to return per section before truncating.
    ///
    /// Truncation is always reported through ``ResultSetFacets/bounds``, never silent.
    ///
    /// ## This is a runaway guard, not a display decision (#586)
    /// It used to be 50, which was a display decision that had leaked into the query — and it
    /// was measurably the wrong one. The years section is ordered newest-first, so a 50-row cut
    /// kept the 50 most recent years and dropped the rest: on the shipped index the histogram
    /// started at 1953, hiding 72% of the dated corpus, both World Wars included.
    ///
    /// Raising it costs nothing, which is the reason it can be raised. Cache-controlled on the
    /// owner's 316,839-document index, the people aggregate — the most expensive of the five —
    /// measured **0.798 s / 0.811 s at `LIMIT 50`** and **0.894 s / 0.802 s at `LIMIT 20000`**
    /// while returning 16,385 rows. The `GROUP BY` computes every group either way; the limit
    /// only decides how many are marshalled back. So the section is fetched whole and
    /// ``FacetPaging`` does the display cut, where it can be re-sorted and re-paged without
    /// touching the database.
    ///
    /// 20,000 clears the largest real section — 16,385 distinct rollups on a whole-corpus
    /// match, against 18,078 in the rollup table — so it should never bite. If it ever does,
    /// ``FacetBound/isTruncated`` still says so.
    var limitPerSection: Int = FacetRequest.fetchCeiling

    /// The per-section row ceiling. See ``limitPerSection`` for why it is this high.
    static let fetchCeiling = 20_000

    /// Every section, at the default limit.
    static let all = FacetRequest(sections: Set(FacetSection.allCases))

    /// One section.
    static func one(_ section: FacetSection, limit: Int = FacetRequest.fetchCeiling) -> FacetRequest {
        FacetRequest(sections: [section], limitPerSection: limit)
    }
}
