// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SimilarityAxis

/// One dimension of document-to-document proximity in the #308 find-related model.
///
/// Axes split into two roles (design §6.2). **Generators** produce a *bounded* candidate
/// set (genuinely `O(neighbours)`, a keyed lookup) — archival provenance and cross-references.
/// **Scorers** only *rank* the already-generated candidates and never enumerate — date,
/// subseries, shared persons, and (Phase 3) shared subjects. The split exists because three of
/// the "live" signals map to huge sets (a head-of-state person rollup is tens of thousands of
/// documents), so unioning every axis's enumeration would approach the whole corpus for a
/// prominent anchor; scorers dodge that by batch-scoring the bounded candidate set instead.
///
/// Version history:
///   1.0 — #308 Phase 2: initial six-axis model (the shared-subjects scorer is inert until the
///          Phase 3 document-grain data drop; the cross-reference generator landed in Phase 2b)
///   1.1 — #562: `ProximityMath.narrowing` / `.printAdjacency` and `VolumeArrangement` added for the
///          corpus-proximity axis; `.subseries` renamed in display only (its rawValue is persisted)
enum SimilarityAxis: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// Same original archival provenance — lot file, central decimal file, record-group series,
    /// or presidential-library collection (`IndexingPipeline.archivalNeighbors`). A generator.
    case archivalProvenance
    /// Directly cited by or citing the anchor (`CrossReferenceStore` edges). A generator.
    case crossReference
    /// Nearness of editorial coverage dates (`|Δyear|` decay). A scorer.
    case dateProximity
    /// Where the editors placed the two documents relative to each other: how narrowly the volume's
    /// own arrangement contains them both, whether they were printed side by side, and failing both,
    /// whether they share a subseries (`VolumeManifestEntry.subseries`). A scorer.
    ///
    /// **The rawValue is a persistence token — do not rename this case.** It is the key in the
    /// UserDefaults axis-weight string, in the CloudKit-mirrored `Project.leadAxisWeights`, and in
    /// the `Hashable` identity of every find-related window. `AxisWeights.init?(rawValue:)` skips
    /// tokens it does not recognise and no read path merges defaults, so a rename ships as a silent
    /// weight of 0 for every user who has ever moved the slider — and compiles clean.
    case subseries
    /// Overlap of the mentioned people, resolved through the cross-corpus person rollup. A scorer.
    case sharedPersons
    /// Overlap of detected subject topics (Phase 3 document-grain data; inert until then). A scorer.
    case sharedSubjects

    var id: String { rawValue }

    /// Whether this axis *produces* candidates (bounded enumeration) rather than only scoring
    /// them. Generators drive the candidate universe; scorers rank it (design §6.2).
    var isGenerator: Bool {
        switch self {
        case .archivalProvenance, .crossReference: return true
        case .dateProximity, .subseries, .sharedPersons, .sharedSubjects: return false
        }
    }

    /// The user-facing axis name.
    var displayName: String {
        switch self {
        case .archivalProvenance:
            return String(localized: "related.axis.archival", defaultValue: "Archival provenance")
        case .crossReference:
            return String(localized: "related.axis.crossReference", defaultValue: "Cross-references")
        case .dateProximity:
            return String(localized: "related.axis.date", defaultValue: "Close in date")
        case .subseries:
            // Renamed from "Same volume or subseries" in #562: the axis now grades placement inside
            // a volume, so a same-volume row reads 60–100% rather than a flat 100%, and the old
            // name made a 73% look like a bug. The `case` keeps its rawValue — see above.
            return String(localized: "related.axis.corpusProximity", defaultValue: "Corpus proximity")
        case .sharedPersons:
            return String(localized: "related.axis.persons", defaultValue: "Shared people")
        case .sharedSubjects:
            return String(localized: "related.axis.subjects", defaultValue: "Shared topics")
        }
    }

    /// An SF Symbol representing the axis in the tuning UI and per-row "why related" chips.
    var systemImage: String {
        switch self {
        case .archivalProvenance: return "archivebox"
        case .crossReference:     return "arrow.triangle.branch"
        case .dateProximity:      return "calendar"
        case .subseries:          return "books.vertical"
        case .sharedPersons:      return "person.2"
        case .sharedSubjects:     return "tag"
        }
    }

    /// The out-of-the-box weight for this axis. Generators and shared people start meaningful;
    /// date and subseries are mild refinements; **shared subjects defaults to 0** — the data is
    /// gated (#261) and, per design Q4, the detected-topic axis ships opt-in with an explicit
    /// "experimental" framing rather than shaping results by default.
    var defaultWeight: Double {
        switch self {
        case .archivalProvenance: return 1.0
        case .crossReference:     return 1.0
        case .dateProximity:      return 0.5
        case .subseries:          return 0.3
        case .sharedPersons:      return 0.7
        case .sharedSubjects:     return 0.0
        }
    }
}

