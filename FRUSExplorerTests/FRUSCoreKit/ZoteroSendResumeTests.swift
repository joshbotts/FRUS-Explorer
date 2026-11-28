// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - ZoteroSendResumeTests

/// A send to Zotero that stops part-way, and its finish (#1923, L64 of the plan of record from 2026-11-25).
///
/// Every test sends through a Zotero stand-in (`StandIn`): one library per test, under a user id of the
/// test's own, which keeps what each write made and answers as Zotero's Web API v3 documents (*Write
/// Requests*, read 2026-11-28): a write token of a request that succeeded is remembered, and a second
/// request under it is refused with a 412; one of a request that failed is not. A test names the writes it
/// wants answered otherwise: refused before anything is written, written with the answer lost, or the
/// connection dropped before the write arrived. Its reads list a collection's items or the library's, newest
/// first, and the account's collections, as `format=json` does. No test reaches the network, and no test
/// waits: the client's sleep returns at once, so the suite's limit is for a hang alone.
///
/// The first three tests showed the defect on `v2`'s client (`d9b86ae2`), finishing a stopped send the only
/// way a caller then could, by sending again: two Zotero collections and 50 documents twice, twice over, and a
/// document sent alone in Zotero twice. They now finish from the stop's progress.
///
/// Version history:
///   1.0 — 2026-11-28: L64 (#1923), the defect shown first
///   1.1 — 2026-11-28: L64's fix: each finish from the stop's progress, and the resume's own tests
@Suite("Zotero send — a stopped send and its finish (#1923)", .timeLimit(.minutes(5)))
struct ZoteroSendResumeTests {

    // MARK: The stand-in

    /// What Zotero holds for one test's account, and how the test wants its writes answered.
    final class Library: @unchecked Sendable {

        /// A Zotero collection.
        struct Collection: Equatable {
            let key: String
            let name: String
        }

        /// A top-level Zotero item.
        struct Item: Equatable {
            let key: String
            let url: String
            let title: String
            let collections: [String]
        }

        /// A child note.
        struct Note: Equatable {
            let key: String
            let parent: String
            let html: String
        }

        /// How one write is answered, where the test wants something other than Zotero's 200.
        enum Fault {
            /// Zotero refuses the write with this status and writes nothing, as a 403, a 429 or a 503 does.
            case refuse(Int)
            /// Zotero writes it, and its answer never arrives: the client sees the connection lost.
            case loseAnswer
            /// The connection drops before the write reaches Zotero, which writes nothing.
            case dropBeforeWrite
        }

        private let lock = NSLock()
        private var storedCollections: [Collection] = []
        private var storedItems: [Item] = []
        private var storedNotes: [Note] = []
        private var tokens: Set<String> = []
        private var keyCount = 0
        private var writes = 0
        private var faults: [Int: Fault] = [:]
        private var failedReads = 0
        private var requestLog: [String] = []

        /// The collections, oldest first.
        var collections: [Collection] { lock.withLock { storedCollections } }
        /// The top-level items, oldest first.
        var items: [Item] { lock.withLock { storedItems } }
        /// The child notes, oldest first.
        var notes: [Note] { lock.withLock { storedNotes } }
        /// Each request the stand-in was asked, in order: its method and path, and for a write its token.
        var log: [String] { lock.withLock { requestLog } }

        /// The URLs held by more than one item, each once, sorted.
        var duplicatedURLs: [String] {
            Dictionary(grouping: items, by: \.url).filter { $0.value.count > 1 }.keys.sorted()
        }

        /// The notes under the item whose URL is `url`, each note's HTML, oldest first.
        func notes(under url: String) -> [String] {
            let keys = Set(items.filter { $0.url == url }.map(\.key))
            return notes.filter { keys.contains($0.parent) }.map(\.html)
        }

        /// Answers the `number`th write (counted from 1 over every POST, a retry included) as `fault` says.
        func answer(write number: Int, with fault: Fault) {
            lock.withLock { faults[number] = fault }
        }

        /// Loses the connection on the next `count` reads.
        func failReads(_ count: Int) {
            lock.withLock { failedReads = count }
        }

        /// Puts a collection in the library before the send, as an earlier one, or the reader, made it.
        @discardableResult
        func addCollection(named name: String) -> String {
            lock.withLock {
                let key = nextKey("C")
                storedCollections.append(Collection(key: key, name: name))
                return key
            }
        }

