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

// MARK: - FacetSelectionTests

/// Multi-select and exclude on the facet panel (#775).
///
/// ## The acceptance criterion is one test
/// The issue asks that *include 1951 and 1953* and *include 1950–1953 then exclude 1950 and 1952*
/// reach the same results. Everything else here supports ``equivalentSelectionsResolveIdentically``,
/// which is the requirement stated as an assertion.
///
/// ## Why the resolution is worth testing at all
/// Because it is what keeps negation out of SQL. `substr(NULL, 1, 4) NOT IN ('1950')` is NULL,
/// SQLite drops the row, and a `NOT IN` spelling would silently delete every undated document
/// while the panel went on reporting them. Resolving over a finite domain in Swift makes that
/// failure unreachable rather than guarded.
///
/// Version history:
///   1.0 — Session 2026-08-10: #775
@Suite("Facet selection (#775)")
struct FacetSelectionTests {

    /// The years a search over 1950–1953 would show.
    private let universe = ["1950", "1951", "1952", "1953"]

    // MARK: - The acceptance criterion

    @Test("Include-two and include-four-minus-two resolve to the same set")
    func equivalentSelectionsResolveIdentically() {
        var picked = FacetSelection()
        picked.set("1951", to: .included)
        picked.set("1953", to: .included)

        var subtracted = FacetSelection()
        for year in universe { subtracted.set(year, to: .included) }
        subtracted.set("1950", to: .excluded)
        subtracted.set("1952", to: .excluded)

        #expect(picked.resolved(from: universe) == ["1951", "1953"])
        #expect(subtracted.resolved(from: universe) == ["1951", "1953"], """
            #775's whole request: the two routes must arrive at the same result list. They are the \
            same value after resolution, so they cannot diverge downstream — which is why the \
            resolution happens once, here, and not twice in two query paths.
            """)
        #expect(picked.resolved(from: universe) == subtracted.resolved(from: universe))
    }

    // MARK: - The three states

    @Test("A row cycles neutral → included → excluded → neutral")
    func rowCycles() {
        var selection = FacetSelection()
        #expect(selection.state(of: "1951") == .neutral)
        selection.cycle("1951")
        #expect(selection.state(of: "1951") == .included)
        selection.cycle("1951")
        #expect(selection.state(of: "1951") == .excluded)
        selection.cycle("1951")
        #expect(selection.state(of: "1951") == .neutral)
    }

    @Test("A key is never both included and excluded")
    func statesAreExclusive() {
        var selection = FacetSelection()
        selection.set("1951", to: .included)
        selection.set("1951", to: .excluded)
        #expect(selection.includedKeys.isEmpty, """
            A key in both sets is a state no resolution rule can interpret and no row can draw. \
            `set` removes before it inserts, which is what makes that unreachable.
            """)
        #expect(selection.excludedKeys == ["1951"])
    }

    // MARK: - Resolution's edges, each of which is a different answer

    @Test("An empty selection is no filter at all")
    func emptySelectionIsNil() {
        #expect(FacetSelection().resolved(from: universe) == nil, """
            `nil` means "do not constrain this dimension". It must not be an empty array, which \
            means something else entirely — see below.
            """)
    }

    @Test("Excluding everything included is a real, empty answer")
    func excludingEverythingIsEmptyNotNil() {
        var selection = FacetSelection()
        selection.set("1951", to: .included)
        selection.set("1951", to: .excluded)
        // The cycle above lands on excluded-only, which over this universe leaves three years.
        #expect(selection.resolved(from: universe) == ["1950", "1952", "1953"])

        var all = FacetSelection()
        for year in universe { all.set(year, to: .excluded) }
        #expect(all.resolved(from: universe) == [], """
            Excluding every year the search matched is a real request with an empty answer. \
            Returning nil here would widen the search to the whole corpus under a chip promising \
            the opposite — the inversion `CustomVolumeScope` exists to prevent.
            """)
    }

    @Test("Exclude-only means everything else in this result set")
    func excludeOnlyStartsFromTheUniverse() {
        var selection = FacetSelection()
        selection.set("1950", to: .excluded)
        #expect(selection.resolved(from: universe) == ["1951", "1952", "1953"], """
            The universe is the section's own buckets, so this is "everything in this match except \
            1950" — what the user can see and predict. Not "everything in the corpus except 1950", \
            which would silently re-scope the moment the keywords changed.
            """)
    }

    @Test("Resolution keeps the universe's order and drops keys it does not contain")
    func resolutionIsBoundedByTheUniverse() {
        var selection = FacetSelection()
        selection.set("1953", to: .included)
        selection.set("1951", to: .included)
        selection.set("1899", to: .included)
        #expect(selection.resolved(from: universe) == ["1951", "1953"], """
            A key the section does not list cannot filter to anything, and passing it to SQL would \
            put a year in the predicate that the panel never showed.
            """)
    }

    // MARK: - The applier

    @Test("Years takes the resolved set verbatim, empty array included")
    func applierWritesYears() {
        var parameters = SearchParameters()
        FacetSelectionApplier.apply(.years, keys: ["1953", "1951"], to: &parameters)
        #expect(parameters.yearKeys == ["1951", "1953"], "sorted, so a signature is stable")

        FacetSelectionApplier.apply(.years, keys: [], to: &parameters)
        #expect(parameters.yearKeys == [], """
            An empty array must survive to the query, where `yearKeys == []` matches nothing. \
            Coercing it to nil here is the silent-widening bug.
            """)

        FacetSelectionApplier.apply(.years, keys: nil, to: &parameters)
        #expect(parameters.yearKeys == nil)
    }

    @Test("Volumes takes the other empty-set convention, deliberately")
    func applierWritesVolumes() {
        var parameters = SearchParameters()
        FacetSelectionApplier.apply(.volumes, keys: ["frus1952-54v01", "frus1950v01"], to: &parameters)
        #expect(parameters.volumeIds == ["frus1950v01", "frus1952-54v01"])

        FacetSelectionApplier.apply(.volumes, keys: [], to: &parameters)
        #expect(parameters.volumeIds == nil, """
            `volumeIds`' own SQL contract is that empty means no filter — it is reached from \
            scopes that legitimately resolve to nothing. The two fields differ here on purpose \
            and each is documented against its own predicate.
            """)
    }

    @Test("A section that does not stage is left alone")
    func applierIgnoresUnstagedSections() {
        var parameters = SearchParameters(personRollupId: 42)
        FacetSelectionApplier.apply(.people, keys: ["7"], to: &parameters)
        #expect(parameters.personRollupId == 42, """
            People is not staged this wave. Writing something here would half-implement a \
            multi-person filter the model cannot express — `personRollupId` is one rollup and \
            `PersonRollupAnchor` is singular.
            """)
    }
}

// MARK: - YearSetFilterTests

/// The `yearKeys` predicate, against a real index (#775).
///
/// These run the actual SQL, because the whole point of the field is that it does something
/// different from `dateRange` — and the difference is a shipped defect, not a preference. On the
/// owner's index the Years facet's 1948 row reads **7,392** documents and the `dateRange` a 1948
/// tap applied returned **7,892**, because 7,562 dated rows span a year boundary. A facet row that
/// does not deliver its own count is a wrong answer wearing a number.
///
/// Version history:
///   1.0 — Session 2026-08-10: #775
@Suite("Year-set filter (#775)")
struct YearSetFilterTests {

    /// Two documents: one wholly inside 1951, one running from December 1950 into January 1951.
    private func volumeXML() -> String {
        """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
          <div type="document" xml:id="d1" n="1"
               frus:doc-dateTime-min="1951-06-01" frus:doc-dateTime-max="1951-06-01">
            <head>Wholly within 1951</head>
            <p>Negotiations continued.</p>
          </div>
          <div type="document" xml:id="d2" n="2"
               frus:doc-dateTime-min="1950-12-20" frus:doc-dateTime-max="1951-01-10">
            <head>Spanning the year boundary</head>
            <p>Negotiations continued.</p>
          </div>
          <div type="document" xml:id="d3" n="3"
               frus:doc-dateTime-min="1953-03-01" frus:doc-dateTime-max="1953-03-01">
            <head>Wholly within 1953</head>
            <p>Negotiations continued.</p>
          </div>
        </body></text></TEI>
        """
    }

    private func fixture() async throws -> (dir: URL, service: SearchService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSYearSet-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try Data(volumeXML().utf8).write(to: volDir.appendingPathComponent("vol1.xml"))
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline))
    }

    @Test("A year set matches on the start year, like the facet's own buckets")
    func matchesOnStartYear() async throws {
        let (dir, service) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        var params = SearchParameters(keywords: "negotiations")
        params.yearKeys = ["1951"]
        let ids = try await service.search(parameters: params).map(\.documentId).sorted()
        #expect(ids == ["d1"], """
            d2 runs from December 1950 into January 1951, so interval overlap would return it — \
            and the Years facet, which buckets on the start year, counts it under 1950. Returning \
            it here would reproduce the shipped 7,392-vs-7,892 mismatch in miniature. Got: \(ids)
            """)
    }

    @Test("The two routes #775 names return the same documents")
    func equivalentRoutesAgree() async throws {
        let (dir, service) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let universe = ["1950", "1951", "1952", "1953"]
        var picked = FacetSelection()
        picked.set("1951", to: .included)
        picked.set("1953", to: .included)

        var subtracted = FacetSelection()
        for year in universe { subtracted.set(year, to: .included) }
        subtracted.set("1950", to: .excluded)
        subtracted.set("1952", to: .excluded)

        var a = SearchParameters(keywords: "negotiations")
        FacetSelectionApplier.apply(.years, keys: picked.resolved(from: universe), to: &a)
        var b = SearchParameters(keywords: "negotiations")
        FacetSelectionApplier.apply(.years, keys: subtracted.resolved(from: universe), to: &b)

        let idsA = try await service.search(parameters: a).map(\.documentId).sorted()
        let idsB = try await service.search(parameters: b).map(\.documentId).sorted()
        #expect(idsA == ["d1", "d3"])
        #expect(idsA == idsB, "#775's acceptance criterion, end to end through the real query")
    }

    @Test("An empty year set matches nothing rather than everything")
    func emptySetMatchesNothing() async throws {
        let (dir, service) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        var params = SearchParameters(keywords: "negotiations")
        params.yearKeys = []
        let ids = try await service.search(parameters: params).map(\.documentId)
        #expect(ids.isEmpty, """
            An empty set is "the user excluded everything they included". Treating it as absent \
            would return the whole corpus under a filter promising the opposite.
            """)
    }

    @Test("A year set and a date range both apply")
    func yearSetAndDateRangeCompose() async throws {
        let (dir, service) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        var params = SearchParameters(keywords: "negotiations")
        params.yearKeys = ["1951", "1953"]
        params.dateRange = DateRange(earliest: "1953-01-01", latest: "1953-12-31")
        let ids = try await service.search(parameters: params).map(\.documentId).sorted()
        #expect(ids == ["d3"], """
            The two are different questions — start-year containment and interval overlap — and \
            they AND. If either cleared the other, this would return d1 as well.
            """)
    }

    @Test("The count sees the year set, so it cannot promise rows the list does not show")
    func countSeesTheYearSet() async throws {
        let (dir, service) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        var params = SearchParameters(keywords: "negotiations")
        params.yearKeys = ["1951"]
        let count = try await service.searchCount(parameters: params)
        let results = try await service.search(parameters: params)
        #expect(count == 1)
        #expect(count == results.count, """
            The count and the result list must share the predicate. A count that ignored the year \
            set would be a number the researcher is about to publish and the app cannot show.
            """)
    }
}

// MARK: - YearKeysPersistenceTests

/// That adding `yearKeys` did not break the archive every saved search rides in (#775).
///
/// `SearchParameters` is `Codable` and a `SavedSearch` stores the encoded blob, so a new field
/// persists for free — **if** it is declared correctly. Declared non-Optional with a default, the
/// synthesised `Decodable` throws `keyNotFound` on every blob written before today, the decode is
/// wrapped in `try?`, and the failure is silent: the saved search falls back to its scalar columns
/// and quietly loses the fields that only live in the blob. That is the field-drop trap this repo
/// has already paid for once, facing the other way.
///
/// Version history:
///   1.0 — Session 2026-08-10: #775
@Suite("Year set persistence (#775)")
struct YearKeysPersistenceTests {

    @Test("A blob written before yearKeys existed still decodes, with its other filters intact")
    func preChangeBlobStillDecodes() throws {
        // Captured from the encoder before this change. Deliberately a literal rather than a
        // round-trip: a round-trip through today's encoder would contain the new key and prove
        // nothing about yesterday's data.
        let json = """
        {"booleanMode":"and","documentTypeFilter":"all","excludedTerms":[],
         "includeDocumentText":true,"includeFrontMatter":true,"includeNotes":true,
         "includeSummaries":true,"keywords":"berlin","personRollupId":42,
         "subjectTagIds":[],"userTagIds":["A1B2"],"volumeIds":["frus1952-54v01"]}
        """
        let decoded = try JSONDecoder().decode(SearchParameters.self, from: Data(json.utf8))
        #expect(decoded.yearKeys == nil, "absent means no year filter, not a decode failure")
        #expect(decoded.volumeIds == ["frus1952-54v01"], """
            The volume scope proves the BLOB path was taken. If `yearKeys` were non-Optional the \
            decode would throw, the caller's `try?` would swallow it, and a saved search would \
            restore from its scalar columns with its volume scope silently gone.
            """)
        #expect(decoded.personRollupId == 42)
        #expect(decoded.userTagIds == ["A1B2"])
        #expect(decoded.keywords == "berlin")
    }

    @Test("A year set round-trips through the archive")
    func yearSetRoundTrips() throws {
        var parameters = SearchParameters(keywords: "berlin")
        parameters.yearKeys = ["1951", "1953"]
        let data = try JSONEncoder().encode(parameters)
        let decoded = try JSONDecoder().decode(SearchParameters.self, from: data)
        #expect(decoded.yearKeys == ["1951", "1953"])
    }

    @Test("An empty year set survives the archive as empty, not as absent")
    func emptyYearSetRoundTrips() throws {
        var parameters = SearchParameters(keywords: "berlin")
        parameters.yearKeys = []
        let data = try JSONEncoder().encode(parameters)
        let decoded = try JSONDecoder().decode(SearchParameters.self, from: data)
        #expect(decoded.yearKeys == [], """
            The two are different searches — one filters to nothing, the other does not filter — \
            and a restore that confused them would silently return the whole corpus.
            """)
    }

    @Test("Two searches differing only in their years sign differently")
    func signatureSeesTheYearSet() {
        var a = SearchParameters(keywords: "berlin")
        a.yearKeys = ["1951", "1953"]
        var b = SearchParameters(keywords: "berlin")
        b.yearKeys = ["1949", "1961"]
        var none = SearchParameters(keywords: "berlin")
        none.yearKeys = nil
        var empty = SearchParameters(keywords: "berlin")
        empty.yearKeys = []

        let sigA = SearchScopeSignature.signature(for: a)
        #expect(sigA != SearchScopeSignature.signature(for: b), """
            The research trail de-duplicates on this signature, and the exported methods appendix \
            is paraphrased from it. Two different scopes signing alike would record one row for \
            both and describe a search the numbers did not come from.
            """)
        #expect(sigA != SearchScopeSignature.signature(for: none))
        #expect(SearchScopeSignature.signature(for: none) != SearchScopeSignature.signature(for: empty))
    }

    @Test("The methods appendix names the years rather than counting them")
    func appendixNamesTheYears() throws {
        var parameters = SearchParameters(keywords: "berlin")
        parameters.yearKeys = ["1951", "1953"]
        let phrases = try #require(
            SearchScopeSignature.describe(SearchScopeSignature.signature(for: parameters)))
        #expect(phrases.contains { $0.contains("1951") && $0.contains("1953") }, """
            Which years were kept is the finding. An appendix reading "2 years" leaves a reader \
            unable to reproduce the search. Got: \(phrases)
            """)
    }
}

// MARK: - StagedSelectionLifetimeTests

/// That a staged selection belongs to the result set it was made in (#775).
///
/// Both tests here exist because the mutation sweep found nothing pinning them, and each undoes a
/// property the feature is unusable without.
///
/// Version history:
///   1.0 — Session 2026-08-10: #775
@Suite("Staged selection lifetime (#775)")
@MainActor
struct StagedSelectionLifetimeTests {

    @Test("A new search clears the staged selection")
    func newSearchClearsTheSelection() {
        let controller = FacetPanelController()
        controller.invalidate(signature: "query=berlin")
        controller.cycleSelection("1951", in: .years)
        controller.cycleSelection("1953", in: .years)
        #expect(controller.selection(for: .years).count == 2)

        controller.invalidate(signature: "query=paris")
        #expect(controller.selection(for: .years).isEmpty, """
            The buckets a selection names come from one result set. Carried into another, the \
            panel shows checkmarks against rows that may not exist and Apply filters to years the \
            new search never matched.
            """)
    }

    @Test("Re-invalidating with the SAME signature keeps the selection")
    func sameSignatureKeepsTheSelection() {
        let controller = FacetPanelController()
        controller.invalidate(signature: "query=berlin")
        controller.cycleSelection("1951", in: .years)
        controller.invalidate(signature: "query=berlin")
        #expect(controller.selection(for: .years).count == 1, """
            `invalidate` is called on every panel pass, not only on a real change. Clearing on a \
            no-op would wipe the selection the moment the user opened a second section.
            """)
    }

    @Test("Sections stage independently")
    func sectionsAreIndependent() {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q")
        controller.cycleSelection("1951", in: .years)
        controller.cycleSelection("frus1952-54v01", in: .volumes)
        #expect(controller.selection(for: .years).includedKeys == ["1951"])
        #expect(controller.selection(for: .volumes).includedKeys == ["frus1952-54v01"])
        controller.clearSelection(in: .years)
        #expect(controller.selection(for: .years).isEmpty)
        #expect(controller.selection(for: .volumes).count == 1,
                "clearing one section must not clear another")
    }

    @Test("The advanced-filter signature sees the year set")
    func signatureSeesTheYearSet() throws {
        // M-1, recurring. The macOS Search window applies filter edits by observing this
        // fingerprint; a field missing from it is set, shown as applied, and silently ignored by
        // the search. It has already happened once, to the working-corpus field.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                            volumesDirectory: dir, concurrencyLimit: 1)
        let vm = SearchViewModel(searchService: SearchService(fts5Store: fts5, pipeline: pipeline))
        let before = vm.advancedFilterSignature
        vm.facetYearKeys = ["1951", "1953"]
        #expect(vm.advancedFilterSignature != before, """
            Without the year set in the signature, macOS never re-runs the search after a year \
            selection: the filter is applied, the chip appears, and the results do not change.
            """)
        vm.facetYearKeys = ["1949"]
        #expect(vm.advancedFilterSignature != before)
        vm.facetYearKeys = nil
        #expect(vm.advancedFilterSignature == before, "clearing it returns to the original scope")
    }
}
