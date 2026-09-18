// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - BrowseLoadKey

/// The value a payload-carrying Browse level keys its load task on (#1301).
///
/// ## Why the keys are values in one place rather than expressions at five call sites
/// The reuse contract at `BrowserView.levelView` says every load task in a level view carries
/// `.task(id:)`, keyed on the payload it loads for. As prose that is a rule nobody can check: a
/// key is an argument to a modifier, so "keyed on the payload" and "keyed on something that
/// happens to differ in the fixture I tested" look identical in a diff. Keying on the section's
/// *title* rather than its id, for instance, passes every test #1301 shipped — measured — and
/// breaks the moment a section's `<head>` repeats its parent's.
///
/// Each function here is one level's key, so the claim becomes an ordinary assertion:
/// `BrowseLoadKeyTests` holds each one to *varying with every component of its payload*.
///
/// ## What a key assertion cannot do, and what round 3 did about it
/// It pins the key's identity, **not** the call site's use of it. Round 2's attack measured that
/// exactly: reverting `VolumeView`'s, `ClustersBrowseView`'s and `CollectionDetailView`'s keyed
/// tasks to bare `.task`s at the call site left every suite green while
/// `volumeKeyVariesWithTheVolume`, `clusterMetadataKeyVariesWithBothComponents` and
/// `archivalCollectionKeyVariesWithTheRecord` went on passing. A source scan for `.task(id:)` is
/// not the answer — this repo has MEASURED a scan of that shape to be vacuous
/// (`VolumeStructure.swift:200`).
///
/// So every level this branch keys now loads through a **modifier in this file** that takes the
/// payload and derives the key itself: there is no key at any call site to get wrong, and a
/// reviewer checks one line per level rather than an expression. That is a structural gate, not a
/// test, and the difference is stated rather than blurred — deleting a modifier call still
/// compiles. Where a self-to-self step is reachable, a walk is the gate instead:
/// `BrowseNestedSectionTests` steps `.compilation → .compilation` three times (twice into a
/// section whose head repeats its parent's) and `.volume → .volume` once from the corpus root's
/// search. For `.clusterDocuments` and `.archivalCollection` no row appends the step, so no walk
/// can exist; those two are held instead by state that carries its own identity
/// (``ClusterDrillState``, ``CollectionDetailLoad``), which makes the *harm* of a missing key
/// smaller and is itself pinned by unit tests.
///
/// ## The registry is the levels this branch keys, and it says which ones it is not
/// `DocumentView`'s key (`entry.documentId + "/" + entry.volumeId`, Session 68) and
/// `CorpusDocumentsView`'s two composite keys predate #1301 and are keyed at their own call
/// sites; they are named here so the contract's "every payload-carrying level is keyed" can be
/// read as a complete claim rather than an unbounded one.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
///   1.1 — #1301 round 3: every keyed level gets a modifier here, so no call site holds a key;
///          the `.volume` level gains a behavioural walk; and the side-loaded-volume story behind
///          the deleted manifest guard is replaced by what is measurable about it
public enum BrowseLoadKey {

    /// One compilation section's documents — **also the cache key** the rows are stored under.
    ///
    /// `BrowserViewModel.compilationKey(volumeId:sectionId:)` forwards to this, so the task's id
    /// and the dictionary the load writes into cannot drift apart: there is one definition.
    ///
    /// - Parameters:
    ///   - volumeId: The volume the section belongs to.
    ///   - sectionId: The section's `xml:id`, which is unique within its volume.
    /// - Returns: The key.
    public static func compilation(volumeId: String, sectionId: String) -> String {
        "\(volumeId)/\(sectionId)"
    }

    /// One volume's structure (`VolumeView`).
    ///
    /// A `.volume → .volume` step **is** reachable: `CorpusView`'s root search calls
    /// `BrowserViewModel.select(_:)`, which assigns the path rather than appending to it, and on
    /// regular-width iPad that list pane stands beside a detail pane that may already be showing a
    /// volume. So this is a live reuse step, not a latent one.
    ///
    /// - Parameter volumeId: The volume being shown.
    /// - Returns: The key.
    public static func volume(_ volumeId: String) -> String { volumeId }