        /// Puts an item in the library before the send, in `collection` if one is named.
        @discardableResult
        func addItem(url: String, title: String, in collection: String? = nil) -> String {
            lock.withLock {
                let key = nextKey("I")
                storedItems.append(Item(key: key, url: url, title: title,
                                        collections: collection.map { [$0] } ?? []))
                return key
            }
        }

        /// Deletes a collection, as the reader can in Zotero between a stop and a finish.
        func removeCollection(_ key: String) {
            lock.withLock { storedCollections.removeAll { $0.key == key } }
        }

        /// What the stand-in answers one request with.
        struct Answer {
            /// The status, or nil for a connection that fails.
            let status: Int?
            var headers: [String: String] = [:]
            var body = Data()
        }

        /// Answers a request as Zotero would, the test's faults applied.
        func answer(_ request: URLRequest, body: Data) -> Answer {
            lock.withLock {
                let method = request.httpMethod ?? "GET"
                let parts = Array(request.url!.pathComponents.drop { $0 != "users" }.dropFirst(2))
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let token = request.value(forHTTPHeaderField: "Zotero-Write-Token") ?? ""
                requestLog.append(method == "POST" ? "POST /\(parts.joined(separator: "/")) \(token)"
                                                   : "GET /\(parts.joined(separator: "/"))")
                if method == "POST" { return write(parts, body: body, token: token) }
                if failedReads > 0 {
                    failedReads -= 1
                    return Answer(status: nil)
                }
                return read(parts, query: query)
            }
        }

        // Each of the four functions below runs under the lock.

        private func nextKey(_ prefix: String) -> String {
            keyCount += 1
            return prefix + String(format: "%07d", keyCount)
        }

        private func write(_ parts: [String], body: Data, token: String) -> Answer {
            writes += 1
            if tokens.contains(token) { return Answer(status: 412) }
            let fault = faults[writes]
            if case .refuse(let status) = fault { return Answer(status: status, body: Data("{}".utf8)) }
            if case .dropBeforeWrite = fault { return Answer(status: nil) }
            let objects = (try? JSONSerialization.jsonObject(with: body)) as? [[String: Any]] ?? []
            var successful: [String: Any] = [:]
            var failed: [String: Any] = [:]
            for (index, object) in objects.enumerated() {
                let slot = String(index)
                if parts.first == "collections" {
                    let key = nextKey("C")
                    storedCollections.append(Collection(key: key, name: object["name"] as? String ?? ""))
                    successful[slot] = ["key": key, "version": writes]
                } else if object["itemType"] as? String == "note" {
                    let parent = object["parentItem"] as? String ?? ""
                    guard storedItems.contains(where: { $0.key == parent }) else {
                        failed[slot] = ["code": 400, "message": "Parent item \(parent) doesn't exist"]
                        continue
                    }
                    let key = nextKey("N")
                    storedNotes.append(Note(key: key, parent: parent, html: object["note"] as? String ?? ""))
                    successful[slot] = ["key": key, "version": writes]
                } else {
                    let named = object["collections"] as? [String] ?? []
                    if let missing = named.first(where: { key in !storedCollections.contains { $0.key == key } }) {
                        failed[slot] = ["code": 409, "message": "Collection \(missing) doesn't exist"]
                        continue
                    }
                    let key = nextKey("I")
                    storedItems.append(Item(key: key, url: object["url"] as? String ?? "",
                                            title: object["title"] as? String ?? "", collections: named))
                    successful[slot] = ["key": key, "version": writes]
                }
            }
            tokens.insert(token)
            if case .loseAnswer = fault { return Answer(status: nil) }
            let answer: [String: Any] = ["successful": successful, "success": [:] as [String: Any],
                                         "unchanged": [:] as [String: Any], "failed": failed]
            return Answer(status: 200, body: (try? JSONSerialization.data(withJSONObject: answer)) ?? Data())
        }

        private func read(_ parts: [String], query: [URLQueryItem]) -> Answer {
            let limit = query.first { $0.name == "limit" }?.value.flatMap(Int.init) ?? 25
            let start = query.first { $0.name == "start" }?.value.flatMap(Int.init) ?? 0
            let all: [[String: Any]]
            switch parts.count {
            case 1 where parts[0] == "collections":
                all = storedCollections.map { collection in
                    let count = storedItems.filter { $0.collections.contains(collection.key) }.count
                    return ["key": collection.key, "version": 1,
                            "data": ["key": collection.key, "name": collection.name, "parentCollection": false],
                            "meta": ["numCollections": 0, "numItems": count]]
                }
            case 2 where parts == ["items", "top"]:
                // The library's top-level items, newest first, as `sort=dateAdded&direction=desc` asks.
                all = storedItems.reversed().map(Self.json)
            case 4 where parts[0] == "collections" && parts[2...] == ["items", "top"]:
                all = storedItems.reversed().filter { $0.collections.contains(parts[1]) }.map(Self.json)
            default:
                return Answer(status: 404)
            }
            let page = Array(all.dropFirst(start).prefix(limit))
            return Answer(status: 200, headers: ["Total-Results": String(all.count)],
                          body: (try? JSONSerialization.data(withJSONObject: page)) ?? Data())
        }

