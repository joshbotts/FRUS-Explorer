// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SeriesFactsIndexStore

/// Loads the bundled series-creator index once, lazily.
///
/// `nil` means the feature degrades to what shipped before #405 — no creator line — never that a
/// series has no creator. The distinction matters here more than usual, because the honest answer
/// for most NAIDs *is* "not stated", and a silent load failure would be indistinguishable from it.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`SeriesFactsIndex.swift`) and the kit never reads the app's bundle
///   1.2 — 2026-11-11 (FRUS Explorer Light, S22c): `SeriesFactsIndex.facts(for:)` and `creatorName(for:)`
///          pass the two stores to the kit's forms, which take the indexes; their rule moved there whole
enum SeriesFactsIndexStore {

    /// The bundled index, or `nil` when the resource is missing or malformed.
    static let shared: SeriesFactsIndex? = load()

    private static func load() -> SeriesFactsIndex? {
        guard let url = Bundle.main.url(forResource: "series-facts-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] SeriesFactsIndexStore: series-facts-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(SeriesFactsIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] SeriesFactsIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Lookup with the app's own guards

extension SeriesFactsIndex {

    /// ``facts(for:centralFiles:seriesFacts:)``, FRUSCoreKit's, over the app's bundled central-files and
    /// series-facts indexes (`CentralFilesIndexStore`, `SeriesFactsIndexStore`); the second loads only
    /// once the guards pass, as it did when this function read both stores itself.
    static func facts(for entry: LotFileEntry) -> Facts? {
        facts(for: entry, centralFiles: CentralFilesIndexStore.shared, seriesFacts: SeriesFactsIndexStore.shared)
    }

    /// ``creatorName(for:centralFiles:seriesFacts:)``, FRUSCoreKit's, over the same two stores.
    static func creatorName(for entry: LotFileEntry) -> String? {
        creatorName(for: entry, centralFiles: CentralFilesIndexStore.shared, seriesFacts: SeriesFactsIndexStore.shared)
    }
}
