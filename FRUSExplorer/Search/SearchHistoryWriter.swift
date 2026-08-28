// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftData

// MARK: - SearchHistoryWriter

/// The one place a `SearchHistoryEntry` is written, for both platforms (M-2).
///
/// ## Why one writer
/// `SearchViewModel` and `MacSearchViewModel` had two copies of this logic, forty near-identical
/// lines apart. That is how #612 happened — iOS recorded a capped count for two builds while macOS
/// recorded the true one, inside a trail that *syncs*, so one project's log carried an iPhone's
/// "1,000" beside a Mac's "195,519" for the same query. A trail exists to make a count citable.
/// Two platforms disagreeing inside it is the worst possible version of that.
///
/// ## The stale-scope problem this fixes
/// The old rule was "one row per distinct submitted query, skip a re-run". It exists because both
/// search screens re-run on *every* filter change — macOS especially, where `searchTrigger` carries
/// `parametersVersion`, so clearing a volume scope or tapping a tag chip re-enters this function.
/// Without the rule, building one scope out of eight checkbox taps would write eight rows and the
/// trail would read as eight searches nobody ran.
///
/// But since #613 the row also carries the **scope** it ran under, and skipping froze that at
/// whatever the first re-run happened to use. A researcher who searched, then narrowed to a working
/// corpus, then read the appendix would find their corpus-wide scope printed against a search that
/// ran inside a corpus. The appendix would be stating a method that was not used — the precise
/// defect M-2 exists to remove.
///
/// So a repeat no longer skips: it **refreshes** the row it already wrote. One row per query, whose
/// scope and counts are the ones it *finally* ran under. Intermediate half-built scopes are not
/// searches the researcher meant to run, and are not recorded; a genuine later re-run of the same
/// query — after other queries in between — is a new row, because the anchor has moved on.
///
/// Version history:
///   1.0 — M-2 commit 5: initial implementation, extracted from the two view models
enum SearchHistoryWriter {

    /// What the last write left behind, so the next call can tell a re-run from a new query.
    ///
    /// The id is held as well as the text because a refresh has to find the row it wrote. Held by
    /// the view model rather than derived from a fetch: "the row *this screen* last wrote" is not
    /// recoverable from the table, which is shared across windows, devices and projects.
    struct Anchor: Equatable, Sendable {
        /// The trimmed query text this screen last recorded.
        var queryText: String
        /// The entry it wrote. Re-fetched on a refresh, because the user can delete it from the
        /// History pane between two re-runs of the same query.
        var entryID: UUID
    }

    /// What a call did, for the caller's debug log and for tests that must distinguish an insert
    /// from a refresh without reading timestamps.
    enum Outcome: Equatable, Sendable {
        /// Research logging is off.
        case suppressed
        /// Nothing to record: an empty query, or a search that errored.
        case skipped
        /// A new row.
        case inserted(UUID)
        /// The anchored row, brought up to date with this re-run.
        case refreshed(UUID)
    }

    /// Everything a row needs, gathered by the caller from its own executed state.
    ///
    /// A struct rather than eleven parameters because both call sites fill it from view-model
    /// properties whose names differ by platform, and a positional argument list is where those
    /// quietly get crossed.
    struct Reading: Sendable {
        /// The submitted query, already trimmed.
        var queryText: String
        /// The headline number both platforms display — the true total when there is one.
        var resultCount: Int
        /// What the fetch returned, capped at `fetchLimit`.
        var loadedCount: Int
        /// Every matching document, or `nil` when no count was available.
        var matchCount: Int?
        /// The fetch ceiling in force on this platform.
        var fetchLimit: Int
        /// How many volumes this device had indexed.
        var indexedVolumeCount: Int?
        /// The **executed** parameters — not the live filter state, which may have moved since.
        var parameters: SearchParameters
        /// The working corpus applied, if any.
        var appliedCorpusId: UUID?
        /// The FTS5 expression the query compiled to.
        var renderedExpression: String?
        /// A route-specific scope signature to record INSTEAD of deriving one from
        /// `parameters` — the Meaning mode's escape from being described as a keyword scope.
        /// `nil` (the default, and every FTS caller) derives as before.
        var signatureOverride: String? = nil
        /// The project active at execution.
        var projectId: UUID?
        /// `true` when the search failed — nothing is recorded.
        var hasError: Bool
    }

    /// Records `reading`, inserting a new row or refreshing the anchored one.
    ///
    /// - Parameters:
    ///   - reading: the executed search.
    ///   - anchor: the caller's anchor, updated in place.
    ///   - context: the context to write to.
    ///   - defaults: where the research-logging switch is read from. Checked **before** the anchor
    ///     is touched, so turning logging off mid-session cannot leave a stale anchor that
    ///     suppresses the next real search.
    /// - Returns: what happened.
    @discardableResult
    static func record(_ reading: Reading,
                       anchor: inout Anchor?,
                       in context: ModelContext,
                       defaults: UserDefaults = .standard) -> Outcome {
        guard AppState.isResearchLoggingEnabled(in: defaults) else { return .suppressed }
        guard !reading.queryText.isEmpty, !reading.hasError else { return .skipped }

        let signature = reading.signatureOverride
            ?? SearchScopeSignature.signature(for: reading.parameters)

        // A re-run of the anchored query: bring the row it wrote up to date rather than adding a
        // second one. Re-fetched by id, because the user can delete it from the History pane
        // between two re-runs — in which case this falls through and inserts.
        if let existing = anchor, existing.queryText == reading.queryText,
           let row = entry(existing.entryID, in: context) {
            row.resultCount = reading.resultCount
            row.loadedCount = reading.loadedCount
            row.matchCount = reading.matchCount
            row.fetchLimit = reading.fetchLimit
            row.indexedVolumeCount = reading.indexedVolumeCount
            row.scopeSignature = signature
            row.appliedCorpusId = reading.appliedCorpusId
            row.renderedExpression = reading.renderedExpression
            row.projectId = reading.projectId
            // The row now describes the search that just ran, so it is dated by that run. Leaving
            // the original time would put a scope and a count against a moment they did not
            // belong to, which is the same class of error as the stale scope.
            row.executedAt = .now
            return .refreshed(row.id)
        }

        let record = SearchHistoryEntry(
            queryText: reading.queryText,
            resultCount: reading.resultCount,
            projectId: reading.projectId,
            loadedCount: reading.loadedCount,
            matchCount: reading.matchCount,
            fetchLimit: reading.fetchLimit,
            indexedVolumeCount: reading.indexedVolumeCount,
            scopeSignature: signature,
            appliedCorpusId: reading.appliedCorpusId,
            renderedExpression: reading.renderedExpression
        )
        context.insert(record)
        anchor = Anchor(queryText: reading.queryText, entryID: record.id)
        return .inserted(record.id)
    }

    /// Fetches one entry by id, or `nil` if it is gone.
    private static func entry(_ id: UUID, in context: ModelContext) -> SearchHistoryEntry? {
        var descriptor = FetchDescriptor<SearchHistoryEntry>(
            predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
