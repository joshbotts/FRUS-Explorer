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
}

// MARK: - ArchivalLifecycleSpan

/// One horizontal span bar in the "Collection lifecycles" card: the coverage years of the
/// volumes that cite a collection, from the earliest to the latest.
/// The x-axis domain for the lifecycle chart.
///
/// Without an explicit domain Swift Charts infers one from the marks, and a `BarMark` anchors its
/// numeric axis at **zero** — so a chart of coverage years rendered an axis running 0–1990 with
/// every bar crushed against the right edge. The years are dates, not magnitudes: nothing is being
/// measured *from* zero, so zero is not a meaningful origin.
///
/// Version history:
///   1.0 — Session 2026-08-10: lifecycle x-axis fix
enum ArchivalLifecycleAxis {

    /// The floor a coverage-year axis opens at when the data starts later.
    ///
    /// FRUS begins with the 1861 volume, so 1860 is the round decade below the series' own start —
    /// it gives the earliest bars somewhere to sit rather than beginning flush against the axis.
    static let defaultFirstYear = 1860

    /// The domain for `spans`, or `nil` when there is nothing to plot.
    ///
    /// - Parameter spans: The plotted lifecycles.
    /// - Returns: The closed year range the axis should cover.
    ///
    /// The floor is a **default, not a clamp**: a span beginning before 1860 widens the axis rather
    /// than being cut off. Clamping would hide the very records whose early coverage makes them
    /// interesting, and it would do so silently — the bar would simply start at the edge.
    static func domain(for spans: [ArchivalLifecycleSpan]) -> ClosedRange<Int>? {
        guard !spans.isEmpty else { return nil }
        let earliest = spans.map(\.firstYear).min() ?? defaultFirstYear
        let latest = spans.map(\.lastYear).max() ?? defaultFirstYear
        let lower = min(defaultFirstYear, earliest)
        // A single-year span would otherwise give a zero-width domain, which Charts renders as an
        // axis with no extent at all.
        let upper = max(latest, lower + 1)
        return lower...upper
    }
}

struct ArchivalLifecycleSpan: Identifiable, Sendable, Equatable {
    /// Authority collection id.
    let id: String
    /// Unique axis label.
    let label: String
    /// The record's own name.
    let name: String
    /// Custodian bucket.
    let category: ArchivalRepositoryCategory
    /// Earliest coverage year among citing volumes.
    let firstYear: Int
    /// Latest coverage year among citing volumes.
    let lastYear: Int
    /// Citing volumes — the bar's rank and its accessibility value.
    let volumeCount: Int
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
}

// MARK: - ArchivalCollectionsData

