// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import LotClaimantsIndexGeneratorCore

// MARK: - HarvestShardStreamingTests

/// Pins `HarvestShardReader.forEachRecord` — the byte-level walk added for #372 item 1b so a pass
/// over all 22 record-group shards fits in memory.
///
/// ## Why a second read path exists at all
/// `read(_:)` decodes a shard's whole `records` array in one `JSONDecoder` call. Measured on
/// `rg_59.json` (3.5 GB, 240,929 records) that peaks at **7.01 GB resident** — survivable on a
/// large machine, fatal on a 16 GB one. The supplement pass has to visit every shard, so the
/// streaming walk was a prerequisite rather than an optimisation.
///
/// ## What these tests are defending
/// A hand-rolled JSON scan is exactly the kind of code that works on the happy path and corrupts
/// quietly on real data. Every case below is a shape the 4.5 GB harvest actually contains, and
/// the parity test is the point: the streaming path must agree with `read(_:)` record for record,
/// because `read(_:)` is `JSONDecoder` and therefore right by definition.
///
/// The naive implementations these kill: searching for the next `}` (dies on a title containing a
/// brace), tracking depth without string awareness (same), and honouring `\` escapes wrongly (a
/// title ending `…\\"` either swallows the record or ends it early).
///
/// Version history:
///   1.0 — Session 2026-08-19: #372 item 1b
@Suite("HarvestShardReader — the streaming walk")
struct HarvestShardStreamingTests {

