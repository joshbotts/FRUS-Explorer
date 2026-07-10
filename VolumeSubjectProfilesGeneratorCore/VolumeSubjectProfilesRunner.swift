// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
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
///   (a present-but-unparseable value fails loudly rather than silently defaulting)
///
/// Version history:
///   1.0 — Session 9: initial implementation
///   1.1 — Session 9 review: provenance pins the source drop's MD5 (refs are stable
///         only within a drop); vocab-index guard runs before the write; malformed
///         parameter env vars throw instead of silently defaulting; compact encoding
public enum VolumeSubjectProfilesRunner {

    /// The artifact schema version this runner emits.
    public static let schemaVersion = 1

    /// Runs the generator.
    ///
    /// - Throws: `RunError` on a missing input or malformed parameter env var, or any
    ///   file/decoding error.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let inputPath = env["DOCUMENT_SUBJECTS"]
            ?? "/Users/jbotts/Development/frus-subjects/data/document_subjects.json"
        let outputPath = env["OUTPUT"]
            ?? "FRUSExplorer/Resources/volume-subject-profiles-index.json"
        let generated = env["GENERATED_DATE"] ?? today()

        let parameters = ProfileAggregator.Parameters(
            genericityThreshold: try parse(env, "GENERICITY_THRESHOLD", Double.init) ?? 0.10,
            minDocCount: try parse(env, "MIN_DOC_COUNT", Int.init) ?? 2,
            topN: try parse(env, "TOP_N", Int.init) ?? 15
        )

        let inputURL = URL(fileURLWithPath: inputPath)
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw RunError.missingInput(inputPath)
        }
        // Read the raw bytes once: the MD5 pins the exact source drop in the provenance
        // (the plan's requirement — the upstream's ~95 synthetic refs are re-minted per
        // export, so two drops with the same internal `generated` date can still carry
        // different ref identities; only a content hash distinguishes them).
        let inputData = try Data(contentsOf: inputURL)
        let inputMD5 = Insecure.MD5.hash(data: inputData).map { String(format: "%02x", $0) }.joined()
        let input = try DocumentSubjectsInput.load(from: inputData)
        log("Loaded \(input.subjects.count) subjects from \(inputPath) (source generated \(input.generated), md5 \(inputMD5))")

        let provenance = """
        Derived from the Office of the Historian public-domain frus-subjects handoff \
        (document_subjects.json, source generated \(input.generated), \
        md5 \(inputMD5)) by VolumeSubjectProfilesGenerator. \
        Per-volume TF-IDF-style top-\(parameters.topN) subjects; \
        genericity threshold \(parameters.genericityThreshold) of tagged corpus documents; \
        minimum \(parameters.minDocCount) documents per subject per volume.
        """

        let (index, stats) = ProfileAggregator.aggregate(
            input: input,
            parameters: parameters,
            schemaVersion: schemaVersion,
            generated: generated,
            provenance: provenance)

        // Correctness guard BEFORE the write: every profile row must reference a valid
        // vocab index — a failed run must not leave a corrupt artifact on disk.
        let vocabCount = index.vocab.count
        for profile in index.profiles {
            for entry in profile.entries {
                precondition(entry.vocabIndex >= 0 && entry.vocabIndex < vocabCount,
                             "profile \(profile.volumeId) references out-of-range vocab index \(entry.vocabIndex)")
            }
        }

        // Compact encoding (sortedKeys only): the artifact ships in the app bundle, and
        // pretty-printing alone quadruples it (624 KB vs ~144 KB) past the plan's
        // 100–300 KB target. Determinism comes from sortedKeys + the aggregator's
        // explicit total-order sorts, not from the whitespace.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(index).write(to: URL(fileURLWithPath: outputPath))

        log("""
        volume-subject-profiles-index.json written to \(outputPath)
          corpus tagged documents:  \(stats.corpusDistinctDocs)
          generic subjects dropped: \(stats.genericSubjectCount)
          vocabulary subjects used: \(stats.usedSubjectCount)
          volumes with a profile:   \(stats.volumeCount)
        """)
    }

    // MARK: - Helpers

    /// Parses an optional env var with `transform`, throwing when the variable is
    /// present but unparseable (a typo must fail the run, not silently regenerate the
    /// artifact with default parameters).
    ///
    /// - Parameters:
    ///   - env: The process environment.
    ///   - key: The variable name.
    ///   - transform: The string-to-value parser (e.g. `Double.init`).
    /// - Returns: The parsed value, or `nil` when the variable is absent.
    /// - Throws: `RunError.invalidParameter` when present but unparseable.
    private static func parse<T>(
        _ env: [String: String], _ key: String, _ transform: (String) -> T?
    ) throws -> T? {
        guard let raw = env[key] else { return nil }
        guard let value = transform(raw) else { throw RunError.invalidParameter(key, raw) }
        return value
    }

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
        /// A parameter env var was set but could not be parsed.
        case invalidParameter(String, String)
        public var description: String {
            switch self {
            case .missingInput(let path):
                return "document_subjects.json not found at \(path)"
            case .invalidParameter(let key, let raw):
                return "environment variable \(key) is set to unparseable value '\(raw)'"
            }
        }
    }
}
