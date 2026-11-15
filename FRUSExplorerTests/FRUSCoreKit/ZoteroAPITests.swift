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
/// past it reaches the caller at once, and a `Backoff` past it is waited for that long.
///
/// Every client here but the last two tests' sleeps through a recorder, so no test waits: each reads the
/// waits its client asked for, in seconds. The last two hold the public client, whose sleep is real, to
/// no wait where none is due, and to two waits of a tenth of a second where those are due. The stub answers each
/// request from the id in its path, which is its test's own, so the tests that run beside each other
/// never see each other's requests.
///
/// Version history:
///   1.0 — 2026-11-14: FRUS Explorer Light's follow-up for S22e, with the bound
@Suite("Zotero client — waits on Zotero's word", .timeLimit(.minutes(1)))
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

    @Test("An HTTP-date Retry-After, which Zotero does not document, waits the 30 s default, as none does")
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

    @Test("A Backoff past the longest wait is waited for the longest wait, and the send finishes",
          arguments: ["60.001", "61", "3600", "1e19", "1e300"])
    func longBackoff(_ value: String) async {
        let outcome = await send([Self.created(backoff: value)])
        #expect(outcome.waits == [ZoteroAPIClient.longestWait])
        #expect(outcome.addedItems == 1)
        #expect(outcome.requests == 1)
    }

    @Test("A Backoff that gives no seconds the client can use is not waited on, and the send finishes",
          arguments: ["nan", "inf", "-inf", "-1", "-0.5", "abc", "Wed, 21 Oct 2015 07:28:00 GMT"])
    func unusableBackoff(_ value: String) async {
        let outcome = await send([Self.created(backoff: value)])
        #expect(outcome.waits.isEmpty)
        #expect(outcome.addedItems == 1)
        #expect(outcome.requests == 1)
    }

    @Test("A Backoff up to the longest wait is waited out after the write, as before, and none is not waited on",
          arguments: [("60", [60.0]), ("5", [5.0]), ("0", [0.0]), ("-0", [0.0]), (nil, [])] as [(String?, [Double])])
    func backoffWaitedOut(_ value: String?, _ waits: [Double]) async {
        let outcome = await send([Self.created(backoff: value)])
        #expect(outcome.waits == waits)
        #expect(outcome.addedItems == 1)
        #expect(outcome.requests == 1)
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

    // MARK: The public client

    @Test("The public client, whose sleep is real, neither traps nor waits on an unusable Backoff or a long Retry-After")
    func publicClientNeitherTrapsNorWaits() async throws {
        let clock = ContinuousClock()
        let started = clock.now
        let client = ZoteroAPIClient(session: Self.stubbedSession())
        for value in ["nan", "inf", "-1"] {
            let user = StubURLProtocol.register([Self.created(backoff: value)])
            let result = try await client.send(items: [Self.item], collectionName: nil, apiKey: "placeholder",
                                               userID: user, username: nil)
            #expect(result.addedItems == 1, "Backoff \(value)")
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
        #expect(clock.now - started < .seconds(10), "no wait was waited out")
    }

    @Test("The public client's sleep is real, in seconds: a 429's Retry-After of 0.1 and a Backoff of 0.1 take 0.2 s")
    func publicClientSleeps() async throws {
        let user = StubURLProtocol.register([Self.tooMany("0.1"), Self.created(backoff: "0.1")])
        let clock = ContinuousClock()
        let started = clock.now
        let result = try await ZoteroAPIClient(session: Self.stubbedSession())
            .send(items: [Self.item], collectionName: nil, apiKey: "placeholder", userID: user, username: nil)
        let elapsed = clock.now - started
        #expect(result.addedItems == 1)
        #expect(StubURLProtocol.requests(for: user) == 2)
        // A sleep never returns early, so the lower bound holds under any load.
        #expect(elapsed >= .milliseconds(200), "the two waits were not slept: \(elapsed)")
        #expect(elapsed < .seconds(10), "\(elapsed)")
    }
}

#if !canImport(FoundationNetworking)
// As `NARAAndZoteroClientHostTests.StubURLProtocol` declares it: Linux's `URLProtocol` is explicitly not
// `Sendable`, so there it conforms to nothing. The stub's own state is behind its lock.
extension ZoteroRetryWaitTests.StubURLProtocol: @unchecked Sendable {}
#endif
