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
///   1.1 — #1051 B-1 (R-2): `documentCount(forVolumeId:)` — the one named seam through
///          which Browse reads per-volume document counts
@Observable
@MainActor
final class AdministrationProfilesStore {

    /// The decoded administration-profiles aggregate, or `nil` if the bundled
    /// resource was absent or could not be decoded.
    let index: AdministrationProfilesIndex?

    /// The volume's total FRUS document count, or `nil` when the index is absent or does
    /// not know the volume (side-loaded volumes, a malformed bundle).
    ///
    /// ## Why this artifact, and why a named accessor (R-2, #1051)
    /// `volumeTotals` is an exact per-volume count of `<div type="document">` elements for
    /// all 552 volumes — verified against the raw TEI and summing to 314,483, the same
    /// number the semantic pipeline counts independently. The manifest's `documentCount`
    /// is structurally dead (the header parser cannot compute it; 0 in all 552 entries),
    /// so Browse reads counts HERE. The accessor exists so that dependency on an artifact
    /// named for another feature stays behind one seam — if the counts ever move into the
    /// manifest, this is the only method that changes.
    ///
    /// Wording rule for every caller: this counts FRUS document divs. Search over the same
    /// volume can return MORE rows (quasi-documents: prose-only chapters, prefaces —
    /// +2,356 corpus-wide), so never present the two as the same universe.
    ///
    /// - Parameter volumeId: The manifest volume id, e.g. `"frus1861"`.
    /// - Returns: `pointDocs + rangeDocs + undatedDocs`, or `nil` when unknown.
    func documentCount(forVolumeId volumeId: String) -> Int? {
        guard let totals = index?.volumeTotals[volumeId] else { return nil }
        return totals.pointDocs + totals.rangeDocs + totals.undatedDocs
    }

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
