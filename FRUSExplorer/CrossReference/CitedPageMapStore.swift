// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitedPageMapStore

/// Lazily loads the bundled `cited-page-map.json` once (A18b, index version 71): the documents on
/// every printed page of another volume the corpus cites, which the indexer's store pass reads
/// through `IndexingResources.bundled` to store a reference to such a page against the document on
/// it (`IndexingPipeline.resolveCrossVolumePageReferences`).
///
/// Nil-tolerant, as `BrokenRefsIndexStore` is: a missing or corrupt resource yields `nil`, and the
/// pipeline then leaves every such reference on the volume (`pg_N`), as every index before 71 did —
/// never a crash. Loaded on first use, which is the first volume's store pass after launch; the
/// decode is a 0.5 MB JSON parse, so no warm-up task is needed. The kit is given the map and never
/// reads the bundle (FRUSCoreKitBoundaryTests).
///
/// Version history:
///   1.0 — A18b: initial implementation
enum CitedPageMapStore {

    /// The bundled map, or `nil` if unavailable. Loaded once.
    static let shared: CitedPageMap? = load()

    private static func load() -> CitedPageMap? {
        guard let url = Bundle.main.url(forResource: "cited-page-map", withExtension: "json") else {
            #if DEBUG
            print("[CitedPageMapStore] cited-page-map.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CitedPageMap.self, from: data)
        } catch {
            #if DEBUG
            print("[CitedPageMapStore] failed to decode cited-page-map.json — \(error)")
            #endif
            return nil
        }
    }
}
