// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import CentralFilesIndexGeneratorCore

/// Tests that the v2 search response decoder matches NARA's real response shape
/// (`body.hits.hits[]._source.record`, cursor in `sort[0]`), as used by NARA's own
/// bulk-download scripts.
struct CatalogResponseDecodeTests {

    /// A page shaped like the real API: `naId` as a number, cursor as a number.
    private let pageJSON = """
    {
      "statusCode": 200,
      "body": {
        "hits": {
          "hits": [
            {
              "_source": { "record": { "naId": 19779414, "title": "Numerical File: 7179-7187" } },
              "sort": [ 19779414 ]
            },
            {
              "_source": { "record": { "naId": "19174810", "title": "Numerical File: 682-699" } },
              "sort": [ "abc123" ]
            }
          ]
        }
      }
    }
    """

    @Test("Decodes records with numeric or string naId and a cursor")
    func decodesPage() throws {
        let data = Data(pageJSON.utf8)
        let page = try NARACatalogHarvestClient.decodePage(data)

        #expect(page.records.count == 2)
        #expect(page.records[0] == CatalogRecord(naId: "19779414", title: "Numerical File: 7179-7187"))
        #expect(page.records[1].naId == "19174810")
        // Cursor is the last hit's sort[0], stringified.
        #expect(page.nextCursor == "abc123")
    }

    @Test("Empty hits list yields no records and no cursor (end of pagination)")
    func decodesEmptyPage() throws {
        let json = #"{ "statusCode": 200, "body": { "hits": { "hits": [] } } }"#
        let page = try NARACatalogHarvestClient.decodePage(Data(json.utf8))
        #expect(page.records.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("Drops records missing naId or title")
    func dropsIncompleteRecords() throws {
        let json = """
        { "statusCode": 200, "body": { "hits": { "hits": [
          { "_source": { "record": { "title": "Numerical File: 1-9" } }, "sort": [1] },
          { "_source": { "record": { "naId": 42 } }, "sort": [2] },
          { "_source": { "record": { "naId": 7, "title": "Numerical File: 10-19" } }, "sort": [3] }
        ] } } }
        """
        let page = try NARACatalogHarvestClient.decodePage(Data(json.utf8))
        #expect(page.records.count == 1)
        #expect(page.records[0].naId == "7")
    }

    @Test("Throws on a non-2xx API statusCode")
    func throwsOnAPIError() {
        let json = #"{ "statusCode": 429, "body": { "hits": { "hits": [] } } }"#
        #expect(throws: NARACatalogHarvestError.self) {
            _ = try NARACatalogHarvestClient.decodePage(Data(json.utf8))
        }
    }
}