        private static func json(_ item: Item) -> [String: Any] {
            ["key": item.key, "version": 1,
             "data": ["key": item.key, "itemType": "bookSection", "title": item.title, "url": item.url,
                      "collections": item.collections],
             "meta": ["numChildren": 0]]
        }
    }

    /// Answers every request from the library registered under the user id in its path.
    final class StandIn: URLProtocol {
        private static let lock = NSLock()
        nonisolated(unsafe) private static var libraries: [String: Library] = [:]
        nonisolated(unsafe) private static var lastID = 7_300_000

        /// A library of a test's own, under a user id no other test uses.
        static func register() -> (user: Int, library: Library) {
            lock.withLock {
                lastID += 1
                let library = Library()
                libraries[String(lastID)] = library
                return (lastID, library)
            }
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            let parts = request.url!.pathComponents
            let id = parts.firstIndex(of: "users").flatMap { parts.indices.contains($0 + 1) ? parts[$0 + 1] : nil } ?? ""
            guard let library = Self.lock.withLock({ Self.libraries[id] }) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            let answer = library.answer(request, body: Self.body(of: request))
            guard let status = answer.status else {
                client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
                return
            }
            var headers = answer.headers
            headers["Content-Type"] = "application/json"
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: answer.body)
            client?.urlProtocolDidFinishLoading(self)
        }

