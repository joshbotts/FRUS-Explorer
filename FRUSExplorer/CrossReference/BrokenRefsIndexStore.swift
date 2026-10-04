// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - BrokenRefsIndexStore

/// Lazily loads the bundled `broken-refs-index.json` once. Nil-tolerant: a missing or corrupt
/// resource yields `nil`, and every consumer treats a `nil` store as "nothing is known-broken"
/// (links stay live, no exclusion, the export section hides) — never a crash.
///
/// Mirrors `VolumeSubjectProfilesStore`'s shape. Loaded on first use — typically the post-launch
/// `applyBrokenRefsIndexIfNeeded` Task, or the first document open / export view otherwise. The
/// decode is a 23 KB JSON parse, so no warm-up task is needed.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: moved from `BrokenRefsIndex.swift`, which the kit compiles; the
///          kit is given an index and never reads a bundle
enum BrokenRefsIndexStore {

    /// The bundled broken-refs index, or `nil` if unavailable. Loaded once.
    static let shared: BrokenRefsIndex? = load()

    private static func load() -> BrokenRefsIndex? {
        guard let url = Bundle.main.url(forResource: "broken-refs-index", withExtension: "json") else {
            #if DEBUG
            print("[BrokenRefsIndexStore] broken-refs-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BrokenRefsIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[BrokenRefsIndexStore] failed to decode broken-refs-index.json — \(error)")
            #endif
            return nil
        }
    }
}
