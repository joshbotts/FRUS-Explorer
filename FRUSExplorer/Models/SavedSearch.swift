// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - SavedSearch

/// A persisted snapshot of a `SearchParameters` state that can be recalled later.
///
/// ## Storage layout
/// All compound values are encoded as flat scalars for CloudKit compatibility.
/// Specifically:
/// - Boolean scope toggles (includeDocumentText, includeSummaries, includeNotes)
///   are packed into `scopeFlags` as bit 0, 1, and 2 respectively (all on = 7).
/// - `booleanModeRaw` is `"and"` or `"or"`.
/// - `documentTypeFilterRaw` is `"all"`, `"documentsOnly"`, or `"editorialNotesOnly"`.
/// - Repeated string values (subject tag IDs, excluded terms) are stored as
///   comma-separated strings. An empty string means no values.
/// - Date range endpoints are stored as optional `Date` fields.
///
/// ## CloudKit compatibility
/// All properties have default values or are optional so that CloudKit schema
/// migrations (adding new columns) work without breaking existing records.
///
/// ## Round-trip
/// Call `searchParameters` to reconstruct a `SearchParameters` value from a
/// stored record. Call `init(name:parameters:)` to create a record from live state.
///
/// Version history:
///   1.0 — Session 96: initial implementation
///   Session 09: `subjectTagIdsCSV` is retained-but-inert (document-level subject
///         tags retired); round-trip stays lossless for CloudKit stability.
///   1.1 — W-5 (#266): `freshnessData` (the run watermark behind "new results since you last
///         ran this") + `lastModified` (the record joins `LastModifiedStamping`, so a
///         CloudKit merge finally has a tiebreaker newer than `createdAt`). Two new CloudKit
///         identifiers — deploy per R-7.
@Model final class SavedSearch {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Display

    /// User-visible label shown in the Saved Searches list.
    var name: String = ""

    // MARK: - Full-text fields

    /// Keywords — maps to `SearchParameters.keywords`.
    var queryText: String = ""
    /// Exact phrase — maps to `SearchParameters.phrase`.
    var phraseText: String = ""
    /// Prefix wildcard — maps to `SearchParameters.prefixWildcard`.
    var prefixWildcard: String = ""
    /// Boolean mode: `"and"` or `"or"` — maps to `SearchParameters.booleanMode`.
    var booleanModeRaw: String = "and"
    /// Comma-separated excluded terms — maps to `SearchParameters.excludedTerms`.
    var excludedTermsCSV: String = ""

    // MARK: - Content scope

    /// Bitmask: bit 0 = includeDocumentText, bit 1 = includeSummaries, bit 2 = includeNotes.
    /// Default 7 (all three enabled).
    var scopeFlags: Int = 7

    // MARK: - Date range

    /// Earliest date bound. `nil` means no date-range filter.
    var dateRangeStart: Date?
    /// Latest date bound. `nil` means no date-range filter.
    var dateRangeEnd: Date?

    // MARK: - Filters

    /// Comma-separated subject tag IDs — maps to `SearchParameters.subjectTagIds`.
    ///
    /// Retained for schema/CloudKit stability only. Document-level subject-tag
    /// filtering was retired in Session 09 (the subject taxonomy was dropped for low
    /// signal-to-noise); this field round-trips losslessly but no longer constrains a
    /// search — see the neutralized filter in `IndexingPipeline.searchDocuments`.
    var subjectTagIdsCSV: String = ""
    /// Document type filter: `"all"`, `"documentsOnly"`, or `"editorialNotesOnly"`.
    var documentTypeFilterRaw: String = "all"
    /// Person `@ref` filter — maps to `SearchParameters.personRef`. Empty = no filter.
    var personRef: String = ""

    // MARK: - Sort

    /// Sort order identifier. Currently always `"relevance"`.
    var sortOrder: String = "relevance"

    // MARK: - Timestamp

    /// When this saved search was created. Optional for CloudKit schema compatibility.
    var createdAt: Date?

    /// When this record last changed — the CloudKit merge tiebreaker (W-5 / #266).
    ///
    /// `SavedSearch` predates `ModelModificationStamper` and never carried one, so a stale
    /// copy on a second device could win every merge. Kept current by the save-time stamper
    /// (the model joins `LastModifiedStamping`); `nil` on rows written before this build.
    var lastModified: Date?

    // MARK: - Initializer

