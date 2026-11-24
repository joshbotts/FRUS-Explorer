// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - SemanticFeedbackEntryTests

/// Semantic Match Feedback's verdict and its file's coding, which FRUSCoreKit holds since FRUS Explorer
/// Light's S26a: the log file and the export a reader shares are these bytes, wherever they are written,
/// and a file written before a field existed still reads. The log's actor, its file's place and its
/// rules are the app's (`SemanticFeedbackLogTests`).
///
/// Version history:
///   1.0 — 2026-11-23: FRUS Explorer Light's S26a
@Suite("FRUSCoreKit — a semantic verdict and its file's coding")
struct SemanticFeedbackEntryTests {

    /// A verdict whose every number is exact in binary, so its bytes are the same on every platform.
    static let entry = SemanticFeedbackEntry(
        recordedAt: Date(timeIntervalSince1970: 1_795_435_200),   // 2026-11-23T12:00:00Z
        anchor: "frus1864p1/d147", neighbour: "frus1864p1/d148", verdict: .helpful,
        cosine: 0.75, era: "0", sameVolume: true, provenanceDigest: "abc")

    @Test("The log file is one line, its keys sorted and its dates in ISO 8601")
    func theFilesBytes() throws {
        let data = try SemanticFeedbackEntry.fileData([Self.entry])
        #expect(String(decoding: data, as: UTF8.self) == """
            [{"anchor":"frus1864p1\\/d147","cosine":0.75,"era":"0","neighbour":"frus1864p1\\/d148",\
            "provenanceDigest":"abc","recordedAt":"2026-11-23T12:00:00Z","sameVolume":true,"verdict":"helpful"}]
            """)
    }

    @Test("The export is the file's coding, pretty-printed, and both read back as the verdicts written")
    func theExportReadsBack() throws {
        let second = SemanticFeedbackEntry(
            recordedAt: Date(timeIntervalSince1970: 1_795_438_800), anchor: "frus1864p1/d147",
            neighbour: "frus1958-60v10p1/d5", verdict: .notHelpful,
            cosine: nil, era: nil, sameVolume: false, provenanceDigest: nil)
        let export = try SemanticFeedbackEntry.exportData([Self.entry, second])
        let text = String(decoding: export, as: UTF8.self)
        #expect(text.hasPrefix("[\n  {\n    \"anchor\" : \"frus1864p1\\/d147\",\n"), "got \(text.prefix(60))")
        #expect(try SemanticFeedbackEntry.entries(from: export) == [Self.entry, second])
        #expect(try SemanticFeedbackEntry.entries(from: try SemanticFeedbackEntry.fileData([Self.entry, second]))
                == [Self.entry, second])
    }

    @Test("A verdict written before a field existed reads, with the field absent; one without its pair does not")
    func decodingIsLenientButForThePairAndTheVerdict() throws {
        let early = Data("""
            [{"anchor":"frus1864p1/d147","neighbour":"frus1864p1/d148","recordedAt":"2026-08-20T09:30:00Z","verdict":"notHelpful"}]
            """.utf8)
        let read = try #require(try SemanticFeedbackEntry.entries(from: early).first)
        #expect(read.verdict == .notHelpful)
        #expect(read.cosine == nil && read.era == nil && read.sameVolume == nil && read.provenanceDigest == nil)
        let noNeighbour = Data("""
            [{"anchor":"frus1864p1/d147","recordedAt":"2026-08-20T09:30:00Z","verdict":"helpful"}]
            """.utf8)
        #expect(throws: DecodingError.self) { try SemanticFeedbackEntry.entries(from: noNeighbour) }
    }

    @Test("The verdicts' tokens and an entry's identity are what the file has always held")
    func theTokensAndTheIdentity() {
        #expect(SemanticFeedbackEntry.Verdict.allCases.map(\.rawValue) == ["helpful", "notHelpful"])
        #expect(Self.entry.id == "1795435200.0-frus1864p1/d147-frus1864p1/d148")
    }
}
