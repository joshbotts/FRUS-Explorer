// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalVolumeCoverage

/// One volume's coverage span, as the archival-analytics joins need it.
///
/// Carried as a value rather than read back off the manifest inside the derivation, so the
/// whole Collections computation is a pure function of its inputs and the tests can drive it
/// with a synthetic corpus.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
struct ArchivalVolumeCoverage: Sendable, Equatable {
    /// Earliest coverage year.
    let firstYear: Int
    /// Latest coverage year.
    let lastYear: Int

    /// The midpoint SA-3a and #762 both attribute by — `(first + last) / 2`.
    var midpointYear: Int { (min(firstYear, lastYear) + max(firstYear, lastYear)) / 2 }

    /// Creates a coverage span, ordering the endpoints.
    init(firstYear: Int, lastYear: Int) {
        self.firstYear = min(firstYear, lastYear)
        self.lastYear = max(firstYear, lastYear)
    }
}

extension ArchivalVolumeCoverage {

    /// The coverage map both archival surfaces bucket by, built from manifest entries (#835).
    ///
    /// Shared rather than duplicated because the coverage map **is** the volume set: every scope
    /// on both surfaces is expressed by restricting it, so two builders would be two definitions
    /// of what a scope means. It is also the input the parity test needs to drive directly, which
    /// a `@MainActor` view method could not offer.
    ///
    /// A volume with no parseable year at either end of its `dateRange` is **skipped**, not
    /// defaulted — an invented year would place it in a band on no evidence.
    ///
    /// - Parameters:
    ///   - entries: The manifest entries to read spans from.
    ///   - allowed: The scope's volume ids, or `nil` for every entry.
    /// - Returns: `volumeId -> span`, carrying only the in-scope, year-bearing volumes.
    static func map(from entries: [VolumeManifestEntry],
                    limitedTo allowed: Set<String>? = nil) -> [String: ArchivalVolumeCoverage] {
        var result: [String: ArchivalVolumeCoverage] = [:]
        result.reserveCapacity(allowed?.count ?? entries.count)
        for entry in entries {
            if let allowed, !allowed.contains(entry.volumeId) { continue }
            let first = FRUSVolumeMetadata.firstYear(in: entry.dateRange.earliest)
            let last = FRUSVolumeMetadata.firstYear(in: entry.dateRange.latest)
            guard let start = first ?? last, let end = last ?? first else { continue }
            result[entry.volumeId] = ArchivalVolumeCoverage(firstYear: start, lastYear: end)
        }
        return result
    }
}

// MARK: - ArchivalRankingRow

/// One bar in a Collections-mode ranking.
struct ArchivalRankingRow: Identifiable, Sendable, Equatable {
    /// The unit's stable key — an authority collection id, or a class key.
    let id: String
    /// The label drawn on the axis. Unique within a ranking; see
    /// ``ArchivalCollectionsData/disambiguate(_:)``.
    let label: String
    /// The row's own name before disambiguation, for detail copy and accessibility.
    let name: String
    /// The custodian bucket the bar is coloured by.
    let category: ArchivalRepositoryCategory
    /// Documents or volumes, per the ranking's weight.
    let value: Int
    /// On the class lens, the leaf keys folded into this row — `POL 27 VIET S` and its siblings
    /// under `POL 27`. Empty on the collections lens, and empty for a decimal file number, which
    /// is already the grain a reader writes on a pull slip.
    ///
    /// A row is a *family* when this holds anything other than the row's own key: the leaf is
    /// what NARA is asked for, so folding it out of sight without a way back would trade a
    /// rankable chart for an unusable one.
    var leaves: [ArchivalClassLeaf] = []

    /// Whether this row folds names a reader would need to see to act on it.
    var isFamily: Bool {
        leaves.count > 1 || (leaves.count == 1 && leaves[0].key != id)
    }
    /// The class key's reading in plain words, or `nil` (#828).
    ///
    /// Declared LAST so the memberwise initialiser takes it last and no existing call site has to
    /// move. Only the class lens carries one, and only where the bundled schedule covers the era
    /// and knows the country. Kept BESIDE the key rather than replacing it: the key is what a pull
    /// slip needs, so every surface shows both.
    var gloss: String?

}

// MARK: - ArchivalClassLeaf

