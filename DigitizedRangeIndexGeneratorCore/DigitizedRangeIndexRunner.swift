// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DigitizedRangeIndexRunner

/// Builds `digitized-ranges-index.json` from the NARA record-group harvest (#663).
///
/// ## Why this needs a streaming reader
/// The input is `HARVEST_DIR/series/rg_59.json` — **3.3 GB in a single line of JSON**, one object
/// with a 240,929-element `records` array. `JSONSerialization` and `JSONDecoder` both need the
/// whole document in memory, which on this file means tens of gigabytes. So the reader scans for
/// record boundaries by brace depth and decodes **one record at a time**, holding only a bounded
/// buffer. RG 256 (170 MB) goes through the same path rather than a second one.
///
/// ## What it keeps
/// File units under the digitised decimal series that carry at least one digital object *and* a
/// title stating a numeric range. Measured on the 2026-07-30 harvest: 4,247 digitised file units
/// in those series, **625** of which state a numeric range — the rest are the Visa Division's
/// name-filed births (`131/Abba-Abbi`), which no decimal citation can match. See
/// `DigitizedRangeTitleParser` for that measurement.
///
/// ## What it refuses to write
/// An empty index, and an index whose ranges collapse to a single class. Both have a plausible
/// cause — a renamed field, a changed ancestry shape — and both would ship a resource that
/// silently disables the feature rather than failing loudly. The same reason
/// `LotClaimantsIndexGenerator` throws on zero divided lots.
///
/// ## Input provenance
/// `HARVEST_DIR` defaults to `/Users/jbotts/Development/nara-record-group-catalog` — **outside
/// the repo**, because the shards are 3.3 GB and gitignored. The artifact this writes is small
/// (~625 rows) and committed. Re-running needs the harvest; see the record-group runbook.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663
public enum DigitizedRangeIndexRunner {

    /// The NARA series whose file units are digitised decimal ranges.
    ///
    /// `302021` Central Decimal Files and `2555709` Decimal Files are the two that carry ranges
    /// FRUS citations can land in. `654171` Numerical Files is deliberately **absent**: the app
    /// already routes 1906–1910 citations to their roll through `central-files-index.json`, and
    /// a second index answering the same question is how two surfaces come to disagree.
    public static let seriesNaIds: Set<String> = ["302021", "2555709"]

    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let harvestDir = env["HARVEST_DIR"]
            ?? "/Users/jbotts/Development/nara-record-group-catalog"
        let output = env["OUTPUT"]
            ?? "FRUSExplorer/Resources/digitized-ranges-index.json"
        let generated = env["GENERATED_DATE"] ?? Self.today()

        let shard = URL(fileURLWithPath: harvestDir)
            .appendingPathComponent("series/rg_59.json")
        guard FileManager.default.fileExists(atPath: shard.path) else {
            throw GeneratorError.missingInput(shard.path)
        }

        var ranges: [DigitizedRange] = []
        var digitizedUnits = 0
        try HarvestRecordStream(url: shard).forEach { record in
            guard record["levelOfDescription"] as? String == "fileUnit",
                  let count = record["digitalObjectCount"] as? Int, count > 0,
                  let ancestors = record["ancestors"] as? [[String: Any]],
                  let seriesId = ancestors.first(where: {
                      $0["levelOfDescription"] as? String == "series"
                  })?["naId"].map(String.init(describing:)),
                  seriesNaIds.contains(seriesId)
            else { return }
            digitizedUnits += 1
            let title = (record["title"] as? String) ?? ""
            guard let parsed = DigitizedRangeTitleParser.parse(title) else { return }
            let objects = record["digitalObjects"] as? [[String: Any]] ?? []
            ranges.append(DigitizedRange(
                decimalClass: parsed.decimalClass, low: parsed.low, high: parsed.high,
                naId: String(describing: record["naId"] ?? ""),
                objectCount: count,
                objectUrl: objects.first?["objectUrl"] as? String,
                objectFilename: objects.first?["objectFilename"] as? String,
                title: title))
        }

        // Deterministic: class, then interval, then NAID.
        ranges.sort {
            ($0.decimalClass, $0.low, $0.high, $0.naId)
                < ($1.decimalClass, $1.low, $1.high, $1.naId)
        }
        let classes = Set(ranges.map(\.decimalClass))
        guard !ranges.isEmpty else { throw GeneratorError.emptyIndex(digitizedUnits) }
        guard classes.count > 1 else { throw GeneratorError.singleClass(classes.first ?? "?") }

        let file = DigitizedRangeIndexFile(
            schemaVersion: 1, generated: generated,
            seriesNaIds: seriesNaIds.sorted(),
            note: "Numeric decimal-file ranges only. The digitised file units this omits are "
                + "name-filed (Visa Division reports of births, class 131), which no decimal "
                + "citation can match.",
            ranges: ranges)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(file).write(to: URL(fileURLWithPath: output))

