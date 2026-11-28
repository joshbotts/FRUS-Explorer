// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif
// SHA-256 is CryptoKit's on Apple platforms; on Linux the web edition supplies swift-crypto's Crypto.
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - CollectionResolutionFixtures

/// A collection resolved through a store the tests supply: one fixture volume indexed by the kit's own
/// pipeline (so the printed numbers, the source notes, the dates and the parsed archival sources are the
/// index's), its documents parsed by the kit's parser, and a store of notes, highlights, summaries and
/// tags as the research data export's records. Nothing here is the app's, so the suites run wherever
/// FRUSCoreKit does.
///
/// Version history:
///   1.0 — 2026-10-27 (FRUS Explorer Light, S18b): initial implementation, with the content assembly's
///          move into the kit
enum CollectionResolutionFixtures {

    static let volume = "frus1961-63v11"

    /// The documents' bodies: a telegram with a figure and a source note naming a lot, a memorandum
    /// citing the central files, and a letter with no source note and no date.
    static let documents: [(id: String, xml: String)] = [
        ("d7", """
        <head>7. Telegram From the Embassy in France to the Department of State<note n="0" type="source" xml:id="d7fn0">Source: Department of State, S/S Files: Lot 72 D 316, Paris Embassy Telegrams. Secret; Niact.</note></head>
        <opener><dateline rendition="#right"><placeName>Paris</placeName>, <date calendar="gregorian" when="1962-10-22">October 22, 1962</date>, 5 p.m.</dateline></opener>
        <p>The Ambassador saw the Foreign Minister <hi rend="italic">this morning</hi> and spoke of the quarantine.</p>
        <figure><head>The quarantine line</head><graphic url="fig1"/></figure>
        """),
        ("d8", """
        <head>8. Memorandum From the President’s Special Assistant to President Kennedy<note n="0" type="source" xml:id="d8fn0">Source: Department of State, Central Files, 611.3722/10–2362. Top Secret.</note></head>
        <opener><dateline rendition="#right"><placeName>Washington</placeName>, <date calendar="gregorian" when="1962-10-23">October 23, 1962</date>.</dateline></opener>
        <p>The Executive Committee met at 10 a.m. and agreed on the text of the proclamation.</p>
        """),
        ("d9", """
        <head>9. Letter From Chairman Khrushchev to President Kennedy</head>
        <p>Dear Mr. President, I have received your letter.</p>
        """),
    ]

