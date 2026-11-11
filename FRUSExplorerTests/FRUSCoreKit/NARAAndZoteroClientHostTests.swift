// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
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

// MARK: - NARAAndZoteroClientHostTests

/// The two web clients as a host drives them (FRUS Explorer Light's S22c): the NARA client reading its
/// key from a `NARACatalogKeyProvider` of the host's own and telling it of each answered call, and the
/// Zotero client resolving a key, each over a `URLSession` whose answers a stub gives, so that no test
/// reaches the network and the package runs the requests through Linux's FoundationNetworking too.
///
/// The stub keeps no state: it answers from the request alone (the key it carries), so the suites that
/// run beside each other cannot see each other's requests.
///
/// Version history:
///   1.0 — 2026-11-11: FRUS Explorer Light's S22c, with the clients' move into FRUSCoreKit
@Suite("NARA and Zotero clients — as a host drives them")
struct NARAAndZoteroClientHostTests {

    /// A host's provider: one key, and a count of the calls it was told of.
    actor CountingKeyProvider: NARACatalogKeyProvider {
        let key: String?
        private(set) var answeredCalls = 0
        init(key: String?) { self.key = key }
        func naraCatalogAPIKey() async throws -> String? { key }
        func recordNARACatalogAPICall() async { answeredCalls += 1 }
    }

    /// A provider that keeps no count: the protocol's own `recordNARACatalogAPICall()` serves it.
    struct FixedKeyProvider: NARACatalogKeyProvider {
        let key: String?
        func naraCatalogAPIKey() async throws -> String? { key }
    }

    struct ProviderFailure: Error, Equatable {}

    /// A provider whose key store fails, as the Keychain can.
    struct FailingKeyProvider: NARACatalogKeyProvider {
        func naraCatalogAPIKey() async throws -> String? { throw ProviderFailure() }
    }

