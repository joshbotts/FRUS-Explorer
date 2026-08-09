// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import SourceProvenanceIndexGeneratorCore
import SourceNoteKit

// MARK: - ProvenanceCategory.from exhaustive mapping

@Suite("ProvenanceCategory.from maps every ParsedSourceNote case")
struct ProvenanceCategoryMappingTests {

    @Test("centralFiles → centralDecimalFile")
    func centralFiles() {
        #expect(ProvenanceCategory.from(.centralFiles(recordGroup: "RG-59", fileIdentifier: "1")) == .centralDecimalFile)
    }

    @Test("cfpfFile → centralForeignPolicyFile")
    func cfpf() {
        #expect(ProvenanceCategory.from(.cfpfFile(fileIdentifier: "P840114–1808")) == .centralForeignPolicyFile)
    }

    @Test("lotFile → lotFile")
    func lot() {
        #expect(ProvenanceCategory.from(.lotFile(recordGroup: "59", lotNumber: "60 D 627", fileIdentifier: nil)) == .lotFile)
    }

    @Test("presidentialLibrary → presidentialLibrary")
    func presidential() {
        #expect(ProvenanceCategory.from(.presidentialLibrary(library: "Eisenhower Library", collection: "Dulles Papers", fileIdentifier: nil)) == .presidentialLibrary)
    }

    @Test("naraCollection → naraCollection")
    func nara() {
        #expect(ProvenanceCategory.from(.naraCollection(recordGroup: "59", series: nil, lotFile: nil, box: nil)) == .naraCollection)
    }

    @Test("ciaCollection → intelligence")
    func cia() {
        #expect(ProvenanceCategory.from(.ciaCollection(jobNumber: "80-01795R", box: nil, description: "CIA")) == .intelligence)
    }

    @Test("namedFileSeries → namedFileSeries")
    func named() {
        #expect(ProvenanceCategory.from(.namedFileSeries(seriesName: "IO Files", fileIdentifier: nil)) == .namedFileSeries)
    }

    @Test("foreignGovernmentArchive → foreignArchive")
    func foreign() {
        #expect(ProvenanceCategory.from(.foreignGovernmentArchive(description: "PRO")) == .foreignArchive)
    }

    @Test("previouslyPublished → previouslyPublished")
    func published() {
        #expect(ProvenanceCategory.from(.previouslyPublished(citation: "Treaty Series No. 762")) == .previouslyPublished)
    }

    @Test("unrecognized → unrecognized")
    func unrecognized() {
        #expect(ProvenanceCategory.from(.unrecognized(rawText: "???")) == .unrecognized)
    }

    @Test("orderedCases covers every case exactly once")
    func orderedCasesComplete() {
        #expect(Set(ProvenanceCategory.orderedCases) == Set(ProvenanceCategory.allCases))
        #expect(ProvenanceCategory.orderedCases.count == ProvenanceCategory.allCases.count)
    }
}

// MARK: - Full SourceNoteParser → ProvenanceCategory pipeline

@Suite("Real source-note strings through the full parser pipeline")
struct PipelineTests {

    private func category(_ note: String) -> ProvenanceCategory {
        ProvenanceCategory.from(SourceNoteParser().parse(note))
    }

    @Test("Decimal central-file note → centralDecimalFile")
    func decimal() {
        #expect(category("763.72110/8937: Telegram") == .centralDecimalFile)
    }

    @Test("Bare File No. note → centralDecimalFile")
    func fileNo() {
        #expect(category("File No. 3767/5.") == .centralDecimalFile)
    }

    @Test("Lot-file note → lotFile")
    func lot() {
        #expect(category("Source: Department of State, S/S Files: Lot 60 D 627, Box 12") == .lotFile)
    }

    @Test("Central Foreign Policy File / P-reel note → centralForeignPolicyFile")
    func cfpf() {
        #expect(category("Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808") == .centralForeignPolicyFile)
        #expect(category("Part of the on-line Access to Archival Databases: Electronic Telegrams, P-Reel") == .centralForeignPolicyFile)
    }

    @Test("Presidential-library note → presidentialLibrary")
    func presidential() {
        #expect(category("Eisenhower Library, Dulles Papers, White House Memoranda Series") == .presidentialLibrary)
    }

