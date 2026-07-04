// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

/// Builds the bundled `collection-authority.json` (Source Explorer Phase 4) from a local
/// mirror of the FRUS TEI volumes: parses every volume's front-matter Sources section
/// **and** every document's source note with the shared `SourceNoteKit` grammar, merges
/// the references into two-level authority records (`AuthorityBuilder`), attaches
/// offline-resolved NARA NAIDs (`OfflineNAIDResolver` — never the live API), and writes
/// the deterministic artifact plus a regeneration report (stats, coverage, and the
/// ambiguous clusters left unmerged).
///
/// Configuration (environment variables):
/// - `VOLUMES_DIR` — directory of volume `*.xml` files (default `/Users/jbotts/Development/frus/volumes`)
/// - `CENTRAL_FILES_INDEX` — bundled index path (default `FRUSExplorer/Resources/central-files-index.json`)
/// - `VOLUME_SOURCES_INDEX` — bundled index path (default `FRUSExplorer/Resources/volume-sources-index.json`)
/// - `CACHE_DIR` — the VolumeSourcesIndexGenerator NAID cache, read-only (default `.cache/volume-sources`)
/// - `OUTPUT` — artifact path (default `FRUSExplorer/Resources/collection-authority.json`)
/// - `REPORT` — regeneration report path (default `collection-authority-report.txt`)
/// - `GENERATED_DATE` — override the `generated` stamp (default: today, `yyyy-MM-dd`)
public enum CollectionAuthorityRunner {

    /// Per-volume extraction result.
    struct VolumeExtraction: Sendable {
        let volumeId: String
        let frontRows: [FrontSourceRow]
        let notes: [DocumentNoteExtractor.DocumentNote]
    }

    /// Runs the full generation pass.
    public static func run() async throws {
        let env = ProcessInfo.processInfo.environment
        let volumesDir = URL(fileURLWithPath: env["VOLUMES_DIR"]
                             ?? "/Users/jbotts/Development/frus/volumes")
        let outputPath = env["OUTPUT"] ?? "FRUSExplorer/Resources/collection-authority.json"
        let reportPath = env["REPORT"] ?? "collection-authority-report.txt"
        let generated = env["GENERATED_DATE"] ?? today()

        let resolver = OfflineNAIDResolver(
            centralFilesIndexURL: URL(fileURLWithPath: env["CENTRAL_FILES_INDEX"]
                                      ?? "FRUSExplorer/Resources/central-files-index.json"),
            volumeSourcesIndexURL: URL(fileURLWithPath: env["VOLUME_SOURCES_INDEX"]
                                       ?? "FRUSExplorer/Resources/volume-sources-index.json"),
            cacheDirectory: URL(fileURLWithPath: env["CACHE_DIR"] ?? ".cache/volume-sources"))

        // MARK: Phase A — corpus pass (bounded concurrency).
        let xmls = try FileManager.default.contentsOfDirectory(at: volumesDir,
                                                               includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !xmls.isEmpty else { throw RunError.noVolumes(volumesDir.path) }
        log("Parsing \(xmls.count) volumes from \(volumesDir.path) …")

        var extractions: [VolumeExtraction] = []
        extractions.reserveCapacity(xmls.count)
        try await withThrowingTaskGroup(of: VolumeExtraction?.self) { group in
            var iterator = xmls.makeIterator()
            var inFlight = 0
            func addNext() {
                guard let url = iterator.next() else { return }
                inFlight += 1
                group.addTask { extractVolume(at: url) }
            }
            for _ in 0..<8 { addNext() }
            while inFlight > 0 {
                if let result = try await group.next() {
                    inFlight -= 1
                    if let extraction = result { extractions.append(extraction) }
                    addNext()
                }
            }
        }
        extractions.sort { $0.volumeId < $1.volumeId }
        let totalNotes = extractions.reduce(0) { $0 + $1.notes.count }
        let totalFrontItems = extractions.reduce(0) {
            $0 + $1.frontRows.filter { $0.kind == .item }.count
        }
        log("Extracted \(totalFrontItems) front-matter items, \(totalNotes) document notes")

        // MARK: Phase B — references.
        let parser = SourceNoteParser()
        var references: [CollectionReference] = []
        var parsedNoteCount = 0
        // Per-volume level-1 keys of the clusterable document notes — the per-era
        // doc-note coverage input for the report.
        var docNoteKeysByVolume: [String: [String]] = [:]
        for extraction in extractions {
            references.append(contentsOf: ReferenceBuilder.references(
                volumeId: extraction.volumeId, frontRows: extraction.frontRows))
            for note in extraction.notes {
                let parsed = parser.parse(note.note)
                parsedNoteCount += 1
                if let ref = ReferenceBuilder.reference(volumeId: extraction.volumeId,
                                                        note: note.note, parsed: parsed) {
                    references.append(ref)
                    if let key = AuthorityBuilder.level1Key(for: ref) {
                        docNoteKeysByVolume[extraction.volumeId, default: []].append(key)
                    }
                }
            }
        }
        log("Built \(references.count) references (from \(parsedNoteCount) notes)")

        // MARK: Phase C — clustering + NAIDs.
        let result = AuthorityBuilder.build(references: references, resolver: resolver)

        // MARK: Phase D — artifact (deterministic bytes).
        let index = CollectionAuthorityIndex(schemaVersion: 1, generated: generated,
                                             collections: result.collections)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: URL(fileURLWithPath: outputPath))

        // MARK: Phase E — report.
        let report = makeReport(generated: generated, result: result,
                                extractions: extractions, totalNotes: totalNotes,
                                docNoteKeysByVolume: docNoteKeysByVolume,
                                artifactBytes: data.count)
        try Data(report.utf8).write(to: URL(fileURLWithPath: reportPath))
        log(report)
        log("collection-authority.json written to \(outputPath) (\(data.count) bytes)")
    }

