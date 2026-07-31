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

import Foundation
import SwiftData

// MARK: - WorkingCorpus

/// A named, fixed set of **documents** a researcher defines once and then works inside.
///
/// The document-grain analogue of ``CustomVolumeScope``, and the move both source reports depend
/// on: define "the 267-document OSP corpus", then run every subsequent query, facet and cloud
/// *within* it.
///
/// ## Why the key list syncs, and not the query that produced it (decision M-1-1)
/// The alternative was to sync the *definition* — query, scope, snapshot date — and re-resolve on
/// each device. That is a far smaller record, and it was the session plan's lean. It was rejected
/// because it gives up the one property that makes a working corpus worth having.
///
/// A working corpus is cited. "Nine of the 267 documents mention Buy American" is a claim, and a
/// claim whose denominator is 267 here and 240 on an iPad is not reproducible — nor could the app
/// even tell that the two disagreed, since neither device would know the other's number. The
/// snapshot **is** the artifact; re-resolving would make it a saved search, which this app already
/// has.
///
/// The honest problem re-resolution was meant to solve — that a device may not have indexed every
/// member — is solved better by carrying the full list and *reporting coverage*: "142 of 267
/// documents indexed on this device" is a true statement about a known corpus, where a silently
/// smaller corpus is not. See ``WorkingCorpusResolver``.
///
/// ## Shape
/// Follows `CustomVolumeScope` exactly: a value array of stable string keys, no child `@Model`, no
/// relationship. Document keys may name documents this device has never indexed — the same
/// legitimate case as a volume scope naming an undownloaded volume, and *not* the dangling-reference
/// hazard of #406, which was `UUID`s pointing at deleted model rows.
///
/// **A working corpus is bounded by the result set that produced it**, so at most 7,500 keys
/// (macOS's search cap) — around 190 KB as a value array, well inside a CloudKit record.
///
/// Enrolled in `frusModelTypes` (**a new CloudKit record type: deploy the schema to Production
/// before shipping**).
///
/// Version history:
///   1.0 — M-1: initial implementation
@Model final class WorkingCorpus {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Display

    /// User-visible name. Not unique — duplicates are allowed and disambiguated by `id`, because
    /// uniqueness across CloudKit devices cannot be guaranteed.
    var name: String = ""

    // MARK: - Membership

    /// Member documents as `"volumeId/documentId"` composite keys — the same string
    /// `IndexingPipeline` uses for `SearchSQLFilters.documentIds` and for keyed body-text fetches,
    /// so no translation layer stands between the stored set and the query that applies it.
    ///
    /// Change membership through ``replaceMembership(_:)``, never by assigning this directly.
    ///
    /// A `didSet` observer here would be the obvious way to keep `lastModified` honest, and it does
    /// not work: measured on this model, a `didSet` on a `@Model` array property fires on **neither**
    /// an in-place append nor a whole reassignment, inserted in a context or detached. `Project`'s
    /// doc comment claims the reassignment case works; it was not true here. `CustomVolumeScope` —
    /// the model this one mirrors — stamps explicitly at its call sites for the same reason, and a
    /// method is one step better than that discipline, because a caller cannot forget it.
    var documentKeys: [String] = []

    // MARK: - Provenance

    /// When the set was captured. Part of the citation, not bookkeeping: a corpus is a claim about
    /// a moment in the index.
    var capturedAt: Date?

    /// The query the set was captured from, as the user typed it. Recorded so a corpus can be
    /// described and re-derived by hand, **not** so it can be silently re-resolved.
    var sourceQuery: String?

    /// A human-readable account of where the set came from ("Search results", "Collection: Berlin
    /// 1948"), for the corpus list and for exports.
    var sourceDescription: String?

    /// How many volumes were indexed on the capturing device. A corpus captured against 40 volumes
    /// and one captured against 552 are different evidence, and nothing else records the difference.
    var indexedVolumeCountAtCapture: Int?

    // MARK: - Bookkeeping

    /// Creation timestamp; optional for CloudKit schema compatibility.
    var createdAt: Date?
    /// Last membership/name edit; optional for CloudKit schema compatibility.
    var lastModified: Date?

    // MARK: - Init

    /// Creates a working corpus.
    ///
    /// - Parameters:
    ///   - name: the user-visible name.
    ///   - documentKeys: `"volumeId/documentId"` keys, de-duplicated and sorted so two captures of
    ///     the same set are equal and the stored order is stable across devices.
    ///   - sourceQuery: the query text the set came from, if any.
    ///   - sourceDescription: where the set came from, for display.
    ///   - indexedVolumeCountAtCapture: volumes indexed on the capturing device.
    init(name: String,
         documentKeys: [String],
         sourceQuery: String? = nil,
         sourceDescription: String? = nil,
         indexedVolumeCountAtCapture: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.documentKeys = Array(Set(documentKeys)).sorted()
        self.capturedAt = Date()
        self.sourceQuery = sourceQuery
        self.sourceDescription = sourceDescription
        self.indexedVolumeCountAtCapture = indexedVolumeCountAtCapture
        self.createdAt = Date()
        self.lastModified = Date()
    }

    // MARK: - Mutation

    /// Replaces the membership and stamps `lastModified`.
    ///
    /// The only supported way to change what a corpus contains. `lastModified` is what CloudKit's
    /// last-writer-wins resolves on, so a membership edit that failed to move it would let a stale
    /// device silently win the merge and restore documents the researcher removed.
    ///
    /// - Parameter keys: the new `"volumeId/documentId"` set, canonicalised the way `init` does so
    ///   an edited corpus and a freshly captured identical one still store identically.
    func replaceMembership(_ keys: [String]) {
        documentKeys = Array(Set(keys)).sorted()
        lastModified = Date()
    }

    /// Renames the corpus and stamps `lastModified`.
    func rename(to newName: String) {
        name = newName
        lastModified = Date()
    }

    // MARK: - Derived

    /// How many documents the corpus names.
    var documentCount: Int { documentKeys.count }

    /// The distinct volumes the corpus spans, derived from the keys.
    var volumeIds: Set<String> {
        Set(documentKeys.compactMap { $0.split(separator: "/").first.map(String.init) })
    }
}
