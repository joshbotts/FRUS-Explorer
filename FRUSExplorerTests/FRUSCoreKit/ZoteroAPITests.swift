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
// Moved into FRUSCoreKit's suites with the Zotero client (FRUS Explorer Light's S22c, 2026-11-11).
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - Fixtures

private let document = FRUSDocumentMetadata(
    documentId: "d1",
    documentNumber: "1",
    header: "Memorandum of Conversation",
    dateline: "Washington, January 1, 1972"
)

private let volume = FRUSVolumeMetadata(
    title: "Foreign Relations of the United States, 1969–1976, Volume I",
    editors: ["Louis J. Smith", "David H. Herschler"],
    generalEditor: nil,
    publicationDate: "1972",
    publicationPlace: "Washington, D.C.",
    publisher: "Government Printing Office"
)

// MARK: - Creator splitting

struct ZoteroAPICreatorTests {

    @Test("Creator: splits a full name on the last space into first/last")
    func splitsName() {
        let c = ZoteroAPICreator.from(type: "editor", fullName: "Louis J. Smith")
        #expect(c.creatorType == "editor")
        #expect(c.firstName == "Louis J.")
        #expect(c.lastName == "Smith")
        #expect(c.name == nil)
    }

    @Test("Creator: single-token name falls back to the single-field form")
    func singleTokenName() {
        let c = ZoteroAPICreator.from(type: "author", fullName: "Department")
        #expect(c.firstName == nil)
        #expect(c.lastName == nil)
        #expect(c.name == "Department")
    }
}

// MARK: - Item mapping + encoding

struct ZoteroAPIItemTests {

    private func sampleItem() -> ZoteroJSONExporter.Item {
        ZoteroJSONExporter.makeItem(
            document: document, volume: volume, year: "1972",
            url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
            isEditorialNote: false, tags: ["NATO"], notes: ["My research note"]
        )
    }

    @Test("ZoteroAPIItem: maps fields, tags, split creators, and the collection key")
    func mapsFromItem() {
        let api = ZoteroAPIItem(item: sampleItem(), collectionKey: "COLL1")
        #expect(api.itemType == "bookSection")
        #expect(api.title == "Document 1: Memorandum of Conversation")
        #expect(api.tags.map(\.tag) == ["NATO"])
        #expect(api.collections == ["COLL1"])
        #expect(api.creators.contains { $0.firstName == "Louis J." && $0.lastName == "Smith" })
        #expect(api.creators.allSatisfy { $0.creatorType == "editor" })
    }

    @Test("ZoteroAPIItem: nil collection key yields an empty collections array")
    func noCollectionKey() {
        let api = ZoteroAPIItem(item: sampleItem(), collectionKey: nil)
        #expect(api.collections.isEmpty)
    }

    @Test("ZoteroAPIItem: encodes split creators and omits nil fields")
    func encodingShape() throws {
        let api = ZoteroAPIItem(item: sampleItem(), collectionKey: "COLL1")
        let data = try JSONEncoder().encode(api)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["itemType"] as? String == "bookSection")
        let creators = try #require(json["creators"] as? [[String: Any]])
        #expect(creators.first?["firstName"] as? String == "Louis J.")
        #expect(creators.first?["lastName"] as? String == "Smith")
        #expect(creators.first?["name"] == nil) // single-field form omitted
        #expect((json["collections"] as? [String]) == ["COLL1"])
    }
}

// MARK: - Notes (child items)

struct ZoteroAPINoteTests {

    @Test("htmlify: escapes entities and wraps blocks in paragraphs")
    func htmlifyEscapesAndWraps() {
        let html = ZoteroAPINote.htmlify("First & <best>\n\nSecond line")
        #expect(html.contains("&amp;"))
        #expect(html.contains("&lt;best&gt;"))
        #expect(html.contains("<p>First &amp; &lt;best&gt;</p>"))
        #expect(html.contains("<p>Second line</p>"))
    }

    @Test("htmlNote: attaches to the parent item")
    func htmlNoteParent() {
        let note = ZoteroAPINote.htmlNote(parentItem: "ITEMKEY1", text: "hi")
        #expect(note.itemType == "note")
        #expect(note.parentItem == "ITEMKEY1")
        #expect(note.note == "<p>hi</p>")
    }
}

// MARK: - Response decoding

struct ZoteroResponseTests {

