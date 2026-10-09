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

    /// With no download under way nothing will arrive on its own, so the caption points to the
    /// control that fetches the files and never says "downloading". Since review round 1 that
    /// control is Download Vectors for Every Volume: the owner's option (a) named Download Missing
    /// Vectors, which fetches only for downloaded volumes, while the unscored ones are usually not.
    @Test("With no download under way, the unscored sentence points to Download Vectors for Every Volume (#1527)")
    func unscoredWithNothingDownloading() {
        let text = SemanticUnscoredCopy.unscored(candidates: 12, volumes: 3, downloading: 0, locale: Self.enUS)
        #expect(text == "12 possible matches in 3 volumes could not be scored. Try Download Vectors for Every Volume in Settings to enable scoring.")
        #expect(!text.contains("downloading"), "nothing is downloading: \(text)")
    }

    /// The searcher asks only for its top candidates' volumes, so with the switch on some unscored
    /// volumes can still be un-asked-for. One of those is enough to make "their match files are
    /// downloading" false; with every one downloading, the owner kept the old sentence, which is
    /// then true. Both sides of that boundary, in one test.
    @Test("The unscored sentence claims a download only when every unscored volume has one (#1527)")
    func unscoredClaimsADownloadOnlyForAll() {
        let two = SemanticUnscoredCopy.unscored(candidates: 12, volumes: 3, downloading: 2, locale: Self.enUS)
        #expect(two.hasSuffix("Try Download Vectors for Every Volume in Settings to enable scoring."), "\(two)")
        #expect(!two.contains("downloading"), "one of the three volumes was never asked for: \(two)")
        let all = SemanticUnscoredCopy.unscored(candidates: 12, volumes: 3, downloading: 3, locale: Self.enUS)
        #expect(all == "12 possible matches in 3 volumes could not be scored yet; their match files are downloading.")
    }

    /// Both variants go through `CountCopy`: singular at one and grouped past 999. The downloading
    /// one kept `%lld` in the first build and read "1 possible matches in 1 volumes" — the case it
    /// is most often shown for, since it needs every unscored volume downloading (review round 1).
    @Test("Both unscored sentences are singular at one and grouped past 999 (#1527)")
    func unscoredCountsReadRight() {
        #expect(SemanticUnscoredCopy.unscored(candidates: 1, volumes: 1, downloading: 0, locale: Self.enUS)
                == "1 possible match in 1 volume could not be scored. Try Download Vectors for Every Volume in Settings to enable scoring.")
        #expect(SemanticUnscoredCopy.unscored(candidates: 1_204, volumes: 2, downloading: 0, locale: Self.enUS)
                .hasPrefix("1,204 possible matches in 2 volumes"))
        #expect(SemanticUnscoredCopy.unscored(candidates: 1, volumes: 1, downloading: 1, locale: Self.enUS)
                == "1 possible match in 1 volume could not be scored yet; their match files are downloading.")
        #expect(SemanticUnscoredCopy.unscored(candidates: 1_204, volumes: 1_001, downloading: 1_001, locale: Self.enUS)
                .hasPrefix("1,204 possible matches in 1,001 volumes could not be scored yet"))
    }

    /// The empty state's pair, with the same rule.
    @Test("The empty state says downloading only when every unscored volume is (#1527)")
    func warmingVariants() {
        #expect(SemanticUnscoredCopy.warming(volumes: 3, downloading: 0, locale: Self.enUS)
                == "Match files for 3 volumes are required. Use Download Vectors for Every Volume in Settings to get the data needed to run this search.")
        #expect(SemanticUnscoredCopy.warming(volumes: 1, downloading: 0, locale: Self.enUS)
                == "Match files for 1 volume are required. Use Download Vectors for Every Volume in Settings to get the data needed to run this search.")
        #expect(SemanticUnscoredCopy.warming(volumes: 3, downloading: 1, locale: Self.enUS)
                .hasPrefix("Match files for 3 volumes are required."))
        #expect(SemanticUnscoredCopy.warming(volumes: 3, downloading: 3, locale: Self.enUS)
                == "Match files for 3 volumes are still downloading in the background. Searching again in a moment may find more.")
        #expect(SemanticUnscoredCopy.warming(volumes: 1, downloading: 1, locale: Self.enUS)
                == "Match files for 1 volume are still downloading in the background. Searching again in a moment may find more.")
    }

    /// The label a control in the Semantic Vectors section is declared with, read from its source.
    private static func storageSectionLabel(_ key: String) throws -> String {
        let source = try searchSurfaceSource("FRUSExplorer/Settings/SemanticStorageSection.swift")
        let call = try #require(source.range(of: "localized: \"\(key)\""), "\(key) is not declared")
        let tail = source[call.upperBound...]
        let open = try #require(tail.range(of: "defaultValue: \""))
        let close = try #require(tail[open.upperBound...].firstIndex(of: "\""))
        return String(tail[open.upperBound..<close])
    }

    /// Review round 1: the not-downloading sentences name the Settings control that really fetches
    /// the files they are about. A meaning search ranks the whole series, so the unscored volumes
    /// are usually ones the reader has not downloaded; Download Missing Vectors fetches only for
    /// downloaded volumes, and SemanticStorageSection hides it whenever every downloaded volume
    /// has its file — the ordinary state with Download With Volumes on. Read from the section's own
    /// labels, so a renamed button fails here rather than leaving the caption naming nothing.
    @Test("The not-downloading sentences name the button that fetches every volume's file (#1527)")
    func notFetchingNamesTheCorpusWideButton() throws {
        let everyVolume = try Self.storageSectionLabel("settings.vectors.downloadAll.label")
        let missing = try Self.storageSectionLabel("settings.vectors.download.label")
        #expect(everyVolume == "Download Vectors for Every Volume" && missing == "Download Missing Vectors",
                "precondition: the section's two download buttons, read as \(everyVolume) / \(missing)")
        for text in [SemanticUnscoredCopy.unscored(candidates: 5, volumes: 2, downloading: 0, locale: Self.enUS),
                     SemanticUnscoredCopy.warming(volumes: 2, downloading: 0, locale: Self.enUS)] {
            #expect(text.contains(everyVolume), "\(text) does not name \(everyVolume)")
            #expect(!text.contains(missing), "\(text) names \(missing), which does not fetch these volumes")
        }
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
        #expect(off.contains("Download Vectors for Every Volume") && !off.contains("are downloading"), "\(off)")
        disclosure.downloadingVolumes = 3
        let on = SemanticModeStrip.caption(disclosure: disclosure, beyondCount: 0)
        #expect(on.contains("their match files are downloading"), "\(on)")
    }

    /// The keyword fallback passes the searcher's own downloading count to both of its phases —
    /// the count `SemanticQuerySearcherTests` drives, answered fetch by fetch. Review round 1
    /// replaced a caption-time gate on an ask count, which counted declined asks once the switch
    /// was on. (The Meaning backend's pass-through is driven at run time there.)
    @Test("The keyword fallback shows the searcher's own downloading count (#1527)")
    func fallbackShowsTheSearchersCount() throws {
        let fallback = try Self.searchSurfaceSource("FRUSExplorer/Search/SemanticSearchFallbackView.swift")
        #expect(fallback.contains("let downloading = results.downloadingVolumes\n"),
                "the keyword fallback must read SemanticQuerySearcher.Results.downloadingVolumes as it is")
        #expect(fallback.components(separatedBy: "downloadingVolumes: downloading)").count - 1 == 2,
                "both the results and the empty phase must carry that count")
        #expect(!fallback.contains("semanticShardFetchesRun"))
    }
}

