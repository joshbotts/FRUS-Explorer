// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - StoppedZoteroSend

/// A send to Zotero that stopped part-way, as this device keeps it so that the reader can finish it (#1923):
/// how far the send got, why it stopped, and how many of the documents it sent the export history counts.
///
/// Version history:
///   1.0 — L64 of the plan of record from 2026-11-25 (#1923)
struct StoppedZoteroSend: Codable, Equatable, Sendable {
    /// How far the send got, which a finish resumes from (`ZoteroAPIClient.send(…, resuming:)`).
    var progress: ZoteroSendProgress
    /// The sentence the send stopped with, or nil when the app ended before the send did.
    var reason: String?
    /// How many of the documents the send wrote are counted in the export history already, so that a
    /// finish records the rest and the history's rows add up to the whole send. Always 0 for a document's
    /// send from its Share tile, which records no history.
    var recordedItemCount: Int

    /// What a document's Share tile says of its stopped send, on iPhone, iPad and the Mac alike: which part
    /// reached Zotero, and what Finish Sending does. The document went first, so with it in Zotero the
    /// stop came at its notes; without it, at the document itself, whose answer may have been lost.
    var documentStopSentence: String {
        if progress.writtenItemCount > 0 {
            return String(localized: "document.share.zotero.stopped.notes",
                          defaultValue: "The document is in your Zotero library, but not all of its notes are. Finish Sending adds the rest, and nothing twice.")
        }
        return String(localized: "document.share.zotero.stopped.item",
                      defaultValue: "The document may not have reached your Zotero library. Finish Sending checks, and adds what did not arrive, nothing twice.")
    }

    /// What a document's Share tile says when a send added notes alone, as the finish of a send that stopped
    /// at its notes does, in place of "Added 0 document and 2 notes to Zotero."; nil for any other result,
    /// which keeps the tile's own sentence.
    static func notesOnlyMessage(_ result: ZoteroSendResult) -> String? {
        guard result.addedItems == 0, result.failedItems == 0, result.addedNotes > 0 else { return nil }
        return CountCopy.phrase(result.addedNotes,
                                one: String(localized: "document.share.zotero.result.notes.one",
                                            defaultValue: "Added %@ note to Zotero."),
                                many: String(localized: "document.share.zotero.result.notes.many",
                                             defaultValue: "Added %@ notes to Zotero."))
    }

    // MARK: The export history's count

    /// What a collection's send that stopped with `stopped` leaves, when it ran from `earlier` (a finish) or
    /// from nothing: the documents the export history has yet to count, which the sheet records at once as
    /// a `zotero-api` row when there are any, and the record to keep, which counts them as recorded.
    ///
    /// - Parameters:
    ///   - stopped: What the send threw.
    ///   - earlier: The stopped send it finished, or nil for a new send.
    /// - Returns: The count to record, and the record to keep.
    static func afterStop(_ stopped: ZoteroSendStopped,
                          earlier: StoppedZoteroSend?) -> (historyCount: Int, record: StoppedZoteroSend) {
        let written = stopped.progress.writtenItemCount
        let record = StoppedZoteroSend(progress: stopped.progress, reason: stopped.errorDescription,
                                       recordedItemCount: written)
        return (max(0, written - (earlier?.recordedItemCount ?? 0)), record)
    }

    /// The documents the export history has yet to count when a collection's send returns `result`: all it
    /// added, for a new send; for a finish of `earlier`, also those the stopped send wrote that no row
    /// counts, as when the app ended before the send did. So the rows add up to the whole send.
    ///
    /// - Parameters:
    ///   - earlier: The stopped send it finished, or nil for a new send.
    ///   - result: What the send returned.
    /// - Returns: The count to record.
    static func historyCount(finishing earlier: StoppedZoteroSend?, with result: ZoteroSendResult) -> Int {
        let unrecorded = (earlier?.progress.writtenItemCount ?? 0) - (earlier?.recordedItemCount ?? 0)
        return max(0, unrecorded) + result.addedItems
    }
}

