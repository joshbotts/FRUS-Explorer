// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - CollectionSummaryExportTests (#2018)

/// A *Summaries* export prints each document's stored summary, and asks Apple Intelligence only for a document that has
/// none (#2018, decision 198).
///
/// Version history:
///   1.0 — L35 (#2018): initial implementation
@Suite("A Summaries export reads each stored summary before it asks Apple Intelligence (#2018)", .serialized)
@MainActor
struct CollectionSummaryExportTests {

    static let volume = "l35aivol"

    /// A saved collection whose documents print at *Summary only* under one prompt, with the summaries of `stored`
    /// stored under it. No prompt record is saved: a summary is stored under the prompt's id, and printing it needs
    /// nothing else.
    static func summariesCollection(in context: ModelContext, documents: [String], stored: Set<String>)
        throws -> (collection: Collection, entries: [CollectionEntry]) {
        let promptId = UUID()
        let collection = Collection(name: "L35 Summaries")
        collection.defaultBodyDepth = CollectionBodyDepth.summaryOnly.rawValue
        collection.summaryPromptId = promptId
        context.insert(collection)
        var entries: [CollectionEntry] = []
        for (position, documentId) in documents.enumerated() {
            let entry = CollectionEntry(collectionId: collection.id, documentId: documentId, volumeId: volume,
                                        sortOrder: position)
            entry.collection = collection
            context.insert(entry)
            entries.append(entry)
            if stored.contains(documentId) {
                context.insert(GeneratedSummary(documentId: documentId, volumeId: volume, promptId: promptId,
                                                responseText: "Stored summary of \(documentId)."))
            }
        }
        try context.save()
        return (collection, entries)
    }

    /// Every summary stored: the export prints them where Apple Intelligence cannot write one. A bare `AppState` has
    /// no summarization service and the store holds no prompt record, so the export reaches neither, as it need not.
    @Test("Every summary stored: the export prints them where Apple Intelligence cannot write one",
          arguments: [AppleIntelligenceAvailability.notEnabled, .modelNotReady, .notEligible])
    func everySummaryStored(availability: AppleIntelligenceAvailability) async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let (collection, entries) = try Self.summariesCollection(in: context, documents: ["d1", "d2"],
                                                                 stored: ["d1", "d2"])
        let resolver = CollectionContentResolver(appState: AppState(), modelContext: context)
        resolver.appleIntelligence = { availability }

        let items = try await resolver.resolve(collection: collection, entries: entries, allNotes: [],
                                               purpose: .export)

        #expect(items.documents.map(\.summaryText) == ["Stored summary of d1.", "Stored summary of d2."])
    }

    /// A summary not stored where Apple Intelligence cannot write one: the export stops, and says how many documents
    /// have none and why this device cannot write it, where it said "The export could not be rendered."
    @Test("A summary not stored: the export says how many have none and what this device lacks")
    func aSummaryNotStored() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let (collection, entries) = try Self.summariesCollection(in: context, documents: ["d1", "d2"],
                                                                 stored: ["d1"])
        let resolver = CollectionContentResolver(appState: AppState(), modelContext: context)
        resolver.appleIntelligence = { .notEnabled }

        do {
            _ = try await resolver.resolve(collection: collection, entries: entries, allNotes: [], purpose: .export)
            Issue.record("The export went ahead with a summary it could not write")
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("1 document"), "The message does not say how many have no summary: \(message)")
            #expect(message.contains(AppleIntelligenceAvailability.notEnabledSentence),
                    "The message does not say Apple Intelligence is turned off, and where to turn it on: \(message)")
        }
    }
}

// MARK: - CollectionExportSentenceTests (J9, decision 192)

/// The export sheet's sentence says what the export will print (the third review's J9; decision 192).
///
/// Version history:
///   1.0 — L35 (J9, decision 192): initial implementation
@Suite("The export sheet's sentence says what the export will print (J9, decision 192)", .serialized)
@MainActor
struct CollectionExportSentenceTests {

    static let volume = "l35sentencevol"

