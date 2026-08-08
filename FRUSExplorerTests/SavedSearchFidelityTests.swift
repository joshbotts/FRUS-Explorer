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

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

/// A saved search must recall the search that was saved (#756).
///
/// ## The defect
/// `SavedSearch` persisted 12 of `SearchParameters`' 20 fields. The other eight — `userTagIds`,
/// `volumeIds`, `documentIds`, `excludeDocumentIds`, `projectId`, `personRollupId`, `personLabel`,
/// `includeFrontMatter` — were dropped on save and returned as **defaults** on recall. So a search
/// saved as "Kissinger détente" (person chip, two tags, front matter excluded) came back as plain
/// `détente` over everything, **broader than the one the user named**, with nothing saying so.
///
/// The asymmetry made it worse: the legacy single-volume `personRef` round-tripped fine while the
/// modern cross-corpus rollup filter did not — and the facet panel *writes* `personRollupId` and
/// clears `personRef`, so a facet-narrowed person filter could not survive a save at all.
///
/// ## Why one archived value rather than eight more columns
/// Eight columns would fix today's list and leave the same trap for field nineteen. Archiving
/// `SearchParameters` itself makes the drop class **unrepresentable**: a new field is persisted by
/// construction. It is also one CloudKit identifier instead of eight, and every identifier is a
/// Production schema deploy (R-7).
///
/// Version history:
///   1.0 — Session 2026-08-08: #756 (audit M-26)
@Suite("Saved-search fidelity")
struct SavedSearchFidelityTests {

    /// Every field the audit found dropped, set to a non-default value.
    private func fullyLoadedParameters() -> SearchParameters {
        var p = SearchParameters(keywords: "détente")
        p.userTagIds = ["tag-a", "tag-b"]
        p.volumeIds = ["frus1969-76v15"]
        p.documentIds = ["d1", "d2"]
        p.excludeDocumentIds = ["d3"]
        p.projectId = UUID()
        p.personRollupId = 42
        p.personLabel = "Kissinger, Henry"
        p.personAnchor = PersonRollupAnchor(volumeId: "frus1969-76v15", ref: "p_HK")
        p.includeFrontMatter = false
        return p
    }

    // MARK: - The eight dropped fields