// MARK: - ZoteroSendProgressStore

/// Where this device keeps a stopped Zotero send (#1923): one small JSON file for each, under
/// `{Application Support}/FRUSExplorer/ZoteroSends/`, named by what was sent and the Zotero account it went to.
///
/// It is the device's alone: nothing of it reaches iCloud or the research export, so another device cannot
/// finish the send, and no CloudKit field is added (the owner's choice, plan of record decision 219). A
/// collection's send and a document's from the Share tile each write their record as the send goes, from the
/// client's `progress` closure, so a send the app did not live to see end can be finished too. A record is
/// dropped when its send finishes, when it holds nothing to finish, from its progress's `expiresAt` on
/// (12 hours after the write it holds in flight was first sent), and when Zotero is disconnected
/// (`ZoteroAccountStore.disconnect()`). One for another account is never read, since a file's name carries
/// its account.
///
/// Version history:
///   1.0 — L64 of the plan of record from 2026-11-25 (#1923)
enum ZoteroSendProgressStore {

    /// What a send was of: a collection, from its export sheet, or one document, from its Share tile.
    enum Subject: Equatable, Sendable {
        /// A collection's send, by the collection's id.
        case collection(UUID)
        /// One document's send.
        case document(volumeId: String, documentId: String)

        /// The file name's part for the subject, its ids percent-encoded so that no two subjects share one.
        var fileStem: String {
            switch self {
            case .collection(let id):
                return "collection-" + id.uuidString
            case .document(let volumeId, let documentId):
                let encoded = "\(volumeId)/\(documentId)".addingPercentEncoding(withAllowedCharacters: .alphanumerics)
                return "document-" + (encoded ?? "\(volumeId)_\(documentId)")
            }
        }
    }

    /// `{Application Support}/FRUSExplorer/ZoteroSends/`, beside the app's other device-local files.
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FRUSExplorer/ZoteroSends", isDirectory: true)
    }

    /// The file a send's record is kept in, for the Zotero account `userID`.
    static func fileURL(for subject: Subject, userID: Int, in directory: URL = defaultDirectory) -> URL {
        directory.appendingPathComponent("\(subject.fileStem)-\(userID).json")
    }

    /// The stopped send of `subject` to the connected account `userID` that a finish may start from at
    /// `now`, or nil: when there is none, and when the record holds nothing to finish or has passed its
    /// `expiresAt`, which also drops it.
    static func load(_ subject: Subject, userID: Int, at now: Date = Date(),
                     in directory: URL = defaultDirectory) -> StoppedZoteroSend? {
        let url = fileURL(for: subject, userID: userID, in: directory)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let record = try? JSONDecoder().decode(StoppedZoteroSend.self, from: data),
              record.progress.canFinish(for: userID, at: now) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return record
    }

    /// Keeps `record` for `subject`, under its progress's account; a record whose progress holds nothing to
    /// finish is dropped instead. Safe to call from any thread: the file is written whole, and a read sees it
    /// before or after.
    static func save(_ record: StoppedZoteroSend, for subject: Subject, in directory: URL = defaultDirectory) {
        let url = fileURL(for: subject, userID: record.progress.userID, in: directory)
        guard !record.progress.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(record).write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[ZoteroSendProgressStore] Could not keep a stopped send: \(error.localizedDescription)")
            #endif
        }
    }

    /// Drops the record of `subject`'s send to the account `userID`: its send finished.
    static func remove(_ subject: Subject, userID: Int, in directory: URL = defaultDirectory) {
        try? FileManager.default.removeItem(at: fileURL(for: subject, userID: userID, in: directory))
    }

    /// Drops every record, as disconnecting Zotero does.
    static func removeAll(in directory: URL = defaultDirectory) {
        try? FileManager.default.removeItem(at: directory)
    }
}
