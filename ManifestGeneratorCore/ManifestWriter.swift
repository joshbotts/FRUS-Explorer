// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Errors thrown by `ManifestWriter`.
public enum ManifestWriterError: Error, Sendable {
    case encodingFailed(String)
    case writeFailed(String)
}

/// Serialises a `[VolumeManifestEntry]` array to a pretty-printed JSON file.
///
/// Output is sorted by `volumeId` for deterministic diffs between releases.
/// Pretty-printing keeps git diffs readable when individual volume metadata changes.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct ManifestWriter {

    private init() {}

    /// Writes a manifest to a JSON file at the given path.
    ///
    /// Creates intermediate directories if they do not exist.
    /// Sorted by `volumeId` for deterministic git diffs.
    ///
    /// - Parameters:
    ///   - entries: The manifest entries to serialise.
    ///   - outputPath: File system path for the output JSON file.
    public static func write(entries: [VolumeManifestEntry], to outputPath: String) throws {
        let sorted = entries.sorted { $0.volumeId < $1.volumeId }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(sorted)
        } catch {
            throw ManifestWriterError.encodingFailed(error.localizedDescription)
        }

        let url = URL(fileURLWithPath: outputPath)
        let directory = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw ManifestWriterError.writeFailed(error.localizedDescription)
        }

        #if DEBUG
        print("[ManifestGenerator] Wrote \(sorted.count) entries to \(outputPath)")
        #endif
    }
}