    /// Three documents at the collection's defaults with headnotes on, two of them with a stored summary, which a
    /// headnote prints when the entry names none.
    static func headnotesCollection(in context: ModelContext, storedFor stored: Set<String>)
        throws -> (collection: Collection, entries: [CollectionEntry]) {
        let collection = Collection(name: "L35 Headnotes")
        collection.defaultIncludeHeadnote = true
        context.insert(collection)
        var entries: [CollectionEntry] = []
        for (position, documentId) in ["d1", "d2", "d3"].enumerated() {
            let entry = CollectionEntry(collectionId: collection.id, documentId: documentId, volumeId: volume,
                                        sortOrder: position)
            entry.collection = collection
            context.insert(entry)
            entries.append(entry)
            if stored.contains(documentId) {
                context.insert(GeneratedSummary(documentId: documentId, volumeId: volume, promptId: UUID(),
                                                responseText: "Headnote of \(documentId)."))
            }
        }
        try context.save()
        return (collection, entries)
    }

    /// Headnotes are counted where they print: two of three here, and none where none is stored. 1.0's sheet read the
    /// collection's default and said "with headnotes" either way.
    @Test("Headnotes are counted where they print, not read from the collection's default")
    func headnotesCountedWhereTheyPrint() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let (some, someEntries) = try Self.headnotesCollection(in: context, storedFor: ["d1", "d2"])
        let sentence = try await Self.sheetSentence(for: some, entries: someEntries, in: context)
        #expect(sentence.contains("headnotes for 2 of 3"), "\(sentence)")