    @Test("ZoteroWriteResponse: decodes successful/failed and maps index→key")
    func decodesWriteResponse() throws {
        let json = """
        { "successful": { "0": { "key": "ITEMKEY1", "version": 1 },
                          "2": { "key": "ITEMKEY3", "version": 1 } },
          "success": { "0": "ITEMKEY1", "2": "ITEMKEY3" },
          "unchanged": {},
          "failed": { "1": { "code": 400, "message": "bad" } } }
        """
        let resp = try JSONDecoder().decode(ZoteroWriteResponse.self, from: Data(json.utf8))
        #expect(resp.keysByIndex[0] == "ITEMKEY1")
        #expect(resp.keysByIndex[2] == "ITEMKEY3")
        #expect(resp.failed["1"]?.code == 400)
    }

    @Test("ZoteroKeyInfo: decodes userID and write/notes access")
    func decodesKeyInfo() throws {
        let json = """
        { "key": "abc", "userID": 12345, "username": "researcher",
          "access": { "user": { "library": true, "write": true, "notes": true } } }
        """
        let info = try JSONDecoder().decode(ZoteroKeyInfo.self, from: Data(json.utf8))
        #expect(info.userID == 12345)
        #expect(info.username == "researcher")
        #expect(info.canWriteNotes)
    }

    @Test("ZoteroKeyInfo: read-only key is rejected by canWriteNotes")
    func readOnlyKey() throws {
        let json = """
        { "userID": 1, "access": { "user": { "library": true, "write": false } } }
        """
        let info = try JSONDecoder().decode(ZoteroKeyInfo.self, from: Data(json.utf8))
        #expect(!info.canWriteNotes)
    }
}

// MARK: - Waits on Zotero's word

/// `ZoteroAPIClient`'s waits on a 429's `Retry-After` and on a `Backoff` (FRUS Explorer Light's follow-up
/// for S22e): a header counts only when its seconds are finite and not negative, a 429 that gives none
/// waits the 30 s default, and no wait lasts longer than `ZoteroAPIClient.longestWait`. A `Retry-After`
/// past it reaches the caller at once, and a `Backoff` past it is waited for that long. Since L41, a
/// `Backoff` holds the account's next request, whichever client makes it, and not the write that gave it
/// (#1924); a send reports each wait through its `status` before it (#1925); and a `Retry-After` may name
/// an HTTP date (#1926).
///
/// Every client here but the last two tests' sleeps through a recorder or a `TestClock`, so no test waits:
/// each reads the waits its client asked for, in seconds, and a `TestClock` moves its time on by them, so a
/// deadline is read exactly. The last two hold the public client, whose sleep is real, to no wait where
/// none is due, and to two waits of a tenth of a second where those are due. Their bounds are for a hang,
/// not for the Mac's pace: in parallel on CI's three cores, the first took 59.7 s with no wait at all
/// (run 1, 2026-11-26). The stub answers each request from the id in its path, which is its test's own, so
/// the tests that run beside each other never see each other's requests, nor each other's deadlines, which
/// are kept by that id.
///
/// Version history:
///   1.0 — 2026-11-14: FRUS Explorer Light's follow-up for S22e, with the bound
///   1.1 — 2026-11-27: L41 (#1924, #1925, #1926), each defect shown first; the public client's bounds and
///          the suite's limit sized for a slow runner
@Suite("Zotero client — waits on Zotero's word", .timeLimit(.minutes(5)))
struct ZoteroRetryWaitTests {

    /// What the stub answers one request with.
    struct Answer: Sendable {
        let status: Int
        var headers: [String: String] = [:]
    }

    /// Answers each request with the answers registered under the id in its path (`users/<id>/…`, or
    /// `keys/<id>` for an account), in turn, the last repeated, and counts the requests under each id.
    final class StubURLProtocol: URLProtocol {
        private static let lock = NSLock()
        nonisolated(unsafe) private static var answers: [String: [Answer]] = [:]
        nonisolated(unsafe) private static var asked: [String: Int] = [:]
        nonisolated(unsafe) private static var lastID = 7_100_000

        /// Registers a test's answers under an id of its own, which the test passes as the user's id or key.
        static func register(_ answers: [Answer]) -> Int {
            lock.lock(); defer { lock.unlock() }
            lastID += 1
            Self.answers[String(lastID)] = answers
            return lastID
        }

