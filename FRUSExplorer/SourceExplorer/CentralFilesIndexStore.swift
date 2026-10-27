// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CentralFilesIndexStore

/// Loads and caches the bundled `central-files-index.json`.
///
/// The index is decoded once, lazily, on first access. `shared` is `nil` only when the
/// resource is missing or cannot be decoded (logged in DEBUG).
///
/// ## Static catalog links (no API key)
/// `numericalFileSeriesURL` and `cardIndexURL` are the fallbacks shown when a case falls
/// in a coverage gap or on the name/place-filed rolls that carry no case number.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
///   1.1 — 2026-10-27 (FRUS Explorer Light, S18b): in a file of its own, `CentralFilesIndexStore.swift`, since the
///          index it loads is FRUSCoreKit's and the kit never reads the app's bundle
enum CentralFilesIndexStore {

    /// The bundled Central Files index, or `nil` if unavailable. Loaded once.
    static let shared: CentralFilesIndex? = load()

    /// NARA Catalog record for the Numerical File series (M862, NAID 654171).
    static let numericalFileSeriesURL = URL(string: "https://catalog.archives.gov/id/654171")!

    /// NARA Catalog record for the Card Index to the Numerical File (M1889, NAID 656824),
    /// the finding aid that resolves names/subjects to case numbers.
    static let cardIndexURL = URL(string: "https://catalog.archives.gov/id/656824")!

    private static func load() -> CentralFilesIndex? {
        guard let url = Bundle.main.url(forResource: "central-files-index", withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CentralFilesIndexStore: central-files-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CentralFilesIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[SourceExplorer] CentralFilesIndexStore: failed to decode central-files-index.json — \(error)")
            #endif
            return nil
        }
    }
}
