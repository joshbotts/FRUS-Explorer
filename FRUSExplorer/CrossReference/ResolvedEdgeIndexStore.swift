// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ResolvedEdgeIndexStore

/// Loads and caches the bundled `resolved-edge-index.json`.
///
/// `shared` is `nil` only when the resource is missing or cannot be decoded. Consumers must treat
/// that as "corpus-wide citations are unavailable" and fall back to the local table — never as
/// "nothing else cites this document".
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
///   1.1 — 2026-11-10 (FRUS Explorer Light, S23b): in a file of its own, unchanged, when
///          `ResolvedEdgeIndex` moved into FRUSCoreKit, which never reads the bundle; the app's
///          `CrossReferenceStore` initialiser passes it (`CrossReferenceStore+App.swift`)
enum ResolvedEdgeIndexStore {

    /// The bundled index, or `nil` when unavailable.
    static let shared: ResolvedEdgeIndex? = load()

    private static func load() -> ResolvedEdgeIndex? {
        guard let url = Bundle.main.url(forResource: "resolved-edge-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[CrossReference] ResolvedEdgeIndexStore: resolved-edge-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(ResolvedEdgeIndex.self, from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[CrossReference] ResolvedEdgeIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
