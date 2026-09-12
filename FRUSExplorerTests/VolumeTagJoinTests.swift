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

// MARK: - VolumeTagJoinTests

/// Every tag slug in `manifest.json` must resolve in `volume-tag-taxonomy.json` (#1284).
///
/// ## Why this did not exist, and what it cost
/// The two artifacts are generated from different sources — the manifest's tags come from each
/// volume's own TEI `<keywords scheme="https://history.state.gov/tags">`, the taxonomy from the
/// publisher's tag listing — and **nothing joined them**. The nearest tests do not:
/// `ManifestStoreTests` pins that a made-up slug returns nil, which is the behaviour and not the
/// data; `SharedManifestDecodeTests` iterates the union of the two STORES' keys, so a manifest slug
/// with no taxonomy entry is not in the set it iterates and cannot fail it.
///
/// The cost is measurable rather than hypothetical: `lgbtq-rights` has been in the shipped manifest
/// on four volumes for the life of the file, `VolumeLevelTagStore.resolve(slug:)` has been dropping
/// it silently on all four, and no test, generator or log surfaced it.
///
/// ## What an unresolvable slug actually breaks
/// Not the chip — the FILTER, asymmetrically, in the direction hardest to notice. The tag picker is
/// driven by the TAXONOMY (`allEntries`), so nothing in the UI can ever ask for a slug the taxonomy
/// lacks; the filter index is built from the MANIFEST, so the volume sits in `volumesByTag` under a
/// key no control can reach. A reader who picks the canonical tag gets a plausible-looking list with
/// that volume silently missing from it.
///
/// Version history:
///   1.0 — #1284: initial implementation
@Suite("Manifest tag slugs resolve in the taxonomy")
struct VolumeTagJoinTests {

    /// Slugs the manifest carries that the taxonomy is known not to resolve, each with its reason.
    ///
    /// **An allowlist, not a waiver.** Every entry is a defect somewhere; listing it here says the
    /// defect has been diagnosed and is owned upstream, and makes a NEW one fail. Delete an entry
    /// when its cause is fixed — the test then proves the fix.
    static let known: [String: String] = [
        // The publisher retired the tag without removing it from the TEI. `history.state.gov/tags/
        // lgbtq-rights` returns 404 and `/tags/all` carries no such entry, while `disability-rights`
        // — printed in the same keywords block of frus1977-80v28 — is live and lists 12 volumes.
        // The taxonomy artifact is faithful to the publisher; the corpus is not. Four volumes:
        // frus1952-54v01p2, frus1958-60v03mSupp, frus1977-80v28, frus1981-88v41.
        "lgbtq-rights": "retired by the publisher; /tags/lgbtq-rights is 404",

        // A typo in one corpus commit, not a new naming convention (#1284). Corpus commit c95d35451
        // ("fix: add volume tags", 2026-09-11) un-commented a placeholder in frus1981-88v16.xml that
        // already used the canonical spellings `reagan-ronald` and `shultz-george-pratt`, and
        // replaced them with these. Corpus-wide the long forms are used by 7–11 volumes each and
        // these three by frus1981-88v16 alone; OH's own tag pages 404 on them, so the publisher's
        // site cannot list the volume under Reagan, Haig or Shultz either. Reported upstream;
        // delete these three when the TEI is corrected.
        "haig-alexander-m": "frus1981-88v16 typo for haig-alexander-meigs (c95d35451)",
        "reagan-ronald-w": "frus1981-88v16 typo for reagan-ronald (c95d35451)",
        "shultz-george-p": "frus1981-88v16 typo for shultz-george-pratt (c95d35451)",
    ]

    @MainActor
    @Test("Every manifest tag slug resolves, or is a known-and-diagnosed exception")
    func everyManifestSlugResolves() throws {
        let store = VolumeLevelTagStore()
        let volumes = ManifestStore().bundledEntries
        var unresolvable: [String: [String]] = [:]
        var checked = 0

        for volume in volumes {
            for slug in volume.tags {
                checked += 1
                guard store.resolve(slug: slug) == nil else { continue }
                unresolvable[slug, default: []].append(volume.volumeId)
            }
        }

        // Counted, because a join that suddenly matched nothing would otherwise pass in silence —
        // an empty manifest, a renamed field, a store that failed to load.
        #expect(checked > 1_000, "the scan read \(checked) slugs; the manifest carries thousands")

        let unexpected = unresolvable.keys.filter { Self.known[$0] == nil }.sorted()
        #expect(unexpected.isEmpty, """
            These manifest tag slugs resolve to nothing in the taxonomy, so the volumes carrying \
            them are absent from the filter for a tag they are labelled with, and the app reports \
            no error: \(unexpected.map { "\($0) on \(unresolvable[$0]!.joined(separator: ", "))" }
                .joined(separator: "; ")). Either correct the slug upstream in the corpus TEI, or — \
            if the publisher owns the defect — add it to `known` WITH ITS REASON.
            """)

        // The other direction: an allowlist entry whose cause has been fixed is stale, and a stale
        // allowlist is how the next real one gets waved through.
        let stale = Self.known.keys.filter { unresolvable[$0] == nil }.sorted()
        #expect(stale.isEmpty, """
            These are allowlisted as unresolvable but now resolve — the upstream fix has landed. \
            Delete them from `known`: \(stale.joined(separator: ", ")).
            """)
    }

    @MainActor
    @Test("frus1981-88v16 carries the eighteen tags the Office of the Historian published")
    func volumeSixteenCarriesItsTags() throws {
        let v16 = try #require(
            ManifestStore().bundledEntries.first { $0.volumeId == "frus1981-88v16" })
        // The volume this change exists for. OH added these in corpus commit c95d35451 and the
        // offline overlay could not see them until #1284 taught it to re-derive `tags`.
        #expect(v16.tags.count == 18)
        #expect(v16.tags.contains("ecuador"))
        #expect(v16.tags.contains("narcotics"))
        #expect(v16.tags.contains("international-monetary-fund"))

        // Fifteen of the eighteen resolve; the three that do not are the upstream typo above, and
        // this pins the split so that a silent change in either direction is visible.
        let store = VolumeLevelTagStore()
        let resolved = v16.tags.filter { store.resolve(slug: $0) != nil }
        #expect(resolved.count == 15, """
            Expected 15 of frus1981-88v16's 18 tags to resolve. If this is now 18, OH has corrected \
            the three person slugs — delete them from `known` above. If it is fewer than 15, a tag \
            that used to resolve has stopped.
            """)
    }
}