// MARK: - AxisWeights

/// The user-tunable weight vector over the similarity axes — per-request state (it rides the
/// `Codable` window payload so a restored macOS window recovers the exact tuning, design §6.3),
/// not a property of the stateless axis types.
///
/// A candidate's total proximity is `Σ weight[axis] × axisScore[axis]` (`RelatedDocumentsRanker`).
struct AxisWeights: Codable, Hashable, Sendable {

    /// Weight per axis; a missing axis reads as 0 through the subscript.
    private(set) var weights: [SimilarityAxis: Double]

    /// Creates a weight vector from an explicit per-axis map.
    init(weights: [SimilarityAxis: Double]) {
        self.weights = weights
    }

    /// The default tuning — each axis's `defaultWeight` (shared subjects 0, design Q4).
    static let `default` = AxisWeights(
        weights: Dictionary(uniqueKeysWithValues: SimilarityAxis.allCases.map { ($0, $0.defaultWeight) }))

    /// The weight for `axis` (0 when unset). Assigning updates the vector.
    subscript(_ axis: SimilarityAxis) -> Double {
        get { weights[axis] ?? 0 }
        set { weights[axis] = newValue }
    }
}

// MARK: - WhyRelatedChip

/// What one "why related" chip says.
///
/// A percentage is the right thing to show for a **scorer** axis, whose score is an absolute
/// `[0, 1]` measure. It is misleading for a **generator** axis, whose score is normalised by that
/// anchor's own strongest candidate — so identical evidence reads differently depending on the
/// company it keeps, and a lone candidate always reads 100%.
///
/// Measured on the owner's index: `archivalProvenance` emits a constant strength, so its chip has
/// read exactly "100%" on every row it has ever rendered — it carries no information at all.
/// `crossReference` reads 100% for the 54.98% of anchors that have one candidate, while an
/// identical single citation reads as low as 21% beside a 48×-cited neighbour.
///
/// So generator axes state their evidence and scorer axes state their score.
///
/// Version history:
///   1.0 — cross-reference chip honesty: initial implementation
enum WhyRelatedChip: Hashable, Sendable {
    /// A cross-reference axis, stating the citation multiplicity it actually found.
    case citations(Int)
    /// A generator axis whose evidence is binary — the chip states presence, not a degree.
    case presence
    /// A scorer axis, whose `[0, 1]` score is an absolute measure and rounds to a percent.
    case percent(Int)
}

// MARK: - Candidate + result value types

/// The display fields for one related-document row, carried alongside the key so the list
/// renders (and the row-tap hand-off builds a `DocumentBrowserEntry`) without a re-fetch.
struct CandidateRecord: Sendable, Hashable {
    /// The document header (title). May be empty; the row falls back to the document id.
    let header: String
    /// The human-readable dateline (a display string, e.g. `"Washington, June 3, 1964"`), if any.
    let dateline: String?
    /// The document number within its volume, if any.
    let documentNumber: String?
    /// Whether the document is an editorial note rather than a primary document.
    let isEditorialNote: Bool

    /// Creates a display record.
    init(header: String, dateline: String?, documentNumber: String?, isEditorialNote: Bool) {
        self.header = header
        self.dateline = dateline
        self.documentNumber = documentNumber
        self.isEditorialNote = isEditorialNote
    }
}

/// One candidate a generator produced: its key, display record, and a **raw** (pre-normalisation)
/// strength for its generating axis. The engine normalises each axis's strengths to `[0, 1]`.
struct GeneratedCandidate: Sendable {
    /// The candidate document.
    let key: DocumentKey
    /// The candidate's display fields.
    let record: CandidateRecord
    /// The generator's raw strength for this candidate (`≥ 0`), normalised per axis by the engine.
    let strength: Double

