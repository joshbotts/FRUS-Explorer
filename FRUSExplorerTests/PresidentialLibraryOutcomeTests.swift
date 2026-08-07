// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - PresidentialLibraryOutcomeTests

/// Pins the offline presidential-library route (#681) — the first archival resolution Source
/// Explorer has ever had for a library citation that does not go over the network.
///
/// ## What is being protected
/// Measured over the corpus with the shipped types (2026-08-06), of **30,417** library documents:
///
/// | outcome | documents | share |
/// |---|---|---|
/// | exact series | 1,642 | 5.4% |
/// | verified collection | 11,688 | 38.4% |
/// | no match | 17,087 | 56.2% |
///
/// The 43.8% that reach an answer do so through a **hand-verified** `collectionIdentifier`, and
/// 1,477 of the 1,642 exact-series answers come from a hand-curated NAID rather than from the
/// title rule. That is the whole design: this project's worst defect is a confidently wrong
/// archival link, so the join is anchored on curation and the title match only operates *inside*
/// an already-verified collection.
///
/// The tests below therefore fall into three groups: the rows that must resolve, the rows that
/// must **not** (deliberately unmapped, and easy for a later session to "fix" into a wrong
/// answer), and the branch behaviour that no corpus row currently exercises.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681, wiring the bundled catalogue into both Source Explorer views
@Suite("Presidential library offline outcome")
struct PresidentialLibraryOutcomeTests {