        let otherContext = ModelContext(try ModelContainer.makeTestContainer())
        let (none, noneEntries) = try Self.headnotesCollection(in: otherContext, storedFor: [])
        let unstored = try await Self.sheetSentence(for: none, entries: noneEntries, in: otherContext)
        #expect(unstored.contains("headnotes for 0 of 3"), "\(unstored)")
    }

    /// The sentence the export sheet shows for `collection` in PDF, counted as the sheet counts it. 1.0's sheet showed
    /// `Collection.compositionSummarySentence`, which reads the defaults: on 1.0 both expectations above failed, reading
    /// "Exports the full text of each document, with headnotes, your notes, and footnotes." for two stored and for none.
    static func sheetSentence(for collection: Collection, entries: [CollectionEntry],
                              in context: ModelContext) async throws -> String {
        let tally = try await CollectionContentResolver(appState: AppState(), modelContext: context)
            .exportTally(collection: collection, entries: entries, allNotes: [])
        return CollectionExportSentence.text(for: tally, format: .pdf, drawsWordCloud: false)
    }

    /// The tally is the export's own reading of each document, over the store alone: depth by the cascade (an entry's
    /// own, else its section's, else the collection's), a headnote where one is asked for and stored, a summary to
    /// write where none is stored, and notes and highlights where they print.
    @Test("The tally reads each document as the export does")
    func tallyReadsEachDocumentAsTheExportDoes() async throws {
        let context = ModelContext(try ModelContainer.makeTestContainer())
        let promptId = UUID()
        let collection = Collection(name: "L35 Tally")
        collection.summaryPromptId = promptId
        collection.applyHighlights = true
        context.insert(collection)
        // d1 full; a section of summaries holding d2 and d3; d4 a citation by its own setting, under the section.
        func add(_ kind: CollectionEntryKind, _ documentId: String, _ position: Int,
                 text: String? = nil, depth: CollectionBodyDepth? = nil) -> CollectionEntry {
            let entry = CollectionEntry(collectionId: collection.id, documentId: documentId,
                                        volumeId: documentId.isEmpty ? "" : Self.volume, sortOrder: position)
            entry.entryKind = kind
            entry.text = text
            entry.bodyDepthOverride = depth?.rawValue
            entry.collection = collection
            context.insert(entry)
            return entry
        }
        let entries = [
            add(.document, "d1", 0),
            add(.heading, "", 1, text: "Summaries", depth: .summaryOnly),
            add(.document, "d2", 2),
            add(.document, "d3", 3),
            add(.document, "d4", 4, depth: .index),
            add(.prose, "", 5, text: "Not counted."),
        ]
        entries[2].includeHeadnote = true
        entries[3].includeHeadnote = true
        context.insert(GeneratedSummary(documentId: "d2", volumeId: Self.volume, promptId: promptId,
                                        responseText: "d2's summary."))
        let note = ResearchNote(documentId: "d1", volumeId: Self.volume, bodyText: "A note on d1.")
        context.insert(note)
        context.insert(DocumentHighlight(volumeId: Self.volume, documentId: "d1", startOffset: 0, endOffset: 4,
                                         renderingVersion: "test"))
        try context.save()

        let tally = try await CollectionContentResolver(appState: AppState(), modelContext: context)
            .exportTally(collection: collection, entries: entries, allNotes: [note])

        var expected = CollectionExportTally()
        expected.documents = 4
        expected.inFull = 1
        expected.asSummaries = 2
        expected.asCitations = 1
        expected.headnotesAsked = 2
        expected.headnotesPrinted = 1
        expected.summariesToWrite = 1
        expected.printsNotes = true
        expected.printsHighlights = true
        #expect(tally == expected)

        // A note switched off for its document does not print, and the sentence says no notes.
        entries[0].includeNotesOverride = false
        try context.save()
        let noNotes = try await CollectionContentResolver(appState: AppState(), modelContext: context)
            .exportTally(collection: collection, entries: entries, allNotes: [note])
        #expect(!noNotes.printsNotes)
    }

    /// The sentence's forms, from the tally, in each kind of format.
    @Test("The sentence says how the documents print, and what prints with them")
    func sentenceForms() {
        func tally(_ full: Int, _ summaries: Int, _ citations: Int, asked: Int = 0, printed: Int = 0,
                   notes: Bool = false, highlights: Bool = false) -> CollectionExportTally {
            var tally = CollectionExportTally()
            tally.documents = full + summaries + citations
            tally.inFull = full
            tally.asSummaries = summaries
            tally.asCitations = citations
            tally.headnotesAsked = asked
            tally.headnotesPrinted = printed
            tally.printsNotes = notes
            tally.printsHighlights = highlights
            return tally
        }
        func pdf(_ tally: CollectionExportTally, cloud: Bool = false) -> String {
            CollectionExportSentence.text(for: tally, format: .pdf, drawsWordCloud: cloud)
        }
        #expect(pdf(tally(0, 0, 0)) == "This collection has no documents.")
        #expect(pdf(tally(1, 0, 0)) == "The full text of 1 document.")
        #expect(pdf(tally(6, 0, 0)) == "The full text of 6 documents.")
        #expect(pdf(tally(0, 6, 0)) == "A summary of each of 6 documents.")
        #expect(pdf(tally(0, 0, 6)) == "A citation for each of 6 documents.")
        #expect(pdf(tally(2, 2, 2, asked: 6, printed: 4, notes: true, highlights: true), cloud: true)
                == "6 documents: 2 in full, 2 as summaries, and 2 as citations, with headnotes for 4 of 6, your notes, "
                + "your highlights, and a word-cloud overview.")
        #expect(pdf(tally(4, 1, 1)) == "6 documents: 4 in full, 1 as a summary, and 1 as a citation.")
        #expect(pdf(tally(3, 0, 0, asked: 3, printed: 0)) == "The full text of 3 documents, with headnotes for 0 of 3.")
        #expect(pdf(tally(1, 0, 0, asked: 1, printed: 1)) == "The full text of 1 document, with its headnote.")
        #expect(pdf(tally(1, 0, 0, asked: 1, printed: 0)) == "The full text of 1 document, with no stored headnote.")

        // BibTeX and RIS print citations and the notes that print; the collection file is the collection itself.
        let mixed = tally(2, 2, 2, asked: 6, printed: 4, notes: true, highlights: true)
        for format in [ExportFormat.bibtex, .zoteroJSON] {
            #expect(CollectionExportSentence.text(for: mixed, format: format, drawsWordCloud: false)
                    == "A citation for each of 6 documents, with your notes.")
        }
        #expect(CollectionExportSentence.text(for: mixed, format: .fruscollection, drawsWordCloud: false)
                == "An editable copy of this collection and its 6 documents.")
    }

    /// What this device lacks is said for a rendered format with a summary to write, where Apple Intelligence cannot
    /// write it, in the words the export stops with; and nothing otherwise.
    @Test("What this device lacks: summaries to write, where Apple Intelligence cannot write them")
    func deviceLacks() {
        var tally = CollectionExportTally()
        tally.documents = 3
        tally.asSummaries = 3
        tally.summariesToWrite = 2
        for availability in [AppleIntelligenceAvailability.notEnabled, .modelNotReady, .notEligible] {
            let said = CollectionExportSentence.deviceLacks(tally, format: .pdf, availability: availability)
            #expect(said == CollectionSummaryExportError.summariesNeedAppleIntelligence(
                missing: 2, availability: availability).errorDescription)
            #expect(said?.hasPrefix("2 documents have no stored summary.") == true, "\(said ?? "nil")")
        }
        #expect(CollectionExportSentence.deviceLacks(tally, format: .pdf, availability: .available) == nil)
        for format in [ExportFormat.bibtex, .zoteroJSON, .fruscollection] {
            #expect(CollectionExportSentence.deviceLacks(tally, format: format, availability: .notEnabled) == nil,
                    "\(format) prints no summary")
        }
        tally.summariesToWrite = 0
        #expect(CollectionExportSentence.deviceLacks(tally, format: .pdf, availability: .notEnabled) == nil)
        #expect(CollectionSummaryExportError.summariesNeedAppleIntelligence(missing: 1, availability: .notEligible)
            .errorDescription == "1 document has no stored summary. "
            + CollectionSummaryExportError.notEligibleSentence)
    }
}