/// One subject-numeric leaf inside a folded family row (`POL 27 VIET S` under `POL 27`).
struct ArchivalClassLeaf: Identifiable, Sendable, Equatable {
    /// The full class key, as a source note wrote it and as a pull slip needs it.
    let key: String
    /// Documents this leaf supplies in the band.
    let documents: Int
    /// Volumes citing this leaf in the band.
    ///
    /// Carried beside `documents` so an expanded family can be read in the **same unit as the
    /// bar above it**. Without it a row measured in volumes — say 36 — expands to leaves summing
    /// to several hundred, and the arithmetic a reader does in their head is wrong in a way the
    /// screen never explains.
    let volumes: Int

    var id: String { key }

    /// This leaf's value under one weight, so the expansion always matches its bar.
    func value(weight: ArchivalWeight) -> Int {
        weight == .documents ? documents : volumes
    }
}

// MARK: - ArchivalRanking

/// A ranked list plus everything a caller must disclose about it.
struct ArchivalRanking: Sendable, Equatable {
    /// The bars, heaviest first.
    let rows: [ArchivalRankingRow]
    /// The umbrella record's own value in this band, when it was hidden and had one.
    ///
    /// `nil` means nothing was hidden — either the filter is off, or the umbrella contributes
    /// nothing to this band. The two are different and the disclosure line says which: the
    /// umbrella supplies 12,060 documents to the 1948–1960 band and **none at all** before
    /// 1948, so a fixed "157 volumes hidden" sentence would be wrong in three bands of five.
    let hiddenUmbrellaValue: Int?
    /// Units with a non-zero value in this band, before the row cap.
    let unitsReached: Int
    /// Volumes whose coverage midpoint falls in this band.
    let bandVolumeCount: Int
    /// Source notes scanned across the band's volumes — the denominator for every share below.
    /// Zero when the usage index is absent, in which case no share may be stated.
    var bandNoteCount: Int = 0
    /// What the **drawn** rows account for, in the weight's own unit.
    var shownValue: Int = 0

    /// The drawn rows' share of the band's source notes, or `nil` when it cannot be stated.
    ///
    /// Only meaningful under the documents weight: a share needs a numerator and denominator
    /// counting the same thing, and the volumes weight counts volumes against a note total.
    /// `nil` rather than a wrong number is the whole point of the field.
    /// **Documents only, and that now excludes two weights rather than one.** The denominator is
    /// the band's source-note count, which is the population documents are drawn from; a volume
    /// count is not a share of it, and neither is a footnote-pointer count — pointers are read from
    /// editorial footnotes, not from source notes at all, so the ratio would divide two unrelated
    /// populations and print a plausible percentage. Leave this gated on `.documents`.
    func shownShare(weight: ArchivalWeight) -> Double? {
        guard weight == .documents, bandNoteCount > 0, shownValue > 0 else { return nil }
        return Double(shownValue) / Double(bandNoteCount)
    }
}

// MARK: - ArchivalCollectionsData

/// The corpus-wide Collections-mode derivation: era band × archival unit, under either weight
/// and either unit lens.
///
/// ## Where the numbers come from
/// - **Documents** come from `collection-usage-index.json` (#763) — per-(unit, volume) counts
///   over document source notes.
/// - **Volumes** come from `collection-authority.json` — a volume counts when its front matter
///   *or* a document source note names the collection.
///
/// Those two populations are not the same, and the difference is the point rather than a
/// defect: 2,595 of the authority's 4,423 records are named in a volume's front matter and
/// never resolved from a document note, so they rank under Volumes and vanish under Documents.
/// The mode's footnote block says so. The class lens has no such split — a class key only ever
/// comes from a parsed document note — so both weights there are computed from the usage index.
///
/// ## Cost
/// ``make(authority:usage:coverage:)`` walks every record's volume list and every usage row
/// once: roughly 12,000 memberships and 12,000 usage rows on the shipped artifacts. It is
/// built once per visit off the main actor and every ranking after that is a dictionary read
/// and a sort.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
///   1.1 — Session 2026-08-10: #832(c) — the lifecycle span type and its derivation removed;
///          the authority loop stays because it is the Volumes weight's only writer
///   1.2 — Session 2026-08-10: #826 — the class lens folds to one grain with its leaves kept,
///          and the per-band source-note denominator is read from the usage index at last
///   1.3 — Session 2026-08-10: #825 — `record(forId:)`, so a drawn row can find its authority
///          record without the view reaching into the derivation's tables
///   1.4 — Session 2026-08-11: #835 — `ranking(bands:…)` merges several era bands before
///         disambiguating (the merge cannot happen in a caller: 279 shipped names are
///         carried by more than one record), and `ArchivalVolumeCoverage.map(from:limitedTo:)`
///         becomes the one definition of what a scope means
///   1.5 — Session 2026-08-11: #828 — class rows carry a `gloss`, attached where the row is
///         BUILT so every surface reading a ranking gets it: chart, uncapped list, CSV, card
///   1.6 — Session 2026-08-11: #828 — a class label is decided by the coverage of the volumes
///         citing THAT KEY (`classSpans`, `gloss(forKey:bands:)`) rather than by the era band's
///         own years, which straddle the 1950 renumbering in every band after the first
struct ArchivalCollectionsData: Sendable {

