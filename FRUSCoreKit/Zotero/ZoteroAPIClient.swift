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

    /// Pushes the given items (with their tags and notes) into the user's library,
    /// optionally creating a new collection to hold them.
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
    /// - Parameters:
    ///   - items: Resolved export items (tags + notes already attached).
    ///   - collectionName: When non-nil, a new collection is created and every item
    ///     placed in it.
    ///   - apiKey: The user's API key.
    ///   - userID: The resolved numeric user ID.
    ///   - username: The username, used to build a "View in Zotero" web URL.
    ///   - status: Progress callback (human-readable): each step, and each wait on Zotero's word
    ///     with its seconds (`retryStatus(seconds:locale:)`, `backoffStatus(seconds:locale:)`).
    /// - Returns: A summary of what was created.
    public func send(
        items: [ZoteroJSONExporter.Item],
        collectionName: String?,
        apiKey: String,
        userID: Int,
        username: String?,
        status: @Sendable (String) -> Void = { _ in }
    ) async throws -> ZoteroSendResult {
        guard !items.isEmpty else {
            return ZoteroSendResult(addedItems: 0, failedItems: 0, addedNotes: 0,
                                    collectionKey: nil, webURL: nil)
        }

        // 1. Collection
        var collectionKey: String?
        if let collectionName {
            let step = String(localized: "zotero.status.collection", defaultValue: "Creating collection…")
            status(step)
            collectionKey = try await createCollection(name: collectionName, apiKey: apiKey, userID: userID,
                                                       step: step, status: status)
        }

        // 2. Items (chunked)
        let apiItems = items.map { ZoteroAPIItem(item: $0, collectionKey: collectionKey) }
        var keysByInputIndex: [Int: String] = [:]
        var failedCount = 0
        var offset = 0
        while offset < apiItems.count {
            try Task.checkCancellation()
            let chunk = Array(apiItems[offset..<min(offset + maxBatch, apiItems.count)])
            let step = String(format: String(localized: "zotero.status.items %lld %lld",
                                              defaultValue: "Uploading items %lld–%lld…"),
                              Int64(offset + 1), Int64(min(offset + maxBatch, apiItems.count)))
            status(step)
            let response = try await writeObjects(chunk, path: "items", apiKey: apiKey, userID: userID,
                                                  step: step, status: status)
            for (localIndex, key) in response.keysByIndex { keysByInputIndex[offset + localIndex] = key }
            failedCount += response.failed.count
            offset += maxBatch
        }

        // 3. Child notes (need parent keys from step 2)
        var notes: [ZoteroAPINote] = []
        for (index, item) in items.enumerated() {
            guard let parentKey = keysByInputIndex[index] else { continue }
            for note in item.notes ?? [] {
                notes.append(.htmlNote(parentItem: parentKey, text: note.note))
            }
        }
        var addedNotes = 0
        var noteOffset = 0
        while noteOffset < notes.count {
            try Task.checkCancellation()
            let chunk = Array(notes[noteOffset..<min(noteOffset + maxBatch, notes.count)])
            let step = String(localized: "zotero.status.notes", defaultValue: "Uploading notes…")
            status(step)
            let response = try await writeObjects(chunk, path: "items", apiKey: apiKey, userID: userID,
                                                  step: step, status: status)
            addedNotes += response.successful.count
            noteOffset += maxBatch
        }

        return ZoteroSendResult(
            addedItems: keysByInputIndex.count,
            failedItems: failedCount,
            addedNotes: addedNotes,
            collectionKey: collectionKey,
            webURL: Self.collectionWebURL(username: username, collectionKey: collectionKey)
        )
    }

    // MARK: - Primitives

    /// Creates a collection and returns its key.
    private func createCollection(
        name: String, apiKey: String, userID: Int, step: String, status: @Sendable (String) -> Void
    ) async throws -> String {
        struct NewCollection: Encodable { let name: String; let parentCollection = false }
        let body = try JSONEncoder().encode([NewCollection(name: name)])
        let response = try await writeRequest(path: "collections", body: body, apiKey: apiKey, userID: userID,
                                              step: step, status: status)
        guard let created = response.keysByIndex[0] else { throw ZoteroAPIError.http(200) }
        return created
    }

    /// Encodes and writes a batch of objects, returning the parsed write response.
    private func writeObjects<T: Encodable>(
        _ objects: [T], path: String, apiKey: String, userID: Int, step: String, status: @Sendable (String) -> Void
    ) async throws -> ZoteroWriteResponse {
        let body = try JSONEncoder().encode(objects)
        return try await writeRequest(path: path, body: body, apiKey: apiKey, userID: userID,
                                      step: step, status: status)
    }

    /// Performs a POST with idempotency + retry/backoff, returning the write response.
    ///
    /// Each request first waits what is left of the account's `Backoff` (`holdToBackoff`). A 2xx's
    /// own `Backoff` sets that deadline and is not waited here, so the send's last write returns at
    /// once and its next write, or the account's next send, waits it (#1924). `step` is the message
    /// the send reported for this write, said again after each wait (#1925).
    private func writeRequest(
        path: String, body: Data, apiKey: String, userID: Int, step: String, status: @Sendable (String) -> Void
    ) async throws -> ZoteroWriteResponse {
        let url = base.appendingPathComponent("users/\(userID)/\(path)")
        let writeToken = Self.writeToken()

        var attempt = 0
        while true {
            try await holdToBackoff(userID: userID, step: step, status: status)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(writeToken, forHTTPHeaderField: "Zotero-Write-Token")

            do {
                let (data, response) = try await perform(request)
                try Self.checkStatus(response, invalidKeyOn: [403], localNow: wallClock())
                if let backoff = Self.backoffSeconds(response), backoff > 0 {
                    // This write succeeded: the account's next write waits, for `longestWait` at most.
                    await deadlines.hold(userID, until: now().advanced(by: .seconds(min(backoff, Self.longestWait))))
                }
                guard let decoded = try? JSONDecoder().decode(ZoteroWriteResponse.self, from: data) else {
                    throw ZoteroAPIError.decoding
                }
                return decoded
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
