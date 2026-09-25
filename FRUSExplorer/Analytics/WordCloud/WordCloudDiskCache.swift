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
/// **The count is not the whole fingerprint.** A re-index that rewrites the stored text keeps
/// every row, so the key it builds is the key an entry counted from the old text was saved under
/// (#1421 review: v59 re-joined 313,949 bodies). This cache does not decide reuse on its own —
/// `WordFrequencyService.isReusable(_:for:indexVersion:)` reads the entry's own `indexVersion`
/// stamp and counts again when the installed index has moved, writing the new count over the
/// same key.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 3 on-disk cache
///   1.1 — #1373 review round 3: ``mostRecent(lens:where:)`` takes the caller's own test of an
///          entry, so the settings bench can skip one whose tagger stamp it cannot trust; and
///          ``remove(key:)``, so a test that writes into this directory can take its entries out
///   1.2 — #1421 review: documents that the key's count fingerprint misses a re-index, and that
///          the entry's `indexVersion` stamp is what the service checks for it
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
    ///   - tuning: A token summarising the tunable criteria (`WordCloudTuning.cacheToken`).
    ///   - fingerprint: The index fingerprint (`documentCacheCount`).
    /// - Returns: A composite key string.
    static func key(
        signature: String, limit: Int, includeDiplomatic: Bool,
        extras: String = "", tuning: String = "", fingerprint: Int
    ) -> String {
        "\(signature)|n=\(limit)|diplo=\(includeDiplomatic)|x=\(extras)|t=\(tuning)|fp=\(fingerprint)"
    }

    /// Loads a cached result for `key`, or `nil` if none is stored.
    static func load(key: String) -> WordCloudResult? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode(WordCloudResult.self, from: data)
        else { return nil }
        return result
    }

    /// The most recently written cached cloud computed under `lens`.
    ///
    /// Filenames are SHA-256 digests, so the key — and with it the scope and tuning — is not
    /// recoverable from a cache file. This is deliberately a "some real cloud you looked at
    /// recently", not a specific one: the Word Cloud settings bench uses it as sample material
    /// to show what the current criteria would keep, and falls back to a canned list when there
    /// is nothing suitable.
    ///
    /// The lens filter is load-bearing, not a nicety. Whether a cloud is persisted depends on
    /// its **scope**, not its lens, so a subseries cloud viewed under People is written here
    /// like any other — and its terms are multi-word names ("united states"), which the word
    /// path rejects on sight for containing a space. Measuring one against `.allTerms` criteria
    /// would report a near-total drop that says nothing about the user's settings. Entries
    /// written before S-5b carry no lens stamp and are skipped for the same reason: unknown is
    /// not the same as safe.
    ///
    /// `qualifies` is the caller's own test, applied after the lens and the non-empty checks. The
    /// bench passes `WordFrequencyService.isReusable`, so an entry whose tagger stamp does not say
    /// it was counted as designed — one written before #1373, or counted without a lemmatiser — is
    /// skipped for the next newest rather than sampled (#1373 review round 3).
    ///
    /// Synchronous disk I/O: call it from a `.task`, never a view body.
    ///
    /// - Parameters:
    ///   - lens: The lens an entry must have been computed under to qualify.
    ///   - qualifies: Whether an entry that passed the lens check may be returned.
    /// - Returns: The newest qualifying entry, or `nil` when there is none.
    static func mostRecent(lens: WordCloudLens = .allTerms,
                           where qualifies: (WordCloudResult) -> Bool = { _ in true }) -> WordCloudResult? {
        guard let directory,
              let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])
        else { return nil }

        let newestFirst = entries
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> (URL, Date)? in
                guard let date = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate else { return nil }
                return (url, date)
            }
            .sorted { $0.1 > $1.1 }

        for (url, _) in newestFirst {
            if let data = try? Data(contentsOf: url),
               let result = try? JSONDecoder().decode(WordCloudResult.self, from: data),
               result.lens == lens,
               !result.terms.isEmpty,
               qualifies(result) {
                return result
            }
        }
        return nil
    }

    /// Saves `result` under `key`, overwriting any existing entry.
    static func save(_ result: WordCloudResult, key: String) {
        guard let url = fileURL(for: key),
              let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Removes the entry stored under `key`, if there is one.
    ///
    /// The app never needs it — an entry is superseded by a new fingerprint, not deleted — but a
    /// test writing into the host's real cache does: an entry it leaves behind is a file
    /// ``mostRecent(lens:where:)`` may later hand the settings bench as the reader's own cloud.
    static func remove(key: String) {
        guard let url = fileURL(for: key) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Maps a key to a filesystem-safe file URL via a SHA-256 digest. Internal rather than private
    /// so a test can set an entry's modification date, which is what ``mostRecent(lens:where:)``
    /// orders by.
    static func fileURL(for key: String) -> URL? {
        guard let directory else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(name).json")
    }
}
