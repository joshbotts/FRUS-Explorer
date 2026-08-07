// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PresidentialLibraryOutcome

/// What the bundled catalogue can say about a presidential-library citation, and how to say it
/// (#681).
///
/// ## Why this is a type and not a branch in each view
/// The same reason `CatalogQueryEvidence` is: there are two hand-written Source Explorer views,
/// and this codebase has shipped a Source Explorer affordance to one platform and not the other
/// (#617, and the macOS custody gate that survived mutation in #704). Resolution *and* wording
/// live here so the two views cannot answer the same citation differently, or hedge on one
/// platform and not the other.
///
/// ## What the two branches mean
/// The join runs through a **hand-verified** `collectionIdentifier`, so the collection is not a
/// guess in either branch — it is the row a curator checked against the harvested catalogue.
/// What varies is whether the citation also pins one series inside it:
///
/// - ``series(_:inCollection:)`` — the citation names a series and exactly one series in the
///   verified collection answers to the name, or a curator matched it by hand. This is the
///   resolution.
/// - ``collection(_:candidates:)`` — the collection is known and the series is not. FRUS cites
///   the Johnson `Country File` undivided where NARA holds seven regional country-file series;
///   none of them is *the* answer, so the collection is offered as the answer it actually is and
///   the series are offered as candidates.
///
/// ## Why an offline hit suppresses the live query
/// Owner decision, 2026-08-06. Showing an exact NARA collection *beside* three unconstrained
/// free-text hits re-creates the ambiguity #704 and #705 spent two PRs removing: the reader has
/// no way to tell which rows were verified. The live query remains for citations this cannot
/// answer — see ``suppressesLiveQuery``.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681, wires the bundled catalogue into both Source Explorer views
enum PresidentialLibraryOutcome: Sendable, Equatable {

    /// One series inside one verified collection — safe to present as the resolution.
    case series(PresidentialLibraryIndex.Series,
                inCollection: PresidentialLibraryIndex.Collection)

    /// The collection is verified; the cited series is not pinned. `candidates` is the narrowed
    /// set when the citation's series name matched several, and the collection's whole series
    /// list when it named none or matched none.
    case collection(PresidentialLibraryIndex.Collection,
                    candidates: [PresidentialLibraryIndex.Series])

    /// The bundled catalogue has nothing for this citation.
    case none

    // MARK: - Resolution

    /// The most candidate series listed before the list stops being evidence and starts being an
    /// inventory. The caveat states the full count whenever it is larger, so nothing is dropped
    /// silently.
    static let candidateDisplayLimit = 8

    /// Resolves a presidential-library citation against the bundled catalogue.
    ///
    /// - Parameters:
    ///   - repository: as the citation writes it (`Kennedy Library`).
    ///   - collection: the level-1 segment (`National Security Files`).
    ///   - note: the raw source note, which is where the level-2 series segment has to come from
    ///     — the per-document parse keeps only level 1.
    ///   - index: the bundled catalogue; injectable so tests do not depend on `Bundle.main`.
    ///   - curated: the curated bridge table, likewise injectable.
    ///
    /// Repositories the National Archives does not administer resolve to ``none`` without a
    /// special case: they are not in the harvest, so ``PresidentialLibraryIndex/library(for:)``
    /// does not find them.
    static func resolve(
        repository: String,
        collection: String,
        note: String,
        index: PresidentialLibraryIndex? = PresidentialLibraryIndexStore.shared,
        curated: CuratedLibraryResolutions? = CuratedLibraryResolutionsStore.shared
    ) -> PresidentialLibraryOutcome {
        guard let index else { return .none }
        let subCollection = CuratedLibraryResolutions.subCollection(
            inNote: note, afterCollection: collection)
        let match = index.match(
            repository: repository,
            collection: collection,
            series: subCollection,
            collectionIdentifier: curated?.collectionIdentifier(
                repository: repository, collection: collection))

        let hit: PresidentialLibraryIndex.Collection
        switch match {
        case .none:
            return .none
        case .series(_, let inCollection):
            hit = inCollection
        case .collection(let c, _):
            hit = c
        }

        // A curated series NAID outranks the title match. It was derived by the same rule but
        // checked by hand, and where the two disagree the checked one is the answer.
        if let naId = curated?.seriesNaId(repository: repository, collection: collection,
                                          subCollection: subCollection),
           let curatedSeries = hit.series.first(where: { $0.naId == naId }) {
            return .series(curatedSeries, inCollection: hit)
        }

        switch match {
        case .series(let only, let inCollection):
            return .series(only, inCollection: inCollection)
        case .collection(let c, let candidates):
            return .collection(c, candidates: candidates)
        case .none:
            return .none
        }
    }