    /// The countable evidence behind this candidate, when the axis has one worth stating — the
    /// citation multiplicity for cross-references. `nil` where the evidence is binary (archival
    /// adjacency) or where there is nothing countable to report.
    ///
    /// Carried separately from ``strength`` because strength is damped and then normalised, so by
    /// the time the ranker is done the original count is unrecoverable — and the count is the thing
    /// worth showing a researcher.
    let evidenceCount: Int?

    /// Creates a generated candidate.
    init(key: DocumentKey, record: CandidateRecord, strength: Double, evidenceCount: Int? = nil) {
        self.key = key
        self.record = record
        self.strength = strength
        self.evidenceCount = evidenceCount
    }
}

/// One ranked related-document result: the document, its display record, its total proximity, and
/// the per-axis breakdown of *nonzero* contributions (the "why related" affordance).
struct RelatedDocumentRow: Identifiable, Sendable, Hashable {
    /// The related document.
    let key: DocumentKey
    /// Display fields for the row.
    let record: CandidateRecord
    /// The weighted total proximity `Σ weight[axis] × axisScore[axis]`.
    let totalScore: Double
    /// The nonzero per-axis contributions — the **pre-weight** `axisScore`, not the weighted
    /// product — for the "why related" chips.
    ///
    /// A researcher who sets an axis to weight 0.1 still sees its chip at up to 100%: the chip
    /// states how strong the signal is, not how much it influenced the ranking.
    let axisScores: [SimilarityAxis: Double]
    /// A short context snippet (on-device summary or a leading body excerpt), filled by the engine
    /// for the shown rows so a researcher can judge relevance (#362); `nil` when the document has no
    /// indexed text. Not a designated-init parameter — the ranker builds rows without it and the
    /// engine fills it post-rank.
    var snippet: String? = nil

    /// Countable evidence per generator axis, filled by the engine after ranking — the same
    /// non-designated-`var` shape as ``snippet``, and for the same reason: it keeps
    /// `RelatedDocumentsRanker.rank` a pure function of its inputs, so the ranking itself is
    /// provably unchanged by this being here.
    var axisEvidence: [SimilarityAxis: Int] = [:]

    var id: DocumentKey { key }
    /// The related document's volume.
    var volumeId: String { key.volumeId }
    /// The related document's id.
    var documentId: String { key.documentId }

    /// The "why related" chips, strongest first, in a **total** order.
    ///
    /// The tie-break is load-bearing rather than tidy. `axisScores` is a `Dictionary`, whose
    /// iteration order is per-process hash-seeded, and `sorted(by:)` carries no stability
    /// guarantee — so ties render in an order that can differ between launches. Ties are the common
    /// case, not an edge case: archival is exactly 1.0 whenever it fires, the top cross-reference
    /// candidate is exactly 1.0 for 88.38% of firing anchors, and date proximity is exactly 1.0 at
    /// Δyear = 0. Falling back to the `allCases` index makes the order reproducible.
    var whyRelatedChips: [(axis: SimilarityAxis, chip: WhyRelatedChip)] {
        let order = SimilarityAxis.allCases
        return axisScores
            .sorted {
                $0.value != $1.value
                    ? $0.value > $1.value
                    : (order.firstIndex(of: $0.key) ?? 0) < (order.firstIndex(of: $1.key) ?? 0)
            }
            .map { axis, score in
                switch axis {
                case .crossReference:
                    // Falling back to a percent here would silently restore exactly the misleading
                    // chip this exists to replace, so the absence is made loud in debug builds.
                    if let count = axisEvidence[axis] { return (axis, .citations(count)) }
                    #if DEBUG
                    print("[RelatedDocumentRow] \(key.compositeString) scored on .crossReference with no evidence count")
                    #endif
                    return (axis, .percent(Int((score * 100).rounded())))
                case .archivalProvenance:
                    return (axis, .presence)
                default:
                    return (axis, .percent(Int((score * 100).rounded())))
                }
            }
    }

    /// Creates a ranked row.
    init(key: DocumentKey, record: CandidateRecord, totalScore: Double,
                axisScores: [SimilarityAxis: Double]) {
        self.key = key
        self.record = record
        self.totalScore = totalScore
        self.axisScores = axisScores
    }
}

