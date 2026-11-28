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

// MARK: - ZoteroSendProgressStoreTests

/// What the app keeps of a stopped Zotero send, and what it says and records of one (#1923, L64 of the plan
/// of record from 2026-11-25).
///
/// Each test keeps its records in a folder of its own under the temporary directory, removed at its end, so
/// no test reads the app's own records or another test's. The kit's suite, `ZoteroSendResumeTests`, holds the
/// send and its finish against a Zotero stand-in; these hold the file, the sentences and the export history's
/// arithmetic, which the sheet and the Share tiles call.
///
/// Version history:
///   1.0 — 2026-11-28: L64 (#1923)
@Suite("A stopped Zotero send, kept on this device (#1923)")
struct ZoteroSendProgressStoreTests {

    /// A folder of the test's own.
    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ZoteroSends-\(UUID().uuidString)",
                                                                      isDirectory: true)
    }

    /// A progress for `userID` with `items` written (documents 1 to `items`), and an items write in flight
    /// first sent at `sent` when one is given.
    private func progress(userID: Int = 4210, items: Int, inFlightSentAt sent: Date? = nil,
                          at now: Date = Date()) -> ZoteroSendProgress {
        var progress = ZoteroSendProgress(userID: userID, at: now)
        progress.collectionKey = "COLL0001"
        progress.written = (0..<items).map { index in
            ZoteroSendProgress.WrittenItem(
                identity: .init(name: "https://history.state.gov/historicaldocuments/frus1969-76v01/d\(index + 1)",
                                occurrence: 1),
                key: "ITEM\(index)", noteDigests: [])
        }
        if let sent {
            progress.inFlight = ZoteroSendProgress.WriteInFlight(kind: .items, writeToken: "token", firstSentAt: sent,
                                                                 items: [], notes: [])
        }
        return progress
    }

    // MARK: The file

    @Test("A record is kept by its subject and account, read back whole, and dropped when its send finishes")
    func keptReadAndDropped() throws {
        let directory = folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let subject = ZoteroSendProgressStore.Subject.collection(UUID())
        let record = StoppedZoteroSend(progress: progress(items: 50), reason: "Zotero returned an unexpected error (HTTP 503).",
                                       recordedItemCount: 50)
        ZoteroSendProgressStore.save(record, for: subject, in: directory)
        #expect(ZoteroSendProgressStore.load(subject, userID: 4210, in: directory) == record)
        #expect(ZoteroSendProgressStore.load(subject, userID: 4211, in: directory) == nil, "another account's")
        #expect(ZoteroSendProgressStore.load(.collection(UUID()), userID: 4210, in: directory) == nil,
                "another collection's")

        ZoteroSendProgressStore.remove(subject, userID: 4210, in: directory)
        #expect(ZoteroSendProgressStore.load(subject, userID: 4210, in: directory) == nil)
    }

    @Test("A record with nothing to finish is not kept, and saving one drops the record it replaces")
    func anEmptyProgressIsNotKept() throws {
        let directory = folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let subject = ZoteroSendProgressStore.Subject.document(volumeId: "frus1969-76v01", documentId: "d1")
        ZoteroSendProgressStore.save(StoppedZoteroSend(progress: progress(items: 1), reason: nil, recordedItemCount: 0),
                                     for: subject, in: directory)
        #expect(ZoteroSendProgressStore.load(subject, userID: 4210, in: directory) != nil)

        // A send's last word on a stop that wrote nothing is an empty progress.
        ZoteroSendProgressStore.save(StoppedZoteroSend(progress: ZoteroSendProgress(userID: 4210, at: Date()),
                                                       reason: nil, recordedItemCount: 0),
                                     for: subject, in: directory)
        let url = ZoteroSendProgressStore.fileURL(for: subject, userID: 4210, in: directory)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("A record is read until 12 hours after its write in flight was first sent, and dropped from then")
    func twelveHours() throws {
        let directory = folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let subject = ZoteroSendProgressStore.Subject.collection(UUID())
        let sent = Date(timeIntervalSince1970: 1_800_000_000)
        let record = StoppedZoteroSend(progress: progress(items: 50, inFlightSentAt: sent, at: sent.addingTimeInterval(30)),
                                       reason: nil, recordedItemCount: 0)
        ZoteroSendProgressStore.save(record, for: subject, in: directory)
        let lastMoment = sent.addingTimeInterval(12 * 60 * 60 - 1)
        #expect(ZoteroSendProgressStore.load(subject, userID: 4210, at: lastMoment, in: directory) == record)
        #expect(ZoteroSendProgressStore.load(subject, userID: 4210, at: sent.addingTimeInterval(12 * 60 * 60),
                                             in: directory) == nil)
        let url = ZoteroSendProgressStore.fileURL(for: subject, userID: 4210, in: directory)
        #expect(!FileManager.default.fileExists(atPath: url.path), "the expired record was kept")
    }

    @Test("Disconnecting drops every record, and no two subjects share a file")
    func removeAllAndNames() throws {
        let directory = folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let one = ZoteroSendProgressStore.Subject.document(volumeId: "a-b", documentId: "c")
        let other = ZoteroSendProgressStore.Subject.document(volumeId: "a", documentId: "b-c")
        #expect(ZoteroSendProgressStore.fileURL(for: one, userID: 1, in: directory)
                != ZoteroSendProgressStore.fileURL(for: other, userID: 1, in: directory))
        for subject in [one, other] {
            ZoteroSendProgressStore.save(StoppedZoteroSend(progress: progress(items: 1), reason: nil, recordedItemCount: 0),
                                         for: subject, in: directory)
        }
        #expect(ZoteroSendProgressStore.load(one, userID: 4210, in: directory) != nil)
        ZoteroSendProgressStore.removeAll(in: directory)
        #expect(ZoteroSendProgressStore.load(one, userID: 4210, in: directory) == nil)
        #expect(ZoteroSendProgressStore.load(other, userID: 4210, in: directory) == nil)
    }

    // MARK: The export history

    @Test("A stop records the documents no row counts yet, and a finish the rest, so the rows add up to the whole send")
    func historyAddsUp() throws {
        // A new send stops with 50 written: the history counts 50 at once.
        let first = Self.stop(progress(items: 50))
        let (count, record) = StoppedZoteroSend.afterStop(first, earlier: nil)
        #expect(count == 50 && record.recordedItemCount == 50)

        // Its finish writes 5 more and stops again: 5 more.
        let (again, kept) = StoppedZoteroSend.afterStop(Self.stop(progress(items: 55)), earlier: record)
        #expect(again == 5 && kept.recordedItemCount == 55)

        // A finish then adds the last 5: 5, for 60 in all.
        #expect(StoppedZoteroSend.historyCount(finishing: kept, with: Self.result(added: 5)) == 5)

        // A send the app did not live to see end left 50 written and none recorded: its finish counts them too.
        let unrecorded = StoppedZoteroSend(progress: progress(items: 50), reason: nil, recordedItemCount: 0)
        #expect(StoppedZoteroSend.historyCount(finishing: unrecorded, with: Self.result(added: 10)) == 60)
        #expect(StoppedZoteroSend.historyCount(finishing: nil, with: Self.result(added: 12)) == 12, "a new send, as before")
    }

    private static func stop(_ progress: ZoteroSendProgress) -> ZoteroSendStopped {
        ZoteroSendStopped(cause: ZoteroAPIError.http(503), progress: progress)
    }

    private static func result(added: Int) -> ZoteroSendResult {
        ZoteroSendResult(addedItems: added, failedItems: 0, addedNotes: 0, collectionKey: "COLL0001", webURL: nil,
                         itemsLeftInLibrary: 0)
    }

    // MARK: What the app says

    @Test("A document's stopped send says which part stopped: its notes, or the document itself")
    func theDocumentsStopSentence() {
        let notes = StoppedZoteroSend(progress: progress(items: 1), reason: nil, recordedItemCount: 0)
        #expect(notes.documentStopSentence.hasPrefix("The document is in your Zotero library, but not all of its notes are."))
        let item = StoppedZoteroSend(progress: progress(items: 0, inFlightSentAt: Date()), reason: nil, recordedItemCount: 0)
        #expect(item.documentStopSentence.hasPrefix("The document may not have reached your Zotero library."))
    }

    @Test("A finish that added notes alone says so, where the Share tile's own sentence would read “Added 0 document”")
    func aNotesOnlyFinish() {
        func result(items: Int, failed: Int = 0, notes: Int) -> ZoteroSendResult {
            ZoteroSendResult(addedItems: items, failedItems: failed, addedNotes: notes, collectionKey: nil, webURL: nil,
                             itemsLeftInLibrary: 0)
        }
        #expect(StoppedZoteroSend.notesOnlyMessage(result(items: 0, notes: 2)) == "Added 2 notes to Zotero.")
        #expect(StoppedZoteroSend.notesOnlyMessage(result(items: 0, notes: 1)) == "Added 1 note to Zotero.")
        #expect(StoppedZoteroSend.notesOnlyMessage(result(items: 1, notes: 2)) == nil, "a document's send, as before")
        #expect(StoppedZoteroSend.notesOnlyMessage(result(items: 0, failed: 1, notes: 0)) == nil, "a refused document")
    }

    @Test("The collection's row says how many documents reached Zotero and when, why it stopped, and what Finish Sending does")
    @MainActor
    func theCollectionsStoppedCaption() {
        // A locale that groups thousands, which the count follows; the date is the reader's own.
        let locale = Locale(identifier: "en_US")
        let at = Date(timeIntervalSince1970: 1_800_000_000)
        let when = at.formatted(date: .abbreviated, time: .shortened)
        let finish = "Finish Sending sends the rest into the same Zotero collection, and nothing twice."
        let many = StoppedZoteroSend(progress: progress(items: 1_250, at: at), reason: "Couldn’t reach Zotero.",
                                     recordedItemCount: 1_250)
        #expect(ExportSheetView.zoteroStoppedCaption(many, locale: locale)
                == "1,250 documents reached Zotero on \(when), before the send stopped. Couldn’t reach Zotero. \(finish)")
        let one = StoppedZoteroSend(progress: progress(items: 1, at: at), reason: nil, recordedItemCount: 1)
        #expect(ExportSheetView.zoteroStoppedCaption(one, locale: locale)
                == "1 document reached Zotero on \(when), before the send stopped. \(finish)")
        let none = StoppedZoteroSend(progress: progress(items: 0, inFlightSentAt: at, at: at), reason: nil,
                                     recordedItemCount: 0)
        #expect(ExportSheetView.zoteroStoppedCaption(none, locale: locale)
                == "A send on \(when) stopped before Zotero confirmed any of its documents. \(finish)")
    }
}