    // MARK: - What the view needs

    /// Whether the bundled catalogue answered at all.
    var isHit: Bool { self != .none }

    /// Whether the live catalogue query must be skipped for this citation (owner decision, see
    /// the type's discussion). True for every hit — the collection is verified in both branches,
    /// and unconstrained free-text rows beside it would be indistinguishable from it.
    var suppressesLiveQuery: Bool { isHit }

    /// The verified collection, in both hit branches.
    var verifiedCollection: PresidentialLibraryIndex.Collection? {
        switch self {
        case .series(_, let inCollection): return inCollection
        case .collection(let c, _): return c
        case .none: return nil
        }
    }

    /// The resolved series, when the citation pinned one.
    var resolvedSeries: PresidentialLibraryIndex.Series? {
        if case .series(let s, _) = self { return s }
        return nil
    }

    /// Candidate series to list, or `nil` when there are none worth listing.
    ///
    /// Empty when the citation narrowed nothing: a collection's *entire* series list is its
    /// inventory rather than evidence about this citation, and the researcher is better served
    /// by the collection's own catalogue record — which the view links — than by the first eight
    /// of forty-eight series in NAID order.
    var candidateSeries: [PresidentialLibraryIndex.Series]? {
        guard case .collection(let c, let candidates) = self,
              !candidates.isEmpty,
              candidates.count < c.series.count else { return nil }
        return Array(candidates.prefix(Self.candidateDisplayLimit))
    }

    /// The full candidate count, which may exceed what ``candidateSeries`` lists.
    var candidateTotal: Int {
        guard case .collection(_, let candidates) = self else { return 0 }
        return candidates.count
    }

    /// The section heading.
    ///
    /// "NARA Catalog" in both branches, because the first thing the section shows is the verified
    /// collection. `CatalogQueryEvidence` puts the hedge in the *heading* on the reasoning that a
    /// caveat below the rows is read last; here the hedge attaches to the series rows, and the
    /// caveat is rendered **above** them, so it is read before the thing it qualifies.
    var sectionTitle: String {
        String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")
    }

    /// What the reader must know before treating the rows as an answer, or `nil` when the
    /// citation resolved exactly.
    var caveat: String? {
        guard case .collection(let c, let candidates) = self else { return nil }
        if candidates.count >= c.series.count {
            return String(localized: "source.explorer.presLib.offline.collectionOnly",
                          defaultValue: """
                          The collection is identified, but the citation does not name one of \
                          its \(c.series.count) series unambiguously. Open the collection record \
                          to find the series cited.
                          """)
        }
        let shown = min(candidates.count, Self.candidateDisplayLimit)
        return String(localized: "source.explorer.presLib.offline.candidates",
                      defaultValue: """
                      The collection is identified. The series named in the citation matches \
                      \(candidates.count) of its records — \(shown) shown below — so none of \
                      them is the answer on its own. Check the titles and dates before citing.
                      """)
    }

    /// The label for the verified collection row.
    var collectionRowLabel: String {
        String(localized: "source.explorer.presLib.offline.collection",
               defaultValue: "Collection")
    }

    /// The label for the resolved series row.
    var seriesRowLabel: String {
        String(localized: "source.explorer.presLib.offline.series", defaultValue: "Series")
    }

    /// The provenance line: this came out of the bundle, not the network.
    var provenanceNote: String {
        String(localized: "source.explorer.presLib.offline.provenance",
               defaultValue: """
               Matched against the National Archives' own description of this library, from the \
               bundled catalog — no API key or network required.
               """)
    }
}
