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

// MARK: - FRUSCanonicalURLTests

/// The one spelling of a document's public address (#358).
///
/// On iOS this URL **is** the Zotero integration for anyone without an API key: Zotero's share
/// extension ingests `public.url` through its web translators and cannot read an RIS at all. A
/// second, drifting spelling would break the fallback on one platform only.
///
/// Version history:
///   1.0 — Session 2026-08-10: #358 (F-8)
@Suite("Canonical document URL (#358)")
struct FRUSCanonicalURLTests {

    @Test("It builds the history.state.gov address the FRUS site actually uses")
    func buildsTheRealAddress() {
        #expect(FRUSCanonicalURL.string(volumeId: "frus1969-76v01", documentId: "d1")
                == "https://history.state.gov/historicaldocuments/frus1969-76v01/d1")
        // The exporters document this exact shape; if it ever diverges, the RIS/BibTeX `UR`/`url`
        // fields and the iOS share entry would point at different pages for the same document.
        #expect(FRUSCanonicalURL.url(volumeId: "frus1952-54v01p1", documentId: "d243")?
                .absoluteString.hasSuffix("/frus1952-54v01p1/d243") == true)
    }

    @Test("An unusable identifier yields nil rather than a broken URL")
    func refusesEmptyIdentifiers() {
        // The share entry is conditional on this returning non-nil, so a bad id removes the row
        // rather than offering Zotero a link to a 404.
        #expect(FRUSCanonicalURL.url(volumeId: "", documentId: "d1") == nil)
        #expect(FRUSCanonicalURL.url(volumeId: "frus1969-76v01", documentId: "") == nil)
    }

    @Test("The macOS export helper routes through the same builder")
    func macOSHelperSharesTheSpelling() throws {
        // `DocumentExportSupport` is inside `#if os(macOS)`, so this cannot be called from an iOS
        // test — assert by source that it delegates rather than re-spelling the URL.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/App/SupportingViews.swift"),
            encoding: .utf8)
        #expect(source.contains("FRUSCanonicalURL.string(volumeId:"), """
            The macOS canonicalURL must delegate to the shared builder. Two spellings of this URL \
            is exactly the drift #358's fallback cannot survive.
            """)
        #expect(!source.contains("\"https://history.state.gov/historicaldocuments/\\("),
                "the macOS helper still spells the URL itself")
    }
}

// MARK: - ZoteroIOSDeadEndTests

/// That neither iOS Zotero surface ends in a dead end (#358).
///
/// Verified upstream in `Planning/Completed/BigPicture-ZoteroExport.md`: `zotero-ios` declares no
/// `CFBundleDocumentTypes` for `.ris`/`.bib` and has no File → Import, and its share extension
/// runs web translators over `public.url` with no citation-file parser. So an RIS shared on iOS
/// makes Zotero *appear* in the sheet and then does nothing — the reported symptom.
///
/// Version history:
///   1.0 — Session 2026-08-10: #358 (F-8)
@Suite("Zotero iOS dead ends (#358)")
struct ZoteroIOSDeadEndTests {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    @Test("The document share menu offers the web-page route on iOS")
    func documentMenuOffersTheWorkingRoute() throws {
        let view = try source("FRUSExplorer/DocumentView/DocumentView.swift")
        // The QUOTED key, not the bare substring: `"document.share.zoteroWebRemoved"` contains
        // `document.share.zoteroWeb`, so a loose check passes while the entry is gone. A mutation
        // renaming the key proved it.
        #expect(view.contains("\"document.share.zoteroWeb\""), """
            Without this entry the iOS menu offers only BibTeX and RIS files, neither of which \
            Zotero on iOS can read — every route to Zotero is a dead end for a user with no API \
            key, which is what #358 reports.
            """)
        #expect(view.contains("FRUSCanonicalURL.url(volumeId:"),
                "the entry must share the URL, not spell a second one")
    }

    @Test("The collection row does not promise an RIS route into Zotero on iOS")
    func collectionRowDoesNotOverPromise() throws {
        let sheet = try source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        // The retired caption read "Falls back to an RIS file with no account" on BOTH platforms.
        #expect(!sheet.contains("Falls back to an RIS file with no account."), """
            That caption is false on iOS: the file reaches nothing there. It was replaced by a \
            platform-aware one that names the Mac.
            """)
        #expect(sheet.contains("export.zotero.send.caption.iosNoAccount"))
        #expect(sheet.contains("not on iPhone or iPad"),
                "the iOS caption must say plainly where the file does and does not work")
    }

    @Test("A failed send offers the file route instead of ending")
    func failedSendRecovers() throws {
        let sheet = try source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        #expect(sheet.contains("zoteroFileRecoveryOffered = true"), """
            A failed send used to end at an error message, discarding the resolved collection. \
            The file route does not depend on whatever broke the API call.
            """)
        #expect(sheet.contains("export.zotero.recover"))
        // …and the offer must be cleared when a new export starts, or a stale button survives.
        #expect(sheet.contains("zoteroFileRecoveryOffered = false"))
        // Both the missing-credentials guard and the catch must set it — a send can fail either way.
        #expect(sheet.components(separatedBy: "zoteroFileRecoveryOffered = true").count - 1 >= 2,
                "both failure paths must offer the recovery")
    }
}

// MARK: - CollectionZoteroSendNotesTests

/// The collection's Zotero send follows each document's research-notes setting (#2000).
///
/// The send took each resolved document's Zotero item as it stood and read no setting, so a note its
/// author had turned off for the collection, a section or a document went into their Zotero library.
/// It is a `private` function of a view, which no test can call, so the first test reads it: the send
/// posts the RIS file's records (`ZoteroCollectionExporter.records(for:options:)`, which the kit's
/// `CollectionNotesSettingTests` hold to the page), under the options the RIS file is written with.
/// It failed on the code before the fix. The second test holds those options to the collection's own
/// switch, which is the app's.
///
/// Version history:
///   1.0 — L29 (#2000): initial implementation
@Suite("The collection's Zotero send follows each document's research-notes setting (#2000)")
struct CollectionZoteroSendNotesTests {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    /// The text of `signature`'s function in `code`, to its closing brace at the same indentation.
    private func body(of signature: String, in code: String) throws -> Substring {
        let start = try #require(code.range(of: signature), "no \(signature)")
        let end = try #require(code.range(of: "\n    }\n", range: start.upperBound..<code.endIndex),
                               "\(signature) has no closing brace at its indentation")
        return code[start.lowerBound..<end.upperBound]
    }

    @Test("The send posts the RIS file's records, under the options the RIS file is written with")
    func sendPostsTheFilesRecords() throws {
        let sheet = try source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        let send = try body(of: "private func sendToZoteroLibrary() async {", in: sheet)
        let file = try body(of: "private func exportZoteroRIS() async {", in: sheet)
        #expect(send.contains("ZoteroCollectionExporter.records("), """
            The send must post the records the RIS file prints, each document's notes left out where \
            its notes are off. It posted every item as resolved (#2000).
            """)
        #expect(!send.contains(#"compactMap(\.zoteroItem)"#), "the send still posts the items as resolved")
        let options = "ExportFormat.zoteroJSON.exportOptions(for: collection)"
        #expect(send.contains(options) && file.contains(options),
                "the send and the RIS file must read the collection's settings through the same options")
    }

    @Test("The options the send reads carry the collection's research-notes switch")
    @MainActor
    func theOptionsCarryTheCollectionsSwitch() throws {
        let container = try ModelContainer.makeTestContainer()
        let collection = Collection(name: "Notes")
        container.mainContext.insert(collection)
        let item = ZoteroJSONExporter.Item(itemType: "bookSection", title: "Document 1",
                                           notes: [ZoteroJSONExporter.Note(note: "A note.")])
        let settings: [Bool?] = [nil, true]
        let documents: [CollectionExportItem] = settings.enumerated().map { index, notes in
            .document(CollectionExportDocument(documentId: "d\(index + 1)", volumeId: "frus1961-63v11",
                                               sortOrder: index, title: "", bodyText: "",
                                               includeNotesOverride: notes, zoteroItem: item))
        }
        func notesSent() -> [Int] {
            ZoteroCollectionExporter.records(for: documents,
                                             options: ExportFormat.zoteroJSON.exportOptions(for: collection))
                .map { $0.notes?.count ?? 0 }
        }
        #expect(notesSent() == [1, 1])
        collection.includeNotes = false
        // The collection's Off holds for the document that follows it; the other's own On wins, as
        // the page prints it.
        #expect(notesSent() == [0, 1])
        withExtendedLifetime(container) {}
    }
}