    /// Creates a `SavedSearch` from live `SearchParameters` state.
    init(name: String, parameters: SearchParameters) {
        self.id = UUID()
        self.name = name
        self.queryText = parameters.keywords ?? ""
        self.phraseText = parameters.phrase ?? ""
        self.prefixWildcard = parameters.prefixWildcard ?? ""
        self.booleanModeRaw = parameters.booleanMode == .or ? "or" : "and"
        self.excludedTermsCSV = parameters.excludedTerms.joined(separator: ",")
        var flags = 0
        if parameters.includeDocumentText { flags |= 1 }
        if parameters.includeSummaries    { flags |= 2 }
        if parameters.includeNotes        { flags |= 4 }
        self.scopeFlags = flags
        if let range = parameters.dateRange {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            self.dateRangeStart = range.earliest.flatMap { fmt.date(from: $0) }
            self.dateRangeEnd   = range.latest.flatMap   { fmt.date(from: $0) }
        }
        self.subjectTagIdsCSV = parameters.subjectTagIds.joined(separator: ",")
        switch parameters.documentTypeFilter {
        case .documentsOnly:      self.documentTypeFilterRaw = "documentsOnly"
        case .editorialNotesOnly: self.documentTypeFilterRaw = "editorialNotesOnly"
        case .all:                self.documentTypeFilterRaw = "all"
        }
        self.personRef = parameters.personRef ?? ""
        self.sortOrder = "relevance"
        self.createdAt = .now
        self.lastModified = .now
        // The complete snapshot (#756). Encoding cannot realistically fail for this value type, and
        // a nil here degrades to exactly the old behaviour rather than losing the record.
        self.parametersData = try? JSONEncoder().encode(parameters)
    }

    // MARK: - Complete snapshot (#756)

    /// The whole `SearchParameters` value, JSON-archived.
    ///
    /// ## Why one blob and not eight more columns
    /// The scalar columns below persist 12 of `SearchParameters`' 20 fields. The other **eight** —
    /// `userTagIds`, `volumeIds`, `documentIds`, `excludeDocumentIds`, `projectId`,
    /// `personRollupId`, `personLabel`, `includeFrontMatter` — were dropped on save and returned as
    /// defaults on recall, so a saved search ran **broader than the one the user named**, silently
    /// (audit M-26). Worse, the facet panel writes `personRollupId` and clears `personRef`, so a
    /// facet-narrowed person filter could not survive a save at all — while the legacy single-volume
    /// `personRef` round-tripped fine.
    ///
    /// Adding eight columns would fix today's list and leave the same trap for field nineteen.
    /// Archiving the value itself means **the drop class cannot recur**: a new field on
    /// `SearchParameters` is persisted by construction. It is also one CloudKit identifier instead
    /// of eight, which matters because every one of them is a schema deploy (R-7).
    ///
    /// ## Compatibility
    /// `nil` on every record written before this build, so ``searchParameters`` falls back to the
    /// scalar columns. Those columns are still WRITTEN too — they are what the CloudKit schema and
    /// any older build on another device can read, so a record saved here still recalls (partially,
    /// as before) on a device that has not updated.
    var parametersData: Data?

    // MARK: - Freshness watermark (W-5 / #266)

    /// The last-run watermark, JSON-archived — when this search was last recalled, how many
    /// results it matched then, and how many volumes were indexed on the device that ran it.
    ///
    /// One blob rather than three columns for the same reason as ``parametersData``: a future
    /// field costs nothing here, while every scalar column is its own CloudKit identifier and
    /// deploy (R-7). SYNCED deliberately (the owner's W-5 watermark decision): the badge means
    /// "new since you last ran this search *anywhere*", so running a search on the Mac clears
    /// the phone's badge too. `nil` = never recorded (records written before this build, and
    /// searches saved but not yet re-run) — surfaces show no badge rather than a fake zero.
    var freshnessData: Data?

    /// The decoded watermark, or `nil` when none was ever recorded or the blob does not parse.
    var freshness: SavedSearchFreshness? {
        guard let freshnessData else { return nil }
        return try? JSONDecoder().decode(SavedSearchFreshness.self, from: freshnessData)
    }

    /// Records a run of this search: stamps the watermark with now, the run's match count,
    /// and the device's indexed-volume count. Pass `matchCount: nil` from a hand-off site
    /// that never learns the count (the sidebar shortcuts) — `lastRunAt` still advances and
    /// the baseline is CLEARED, not kept: the user just saw the current results, so the old
    /// baseline would keep claiming "+N" about results already seen. The freshness evaluator
    /// backfills a nil baseline with the current count (showing no badge for that cycle).
    func recordRun(matchCount: Int?, indexedVolumeCount: Int?) {
        let mark = SavedSearchFreshness(
            lastRunAt: .now,
            matchCountAtLastRun: matchCount,
            indexedVolumeCountAtLastRun: indexedVolumeCount)
        freshnessData = try? JSONEncoder().encode(mark)
    }

