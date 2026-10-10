// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - BulkResultRequestTests

/// A command chosen on search results carries its own documents (#1576 lane 2).
///
/// `CollectionAttachmentTests` drives the write, `appendDocuments`, on a real store. This file
/// holds the request, the picker's words, and the wiring nothing hosts: source scans, matched on
/// the call, of the modifier that presents the sheet and of the two search hosts.
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
@Suite("Bulk result request")
struct BulkResultRequestTests {

    private func result(_ volumeId: String, _ documentId: String) -> SearchResult {
        SearchResult(documentId: documentId, volumeId: volumeId, header: "Doc", snippet: "", bm25Score: 0)
    }

    @Test("A request holds its rows' documents in the order given")
    func requestFreezesTheDocumentsInOrder() throws {
        let request = try #require(BulkResultRequest(
            .addToCollection,
            results: [result("frus1969-76v01", "d3"), result("frus1964-68v02", "d1"), result("frus1969-76v01", "d2")],
            fromMeaningSearch: false))

        #expect(request.command == .addToCollection)
        #expect(request.documents == [
            CollectionDocumentRef(volumeId: "frus1969-76v01", documentId: "d3"),
            CollectionDocumentRef(volumeId: "frus1964-68v02", documentId: "d1"),
            CollectionDocumentRef(volumeId: "frus1969-76v01", documentId: "d2"),
        ])
        #expect(!request.fromMeaningSearch)
    }

    @Test("A request says whether a Meaning search listed its rows")
    func requestCarriesTheEngine() throws {
        let rows = [result("v1", "d1")]
        let meaning = try #require(BulkResultRequest(.addToCollection, results: rows, fromMeaningSearch: true))
        let keywords = try #require(BulkResultRequest(.addToCollection, results: rows, fromMeaningSearch: false))
        #expect(meaning.fromMeaningSearch)
        #expect(!keywords.fromMeaningSearch)
    }

    /// `.sheet(item:)` presents on identity. The same row asked for twice must present twice.
    @Test("Two requests for the same rows are two requests")
    func eachRequestHasItsOwnIdentity() throws {
        let rows = [result("v1", "d1")]
        let first = try #require(BulkResultRequest(.addToCollection, results: rows, fromMeaningSearch: false))
        let second = try #require(BulkResultRequest(.addToCollection, results: rows, fromMeaningSearch: false))
        #expect(first.id != second.id)
        #expect(first != second)
        #expect(first.documents == second.documents)
    }

    /// A command on nothing has no sheet to present: one that opened would be titled for no
    /// documents and would confirm an add of nothing.
    @Test("There is no request for no results")
    func noRequestForNoResults() {
        #expect(BulkResultRequest(.addToCollection, results: [], fromMeaningSearch: false) == nil)
    }

    /// The sheet's title prints the request's count and the add takes each document once, so the
    /// request holds each once: the count on the title is the count acted on.
    @Test("A document listed twice is in the request once, where it first stands")
    func requestHoldsEachDocumentOnce() throws {
        let request = try #require(BulkResultRequest(
            .addToCollection,
            results: [result("v1", "d2"), result("v1", "d1"), result("v1", "d2"), result("v2", "d2")],
            fromMeaningSearch: false))
        #expect(request.documents == [
            CollectionDocumentRef(volumeId: "v1", documentId: "d2"),
            CollectionDocumentRef(volumeId: "v1", documentId: "d1"),
            CollectionDocumentRef(volumeId: "v2", documentId: "d2"),
        ])
    }

    @Test("A document reference's key is the collection editors' own")
    func referenceKeyIsTheEditorsKey() {
        #expect(CollectionDocumentRef(volumeId: "frus1969-76v01", documentId: "d12").key == "frus1969-76v01/d12")
    }
}

// MARK: - CollectionPickerDocumentsModeTests

