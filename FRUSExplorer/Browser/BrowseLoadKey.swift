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
/// `BrowseLoadKeyTests` holds each one to *varying with every component of its payload*. What that
/// buys is bounded and worth stating plainly: it pins the key's identity, not the call site's use
/// of it. A view that stopped calling these would not be caught here — for `CompilationView`,
/// which is the level #1301 was reported against, that hole is closed by
/// ``SwiftUI/View/compilationDocumentLoad(vm:volumeId:section:)`` below, where the key and the
/// load it belongs to are welded into one modifier and the call site has no key to get wrong.
///
/// ## The registry is the levels this branch keys, and it says which ones it is not
/// `DocumentView`'s key (`entry.documentId + "/" + entry.volumeId`, Session 68) and
/// `CorpusDocumentsView`'s two composite keys predate #1301 and are keyed at their own call
/// sites; they are named here so the contract's "every payload-carrying level is keyed" can be
/// read as a complete claim rather than an unbounded one.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
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
    ///     the *manifest* — a lookup through `allSubseriesGroups` that a side-loaded volume fails
    ///     while its documents index perfectly well. The gate is now
    ///     ``CompilationDocumentsPresentation/shouldLoad(isIndexed:)``, whose signature cannot
    ///     express a manifest input, so reinstating that guard is a compile error rather than a
    ///     silent regression.
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
}