    /// The authority id of the `Central Files` umbrella — the record the design hides by
    /// default.
    ///
    /// Measured on the shipped authority: 157 citing volumes and 17,587 documents, against
    /// 7,056 for the next-largest collection in the series. Hiding it is a scale decision, not
    /// a claim that it is uninteresting, which is why the filter is a visible chip and the
    /// hidden value is always stated.
    ///
    /// The era-specific `Central Files 1970–73` / `1967–69` / `1964–66` records are separate
    /// authority records and are **not** hidden: they are the era's real central-file bar, and
    /// suppressing them would remove the State Department from the very charts that show it
    /// losing ground to the White House.
    static let umbrellaCollectionId = "txt:department of state|central file"

    /// Rows shown per ranking before "Show more".
    static let rowCap = 12

    /// Per-band document counts by authority collection id.
    private let collectionDocuments: [[String: Int]]
    /// Per-band citing-volume counts by authority collection id.
    private let collectionVolumes: [[String: Int]]
    /// Per-band document counts by **folded** class key.
    private let classDocuments: [[String: Int]]
    /// Per-band citing-volume counts by folded class key.
    private let classVolumes: [[String: Int]]
    /// Per-band leaves inside each folded class key, heaviest first.
    private let classLeaves: [[String: [ArchivalClassLeaf]]]
    /// The label table class rows are read against.
    ///
    /// Injected rather than reached for, so a test can drive the derivation against a table with
    /// TWO schedules. The shipped artifact carries one, which makes the whole renumbering rule —
    /// and in particular the lower bound of a key's coverage span — unobservable through any
    /// output: with a single schedule the clamp handles every lower bound that could matter. The
    /// rule this parameter exists to test is the one the next schedule will land on.
    private let labels: DecimalClassLabelTable?
    /// Per-band coverage span of the volumes citing each folded class key.
    ///
    /// The evidence a class label rests on. See ``gloss(forKey:bands:)``: a decimal key means
    /// different things either side of the 1950 renumbering, and the years that decide which
    /// schedule may speak belong to the volumes citing the key, not to the era band the chart
    /// happens to be grouping by.
    private let classSpans: [[String: ClosedRange<Int>]]
    /// Volumes per band.
    private let bandVolumeCounts: [Int]
    /// Source notes scanned per band — the denominator every share on this surface needs.
    ///
    /// Shipped in `collection-usage-index.json` as `volumeNoteCounts` since #763 and read by
    /// nothing until now, which is why the mode could open on a band where its twelve bars
    /// account for 9.4% of the sourced documents and say nothing about it.
    private let bandNoteCounts: [Int]
    /// Authority records by id, for labels and categories.
    private let records: [String: AuthorityCollectionRecord]

    /// Whether document weights are available at all — `false` when the usage index is missing,
    /// in which case the Documents weight must be disabled rather than shown as zeroes.
    let supportsDocumentWeight: Bool

    /// Footnote references pointing at each collection, per band.
    ///
    /// **A different body of evidence from the two beside it**, and the reason the weight is a swap
    /// rather than a third column: `collectionDocuments` and `collectionVolumes` both count where
    /// FRUS *drew documents from*; this counts what its footnotes *pointed at* and FRUS did not
    /// print. The two are never added — that addition is the defect #783 removed.
    let collectionPointers: [[String: Int]]

    /// Whether the pointer weight can be drawn — `false` when the external-citation index is
    /// missing, in which case the weight is disabled rather than ranking an empty table.
    let supportsPointerWeight: Bool

    /// Volumes the derivation could place in a band (i.e. whose coverage parsed).
    let volumesPlaced: Int

    // MARK: - Building

