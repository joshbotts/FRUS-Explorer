// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CuratedLotResolutionsStore

/// Loads the bundled curated lot outcomes once, mirroring `CentralFilesIndexStore`.
///
/// Version history:
///   1.0 — Session 2026-08-03: #375 curated lot outcomes (N-3)
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`CuratedLotResolutions.swift`) and the kit never reads the app's bundle
enum CuratedLotResolutionsStore {

    /// The bundled curated outcomes, or `nil` when the resource is missing or malformed.
    /// A `nil` store degrades to the pre-curation behaviour, which is honest rather than wrong.
    static let shared: CuratedLotResolutions? = load()

    private static func load() -> CuratedLotResolutions? {
        guard let url = Bundle.main.url(forResource: "curated-lot-resolutions",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CuratedLotResolutionsStore: curated-lot-resolutions.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CuratedLotResolutions.self, from: data)
        } catch {
            #if DEBUG
            print("[SourceExplorer] CuratedLotResolutionsStore: failed to decode curated-lot-resolutions.json — \(error)")
            #endif
            return nil
        }
    }
}