// MARK: - CollectionExportFormatMemoryTests (L35)

/// The sheet opens on the format a collection last exported as on this device (the design's §5.1).
///
/// Version history:
///   1.0 — L35: initial implementation
@Suite("The export sheet opens on the format a collection last exported as here (L35)")
struct CollectionExportFormatMemoryTests {

    /// A defaults domain of the test's own, removed as the test ends.
    private static func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "L35.exportFormat.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test("Each collection keeps its own; none kept, or one not offered now, opens on PDF")
    func eachCollectionKeepsItsOwn() throws {
        try Self.withDefaults { defaults in
            let all = ExportFormat.gridFormats(smartCollection: false)
            let smart = ExportFormat.gridFormats(smartCollection: true)
            let one = UUID(), two = UUID()
            #expect(CollectionExportFormatMemory.format(for: one, offered: all, in: defaults) == .pdf)
            CollectionExportFormatMemory.remember(.docx, for: one, in: defaults)
            CollectionExportFormatMemory.remember(.fruscollection, for: two, in: defaults)
            #expect(CollectionExportFormatMemory.format(for: one, offered: all, in: defaults) == .docx)
            #expect(CollectionExportFormatMemory.format(for: two, offered: all, in: defaults) == .fruscollection)
            // Linked to a saved search since, the second is offered no collection file.
            #expect(CollectionExportFormatMemory.format(for: two, offered: smart, in: defaults) == .pdf)
            CollectionExportFormatMemory.remember(.bibtex, for: one, in: defaults)
            #expect(CollectionExportFormatMemory.format(for: one, offered: all, in: defaults) == .bibtex)
        }
    }

    /// Only the sheet's Export keeps a format, and only once a file is made: the Zotero send runs from its own row and
    /// is not a format the sheet opens on (the third review). Read from the sheet's source.
    @Test("Only an export made with Export is kept, once its file is made")
    func onlyExportKeepsTheFormat() throws {
        let sheet = try CollectionListRowActionWiringTests.source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        let remembers = sheet.components(separatedBy: "CollectionExportFormatMemory.remember(").count - 1
        #expect(remembers == 1, "the sheet keeps a format at \(remembers) places")
        let runExport = try #require(CollectionListRowActionWiringTests.body(of: "private func runExport() async {",
                                                                             in: sheet))
        #expect(runExport.contains("if exportError == nil, exportedURL != nil {")
                && runExport.contains("CollectionExportFormatMemory.remember(selectedFormat, for: collection.id)"))
        let send = try #require(CollectionListRowActionWiringTests.body(of: "private func sendToZotero() async {",
                                                                        in: sheet))
        #expect(!send.contains("runExport"), "the Zotero send must not run the sheet's Export")
    }
}

// MARK: - CollectionBibTeXSummaryFreeTests (L35, beside #2018)

/// BibTeX prints each document's citation and notes and nothing of its body, so its export resolves the documents
/// alone, as RIS and the Zotero send do, and asks for no summary.
///
/// Version history:
///   1.0 — L35: initial implementation
@Suite("BibTeX resolves no summary (L35, beside #2018)", .serialized)
@MainActor
struct CollectionBibTeXSummaryFreeTests {

    /// The documents-only resolve that BibTeX now takes does not ask for a summary: a *Summaries* collection with none
    /// stored resolves where Apple Intelligence cannot write one.
    @Test("The documents-only resolve asks for no summary")
    func documentsOnlyAsksForNoSummary() async throws {
        let context = ModelContext(try ModelContainer.makeTestContainer())
        let (collection, entries) = try CollectionSummaryExportTests.summariesCollection(
            in: context, documents: ["d1", "d2"], stored: [])
        let resolver = CollectionContentResolver(appState: AppState(), modelContext: context)
        resolver.appleIntelligence = { .notEnabled }
        let documents = try await resolver.resolveDocuments(collection: collection, entries: entries, allNotes: [],
                                                            purpose: .export)
        #expect(documents.map(\.documentId) == ["d1", "d2"])
        // The full path, which PDF, HTML and Word take, does ask, and says why it cannot.
        await #expect(throws: CollectionSummaryExportError.self) {
            _ = try await resolver.resolve(collection: collection, entries: entries, allNotes: [], purpose: .export)
        }
    }

    /// The sheet's BibTeX takes that resolve, read from its source.
    @Test("The sheet's BibTeX export takes the documents-only resolve")
    func sheetRoutesBibTeX() throws {
        let sheet = try CollectionListRowActionWiringTests.source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        let rendered = try #require(CollectionListRowActionWiringTests.body(
            of: "private func runRenderedExport() async {", in: sheet))
        #expect(rendered.contains("if selectedFormat == .bibtex {\n                items = try await resolvedZoteroDocuments()"),
                "BibTeX must resolve the documents alone:\n\(rendered)")
    }
}

