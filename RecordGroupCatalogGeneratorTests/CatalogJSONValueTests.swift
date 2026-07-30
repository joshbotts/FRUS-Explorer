// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import RecordGroupCatalogGeneratorCore

/// Tests the `Sendable` JSON tree and its value coercions.
///
/// Every coercion here exists because NARA's export actually ships the awkward form — the fixtures
/// quote real values measured from the bulk export on 2026-07-29, not invented edge cases.
struct CatalogJSONValueTests {

    private func decode(_ json: String) throws -> CatalogJSONValue {
        try JSONDecoder().decode(CatalogJSONValue.self, from: Data(json.utf8))
    }

    @Test("Decodes every JSON kind, preferring Int over Double for whole numbers")
    func decodesKinds() throws {
        let value = try decode("""
        {"s":"x","i":7,"d":1.5,"b":true,"n":null,"a":[1,2],"o":{"k":"v"}}
        """)
        #expect(value["s"] == .string("x"))
        #expect(value["i"] == .int(7))
        #expect(value["d"] == .double(1.5))
        #expect(value["b"] == .bool(true))
        #expect(value["a"] == .array([.int(1), .int(2)]))
        #expect(value["o"] == .object(["k": .string("v")]))
        // An explicit null reads as absent through the subscript…
        #expect(value["n"] == nil)
        // …but the census still needs to know the key was there.
        #expect(value.hasKey("n"))
        #expect(!value.hasKey("missing"))
    }

    @Test("audiovisual is a quoted string of varying case — all four spellings coerce")
    func coercesQuotedBooleans() throws {
        // "false" measured in RG 486; "True" appears in NARA's own published API example. A literal
        // == "true" test would silently read one of the two as nil.
        for (raw, expected) in [("\"false\"", false), ("\"False\"", false),
                                ("\"true\"", true), ("\"True\"", true)] {
            let value = try decode("{\"audiovisual\":\(raw)}")
            #expect(value["audiovisual"]?.boolValue == expected, "spelling \(raw)")
        }
        let realBool = try decode("{\"a\":true}")
        #expect(realBool["a"]?.boolValue == true)
        let notABool = try decode("{\"a\":\"maybe\"}")
        #expect(notABool["a"]?.boolValue == nil)
    }

    @Test("naId stringifies identically whether it arrives as a number or a string")
    func stringifiesNaId() throws {
        let numericNaId = try decode("{\"naId\":1933760}")
        #expect(numericNaId["naId"]?.stringValue == "1933760")
        let stringNaId = try decode("{\"naId\":\"1933760\"}")
        #expect(stringNaId["naId"]?.stringValue == "1933760")
        // An integral double must not become "1933760.0" — that would fail to match its integer form.
        #expect(CatalogJSONValue.double(1933760).stringValue == "1933760")
        #expect(CatalogJSONValue.double(1.5).stringValue == "1.5")
    }

    @Test("holdingsMeasurements.count is a Double even when it counts discrete boxes")
    func coercesIntegralDoubles() throws {
        let value = try decode("{\"count\":13.0}")
        #expect(value["count"]?.doubleValue == 13.0)
        #expect(value["count"]?.intValue == 13)
        // A genuinely fractional value must not silently truncate to an Int.
        let fractional = try decode("{\"count\":13.5}")
        #expect(fractional["count"]?.intValue == nil)
    }

    @Test("nonEmptyString trims and rejects blanks")
    func trimsStrings() throws {
        let value = try decode("{\"a\":\"  padded  \",\"b\":\"   \",\"c\":\"\"}")
        #expect(value["a"]?.nonEmptyString == "padded")
        #expect(value["b"]?.nonEmptyString == nil)
        #expect(value["c"]?.nonEmptyString == nil)
    }

