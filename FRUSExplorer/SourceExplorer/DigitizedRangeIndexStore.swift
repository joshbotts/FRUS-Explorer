// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DigitizedRangeIndexStore

/// Loads the bundled `digitized-ranges-index.json` once, mirroring the other Source Explorer
/// stores. `nil` when the resource is absent or malformed — in which case the surfaces simply
/// show nothing extra, as before.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663, with the index
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`DigitizedRangeIndex.swift`) and the kit never reads the app's bundle
enum DigitizedRangeIndexStore {
    static let shared: DigitizedRangeIndex? = load()

    private static func load() -> DigitizedRangeIndex? {
        guard let url = Bundle.main.url(forResource: "digitized-ranges-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] DigitizedRangeIndexStore: resource not found in bundle.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(DigitizedRangeIndex.self,
                                            from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] DigitizedRangeIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
