// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeSubjectProfilesStore

/// Loads and caches the bundled `volume-subject-profiles-index.json`.
///
/// Decoded once, **lazily**, on first access — deliberately NOT at `AppState` init, unlike
/// the removed synchronous `SubjectTagStore`. `shared` is `nil` only when the resource is
/// missing or malformed (logged in DEBUG); the volume-detail "Top subjects" section then
/// simply does not appear. Mirrors ``VolumeSourcesIndexStore``.
///
/// Version history:
///   1.0 — Session 9: initial implementation
///   1.1 — FRUSCoreKit, part 2: moved from `VolumeSubjectProfiles.swift`, which the kit compiles;
///          the kit never reads a bundle
enum VolumeSubjectProfilesStore {

    /// The bundled volume-subject profiles, or `nil` if unavailable. Loaded once.
    static let shared: VolumeSubjectProfiles? = load()

    private static func load() -> VolumeSubjectProfiles? {
        guard let url = Bundle.main.url(forResource: "volume-subject-profiles-index", withExtension: "json") else {
            #if DEBUG
            print("[VolumeSubjectProfilesStore] volume-subject-profiles-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VolumeSubjectProfiles.self, from: data)
        } catch {
            #if DEBUG
            print("[VolumeSubjectProfilesStore] failed to decode volume-subject-profiles-index.json — \(error)")
            #endif
            return nil
        }
    }
}
