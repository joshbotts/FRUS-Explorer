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

    /// The Meaning mode reads its FILTERS from the parameters and nothing else (#1299 round 2). The typed text is the
    /// semantic query, so a keyword mark in it must not reach the intersection: `=containment policy` used to add an
    /// exact-word filter here, which removed every semantic hit whose document lacks the literal word and reported them
    /// as "Your filters removed N matches" to a reader who had set no filter — while Search Tips said `=` does nothing
    /// in a Meaning search.
    @Test("The Meaning filter key set reads no typed text: a typed = adds no exact-word filter")
    func filterKeySetIgnoresTypedText() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let service = SearchService(fts5Store: store, pipeline: pipeline)
            let volDir = dir.appendingPathComponent("volumes")
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [
                ("d1", "<head>Memorandum</head><p>The containment policy toward the Soviet Union.</p>"),
                ("d2", "<head>Telegram</head><p>We must contain Soviet expansion; that is our policy.</p>"),
            ])
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                               volumeId: "frus1969-76v02",
                               documents: [
                ("d1", "<head>Letter</head><p>Containment again.</p>"),
            ])
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v02")

            // Precondition: in a KEYWORD search the mark is live — it narrows the stemmed match to the literal word —
            // so a nil key set below is the Meaning route ignoring it, not a mark that does nothing anywhere.
            let typed = "=containment policy"
            #expect(SearchService.exactTerms(from: SearchParameters(keywords: typed)) == ["containment"])
            let stemmed = try await service.search(parameters: SearchParameters(keywords: "containment policy"))
            let marked = try await service.search(parameters: SearchParameters(keywords: typed))
            #expect(Set(stemmed.map { "\($0.volumeId)/\($0.documentId)" })
                    == ["frus1969-76v01/d1", "frus1969-76v01/d2"], "precondition: stemmed, contain matches too")
            #expect(marked.map { "\($0.volumeId)/\($0.documentId)" } == ["frus1969-76v01/d1"],
                    "precondition: marked, the keyword search keeps only the literal word")

            // No filter set: nothing constrains, whatever the reader typed.
            for keywords in ["=containment", typed, "=containment -soviet"] {
                let keys = try await service.filterKeySet(parameters: SearchParameters(keywords: keywords))
                #expect(keys == nil, "\(keywords) reached the Meaning filter intersection as \(String(describing: keys))")
            }

            // A real filter beside typed syntax: exactly the filter's own key set.
            let volumeOnly = try await service.filterKeySet(
                parameters: SearchParameters(volumeIds: ["frus1969-76v01"]))
            #expect(volumeOnly == Set(["frus1969-76v01/d1", "frus1969-76v01/d2"]), "precondition: the filter alone")
            let volumeAndMark = try await service.filterKeySet(
                parameters: SearchParameters(keywords: "=containment", volumeIds: ["frus1969-76v01"]))
            #expect(volumeAndMark == volumeOnly, "the typed = narrowed the filter's key set")
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
    func semanticSignatureDescribes() throws {
        let described = SearchScopeSignature.describe(SearchScopeSignature.semanticRouteSignature)
        let prose = try #require(described?.first)
        #expect(prose.contains("meaning"))
        #expect(!prose.contains("searched document text"))
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
    @MainActor
    func stripCaption() {
        let base = SemanticModeStrip.caption(disclosure: nil, beyondCount: 0)
        #expect(base.contains("Front matter"))

        var disclosure = SemanticSearchBackend.Disclosure(
            unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
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

    // MARK: - #1527: "downloading" only when it is

    private static let enUS = Locale(identifier: "en_US")

    /// With Download With Volumes off (or offline) nothing downloads, so the caption points to
    /// Download Missing Vectors — the owner's wording — and never says "downloading".
    @Test("With no download under way, the unscored sentence points to Download Missing Vectors (#1527)")
    func unscoredWithNothingDownloading() {
        let text = SemanticUnscoredCopy.unscored(candidates: 12, volumes: 3, downloading: 0, locale: Self.enUS)
        #expect(text == "12 possible matches in 3 volumes could not be scored. Try Download Missing Vectors in Settings to enable scoring.")
        #expect(!text.contains("downloading"), "nothing is downloading: \(text)")
    }

    /// The searcher asks only for its top candidates' volumes, so with the switch on some unscored
    /// volumes can still be un-asked-for. One of those is enough to make "their match files are
    /// downloading" false; with every one downloading, the owner kept the old sentence, which is
    /// then true. Both sides of that boundary, in one test.
    @Test("The unscored sentence claims a download only when every unscored volume has one (#1527)")
    func unscoredClaimsADownloadOnlyForAll() {
        let two = SemanticUnscoredCopy.unscored(candidates: 12, volumes: 3, downloading: 2, locale: Self.enUS)
        #expect(two.hasSuffix("Try Download Missing Vectors in Settings to enable scoring."), "\(two)")
        #expect(!two.contains("downloading"), "one of the three volumes was never queued: \(two)")
        let all = SemanticUnscoredCopy.unscored(candidates: 12, volumes: 3, downloading: 3, locale: Self.enUS)
        #expect(all == "12 possible matches in 3 volumes could not be scored yet; their match files are downloading.")
    }

    /// The new variant goes through `CountCopy`: singular at one and grouped past 999.
    @Test("The not-downloading sentence is singular at one and grouped past 999 (#1527)")
    func unscoredCountsReadRight() {
        #expect(SemanticUnscoredCopy.unscored(candidates: 1, volumes: 1, downloading: 0, locale: Self.enUS)
                == "1 possible match in 1 volume could not be scored. Try Download Missing Vectors in Settings to enable scoring.")
        #expect(SemanticUnscoredCopy.unscored(candidates: 1_204, volumes: 2, downloading: 0, locale: Self.enUS)
                .hasPrefix("1,204 possible matches in 2 volumes"))
    }

    /// The empty state's pair, with the same rule.
    @Test("The empty state says downloading only when every unscored volume is (#1527)")
    func warmingVariants() {
        #expect(SemanticUnscoredCopy.warming(volumes: 3, downloading: 0, locale: Self.enUS)
                == "Match files for 3 volumes are required. Use Download Missing Vectors to get the data needed to run this search.")
        #expect(SemanticUnscoredCopy.warming(volumes: 1, downloading: 0, locale: Self.enUS)
                == "Match files for 1 volume are required. Use Download Missing Vectors to get the data needed to run this search.")
        #expect(SemanticUnscoredCopy.warming(volumes: 3, downloading: 1, locale: Self.enUS)
                .hasPrefix("Match files for 3 volumes are required."))
        #expect(SemanticUnscoredCopy.warming(volumes: 3, downloading: 3, locale: Self.enUS)
                == "Match files for 3 volumes are still downloading in the background. Searching again in a moment may find more.")
    }

    /// The Meaning strip reads the disclosure's own downloading count — the real caption path, not
    /// the copy function alone.
    @Test("The Meaning strip's unscored sentence follows the disclosure's downloading count (#1527)")
    @MainActor
    func stripFollowsDownloadingCount() {
        var disclosure = SemanticSearchBackend.Disclosure(
            unscoredCandidates: 12, unscoredVolumes: 3, downloadingVolumes: 0,
            filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false)
        let off = SemanticModeStrip.caption(disclosure: disclosure, beyondCount: 0)
        #expect(off.contains("Download Missing Vectors") && !off.contains("are downloading"), "\(off)")
        disclosure.downloadingVolumes = 3
        let on = SemanticModeStrip.caption(disclosure: disclosure, beyondCount: 0)
        #expect(on.contains("their match files are downloading"), "\(on)")
    }

    /// The text of the call that starts at `open` (an index just past its `(`), balanced.
    private static func callText(_ source: String, from open: String.Index) -> String {
        var depth = 1
        var index = open
        while index < source.endIndex, depth > 0 {
            if source[index] == "(" { depth += 1 } else if source[index] == ")" { depth -= 1 }
            index = source.index(after: index)
        }
        return String(source[open..<index])
    }

    /// Every search surface tells the caption whether a fetch really starts. A surface that left it
    /// out would claim "downloading" with the switch off, which is #1527 again on one platform.
    @Test("Both backends and the keyword fallback read whether shard fetches run (#1527)")
    func surfacesReadWhetherFetchesRun() throws {
        var calls = 0
        for path in ["FRUSExplorer/Search/SearchView.swift", "FRUSExplorer/App/SearchSheet.swift"] {
            let source = try Self.searchSurfaceSource(path)
            var searchFrom = source.startIndex
            while let open = source.range(of: "SemanticSearchBackend(", range: searchFrom..<source.endIndex) {
                let call = Self.callText(source, from: open.upperBound)
                calls += 1
                #expect(call.contains("shardFetchesRun:") && call.contains("semanticShardFetchesRun"),
                        "\(path): SemanticSearchBackend(\(call) does not read appState.semanticShardFetchesRun")
                searchFrom = open.upperBound
            }
        }
        #expect(calls == 2, "found \(calls) SemanticSearchBackend( calls in the two surfaces")
        let fallback = try Self.searchSurfaceSource("FRUSExplorer/Search/SemanticSearchFallbackView.swift")
        #expect(fallback.contains("appState.semanticShardFetchesRun ? results.queuedVolumes : 0"),
                "the keyword fallback must count a volume as downloading only when fetches run")
    }
}
