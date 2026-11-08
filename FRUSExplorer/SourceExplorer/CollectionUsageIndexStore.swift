// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionUsageIndexStore

/// Loads and caches the bundled `collection-usage-index.json`.
///
/// Lazy and load-once, like every sibling index store. `shared` is `nil` only when the resource
/// is missing or cannot be decoded — every consumer must treat that as "document weights are
/// unavailable" and fall back to the volume-grain counts the authority already carries, never as
/// "this collection supplies no documents".
///
/// Version history:
///   1.0 — Session 2026-08-08: #763
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`CollectionUsageIndex.swift`) and the kit never reads the app's bundle
enum CollectionUsageIndexStore {

    /// The bundled usage index, or `nil` when unavailable.
    static let shared: CollectionUsageIndex? = load()

    private static func load() -> CollectionUsageIndex? {
        guard let url = Bundle.main.url(forResource: "collection-usage-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CollectionUsageIndexStore: collection-usage-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(CollectionUsageIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] CollectionUsageIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
