// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ProvenanceFlowIndexStore

/// Loads and caches the bundled `provenance-flow-index.json`.
///
/// `shared` is `nil` only when the resource is missing or cannot be decoded; consumers must treat
/// that as "reference flows are unavailable", never as "this collection references nothing".
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`ProvenanceFlowIndex.swift`) and the kit never reads the app's bundle
enum ProvenanceFlowIndexStore {

    /// The bundled flow index, or `nil` when unavailable.
    static let shared: ProvenanceFlowIndex? = load()

    private static func load() -> ProvenanceFlowIndex? {
        guard let url = Bundle.main.url(forResource: "provenance-flow-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] ProvenanceFlowIndexStore: provenance-flow-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(ProvenanceFlowIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] ProvenanceFlowIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
