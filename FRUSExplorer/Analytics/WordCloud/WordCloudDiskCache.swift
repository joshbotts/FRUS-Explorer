// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
import Foundation

/// Persists expensive word-cloud results (corpus and large subseries) to disk so
/// they survive relaunch and need not be recomputed every time the view opens.
///
/// Entries live under `Library/Caches/WordCloud/` as JSON. The cache key folds in
/// the scope signature, stopword policy, term limit, and an index fingerprint
/// (the `document_cache` row count), so a stored result is only reused while it
/// remains valid; adding or removing indexed volumes changes the fingerprint and
/// the old file is simply never read again. Being in `Caches`, the OS may purge
/// entries under storage pressure — that only triggers a recompute, never
/// incorrect data.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 3 on-disk cache
enum WordCloudDiskCache {

    /// Directory holding cached word-cloud JSON files.
    private static var directory: URL? {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = caches.appendingPathComponent("WordCloud", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Builds a stable cache key from the scope and parameters.
    ///
    /// - Parameters:
    ///   - signature: The scope signature (`WordCloudScope.signature`).
    ///   - limit: The requested term limit.
    ///   - includeDiplomatic: Whether the diplomatic stopword layer is active.
    ///   - extras: A token summarising any per-scope extra stopwords.
    ///   - fingerprint: The index fingerprint (`documentCacheCount`).
    /// - Returns: A composite key string.
    static func key(
        signature: String, limit: Int, includeDiplomatic: Bool,
        extras: String = "", fingerprint: Int
    ) -> String {
        "\(signature)|n=\(limit)|diplo=\(includeDiplomatic)|x=\(extras)|fp=\(fingerprint)"
    }

    /// Loads a cached result for `key`, or `nil` if none is stored.
    static func load(key: String) -> WordCloudResult? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode(WordCloudResult.self, from: data)
        else { return nil }
        return result
    }

    /// Saves `result` under `key`, overwriting any existing entry.
    static func save(_ result: WordCloudResult, key: String) {
        guard let url = fileURL(for: key),
              let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Maps a key to a filesystem-safe file URL via a SHA-256 digest.
    private static func fileURL(for key: String) -> URL? {
        guard let directory else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(name).json")
    }
}
