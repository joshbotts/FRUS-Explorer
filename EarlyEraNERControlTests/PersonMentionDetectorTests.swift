// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import EarlyEraNERControlCore

// MARK: - CodePointOffsetTests

/// The offset arithmetic that joins this detector to a Python-produced store (#234 R-1).
///
/// Every other producer and consumer in this program is Python, which indexes strings by **code
/// point**. Swift offers three plausible answers — grapheme clusters (`String.count`), UTF-16
/// units (`utf16Offset`), and code points — and all three agree on ASCII, which is why this is
/// tested against strings where they disagree rather than against the corpus.
///
/// Version history:
///   1.0 — Session 2026-08-11: #234 R-1 control detector.
@Suite("Code-point offsets (#234 R-1)")
struct CodePointOffsetTests {

    /// Ranges for every occurrence of `needle` in `haystack`.
    private func ranges(of needle: String, in haystack: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var searchStart = haystack.startIndex
        while let range = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            found.append(range)
            searchStart = range.upperBound
        }
        return found
    }

    @Test("ASCII text offsets match what Python would produce")
    func asciiOffsets() throws {
        let text = "Hamilton Fish wrote to Lord Granville about Fish."
        let mentions = try PersonMentionDetector.mentions(
            in: text, tokenRanges: ranges(of: "Fish", in: text))
        #expect(mentions.count == 2)
        #expect(mentions[0].start == 9)
        #expect(mentions[0].end == 13)
        // The second occurrence proves the cursor walks forward correctly across a gap.
        #expect(mentions[1].start == 44)
        #expect(mentions[1].surface == "Fish")
    }

    @Test("A decomposed accent counts as two code points, not one character")
    func decomposedAccent() throws {
        // "Jose\u{301}" is 5 code points and 4 Characters. A grapheme-based offset would place
        // the following name one short, and every span after it in the document with it.
        let text = "Jose\u{301} wrote to Marshall."
        let mentions = try PersonMentionDetector.mentions(
            in: text, tokenRanges: ranges(of: "Marshall", in: text))
        #expect(text.count == 23)                 // Characters
        #expect(text.unicodeScalars.count == 24)  // code points — what Python counts
        #expect(mentions.count == 1)
        #expect(mentions[0].start == 15)          // 16 if you counted Characters — the defect
        let scalars = Array(text.unicodeScalars)
        #expect(String(String.UnicodeScalarView(scalars[mentions[0].start..<mentions[0].end]))
                == "Marshall")
    }

    @Test("An astral character counts as one code point, not two UTF-16 units")
    func astralCharacter() throws {
        // U+1D4D0 is a single code point stored as a surrogate pair. A UTF-16 offset would put
        // everything after it two places late; Python would say one.
        let text = "\u{1D4D0} then Bevin spoke."
        let mentions = try PersonMentionDetector.mentions(
            in: text, tokenRanges: ranges(of: "Bevin", in: text))
        #expect(text.utf16.count == text.unicodeScalars.count + 1)
        #expect(mentions.count == 1)
        #expect(mentions[0].start == 7)
    }

    @Test("Adjacent ranges do not lose the cursor")
    func adjacentRanges() throws {
        let text = "AB"
        let first = text.startIndex..<text.index(text.startIndex, offsetBy: 1)
        let second = text.index(text.startIndex, offsetBy: 1)..<text.endIndex
        let mentions = try PersonMentionDetector.mentions(in: text, tokenRanges: [first, second])
        #expect(mentions.map(\.start) == [0, 1])
        #expect(mentions.map(\.end) == [1, 2])
    }

    @Test("An empty range list yields nothing rather than failing")
    func noRanges() throws {
        #expect(try PersonMentionDetector.mentions(in: "nobody here", tokenRanges: []).isEmpty)
    }
}

// MARK: - TaggerSmokeTests

/// The recogniser itself, asserted only on properties that hold across OS releases.
///
/// `NLTagger` is closed-source and ships with the system, so its exact output is a moving target —
/// which is why the run manifest records the OS build. These tests pin self-consistency (every
/// span slices back to its own surface) rather than a particular set of names, so an OS update
/// cannot turn a green suite red for a reason that is not a defect.
@Suite("NLTagger control detector (#234 R-1)")
struct TaggerSmokeTests {

    @Test("Every detected span slices back to its own surface")
    func spansAreSelfConsistent() throws {
        let text = "Mr. Bevin agreed with Marshall that Hamilton Fish had settled the question "
                 + "in Washington, and the Secretary of State said nothing."
        let mentions = try PersonMentionDetector().mentions(in: text)
        let scalars = Array(text.unicodeScalars)
        for mention in mentions {
            #expect(mention.start < mention.end)
            #expect(mention.end <= scalars.count)
            #expect(Array(scalars[mention.start..<mention.end])
                    == Array(mention.surface.unicodeScalars))
        }
    }

    @Test("Mentions come back in document order")
    func mentionsAreOrdered() throws {
        let text = "Fish wrote, Granville replied, and Bevin summarised."
        let mentions = try PersonMentionDetector().mentions(in: text)
        #expect(mentions == mentions.sorted { $0.start < $1.start })
    }
}