// MARK: - CollectionListRowActionWiringTests (L35, #2006)

/// The Collections list's row and Manage Collections' row each offer their menu as VoiceOver actions, from the menu's
/// own builder, so an action cannot do other than the menu item of its name (#2006). `CollectionListRowActionsTests`
/// (UI) reads the actions' names from VoiceOver, which cannot be made to perform one.
///
/// Version history:
///   1.0 — L35 (#2006): initial implementation
@Suite("The list rows' menus are their VoiceOver actions (#2006)")
struct CollectionListRowActionWiringTests {

    @Test("The Collections list's row: one builder for its menu and its actions, Export… first")
    func collectionListRow() throws {
        let list = try Self.source("FRUSExplorer/Collections/CollectionListView.swift")
        #expect(list.contains(".contextMenu { rowActions(for: collection, forVoiceOver: false) }"))
        #expect(list.contains(".accessibilityActions { rowActions(for: collection, forVoiceOver: true) }"))
        let builder = try #require(Self.body(of: "private func rowActions(for collection: Collection, forVoiceOver: Bool)",
                                             in: list))
        // Delete stays the menu's alone: VoiceOver offers it as the row's swipe action.
        let delete = try #require(builder.range(of: "pendingDeletionId = collection.id"))
        let guarded = try #require(builder.range(of: "if !forVoiceOver {"))
        #expect(guarded.lowerBound < delete.lowerBound, "VoiceOver would be offered Delete twice")
        let export = try #require(builder.range(of: "exporting = collection"))
        let rename = try #require(builder.range(of: "renaming = collection"))
        #expect(export.lowerBound < rename.lowerBound, "Export… is the menu's first item")
        // One menu: the row builds no second list of the items for VoiceOver.
        #expect(list.components(separatedBy: "accessibilityAction(named:").count == 1)
    }

    @Test("Manage Collections' row on the Mac: one builder for its menu and its actions, Export… first")
    func manageCollectionsRow() throws {
        let mac = try Self.source("FRUSExplorer/Collections/MacCollectionManagerView.swift")
        #expect(mac.contains(".contextMenu { rowActions(forVoiceOver: false) }"))
        #expect(mac.contains(".accessibilityActions { rowActions(forVoiceOver: true) }"))
        let builder = try #require(Self.body(of: "private func rowActions(forVoiceOver: Bool)", in: mac))
        let export = try #require(builder.range(of: "Button(action: onExport)"))
        let rename = try #require(builder.range(of: "isNameFocused = true"))
        #expect(export.lowerBound < rename.lowerBound, "Export… is the menu's first item")
        // Delete stays the menu's alone: VoiceOver offers it through the list's `.onDelete` (#1823).
        let delete = try #require(builder.range(of: "Button(role: .destructive, action: onDelete)"))
        let guarded = try #require(builder.range(of: "if !forVoiceOver {"))
        #expect(guarded.lowerBound < delete.lowerBound, "VoiceOver would be offered Delete twice")
        // Export… opens the export sheet over Manage Collections, for the row's collection.
        let sheet = try #require(Self.body(of: "private struct MacManageCollectionsSheet: View", in: mac))
        #expect(sheet.contains("onExport: { exporting = c }"))
        #expect(sheet.contains("CollectionListExportSheet(collection: collection)"))
    }

    /// The repository's root, from this file's place in it.
    static let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// A file of the repository, read whole.
    static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// The body of the function whose declaration begins `signature`, from its opening brace to the brace that closes
    /// it; `nil` when no such declaration is in `text`.
    static func body(of signature: String, in text: String) -> String? {
        guard let start = text.range(of: signature),
              let open = text[start.lowerBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[open...index]) }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
