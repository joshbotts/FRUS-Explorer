// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
#if canImport(FTS5Store)
import FTS5Store
#endif
#if canImport(SourceNoteKit)
import SourceNoteKit
#endif

// MARK: - SourceExplorerResolutionTests

/// `SourceExplorerResolution.resolved`, the sequence both Source Explorer views run and FRUS Explorer Light
/// runs over the same files, driven through a real index: the order its steps run in, which a view draws
/// as they come; the bundled files read only where a step reads them; and each part equal to what its step
/// gives on its own.
///
/// The order used to be pinned by scanning each twin's `load()` for its calls
/// (`SourceExplorerReloadWiringAuditTests`, 1.2). The sequence is the kit's now, so it is run instead.
///
/// Version history:
///   1.0 — 2026-11-10 (FRUS Explorer Light, S22b): initial implementation
@Suite("Source Explorer resolution")
@MainActor
struct SourceExplorerResolutionTests {

    /// Every value `resolved` hands its host, in order, on the main actor where it hands them.
    @MainActor
    final class Updates {
        var values: [SourceExplorerResolution] = []
    }

    /// The evaluation, through a real index, puts the pre-1906 document's homes after the authority step
    /// and before every step that reads the year; the related documents are searched, then found; and the
    /// register is read only once both of the country series' gates have passed.
    @Test("A pre-1906 document's steps run in the views' order, each value handed over as it lands")
    func theStepsRunInTheViewsOrder() async throws {
        let fixture = try await ResolutionFixtures.index(ResolutionFixtures.d573XML, volumeId: "vol1")
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let reads = ResolutionFixtures.Reads()
        let updates = Updates()
        // The route History and the Research tab take: the xml:id as the header, no dateline, no year.
        let route = CountrySeriesRoute(header: "d573", dateline: nil, year: nil, volumeId: "vol1", documentId: "d573")
        let resolved = await SourceExplorerResolution(rawSourceNote: "").resolved(
            route: route, pipeline: fixture.pipeline,
            dependencies: ResolutionFixtures.dependencies(reads, volumeURL: fixture.volumeURL)) {
                updates.values.append($0)
            }

        let values = updates.values
        try #require(values.count == 7, """
            \(values.count) values: the authority record, the country series, the day, the marking, the \
            pointers, the search started and the related documents, and no library step for a blank note
            """)
        #expect(values[0].countrySeries == .loading && values[0].documentContext == nil,
                "the authority record is handed over before the evaluation")
        #expect(values[1].countrySeries.homes.map(\.classification.category) == [.instructions],
                "\(values[1].countrySeries)")
        #expect(values[1].documentContext?.year == 1863, "the evaluation reads the year the route left out")
        #expect(values[1].documentDay == nil && values[2].documentDay == values.last?.documentDay,
                "the day is its own step, after the evaluation")
        #expect(values[4].relatedDocuments.documents.isEmpty && !values[4].relatedDocuments.isSearching,
                "nothing is searched before the pointers")
        #expect(values[5].relatedDocuments.isSearching, "the host is told the search has started")
        guard case .found = values[6].relatedDocuments else {
            Issue.record("the related documents were not found: \(values[6].relatedDocuments)")
            return
        }
        #expect(reads.names == ["centralFiles", "chiefsOfMission", "ast", "store"], """
            The central files for the evaluation, the register once its gates passed, then the parsed \
            documents (a miss, so the volume is parsed and kept); no authority, for a blank note with no \
            pointers, and no library catalogue. Read: \(reads.names)
            """)

        // Each part is what its step gives alone.
        let alone = await CentralFilesClassifier.evaluate(
            route: route, pipeline: fixture.pipeline, index: CentralFilesIndexStore.shared, roster: .bundled,
            astCache: DocumentASTCache(), volumeURL: fixture.volumeURL)
        #expect(resolved.countrySeries == alone.outcome && resolved.documentContext == alone.context)
        let neighbours = try await fixture.pipeline.archivalNeighbors(
            forVolumeId: "vol1", documentId: "d573", documentYear: alone.context.year)
        #expect(resolved.relatedDocuments.documents.map(\.compositeKey) == neighbours.documents.map(\.compositeKey))
        #expect(resolved.relatedDocuments.totalCount == neighbours.totalCount)
        #expect(resolved.countrySeries == values[6].countrySeries && resolved.documentDay == values[6].documentDay,
                "the value returned is the last one handed over")
    }

    /// d41's footnotes cite lot 66 D 95 and the lot its own note names, 63 D 351 (#1390).
    @Test("A document's pointers carry the note it was resolved with, and every part is its step's")
    func thePartsAreTheStepsOwn() async throws {
        let fixture = try await ResolutionFixtures.index(ResolutionFixtures.d41XML, volumeId: "frus1952-54v02p1")
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let reads = ResolutionFixtures.Reads()
        let note = "S/S–NSC files, lot 63 D 351, NSC 140"
        let route = CountrySeriesRoute(header: nil, dateline: nil, year: nil,
                                       volumeId: "frus1952-54v02p1", documentId: "d41")
        let resolved = await SourceExplorerResolution(rawSourceNote: note).resolved(
            route: route, pipeline: fixture.pipeline,
            dependencies: ResolutionFixtures.dependencies(reads, volumeURL: fixture.volumeURL))

        let parsed = SourceNoteParser().parse(note)
        #expect(resolved.parsed == parsed)
        let authority = CollectionAuthorityStore.shared
        try #require(resolved.authorityRecord != nil, "fixture guard: the authority holds lot 63 D 351")
        #expect(resolved.authorityRecord == authority?.record(forParsed: parsed, note: note))
        let citations = try await fixture.pipeline.externalCitations(volumeId: "frus1952-54v02p1", documentId: "d41")
        try #require(!citations.isEmpty, "fixture guard: d41's footnotes must be harvested")
        let listed = SourceExplorerResolution.UnprintedPointer.list(citations, sourceNote: parsed) { citation in
            authority.flatMap { SourceExplorerResolution.UnprintedPointer.resolve(citation, authority: $0) }
        }
        #expect(resolved.unprintedPointers == listed)
        #expect(resolved.unprintedPointers.allSatisfy { $0.sourceNoteLotNorm == "63D351" })
        #expect(resolved.unprintedPointers.contains { $0.rowText.sameLotNote != nil },
                "footnote 3 cites the note's own lot")
        let day = try await fixture.pipeline.documentDay(volumeId: "frus1952-54v02p1", documentId: "d41")
        let marking = try await fixture.pipeline.storedClassification(volumeId: "frus1952-54v02p1", documentId: "d41")
        #expect(resolved.documentDay == day && day != nil, "the day is the index's: \(String(describing: day))")
        #expect(resolved.storedClassification == marking)
        // A document of 1953: the hydrated year refuses the country series, and the register is not read.
        #expect(resolved.countrySeries == .notApplicable)
        #expect(!reads.names.contains("chiefsOfMission"), "the register was read for a 1953 document: \(reads.names)")
        #expect(reads.names.first == "collectionAuthority", "the authority record is the first read: \(reads.names)")
        #expect(reads.names.filter { $0 == "collectionAuthority" }.count == 1,
                "the authority is read once, for the record and the pointers both: \(reads.names)")
        #expect(resolved.presidentialLibrary == .none)
        // d42 cites the same lot, so the neighbours are not empty, and they are the entry point's own.
        let neighbours = try await fixture.pipeline.archivalNeighbors(
            forVolumeId: "frus1952-54v02p1", documentId: "d41", documentYear: resolved.documentContext?.year)
        #expect(resolved.relatedDocuments.documents.map(\.compositeKey) == ["frus1952-54v02p1/d42"])
        #expect(resolved.relatedDocuments.documents.map(\.compositeKey) == neighbours.documents.map(\.compositeKey))
        #expect(resolved.relatedDocuments.totalCount == neighbours.totalCount)
    }

    /// The bundled catalogue answers a library citation with neither a key nor the network (#681), after
    /// the related documents, and only for a library citation is it read at all.
    @Test("A library citation is answered last, from the catalogue and the curated table read for it alone")
    func aLibraryCitationIsAnsweredLast() async throws {
        let fixture = try await ResolutionFixtures.index(ResolutionFixtures.d41XML, volumeId: "frus1952-54v02p1")
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let reads = ResolutionFixtures.Reads()
        let updates = Updates()
        let note = "Johnson Library, National Security File, Country File, Vietnam, Vol. XII."
        let route = CountrySeriesRoute(header: nil, dateline: nil, year: nil,
                                       volumeId: "frus1952-54v02p1", documentId: "d41")
        let resolved = await SourceExplorerResolution(rawSourceNote: note).resolved(
            route: route, pipeline: fixture.pipeline,
            dependencies: ResolutionFixtures.dependencies(reads, volumeURL: fixture.volumeURL)) {
                updates.values.append($0)
            }
        guard case .presidentialLibrary(let library, let collection, _) = resolved.parsed else {
            Issue.record("fixture guard: the note must parse as a library citation: \(resolved.parsed)")
            return
        }
        #expect(updates.values.count == 8, "the library is a step of its own: \(updates.values.count) values")
        #expect(updates.values.dropLast().allSatisfy { $0.presidentialLibrary == .none },
                "the library was answered before the related documents")
        #expect(Array(reads.names.suffix(2)) == ["presidentialLibraries", "curatedLibraries"], "\(reads.names)")
        #expect(reads.names.filter { $0 == "presidentialLibraries" }.count == 1)
        #expect(resolved.presidentialLibrary.isHit, "fixture guard: the catalogue answers the Johnson Library's NSF")
        #expect(resolved.presidentialLibrary == PresidentialLibraryOutcome.resolve(
            repository: library, collection: collection, note: note,
            index: PresidentialLibraryIndexStore.shared, curated: CuratedLibraryResolutionsStore.shared))
    }

    /// A note explored with no indexed document behind it (opened from History or the Research tab) takes
    /// the note-keyed query, which reads a central-files class from the note itself (index version 69): a
    /// Subject-Numeric file cited in the Department's wording finds the documents that cite it through the
    /// National Archives too. The same query without the note reads the parse alone and finds another set,
    /// so the fixture tells a sequence that hands the query its note from one that does not.
    @Test("A note with no document behind it is matched on the class its own text names")
    func aNoteWithNoDocumentIsMatchedOnItsClass() async throws {
        let fixture = try await ResolutionFixtures.index(ResolutionFixtures.classXML, volumeId: "frus1969-76v01")
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let note = "Source: Department of State, Central Files, POL 27 ARAB-ISR. Secret."
        let route = CountrySeriesRoute(header: nil, dateline: nil, year: nil, volumeId: nil, documentId: nil)
        let resolved = await SourceExplorerResolution(rawSourceNote: note).resolved(
            route: route, pipeline: fixture.pipeline,
            dependencies: ResolutionFixtures.dependencies(ResolutionFixtures.Reads(), volumeURL: nil))

        let keyed = try await fixture.pipeline.relatedDocuments(for: resolved.parsed, rawCitation: note)
        let unkeyed = try await fixture.pipeline.relatedDocuments(for: resolved.parsed)
        try #require(Set(keyed.documents.map(\.documentId)) == ["d1", "d2"],
                     "fixture guard: the file is cited both ways: \(keyed.documents.map(\.documentId))")
        try #require(Set(unkeyed.documents.map(\.documentId)) != ["d1", "d2"],
                     "fixture guard: the query finds the same set without the note: \(unkeyed.documents.map(\.documentId))")
        #expect(resolved.relatedDocuments.documents.map(\.compositeKey) == keyed.documents.map(\.compositeKey))
        #expect(resolved.relatedDocuments.totalCount == keyed.totalCount)
    }

    /// While the index starts, the steps that need none still answer, and the country series says why it
    /// did not run, as the views say it.
    @Test("With no index, the parse, the authority and the country series' reason are all there is")
    func withNoIndexOnlyTheIndexFreeStepsRun() async throws {
        let reads = ResolutionFixtures.Reads()
        let updates = Updates()
        let note = "S/S–NSC files, lot 63 D 351, NSC 140"
        let route = CountrySeriesRoute(header: nil, dateline: nil, year: nil,
                                       volumeId: "frus1952-54v02p1", documentId: "d41")
        let resolved = await SourceExplorerResolution(rawSourceNote: note).resolved(
            route: route, pipeline: nil,
            dependencies: ResolutionFixtures.dependencies(reads, volumeURL: nil)) {
                updates.values.append($0)
            }
        #expect(updates.values.count == 5, "no search is started without an index: \(updates.values.count) values")
        #expect(resolved.countrySeries == .notChecked(.indexStarting))
        #expect(resolved.relatedDocuments.documents.isEmpty && !resolved.relatedDocuments.isSearching)
        if case .notRun = resolved.relatedDocuments {} else {
            Issue.record("the related documents ran with no index: \(resolved.relatedDocuments)")
        }
        #expect(resolved.unprintedPointers.isEmpty && resolved.documentDay == nil && resolved.storedClassification == nil)
        #expect(resolved.authorityRecord != nil
                && resolved.authorityRecord == CollectionAuthorityStore.shared?.record(forParsed: resolved.parsed, note: note))
        #expect(!reads.names.contains("chiefsOfMission") && !reads.names.contains("ast"), "\(reads.names)")
    }

    /// A view loading the document it already shows starts from what it shows: each part stays until its
    /// step replaces it, but the country series, the hydrated document, the day and the marking go back to
    /// their first state, as the iOS view reset them before each load.
    @Test("A value resolved again keeps each part until its step replaces it")
    func aValueResolvedAgainKeepsItsParts() async throws {
        let fixture = try await ResolutionFixtures.index(ResolutionFixtures.d41XML, volumeId: "frus1952-54v02p1")
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let note = "S/S–NSC files, lot 63 D 351, NSC 140"
        let route = CountrySeriesRoute(header: nil, dateline: nil, year: nil,
                                       volumeId: "frus1952-54v02p1", documentId: "d41")
        let dependencies = ResolutionFixtures.dependencies(ResolutionFixtures.Reads(), volumeURL: fixture.volumeURL)
        let first = await SourceExplorerResolution(rawSourceNote: note).resolved(
            route: route, pipeline: fixture.pipeline, dependencies: dependencies)
        try #require(first.authorityRecord != nil && !first.unprintedPointers.isEmpty
                     && !first.relatedDocuments.documents.isEmpty && first.documentContext != nil,
                     "fixture guard: the first resolution holds every part")

        let again = first.resolvingAgain()
        #expect(again.countrySeries == .loading && again.documentContext == nil)
        #expect(again.documentDay == nil && again.storedClassification == nil)
        #expect(again.authorityRecord == first.authorityRecord && again.unprintedPointers == first.unprintedPointers)
        #expect(again.relatedDocuments.documents.map(\.compositeKey) == first.relatedDocuments.documents.map(\.compositeKey))
        #expect(again.parsed == first.parsed && again.presidentialLibrary == first.presidentialLibrary)

        let updates = Updates()
        let resolved = await again.resolved(route: route, pipeline: fixture.pipeline, dependencies: dependencies) {
            updates.values.append($0)
        }
        try #require(updates.values.count == 7, "\(updates.values.count) values")
        // The first value handed over, after the authority step: the pointers and the neighbours are still
        // the held ones, and the country series is checking, not the held one.
        #expect(updates.values[0].unprintedPointers == first.unprintedPointers)
        #expect(updates.values[0].relatedDocuments.documents.map(\.compositeKey)
                == first.relatedDocuments.documents.map(\.compositeKey))
        #expect(updates.values[0].countrySeries == .loading)
        #expect(updates.values[5].relatedDocuments.isSearching, "the search still says it has started")
        #expect(resolved.countrySeries == first.countrySeries && resolved.documentContext == first.documentContext)
        #expect(resolved.unprintedPointers == first.unprintedPointers && resolved.documentDay == first.documentDay)
    }

    /// A view resets to this before its first await: the parse, and nothing the previous document resolved.
    @Test("The starting value is the parse alone")
    func theStartingValueIsTheParseAlone() {
        let start = SourceExplorerResolution(rawSourceNote: "  ")
        #expect(!start.hasSourceNote)
        #expect(start.countrySeries == .loading && start.documentContext == nil && start.authorityRecord == nil)
        #expect(start.unprintedPointers.isEmpty && start.documentDay == nil && start.storedClassification == nil)
        #expect(start.presidentialLibrary == .none && !start.relatedDocuments.isSearching)
        #expect(SourceExplorerResolution(rawSourceNote: "Lot 64 D 199").parsed
                == SourceNoteParser().parse("Lot 64 D 199"))
    }
}

// MARK: - ResolutionFixtures

/// The fixtures and the recording dependencies, nonisolated so the providers the resolution calls off the
/// main actor can reach them.
enum ResolutionFixtures {

    /// The bundled files and parsed documents a resolution read, in order.
    final class Reads: @unchecked Sendable {
        private let lock = NSLock()
        private var log: [String] = []
        func note(_ name: String) {
            lock.lock()
            log.append(name)
            lock.unlock()
        }
        var names: [String] {
            lock.lock()
            defer { lock.unlock() }
            return log
        }
    }

    /// A parsed-document source that keeps what it is given and records each call.
    actor RecordingASTSource: DocumentASTSource {
        let reads: Reads
        private var kept: [String: FRUSDocumentAST] = [:]
        init(_ reads: Reads) { self.reads = reads }
        func ast(volumeId: String, documentId: String) -> FRUSDocumentAST? {
            reads.note("ast")
            return kept["\(volumeId)/\(documentId)"]
        }
        func store(_ documents: [FRUSDocumentAST], volumeId: String) {
            reads.note("store")
            for document in documents { kept["\(volumeId)/\(document.documentId)"] = document }
        }
    }

    /// `value`, noted under `name` each time it is read.
    static func read<T>(_ reads: Reads, _ name: String, _ value: @autoclosure () -> T) -> T {
        reads.note(name)
        return value()
    }

    /// The app's files, through the stores the suites name, each read noted where the resolution reads it.
    static func dependencies(_ reads: Reads, volumeURL: URL?) -> SourceExplorerResolution.Dependencies {
        SourceExplorerResolution.Dependencies(
            collectionAuthority: read(reads, "collectionAuthority", CollectionAuthorityStore.shared),
            centralFiles: read(reads, "centralFiles", CentralFilesIndexStore.shared),
            chiefsOfMission: read(reads, "chiefsOfMission", ChiefsOfMissionRoster.bundled),
            presidentialLibraries: read(reads, "presidentialLibraries", PresidentialLibraryIndexStore.shared),
            curatedLibraries: read(reads, "curatedLibraries", CuratedLibraryResolutionsStore.shared),
            parsedDocuments: RecordingASTSource(reads),
            volumeURL: volumeURL)
    }

    /// One volume indexed through the real pipeline into a fresh folder.
    static func index(_ xml: String, volumeId: String) async throws
        -> (dir: URL, pipeline: IndexingPipeline, volumeURL: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSResolution-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let volumeURL = volumes.appendingPathComponent("\(volumeId).xml")
        try Data(xml.utf8).write(to: volumeURL)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL), databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume(volumeId)
        return (dir, pipeline, volumeURL)
    }

    /// A volume shaped like `frus1863p2`, as `SourceExplorerEvaluationTests` indexes it: `d573`, Seward to
    /// Dayton, inside a `France.` chapter, with its printed serial.
    static let d573XML = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="chapter" xml:id="ch1">
          <head>France.</head>
          <div type="document" xml:id="d573">
            <head>Mr. Seward to Mr. Dayton.</head>
            <opener><dateline>Department of State , Washington , November 10, 1863.</dateline>
              <seg rendition="#left">No. 428.]</seg></opener>
            <p>Sir: Your despatch has been received.</p>
          </div>
        </div>
        </body></text></TEI>
        """

    /// A Subject-Numeric file cited in the Department's wording (d1) and through the National Archives (d2), as
    /// `IndexingPipelineTests`' class leaves are, and another file (d3).
    static let classXML = """
    <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
      <div subtype="historical-document" type="document" xml:id="d1" n="1">
        <head>Telegram From the Department of State to the Embassy in Israel</head>
        <note rend="inline" type="source">Source: Department of State, Central Files, POL 27 ARAB-ISR. Secret.</note>
        <p>Text.</p>
      </div>
      <div subtype="historical-document" type="document" xml:id="d2" n="2">
        <head>Memorandum From the Executive Secretary of the Department of State</head>
        <note rend="inline" type="source">Source: National Archives and Records Administration, RG 59, Central Files 1967–69, POL 27 ARAB-ISR. Secret; Immediate.</note>
        <p>Text.</p>
      </div>
      <div subtype="historical-document" type="document" xml:id="d3" n="3">
        <head>Telegram From the Mission to the United Nations to the Department of State</head>
        <note rend="inline" type="source">Source: Department of State, Central Files, POL 19 UN. Confidential.</note>
        <p>Text.</p>
      </div>
    </body></text></TEI>
    """

    /// `frus1952-54v02p1` d41, as `UnprintedMaterialRowTests` indexes it, with a second document from its lot.
    static let d41XML = """
    <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
      <div subtype="historical-document" type="document" xml:id="d41" n="41">
        <note rend="inline" type="source"><gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140</note>
        <head><hi rend="italic">Report to the National Security Council by the Executive Secretary (<persName corresp="#p_LAYJSJ1">Lay</persName>)</hi><note n="1" xml:id="d41fn1">Copies to the Secretary of the Treasury, the Attorney General, the Director of Defense Mobilization, and the Acting Federal Civil Defense Administrator.</note></head>
        <opener>
          <dateline rendition="#right"><placeName><hi rend="smallcaps">Washington</hi></placeName>, <date calendar="gregorian" when="1953-01-19">January 19, 1953</date>.</dateline>
        </opener>
        <list type="references">
          <head>References:</head>
          <label>A.</label>
          <item><gloss target="#t_NSC1">NSC</gloss> Action Nos. 687 and 699<note n="2" xml:id="d41fn2">In <gloss target="#t_NSC1">NSC</gloss> Action No. 543, taken on Aug. 30, 1951, the National Security Council approved a draft directive on “A Project To Provide a More Adequate Basis for Planning for the Security of the United States”, prepared by the Director of Central Intelligence pursuant to <gloss target="#t_NSC1">NSC</gloss> Action No. 519. <gloss target="#t_NSC1">NSC</gloss> Action No. 687, taken at the Council meeting of Nov. 26, 1952, noted that a summary evaluation was limited and inadequate in several respects. (<gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> (Miscellaneous) files, lot 66 D 95, “Record of Actions”) <gloss target="#t_NSC1">NSC</gloss> Action No. 699, taken by the Council on Jan. 16, 1953, accepted a draft National Security Council directive for a special evaluation subcommittee. (<gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> (Miscellaneous) files, lot 66 D 95, “<gloss target="#t_NSC1">NSC</gloss> Record of Actions”)</note></item>
          <label>B.</label>
          <item>Memo for <gloss target="#t_NSC1">NSC</gloss> from Executive Secretary, dated January 15, 1953<note n="3" xml:id="d41fn3">Reference is to the memorandum enclosing the draft National Security Council directive for a special evaluation subcommittee which became the subject of <gloss target="#t_NSC1">NSC</gloss> Action No. 699. A copy of this memorandum is in <gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140 Series.</note></item>
          <label>C.</label>
          <item>Memo for <gloss target="#t_NSC1">NSC</gloss> from Acting Executive Secretary, dated October 21, 1952<note n="4" xml:id="d41fn4">Reference is to the memorandum enclosing the summary evaluation which became the subject of <gloss target="#t_NSC1">NSC</gloss> Action No. 687 discussed in footnote 2 above. A copy of this memorandum is in <gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140 Series.</note></item>
          <label>D.</label>
          <item>Memo for <gloss target="#t_NSC1">NSC</gloss> from Executive Secretary, dated November 25, 1952<note n="5" xml:id="d41fn5">Reference is to the memorandum containing amendments to the summary evaluation which became the subject of <gloss target="#t_NSC1">NSC</gloss> Action No. 687 discussed in footnote 2 above. A copy of this memorandum is in <gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140 Series.</note></item>
        </list>
        <p>The draft directive, together with the above action, was subsequently submitted to the President for consideration.</p>
      </div>
      <div subtype="historical-document" type="document" xml:id="d42" n="42">
        <note rend="inline" type="source">S/S–NSC files, lot 63 D 351, NSC 141</note>
        <head>Memorandum by the Executive Secretary of the National Security Council</head>
        <opener>
          <dateline rendition="#right"><placeName>Washington</placeName>, <date calendar="gregorian" when="1953-01-20">January 20, 1953</date>.</dateline>
        </opener>
        <p>A second document from the same lot, so that d41 has an archival neighbour (S22b's fixture).</p>
      </div>
    </body></text></TEI>
    """
}
