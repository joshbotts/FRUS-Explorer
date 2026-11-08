// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ExternalCitationIndex

/// Where FRUS's editorial footnotes point **outside** the printed record — the bundled
/// `external-citation-index.json` (#784).
///
/// ## What one number here means
/// A *reference* is one archival unit named in one editorial footnote: the editor writing
/// *"Telegram 1345 from Moscow, March 5, is in … Lot 66–D95"* — a document the volume did not
/// print, and where to find it. Three claims that look alike and are not:
///
/// | index | claim |
/// |---|---|
/// | `collection-usage-index.json` | documents **drawn from** this archival unit |
/// | `provenance-flow-index.json` | references between two **printed** documents |
/// | this one | material the editors said exists **and did not print** |
///
/// ## The era claim #784 makes does not survive its own scope
/// The issue's headline is that footnote citations are "the only archival-flow signal that reaches
/// 1910–1945", citing 640 / 523 / 1,183 references for the 1910s / 1920s / 1930s. Measured on the
/// shipped artifact, at the scope the same issue mandates (lot files and library collections only),
/// those decades yield **0 / 0 / 2**.
///
/// The two figures are not in conflict; they count different things. #784's own verbatim examples
/// of pre-war reach — `(file No. 711.684/11)` and `(811.114 Guatemala/90)` — are **decimal file
/// numbers**, the unit the same issue defers as "later, guarded". Measured over the 159 volumes
/// whose coverage midpoint falls in 1910–1945: 4,877 footnotes name a decimal file, 67 name a lot,
/// and 120 name a library — of which the great majority are the head-nested *"Photostatic copy
/// obtained from the Franklin D. Roosevelt Library"* provenance statements the harvest excludes by
/// design. Lot files and presidential libraries are a post-1945 filing practice. **A surface built
/// on this index must not claim pre-war reach**; ``eraSpan`` reports what the data actually covers.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
struct ExternalCitationIndex: Decodable, Sendable {

    /// One archival unit's references, broken down by the volume whose footnotes made them.
    struct UnitRow: Decodable, Sendable {
        /// Index into ``targetIds``.
        let key: Int
        /// Volume indices, ascending.
        let volumes: [Int]
        /// Reference counts, parallel to ``volumes``.
        let counts: [Int]

        enum CodingKeys: String, CodingKey {
            case key = "k"
            case volumes = "v"
            case counts = "n"
        }

        /// References across every volume.
        var total: Int { counts.reduce(0, +) }
    }

    /// One (citing unit → cited unit) edge.
    struct Pair: Decodable, Sendable {
        /// Index into ``sourceIds`` — the citing document's *own* archival unit.
        let source: Int
        /// Index into ``targetIds`` — the unit its footnote points at.
        let target: Int
        /// References along this edge.
        let count: Int

        enum CodingKeys: String, CodingKey {
            case source = "f"
            case target = "t"
            case count = "n"
        }
    }

    /// What the scan saw. Every disclosure is computed from this, never written into a sentence a
    /// regenerated artifact would leave quietly wrong.
    struct Coverage: Decodable, Sendable {
        let volumesScanned: Int
        let volumesWithReferences: Int
        let documentsScanned: Int
        let footnotesScanned: Int
        let footnotesExcluded: Int
        let headNestedExcluded: Int
        let headNestedExcludedWithAnchor: Int
        let referencesFound: Int
        let referencesInherited: Int
        let absenceClaimsRefused: Int
        let lotReferences: Int
        let libraryReferences: Int
        let referencesJoined: Int
        let referencesWithBothEnds: Int
        let sameUnitReferences: Int
        let authorityCollectionCount: Int

        // MARK: Decimal channel (#834, schema 2)

        /// References naming a **central-file class**. Admitted by the shipped rule: the clause
        /// carries a class followed by its document serial and the key composes under the
        /// 1910-1949 schedule. Subject-numeric designators are out of scope by decision.
        let decimalReferences: Int
        /// Of those, the ones whose class came from a bare `Ibid.` inheriting an earlier
        /// footnote's class (#1014 W-1b). Any surface quoting the channel's size owes this
        /// split, the way the collection axis owes ``referencesInherited``.
        let decimalReferencesInherited: Int
        /// Decimal references whose citing document also has a class, so a class pair exists.
        let decimalReferencesWithBothEnds: Int
        /// Decimal pairs whose two ends are the **same class** — the document restating its own
        /// file rather than pointing outside itself. Stored and counted, never drawn.
        let decimalSameClassReferences: Int
        /// Candidates refused as subject-numeric (`POL 27 VIET S`).
        let decimalSubjectNumericRefused: Int
        /// Candidates whose key does not compose under the shipped schedule. The country table is
        /// incomplete, so some are false negatives; the count says how many are at stake.
        let decimalNotComposingRefused: Int
        /// Candidates refused because the key does not round-trip through the shared class
        /// vocabulary — a joinability rule, not an authenticity one. See the generator's note.
        let decimalNotInSharedVocabularyRefused: Int

