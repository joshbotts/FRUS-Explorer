// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RollScansIndexStore

/// Loads the bundled `roll-scans-index.json` once. `nil` when the resource is absent or
/// malformed — in which case the pre-1910 section renders exactly as it did before, with the
/// catalog links and no PDF buttons.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663 follow-up, with the index
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`RollScansIndex.swift`) and the kit never reads the app's bundle
enum RollScansIndexStore {
    static let shared: RollScansIndex? = load()

    private static func load() -> RollScansIndex? {
        guard let url = Bundle.main.url(forResource: "roll-scans-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] RollScansIndexStore: resource not found in bundle.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(RollScansIndex.self, from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] RollScansIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