// MARK: - SearchResultRouteTests (#1584, #1595, #1596, #1597, #1598)

/// A Meaning engine that returns the rows it was given, for driving a Meaning run through the view model.
///
/// `SemanticSearchBackend` needs the query encoder's model and the vector files, which a test host has neither of;
/// the view models hold the engine as `MeaningSearchRunning` so this can stand in for it.
@MainActor
private struct FixedMeaningSearch: MeaningSearchRunning {

    /// The rows every run returns.
    let rows: [SearchResult]

    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        SemanticSearchBackend.Outcome(
            results: rows, beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false))
    }

    /// `count` rows with a semantic score each, as a Meaning run returns them.
    static func returning(_ count: Int) -> FixedMeaningSearch {
        FixedMeaningSearch(rows: (0..<count).map { index in
            SearchResult(documentId: "m\(index)", volumeId: "vol1", header: "\(index + 1). Item",
                         snippet: "", bm25Score: -Double(count - index),
                         semanticScore: 0.9 - Double(index) / 1_000)
        })
    }
}

/// What the search screen says of the rows it shows follows the run that produced them: the ceiling that fetch ran
/// under, and the engine it ran through.
///
/// Each of these drives `SearchViewModel` over a real index, because the defects were in the wiring and not in the
/// sentences. `ResultSetScope`'s sentences had passed their own tests all along while `SearchView` handed them the
/// keyword ceiling for a browse (#1584) and the picker's mode for the engine (#1597).
///
/// Version history:
///   1.0 — #1584, #1595, #1596, #1597, #1598: initial implementation
@Suite("Search results are described by the run that produced them")
@MainActor
struct SearchResultRouteTests {