    @Test("asArray normalises arity so an object-where-array change cannot empty a field")
    func normalisesArity() throws {
        let realArray = try decode("{\"a\":[1,2]}")
        #expect(realArray["a"]?.asArray.count == 2)
        // A lone object becomes a one-element list rather than nothing.
        let loneObject = try decode("{\"a\":{\"k\":1}}")
        #expect(loneObject["a"]?.asArray.count == 1)
        #expect(CatalogJSONValue.null.asArray.isEmpty)
    }

    @Test("Round-trips through re-encoding, which the raw NDJSON store depends on")
    func roundTrips() throws {
        let json = """
        {"a":[1,2.5,"x",true,null],"o":{"nested":{"deep":1}}}
        """
        let decoded = try decode(json)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let reencoded = try encoder.encode(decoded)
        let roundTripped = try JSONDecoder().decode(CatalogJSONValue.self, from: reencoded)
        #expect(roundTripped == decoded)
    }

    @Test("Unwraps both the bulk-export and API envelopes, and a bare record")
    func unwrapsEnvelopes() throws {
        // Bulk export: every line is {"record": {…}}.
        let bulk = try CatalogJSONValue.decodeRecordLine(Data("""
        {"record":{"naId":1,"title":"T"}}
        """.utf8))
        #expect(bulk?["title"]?.stringValue == "T")

        // Live API: the same object at _source.record.
        let api = try CatalogJSONValue.decodeRecordLine(Data("""
        {"_source":{"record":{"naId":2,"title":"U"}}}
        """.utf8))
        #expect(api?["title"]?.stringValue == "U")

        // A bare record is accepted so re-projection over hand-edited NDJSON works.
        let bare = try CatalogJSONValue.decodeRecordLine(Data("""
        {"naId":3,"title":"V"}
        """.utf8))
        #expect(bare?["title"]?.stringValue == "V")

        // Valid JSON that is not an object yields nil rather than throwing.
        let nonObject = try CatalogJSONValue.decodeRecordLine(Data("[1,2]".utf8))
        #expect(nonObject == nil)
        let empty = try CatalogJSONValue.decodeRecordLine(Data())
        #expect(empty == nil)
    }
}

/// Tests the NDJSON line splitter.
struct NDJSONSplittingTests {

    private func records(_ text: String) throws -> [CatalogJSONValue] {
        var out: [CatalogJSONValue] = []
        try CatalogBulkExportClient.forEachRecord(inNDJSON: Data(text.utf8)) { out.append($0) }
        return out
    }

    @Test("Splits lines with and without a trailing newline")
    func splitsLines() throws {
        let body = """
        {"record":{"naId":1,"title":"A"}}
        {"record":{"naId":2,"title":"B"}}
        """
        let withoutTrailing = try records(body)
        #expect(withoutTrailing.count == 2)
        let withTrailing = try records(body + "\n")
        #expect(withTrailing.count == 2)
    }

    @Test("Tolerates CRLF and blank lines")
    func tolerantOfLineEndings() throws {
        let body = "{\"record\":{\"naId\":1,\"title\":\"A\"}}\r\n\r\n{\"record\":{\"naId\":2,\"title\":\"B\"}}\r\n"
        let parsed = try records(body)
        #expect(parsed.count == 2)
        #expect(parsed[1]["title"]?.stringValue == "B")
    }

    @Test("A malformed line is reported and skipped, never fatal to the shard")
    func reportsMalformedLines() throws {
        // One bad line in a 17 GB record group must not cost the whole harvest — but it must be
        // counted, so a run that skipped 40,000 lines cannot pass for a clean one.
        let body = """
        {"record":{"naId":1,"title":"A"}}
        {this is not json
        {"record":{"naId":2,"title":"B"}}
        """
        var good: [CatalogJSONValue] = []
        var failures: [Int] = []
        try CatalogBulkExportClient.forEachRecord(
            inNDJSON: Data(body.utf8),
            onMalformedLine: { line, _ in failures.append(line) },
            body: { good.append($0) })
        #expect(good.count == 2)
        #expect(failures == [2])
    }
}