    /// Builds the whole derivation in one pass over the two artifacts.
    ///
    /// - Parameters:
    ///   - authority: Every authority record.
    ///   - usage: The bundled usage index, or `nil` when it failed to load.
    ///   - coverage: Coverage spans by volume id. Volumes absent here are skipped entirely —
    ///     they cannot be attributed to a band without a coverage year.
    static func make(authority: [AuthorityCollectionRecord],
                     usage: CollectionUsageIndex?,
                     coverage: [String: ArchivalVolumeCoverage],
                     external: ExternalCitationIndex? = ExternalCitationIndexStore.shared,
                     labels: DecimalClassLabelTable? = DecimalClassLabelStore.shared)
        -> ArchivalCollectionsData {
        let bandCount = ArchivalEraBand.all.count
        var bandByVolume: [String: Int] = [:]
        bandByVolume.reserveCapacity(coverage.count)
        var bandVolumeCounts = [Int](repeating: 0, count: bandCount)
        for (volumeId, span) in coverage {
            let band = ArchivalEraBand.band(forMidpointYear: span.midpointYear).index
            bandByVolume[volumeId] = band
            bandVolumeCounts[band] += 1
        }

        var records: [String: AuthorityCollectionRecord] = [:]
        records.reserveCapacity(authority.count)
        var collectionVolumes = [[String: Int]](repeating: [:], count: bandCount)
        // This loop is the ranking's only source for two things: `records`, which supplies every
        // row's label and custodian, and `collectionVolumes`, the **sole** writer of the named-
        // collection lens's Volumes weight. It is not bookkeeping for a chart — deleting it would
        // leave the ranking rendering an empty Volumes weight rather than failing.
        for record in authority {
            records[record.id] = record
            for volumeId in record.volumeIds {
                // `bandByVolume` is populated from `coverage` above, so membership here already
                // implies a coverage span; the band is all this pass needs from it.
                guard let band = bandByVolume[volumeId] else { continue }
                collectionVolumes[band][record.id, default: 0] += 1
            }
        }

        var collectionDocuments = [[String: Int]](repeating: [:], count: bandCount)
        var classDocuments = [[String: Int]](repeating: [:], count: bandCount)
        var classVolumes = [[String: Int]](repeating: [:], count: bandCount)
        var classLeaves = [[String: [ArchivalClassLeaf]]](repeating: [:], count: bandCount)
        var classSpans = [[String: ClosedRange<Int>]](repeating: [:], count: bandCount)
        var bandNoteCounts = [Int](repeating: 0, count: bandCount)
        if let usage {
            // The collection lens takes its volume weight from the authority instead (see the
            // type's note), so the counts this pass produces for it are deliberately dropped.
            _ = tally(usage.collections, keys: usage.collectionIds, volumes: usage.volumes,
                      bandByVolume: bandByVolume, into: &collectionDocuments)
            (classVolumes, classLeaves) = tallyClasses(
                usage.classes, keys: usage.classKeys, volumes: usage.volumes,
                bandByVolume: bandByVolume, coverage: coverage,
                into: &classDocuments, spans: &classSpans)
            for (index, volumeId) in usage.volumes.enumerated() {
                guard let band = bandByVolume[volumeId],
                      usage.volumeNoteCounts.indices.contains(index) else { continue }
                bandNoteCounts[band] += usage.volumeNoteCounts[index]
            }
        }

        // The pointer weight, banded by the CITING volume's coverage — the same rule the other two
        // use, so the bands still partition the corpus and a multi-band ranking can add them.
        var collectionPointers = [[String: Int]](repeating: [:], count: bandCount)
        if let external {
            external.forEachReference { targetId, volumeId, count in
                guard let band = bandByVolume[volumeId] else { return }
                collectionPointers[band][targetId, default: 0] += count
            }
        }

        return ArchivalCollectionsData(
            collectionDocuments: collectionDocuments,
            collectionVolumes: collectionVolumes,
            classDocuments: classDocuments,
            classVolumes: classVolumes,
            classLeaves: classLeaves,
            labels: labels,
            classSpans: classSpans,
            bandVolumeCounts: bandVolumeCounts,
            bandNoteCounts: bandNoteCounts,
            records: records,
            supportsDocumentWeight: usage != nil,
            collectionPointers: collectionPointers,
            supportsPointerWeight: external != nil,
            volumesPlaced: bandByVolume.count)
    }

