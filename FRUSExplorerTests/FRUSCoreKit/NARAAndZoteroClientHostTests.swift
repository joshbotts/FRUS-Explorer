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
///   1.1 — 2026-11-16: `NARALiveRecordGroupTests`, over NARA's live answer for Lot 63 D 351 (#1908)
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

// MARK: - NARALiveRecordGroupTests

/// Where NARA's live answers put a record's record group, and what the client makes of them (#1908, the plan
/// of record's row N1).
///
/// `liveAnswer` is NARA's answer for series 2839192, the S/S–NSC Files (Lot 63 D 351), read on 2026-11-16
/// and re-indented, nothing else changed. It holds no key and no header. It was read through the Catalog
/// website's own search (`catalog.archives.gov/proxy/records/search?naId=2839192`), because that day
/// `/api/v2/records/search` answered every request, keyed or not, with the website's HTML page and HTTP 200
/// (`x-cache: Error from cloudfront`). The two serve one index in one shape, `body.hits.hits[]._source.record`,
/// which the generators' harvest client reads from `/api/v2` (`NARACatalogHarvestClient`). The record carries
/// no `recordGroupNumber`; its `ancestors` member at `recordGroup` level carries `59`, a number.
///
/// Version history:
///   1.0 — 2026-11-16: #1908
@Suite("NARA's live record group — on the ancestor (#1908)")
struct NARALiveRecordGroupTests {