    /// One semantic cluster's membership (`ClusterDocumentsView`).
    ///
    /// - Parameter clusterId: The cluster being shown, as the artifact numbers it.
    /// - Returns: The key.
    public static func clusterMembership(clusterId: Int) -> String { "\(clusterId)" }

    /// One semantic cluster's per-volume metadata, re-asked when the library grows.
    ///
    /// Both components are load-bearing: the indexed-volume count is the B-4 idiom that upgrades
    /// degraded rows when an index pass finishes, and the cluster id is what #1301's contract
    /// adds. A key carrying only the count still looks like a working idiom in a diff.
    ///
    /// - Parameters:
    ///   - clusterId: The cluster being shown, as the artifact numbers it.
    ///   - indexedVolumeCount: `AppState.indexedVolumeIds.count`.
    /// - Returns: The key.
    public static func clusterMetadata(clusterId: Int, indexedVolumeCount: Int) -> String {
        "\(clusterId)-\(indexedVolumeCount)"
    }

    /// One archival collection's local counts, related collections and era timeline
    /// (`CollectionDetailView`, mounted as the `.archivalCollection` level).
    ///
    /// - Parameter recordId: `AuthorityCollectionRecord.id`.
    /// - Returns: The key.
    public static func archivalCollection(recordId: String) -> String { recordId }
}

// MARK: - The compilation load, welded to its key

extension View {

    /// Loads a compilation section's documents, keyed on the section it loads for (#1301).
    ///
    /// ## Why this is a modifier and not a `.task(id:)` at the call site
    /// Three defects of the same shape live in the two lines this replaces, and each survived
    /// #1301's first round of tests:
    ///
    ///  1. **A key that is not the payload.** `.task(id: section.title)` compiles, reads
    ///     plausibly, and passes every test the branch shipped. Here there is no key at the call
    ///     site to get wrong: the modifier takes the section and derives the key itself.
    ///  2. **A gate on something the load does not need.** The deleted `guard volume != nil` read
    ///     the *manifest* — a lookup through `allSubseriesGroups` — and `loadDocuments` reads no
    ///     manifest at all, so it was dead weight and one more thing to get wrong. The gate is now
    ///     ``CompilationDocumentsPresentation/shouldLoad(isIndexed:)``, which takes one `Bool`.
    ///
    ///     **The honest scope, because round 2 claimed more than this.** Reinstating the lookup
    ///     *through that function* is a compile error — there is nowhere to put a manifest — but
    ///     this modifier still holds `vm`, so a separate `guard vm.allSubseriesGroups…` written
    ///     inside the task body below compiles and no test catches it (measured by round 2's
    ///     mutation attack, which wrote exactly that guard: 31 tests in four suites green — the
    ///     count before round 3 — and the push-path UI test green in 34.35 s). `vm` stays because it
    ///     is what makes the key and the load read the same two values — the property that killed
    ///     the `section.title` key — and narrowing the mistake is worth more than the appearance
    ///     of preventing it.
    ///
    ///     What such a guard would cost is also smaller than round 2 said, and that is measurable
    ///     rather than asserted: `isIndexed(_:)` is a `document_cache` test, so anything passing
    ///     the gate is on disk, and since #777 `ManifestStore.browsableEntries` is
    ///     `catalogue + localEntries`, which folds every volume on disk into `allVolumes` and so
    ///     into `allSubseriesGroups`. A reinstated guard would therefore refuse **no volume a
    ///     reader can reach** — not "only side-loaded ones", which is what three comments, a test
    ///     message and the plan used to say about a failure nobody has reproduced.
    ///  3. **Dropping the gate that remains.** `isIndexed` must be checked: `document_cache`
    ///     answers an unindexed volume with an empty set, which records `.loaded` — the one state
    ///     that short-circuits — so every later kick returns early and the reader is left on "No
    ///     documents in this section." for ever. `CompilationDocumentLoadingTests` measures that
    ///     trap from both ends.
    ///
    /// - Parameters:
    ///   - vm: The browser view model that owns the per-section load state.
    ///   - volumeId: The volume the section belongs to.
    ///   - section: The section whose direct documents are wanted.
    /// - Returns: The view, with the keyed load attached.
    @MainActor
    func compilationDocumentLoad(vm: BrowserViewModel,
                                 volumeId: String,
                                 section: VolumeSection) -> some View {
        task(id: BrowseLoadKey.compilation(volumeId: volumeId, sectionId: section.sectionId)) {
            guard CompilationDocumentsPresentation.shouldLoad(isIndexed: vm.isIndexed(volumeId))
            else { return }
            await vm.loadDocuments(for: section, volumeId: volumeId)
        }
    }

