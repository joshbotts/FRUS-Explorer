// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - POCOMIndexStore

/// Loads the bundled `pocom-index.json` once, lazily.
///
/// `nil` only when the resource is absent from the bundle or malformed — in which case the Career
/// section does not appear and Source Explorer's addressee rule decides nothing. The unit tests are
/// app-hosted (`TEST_HOST`), so the store loads there too.
///
/// Version history:
///   1.0 — Session 2026-08-07: #736
///   1.1 — 2026-11-10 (FRUS Explorer Light, S22b): in a file of its own, since the index it loads is
///          FRUSCoreKit's (`FRUSCoreKit/Models/POCOMIndex.swift`) and the kit never reads the app's bundle;
///          with `ChiefsOfMissionRoster.bundled`, the roster this store's index describes
enum POCOMIndexStore {
    static let shared: POCOMIndex? = load()

    private static func load() -> POCOMIndex? {
        guard let url = Bundle.main.url(forResource: "pocom-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[POCOMIndex] pocom-index.json not found in bundle")
            #endif
            return nil
        }
        do {
            let index = try JSONDecoder().decode(POCOMIndex.self, from: data)
            #if DEBUG
            print("[POCOMIndex] loaded \(index.careers.count) careers (generated \(index.generated))")
            #endif
            return index
        } catch {
            #if DEBUG
            print("[POCOMIndex] decode failed: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - ChiefsOfMissionRoster.bundled

extension ChiefsOfMissionRoster {

    /// The roster read from the bundled `pocom-index.json`. Empty when the file is absent, or is a
    /// version-1 file with no `chiefs` table — in which case the rule decides nothing.
    static let bundled = ChiefsOfMissionRoster(index: POCOMIndexStore.shared)
}