        /// How many requests the stub has been asked under `id`.
        static func requests(for id: Int) -> Int {
            lock.lock(); defer { lock.unlock() }
            return asked[String(id), default: 0]
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            let parts = request.url!.pathComponents
            let id = parts.firstIndex(where: { $0 == "users" || $0 == "keys" })
                .flatMap { parts.indices.contains($0 + 1) ? parts[$0 + 1] : nil } ?? ""
            let answer: Answer = {
                Self.lock.lock(); defer { Self.lock.unlock() }
                let turn = Self.asked[id, default: 0]
                Self.asked[id] = turn + 1
                guard let list = Self.answers[id], !list.isEmpty else { return Answer(status: 404) }
                return list[min(turn, list.count - 1)]
            }()
            var headers = answer.headers
            headers["Content-Type"] = "application/json"
            // A 2xx is a write that created the one item sent.
            let body = (200..<300).contains(answer.status)
                ? #"{"successful": {"0": {"key": "ITEMKEY1", "version": 1}}, "success": {"0": "ITEMKEY1"}, "unchanged": {}, "failed": {}}"#
                : "{}"
            let response = HTTPURLResponse(url: request.url!, statusCode: answer.status, httpVersion: "HTTP/1.1",
                                           headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    /// The waits a client asked for, in seconds, in order.
    actor WaitRecorder {
        private(set) var seconds: [Double] = []

        func record(_ nanoseconds: UInt64) {
            seconds.append(Double(nanoseconds) / 1_000_000_000)
        }

        /// The sleep to give the client: it records the wait and returns at once.
        nonisolated var sleep: @Sendable (UInt64) async throws -> Void {
            { [self] nanoseconds in await record(nanoseconds) }
        }
    }

    /// What a send came to: its result or error, the waits it asked for, and the requests it made.
    struct Outcome {
        let result: Result<ZoteroSendResult, any Error>
        let waits: [Double]
        let requests: Int

        /// The seconds of the `rateLimited` the send threw, or nil when it threw something else or nothing.
        var rateLimitedSeconds: Double? {
            guard case .failure(let error) = result, case ZoteroAPIError.rateLimited(let seconds) = error else { return nil }
            return seconds
        }

        /// The items the send added, or nil when it threw.
        var addedItems: Int? { try? result.get().addedItems }
    }

    /// The one item every send here sends, with no notes and no collection, so that a send is one write.
    private static let item = ZoteroJSONExporter.makeItem(
        document: document, volume: volume, year: "1972",
        url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
        isEditorialNote: false, tags: [], notes: []
    )

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func tooMany(_ retryAfter: String?) -> Answer {
        Answer(status: 429, headers: retryAfter.map { ["Retry-After": $0] } ?? [:])
    }

    private static func created(backoff: String?) -> Answer {
        Answer(status: 200, headers: backoff.map { ["Backoff": $0] } ?? [:])
    }

    /// Sends `item` through a client that records its waits, the stub giving `answers` in turn.
    private func send(_ answers: [Answer]) async -> Outcome {
        let user = StubURLProtocol.register(answers)
        let recorder = WaitRecorder()
        let client = ZoteroAPIClient(session: Self.stubbedSession(), sleep: recorder.sleep)
        let result: Result<ZoteroSendResult, any Error>
        do {
            result = .success(try await client.send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                                    userID: user, username: nil))
        } catch {
            result = .failure(error)
        }
        return Outcome(result: result, waits: await recorder.seconds, requests: StubURLProtocol.requests(for: user))
    }

    /// What a send told its caller and what it waited, in the order it did them (L41).
    enum Event: Equatable, Sendable {
        case status(String)
        case wait(Double)
    }

    /// A clock a test moves, which also keeps what its sends told their callers and waited (L41).
    ///
    /// Its sleep logs each wait and moves `now()` on by as much, so a `Backoff` deadline set at one moment is
    /// read the exact seconds later the client waited, and `advance(by:)` is time passing between two sends.
    /// Its wall clock, which a `Retry-After` date is counted from when the response has no `Date`, stands at
    /// RFC 9110's example moment. Every method takes the lock, and none is async: `NSLock` is not for an
    /// async context.
    final class TestClock: @unchecked Sendable {
        /// `Sun, 06 Nov 1994 08:49:37 GMT`, RFC 9110's example of an HTTP date.
        static let wallNow = Date(timeIntervalSince1970: 784_111_777)

        private let lock = NSLock()
        private let origin = ContinuousClock.now
        private var elapsed: Duration = .zero
        private var kept: [Event] = []

        /// Everything the sends told their callers and waited, in order.
        var events: [Event] {
            lock.lock(); defer { lock.unlock() }
            return kept
        }

        /// The waits alone, in seconds.
        var waits: [Double] {
            events.compactMap { event -> Double? in
                if case .wait(let seconds) = event { return seconds }
                return nil
            }
        }

        /// The clock's moment: when it was made, moved on by every wait and every `advance(by:)`.
        func now() -> ContinuousClock.Instant {
            lock.lock(); defer { lock.unlock() }
            return origin.advanced(by: elapsed)
        }

        /// Moves the clock on, as time passing between two sends.
        func advance(by seconds: Double) {
            lock.lock(); defer { lock.unlock() }
            elapsed += .seconds(seconds)
        }

        /// Logs a wait the client asked for, and moves the clock on by it.
        func waited(nanoseconds: UInt64) {
            lock.lock(); defer { lock.unlock() }
            kept.append(.wait(Double(nanoseconds) / 1_000_000_000))
            elapsed += .nanoseconds(Int64(nanoseconds))
        }

        /// Logs what a send told its caller.
        func said(_ message: String) {
            lock.lock(); defer { lock.unlock() }
            kept.append(.status(message))
        }

        /// The status callback to give a send.
        var status: @Sendable (String) -> Void {
            { [self] message in said(message) }
        }

        /// A client that waits, reads the time and counts a `Retry-After` date by this clock, and holds to the
        /// process's `Backoff` deadlines, as every client does.
        func client() -> ZoteroAPIClient {
            ZoteroAPIClient(session: ZoteroRetryWaitTests.stubbedSession(),
                            sleep: { [self] nanoseconds in waited(nanoseconds: nanoseconds) },
                            now: { [self] in now() },
                            wallClock: { Self.wallNow })
        }
    }

    /// Sends `item` through `clock`'s client, its status kept by `clock`, the stub giving `answers` in turn under an
    /// id of the send's own. With a `collection`, a send is two writes: the collection, then the item.
    private func send(_ answers: [Answer], collection: String? = nil, by clock: TestClock) async -> Outcome {
        let user = StubURLProtocol.register(answers)
        let result: Result<ZoteroSendResult, any Error>
        do {
            result = .success(try await clock.client().send(items: [Self.item], collectionName: collection,
                                                            apiKey: "placeholder", userID: user, username: nil,
                                                            status: clock.status))
        } catch {
            result = .failure(error)
        }
        return Outcome(result: result, waits: clock.waits, requests: StubURLProtocol.requests(for: user))
    }

    /// The name of the collection a two-write send makes.
    private static let collectionName = "Placeholder"

    /// What a send says as it begins each of its steps here: the collection, then the one item.
    private static let collectionStep = "Creating collection…"
    private static let itemStep = "Uploading items 1–1…"

    // MARK: Reading a header

    @Test("A header's seconds count when finite and not negative, and -0 reads as 0",
          arguments: [("30", 30.0), ("0.5", 0.5), ("60", 60.0), ("1e300", 1e300), ("0", 0.0), ("-0", 0.0)]
            as [(String, Double)])
    func usableSeconds(_ value: String, _ seconds: Double) {
        let read = ZoteroAPIClient.headerSeconds(value)
        #expect(read == seconds)
        #expect(read?.sign == .plus, "\(value) reads as a number of seconds that is not negative")
    }

    @Test("A header that is absent, not a number, not finite or negative gives no seconds",
          arguments: [nil, "", "nan", "NaN", "-nan", "inf", "-inf", "infinity", "-1", "-0.5", "-1e300", "30s",
                      "Wed, 21 Oct 2015 07:28:00 GMT"] as [String?])
    func unusableSeconds(_ value: String?) {
        #expect(ZoteroAPIClient.headerSeconds(value) == nil)
    }

    // MARK: A 429's Retry-After

    @Test("A 429 whose Retry-After gives no seconds the client can use waits 30 s before each of three retries",
          arguments: ["nan", "NaN", "-nan", "inf", "-inf", "infinity", "-1", "-0.5", "-1e300", "abc"])
    func unusableRetryAfter(_ value: String) async {
        let outcome = await send([Self.tooMany(value)])
        #expect(outcome.waits == [30, 30, 30])
        #expect(outcome.rateLimitedSeconds == 30)
        #expect(outcome.requests == 4)
    }

    @Test("A Retry-After date before the moment it is counted from, here the device's clock, waits the 30 s default, as none does")
    func httpDateRetryAfter() async {
        for value in ["Wed, 21 Oct 2015 07:28:00 GMT", nil] as [String?] {
            let outcome = await send([Self.tooMany(value)])
            #expect(outcome.waits == [30, 30, 30], "\(value ?? "no Retry-After")")
            #expect(outcome.rateLimitedSeconds == 30)
            #expect(outcome.requests == 4)
        }
    }

    @Test("A Retry-After past the longest wait reaches the caller at once, with Zotero's seconds and no retry",
          arguments: ["60.001", "61", "3600", "86400", "18446744074", "1e19", "1e300"])
    func longRetryAfter(_ value: String) async {
        let outcome = await send([Self.tooMany(value)])
        #expect(outcome.waits.isEmpty)
        #expect(outcome.rateLimitedSeconds == Double(value))
        #expect(outcome.requests == 1)
    }

    @Test("A Retry-After up to the longest wait is waited out before each retry, as before: 60, 2, 0.5, 0 and -0",
          arguments: [("60", 60.0), ("2", 2.0), ("0.5", 0.5), ("0", 0.0), ("-0", 0.0)] as [(String, Double)])
    func retryAfterWaitedOut(_ value: String, _ seconds: Double) async {
        let outcome = await send([Self.tooMany(value)])
        #expect(outcome.waits == [seconds, seconds, seconds])
        #expect(outcome.rateLimitedSeconds == seconds)
        #expect(outcome.rateLimitedSeconds?.sign == .plus)
        #expect(outcome.requests == 4)
    }

    @Test("A 429 and then a write: one wait of Zotero's seconds, then the send's result, as before")
    func retryThenWrite() async {
        let outcome = await send([Self.tooMany("1"), Self.created(backoff: nil)])
        #expect(outcome.waits == [1])
        #expect(outcome.addedItems == 1)
        #expect(outcome.requests == 2)
    }

    // MARK: A Backoff

    // Each send here is two writes, the collection and then the item, so a Backoff on the first holds the second.

    @Test("A Backoff past the longest wait holds the next write for the longest wait, and the send finishes",
          arguments: ["60.001", "61", "3600", "1e19", "1e300"])
    func longBackoff(_ value: String) async {
        let outcome = await send([Self.created(backoff: value), Self.created(backoff: nil)],
                                 collection: Self.collectionName, by: TestClock())
        #expect(outcome.waits == [ZoteroAPIClient.longestWait])
        #expect(outcome.addedItems == 1)
        #expect(outcome.requests == 2)
    }

    @Test("A Backoff that gives no seconds the client can use holds nothing, and the send finishes",
          arguments: ["nan", "inf", "-inf", "-1", "-0.5", "abc", "Wed, 21 Oct 2015 07:28:00 GMT"])
    func unusableBackoff(_ value: String) async {
        let outcome = await send([Self.created(backoff: value), Self.created(backoff: nil)],
                                 collection: Self.collectionName, by: TestClock())
        #expect(outcome.waits.isEmpty)
        #expect(outcome.addedItems == 1)
        #expect(outcome.requests == 2)
    }

    @Test("A Backoff up to the longest wait is waited out before the next write (#1924), and one of 0 or none holds nothing",
          arguments: [("60", [60.0]), ("5", [5.0]), ("0.5", [0.5]), ("0", []), ("-0", []), (nil, [])]
            as [(String?, [Double])])
    func backoffWaitedBeforeTheNextWrite(_ value: String?, _ waits: [Double]) async {
        let outcome = await send([Self.created(backoff: value), Self.created(backoff: nil)],
                                 collection: Self.collectionName, by: TestClock())
        #expect(outcome.waits == waits)
        #expect(outcome.addedItems == 1)
        #expect(outcome.requests == 2)
    }

    // MARK: The account

    @Test("An account's 429 is never retried, and carries 30 for a Retry-After the client cannot use, else Zotero's seconds")
    func accountRateLimited() async {
        for (value, seconds) in [("nan", 30.0), ("-1", 30.0), ("12", 12.0), ("1e300", 1e300)] {
            let key = StubURLProtocol.register([Self.tooMany(value)])
            let recorder = WaitRecorder()
            let client = ZoteroAPIClient(session: Self.stubbedSession(), sleep: recorder.sleep)
            do {
                _ = try await client.resolveAccount(key: String(key))
                Issue.record("\(value): the account resolved")
            } catch ZoteroAPIError.rateLimited(let carried) {
                #expect(carried == seconds, "\(value)")
            } catch {
                Issue.record("\(value): expected rateLimited, got \(error)")
            }
            #expect(await recorder.seconds.isEmpty)
            #expect(StubURLProtocol.requests(for: key) == 1)
        }
    }

    // MARK: L41 — a Backoff holds the next request (#1924)

    @Test("L41 (#1924): a send whose last write answers a Backoff returns at once")
    func backoffOnTheLastWriteIsNotWaited() async {
        let outcome = await send([Self.created(backoff: "5")])
        #expect(outcome.waits.isEmpty, "the send waited \(outcome.waits) after its last write")
        #expect(outcome.addedItems == 1)
    }

    @Test("L41 (#1924): the next send, by a new client, waits what is left of the Backoff before its first request, and says so")
    func nextSendByANewClientWaitsWhatIsLeft() async throws {
        let clock = TestClock()
        let user = StubURLProtocol.register([Self.created(backoff: "5"), Self.created(backoff: nil)])
        _ = try await clock.client().send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                          userID: user, username: nil, status: clock.status)
        #expect(clock.waits.isEmpty, "the first send waited \(clock.waits) after its last write")
        clock.advance(by: 2)
        let result = try await clock.client().send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                                   userID: user, username: nil, status: clock.status)
        #expect(clock.events == [.status(Self.itemStep),
                                 .status(Self.itemStep), .status(ZoteroAPIClient.backoffStatus(seconds: 3)), .wait(3),
                                 .status(Self.itemStep)])
        #expect(result.addedItems == 1)
        #expect(StubURLProtocol.requests(for: user) == 2)
    }

    @Test("L41 (#1924): a Backoff that has run out by the next send holds nothing")
    func passedBackoffHoldsNothing() async throws {
        let clock = TestClock()
        let user = StubURLProtocol.register([Self.created(backoff: "5"), Self.created(backoff: nil)])
        for _ in 0..<2 {
            _ = try await clock.client().send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                              userID: user, username: nil, status: clock.status)
            clock.advance(by: 5)
        }
        #expect(clock.waits.isEmpty)
        #expect(StubURLProtocol.requests(for: user) == 2)
    }

    @Test("L41 (#1924): an account's Backoff holds that account's requests, and not another's")
    func backoffHoldsItsAccountAlone() async throws {
        let clock = TestClock()
        let held = StubURLProtocol.register([Self.created(backoff: "5")])
        let other = StubURLProtocol.register([Self.created(backoff: nil)])
        _ = try await clock.client().send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                          userID: held, username: nil, status: clock.status)
        let result = try await clock.client().send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                                   userID: other, username: nil, status: clock.status)
        #expect(clock.waits.isEmpty)
        #expect(result.addedItems == 1)
    }

    @Test("L41 (#1924): the deadlines keep the later of two for an account, and drop one that has passed")
    func deadlinesKeepTheLaterAndDropThePassed() async {
        let deadlines = ZoteroBackoffDeadlines()
        let start = ContinuousClock.now
        await deadlines.hold(1, until: start.advanced(by: .seconds(5)))
        await deadlines.hold(1, until: start.advanced(by: .seconds(3)))
        #expect(await deadlines.remaining(for: 1, at: start) == 5)
        await deadlines.hold(1, until: start.advanced(by: .seconds(8)))
        #expect(await deadlines.remaining(for: 1, at: start.advanced(by: .seconds(2))) == 6)
        #expect(await deadlines.remaining(for: 2, at: start) == nil, "another account has none")
        #expect(await deadlines.remaining(for: 1, at: start.advanced(by: .seconds(8))) == nil)
        // Read at its end, the deadline was dropped, so an earlier one now stands.
        await deadlines.hold(1, until: start.advanced(by: .seconds(4)))
        #expect(await deadlines.remaining(for: 1, at: start) == 4)
    }

    // MARK: L41 — each wait reported through the send's status (#1925)

    @Test("L41 (#1925): a 429's wait is reported through status before it, and the step again after it")
    func retryWaitIsReported() async {
        let clock = TestClock()
        let outcome = await send([Self.tooMany("5"), Self.created(backoff: nil)], by: clock)
        #expect(outcome.addedItems == 1)
        #expect(clock.events == [.status(Self.itemStep), .status(ZoteroAPIClient.retryStatus(seconds: 5)), .wait(5),
                                 .status(Self.itemStep)])
    }

    @Test("L41 (#1925): a Backoff's wait is reported through status before it, and the step again after it")
    func backoffWaitIsReported() async {
        let clock = TestClock()
        let outcome = await send([Self.created(backoff: "3"), Self.created(backoff: nil)],
                                 collection: Self.collectionName, by: clock)
        #expect(outcome.addedItems == 1)
        #expect(clock.events == [.status(Self.collectionStep),
                                 .status(Self.itemStep), .status(ZoteroAPIClient.backoffStatus(seconds: 3)), .wait(3),
                                 .status(Self.itemStep)])
    }

    @Test("L41 (#1925): a send with no wait reports its steps as before, and a wait of 0 s says nothing")
    func noWaitSaysNothing() async {
        let clock = TestClock()
        _ = await send([Self.created(backoff: nil), Self.created(backoff: nil)], collection: Self.collectionName,
                       by: clock)
        #expect(clock.events == [.status(Self.collectionStep), .status(Self.itemStep)])
        let retried = TestClock()
        _ = await send([Self.tooMany("0"), Self.created(backoff: nil)], by: retried)
        #expect(retried.events == [.status(Self.itemStep), .wait(0)])
    }

    @Test("L41 (#1925): a wait's message names its whole seconds, rounded up, in the form for one or for many",
          arguments: [(1.0, "1 second"), (0.2, "1 second"), (1.5, "2 seconds"), (45.0, "45 seconds"), (60.0, "60 seconds")]
            as [(Double, String)])
    func waitMessages(_ seconds: Double, _ phrase: String) {
        let locale = Locale(identifier: "en_US_POSIX")
        #expect(ZoteroAPIClient.retryStatus(seconds: seconds, locale: locale) == "Zotero is busy: trying again in \(phrase)…")
        #expect(ZoteroAPIClient.backoffStatus(seconds: seconds, locale: locale)
                == "Zotero asked for a pause: continuing in \(phrase)…")
    }

    // MARK: L41 — a date Retry-After (#1926)

    @Test("L41 (#1926): a Retry-After gives its seconds, or those until its date, from the response's Date or else the device's clock",
          arguments: [
            ("45", nil, 45),
            ("Sun, 06 Nov 1994 08:50:22 GMT", "Sun, 06 Nov 1994 08:49:37 GMT", 45),
            ("Sun, 06 Nov 1994 09:49:37 GMT", "Sun, 06 Nov 1994 08:49:37 GMT", 3_600),
            ("Sun, 06 Nov 1994 08:49:37 GMT", "Sun, 06 Nov 1994 08:49:37 GMT", 0),
            ("Sun, 06 Nov 1994 08:50:22 GMT", nil, 45),
            ("Sun, 06 Nov 1994 08:50:22 GMT", "yesterday", 45),
            ("Sun, 06 Nov 1994 08:49:36 GMT", "Sun, 06 Nov 1994 08:49:37 GMT", nil),
            ("Sun, 06 Nov 1994 08:49:36 GMT", nil, nil),
            ("Sun, 06 Nov 1994 25:49:37 GMT", nil, nil),
            ("Sun, 06 Nov 1994 08:50:22 UTC", nil, nil),
            ("06 Nov 1994 08:50:22 GMT", nil, nil),
            ("Sunday, 06-Nov-94 08:50:22 GMT", nil, nil),
            ("Sun Nov  6 08:50:22 1994", nil, nil),
            (nil, "Sun, 06 Nov 1994 08:49:37 GMT", nil),
          ] as [(String?, String?, Double?)])
    func retryAfterReadings(_ value: String?, _ date: String?, _ seconds: Double?) {
        #expect(ZoteroAPIClient.retryAfterSeconds(value, responseDate: date, localNow: TestClock.wallNow) == seconds)
    }

    @Test("L41 (#1926): a Retry-After date 45 s after the response's Date waits 45 s before each retry")
    func retryAfterDateCountedFromTheResponseDate() async {
        let outcome = await send([Answer(status: 429, headers: ["Retry-After": "Sun, 06 Nov 1994 08:50:22 GMT",
                                                                "Date": "Sun, 06 Nov 1994 08:49:37 GMT"])])
        #expect(outcome.waits == [45, 45, 45])
        #expect(outcome.rateLimitedSeconds == 45)
        #expect(outcome.requests == 4)
    }

    @Test("L41 (#1926): a Retry-After date an hour after the response's Date reaches the caller at once, carrying 3,600")
    func retryAfterDateAnHourOn() async {
        let outcome = await send([Answer(status: 429, headers: ["Retry-After": "Sun, 06 Nov 1994 09:49:37 GMT",
                                                                "Date": "Sun, 06 Nov 1994 08:49:37 GMT"])])
        #expect(outcome.waits.isEmpty)
        #expect(outcome.rateLimitedSeconds == 3_600)
        #expect(outcome.requests == 1)
    }

    @Test("L41 (#1926): a Retry-After date 45 s after the device's clock, with no Date, waits 45 s before each retry")
    func retryAfterDateCountedFromTheLocalClock() async {
        let outcome = await send([Answer(status: 429, headers: ["Retry-After": "Sun, 06 Nov 1994 08:50:22 GMT"])],
                                 by: TestClock())
        #expect(outcome.waits == [45, 45, 45])
        #expect(outcome.rateLimitedSeconds == 45)
        #expect(outcome.requests == 4)
    }

    // MARK: The public client

    @Test("The public client, whose sleep is real, neither traps nor waits on an unusable Backoff or a long Retry-After")
    func publicClientNeitherTrapsNorWaits() async throws {
        let clock = ContinuousClock()
        let started = clock.now
        let client = ZoteroAPIClient(session: Self.stubbedSession())
        for value in ["nan", "inf", "-1"] {
            // Two sends for one account, so a Backoff wrongly held would hold the second.
            let user = StubURLProtocol.register([Self.created(backoff: value), Self.created(backoff: nil)])
            for _ in 0..<2 {
                let result = try await client.send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                                   userID: user, username: nil)
                #expect(result.addedItems == 1, "Backoff \(value)")
            }
        }
        for value in ["1e300", "3600"] {
            let user = StubURLProtocol.register([Self.tooMany(value)])
            do {
                _ = try await client.send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                          userID: user, username: nil)
                Issue.record("Retry-After \(value): the send finished")
            } catch ZoteroAPIError.rateLimited(let seconds) {
                #expect(seconds == Double(value), "Retry-After \(value)")
            }
            #expect(StubURLProtocol.requests(for: user) == 1, "Retry-After \(value)")
        }
        // A bound for a hang, not for the Mac's pace (the suite's comment). Waits wrongly made on the three Backoffs
        // alone would take 180 s, on the two Retry-Afters 360 s; the recorders above pin each wait exactly.
        #expect(clock.now - started < .seconds(150), "no wait was waited out")
    }

    @Test("The public client's sleep is real, and its Backoff holds the next public client: a Retry-After of 0.1 s and a Backoff of 0.1 s take 0.2 s over two sends")
    func publicClientSleeps() async throws {
        let user = StubURLProtocol.register([Self.tooMany("0.1"), Self.created(backoff: "0.1"),
                                             Self.created(backoff: nil)])
        let clock = ContinuousClock()
        let started = clock.now
        let first = try await ZoteroAPIClient(session: Self.stubbedSession())
            .send(items: [Self.item], collectionName: nil, apiKey: "placeholder", userID: user, username: nil)
        let firstTook = clock.now - started
        let second = try await ZoteroAPIClient(session: Self.stubbedSession())
            .send(items: [Self.item], collectionName: nil, apiKey: "placeholder", userID: user, username: nil)
        let elapsed = clock.now - started
        #expect(first.addedItems == 1 && second.addedItems == 1)
        #expect(StubURLProtocol.requests(for: user) == 3)
        // A sleep never returns early, so the lower bounds hold under any load; the upper is for a hang.
        #expect(firstTook >= .milliseconds(100), "the Retry-After was not slept: \(firstTook)")
        #expect(elapsed >= .milliseconds(200), "the two waits were not slept: \(elapsed)")
        #expect(elapsed < .seconds(120), "\(elapsed)")
    }
}

#if !canImport(FoundationNetworking)
// As `NARAAndZoteroClientHostTests.StubURLProtocol` declares it: Linux's `URLProtocol` is explicitly not
// `Sendable`, so there it conforms to nothing. The stub's own state is behind its lock.
extension ZoteroRetryWaitTests.StubURLProtocol: @unchecked Sendable {}
#endif