    @Test("Every field the audit found dropped now survives a save and recall")
    func allEightFieldsRoundTrip() {
        let original = fullyLoadedParameters()
        let recalled = SavedSearch(name: "Kissinger détente", parameters: original).searchParameters

        // Named individually rather than compared wholesale: a single `==` would report one
        // failure for eight distinct regressions, and the message would not say which field went.
        #expect(recalled.userTagIds == original.userTagIds, "userTagIds dropped (#756 / M-26)")
        #expect(recalled.volumeIds == original.volumeIds, "volumeIds dropped")
        #expect(recalled.documentIds == original.documentIds, "documentIds dropped")
        #expect(recalled.excludeDocumentIds == original.excludeDocumentIds, "excludeDocumentIds dropped")
        #expect(recalled.projectId == original.projectId, "projectId dropped")
        #expect(recalled.personRollupId == original.personRollupId, """
            personRollupId dropped. This is the one that could not survive AT ALL: the facet panel \
            writes it and clears personRef, so a facet-narrowed person filter was unsaveable, while \
            the legacy single-volume personRef round-tripped fine.
            """)
        #expect(recalled.personLabel == original.personLabel, "personLabel dropped")
        #expect(recalled.includeFrontMatter == original.includeFrontMatter,
                "includeFrontMatter dropped — a recalled search silently re-included front matter")
    }

    @Test("The whole value round-trips, not just the fields anyone thought to list")
    func wholeValueRoundTrips() {
        // The point of archiving rather than enumerating: this assertion keeps holding when
        // SearchParameters grows a field, which is precisely what the column approach could not do.
        let original = fullyLoadedParameters()
        let recalled = SavedSearch(name: "n", parameters: original).searchParameters
        #expect(recalled == original)
    }

    @Test("The #747 person anchor survives too")
    func personAnchorRoundTrips() {
        // Added after the columns were written, and never persisted by them — the ninth field the
        // enumerate-the-columns approach would have missed.
        let original = fullyLoadedParameters()
        let recalled = SavedSearch(name: "n", parameters: original).searchParameters
        #expect(recalled.personAnchor == original.personAnchor)
    }

    // MARK: - Records written before this build

    @Test("A record with no snapshot still recalls from its scalar columns")
    func legacyRecordStillRecalls() {
        // Every saved search in every existing library has parametersData == nil. Those must keep
        // working exactly as before — the fix adds fidelity, it does not invalidate history.
        let saved = SavedSearch(name: "legacy", parameters: SearchParameters(keywords: "berlin"))
        saved.parametersData = nil

        let recalled = saved.searchParameters
        #expect(recalled.keywords == "berlin", "the scalar fallback must still reconstruct the query")
        #expect(recalled.personRollupId == nil, "and legitimately returns defaults for the rest")
    }

    @Test("A corrupt snapshot falls back rather than returning an empty search")
    func corruptSnapshotFallsBack() {
        let saved = SavedSearch(name: "corrupt", parameters: SearchParameters(keywords: "berlin"))
        saved.parametersData = Data("not json".utf8)

        #expect(saved.searchParameters.keywords == "berlin", """
            An undecodable snapshot must fall through to the scalar columns. Returning a blank \
            SearchParameters would turn a corrupt byte into a silently different search — the same \
            failure class this issue is about.
            """)
    }

    @Test("The scalar columns are still written, so an older build can read the record")
    func scalarColumnsStillWritten() {
        // CloudKit-synced: a device on an older build reads the columns, not the blob. Dropping
        // them would make every new save unreadable there rather than partially readable.
        var p = SearchParameters(keywords: "détente")
        p.personRef = "#p_HK"
        let saved = SavedSearch(name: "n", parameters: p)
        #expect(saved.queryText == "détente")
        #expect(saved.personRef == "#p_HK")
    }

    // MARK: - Persisted through a real store

    @Test("The snapshot survives a real SwiftData round trip")
    @MainActor
    func survivesPersistence() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(ModelContainer.frusModelTypes),
                                           configurations: config)
        let context = container.mainContext
        let original = fullyLoadedParameters()
        context.insert(SavedSearch(name: "Kissinger détente", parameters: original))
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<SavedSearch>()).first)
        #expect(fetched.searchParameters == original,
                "the archived snapshot must survive the store, not just the initializer")
    }

    // MARK: - The enabling conformance

    @Test("SearchParameters encodes and decodes on its own")
    func parametersAreCodable() throws {
        // #747 recorded that SearchParameters was NOT Codable, which is why SavedSearch flattened
        // it into columns in the first place and why #754 had to defer search restoration. This is
        // the conformance both depended on.
        let original = fullyLoadedParameters()
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(SearchParameters.self, from: data) == original)
    }

    @Test("The two enums encode by name, so reordering their cases cannot re-interpret archives")
    func enumsAreRawValueBacked() throws {
        // A synthesised enum encoding is positional. If DocumentTypeFilter or BooleanMode were
        // encoded that way, inserting a case would silently change what every archived search means.
        // Decode from a BARE JSON STRING. This is the assertion that actually distinguishes the
        // two encodings: a raw-value enum is `"editorialNotesOnly"`, while a synthesised one is
        // the object `{"editorialNotesOnly":{}}`. My first version checked that the encoded bytes
        // CONTAINED the case name — which is true of both, so it passed with `String` removed from
        // the declaration (measured: M5 and M6 both survived). The name being present says nothing
        // about whether position or name is the contract.
        #expect(try JSONDecoder().decode(DocumentTypeFilter.self,
                                         from: Data("\"editorialNotesOnly\"".utf8)) == .editorialNotesOnly,
                """
                DocumentTypeFilter must be String-raw-value backed (#756). A synthesised enum \
                encoding is POSITIONAL, so inserting a case would silently re-interpret every \
                archived search.
                """)
        #expect(try JSONDecoder().decode(FTS5Query.BooleanMode.self,
                                         from: Data("\"or\"".utf8)) == .or,
                "BooleanMode must be String-raw-value backed, for the same reason (#756)")

        // And the round trip must agree with that spelling.
        let filter = try JSONEncoder().encode(DocumentTypeFilter.editorialNotesOnly)
        #expect(String(data: filter, encoding: .utf8) == "\"editorialNotesOnly\"",
                "the encoded form is the bare name, not a wrapper object")
    }
}