    /// Answers the NARA Catalog and the Zotero API from the request alone: the NARA key `accepted`
    /// gets one series, any other key a 403; the Zotero key `writer` gets an account that can write
    /// notes, `reader` one that cannot, and any other a 403.
    final class StubURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            let (status, body) = Self.answer(to: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        static func answer(to request: URLRequest) -> (Int, String) {
            let url = request.url!
            if url.host == "catalog.archives.gov" {
                guard request.value(forHTTPHeaderField: "x-api-key") == "accepted" else { return (403, "{}") }
                return (200, """
                    {"opaResponse": {"results": {"result": [{"naId": "1240", "title": "Central Decimal Files",
                     "recordGroupNumber": 59, "levelOfDescription": "series"}]}}}
                    """)
            }
            if url.host == "api.zotero.org", url.path.hasPrefix("/keys/") {
                switch url.lastPathComponent {
                case "writer":
                    return (200, #"{"userID": 4210, "username": "frus", "access": {"user": {"library": true, "write": true, "notes": true}}}"#)
                case "reader":
                    return (200, #"{"userID": 4211, "username": "frus2", "access": {"user": {"library": true, "write": false}}}"#)
                default:
                    return (403, "{}")
                }
            }
            return (404, "{}")
        }
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // MARK: - NARA: the key provider

    @Test("A provider with no key, or an empty one, refuses every search before any request")
    func noKeyIsMissing() async throws {
        for key in [nil, ""] as [String?] {
            let provider = CountingKeyProvider(key: key)
            let client = NARACatalogClient(keyProvider: provider, urlSession: Self.stubbedSession())
            // `hasAPIKey()` asks whether the provider returns a key at all, as it asked the Keychain:
            // an empty key is a key there, and the search refuses it.
            #expect(await client.hasAPIKey() == (key != nil))
            do {
                _ = try await client.searchByRecordGroup("59", keywords: "decimal", maxResults: 1)
                Issue.record("a search without a key ran")
            } catch NARACatalogError.missingAPIKey {
            } catch {
                Issue.record("expected missingAPIKey, got \(error)")
            }
            #expect(await provider.answeredCalls == 0)
        }
    }

    @Test("The provider's key goes in x-api-key, and each answered call is told to the provider")
    func keyIsSentAndCallsAreCounted() async throws {
        let provider = CountingKeyProvider(key: "accepted")
        let client = NARACatalogClient(keyProvider: provider, urlSession: Self.stubbedSession())
        #expect(await client.hasAPIKey())
        let results = try await client.searchByRecordGroup("59", keywords: "decimal", maxResults: 1)
        #expect(results.map(\.naId) == ["1240"])
        #expect(results.first?.recordGroupNumber == "59")
        #expect(results.first?.catalogURL.absoluteString == "https://catalog.archives.gov/id/1240")
        #expect(await provider.answeredCalls == 1)
        _ = try await client.searchByRecordGroup("59", keywords: "decimal", maxResults: 1)
        #expect(await provider.answeredCalls == 2)
    }

    @Test("A rejected key is the client's 403, and a refused call is not counted")
    func rejectedKeyIsNotCounted() async throws {
        let provider = CountingKeyProvider(key: "refused")
        let client = NARACatalogClient(keyProvider: provider, urlSession: Self.stubbedSession())
        do {
            _ = try await client.searchByRecordGroup("59", keywords: "decimal", maxResults: 1)
            Issue.record("a rejected key answered")
        } catch NARACatalogError.apiKeyRejected {
        } catch {
            Issue.record("expected apiKeyRejected, got \(error)")
        }
        #expect(await provider.answeredCalls == 0)
    }

    @Test("A provider that counts nothing needs no method of its own, and a failing provider's error reaches the caller")
    func defaultRecordAndFailingProvider() async throws {
        let quiet = NARACatalogClient(keyProvider: FixedKeyProvider(key: "accepted"), urlSession: Self.stubbedSession())
        #expect(try await quiet.searchByRecordGroup("59", keywords: "decimal", maxResults: 1).count == 1)

        let failing = NARACatalogClient(keyProvider: FailingKeyProvider(), urlSession: Self.stubbedSession())
        #expect(await failing.hasAPIKey() == false)
        await #expect(throws: ProviderFailure.self) {
            _ = try await failing.searchByRecordGroup("59", keywords: "decimal", maxResults: 1)
        }
    }

    // MARK: - Zotero

    @Test("The Zotero client resolves a key's account, and refuses one that cannot write notes or is rejected")
    func zoteroResolvesAccounts() async throws {
        let client = ZoteroAPIClient(session: Self.stubbedSession())
        let info = try await client.resolveAccount(key: "writer")
        #expect(info.userID == 4210)
        #expect(info.username == "frus")
        #expect(info.canWriteNotes)
        for (key, expected) in [("reader", "insufficientPermissions"), ("unknown", "invalidKey")] {
            do {
                _ = try await client.resolveAccount(key: key)
                Issue.record("\(key) resolved")
            } catch let error as ZoteroAPIError {
                switch (error, expected) {
                case (.insufficientPermissions, "insufficientPermissions"), (.invalidKey, "invalidKey"): break
                default: Issue.record("\(key): expected \(expected), got \(error)")
                }
                #expect(error.errorDescription?.isEmpty == false)
            }
        }
    }

    @Test("Sending nothing makes no request and adds nothing")
    func zoteroSendsNothingForNoItems() async throws {
        let client = ZoteroAPIClient(session: Self.stubbedSession())
        let result = try await client.send(items: [], collectionName: "FRUS", apiKey: "writer",
                                           userID: 4210, username: "frus")
        #expect(result.addedItems == 0 && result.failedItems == 0 && result.addedNotes == 0)
        #expect(result.collectionKey == nil && result.webURL == nil)
    }
}

#if !canImport(FoundationNetworking)
// As the app's other stubs declare theirs (`StubShardProtocol`, `StubVolumeListing`): the stub keeps no
// state. Linux's `URLProtocol` is explicitly not `Sendable`, so there it conforms to nothing.
extension NARAAndZoteroClientHostTests.StubURLProtocol: @unchecked Sendable {}
#endif