/// The payload a find-related load returns: the ranked rows (already limited) and the number of
/// rankable rows before the limit was applied (drives an "N more" overflow hint).
struct RelatedDocumentsResult: Sendable {
    /// The ranked, limited rows.
    let rows: [RelatedDocumentRow]
    /// The count of candidates that scored above 0 *before* the limit — the honest "N more"
    /// denominator (record-less and zero-total candidates are already excluded, so this is `≥ rows.count`).
    let totalBeforeLimit: Int

    /// The empty result — no live index, or no candidates.
    static let empty = RelatedDocumentsResult(rows: [], totalBeforeLimit: 0)

    /// Creates a result.
    init(rows: [RelatedDocumentRow], totalBeforeLimit: Int) {
        self.rows = rows
        self.totalBeforeLimit = totalBeforeLimit
    }
}

// MARK: - Axis protocols

/// A bounded candidate producer (design §6.2). Enumerates only `O(neighbours)` documents via a
/// keyed lookup — never a corpus scan. `@MainActor` so it reads `AppState`; the actual SQLite work
/// happens inside the awaited actor calls (`IndexingPipeline`, `CrossReferenceStore`), off the main
/// thread.
@MainActor protocol SimilarityGenerator {
    /// The axis this generator produces candidates for.
    var axis: SimilarityAxis { get }
    /// The bounded candidate set for `anchor`, filtered to `scopeVolumeIds` (`nil` = all indexed).
    /// `anchorYear` feeds date-sensitive keyed queries (e.g. decimal-file chronological segmenting).
    /// `limit` is the candidate-pool depth to fetch — the engine sizes it above the display limit so
    /// scoring re-ranks a pool larger than what's shown.
    func candidates(for anchor: DocumentKey, anchorYear: Int?, limit: Int,
                    scopeVolumeIds: Set<String>?, appState: AppState) async throws -> [GeneratedCandidate]
}

/// A ranker over an already-generated candidate set (design §6.2). Produces a `[0, 1]` score per
/// candidate via **batch** signature extraction (one chunked query, never one-per-candidate) and
/// never enumerates. `@MainActor` for the same reason as `SimilarityGenerator`.
@MainActor protocol SimilarityScorer {
    /// The axis this scorer contributes.
    var axis: SimilarityAxis { get }
    /// A `0…1` proximity for each candidate against `anchor`. A candidate absent from the result
    /// (or scored 0) contributes nothing on this axis.
    func scores(anchor: DocumentKey, candidates: [DocumentKey],
                appState: AppState) async throws -> [DocumentKey: Double]
}

// MARK: - ProximityMath

/// The pure scoring arithmetic the scorers share, factored out so the math is unit-testable without a
/// live index (the batch queries around it need one; the arithmetic does not).
enum ProximityMath {

    /// Exponential date-proximity decay `exp(-|Δyear| / tau)` — in `(0, 1]`, exactly 1 at `Δ = 0`,
    /// decreasing with the absolute year gap.
    static func dateDecay(deltaYears: Int, tau: Double) -> Double {
        exp(-abs(Double(deltaYears)) / tau)
    }

    /// The Jaccard index `|A ∩ B| / |A ∪ B|` in `[0, 1]`; `0` when both sets are empty (rather than a
    /// divide-by-zero).
    static func jaccard<Element: Hashable>(_ lhs: Set<Element>, _ rhs: Set<Element>) -> Double {
        let unionCount = lhs.union(rhs).count
        guard unionCount > 0 else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(unionCount)
    }

    /// Log damping for a citation multiplicity: `1 + ln(max(count, 1))` (#356). Maps `1×` → `1.0`;
    /// `count ≤ 0` clamps to `1.0`.
    ///
    /// ## What it actually buys, measured
    /// On the owner's 552-volume / 316,839-document index (2026-08-02; population = anchors that are
    /// themselves indexed documents, 88,940 of them, over 180,504 distinct pairs) the largest pair
    /// multiplicity is **48** and **92.63%** of pairs are 1×.
    ///
    /// At that 48× worst case the damping lifts a 1×-cited partner from `1/48 = 0.0208` to
    /// `1/(1 + ln 48) = 0.2053` — a 9.85× rescue that *softens* the compression without removing it.
    /// At the modal compressed case, one partner cited twice, every other partner is still cut 40.9%
    /// to `1/(1 + ln 2) = 0.5906`.
    ///
    /// The compression is also rarer than the mechanism suggests: **88.38%** of cross-referenced
    /// anchors have a divisor of exactly 1.0, so no damping happens at all for them.
    ///
    /// The previous version of this comment claimed a maximum of 121× and concluded that a lone
    /// citation therefore "stays visible above the flat archival-provenance bulk". Neither survived
    /// measurement: 121 is not the corpus maximum, and since `ArchivalProvenanceGenerator` emits a
    /// constant 1.0 at the same default weight, a damped cross-reference value can at best **tie**
    /// the archival bulk — never exceed it.
    static func logDampedMultiplicity(_ count: Int) -> Double {
        1 + log(Double(max(count, 1)))
    }

