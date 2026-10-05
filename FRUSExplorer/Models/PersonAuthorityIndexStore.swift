// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonAuthorityIndex + bundled loading

extension PersonAuthorityIndex {

    /// Loads the bundled `person-authority-index.json`, or `nil` if it is absent (e.g. the unit-test
    /// bundle) or fails to decode. Decoding ~1.3 MB is fast; callers cache the result.
    public static func loadBundled(bundle: Bundle = .main) -> PersonAuthorityIndex? {
        guard let url = bundle.url(forResource: "person-authority-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[PersonAuthorityIndex] person-authority-index.json not found in bundle")
            #endif
            return nil
        }
        do {
            let index = try JSONDecoder().decode(PersonAuthorityIndex.self, from: data)
            #if DEBUG
            print("[PersonAuthorityIndex] loaded \(index.crosswalkCount) crosswalk entries, "
                + "\(index.authority.count) canonical people (generated \(index.generated))")
            #endif
            return index
        } catch {
            #if DEBUG
            print("[PersonAuthorityIndex] decode failed: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - PersonAuthorityIndexStore

/// The one decoded copy of the bundled authority index (#736).
///
/// `IndexingPipeline` has loaded this since Phase 5 for clustering; the person detail sheet now
/// needs it too, for the schema-v2 fields (POCOM slug, Wikidata, role text) that the rollup table
/// does not carry. Two independent `loadBundled()` calls would hold two decoded copies of a 2.4 MB
/// file resident, so both go through here instead.
///
/// The pipeline keeps its own injectable slot for tests — this store is deliberately *not*
/// settable, because a shared mutable singleton is how one test leaks a fixture into another.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 2: moved, with `loadBundled(bundle:)`, from `PersonAuthorityIndex.swift`,
///          which the kit compiles; the kit is given the index (`IndexingResources`) and never reads
///          a bundle
enum PersonAuthorityIndexStore {
    static let shared: PersonAuthorityIndex? = PersonAuthorityIndex.loadBundled()
}
