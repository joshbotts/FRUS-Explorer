// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

/// Orchestrates the SourceNoteParser eval run over the `citations.csv` corpus.
///
/// Called from `SourceNoteEvalGenerator/main.swift`. Steps:
/// 1. Stream `citations.csv` (RFC-4180 with quoted TEI fields — `CSVReader`)
/// 2. Keep `citation_type == "source-note"` rows
/// 3. Normalize each note the way `IndexingPipeline` stores it post-Phase-1
///    (`NotePreparation.parserInput`)
/// 4. Run `SourceNoteParser.parse(_:)` and tally era × outcome (`EvalReport`)
/// 5. Write the deterministic diffable report
///
/// ## When to Run
/// Before and after every parser grammar change (Phase 2 work). Diff the fresh
/// report against the committed BEFORE snapshot `SourceNoteKit/eval-baseline.txt`;
/// a grammar change is justified when it moves notes out of `unrecognized` without
/// regressing other eras. Targets: unrecognized <10% for 1906–1963, <15% overall.
///
/// ## Environment
/// - `CITATIONS_CSV` — corpus path (default `~/Development/citations.csv`)
/// - `OUTPUT` — report path (default `eval-report.txt` in the working directory;
///   the committed baseline is a copy of this file)
///
/// Version history:
///   1.0 — Source Explorer Phase 2 (Session 2026-07-03): initial implementation
public struct SourceNoteEvalRunner {

    /// Default corpus location (the owner's local harvest; read-only).
    public static var defaultCSVPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Development/citations.csv").path
    }

    /// Default report output path, relative to the working directory.
    public static let defaultOutputPath = "eval-report.txt"

    /// Column indexes of `citations.csv`
    /// (`volume_id,citation_type,ancestor_id,xpath,plain_text,tei_xml`).
    private enum Column {
        static let volumeId = 0
        static let citationType = 1
        static let xpath = 3
        static let plainText = 4
        static let teiXML = 5
    }

    private init() {}

    /// Runs the eval and writes the report.
    ///
    /// - Parameters:
    ///   - csvPath: Corpus csv path.
    ///   - outputPath: Where to write the report.
    /// - Returns: The rendered report text (also written to `outputPath`).
    @discardableResult
    public static func run(
        csvPath: String = defaultCSVPath,
        outputPath: String = defaultOutputPath
    ) throws -> String {
        print("[SourceNoteEvalGenerator] Corpus: \(csvPath)")
        let parser = SourceNoteParser()
        var report = EvalReport()
        var rowIndex = 0
        var noteRows = 0

        try CSVReader.forEachRecord(in: URL(fileURLWithPath: csvPath)) { row in
            defer { rowIndex += 1 }
            guard rowIndex > 0 else { return true }  // header
            guard row.count > Column.teiXML,
                  row[Column.citationType] == "source-note" else { return true }
            noteRows += 1
            let input = NotePreparation.parserInput(
                plainText: row[Column.plainText],
                teiXML: row[Column.teiXML],
                xpath: row[Column.xpath]
            )
            let outcome = EvalOutcome(parsed: parser.parse(input))
            report.record(volumeId: row[Column.volumeId],
                          outcome: outcome,
                          parserInput: input)
            if noteRows % 50_000 == 0 {
                print("[SourceNoteEvalGenerator]   …\(noteRows) notes evaluated")
            }
            return true
        }

        let corpusName = (csvPath as NSString).lastPathComponent
        let text = report.render(
            corpusDescription: "\(corpusName) (citation_type='source-note', \(noteRows) rows)"
        )
        try text.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("[SourceNoteEvalGenerator] ✓ \(noteRows) notes → \(outputPath)")
        printSummary(report)
        return text
    }

    /// Prints the headline unrecognized rates to stdout.
    private static func printSummary(_ report: EvalReport) {
        var grandTotal = 0
        var grandUnrec = 0
        for era in EraBucket.allCases {
            let total = report.total(for: era)
            guard total > 0 else { continue }
            let unrec = report.count(for: era, outcome: .unrecognized)
            grandTotal += total
            grandUnrec += unrec
            printRate(label: era.label, unrecognized: unrec, total: total)
        }
        if grandTotal > 0 {
            printRate(label: "OVERALL", unrecognized: grandUnrec, total: grandTotal)
        }
    }

    /// Prints one aligned unrecognized-rate line.
    private static func printRate(label: String, unrecognized: Int, total: Int) {
        let padded = label.padding(toLength: max(10, label.count), withPad: " ", startingAt: 0)
        let pct = Double(unrecognized) * 100 / Double(total)
        print("[SourceNoteEvalGenerator]   \(padded)"
              + String(format: " unrecognized %6d/%6d (%.1f%%)", unrecognized, total, pct))
    }
}
