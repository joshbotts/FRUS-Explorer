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
        summaries.first { $0.volumeId == volumeId && $0.documentId == documentId && $0.promptId == promptId }
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
            #expect(d7.relatedDocumentCitations.first?.contains("Document 8") == true,
                    "\(d7.relatedDocumentCitations)")
            // The render model is the store's AST, converted; the header is its head, and the dateline,
            // inside an opener, prints with the body rather than in the header.
            #expect(d7.renderModel != nil && d7.header.hasPrefix("7. Telegram") && d7.dateline == nil)
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

    /// The dump's SHA-256, 5,524 bytes, taken on macOS 27.2 (SwiftPM) on 2026-10-27.
    static let pinnedItemsDigest = "1f15f3dd403915a3b84545a8066aa75220a6bcdd9108b52493271d140aad04a9"
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
        #expect(snapshot.entries.map { "\($0.volumeId)/\($0.documentId)#\($0.sortOrder)" } == ["v1/d8#0", "v2/d2#1"])
        #expect(snapshot.entries.allSatisfy { $0.entryKind == .document })
        #expect(SmartCollectionSnapshot.snapshotName("   ") == "Smart Collection (Snapshot)")
        #expect(SmartCollectionSnapshot.resultLimit == 1_000)
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
