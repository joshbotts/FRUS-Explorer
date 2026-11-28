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

/// A send to Zotero that stops part-way, and what a second send does after it (#1923, L64 of the plan of
/// record from 2026-11-25).
///
/// Every test sends through a Zotero stand-in (`StandIn`): one library per test, under a user id of the
/// test's own, which keeps what each write made and answers as Zotero's Web API v3 documents (*Write
/// Requests*, read 2026-11-27): a write token of a request that succeeded is remembered, and a second
/// request under it is refused with a 412; one of a request that failed is not. A test names the writes it
/// wants answered otherwise: refused before anything is written, written with the answer lost, or the
/// connection dropped before the write arrived. No test reaches the network, and no test waits: the client's
/// sleep returns at once.
///
/// Version history:
///   1.0 — 2026-11-27: L64 (#1923), the defect shown first
@Suite("Zotero send — a stopped send, sent again (#1923)", .timeLimit(.minutes(5)))
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
        func addItem(url: String, title: String, in collection: String? = nil) {
            lock.withLock {
                storedItems.append(Item(key: nextKey("I"), url: url, title: title,
                                        collections: collection.map { [$0] } ?? []))
            }
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
                url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d\(number)",
                notes: notes == 0 ? nil : (1...notes).map { ZoteroJSONExporter.Note(note: "Note \($0) on \(number)") })
        }
    }

    /// The name of the Zotero collection a collection's send makes.
    static let collectionName = "Placeholder"

    /// A client of the stand-in whose waits return at once.
    static func client() -> ZoteroAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StandIn.self]
        return ZoteroAPIClient(session: URLSession(configuration: configuration), sleep: { _ in })
    }

    /// Sends `items`, as the app's collection sheet does when `collection` is true and as its Share sends do
    /// otherwise, and returns what the send threw, or nil when it finished.
    static func send(_ items: [ZoteroJSONExporter.Item], collection: Bool, user: Int) async -> (any Error)? {
        do {
            _ = try await client().send(items: items, collectionName: collection ? collectionName : nil,
                                        apiKey: "placeholder", userID: user, username: nil)
            return nil
        } catch {
            return error
        }
    }

    /// Finishes a send that stopped with `error`, as a caller can.
    ///
    /// The error says nothing of how far the send got, so all a caller can do is send again: what the app's
    /// sheet and Share sends do when the reader taps Send to Zotero Library a second time.
    static func finish(after error: any Error, _ items: [ZoteroJSONExporter.Item], collection: Bool,
                       user: Int) async throws -> ZoteroSendResult {
        try await client().send(items: items, collectionName: collection ? collectionName : nil,
                                apiKey: "placeholder", userID: user, username: nil)
    }

    // MARK: The defect (#1923)

    @Test("#1923: a collection's send stopped at its second batch, finished, leaves one Zotero collection and each document once")
    func stoppedAtTheSecondBatch() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the collection, 2 items 1–50, 3 items 51–60, which Zotero refuses with a 503.
        library.answer(write: 3, with: .refuse(503))
        let items = Self.items(60)
        let stopped = try #require(await Self.send(items, collection: true, user: user))
        #expect(library.items.count == 50, "the stop kept the first batch")

        _ = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(library.collections.count == 1, "the finish made \(library.collections.count - 1) more Zotero collection(s)")
        #expect(library.duplicatedURLs.isEmpty, "\(library.duplicatedURLs.count) documents are in Zotero twice")
        #expect(library.items.count == 60)
    }

    @Test("#1923: a batch whose answer was lost, finished, leaves each document once, its notes under it")
    func lostAnswerOfABatch() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the collection, 2 items 1–50, whose answer is lost, then the notes.
        library.answer(write: 2, with: .loseAnswer)
        let items = Self.items(50, notes: 1)
        let stopped = try #require(await Self.send(items, collection: true, user: user))
        #expect(library.items.count == 50, "Zotero wrote the batch")
        #expect(library.notes.isEmpty)

        _ = try await Self.finish(after: stopped, items, collection: true, user: user)
        #expect(library.collections.count == 1, "the finish made \(library.collections.count - 1) more Zotero collection(s)")
        #expect(library.duplicatedURLs.isEmpty, "\(library.duplicatedURLs.count) documents are in Zotero twice")
        #expect(library.items.count == 50)
        #expect(library.notes.count == 50)
        #expect(items.allSatisfy { library.notes(under: $0.url!).count == 1 }, "a document's note is missing or doubled")
    }

    @Test("#1923: a document's send whose notes stopped, finished, leaves the document once with each of its notes")
    func documentSendStoppedAtItsNotes() async throws {
        let (user, library) = StandIn.register()
        // Writes: 1 the document, 2 its notes, which Zotero refuses with a 503.
        library.answer(write: 2, with: .refuse(503))
        let items = Self.items(1, notes: 2)
        let stopped = try #require(await Self.send(items, collection: false, user: user))
        #expect(library.items.count == 1)
        #expect(library.notes.isEmpty)

        _ = try await Self.finish(after: stopped, items, collection: false, user: user)
        #expect(library.duplicatedURLs.isEmpty, "the document is in Zotero \(library.items.count) times")
        #expect(library.notes(under: items[0].url!) == ["<p>Note 1 on 1</p>", "<p>Note 2 on 1</p>"])
    }
}

#if !canImport(FoundationNetworking)
// As `ZoteroRetryWaitTests.StubURLProtocol` declares it: Linux's `URLProtocol` is explicitly not `Sendable`,
// so there it conforms to nothing. The stand-in's own state is behind its locks.
extension ZoteroSendResumeTests.StandIn: @unchecked Sendable {}
#endif
