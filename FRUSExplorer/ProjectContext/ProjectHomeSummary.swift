// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ProjectHomeSummary

/// Derives one project's activity summary + recent feeds for the **Project Home**
/// dashboard (#377 Phase 1).
///
/// A pure value type: the view supplies the project's already-filtered activity
/// records (from reactive `@Query`s), and this computes the counts and short
/// "recent" feeds. Keeping it free of SwiftData fetching makes it (a) reactive — it
/// is rebuilt from the live query results on every change, so counts never go stale
/// while the dashboard is open (the refresh pitfall recorded for document-open flows)
/// — and (b) unit-testable with plain arrays.
///
/// Version history:
///   1.0 — #377 Phase 1: initial implementation
struct ProjectHomeSummary {

    /// How many rows each "recent" feed surfaces.
    static let recentLimit = 5

    /// Notes tagged with this project, expected most-recently-modified first.
    let notes: [ResearchNote]
    /// Collections tagged with this project, expected most-recently-modified first.
    let collections: [Collection]
    /// Reading-history entries for this project, expected most-recent first.
    let visits: [ReadingHistoryEntry]
    /// Search-history entries for this project, expected most-recent first.
    let searches: [SearchHistoryEntry]

    /// Builds a summary from a project's already-filtered activity records. Each array
    /// is expected pre-sorted newest-first (the query sort order the view applies).
    init(notes: [ResearchNote],
         collections: [Collection],
         visits: [ReadingHistoryEntry],
         searches: [SearchHistoryEntry]) {
        self.notes = notes
        self.collections = collections
        self.visits = visits
        self.searches = searches
    }

    // MARK: - Summary counts

    /// Collections in this project.
    var collectionCount: Int { collections.count }

    /// Notes in this project.
    var noteCount: Int { notes.count }

    /// Distinct documents visited in this project (`volumeId/documentId` pairs).
    var documentsVisitedCount: Int {
        Set(visits.map { Self.key($0.volumeId, $0.documentId) }).count
    }

    /// Searches run in this project.
    var searchCount: Int { searches.count }

    /// Whether the project has any tagged activity at all (drives the empty state).
    var isEmpty: Bool {
        notes.isEmpty && collections.isEmpty && visits.isEmpty && searches.isEmpty
    }

    // MARK: - Recent feeds

    /// The most-recently-modified notes (up to ``recentLimit``).
    var recentNotes: [ResearchNote] { Array(notes.prefix(Self.recentLimit)) }

    /// The most-recently-visited documents (up to ``recentLimit``), de-duplicated by
    /// `volumeId/documentId` so a re-read doesn't crowd out older distinct documents.
    var recentVisits: [ReadingHistoryEntry] {
        var seen = Set<String>()
        var result: [ReadingHistoryEntry] = []
        for entry in visits {   // expected accessedAt-descending
            let key = Self.key(entry.volumeId, entry.documentId)
            if seen.insert(key).inserted {
                result.append(entry)
                if result.count == Self.recentLimit { break }
            }
        }
        return result
    }

    /// The most-recently-executed searches (up to ``recentLimit``).
    var recentSearches: [SearchHistoryEntry] { Array(searches.prefix(Self.recentLimit)) }

    // MARK: - Helpers

    /// Stable `volumeId/documentId` key.
    private static func key(_ volumeId: String, _ documentId: String) -> String {
        "\(volumeId)/\(documentId)"
    }
}
