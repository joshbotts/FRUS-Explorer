// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Talks to the Zotero Web API v3 to push FRUS documents, tags, notes, and a
/// destination collection directly into the user's library (which then syncs to
/// their Zotero apps, including iOS — the only annotation-preserving path there).
///
/// Authentication is a user-supplied API key (passed per call from
/// `ZoteroAccountStore`); no OAuth flow. Writes are chunked to Zotero's 50-item
/// limit, carry a `Zotero-Write-Token` for idempotency on retry, and honour the
/// `Retry-After` (429) and advisory `Backoff` headers, each wait at most `longestWait`.
/// A `Backoff` holds the account's next write, whichever client in the process makes it
/// (`ZoteroBackoffDeadlines`), and a send reports each wait through its `status` first.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
///   1.1 — FRUS Explorer Light's S22c: in FRUSCoreKit, public, with `URLSession` from
///          FoundationNetworking on Linux; the key was a parameter already
///   1.2 — FRUS Explorer Light's follow-up for S22e: a wait on Zotero's word reads only seconds
///          that are finite and not negative (`headerSeconds(_:)`) and lasts at most `longestWait`,
///          so no header value can trap the client or hold a send without end; the waits go
///          through a sleep a test can replace (`init(session:sleep:)`)
///   1.3 — L41 of the plan of record from 2026-11-25: a `Backoff` is waited before the account's
///          next write, under a deadline every client in the process sees, where it was waited
///          after the write that gave it, so a send returns as soon as its last write succeeds
///          (#1924); a send reports each wait through its `status` before it (#1925); and a
///          `Retry-After` that is an HTTP date is read as the seconds until it (#1926)
///   1.4 — L64 of the plan of record from 2026-11-25 (#1923): a send keeps how far it got
///          (`ZoteroSendProgress`), hands it to a host as it goes, and throws it in
///          `ZoteroSendStopped` when it stops once Zotero may have taken part of it;
///          `send(…, resuming:)` finishes such a send, sending again under its own token a write
///          whose answer was lost, and reading what Zotero made when Zotero refuses that token as
///          used (412)
public actor ZoteroAPIClient {

    private let session: URLSession
    private let base = URL(string: "https://api.zotero.org")!
    private let maxBatch = 50
    private let maxRetries = 3
    /// Waits the given nanoseconds: `Task.sleep`, or a test's recorder.
    private let sleepNanoseconds: @Sendable (UInt64) async throws -> Void
    /// The moment a `Backoff`'s deadline is set from and read against: `ContinuousClock`'s, or a test's.
    private let now: @Sendable () -> ContinuousClock.Instant
    /// The date a `Retry-After` date is counted from when the response carries no `Date` the client
    /// can read: the device's, or a test's.
    private let wallClock: @Sendable () -> Date
    /// Where each account's `Backoff` deadline is kept: the process's, unless a test passes its own.
    private let deadlines: ZoteroBackoffDeadlines

    /// The longest the client waits at once on Zotero's word, in seconds: a 429's `Retry-After`,
    /// or a `Backoff`. It is above the 30 s a 429 waits when it gives no seconds the client can
    /// use, so that default, and any well-formed value up to a minute, waits as it always has.
    /// Zotero's documentation names two forms of rate limiting, and the client treats them apart:
    /// - A 429 is the hard limit: the request was refused, and Zotero asks for none before its
    ///   `Retry-After`. Past this wait the 429 reaches the caller at once, as
    ///   `ZoteroAPIError.rateLimited`, rather than a retry before Zotero's time, which breaks its
    ///   rule and invites stricter throttling.
    /// - A `Backoff` is a request to slow down, on a write that succeeded. The account's next
    ///   write waits it out, for this long at most, and the send goes on, its remaining writes
    ///   inside a longer backoff: a bounded departure from the advice to make no request until it
    ///   ends, so that a send is not stopped part-way, with what it already wrote kept in the
    ///   library and nothing to say so.
    static let longestWait: TimeInterval = 60

    /// Creates a client. Its waits are real, and it holds to the `Backoff` deadlines that every
    /// client in the process shares (`ZoteroBackoffDeadlines.shared`).
    /// - Parameter session: URL session (injectable for testing).
    public init(session: URLSession = .shared) {
        self.init(session: session, sleep: { try await Task.sleep(nanoseconds: $0) })
    }

    /// Creates a client whose waits go to `sleep`, in nanoseconds, so that a test can read the
    /// waits the client asks for without waiting them out. A `Backoff`'s deadline is set and read
    /// by `now` and kept in `deadlines`, and a `Retry-After` date is counted from `wallClock` when
    /// the response carries no `Date` the client can read.
    init(session: URLSession,
         sleep: @escaping @Sendable (UInt64) async throws -> Void,
         now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now },
         wallClock: @escaping @Sendable () -> Date = { Date() },
         deadlines: ZoteroBackoffDeadlines = .shared) {
        self.session = session
        self.sleepNanoseconds = sleep
        self.now = now
        self.wallClock = wallClock
        self.deadlines = deadlines
    }

    // MARK: - Account

    /// Resolves the owner and permissions of an API key (`GET /keys/<key>`).
    ///
    /// - Throws: `.invalidKey` on 403/404, `.insufficientPermissions` if the key
    ///   can't write notes, or a network/decoding error.
    public func resolveAccount(key: String) async throws -> ZoteroKeyInfo {
        var request = URLRequest(url: base.appendingPathComponent("keys/\(key)"))
        request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, invalidKeyOn: [403, 404], localNow: wallClock())
        guard let info = try? JSONDecoder().decode(ZoteroKeyInfo.self, from: data) else {
            throw ZoteroAPIError.decoding
        }
        guard info.canWriteNotes else { throw ZoteroAPIError.insufficientPermissions }
        return info
    }

    // MARK: - High-level send

    /// Pushes the given items (with their tags and notes) into the user's library, optionally creating a
    /// new collection to hold them, or finishes a send that stopped part-way (#1923).
    ///
    /// A send makes one write for the collection, one for each 50 items and one for each 50
    /// notes, and each write waits on Zotero's word when it asks: up to a minute before each of
    /// three retries of a 429, and, before it begins, up to a minute while the account's last
    /// `Backoff` runs, from this send's write before it or from an earlier send, so one write can
    /// take four minutes, or longer while another send for the account is answered with a `Backoff`. The `Backoff` on a send's last write is left to the account's next
    /// write, so a send returns as soon as its last write succeeds. Each wait is reported through
    /// `status` before it, and the step's own message again after it. A 429 that asks for longer
    /// than a minute stops the send there, as `ZoteroAPIError.rateLimited`, with the writes before
    /// it kept in the library.
    ///
    /// **How far it got.** The send keeps a `ZoteroSendProgress` as it goes, and hands it to `progress`
    /// before each write leaves, after each answer is read, and when it stops, so a host that keeps the last
    /// one it was given can finish a send its process did not live to see end. A send that stops once Zotero
    /// may have taken part of it, after an answer was read or with a write out whose answer was not, throws
    /// `ZoteroSendStopped` with that progress. One that stops before throws its error alone, as it did before.
    ///
    /// **A finish.** Given in `earlier` a stopped send's progress for this account, the send makes no second
    /// collection and writes nothing Zotero took. It sends the write in flight again under its own token, then
    /// the items Zotero has not taken and the notes not written under those it has, so a collection edited since
    /// the stop sends what was added and leaves what was removed (`ZoteroSendResult.itemsLeftInLibrary`). When
    /// Zotero refuses the write in flight's token as used (412), the write landed, and the finish reads what it
    /// made (`ZoteroSendProgress` says how). A progress for another account is not resumed: the send starts
    /// afresh. A host offers no finish from the progress's `expiresAt` (`ZoteroSendProgress.canFinish(for:at:)`),
    /// which the client does not check.
    ///
    /// - Parameters:
    ///   - items: Resolved export items (tags + notes already attached).
    ///   - collectionName: When non-nil, a new collection is created and every item
    ///     placed in it, unless `earlier` holds the one a stopped send made.
    ///   - apiKey: The user's API key.
    ///   - userID: The resolved numeric user ID.
    ///   - username: The username, used to build a "View in Zotero" web URL.
    ///   - earlier: The progress of a stopped send to finish (`ZoteroSendStopped.progress`), or nil.
    ///   - status: Progress callback (human-readable): each step, and each wait on Zotero's word
    ///     with its seconds (`retryStatus(seconds:locale:)`, `backoffStatus(seconds:locale:)`).
    ///   - progress: Called on the client's actor with the send's progress before each write leaves, after
    ///     each answer is read, and when the send stops, for a host that keeps it as the send goes.
    /// - Returns: A summary of what was created. A finish's counts what it wrote or found written, so the
    ///   stopped send's progress and the finish's result together count the whole send.
    /// - Throws: `ZoteroSendStopped` when the send stops once Zotero may have taken part of it, else the
    ///   error that stopped it.
    public func send(
        items: [ZoteroJSONExporter.Item],
        collectionName: String?,
        apiKey: String,
        userID: Int,
        username: String?,
        resuming earlier: ZoteroSendProgress? = nil,
        status: @Sendable (String) -> Void = { _ in },
        progress report: @Sendable (ZoteroSendProgress) -> Void = { _ in }
    ) async throws -> ZoteroSendResult {
        let resumed = earlier?.userID == userID ? earlier : nil
        let identities = ZoteroSendProgress.ItemIdentity.of(items)
        let given = Set(identities)
        let leftInLibrary = resumed?.written.filter { !given.contains($0.identity) }.count ?? 0
        guard !items.isEmpty else {
            return ZoteroSendResult(addedItems: 0, failedItems: 0, addedNotes: 0,
                                    collectionKey: nil, webURL: nil, itemsLeftInLibrary: leftInLibrary)
        }

        var run = SendRun(progress: resumed ?? ZoteroSendProgress(userID: userID, at: wallClock()), apiKey: apiKey)
        do {
            try await settleWriteInFlight(items, identities: identities, collectionName: collectionName, &run,
                                          status: status, report: report)
            try await sendCollection(named: collectionName, &run, status: status, report: report)
            try await sendItems(items, identities: identities, &run, status: status, report: report)
            try await sendNotes(items, identities: identities, &run, status: status, report: report)
        } catch {
            report(run.progress)
            if run.progress.isEmpty { throw error }
            throw ZoteroSendStopped(cause: error, progress: run.progress)
        }
        return ZoteroSendResult(
            addedItems: run.addedItems,
            failedItems: run.failedItems,
            addedNotes: run.addedNotes,
            collectionKey: run.progress.collectionKey,
            webURL: Self.collectionWebURL(username: username, collectionKey: run.progress.collectionKey),
            itemsLeftInLibrary: leftInLibrary
        )
    }

    // MARK: - A finish's write in flight (#1923)

    /// Settles the write a stopped send left in flight, before anything else is written: sends it again under
    /// its own token, and, when Zotero refuses the token as used, reads what the write made. So a finish never
    /// holds two writes in flight, and a later write of it, of documents added since, records its own.
    private func settleWriteInFlight(_ items: [ZoteroJSONExporter.Item],
                                     identities: [ZoteroSendProgress.ItemIdentity], collectionName: String?,
                                     _ run: inout SendRun,
                                     status: @Sendable (String) -> Void,
                                     report: @Sendable (ZoteroSendProgress) -> Void) async throws {
        guard let inFlight = run.progress.inFlight else { return }
        switch inFlight.kind {
        case .collection:
            try await settleCollection(named: collectionName, &run, status: status, report: report)
        case .items:
            try await settleItems(inFlight, items, identities: identities, &run, status: status, report: report)
        case .notes:
            try await settleNotes(inFlight, items, identities: identities, &run, status: status, report: report)
        }
        run.progress.updatedAt = wallClock()
        report(run.progress)
    }

    /// Settles a collection write in flight. A 412 means Zotero made the collection, which the account's
    /// collections then name; when they name none, the collection step makes it anew.
    private func settleCollection(named name: String?, _ run: inout SendRun,
                                  status: @Sendable (String) -> Void,
                                  report: @Sendable (ZoteroSendProgress) -> Void) async throws {
        guard let name else {
            // A send with no collection cannot name the one in flight: its items go to the library.
            run.progress.inFlight = nil
            return
        }
        let step = Self.collectionStatus
        status(step)
        if let response = try await write(Self.collectionBody(name), path: "collections", kind: .collection,
                                          resending: true, &run, step: step, status: status, report: report) {
            try run.recordCollection(from: response, at: wallClock())
        } else {
            status(Self.checkingStatus)
            run.progress.collectionKey = try await madeCollectionKey(named: name, run, status: status)
            run.progress.inFlight = nil
        }
    }

    /// Settles an items write in flight, its items as the send now has them. A 412 means Zotero took it, and
    /// the items Zotero lists give their keys; an item it lists none for is written with the rest.
    private func settleItems(_ inFlight: ZoteroSendProgress.WriteInFlight, _ items: [ZoteroJSONExporter.Item],
                             identities: [ZoteroSendProgress.ItemIdentity], _ run: inout SendRun,
                             status: @Sendable (String) -> Void,
                             report: @Sendable (ZoteroSendProgress) -> Void) async throws {
        let carried = Set(inFlight.items)
        let batch = identities.indices.filter { carried.contains(identities[$0]) && run.key(for: identities[$0]) == nil }
        guard !batch.isEmpty else {
            // Every item it carried has left the send since: none of it is wanted now.
            run.progress.inFlight = nil
            return
        }
        let taken = identities.filter { run.key(for: $0) != nil }.count
        let step = Self.itemsStatus(from: taken + 1, to: taken + batch.count)
        status(step)
        let batchIdentities = batch.map { identities[$0] }
        let body = try JSONEncoder().encode(batch.map { ZoteroAPIItem(item: items[$0], collectionKey: run.progress.collectionKey) })
        if let response = try await write(body, path: "items", kind: .items, items: batchIdentities,
                                          resending: true, &run, step: step, status: status, report: report) {
            run.record(response, forItems: batchIdentities)
        } else {
            status(Self.checkingStatus)
            let found = try await listedKeys(for: batchIdentities, run, status: status)
            for identity in batchIdentities {
                if let key = found[identity] { run.recordItem(identity, key: key) }
            }
            run.progress.inFlight = nil
        }
    }

    /// Settles a notes write in flight, with those of its notes the send still has to write. A 412 means
    /// Zotero took it, and its notes are counted as written.
    private func settleNotes(_ inFlight: ZoteroSendProgress.WriteInFlight, _ items: [ZoteroJSONExporter.Item],
                             identities: [ZoteroSendProgress.ItemIdentity], _ run: inout SendRun,
                             status: @Sendable (String) -> Void,
                             report: @Sendable (ZoteroSendProgress) -> Void) async throws {
        var carried = Dictionary(inFlight.notes.map { ($0, 1) }, uniquingKeysWith: +)
        let batch = run.notesToWrite(items, identities: identities).filter { pending in
            guard let count = carried[pending.ref], count > 0 else { return false }
            carried[pending.ref] = count - 1
            return true
        }
        guard !batch.isEmpty else {
            // Every note it carried has left the send since: none of it is wanted now.
            run.progress.inFlight = nil
            return
        }
        let step = Self.notesStatus
        status(step)
        let refs = batch.map(\.ref)
        let body = try JSONEncoder().encode(batch.map(\.note))
        if let response = try await write(body, path: "items", kind: .notes, notes: refs, resending: true,
                                          &run, step: step, status: status, report: report) {
            run.record(response, forNotes: refs)
        } else {
            for ref in refs { run.recordNote(ref) }
            run.progress.inFlight = nil
        }
    }

    // MARK: - The send's three steps

    /// Writes the Zotero collection, unless the send makes none or the progress holds its key.
    private func sendCollection(named name: String?, _ run: inout SendRun,
                                status: @Sendable (String) -> Void,
                                report: @Sendable (ZoteroSendProgress) -> Void) async throws {
        guard let name, run.progress.collectionKey == nil else { return }
        let step = Self.collectionStatus
        status(step)
        guard let response = try await write(Self.collectionBody(name), path: "collections", kind: .collection,
                                             resending: false, &run, step: step, status: status, report: report)
        else { throw ZoteroAPIError.http(412) }
        try run.recordCollection(from: response, at: wallClock())
        report(run.progress)
    }

    /// Writes the items Zotero has not taken, fifty at a time, each batch's items numbered among the send's.
    private func sendItems(_ items: [ZoteroJSONExporter.Item], identities: [ZoteroSendProgress.ItemIdentity],
                           _ run: inout SendRun,
                           status: @Sendable (String) -> Void,
                           report: @Sendable (ZoteroSendProgress) -> Void) async throws {
        let rest = identities.indices.filter { run.key(for: identities[$0]) == nil }
        var handled = identities.count - rest.count
        var offset = 0
        while offset < rest.count {
            try Task.checkCancellation()
            let chunk = Array(rest[offset..<min(offset + maxBatch, rest.count)])
            let step = Self.itemsStatus(from: handled + 1, to: handled + chunk.count)
            status(step)
            let chunkIdentities = chunk.map { identities[$0] }
            let body = try JSONEncoder().encode(chunk.map { ZoteroAPIItem(item: items[$0], collectionKey: run.progress.collectionKey) })
            guard let response = try await write(body, path: "items", kind: .items, items: chunkIdentities,
                                                 resending: false, &run, step: step, status: status, report: report)
            else { throw ZoteroAPIError.http(412) }
            run.record(response, forItems: chunkIdentities)
            run.progress.updatedAt = wallClock()
            report(run.progress)
            handled += chunk.count
            offset += maxBatch
        }
    }

    /// Writes the notes not yet written under the items Zotero took, fifty at a time. An item's notes are known
    /// by their text, so a note sent is not sent again, and one the item gained since a stop is sent.
    private func sendNotes(_ items: [ZoteroJSONExporter.Item], identities: [ZoteroSendProgress.ItemIdentity],
                           _ run: inout SendRun,
                           status: @Sendable (String) -> Void,
                           report: @Sendable (ZoteroSendProgress) -> Void) async throws {
        let notes = run.notesToWrite(items, identities: identities)
        var offset = 0
        while offset < notes.count {
            try Task.checkCancellation()
            let chunk = Array(notes[offset..<min(offset + maxBatch, notes.count)])
            let step = Self.notesStatus
            status(step)
            let refs = chunk.map(\.ref)
            let body = try JSONEncoder().encode(chunk.map(\.note))
            guard let response = try await write(body, path: "items", kind: .notes, notes: refs, resending: false,
                                                 &run, step: step, status: status, report: report)
            else { throw ZoteroAPIError.http(412) }
            run.record(response, forNotes: refs)
            run.progress.updatedAt = wallClock()
            report(run.progress)
            offset += maxBatch
        }
    }

    // MARK: - Reading what a write made (#1923)

    /// The key of the collection a write in flight made, once Zotero has refused its token as used: of the
    /// account's collections named `name` that hold no items yet, the one Zotero changed last, or nil when
    /// none is. Read a hundred at a time, for at most `maxReadPages` pages.
    private func madeCollectionKey(named name: String, _ run: SendRun,
                                   status: @Sendable (String) -> Void) async throws -> String? {
        var best: (key: String, version: Int)?
        var start = 0
        for _ in 0..<Self.maxReadPages {
            let page = try await readPage("collections", start: start, as: ListedCollection.self, run, status: status)
            for collection in page.entries where collection.data?.name == name && collection.meta?.numItems == 0 {
                let version = collection.version ?? 0
                if best.map({ version > $0.version }) ?? true { best = (collection.key, version) }
            }
            start += page.entries.count
            if page.entries.isEmpty || start >= page.total { break }
        }
        return best?.key
    }

    /// The keys Zotero gave the items of `identities`, once it has refused an items write's token as used:
    /// read by each item's identity from the Zotero collection's items, or from the library's hundred newest
    /// where the send makes no collection. An item whose key the progress holds is passed over, so the copies
    /// of a document entered twice take a key each.
    private func listedKeys(for identities: [ZoteroSendProgress.ItemIdentity], _ run: SendRun,
                            status: @Sendable (String) -> Void) async throws -> [ZoteroSendProgress.ItemIdentity: String] {
        let known = Set(run.progress.written.map(\.key))
        let path: String
        let query: [URLQueryItem]
        let pages: Int
        if let collectionKey = run.progress.collectionKey {
            (path, query, pages) = ("collections/\(collectionKey)/items/top", [], Self.maxReadPages)
        } else {
            (path, query, pages) = ("items/top", [URLQueryItem(name: "sort", value: "dateAdded"),
                                                  URLQueryItem(name: "direction", value: "desc")], 1)
        }
        var keysByName: [String: [String]] = [:]
        var start = 0
        for _ in 0..<pages {
            let page = try await readPage(path, query: query, start: start, as: ListedItem.self, run, status: status)
            for item in page.entries where !known.contains(item.key) {
                let name = ZoteroSendProgress.ItemIdentity.name(url: item.data?.url, title: item.data?.title)
                keysByName[name, default: []].append(item.key)
            }
            start += page.entries.count
            if page.entries.isEmpty || start >= page.total { break }
        }
        var found: [ZoteroSendProgress.ItemIdentity: String] = [:]
        for identity in identities {
            guard var keys = keysByName[identity.name], !keys.isEmpty else { continue }
            found[identity] = keys.removeFirst()
            keysByName[identity.name] = keys
        }
        return found
    }

    /// One page of a list Zotero gives in `format=json`, a hundred entries from `start`, and the total it says
    /// the list holds (`Total-Results`), through a write's waits on Zotero's word. A 404 is an empty list,
    /// as when the reader has deleted the Zotero collection since; an answer the client cannot read is
    /// `ZoteroAPIError.decoding`.
    private func readPage<Entry: Decodable>(_ path: String, query: [URLQueryItem] = [], start: Int,
                                             as entry: Entry.Type, _ run: SendRun,
                                             status: @Sendable (String) -> Void) async throws -> (entries: [Entry], total: Int) {
        var components = URLComponents(url: base.appendingPathComponent("users/\(run.userID)/\(path)"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "format", value: "json"),
                                  URLQueryItem(name: "limit", value: String(Self.readPageSize)),
                                  URLQueryItem(name: "start", value: String(start))] + query
        guard let url = components?.url else { throw ZoteroAPIError.network("No URL") }
        let apiKey = run.apiKey
        let answer: (data: Data, response: HTTPURLResponse)
        do {
            answer = try await exchange(userID: run.userID, step: Self.checkingStatus, status: status) {
                var request = URLRequest(url: url)
                request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                return request
            }
        } catch ZoteroAPIError.http(404) {
            return ([], 0)
        }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: answer.data) else {
            throw ZoteroAPIError.decoding
        }
        let total = answer.response.value(forHTTPHeaderField: "Total-Results").flatMap(Int.init) ?? entries.count
        return (entries, total)
    }

    /// The most pages a read of what a write made reads, a hundred entries each: a Zotero collection's items,
    /// or the account's collections, past 5,000 are not read.
    static let maxReadPages = 50

    /// How many entries a page of a read asks for: the most Zotero gives.
    static let readPageSize = 100

    // MARK: - Primitives

    /// One write of a send: `body` POSTed to `path`, under the token of the write in flight when `resending`,
    /// else under a new one, which the progress records as in flight, and `report` hears, before the request
    /// first leaves (#1923). Zotero's answer is returned for the caller to record, which clears the write in
    /// flight. A write Zotero refused (`isRefusal(_:)`) wrote nothing: when it was not in flight before, it is
    /// cleared, so a stop there leaves no write in flight. Any other error leaves it in flight, since Zotero
    /// may have taken it.
    ///
    /// - Returns: Zotero's answer; or nil when `resending` and Zotero refuses the token as used (412), which
    ///   means it took the write before.
    private func write(_ body: Data, path: String, kind: ZoteroSendProgress.WriteKind,
                       items: [ZoteroSendProgress.ItemIdentity] = [], notes: [ZoteroSendProgress.NoteRef] = [],
                       resending: Bool, _ run: inout SendRun, step: String,
                       status: @Sendable (String) -> Void,
                       report: @Sendable (ZoteroSendProgress) -> Void) async throws -> ZoteroWriteResponse? {
        let token = resending ? (run.progress.inFlight?.writeToken ?? Self.writeToken()) : Self.writeToken()
        let (apiKey, userID) = (run.apiKey, run.userID)
        do {
            return try await writeRequest(path: path, body: body, token: token, apiKey: apiKey, userID: userID,
                                          step: step, status: status) {
                guard run.progress.inFlight == nil else { return }
                let sent = wallClock()
                run.progress.inFlight = ZoteroSendProgress.WriteInFlight(kind: kind, writeToken: token, firstSentAt: sent,
                                                                         items: items, notes: notes)
                run.progress.updatedAt = sent
                report(run.progress)
            }
        } catch ZoteroAPIError.http(412) where resending {
            return nil
        } catch {
            if !resending, Self.isRefusal(error) {
                run.progress.inFlight = nil
                run.progress.updatedAt = wallClock()
            }
            throw error
        }
    }

    /// Performs a POST under `writeToken`, with the waits and retries of `exchange`, returning the write
    /// response. `willSend` runs before each attempt leaves.
    private func writeRequest(
        path: String, body: Data, token writeToken: String, apiKey: String, userID: Int, step: String,
        status: @Sendable (String) -> Void, willSend: () -> Void
    ) async throws -> ZoteroWriteResponse {
        let url = base.appendingPathComponent("users/\(userID)/\(path)")
        let answer = try await exchange(userID: userID, step: step, status: status, willSend: willSend) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(writeToken, forHTTPHeaderField: "Zotero-Write-Token")
            return request
        }
        guard let decoded = try? JSONDecoder().decode(ZoteroWriteResponse.self, from: answer.data) else {
            throw ZoteroAPIError.decoding
        }
        return decoded
    }

    /// Sends the request `make` builds until Zotero answers it, and returns a 2xx's body and response.
    ///
    /// Each attempt first waits what is left of the account's `Backoff` (`holdToBackoff`), then runs
    /// `willSend`, then sends. A 2xx's own `Backoff` sets that deadline and is not waited here, so a send's
    /// last request returns at once and its next one, or the account's next send, waits it (#1924). A 429 is
    /// retried up to three times, each after its `Retry-After`, reported through `status` first and `step`
    /// again after (#1925); one that asks for longer than `longestWait` reaches the caller at once.
    private func exchange(
        userID: Int, step: String, status: @Sendable (String) -> Void, willSend: () -> Void = {},
        _ make: () -> URLRequest
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var attempt = 0
        while true {
            try await holdToBackoff(userID: userID, step: step, status: status)
            willSend()
            do {
                let (data, response) = try await perform(make())
                try Self.checkStatus(response, invalidKeyOn: [403], localNow: wallClock())
                if let backoff = Self.backoffSeconds(response), backoff > 0 {
                    // This request succeeded: the account's next waits, for `longestWait` at most.
                    await deadlines.hold(userID, until: now().advanced(by: .seconds(min(backoff, Self.longestWait))))
                }
                guard let http = response as? HTTPURLResponse else { throw ZoteroAPIError.network("No HTTP response") }
                return (data, http)
            } catch let ZoteroAPIError.rateLimited(retryAfter) where attempt < maxRetries {
                // Zotero asks for no request before `retryAfter`: past `longestWait` the caller hears it now.
                guard retryAfter <= Self.longestWait else { throw ZoteroAPIError.rateLimited(retryAfter: retryAfter) }
                attempt += 1
                if retryAfter > 0 { status(Self.retryStatus(seconds: retryAfter)) }
                try await pause(retryAfter)
                if retryAfter > 0 { status(step) }
                continue
            }
        }
    }

    /// Waits what is left of the account's `Backoff` deadline, saying so through `status` first and
    /// `step` again after, or returns at once when the account has none or it has passed (#1924, #1925).
    private func holdToBackoff(userID: Int, step: String, status: @Sendable (String) -> Void) async throws {
        guard let remaining = await deadlines.remaining(for: userID, at: now()), remaining > 0 else { return }
        status(Self.backoffStatus(seconds: remaining))
        try await pause(remaining)
        status(step)
    }

    /// Waits `seconds` through the client's sleep. Every caller holds it to 0...`longestWait`
    /// already; the clamp here (nothing for a value that is not finite) keeps the conversion to
    /// nanoseconds from trapping whatever a caller passes.
    private func pause(_ seconds: TimeInterval) async throws {
        let bounded = seconds.isFinite ? min(max(seconds, 0), Self.longestWait) : 0
        try await sleepNanoseconds(UInt64(bounded * 1_000_000_000))
    }

    /// Wraps `URLSession.data(for:)` to normalise transport errors.
    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw ZoteroAPIError.network(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Throws an appropriate `ZoteroAPIError` for non-2xx responses. A 429's `Retry-After` date is
    /// counted from the response's own `Date`, or from `localNow` when it has none the client can read.
    private static func checkStatus(_ response: URLResponse, invalidKeyOn: Set<Int>, localNow: Date) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ZoteroAPIError.network("No HTTP response")
        }
        switch http.statusCode {
        case 200...299:
            return
        case 429:
            // Zotero's seconds, or those until its date, or 30 when it gives none the client can use
            // (`retryAfterSeconds`).
            let retry = retryAfterSeconds(http.value(forHTTPHeaderField: "Retry-After"),
                                          responseDate: http.value(forHTTPHeaderField: "Date"),
                                          localNow: localNow) ?? 30
            throw ZoteroAPIError.rateLimited(retryAfter: retry)
        case let code where invalidKeyOn.contains(code):
            throw ZoteroAPIError.invalidKey
        default:
            throw ZoteroAPIError.http(http.statusCode)
        }
    }

    /// The advisory `Backoff` header value in seconds, if present and usable (`headerSeconds(_:)`).
    private static func backoffSeconds(_ response: URLResponse) -> TimeInterval? {
        headerSeconds((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Backoff"))
    }

    /// The seconds a `Retry-After` or `Backoff` header gives, or nil when it gives none the client can
    /// use: absent, not a number Swift reads, not finite ("nan", "inf"), or negative ("-1"). "-0" reads
    /// as 0, as "0" does. A `Backoff` is read by this alone; a `Retry-After` may also be a date
    /// (`retryAfterSeconds(_:responseDate:localNow:)`).
    static func headerSeconds(_ value: String?) -> TimeInterval? {
        guard let value, let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 else { return nil }
        return seconds == 0 ? 0 : seconds
    }

    /// The seconds a 429's `Retry-After` gives (#1926): its seconds, as `headerSeconds(_:)` reads them,
    /// or the seconds until the HTTP date it names (RFC 9110 §10.2.3), counted from the response's own
    /// `Date` so that the device clock's error does not count, or from `localNow` when the response has
    /// no `Date` the client can read. Nil when it gives none the client can use: absent, neither form,
    /// or a date before the moment it is counted from. Zotero documents seconds alone; a date would come
    /// from something in front of it, such as a proxy.
    static func retryAfterSeconds(_ value: String?, responseDate: String?, localNow: Date) -> TimeInterval? {
        if let seconds = headerSeconds(value) { return seconds }
        guard let value, let until = httpDate(value) else { return nil }
        let seconds = until.timeIntervalSince(responseDate.flatMap(httpDate) ?? localNow)
        guard seconds.isFinite, seconds >= 0 else { return nil }
        return seconds
    }

    /// The moment an HTTP date names in IMF-fixdate, the form a sender must generate (RFC 9110 §5.6.7):
    /// "Sun, 06 Nov 1994 08:49:37 GMT". Nil for anything else, the two obsolete forms included.
    static func httpDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.isLenient = false
        return formatter.date(from: text)
    }

    /// What a send says before it waits on a 429's `Retry-After` (#1925): "Zotero is busy: trying
    /// again in 30 seconds…", the seconds rounded up (`wholeSeconds(_:)`).
    static func retryStatus(seconds: TimeInterval, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(wholeSeconds(seconds),
                         one: String(localized: "zotero.status.retry.one",
                                     defaultValue: "Zotero is busy: trying again in %@ second…"),
                         many: String(localized: "zotero.status.retry.many",
                                      defaultValue: "Zotero is busy: trying again in %@ seconds…"),
                         locale: locale)
    }

    /// What a send says before it waits out the account's `Backoff` (#1925): "Zotero asked for a
    /// pause: continuing in 45 seconds…", the seconds rounded up (`wholeSeconds(_:)`).
    static func backoffStatus(seconds: TimeInterval, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(wholeSeconds(seconds),
                         one: String(localized: "zotero.status.backoff.one",
                                     defaultValue: "Zotero asked for a pause: continuing in %@ second…"),
                         many: String(localized: "zotero.status.backoff.many",
                                      defaultValue: "Zotero asked for a pause: continuing in %@ seconds…"),
                         locale: locale)
    }

    /// A wait as a status names it: whole seconds rounded up, so a wait of 0.2 s reads as 1 second and
    /// never as 0, and at most `longestWait`, the longest the client waits at once.
    static func wholeSeconds(_ seconds: TimeInterval) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(min(seconds, longestWait).rounded(.up))
    }

    /// The body of a collection's write: one new top-level collection of `name`.
    static func collectionBody(_ name: String) -> Data {
        struct NewCollection: Encodable { let name: String; let parentCollection = false }
        return (try? JSONEncoder().encode([NewCollection(name: name)])) ?? Data()
    }

    /// What a send says as it writes the Zotero collection: "Creating collection…".
    static var collectionStatus: String {
        String(localized: "zotero.status.collection", defaultValue: "Creating collection…")
    }

    /// What a send says as it writes a batch of notes: "Uploading notes…".
    static var notesStatus: String {
        String(localized: "zotero.status.notes", defaultValue: "Uploading notes…")
    }

    /// What a finish says while it reads what a write in flight made, once Zotero has refused the write's
    /// token as used (#1923): "Checking what reached Zotero…".
    static var checkingStatus: String {
        String(localized: "zotero.status.check", defaultValue: "Checking what reached Zotero…")
    }

    /// What a send says as it writes its items from `first` to `last`: "Uploading items 51–100…".
    static func itemsStatus(from first: Int, to last: Int) -> String {
        String(format: String(localized: "zotero.status.items %lld %lld",
                              defaultValue: "Uploading items %lld–%lld…"),
               Int64(first), Int64(last))
    }

    /// Whether `error` is Zotero's refusal of a request, which then wrote nothing: an answer from 400 to 499,
    /// `invalidKey` (a 403) and `rateLimited` (a 429) among them. A 5xx, a lost connection, an answer the
    /// client could not read and a cancelled request may each come after Zotero took a write (#1923).
    static func isRefusal(_ error: any Error) -> Bool {
        switch error as? ZoteroAPIError {
        case .invalidKey?, .rateLimited?:
            return true
        case .http(let code)?:
            return (400..<500).contains(code)
        default:
            return false
        }
    }

    /// A random 32-character hex write token for idempotency.
    private static func writeToken() -> String {
        (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    /// Builds the web URL for the destination collection (or library).
    private static func collectionWebURL(username: String?, collectionKey: String?) -> URL? {
        guard let username, !username.isEmpty else { return nil }
        if let collectionKey {
            return URL(string: "https://www.zotero.org/\(username)/collections/\(collectionKey)")
        }
        return URL(string: "https://www.zotero.org/\(username)/library")
    }

    // MARK: - A send's state (#1923)

    /// One send's state as it runs: its progress, its key, what it has added, and the lookups its steps make.
    private struct SendRun {
        /// How far the send has got.
        var progress: ZoteroSendProgress
        /// The user's API key.
        let apiKey: String
        /// The items this send wrote, or found written after a 412.
        private(set) var addedItems = 0
        /// The items Zotero refused in this send's answers.
        private(set) var failedItems = 0
        /// The notes this send wrote, or counted as written after a 412.
        private(set) var addedNotes = 0
        /// Where each item Zotero took is in `progress.written`, by its identity.
        private var writtenIndex: [ZoteroSendProgress.ItemIdentity: Int]

        /// A run from `progress`, which a new send makes empty and a finish takes from the stopped send.
        init(progress: ZoteroSendProgress, apiKey: String) {
            self.progress = progress
            self.apiKey = apiKey
            var index: [ZoteroSendProgress.ItemIdentity: Int] = [:]
            for (position, item) in progress.written.enumerated() where index[item.identity] == nil {
                index[item.identity] = position
            }
            writtenIndex = index
        }

        /// The Zotero user ID the send writes to.
        var userID: Int { progress.userID }

        /// The key Zotero gave the item of `identity`, if it took it.
        func key(for identity: ZoteroSendProgress.ItemIdentity) -> String? {
            writtenIndex[identity].map { progress.written[$0].key }
        }

        /// Records that Zotero took the item of `identity` under `key`.
        mutating func recordItem(_ identity: ZoteroSendProgress.ItemIdentity, key: String) {
            guard writtenIndex[identity] == nil else { return }
            writtenIndex[identity] = progress.written.count
            progress.written.append(ZoteroSendProgress.WrittenItem(identity: identity, key: key, noteDigests: []))
            addedItems += 1
        }

        /// Records that Zotero took the note `ref` under its item.
        mutating func recordNote(_ ref: ZoteroSendProgress.NoteRef) {
            guard let position = writtenIndex[ref.item] else { return }
            progress.written[position].noteDigests.append(ref.digest)
            addedNotes += 1
        }

        /// Records an items write's answer, each item it took by its place in `batch` and the count it
        /// refused. The write is then no longer in flight.
        mutating func record(_ response: ZoteroWriteResponse, forItems batch: [ZoteroSendProgress.ItemIdentity]) {
            for (local, key) in response.keysByIndex.sorted(by: { $0.key < $1.key }) where batch.indices.contains(local) {
                recordItem(batch[local], key: key)
            }
            failedItems += response.failed.count
            progress.inFlight = nil
        }

        /// Records a notes write's answer, each note it took by its place in `batch`. The write is then no
        /// longer in flight.
        mutating func record(_ response: ZoteroWriteResponse, forNotes batch: [ZoteroSendProgress.NoteRef]) {
            for local in response.keysByIndex.keys.sorted() where batch.indices.contains(local) {
                recordNote(batch[local])
            }
            progress.inFlight = nil
        }

        /// Records a collection write's answer: the collection's key, or `ZoteroAPIError.http(200)` where
        /// Zotero refused the collection inside its 200, which wrote nothing. The write is then no longer in
        /// flight, either way.
        mutating func recordCollection(from response: ZoteroWriteResponse, at now: Date) throws {
            progress.inFlight = nil
            progress.updatedAt = now
            guard let key = response.keysByIndex[0] else { throw ZoteroAPIError.http(200) }
            progress.collectionKey = key
        }

        /// A note still to write: which it is, and the object a write sends for it.
        struct PendingNote {
            /// The note, by its item and its text's digest.
            let ref: ZoteroSendProgress.NoteRef
            /// The child note to POST, under its item's key.
            let note: ZoteroAPINote
        }

        /// The notes still to write: under each of `items` Zotero took, in order, each note whose text was
        /// not written under it, a text written once counted once.
        func notesToWrite(_ items: [ZoteroJSONExporter.Item],
                          identities: [ZoteroSendProgress.ItemIdentity]) -> [PendingNote] {
            var pending: [PendingNote] = []
            for (index, item) in items.enumerated() {
                guard let position = writtenIndex[identities[index]] else { continue }
                let written = progress.written[position]
                var sent = Dictionary(written.noteDigests.map { ($0, 1) }, uniquingKeysWith: +)
                for note in item.notes ?? [] {
                    let digest = ZoteroSendProgress.digest(of: note.note)
                    if let count = sent[digest], count > 0 {
                        sent[digest] = count - 1
                        continue
                    }
                    pending.append(PendingNote(ref: ZoteroSendProgress.NoteRef(item: identities[index], digest: digest),
                                               note: .htmlNote(parentItem: written.key, text: note.note)))
                }
            }
            return pending
        }
    }

    /// An item as Zotero lists it in `format=json`: its key, and the two fields its identity is read from.
    private struct ListedItem: Decodable {
        /// The item's key.
        let key: String
        /// The item's fields, of which an identity reads two.
        let data: Fields?

        /// The fields an item's identity is read from.
        struct Fields: Decodable {
            /// The item's URL; empty where it has none.
            let url: String?
            /// The item's title.
            let title: String?
        }
    }

    /// A collection as Zotero lists it in `format=json`: its key, its version, its name, and how many items it
    /// holds.
    private struct ListedCollection: Decodable {
        /// The collection's key.
        let key: String
        /// The library version at which it last changed.
        let version: Int?
        /// The collection's fields.
        let data: Fields?
        /// What Zotero says of it.
        let meta: Meta?

        /// The collection's fields: its name.
        struct Fields: Decodable {
            /// The collection's name.
            let name: String?
        }

        /// What Zotero says of a collection: how many items it holds.
        struct Meta: Decodable {
            /// How many items it holds.
            let numItems: Int?
        }
    }
}

// MARK: - Backoff deadlines

/// Each Zotero account's `Backoff` deadline: the moment before which no client in the process writes
/// to it (#1924).
///
/// The app makes a new `ZoteroAPIClient` for each send — the reader's Share menu, the Mac's Share
/// popover and a collection's export sheet — so a deadline one client kept would be gone when the
/// next send began. Zotero asks for no request until a `Backoff` ends, and a deadline kept here holds
/// every client's writes to it; a key's account is resolved (`resolveAccount(key:)`) without it. An
/// account is its numeric user ID, which every write names in its path: two keys to one library share
/// its deadline, and two users of one server do not.
///
/// A deadline is at most `ZoteroAPIClient.longestWait` away when it is set, and is dropped when it is read
/// after it has passed. One for an account that never writes again stays, an instant under a user ID, until
/// the process ends. No API key is kept.
///
/// Version history:
///   1.0 — L41 of the plan of record from 2026-11-25 (#1924)
actor ZoteroBackoffDeadlines {

    /// The process's deadlines, which every client made by `ZoteroAPIClient.init(session:)` holds to.
    static let shared = ZoteroBackoffDeadlines()

    private var deadlines: [Int: ContinuousClock.Instant] = [:]

    /// Holds `userID`'s writes until `deadline`, or until the later one it already has.
    func hold(_ userID: Int, until deadline: ContinuousClock.Instant) {
        if let held = deadlines[userID], held >= deadline { return }
        deadlines[userID] = deadline
    }

    /// The seconds from `now` to `userID`'s deadline, or nil when it has none or it has passed, which
    /// drops it.
    func remaining(for userID: Int, at now: ContinuousClock.Instant) -> TimeInterval? {
        guard let deadline = deadlines[userID] else { return nil }
        guard now < deadline else {
            deadlines[userID] = nil
            return nil
        }
        let (seconds, attoseconds) = now.duration(to: deadline).components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
