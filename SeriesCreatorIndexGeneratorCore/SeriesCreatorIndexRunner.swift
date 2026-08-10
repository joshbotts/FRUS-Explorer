// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit
import LotClaimantsIndexGeneratorCore

// MARK: - SeriesCreatorIndexRunner

/// Builds `series-creator-index.json`: for every NARA series the app can already name, the
/// organisational body NARA credits with creating it (#405).
///
/// ## What it answers, and what it deliberately does not
/// "Who made these records?" is a real archival question that FRUS's own source notes never
/// answer — a note names the container (`Lot 64 D 199`), not the office. NARA does, on the series
/// record, and the app already stores the series NAIDs, so the join needs no new resolution work
/// and no API key.
///
/// **This is a display projection, not a similarity axis.** #405 asked for both; the axis half was
/// measured and refused, and the number that refused it is reachability, not data quality: only
/// the lot-file route reaches a series NAID, which is 4.8% of documents with a source row, giving
/// **2.8% of the corpus**. Three-quarters of the corpus resolves instead to a single record-group
/// node (NAID 388, "General Records of the Department of State"), whose creator would read
/// "Department of State" for most of the corpus. Do not resurrect the axis on the strength of this
/// artifact existing — it was never a data problem.
///
/// ## Why a separate bundled file
/// The creator data lives in the 4.5 GB record-group harvest, which is gitignored and not part of
/// any build. This projection is **kilobytes**: 622 series, 364 distinct headings, interned.
/// `creator-authority.json` (16 MB) holds the creators' own authority records — administrative
/// history prose and so on — and is a different, much larger thing that no surface needs.
///
/// ## What is stored, and what is left unrendered on purpose
/// Both the `Most Recent` creator and any `Predecessor`s are stored, though only the former has a
/// surface today. The harvest pass is the expensive part; re-running it later to answer a question
/// the same scan could have answered costs the same again — the principle the presidential-library
/// harvester states for its deeper levels. 118 of the 622 series carry a predecessor.
///
/// ## Measured, 2026-08-10
/// - 8,234 NAIDs are reachable from the bundled indexes; 2,121 are series in the harvest;
///   **622 carry a creator**. The rest are file units — `creators` is present on exactly the
///   series layer (20,180 of 751,880 harvested records), so a numerical-file roll reaches a
///   creator-less record by construction, not by a harvesting gap.
/// - 364 distinct headings; depth after stripping the date parenthetical is 2 levels 61,
///   3 levels 204, 4 levels 91, 5 levels 6.
/// - **357 of 364 share "Department of State" as their root**, which is why the useful grain is
///   bureau/office and why a root-level match would be worthless.
/// - Largest: "Department of State. Office of the Secretary. Executive Secretariat." on 57 series.
///
/// THROWS rather than writing an index of zeroes: an artifact that resolved nothing would disable
/// the feature while the build exits 0.
///
/// Entirely offline & deterministic (filename-sorted shard scan, sorted vocabulary, sorted keys).
///
/// Env: `HARVEST_DIR` (default `/Users/jbotts/Development/nara-record-group-catalog`),
/// `CENTRAL_FILES_INDEX`, `VOLUME_SOURCES_INDEX`, `OUTPUT`, `GENERATED_DATE`.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
public enum SeriesCreatorIndexRunner {

    /// The bundled projection.
    public struct Index: Codable, Sendable, Equatable {
        public var schemaVersion: Int
        public var generated: String
        /// Every distinct creator heading, sorted, with NARA's trailing date parenthetical
        /// **removed** — `"… Executive Secretariat. (1789 - )"` becomes `"… Executive
        /// Secretariat."`. The dates describe the *body*, not the records, and repeating them on
        /// a line that already states the series' own date range reads as a contradiction.
        public var headings: [String]
        /// Series NAID → its creators, as indices into `headings`.
        public var byNaId: [String: Entry]
    }

    /// One series' creators.
    public struct Entry: Codable, Sendable, Equatable {
        /// Index into `headings` of the body NARA marks `Most Recent` — the one a surface should
        /// name. Falls back to the series' first creator when NARA marks none (measured: 1 of
        /// 622, naId 2521222), because a series with a creator but no *type* still has a creator.
        public var creator: Int
        /// Indices of any `Predecessor` bodies. Stored, not yet rendered — see the type doc.
        public var predecessors: [Int]?

        enum CodingKeys: String, CodingKey {
            case creator = "c"
            case predecessors = "p"
        }
    }

    /// Anything that stops the artifact being trustworthy.
    public enum RunError: Error, CustomStringConvertible {
        case noNAIDs(String)
        case noCreatorsResolved(scanned: Int, naIdsHeld: Int)

        public var description: String {
            switch self {
            case .noNAIDs(let path):
                return """
                    Found no NARA NAIDs in the bundled indexes (\(path)). The projection is a join \
                    onto NAIDs the app already holds; with none there is nothing to build.
                    """
            case .noCreatorsResolved(let scanned, let held):
                return """
                    Scanned \(scanned) harvested series and resolved \(held) app NAIDs, but not one \
                    carried a creator. Expected ~622. Refusing to write an empty index — it would \
                    disable the feature silently while the build exits 0.
                    """
            }
        }
    }

