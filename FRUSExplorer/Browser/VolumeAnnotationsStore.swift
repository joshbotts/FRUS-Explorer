// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeAnnotationsStore

/// Loads and caches the bundled `volume-annotations-index.json`: what editorial annotation each
/// catalogue volume carries, for the volume page's "Editors' Annotations" section and the Browse
/// axis of the same name (`Planning/Editors-Annotations-Design-2026-11-06.md`).
///
/// Decoded once, **lazily**, on first access, as ``VolumeSubjectProfilesStore`` is. `shared` is
/// `nil` only when the resource is missing or malformed (logged in DEBUG). The type it decodes,
/// `VolumeAnnotationsIndex`, is FRUSCoreKit's, which never reads a bundle, so the store is the app's.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
enum VolumeAnnotationsStore {

    /// The bundled index, or `nil` if unavailable. Loaded once.
    static let shared: VolumeAnnotationsIndex? = load()

    private static func load() -> VolumeAnnotationsIndex? {
        guard let url = Bundle.main.url(forResource: "volume-annotations-index", withExtension: "json") else {
            #if DEBUG
            print("[VolumeAnnotationsStore] volume-annotations-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[VolumeAnnotationsStore] failed to decode volume-annotations-index.json — \(error)")
            #endif
            return nil
        }
    }
}