    /// Extracts one volume (front matter + document notes) with a single XML pass each.
    static func extractVolume(at url: URL) -> VolumeExtraction? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let volumeId = url.deletingPathExtension().lastPathComponent
        let frontRows = FrontMatterSourcesExtractor.extract(fromXML: data)
        let notes = DocumentNoteExtractor.extract(fromXML: data)
        guard !frontRows.isEmpty || !notes.isEmpty else { return nil }
        return VolumeExtraction(volumeId: volumeId, frontRows: frontRows, notes: notes)
    }

    // MARK: - Report

    /// Assembles the regeneration report: artifact stats, keyed-row coverage, per-era
    /// document-note coverage, and the ambiguous clusters left unmerged.
    static func makeReport(generated: String, result: AuthorityBuilder.BuildResult,
                           extractions: [VolumeExtraction], totalNotes: Int,
                           docNoteKeysByVolume: [String: [String]] = [:],
                           artifactBytes: Int) -> String {
        let records = result.collections
        let lotRecords = records.filter { $0.lotFileNorm != nil }
        let naidCount = records.filter { $0.naId != nil }.count
        let aliasCount = records.reduce(0) { $0 + $1.aliases.count }
            + records.reduce(0) { sum, r in sum + r.children.reduce(0) { $0 + $1.aliases.count } }
        let childCount = records.reduce(0) { $0 + $1.children.count }

        // Coverage: % of Phase-3-keyed front-matter items landing in an authority record.
        let ids = Set(records.map(\.id))
        let classChildren = Set(records.flatMap { $0.children.compactMap(\.decimalClass) })
        var childNamesByRepo: Set<String> = []
        for record in records {
            let repo = ReferenceBuilder.normalized(record.repository ?? "")
            for child in record.children where child.decimalClass == nil {
                childNamesByRepo.insert(repo + "|" + CollectionKeying.segmentNorm(child.name))
            }
        }
        var keyed = 0, landed = 0
        var keyedLot = 0, landedLot = 0, keyedClass = 0, landedClass = 0
        var keyedText = 0, landedText = 0
        for extraction in extractions {
            for row in extraction.frontRows where row.kind == .item {
                // Structural headings (repository / RG scaffolding) are excluded from
                // the authority by design — they are not "keyed collections" missed.
                guard !ReferenceBuilder.isStructural(row) || row.lotFileNorm != nil
                else { continue }
                if let lot = row.lotFileNorm {
                    keyed += 1; keyedLot += 1
                    if ids.contains("lot:" + lot) { landed += 1; landedLot += 1 }
                } else if let cls = row.decimalClass {
                    keyed += 1; keyedClass += 1
                    if classChildren.contains(cls) { landed += 1; landedClass += 1 }
                } else if row.repository != nil || row.recordGroup != nil {
                    keyed += 1; keyedText += 1
                    if let segment = ReferenceBuilder.leadingMergeSegment(of: row.text) {
                        let canonical = ReferenceBuilder.canonicalRepository(row.repository)
                        let repo = ReferenceBuilder.isCentralFilesSegment(segment)
                                && CollectionKeying.centralFilesOverrideApplies(to: canonical)
                            ? "department of state"
                            : ReferenceBuilder.normalized(canonical ?? "")
                        let norm = CollectionKeying.segmentNorm(segment)
                        if ids.contains("txt:" + repo + "|" + norm)
                            || childNamesByRepo.contains(repo + "|" + norm)
                            || (row.repository == nil && ids.contains("txt:|" + norm)) {
                            landed += 1; landedText += 1
                        }
                    }
                }
            }
        }
        func pct(_ n: Int, _ d: Int) -> String {
            d == 0 ? "n/a" : String(format: "%.1f%%", 100.0 * Double(n) / Double(d))
        }

        var lines: [String] = []
        lines.append("collection-authority.json regeneration report — \(generated)")
        lines.append(String(repeating: "=", count: 60))
        lines.append("volumes parsed:            \(extractions.count)")
        lines.append("document notes parsed:     \(totalNotes)")
        lines.append("authority records:         \(records.count) (lot-keyed: \(lotRecords.count), with NAID: \(naidCount))")
        lines.append("sub-series children:       \(childCount)")
        lines.append("alias forms:               \(aliasCount)")
        lines.append("unclusterable references:  \(result.unclusterableCount)")
        lines.append("artifact size:             \(artifactBytes) bytes")
        lines.append("")
        lines.append("Coverage — Phase-3-keyed front-matter items landing in an authority record:")
        lines.append("  lot-keyed:   \(landedLot)/\(keyedLot) (\(pct(landedLot, keyedLot)))")
        lines.append("  class-keyed: \(landedClass)/\(keyedClass) (\(pct(landedClass, keyedClass)))")
        lines.append("  text-keyed:  \(landedText)/\(keyedText) (\(pct(landedText, keyedText)))")
        lines.append("  overall:     \(landed)/\(keyed) (\(pct(landed, keyed)))")
        lines.append("")

        // Per-era document-note coverage: parsed notes → clusterable (a level-1
        // identity exists) → landed (the identity's record ships in the artifact).
        // Notes below the doc-note-only volume threshold intentionally do not land.
        if !docNoteKeysByVolume.isEmpty {
            struct EraBucket { var notes = 0; var clusterable = 0; var landed = 0 }
            var eras: [String: EraBucket] = [:]
            func eraName(of volumeId: String) -> String {
                let digits = volumeId.dropFirst(4).prefix(while: \.isNumber)
                guard digits.count == 4, let year = Int(digits) else { return "other" }
                switch year {
                case ..<1946: return "…–1945"
                case ..<1961: return "1946–1960"
                case ..<1969: return "1961–1968"
                case ..<1977: return "1969–1976"
                case ..<1989: return "1977–1988"
                default: return "1989–…"
                }
            }
            for extraction in extractions {
                let era = eraName(of: extraction.volumeId)
                var bucket = eras[era] ?? EraBucket()
                bucket.notes += extraction.notes.count
                for key in docNoteKeysByVolume[extraction.volumeId] ?? [] {
                    bucket.clusterable += 1
                    if ids.contains(key) { bucket.landed += 1 }
                }
                eras[era] = bucket
            }
            lines.append("Coverage — document source notes by era (parsed → clusterable → landed):")
            for (era, b) in eras.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(era): \(b.notes) notes → \(b.clusterable) clusterable (\(pct(b.clusterable, b.notes))) → \(b.landed) landed (\(pct(b.landed, b.notes)) of notes, \(pct(b.landed, b.clusterable)) of clusterable)")
            }
            lines.append("")
        }
        lines.append("Ambiguous clusters left unmerged (same leading segment, different repositories): \(result.ambiguous.count)")
        for cluster in result.ambiguous.prefix(200) {
            lines.append("  \(cluster.segment)  ←  \(cluster.repositories.joined(separator: " | "))")
        }
        if result.ambiguous.count > 200 {
            lines.append("  … \(result.ambiguous.count - 200) more")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Helpers

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    /// Fatal configuration errors.
    public enum RunError: Error, CustomStringConvertible {
        /// No volume XML files were found at the configured path.
        case noVolumes(String)
        public var description: String {
            switch self {
            case .noVolumes(let dir): return "No .xml volumes found in \(dir)"
            }
        }
    }
}