    @Test("Empty / whitespace note → unrecognized")
    func empty() {
        #expect(category("") == .unrecognized)
        #expect(category("   \n\t  ") == .unrecognized)
    }
}

// MARK: - Coverage-decade bucketing

@Suite("coverageDecade bucketing")
struct DecadeBucketingTests {

    private func range(_ e: String?, _ l: String?) -> ManifestVolumeEntry.DateRange {
        .init(earliest: e, latest: l)
    }

    @Test("Midpoint floored to the decade")
    func midpoint() {
        // 1918..1922 → midpoint 1920 → 1920
        #expect(coverageDecade(for: range("1918-01-01T00:00:00-05:00", "1922-12-31T23:59:59-05:00")) == 1920)
        // 1955..1957 → midpoint 1956 → 1950
        #expect(coverageDecade(for: range("1955-01-01T00:00:00Z", "1957-12-31T00:00:00Z")) == 1950)
        // single year 1920 → 1920
        #expect(coverageDecade(for: range("1920-06-01T00:00:00Z", "1920-06-30T00:00:00Z")) == 1920)
    }

    @Test("Missing endpoints fall back to the present one")
    func missing() {
        #expect(coverageDecade(for: range("1933-01-01T00:00:00Z", nil)) == 1930)
        #expect(coverageDecade(for: range(nil, "1948-01-01T00:00:00Z")) == 1940)
        #expect(coverageDecade(for: range(nil, nil)) == nil)
        #expect(coverageDecade(for: nil) == nil)
    }

    @Test("firstYear reads the leading four digits")
    func firstYearHelper() {
        #expect(firstYear("1920-01-01T00:00:00-05:00") == 1920)
        #expect(firstYear("abcd-01-01") == nil)
        #expect(firstYear("19") == nil)
        #expect(firstYear(nil) == nil)
    }
}

// MARK: - Source-note extraction

@Suite("SourceNoteExtractor")
struct SourceNoteExtractorTests {

    @Test("Collects type=source notes across note/seg/p, ignores others, collapses whitespace")
    func extract() {
        let xml = Data("""
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <text><body>
            <div type="document">
              <head>Doc 1<note type="source">763.72110/8937:
                    Telegram</note></head>
              <p>Body text that is not a source note.</p>
            </div>
            <div type="document">
              <note type="source">Source: Department of State, S/S Files: Lot 60 D 627</note>
            </div>
            <div type="document">
              <seg type="source">File No. 3767/5.</seg>
            </div>
          </body></text>
        </TEI>
        """.utf8)
        let notes = SourceNoteExtractor.extract(fromXML: xml)
        #expect(notes.count == 3)
        #expect(notes[0] == "763.72110/8937: Telegram")
        #expect(notes[1] == "Source: Department of State, S/S Files: Lot 60 D 627")
        #expect(notes[2] == "File No. 3767/5.")
    }

    @Test("A source element wrapping an inner typed element yields one note")
    func nested() {
        let xml = Data("""
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
          <note type="source">Source: <hi type="source">RG 59</hi>, Central Files</note>
        </body></text></TEI>
        """.utf8)
        let notes = SourceNoteExtractor.extract(fromXML: xml)
        #expect(notes.count == 1)
        #expect(notes[0] == "Source: RG 59, Central Files")
    }
}

// MARK: - VolumeBucketTests

/// The per-volume table schema 2 adds (#267), driven over a fixture corpus.
///
/// The decade table was already covered; nothing exercised `byVolume`, and a mutation sweep
/// confirmed it — dropping the field entirely, and dropping its per-category counting, both left
/// the suite green. These run the real scan so the parse, the category mapping and the bucketing
/// are the shipping ones.
///
/// Version history:
///   1.0 — Session 2026-08-08: #267
@Suite("Source provenance — per-volume buckets")
struct VolumeBucketTests {

    /// A volume whose documents carry `notes` as their source notes.
    private func volume(_ id: String, notes: [String], in directory: URL) throws -> URL {
        let body = notes.map { "<note type=\"source\">\($0)</note>" }.joined(separator: "\n")
        let xml = "<TEI><text><body>\n\(body)\n</body></text></TEI>"
        let url = directory.appendingPathComponent("\(id).xml")
        try Data(xml.utf8).write(to: url)
        return url
    }

