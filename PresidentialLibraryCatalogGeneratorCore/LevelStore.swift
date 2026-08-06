// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LevelStore

/// The on-disk store for one (library, level) slice of the harvest.
///
/// Three files, and the third is the point:
/// - `<LIB>-<level>.ndjson` — one record per line, **appended** as pages arrive.
/// - `<LIB>-<level>.cursor` — where to resume if the run stops.
/// - `<LIB>-<level>.done` — written only after the completeness check passes.
///
/// NDJSON rather than a JSON array because the file-unit levels run to ~224,000 records for a
/// single library. An array has to be held whole to be written or read; lines do not. That is
/// the same failure the record-group harvester documents as an 18.5 GB peak.
///
/// A store with no `.done` is **known-partial**. Nothing reads it as complete, and the harvest
/// resumes into it rather than starting over — which matters when `DEPTH=all` is a run of nearly
/// a million records.
struct LevelStore {

    let cacheDir: URL
    let library: String
    let level: String

    private var stem: URL { cacheDir.appending(path: "\(library)-\(level)") }
    private var data: URL { stem.appendingPathExtension("ndjson") }
    private var cursorFile: URL { stem.appendingPathExtension("cursor") }
    private var doneFile: URL { stem.appendingPathExtension("done") }

    /// Whether this slice finished and passed its completeness check.
    var isComplete: Bool { FileManager.default.fileExists(atPath: doneFile.path) }

    /// The cursor an interrupted run left behind, or `nil` to start from the beginning.
    var savedCursor: String? {
        guard !isComplete, let raw = try? String(contentsOf: cursorFile, encoding: .utf8) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Clears any partial data so a fresh run does not append to it.
    func reset() throws {
        for url in [data, cursorFile, doneFile] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Appends a page and records the cursor that follows it, in that order — so a crash between
    /// the two costs a repeated page on resume rather than a silently skipped one.
    func append(_ page: [[String: Any]], cursor: String?) throws {
        var buffer = Data()
        for record in page {
            buffer.append(try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]))
            buffer.append(0x0A)
        }
        if FileManager.default.fileExists(atPath: data.path) {
            let handle = try FileHandle(forWritingTo: data)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: buffer)
        } else {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            try buffer.write(to: data)
        }
        if let cursor { try Data(cursor.utf8).write(to: cursorFile) }
    }

    /// Marks the slice complete. Called only after the count matched NARA's stated total.
    func markComplete() throws {
        try Data("ok".utf8).write(to: doneFile)
        try? FileManager.default.removeItem(at: cursorFile)
    }

    /// How many records are stored, counted without decoding them.
    func count() throws -> Int {
        guard FileManager.default.fileExists(atPath: data.path) else { return 0 }
        var lines = 0
        let handle = try FileHandle(forReadingFrom: data)
        defer { try? handle.close() }
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            lines += chunk.filter { $0 == 0x0A }.count
        }
        return lines
    }

    /// Decodes the whole slice. Only used for `collection` and `series`, which are small; the
    /// deeper levels are left on disk for whatever later question wants them.
    func load() throws -> [[String: Any]] {
        guard FileManager.default.fileExists(atPath: data.path) else { return [] }
        let text = try String(contentsOf: data, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: true).compactMap {
            (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any]
        }
    }
}
