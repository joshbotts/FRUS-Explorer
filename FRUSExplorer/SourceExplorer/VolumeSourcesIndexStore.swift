// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeSourcesIndexStore

/// Loads and caches the bundled `volume-sources-index.json`.
///
/// The index is decoded once, lazily, on first access. `shared` is `nil` only when the
/// resource is missing or cannot be decoded (logged in DEBUG). Mirrors
/// ``CentralFilesIndexStore``.
///
/// Version history:
///   1.0 — Session 2026-07-01: initial implementation
///   1.1 — 2026-10-27 (FRUS Explorer Light, S18b): in a file of its own, `VolumeSourcesIndexStore.swift`, since the
///          index it loads is FRUSCoreKit's and the kit never reads the app's bundle
enum VolumeSourcesIndexStore {

    /// The bundled volume-sources resolution index, or `nil` if unavailable. Loaded once.
    static let shared: VolumeSourcesIndex? = load()

    private static func load() -> VolumeSourcesIndex? {
        guard let url = Bundle.main.url(forResource: "volume-sources-index", withExtension: "json") else {
            #if DEBUG
            print("[Browser] VolumeSourcesIndexStore: volume-sources-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VolumeSourcesIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[Browser] VolumeSourcesIndexStore: failed to decode volume-sources-index.json — \(error)")
            #endif
            return nil
        }
    }
}
