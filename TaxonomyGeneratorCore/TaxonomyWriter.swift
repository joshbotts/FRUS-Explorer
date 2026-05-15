// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Errors thrown by `TaxonomyWriter`.
public enum TaxonomyWriterError: Error, Sendable {
    case encodingFailed(String)
    case writeFailed(String)
}

/// Serialises a `[TagTaxonomyFileEntry]` array to a pretty-printed JSON file.
///
/// Output is sorted by `slug` for deterministic diffs between runs.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct TaxonomyWriter {

    private init() {}

    /// Writes a taxonomy to a JSON file at the given path.
    ///
    /// - Parameters:
    ///   - entries: The taxonomy entries to serialise.
    ///   - outputPath: File system path for the output JSON file.
    public static func write(entries: [TagTaxonomyFileEntry], to outputPath: String) throws {
        let sorted = entries.sorted { $0.slug < $1.slug }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(sorted)
        } catch {
            throw TaxonomyWriterError.encodingFailed(error.localizedDescription)
        }

        let url = URL(fileURLWithPath: outputPath)
        let directory = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw TaxonomyWriterError.writeFailed(error.localizedDescription)
        }

        #if DEBUG
        print("[TaxonomyGenerator] Wrote \(sorted.count) entries to \(outputPath)")
        #endif
    }
}
