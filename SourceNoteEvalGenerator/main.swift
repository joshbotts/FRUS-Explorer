// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteEvalGeneratorCore

/// SourceNoteEvalGenerator entry point.
///
/// Runs `SourceNoteParser` over every `citation_type='source-note'` row of the
/// offline `citations.csv` eval corpus and writes a deterministic, diffable
/// classification-rate report bucketed by FRUS era. Run before and after every
/// parser grammar change and diff against the committed BEFORE snapshot
/// `SourceNoteKit/eval-baseline.txt`:
/// ```
/// swift run SourceNoteEvalGenerator
/// diff SourceNoteKit/eval-baseline.txt eval-report.txt
/// ```
///
/// Optional environment variables:
///   CITATIONS_CSV — corpus path (default ~/Development/citations.csv)
///   OUTPUT        — report path (default ./eval-report.txt)
///   DUMP          — per-note dump path (outcome/era/input per row, corpus order)
///                   for positional before/after regression diffing
let env = ProcessInfo.processInfo.environment
do {
    try SourceNoteEvalRunner.run(
        csvPath: env["CITATIONS_CSV"] ?? SourceNoteEvalRunner.defaultCSVPath,
        outputPath: env["OUTPUT"] ?? SourceNoteEvalRunner.defaultOutputPath,
        dumpPath: env["DUMP"]
    )
} catch {
    print("[SourceNoteEvalGenerator] ✗ \(error)")
    exit(1)
}