/// The corpus-wide Collections-mode derivation: era band × archival unit, under either weight
/// and either unit lens, plus the collection lifecycles.
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

    /// Lifecycle bars shown, ranked by citing volumes.
    static let lifecycleCap = 18

    /// Per-band document counts by authority collection id.
    private let collectionDocuments: [[String: Int]]
    /// Per-band citing-volume counts by authority collection id.
    private let collectionVolumes: [[String: Int]]
    /// Per-band document counts by class key.
    private let classDocuments: [[String: Int]]
    /// Per-band citing-volume counts by class key.
    private let classVolumes: [[String: Int]]
    /// Volumes per band.
    private let bandVolumeCounts: [Int]
    /// Authority records by id, for labels and categories.
    private let records: [String: AuthorityCollectionRecord]
    /// Every lifecycle span, ranked by citing volumes, capped.
    private let lifecycles: [ArchivalLifecycleSpan]

    /// Whether document weights are available at all — `false` when the usage index is missing,
    /// in which case the Documents weight must be disabled rather than shown as zeroes.
    let supportsDocumentWeight: Bool

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
                     coverage: [String: ArchivalVolumeCoverage]) -> ArchivalCollectionsData {
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
        var spans: [ArchivalLifecycleSpan] = []
        for record in authority {
            records[record.id] = record
            var earliest: Int?
            var latest: Int?
            var citing = 0
            for volumeId in record.volumeIds {
                guard let band = bandByVolume[volumeId], let span = coverage[volumeId] else {
                    continue
                }
                collectionVolumes[band][record.id, default: 0] += 1
                earliest = min(earliest ?? span.firstYear, span.firstYear)
                latest = max(latest ?? span.lastYear, span.lastYear)
                citing += 1
            }
            if let earliest, let latest, citing > 0 {
                spans.append(ArchivalLifecycleSpan(
                    id: record.id, label: record.name, name: record.name,
                    category: ArchivalRepositoryCategory.from(record),
                    firstYear: earliest, lastYear: latest, volumeCount: citing))
            }
        }

        var collectionDocuments = [[String: Int]](repeating: [:], count: bandCount)
        var classDocuments = [[String: Int]](repeating: [:], count: bandCount)
        var classVolumes = [[String: Int]](repeating: [:], count: bandCount)
        if let usage {
            // The collection lens takes its volume weight from the authority instead (see the
            // type's note), so the counts this pass produces for it are deliberately dropped.
            _ = tally(usage.collections, keys: usage.collectionIds, volumes: usage.volumes,
                      bandByVolume: bandByVolume, into: &collectionDocuments)
            classVolumes = tally(usage.classes, keys: usage.classKeys, volumes: usage.volumes,
                                 bandByVolume: bandByVolume, into: &classDocuments)
        }

        // Ranked once here rather than per read: the cap is a display decision but the order is
        // a property of the data, and re-sorting 4,423 spans on every band switch is waste.
        let rankedSpans = spans
            .sorted { a, b in
                if a.volumeCount != b.volumeCount { return a.volumeCount > b.volumeCount }
                if a.name != b.name { return a.name < b.name }
                return a.id < b.id
            }
            .prefix(lifecycleCap)
        let labelledSpans = disambiguate(Array(rankedSpans), records: records)

        return ArchivalCollectionsData(
            collectionDocuments: collectionDocuments,
            collectionVolumes: collectionVolumes,
            classDocuments: classDocuments,
            classVolumes: classVolumes,
            bandVolumeCounts: bandVolumeCounts,
            records: records,
            lifecycles: labelledSpans,
            supportsDocumentWeight: usage != nil,
            volumesPlaced: bandByVolume.count)
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
        let table: [String: Int]
        switch (lens, weight) {
        case (.namedCollections, .documents): table = collectionDocuments[band.index]
        case (.namedCollections, .volumes): table = collectionVolumes[band.index]
        case (.centralFileClasses, .documents): table = classDocuments[band.index]
        case (.centralFileClasses, .volumes): table = classVolumes[band.index]
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
                return ArchivalRankingRow(id: key, label: key, name: key,
                                          category: .stateDepartment, value: value)
            }
        }

        return ArchivalRanking(rows: Self.disambiguate(Array(rows), records: records),
                               hiddenUmbrellaValue: (hiddenValue ?? 0) > 0 ? hiddenValue : nil,
                               unitsReached: ranked.count,
                               bandVolumeCount: bandVolumeCounts[band.index])
    }

    /// The lifecycle span bars, ranked by citing volumes.
    var lifecycleSpans: [ArchivalLifecycleSpan] { lifecycles }

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
                                      category: row.category, value: row.value)
        }
    }

    private static func disambiguate(_ spans: [ArchivalLifecycleSpan],
                                     records: [String: AuthorityCollectionRecord])
        -> [ArchivalLifecycleSpan] {
        let repeated = repeatedNames(spans.map(\.name))
        guard !repeated.isEmpty else { return spans }
        var used = Set<String>()
        return spans.map { span in
            guard repeated.contains(span.name) else {
                used.insert(span.label)
                return span
            }
            var label = span.name
            if let repository = records[span.id]?.repository {
                label = "\(span.name) · \(repository)"
            }
            if used.contains(label) { label = "\(span.name) · \(span.id)" }
            used.insert(label)
            return ArchivalLifecycleSpan(id: span.id, label: label, name: span.name,
                                         category: span.category, firstYear: span.firstYear,
                                         lastYear: span.lastYear, volumeCount: span.volumeCount)
        }
    }

    /// Names carried by more than one row.
    private static func repeatedNames(_ names: [String]) -> Set<String> {
        var seen = Set<String>()
        var repeated = Set<String>()
        for name in names where !seen.insert(name).inserted { repeated.insert(name) }
        return repeated
    }
}
