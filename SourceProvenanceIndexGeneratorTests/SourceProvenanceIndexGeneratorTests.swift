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