/// The collection picker's documents mode: its words, and its wiring read from source, since
/// nothing hosts the picker (see `CollectionTests.pickerRowUsesListName`).
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
@Suite("Collection picker, documents mode")
struct CollectionPickerDocumentsModeTests {

    private static let enUS = Locale(identifier: "en_US")

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `text` with every run of whitespace removed, so a scan matches a call however it is wrapped.
    private static func squeezed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    /// The declaration that opens with `header`, to the line that closes it at the header's own
    /// indentation.
    private static func declaration(_ header: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: header), "\(header) is gone: moved or renamed?")
        let lineStart = source[..<start.lowerBound].lastIndex(of: "\n").map(source.index(after:)) ?? source.startIndex
        let indent = source[lineStart..<start.lowerBound]
        let close = try #require(source.range(of: "\n\(indent)}\n", range: start.upperBound..<source.endIndex))
        return source[start.lowerBound..<close.upperBound]
    }

    /// `source` without its comment lines, so a note that quotes a call cannot satisfy a scan for it.
    private static func code(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: The words

    /// One document reads as the document's own picker does. Past one the title carries the count,
    /// which is what tells the reader how many documents the tap will add.
    @Test("The title is the plain one for one document and carries the count for several")
    func titleCarriesTheCount() {
        #expect(CollectionPickerCopy.documentsTitle(count: 1, locale: Self.enUS) == "Add to Collection")
        #expect(CollectionPickerCopy.documentsTitle(count: 2, locale: Self.enUS) == "Add 2 Documents to Collection")
        #expect(CollectionPickerCopy.documentsTitle(count: 37, locale: Self.enUS) == "Add 37 Documents to Collection")
        #expect(CollectionPickerCopy.documentsTitle(count: 1_000, locale: Self.enUS)
                == "Add 1,000 Documents to Collection")
        #expect(CollectionPickerCopy.title == "Add to Collection")
    }

    @Test("A refused add says why, and a failed save says the documents may not be kept")
    func failureMessages() {
        #expect(CollectionPickerCopy.addFailure(CollectionDocumentAppendRefusal.smartCollection, locale: Self.enUS)
                == "This is a smart collection. Its documents come from its saved search, so nothing can be added to it by hand.")
        #expect(CollectionPickerCopy.addFailure(
                    CollectionDocumentAppendRefusal.overLimit(count: 1_200, limit: 1_000), locale: Self.enUS)
                == "A collection takes up to 1,000 documents at a time, and 1,200 documents were chosen.")
        let save = CollectionPickerCopy.addFailure(CocoaError(.fileWriteOutOfSpace), locale: Self.enUS)
        #expect(save.hasPrefix("The collection could not be saved, so nothing was added. "))
        #expect(save.count > "The collection could not be saved, so nothing was added. ".count,
                "the save's own description follows")
    }

    // MARK: The sheet's own values

    /// Decision 6 reaches the chip through the initialiser. The scans below read the request,
    /// the modifier's call and the bodies' condition; this reads what the initialiser stores.
    @Test("The documents initialiser stores its documents and whether a Meaning search listed them")
    @MainActor
    func documentsInitialiserStoresWhatItIsGiven() {
        let documents = [CollectionDocumentRef(volumeId: "v1", documentId: "d1"),
                         CollectionDocumentRef(volumeId: "v1", documentId: "d2")]
        let fromMeaning = CollectionPickerSheet(documents: documents, fromMeaningSearch: true)
        #expect(fromMeaning.documents == documents)
        #expect(fromMeaning.fromMeaningSearch)
        #expect(fromMeaning.entry == nil)
        #expect(fromMeaning.excerpt == nil)

        let fromKeywords = CollectionPickerSheet(documents: documents, fromMeaningSearch: false)
        #expect(!fromKeywords.fromMeaningSearch)
        #expect(!CollectionPickerSheet(documents: documents).fromMeaningSearch, "the default is a keyword list")
    }

    // MARK: The list's order

    /// The picker's query sorts by `lastModified`, and a documents-mode add stamps the collection
    /// it adds to. Without a held order the tapped row leaves for the top of the list at the tap.
    @Test("The list keeps the order it opened in, with a collection made since ahead of the rest")
    func listKeepsItsOpeningOrder() {
        let a = UUID(), b = UUID(), c = UUID(), made = UUID()
        // The live order after `c` was stamped, and a collection was made: both lead the query.
        let live = [made, c, a, b]
        #expect(CollectionPickerOrder.held(live, id: { $0 }, listed: [a, b, c]) == [made, a, b, c])
        // Before the sheet has appeared there is nothing held, and the live order stands.
        #expect(CollectionPickerOrder.held(live, id: { $0 }, listed: nil) == live)
        // A collection deleted since is simply gone; two made since keep the live order.
        let other = UUID()
        #expect(CollectionPickerOrder.held([other, made, b, a], id: { $0 }, listed: [a, b, c]) == [other, made, a, b])
        #expect(CollectionPickerOrder.held([a, b], id: { $0 }, listed: []) == [a, b])
    }

    // MARK: The picker

    /// The documents branch is inside the add the row calls, after the smart-collection guard and
    /// before the single-document branches, and it writes through `appendDocuments` and nothing
    /// else.
    @Test("The picker's documents mode adds through appendDocuments, after the smart-collection guard")
    func pickerAddsThroughAppendDocuments() throws {
        let picker = try Self.source("FRUSExplorer/Collections/CollectionPickerSheet.swift")
        let add = Self.code(String(try Self.declaration("private func addDocument(to collection: Collection) {", in: picker)))
        let guardAt = try #require(add.range(of: "guard CollectionPickerRow(collection).takesEntries else { return }"))
        // One add to a presentation: the sheet closes a moment after a tap, and a second tap
        // before it has would add again, to a row the reader did not choose it for.
        let onceAt = try #require(add.range(of: "guard addedCollectionId == nil else { return }"),
                                  "a second tap before the sheet closes must not add again")
        let branchAt = try #require(add.range(of: "if let documents {"))
        #expect(guardAt.upperBound < onceAt.lowerBound && onceAt.upperBound < branchAt.lowerBound,
                "the one-add guard stands before every write")
        let excerptAt = try #require(add.range(of: "CollectionExcerpts.appendToCollection("))
        let singleAt = try #require(add.range(of: "CollectionDocumentDiscovery.appendToCollection("))
        #expect(guardAt.upperBound < branchAt.lowerBound, "a smart collection is refused before the documents branch")
        #expect(branchAt.upperBound < excerptAt.lowerBound && branchAt.upperBound < singleAt.lowerBound,
                "documents mode returns before either single-document write")
        #expect(Self.squeezed(add).contains(Self.squeezed("""
            if let documents {
                addDocuments(documents, to: collection)
                return
            }
            guard let entry else { return }
            """)))

        let bulk = Self.code(String(try Self.declaration(
            "private func addDocuments(_ documents: [CollectionDocumentRef], to collection: Collection) {", in: picker)))
        #expect(Self.squeezed(bulk).contains(Self.squeezed("""
            let outcome = try CollectionDocumentDiscovery.appendDocuments(
                documents, to: collection, modelContext: modelContext)
            addedCollectionId = collection.id
            """)), "the checkmark follows a write that returned")
        #expect(bulk.contains("addFailure = CollectionPickerCopy.addFailure(error)"), "a failed add is said, not swallowed")
        #expect(!bulk.contains("try?"), "the add's error must reach the catch")
        #expect(!bulk.contains("appendToCollection("), "documents mode has one writer")
    }

    /// Decision 6. The documents are the volumes' in every mode, so that chip is unconditional;
    /// a list a Meaning search made is the model's grouping, so its chip joins it, in both bodies.
    @Test("Both bodies badge a Meaning search's list as the model's grouping, beside the volumes' chip")
    func bothBodiesBadgeAMeaningList() throws {
        let picker = try Self.source("FRUSExplorer/Collections/CollectionPickerSheet.swift")
        for header in ["private var macBody: some View {", "private var iOSBody: some View {"] {
            let body = Self.code(String(try Self.declaration(header, in: picker)))
            let volumes = try #require(body.range(of: "ProvenanceChip(source: .frusText)"), "\(header) lost the volumes' chip")
            let model = try #require(body.range(of: "if fromMeaningSearch { ProvenanceChip(source: .appModel) }"),
                                     "\(header) does not badge a Meaning search's list")
            #expect(volumes.upperBound < model.lowerBound)
            #expect(body.components(separatedBy: "ProvenanceChip(source: .appModel)").count - 1 == 1,
                    "\(header): the model's chip is drawn only under the condition")
        }
    }

    /// A plain button is hit only where its label draws. Without a content shape the space
    /// between a collection's name and the row's trailing edge took no tap, which on an iPad's
    /// wide sheet is most of the row: `SearchResultAddToCollectionTests` taps a row's centre and
    /// failed there on an iPad Pro 13-inch until this was added.
    @Test("A collection's row takes a tap anywhere on it")
    func rowTakesATapAnywhere() throws {
        let picker = try Self.source("FRUSExplorer/Collections/CollectionPickerSheet.swift")
        let row = Self.squeezed(Self.code(String(try Self.declaration(
            "private func collectionRow(_ collection: Collection) -> some View {", in: picker))))
        // The shape is on the label's row, which the Spacer makes as wide as the list's row,
        // and inside the button: on the button it would be applied after the style.
        #expect(row.contains(Self.squeezed("""
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            """)), "the row's label has no content shape, so only its words take a tap")
        #expect(row.contains(Self.squeezed("Spacer() if addedCollectionId == collection.id {")),
                "the label's row must stay as wide as the list's row for the shape to cover it")
    }

    @Test("The picker lists its collections in the held order, searched or not")
    func pickerListsTheHeldOrder() throws {
        let picker = try Self.source("FRUSExplorer/Collections/CollectionPickerSheet.swift")
        let ordered = Self.squeezed(Self.code(String(try Self.declaration("private var ordered: [Collection] {", in: picker))))
        #expect(ordered.contains(Self.squeezed("CollectionPickerOrder.held(collections, id: \\.id, listed: orderAtOpen)")))
        let filtered = Self.squeezed(Self.code(String(try Self.declaration("private var filtered: [Collection] {", in: picker))))
        #expect(filtered.contains(Self.squeezed("guard !searchText.isEmpty else { return ordered } return ordered.filter {")),
                "the list and its search must both read the held order")
        let body = Self.squeezed(Self.code(String(try Self.declaration("var body: some View {", in: picker))))
        #expect(body.contains(Self.squeezed("""
            .onAppear {
                if orderAtOpen == nil { orderAtOpen = collections.map(\\.id) }
            }
            """)), "the order is taken once, when the sheet appears")
    }

    @Test("The picker's title is the documents title in documents mode")
    func titleReadsTheDocuments() throws {
        let picker = try Self.source("FRUSExplorer/Collections/CollectionPickerSheet.swift")
        let title = Self.squeezed(Self.code(String(try Self.declaration("private var pickerTitle: String {", in: picker))))
        #expect(title.contains(Self.squeezed(
            "if let documents { return CollectionPickerCopy.documentsTitle(count: documents.count) }")))
    }

    // MARK: The hosts

    /// The sheet is built from the request it is handed. A host that built the picker itself
    /// would read whatever is on screen when the sheet opens, which is the trap the request exists
    /// to close (#862).
    @Test("The sheet is presented on the request, and built from the request's own documents")
    func modifierPresentsFromTheRequest() throws {
        let file = try Self.source("FRUSExplorer/Search/BulkResultRequest.swift")
        let body = Self.squeezed(Self.code(String(try Self.declaration(
            "func body(content: Content) -> some View {", in: file))))
        #expect(body.contains(Self.squeezed("""
            content.sheet(item: $request) { request in
                switch request.command {
                case .addToCollection:
                    CollectionPickerSheet(documents: request.documents,
                                          fromMeaningSearch: request.fromMeaningSearch)
                }
            }
            """)))
        // And the hosts' one call reaches that modifier.
        let mount = Self.squeezed(Self.code(String(try Self.declaration(
            "func bulkResultSheets(_ request: Binding<BulkResultRequest?>) -> some View {", in: file))))
        #expect(mount.contains(Self.squeezed("modifier(BulkResultSheets(request: request))")),
                "bulkResultSheets does not apply the presenter")
    }

    @Test("Each search host makes the request from the row and mounts the one presenter",
          arguments: [
            (path: "FRUSExplorer/Search/SearchView.swift", model: "vm", voiceOverAction: true),
            (path: "FRUSExplorer/App/SearchSheet.swift", model: "searchVM", voiceOverAction: false),
          ])
    func hostMakesTheRequestFromTheRow(host: (path: String, model: String, voiceOverAction: Bool)) throws {
        let code = Self.code(try Self.source(host.path))
        let squeezed = Self.squeezed(code)

        // The request: this row's document, and the engine that listed it, taken when chosen.
        #expect(squeezed.contains(Self.squeezed("""
            private func addToCollectionRequest(for result: SearchResult) -> BulkResultRequest? {
                BulkResultRequest(.addToCollection, results: [result],
                                  fromMeaningSearch: \(host.model).resultsAreSemantic)
            }
            """)), "\(host.path) does not build the request from the row")

        // The menu item, at the menu's own level directly after Archival Neighbors…: inside no
        // condition, so it is there whether or not Checklist Mode is on.
        #expect(squeezed.contains(Self.squeezed("""
                            systemImage: "archivebox"
                        )
                    }
                    Divider()
                    Button {
                        bulkRequest = addToCollectionRequest(for: result)
                    } label: {
                        Label(BulkResultCopy.addToCollection, systemImage: "plus.circle")
                    }
            """)), "\(host.path): the row's menu has no Add to Collection item after Archival Neighbors…")

        let makers = code.components(separatedBy: "bulkRequest = addToCollectionRequest(for: result)").count - 1
        let action = Self.squeezed("""
                        Label(BulkResultCopy.addToCollection, systemImage: "plus.circle")
                    }
                }
                .accessibilityAction(named: Text(BulkResultCopy.addToCollection)) {
                    bulkRequest = addToCollectionRequest(for: result)
                }
            """)
        if host.voiceOverAction {
            // On iPhone and iPad the row is a button, one accessibility element, and carries the
            // command as a named action too: on the row, directly after its menu.
            #expect(makers == 2, "\(host.path): the row's menu item and its VoiceOver action must each make the request")
            #expect(squeezed.contains(action), "\(host.path): the row has no Add to Collection action, on the row, after its menu")
        } else {
            // The Mac's row is a stack of texts under a tap gesture, not one element, so a named
            // action has nothing to land on; VoiceOver reaches the command through the menu.
            #expect(makers == 1, "\(host.path): the menu item alone makes the request")
            #expect(!code.contains(".accessibilityAction(named: Text(BulkResultCopy.addToCollection))"))
        }

        // One presenter, and no sheet of the host's own making.
        #expect(code.components(separatedBy: ".bulkResultSheets($bulkRequest)").count - 1 == 1,
                "\(host.path) must mount the presenter once")
        #expect(!code.contains("CollectionPickerSheet("),
                "\(host.path) builds the picker itself, from live state, where it should hand over a request")
    }

    @Test("The command's words")
    func commandWords() {
        #expect(BulkResultCopy.addToCollection == "Add to Collection…")
    }
}
