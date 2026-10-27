// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RecordedSearch

/// One search the research trail recorded, as values: the fields of a `SearchHistoryEntry` that the
/// trail's readers use — the method appendix, and how a row's count is read.
///
/// The app's rows map to it field for field (`SearchHistoryEntry.recordedSearch`), and so do FRUS
/// Explorer Light's, so the rules that read a recorded search are one definition for both.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation, with
///          ``RecordedCount``, which was `SearchHistoryEntry.RecordedCount`, and the rule that reads it
public struct RecordedSearch: Identifiable, Sendable, Equatable {

    /// The row's identifier.
    public var id: UUID
    /// The submitted query text, trimmed of surrounding whitespace.
    public var queryText: String
    /// How many documents the search matched, at the time it was executed — the headline number.
    public var resultCount: Int
    /// The project active when the search was executed. `nil` for global context.
    public var projectId: UUID?
    /// When the search was executed. `nil` on rows migrated from the retired `SessionEvent`.
    public var executedAt: Date?
    /// What the fetch returned, capped at ``fetchLimit``. `nil` on rows written before M-2.
    public var loadedCount: Int?
    /// Every document matching the query, when the count was available.
    public var matchCount: Int?
    /// The fetch ceiling in force — `nil` if and only if the row was written before M-2.
    public var fetchLimit: Int?
    /// How many volumes the device had indexed when the search ran.
    public var indexedVolumeCount: Int?
    /// The scope the query ran under, as ``SearchScopeSignature`` writes it.
    public var scopeSignature: String?
    /// The working corpus the search ran inside, by id.
    public var appliedCorpusId: UUID?
    /// The FTS5 expression the engine actually executed.
    public var renderedExpression: String?

    /// Creates a recorded search from a trail row's values.
    public init(id: UUID, queryText: String, resultCount: Int, projectId: UUID? = nil,
                executedAt: Date? = nil, loadedCount: Int? = nil, matchCount: Int? = nil,
                fetchLimit: Int? = nil, indexedVolumeCount: Int? = nil, scopeSignature: String? = nil,
                appliedCorpusId: UUID? = nil, renderedExpression: String? = nil) {
        self.id = id
        self.queryText = queryText
        self.resultCount = resultCount
        self.projectId = projectId
        self.executedAt = executedAt
        self.loadedCount = loadedCount
        self.matchCount = matchCount
        self.fetchLimit = fetchLimit
        self.indexedVolumeCount = indexedVolumeCount
        self.scopeSignature = scopeSignature
        self.appliedCorpusId = appliedCorpusId
        self.renderedExpression = renderedExpression
    }

    /// The only supported way to read this search's count: ``RecordedCount/init(resultCount:loadedCount:matchCount:fetchLimit:scopeSignature:)``.
    public var recordedCount: RecordedCount {
        RecordedCount(resultCount: resultCount, loadedCount: loadedCount, matchCount: matchCount,
                      fetchLimit: fetchLimit, scopeSignature: scopeSignature)
    }
}

// MARK: - RecordedSearch.RecordedCount

extension RecordedSearch {

    /// What a recorded search's count actually asserts.
    ///
    /// Four states, not one number. `resultCount` alone cannot say whether 1,000 is the answer or
    /// a floor, nor whether a row predates the fields that would tell you — and an appendix built
    /// on "1,000" where the truth is "at least 1,000, of an unknown total" is the defect the Q
    /// wave spent nine PRs removing from the screen.
    ///
    /// Modelled on ``CorpusCaptureTruncation``, and for the same reason: `unrecorded` is
    /// not a synonym for any of the others, and a consumer that collapses it into one re-tells the
    /// claim the type exists to prevent.
    ///
    /// Version history:
    ///   1.0 — M-2: initial implementation, as `SearchHistoryEntry.RecordedCount`
    ///   1.1 — 2026-10-19: #1688 — a Meaning-route row written with no match count reads as its list,
    ///          never a floor
    ///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with the rule
    ///          `SearchHistoryEntry.recordedCount` read a row by (``init(resultCount:loadedCount:matchCount:fetchLimit:scopeSignature:)``)
    ///          and `isPartialEvidence(corpusTruncation:)`; `SearchHistoryEntry.RecordedCount` names it
    public enum RecordedCount: Equatable, Sendable {
        /// A real whole-query total, with the fetch that accompanied it.
        case exact(match: Int, loaded: Int)
        /// The count failed and the fetch capped: the answer is **at least** `loaded`.
        case floor(loaded: Int, fetchLimit: Int)
        /// The count failed but the fetch did not cap, so `loaded` *is* every matching document.
        case completeWithoutTotal(loaded: Int)
        /// Written before M-2. The number is whatever that build recorded; nothing more is known.
        case unrecorded(reported: Int)

        /// Reads a trail row's count from its fields.
        ///
        /// Reading `resultCount`, `matchCount` or `loadedCount` directly loses the distinction between
        /// a measured total and a floor, which is the distinction the appendix exists to preserve.
        ///
        /// - Parameters:
        ///   - resultCount: The row's headline number.
        ///   - loadedCount: What the fetch returned.
        ///   - matchCount: Every document matching the query, when counted.
        ///   - fetchLimit: The fetch ceiling, `nil` on a row written before M-2.
        ///   - scopeSignature: The row's scope signature.
        public init(resultCount: Int, loadedCount: Int?, matchCount: Int?, fetchLimit: Int?,
                    scopeSignature: String?) {
            // `fetchLimit` is nil if and only if the row predates M-2 — it is the one field with no
            // legitimate nil on a new row, which is what makes it the discriminator.
            guard let fetchLimit, let loadedCount else { self = .unrecorded(reported: resultCount); return }
            if let matchCount { self = .exact(match: matchCount, loaded: loadedCount); return }
            // A Meaning list is the whole of its ranking (#1688). Since build 51 its row records the
            // list's length as its match count; a row an earlier build wrote has none, under the
            // engine's 100-row length, and read by the rule below a full list was "at least 100". It is
            // read as the list it recorded, never as a floor.
            if SearchScopeSignature.isMeaningRoute(scopeSignature) {
                self = .exact(match: loadedCount, loaded: loadedCount)
                return
            }
            // The same predicate `ResultSetScope.didHitFetchLimit` uses. Sound because `loadedCount`
            // is the unfiltered fetch: checklist filtering happens after, and never lowers it.
            if loadedCount >= fetchLimit {
                self = .floor(loaded: loadedCount, fetchLimit: fetchLimit)
                return
            }
            self = .completeWithoutTotal(loaded: loadedCount)
        }

        /// Whether this count describes less than the whole answer to its query.
        ///
        /// A corpus the search ran inside may itself have been a truncated capture, which the count
        /// cannot know alone — hence the parameter. Resolve it from the row's `appliedCorpusId`.
        ///
        /// - Parameter corpusTruncation: The truncation of the corpus the search ran inside, if any.
        /// - Returns: `true` for partial evidence.
        public func isPartialEvidence(corpusTruncation: CorpusCaptureTruncation? = nil) -> Bool {
            if case .truncated = corpusTruncation { return true }
            if case .floor = self { return true }
            return false
        }
    }
}