    /// A view model over an index of `documents` documents in one volume, every one holding the word
    /// "containment" and tagged with subject area 2, so one fixture answers a keyword search and a browse.
    private func makeViewModel(documents: Int) async throws -> (dir: URL, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSRoute-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<documents {
            xml += "<div type=\"document\" xml:id=\"d\(index)\"><head>\(index + 1). Item</head>"
                + "<p>The doctrine of containment shaped policy.</p></div>\n"
        }
        xml += "</body></text></TEI>"
        try Data(xml.utf8).write(to: volDir.appendingPathComponent("vol1.xml"))
        let dbURL = dir.appendingPathComponent("t.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        let subjectRows: @Sendable (String) -> [(documentId: String, buckets: [Int], subjects: [Int])] = { _ in
            (0..<documents).map { (documentId: "d\($0)", buckets: [2], subjects: [10]) }
        }
        _ = try await pipeline.applyDocumentSubjects(rows: subjectRows, digest: "d1", volumeIds: ["vol1"])
        return (dir, SearchViewModel(searchService: SearchService(fts5Store: fts5, pipeline: pipeline)))
    }

    // MARK: - #1584: a browse is measured against the ceiling it was fetched under

    /// One document more than the keyword ceiling. As a browse it is fetched under 7,500 and is all on the device;
    /// as a keyword search over the same documents it is cut at 1,000. The screen has to tell the two apart.
    @Test("A complete browse of more than 1,000 documents reads as complete, and a capture of it is whole")
    func completeBrowsePastTheKeywordCeilingReadsComplete() async throws {
        let count = SearchViewModel.searchHardLimit + 1
        let (dir, vm) = try await makeViewModel(documents: count)
        defer { try? FileManager.default.removeItem(at: dir) }

        vm.subjectBucket = 2
        await vm.search()
        #expect(vm.results.count == count, "the browse loads every tagged document")
        let browse = vm.resultSetScope
        #expect(browse.headerDescription == "1,001 results", """
            A browse that loaded every document it matched is described as cut off. The scope was built with the \
            keyword ceiling where the fetch ran under the browse ceiling (#1584).
            """)
        #expect(browse.overCapGuidance == nil, "nothing more would load, so there is no advice to narrow")
        #expect(browse.timelineBiasCaption == nil)
        #expect(browse.captureTruncationWarning == nil)
        #expect(browse.captureProvenanceDescription == "Search results")
        #expect(!browse.isCapturePartial, "a working corpus saved from it is every matching document")

        // The control: the same documents through a keyword search stop at 1,000 and say so.
        vm.subjectBucket = nil
        vm.keywords = "containment"
        await vm.search()
        #expect(vm.results.count == SearchViewModel.searchHardLimit)
        let keyword = vm.resultSetScope
        #expect(keyword.headerDescription == "1,000 loaded · 1,001 total")
        #expect(keyword.overCapGuidance != nil)
        #expect(keyword.isCapturePartial)
        #expect(keyword.captureProvenanceDescription == "Search results — the highest-scoring 1,000 of 1,001 matches")
    }

    // MARK: - #1597: the rows belong to the engine the picker names

    @Test("Switching to Meaning over a browse clears its rows, and switching back runs it again")
    func modeSwitchOverABrowseClearsItAndTheWayBackRestoresIt() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(3)

        vm.subjectBucket = 2
        await vm.search()
        #expect(vm.results.count == 6)
        #expect(vm.resultSetScope.headerDescription == "6 results")

        // A browse has no question, so the Meaning engine has nothing to run.
        #expect(!vm.switchSearchMode(to: .meaning), "there is nothing for the Meaning engine to run")
        #expect(vm.searchMode == .meaning)
        #expect(vm.results.isEmpty, """
            The browse's rows stayed on screen after the picker moved to Meaning. They would be drawn under the \
            Meaning strip although no Meaning search ran (#1597).
            """)
        #expect(!vm.hasSearched, "so the pre-search prompt shows, not the Meaning empty state")
        #expect(vm.searchError == nil)
        #expect(vm.totalMatchCount == nil)
        #expect(vm.userTagCountScope == nil)
        #expect(vm.subjectBucket == 2, "the filter is the reader's and stays")

        // The way back: the browse the switch set aside runs again.
        #expect(vm.switchSearchMode(to: .keywords), "the browse is run again on the way back")
        await vm.search()
        #expect(vm.results.count == 6)
        #expect(vm.resultSetScope.headerDescription == "6 results")
    }

    @Test("Until the new engine's rows arrive, the rows on screen are described by the engine they came from")
    func rowsKeepTheirOwnEngineUntilTheRunReplacesThem() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(3)

        vm.keywords = "containment"
        await vm.search()
        #expect(vm.resultSetScope.headerDescription == "6 results")

        // The picker has moved and the run has not happened yet: these are still the keyword search's rows.
        #expect(vm.switchSearchMode(to: .meaning), "typed text is a question the Meaning engine can run")
        #expect(vm.searchMode == .meaning)
        #expect(!vm.resultSetScope.isMeaningSearch)
        #expect(vm.resultSetScope.headerDescription == "6 results", """
            Keyword rows are counted as "closest matches" because the picker says Meaning. The scope must read the \
            engine that produced the rows, not the picker (#1597).
            """)

        await vm.search()
        #expect(vm.results.count == 3)
        #expect(vm.resultSetScope.isMeaningSearch)
        #expect(vm.resultSetScope.headerDescription == "3 closest matches")

        // And the other way round.
        #expect(vm.switchSearchMode(to: .keywords))
        #expect(vm.resultSetScope.headerDescription == "3 closest matches")
        await vm.search()
        #expect(vm.resultSetScope.headerDescription == "6 results")
    }

    @Test("A mode switch before any search runs nothing and clears nothing")
    func aModeSwitchBeforeAnySearchRunsNothing() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.keywords = "containment"   // typed, never submitted
        #expect(!vm.switchSearchMode(to: .meaning))
        #expect(!vm.switchSearchMode(to: .keywords))
        #expect(!vm.switchSearchMode(to: .keywords), "choosing the mode already chosen does nothing")
        #expect(vm.keywords == "containment")
        #expect(!vm.hasSearched)
    }

    // MARK: - #1598, and #1584's Meaning case: a Meaning list is not a fetch at its ceiling

    @Test("A full Meaning list is not advised to narrow, and a capture of it says what it is")
    func aFullMeaningListIsDescribedAsARanking() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(SemanticSearchBackend.hitLimit)
        vm.searchMode = .meaning
        vm.keywords = "how was containment meant to work"
        await vm.search()

        #expect(vm.results.count == 100)
        #expect(vm.lastFetchLimit == 100, "the ceiling recorded with these rows is the Meaning engine's list length")
        let scope = vm.resultSetScope
        #expect(!scope.didHitFetchLimit, """
            A full Meaning list reads as a fetch that hit its ceiling. Its 100 rows are the answer's shape, and \
            narrowing loads nothing more (#1595, and #1584's Meaning case).
            """)
        #expect(scope.headerDescription == "100 closest matches")
        #expect(scope.overCapGuidance == nil)
        #expect(scope.captureProvenanceDescription == "Meaning search — the 100 closest matches", """
            A working corpus saved from a Meaning list is stored as "Search results", the words a complete keyword \
            capture gets (#1598).
            """)
        #expect(scope.captureTruncationWarning?.contains("Meaning search") == true)
        #expect(scope.isCapturePartial, "a ranking's nearest documents are never every matching document")
        #expect(scope.totalMatchCount == nil)
    }

    // MARK: - A hand-off that names a search runs as a keyword search

    @Test("A hand-off that names something to find sets the picker to Keywords; one that only sets a scope does not")
    func aHandoffThatNamesASearchRunsAsKeywords() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Find all mentions, a topic: no typed text at all.
        vm.searchMode = .meaning
        var browse = SearchParameters()
        browse.subjectBucket = 2
        #expect(vm.applyHandoff(browse), "a subject-only hand-off names a search to run")
        #expect(vm.searchMode == .keywords, """
            A browse hand-off kept the picker on Meaning. The Meaning engine has no question to run for it, so the \
            reader lands on "Type a question or phrase to search by meaning."
            """)
        await vm.search()
        #expect(vm.results.count == 6)
        #expect(vm.searchError == nil)

        // Corpus Analytics' "View N documents": a term.
        vm.searchMode = .meaning
        #expect(vm.applyHandoff(SearchParameters(keywords: "containment")))
        #expect(vm.searchMode == .keywords)

        // Search this volume: a scope and nothing to find. It runs nothing and leaves the picker alone.
        vm.searchMode = .meaning
        var scopeOnly = SearchParameters()
        scopeOnly.volumeIds = ["vol1"]
        #expect(!vm.applyHandoff(scopeOnly))
        #expect(vm.searchMode == .meaning)
    }

    @Test("The hand-off rule counts typed text, a phrase, a prefix, a person and a subject, and not an empty string")
    func handoffRule() {
        #expect(!SearchParameters().namesASearchToRun)
        #expect(!SearchParameters(keywords: "").namesASearchToRun, "an empty string is nothing to find")
        #expect(SearchParameters(keywords: "berlin").namesASearchToRun)
        var phrase = SearchParameters(); phrase.phrase = "berlin blockade"
        #expect(phrase.namesASearchToRun)
        var prefix = SearchParameters(); prefix.prefixWildcard = "negotiat"
        #expect(prefix.namesASearchToRun)
        var person = SearchParameters(); person.personRef = "p_KHA1"
        #expect(person.namesASearchToRun)
        var subject = SearchParameters(); subject.subjectBucket = 2
        #expect(subject.namesASearchToRun)
        var excluded = SearchParameters(); excluded.excludedTerms = ["berlin"]
        #expect(!excluded.namesASearchToRun, "an exclusion alone names nothing to find")
        var volume = SearchParameters(); volume.volumeIds = ["vol1"]
        #expect(!volume.namesASearchToRun)
    }

    // MARK: - #1592: Checklist Mode says when Log Research Sessions is off

    @Test("The checklist's line shows only while the mode is on and Log Research Sessions is off")
    func checklistLoggingNotice() throws {
        #expect(ChecklistLoggingNotice.text(checklistMode: false, loggingEnabled: true) == nil)
        #expect(ChecklistLoggingNotice.text(checklistMode: false, loggingEnabled: false) == nil,
                "with the mode off nothing is being hidden, so there is nothing to explain")
        #expect(ChecklistLoggingNotice.text(checklistMode: true, loggingEnabled: true) == nil)
        let notice = try #require(ChecklistLoggingNotice.text(checklistMode: true, loggingEnabled: false))
        #expect(notice.contains("Log Research Sessions"), "it names the switch as Settings labels it")
        #expect(notice.contains("Mark Reviewed"), "and the way of hiding a result that still works")
    }

    // MARK: - The wiring a unit test cannot drive

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is missing or empty")
        return text
    }

    /// The text of the declaration that starts with `header`, through its closing brace.
    private static func declaration(_ header: String, in source: String, path: String) throws -> String {
        let start = try #require(source.range(of: header), "\(path) no longer declares `\(header)`")
        var depth = 0
        var opened = false
        var index = start.lowerBound
        while index < source.endIndex {
            let character = source[index]
            if character == "{" { depth += 1; opened = true }
            if character == "}" { depth -= 1 }
            index = source.index(after: index)
            if opened && depth == 0 { break }
        }
        #expect(opened && depth == 0, "\(path): `\(header)` has no balanced body")
        return String(source[start.lowerBound..<index])
    }

    /// `MacSearchViewModel` is compiled for the Mac only and this target runs on iOS, so its half of the wiring is
    /// pinned where it is written. The iPhone view model's half is driven above; both are read here so the two cannot
    /// part.
    @Test("Both view models compose the scope from the ceiling and the engine recorded with the rows")
    func bothViewModelsComposeTheScopeFromTheRun() throws {
        for path in ["FRUSExplorer/Search/SearchViewModel.swift", "FRUSExplorer/App/MacSearchViewModel.swift"] {
            let source = try Self.source(path)
            let scope = try Self.declaration("var resultSetScope: ResultSetScope {", in: source, path: path)
            #expect(scope.contains("fetchLimit: lastFetchLimit,"),
                    "\(path): the scope must carry the ceiling this fetch ran under, not a constant (#1584)")
            #expect(scope.contains("isMeaningSearch: resultsAreSemantic)"),
                    "\(path): the scope must carry the engine that produced the rows, not the picker (#1597)")
            #expect(!scope.contains("searchMode"), "\(path): the scope reads the picker")
            #expect(!scope.contains("HardLimit"), "\(path): the scope reads a ceiling constant")
        }
        let mac = try Self.source("FRUSExplorer/App/MacSearchViewModel.swift")
        let truncated = try Self.declaration("var isResultSetTruncated: Bool {", in: mac,
                                             path: "MacSearchViewModel.swift")
        #expect(truncated.contains("resultSetScope.didHitFetchLimit"), """
            The Mac window's truncation flag has its own rule again. It called a full Meaning list truncated while \
            the shared scope did not (#1595).
            """)
    }

    @Test("Neither search view composes a scope of its own")
    func neitherViewComposesAScope() throws {
        let ios = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let mac = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        #expect(ios.contains("private var resultSetScope: ResultSetScope { vm.resultSetScope }"))
        #expect(mac.contains("private var resultSetScope: ResultSetScope { searchVM.resultSetScope }"))
        for (path, source) in [("SearchView.swift", ios), ("SearchSheet.swift", mac)] {
            #expect(!source.contains("ResultSetScope("),
                    "\(path) builds a ResultSetScope itself; the view model's is the one recorded with the rows")
        }
    }

    @Test("Visualize in Corpus Analytics is offered in Keywords mode only, on both surfaces (#1596)")
    func visualizeIsKeywordsOnly() throws {
        for (path, mode) in [("FRUSExplorer/Search/SearchView.swift", "vm.searchMode == .keywords"),
                             ("FRUSExplorer/App/SearchSheet.swift", "searchVM.searchMode == .keywords")] {
            let source = try Self.source(path)
            // The button, and only the button: from its comment to the call it makes.
            let comment = try #require(source.range(of: "// Search → Analytics handoff (Direction B)"),
                                       "\(path) lost the hand-off's comment")
            let call = try #require(source.range(of: "openSearchInAnalytics()",
                                                 range: comment.upperBound..<source.endIndex),
                                    "\(path) lost the hand-off's call")
            let condition = source[comment.upperBound..<call.lowerBound]
            #expect(condition.count < 1_200, "\(path): the comment and the call have drifted apart")
            #expect(condition.contains(mode), """
                \(path) offers Visualize in Corpus Analytics above a Meaning list. The chart reads its term with \
                the keyword parser, so it would count the documents holding every word of the question.
                """)
        }
    }

    @Test("Both surfaces run a hand-off through applyHandoff, and show the checklist's line")
    func bothSurfacesWireTheHandoffAndTheChecklistLine() throws {
        let ios = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let consume = try Self.declaration("private func consumePendingSearch() {", in: ios, path: "SearchView.swift")
        #expect(consume.contains("if vm.applyHandoff(params) {"))
        #expect(!consume.contains("vm.applyParameters(params)"))

        let mac = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        #expect(mac.components(separatedBy: "searchVM.applyHandoff(params)").count - 1 == 2,
                "the Mac window reads a hand-off in two places: when it opens and while it is open")
        #expect(!mac.contains("searchVM.applyParameters(params)"))

        for (path, source) in [("SearchView.swift", ios), ("SearchSheet.swift", mac)] {
            #expect(source.contains("@AppStorage(AppState.researchLoggingPreferenceKey) private var loggingEnabled = true"),
                    "\(path) does not observe Log Research Sessions")
            #expect(source.contains("ChecklistLoggingNotice.text(checklistMode:"),
                    "\(path) does not show the checklist's line (#1592)")
        }
    }

    // MARK: - Two defects seen in the running app while checking #1584 and #1597

    @Test("The model offer says a keyword search found nothing only where one ran")
    func modelOfferNamesTheSearchThatRan() throws {
        let afterKeywords = SemanticModelOfferCard.offerText(followsKeywordSearch: true)
        let inMeaningMode = SemanticModelOfferCard.offerText(followsKeywordSearch: false)
        #expect(afterKeywords.hasPrefix("Keyword search found nothing"))
        #expect(!inMeaningMode.contains("Keyword search"), """
            In Meaning mode no keyword search ran, and the offer says one found nothing.
            """)
        for text in [afterKeywords, inMeaningMode] {
            #expect(text.contains("229 MB"), "both state the size of the download")
            #expect(text.contains("entirely on this device"), "and where the model runs")
        }
        // The two mounts: Meaning mode's empty state says which it is; the keyword fallback takes the default.
        let meaning = try Self.source("FRUSExplorer/Search/SemanticMeaningModeViews.swift")
        #expect(meaning.contains("SemanticModelOfferCard(followsKeywordSearch: false, onModelReady: onModelReady)"))
        let fallback = try Self.source("FRUSExplorer/Search/SemanticSearchFallbackView.swift")
        #expect(fallback.contains("SemanticModelOfferCard {"))
        #expect(!fallback.contains("followsKeywordSearch: false"))
    }

    @Test("A topic card's Find documents on this topic brings Search forward on iPhone and iPad")
    func topicCardBringsSearchForward() throws {
        let path = "FRUSExplorer/Browser/SubjectIndexView.swift"
        let body = try Self.declaration("private func findDocuments() {", in: try Self.source(path), path: path)
        let iosBranch = try #require(body.range(of: "#else"), "findDocuments lost its iOS branch")
        let ios = body[iosBranch.upperBound...]
        let search = try #require(ios.range(of: "appState.openSearch(params, from: sceneID)"))
        let tab = try #require(ios.range(of: "appState.openTab(.search, from: sceneID)"), """
            The topic card hands its search to the Search tab and does not bring the tab forward, so the card \
            closes and the reader is left on Topics.
            """)
        #expect(search.lowerBound < tab.lowerBound)
    }

    @Test("The capture sheet stores the scope's own answer about the capture")
    func captureStoresTheScopesAnswer() throws {
        let sheet = try Self.source("FRUSExplorer/Search/SaveWorkingCorpusSheet.swift")
        #expect(sheet.contains("wasTruncatedAtCapture: scope.isCapturePartial,"))
        #expect(sheet.contains("sourceDescription: scope.captureProvenanceDescription,"))
    }
}