    /// How much of a volume the smallest shared editorial container **excludes**, on a log scale
    /// (#562). `1` when the container holds just the two things being compared; `0` when it is the
    /// whole volume — which says nothing beyond "same volume".
    ///
    /// The measure is *volume-relative*, not depth-based, and that is the whole point. Nesting
    /// practice varies across the series — an early volume's single tier of country compilations
    /// does the work a later volume splits across compilations and chapters — so counting levels
    /// compares incomparable things. Asking "how much did the editors narrow the field?" does not
    /// care how many levels the narrowing took. A single-child wrapper (a compilation holding one
    /// chapter and nothing else) is nearly invisible here; under a depth ratio it is a whole level.
    ///
    /// Units are **sections plus documents**, never documents alone. `frus1919Parisv13` is the
    /// volume that forces this: it has 2 TEI document elements and 176 sections against 170 indexed
    /// documents, so a document-only denominator is 2 and every ratio collapses to a flat 1.0.
    ///
    /// The `ln(n / 2)` denominator (rather than `ln(n)`) is what lets a 2-unit container reach
    /// exactly 1 — a container cannot hold fewer than two distinct things, so dividing by `ln(n)`
    /// caps the measure around 0.89 and wastes the top of the range.
    ///
    /// - Parameters:
    ///   - totalUnits: Every section and document in the volume. Returns 0 below 3 — there is no
    ///     room to narrow, and `ln(n / 2)` is 0 at `n == 2`.
    ///   - containerUnits: The shared container's own unit count, clamped into `2...totalUnits`.
    /// - Returns: `[0, 1]`, decreasing as the container widens.
    static func narrowing(totalUnits: Int, containerUnits: Int) -> Double {
        guard totalUnits >= 3 else { return 0 }
        let n = Double(totalUnits)
        let units = Double(min(max(containerUnits, 2), totalUnits))
        return min(1, max(0, log(n / units) / log(n / 2)))
    }

    /// Print adjacency over a volume's reading order: a gap of 1 → `1.0`, 2 → `2/3`, 3 → `1/3`,
    /// anything else → `0` (#562).
    ///
    /// Deliberately narrow. Ordinal distance and date distance correlate strongly inside a large
    /// section, and `dateProximity` already ships at a higher default weight — a long ordinal tail
    /// would mostly re-state that axis under a different name. Three positions is enough to say
    /// "printed side by side" and no more.
    ///
    /// - Parameter ordinalGap: Signed difference of two reading-order positions; the sign is ignored.
    static func printAdjacency(ordinalGap: Int) -> Double {
        let distance = abs(ordinalGap)
        guard distance >= 1, distance <= 3 else { return 0 }
        return Double(4 - distance) / 3
    }
}

// MARK: - VolumeArrangement