    /// The class vocabulary's per-band totals, **folded to one grain**, with the leaves kept.
    ///
    /// ## Why the fold happens here and not at display time
    /// The artifact's class vocabulary holds two filing systems (#763): decimal file numbers
    /// (`763.72`) and subject-numeric designators (`POL 27 VIET S`). Ranking them raw put two
    /// grains in one chart — a decimal row is a whole class, a subject-numeric row one country's
    /// slice of one — and it split the heaviest unit in the corpus: raw, 1961–1968 leads with
    /// `POL 27 VIET S` at 463; folded, `POL 27` is 1,090. Owner decision **D-3** admits the
    /// subject-numeric lens at category+number, and the Network already folds there through the
    /// same `CollectionKeying.subjectNumericGroup`.
    ///
    /// ## The volumes weight cannot be folded by addition
    /// A volume citing `POL 27 VIET S` **and** `POL 27 ARAB-ISR` is one citing volume of
    /// `POL 27`, not two. The raw tally counts one `(key, volume)` pair per stored pair, which is
    /// exactly right at leaf grain and double-counts the moment leaves merge — so this pass
    /// accumulates a *set* of volume ids per folded key and counts it at the end. `ArchivalNetworkData`
    /// carries the same warning for the same reason on its own axis.
    ///
    /// - Returns: Per-band volume counts, and per-band leaves by folded key (heaviest first).
    private static func tallyClasses(_ rows: [CollectionUsageIndex.UsageRow], keys: [String],
                                     volumes: [String], bandByVolume: [String: Int],
                                     coverage: [String: ArchivalVolumeCoverage],
                                     into documents: inout [[String: Int]],
                                     spans: inout [[String: ClosedRange<Int>]])
        -> ([[String: Int]], [[String: [ArchivalClassLeaf]]]) {
        let bandCount = documents.count
        var volumeSets = [[String: Set<String>]](repeating: [:], count: bandCount)
        var leafDocuments = [[String: [String: Int]]](repeating: [:], count: bandCount)
        var leafVolumes = [[String: [String: Set<String>]]](repeating: [:], count: bandCount)
        for row in rows where keys.indices.contains(row.key) {
            let leaf = keys[row.key]
            // A decimal file number folds to itself: it is already the unit a pull slip names.
            let group = CollectionKeying.subjectNumericGroup(leaf) ?? leaf
            for (position, volumeIndex) in row.volumes.enumerated()
            where volumes.indices.contains(volumeIndex) {
                let volumeId = volumes[volumeIndex]
                guard let band = bandByVolume[volumeId] else { continue }
                documents[band][group, default: 0] += row.counts[position]
                volumeSets[band][group, default: []].insert(volumeId)
                // The span is WIDENED across every contributor, not overwritten: a key cited from
                // both sides of the 1950 renumbering must span it and stay unlabelled, and a rule
                // that tracked the last volume seen would label it from whichever one the row
                // happened to end on.
                //
                // Keyed by the FOLDED key, matching `documents` on the line above and the grain
                // the label is looked up at. Only subject-numeric keys fold, and none of those
                // resolves against a decimal schedule, so today this is a choice about what the
                // structure MEANS rather than one any output can distinguish.
                if let years = coverage[volumeId] {
                    let existing = spans[band][group]
                    let low = min(existing?.lowerBound ?? years.firstYear, years.firstYear)
                    let high = max(existing?.upperBound ?? years.lastYear, years.lastYear)
                    spans[band][group] = low...high
                }
                leafDocuments[band][group, default: [:]][leaf, default: 0] += row.counts[position]
                leafVolumes[band][group, default: [:]][leaf, default: []].insert(volumeId)
            }
        }

        var volumeCounts = [[String: Int]](repeating: [:], count: bandCount)
        var leaves = [[String: [ArchivalClassLeaf]]](repeating: [:], count: bandCount)
        for band in 0..<bandCount {
            volumeCounts[band] = volumeSets[band].mapValues(\.count)
            let volumesByLeaf = leafVolumes[band]
            leaves[band] = leafDocuments[band].map { group, byLeaf in
                (group, byLeaf
                    .map { ArchivalClassLeaf(
                        key: $0.key, documents: $0.value,
                        volumes: volumesByLeaf[group]?[$0.key]?.count ?? 0) }
                    // Heaviest first, then by key: a total order, so the expansion a reader sees
                    // is the same on every launch.
                    .sorted { $0.documents != $1.documents ? $0.documents > $1.documents
                                                           : $0.key < $1.key })
            }.reduce(into: [String: [ArchivalClassLeaf]]()) { $0[$1.0] = $1.1 }
        }
        return (volumeCounts, leaves)
    }

