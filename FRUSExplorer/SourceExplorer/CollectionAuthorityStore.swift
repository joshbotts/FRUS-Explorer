// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionAuthorityStore

/// Loads and caches the bundled `collection-authority.json`.
///
/// The index is decoded once, lazily, on first access; views warm it off the main
/// thread before their first per-row lookup (`Task.detached { _ = shared }` — the
/// `VolumeSourcesIndexStore` pattern). `shared` is `nil` only when the resource is
/// missing or cannot be decoded (logged in DEBUG).
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): initial implementation
///   1.1 — Session 2026-07-04 (Phase 4 verification): alias/segment lookups use the
///          plural-folded `CollectionKeying.segmentNorm`
///   1.2 — Session 2026-07-04 (Phase 4 adversarial review): lookup step 3 (the
///          unattributed bucket) is guarded — generic segments never bridge, and the
///          unattributed record must be the sole text record carrying the segment
///   1.3 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`CollectionAuthority.swift`) and the kit never reads the app's bundle
enum CollectionAuthorityStore {

    /// The bundled collection authority, or `nil` if unavailable. Loaded once.
    static let shared: CollectionAuthorityIndex? = load()

    private static func load() -> CollectionAuthorityIndex? {
        guard let url = Bundle.main.url(forResource: "collection-authority", withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CollectionAuthorityStore: collection-authority.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CollectionAuthorityIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[SourceExplorer] CollectionAuthorityStore: failed to decode collection-authority.json — \(error)")
            #endif
            return nil
        }
    }
}
