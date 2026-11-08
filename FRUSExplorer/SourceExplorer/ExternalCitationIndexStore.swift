// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ExternalCitationIndexStore

/// Loads and caches the bundled `external-citation-index.json`.
///
/// `shared` is `nil` only when the resource is missing or cannot be decoded; consumers must treat
/// that as "footnote citations are unavailable", never as "this collection is never cited".
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`ExternalCitationIndex.swift`) and the kit never reads the app's bundle
enum ExternalCitationIndexStore {

    /// The bundled index, or `nil` when unavailable.
    static let shared: ExternalCitationIndex? = load()

    private static func load() -> ExternalCitationIndex? {
        guard let url = Bundle.main.url(forResource: "external-citation-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] ExternalCitationIndexStore: external-citation-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(ExternalCitationIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] ExternalCitationIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