/// A volume's editorial arrangement, flattened once into the lookups the corpus-proximity axis
/// needs: which section holds a given document, how much of the volume that section spans, and
/// where the document falls in the volume's reading order (#562).
///
/// Built from the `VolumeStructure` already stored in `volume_structures` at index time, so this
/// reads existing data and needs no re-parse, no `currentDateIndexVersion` bump, and no schema
/// change.
///
/// ## What it deliberately does not read
/// Only `sectionId`, `documentIds`, and `subsections`. **Never `divType`, never `title`.** The live
/// corpus carries 47 distinct `divType` values, and `VolumeSection.frontMatterKinds` contains
/// `"section"`, which is also a body div type in nine volumes — so any kind-keyed filter
/// misclassifies real content. There is no front/back-matter exclusion and no era rule: the
/// synthetic `front` / `back` wrappers are just sections, counted like any other.
///
/// ## Documents that are really sections
/// 2,356 rows in `document_cache` (0.74%) are container quasi-documents whose id is a *section*
/// id — whole prose sections the app presents as readable documents. Mapping section ids into the
/// same table alongside document ids lifts placement coverage from 99.26% to 99.9987%, leaving
/// exactly four unplaceable documents corpus-wide. Those quasi-documents get a containment score
/// but no reading-order position, since they are containers rather than entries in the sequence.
///
/// ## Reading order
/// A depth-first walk: a section's own documents, then its subsections, each in stored order. 267
/// sections (1.06%, across 73 volumes) hold both documents and subsections, and in 23 of them the
/// documents are not a strict prefix — so for those the walk is a close approximation of the
/// printed order rather than an exact reproduction. `VolumeSection` stores documents and
/// subsections as two separate arrays, which is what loses the interleaving; recovering it exactly
/// would mean changing parse output, and that is a full-corpus re-parse for every user to correct
/// the ordering of 23 sections.
///
/// Version history:
///   1.0 — #562: initial implementation
struct VolumeArrangement {

    /// Section index → parent section index; `-1` for a top-level section.
    private let parents: [Int]
    /// Section index → nesting depth; `0` for a top-level section.
    private let depths: [Int]
    /// Section index → unit count: itself, plus its direct documents, plus its subsections' units.
    private let units: [Int]
    /// Document id **or** section id → the section index that holds it.
    private let holders: [String: Int]
    /// Document id → reading-order position. Sections are absent by design.
    private let ordinals: [String: Int]

    /// Every section and document in the volume. The denominator for ``ProximityMath/narrowing(totalUnits:containerUnits:)``.
    let totalUnits: Int

    /// Flattens a stored volume structure. One depth-first pass; `O(units)`.
    init(_ structure: VolumeStructure) {
        var parents: [Int] = []
        var depths: [Int] = []
        var units: [Int] = []
        var holders: [String: Int] = [:]
        var ordinals: [String: Int] = [:]
        var nextOrdinal = 0

        /// Walks `section`, returning its unit count.
        func walk(_ section: VolumeSection, parent: Int, depth: Int) -> Int {
            let index = parents.count
            parents.append(parent)
            depths.append(depth)
            units.append(0)

            // Sections are registered first and only when the id is free, so a document of the same
            // name wins the mapping below. No such collision exists in the corpus today; the order
            // is here so that if one ever appears it degrades toward the real document.
            if !section.sectionId.isEmpty, holders[section.sectionId] == nil {
                holders[section.sectionId] = index
            }
            for documentId in section.documentIds {
                holders[documentId] = index
                ordinals[documentId] = nextOrdinal
                nextOrdinal += 1
            }

            var total = 1 + section.documentIds.count
            for subsection in section.subsections {
                total += walk(subsection, parent: index, depth: depth + 1)
            }
            units[index] = total
            return total
        }

        var total = 0
        for section in structure.sections {
            total += walk(section, parent: -1, depth: 0)
        }

        self.parents = parents
        self.depths = depths
        self.units = units
        self.holders = holders
        self.ordinals = ordinals
        self.totalUnits = total
    }

    /// The section holding `id` — a document id or a container quasi-document's section id — or
    /// `nil` when the volume's structure does not place it.
    func section(holding id: String) -> Int? { holders[id] }

    /// `id`'s position in the volume's reading order, or `nil` for a container quasi-document.
    func ordinal(of id: String) -> Int? { ordinals[id] }

    /// The unit count of the lowest section containing both, or ``totalUnits`` when they share no
    /// section below the volume itself.
    ///
    /// Climbs the deeper side to the shallower, then climbs together. At most eight steps — the
    /// deepest body nesting measured in the corpus is seven, plus the synthetic wrapper.
    func containerUnits(_ lhs: Int, _ rhs: Int) -> Int {
        var left = lhs
        var right = rhs
        guard parents.indices.contains(left), parents.indices.contains(right) else { return totalUnits }
        while depths[left] > depths[right] { left = parents[left] }
        while depths[right] > depths[left] { right = parents[right] }
        while left != right {
            left = parents[left]
            right = parents[right]
            guard left >= 0, right >= 0 else { return totalUnits }
        }
        return units[left]
    }
}
