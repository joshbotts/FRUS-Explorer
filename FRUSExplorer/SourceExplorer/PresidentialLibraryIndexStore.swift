// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PresidentialLibraryIndexStore

/// Loads the bundled catalogue once, mirroring the other Source Explorer stores.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681, with the catalogue's reader
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`PresidentialLibraryIndex.swift`) and the kit never reads the app's bundle
enum PresidentialLibraryIndexStore {

    /// The bundled index, or `nil` when the resource is absent or malformed — in which case the
    /// app falls back to the curated finding aids and the live query, as before.
    static let shared: PresidentialLibraryIndex? = load()

    private static func load() -> PresidentialLibraryIndex? {
        guard let url = Bundle.main.url(forResource: "presidential-library-catalog",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] PresidentialLibraryIndexStore: catalog not found in bundle.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(PresidentialLibraryIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] PresidentialLibraryIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