    private func index() throws -> PresidentialLibraryIndex {
        try #require(PresidentialLibraryIndexStore.shared,
                     "presidential-library-catalog.json must decode from the app bundle")
    }

    private func curated() throws -> CuratedLibraryResolutions {
        try #require(CuratedLibraryResolutionsStore.shared,
                     "curated-library-resolutions.json must decode from the app bundle")
    }

    /// Resolves through the shipped code path, against the shipped artifacts.
    private func resolve(_ repository: String, _ collection: String,
                         _ note: String) throws -> PresidentialLibraryOutcome {
        PresidentialLibraryOutcome.resolve(repository: repository, collection: collection,
                                           note: note, index: try index(),
                                           curated: try curated())
    }

    // MARK: - Rows that must resolve

    /// The cross-check that earns the title rule its trust: run blind, it lands the Johnson
    /// `Special Head of State Correspondence File` on NAID 7763260 — the identifier separately
    /// confirmed against the catalogue record by hand in #701.
    @Test("A cited series inside a verified collection resolves to its NARA series record")
    func citedSeriesResolves() throws {
        let outcome = try resolve(
            "Johnson Library", "National Security File",
            "Johnson Library, National Security File, Special Head of State Correspondence File, Box 10, USSR.")
        let series = try #require(outcome.resolvedSeries,
                                  "expected an exact series, got \(outcome)")
        #expect(series.naId == 7763260)
        #expect(try #require(outcome.verifiedCollection).identifier == "LBJ-NSF")
        #expect(outcome.caveat == nil, "an exact resolution must not be hedged")
    }

    /// The Eisenhower name trap, on the catalogue side. `DDE-1424 Ann C. Whitman Papers` is the
    /// secretary's one-foot personal papers and scores well on any word match; the Whitman File
    /// is `DDE-EPRES`, *Papers as President of the United States*. 2,083 documents ride on this
    /// distinction, and #702 already refused the same trap on the finding-aid side.
    @Test("The Whitman File resolves to the presidential papers, not the secretary's papers")
    func whitmanFileAvoidsTheSecretarysPapers() throws {
        let outcome = try resolve(
            "Eisenhower Library", "Whitman File",
            "Eisenhower Library, Whitman File, Dulles-Herter Series, Box 4, Dulles, John Foster.")
        let collection = try #require(outcome.verifiedCollection, "expected a hit, got \(outcome)")
        #expect(collection.identifier == "DDE-EPRES")
        #expect(collection.identifier != "DDE-1424")
    }

    /// Kennedy cites two collections whose short forms differ by one word. They are separate
    /// NARA collections and the identifiers must not cross.
    @Test("The two Kennedy collections resolve to their own identifiers")
    func kennedyCollectionsDoNotCross() throws {
        let pof = try resolve(
            "Kennedy Library", "President's Office Files",
            "Kennedy Library, President's Office Files, Countries Series, Box 1, Germany.")
        #expect(try #require(pof.verifiedCollection).identifier == "JFK-3")

        let nsf = try resolve(
            "Kennedy Library", "National Security Files",
            "Kennedy Library, National Security Files, Countries Series, Box 2, Berlin.")
        #expect(try #require(nsf.verifiedCollection).identifier == "JFK-4")
    }

    // MARK: - Rows that must NOT resolve

    /// The Johnson `Country File` is **seven regional series** at NARA and none of them is the
    /// answer. The collection is known; the series is not. Resolving this to whichever series
    /// sorted first would be the confidently-wrong link the whole workstream exists to avoid.
    @Test("A series NARA divides stops at the collection")
    func dividedSeriesStopsAtTheCollection() throws {
        let outcome = try resolve(
            "Johnson Library", "National Security File",
            "Johnson Library, National Security File, Country File, Vietnam, Box 12.")
        #expect(outcome.resolvedSeries == nil,
                "Country File names seven NARA series; none is the answer")
        #expect(try #require(outcome.verifiedCollection).identifier == "LBJ-NSF")
        #expect(outcome.caveat != nil, "an unpinned series must be hedged")
    }

    /// Three high-weight rows are deliberately unmapped, and each is one plausible-looking
    /// curation away from becoming a wrong answer for thousands of documents. See
    /// `project_library_collection_identifiers` for the full reasoning; in short:
    ///
    /// - **Nixon `NSC Files`** (7,054 documents): the only Nixon collection titled *National
    ///   Security Files* carries 4 series where the NSC Files have ~30. Mapping there would
    ///   resolve 7,000 citations into a stub.
    /// - **Ford `National Security Adviser`** (1,479): genuinely 18 separate NARA collections,
    ///   one per staff office. No single identifier is correct.
    /// - **Library of Congress `Manuscript Division`** (958): not a NARA repository at all, so
    ///   the catalogue has no record of it — and the harvest never contained one.
    @Test("The deliberately unmapped rows resolve to nothing")
    func deliberatelyUnmappedRowsStayUnmapped() throws {
        let cases: [(String, String, String)] = [
            ("Nixon Presidential Materials", "NSC Files",
             "National Archives, Nixon Presidential Materials, NSC Files, Box 849, Country Files, Latin America."),
            ("Ford Library", "National Security Adviser",
             "Ford Library, National Security Adviser, Presidential Country Files for East Asia, Box 12."),
            ("Library of Congress", "Manuscript Division",
             "Library of Congress, Manuscript Division, Kissinger Papers, Box 3."),
        ]
        for (repository, collection, note) in cases {
            let outcome = try resolve(repository, collection, note)
            #expect(outcome == .none,
                    Comment(rawValue: "\(repository) / \(collection) must not resolve — got \(outcome)"))
            #expect(!outcome.suppressesLiveQuery,
                    Comment(rawValue: "\(collection): a non-answer must leave the live query in place"))
        }
    }

    // MARK: - The live-query suppression (owner decision 2026-08-06)

    /// Showing an exact NARA collection beside three unconstrained free-text hits re-creates the
    /// ambiguity #704 and #705 spent two PRs removing: nothing on screen tells the reader which
    /// rows were verified. So a hit suppresses the query, and only a hit.
    @Test("Every hit suppresses the live query; a miss does not")
    func hitsSuppressTheLiveQuery() throws {
        let exact = try resolve(
            "Johnson Library", "National Security File",
            "Johnson Library, National Security File, Special Head of State Correspondence File, Box 10.")
        let collectionOnly = try resolve(
            "Johnson Library", "National Security File",
            "Johnson Library, National Security File, Country File, Vietnam, Box 12.")

        #expect(exact.suppressesLiveQuery)
        #expect(collectionOnly.suppressesLiveQuery)
        #expect(!PresidentialLibraryOutcome.none.suppressesLiveQuery)
    }

    // MARK: - Candidate listing

    /// A collection's *entire* series list is its inventory, not evidence about this citation.
    /// Measured, this is what every single `.collection` row in the corpus looks like — 48 of 48
    /// for `LBJ-NSF`, 32 of 32 for `JC-NSA` — so listing the first eight in NAID order would be
    /// noise on 11,688 documents. The collection's own catalogue record is the useful link.
    @Test("An unnarrowed collection lists no candidate series")
    func unnarrowedCollectionListsNothing() throws {
        let outcome = try resolve(
            "Johnson Library", "National Security File",
            "Johnson Library, National Security File, Country File, Vietnam, Box 12.")
        #expect(outcome.candidateSeries == nil)
        #expect(try #require(outcome.verifiedCollection).catalogURL != nil,
                "the collection record is what this branch offers instead")
    }

    /// The narrowed branch has **no traffic in the current corpus** — measured, 0 of 30,417
    /// documents — but it is not unreachable: 53 collections in the shipped index hold two
    /// series with the same normalised title, so one curation of a colliding collection makes it
    /// live. It is fixture-tested rather than deleted because the alternative render (collection
    /// only) would silently drop the fact that exactly two series answer to the cited name.
    @Test("A narrowed candidate set is listed and hedged")
    func narrowedCandidatesAreListed() {
        let twins = [
            PresidentialLibraryIndex.Series(naId: 1, title: "Country File", inclusiveDates: nil),
            PresidentialLibraryIndex.Series(naId: 2, title: "Country File", inclusiveDates: nil),
            PresidentialLibraryIndex.Series(naId: 3, title: "Agency File", inclusiveDates: nil),
        ]
        let collection = PresidentialLibraryIndex.Collection(
            identifier: "TEST-1", title: "Test Collection", naId: 99,
            statedSeriesCount: 3, series: twins)
        let outcome = PresidentialLibraryOutcome.collection(
            collection, candidates: Array(twins.prefix(2)))

        let listed = try? #require(outcome.candidateSeries)
        #expect(listed?.count == 2)
        #expect(outcome.candidateTotal == 2)
        #expect(outcome.caveat != nil, "candidates must be hedged")
        #expect(outcome.resolvedSeries == nil)
        #expect(outcome.suppressesLiveQuery)
    }

    /// The display limit must not drop rows silently — the caveat states the true total whenever
    /// it exceeds what is listed.
    @Test("A candidate set past the display limit says how many there are")
    func oversizeCandidateSetStatesTheTotal() {
        let many = (1...12).map {
            PresidentialLibraryIndex.Series(naId: $0, title: "Country File", inclusiveDates: nil)
        }
        let collection = PresidentialLibraryIndex.Collection(
            identifier: "TEST-2", title: "Test Collection", naId: 98,
            statedSeriesCount: 20,
            series: many + [PresidentialLibraryIndex.Series(naId: 99, title: "Other",
                                                            inclusiveDates: nil)])
        let outcome = PresidentialLibraryOutcome.collection(collection, candidates: many)

        #expect(outcome.candidateSeries?.count == PresidentialLibraryOutcome.candidateDisplayLimit)
        #expect(outcome.candidateTotal == 12)
        let caveat = try? #require(outcome.caveat)
        #expect(caveat?.contains("12") == true,
                "the caveat must state the full count, not only what is shown")
    }

    // MARK: - Curation outranks the title rule

    /// A curated NAID was derived by the same title rule but **checked by hand**, so where the
    /// two disagree the checked one is the answer. Built as a fixture because no shipped row
    /// disagrees — which is the point: this pins the precedence before one ever does.
    @Test("A curated series NAID outranks a unique title match")
    func curatedSeriesOutranksTitleMatch() {
        let cited = PresidentialLibraryIndex.Series(naId: 500, title: "Special File",
                                                    inclusiveDates: nil)
        let curatedTarget = PresidentialLibraryIndex.Series(naId: 900, title: "Something Else",
                                                            inclusiveDates: nil)
        let index = PresidentialLibraryIndex(
            schemaVersion: 1, generated: "2026-08-06", source: "fixture",
            libraries: [.init(prefix: "LBJ", citedAs: "Johnson Library", collections: [
                .init(identifier: "LBJ-TEST", title: "Test", naId: 42,
                      statedSeriesCount: 2, series: [cited, curatedTarget])
            ])])
        let curated = CuratedLibraryResolutions(
            schemaVersion: 1, generated: "2026-08-06", note: nil,
            entries: [.init(repository: "Johnson Library", collection: "Test File",
                            subCollection: "Special File", subCollectionAliases: nil,
                            collectionIdentifier: "LBJ-TEST", seriesNaId: 900,
                            resolution: .init(title: "aid", url: "https://example.org",
                                              naId: nil, rationale: nil))])

        let outcome = PresidentialLibraryOutcome.resolve(
            repository: "Johnson Library", collection: "Test File",
            note: "Johnson Library, Test File, Special File, Box 1.",
            index: index, curated: curated)

        #expect(outcome.resolvedSeries?.naId == 900,
                "the hand-checked NAID must win over the title match on 500")
    }

    /// A `collectionIdentifier` naming no collection resolves to nothing rather than falling
    /// back to a title guess — a wrong identifier is a curation error to surface, not to paper
    /// over. Without this the fallback would quietly resolve to a plausible wrong collection.
    @Test("An identifier that names no collection resolves to nothing")
    func unknownIdentifierDoesNotFallBackToTitles() {
        let index = PresidentialLibraryIndex(
            schemaVersion: 1, generated: "2026-08-06", source: "fixture",
            libraries: [.init(prefix: "LBJ", citedAs: "Johnson Library", collections: [
                .init(identifier: "LBJ-REAL", title: "Test File", naId: 42,
                      statedSeriesCount: 0, series: [])
            ])])
        let curated = CuratedLibraryResolutions(
            schemaVersion: 1, generated: "2026-08-06", note: nil,
            entries: [.init(repository: "Johnson Library", collection: "Test File",
                            subCollection: nil, subCollectionAliases: nil,
                            collectionIdentifier: "LBJ-TYPO", seriesNaId: nil,
                            resolution: .init(title: "aid", url: "https://example.org",
                                              naId: nil, rationale: nil))])

        let outcome = PresidentialLibraryOutcome.resolve(
            repository: "Johnson Library", collection: "Test File",
            note: "Johnson Library, Test File, Box 1.", index: index, curated: curated)

        #expect(outcome == .none,
                "a typo'd identifier must surface as no answer, not as a title-matched guess")
    }

    // MARK: - Platform parity

    /// Both Source Explorer views are hand-written, and this codebase has shipped a Source
    /// Explorer affordance to one platform and not the other — #617, and the macOS custody gate
    /// that survived mutation in #704. No runtime test can reach a macOS `GroupBox` from an iOS
    /// test bundle, so the mechanical answer is to read both files.
    ///
    /// The suppression check is anchored on the **dispatch branch** — the span between the last
    /// `case .presidentialLibrary` and the live call it guards — rather than on the first
    /// occurrence of the symbol anywhere in the file. A file-wide substring search would pass on
    /// a doc comment mentioning the guard while the branch itself ran unguarded.
    private static let views = [
        "FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
        "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift",
    ]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, Comment(rawValue: "\(path) is implausibly small — did it move?"))
        return text
    }

    @Test("Both views guard the live library query on the offline outcome")
    func bothViewsSuppressTheLiveQuery() throws {
        for path in Self.views {
            let text = try Self.source(path)
            let call = try #require(
                text.range(of: "searchByPresidentialMaterials"),
                Comment(rawValue: "\(path) no longer issues the library query — update this test"))
            let branch = try #require(
                text.range(of: "case .presidentialLibrary", options: .backwards,
                           range: text.startIndex..<call.lowerBound),
                Comment(rawValue: "\(path): no dispatch branch precedes the library query"))

            #expect(text[branch.lowerBound..<call.lowerBound].contains("suppressesLiveQuery"),
                    Comment(rawValue: """
                            \(path): the presidential-library dispatch branch reaches \
                            searchByPresidentialMaterials without checking the offline outcome. \
                            An offline hit must suppress the live query (owner decision \
                            2026-08-06) — unconstrained free-text rows shown beside a verified \
                            NARA collection cannot be told apart from it.
                            """))
        }
    }

    @Test("Both views render the offline catalogue answer")
    func bothViewsRenderTheOfflineAnswer() throws {
        for path in Self.views {
            let text = try Self.source(path)
            #expect(text.contains("PresidentialLibraryOutcome.resolve"),
                    Comment(rawValue: "\(path) never resolves the bundled library catalogue"))
            #expect(text.contains("libraryOutcome.isHit"),
                    Comment(rawValue: "\(path) never branches on an offline hit"))
            #expect(text.contains("outcome.verifiedCollection"),
                    Comment(rawValue: "\(path) never renders the verified collection"))
            #expect(text.contains("outcome.caveat"),
                    Comment(rawValue: """
                            \(path) renders the offline answer without its caveat — the \
                            collection-only branch would read as an exact resolution.
                            """))
        }
    }
}