    // MARK: - Round-trip

    /// Reconstructs the `SearchParameters` snapshot stored in this record.
    var searchParameters: SearchParameters {
        // The complete snapshot wins when present (#756). The scalar reconstruction below remains
        // for records written before this build — and for anything that fails to decode, which is
        // better than handing back an empty search.
        if let parametersData,
           let decoded = try? JSONDecoder().decode(SearchParameters.self, from: parametersData) {
            return decoded
        }
        let kw  = queryText.isEmpty ? nil : queryText
        let ph  = phraseText.isEmpty ? nil : phraseText
        let pw  = prefixWildcard.isEmpty ? nil : prefixWildcard
        let excluded: [String] = excludedTermsCSV.isEmpty
            ? []
            : excludedTermsCSV.split(separator: ",").map(String.init)
        let boolMode: FTS5Query.BooleanMode = booleanModeRaw == "or" ? .or : .and
        let tagIds: [String] = subjectTagIdsCSV.isEmpty
            ? []
            : subjectTagIdsCSV.split(separator: ",").map(String.init)
        let docType: DocumentTypeFilter
        switch documentTypeFilterRaw {
        case "documentsOnly":      docType = .documentsOnly
        case "editorialNotesOnly": docType = .editorialNotesOnly
        default:                   docType = .all
        }
        let dateRange: DateRange?
        if let start = dateRangeStart, let end = dateRangeEnd {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            dateRange = DateRange(earliest: fmt.string(from: start),
                                  latest: fmt.string(from: end))
        } else {
            dateRange = nil
        }
        return SearchParameters(
            keywords: kw,
            phrase: ph,
            booleanMode: boolMode,
            excludedTerms: excluded,
            prefixWildcard: pw,
            dateRange: dateRange,
            subjectTagIds: tagIds,
            includeDocumentText: scopeFlags & 1 != 0,
            includeSummaries:    scopeFlags & 2 != 0,
            includeNotes:        scopeFlags & 4 != 0,
            documentTypeFilter:  docType,
            personRef: personRef.isEmpty ? nil : personRef
        )
    }
}

// MARK: - SavedSearchFreshness

/// The `SavedSearch` run watermark (W-5 / #266): when the search was last run, what it
/// matched then, and how many volumes were indexed on the device that ran it.
///
/// `indexedVolumeCountAtLastRun` is context for the surfaces, not part of the verdict math:
/// a "+12 since last run" caption after six new volumes indexed is growth of the library, not
/// of the archive — a surface may choose to say so.
///
/// Every field is optional and the decoder is hand-written per-field-tolerant (`try?` around
/// each), so a blob written by a build with more fields — or a corrupted one — degrades to
/// whatever still parses rather than discarding the whole watermark.
///
/// Version history:
///   1.0 — W-5 (#266): initial implementation
struct SavedSearchFreshness: Codable, Equatable, Sendable {
    /// When the search was last recalled and run. `nil` never happens in a freshly-recorded
    /// mark, but survives decoding a partial blob.
    var lastRunAt: Date?
    /// The exact match count that run reported (`searchCount` — uncapped), the baseline the
    /// "+N since last run" delta is computed against. `nil` when the last run came through a
    /// hand-off site that never learns the count; the freshness evaluator backfills it.
    var matchCountAtLastRun: Int?
    /// How many volumes were indexed on the device at that run.
    var indexedVolumeCountAtLastRun: Int?

    init(lastRunAt: Date?, matchCountAtLastRun: Int?, indexedVolumeCountAtLastRun: Int?) {
        self.lastRunAt = lastRunAt
        self.matchCountAtLastRun = matchCountAtLastRun
        self.indexedVolumeCountAtLastRun = indexedVolumeCountAtLastRun
    }

    private enum CodingKeys: String, CodingKey {
        case lastRunAt, matchCountAtLastRun, indexedVolumeCountAtLastRun
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastRunAt = try? container.decodeIfPresent(Date.self, forKey: .lastRunAt)
        matchCountAtLastRun = try? container.decodeIfPresent(Int.self, forKey: .matchCountAtLastRun)
        indexedVolumeCountAtLastRun = try? container.decodeIfPresent(
            Int.self, forKey: .indexedVolumeCountAtLastRun)
    }
}