    /// Folds one usage vocabulary's rows into per-band document totals, returning the matching
    /// per-band count of *volumes* each key appears in.
    ///
    /// A key's volume count is the number of `(key, volume)` pairs the artifact stores for it in
    /// the band — every stored pair carries a non-zero count by construction, so a pair is
    /// exactly one citing volume.
    private static func tally(_ rows: [CollectionUsageIndex.UsageRow], keys: [String],
                              volumes: [String], bandByVolume: [String: Int],
                              into documents: inout [[String: Int]]) -> [[String: Int]] {
        var volumeCounts = [[String: Int]](repeating: [:], count: documents.count)
        for row in rows where keys.indices.contains(row.key) {
            let key = keys[row.key]
            for (position, volumeIndex) in row.volumes.enumerated()
            where volumes.indices.contains(volumeIndex) {
                guard let band = bandByVolume[volumes[volumeIndex]] else { continue }
                documents[band][key, default: 0] += row.counts[position]
                volumeCounts[band][key, default: 0] += 1
            }
        }
        return volumeCounts
    }

    // MARK: - Rankings

    /// The ranked units in one band.
    ///
    /// - Parameters:
    ///   - band: The era band.
    ///   - lens: Named collections or central-file classes.
    ///   - weight: Documents or volumes.
    ///   - hidingUmbrella: Whether to drop the `Central Files` umbrella record. Ignored on the
    ///     class lens, which has no umbrella — a class key is already a leaf.
    ///   - limit: Rows returned.
    func ranking(band: ArchivalEraBand, lens: ArchivalUnitLens, weight: ArchivalWeight,
                 hidingUmbrella: Bool, limit: Int = rowCap) -> ArchivalRanking {
        ranking(bands: [band], lens: lens, weight: weight,
                hidingUmbrella: hidingUmbrella, limit: limit)
    }

    /// The same ranking over SEVERAL era bands at once — what a whole-scope card asks for (#835).
    ///
    /// ## The summation is exact, for both weights
    /// `make` writes `bandByVolume[volumeId]` exactly once per volume, so **the bands partition
    /// the corpus**. A unit's citing volumes in band *i* and band *j* are therefore disjoint sets,
    /// and adding the per-band tables double-counts nothing — under Documents *or* under Volumes.
    /// That is not the case for the class lens's *leaves within one band*, which is why
    /// ``tallyClasses`` accumulates volume-id sets there; the two situations look alike and are
    /// not, so the distinction is stated here rather than left to be rediscovered.
    ///
    /// ## Why the merge is here and not in a view
    /// ``disambiguate(_:records:)`` runs per ranking, and 279 shipped authority names are carried
    /// by more than one record. Rows unique inside their own band can collide the moment the bands
    /// are merged — and Swift Charts silently draws two bars sharing a label as one. A caller that
    /// merged five rankings itself would produce exactly that, so the merge happens before
    /// disambiguation, inside the type that owns it.
    ///
    /// Per #763 no era rollup is stored: this sums the per-band rows at render time.
    ///
    /// - Parameters:
    ///   - bands: The bands to combine. Order is irrelevant; duplicates would double-count, so
    ///     they are dropped.
    ///   - lens: Named collections or central-file classes.
    ///   - weight: Documents or volumes.
    ///   - hidingUmbrella: Whether to drop the `Central Files` umbrella record.
    ///   - limit: Rows returned.
    /// - Returns: The merged ranking. Its `bandVolumeCount` and `bandNoteCount` are the totals
    ///   over the requested bands, so a share computed from them describes the same population.
    func ranking(bands: [ArchivalEraBand], lens: ArchivalUnitLens, weight: ArchivalWeight,
                 hidingUmbrella: Bool, limit: Int = rowCap) -> ArchivalRanking {
        // Deduplicated so a caller passing the same band twice cannot silently double every
        // figure in the card that draws it.
        var seen = Set<Int>()
        let indices = bands.map(\.index).filter { seen.insert($0).inserted }

        var table: [String: Int] = [:]
        for index in indices {
            let source: [String: Int]
            switch (lens, weight) {
            case (.namedCollections, .documents): source = collectionDocuments[index]
            case (.namedCollections, .volumes): source = collectionVolumes[index]
            case (.namedCollections, .unprintedPointers): source = collectionPointers[index]
            case (.centralFileClasses, .documents): source = classDocuments[index]
            case (.centralFileClasses, .volumes): source = classVolumes[index]
            // **The class lens has no pointer vocabulary at all.** #784's harvest covers lot files
            // and presidential libraries; it never reads a decimal class, so there is nothing to
            // rank. The weight is disabled on this lens in the UI (`supports(_:for:)`), and this
            // case exists so the combination degrades to an empty ranking rather than to whichever
            // table an inexhaustive switch would have fallen through to.
            case (.centralFileClasses, .unprintedPointers): source = [:]
            }
            if table.isEmpty {
                table = source
            } else {
                table.merge(source, uniquingKeysWith: +)
            }
        }

        let hidesUmbrella = hidingUmbrella && lens == .namedCollections
        let hiddenValue = hidesUmbrella ? table[Self.umbrellaCollectionId] : nil
        let ranked = table
            .filter { $0.value > 0 && !(hidesUmbrella && $0.key == Self.umbrellaCollectionId) }
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                return a.key < b.key
            }

