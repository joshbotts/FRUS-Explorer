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
import Synchronization
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
        // Inside a held list the field runs the other engine within it, and its prompt says so first
        // (#1577 lane 4, `SearchLayerDirection.fieldPrompt`); everywhere else it is the mode's.
        #expect(ios.contains("prompt: vm.pinnedBase?.direction.fieldPrompt ?? vm.searchMode.fieldPrompt("),
                "SearchView must derive its prompt from the mode")
        #expect(ios.contains("search.keywords.placeholder"),
                "iOS keeps its own compact keyword wording")

        let mac = try Self.searchSurfaceSource("FRUSExplorer/App/SearchSheet.swift")
        // The same on the Mac since #1577 lane 5.
        #expect(mac.contains("searchVM.pinnedBase?.direction.fieldPrompt ?? searchVM.searchMode.fieldPrompt("),
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

/// A Meaning engine whose runs wait to be let go (#1577 lane 2), so a test can land a keyword search
/// while a Meaning run that was sent first is still out.
@MainActor
private final class GatedMeaningSearch: MeaningSearchRunning {

    /// The rows every run returns once it is released.
    private let rows: [SearchResult]
    /// The runs that are waiting.
    private var waiting: [CheckedContinuation<Void, Never>] = []
    /// How many runs have reached the engine.
    private(set) var started = 0

    init(returning count: Int) { rows = FixedMeaningSearch.returning(count).rows }

    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        started += 1
        await withCheckedContinuation { waiting.append($0) }
        return SemanticSearchBackend.Outcome(
            results: rows, beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false))
    }

    /// Lets every waiting run return.
    func release() {
        let held = waiting
        waiting = []
        held.forEach { $0.resume() }
    }
}

/// The first search statement a test's prepared-statement hook holds (#1680): whether one has reached the hook,
/// and whether its task was cancelled when the hook let it go. Shared with the `@Sendable` hook, which runs on the
/// pipeline's executor.
private final class HeldStatement: Sendable {

    private struct State {
        var entered = false
        var sawCancellation = false
        var prepared = 0
        var ranToItsEnd = 0
    }

    private let state = Mutex(State())

    /// Whether a statement has reached the hook.
    var entered: Bool { state.withLock { $0.entered } }

    /// Whether the held statement's task was cancelled when the hook let it go.
    var sawCancellation: Bool { state.withLock { $0.sawCancellation } }

    /// How many statements were prepared, across every search.
    var preparedCount: Int { state.withLock { $0.prepared } }

    /// How many statements ran to their end, across every search.
    var ranToItsEndCount: Int { state.withLock { $0.ranToItsEnd } }

    /// Counts one moment a statement reported.
    func note(_ moment: SearchStatementMoment) {
        state.withLock { state in
            switch moment {
            case .prepared: state.prepared += 1
            case .ranToItsEnd: state.ranToItsEnd += 1
            }
        }
    }

    /// `true` for the first statement only, which the hook then holds.
    func claimFirst() -> Bool {
        state.withLock { state in
            guard !state.entered else { return false }
            state.entered = true
            return true
        }
    }

    /// Records how the held statement was let go.
    func release(sawCancellation: Bool) {
        state.withLock { $0.sawCancellation = sawCancellation }
    }
}

/// A Meaning engine whose runs each wait to be let go by their own question, and return two rows headed with it
/// (#1648), so a test can send two questions and have them come back in either order.
@MainActor
private final class QuestionGatedMeaningSearch: MeaningSearchRunning {