    /// Writes the fixture volume, with each document's number as the corpus prints it, as TEI.
    static func writeVolume(to directory: URL) throws -> URL {
        let blocks = documents.map { doc in
            "<div type=\"document\" subtype=\"historical-document\" n=\"\(doc.id.dropFirst())\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volume)</title></titleStmt>
          <publicationStmt><date>1996</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="compilation" xml:id="comp1">
          \(blocks)
          </div></body></text>
        </TEI>
        """
        let url = directory.appendingPathComponent("\(volume).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static let promptA = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    static let promptB = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
    static let noteOne = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    static let noteTwo = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!
    static let noteThree = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
    static let noteFour = UUID(uuidString: "00000000-0000-0000-0000-00000000B004")!
    static let highlightKept = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    static let highlightLeft = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!
    static let tagQuarantine = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
    static let tagUnused = UUID(uuidString: "00000000-0000-0000-0000-00000000D002")!
    static let missingSummary = UUID(uuidString: "00000000-0000-0000-0000-00000000E404")!

    static func note(_ id: UUID, _ document: String, _ body: String, tags: [UUID] = []) -> ResearchNoteExport {
        ResearchNoteExport(id: id, documentId: document, volumeId: volume, bodyText: body, projectIds: [],
                           userTagIds: tags, selectedSummaryIds: [], linkedHighlightIds: [])
    }

    /// The researcher's notes: one picked by d7's entry, one d8's legacy link names, and two on d9, one
    /// of them empty, which no list carries.
    static let notes: [ResearchNoteExport] = [
        note(noteOne, "d7", "The Ambassador's account matches the French record.", tags: [tagQuarantine]),
        note(noteTwo, "d8", "Compare the proclamation's draft."),
        note(noteThree, "d9", "The first letter of the exchange."),
        note(noteFour, "d9", ""),
    ]

    static func summary(_ document: String, prompt: UUID, _ text: String, authorship: SummaryAuthorship? = nil,
                        draft: Bool = false) -> GeneratedSummaryExport {
        GeneratedSummaryExport(id: UUID(), documentId: document, volumeId: volume, promptId: prompt,
                               responseText: text, responseFormat: .general, wasChunked: false,
                               authorship: authorship, isHeadnoteDraft: draft)
    }

    static func entry(_ sortOrder: Int, kind: CollectionEntryKind, document: String = "", text: String? = nil,
                      level: Int = 1, configure: (inout CollectionEntryExport) -> Void = { _ in })
        -> CollectionEntryExport {
        var entry = CollectionEntryExport(
            id: UUID(), documentId: document, volumeId: document.isEmpty ? "" : volume, sortOrder: sortOrder,
            selectedNoteIds: [], kind: kind.rawValue, level: level, text: text, selectedHighlightIds: [])
        configure(&entry)
        return entry
    }

    /// The static collection: a section that turns on highlights, source notes and the "See also:"
    /// line for its two documents (one picking a note and a highlight, one with a legacy note link and
    /// a headnote whose chosen summary is gone), a prose block, an untitled sub-section at index depth
    /// holding d9 (whose notes are all of its own), an excerpt, four apparatus blocks, and three entries a
    /// resolve skips: a block type and an entry kind from a newer build, and a document with no ids.
    static func staticCollection(defaultBodyDepth: String = "full", summaryPromptId: UUID? = promptA)
        -> CollectionExport {
        let entries: [CollectionEntryExport] = [
            entry(0, kind: .heading, text: "The Crisis") {
                $0.applyHighlightsOverride = true
                $0.includeSourceNoteOverride = true
                $0.includeRelatedDocuments = true
            },
            entry(1, kind: .document, document: "d7") {
                $0.selectedNoteIds = [noteOne]
                $0.selectedHighlightIds = [highlightKept]
            },
            entry(2, kind: .document, document: "d8") {
                $0.researchNoteId = noteTwo
                $0.includeHeadnote = true
                $0.headnoteSummaryId = missingSummary
                $0.titleOverride = "The proclamation memorandum"
            },
            entry(3, kind: .prose, text: "An editorial note."),
            entry(4, kind: .heading, text: "  ", level: 2) { $0.bodyDepthOverride = "index" },
            entry(5, kind: .document, document: "d9"),
            entry(6, kind: .excerpt, document: "d7", text: "spoke of the quarantine") {
                $0.excerptColorTag = "green"
            },
            entry(7, kind: .generated) { $0.generatedBlockType = CollectionGeneratedBlockType.bibliography.rawValue },
            entry(8, kind: .generated) { $0.generatedBlockType = CollectionGeneratedBlockType.chronology.rawValue },
            entry(9, kind: .generated) { $0.generatedBlockType = CollectionGeneratedBlockType.archivalSources.rawValue },
            entry(10, kind: .generated) { $0.generatedBlockType = CollectionGeneratedBlockType.thematicIndex.rawValue },
            entry(11, kind: .generated) { $0.generatedBlockType = "atlas" },
            entry(12, kind: .document) { $0.kind = "timeline" },
            entry(13, kind: .document),
        ]
        return CollectionExport(
            id: UUID(), name: "Missiles", projectIds: [], entries: entries,
            defaultBodyDepth: defaultBodyDepth, footnoteStyle: "all", tocStyle: "citation",
            applyHighlights: false, includeNotes: true, includeWordCloud: false,
            defaultIncludeHeadnote: false, summaryPromptId: summaryPromptId)
    }

    /// The prose block's paragraphs, as a host decodes them from its rich text.
    static let proseParagraphs: [[ProseFormattedSpan]] = [[
        ProseFormattedSpan(text: "An ", bold: false, italic: false, underline: false, colorHex: nil, linkURL: nil),
        ProseFormattedSpan(text: "editorial", bold: true, italic: false, underline: false, colorHex: nil, linkURL: nil),
        ProseFormattedSpan(text: " note.", bold: false, italic: false, underline: false, colorHex: nil, linkURL: nil),
    ]]

    /// The collection's entries as the assembly reads them, the prose block with its paragraphs.
    static func entries(of collection: CollectionExport) -> [CollectionContentAssembly.Entry] {
        collection.entries.map {
            CollectionContentAssembly.Entry($0, proseParagraphs: $0.entryKind == .prose ? proseParagraphs : nil)
        }
    }

    /// The central-files index of two lots, `72D316` and `64D563`, and the claimants index dividing the
    /// second, as the shipped bundles hold every divided lot (`ArchivalResolver.lotResolution`'s note).
    static func archivalIndexes() throws -> ArchivalIndexes {
        let central = """
        {"schemaVersion":1,"generated":"2026-10-27",
         "numericalFile":{"seriesNaId":"654171","microfilm":"M862","rolls":[]},
         "countrySeries":[],
         "lotFiles":[{"lotNumber":"72D316","recordGroup":"59","naId":"1234567",
                      "title":"Paris Embassy Telegrams, 1962","catalogURL":"https://catalog.archives.gov/id/1234567",
                      "matchType":"control","levelOfDescription":"series"},
                     {"lotNumber":"64D563","recordGroup":"59","naId":"7654321",
                      "title":"Conference Files","catalogURL":"https://catalog.archives.gov/id/7654321",
                      "matchType":"control","levelOfDescription":"series"}]}
        """
        let claimants = """
        {"schemaVersion":1,"generated":"2026-10-27","lots":[{"lotNumber":"64D563","claimants":[
          {"naId":"1","title":"One","evidence":"controlNumber"},{"naId":"2","title":"Two","evidence":"controlNumber"}]}]}
        """
        return ArchivalIndexes(
            centralFiles: try JSONDecoder().decode(CentralFilesIndex.self, from: Data(central.utf8)),
            claimants: try JSONDecoder().decode(LotClaimantsIndex.self, from: Data(claimants.utf8)))
    }
}

// MARK: - FixtureContentStore

/// The store the suites supply: the fixture volume's index and parsed documents, the research data
/// export's records, and a record of every export step asked of it.
@MainActor
final class FixtureContentStore: CollectionContentDataSource {
    var manifestEntries: [VolumeManifestEntry]
    var indexingPipeline: IndexingPipeline?
    var asts: [String: FRUSDocumentAST] = [:]
    var crossReferences: [String: [(volumeId: String, documentId: String)]]? = [:]
    var personMentionStore: PersonMentionStore? = nil
    var archivalIndexes = ArchivalIndexes()
    var highlightRecords: [DocumentHighlightExport] = []
    var summaries: [GeneratedSummaryExport] = []
    var tags: [UserTagExport] = []
    var assignments: [DocumentTagAssignmentExport] = []
    var tagNamesByDocument: [String: [String]] = [:]
    var smartRefs: [SmartCollectionDocumentRef] = []
    var generated: [String: String] = [:]
    /// The format every summary in `generated` is written in.
    var generatedFormat: ResponseFormat = .general

    private(set) var preparedVolumeIds: [Set<String>] = []
    private(set) var fetchedImages: [[FigureImageName]] = []
    private(set) var generationPrompts: [UUID] = []

    init(manifestEntries: [VolumeManifestEntry], indexingPipeline: IndexingPipeline?) {
        self.manifestEntries = manifestEntries
        self.indexingPipeline = indexingPipeline
    }

    func documentAST(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
        asts["\(volumeId)/\(documentId)"]
    }

    func crossReferenceTargets(volumeId: String, documentId: String) async -> [(volumeId: String, documentId: String)]? {
        guard let crossReferences else { return nil }
        return crossReferences["\(volumeId)/\(documentId)"] ?? []
    }

    func highlights(volumeId: String, documentId: String) -> [DocumentHighlightExport] {
        highlightRecords.filter { $0.volumeId == volumeId && $0.documentId == documentId }
    }

    func summary(id: UUID) -> GeneratedSummaryExport? { summaries.first { $0.id == id } }

    func headnoteSummaries(volumeId: String, documentId: String) -> [GeneratedSummaryExport] {
        summaries.filter { $0.volumeId == volumeId && $0.documentId == documentId && $0.isHeadnoteDraft != true }
    }

    func summary(volumeId: String, documentId: String, promptId: UUID) -> GeneratedSummaryExport? {
        // The protocol's contract since L34: the newest under the prompt, by `SummaryRecency`.
        SummaryRecency.newest(summaries.filter {
            $0.volumeId == volumeId && $0.documentId == documentId && $0.promptId == promptId
        }, recency: { $0.recency })
    }

    func zoteroTags(volumeId: String, documentId: String) -> [String] {
        tagNamesByDocument["\(volumeId)/\(documentId)"] ?? []
    }

    func userTags() -> [UserTagExport] { tags }

    func tagAssignments() -> [DocumentTagAssignmentExport] { assignments }

    func smartDocumentRefs() async throws -> [SmartCollectionDocumentRef] { smartRefs }

    func prepareVolumesForExport(_ volumeIds: Set<String>) async { preparedVolumeIds.append(volumeIds) }

    func fetchAbsentFigureImages(_ images: [FigureImageName]) async { fetchedImages.append(images) }

    func generateSummaries(for documents: [CollectionExportDocument], promptId: UUID,
                           bodyTexts: [String: String]) async throws -> [String: GeneratedSummaryExport] {
        generationPrompts.append(promptId)
        var result: [String: GeneratedSummaryExport] = [:]
        for doc in documents {
            let key = "\(doc.volumeId)/\(doc.documentId)"
            guard let text = generated[key] else { throw ExportError.renderingFailed }
            result[key] = GeneratedSummaryExport(id: UUID(), documentId: doc.documentId, volumeId: doc.volumeId,
                                                 promptId: promptId, responseText: text,
                                                 responseFormat: generatedFormat, wasChunked: false)
        }
        return result
    }

    /// The store over the fixture volume in `directory`: indexed by the kit's pipeline, each document
    /// parsed by the kit's parser, the fixture records, and d7's cross-reference to d8.
    static func make(in directory: URL) async throws -> FixtureContentStore {
        let volumes = directory.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let volumeURL = try CollectionResolutionFixtures.writeVolume(to: volumes)
        let (pipeline, _) = try await makeTestPipeline(dir: directory, volumesDir: volumes)
        try await pipeline.indexVolume(CollectionResolutionFixtures.volume)
        let manifest = try testManifestEntries().filter { $0.volumeId == CollectionResolutionFixtures.volume }
        let store = FixtureContentStore(manifestEntries: manifest, indexingPipeline: pipeline)
        for doc in CollectionResolutionFixtures.documents {
            store.asts["\(CollectionResolutionFixtures.volume)/\(doc.id)"] =
                try await FRUSDocumentParser().parseDocument(documentId: doc.id, volumeURL: volumeURL)
        }
        let volume = CollectionResolutionFixtures.volume
        store.crossReferences = ["\(volume)/d7": [(volume, "d8"), (volume, "d7"), (volume, "d42")]]
        store.archivalIndexes = try CollectionResolutionFixtures.archivalIndexes()
        store.highlightRecords = [
            DocumentHighlightExport(id: CollectionResolutionFixtures.highlightKept, volumeId: volume,
                                    documentId: "d7", startOffset: 4, endOffset: 13, colorTag: "pink",
                                    selectedText: "Ambassador", renderingVersion: "v"),
            DocumentHighlightExport(id: CollectionResolutionFixtures.highlightLeft, volumeId: volume,
                                    documentId: "d7", startOffset: 20, endOffset: 30, colorTag: "blue",
                                    selectedText: "Foreign", renderingVersion: "v"),
        ]
        store.summaries = [
            CollectionResolutionFixtures.summary("d8", prompt: CollectionResolutionFixtures.promptB,
                                                 "The other prompt's summary."),
            CollectionResolutionFixtures.summary("d8", prompt: CollectionResolutionFixtures.promptA,
                                                 "The proclamation was agreed.", authorship: .userWritten),
            CollectionResolutionFixtures.summary("d9", prompt: CollectionResolutionFixtures.promptA,
                                                 "A private draft.", draft: true),
        ]
        store.tags = [UserTagExport(id: CollectionResolutionFixtures.tagUnused, name: "Berlin"),
                      UserTagExport(id: CollectionResolutionFixtures.tagQuarantine, name: "Quarantine")]
        store.assignments = [DocumentTagAssignmentExport(id: UUID(), volumeId: volume, documentId: "d9",
                                                         tagId: CollectionResolutionFixtures.tagQuarantine)]
        store.tagNamesByDocument = ["\(volume)/d7": ["Quarantine"]]
        return store
    }
}

/// Runs `body` in a fresh temporary directory, removed afterwards — on the main actor, where the store is.
@MainActor
private func withResolutionDirectory<T>(_ body: @MainActor (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSResolutionTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

// MARK: - A plain dump of resolved items

/// Every resolved item, one field to a line, so a pin's failure shows what moved.
enum ResolvedItemsDump {
    static func text(of items: [CollectionExportItem]) -> String {
        items.map(text(of:)).joined(separator: "\n")
    }

    /// A summary's format after its text: nothing for `.general`, which every pinned summary is, so the
    /// pin taken before the formats were carried (2026-10-31) still holds; a structured one's field names.
    static func format(_ format: ResponseFormat) -> String {
        guard case .structured(let schema) = format else { return "" }
        return " structured(\(schema.fields.map(\.name).joined(separator: ",")))"
    }

    static func text(of item: CollectionExportItem) -> String {
        switch item {
        case .heading(let title, let level):
            return "heading \(level) \(title.debugDescription)"
        case .prose(let paragraphs):
            return "prose " + paragraphs.map { $0.map { "\($0.text)\($0.bold ? "*" : "")" }.joined() }
                .joined(separator: " ¶ ")
        case .excerpt(let excerpt):
            return "excerpt \(excerpt.text.debugDescription) \(excerpt.volumeId)/\(excerpt.documentId) "
                + "color=\(excerpt.colorTag ?? "-") citation=\(excerpt.citation)"
        case .generated(let block):
            return "block \(block.type.rawValue) \(block.title)\n" + block.rows.map {
                "  " + String(repeating: "  ", count: $0.indentLevel) + $0.text
                    + ($0.secondaryText.map { " | \($0)" } ?? "") + ($0.url.map { " <\($0)>" } ?? "")
            }.joined(separator: "\n")
        case .document(let doc):
            var lines = ["document \(doc.volumeId)/\(doc.documentId) #\(doc.sortOrder) depth=\(doc.bodyDepth.rawValue)"]
            lines.append("  title=\(doc.title) override=\(doc.titleOverride ?? "-") date=\(doc.date ?? "-")")
            lines.append("  citation=\(doc.citation)")
            lines.append("  short=\(doc.shortCitation)")
            lines.append("  header=\(doc.header) dateline=\(doc.dateline ?? "-")")
            lines.append("  body=\(doc.bodyText.prefix(60).debugDescription) model=\(doc.renderModel != nil)")
            lines.append("  notes=\(doc.noteTexts)")
            lines.append("  highlights=\(doc.highlights.map { "\($0.startOffset)-\($0.endOffset) \($0.color.rawValue)" })")
            lines.append("  source=\(doc.sourceNoteText ?? "-")")
            lines.append("  headnote=\(doc.includeHeadnote) \(doc.headnoteText ?? "-") \(doc.headnoteAuthorship.rawValue)"
                + format(doc.headnoteFormat))
            lines.append("  summary=\(doc.summaryText ?? "-")" + format(doc.summaryFormat))
            lines.append("  overrides hl=\(String(describing: doc.applyHighlightsOverride)) "
                + "notes=\(String(describing: doc.includeNotesOverride)) "
                + "fn=\(String(describing: doc.includeFootnotesOverride)) "
                + "prompt=\(doc.summaryPromptIdOverride?.uuidString ?? "-")")
            lines.append("  related=\(doc.relatedDocumentCitations)")
            if let item = doc.zoteroItem {
                lines.append("  zotero=\(item.title) | \(item.date ?? "-") | \(item.extra ?? "-") | "
                    + "tags=\((item.tags ?? []).map(\.tag)) notes=\((item.notes ?? []).map(\.note))")
            } else {
                lines.append("  zotero=-")
            }
            return lines.joined(separator: "\n")
        }
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - CollectionResolutionTests

/// A collection resolves through a data source the host supplies, as values: FRUSCoreKit's
/// `CollectionContentAssembly`, over a fixture volume the kit indexed and a store of records.
@Suite("Collection resolution through a data source")
@MainActor
struct CollectionResolutionTests {

    let enUS = Locale(identifier: "en_US")

    func assembly(_ collection: CollectionExport, store: FixtureContentStore,
                  notes: [ResearchNoteExport] = CollectionResolutionFixtures.notes) -> CollectionContentAssembly {
        CollectionContentAssembly(collection: collection, notes: notes, source: store, locale: enUS)
    }

    @Test("A static collection's preview resolves every entry through the store, each rule as the app's")
    func staticPreview() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let collection = CollectionResolutionFixtures.staticCollection()
            let items = try await assembly(collection, store: store).resolve(
                entries: CollectionResolutionFixtures.entries(of: collection),
                introduction: [[ProseFormattedSpan(text: "Introduction.", bold: false, italic: false,
                                                   underline: false, colorHex: nil, linkURL: nil)]],
                purpose: .preview)

            // The introduction leads; the untitled sub-section stays in a preview; the newer build's
            // block, kind and the id-less document are skipped.
            #expect(items.count == 12, "\(ResolvedItemsDump.text(of: items))")
            guard case .prose(let intro) = items.first else { Issue.record("no introduction first"); return }
            #expect(intro.first?.first?.text == "Introduction.")
            let docs = items.documents
            #expect(docs.map(\.documentId) == ["d7", "d8", "d9"])

            let d7 = docs[0]
            // Section defaults reach the document: highlights (only the one it picked), its source note
            // from the index, the "See also:" line to d8 alone (self and a non-member left out).
            #expect(d7.highlights.map(\.startOffset) == [4] && d7.highlights.first?.color == .pink)
            #expect(d7.applyHighlightsOverride == true)
            #expect(d7.noteTexts == ["The Ambassador's account matches the French record."])
            #expect(d7.sourceNoteText?.contains("Lot 72 D 316") == true, "\(d7.sourceNoteText ?? "nil")")
            #expect(d7.relatedDocumentCitations.count == 1)
            // By its short form since L49: the collection prints d8 in full.
            #expect(d7.relatedDocumentCitations == ["_FRUS_, 1961–1963, vol. XI, doc. 8."],
                    "\(d7.relatedDocumentCitations)")
            // The render model is the store's AST, converted; the header is the one reading of its head, the
            // volume's number kept and the source note's call left out, and since L34 (#1994) the dateline is
            // read inside the opener, where it had been read at the top level alone and so as absent.
            #expect(d7.renderModel != nil && d7.header == "7. Telegram From the Embassy in France to the Department of State")
            #expect(d7.dateline == "Paris, October 22, 1962, 5 p.m.")
            // The record's title names the number once (decision 165), and its date line is the dateline (198).
            #expect(d7.zoteroItem?.title == "Document 7: Telegram From the Embassy in France to the Department of State")
            #expect(d7.zoteroItem?.extra == "Document date: Paris, October 22, 1962, 5 p.m.")
            #expect(d7.zoteroItem?.tags?.map(\.tag) == ["Quarantine"])
            #expect(d7.citation.contains("Document 7"), "\(d7.citation)")

            let d8 = docs[1]
            // The legacy note link, the headnote falling back from a gone summary to the collection
            // prompt's (written by the researcher), and the title override.
            #expect(d8.noteTexts == ["Compare the proclamation's draft."])
            #expect(d8.includeHeadnote && d8.headnoteText == "The proclamation was agreed.")
            #expect(d8.headnoteAuthorship == .userWritten)
            #expect(d8.titleOverride == "The proclamation memorandum")

            let d9 = docs[2]
            // The untitled sub-section's index depth; all of d9's own notes but the empty one; no
            // highlights below full depth.
            #expect(d9.bodyDepth == .index)
            #expect(d9.noteTexts == ["The first letter of the exchange."])
            #expect(d9.highlights.isEmpty)

            let headings = items.compactMap { item -> (String, Int)? in
                if case .heading(let title, let level) = item { return (title, level) } else { return nil }
            }
            #expect(headings.map(\.0) == ["The Crisis", "  "] && headings.map(\.1) == [1, 2])

            let excerpt = items.compactMap { item -> CollectionExportExcerpt? in
                if case .excerpt(let e) = item { return e } else { return nil }
            }.first
            #expect(excerpt?.colorTag == "green" && excerpt?.citation.contains("Document 7") == true)

            let blocks = items.compactMap { item -> CollectionGeneratedBlock? in
                if case .generated(let b) = item { return b } else { return nil }
            }
            #expect(blocks.map(\.type) == [.bibliography, .chronology, .archivalSources, .thematicIndex])
            let chronology = try #require(blocks.first { $0.type == .chronology })
            #expect(chronology.rows.first?.text == "October 22, 1962", "\(chronology.rows.map(\.text))")
            let archival = try #require(blocks.first { $0.type == .archivalSources })
            #expect(archival.rows.contains { $0.url == "https://catalog.archives.gov/id/1234567" },
                    "the lot the central-files index answers carries its link: \(archival.rows.map(\.text))")
            let thematic = try #require(blocks.first { $0.type == .thematicIndex })
            #expect(thematic.rows.map(\.text) == ["Quarantine", "Document 7", "Document 9"],
                    "the tag reaches d7 through its note and d9 through an assignment; Berlin reaches none")

            // Nothing an export does was asked of the store.
            #expect(store.preparedVolumeIds.isEmpty && store.fetchedImages.isEmpty && store.generationPrompts.isEmpty)
        }
    }

    @Test("An export leaves out the untitled section, readies the documents' volumes and asks for printed figures")
    func staticExport() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let collection = CollectionResolutionFixtures.staticCollection()
            let items = try await assembly(collection, store: store).resolve(
                entries: CollectionResolutionFixtures.entries(of: collection), introduction: nil,
                purpose: .export, printsFigureImages: true)
            let headings = items.compactMap { item -> String? in
                if case .heading(let title, _) = item { return title } else { return nil }
            }
            #expect(headings == ["The Crisis"], "an export leaves out a heading saved with no text")
            // The dropped heading's index depth still reaches d9.
            #expect(items.documents.first { $0.documentId == "d9" }?.bodyDepth == .index)
            // Document entries only: the excerpt's volume is provenance. The document entry with no ids
            // is asked for too, as an empty volume id, as the app's resolver always asked.
            #expect(store.preparedVolumeIds == [[CollectionResolutionFixtures.volume, ""]])
            // d7 is the one document at full depth with a figure.
            #expect(store.fetchedImages.count == 1)
            #expect(store.fetchedImages.first?.map(\.graphic) == ["fig1"], "\(store.fetchedImages)")
        }
    }

    /// 2026-10-31: the exporters print a structured summary as its fields, so the format it was written
    /// in must reach them from every place a summary comes from: a headnote, a stored summary attached to
    /// a preview, and a summary the store answers an export with. Until then the copy the summary phase
    /// makes (`withSummary`) also dropped the headnote's authorship, so a summary-depth document's
    /// headnote the reader had written was labelled AI-generated.
    @Test("A summary's format reaches its headnote and its summary body, and the headnote keeps its authorship")
    func summaryFormatAndHeadnoteAuthorship() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let schema = StructuredSummarySchema(fields: [.init(name: "Subject", description: ""),
                                                          .init(name: "Outcome", description: "")])
            let json = #"{"Outcome": "Agreed.", "Subject": "The proclamation"}"#
            let structured = ResponseFormat.structured(schema: schema)
            // d8's summary under the collection's prompt, which is its headnote too, structured.
            store.summaries = store.summaries.map { summary in
                guard summary.documentId == "d8", summary.promptId == CollectionResolutionFixtures.promptA
                else { return summary }
                var record = summary
                record.responseText = json
                record.responseFormat = structured
                return record
            }
            let collection = CollectionResolutionFixtures.staticCollection(defaultBodyDepth: "summaryOnly")
            let entries = CollectionResolutionFixtures.entries(of: collection)

            let preview = try await assembly(collection, store: store)
                .resolve(entries: entries, introduction: nil, purpose: .preview)
            let d8 = try #require(preview.documents.first { $0.documentId == "d8" })
            #expect(d8.headnoteText == json && d8.headnoteFormat == structured)
            #expect(d8.summaryText == json && d8.summaryFormat == structured)
            #expect(d8.headnoteAuthorship == .userWritten, "the summary phase dropped the headnote's authorship")
            #expect(ResolvedItemsDump.text(of: [.document(d8)])
                        .contains("  summary=\(json) structured(Subject,Outcome)"))

            // One entry at a time, as the preview refreshes a row.
            let d8Entry = try #require(entries.first { $0.documentId == "d8" })
            let single = try #require(await assembly(collection, store: store).resolveItem(d8Entry))
            guard case .document(let refreshed) = single else { Issue.record("not a document"); return }
            #expect(refreshed.summaryFormat == structured && refreshed.headnoteFormat == structured)

            store.generated = ["\(CollectionResolutionFixtures.volume)/d7": json,
                               "\(CollectionResolutionFixtures.volume)/d8": json]
            store.generatedFormat = structured
            let export = try await assembly(collection, store: store)
                .resolve(entries: entries, introduction: nil, purpose: .export)
            #expect(export.documents.filter { $0.bodyDepth == .summaryOnly }.map(\.summaryFormat)
                        == [structured, structured])
            #expect(export.documents.first { $0.documentId == "d8" }?.headnoteAuthorship == .userWritten)

            // And the page prints the fields, not the JSON.
            let html = CollectionItemHTMLRenderer(options: CollectionExportOptions())
                .pageHTML(metadata: CollectionExportMetadata(name: "Fields", note: nil), items: export)
            #expect(html.contains("<p><strong>Subject:</strong> The proclamation</p>"))
            #expect(html.contains("<p><em><strong>Outcome:</strong> Agreed.</em></p>"))
            #expect(!html.contains("{&quot;Outcome&quot;"), "the stored JSON is printed")
        }
    }

    @Test("The summary phase attaches stored summaries to a preview and asks the store for an export's")
    func summaryPhase() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let summaryCollection = CollectionResolutionFixtures.staticCollection(defaultBodyDepth: "summaryOnly")
            let entries = CollectionResolutionFixtures.entries(of: summaryCollection)
            let preview = try await assembly(summaryCollection, store: store)
                .resolve(entries: entries, introduction: nil, purpose: .preview)
            let previewSummaries = preview.documents.map { "\($0.documentId)=\($0.summaryText ?? "-")" }
            // d8 has a summary under the collection's prompt; d7 none; d9 is at index depth.
            #expect(previewSummaries == ["d7=-", "d8=The proclamation was agreed.", "d9=-"], "\(previewSummaries)")

            store.generated = ["\(CollectionResolutionFixtures.volume)/d7": "Generated for d7",
                               "\(CollectionResolutionFixtures.volume)/d8": "The proclamation was agreed."]
            let export = try await assembly(summaryCollection, store: store)
                .resolve(entries: entries, introduction: nil, purpose: .export)
            #expect(export.documents.map { $0.summaryText ?? "-" }
                        == ["Generated for d7", "The proclamation was agreed.", "-"])
            #expect(store.generationPrompts == [CollectionResolutionFixtures.promptA])

            // No prompt anywhere: an export refuses with the app's error; a preview shows placeholders.
            let promptless = CollectionResolutionFixtures.staticCollection(defaultBodyDepth: "summaryOnly",
                                                                          summaryPromptId: nil)
            await #expect(throws: CollectionResolveError.self) {
                try await assembly(promptless, store: store).resolve(
                    entries: CollectionResolutionFixtures.entries(of: promptless), introduction: nil,
                    purpose: .export)
            }
            let placeholders = try await assembly(promptless, store: store).resolve(
                entries: CollectionResolutionFixtures.entries(of: promptless), introduction: nil, purpose: .preview)
            #expect(placeholders.documents.allSatisfy { $0.summaryText == nil })
        }
    }

    @Test("A smart collection resolves its saved search's results, with its blocks around them")
    func smartCollection() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let volume = CollectionResolutionFixtures.volume
            store.smartRefs = [SmartCollectionDocumentRef(documentId: "d9", volumeId: volume, sortOrder: 0),
                               SmartCollectionDocumentRef(documentId: "d7", volumeId: volume, sortOrder: 1)]
            var smart = CollectionResolutionFixtures.staticCollection()
            smart.savedSearchId = UUID()
            smart.applyHighlights = true
            smart.includeSourceNote = true
            smart.entries = [
                CollectionResolutionFixtures.entry(0, kind: .generated) {
                    $0.generatedBlockType = CollectionGeneratedBlockType.bibliography.rawValue
                },
                CollectionResolutionFixtures.entry(1, kind: .generated) {
                    $0.generatedBlockType = CollectionGeneratedBlockType.chronology.rawValue
                },
                // Left from before the link: its section defaults would turn both off, and reach no result.
                CollectionResolutionFixtures.entry(2, kind: .heading, text: "Before the link") {
                    $0.applyHighlightsOverride = false
                    $0.includeSourceNoteOverride = false
                },
            ]
            let items = try await assembly(smart, store: store)
                .resolve(entries: [], introduction: nil, purpose: .export)
            let kinds = items.map { item -> String in
                switch item {
                case .generated(let b): return b.type.rawValue
                case .document(let d): return d.documentId
                default: return "other"
                }
            }
            // The chronology is front matter, the bibliography back matter.
            #expect(kinds == ["chronology", "d9", "d7", "bibliography"], "\(kinds)")
            // A smart document takes every note and highlight on its document and the collection's
            // composition, and no heading's section defaults.
            let d7 = try #require(items.documents.first { $0.documentId == "d7" })
            #expect(d7.noteTexts == ["The Ambassador's account matches the French record."])
            #expect(d7.highlights.map(\.startOffset) == [4, 20] && d7.applyHighlightsOverride == nil)
            #expect(d7.sourceNoteText?.contains("Lot 72 D 316") == true)
            // A smart collection's volumes come from the index: nothing to ready.
            #expect(store.preparedVolumeIds.isEmpty)

            // The preview's capped path computes the blocks over the full result set.
            let capped = await assembly(smart, store: store)
                .resolveSmartItems(Array(store.smartRefs.prefix(1)), fullRefs: store.smartRefs)
            let bibliography = capped.compactMap { item -> CollectionGeneratedBlock? in
                if case .generated(let b) = item, b.type == .bibliography { return b } else { return nil }
            }.first
            #expect(bibliography?.rows.count == 2, "\(bibliography?.rows.map(\.text) ?? [])")
            #expect(capped.documents.map(\.documentId) == ["d9"])
        }
    }

    @Test("Documents-only and single-entry resolves agree with a full one")
    func documentsAndSingleItem() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let collection = CollectionResolutionFixtures.staticCollection()
            let entries = CollectionResolutionFixtures.entries(of: collection)
            let assembled = assembly(collection, store: store)
            let documents = try await assembled.resolveDocuments(entries: entries, purpose: .preview)
            #expect(documents.map(\.documentId) == ["d7", "d8", "d9"])
            let single = await assembled.resolveItem(entries[2])
            guard case .document(let d8) = single else { Issue.record("d8 did not resolve"); return }
            #expect(d8.headnoteText == documents[1].headnoteText && d8.citation == documents[1].citation)
            // A single entry knows no section: d7 alone takes no section default.
            guard case .document(let d7) = await assembled.resolveItem(entries[1]) else {
                Issue.record("d7 did not resolve"); return
            }
            #expect(d7.highlights.isEmpty && d7.sourceNoteText == nil)
            #expect(await assembled.resolveItem(entries[11]) == nil, "a newer build's block type")
        }
    }

    /// R2b's finding, taken by L34: a headnote with no summary of its own printed the first summary the
    /// store returned, which in the app is the oldest, where the document's rail shows the newest.
    @Test("A headnote whose summary is gone prints the newest stored, under the collection's prompt where it has one (L34)")
    func headnoteFallsBackToTheNewest() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
            func made(_ text: String, prompt: UUID, day: Double) -> GeneratedSummaryExport {
                var summary = CollectionResolutionFixtures.summary("d8", prompt: prompt, text)
                summary.createdAt = start.addingTimeInterval(day * 86_400)
                return summary
            }
            let (a, b) = (CollectionResolutionFixtures.promptA, CollectionResolutionFixtures.promptB)
            // Stored oldest first, as the app's store returns them. d8's entry chose a summary that is gone.
            store.summaries = [made("The oldest.", prompt: b, day: 0), made("Older, under A.", prompt: a, day: 1),
                               made("Newer, under A.", prompt: a, day: 2), made("The newest.", prompt: b, day: 3)]
            func headnote(_ prompt: UUID?) async throws -> String? {
                let collection = CollectionResolutionFixtures.staticCollection(summaryPromptId: prompt)
                let items = try await assembly(collection, store: store).resolve(
                    entries: CollectionResolutionFixtures.entries(of: collection), introduction: nil, purpose: .preview)
                return items.documents.first { $0.documentId == "d8" }?.headnoteText
            }
            let underTheCollectionsPrompt = try await headnote(a)
            let withNoPrompt = try await headnote(nil)
            #expect(underTheCollectionsPrompt == "Newer, under A.")
            #expect(withNoPrompt == "The newest.")
        }
    }

    /// The whole static preview as text, pinned: the same values resolve the same items wherever the
    /// kit runs. Re-take the pin from the failure message when a change means to move a line, and say why.
    @Test("The fixture collection resolves to the pinned items")
    func pinnedItems() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let collection = CollectionResolutionFixtures.staticCollection()
            let items = try await assembly(collection, store: store).resolve(
                entries: CollectionResolutionFixtures.entries(of: collection), introduction: nil, purpose: .preview)
            let dump = ResolvedItemsDump.text(of: items)
            let digest = ResolvedItemsDump.sha256(dump)
            #expect(digest == Self.pinnedItemsDigest, "\(digest), \(dump.utf8.count) bytes:\n\(dump)")
        }
    }

    /// The dump's SHA-256, 5,031 bytes, taken on macOS 27.2 in SwiftPM by L49 (2026-11-28).
    ///
    /// Re-taken by L49, because a collection names one of its documents again by the short form ("Wherever a document
    /// repeats"), and the dump prints each document's new `shortCitation`. The 630 bytes fewer are those lines alone:
    /// three `short=` lines, 46 bytes each, added (138); and four full citations of 229 bytes become short forms of 37
    /// (768 fewer): d7's See also line, which names d8, and the Chronology's three rows. The dump of 2026-11-27 was 5,661
    /// bytes, `2cfd6772…9b76b88`.
    ///
    /// Taken by L34 on macOS 27.2 in Xcode and SwiftPM alike (2026-11-27), because a document's heading and dateline are
    /// read once, from its parse
    /// (`DocumentHeadingReading`), and its record from that reading (decisions 165 and 198). The 137 bytes
    /// added are those lines alone: `d7`'s and `d8`'s datelines, which the opener holds and the old reading
    /// left `-` (#1994), 58 bytes; their records' *Document date:* lines, 88; and three records' titles that
    /// name the document's number once, "Document 7: Telegram From…" for "Document 7: 7. Telegram From…"
    /// (#2002), 9 fewer. The dump of 2026-10-27 was 5,524 bytes, `1f15f3dd…aad04a9`.
    static let pinnedItemsDigest = "48e8f9ad99e60dfbb14bf49f76fc9beab09d6e12b7e9e03b996d29439a89687c"
}

// MARK: - The values' rules

@Suite("Collection values: composition, depth, snapshot and the native file")
struct CollectionValuesTests {

    @Test("Composition reads from values as the model's effective accessors read the legacy footnote style")
    func compositionFromValues() {
        var collection = CollectionResolutionFixtures.staticCollection()
        collection.footnoteStyle = "sourceNoteOnly"
        collection.includeFootnotes = nil
        collection.includeSourceNote = nil
        let derived = CollectionExportOptions(composing: collection)
        #expect(!derived.includeFootnotes && derived.includeSourceNote)
        collection.includeFootnotes = true
        let explicit = CollectionExportOptions(composing: collection)
        #expect(explicit.includeFootnotes && explicit.includeSourceNote)
        // A record from before format version 7 carries no composition: the model's defaults.
        let bare = CollectionExportOptions(composing: CollectionExport(id: UUID(), name: "Old", projectIds: [],
                                                                      entries: []))
        #expect(bare.tocStyle == .citation && bare.includeFootnotes && !bare.includeSourceNote
                && bare.includeNotes && !bare.applyHighlights && !bare.includeWordCloud && !bare.includeHeadnoteDefault)
        #expect(CollectionFootnoteStyle.bestFitRawValue(footnotes: true, sourceNote: true) == "all")
        #expect(CollectionFootnoteStyle.derivedFlags(fromStyleRawValue: "unknown") == (true, false))
    }

    @Test("Summary-only depth is offered only where summaries can be had")
    func summaryAvailability() {
        #expect(CollectionBodyDepth.available(summariesAvailable: true) == [.full, .summaryOnly, .index])
        #expect(CollectionBodyDepth.available(summariesAvailable: false) == [.full, .index])
    }

    @Test("A snapshot copies the smart collection's name, note, projects and composition, with one entry per result")
    func snapshotValues() {
        // Since L29 (J39) the fixture's apparatus blocks travel too, its Chronology before the results and the
        // rest after; `snapshotCarriesSettingsAndBlocks` holds them.
        var smart = CollectionResolutionFixtures.staticCollection()
        smart.name = "  Missiles  "
        smart.note = "Searches for missiles."
        smart.projectIds = [UUID()]
        smart.savedSearchId = UUID()
        smart.includeFootnotes = false
        let snapshot = SmartCollectionSnapshot.snapshot(of: smart, results: [("d8", "v1"), ("d2", "v2")])
        #expect(snapshot.name == "Missiles (Snapshot)" && snapshot.note == smart.note)
        #expect(snapshot.projectIds == smart.projectIds && snapshot.savedSearchId == nil)
        #expect(snapshot.includeFootnotes == false && snapshot.summaryPromptId == smart.summaryPromptId)
        #expect(snapshot.defaultBodyDepth == smart.defaultBodyDepth && snapshot.footnoteStyle == smart.footnoteStyle
                && snapshot.tocStyle == smart.tocStyle && snapshot.includeNotes == smart.includeNotes)
        #expect(snapshot.entries.filter { $0.entryKind == .document }
                    .map { "\($0.volumeId)/\($0.documentId)#\($0.sortOrder)" } == ["v1/d8#1", "v2/d2#2"])
        #expect(snapshot.entries.map(\.entryKind)
                == [.generated, .document, .document, .generated, .generated, .generated, .generated])
        #expect(SmartCollectionSnapshot.snapshotName("   ") == "Smart Collection (Snapshot)")
        #expect(SmartCollectionSnapshot.resultLimit == 1_000)
    }

    /// The design's §4.5: a snapshot carries every setting of the smart collection and its own blocks
    /// (#1996), each in its place (the third review's J39). Until L29 it carried the composition alone,
    /// and no block, so a smart collection that printed a Chronology made a snapshot that printed none.
    /// A smart collection prints its front-matter blocks before the search's documents and the rest
    /// after (`CollectionContentAssembly.resolveSmartItems`), so the snapshot puts them there. The
    /// entries it held before its link, which nothing it produces prints, stay behind.
    @Test("A snapshot carries every setting and the smart collection's own blocks in their places (#1996, J39)")
    func snapshotCarriesSettingsAndBlocks() {
        typealias R = CollectionResolutionFixtures
        func block(_ sortOrder: Int, _ type: String) -> CollectionEntryExport {
            R.entry(sortOrder, kind: .generated) { $0.generatedBlockType = type }
        }
        let smart = CollectionExport(
            id: UUID(), name: "Missiles", note: "Searches for missiles.", projectIds: [UUID()],
            savedSearchId: UUID(),
            entries: [
                R.entry(0, kind: .document, document: "d1"),
                block(1, CollectionGeneratedBlockType.bibliography.rawValue),
                R.entry(2, kind: .heading, text: "Added before the link"),
                block(3, CollectionGeneratedBlockType.chronology.rawValue),
                block(4, "atlas"),
                block(5, CollectionGeneratedBlockType.personsIndex.rawValue),
            ],
            createdAt: Date(timeIntervalSince1970: 1_790_000_000),
            lastModified: Date(timeIntervalSince1970: 1_790_000_100),
            subtitle: "A reader", authorLine: "A. Researcher", introductionText: "An introduction.",
            introductionRichText: Data("{\\rtf1 An introduction.}".utf8),
            includeColophon: true, includeProjectProvenance: true, includeMethodAppendix: true,
            defaultBodyDepth: "index", footnoteStyle: "none", includeFootnotes: false, includeSourceNote: true,
            tocStyle: "headerAndDateline", applyHighlights: true, includeNotes: false, includeWordCloud: true,
            defaultIncludeHeadnote: true, summaryPromptId: UUID())
        let snapshot = SmartCollectionSnapshot.snapshot(of: smart, results: [("d8", "v1"), ("d2", "v2")])

        // Every setting, but the link, the name and the dates.
        var expected = smart
        expected.id = snapshot.id
        expected.name = "Missiles (Snapshot)"
        expected.savedSearchId = nil
        expected.createdAt = snapshot.createdAt
        expected.lastModified = snapshot.lastModified
        expected.entries = snapshot.entries
        #expect(snapshot == expected)
        #expect(snapshot.createdAt == nil && snapshot.lastModified == nil, "the host stamps a new collection's dates")

        // The Chronology before the documents, the rest after them in their order, a block type this build
        // does not know among them; nothing from before the link.
        #expect(snapshot.entries.map { $0.generatedBlockType ?? "\($0.volumeId)/\($0.documentId)" }
                == ["chronology", "v1/d8", "v2/d2", "bibliography", "atlas", "personsIndex"])
        #expect(snapshot.entries.map(\.sortOrder) == Array(0..<6))
        let sources = Set(smart.entries.map(\.id))
        #expect(snapshot.entries.allSatisfy { !sources.contains($0.id) }, "a carried block keeps its source's id")
    }

    #if !SWIFT_PACKAGE // `SearchViewModel` is the app's
    /// The kit's limit is the one the app passes, the iOS search's ceiling, so a change to either fails here.
    @Test("A smart collection resolves at the iOS search's ceiling, which the app passes")
    @MainActor
    func resultLimitIsTheSearchCeiling() {
        #expect(SmartCollectionSnapshot.resultLimit == SearchViewModel.searchHardLimit)
    }
    #endif

    @Test("A .fruscollection file writes from values and imports back into values")
    func nativeFileRoundTrip() throws {
        let collection = CollectionResolutionFixtures.staticCollection()
        let file = NativeCollectionSerializer.makeFile(from: collection, includeNotes: true) { entry in
            entry.documentId == "d7" ? ["A note that travels.", ""] : []
        }
        // Excerpts, blocks, levels and overrides make it a v2 file a v1 reader can open.
        #expect(file.formatVersion == 2 && file.minimumReaderVersion == 1)
        // The newer build's kind is left out of the file; its unknown block type travels.
        #expect(file.entries.count == 13)
        #expect(file.entries.contains { $0.kind == "generated" && $0.generatedBlockType == "atlas" })
        #expect(file.entries.first { $0.documentId == "d7" }?.notes == ["A note that travels."])
        #expect(file.entries.first { $0.kind == "heading" && $0.text == "  " }?.level == 2)

        let decoded = try NativeCollectionSerializer.decode(try NativeCollectionSerializer.encode(file))
        #expect(decoded == file)
        var ids = 0
        let imported = NativeCollectionSerializer.importedValues(from: decoded) {
            ids += 1
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", ids))!
        }
        #expect(imported.collection.name == "Missiles")
        #expect(imported.collection.entries.map(\.sortOrder) == Array(0..<13))
        #expect(imported.notes.map(\.bodyText) == ["A note that travels."])
        let d7 = try #require(imported.collection.entries.first { $0.documentId == "d7" && $0.entryKind == .document })
        #expect(d7.selectedNoteIds == imported.notes.map(\.id))
        #expect(d7.selectedHighlightIds == [], "device-local highlight ids never travel")
        let heading = try #require(imported.collection.entries.first { $0.entryKind == .heading })
        #expect(heading.applyHighlightsOverride == true && heading.includeRelatedDocuments == true)
        #expect(imported.collection.summaryPromptId == nil && imported.collection.projectIds.isEmpty)
        // Written again, the import makes the same file but for the notes, which it pinned to its entries.
        let again = NativeCollectionSerializer.makeFile(from: imported.collection, includeNotes: false) { _ in [] }
        func withoutNotes(_ entries: [FRUSCollectionFile.Entry]) -> [FRUSCollectionFile.Entry] {
            entries.map { var entry = $0; entry.notes = nil; return entry }
        }
        #expect(withoutNotes(again.entries) == withoutNotes(file.entries))
        var expected = file
        expected.entries = withoutNotes(file.entries)
        #expect(again == expected)
    }

    @Test("A collection that uses no v2 feature writes a v1 file, and a newer reader's file is refused")
    func writeMinimumAndTheGate() throws {
        let plain = CollectionExport(
            id: UUID(), name: "Plain", projectIds: [],
            entries: [CollectionResolutionFixtures.entry(0, kind: .document, document: "d7"),
                      CollectionResolutionFixtures.entry(1, kind: .heading, text: "Part")],
            defaultBodyDepth: "full", footnoteStyle: "all", tocStyle: "citation", applyHighlights: false,
            includeNotes: true, includeWordCloud: false, defaultIncludeHeadnote: false)
        let file = NativeCollectionSerializer.makeFile(from: plain, includeNotes: false) { _ in [] }
        #expect(file.formatVersion == 1 && file.minimumReaderVersion == nil)
        var future = file
        future.formatVersion = 3
        future.minimumReaderVersion = 3
        #expect(throws: NativeCollectionError.self) {
            _ = try NativeCollectionSerializer.decode(try NativeCollectionSerializer.encode(future))
        }
    }

    @Test("A divided lot links nothing; an unknown lot links nothing; a known one links its series")
    func archivalIndexesPassedIn() throws {
        let indexes = try CollectionResolutionFixtures.archivalIndexes()
        #expect(ArchivalResolver.documentResolution(lotFile: "Lot 72 D 316", indexes: indexes)?.naId == "1234567")
        // Central files answers the divided lot, and the claimants index alone refuses it (#1205).
        #expect(ArchivalResolver.documentResolution(lotFile: "64–D 563", indexes: indexes) == nil)
        var undivided = indexes
        undivided.claimants = nil
        #expect(ArchivalResolver.documentResolution(lotFile: "64–D 563", indexes: undivided)?.naId == "7654321")
        #expect(ArchivalResolver.documentResolution(lotFile: "99 D 999", indexes: indexes) == nil)
        #expect(ArchivalResolver.documentResolution(lotFile: "72 D 316", indexes: ArchivalIndexes()) == nil)
    }
}

// MARK: - The newest summary

/// The order a document's summaries are shown and printed in (L34): FRUSCoreKit's `SummaryRecency`, the
/// rule the app's `GeneratedSummary.ranksAbove(_:_:)` reads its records through.
@Suite("A document's summaries, newest first (SummaryRecency)")
struct SummaryRecencyTests {

    /// A summary as the tests store one: its words, its prompt and its place in the order.
    struct Stored {
        let text: String
        let prompt: UUID
        let recency: SummaryRecency
    }

    @Test("Newest first: by when each was made, then when it was last saved, then by id; no date is the oldest")
    func order() throws {
        let early = Date(timeIntervalSinceReferenceDate: 800_000_000), late = early.addingTimeInterval(60)
        let idA = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        let idB = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000B"))
        // When it was made decides, whatever the save stamps say.
        #expect(SummaryRecency(createdAt: late, lastModified: early, id: idB)
            .ranksAbove(SummaryRecency(createdAt: early, lastModified: late, id: idA)))
        // Made together: the later save.
        #expect(SummaryRecency(createdAt: early, lastModified: late, id: idB)
            .ranksAbove(SummaryRecency(createdAt: early, lastModified: early, id: idA)))
        // Alike in both: the id, so that the order is total.
        #expect(SummaryRecency(createdAt: early, lastModified: early, id: idA)
            .ranksAbove(SummaryRecency(createdAt: early, lastModified: early, id: idB)))
        // A summary with no date is the oldest.
        #expect(SummaryRecency(createdAt: early, lastModified: nil, id: idB)
            .ranksAbove(SummaryRecency(createdAt: nil, lastModified: late, id: idA)))
        let same = SummaryRecency(createdAt: early, lastModified: early, id: idA)
        #expect(!same.ranksAbove(same))
    }

    @Test("A headnote falls back to the newest under its prompt, else the newest of all, in whatever order they come")
    func fallback() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let (a, b, unused) = (UUID(), UUID(), UUID())
        func stored(_ text: String, _ prompt: UUID, day: Double) -> Stored {
            Stored(text: text, prompt: prompt,
                   recency: SummaryRecency(createdAt: start.addingTimeInterval(day * 86_400), lastModified: nil, id: UUID()))
        }
        let oldestFirst = [stored("oldest", b, day: 0), stored("older A", a, day: 1), stored("newer A", a, day: 2),
                           stored("newest", b, day: 3)]
        for summaries in [oldestFirst, Array(oldestFirst.reversed()), [oldestFirst[2], oldestFirst[0], oldestFirst[3], oldestFirst[1]]] {
            func pick(_ prompt: UUID?) -> String? {
                SummaryRecency.headnoteFallback(summaries, preferredPromptId: prompt,
                                                promptId: { $0.prompt }, recency: { $0.recency })?.text
            }
            #expect(pick(a) == "newer A")
            #expect(pick(b) == "newest")
            #expect(pick(nil) == "newest")
            #expect(pick(unused) == "newest", "a prompt with nothing stored under it falls back to the newest of all")
            #expect(SummaryRecency.newest(summaries, recency: { $0.recency })?.text == "newest")
        }
        let nothing: [Stored] = []
        #expect(SummaryRecency.headnoteFallback(nothing, preferredPromptId: a, promptId: { $0.prompt },
                                                recency: { $0.recency }) == nil)
    }
}

// MARK: - The new facts through the assembly (L43)

/// A collection's own facts as the assembly resolves them (L43): its citation style in every place a citation
/// prints, a section's headnote default, the collection's See also, and a document's date line.
@Suite("L43: a collection's facts through the assembly")
@MainActor
struct CollectionFactsResolutionTests {

    typealias Fixtures = CollectionResolutionFixtures

    func assembly(_ collection: CollectionExport, store: FixtureContentStore) -> CollectionContentAssembly {
        CollectionContentAssembly(collection: collection, notes: Fixtures.notes, source: store,
                                  locale: Locale(identifier: "en_US"))
    }

    /// The design's §6 and decision 161: a collection in Chicago cites each document in the CMOS FAQ's note, named by
    /// the heading and dateline the index stores, and one document is cited alike wherever it is cited in full: at its
    /// head, in a passage's source line and in the Bibliography's rows. Since L49 the See also line names it by its
    /// short form, in Chicago's arabic figures. The italics the exporters read are `_…_`.
    @Test("A Chicago collection cites each document in the FAQ's note, alike wherever it is cited in full")
    func chicagoEverywhere() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            var collection = Fixtures.staticCollection()
            collection.citationStyle = CitationStyle.chicago.rawValue
            let items = try await assembly(collection, store: store).resolve(
                entries: Fixtures.entries(of: collection), introduction: nil, purpose: .preview)
            let docs = items.documents
            let d7 = try #require(docs.first { $0.documentId == "d7" })
            let d8 = try #require(docs.first { $0.documentId == "d8" })

            #expect(d7.citation == "The Embassy in France to the Department of State, telegram, Paris, October 22, 1962, "
                    + "in _Foreign Relations of the United States, 1961–1963_, ed. David S. Patterson, vol. 11, "
                    + "_Cuban Missile Crisis and Aftermath_, ed. Edward C. Keefer, Charles S. Sampson, and Louis J. Smith "
                    + "(Government Printing Office, 1996), doc. 7.", "\(d7.citation)")
            #expect(!d7.citation.contains("*"), "the exporters read one kind of italics")
            #expect(d8.citation.hasPrefix("The President’s Special Assistant to President Kennedy, memorandum, "
                                          + "Washington, October 23, 1962, in _Foreign Relations"), "\(d8.citation)")

            // The same note wherever the document is cited.
            let excerpt = items.compactMap { item -> CollectionExportExcerpt? in
                if case .excerpt(let e) = item { return e } else { return nil }
            }.first
            #expect(excerpt?.citation == d7.citation)
            #expect(d7.relatedDocumentCitations == [d8.shortCitation])
            #expect(d8.shortCitation == "_FRUS_, 1961–1963, vol. 11, doc. 8.", "\(d8.shortCitation)")
            let bibliography = try #require(items.compactMap { item -> CollectionGeneratedBlock? in
                if case .generated(let b) = item, b.type == .bibliography { return b } else { return nil }
            }.first)
            #expect(bibliography.rows.map(\.text).contains(d7.citation), "\(bibliography.rows.map(\.text))")

            // History at State, 1.0's, for a collection that names no style.
            let plain = try await assembly(Fixtures.staticCollection(), store: store).resolve(
                entries: Fixtures.entries(of: Fixtures.staticCollection()), introduction: nil, purpose: .preview)
            #expect(plain.documents.first?.citation.hasPrefix("_Foreign Relations of the United States_, 1961–1963") == true)
        }
    }

    /// Decision 164 and the third review's J24: a section's headnote default is the heading's own field, read before
    /// the collection's; nested sections inherit it; and a heading's own `includeHeadnote`, which headings made under
    /// the builds of 2026-07-01 to 07-11 hold as an unseen `false`, switches nothing off.
    @Test("A section's headnote default governs its documents; a heading's own includeHeadnote does not (J24)")
    func sectionHeadnoteDefault() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            func collection(defaultHeadnote: Bool, _ entries: [CollectionEntryExport]) -> CollectionExport {
                CollectionExport(id: UUID(), name: "Headnotes", projectIds: [], entries: entries,
                                 defaultIncludeHeadnote: defaultHeadnote, summaryPromptId: Fixtures.promptA)
            }
            func headnotes(_ collection: CollectionExport) async throws -> [Bool] {
                try await assembly(collection, store: store)
                    .resolveDocuments(entries: Fixtures.entries(of: collection), purpose: .preview)
                    .map(\.includeHeadnote)
            }
            // On in the section, inherited by a sub-section; off where the collection's default is.
            let sections = collection(defaultHeadnote: false, [
                Fixtures.entry(0, kind: .heading, text: "On") { $0.headnoteDefault = true },
                Fixtures.entry(1, kind: .document, document: "d8"),
                Fixtures.entry(2, kind: .heading, text: "Inside", level: 2),
                Fixtures.entry(3, kind: .document, document: "d8"),
                Fixtures.entry(4, kind: .heading, text: "Off") { $0.headnoteDefault = false },
                Fixtures.entry(5, kind: .document, document: "d8"),
                Fixtures.entry(6, kind: .document, document: "d8") { $0.includeHeadnote = true },
            ])
            #expect(try await headnotes(sections) == [true, true, false, true], "the document's own setting wins")

            // The legacy explicit false on a heading's includeHeadnote is not a section default.
            let legacy = collection(defaultHeadnote: true, [
                Fixtures.entry(0, kind: .heading, text: "Made on 2026-07-05") { $0.includeHeadnote = false },
                Fixtures.entry(1, kind: .document, document: "d8"),
            ])
            #expect(try await headnotes(legacy) == [true])
        }
    }

    /// Decision 164: See also for the collection prints where neither the document nor its section sets it, and a
    /// section's Off still wins.
    @Test("The collection's See also prints where neither a document nor its section sets it")
    func collectionSeeAlso() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            func related(_ seeAlso: Bool, _ entries: [CollectionEntryExport]) async throws -> [Int] {
                let collection = CollectionExport(id: UUID(), name: "See also", projectIds: [], entries: entries,
                                                  defaultIncludeRelatedDocuments: seeAlso)
                return try await assembly(collection, store: store)
                    .resolveDocuments(entries: Fixtures.entries(of: collection), purpose: .preview)
                    .map(\.relatedDocumentCitations.count)
            }
            let plain = [Fixtures.entry(0, kind: .document, document: "d7"),
                         Fixtures.entry(1, kind: .document, document: "d8")]
            #expect(try await related(false, plain) == [0, 0], "1.0's: off")
            #expect(try await related(true, plain) == [1, 0], "d7 names d8; d8 names nothing")
            let sectionOff = [Fixtures.entry(0, kind: .heading, text: "Off") { $0.includeRelatedDocuments = false },
                              Fixtures.entry(1, kind: .document, document: "d7"),
                              Fixtures.entry(2, kind: .document, document: "d8")]
            #expect(try await related(true, sectionOff) == [0, 0])
        }
    }

    /// Decision 163: an entry's date line reaches its document, which the plan prints under a title alone (J41).
    @Test("An entry's date line reaches its document")
    func dateLine() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let collection = CollectionExport(id: UUID(), name: "Date lines", projectIds: [], entries: [
                Fixtures.entry(0, kind: .document, document: "d8") {
                    $0.titleOverride = "The proclamation"
                    $0.dateLine = "Washington, 23 October 1962"
                },
                Fixtures.entry(1, kind: .heading, text: "A heading's date line is no document's") {
                    $0.dateLine = "Nowhere"
                },
            ])
            let docs = try await assembly(collection, store: store)
                .resolveDocuments(entries: Fixtures.entries(of: collection), purpose: .preview)
            #expect(docs.map(\.dateLine) == ["Washington, 23 October 1962"])
            #expect(docs.first?.printedDateLine == "Washington, 23 October 1962")
        }
    }
}

// MARK: - L49: the short form wherever a collection names a document again

/// The owner's answer for L49, "Wherever a document repeats": a collection names one of its documents again by its short
/// form (`FRUSShortCitation`), in a contents row, on the See also line and in the Chronology's rows, and cites it in
/// full at its head, in a passage's source line and in the Bibliography. Always, with no switch.
@Suite("L49: the short form wherever a collection names a document again")
@MainActor
struct ShortFormPlacesTests {

    typealias Fixtures = CollectionResolutionFixtures

    /// The fixture collection in History at State ("vol. XI") and in Chicago ("vol. 11"), each place read off one
    /// resolve. Before L49 every one of these places printed the full citation.
    @Test("A document is named again by its short form, and cited in full at its head, a passage and the Bibliography",
          arguments: [CitationStyle.historyAtState, .chicago])
    func shortFormWhereADocumentRepeats(style: CitationStyle) async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            var collection = Fixtures.staticCollection()
            collection.citationStyle = style.rawValue
            let items = try await CollectionContentAssembly(collection: collection, notes: Fixtures.notes, source: store,
                                                            locale: Locale(identifier: "en_US"))
                .resolve(entries: Fixtures.entries(of: collection), introduction: nil, purpose: .preview)
            let docs = items.documents
            let volume = style == .historyAtState ? "XI" : "11"
            func short(_ number: String) -> String { "_FRUS_, 1961–1963, vol. \(volume), doc. \(number)." }
            #expect(docs.map(\.shortCitation) == [short("7"), short("8"), short("9")], "\(docs.map(\.shortCitation))")

            // Named again: the contents rows in Citation style, the author's title with the short form under it, the
            // See also line, and every document in the Chronology, dated or not.
            let rows = CollectionContentsRow.rows(for: items, style: .citation).filter { $0.number != nil }
            #expect(rows.map(\.text) == [short("7"), "The proclamation memorandum", short("9")], "\(rows.map(\.text))")
            #expect(rows.dropFirst().first?.lines.last == short("8"), "\(rows.map(\.lines))")
            #expect(docs.first?.relatedDocumentCitations == [short("8")])
            let chronology = try #require(items.compactMap { item -> CollectionGeneratedBlock? in
                if case .generated(let b) = item, b.type == .chronology { return b } else { return nil }
            }.first)
            let named = chronology.rows.compactMap { $0.secondaryText ?? ($0.indentLevel > 0 ? $0.text : nil) }
            #expect(named.count == 3 && Set(named) == [short("7"), short("8"), short("9")], "\(named)")

            // Cited in full: the head, the passage's source line, the Bibliography's rows.
            #expect(docs.allSatisfy { $0.citation != $0.shortCitation && $0.citation.contains("Foreign Relations") },
                    "\(docs.map(\.citation))")
            let excerpt = items.compactMap { item -> CollectionExportExcerpt? in
                if case .excerpt(let e) = item { return e } else { return nil }
            }.first
            #expect(excerpt?.citation == docs.first?.citation)
            let bibliography = try #require(items.compactMap { item -> CollectionGeneratedBlock? in
                if case .generated(let b) = item, b.type == .bibliography { return b } else { return nil }
            }.first)
            #expect(Set(bibliography.rows.map(\.text)) == Set(docs.map(\.citation)), "\(bibliography.rows.map(\.text))")
        }
    }
}

// MARK: - L58: the defects, shown first

/// The three defects L58 ends, each held to what fixes it, written against what the format and the statement had before
/// L58 so that the same suite fails on L43's tip and passes on L58's (decision 183: a row shows its defect first).
///
/// - **J6** (the third review): the writer left a document's Off out, and the reader took the missing key for Default,
///   which a collection with headnotes on turns On.
/// - **#1999's file half**: the file named a headnote by its draft's id, an id of the sender's library, and carried
///   none of its words, so a headnote never reached a colleague.
/// - **#2005's rest**: a collection's statement of sources said nothing of the lines its compiler wrote, a title and its
///   date line or a headnote of theirs, beside the volumes' text.
@Suite("L58: the collection file's headnote and the statement of sources, shown first")
struct CollectionFileDefectTests {

    /// A collection of one document, d1, whose headnote is set as `includeHeadnote` says, under a collection whose
    /// headnotes are on.
    private func collection(includeHeadnote: Bool?, headnoteSummaryId: UUID? = nil) -> CollectionExport {
        let entry = CollectionEntryExport(id: UUID(), documentId: "d1", volumeId: "frus1961-63v11", sortOrder: 0,
                                          selectedNoteIds: [], kind: CollectionEntryKind.document.rawValue,
                                          includeHeadnote: includeHeadnote, headnoteSummaryId: headnoteSummaryId)
        return CollectionExport(id: UUID(), name: "Headnotes", projectIds: [], entries: [entry],
                                defaultIncludeHeadnote: true)
    }

    /// A file written from `collection` and read back, as a recipient's import reads it.
    private func roundTrip(_ collection: CollectionExport) throws -> (json: String, imported: NativeCollectionImport) {
        let file = NativeCollectionSerializer.makeFile(from: collection, includeNotes: false, resolveNoteTexts: { _ in [] })
        let data = try NativeCollectionSerializer.encode(file)
        return (String(decoding: data, as: UTF8.self),
                NativeCollectionSerializer.importedValues(from: try NativeCollectionSerializer.decode(data)))
    }

    @Test("J6: a document switched Off, in a collection with headnotes on, arrives Off")
    func offArrivesOff() throws {
        let (json, imported) = try roundTrip(collection(includeHeadnote: false))
        let entry = try #require(imported.collection.entries.first)
        #expect(entry.includeHeadnote == false,
                "Off arrived as \(String(describing: entry.includeHeadnote)), which the collection's On turns on: \(json)")
    }

    @Test("#1999: a headnote is never named in the file by an id of the sender's library")
    func headnoteIsNoDraftId() throws {
        let draft = UUID()
        let (json, _) = try roundTrip(collection(includeHeadnote: true, headnoteSummaryId: draft))
        #expect(!json.contains(draft.uuidString), "the file names the sender's draft by its id: \(json)")
    }

    @Test("#2005: a collection's statement of sources names the lines its compiler wrote")
    func statementNamesTheCompilersLines() {
        let titled = CollectionExportDocument(documentId: "d1", volumeId: "frus1961-63v11", sortOrder: 0,
                                              title: "Volume — d1", titleOverride: "The Long Telegram",
                                              bodyText: "Text.", citation: "A citation.")
        let lines = CollectionColophon.sourceLines(for: [.document(titled)], embedsWordCloud: false)
        #expect(lines.contains { $0.contains("compiler") },
                "the statement says nothing of the title the compiler wrote: \(lines)")
        // A document with no line of the compiler's prints no such sentence.
        let plain = CollectionExportDocument(documentId: "d1", volumeId: "frus1961-63v11", sortOrder: 0,
                                             title: "Volume — d1", bodyText: "Text.", citation: "A citation.")
        #expect(!CollectionColophon.sourceLines(for: [.document(plain)], embedsWordCloud: false)
            .contains { $0.contains("compiler") })
    }
}

// MARK: - L58: the Note on the Text

/// The Note on the Text (L58; the Collections design's §3.6): its rule over the documents' readings, and its place in a
/// resolve, outside the block seam (the third review's J18). The sentences are the row's proposal for the owner's
/// words, so a test that reads one is a reminder (decision 9 of the 2026-10-11 plan of record): an edit to the words
/// moves it, with the reason here.
@Suite("L58: the Note on the Text")
@MainActor
struct NoteOnTheTextTests {

    typealias Fixtures = CollectionResolutionFixtures
    typealias Note = CollectionNoteOnTheText

    @Test("Documents are named by their contents numbers, a run of three or more as a range")
    func documentsPhrase() {
        #expect(Note.documentsPhrase([3]) == "document 3")
        #expect(Note.documentsPhrase([5, 2]) == "documents 2 and 5")
        #expect(Note.documentsPhrase([1, 2, 3, 4, 7]) == "documents 1–4 and 7")
        #expect(Note.documentsPhrase([1, 2, 5, 6, 7, 9]) == "documents 1, 2, 5–7 and 9")
    }

    @Test("A collection that prints its documents whole, as the volumes do, has nothing to say, and prints no Note")
    func nothingToSay() {
        let note = Note(documents: [Note.Document(number: 1), Note.Document(number: 2)])
        #expect(note.paragraphs.isEmpty)
        #expect(!note.hasSomethingToSay)
        #expect(note.block() == nil, "not even a title, and never Nothing to list")
        // A source note switched off still prints among a full text's footnotes (#1991), so nothing is left out.
        #expect(Note(documents: [Note.Document(number: 1, includesSourceNote: false)]).paragraphs.isEmpty)
    }

    @Test("Titles and date lines: said for every document, or with the documents named")
    func titles() throws {
        let some = Note(documents: [Note.Document(number: 1, hasTitle: true, hasDateLine: true),
                                    Note.Document(number: 2),
                                    Note.Document(number: 3, hasTitle: true)])
        let paragraph = try #require(some.paragraphs.first)
        #expect(paragraph.hasPrefix("The titles of documents 1 and 3 are the compiler’s;"), "\(paragraph)")
        #expect(paragraph.contains("_As published:_"))
        #expect(paragraph.hasSuffix("So is the date line under the title of document 1."), "\(paragraph)")

        let every = Note(documents: [Note.Document(number: 1, hasTitle: true, hasDateLine: true),
                                     Note.Document(number: 2, hasTitle: true, hasDateLine: true)])
        #expect(every.paragraphs.first?.hasPrefix("Every document’s title is the compiler’s;") == true)
        #expect(every.paragraphs.first?.hasSuffix("So is the date line under each title.") == true)
        // A date line with no title prints nowhere (J41), so the Note says nothing of it.
        #expect(Note(documents: [Note.Document(number: 1, hasDateLine: true)]).paragraphs.isEmpty)
    }

    @Test("What is left out: summaries, citations, footnotes and source notes, each for the whole collection or named")
    func leftOut() throws {
        let note = Note(documents: [
            Note.Document(number: 1, includesFootnotes: false),
            Note.Document(number: 2, bodyDepth: .summaryOnly),
            Note.Document(number: 3, bodyDepth: .index, includesSourceNote: false),
            Note.Document(number: 4, includesFootnotes: false, includesSourceNote: false),
        ])
        let paragraph = try #require(note.paragraphs.first)
        #expect(paragraph == "Document 2 is given as a summary written by Apple Intelligence, in place of its text. "
                + "Document 3 is given by its citation alone. "
                + "Footnotes are left out of documents 1 and 4; their numbers remain in the text. "
                + "The archival source notes of documents 3 and 4 are left out.", "\(paragraph)")

        let all = Note(documents: [Note.Document(number: 1, includesFootnotes: false, includesSourceNote: false),
                                   Note.Document(number: 2, includesFootnotes: false, includesSourceNote: false)])
        #expect(all.paragraphs == ["Footnotes are left out; their numbers remain in the text. "
                                   + "The archival source notes are left out."])
        let summaries = Note(documents: [Note.Document(number: 1, bodyDepth: .summaryOnly),
                                         Note.Document(number: 2, bodyDepth: .summaryOnly)])
        #expect(summaries.paragraphs == ["Every document is given as a summary written by Apple Intelligence, in place of its text."])
    }

    @Test("Headnotes: one sentence for each writer, by name, and one for all where one writer wrote them all")
    func headnotes() throws {
        let note = Note(documents: [
            Note.Document(number: 1, headnote: .appleIntelligence),
            Note.Document(number: 2, headnote: .person(name: "Jane Doe")),
            Note.Document(number: 3, headnote: .appleIntelligence),
            Note.Document(number: 4, headnote: .personFromDraft(name: "Jane Doe")),
            Note.Document(number: 5, headnote: .person(name: nil)),
            Note.Document(number: 6),
        ])
        #expect(note.paragraphs == ["The headnotes to documents 1 and 3 were written by Apple Intelligence. "
                                    + "The headnote to document 2 was written by Jane Doe. "
                                    + "The headnote to document 4 was drafted by Apple Intelligence and edited by Jane Doe. "
                                    + "The headnote to document 5 was written by hand, not by Apple Intelligence."])
        let one = Note(documents: [Note.Document(number: 1, headnote: .person(name: "Jane Doe")),
                                   Note.Document(number: 2, headnote: .person(name: "Jane Doe"))])
        #expect(one.paragraphs == ["The headnotes were written by Jane Doe."])
    }

    @Test("Quoted passages and the labels the compiler reworded")
    func passagesAndLabels() throws {
        let wording = CollectionWording(json: #"{"bibliography":"Works Cited","researchNote":"Commentary","later":"x"}"#)
        let note = Note(documents: [Note.Document(number: 1)], quotedPassageCount: 2, wording: wording)
        #expect(note.paragraphs.count == 2)
        #expect(note.paragraphs.first?.hasPrefix("The 2 passages quoted in this collection are excerpts") == true)
        #expect(note.paragraphs.last == "The compiler’s own words stand for the app’s in these labels: "
                + "_Commentary_ for Research Note and _Works Cited_ for Bibliography.", "\(note.paragraphs)")
    }

    /// J18: the Note is read from the resolved entries, outside the block seam, over the whole collection: its row
    /// prints it where its row is, a capped preview's Note is the export's, and a collection with nothing to say prints
    /// no item at all for the row, where a block prints *Nothing to list*.
    @Test("The assembly prints the Note at its row, read over every entry, and nothing where it has nothing to say")
    func throughTheAssembly() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            var collection = Fixtures.staticCollection()
            collection.entries.append(Fixtures.entry(20, kind: .generated) {
                $0.generatedBlockType = CollectionGeneratedBlockType.noteOnTheText.rawValue
            })
            let assembly = CollectionContentAssembly(collection: collection, notes: Fixtures.notes, source: store,
                                                     locale: Locale(identifier: "en_US"))
            func note(_ items: [CollectionExportItem]) -> CollectionGeneratedBlock? {
                items.compactMap { item -> CollectionGeneratedBlock? in
                    if case .generated(let block) = item, block.type == .noteOnTheText { return block }
                    return nil
                }.first
            }
            let items = try await assembly.resolve(entries: Fixtures.entries(of: collection), introduction: nil,
                                                   purpose: .preview)
            let block = try #require(note(items), "the Note prints at its row")
            #expect(block.title == "Note on the Text")
            let text = block.rows.map(\.text).joined(separator: "\n")
            // d8 has a title of the compiler's; d9 is in an index-depth section; one passage is quoted.
            #expect(text.contains("The title of document 2 is the compiler’s"), "\(text)")
            #expect(text.contains("Document 3 is given by its citation alone."), "\(text)")
            #expect(text.contains("The passage quoted in this collection"), "\(text)")
            #expect(!text.contains(CollectionGeneratedBlocks.emptyRowText))
            if case .generated(let last)? = items.last {
                #expect(last.type == .noteOnTheText, "the Note prints where its row is, last")
            } else {
                Issue.record("the last item is not the Note: \(String(describing: items.last))")
            }

            // A capped preview passes a prefix of the entries; the Note is read over all of them.
            let capped = try await assembly.resolve(entries: Array(Fixtures.entries(of: collection).prefix(2)),
                                                    introduction: nil, purpose: .preview)
            #expect(capped.isEmpty || note(capped) == nil, "the capped prefix holds no Note row")
            let item = await assembly.resolveItem(CollectionContentAssembly.Entry(
                collection.entries.last!, proseParagraphs: nil))
            if case .generated(let single)? = item {
                #expect(single.rows.map(\.text) == block.rows.map(\.text), "the row's own resolve reads the whole collection")
            } else {
                Issue.record("the Note's row resolved to \(String(describing: item))")
            }

            // Nothing to say: the row prints nothing, not a title over Nothing to list.
            let plain = CollectionExport(id: UUID(), name: "Plain", projectIds: [], entries: [
                Fixtures.entry(0, kind: .document, document: "d7"),
                Fixtures.entry(1, kind: .generated) { $0.generatedBlockType = CollectionGeneratedBlockType.noteOnTheText.rawValue },
            ], defaultBodyDepth: "full", footnoteStyle: "all")
            let plainItems = try await CollectionContentAssembly(collection: plain, notes: [], source: store)
                .resolve(entries: Fixtures.entries(of: plain), introduction: nil, purpose: .export)
            #expect(note(plainItems) == nil)
            #expect(plainItems.count == 1, "the document alone: \(plainItems.count) items")
        }
    }

    /// Decision 194: a headnote's caption names its writer, in the collection's word for a headnote, and the Note counts
    /// it the same way. A person's headnote never stamped is named by the collection's author line.
    @Test("A headnote's caption names its writer, by the name it carries, else the author line")
    func headnoteCaption() async throws {
        try await withResolutionDirectory { dir in
            let store = try await FixtureContentStore.make(in: dir)
            let volume = Fixtures.volume
            let stamped = GeneratedSummaryExport(id: UUID(), documentId: "d7", volumeId: volume,
                                                 promptId: GeneratedSummaryExport.headnoteDraftPromptId,
                                                 responseText: "Jane's headnote.", responseFormat: .general,
                                                 wasChunked: false, authorship: .userWritten, isHeadnoteDraft: true,
                                                 writerName: "Jane Doe")
            let unstamped = GeneratedSummaryExport(id: UUID(), documentId: "d8", volumeId: volume,
                                                   promptId: GeneratedSummaryExport.headnoteDraftPromptId,
                                                   responseText: "An edited draft.", responseFormat: .general,
                                                   wasChunked: false, authorship: .aiEdited, isHeadnoteDraft: true)
            store.summaries += [stamped, unstamped]
            let collection = CollectionExport(id: UUID(), name: "Captions", projectIds: [], entries: [
                Fixtures.entry(0, kind: .document, document: "d7") { $0.includeHeadnote = true; $0.headnoteSummaryId = stamped.id },
                Fixtures.entry(1, kind: .document, document: "d8") { $0.includeHeadnote = true; $0.headnoteSummaryId = unstamped.id },
            ], authorLine: "The Compiler", labelsJSON: #"{"headnote":"Editor’s Note"}"#)
            let docs = try await CollectionContentAssembly(collection: collection, notes: [], source: store)
                .resolveDocuments(entries: Fixtures.entries(of: collection), purpose: .preview)
            #expect(docs.map(\.headnoteWriter) == [.person(name: "Jane Doe"), .personFromDraft(name: "The Compiler")])
            let options = CollectionExportOptions(composing: collection)
            let captions = docs.map { doc in
                CollectionDocumentPlan(document: doc, options: options).lines.first { $0.role == .headnote }?.attribution
            }
            #expect(captions == ["Editor’s Note by Jane Doe",
                                 "Editor’s Note by The Compiler, from a draft by Apple Intelligence"], "\(captions)")
            #expect(CollectionAIAttribution.headnoteLabel(writer: .appleIntelligence, label: "Headnote")
                    == "Headnote by Apple Intelligence (on-device)")
            #expect(CollectionAIAttribution.headnoteLabel(writer: .person(name: nil), label: "Headnote") == nil)
            // The stored name of nobody takes no author line after it (an import's mark).
            #expect(CollectionHeadnoteWriter(authorship: .userWritten, storedName: CollectionHeadnoteWriter.unnamed,
                                             authorLine: "The Recipient") == .person(name: nil))
        }
    }
}

// MARK: - L58: the collection file's new keys

/// The collection file's new keys (L58; the Collections design's §7.4; decisions 166, 193 and 194): each written only
/// where it is set, read back by the importer, and none a key 1.0 reads with a new type. The file run of 2026-11-27
/// opened a hand-made file with these keys in 1.0 (1861) by all four ways in: 1.0 dropped every new key and kept
/// `includeHeadnote: false` and an unknown block type (`L43-prep-file-run.md`).
@Suite("L58: the collection file's new keys")
struct CollectionFileKeysTests {

    /// A collection with every new fact set: Chicago, the volume's heading leading, two words and a later build's name,
    /// See also; a heading with its headnote default Off; d475 titled with a date line and its headnote On; d473 Off
    /// with a draft of its own; d470 at Default.
    private func collection() -> CollectionExport {
        func entry(_ order: Int, _ kind: CollectionEntryKind, _ document: String = "",
                   configure: (inout CollectionEntryExport) -> Void = { _ in }) -> CollectionEntryExport {
            var entry = CollectionEntryExport(id: UUID(), documentId: document,
                                              volumeId: document.isEmpty ? "" : "frus1946v06", sortOrder: order,
                                              selectedNoteIds: [], kind: kind.rawValue, level: 1,
                                              text: kind == .heading ? "Moscow, February 1946" : nil)
            configure(&entry)
            return entry
        }
        return CollectionExport(
            id: UUID(), name: "The new keys", projectIds: [], entries: [
                entry(0, .generated) { $0.generatedBlockType = CollectionGeneratedBlockType.noteOnTheText.rawValue },
                entry(1, .heading) { $0.headnoteDefault = false },
                entry(2, .document, "d475") {
                    $0.titleOverride = "The Long Telegram"
                    $0.dateLine = "Moscow, 22 February 1946"
                    $0.includeHeadnote = true
                    $0.headnoteSummaryId = UUID()
                },
                entry(3, .document, "d473") { $0.includeHeadnote = false; $0.headnoteSummaryId = UUID() },
                entry(4, .document, "d470"),
            ],
            authorLine: "Jane Doe", defaultIncludeHeadnote: true,
            citationStyle: "chicago", opening: "volumeHeading",
            labelsJSON: #"{"bibliography":"Works Cited","later":"A later build's word"}"#,
            defaultIncludeRelatedDocuments: true)
    }

    /// The headnote d475 prints, Jane Doe's, as the app's store answers it.
    private let jane = FRUSCollectionFile.Headnote(text: "Kennan's answer to telegram 284.", format: "general",
                                                   authorship: "userWritten", writerName: "Jane Doe")

    @Test("Each new key is written where it is set, and a headnote travels as its text where it prints")
    func writtenWhereSet() throws {
        var asked: [String] = []
        let file = NativeCollectionSerializer.makeFile(from: collection(), includeNotes: false,
                                                       resolveNoteTexts: { _ in [] }) { entry, _ in
            asked.append(entry.documentId)
            return jane
        }
        #expect(file.formatVersion == 2 && file.minimumReaderVersion == 1, "no change of version or floor")
        #expect(file.citationStyle == "chicago" && file.opening == "volumeHeading")
        #expect(file.labels == ["bibliography": "Works Cited", "later": "A later build's word"])
        #expect(file.includeRelatedDocuments == true)
        #expect(file.authorLine == "Jane Doe", "the author line serves as the compiler's name (decision 234)")
        let entries = file.entries
        #expect(entries.map(\.generatedBlockType) == ["noteOnTheText", nil, nil, nil, nil])
        #expect(entries[1].headnoteDefault == false && entries[1].includeHeadnote == nil, "J24: a heading's own field")
        #expect(entries[2].dateLine == "Moscow, 22 February 1946" && entries[2].includeHeadnote == true)
        #expect(entries[2].headnote == jane)
        #expect(entries[3].includeHeadnote == false && entries[3].headnote == nil, "Off travels as Off, and no draft (193)")
        #expect(entries[4].includeHeadnote == nil && entries[4].headnote == nil,
                "d470 is Default in a section whose default is Off: no headnote prints, so none travels")
        #expect(entries.allSatisfy { $0.headnoteSummaryId == nil }, "no id of the sender's library (166)")
        #expect(asked == ["d475"], "only a headnote that prints is asked for")

        // 1.0 keeps reading what it read: no key it knows has a new type (the file run's finding 4).
        let json = String(decoding: try NativeCollectionSerializer.encode(file), as: UTF8.self)
        #expect(json.contains("\"includeHeadnote\" : false"))
        #expect(!json.contains("headnoteSummaryId"))
    }

    @Test("A collection that sets nothing new and has no headnote writes the bytes it wrote before L58")
    func writeMinimumStays() throws {
        let plain = CollectionExport(id: UUID(), name: "Plain", projectIds: [], entries: [
            CollectionEntryExport(id: UUID(), documentId: "d1", volumeId: "frus1961-63v11", sortOrder: 0,
                                  selectedNoteIds: [], kind: "document")])
        let file = NativeCollectionSerializer.makeFile(from: plain, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(file.formatVersion == 1)
        // The keys 1.0's writer wrote, and no other (read as keys, so the check holds wherever the kit runs).
        let data = try NativeCollectionSerializer.encode(file)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["composition", "entries", "format", "formatVersion", "name"])
        let composition = try #require(object["composition"] as? [String: Any])
        #expect(Set(composition.keys) == ["applyHighlights", "defaultBodyDepth", "footnoteStyle", "includeNotes",
                                          "includeWordCloud", "tocStyle"])
        let entry = try #require((object["entries"] as? [[String: Any]])?.first)
        #expect(Set(entry.keys) == ["documentId", "kind", "volumeId"])
    }

    @Test("An import reads every new key back, and makes a headnote draft of its own")
    func importReadsThemBack() throws {
        var ids = (1...40).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))! }.makeIterator()
        let file = NativeCollectionSerializer.makeFile(from: collection(), includeNotes: false,
                                                       resolveNoteTexts: { _ in [] }) { _, _ in jane }
        let data = try NativeCollectionSerializer.encode(file)
        let imported = NativeCollectionSerializer.importedValues(from: try NativeCollectionSerializer.decode(data),
                                                                 makeId: { ids.next()! })
        let values = imported.collection
        #expect(values.citationStyle == "chicago" && values.opening == "volumeHeading")
        #expect(CollectionWording(json: values.labelsJSON).storedWords
                == ["bibliography": "Works Cited", "later": "A later build's word"], "a later build's word survives")
        #expect(values.defaultIncludeRelatedDocuments == true && values.defaultIncludeHeadnote == true)
        let entries = values.entries
        #expect(entries[1].headnoteDefault == false)
        #expect(entries[2].dateLine == "Moscow, 22 February 1946")
        #expect(entries[3].includeHeadnote == false, "Off arrives Off (J6)")
        let draft = try #require(imported.headnoteDrafts.first)
        #expect(imported.headnoteDrafts.count == 1)
        #expect(entries[2].headnoteSummaryId == draft.id, "the entry names the import's own draft")
        #expect(draft.responseText == jane.text && draft.authorship == .userWritten && draft.writerName == "Jane Doe")
        #expect(draft.isHeadnoteDraft == true && draft.promptId == GeneratedSummaryExport.headnoteDraftPromptId)
        #expect(draft.documentId == "d475" && draft.volumeId == "frus1946v06")
        // Ids in file order: the collection's, then each entry's own and its draft's.
        #expect(values.id.uuidString.hasSuffix("000000000001") && entries[2].id.uuidString.hasSuffix("000000000004"))
        #expect(draft.id.uuidString.hasSuffix("000000000005"))
    }

    @Test("A person's headnote with no writer's name takes the file's author line, else nobody's; a guess is never made")
    func writerNames() throws {
        func importing(_ headnote: FRUSCollectionFile.Headnote, authorLine: String?) throws -> GeneratedSummaryExport? {
            let file = FRUSCollectionFile(
                format: "fruscollection", formatVersion: 2, minimumReaderVersion: 1, name: "Names",
                authorLine: authorLine,
                composition: .init(defaultBodyDepth: "full", footnoteStyle: "all", tocStyle: "citation",
                                   applyHighlights: false, includeNotes: true, includeWordCloud: false),
                entries: [.init(kind: "document", documentId: "d1", volumeId: "v1", includeHeadnote: true,
                                headnote: headnote)])
            return NativeCollectionSerializer.importedValues(from: file).headnoteDrafts.first
        }
        let person = FRUSCollectionFile.Headnote(text: "Mine.", authorship: "userWritten")
        #expect(try importing(person, authorLine: "The Sender")?.writerName == "The Sender", "decision 234")
        #expect(try importing(person, authorLine: nil)?.writerName == CollectionHeadnoteWriter.unnamed,
                "named by nobody, so the recipient's author line never claims it")
        let ai = FRUSCollectionFile.Headnote(text: "The model's.", authorship: "aiGenerated", writerName: "Ignored")
        #expect(try importing(ai, authorLine: "The Sender")?.writerName == nil, "Apple Intelligence's has no person")
        #expect(try importing(FRUSCollectionFile.Headnote(text: "Whose?"), authorLine: nil) == nil,
                "no authorship: the import leaves it out rather than guess")
        #expect(try importing(FRUSCollectionFile.Headnote(text: "  ", authorship: "userWritten"), authorLine: nil) == nil)
        #expect(try importing(FRUSCollectionFile.Headnote(text: "x", authorship: "agentWritten"), authorLine: nil) == nil)
    }

    @Test("A structured headnote travels with its fields' names and imports as structured")
    func structuredHeadnote() throws {
        let schema = StructuredSummarySchema(fields: [.init(name: "KeyParticipants", description: "Who"),
                                                      .init(name: "Background", description: "Why")])
        let summary = GeneratedSummaryExport(id: UUID(), documentId: "d1", volumeId: "v1", promptId: UUID(),
                                             responseText: #"{"Background":"b","KeyParticipants":"k"}"#,
                                             responseFormat: .structured(schema: schema), wasChunked: false,
                                             authorship: .aiGenerated)
        let headnote = try #require(FRUSCollectionFile.Headnote(summary: summary, authorLine: "Jane Doe"))
        #expect(headnote.format == "structured" && headnote.fields == ["KeyParticipants", "Background"])
        #expect(headnote.writerName == nil, "Apple Intelligence's")
        guard case .structured(let back) = headnote.responseFormat else {
            Issue.record("a structured headnote read back as \(headnote.responseFormat)")
            return
        }
        #expect(back.fields.map(\.name) == ["KeyParticipants", "Background"])
        // A person's headnote never stamped carries the author line, the name its export prints.
        let edited = GeneratedSummaryExport(id: UUID(), documentId: "d1", volumeId: "v1", promptId: UUID(),
                                            responseText: "Edited.", responseFormat: .general, wasChunked: false,
                                            authorship: .aiEdited)
        #expect(FRUSCollectionFile.Headnote(summary: edited, authorLine: " Jane Doe ")?.writerName == "Jane Doe")
    }
}
