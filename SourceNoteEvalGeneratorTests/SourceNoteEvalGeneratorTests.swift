// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import SourceNoteEvalGeneratorCore
import SourceNoteKit

// MARK: - CSVReader

@Suite("CSVReader")
struct CSVReaderTests {

    @Test("Plain unquoted rows split on commas and newlines")
    func plainRows() {
        let rows = CSVReader.parse("a,b,c\nd,e,f\n")
        #expect(rows == [["a", "b", "c"], ["d", "e", "f"]])
    }

    @Test("Quoted field with embedded commas stays one field")
    func quotedCommas() {
        let rows = CSVReader.parse(#"v1,source-note,"Lot 64 D 199, Box 3",tail"#)
        #expect(rows == [["v1", "source-note", "Lot 64 D 199, Box 3", "tail"]])
    }

    @Test("Quoted TEI field with embedded newlines and escaped quotes parses intact")
    func quotedTEIXML() {
        // Mirrors the citations.csv tei_xml column: ""-escaped attribute quotes and a
        // literal newline inside one quoted field.
        let csv = """
        volume_id,citation_type,xpath,tei_xml
        frus1861,source-note,id('d5')/note,"<note xmlns=""http://www.tei-c.org/ns/1.0"" rend=""inline""
        type=""source"">[Extract.]</note>"
        """
        let rows = CSVReader.parse(csv)
        #expect(rows.count == 2)
        #expect(rows[1][0] == "frus1861")
        let xml = rows[1][3]
        #expect(xml.contains(#"rend="inline""#))
        #expect(xml.contains("\ntype=\"source\""))
        #expect(xml.hasSuffix("</note>"))
    }

    @Test("CRLF record terminators and a final record without trailing newline")
    func crlfAndNoTrailingNewline() {
        let rows = CSVReader.parse("a,b\r\nc,d\r\ne,f")
        #expect(rows == [["a", "b"], ["c", "d"], ["e", "f"]])
    }

    @Test("Empty fields are preserved, including a trailing empty field")
    func emptyFields() {
        let rows = CSVReader.parse("a,,c\n,x,\n")
        #expect(rows == [["a", "", "c"], ["", "x", ""]])
    }

    @Test("Blank lines between records are skipped")
    func blankLines() {
        let rows = CSVReader.parse("a,b\n\nc,d\n")
        #expect(rows == [["a", "b"], ["c", "d"]])
    }

    @Test("Multibyte UTF-8 content (en-dashes) survives byte-level parsing")
    func multibyte() {
        let rows = CSVReader.parse("frus1958-60v01,\"Lot 71–D 440, Box 19232\"\n")
        #expect(rows == [["frus1958-60v01", "Lot 71–D 440, Box 19232"]])
    }

    @Test("Streaming across chunk boundaries yields identical records")
    func chunkBoundaries() throws {
        let csv = "aaa,\"b,\nb\",ccc\nddd,eee,fff\n"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("csvreader-chunk-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data(csv.utf8).write(to: tmp)
        // A 3-byte chunk size forces quoted fields and CRLF pairs to straddle chunks.
        var rows: [[String]] = []
        try CSVReader.forEachRecord(in: tmp, chunkSize: 3) { row in
            rows.append(row)
            return true
        }
        #expect(rows == [["aaa", "b,\nb", "ccc"], ["ddd", "eee", "fff"]])
    }

    @Test("Handler returning false stops the stream early")
    func earlyStop() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("csvreader-stop-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data("a\nb\nc\n".utf8).write(to: tmp)
        var rows = 0
        try CSVReader.forEachRecord(in: tmp) { _ in
            rows += 1
            return rows < 2
        }
        #expect(rows == 2)
    }
}

// MARK: - EraBucket

@Suite("EraBucket")
struct EraBucketTests {

    @Test("Volume ids bucket by leading year, mirroring the audit table")
    func volumeIdBuckets() {
        #expect(EraBucket(volumeId: "frus1861") == .pre1906)
        #expect(EraBucket(volumeId: "frus1905") == .pre1906)
        #expect(EraBucket(volumeId: "frus1909") == .era1906to1939)
        #expect(EraBucket(volumeId: "frus1939v01") == .era1906to1939)
        #expect(EraBucket(volumeId: "frus1940v02") == .era1940to1951)
        #expect(EraBucket(volumeId: "frus1951v03") == .era1940to1951)
        #expect(EraBucket(volumeId: "frus1952-54v01p2") == .era1952to1954)
        #expect(EraBucket(volumeId: "frus1955-57v19") == .era1955to1957)
        #expect(EraBucket(volumeId: "frus1958-60v01") == .era1958to1960)
        #expect(EraBucket(volumeId: "frus1961-63v10") == .era1961to1963)
        #expect(EraBucket(volumeId: "frus1964-68v01") == .era1964to1976)
        #expect(EraBucket(volumeId: "frus1969-76ve10") == .era1964to1976)
        #expect(EraBucket(volumeId: "frus1977-80v22") == .era1977plus)
        #expect(EraBucket(volumeId: "frus1981-88v44p1") == .era1977plus)
        #expect(EraBucket(volumeId: "frus1989-92v31") == .era1977plus)
    }

    @Test("Ids without a frusYYYY prefix yield nil")
    func invalidIds() {
        #expect(EraBucket(volumeId: "notavolume") == nil)
        #expect(EraBucket(volumeId: "frusXYZ") == nil)
        #expect(EraBucket(volumeId: "") == nil)
    }
}

// MARK: - NotePreparation

@Suite("NotePreparation")
struct NotePreparationTests {

    @Test("Top-level note xpath routes to whitespace-normalized plain text")
    func topLevelWholeText() {
        let input = NotePreparation.parserInput(
            plainText: "  711.00/11–552.\n Secret.  ",
            teiXML: #"<note rend="inline" type="source">711.00/11–552. Secret.</note>"#,
            xpath: "id('d5')/note"
        )
        #expect(input == "711.00/11–552. Secret.")
    }

    @Test("Head-nested xpath is detected from the bare id() shape")
    func headNestedDetection() {
        #expect(NotePreparation.isHeadNestedXPath("id('d184fn1')"))
        #expect(!NotePreparation.isHeadNestedXPath("id('d5')/note"))
        #expect(!NotePreparation.isHeadNestedXPath("id('d10')/attachment/note"))
        #expect(!NotePreparation.isHeadNestedXPath("id('d10')/note[2]"))
    }

    @Test("Multi-paragraph head note selects the first Source:-prefixed paragraph")
    func headNoteParagraphSelection() {
        let xml = """
        <note n="1" type="source" xml:id="d1fn1">
          <p>Summary paragraph about the meeting.</p>
          <p>Source: Eisenhower Library, Dulles papers. Secret.</p>
        </note>
        """
        let input = NotePreparation.parserInput(
            plainText: "Summary paragraph about the meeting. Source: Eisenhower Library, Dulles papers. Secret.",
            teiXML: xml,
            xpath: "id('d1fn1')"
        )
        #expect(input == "Source: Eisenhower Library, Dulles papers. Secret.")
    }

    @Test("Head note without a Source: paragraph falls back to whole-note text")
    func headNoteWholeFallback() {
        let xml = """
        <note n="1" type="source" xml:id="d2fn1">
          <p>Received through the Chinese <hi rend="italic">minister</hi>,</p>
          <p>July 19, 1909.</p>
        </note>
        """
        let input = NotePreparation.parserInput(
            plainText: "irrelevant",
            teiXML: xml,
            xpath: "id('d2fn1')"
        )
        #expect(input == "Received through the Chinese minister, July 19, 1909.")
    }

    @Test("[Source: …] wrapper collapses to Source:-prefixed shape")
    func wrapperCollapse() {
        let input = NotePreparation.parserInput(
            plainText: "[Source: Kennedy Library, President's Office Files.]",
            teiXML: #"<note type="source">[Source: Kennedy Library, President's Office Files.]</note>"#,
            xpath: "id('d9')/note"
        )
        #expect(input == "Source: Kennedy Library, President's Office Files.")
        #expect(NotePreparation.normalizeSourceNoteWrapper("711.00/11–552.") == "711.00/11–552.")
    }

    @Test("Malformed tei_xml on a head-nested row falls back to plain_text")
    func malformedXMLFallback() {
        let input = NotePreparation.parserInput(
            plainText: "Source: Department of State, Central Files.",
            teiXML: "<note><p>unclosed",
            xpath: "id('d3fn1')"
        )
        #expect(input == "Source: Department of State, Central Files.")
    }
}

// MARK: - EvalReport

@Suite("EvalReport")
struct EvalReportTests {

    /// Builds the fixture report used by the determinism test.
    private func makeReport() -> EvalReport {
        var r = EvalReport(sampleCap: 2)
        r.record(volumeId: "frus1909", outcome: .centralFiles, parserInput: "893.00/123")
        r.record(volumeId: "frus1909", outcome: .unrecognized, parserInput: "odd note A")
        r.record(volumeId: "frus1909", outcome: .unrecognized, parserInput: "odd note B")
        r.record(volumeId: "frus1909", outcome: .unrecognized, parserInput: "odd note A")
        r.record(volumeId: "frus1909", outcome: .unrecognized, parserInput: "odd note C")
        r.record(volumeId: "frus1961-63v10", outcome: .presidentialLibrary,
                 parserInput: "Source: Kennedy Library")
        return r
    }

    @Test("Report tallies era × outcome and renders deterministically")
    func reportDeterminism() {
        let a = makeReport()
        let textA = a.render(corpusDescription: "fixture")
        let textB = makeReport().render(corpusDescription: "fixture")
        #expect(textA == textB)
        #expect(a.total(for: .era1906to1939) == 5)
        #expect(a.count(for: .era1906to1939, outcome: .unrecognized) == 4)
        #expect(a.total(for: .era1961to1963) == 1)
        // Sample cap: only the first two distinct unrecognized inputs are kept.
        #expect(textA.contains("odd note A"))
        #expect(textA.contains("odd note B"))
        #expect(!textA.contains("odd note C"))
    }

    @Test("Rows without a bucketable volume id are counted, not dropped silently")
    func unbucketedRows() {
        var r = EvalReport()
        r.record(volumeId: "bogus", outcome: .unrecognized, parserInput: "x")
        #expect(r.unbucketedRows == 1)
        #expect(r.render(corpusDescription: "fixture").contains("unbucketed rows"))
    }
}

// MARK: - End-to-end fixture run

@Suite("SourceNoteEvalRunner")
struct SourceNoteEvalRunnerTests {

    @Test("Fixture csv → report with expected classifications per era")
    func endToEnd() throws {
        // Three rows: a pre-1906 [Extract.] (unrecognized), a decimal file (centralFiles),
        // and a head-nested multi-paragraph note whose Source: paragraph must be selected
        // (presidentialLibrary). The tei_xml carries ""-escaped quotes and embedded commas.
        let csv = """
        volume_id,citation_type,ancestor_id,xpath,plain_text,tei_xml
        frus1861,source-note,d5,id('d5')/note,[Extract.],"<note rend=""inline"" type=""source"">[Extract.]</note>"
        frus1909,source-note,d8,id('d8')/note,893.00/123.,"<note rend=""inline"" type=""source"">893.00/123.</note>"
        frus1958-60v01,source-note,d9,id('d9fn1'),"Memo of talk. Source: Eisenhower Library, Dulles papers.","<note n=""1"" type=""source"" xml:id=""d9fn1""><p>Memo of talk.</p><p>Source: Eisenhower Library, Dulles papers.</p></note>"
        frus1909,footnote-archival,d8,id('d8')/note[2],ignored,"<note>ignored</note>"
        """
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let csvURL = dir.appendingPathComponent("citations.csv")
        let outURL = dir.appendingPathComponent("eval-report.txt")
        try Data(csv.utf8).write(to: csvURL)

        let text = try SourceNoteEvalRunner.run(csvPath: csvURL.path, outputPath: outURL.path)
        #expect(text.contains("TOTAL NOTES: 3"))          // footnote-archival row filtered out
        #expect(text.contains("era pre-1906"))
        #expect(text.contains("era 1906-1939"))
        #expect(text.contains("era 1958-1960"))
        #expect(text.contains("centralFiles"))
        #expect(text.contains("presidentialLibrary"))     // Source: paragraph was selected
        #expect(text.contains("[Extract.]"))              // unrecognized sample surfaced
        let onDisk = try String(contentsOf: outURL, encoding: .utf8)
        #expect(onDisk == text)
    }
}