    /// One record in the shard's real wire shape, with the nesting the walk has to survive.
    private func record(naId: String, title: String, level: String = "series",
                        rg: Int? = 59, controls: [String] = [],
                        extra: String = "") -> String {
        let variants = controls.map {
            #"{"number":"\#($0)","type":"State Department Lot File Number","note":null}"#
        }.joined(separator: ",")
        let rgClause = rg.map { #""recordGroupNumber":\#($0),"# } ?? ""
        return """
        {"naId":"\(naId)","title":\(quoted(title)),"levelOfDescription":"\(level)",
         \(rgClause)"variantControlNumbers":[\(variants)],
         "ancestors":[{"recordGroupNumber":\(rg.map(String.init) ?? "null")}],
         "physicalOccurrences":[{"extent":"1 linear foot","referenceUnitNames":["NWCTB"]}],
         "inclusiveStartDate":{"year":1950},"inclusiveEndDate":{"year":1955}\(extra)}
        """
    }

    /// JSON-quotes a Swift string, so a test fixture cannot itself be the thing that is wrong.
    private func quoted(_ s: String) -> String {
        String(decoding: try! JSONEncoder().encode(s), as: UTF8.self)
    }

    private func shard(_ records: [String], generated: String? = "2026-07-30",
                       generatedLast: Bool = false) -> String {
        let stamp = generated.map { #""generated":"\#($0)""# }
        let head = generatedLast ? #""depth":"series""# : [#""depth":"series""#, stamp]
            .compactMap { $0 }.joined(separator: ",")
        let tail = generatedLast ? (stamp.map { "," + $0 } ?? "") : ""
        return "{\(head),\"records\":[\(records.joined(separator: ","))]\(tail)}"
    }

    /// Writes a fixture and returns both read paths' results for comparison.
    private func bothPaths(_ json: String) throws
        -> (streamed: [HarvestShardReader.Record], whole: [HarvestShardReader.Record],
            streamedStamp: String?, wholeStamp: String?) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shard-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var streamed: [HarvestShardReader.Record] = []
        let streamedStamp = try HarvestShardReader.forEachRecord(url) { streamed.append($0) }
        let (whole, wholeStamp) = try HarvestShardReader.read(url)
        return (streamed, whole, streamedStamp, wholeStamp)
    }

    private func assertParity(_ json: String, expecting count: Int,
                              _ note: Comment? = nil) throws {
        let r = try bothPaths(json)
        #expect(r.whole.count == count, "fixture guard: the whole-array path must see \(count)")
        #expect(r.streamed.count == r.whole.count, note ?? "record count diverged")
        #expect(r.streamed.map(\.naId) == r.whole.map(\.naId), "order or identity diverged")
        #expect(r.streamed.map(\.title) == r.whole.map(\.title), "titles diverged")
        #expect(r.streamed.map(\.variantControlNumbers) == r.whole.map(\.variantControlNumbers))
        #expect(r.streamed.map(\.recordGroupNumber) == r.whole.map(\.recordGroupNumber))
        #expect(r.streamed.map(\.levelOfDescription) == r.whole.map(\.levelOfDescription))
        #expect(r.streamedStamp == r.wholeStamp, "the generated stamp diverged")
    }

    // MARK: - Parity

    @Test("A plain multi-record shard streams identically to the whole-array read")
    func plainShardIsAtParity() throws {
        try assertParity(shard([
            record(naId: "1", title: "Conference Files", controls: ["60D627"]),
            record(naId: "2", title: "Subject Files", controls: ["74D267", "1980D0135"]),
            record(naId: "3", title: "Records Relating to Paraguay"),
        ]), expecting: 3)
    }

    /// The reason the walk is brace-aware. NARA titles really do carry brackets — and a scan for
    /// the next `}` ends this record 30 bytes early, then decodes the remainder as the next one.
    @Test("A title containing braces and brackets does not end the record early")
    func bracesInTitlesSurvive() throws {
        try assertParity(shard([
            record(naId: "1", title: "Case files {restricted} [see also RG 84]", controls: ["61D385"]),
            record(naId: "2", title: "}{][", controls: ["59D95"]),
            record(naId: "3", title: "Files of the Under Secretary"),
        ]), expecting: 3, "a brace inside a string was treated as structure")
    }

    /// The reason the walk honours `\`. A title ending in an escaped quote is the case where a
    /// naive scanner flips its in-string state and then reads the rest of the shard as one record.
    @Test("Escaped quotes and backslashes inside titles do not desynchronise the scan")
    func escapesSurvive() throws {
        try assertParity(shard([
            record(naId: "1", title: #"Memoranda marked "EYES ONLY""#, controls: ["65D238"]),
            record(naId: "2", title: #"A title ending in a backslash \"#),
            record(naId: "3", title: #"Both \" and { together"#),
            record(naId: "4", title: "ordinary"),
        ]), expecting: 4, "an escape pair was mis-scanned")
    }

    @Test("Whitespace and newlines between elements are skipped, not decoded")
    func whitespaceBetweenElementsIsSkipped() throws {
        let json = "{\"generated\":\"2026-07-30\",\"records\":[\n  "
            + record(naId: "1", title: "A")
            + " ,\n\n\t"
            + record(naId: "2", title: "B")
            + "\n]}"
        try assertParity(json, expecting: 2)
    }

    @Test("An empty records array yields no records and still reports the stamp")
    func emptyArrayIsNotAnError() throws {
        let r = try bothPaths(shard([]))
        #expect(r.streamed.isEmpty)
        #expect(r.streamedStamp == "2026-07-30")
        #expect(r.streamedStamp == r.wholeStamp)
    }

    // MARK: - The generated stamp

    @Test("The stamp is found when it precedes the array, and when it follows it")
    func stampIsFoundOnBothSides() throws {
        let before = try bothPaths(shard([record(naId: "1", title: "A")]))
        #expect(before.streamedStamp == "2026-07-30")
        let after = try bothPaths(shard([record(naId: "1", title: "A")], generatedLast: true))
        #expect(after.streamedStamp == "2026-07-30",
                "a shard that puts `records` first must still yield its stamp")
        #expect(after.streamedStamp == after.wholeStamp)
    }

    /// The stamp must come from OUTSIDE the array. A record carrying its own `generated` would
    /// otherwise be read as the shard's, silently mis-dating the provenance of every artifact
    /// built from it — the kind of wrong number that survives review because it looks like a date.
    @Test("A `generated` inside a record is never mistaken for the shard's")
    func recordLevelStampIsIgnored() throws {
        let json = "{\"depth\":\"series\",\"records\":["
            + record(naId: "1", title: "A", extra: #","generated":"1999-01-01""#)
            + "]}"
        let r = try bothPaths(json)
        #expect(r.streamed.count == 1)
        #expect(r.streamedStamp == nil, "the record's own stamp must not be adopted")
        #expect(r.streamedStamp == r.wholeStamp)
    }

    // MARK: - Refusals

    @Test("A shard with no records array throws rather than reporting zero records")
    func missingArrayThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shard-\(UUID().uuidString).json")
        try Data(#"{"generated":"2026-07-30","depth":"series"}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: HarvestShardReader.ShardScanError.self) {
            try HarvestShardReader.forEachRecord(url) { _ in }
        }
    }

    /// A truncated shard is the realistic corruption — an interrupted write, a partial copy. It
    /// must name the byte offset rather than yield the records it managed to read, or a half
    /// harvest silently becomes a whole artifact.
    @Test("A truncated final record throws and names its offset")
    func truncatedElementThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shard-\(UUID().uuidString).json")
        let full = shard([record(naId: "1", title: "A"), record(naId: "2", title: "B")])
        try Data(full.dropLast(40).utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: HarvestShardReader.ShardScanError.self) {
            try HarvestShardReader.forEachRecord(url) { _ in }
        }
    }

    @Test("Throwing from the body aborts the walk")
    func bodyCanAbort() throws {
        struct Stop: Error {}
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shard-\(UUID().uuidString).json")
        try Data(shard([record(naId: "1", title: "A"), record(naId: "2", title: "B"),
                        record(naId: "3", title: "C")]).utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var seen = 0
        #expect(throws: Stop.self) {
            try HarvestShardReader.forEachRecord(url) { _ in
                seen += 1
                if seen == 2 { throw Stop() }
            }
        }
        #expect(seen == 2, "the walk must stop at the throwing record, not run to completion")
    }

    // MARK: - Scale

    /// Not a performance test — a correctness-at-scale one. The walk's state is a range table, and
    /// an off-by-one in the element boundary shows up as a decode failure only once enough
    /// elements accumulate for the drift to leave a valid record.
    @Test("A thousand records round-trip in order")
    func manyRecordsRoundTrip() throws {
        let records = (0..<1_000).map {
            record(naId: "\($0)", title: "Series \($0) {sub} \"quoted\"",
                   controls: ["\(50 + $0 % 40)D\($0)"])
        }
        let r = try bothPaths(shard(records))
        #expect(r.streamed.count == 1_000)
        #expect(r.streamed.map(\.naId) == r.whole.map(\.naId))
        #expect(r.streamed.map(\.title) == r.whole.map(\.title))
        #expect(r.streamed.first?.naId == "0" && r.streamed.last?.naId == "999")
    }
}
