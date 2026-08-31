// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

/// The hybrid page's machinery (V-5): the filter key set, the semantic display rows, the route
/// signature's honest rendering, the appendix caveats' mode split, and the parity pins that keep
/// the two hand-maintained search surfaces mounting the same Meaning-mode pieces.
/// Local copies of the pipeline-test helpers, which are `private` to their own files.
private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("HybridTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

private func writeTEIVolume(to url: URL, volumeId: String,
                            documents: [(id: String, xml: String)]) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let divs = documents.map { doc in
        "<div type=\"document\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
    }.joined(separator: "\n")
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="\(volumeId)">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt></fileDesc></teiHeader>
      <text><body>\(divs)</body></text>
    </TEI>
    """
    try xml.write(to: url, atomically: true, encoding: .utf8)
}

@Suite("Hybrid search mode")
struct HybridSearchModeTests {

    // MARK: - Pipeline: the filter key set

    @Test("Filters produce an uncapped key set; no filters produce nil, never everything")
    func filterKeySet() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [
                ("d1", "<head>Memorandum</head><p>Detente policy.</p>"),
                ("d2", "<head>Telegram</head><p>Negotiations.</p>"),
            ])
            try await pipeline.indexVolume("frus1969-76v01")

            // Unfiltered: nil — "the whole corpus" is not a match set (the facet precedent).
            let unfiltered = try await pipeline.documentKeysMatchingFilters(SearchSQLFilters())
            #expect(unfiltered == nil)

            // A volume scope: exactly that volume's keys.
            let scoped = try await pipeline.documentKeysMatchingFilters(
                SearchSQLFilters(volumeIds: ["frus1969-76v01"]))
            #expect(scoped == Set(["frus1969-76v01/d1", "frus1969-76v01/d2"]))

            // A scope over a volume this index has never seen: empty, not nil — filters DO
            // constrain, to nothing, and the Meaning mode must show zero rather than all.
            let foreign = try await pipeline.documentKeysMatchingFilters(
                SearchSQLFilters(volumeIds: ["frus1861"]))
            #expect(foreign == Set())
        }
    }

    @Test("Semantic display rows carry the FTS row's fields with a bounded body prefix")
    func semanticDisplayRows() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let longBody = String(repeating: "negotiation and settlement ", count: 400)
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [
                ("d1", "<head>Memorandum of Conversation</head><p>\(longBody)</p>"),
            ])
            try await pipeline.indexVolume("frus1969-76v01")

            let rows = try await pipeline.semanticResultRows(
                forKeys: [(volumeId: "frus1969-76v01", documentId: "d1"),
                          (volumeId: "frus1969-76v01", documentId: "d999")])
            #expect(rows.count == 1, "an unindexed key is absent, never invented")
            let row = try #require(rows["frus1969-76v01/d1"])
            #expect(row.header == "Memorandum of Conversation")
            #expect(row.bodyText.count <= 3000,
                    "the body is a bounded prefix — the meaning snippet reads the front only")
            #expect(!row.bodyText.isEmpty)
        }
    }

    // MARK: - The route signature and the appendix

    @Test("The semantic route signature renders as method prose, never as a keyword scope")
    func semanticSignatureDescribes() {
        let described = SearchScopeSignature.describe(SearchScopeSignature.semanticRouteSignature)
        let prose = try? #require(described?.first)
        #expect(prose?.contains("meaning") == true)
        #expect(prose?.contains("searched document text") != true)
        // The fails-closed rule stands for anything else route-shaped but unknown.
        #expect(SearchScopeSignature.describe("route=telepathy;engine=none") == nil)
    }

    @Test("The writer records the signature override verbatim for a Meaning run")
    @MainActor
    func writerHonoursSignatureOverride() throws {
        let container = try ModelContainer(
            for: SearchHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let defaults = UserDefaults(suiteName: "hybrid-writer-\(UUID().uuidString)")!
        defaults.set(true, forKey: AppState.researchLoggingPreferenceKey)

        var anchor: SearchHistoryWriter.Anchor?
        let outcome = SearchHistoryWriter.record(
            SearchHistoryWriter.Reading(
                queryText: "why did the marshall plan happen",
                resultCount: 42, loadedCount: 42, matchCount: nil, fetchLimit: 100,
                indexedVolumeCount: 12,
                parameters: SearchParameters(keywords: "why did the marshall plan happen"),
                appliedCorpusId: nil,
                renderedExpression: "route=semantic; model=m; top=100",
                signatureOverride: SearchScopeSignature.semanticRouteSignature,
                projectId: nil, hasError: false),
            anchor: &anchor, in: context, defaults: defaults)
        guard case .inserted(let id) = outcome else {
            Issue.record("expected an insert, got \(outcome)")
            return
        }
        let rows = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        let row = try #require(rows.first { $0.id == id })
        #expect(row.scopeSignature == SearchScopeSignature.semanticRouteSignature,
                "the override must be stored verbatim, not re-derived from FTS parameters")
        _ = container
    }

    @Test("Appendix caveats split by route: semantic zeros never claim term absence")
    func appendixCaveatsSplitByRoute() {
        let keywordZero = SearchHistoryEntry(
            queryText: "zanzibar treaty", resultCount: 0,
            executedAt: Date(timeIntervalSince1970: 10),
            loadedCount: 0, matchCount: 0, fetchLimit: 1_000, indexedVolumeCount: 12,
            scopeSignature: SearchScopeSignature.signature(
                for: SearchParameters(keywords: "zanzibar treaty")))
        let semanticZero = SearchHistoryEntry(
            queryText: "why did détente collapse", resultCount: 0,
            executedAt: Date(timeIntervalSince1970: 20),
            loadedCount: 0, matchCount: nil, fetchLimit: 100, indexedVolumeCount: 12,
            scopeSignature: SearchScopeSignature.semanticRouteSignature)

        // Semantic-only zero: NO term-absence caveat, semantic caveat present.
        let semanticOnly = QueryMethodAppendix.make(
            searches: [semanticZero], corpusNames: [:],
            projectName: nil, researchQuestion: nil,
            generatedAt: Date(timeIntervalSince1970: 1_000))
        #expect(semanticOnly.keywordZeroResultRowCount == 0)
        #expect(semanticOnly.semanticRowCount == 1)
        #expect(!semanticOnly.markdown.contains("the term is absent"),
                "a semantic zero says nothing about term absence")
        #expect(semanticOnly.markdown.contains("ran by meaning"))

        // Mixed: both caveats, each counting its own route.
        let mixed = QueryMethodAppendix.make(
            searches: [keywordZero, semanticZero], corpusNames: [:],
            projectName: nil, researchQuestion: nil,
            generatedAt: Date(timeIntervalSince1970: 1_000))
        #expect(mixed.keywordZeroResultRowCount == 1)
        #expect(mixed.markdown.contains("the term is absent"))
        #expect(mixed.markdown.contains("ran by meaning"))
    }

    // MARK: - The strip's disclosures

    @Test("The Meaning strip states every disclosure it owes, and only those")
    func stripCaption() {
        let base = SemanticModeStrip.caption(disclosure: nil, beyondCount: 0)
        #expect(base.contains("Front matter"))

        var disclosure = SemanticSearchBackend.Disclosure(
            unscoredCandidates: 0, unscoredVolumes: 0,
            filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false)
        #expect(SemanticModeStrip.caption(disclosure: disclosure, beyondCount: 0) == base,
                "a clean run adds nothing")

        disclosure.filtersApplied = true
        disclosure.filteredOut = 7
        disclosure.beyondUncheckedByFilters = true
        disclosure.unscoredCandidates = 12
        disclosure.unscoredVolumes = 3
        let full = SemanticModeStrip.caption(disclosure: disclosure, beyondCount: 2)
        #expect(full.contains("removed 7"))
        #expect(full.contains("volume scope only"))
        #expect(full.contains("could not be scored"))
    }

    // MARK: - Twin-surface parity pins

    private static func searchSurfaceSource(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("Both search surfaces mount the Meaning mode's pieces")
    func bothSurfacesMountMeaningPieces() throws {
        for path in ["FRUSExplorer/Search/SearchView.swift", "FRUSExplorer/App/SearchSheet.swift"] {
            let source = try Self.searchSurfaceSource(path)
            for piece in ["SemanticModeStrip(", "SemanticBeyondLibrarySection(hits:",
                          "SemanticMeaningEmptyState(", "makeSemanticBackend()",
                          "SearchMode.allCases"] {
                #expect(source.contains(piece), "\(path) must mount \(piece)")
            }
            #expect(source.contains(".meaning"),
                    "\(path) must gate its keyword-only readings off in Meaning mode")
        }
    }

    @Test("The backend keeps the score-sign contract: ordering negated, display verbatim")
    func backendScoreSignContract() throws {
        // A silent inversion here breaks the date sorts' tie-break with no test failing
        // anywhere else, so the mapping is pinned at the source: `bm25Score` must carry the
        // NEGATED cosine (lower-is-better convention) and `semanticScore` the cosine itself.
        let source = try Self.searchSurfaceSource("FRUSExplorer/Search/SemanticSearchBackend.swift")
        #expect(source.contains("bm25Score: -hit.score"))
        #expect(source.contains("semanticScore: hit.score"))
    }

    @Test("The field prompt changes with the engine, and the surface keeps its keyword wording")
    func fieldPromptFollowsMode() {
        // Structural assertions only. Pinning the literal copy would be a second copy of the
        // string table: red on a harmless wording edit, and green if the wiring were broken.
        let keywordWording = "«surface's own wording»"

        #expect(SearchMode.keywords.fieldPrompt(keywordPrompt: keywordWording) == keywordWording,
                "Keywords mode must return the surface's wording untouched: the two search fields differ deliberately")

        let meaning = SearchMode.meaning.fieldPrompt(keywordPrompt: keywordWording)
        #expect(!meaning.isEmpty)
        #expect(meaning != keywordWording,
                "Meaning mode must supply its own prompt; returning the keyword wording is the defect A-1 exists to fix")

        // The Meaning prompt is a property of the engine, not of the caller, so it must not vary
        // with what the surface passed in.
        #expect(SearchMode.meaning.fieldPrompt(keywordPrompt: "something else") == meaning)
    }

    @Test("The pre-search prompt varies on both mode and scope, with no repeats")
    func initialPromptVariesOnModeAndScope() {
        // Four distinct strings across the two axes. Structural, not a copy of the string
        // table: the failure this catches is a missed switch arm returning a neighbour's
        // string, which reads plausibly and would ship.
        let all = SearchMode.allCases.flatMap { mode in
            [mode.initialPrompt(scoped: false), mode.initialPrompt(scoped: true)]
        }
        #expect(all.count == 4)
        #expect(Set(all).count == 4, "each mode/scope pair needs its own wording")
        #expect(all.allSatisfy { !$0.isEmpty })

        // The mode axis must actually move, in both scope states — the defect being fixed is a
        // prompt that stayed on the keyword wording after the reader switched engines.
        #expect(SearchMode.keywords.initialPrompt(scoped: false)
                != SearchMode.meaning.initialPrompt(scoped: false))
        #expect(SearchMode.keywords.initialPrompt(scoped: true)
                != SearchMode.meaning.initialPrompt(scoped: true))
    }

    @Test("The pre-search prompt is wired to the mode, and the scope polarity is not inverted")
    func initialPromptIsWiredWithCorrectPolarity() throws {
        // `effectiveVolumeIds.isEmpty` means UNSCOPED, so the call must negate it. Passing the
        // flag straight through inverts the two strings — a swap no unit test on the enum can
        // see, and one that reads plausibly on screen until you notice the corpus prompt only
        // appears inside a volume.
        let source = try Self.searchSurfaceSource("FRUSExplorer/Search/SearchView.swift")
        #expect(source.contains("vm.searchMode.initialPrompt(scoped: !vm.effectiveVolumeIds.isEmpty)"),
                "the pre-search prompt must come from the mode, with isEmpty negated into scoped")
        #expect(!source.contains("defaultValue: \"Enter keywords to search the FRUS corpus.\""),
                "the mode-blind literal is gone from the view; it now lives on SearchMode")
    }

    @Test("Both surfaces route their field prompt through SearchMode")
    func bothSurfacesRoutePromptThroughMode() throws {
        // A unit test can reach the enum but not a `.searchable(prompt:)` argument inside a
        // private view body, so the wiring is pinned at the source. Two-sided on purpose: the
        // positive half alone would survive someone leaving the old static prompt in place.
        // What this CANNOT check: that the placeholder visibly changes when the reader taps
        // Meaning. That is an on-device check on both platforms.
        let ios = try Self.searchSurfaceSource("FRUSExplorer/Search/SearchView.swift")
        #expect(ios.contains("prompt: vm.searchMode.fieldPrompt("),
                "SearchView must derive its prompt from the mode")
        #expect(ios.contains("search.keywords.placeholder"),
                "iOS keeps its own compact keyword wording")

        let mac = try Self.searchSurfaceSource("FRUSExplorer/App/SearchSheet.swift")
        #expect(mac.contains("searchVM.searchMode.fieldPrompt("),
                "SearchSheet must derive its prompt from the mode")
        #expect(!mac.contains("TextField(\"Search documents, notes, summaries…\""),
                "the raw literal is gone; this line is the only mechanical guard against its return")
        #expect(mac.contains("search.query.placeholder.mac"),
                "the Mac keyword wording survives as a localized string, naming the three scopes")
    }

    @Test("Both surfaces force Keywords mode when running a SavedSearch")
    func savedSearchForcesKeywords() throws {
        for path in ["FRUSExplorer/Search/SearchView.swift", "FRUSExplorer/App/SearchSheet.swift"] {
            let source = try Self.searchSurfaceSource(path)
            let range = try #require(source.range(of: "SavedSearchesView { saved in"),
                                     "\(path) lost its SavedSearches mount")
            let after = source[range.upperBound...].prefix(600)
            #expect(after.contains("searchMode = .keywords"),
                    "\(path): a SavedSearch archives FTS parameters and its W-5 freshness watermark diffs against FTS counts — it must never run semantic")
        }
    }
}