    static let liveAnswer = #"""
        {
         "body": {
          "hits": {
           "total": {
            "value": 1,
            "relation": "eq"
           },
           "max_score": null,
           "hits": [
            {
             "_index": "nac-records4",
             "_id": "2839192",
             "_score": 3,
             "_source": {
              "metadata": {
               "fileName": "NAC_ADHOC_2026-02-17_DESC_0127.xml",
               "controlGroup": {
                "indexName": "records",
                "type": "recordGroup",
                "naId": 388
               },
               "ingestTime": "2026-02-18 11:44:41.671110",
               "uuid": "afdf2611-c409-4a1a-982b-ec10e9281ead"
              },
              "record": {
               "accessionNumbers": [
                "NN3-59-91-23"
               ],
               "inclusiveStartDate": {
                "year": 1947,
                "logicalDate": "1947-01-01"
               },
               "levelOfDescription": "series",
               "creators": [
                {
                 "creatorType": "Most Recent",
                 "heading": "Department of State. Office of the Secretary. Executive Secretariat. (1964 - )",
                 "authorityType": "organization",
                 "establishDate": {
                  "year": 1964,
                  "logicalDate": "1964-01-01"
                 },
                 "naId": 10448887
                }
               ],
               "recordType": "description",
               "inclusiveEndDate": {
                "year": 1979,
                "logicalDate": "1979-12-31"
               },
               "useRestriction": {
                "note": "Some of the records in this series may be subject to copyright restrictions. Researchers should contact the publisher for more information.",
                "specificUseRestrictions": [
                 "Copyright"
                ],
                "status": "Restricted - Possibly"
               },
               "audiovisual": "false",
               "fileUnitCount": 448,
               "title": "Records Relating to National Security Council Policy Papers",
               "physicalOccurrences": [
                {
                 "extent": "26 linear feet, 3 linear inches",
                 "referenceUnits": [
                  {
                   "address2": "8601 Adelphi Road",
                   "city": "College Park",
                   "phone": "301-837-3510",
                   "address1": "National Archives at College Park",
                   "postalCode": "20740-6001",
                   "name": "National Archives at College Park - Textual Reference",
                   "state": "MD",
                   "fax": "301-837-1752",
                   "email": "Archives2reference@nara.gov"
                  }
                 ],
                 "mediaOccurrences": [
                  {
                   "specificMediaType": "Paper"
                  }
                 ],
                 "holdingsMeasurements": [
                  {
                   "count": 60,
                   "type": "Legal Archives Box, Standard"
                  }
                 ],
                 "copyStatus": "Preservation-Reproduction-Reference"
                }
               ],
               "accessRestriction": {
                "note": "This series has undergone a comprehensive declassification review and most documents have been declassified. A few individual documents within the series remain classified and unavailable for research. Withdrawal sheets giving information necessary for mandatory declassification review requests have replaced the few documents that could not be declassified at the time of the comprehensive review.",
                "specificAccessRestrictions": [
                 {
                  "securityClassification": "Secret",
                  "restriction": "FOIA (b)(1) National Security"
                 }
                ],
                "status": "Restricted - Partly"
               },
               "arrangement": "Arranged by Department of State Lot file number and thereunder in two parts. Part one is arranged numerically by National Security Council document number. Part two is roughly arranged numerically by National Security Council document number.",
               "dataControlGroup": {
                "groupName": "National Archives at College Park \u2013 Textual Reference",
                "groupId": "RRAR",
                "groupCd": "RRAR"
               },
               "generalRecordsTypes": [
                "Textual Records",
                "Maps and Charts"
               ],
               "variantControlNumbers": [
                {
                 "number": "A1 1586",
                 "type": "Former HMS/MLR Entry Number"
                },
                {
                 "number": "NND 959297",
                 "type": "Declassification Project Number"
                },
                {
                 "number": "A1 1586E",
                 "type": "HMS/MLR Entry Number"
                },
                {
                 "note": "This is a Department of State LOT file number.",
                 "number": "63D351",
                 "type": "Agency-Assigned Identifier"
                },
                {
                 "number": "NND 959008",
                 "type": "Declassification Project Number"
                },
                {
                 "note": "This is a Department of State LOT file number.",
                 "number": "66D95",
                 "type": "Agency-Assigned Identifier"
                },
                {
                 "number": "NND 965070",
                 "type": "Declassification Project Number"
                }
               ],
               "otherTitles": [
                "Records Relating to Participation in the Operations Coordinating Board and the National Security Council",
                "Records Relating to Policy Papers",
                "Records Relating to State Department Participation in the Operations Coordination Board and the National Security Council"
               ],
               "ancestors": [
                {
                 "inclusiveStartDate": {
                  "year": 1763,
                  "logicalDate": "1763-01-01"
                 },
                 "distance": 1,
                 "levelOfDescription": "recordGroup",
                 "recordGroupNumber": 59,
                 "inclusiveEndDate": {
                  "year": 2002,
                  "logicalDate": "2002-12-31"
                 },
                 "title": "General Records of the Department of State",
                 "naId": 388
                }
               ],
               "scopeAndContentNote": "This series includes memorandums, briefing materials, correspondence, notes, drafts, policy papers, maps, and reports relating to the Department of State's input and comments on National Security Council policy papers. Subjects covered include national security, policies towards other countries, nuclear energy, U.S. positions of worldwide issues, military aid, communism, international trade, military manpower, communication issues, construction projects, defense issues, outer space, and other issues reviewed by the National Security Council.  The records were maintained by the Executive Secretariat.",
               "naId": 2839192
              }
             },
             "sort": [
              3,
              "2839192"
             ]
            }
           ]
          },
          "aggregations": {
           "typeOfMaterials": {
            "doc_count_error_upper_bound": 0,
            "sum_other_doc_count": 0,
            "buckets": [
             {
              "key": "Maps and Charts",
              "doc_count": 1
             },
             {
              "key": "Textual Records",
              "doc_count": 1
             }
            ]
           },
           "collectionIdentifier": {
            "doc_count": 1,
            "filter_collections": {
             "doc_count": 0,
             "collections": {
              "doc_count_error_upper_bound": 0,
              "sum_other_doc_count": 0,
              "buckets": []
             }
            }
           },
           "referenceUnits": {
            "doc_count_error_upper_bound": 0,
            "sum_other_doc_count": 0,
            "buckets": [
             {
              "key": "National Archives at College Park - Textual Reference",
              "doc_count": 1
             }
            ]
           },
           "recordGroupNumber": {
            "doc_count": 1,
            "filter_recordGroups": {
             "doc_count": 1,
             "recordGroups": {
              "doc_count_error_upper_bound": 0,
              "sum_other_doc_count": 0,
              "buckets": [
               {
                "key": "59: General Records of the Department of State",
                "doc_count": 1
               }
              ]
             }
            }
           },
           "levelOfDescription": {
            "doc_count_error_upper_bound": 0,
            "sum_other_doc_count": 0,
            "buckets": [
             {
              "key": "series",
              "doc_count": 1
             }
            ]
           },
           "availableOnline": {
            "doc_count": 0
           },
           "dataSource": {
            "doc_count_error_upper_bound": 0,
            "sum_other_doc_count": 0,
            "buckets": [
             {
              "key": "description",
              "doc_count": 1
             }
            ]
           },
           "localIdentifierCount": {
            "doc_count": 0
           },
           "objectType": {
            "doc_count_error_upper_bound": 0,
            "sum_other_doc_count": 0,
            "buckets": []
           }
          }
         },
         "statusCode": 200,
         "headers": {
          "date": "Mon, 16 Nov 2026 19:42:39 GMT",
          "content-type": "application/json; charset=UTF-8",
          "content-length": "5667",
          "connection": "keep-alive",
          "access-control-allow-origin": "*"
         }
        }
        """#

    /// The one record in `liveAnswer`, as `JSONSerialization` decodes it.
    static func liveRecord() throws -> [String: Any] {
        let json = try #require(try JSONSerialization.jsonObject(with: Data(liveAnswer.utf8)) as? [String: Any])
        let body = try #require(json["body"] as? [String: Any])
        let hits = try #require((body["hits"] as? [String: Any])?["hits"] as? [[String: Any]])
        let source = try #require(hits.first?["_source"] as? [String: Any])
        return try #require(source["record"] as? [String: Any])
    }

    /// Answers every request with `liveAnswer`, or, for the key `cdn-error`, the HTML page NARA's CDN served.
    final class LiveAnswerProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            let cdnError = request.value(forHTTPHeaderField: "x-api-key") == "cdn-error"
            let body = cdnError
                ? "<!doctype html><html lang=\"en\"><head><title>National Archives Catalog</title></head><body></body></html>"
                : NARALiveRecordGroupTests.liveAnswer
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": cdnError ? "text/html" : "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    static func client(key: String) -> (NARACatalogClient, NARAAndZoteroClientHostTests.CountingKeyProvider) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LiveAnswerProtocol.self]
        let provider = NARAAndZoteroClientHostTests.CountingKeyProvider(key: key)
        return (NARACatalogClient(keyProvider: provider, urlSession: URLSession(configuration: configuration)), provider)
    }

    @Test("The live answer's record group is on its recordGroup ancestor alone, and the client reads it there")
    func liveShapeReadsTheAncestor() throws {
        let record = try Self.liveRecord()
        #expect(record["recordGroupNumber"] == nil)
        #expect(record["description"] == nil)
        let result = try #require(NARACatalogClient.buildResult(from: record))
        #expect(result.naId == "2839192")
        #expect(result.recordGroupNumber == "59")
        #expect(result.levelOfDescription == "series")
        #expect(result.variantControlNumbers.contains("63D351"))
        #expect(NARACatalogClient.firstAcceptable([result], recordGroup: "59", lotNumber: "63D351")?.naId == "2839192")
        #expect(NARACatalogClient.firstAcceptable([result], recordGroup: "84", lotNumber: "63D351") == nil)
    }

    @Test("A lot lookup over the live answer resolves the series, and the answered call is counted")
    func lotLookupResolves() async throws {
        let (client, provider) = Self.client(key: "accepted")
        let results = try await client.resolveLotFileVariants(lotNumber: "63 D 351", recordGroup: "59")
        #expect(results.map(\.naId) == ["2839192"])
        #expect(await provider.answeredCalls == 1)
    }

    @Test("A record with no record group of its own or at its recordGroup ancestor still reads nil, and is refused (#321)")
    func noRecordGroupIsRefused() throws {
        var record = try Self.liveRecord()
        record["ancestors"] = nil
        let bare = try #require(NARACatalogClient.buildResult(from: record))
        #expect(bare.recordGroupNumber == nil)
        #expect(NARACatalogClient.firstAcceptable([bare], recordGroup: "59", lotNumber: "63D351") == nil)

        // An ancestor at another level is not the record group, whatever it carries.
        record["ancestors"] = [["naId": 1, "levelOfDescription": "series", "recordGroupNumber": 59]]
        #expect(NARACatalogClient.buildResult(from: record)?.recordGroupNumber == nil)
        // A recordGroup ancestor without the number gives none.
        record["ancestors"] = [["naId": 388, "levelOfDescription": "recordGroup"]]
        #expect(NARACatalogClient.buildResult(from: record)?.recordGroupNumber == nil)
    }

    @Test("A record's own record group, or its description's, is read before the ancestor's")
    func ownFieldsComeFirst() throws {
        var record = try Self.liveRecord()
        record["recordGroupNumber"] = 84
        #expect(NARACatalogClient.buildResult(from: record)?.recordGroupNumber == "84")
        record["recordGroupNumber"] = nil
        record["description"] = ["recordGroupNumber": "84"]
        #expect(NARACatalogClient.buildResult(from: record)?.recordGroupNumber == "84")
        // An ancestors list inside the description is read too.
        let ancestors = try #require(record["ancestors"])
        record["ancestors"] = nil
        record["description"] = ["ancestors": ancestors]
        #expect(NARACatalogClient.buildResult(from: record)?.recordGroupNumber == "59")
    }

    @Test("The live answer's scope note is the record's own, and the client reads it (#1970)")
    func liveShapeReadsTheScopeNote() throws {
        let record = try Self.liveRecord()
        #expect(record["scopeAndContentNote"] is String, "fixture guard: the live record carries its note")
        #expect(record["scopeContent"] == nil && record["description"] == nil,
                "fixture guard: neither shape the client read before")
        let note = try #require(NARACatalogClient.buildResult(from: record)?.scopeNote)
        #expect(note.hasPrefix("This series includes memorandums, briefing materials"), "\(note.prefix(60))")
    }

    @Test("The two older shapes still give their notes, the record's own first; none, or an empty one, gives nil")
    func olderScopeNoteShapesAndNone() throws {
        var record = try Self.liveRecord()
        let live = try #require(record["scopeAndContentNote"] as? String)
        record["scopeContent"] = "An older note."
        record["description"] = ["scopeAndContentNote": "A description's note."]
        #expect(NARACatalogClient.buildResult(from: record)?.scopeNote == live, "the record's own note comes first")
        record["scopeAndContentNote"] = nil
        #expect(NARACatalogClient.buildResult(from: record)?.scopeNote == "An older note.")
        record["scopeContent"] = nil
        #expect(NARACatalogClient.buildResult(from: record)?.scopeNote == "A description's note.")
        record["description"] = nil
        #expect(NARACatalogClient.buildResult(from: record)?.scopeNote == nil)
        for empty in ["", "  "] {
            record["scopeAndContentNote"] = empty
            record["scopeContent"] = empty
            #expect(NARACatalogClient.buildResult(from: record)?.scopeNote == nil, "an empty note reads as none")
        }
    }

    @Test("An HTTP 200 HTML page is the client's decodingError, not an empty answer, and is not counted")
    func htmlPageIsAnError() async throws {
        let (client, provider) = Self.client(key: "cdn-error")
        do {
            _ = try await client.resolveLotFileVariants(lotNumber: "63 D 351", recordGroup: "59")
            Issue.record("an HTML page read as an answer")
        } catch NARACatalogError.decodingError {
        } catch {
            Issue.record("expected decodingError, got \(error)")
        }
        #expect(await provider.answeredCalls == 0)
        #expect(throws: NARACatalogError.self) { _ = try NARACatalogClient.decodeResults(from: Data("<!doctype html>".utf8)) }
        // A JSON object of a shape the client does not know still reads as no records.
        #expect(try NARACatalogClient.decodeResults(from: Data(#"{"error": {"id": "422"}}"#.utf8)).isEmpty)
    }
}

#if !canImport(FoundationNetworking)
// As the app's other stubs declare theirs (`StubShardProtocol`, `StubVolumeListing`): the stub keeps no
// state. Linux's `URLProtocol` is explicitly not `Sendable`, so there it conforms to nothing.
extension NARAAndZoteroClientHostTests.StubURLProtocol: @unchecked Sendable {}
extension NARALiveRecordGroupTests.LiveAnswerProtocol: @unchecked Sendable {}
#endif
