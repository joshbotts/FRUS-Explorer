// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Builds the bundled `volume-subject-profiles-index.json` (Wave-6 Session 9): reads
/// the Office of the Historian's public-domain `frus-subjects` document–subject
/// mappings and aggregates a per-volume "top subjects" profile.
///
/// Entirely offline and deterministic. Configuration (environment variables):
/// - `DOCUMENT_SUBJECTS` — the input `document_subjects.json`
///   (default `/Users/jbotts/Development/frus-subjects/data/document_subjects.json`)
/// - `OUTPUT` — output path
///   (default `FRUSExplorer/Resources/volume-subject-profiles-index.json`)
/// - `GENERATED_DATE` — override the `generated` stamp (default: today, `yyyy-MM-dd`, UTC)
/// - `GENERICITY_THRESHOLD` / `MIN_DOC_COUNT` / `TOP_N` — override the scoring parameters
public enum VolumeSubjectProfilesRunner {

    /// The artifact schema version this runner emits.
    public static let schemaVersion = 1

    /// Runs the generator.
    ///
    /// - Throws: `RunError` on a missing input, or any file/decoding error.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let inputPath = env["DOCUMENT_SUBJECTS"]
            ?? "/Users/jbotts/Development/frus-subjects/data/document_subjects.json"
        let outputPath = env["OUTPUT"]
            ?? "FRUSExplorer/Resources/volume-subject-profiles-index.json"
        let generated = env["GENERATED_DATE"] ?? today()

        let parameters = ProfileAggregator.Parameters(
            genericityThreshold: env["GENERICITY_THRESHOLD"].flatMap(Double.init) ?? 0.10,
            minDocCount: env["MIN_DOC_COUNT"].flatMap(Int.init) ?? 2,
            topN: env["TOP_N"].flatMap(Int.init) ?? 15
        )

        let inputURL = URL(fileURLWithPath: inputPath)
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw RunError.missingInput(inputPath)
        }
        let input = try DocumentSubjectsInput.load(from: inputURL)
        log("Loaded \(input.subjects.count) subjects from \(inputPath) (source generated \(input.generated))")

        let provenance = """
        Derived from the Office of the Historian public-domain frus-subjects handoff \
        (document_subjects.json, source generated \(input.generated)) by \
        VolumeSubjectProfilesGenerator. Per-volume TF-IDF-style top-\(parameters.topN) subjects; \
        genericity threshold \(parameters.genericityThreshold) of tagged corpus documents; \
        minimum \(parameters.minDocCount) documents per subject per volume.
        """

        let (index, stats) = ProfileAggregator.aggregate(
            input: input,
            parameters: parameters,
            schemaVersion: schemaVersion,
            generated: generated,
            provenance: provenance)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(index).write(to: URL(fileURLWithPath: outputPath))

        // Correctness guard: every profile row must reference a valid vocab index.
        let vocabCount = index.vocab.count
        for profile in index.profiles {
            for entry in profile.entries {
                precondition(entry.vocabIndex >= 0 && entry.vocabIndex < vocabCount,
                             "profile \(profile.volumeId) references out-of-range vocab index \(entry.vocabIndex)")
            }
        }

        log("""
        volume-subject-profiles-index.json written to \(outputPath)
          corpus tagged documents:  \(stats.corpusDistinctDocs)
          generic subjects dropped: \(stats.genericSubjectCount)
          vocabulary subjects used: \(stats.usedSubjectCount)
          volumes with a profile:   \(stats.volumeCount)
        """)
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

    /// Errors thrown by the runner.
    public enum RunError: Error, CustomStringConvertible {
        /// The `document_subjects.json` input was not found.
        case missingInput(String)
        public var description: String {
            switch self {
            case .missingInput(let path): return "document_subjects.json not found at \(path)"
            }
        }
    }
}
