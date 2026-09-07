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

// MARK: - ShardWriterByteParityTests

/// P-2's gate: the streaming shard write must produce byte-identical output to the whole-shard
/// encode it replaced.
///
/// **Nothing in this repo pinned these bytes before this suite.** `RunnerEndToEndTests.isDeterministic`
/// compares two fresh runs against *each other*, not against a golden, and `harvestsEndToEnd`
/// decodes the shard rather than comparing it — so both stay green under any encoder that
/// round-trips. The shards are gitignored (4.5 GB) and six downstream consumers parse them, one of
/// them (`DigitizedRangeIndexRunner`) by matching the exact 11-byte literal `"records":[` with no
/// whitespace tolerance. A byte change here is a silent, unreviewable change to a shipped artifact.
struct ShardWriterByteParityTests {

    /// A writer over a fresh temporary directory, and that directory.
    private func makeWriter() throws -> (RecordGroupCatalogWriter, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("p2-shard-parity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let writer = RecordGroupCatalogWriter(outputDirectory: dir)
        // The runner calls this before any write; `seriesDirectory` does not exist until it does,
        // and the previous `Data.write(to:)` depended on it just as the streaming write does.
        try writer.prepare()
        return (writer, dir)
    }

    /// The 500 committed sample records — real NARA payloads across 16 record groups.
    ///
    /// Read through `#filePath` in a THROWING helper, not a `static let` with a `fatalError`: a trap
    /// in a static initialiser kills the test process, and `xcodebuild` then prints
    /// "0 tests ... passed" with a ✔.
    private func sampleRecords() throws -> [HarvestedRecord] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "Planning/nara-record-group-catalog/series-sample.json")
        struct Sample: Decodable { let records: [HarvestedRecord] }
        return try JSONDecoder().decode(Sample.self, from: Data(contentsOf: url)).records
    }

    private func shard(_ records: [HarvestedRecord],
                       title: String? = "Records of the Department of State",
                       group: Int = 59) -> RecordGroupIndexShard {
        RecordGroupIndexShard(generated: "2026-09-07", recordGroup: group,
                             title: title, depth: .seriesAndFileUnits, records: records)
    }

    /// The written file must equal what `JSONEncoder.encode(shard)` would have produced.
    private func expectParity(_ shard: RecordGroupIndexShard,
                              _ label: String) throws {
        let (writer, dir) = try makeWriter()
        defer { try? FileManager.default.removeItem(at: dir) }
        let reference = try RecordGroupCatalogWriter.compactEncoder.encode(shard)
        let returned = try writer.writeShard(shard)
        let written = try Data(contentsOf: dir.appendingPathComponent("series")
            .appendingPathComponent("rg_\(shard.recordGroup).json"))
        #expect(written == reference, "\(label): streamed bytes differ from the whole-shard encode")
        #expect(returned == written.count,
                "\(label): writeShard returned \(returned) but wrote \(written.count)")
    }

    // MARK: Real data

    @Test("The 500 committed sample records stream byte-identically")
    func realSampleIsByteIdentical() throws {
        let records = try sampleRecords()
        // Without this the comparison could pass over an empty array and prove nothing.
        #expect(records.count == 500, "the committed sample holds \(records.count) records")
        try expectParity(shard(records), "500 real records")
    }

    // MARK: Boundaries the corpus does not exercise

    /// `RunnerEndToEndTests` only ever writes three records, so none of these has ever been written.
    /// A stray leading or trailing comma yields invalid JSON at exactly these counts.
    @Test("Zero, one and two records all stream byte-identically", arguments: [0, 1, 2])
    func boundaryCountsAreByteIdentical(_ n: Int) throws {
        let records = Array(try sampleRecords().prefix(n))
        #expect(records.count == n)
        try expectParity(shard(records), "\(n) records")
    }

    /// A shard with no records must still emit `"records":[]`, not `"records":[,]` or a truncation.
    @Test("An empty shard emits a well-formed empty array")
    func emptyShardIsWellFormed() throws {
        let (writer, dir) = try makeWriter()
        defer { try? FileManager.default.removeItem(at: dir) }
        try writer.writeShard(shard([]))
        let written = try Data(contentsOf: dir.appendingPathComponent("series")
            .appendingPathComponent("rg_59.json"))
        let text = try #require(String(data: written, encoding: .utf8))
        #expect(text.contains("\"records\":[]"), "empty shard wrote: \(text)")
        // Proves it is parseable, which a stray comma would break.
        _ = try JSONDecoder().decode(RecordGroupIndexShard.self, from: written)
    }

    /// `RecordGroupCatalogRunner` passes a nilable title, and `.sortedKeys` puts `title` LAST — so a
    /// nil title changes the epilogue. An encoder-authored epilogue handles it; a hand-written one
    /// would have to know.
    @Test("A nil title omits the key rather than emitting null")
    func nilTitleIsByteIdentical() throws {
        let records = Array(try sampleRecords().prefix(3))
        try expectParity(shard(records, title: nil), "nil title")
        let (writer, dir) = try makeWriter()
        defer { try? FileManager.default.removeItem(at: dir) }
        try writer.writeShard(shard(records, title: nil))
        let text = try #require(String(data: try Data(contentsOf:
            dir.appendingPathComponent("series").appendingPathComponent("rg_59.json")),
            encoding: .utf8))
        // Every RECORD carries its own `title`, so a whole-file search proves nothing. The shard's
        // own `title` sorts LAST under `.sortedKeys`, so its absence is a property of the tail.
        #expect(text.hasSuffix("\"schemaVersion\":1}"),
                "a nil title must be omitted; tail was \(text.suffix(40))")
        #expect(!text.hasSuffix("null}"), "a nil title must be omitted, not emitted as null")
    }

    /// Characters the 500-record sample does not contain. `.withoutEscapingSlashes` is set, so a
    /// slash must stay bare; a quote, a backslash, an emoji and a combining accent must not.
    @Test("Adversarial title characters stream byte-identically")
    func adversarialTitleIsByteIdentical() throws {
        let records = Array(try sampleRecords().prefix(2))
        let nasty = #"Quote " backslash \ slash / brace {} emoji 🗂 combining e\#u{0301} tab\#t"#
        try expectParity(shard(records, title: nasty), "adversarial title")
    }

    // MARK: The split guard

    /// The guard fires when the marker is absent — the case a format change would create.
    ///
    /// This test exists because a mutation weakening `occurrences == 1` to `occurrences >= 0`
    /// SURVIVED a nine-mutation sweep. It survived correctly: with the split inline, no shard could
    /// reach the guard, because a string value containing the marker has its quotes escaped. Handing
    /// the extracted function a pretty-printed skeleton is the only way to reach it — and that is
    /// exactly what would happen if `compactEncoder` ever gained `.prettyPrinted`, which emits
    /// `"records" : []` and matches zero times. Without the guard the writer would silently produce
    /// a truncated shard.
    @Test("A skeleton the encoder would never produce is refused, not silently truncated")
    func theSplitGuardRefusesAMissingMarker() throws {
        let pretty = JSONEncoder()
        pretty.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        let skeleton = try pretty.encode(shard([]))
        // The premise: pretty-printing really does break the marker.
        #expect(!String(decoding: skeleton, as: UTF8.self).contains("\"records\":[]"),
                "the pretty-printed skeleton still contains the compact marker")
        #expect(throws: RecordGroupCatalogWriter.ShardWriteError.ambiguousRecordsMarker(occurrences: 0)) {
            _ = try RecordGroupCatalogWriter.split(emptyRecordsSkeleton: skeleton)
        }
    }

    /// Two occurrences are refused rather than resolved by taking the first.
    @Test("A doubled marker is refused rather than split at the first hit")
    func theSplitGuardRefusesADoubledMarker() throws {
        let doubled = Data(#"{"a":"records":[]","records":[]}"#.utf8)
        #expect(throws: RecordGroupCatalogWriter.ShardWriteError.ambiguousRecordsMarker(occurrences: 2)) {
            _ = try RecordGroupCatalogWriter.split(emptyRecordsSkeleton: doubled)
        }
    }

    /// The happy path splits between the brackets, so an empty list needs no special case.
    @Test("The split lands between the brackets")
    func theSplitLandsBetweenTheBrackets() throws {
        let skeleton = try RecordGroupCatalogWriter.compactEncoder.encode(shard([]))
        let (prologue, epilogue) = try RecordGroupCatalogWriter.split(emptyRecordsSkeleton: skeleton)
        #expect(prologue.last == UInt8(ascii: "["), "prologue must end at the open bracket")
        #expect(epilogue.first == UInt8(ascii: "]"), "epilogue must start at the close bracket")
        #expect(prologue + epilogue == skeleton, "the two halves must reconstitute the skeleton")
    }

    // MARK: Atomicity

    /// A failed write must leave the previous good shard intact and no `.partial` behind.
    ///
    /// The runner's materially-short guard exists to stop a worse shard replacing a better one, and
    /// a half-written file defeats it from underneath — silently, because `SeriesFactsIndexRunner`
    /// throws only on *zero* creators and `AccessionSeriesIndexRunner` only on an *empty* map, so a
    /// truncated shard yields a truncated shipped artifact and exit 0.
    @Test("A failed write leaves the previous shard intact and no staging file")
    func aFailedWriteIsAtomic() throws {
        let (writer, dir) = try makeWriter()
        defer { try? FileManager.default.removeItem(at: dir) }
        let good = shard(Array(try sampleRecords().prefix(5)))
        try writer.writeShard(good)
        let live = dir.appendingPathComponent("series").appendingPathComponent("rg_59.json")
        let before = try Data(contentsOf: live)
        #expect(!before.isEmpty)

        // Injecting a real I/O failure, not a poisoned value.
        //
        // My first attempt set `title` to the literal `records":[]` expecting to make the marker
        // ambiguous. It does NOT: JSON escapes the embedded quote, so the encoded form is
        // `records\":[]` and the marker stays unique. A data-driven collision is impossible, which
        // is recorded on `ShardWriteError.ambiguousRecordsMarker` — so the failure has to come from
        // the filesystem.
        let seriesDir = dir.appendingPathComponent("series")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: seriesDir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                   ofItemAtPath: seriesDir.path)
        }
        #expect(throws: (any Error).self) {
            try writer.writeShard(shard(Array(try self.sampleRecords().prefix(9))))
        }
        #expect(try Data(contentsOf: live) == before, "the previous good shard was disturbed")
        #expect(!FileManager.default.fileExists(
            atPath: writer.stagingURL(recordGroup: 59).path), "a .partial survived a failed write")
    }

    /// The staging file must never be picked up as a shard.
    ///
    /// `SeriesFactsIndexRunner:429` and `AccessionSeriesIndexRunner:211` filter this directory on
    /// `pathExtension == "json"` with no `rg_` prefix guard, and `AccessionSeriesIndexRunner:219`
    /// derives the record group from the file NAME — so a staging file named `rg_59.tmp.json` would
    /// be read as record group `"59.tmp"` and corrupt every key in a shipped artifact.
    @Test("The staging file's extension keeps it out of every consumer's directory scan")
    func stagingFileIsInvisibleToConsumers() throws {
        let (writer, dir) = try makeWriter()
        defer { try? FileManager.default.removeItem(at: dir) }
        let staging = writer.stagingURL(recordGroup: 59)
        #expect(staging.pathExtension == "partial",
                "staging extension is \(staging.pathExtension) — consumers filter on \"json\"")
        // The filename trap, spelled out: this is what the consumers would infer.
        let inferred = staging.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "rg_", with: "")
        #expect(inferred == "59.json",
                "guard the shape: a consumer that ignored pathExtension would infer \(inferred)")
    }
}
