// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CuratedLibraryResolutionsStore

/// Loads the bundled curated library resolutions once, mirroring `CuratedLotResolutionsStore`.
///
/// Version history:
///   1.0 — Session 2026-08-06: #355 / N-4
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`CuratedLibraryResolutions.swift`) and the kit never reads the app's bundle
enum CuratedLibraryResolutionsStore {

    /// The bundled entries, or `nil` when the resource is missing or malformed — in which case
    /// the app degrades to the repository-level fallback, which is vague but not wrong.
    static let shared: CuratedLibraryResolutions? = load()

    private static func load() -> CuratedLibraryResolutions? {
        guard let url = Bundle.main.url(forResource: "curated-library-resolutions",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CuratedLibraryResolutionsStore: curated-library-resolutions.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(CuratedLibraryResolutions.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] CuratedLibraryResolutionsStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