    /// NARA appends the creating body's own lifespan to its heading:
    /// `"War Trade Board. (10/12/1917 - 06/30/1919)"`. Stripped for display — see `headings`.
    ///
    /// **Measured, not guessed.** All 369 raw headings reachable from the app end in a
    /// parenthetical, every one contains a 4-digit year, and none contains NARA's ` : `
    /// disambiguator — so this strips 369 of 369 and keeps nothing back.
    ///
    /// The ` : ` exclusion is a guard rather than a live case, and it is deliberate. NARA uses
    /// that form for *identity*, not lifespan — `President (1945-1953 : Truman)` — and in this
    /// corpus it appears mid-heading, where an end-anchored pattern cannot reach it. Should a
    /// future harvest put one at the end, the exclusion keeps four presidencies from collapsing
    /// into a bare `President`.
    ///
    /// The class must stay permissive about what a date looks like: NARA writes `(1958 - ca.
    /// 1961)` and `(1969 - 1974 ?)`, so a digits-and-dashes-only rule leaves 106 of the 369
    /// headings with their tail still attached. Requiring a year and rejecting ` : ` is what
    /// separates the two kinds.
    static let dateTail = try? NSRegularExpression(pattern: #"\s*\([^()]*\d{4}[^()]*\)\s*$"#)

    /// Whether a trailing parenthetical is NARA's identity disambiguator rather than a lifespan.
    static func isIdentityParenthetical(_ text: String) -> Bool { text.contains(" : ") }

    /// Removes the trailing date parenthetical from a NARA creator heading.
    public static func displayHeading(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dateTail else { return trimmed }
        let ns = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = dateTail.firstMatch(in: trimmed, range: ns),
              let range = Range(match.range, in: trimmed) else { return trimmed }
        guard !isIdentityParenthetical(String(trimmed[range])) else { return trimmed }
        return trimmed.replacingCharacters(in: range, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Every NARA NAID the bundled indexes name, from any nesting depth.
    ///
    /// Deliberately a structural walk rather than a list of known key paths: the two indexes are
    /// regenerated by other tools whose shapes change, and a hard-coded path that silently stopped
    /// matching would shrink this artifact without failing anything.
    static func naIds(inJSONAt url: URL) throws -> Set<String> {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let any = try JSONSerialization.jsonObject(with: data)
        var out = Set<String>()
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                for (key, value) in dict {
                    if key == "naId", let s = scalarString(value) { out.insert(s) }
                    else { walk(value) }
                }
            } else if let array = node as? [Any] {
                for element in array { walk(element) }
            }
        }
        walk(any)
        return out
    }

    private static func scalarString(_ value: Any) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        if let i = value as? Int { return String(i) }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    /// Builds and writes the index.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let harvestDir = env["HARVEST_DIR"] ?? "/Users/jbotts/Development/nara-record-group-catalog"
        let centralFiles = env["CENTRAL_FILES_INDEX"]
            ?? "FRUSExplorer/Resources/central-files-index.json"
        let volumeSources = env["VOLUME_SOURCES_INDEX"]
            ?? "FRUSExplorer/Resources/volume-sources-index.json"
        let output = env["OUTPUT"] ?? "FRUSExplorer/Resources/series-creator-index.json"
        let generated = env["GENERATED_DATE"] ?? generatorDateStamp()

        var held = Set<String>()
        for path in [centralFiles, volumeSources] {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                generatorLog("missing bundled index, skipping: \(path)")
                continue
            }
            let found = try naIds(inJSONAt: url)
            generatorLog("\(URL(fileURLWithPath: path).lastPathComponent): \(found.count) NAIDs")
            held.formUnion(found)
        }
        guard !held.isEmpty else { throw RunError.noNAIDs("\(centralFiles), \(volumeSources)") }
        generatorLog("distinct NAIDs the app holds: \(held.count)")

        let shardDir = URL(fileURLWithPath: harvestDir).appending(path: "series")
        let shards = try FileManager.default
            .contentsOfDirectory(at: shardDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var scanned = 0
        var resolved = 0
        var creatorsByNaId: [String: [HarvestShardReader.Record.Creator]] = [:]
        for shard in shards {
            let (records, _) = try HarvestShardReader.read(shard)
            for record in records {
                scanned += 1
                guard held.contains(record.naId) else { continue }
                resolved += 1
                if !record.creators.isEmpty { creatorsByNaId[record.naId] = record.creators }
            }
            generatorLog("\(shard.lastPathComponent): \(records.count) records")
        }
        generatorLog("scanned \(scanned) harvested records; \(resolved) matched an app NAID; "
                     + "\(creatorsByNaId.count) carry a creator")
        guard !creatorsByNaId.isEmpty else {
            throw RunError.noCreatorsResolved(scanned: scanned, naIdsHeld: resolved)
        }

        // Intern the vocabulary. Sorted so the artifact is byte-stable across runs.
        var vocabulary: [String] = []
        var indexOf: [String: Int] = [:]
        for heading in Set(creatorsByNaId.values.flatMap { $0 }.map { displayHeading($0.heading) })
            .sorted() {
            indexOf[heading] = vocabulary.count
            vocabulary.append(heading)
        }

        var rows: [String: Entry] = [:]
        for (naId, creators) in creatorsByNaId {
            let mostRecent = creators.first { $0.creatorType == "Most Recent" } ?? creators[0]
            guard let primary = indexOf[displayHeading(mostRecent.heading)] else { continue }
            let predecessors = creators
                .filter { $0.creatorType != "Most Recent" }
                .compactMap { indexOf[displayHeading($0.heading)] }
                .filter { $0 != primary }
                .sorted()
            rows[naId] = Entry(creator: primary,
                               predecessors: predecessors.isEmpty ? nil : Array(Set(predecessors)).sorted())
        }

        let index = Index(schemaVersion: 1, generated: generated,
                          headings: vocabulary, byNaId: rows)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(index)
        let outURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: outURL)

        generatorLog("""
            series-creator-index.json written to \(output)
              series with a creator: \(rows.count)
              distinct headings:     \(vocabulary.count)
              with predecessors:     \(rows.values.filter { $0.predecessors != nil }.count)
              bytes:                 \(data.count)
            """)
    }
}