// MARK: - StoreIOTests

/// Reading and writing the store shapes the Python side produces and consumes.
@Suite("NER store IO (#234 R-1)")
struct StoreIOTests {

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ner-control-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("A plain .jsonl text layer is read in file order")
    func readsPlainTextLayer() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let lines = """
            {"d":"d1","o":0,"t":"Hamilton Fish wrote."}
            {"d":"d2","o":1,"t":"Bevin replied."}

            """
        try Data(lines.utf8).write(to: directory.appendingPathComponent("frusTest.jsonl"))
        let documents = try NERStoreIO.textLayer(volume: "frusTest", in: directory)
        #expect(documents.map(\.id) == ["d1", "d2"])
        #expect(documents[1].ordinal == 1)
        #expect(documents[0].text == "Hamilton Fish wrote.")
    }

    @Test("An absent volume is an error for text and an empty list for the marked layer")
    func absentVolumes() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: DetectorError.self) {
            _ = try NERStoreIO.textLayer(volume: "frusMissing", in: directory)
        }
        #expect(try NERStoreIO.markedLayer(volume: "frusMissing", in: directory).isEmpty)
    }

    @Test("Detected rows are written in the Python writer's key order")
    func writesRowShape() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("frusTest.jsonl")
        try NERStoreIO.writeDetected([
            DetectedRow(document: "d1", ordinal: 0, start: 3, end: 7, surface: "Fish"),
            DetectedRow(document: "d1", ordinal: 0, start: 9, end: 14, surface: "\"Q\""),
        ], to: url)
        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written.hasPrefix("{\"d\":\"d1\",\"o\":0,\"s\":3,\"e\":7,\"n\":\"Fish\"}"))
        #expect(written.contains("\\\"Q\\\""))     // quotes escaped the way json.dumps escapes them
        #expect(written.hasSuffix("\n"))
        // `ci` is the one place the two writers DIVERGE, and the divergence is the point:
        // `harvest_ner.py` closes its detected row with `"ci": chunk_index` because a windowed
        // LLM pass has a chunk to name, and this detector does not chunk. Writing a constant 0
        // would fabricate a field a reader could believe; its absence raises a KeyError in a
        // consumer that wants it, which is the loud failure. Asserted rather than merely omitted
        // from the prefix above, because a prefix match cannot tell a missing field from a
        // reordered one — and this test shipped expecting `,"ci":0}`, which is how it went in red.
        #expect(written.contains("\"ci\"") == false, """
            The control writes no chunk index. See NERStoreIO.writeDetected's own note: a constant \
            0 here is a fabricated field, not a harmless default.
            """)
    }

    @Test("A ground-truth file groups documents by volume")
    func readsGroundTruth() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("m2a-ground-truth.jsonl")
        try Data("""
            {"v":"frusA","d":"d1","s":0,"e":4,"n":"Fish","seeded":true}
            {"v":"frusA","d":"d2","s":5,"e":9,"n":"Grey","seeded":false}
            {"v":"frusB","d":"d1","s":1,"e":6,"n":"Bevin","seeded":false}

            """.utf8).write(to: url)
        let grouped = try NERStoreIO.groundTruthDocuments(at: url)
        #expect(grouped["frusA"] == ["d1", "d2"])
        #expect(grouped["frusB"] == ["d1"])
    }

    @Test("head.json keys are the snake_case names the Python scorer reads")
    func summaryEncodesScorerKeys() throws {
        let summary = VolumeSummary(
            volume: "frusTest", model: "NLTagger nameType (test)", sampled: true,
            sampledDocIds: ["d1"], docsScanned: 1, docsInVolume: 2, charsScanned: 40,
            mentions: 3, overlappingMarked: 1, novel: 2, markedInScannedDocs: 1,
            forcedEnglish: true, secs: 0.4)
        let json = try String(data: NERStoreIO.encodeJSON(summary), encoding: .utf8) ?? ""
        #expect(json.contains("\"sampled_doc_ids\""))
        #expect(json.contains("\"docs_scanned\""))
        #expect(json.contains("\"overlapping_marked\""))
    }
}

// MARK: - ResumeScopeTests

/// The guards that keep a run from finishing clean while having done nothing, or the wrong thing
/// (#863 follow-up).
@Suite("Control run — scope and resume guards")
struct ResumeScopeTests {

    private func summary(sampled: Bool, ids: [String]?) -> VolumeSummary {
        VolumeSummary(volume: "frusTest", model: "test", sampled: sampled, sampledDocIds: ids,
                      docsScanned: ids?.count ?? 9, docsInVolume: 9, charsScanned: 100,
                      mentions: 3, overlappingMarked: 2, novel: 1, markedInScannedDocs: 4,
                      forcedEnglish: true, secs: 0.1)
    }

    @Test("A sampled pass never stands in for a full sweep")
    func sampledDoesNotCoverFull() {
        // The defect this rule exists for: the runbook's fast path samples three documents a
        // volume against the ground truth, and the head it writes is indistinguishable from a
        // full pass's at the grain the old resume test used — file existence. The full sweep
        // that followed skipped those volumes, and the manifest, which re-derives its totals
        // from every head, folded three documents into what it called a complete pass.
        let sampled = summary(sampled: true, ids: ["d1", "d2", "d3"])
        #expect(EarlyEraNERControlRunner.covers(sampled, requesting: nil) == false)
    }

    @Test("A full pass covers any sample, so a complete store is never redone")
    func fullCoversSample() {
        let full = summary(sampled: false, ids: nil)
        #expect(EarlyEraNERControlRunner.covers(full, requesting: nil))
        #expect(EarlyEraNERControlRunner.covers(full, requesting: ["d4"]))
    }

    @Test("A sampled pass is reused only for documents it actually names")
    func sampledCoversItsOwnSubset() {
        let sampled = summary(sampled: true, ids: ["d1", "d2", "d3"])
        #expect(EarlyEraNERControlRunner.covers(sampled, requesting: ["d1", "d3"]))
        #expect(EarlyEraNERControlRunner.covers(sampled, requesting: ["d1", "d9"]) == false, """
            `d9` was never scanned. Reusing this head would report a document the detector \
            never saw as one it found nothing in.
            """)
        // A sample that did not record WHICH documents cannot cover anything: the scorer already
        // refuses such a store, and the resume path must not quietly accept it either.
        #expect(EarlyEraNERControlRunner.covers(summary(sampled: true, ids: nil),
                                                requesting: ["d1"]) == false)
    }

    @Test("An unreadable head resumes nothing rather than failing the run")
    func unreadableHeadIsAbsent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let truncated = directory.appendingPathComponent("frusTest.head.json")
        try Data("{\"volume\":\"frusTe".utf8).write(to: truncated)
        #expect(EarlyEraNERControlRunner.storedSummary(at: truncated) == nil, """
            A head truncated by a killed run should send the volume back through the detector, \
            not abort the sweep.
            """)
        #expect(EarlyEraNERControlRunner.storedSummary(
            at: directory.appendingPathComponent("absent.head.json")) == nil)
    }
}

// MARK: - WhitespaceTrimTests

/// A person name never begins or ends with whitespace, and a span that says otherwise is off by
/// exactly that much against the editors' markup (#863 follow-up).
@Suite("Control detector — span whitespace")
struct WhitespaceTrimTests {

    @Test("A token range carrying whitespace yields the name's own offsets")
    func trimsToTheName() throws {
        let text = "To Mr. Fish , and then"
        let start = text.index(text.startIndex, offsetBy: 2)     // the space before "Mr."
        let end = text.index(text.startIndex, offsetBy: 12)      // the space after "Fish"
        let mentions = try PersonMentionDetector.mentions(in: text, tokenRanges: [start..<end])
        let mention = try #require(mentions.first)
        #expect(mention.surface == "Mr. Fish")
        #expect(mention.start == 3 && mention.end == 11, """
            Untrimmed this is [2,12) with the surface " Mr. Fish ", which still slices back to \
            itself — so `spanMismatch` never fires and the scorer's own span check passes. It \
            would show up only as a zeroed strict-precision column, read as a weakness in the \
            recogniser rather than a bug in the harness.
            """)
    }

    @Test("Offsets stay in code points when the trimmed text is not ASCII")
    func trimsAroundNonASCII() throws {
        // The whole reason this arithmetic is factored out: it is right for ASCII either way.
        let text = "Sr. Muñoz  wrote"
        let start = text.startIndex
        let end = text.index(text.startIndex, offsetBy: 11)
        let mention = try #require(
            PersonMentionDetector.mentions(in: text, tokenRanges: [start..<end]).first)
        #expect(mention.surface == "Sr. Muñoz")
        #expect(mention.start == 0 && mention.end == 9)
    }

    @Test("A range holding only whitespace yields no mention at all")
    func dropsEmptyRanges() throws {
        let text = "a   b"
        let start = text.index(text.startIndex, offsetBy: 1)
        let end = text.index(text.startIndex, offsetBy: 4)
        #expect(try PersonMentionDetector.mentions(in: text, tokenRanges: [start..<end]).isEmpty)
    }

    @Test("Trimming does not disturb the running cursor for later spans")
    func cursorSurvivesTrimming() throws {
        // The offsets are produced by one forward cursor, so a trimmed range has to leave it
        // where the NEXT range expects it. A fixture with one span is blind to this.
        let text = "Mr. Fish  met  Lord Grey today"
        func range(_ lower: Int, _ upper: Int) -> Range<String.Index> {
            text.index(text.startIndex, offsetBy: lower)..<text.index(text.startIndex,
                                                                     offsetBy: upper)
        }
        let mentions = try PersonMentionDetector.mentions(
            in: text, tokenRanges: [range(0, 9), range(14, 24)])
        #expect(mentions.map(\.surface) == ["Mr. Fish", "Lord Grey"])
        #expect(mentions.map(\.start) == [0, 15])
        #expect(mentions.map(\.end) == [8, 24])
    }
}