        let rows = ranked.prefix(limit).map { key, value -> ArchivalRankingRow in
            switch lens {
            case .namedCollections:
                let record = records[key]
                return ArchivalRankingRow(
                    id: key, label: record?.name ?? key, name: record?.name ?? key,
                    category: record.map(ArchivalRepositoryCategory.from) ?? .otherInstitution,
                    value: value)
            case .centralFileClasses:
                // Every class key is a heading inside the State Department's own central
                // filing system, so the whole lens is one colour. It is not "other".
                // The single injection point: every surface that draws a class row — the
                // ranking, the uncapped list, the exports, the guide card — reaches it through
                // this call, which is what #828's "one label source" means in practice.
                return ArchivalRankingRow(id: key, label: key, name: key,
                                          category: .stateDepartment, value: value,
                                          leaves: mergedLeaves(forKey: key, bands: indices),
                                          gloss: gloss(forKey: key, bands: indices))
            }
        }

        let labelled = Self.disambiguate(Array(rows), records: records)
        return ArchivalRanking(rows: labelled,
                               hiddenUmbrellaValue: (hiddenValue ?? 0) > 0 ? hiddenValue : nil,
                               unitsReached: ranked.count,
                               bandVolumeCount: indices.reduce(0) { $0 + bandVolumeCounts[$1] },
                               bandNoteCount: indices.reduce(0) { $0 + bandNoteCounts[$1] },
                               shownValue: labelled.reduce(0) { $0 + $1.value })
    }

    /// One class key's reading in plain words, from the coverage of the volumes citing IT (#828).
    ///
    /// ## The band is a display grouping; the key's own volumes are the evidence
    /// The classification was renumbered in 1950, so a label is only safe when one schedule covers
    /// the documents behind the key. Asking that of the *era band* asks the wrong question: band 1
    /// runs 1948–1960 and spans three schedules, so no schedule can ever speak for it however many
    /// are parsed — while the keys inside it are cited by volumes that mostly sit squarely in one.
    /// `862.00` is cited only by volumes covering 1948–1949, and the 1910–49 schedule says exactly
    /// what it means.
    ///
    /// This is a **prerequisite, not a refinement**. With the band's span the two later schedules
    /// would label nothing at all once parsed: band 1's 1960 falls outside 1951–59 and band 2's
    /// 1968 outside 1960–63, so every key in the eras those schedules exist for would still render
    /// bare.
    ///
    /// Measured on the shipped artifact, which carries the 1910–49 schedule alone: band 0 is
    /// unchanged key for key, band 1 gains 310 keys and **966 documents**, and bands 2–4 gain
    /// nothing until their schedules are parsed. A merged-band selection — which no class-lens
    /// surface makes today, though the entry point exists — goes from labelling **nothing** to
    /// 67,213 documents, because the union of two bands' years is covered by no schedule at all.
    ///
    /// ## The span is a union, and it can only take a label away
    /// A key cited by volumes running 1930–1940 and 1955–1960 yields 1930...1960, which no schedule
    /// governs, so it stays bare. That is the same conservatism the band rule had, applied to the
    /// population it is actually about.
    ///
    /// - Parameters:
    ///   - key: A folded class key.
    ///   - bands: The band indices being ranked.
    /// - Returns: The gloss, or `nil` when no schedule covers the key's coverage. A key with no
    ///   recorded span also yields `nil`, though that branch is unreachable: the tally writes a
    ///   span and a document count in the same step, under the same guard, so a row that exists
    ///   has a span. Reaching for the band's years there would be the one place the replaced rule
    ///   survived, and only for the rows whose evidence was missing.
    private func gloss(forKey key: String, bands: [Int]) -> String? {
        var low: Int?
        var high: Int?
        for index in bands {
            guard let span = classSpans[index][key] else { continue }
            low = min(low ?? span.lowerBound, span.lowerBound)
            high = max(high ?? span.upperBound, span.upperBound)
        }
        guard let low, let high else { return nil }
        return labels?.gloss(for: key, coveringYears: low...high)
    }

    /// One class key's leaves across several bands, folded and re-ranked.
    ///
    /// Both figures add across bands for the reason the ranking's own note gives — the bands
    /// partition the volumes — so a leaf's documents and its citing volumes are each a plain sum.
    ///
    /// - Parameters:
    ///   - key: The folded class key whose leaves are wanted.
    ///   - bands: The band indices to combine.
    /// - Returns: The merged leaves, heaviest by documents first, then by key.
    private func mergedLeaves(forKey key: String, bands: [Int]) -> [ArchivalClassLeaf] {
        if bands.count == 1 { return classLeaves[bands[0]][key] ?? [] }
        var documents: [String: Int] = [:]
        var volumes: [String: Int] = [:]
        for index in bands {
            for leaf in classLeaves[index][key] ?? [] {
                documents[leaf.key, default: 0] += leaf.documents
                volumes[leaf.key, default: 0] += leaf.volumes
            }
        }
        return documents
            .map { ArchivalClassLeaf(key: $0.key, documents: $0.value,
                                     volumes: volumes[$0.key] ?? 0) }
            .sorted { a, b in
                if a.documents != b.documents { return a.documents > b.documents }
                return a.key < b.key
            }
    }

    /// Documents one lens reaches in a band, across every unit — the numerator behind "how much
    /// of this era's sourcing does this lens even see".
    ///
    /// Not a share on its own: a source note can name a collection *and* a central-file number,
    /// so the two lenses' reaches overlap and must never be added or subtracted. It is used only
    /// to decide whether the *other* lens would show a reader materially more of the same band,
    /// which is the one comparison the overlap does not spoil.
    func reach(band: ArchivalEraBand, lens: ArchivalUnitLens) -> Int {
        let table = lens == .namedCollections
            ? collectionDocuments[band.index]
            : classDocuments[band.index]
        return table.values.reduce(0, +)
    }

    /// The authority record behind a ranking row, or `nil` when the row has none.
    ///
    /// Not every drawn row has one. A collection row's id comes from whichever table the weight
    /// selected, and the documents table is keyed by the **usage index**, which can name an id the
    /// authority does not carry; the ranking already falls back to the raw id for such a row's
    /// label. Callers that navigate must therefore treat `nil` as "this row does not open"
    /// rather than as an error — a row with no record has no detail screen to show.
    func record(forId id: String) -> AuthorityCollectionRecord? {
        records[id]
    }

    /// Source notes scanned across a band's volumes, or `nil` when the usage index is absent.
    func noteCount(band: ArchivalEraBand) -> Int? {
        let count = bandNoteCounts[band.index]
        return count > 0 ? count : nil
    }

    // MARK: - Label disambiguation

    /// Makes every label in a set unique, because a Swift Charts categorical axis keys on the
    /// label string and **silently merges two bars that share one**.
    ///
    /// This is not hypothetical tidying. 279 of the shipped authority's names are carried by
    /// more than one record — `White House Central Files` by nine — and two of the five era
    /// bands hit a collision inside their visible top twelve: `NSC Institutional Files` in
    /// 1969–1976, `National Security Council` in 1977–1992, where a Ford Library record and a
    /// NARA record would otherwise have been drawn as one bar carrying the sum of both.
    ///
    /// Repeated names gain their repository; a name repeated *within* one repository gains the
    /// authority id, which is unique by construction. Unique names are left alone, so the
    /// common case reads clean.
    private static func disambiguate(_ rows: [ArchivalRankingRow],
                                     records: [String: AuthorityCollectionRecord])
        -> [ArchivalRankingRow] {
        let repeated = repeatedNames(rows.map(\.name))
        guard !repeated.isEmpty else { return rows }
        var used = Set<String>()
        return rows.map { row in
            guard repeated.contains(row.name) else {
                used.insert(row.label)
                return row
            }
            var label = row.name
            if let repository = records[row.id]?.repository {
                label = "\(row.name) · \(repository)"
            }
            if used.contains(label) { label = "\(row.name) · \(row.id)" }
            used.insert(label)
            return ArchivalRankingRow(id: row.id, label: label, name: row.name,
                                      category: row.category, value: row.value,
                                      leaves: row.leaves)
        }
    }

    /// Names carried by more than one row.
    ///
    /// Still shared-looking after the lifecycle card's removal left one caller: it is the whole
    /// reason the ranking's labels are unique, and Swift Charts silently merges two bars that
    /// share a label, so a regression here loses rows rather than mislabelling them.
    private static func repeatedNames(_ names: [String]) -> Set<String> {
        var seen = Set<String>()
        var repeated = Set<String>()
        for name in names where !seen.insert(name).inserted { repeated.insert(name) }
        return repeated
    }
}