    private func corpus() throws -> (files: [URL], decades: [String: Int]) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prov-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let files = [
            try volume("frus1952-54v01", notes: [
                "Source: Department of State, Central Files, 611.41/3–553. Secret.",
                "Source: Department of State, Central Files, 788.5/9–1361. Top Secret.",
                "Source: Department of State, Conference Files: Lot 64 D 199, CF 100.",
            ], in: root),
            try volume("frus1952-54v02", notes: [
                "Source: Department of State, Conference Files: Lot 64 D 199, CF 200.",
            ], in: root),
            try volume("frus1964-68v01", notes: [
                "Source: Johnson Library, National Security File, Country File, Vietnam.",
            ], in: root),
            // Has a decade but no notes — must be skipped, not emitted as an empty bucket.
            try volume("frus1969-76v01", notes: [], in: root),
        ]
        return (files, ["frus1952-54v01": 1950, "frus1952-54v02": 1950,
                        "frus1964-68v01": 1960, "frus1969-76v01": 1970])
    }

    @Test("Every scanned volume with notes gets a bucket carrying its own counts")
    func perVolumeCounts() throws {
        let (files, decades) = try corpus()
        let index = SourceProvenanceIndexRunner
            .build(xmls: files, decadeByVolume: decades, generated: "2026-08-08").index
        let volumes = try #require(index.byVolume, "schema 2 must emit byVolume")

        #expect(volumes.map(\.volumeId) == ["frus1952-54v01", "frus1952-54v02", "frus1964-68v01"],
                "a volume with no source notes must not appear as an empty bucket")
        let first = try #require(volumes.first)
        #expect(first.decade == 1950)
        #expect(first.totalNotes == 3)
        #expect(first.counts["centralDecimalFile"] == 2, """
            The volume's own category counts are wrong: \(first.counts). A bucket that carried \
            the decade's counts, or none at all, would still pass every decade-level assertion.
            """)
        #expect(first.counts["lotFile"] == 1)
        #expect(first.counts["presidentialLibrary"] == nil, "zero counts are omitted")
    }

    @Test("The per-volume table sums to the decade table it ships beside")
    func volumesRollUpToDecades() throws {
        let (files, decades) = try corpus()
        let index = SourceProvenanceIndexRunner
            .build(xmls: files, decadeByVolume: decades, generated: "2026-08-08").index
        let volumes = try #require(index.byVolume)

        for bucket in index.byDecade {
            let members = volumes.filter { $0.decade == bucket.decade }
            #expect(members.reduce(0) { $0 + $1.totalNotes } == bucket.totalNotes,
                    "\(bucket.decade): volumes and decade disagree on the note total")
            #expect(members.count == bucket.volumeCount,
                    "\(bucket.decade): \(members.count) volume buckets vs volumeCount \(bucket.volumeCount)")
            var summed: [String: Int] = [:]
            for member in members {
                for (category, count) in member.counts { summed[category, default: 0] += count }
            }
            #expect(summed == bucket.counts, "\(bucket.decade): category counts disagree")
        }
        #expect(volumes.reduce(0) { $0 + $1.totalNotes } == index.totalSourceNotes)
        #expect(volumes.count == index.volumesCovered)
    }

    @Test("Buckets are sorted by volume id whatever order the scan saw them in")
    func bucketsAreSorted() throws {
        let (files, decades) = try corpus()
        let index = SourceProvenanceIndexRunner
            .build(xmls: files.reversed(), decadeByVolume: decades, generated: "2026-08-08").index
        let volumes = try #require(index.byVolume)
        #expect(volumes.map(\.volumeId) == volumes.map(\.volumeId).sorted(), """
            Reversing the scan order changed the output order, so the artifact's determinism \
            depends on the directory listing rather than on the writer.
            """)
    }

    @Test("The artifact declares schema 2")
    func schemaVersion() throws {
        let (files, decades) = try corpus()
        let index = SourceProvenanceIndexRunner
            .build(xmls: files, decadeByVolume: decades, generated: "2026-08-08").index
        #expect(index.schemaVersion == 2)
    }
}