        /// Decimal references a flow diagram can draw — both ends present and not the same class.
        var betweenClassReferences: Int {
            decimalReferencesWithBothEnds - decimalSameClassReferences
        }

        /// Share of the decimal channel that is a document citing its OWN file, `0...1`.
        ///
        /// **Any surface quoting the decimal channel owes this number.** Measured 74-76% pre-war:
        /// most of what the channel finds is provenance restated, not a pointer outside the
        /// document. Quoting `decimalReferences` alone overstates the layer by roughly 3x.
        var decimalSameClassShare: Double {
            guard decimalReferencesWithBothEnds > 0 else { return 0 }
            return Double(decimalSameClassReferences) / Double(decimalReferencesWithBothEnds)
        }

        /// References a flow diagram can actually draw.
        var betweenUnitReferences: Int { referencesWithBothEnds - sameUnitReferences }

        /// Share of references whose unit came from an `Ibid.` rather than a phrase of its own,
        /// `0...1`. The caveat quotes this rather than a written-down number.
        var inheritedShare: Double {
            guard referencesFound > 0 else { return 0 }
            return Double(referencesInherited) / Double(referencesFound)
        }
    }

    /// Artifact schema version.
    let schemaVersion: Int
    /// Generation date stamp.
    let generated: String
    /// Volumes contributing at least one reference, sorted — the index space for ``targets``.
    let volumes: [String]
    /// Authority collection ids reached as a citation target, sorted.
    let targetIds: [String]
    /// Authority collection ids reached as a citing document's own unit, sorted.
    let sourceIds: [String]
    /// Per-target references by volume.
    let targets: [UnitRow]
    /// (source → target) edges, including same-unit ones.
    let pairs: [Pair]

    // MARK: The class axis (#834, schema 2)

    /// Central-file class keys reached as a citation **target**, sorted.
    ///
    /// A second axis rather than more `targetIds`, because the authority has no class records —
    /// classes exist there only as id-less display children, so a bare `(681.8229/8-2950, not
    /// printed)` resolves to nothing. These keys share `collection-usage-index.json`'s vocabulary
    /// and are **not namespaced**, so they are the keys `ArchivalCollectionsData` already ranks and
    /// `decimal-class-labels.json` already glosses.
    let classTargetKeys: [String]
    /// Class keys reached as a citing document's **own** class, sorted.
    ///
    /// **This vocabulary holds BOTH filing systems, and the target one does not.** Subject-numeric
    /// designators (`POL 1 CHICOM USSR`, `DEF 18`) are out of scope as harvest TARGETS by owner
    /// decision — the footnote grammar refuses them — but a citing document filed under one is
    /// simply a fact about that document, and dropping it would discard real pairs whose target is
    /// a decimal file. So a pair may read `POL 1 CHICOM USSR -> 763.72`, meaning a
    /// subject-numeric-filed document cited a decimal one. Branch on
    /// `CollectionKeying.isSubjectNumericClass` before grouping or labelling.
    let classSourceKeys: [String]
    /// Per-target-class references by volume.
    let classTargets: [UnitRow]
    /// (source class → target class) edges. **Same-class edges are included** and are exactly
    /// those where `classSourceKeys[source] == classTargetKeys[target]`.
    let classPairs: [Pair]

    /// What the scan saw.
    let coverage: Coverage

    // MARK: - Lookups

    /// Total decimal references naming each class key, across every volume — the vocabulary the
    /// class lens ranks under the *unprinted pointers* weight.
    ///
    /// Same-class references are NOT excluded here: this counts references naming a class, which
    /// is a fact about the class, and the caller decides what to do about self-citation. A caller
    /// wanting only outward pointers should use ``classPairs`` and drop `source == target`.
    func classReferenceTotals() -> [String: Int] {
        var totals: [String: Int] = [:]
        for row in classTargets where row.key < classTargetKeys.count {
            totals[classTargetKeys[row.key]] = row.counts.reduce(0, +)
        }
        return totals
    }

    /// References **out of** a collection — where the editors, annotating material drawn from it,
    /// pointed the reader. Heaviest first, same-unit edges excluded.
    func outgoingReferences(fromCollectionId id: String) -> [(collectionId: String, count: Int)] {
        guard let index = sourceIds.firstIndex(of: id) else { return [] }
        return pairs
            .filter { $0.source == index && targetIds[$0.target] != id }
            .sorted { $0.count > $1.count }
            .map { (targetIds[$0.target], $0.count) }
    }

    /// References **into** a collection — which collections' documents were annotated by pointing
    /// at this one. Heaviest first, same-unit edges excluded.
    func incomingReferences(toCollectionId id: String) -> [(collectionId: String, count: Int)] {
        guard let index = targetIds.firstIndex(of: id) else { return [] }
        return pairs
            .filter { $0.target == index && sourceIds[$0.source] != id }
            .sorted { $0.count > $1.count }
            .map { (sourceIds[$0.source], $0.count) }
    }

    /// References from a collection to itself — the number the "between units only" disclosure has
    /// to quote.
    func sameUnitReferences(forCollectionId id: String) -> Int {
        guard let source = sourceIds.firstIndex(of: id),
              let target = targetIds.firstIndex(of: id) else { return 0 }
        return pairs.first { $0.source == source && $0.target == target }?.count ?? 0
    }

