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
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
///   1.1 — FRUS Explorer Light's S22c: in FRUSCoreKit, public, with `URLSession` from
///          FoundationNetworking on Linux; the key was a parameter already
///   1.2 — FRUS Explorer Light's follow-up for S22e: a wait on Zotero's word reads only seconds
///          that are finite and not negative (`headerSeconds(_:)`) and lasts at most `longestWait`,
///          so no header value can trap the client or hold a send without end; the waits go
///          through a sleep a test can replace (`init(session:sleep:)`)
public actor ZoteroAPIClient {

    private let session: URLSession
    private let base = URL(string: "https://api.zotero.org")!
    private let maxBatch = 50
    private let maxRetries = 3
    /// Waits the given nanoseconds: `Task.sleep`, or a test's recorder.
    private let sleepNanoseconds: @Sendable (UInt64) async throws -> Void

    /// The longest the client waits at once on Zotero's word, in seconds: a 429's `Retry-After`,
    /// or a `Backoff`. It is above the 30 s a 429 waits when it gives no seconds the client can
    /// use, so that default, and any well-formed value up to a minute, waits as it always has.
    /// Zotero's documentation names two forms of rate limiting, and the client treats them apart:
    /// - A 429 is the hard limit: the request was refused, and Zotero asks for none before its
    ///   `Retry-After`. Past this wait the 429 reaches the caller at once, as
    ///   `ZoteroAPIError.rateLimited`, rather than a retry before Zotero's time, which breaks its
    ///   rule and invites stricter throttling.
    /// - A `Backoff` is a request to slow down, on a write that succeeded. Past this wait the
    ///   client waits this long and the send goes on, its remaining writes inside Zotero's backoff:
    ///   a bounded departure from the advice to make no request until it ends, so that a send is
    ///   not stopped part-way, with what it already wrote kept in the library and nothing to say so.
    static let longestWait: TimeInterval = 60

    /// Creates a client.
    /// - Parameter session: URL session (injectable for testing).
    public init(session: URLSession = .shared) {
        self.init(session: session, sleep: { try await Task.sleep(nanoseconds: $0) })
    }

    /// Creates a client whose waits go to `sleep`, in nanoseconds, so that a test can read the
    /// waits the client asks for without waiting them out.
    init(session: URLSession, sleep: @escaping @Sendable (UInt64) async throws -> Void) {
        self.session = session
        self.sleepNanoseconds = sleep
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
        try Self.checkStatus(response, invalidKeyOn: [403, 404])
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
    /// three retries of a 429, and up to a minute after a `Backoff`, so one write can take four
    /// minutes. A 429 that asks for longer stops the send there, as `ZoteroAPIError.rateLimited`,
    /// with the writes before it kept in the library.
    ///
    /// - Parameters:
    ///   - items: Resolved export items (tags + notes already attached).
    ///   - collectionName: When non-nil, a new collection is created and every item
    ///     placed in it.
    ///   - apiKey: The user's API key.
    ///   - userID: The resolved numeric user ID.
    ///   - username: The username, used to build a "View in Zotero" web URL.
    ///   - status: Progress callback (human-readable).
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
            status(String(localized: "zotero.status.collection",
                          defaultValue: "Creating collection…"))
            collectionKey = try await createCollection(name: collectionName, apiKey: apiKey, userID: userID)
        }

        // 2. Items (chunked)
        let apiItems = items.map { ZoteroAPIItem(item: $0, collectionKey: collectionKey) }
        var keysByInputIndex: [Int: String] = [:]
        var failedCount = 0
        var offset = 0
        while offset < apiItems.count {
            try Task.checkCancellation()
            let chunk = Array(apiItems[offset..<min(offset + maxBatch, apiItems.count)])
            status(String(format: String(localized: "zotero.status.items %lld %lld",
                                          defaultValue: "Uploading items %lld–%lld…"),
                          Int64(offset + 1), Int64(min(offset + maxBatch, apiItems.count))))
            let response = try await writeObjects(chunk, path: "items", apiKey: apiKey, userID: userID)
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
            status(String(localized: "zotero.status.notes", defaultValue: "Uploading notes…"))
            let response = try await writeObjects(chunk, path: "items", apiKey: apiKey, userID: userID)
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
    private func createCollection(name: String, apiKey: String, userID: Int) async throws -> String {
        struct NewCollection: Encodable { let name: String; let parentCollection = false }
        let body = try JSONEncoder().encode([NewCollection(name: name)])
        let response = try await writeRequest(path: "collections", body: body, apiKey: apiKey, userID: userID)
        guard let created = response.keysByIndex[0] else { throw ZoteroAPIError.http(200) }
        return created
    }

    /// Encodes and writes a batch of objects, returning the parsed write response.
    private func writeObjects<T: Encodable>(
        _ objects: [T], path: String, apiKey: String, userID: Int
    ) async throws -> ZoteroWriteResponse {
        let body = try JSONEncoder().encode(objects)
        return try await writeRequest(path: path, body: body, apiKey: apiKey, userID: userID)
    }

    /// Performs a POST with idempotency + retry/backoff, returning the write response.
    private func writeRequest(
        path: String, body: Data, apiKey: String, userID: Int
    ) async throws -> ZoteroWriteResponse {
        let url = base.appendingPathComponent("users/\(userID)/\(path)")
        let writeToken = Self.writeToken()

        var attempt = 0
        while true {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(writeToken, forHTTPHeaderField: "Zotero-Write-Token")

            do {
                let (data, response) = try await perform(request)
                try Self.checkStatus(response, invalidKeyOn: [403])
                if let backoff = Self.backoffSeconds(response) {
                    // This write succeeded: a longer backoff is waited for `longestWait`, and the send goes on.
                    try await pause(min(backoff, Self.longestWait))
                }
                guard let decoded = try? JSONDecoder().decode(ZoteroWriteResponse.self, from: data) else {
                    throw ZoteroAPIError.decoding
                }
                return decoded
            } catch let ZoteroAPIError.rateLimited(retryAfter) where attempt < maxRetries {
                // Zotero asks for no request before `retryAfter`: past `longestWait` the caller hears it now.
                guard retryAfter <= Self.longestWait else { throw ZoteroAPIError.rateLimited(retryAfter: retryAfter) }
                attempt += 1
                try await pause(retryAfter)
                continue
            }
        }
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

    /// Throws an appropriate `ZoteroAPIError` for non-2xx responses.
    private static func checkStatus(_ response: URLResponse, invalidKeyOn: Set<Int>) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ZoteroAPIError.network("No HTTP response")
        }
        switch http.statusCode {
        case 200...299:
            return
        case 429:
            // Zotero's seconds, or 30 when it gives none the client can use (`headerSeconds(_:)`).
            let retry = headerSeconds(http.value(forHTTPHeaderField: "Retry-After")) ?? 30
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
    /// use: absent, not a number Swift reads, not finite ("nan", "inf"), or negative ("-1"). An HTTP-date
    /// `Retry-After` is not a number Swift reads, and Zotero documents seconds alone. "-0" reads as 0,
    /// as "0" does.
    static func headerSeconds(_ value: String?) -> TimeInterval? {
        guard let value, let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 else { return nil }
        return seconds == 0 ? 0 : seconds
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