        FileHandle.standardError.write(Data("""
            digitised file units in the target series: \(digitizedUnits)
            ranges written: \(ranges.count) across \(classes.count) classes
            output: \(output)

            """.utf8))
    }

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    public enum GeneratorError: Error, CustomStringConvertible {
        case missingInput(String)
        case emptyIndex(Int)
        case singleClass(String)

        public var description: String {
            switch self {
            case .missingInput(let path):
                return "Harvest shard not found at \(path). Set HARVEST_DIR — the shards are "
                     + "gitignored and live outside the repo."
            case .emptyIndex(let units):
                return "No ranges parsed from \(units) digitised file units. Refusing to write "
                     + "an index that would silently disable the feature."
            case .singleClass(let cls):
                return "Every range landed in one class (\(cls)). That is a field-shape change, "
                     + "not a corpus fact — refusing to write."
            }
        }
    }
}

// MARK: - HarvestRecordStream

/// Reads a harvest shard's `records` array one object at a time.
///
/// The shard is a single-line JSON object of up to 3.3 GB; nothing in Foundation parses that
/// incrementally, so this finds each record's extent by counting braces outside string literals
/// and hands the bytes to `JSONSerialization` alone. Memory stays bounded by the largest single
/// record (RG 59's biggest file unit is ~4 MB) rather than by the file.
///
/// A **class**, not a struct with an `inout` buffer: the first version passed the buffer
/// `inout` to the brace scanner while the refill closure also captured it, which is two
/// overlapping accesses to one variable and traps at runtime under exclusivity checking. One
/// owner for the buffer removes the possibility rather than working around it.
final class HarvestRecordStream {
    private let handle: FileHandle
    private var buffer = Data()
    private let chunkSize = 1 << 22

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
    }

    deinit { try? handle.close() }

    /// Appends the next chunk; `false` at end of file.
    private func fill() throws -> Bool {
        guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else {
            return false
        }
        buffer.append(chunk)
        return true
    }

    func forEach(_ body: ([String: Any]) throws -> Void) throws {
        // Advance to the opening bracket of the records array.
        let marker = Data("\"records\":[".utf8)
        while true {
            if let r = buffer.range(of: marker) {
                buffer = buffer.subdata(in: r.upperBound..<buffer.endIndex)
                break
            }
            // Keep an overlap so the marker cannot straddle two chunks.
            if buffer.count > marker.count {
                buffer = buffer.subdata(in: (buffer.count - marker.count)..<buffer.count)
            }
            guard try fill() else { return }
        }

        while true {
            dropLeadingSeparators()
            guard let first = buffer.first else {
                guard try fill() else { return }
                continue
            }
            if first == 0x5D { return }          // ']' — end of records
            if first != 0x7B {                   // not '{' — need more bytes
                guard try fill() else { return }
                continue
            }
            guard let end = try objectEnd() else { return }
            let slice = buffer.subdata(in: buffer.startIndex..<end)
            if let object = try JSONSerialization.jsonObject(with: slice) as? [String: Any] {
                try body(object)
            }
            buffer = buffer.subdata(in: end..<buffer.endIndex)
        }
    }

    private func dropLeadingSeparators() {
        var i = buffer.startIndex
        while i < buffer.endIndex,
              buffer[i] == 0x20 || buffer[i] == 0x0A || buffer[i] == 0x0D
                  || buffer[i] == 0x09 || buffer[i] == 0x2C {
            i += 1
        }
        if i > buffer.startIndex { buffer = buffer.subdata(in: i..<buffer.endIndex) }
    }

    /// The index one past the closing brace of the object at the buffer's head, reading more
    /// bytes as needed. Brace counting ignores braces inside string literals and honours
    /// backslash escapes — without both, a record whose title contains `{` truncates.
    private func objectEnd() throws -> Data.Index? {
        var depth = 0
        var inString = false
        var escaped = false
        var consumed = 0
        while true {
            var i = buffer.startIndex + consumed
            while i < buffer.endIndex {
                let byte = buffer[i]
                if escaped { escaped = false; i += 1; continue }
                if inString {
                    if byte == 0x5C { escaped = true }
                    else if byte == 0x22 { inString = false }
                } else if byte == 0x22 { inString = true }
                else if byte == 0x7B { depth += 1 }
                else if byte == 0x7D {
                    depth -= 1
                    if depth == 0 { return i + 1 }
                }
                i += 1
            }
            consumed = i - buffer.startIndex
            guard try fill() else { return nil }
        }
    }
}