    /// Loads a volume's structure, keyed on the volume it loads for (#1301 round 3).
    ///
    /// A `.volume → .volume` step **is** reachable — see ``BrowseLoadKey/volume(_:)`` — and
    /// `loadVolumeStructure(for:)` guards on `volumeStructures[volumeId] == nil`, so a bare
    /// `.task` leaves the second volume with no structure at all and `VolumeView` holds "Loading
    /// structure…" for the life of the process. `BrowseNestedSectionTests`'
    /// `testASecondVolumeFromRootSearchLoadsItsOwnStructure` walks exactly that step on iPad.
    ///
    /// - Parameters:
    ///   - vm: The browser view model that owns `volumeStructures`.
    ///   - volume: The volume being shown.
    /// - Returns: The view, with the keyed load attached.
    @MainActor
    func volumeStructureLoad(vm: BrowserViewModel, volume: VolumeManifestEntry) -> some View {
        task(id: BrowseLoadKey.volume(volume.volumeId)) {
            await vm.loadVolumeStructure(for: volume)
        }
    }

    /// Loads one semantic cluster's membership, keyed on the cluster (#1301 round 3).
    ///
    /// - Parameters:
    ///   - clusterId: The cluster being shown.
    ///   - load: `ClusterDocumentsView.loadMembership()`.
    /// - Returns: The view, with the keyed load attached.
    @MainActor
    func clusterMembershipLoad(clusterId: Int,
                               load: @escaping @MainActor () async -> Void) -> some View {
        task(id: BrowseLoadKey.clusterMembership(clusterId: clusterId)) { await load() }
    }

    /// Loads one cluster's per-volume metadata, keyed on the cluster **and** on the size of the
    /// reader's index (#1301 round 3).
    ///
    /// Both components are arguments here rather than a key at the call site, because the
    /// count-only form — which drops the cluster — still re-keys when an index pass finishes and
    /// therefore reads in a diff as the working B-4 idiom.
    ///
    /// - Parameters:
    ///   - clusterId: The cluster being shown.
    ///   - indexedVolumeCount: `AppState.indexedVolumeIds.count`.
    ///   - load: `ClusterDocumentsView.loadMetadata()`.
    /// - Returns: The view, with the keyed load attached.
    @MainActor
    func clusterMetadataLoad(clusterId: Int,
                             indexedVolumeCount: Int,
                             load: @escaping @MainActor () async -> Void) -> some View {
        task(id: BrowseLoadKey.clusterMetadata(clusterId: clusterId,
                                               indexedVolumeCount: indexedVolumeCount)) {
            await load()
        }
    }

    /// Loads one archival collection's local counts, related collections and era timeline, keyed
    /// on the record (#1301 round 3).
    ///
    /// - Parameters:
    ///   - recordId: `AuthorityCollectionRecord.id`.
    ///   - load: The three loads, in the order `CollectionDetailView` runs them.
    /// - Returns: The view, with the keyed load attached.
    @MainActor
    func archivalCollectionLoad(recordId: String,
                                load: @escaping @MainActor () async -> Void) -> some View {
        task(id: BrowseLoadKey.archivalCollection(recordId: recordId)) { await load() }
    }
}
