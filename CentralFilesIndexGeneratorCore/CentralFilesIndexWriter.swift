// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Errors thrown by `CentralFilesIndexWriter`.
public enum CentralFilesIndexWriterError: Error, Sendable {
    case encodingFailed(String)
    case writeFailed(String)
}

/// Serialises a `CentralFilesIndex` to a pretty-printed, deterministically-ordered
/// JSON file (sorted keys; rolls already sorted by `caseStart`) so git diffs between
/// harvests stay readable.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
public enum CentralFilesIndexWriter {

    /// Writes the index to `outputPath`, creating intermediate directories.
    public static func write(_ index: CentralFilesIndex, to outputPath: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(index)
        } catch {
            throw CentralFilesIndexWriterError.encodingFailed(error.localizedDescription)
        }

        let url = URL(fileURLWithPath: outputPath)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw CentralFilesIndexWriterError.writeFailed(error.localizedDescription)
        }
    }
}
