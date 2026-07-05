// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AdministrationProfilesStore

/// Loads and holds the bundled `administration-profiles-index.json` aggregate
/// (Series Analytics SA-2a), the offline data source for the "Administration
/// Profiles" dashboard (SA-2b).
///
/// It mirrors the bundled-JSON loader pattern used by `SourceProvenanceStore` and
/// `ManifestStore`: the resource is decoded from the app bundle once at init into
/// `index`. When the resource is missing or malformed, `index` is `nil` (logged in
/// DEBUG) — never a crash — and the dashboard degrades to its neutral empty state.
///
/// The store is wired on `AppState` next to `sourceProvenanceStore`, so the
/// dashboard reaches it through the environment.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
@Observable
@MainActor
final class AdministrationProfilesStore {

    /// The decoded administration-profiles aggregate, or `nil` if the bundled
    /// resource was absent or could not be decoded.
    let index: AdministrationProfilesIndex?

    /// Loads and decodes `administration-profiles-index.json` from the app bundle.
    ///
    /// A missing or malformed resource yields a `nil` `index` (logged in DEBUG)
    /// rather than trapping.
    init() {
        index = Self.load()
    }

    /// Injects a pre-built index — for tests and previews that need a known
    /// aggregate without touching the bundle.
    ///
    /// - Parameter index: The index to hold (may be `nil` to simulate the
    ///   missing-resource path).
    init(index: AdministrationProfilesIndex?) {
        self.index = index
    }

    /// Decodes the bundled aggregate, or returns `nil` on any failure.
    private static func load() -> AdministrationProfilesIndex? {
        guard let url = Bundle.main.url(forResource: "administration-profiles-index", withExtension: "json") else {
            #if DEBUG
            print("[AdministrationProfilesStore] administration-profiles-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AdministrationProfilesIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[AdministrationProfilesStore] failed to decode administration-profiles-index.json — \(error)")
            #endif
            return nil
        }
    }
}