    /// The runs that are waiting, by question.
    private var waiting: [String: CheckedContinuation<Void, Never>] = [:]
    /// The questions that have reached the engine, in order.
    private(set) var started: [String] = []

    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        started.append(query)
        await withCheckedContinuation { waiting[query] = $0 }
        return SemanticSearchBackend.Outcome(
            results: (0..<2).map { index in
                SearchResult(documentId: "d\(index)", volumeId: "vol1", header: query,
                             snippet: "", bm25Score: -Double(index), semanticScore: 0.9 - Double(index) / 100)
            },
            beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false))
    }

    /// Lets the run that asked `question` return.
    func release(_ question: String) {
        waiting.removeValue(forKey: question)?.resume()
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
///   1.1 — #1688: a full Meaning list's trail row records its count as exact
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

    // MARK: - #1577 lane 2: the route, and what asks it

    @Test("The route is written with the rows, and a switch of the picker alone does not move it")
    func theRouteIsWrittenWithTheRows() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(3)
        #expect(vm.executedRoute == .keywords, "before any search")

        vm.keywords = "containment"
        await vm.search()
        #expect(vm.executedRoute == .keywords)
        #expect(!vm.resultsAreSemantic)

        #expect(vm.switchSearchMode(to: .meaning))
        #expect(vm.executedRoute == .keywords, "the picker moved; the rows are still the keyword search's")
        await vm.search()
        #expect(vm.executedRoute == .meaning)
        #expect(vm.resultsAreSemantic)
        #expect(vm.resultSetScope.route == .meaning)

        #expect(vm.switchSearchMode(to: .keywords))
        #expect(vm.executedRoute == .meaning, "the picker moved back; the rows are still the Meaning search's")
        await vm.search()
        #expect(vm.executedRoute == .keywords)
        #expect(vm.resultSetScope.route == .keywords)
    }

    /// The facet panel is given three things: the count it heads its preamble with, whether to word that preamble for
    /// a Meaning list, and the keys to count over. Each host worked all three out from the picker, so between a switch
    /// and the new rows the panel described keyword rows as a Meaning list, or ran the keyword match of a question
    /// beside a Meaning list. They are the view model's now, and each host passes them through
    /// (`FacetMeaningModeTests`).
    @Test("What the facet panel is given follows the rows through a switch, in both directions")
    func theFacetPanelsInputsFollowTheRows() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(3)
        #expect(vm.facetMatchCount == nil, "before any search there is no count to head the panel with")

        vm.keywords = "containment"
        await vm.search()
        #expect(vm.facetMatchCount == 6)
        #expect(vm.facetDocumentKeys == nil, "a keyword match is aggregated in the index, not over keys")
        #expect(!vm.resultsAreSemantic)

        #expect(vm.switchSearchMode(to: .meaning))
        #expect(vm.searchMode == .meaning)
        #expect(vm.facetDocumentKeys == nil, """
            The picker says Meaning and the six rows are a keyword match's. Asked of the picker, the panel would \
            be handed their six keys and would word them as "the 6 closest matches".
            """)
        #expect(!vm.resultsAreSemantic)

        await vm.search()
        #expect(vm.facetMatchCount == 3)
        #expect(vm.facetDocumentKeys?.map(\.documentId) == ["m0", "m1", "m2"], "a Meaning list's facets count its own rows")
        #expect(vm.resultsAreSemantic)

        #expect(vm.switchSearchMode(to: .keywords))
        #expect(vm.searchMode == .keywords)
        #expect(vm.facetMatchCount == 3)
        #expect(vm.facetDocumentKeys?.map(\.documentId) == ["m0", "m1", "m2"], """
            The picker says Keywords and the three rows are a Meaning list. Asked of the picker, the panel would \
            be handed no keys and would aggregate the keyword match of the question beside that list.
            """)
        #expect(vm.resultsAreSemantic)

        await vm.search()
        #expect(vm.facetMatchCount == 6)
        #expect(vm.facetDocumentKeys == nil)
    }

    @Test("The readings are offered for keyword rows under the Keywords engine, and not across a switch in either direction")
    func theReadingsDoorNeedsTheEngineAndTheRows() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(3)

        vm.keywords = "containment"
        await vm.search()
        #expect(vm.offersReadings)

        // Keywords to Meaning: the field's engine is Meaning at once, so the door shuts at once.
        #expect(vm.switchSearchMode(to: .meaning))
        #expect(!vm.offersReadings, "a reading opened now would be left open over the Meaning list about to arrive")
        await vm.search()
        #expect(!vm.offersReadings)

        // Meaning to Keywords: the engine is Keywords at once, and the rows are still a Meaning list.
        #expect(vm.switchSearchMode(to: .keywords))
        #expect(vm.searchMode == .keywords)
        #expect(!vm.offersReadings, """
            The door opened on the picker alone, over a Meaning list: a concordance opened in that moment scanned \
            the Meaning list's rows for the words of the question.
            """)
        await vm.search()
        #expect(vm.offersReadings)
    }

    // MARK: - #1648: a run a later one replaced writes nothing

    /// #1577 lane 2 wrote this test while nothing dropped a superseded search: its precondition was that a Meaning run
    /// sent before a switch landed after the keyword search that followed it, and that its rows replaced the keyword
    /// rows under a picker that said Keywords. That was #1648. The run is numbered now, and one a later search replaced
    /// writes nothing when it comes back, so the keyword rows stay, with their route and their door.
    @Test("A Meaning run that comes back after the keyword search which replaced it writes nothing (#1648)")
    func aMeaningRunThatLandsLateIsDropped() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        let engine = GatedMeaningSearch(returning: 3)
        vm.semanticBackend = engine

        vm.searchMode = .meaning
        vm.keywords = "containment"
        let meaningRun = Task { await vm.search() }
        while engine.started == 0 { await Task.yield() }
        #expect(vm.isSearching, "precondition: the Meaning run is under way")

        // The reader goes back to Keywords, and that search lands while the Meaning run is still out.
        #expect(vm.switchSearchMode(to: .keywords), "a search that is under way runs again through the new engine")
        await vm.search()
        #expect(vm.results.count == 6)
        #expect(vm.executedRoute == .keywords)
        #expect(!vm.isSearching)
        let completed = vm.executedSearchVersion

        engine.release()
        _ = await meaningRun.value
        #expect(vm.searchMode == .keywords)
        #expect(vm.results.count == 6, """
            The Meaning run's 3 rows replaced the keyword search's 6 when it came back last, so the list was a \
            Meaning list under a picker that said Keywords (#1648).
            """)
        #expect(vm.executedRoute == .keywords)
        #expect(vm.offersReadings, "keyword rows under the Keywords engine: a reading can still be opened")
        #expect(vm.executedSearchVersion == completed, "nothing keyed on a completed search fires for the dropped run")
        #expect(vm.semanticDisclosure == nil, "and the Meaning strip has no run to describe")
        #expect(!vm.isSearching)
    }

    /// The same rule within one engine: two questions sent in turn, and the first one's ranking arriving last.
    @Test("Of two Meaning questions, the later one keeps the list when the earlier one comes back last (#1648)")
    func theEarlierOfTwoQuestionsComesBackLast() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        let engine = QuestionGatedMeaningSearch()
        vm.semanticBackend = engine
        vm.searchMode = .meaning

        vm.keywords = "how was containment meant to work"
        let first = Task { await vm.search() }
        while engine.started.count < 1 { await Task.yield() }
        vm.keywords = "who opposed containment"
        let second = Task { await vm.search() }
        while engine.started.count < 2 { await Task.yield() }

        engine.release("who opposed containment")
        _ = await second.value
        #expect(vm.results.map(\.header) == ["who opposed containment", "who opposed containment"])
        #expect(!vm.isSearching)

        engine.release("how was containment meant to work")
        _ = await first.value
        #expect(vm.results.map(\.header) == ["who opposed containment", "who opposed containment"], """
            The first question's ranking, arriving last, replaced the second's: the list answered a question the \
            field no longer held (#1648).
            """)
        #expect(!vm.isSearching)
    }

    /// The switch itself replaces the run: between the switch and the search it starts, a run that comes back has
    /// the other engine's rows, and they would stand under the new picker until the new rows arrived.
    @Test("A Meaning run that comes back between a switch to Keywords and the keyword search lands no rows (#1648)")
    func aSwitchReplacesTheRunUnderWay() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        let engine = GatedMeaningSearch(returning: 3)
        vm.semanticBackend = engine

        vm.searchMode = .meaning
        vm.keywords = "containment"
        let meaningRun = Task { await vm.search() }
        while engine.started == 0 { await Task.yield() }

        #expect(vm.switchSearchMode(to: .keywords))
        engine.release()
        _ = await meaningRun.value
        #expect(vm.results.isEmpty, """
            The Meaning run's rows landed after the switch to Keywords, under the Keywords picker, before any keyword \
            search had run.
            """)
        #expect(vm.executedRoute == .keywords)
        #expect(vm.isSearching, "the keyword search the switch asks for is still to come, and owns the spinner")

        await vm.search()
        #expect(vm.results.count == 6)
        #expect(!vm.isSearching)
    }

    /// A search the guard refuses is still the reader's latest request, so it replaces the run under way.
    @Test("A refused search replaces the run under way, which lands nothing and leaves nothing searching (#1648)")
    func aRefusalReplacesTheRunUnderWay() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        let engine = GatedMeaningSearch(returning: 3)
        vm.semanticBackend = engine

        vm.searchMode = .meaning
        vm.keywords = "containment"
        let meaningRun = Task { await vm.search() }
        while engine.started == 0 { await Task.yield() }

        vm.keywords = "   "
        await vm.search()
        let refusal = try #require(vm.searchError, "precondition: a question of spaces is refused")
        #expect(!vm.isSearching, "nothing is under way once the refusal has replaced the run")

        engine.release()
        _ = await meaningRun.value
        #expect(vm.results.isEmpty, "the replaced run's rows landed under the refusal")
        #expect(vm.searchError == refusal, "and the refusal is still what the screen says")
        #expect(!vm.isSearching)
    }

    /// Emptying the field clears the rows without a search (`SearchView`'s handler on the field, which this calls as
    /// the view does, for a search for words), and so does `clearAll()`, which only tests call today. Either way a run
    /// still out must not put its rows back.
    @Test("Clearing the list without a search replaces the run under way (#1648)")
    func clearingTheListReplacesTheRunUnderWay() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        for clear in ["the emptied field", "clearAll()"] {
            let engine = GatedMeaningSearch(returning: 3)
            vm.semanticBackend = engine
            vm.searchMode = .meaning
            vm.keywords = "containment"
            let meaningRun = Task { await vm.search() }
            while engine.started == 0 { await Task.yield() }

            if clear == "clearAll()" {
                vm.clearAll()
            } else {
                vm.keywords = ""
                #expect(!vm.isSearchingWithNoWords, "precondition: the run under way is a search for words")
                vm.replaceSearchesUnderWay()
                vm.results = []
                vm.hasSearched = false
            }
            #expect(!vm.isSearching, "\(clear): nothing is searching once the list is cleared")

            engine.release()
            #expect(await meaningRun.value == false, "\(clear): the run says it was replaced")
            #expect(vm.results.isEmpty, "\(clear): the run put its rows back under an empty field")
            #expect(!vm.isSearching, "\(clear)")
        }
    }

    /// The review's finding on the emptied field (#1648). A hand-off or a recalled search with no words empties the
    /// field itself (`applyParameters(_:)` sets the keywords to its own, which are none), and the search it starts can
    /// be under way before `SearchView`'s handler on the field runs. That handler asks `isSearchingWithNoWords` before
    /// it replaces or clears anything (`clearedRowsReplaceTheSearchUnderWay` reads that order), so it has to be true
    /// for such a search and false for a search for words, which the emptied field is the reader's way to abandon.
    @Test("A search with no words under way says so, and one for words does not (#1648)")
    func aSearchWithNoWordsUnderWayIsNotTheFields() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(!vm.isSearchingWithNoWords, "nothing is under way")

        // The field holds the last search's words when a subject browse is handed over.
        vm.keywords = "containment"
        await vm.search()
        var browse = SearchParameters()
        browse.subjectBucket = 2
        #expect(vm.applyHandoff(browse))
        #expect(vm.keywords.isEmpty, "precondition: the hand-off emptied the field")
        let handOff = Task { await vm.search() }
        while !vm.isSearching { await Task.yield() }
        #expect(vm.isSearchingWithNoWords, """
            The browse the hand-off started reads as a search for words, so the field it emptied would replace it, and \
            the reader would get the empty prompt in place of the documents handed over.
            """)
        #expect(await handOff.value)
        #expect(vm.results.count == 6)
        #expect(!vm.isSearchingWithNoWords, "the browse is over")

        // A question for the Meaning engine has words.
        let engine = GatedMeaningSearch(returning: 3)
        vm.semanticBackend = engine
        vm.searchMode = .meaning
        vm.keywords = "how was containment meant to work"
        let meaningRun = Task { await vm.search() }
        while engine.started == 0 { await Task.yield() }
        #expect(vm.isSearching)
        #expect(!vm.isSearchingWithNoWords, "a search for words under way is the one an emptied field abandons")
        engine.release()
        #expect(await meaningRun.value)
    }

    /// `SearchView.runSearch()` records a search, and a recalled one its stamp, only for a run that says it was not
    /// replaced. A refusal is the reader's latest request too, and says so.
    @Test("A run says whether a later one replaced it: the replaced one false, the latest and a refusal true (#1648)")
    func aRunSaysWhetherItWasReplaced() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        let engine = GatedMeaningSearch(returning: 3)
        vm.semanticBackend = engine

        vm.searchMode = .meaning
        vm.keywords = "containment"
        let meaningRun = Task { await vm.search() }
        while engine.started == 0 { await Task.yield() }
        #expect(vm.switchSearchMode(to: .keywords))
        #expect(await vm.search(), "the keyword search was not replaced")
        engine.release()
        #expect(await meaningRun.value == false, "the Meaning run was")

        vm.keywords = ""
        #expect(await vm.search(), "a refusal is the latest request, so what it wrote is what the screen shows")
        #expect(vm.searchError != nil)
    }

    /// `results` can be assigned from outside the search functions: each host empties it itself, the iPhone's view when
    /// the field is emptied and the Mac's window when the index is rebuilt. Neither can write the route.
    @Test("A list emptied from outside a search has no Meaning route left on it")
    func anEmptiedListIsNoLongerAMeaningList() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(3)
        vm.searchMode = .meaning
        vm.keywords = "how was containment meant to work"
        await vm.search()
        #expect(vm.executedRoute == .meaning)

        vm.results = []          // what `SearchView` does when the field is emptied
        #expect(vm.executedRoute == .keywords)
        #expect(!vm.resultsAreSemantic)
        #expect(vm.facetDocumentKeys == nil)
    }

    @Test("A Meaning run that finds nothing is still recorded as a Meaning run")
    func aMeaningRunThatFindsNothingKeepsItsRoute() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = FixedMeaningSearch.returning(0)
        vm.searchMode = .meaning
        vm.keywords = "how was containment meant to work"
        await vm.search()
        #expect(vm.results.isEmpty)
        #expect(vm.executedRoute == .meaning, "the route is written after the rows, so emptiness does not reset it here")
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

    /// #1688's second line. A Meaning run was recorded under the engine's list length with no match count, so a full
    /// list of 100 read back as a floor and the method appendix printed "at least 100" of it.
    @Test("A full Meaning list is recorded whole, so the method appendix prints its count")
    func aFullMeaningListIsRecordedWhole() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        let container = try ModelContainer(
            for: SearchHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let defaults = try #require(UserDefaults(suiteName: "meaning-count-\(UUID().uuidString)"))
        defaults.set(true, forKey: AppState.researchLoggingPreferenceKey)
        vm.semanticBackend = FixedMeaningSearch.returning(SemanticSearchBackend.hitLimit)
        vm.searchMode = .meaning
        vm.keywords = "how was containment meant to work"
        await vm.search()
        try #require(vm.results.count == 100 && vm.executedRoute == .meaning, "precondition: a full Meaning list")

        vm.recordSearchHistory(projectId: nil, in: context, defaults: defaults)
        let entry = try #require(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).first)
        // The record itself, which the research-data export carries field by field: the count read
        // below would come out exact from a Meaning row with no match count too, since such rows are
        // read as their list (`TrailRecordedCountTests.meaningRowIsItsList`).
        #expect(entry.matchCount == 100, "the row does not record the list's length as its match count")
        #expect(entry.recordedCount == .exact(match: 100, loaded: 100), """
            A full Meaning list is recorded as a floor: \(entry.recordedCount). The list is the whole of its ranking, \
            and the engine's 100-row length is not a ceiling the answer was cut at.
            """)
        #expect(entry.recordedCount.appendixDescription == 100.formatted())
        #expect(entry.recordedCount.basisToken == "exact")
        #expect(entry.fetchLimit == 100, "the ceiling recorded with the rows is kept, as a layer's is")
        #expect(!entry.isPartialEvidence(), "a whole ranking is not partial evidence")
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

    // MARK: - #1646: a hand-off runs inside the applied working corpus

    /// The rule the Mac's window asks (`SearchParameters.runningInside(workingCorpus:)`): the applied corpus is the only
    /// document gate, the snapshot's own gates go, and nothing else in the snapshot is touched.
    @Test("A hand-off's parameters keep the applied corpus as their only document gate (#1646)")
    func handOffGateRule() {
        let snapshot = SearchParameters(keywords: "berlin", volumeIds: ["frus1958-60v08"],
                                        documentIds: ["frus1958-60v08/d1"],
                                        excludeDocumentIds: ["frus1958-60v08/d2"])
        let inside = snapshot.runningInside(workingCorpus: ["frus1958-60v08/d3", "frus1958-60v08/d4"])
        #expect(inside.documentIds == ["frus1958-60v08/d3", "frus1958-60v08/d4"],
                "the screen's corpus is the gate, not the set the snapshot carried")
        #expect(inside.excludeDocumentIds == nil, "Focus's exclusion is the project's, and never inherited")
        #expect(inside.keywords == "berlin")
        #expect(inside.volumeIds == ["frus1958-60v08"], "the snapshot's own volume scope stays")

        let noCorpus = snapshot.runningInside(workingCorpus: nil)
        #expect(noCorpus.documentIds == nil, "with no corpus applied there is no document gate at all")
        #expect(noCorpus.excludeDocumentIds == nil)
        #expect(SearchParameters().runningInside(workingCorpus: []).documentIds == [],
                "a corpus holding nothing indexed matches nothing, never everything")
    }

    /// iPhone and iPad compose the gate from the corpus they hold each time they build parameters, so a hand-off has
    /// always run inside it there. This drives that through a real index, and holds it to the rule the Mac's window
    /// asks since #1646, so the two platforms cannot part.
    @Test("On iPhone and iPad a hand-off runs inside the applied corpus, as the Mac's rule says (#1646)")
    func aHandOffRunsInsideTheAppliedCorpus() async throws {
        let (dir, vm) = try await makeViewModel(documents: 6)
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.appliedWorkingCorpusKeys = ["vol1/d1", "vol1/d4"]
        vm.appliedWorkingCorpusName = "Two of six"
        // A History scope in force before the hand-off, which the hand-off turns off (#377 Phase 2).
        vm.projectEngagedDocumentKeys = ["vol1/d1", "vol1/d2"]
        vm.projectScope = .history

        let handOff = SearchParameters(keywords: "containment", documentIds: ["vol1/d5"],
                                       excludeDocumentIds: ["vol1/d4"])
        #expect(vm.applyHandoff(handOff))
        #expect(vm.projectScope == .off)
        #expect(vm.appliedWorkingCorpusName == "Two of six", "the corpus stays applied, and its banner with it")
        let rule = handOff.runningInside(workingCorpus: vm.appliedWorkingCorpusKeys)
        #expect(vm.searchParameters.documentIds == rule.documentIds)
        #expect(vm.searchParameters.excludeDocumentIds == rule.excludeDocumentIds)

        await vm.search()
        #expect(Set(vm.results.map(\.documentId)) == ["d1", "d4"], """
            The hand-off did not run inside the applied corpus: the rows are not the corpus's two of the six \
            documents that match.
            """)
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

    /// `text` without its comment lines, so that a scan reads code.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
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
            // Followed on iPhone and iPad by what a layer's sentences owe (#1577 lane 4).
            #expect(scope.contains("route: executedRoute)") || scope.contains("route: executedRoute,"),
                    "\(path): the scope must carry the route that produced the rows, not the picker (#1597)")
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

    /// "Written with the rows" is a rule about statements: the route is assigned beside each assignment of `results`,
    /// in the same branch, so no path can show rows under another route. Counted in each file, so that a new
    /// assignment of rows without one fails here. The one exception rewrites rows in place and cannot change their
    /// route: the tag refresh of #1576 lane 5. iPhone and iPad have three more since #1577 lane 4: a held list's rows
    /// put back with their own route, words found in a Meaning list, and a list ranked by a question (whose rows are
    /// `ranking.results`, never `outcome.results`, so that only a Meaning run's rows are a Meaning list). The Mac has the
    /// same three since lane 5, which gave its window held lists. Each has one more since lane 6: a list cut at its
    /// ceiling ranked whole (`whole.outcome.results`, with the ranking's route).
    @Test("Each view model writes the route beside every statement that assigns the rows")
    func theRouteIsAssignedBesideEveryAssignmentOfRows() throws {
        for (path, expected) in [("FRUSExplorer/Search/SearchViewModel.swift", 12),
                                 ("FRUSExplorer/App/MacSearchViewModel.swift", 13)] {
            let lines = try Self.source(path).components(separatedBy: "\n")
            var assignments = 0
            var meaning = 0
            for (index, line) in lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard code.hasPrefix("results = "), !code.hasPrefix("results = results.map") else { continue }
                assignments += 1
                let window = lines[index..<min(lines.count, index + 9)].map { $0.trimmingCharacters(in: .whitespaces) }
                let route = window.first { $0.hasPrefix("executedRoute = ") }
                #expect(route != nil, "\(path):\(index + 1): rows are assigned with no route beside them")
                // A Meaning run's rows are the only ones that are a Meaning list, and they are never anything else.
                let isMeaningRows = code == "results = outcome.results"
                #expect((route == "executedRoute = .meaning") == isMeaningRows,
                        "\(path):\(index + 1): `\(code)` is given `\(route ?? "no route")`")
                if isMeaningRows { meaning += 1 }
            }
            #expect(assignments == expected, "\(path) assigns its rows in \(assignments) statements; this test read \(expected)")
            #expect(meaning == 1, "\(path) has \(meaning) statements that assign a Meaning run's rows")
            let writes = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("executedRoute = ") }.count
            #expect(writes == expected, "\(path) writes the route \(writes) times for \(expected) assignments of rows")
        }
    }

    /// `MacSearchViewModel` is compiled for the Mac alone, so what the driven tests above hold for the iPhone's view
    /// model is held for the Mac's by its being the same text. One member differs by design, the facet panel's count:
    /// the Mac takes a whole-match count beside every search, and the iPhone shows none before a search has run.
    @Test("Both view models hold the route, the door and the facet panel's inputs in the same words")
    func bothViewModelsHoldTheRouteAndWhatAsksItAlike() throws {
        let keys = """
                var facetDocumentKeys: [(volumeId: String, documentId: String)]? {
                    executedRoute.facetsDescribeTheList
                        ? results.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
                        : nil
                }

            """
        let counts = [
            "FRUSExplorer/Search/SearchViewModel.swift": """
                    var facetMatchCount: Int? {
                        guard hasSearched else { return nil }
                        return executedRoute.facetsDescribeTheList ? results.count : totalMatchCountForFacets
                    }

                """,
            "FRUSExplorer/App/MacSearchViewModel.swift": """
                    var facetMatchCount: Int? {
                        executedRoute.facetsDescribeTheList ? results.count : totalMatchCount
                    }

                """,
        ]
        for (path, count) in counts.sorted(by: { $0.key < $1.key }) {
            let source = try Self.source(path)
            #expect(source.contains("    private(set) var executedRoute: ExecutedSearchRoute = .keywords\n"),
                    "\(path): the route is not a stored property only the view model writes")
            #expect(source.contains("    var resultsAreSemantic: Bool { executedRoute == .meaning }\n"),
                    "\(path): the flag the bulk commands and the facet panel read is no longer a read of the route")
            #expect(source.contains(
                "    var offersReadings: Bool { searchMode == .keywords && executedRoute.offersReadings }\n"),
                    "\(path): the readings' door no longer asks both the field's engine and the rows' route")
            #expect(source.contains(keys), "\(path): the facet panel's keys are not chosen by the rows' route in these words")
            #expect(source.contains(count), "\(path): the facet panel's count is not chosen by the rows' route in these words")
            // The rows' own observer: a list emptied from outside a search function loses a Meaning route.
            let rows = try Self.declaration("    var results: [SearchResult] = [] {", in: source, path: path)
            #expect(rows.contains("            if results.isEmpty { executedRoute = .keywords }\n"),
                    "\(path): an emptied list keeps the route of the rows it held")
        }
    }

    /// The door's line, read where the control is and with comments set aside: the same words in a comment, or on
    /// another control of the file, would not dim the readings.
    @Test("Both hosts dim the readings' control by the view model's rule, on the control itself")
    func bothHostsAskTheViewModelForTheReadingsDoor() throws {
        for (path, header, control, door) in [
            ("FRUSExplorer/Search/SearchView.swift", "    private var examineMenu: some View {",
             "selection: readingSelection) {", ".disabled(vm.results.isEmpty || !vm.offersReadings)"),
            ("FRUSExplorer/App/SearchSheet.swift", "    private var searchToolbar: some ToolbarContent {",
             "Picker(selection: readingSelection) {", ".disabled(searchVM.results.isEmpty || !searchVM.offersReadings)"),
        ] {
            let declaration = Self.code(try Self.declaration(header, in: try Self.source(path), path: path))
            let picker = try #require(declaration.range(of: control), "\(path): `\(header)` no longer holds the reading picker")
            let after = declaration[picker.upperBound...]
            #expect(after.components(separatedBy: door).count - 1 == 1,
                    "\(path): the reading picker is not followed by `\(door)` in code")
            #expect(!declaration.contains("searchMode"), "\(path): `\(header)` asks the picker about the rows")
        }
    }

    /// The other half of the door: a reading that is open when it shuts. The picker's setter closes the readings on a
    /// switch; this handler is the one place that keeps a reading from outliving its door, whatever shuts it. Until
    /// #1648 a Meaning run that came back after the keyword search which replaced it was such a way, and it no longer
    /// lands (`aMeaningRunThatLandsLateIsDropped`).
    @Test("Both hosts send an open reading back to the list when its door shuts")
    func bothHostsCloseAReadingWhenItsDoorShuts() throws {
        for (path, owner) in [("FRUSExplorer/Search/SearchView.swift", "vm"),
                              ("FRUSExplorer/App/SearchSheet.swift", "searchVM")] {
            let code = Self.code(try Self.source(path)).filter { !$0.isWhitespace }
            let handler = ".onChange(of:\(owner).offersReadings){_,offeredin"
                + "if!offered{readingSelection.wrappedValue=.list}}"
            #expect(code.components(separatedBy: handler).count - 1 == 1,
                    "\(path) does not close an open reading when the view model stops offering readings")
        }
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

    /// #1646, the Mac's half, which this target cannot run: `applyParameters(_:)` builds the window's parameters by the
    /// rule `handOffGateRule` holds, and brings the filter view model to them. Until #1646 it set `documentIds` to nil,
    /// so the banner named a corpus the search was not inside, and it left the filter view model on the search before,
    /// so the banner's ✕ (`applyAdvancedFilters()`) re-applied that search's filters: after a person's Find all
    /// mentions it dropped the person and emptied the list.
    @Test("The Mac's window runs a hand-off inside its corpus and brings its filters to it (#1646)")
    func macHandOffKeepsTheCorpus() throws {
        let path = "FRUSExplorer/App/MacSearchViewModel.swift"
        let source = try Self.source(path)
        let apply = Self.code(try Self.declaration("func applyParameters(_ params: SearchParameters) {",
                                                   in: source, path: path))
        #expect(apply.contains("parameters = params.runningInside(workingCorpus: filterVM?.appliedWorkingCorpusKeys)"),
                "the window takes a hand-off's parameters whole, with the snapshot's gates and without its corpus")
        #expect(apply.contains("if let filterVM { mirrorParameters(into: filterVM) }"),
                "the filter view model keeps the search before the hand-off")
        #expect(!apply.contains("parameters.documentIds = nil"), "the corpus is dropped with the project's gates")
        let assigned = try #require(apply.range(of: "parameters = params.runningInside("))
        let mirrored = try #require(apply.range(of: "mirrorParameters(into: filterVM)"))
        #expect(assigned.upperBound < mirrored.lowerBound,
                "the filter view model is given the parameters from before the hand-off: the mirror runs first")
        let sync = Self.code(try Self.declaration("func syncToFilterVM(", in: source, path: path))
        #expect(sync.contains("mirrorParameters(into: filterVM)"),
                "opening the popover and taking a hand-off copy the parameters by different routines")
    }

    /// #1646, found in review: the working corpus banner's ✕ re-applied the filter view model
    /// (`applyAdvancedFilters()`), and a facet's narrowing writes the window's parameters alone, so the ✕ undid a
    /// person or a year chosen in Facets. It derives the document gate alone now (`leaveWorkingCorpus()`).
    @Test("The Mac's corpus banner leaves the corpus and nothing else (#1646)")
    func macLeavingTheCorpusKeepsTheSearch() throws {
        let window = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        let banner = Self.code(try Self.declaration("private var workingCorpusBanner: some View {", in: window,
                                                    path: "SearchSheet.swift"))
        #expect(banner.contains("searchVM.leaveWorkingCorpus()"), "the banner's ✕ does not leave the corpus")
        #expect(!banner.contains("applyAdvancedFilters()"),
                "the banner's ✕ re-applies the filter view model, which undoes a facet's narrowing")

        let path = "FRUSExplorer/App/MacSearchViewModel.swift"
        let leave = Self.code(try Self.declaration("func leaveWorkingCorpus() {", in: try Self.source(path), path: path))
        #expect(leave.contains("filterVM?.clearWorkingCorpus()"))
        let assignments = leave.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("parameters.") }
        #expect(assignments.count == 2 && assignments.allSatisfy {
            $0.hasPrefix("parameters.documentIds ") || $0.hasPrefix("parameters.excludeDocumentIds ")
        }, "leaving the corpus writes more of the parameters than its document gate: \(assignments)")
        #expect(!leave.contains("applyAdvancedFilters") && !leave.contains("applyProjectScope"),
                "leaving the corpus derives more than its document gate")
        #expect(leave.contains("parametersVersion += 1"), "leaving the corpus does not run the search again")
    }

    /// #1648: both view models number a run as it starts, and write the screen's state only once its last wait is over
    /// and they have asked whether a later run replaced it. Read statement by statement, since the Mac's half cannot
    /// run here (the iPhone's is driven above). A write of the rows, the route, the total, the expression, the error,
    /// the version or the tag-count scope fails here when it follows an `await`, or opens a `catch`, with no check
    /// between; and so does an `await` that follows such a write, since a run replaced at that wait would leave its rows
    /// under the last search's total (the review's finding).
    @Test("Both view models write nothing until their last wait is over and they have asked whether the run was replaced (#1648)")
    func everyWriteAfterAWaitAsksFirst() throws {
        let check = "guard searchRuns.isLatest(run) else { return false }"
        let writes = ["results = ", "executedRoute = ", "totalMatchCount = ", "lastRenderedExpression = ",
                      "searchError = ", "executedSearchVersion &+= 1", "userTagCountScope = ", "lastFetchLimit = ",
                      "beyondLibraryHits = ", "semanticDisclosure = "]
        for (path, headers) in [
            ("FRUSExplorer/App/MacSearchViewModel.swift",
             ["func performSearch(service: SearchService?) async -> Bool {",
              "private func performMeaningSearch(run: Int) async -> Bool {",
              // The ranking of a held list, `performMeaningSearch(run:)`'s second path (#1577 lane 5).
              "private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning)"]),
            ("FRUSExplorer/Search/SearchViewModel.swift",
             ["func search() async -> Bool {", "private func searchMeaning(run: Int) async -> Bool {",
              // The ranking of a held list, `searchMeaning(run:)`'s second path (#1577 lane 4).
              "private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning)"]),
        ] {
            let source = try Self.source(path)
            for header in headers {
                let lines = Self.code(try Self.declaration(header, in: source, path: path))
                    .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                var checkedSinceWait = true
                var wroteAfterAWait = false
                var waits = 0
                var checks = 0
                for line in lines {
                    // A wait the run comes back from. A `return await` hands the run to the other engine's path,
                    // which is read on its own.
                    if line.contains("await "), !line.hasPrefix("return ") {
                        #expect(!wroteAfterAWait, """
                            \(path), `\(header)`: `\(line)` waits after the run has written what it found, so a run \
                            replaced at this wait leaves a half-written result set (#1648).
                            """)
                        checkedSinceWait = false
                        waits += 1
                    }
                    // A catch is entered from the wait that threw.
                    if line.hasPrefix("} catch") { checkedSinceWait = false }
                    if line == check {
                        checkedSinceWait = true
                        checks += 1
                    }
                    if writes.contains(where: { line.hasPrefix($0) }) {
                        #expect(checkedSinceWait, """
                            \(path), `\(header)`: `\(line)` writes after a wait with no check that the run is still the \
                            latest, so a run a later one replaced can still write it (#1648).
                            """)
                        if waits > 0 { wroteAfterAWait = true }
                    }
                }
                #expect(waits >= 1 && checks >= 1,
                        "fixture guard, \(path) `\(header)`: \(waits) waits and \(checks) checks were read")
                // The Meaning paths are handed their number; the two entry points take it before anything else.
                // iPhone and iPad take it through `startRun()`, which also cancels the keyword fetch under way so
                // that the kit stops its statements (#1680); the Mac's window cancels its own search task.
                if !header.contains("(run: Int") {
                    let opening = path.hasSuffix("/SearchViewModel.swift")
                        ? "let run = startRun()" : "let run = searchRuns.startRun()"
                    #expect(lines.dropFirst().first { !$0.isEmpty } == opening,
                            "\(path) `\(header)` does not open by numbering its run")
                }
            }
        }
    }

    /// The hosts' half of #1648. Each records a search, and the Mac starts its facets over, only for a run that was not
    /// replaced; the Mac's search task is its only search, so a recalled search and a moved person filter run none of
    /// their own beside it; and a recalled search is stamped with its own count on both, which `SavedSearchFreshness`'s
    /// tests drive (#1646).
    @Test("Both hosts act only on a run that was not replaced, and the Mac runs no second search (#1648)")
    func hostsActOnlyOnTheLatestRun() throws {
        let ios = Self.code(try Self.source("FRUSExplorer/Search/SearchView.swift"))
        let mac = Self.code(try Self.source("FRUSExplorer/App/SearchSheet.swift"))
        #expect(ios.filter { !$0.isWhitespace }.contains("guardawaitvm.search()else{return}vm.recordSearchHistory("),
                "SearchView records a search a later one replaced")
        #expect(mac.filter { !$0.isWhitespace }.contains(
            "guardawaitsearchVM.performSearch(service:appState.searchService)else{return}searchVM.recordSearchHistory("),
                "the Mac window records a search a later one replaced")
        #expect(mac.components(separatedBy: "searchVM.performSearch(").count - 1 == 1, """
            The Mac window runs a search outside its search task. A recalled search and a moved person filter each \
            change the trigger, so a run of their own raced the task's.
            """)
        for (path, text) in [("SearchView.swift", ios), ("SearchSheet.swift", mac)] {
            #expect(text.contains("await SavedSearchFreshnessEvaluator.recordRun("),
                    "\(path) does not stamp a recalled search with its own count")
            #expect(!text.contains("saved.recordRun(matchCount:"),
                    "\(path) stamps a recalled search with the total on screen")
        }
    }

    // MARK: - Two defects seen in the running app while checking #1584 and #1597

    /// The method appendix prints a Meaning search's rendered expression as the record of what ran
    /// (B4). Each view model used to spell the 300m's id itself, so the move to EmbeddingGemma 2
    /// would have recorded the old model beside the new model's results.
    @Test("A Meaning search records the bundled generation's model, from one place")
    @MainActor
    func meaningExpressionNamesTheBundledModel() async throws {
        await BundledSemanticVectors.prepare()
        let model = try #require(BundledSemanticVectors.provenance?.model)
        #expect(model == "embeddinggemma-2-Q8_0")
        #expect(SemanticSearchBackend.renderedExpression
            == "route=semantic; model=embeddinggemma-2-Q8_0; top=100")
        for path in ["FRUSExplorer/Search/SearchViewModel.swift",
                     "FRUSExplorer/App/MacSearchViewModel.swift"] {
            let source = try Self.source(path)
            #expect(source.contains(
                "lastRenderedExpression = SemanticSearchBackend.renderedExpression"), "\(path)")
            #expect(!source.contains("embeddinggemma"), "\(path) names a model of its own")
        }
    }

    @Test("The model offer says a keyword search found nothing only where one ran")
    func modelOfferNamesTheSearchThatRan() throws {
        let afterKeywords = SemanticModelOfferCard.offerText(followsKeywordSearch: true)
        let inMeaningMode = SemanticModelOfferCard.offerText(followsKeywordSearch: false)
        #expect(afterKeywords.hasPrefix("Keyword search found nothing"))
        #expect(!inMeaningMode.contains("Keyword search"), """
            In Meaning mode no keyword search ran, and the offer says one found nothing.
            """)
        // The size the copy states is the pinned file's, in decimal megabytes: "310 MB" for
        // EmbeddingGemma 2 (B4), where it said "229 MB" for the 300m. Derived, so the next model's
        // pin fails here until the sentence says its size.
        let size = "\(Int((Double(SemanticModelStore.publishedBytes) / 1_000_000).rounded())) MB"
        #expect(size == "310 MB")
        for text in [afterKeywords, inMeaningMode] {
            #expect(text.contains(size), "both state the size of the download")
            #expect(text.contains("entirely on this device"), "and where the model runs")
        }
        // Settings' row and footer state the same size.
        let settings = try Self.source("FRUSExplorer/Settings/SemanticModelSection.swift")
        #expect(settings.contains("One \(size) download."))
        #expect(settings.contains("an optional \(size) download"))
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

/// #1680: a search that replaces one still under way stops it, on iPhone and iPad, where the view model cancels the run
/// it replaces. The Mac's window cancels its own search task, and its half is the kit's (`SearchCancellationTests`).
///
/// Version history:
///   1.0 — #1680: initial implementation
@Suite("A search that replaces one under way stops it (#1680)")
@MainActor
struct ReplacedSearchStopTests {

    /// A view model over one volume of 400 documents, every one holding "containment" and "doctrine", so that each
    /// search matches them all and its statements run long enough for the progress handler to be called.
    private func makeViewModel() async throws -> (dir: URL, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSReplaced-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<400 {
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
        return (dir, SearchViewModel(searchService: SearchService(fts5Store: fts5, pipeline: pipeline)))
    }

    /// #1680: on iPhone and iPad the run that replaces another cancels its keyword fetch, and the kit stops the
    /// replaced run's statements, so the search that replaced it does not wait for them.
    ///
    /// The pipeline's test hook holds the first run's first statement, once prepared, until its task is cancelled, with
    /// a bound so that a run nothing cancels fails here rather than hanging. The second search is sent while it is
    /// held: its start cancels the first run's fetch, the hook sees the cancellation and lets the statement go, and the
    /// second search lands with no error. The hook's moments say what the kit did: three statements are prepared (the
    /// held one and the second search's two; the first run's other one is refused before it is prepared) and only the
    /// second search's two run to their end, so the held one was stopped. Before #1680 nothing cancelled the first
    /// run, and its statement ran to its end before the second could start.
    @Test("A search that replaces one under way cancels it, and the replaced search's statement stops (#1680)")
    func aReplacingSearchStopsTheOneUnderWay() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        let held = HeldStatement()
        await vm.searchServiceForTesting.pipeline.setSearchStatementTestHook { moment in
            held.note(moment)
            // Only the first statement is held, once prepared; every later one runs.
            guard moment == .prepared, held.claimFirst() else { return }
            let deadline = ContinuousClock.now + .seconds(10)
            while !Task.isCancelled, ContinuousClock.now < deadline { usleep(1_000) }
            held.release(sawCancellation: Task.isCancelled)
        }

        vm.keywords = "containment"
        let first = Task { await vm.search() }
        for _ in 0..<1_000 where !held.entered { try await Task.sleep(for: .milliseconds(5)) }
        #expect(held.entered, "fixture guard: the first run's statement never reached the hook")
        #expect(vm.isSearching, "precondition: the first run is under way")

        vm.keywords = "doctrine"
        let secondLanded = await vm.search()
        let firstLanded = await first.value

        #expect(held.sawCancellation, """
            The replacing search did not cancel the run under way: its statement was let go by the hook's deadline, \
            not by its task's cancellation (#1680).
            """)
        #expect(held.preparedCount == 3, "statements prepared: \(held.preparedCount)")
        #expect(held.ranToItsEndCount == 2, """
            \(held.ranToItsEndCount) statements ran to their end: the replaced run's held statement was not stopped \
            by the kit after its task was cancelled (#1680).
            """)
        #expect(!firstLanded, "the replaced run reported its rows as the screen's")
        #expect(secondLanded)
        #expect(vm.results.count == 400)
        #expect(vm.totalMatchCount == 400)
        #expect(vm.searchError == nil, "the replaced run's cancellation reached the screen as an error")
        #expect(!vm.isSearching)
    }
}