        /// A request's body: `URLSession` hands a protocol the body as a stream.
        private static func body(of request: URLRequest) -> Data {
            if let body = request.httpBody { return body }
            guard let stream = request.httpBodyStream else { return Data() }
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 16_384)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                guard read > 0 else { break }
                data.append(buffer, count: read)
            }
            return data
        }
    }

    // MARK: Fixtures

    /// `count` items, each a document of its own with `notes` research notes.
    static func items(_ count: Int, notes: Int = 0, from first: Int = 1) -> [ZoteroJSONExporter.Item] {
        (first..<(first + count)).map { number in
            ZoteroJSONExporter.Item(
                itemType: "bookSection", title: "Document \(number): Memorandum",
                url: url(number),
                notes: notes == 0 ? nil : (1...notes).map { ZoteroJSONExporter.Note(note: "Note \($0) on \(number)") })
        }
    }

    /// The URL of the fixture document `number`.
    static func url(_ number: Int) -> String {
        "https://history.state.gov/historicaldocuments/frus1969-76v01/d\(number)"
    }

    /// The number of the fixture document an item is.
    static func number(of item: ZoteroJSONExporter.Item) -> Int {
        Int(URL(string: item.url ?? "")?.lastPathComponent.dropFirst() ?? "") ?? 0
    }

    /// The name of the Zotero collection a collection's send makes.
    static let collectionName = "Placeholder"

    /// The progress a send handed its host, in order, and what it said through `status`.
    final class Heard: @unchecked Sendable {
        private let lock = NSLock()
        private var storedProgress: [ZoteroSendProgress] = []
        private var storedStatus: [String] = []
        /// When it holds for a progress handed over, the host cancels the send's task there.
        private let cancelWhen: (@Sendable (ZoteroSendProgress) -> Bool)?

        /// A host that keeps what it hears, and cancels the send's task where `cancelWhen` says.
        init(cancelWhen: (@Sendable (ZoteroSendProgress) -> Bool)? = nil) {
            self.cancelWhen = cancelWhen
        }

        /// Each progress the send handed over, in order.
        var progress: [ZoteroSendProgress] { lock.withLock { storedProgress } }
        /// Each status the send said, in order.
        var status: [String] { lock.withLock { storedStatus } }

        /// The closure to pass a send's `progress`. It runs on the send's task, which it cancels where
        /// `cancelWhen` holds.
        var onProgress: @Sendable (ZoteroSendProgress) -> Void {
            { [self] progress in
                lock.withLock { storedProgress.append(progress) }
                if cancelWhen?(progress) == true { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }

        /// The closure to pass a send's `status`.
        var onStatus: @Sendable (String) -> Void {
            { [self] message in lock.withLock { storedStatus.append(message) } }
        }
    }

    /// A client of the stand-in whose waits return at once.
    static func client() -> ZoteroAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StandIn.self]
        return ZoteroAPIClient(session: URLSession(configuration: configuration), sleep: { _ in })
    }

    /// Sends `items`, as the app's collection sheet does when `collection` is true and as its Share sends do
    /// otherwise, finishing `earlier` when one is given, and returns its result or what it threw.
    static func send(_ items: [ZoteroJSONExporter.Item], collection: Bool, user: Int,
                     resuming earlier: ZoteroSendProgress? = nil,
                     heard: Heard = Heard()) async -> Result<ZoteroSendResult, any Error> {
        do {
            return .success(try await client().send(
                items: items, collectionName: collection ? collectionName : nil, apiKey: "placeholder",
                userID: user, username: nil, resuming: earlier, status: heard.onStatus, progress: heard.onProgress))
        } catch {
            return .failure(error)
        }
    }

    /// Sends `items` and returns the stop it ends in, recording an issue when it ends otherwise.
    static func stop(_ items: [ZoteroJSONExporter.Item], collection: Bool, user: Int,
                     heard: Heard = Heard()) async throws -> ZoteroSendStopped {
        let outcome = await send(items, collection: collection, user: user, heard: heard)
        guard case .failure(let error) = outcome else {
            Issue.record("the send finished")
            throw CancellationError()
        }
        return try #require(error as? ZoteroSendStopped, "the send threw \(error), not ZoteroSendStopped")
    }

    /// Finishes a send that stopped with `error`, as a caller can: from the progress the stop carries.
    static func finish(after error: any Error, _ items: [ZoteroJSONExporter.Item], collection: Bool,
                       user: Int, heard: Heard = Heard()) async throws -> ZoteroSendResult {
        let stopped = try #require(error as? ZoteroSendStopped, "the send threw \(error), not ZoteroSendStopped")
        return try await send(items, collection: collection, user: user, resuming: stopped.progress, heard: heard).get()
    }

    /// The tokens of the writes in `log`, in order.
    static func writeTokens(_ log: [String]) -> [String] {
        log.filter { $0.hasPrefix("POST") }.compactMap { $0.split(separator: " ").last.map(String.init) }
    }

    // MARK: The defect (#1923)

    @Test("#1923: a collection's send stopped at its second batch, finished, leaves one Zotero collection and each document once")
    func stoppedAtTheSecondBatch() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the collection, 2 items 1–50, 3 items 51–60, which Zotero refuses with a 503.
        library.answer(write: 3, with: .refuse(503))
        let items = Self.items(60)
        let stopped = try await Self.stop(items, collection: true, user: user)
        #expect(library.items.count == 50, "the stop kept the first batch")

        let result = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(library.collections.count == 1, "the finish made \(library.collections.count - 1) more Zotero collection(s)")
        #expect(library.duplicatedURLs.isEmpty, "\(library.duplicatedURLs.count) documents are in Zotero twice")
        #expect(library.items.count == 60)
        #expect(result.addedItems == 10 && result.failedItems == 0, "the finish counts the ten it wrote")
        #expect(result.collectionKey == library.collections.first?.key)
    }

    @Test("#1923: a batch whose answer was lost, finished, leaves each document once, its notes under it")
    func lostAnswerOfABatch() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the collection, 2 items 1–50, whose answer is lost, then the notes.
        library.answer(write: 2, with: .loseAnswer)
        let items = Self.items(50, notes: 1)
        let stopped = try await Self.stop(items, collection: true, user: user)
        #expect(library.items.count == 50, "Zotero wrote the batch")
        #expect(library.notes.isEmpty)

        let heard = Heard()
        let result = try await Self.finish(after: stopped, items, collection: true, user: user, heard: heard)
        #expect(library.collections.count == 1, "the finish made \(library.collections.count - 1) more Zotero collection(s)")
        #expect(library.duplicatedURLs.isEmpty, "\(library.duplicatedURLs.count) documents are in Zotero twice")
        #expect(library.items.count == 50)
        #expect(library.notes.count == 50)
        #expect(items.allSatisfy { library.notes(under: $0.url!).count == 1 }, "a document's note is missing or doubled")
        #expect(result.addedItems == 50 && result.addedNotes == 50, "the finish counts the batch it found written")

        // The lost write went out again under its own token, Zotero refused it as used, and the collection's
        // items gave the keys: no item was written twice.
        let log = library.log
        let tokens = Self.writeTokens(log)
        #expect(tokens.count == 4 && tokens[2] == tokens[1], "the finish did not send the lost write under its token")
        #expect(log.contains("GET /collections/\(result.collectionKey ?? "")/items/top"))
        #expect(heard.status.prefix(2) == ["Uploading items 1–50…", ZoteroAPIClient.checkingStatus])
    }

    @Test("#1923: a document's send whose notes stopped, finished, leaves the document once with each of its notes")
    func documentSendStoppedAtItsNotes() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the document, 2 its notes, which Zotero refuses with a 503.
        library.answer(write: 2, with: .refuse(503))
        let items = Self.items(1, notes: 2)
        let stopped = try await Self.stop(items, collection: false, user: user)
        #expect(library.items.count == 1)
        #expect(library.notes.isEmpty)

        let result = try await Self.finish(after: stopped, items, collection: false, user: user)
        #expect(library.duplicatedURLs.isEmpty, "the document is in Zotero \(library.items.count) times")
        #expect(library.notes(under: items[0].url!) == ["<p>Note 1 on 1</p>", "<p>Note 2 on 1</p>"])
        #expect(result.addedItems == 0 && result.addedNotes == 2)
    }

    // MARK: What a stop carries

    @Test("A stop carries the Zotero collection, the items written by URL, and a write Zotero may have taken with its token")
    func aStopCarriesItsProgress() async throws {
        let (user, library) = StandIn.register()
        library.answer(write: 3, with: .refuse(503))
        let stopped = try await Self.stop(Self.items(60, notes: 1), collection: true, user: user)
        let progress = stopped.progress
        guard case ZoteroAPIError.http(503) = stopped.cause else {
            Issue.record("the cause is \(stopped.cause)")
            return
        }
        #expect(stopped.errorDescription == ZoteroAPIError.http(503).errorDescription)
        #expect(progress.userID == user)
        #expect(progress.collectionKey == library.collections.first?.key)
        #expect(progress.writtenItemCount == 50 && progress.writtenNoteCount == 0)
        #expect(progress.written.map(\.identity.name) == (1...50).map(Self.url))
        #expect(Set(progress.written.map(\.key)) == Set(library.items.map(\.key)))
        // A 503 may follow a write Zotero took, so the batch is in flight, under the token it went out with.
        #expect(progress.writeInFlight == .items)
        #expect(progress.inFlight?.items.map(\.name) == (51...60).map(Self.url))
        #expect(progress.inFlight?.writeToken == Self.writeTokens(library.log).last)
    }

    @Test("A write Zotero refused with a 4xx wrote nothing: the stop has no write in flight, and the finish sends it under a new token",
          arguments: [403, 400, 429])
    func aRefusalIsNoWriteInFlight(_ status: Int) async throws {
        let (user, library) = StandIn.register()
        // A 429 with no Retry-After waits the 30 s default (at once, here) before each of three retries, and
        // its fourth refusal stops the send: writes 3 to 6 are its four attempts. A 403 or a 400 stops it at once.
        for write in status == 429 ? 3...6 : 3...3 { library.answer(write: write, with: .refuse(status)) }
        let items = Self.items(60)
        let stopped = try await Self.stop(items, collection: true, user: user)
        #expect(stopped.progress.writeInFlight == nil, "a refused write is in flight")
        #expect(stopped.progress.writtenItemCount == 50)
        let refused = Self.writeTokens(library.log).last

        _ = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(library.items.count == 60 && library.duplicatedURLs.isEmpty)
        #expect(Self.writeTokens(library.log).last != refused, "the finish reused the refused write's token")
    }

    @Test("A stop before Zotero can have taken anything throws its error alone, as before, and leaves the host an empty progress")
    func aStopBeforeAnythingThrowsItsErrorAlone() async throws {
        let (user, library) = StandIn.register()
        library.answer(write: 1, with: .refuse(403))
        let heard = Heard()
        let outcome = await Self.send(Self.items(3), collection: true, user: user, heard: heard)
        guard case .failure(ZoteroAPIError.invalidKey) = outcome else {
            Issue.record("the send ended \(outcome), not invalidKey alone")
            return
        }
        #expect(heard.progress.last?.isEmpty == true, "the host was left \(String(describing: heard.progress.last))")
        #expect(library.collections.isEmpty && library.items.isEmpty)
    }

    @Test("A send hands its host its progress before each write leaves and after each answer, and at a stop the error's")
    func theHostHearsTheProgressAsItGoes() async throws {
        let (user, library) = StandIn.register()
        let heard = Heard()
        _ = try await Self.send(Self.items(1, notes: 1), collection: true, user: user, heard: heard).get()
        let kinds = heard.progress.map { ($0.writeInFlight, $0.collectionKey != nil, $0.writtenItemCount, $0.writtenNoteCount) }
        #expect(kinds.map(\.0) == [.collection, nil, .items, nil, .notes, nil])
        #expect(kinds.map(\.1) == [false, true, true, true, true, true])
        #expect(kinds.map(\.2) == [0, 0, 0, 1, 1, 1])
        #expect(kinds.map(\.3) == [0, 0, 0, 0, 0, 1])
        #expect(library.notes.count == 1)

        let (other, stalled) = StandIn.register()
        stalled.answer(write: 2, with: .dropBeforeWrite)
        let stopHeard = Heard()
        let stopped = try await Self.stop(Self.items(1), collection: true, user: other, heard: stopHeard)
        #expect(stopHeard.progress.last == stopped.progress)
        // The connection dropped before the write arrived, which the client cannot tell from an answer lost.
        #expect(stopped.progress.writeInFlight == .items)
    }

    // MARK: Finishing

    @Test("A finish of a collection changed since the stop sends what was added, and leaves what was removed in the library")
    func aFinishOfAChangedCollection() async throws {
        let (user, library) = StandIn.register()
        library.answer(write: 3, with: .refuse(503))
        let stopped = try await Self.stop(Self.items(60, notes: 1), collection: true, user: user)

        // Since the stop: documents 1–5 (written) and 55–56 (not) left the collection, and 61–62 joined it.
        let now = Self.items(60, notes: 1).filter { ![1, 2, 3, 4, 5, 55, 56].contains(Self.number(of: $0)) }
            + Self.items(2, notes: 1, from: 61)
        let result = try await Self.finish(after: stopped, now, collection: true, user: user)
        #expect(result.itemsLeftInLibrary == 5)
        #expect(result.addedItems == 10, "51–54, 57–60 and 61–62")
        #expect(library.items.count == 60)
        #expect(!library.items.contains { $0.url == Self.url(55) || $0.url == Self.url(56) })
        #expect(library.duplicatedURLs.isEmpty)
        // Each document the collection holds has its note; those removed got none.
        #expect(now.allSatisfy { library.notes(under: $0.url!).count == 1 })
        #expect((1...5).allSatisfy { library.notes(under: Self.url($0)).isEmpty })
    }

    @Test("A notes write whose answer was lost is counted as written, and its notes are not written twice")
    func lostAnswerOfANotesWrite() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the document, 2 its notes, whose answer is lost.
        library.answer(write: 2, with: .loseAnswer)
        let items = Self.items(1, notes: 2)
        let stopped = try await Self.stop(items, collection: false, user: user)
        #expect(stopped.progress.writeInFlight == .notes)
        #expect(library.notes.count == 2)

        let result = try await Self.finish(after: stopped, items, collection: false, user: user)
        #expect(library.notes.count == 2, "the finish wrote the notes again")
        #expect(result.addedNotes == 2)
    }

    @Test("A note a document gained since the stop is sent, and the notes sent are not sent again")
    func aNoteGainedSinceIsSent() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 items 1–50, 2 item 51, 3 notes 1–50, 4 the note on 51, which Zotero refuses with a 503.
        library.answer(write: 4, with: .refuse(503))
        let items = Self.items(51, notes: 1)
        let stopped = try await Self.stop(items, collection: false, user: user)
        #expect(stopped.progress.writtenNoteCount == 50 && stopped.progress.writeInFlight == .notes)

        // Document 1 gained a note since the stop.
        var gained = items
        gained[0].notes?.append(ZoteroJSONExporter.Note(note: "A note written since"))
        let result = try await Self.finish(after: stopped, gained, collection: false, user: user)
        #expect(library.notes(under: Self.url(1)) == ["<p>Note 1 on 1</p>", "<p>A note written since</p>"])
        #expect(library.notes(under: Self.url(51)) == ["<p>Note 1 on 51</p>"])
        #expect(library.notes.count == 52)
        #expect(result.addedNotes == 2)
    }

    @Test("A finish settles the write in flight before it writes anything new, so a document added since records its own write")
    func theWriteInFlightIsSettledFirst() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the collection, 2 documents 1–2, 3 their notes, whose answer is lost. The finish, of the
        // collection with document 3 added: 4 the notes again (412), then 5 document 3, whose answer is lost too.
        library.answer(write: 3, with: .loseAnswer)
        library.answer(write: 5, with: .loseAnswer)
        let stopped = try await Self.stop(Self.items(2, notes: 1), collection: true, user: user)
        #expect(stopped.progress.writeInFlight == .notes)

        let gained = Self.items(3, notes: 1)
        let again = await Self.send(gained, collection: true, user: user, resuming: stopped.progress)
        guard case .failure(let error) = again, let second = error as? ZoteroSendStopped else {
            Issue.record("the first finish ended \(again)")
            return
        }
        #expect(second.progress.writeInFlight == .items, "document 3's write was not recorded as in flight")
        #expect(second.progress.inFlight?.items.map(\.name) == [Self.url(3)])
        #expect(second.progress.writtenNoteCount == 2)

        _ = try await Self.finish(after: second, gained, collection: true, user: user)
        #expect(library.items.count == 3 && library.duplicatedURLs.isEmpty)
        #expect(gained.allSatisfy { library.notes(under: $0.url!).count == 1 })
    }

    @Test("A collection write whose answer was lost is found by its name, and not taken for an older collection of that name")
    func lostAnswerOfTheCollectionWrite() async throws {
        let (user, library) = StandIn.register()
        let older = library.addCollection(named: Self.collectionName)
        library.addItem(url: Self.url(900), title: "Document 900: Memorandum", in: older)
        library.answer(write: 1, with: .loseAnswer)
        let items = Self.items(3)
        let stopped = try await Self.stop(items, collection: true, user: user)
        #expect(stopped.progress.writeInFlight == .collection)
        let made = try #require(library.collections.last?.key)

        let result = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(result.collectionKey == made, "the finish wrote into \(String(describing: result.collectionKey)), not the collection the lost write made")
        #expect(library.collections.count == 2, "the older one and the one the send made")
        #expect(library.items.filter { $0.collections == [made] }.count == 3)
        #expect(library.log.contains("GET /collections"))
    }

    @Test("A collection write whose answer was lost, and whose collection the reader has deleted since, is made anew")
    func lostCollectionDeletedSince() async throws {
        let (user, library) = StandIn.register()
        library.answer(write: 1, with: .loseAnswer)
        let items = Self.items(2)
        let stopped = try await Self.stop(items, collection: true, user: user)
        library.removeCollection(try #require(library.collections.first?.key))

        let result = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(library.collections.count == 1)
        #expect(result.collectionKey == library.collections.first?.key)
        #expect(library.items.count == 2)
    }

    @Test("A document's send whose answer was lost finds its item among the library's newest, past an older copy of the document")
    func lostAnswerOfADocumentSend() async throws {
        let (user, library) = StandIn.register()
        let olderCopy = library.addItem(url: Self.url(1), title: "Document 1: Memorandum")
        library.answer(write: 1, with: .loseAnswer)
        let items = Self.items(1, notes: 1)
        let stopped = try await Self.stop(items, collection: false, user: user)
        let made = try #require(library.items.last?.key)

        _ = try await Self.finish(after: stopped, items, collection: false, user: user)
        #expect(library.items.count == 2, "the older copy and the one the send made")
        #expect(library.notes.map(\.parent) == [made], "the note went under \(library.notes.map(\.parent)), not the item the send made")
        #expect(!library.notes.contains { $0.parent == olderCopy })
        #expect(library.log.contains("GET /items/top"))
    }

    @Test("A finish whose read fails stops again with its write still in flight, and a second finish ends it")
    func aFinishWhoseReadFails() async throws {
        let (user, library) = StandIn.register()
        library.answer(write: 2, with: .loseAnswer)
        let items = Self.items(5, notes: 1)
        let stopped = try await Self.stop(items, collection: true, user: user)
        library.failReads(1)

        let again = await Self.send(items, collection: true, user: user, resuming: stopped.progress)
        guard case .failure(let error) = again, let second = error as? ZoteroSendStopped else {
            Issue.record("the first finish ended \(again)")
            return
        }
        #expect(second.progress.writeInFlight == .items)
        #expect(second.progress.inFlight?.writeToken == stopped.progress.inFlight?.writeToken)
        #expect(second.progress.inFlight?.firstSentAt == stopped.progress.inFlight?.firstSentAt)

        _ = try await Self.finish(after: second, items, collection: true, user: user)
        #expect(library.items.count == 5 && library.duplicatedURLs.isEmpty)
        #expect(library.notes.count == 5)
    }

    @Test("A document entered twice is two items, and a finish writes the second copy")
    func aDocumentEnteredTwice() async throws {
        let (user, library) = StandIn.register()
        // Item 51 is document 1 again. Writes: 1 the collection, 2 items 1–50, 3 items 51–52, refused.
        library.answer(write: 3, with: .refuse(503))
        let items = Self.items(50) + Self.items(1) + Self.items(1, from: 51)
        let stopped = try await Self.stop(items, collection: true, user: user)
        let result = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(library.items.filter { $0.url == Self.url(1) }.count == 2)
        #expect(library.items.count == 52)
        #expect(result.addedItems == 2)
    }

    @Test("A progress for another account is not resumed: the send starts afresh there")
    func anotherAccountsProgressIsNotResumed() async throws {
        let (user, library) = StandIn.register()
        library.answer(write: 3, with: .refuse(503))
        let items = Self.items(60)
        let stopped = try await Self.stop(items, collection: true, user: user)

        let (other, otherLibrary) = StandIn.register()
        _ = try await Self.send(items, collection: true, user: other, resuming: stopped.progress).get()
        #expect(otherLibrary.collections.count == 1 && otherLibrary.items.count == 60)
        #expect(library.items.count == 50, "the first account's library was written to")
    }

    @Test("A send cancelled once Zotero took a batch throws its progress, with the cancellation as its cause")
    func aCancelledSend() async throws {
        let (user, library) = StandIn.register()
        let items = Self.items(60)
        // The host's closure runs on the send's task: once the first batch's answer is read, it cancels it.
        let outcome = await Task {
            await Self.send(items, collection: true, user: user, heard: Heard(cancelWhen: { $0.writtenItemCount == 50 }))
        }.value
        guard case .failure(let error) = outcome, let stopped = error as? ZoteroSendStopped else {
            Issue.record("the send ended \(outcome)")
            return
        }
        #expect(stopped.cause is CancellationError)
        #expect(stopped.progress.writtenItemCount == 50 && stopped.progress.writeInFlight == nil)

        _ = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(library.items.count == 60 && library.duplicatedURLs.isEmpty)
    }

    // MARK: The progress as a value

    @Test("A progress round-trips through JSON, and a finish may start until 12 hours after its write in flight was first sent")
    func theProgressAsAValue() async throws {
        let (user, library) = StandIn.register()
        library.answer(write: 3, with: .loseAnswer)
        let stopped = try await Self.stop(Self.items(60, notes: 1), collection: true, user: user)
        let progress = stopped.progress
        let decoded = try JSONDecoder().decode(ZoteroSendProgress.self, from: JSONEncoder().encode(progress))
        #expect(decoded == progress)

        let sent = try #require(progress.inFlight?.firstSentAt)
        #expect(progress.expiresAt == sent.addingTimeInterval(12 * 60 * 60))
        #expect(progress.canFinish(for: user, at: sent.addingTimeInterval(12 * 60 * 60 - 1)))
        #expect(!progress.canFinish(for: user, at: progress.expiresAt))
        #expect(!progress.canFinish(for: user + 1, at: sent))
        #expect(!ZoteroSendProgress(userID: user, at: sent).canFinish(for: user, at: sent), "an empty progress")
    }

    @Test("A note is known by its text's SHA-256")
    func aNoteIsKnownByItsDigest() {
        #expect(ZoteroSendProgress.digest(of: "abc")
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(ZoteroSendProgress.digest(of: "Note 1 on 1") != ZoteroSendProgress.digest(of: "Note 1 on 2"))
    }

    @Test("An item's identity is its URL, or its title where it has none, with its place among the items of that name")
    func anItemsIdentity() {
        let items = [
            ZoteroJSONExporter.Item(itemType: "bookSection", title: "A", url: Self.url(1)),
            ZoteroJSONExporter.Item(itemType: "bookSection", title: "B", url: Self.url(1)),
            ZoteroJSONExporter.Item(itemType: "bookSection", title: "C", url: nil),
            ZoteroJSONExporter.Item(itemType: "bookSection", title: "C", url: ""),
        ]
        let identities = ZoteroSendProgress.ItemIdentity.of(items)
        #expect(identities.map(\.name) == [Self.url(1), Self.url(1), "title:C", "title:C"])
        #expect(identities.map(\.occurrence) == [1, 2, 1, 2])
    }
}

#if !canImport(FoundationNetworking)
// As `ZoteroRetryWaitTests.StubURLProtocol` declares it: Linux's `URLProtocol` is explicitly not `Sendable`,
// so there it conforms to nothing. The stand-in's own state is behind its locks.
extension ZoteroSendResumeTests.StandIn: @unchecked Sendable {}
#endif