    /// Total references pointing at one collection, across every volume.
    func referenceCount(forCollectionId id: String) -> Int {
        guard let index = targetIds.firstIndex(of: id) else { return 0 }
        return targets.first { $0.key == index }?.total ?? 0
    }

    /// The volumes whose footnotes point at one collection, and how often.
    func volumeCounts(forCollectionId id: String) -> [(volumeId: String, count: Int)] {
        guard let index = targetIds.firstIndex(of: id),
              let row = targets.first(where: { $0.key == index }) else { return [] }
        return pairs(in: row)
    }

    /// Walks every (target, volume, count) the index carries, once.
    ///
    /// **For a caller that needs all of them**, which `volumeCounts(forCollectionId:)` cannot serve
    /// without a linear row scan per target — 995 targets against 995 rows. The era-banded pointer
    /// weight (#829c) needs exactly one pass, and this is it.
    ///
    /// - Parameter body: Called per reference group with the target id, the citing volume, and the
    ///   count.
    func forEachReference(_ body: (_ targetId: String, _ volumeId: String, _ count: Int) -> Void) {
        for row in targets {
            guard targetIds.indices.contains(row.key) else { continue }
            let id = targetIds[row.key]
            for pair in pairs(in: row) { body(id, pair.volumeId, pair.count) }
        }
    }

    /// Every decimal reference, as (class key, citing volume, count) — the class-axis twin of
    /// ``forEachReference(_:)``.
    ///
    /// Counts **every** reference naming the class, same-class ones included, exactly as the
    /// collection twin counts same-unit ones. That is a deliberate parity: both are per-TARGET
    /// tallies, and a class that a document cited about itself was still cited. The self-citation
    /// share is disclosed in the caveat (`Coverage.decimalSameClassShare`, 74-76% pre-war) rather
    /// than silently netted out here, because a reader comparing the two lenses would otherwise be
    /// comparing two different measures.
    func forEachClassReference(_ body: (_ classKey: String, _ volumeId: String, _ count: Int) -> Void) {
        for row in classTargets {
            guard classTargetKeys.indices.contains(row.key) else { continue }
            let key = classTargetKeys[row.key]
            for pair in pairs(in: row) { body(key, pair.volumeId, pair.count) }
        }
    }

    /// One row's volumes zipped to its counts.
    ///
    /// **The single place the parallel arrays are zipped.** They arrive under one-letter wire names
    /// (`v`/`n`) and nothing in the format enforces that they are the same length, so a second
    /// implementation of this join is a second thing that can silently drift from the first —
    /// producing plausible counts against the wrong volumes. `ExternalCitationTests` pins it.
    ///
    /// - Parameter row: The stored row.
    /// - Returns: The volume ids and their counts, dropping any index the volume table lacks.
    private func pairs(in row: UnitRow) -> [(volumeId: String, count: Int)] {
        zip(row.volumes, row.counts).compactMap { volumeIndex, count in
            guard volumes.indices.contains(volumeIndex) else { return nil }
            return (volumes[volumeIndex], count)
        }
    }

    /// The corpus-wide heaviest (source → target) pairs, excluding same-unit edges.
    func heaviestPairs(limit: Int) -> [(sourceId: String, targetId: String, count: Int)] {
        pairs
            .filter { sourceIds[$0.source] != targetIds[$0.target] }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { (sourceIds[$0.source], targetIds[$0.target], $0.count) }
    }

    /// The earliest and latest coverage years the referencing volumes span, from the manifest.
    ///
    /// Exists so a surface can state the era reach it *has* instead of the one #784 predicted —
    /// see the type's note. Returns `nil` when no referencing volume carries a coverage range.
    func eraSpan(entriesById: [String: VolumeManifestEntry]) -> ClosedRange<Int>? {
        var earliest: Int?
        var latest: Int?
        for volumeId in volumes {
            guard let entry = entriesById[volumeId] else { continue }
            if let year = entry.dateRange.earliest.flatMap({ Int($0.prefix(4)) }) {
                earliest = min(earliest ?? year, year)
            }
            if let year = entry.dateRange.latest.flatMap({ Int($0.prefix(4)) }) {
                latest = max(latest ?? year, year)
            }
        }
        guard let earliest, let latest, earliest <= latest else { return nil }
        return earliest...latest
    }
}

// MARK: - ExternalCitationIndexStore

/// Loads and caches the bundled `external-citation-index.json`.
///
/// `shared` is `nil` only when the resource is missing or cannot be decoded; consumers must treat
/// that as "footnote citations are unavailable", never as "this collection is never cited".
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
enum ExternalCitationIndexStore {

    /// The bundled index, or `nil` when unavailable.
    static let shared: ExternalCitationIndex? = load()

    private static func load() -> ExternalCitationIndex? {
        guard let url = Bundle.main.url(forResource: "external-citation-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] ExternalCitationIndexStore: external-citation-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(ExternalCitationIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] ExternalCitationIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
