// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SourceProvenanceStore

/// Loads and holds the bundled `source-provenance-index.json` aggregate (Series
/// Analytics SA-3a), the offline data source for the "Archival Sourcing Over Time"
/// dashboard (SA-3b).
///
/// It mirrors the bundled-JSON loader pattern used by `CollectionAuthorityStore`
/// and `ManifestStore`: the resource is decoded from the app bundle once at init
/// into `index`. When the resource is missing or malformed, `index` is `nil`
/// (logged in DEBUG) — never a crash — and the dashboard degrades to its neutral
/// empty state. Because the aggregate is ~4.5 KB, decoding is synchronous at init.
///
/// The store is wired on `AppState` next to the other bundled-JSON stores, so the
/// dashboard reaches it through the environment.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
@Observable
@MainActor
final class SourceProvenanceStore {

    /// The decoded provenance aggregate, or `nil` if the bundled resource was
    /// absent or could not be decoded.
    let index: SourceProvenanceIndex?

    /// Loads and decodes `source-provenance-index.json` from the app bundle.
    ///
    /// A missing or malformed resource yields a `nil` `index` (logged in DEBUG)
    /// rather than trapping.
    init() {
        index = Self.load()
    }

    /// Injects a pre-built index — for tests and previews that need a known
    /// aggregate without touching the bundle.
    ///
    /// - Parameter index: The index to hold (may be `nil` to simulate the
    ///   missing-resource path).
    init(index: SourceProvenanceIndex?) {
        self.index = index
    }

    /// Decodes the bundled aggregate, or returns `nil` on any failure.
    private static func load() -> SourceProvenanceIndex? {
        guard let url = Bundle.main.url(forResource: "source-provenance-index", withExtension: "json") else {
            #if DEBUG
            print("[SourceProvenanceStore] source-provenance-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SourceProvenanceIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[SourceProvenanceStore] failed to decode source-provenance-index.json — \(error)")
            #endif
            return nil
        }
    }
}
