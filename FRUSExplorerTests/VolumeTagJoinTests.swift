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
/// on four volumes for the life of the file, `VolumeLevelTagStore.resolve(slug:)` dropped it silently
/// on all four, and no test, generator or log surfaced it. Since decision 39 of the 2026-10-14 plan
/// of record it resolves, from the taxonomy generator's local overlay (#1622), and
/// `lgbtqRightsResolves` pins it.
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
///   1.1 — OH corrected frus1981-88v16's three person slugs (corpus d4d6eecb7, 2026-09-14), so the
///         allowlist loses them and the volume's pin moves from 15 resolving tags to all 18
///   1.2 — #1622, decision 39: `lgbtq-rights` resolves, from the taxonomy generator's local overlay, so
///         the allowlist is empty and `lgbtqRightsResolves` pins the four volumes' tag
@Suite("Manifest tag slugs resolve in the taxonomy")
struct VolumeTagJoinTests {

    /// Slugs the manifest carries that the taxonomy is known not to resolve, each with its reason.
    ///
    /// **An allowlist, not a waiver.** Every entry is a defect somewhere; listing it here says the
    /// defect has been diagnosed and is owned upstream, and makes a NEW one fail. Delete an entry
    /// when its cause is fixed — the test then proves the fix.
    ///
    /// Empty since decision 39 of the 2026-10-14 plan of record (#1622). `lgbtq-rights` was listed
    /// from #1284: the publisher keeps the tag in the TEI of four volumes and only inside a comment in
    /// its taxonomy file, and the taxonomy generator now adds it from its local overlay.
    /// frus1981-88v16's `haig-alexander-m`, `reagan-ronald-w` and `shultz-george-p` were listed from
    /// #1284 until OH restored the canonical spellings in corpus commit d4d6eecb7 (2026-09-14) — the
    /// stale check below is what reported each fix.
    static let known: [String: String] = [:]

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

        // All eighteen resolve since OH corrected the three person slugs (corpus d4d6eecb7). Before
        // that, `haig-alexander-m`, `reagan-ronald-w` and `shultz-george-p` resolved to nothing and
        // the volume was missing from the Haig, Reagan and Shultz filters while wearing those tags —
        // so the canonical spellings are pinned by name, not only by count.
        #expect(v16.tags.contains("haig-alexander-meigs"))
        #expect(v16.tags.contains("reagan-ronald"))
        #expect(v16.tags.contains("shultz-george-pratt"))
        let store = VolumeLevelTagStore()
        let resolved = v16.tags.filter { store.resolve(slug: $0) != nil }
        #expect(resolved.count == 18, """
            Expected all 18 of frus1981-88v16's tags to resolve; \(resolved.count) do. A tag that \
            used to resolve has stopped, or the manifest was regenerated from an older corpus.
            """)
    }

    /// The four volumes carrying `lgbtq-rights` were missing from a filter no control could reach,
    /// because the taxonomy had no entry for the tag (decision 39 of the 2026-10-14 plan of record,
    /// #1622). It now resolves to the owner's name, under Human Rights in Topics, where the Office's
    /// taxonomy file keeps it inside a comment, and its filter lists the four.
    @MainActor
    @Test("LGBTQ Rights resolves under Human Rights in Topics, and its filter lists its four volumes")
    func lgbtqRightsResolves() throws {
        let store = VolumeLevelTagStore()
        let tag = try #require(store.resolve(slug: "lgbtq-rights"), "the taxonomy has no entry for lgbtq-rights")
        #expect(tag.displayName == "LGBTQ Rights")
        #expect(tag.category == .topics)
        #expect(tag.subcategory == "human-rights" && tag.parentSlug == "human-rights")
        #expect(store.resolve(slug: "human-rights") != nil, "its parent does not resolve")
        #expect(store.allTags(inCategory: .topics).contains { $0.slug == "lgbtq-rights" })
        #expect(Set(store.volumes(forTagSlug: "lgbtq-rights"))
                == ["frus1952-54v01p2", "frus1958-60v03mSupp", "frus1977-80v28", "frus1981-88v41"])
    }
}
