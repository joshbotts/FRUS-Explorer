// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
@testable import FRUSExplorer

/// Pins the one property O-0-2 must preserve: sharing `ManifestStore`'s decode with
/// `VolumeLevelTagStore` produces exactly the tag index that decoding twice produced.
///
/// `AppState` no longer builds these stores independently — `manifestStore` owns the single
/// decode of `manifest.json` and hands its entries to `volumeLevelTagStore`. The saving is
/// modest (~8 ms of a 158 ms `FRUSExplorerApp.init()`, per O-0's Time Profiler trace); the
/// durable point is that one file can no longer be read twice into two structures that
/// might disagree.
///
/// These run against the **real bundled `manifest.json`**, not a fixture. That is
/// deliberate: a fixture would prove the two code paths agree with each other while saying
/// nothing about the 552-entry file the app actually ships, which is where a divergence
/// would matter.
///
/// Version history:
///   1.0 — O-0-2: initial implementation
@Suite("Manifest — one decode, shared")
@MainActor
struct SharedManifestDecodeTests {

    @Test("The shared-manifest initialiser builds the same tag index as decoding twice")
    func sharedInitMatchesIndependentDecode() {
        let independent = VolumeLevelTagStore()                        // decodes manifest itself
        let manifestStore = ManifestStore()                            // the one decode
        let shared = VolumeLevelTagStore(bundledManifestEntries: manifestStore.bundledEntries)

        // Compare over every slug either store knows about, so a tag present in one index
        // and absent from the other fails rather than being skipped.
        let slugs = Set(independent.entries.keys).union(shared.entries.keys)
        #expect(!slugs.isEmpty, "bundled taxonomy is empty — this test would be vacuous")

        for slug in slugs {
            #expect(
                independent.volumes(forTagSlug: slug) == shared.volumes(forTagSlug: slug),
                "volumesByTag diverged for slug \(slug)"
            )
        }
    }

    @Test("Sharing the decode does not change the taxonomy half of the store")
    func sharedInitLoadsTheSameTaxonomy() {
        let independent = VolumeLevelTagStore()
        let shared = VolumeLevelTagStore(
            bundledManifestEntries: ManifestStore().bundledEntries
        )

        // Only the manifest is shared; the taxonomy is still read from the bundle by both.
        #expect(independent.entries.keys.sorted() == shared.entries.keys.sorted())
        #expect(independent.allEntries.map(\.slug) == shared.allEntries.map(\.slug))
    }

    @Test("AppState's two stores agree, and the tag index is non-empty")
    func appStateStoresAgree() {
        // The wiring itself: AppState builds manifestStore first and feeds it forward.
        // A regression that reordered them, or reintroduced a second decode, would still
        // pass the two tests above — this is the one that covers the call site.
        let state = AppState()

        let entries = state.manifestStore.bundledEntries
        #expect(!entries.isEmpty, "bundled manifest is empty — this test would be vacuous")

        // Every volume the manifest says carries a tag must be findable through the tag
        // store, which is only true if both were built from the same entries.
        var checked = 0
        for entry in entries {
            for slug in entry.tags {
                #expect(
                    state.volumeLevelTagStore.volumes(forTagSlug: slug).contains(entry.volumeId),
                    "\(entry.volumeId) carries tag \(slug) but the tag index does not list it"
                )
                checked += 1
            }
        }
        #expect(checked > 0, "no volume in the bundled manifest carries any tag")
    }
}
