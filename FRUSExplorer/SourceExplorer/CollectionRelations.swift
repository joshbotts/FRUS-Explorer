// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RelatedCollection

/// One archival collection cited alongside another in the same volumes' source lists.
///
/// The relation is **volume-grain**: two collections share a volume when both were drawn on
/// by the same editorial compilation. That is not document-level affinity — a document has
/// exactly one source note, so no document-grain co-citation exists at all.
///
/// Version history:
///   1.0 — Session 2026-08-08: #762 (archival analytics Phase 1)
struct RelatedCollection: Identifiable, Sendable, Equatable {

    /// The related authority record. Carried whole so a row can push its own
    /// ``CollectionDetailView`` without a second lookup.
    let record: AuthorityCollectionRecord

    /// Volumes that cite both this record and the focus record.
    let sharedVolumeCount: Int

    /// Distinct volumes citing *this* record — how broadly it is drawn on across the series.
    ///
    /// Stored rather than read back off `record.volumeIds` so that the coefficient's denominator
    /// and the breadth tie-break are the same number. The shipped artifact happens to carry no
    /// repeated volume id inside a single record, but a comparator keyed on the raw array while
    /// the score is keyed on the deduplicated set is an inconsistency waiting for the first one.
    let partnerVolumeCount: Int

    /// Overlap coefficient — shared ÷ the *smaller* of the two citing-volume lists, in
    /// `0...1`. Dividing by the smaller list is what damps the umbrella records: the
    /// "Central Files" cluster cites 157 volumes, and on raw shared count it is the top answer
    /// for 461 of the 1,557 collections that have a list at all — near enough one in three,
    /// whatever the two actually have to do with each other.
    let overlap: Double

    var id: String { record.id }
}

// MARK: - CollectionCoverageEra

/// One bucket on the "Cited Over Time" axis: a span of coverage years named the way FRUS
/// names its own subseries.
///
/// These are **not** SA-3's decades. The provenance dashboard buckets by decade because it
/// charts the whole series at once; for a single collection a decade axis is wrong in both
/// directions. Measured over the shipped manifest under SA-3's own midpoint rule, it splits the
/// 66-volume `1969-76` subseries across the 1960s and 1970s, while its single 1960s bar holds
/// volumes from five different subseries — `1952-54`, `1955-57`, `1961-63`, `1964-68`, `1969-76`.
///
/// From 1955 the buckets are exactly the published subseries (`1955-57`, `1958-60`,
/// `1961-63`, `1964-68`, `1969-76`, `1977-80`, `1981-88`, `1989-92`). Earlier, FRUS published
/// a volume run per calendar year — the manifest carries 107 distinct subseries values, most
/// of them a single year — so those group: `1948–1950` and `1951–1954` as the approved design
/// names them, `1941–1947` for the war years, and decades before that.
///
/// Version history:
///   1.0 — Session 2026-08-08: #762
struct CollectionCoverageEra: Identifiable, Sendable, Equatable, Hashable {

    /// Position in ``CollectionRelations/coverageEras``; also the sort key and `id`.
    let index: Int
    /// First coverage year in the bucket.
    let startYear: Int
    /// Last coverage year in the bucket.
    let endYear: Int

    var id: Int { index }

    /// Axis-tick form — `'61–63`. Two-digit years are used only from 1900 on, so a
    /// nineteenth-century bucket can never be read as a twentieth-century one.
    var shortLabel: String {
        guard startYear >= 1900 else { return fullLabel }
        return "’\(Self.twoDigits(startYear))–\(Self.twoDigits(endYear))"
    }

    /// Prose form — `1961–1963`. Used in the generated caption, where the years are read
    /// rather than scanned.
    var fullLabel: String { "\(startYear)–\(endYear)" }

    private static func twoDigits(_ year: Int) -> String {
        let last = year % 100
        return last < 10 ? "0\(last)" : "\(last)"
    }
}

// MARK: - CollectionEraCount

/// How many of a collection's citing volumes fall in one coverage era.
struct CollectionEraCount: Identifiable, Sendable, Equatable {
    /// The era bucket.
    let era: CollectionCoverageEra
    /// Citing volumes attributed to it.
    let volumeCount: Int

    var id: Int { era.index }
}

// MARK: - CollectionRelations

/// The three derivations behind #762's additions to ``CollectionDetailView`` — related
/// collections, the coverage-era timeline, and its caption.
///
/// All three are pure functions over values the app already ships, so they are testable
/// without a view, a container, or a network. Nothing here reads `Bundle.main`: callers pass
/// the decoded authority records and the volume years in, which is what lets the tests drive
/// the real ranking against synthetic corpora as well as the shipped artifact.
///
/// Version history:
///   1.0 — Session 2026-08-08: #762 (archival analytics Phase 1)
enum CollectionRelations {

    // MARK: - Related collections

    /// Volumes a candidate must share with the focus record before it is offered as related.
    ///
    /// A floor is not a nicety here, it is what makes the metric mean anything. The overlap
    /// coefficient is `shared ÷ min(|A|,|B|)`, so it reaches 1.0 for *any* record whose
    /// citing-volume list is a subset of the focus record's — and 2,846 of the 4,423 shipped
    /// records cite exactly one volume. Measured on the 2026-08-06 artifact, **77.8% of all
    /// co-citing pairs score exactly 1.000**, so what a list looks like is decided by the
    /// tie-breaks far more often than by the score.
    ///
    /// Ranked on the score alone, 80.3% of the top-5 slots for records citing 20 or more
    /// volumes go to single-volume records sharing one volume, and a third of those records get
    /// a top-5 that is *entirely* that noise. The shared-count tie-break alone brings it to
    /// 0.5% there — but 27.7% corpus-wide, since for a single-volume focus every candidate ties
    /// on both keys. This floor removes the class outright: a one-volume record cannot share
    /// two. It costs 19 of the 1,577 multi-volume records their list.
    static let minimumSharedVolumes = 2

    /// Rows shown before the "Show all" disclosure, in every capped section of the detail view.
    static let previewRowCap = 5

    /// The collections cited alongside `focus`, best first.
    ///
    /// Ranked by overlap coefficient, then by shared-volume count, then by the partner's own
    /// citing-volume count *ascending*, then by name and id. The order is a total one, so the
    /// list is stable across launches and platforms.
    ///
    /// The tie-breaks carry real weight rather than merely breaking ties: coefficients
    /// saturate at 1.000 across large bands (see ``minimumSharedVolumes``), so shared count is
    /// what separates strong evidence from weak, and preferring the *smaller* partner among
    /// equals prefers the more specific collection over another umbrella.
    ///
    /// Returns an empty list when `focus` cites fewer than ``minimumSharedVolumes`` volumes:
    /// one shared volume is a coincidence of compilation, not evidence of a shared
    /// neighbourhood, and every other collection in that volume would tie.
    ///
    /// - Parameters:
    ///   - focus: The record being viewed.
    ///   - collections: Every authority record, `focus` included (it is skipped by id).
    static func related(to focus: AuthorityCollectionRecord,
                        in collections: [AuthorityCollectionRecord]) -> [RelatedCollection] {
        let focusVolumes = Set(focus.volumeIds)
        guard focusVolumes.count >= minimumSharedVolumes else { return [] }

        var found: [RelatedCollection] = []
        for candidate in collections where candidate.id != focus.id {
            let candidateVolumes = Set(candidate.volumeIds)
            guard !candidateVolumes.isEmpty else { continue }
            let shared = candidateVolumes.intersection(focusVolumes).count
            guard shared >= minimumSharedVolumes else { continue }
            let smaller = min(focusVolumes.count, candidateVolumes.count)
            found.append(RelatedCollection(record: candidate,
                                           sharedVolumeCount: shared,
                                           partnerVolumeCount: candidateVolumes.count,
                                           overlap: Double(shared) / Double(smaller)))
        }

        return found.sorted { a, b in
            if a.overlap != b.overlap { return a.overlap > b.overlap }
            if a.sharedVolumeCount != b.sharedVolumeCount {
                return a.sharedVolumeCount > b.sharedVolumeCount
            }
            if a.partnerVolumeCount != b.partnerVolumeCount {
                return a.partnerVolumeCount < b.partnerVolumeCount
            }
            if a.record.name != b.record.name { return a.record.name < b.record.name }
            return a.record.id < b.record.id
        }
    }

    // MARK: - Coverage eras

    /// The coverage-era axis, earliest first. See ``CollectionCoverageEra``.
    static let coverageEras: [CollectionCoverageEra] = {
        let spans = [(1861, 1870), (1871, 1880), (1881, 1890), (1891, 1900),
                     (1901, 1910), (1911, 1920), (1921, 1930), (1931, 1940),
                     (1941, 1947), (1948, 1950), (1951, 1954), (1955, 1957),
                     (1958, 1960), (1961, 1963), (1964, 1968), (1969, 1976),
                     (1977, 1980), (1981, 1988), (1989, 1992)]
        return spans.enumerated().map { index, span in
            CollectionCoverageEra(index: index, startYear: span.0, endYear: span.1)
        }
    }()

    /// The volume's coverage midpoint — the same join SA-3a's generator uses for its decade
    /// attribution (`(earliest + latest) / 2`, falling back to whichever endpoint parses).
    /// Only the bucket boundaries differ between the two surfaces; the attribution does not.
    static func midpointYear(earliest: String?, latest: String?) -> Int? {
        let first = FRUSVolumeMetadata.firstYear(in: earliest)
        let last = FRUSVolumeMetadata.firstYear(in: latest)
        guard let start = first ?? last, let end = last ?? first else { return nil }
        return (min(start, end) + max(start, end)) / 2
    }

    /// The era a coverage midpoint belongs to.
    ///
    /// Clamped at both ends rather than returning `nil`: eight manifest volumes have a coverage
    /// midpoint before the series' own 1861 floor — six because they print retrospective annexes
    /// (`frus1872p2v5` reaches back to 1620, for a midpoint of 1746), and two because their
    /// coverage simply opens in 1860. None is cited by any authority record today, but dropping a
    /// citing volume would silently shrink a count the user is reading as complete.
    static func eraIndex(forMidpointYear year: Int) -> Int {
        for era in coverageEras where year <= era.endYear {
            return era.index
        }
        return coverageEras.count - 1
    }

    /// Citing volumes bucketed by coverage era, from the first era with volumes through the
    /// last — interior gaps included, because a gap in a collection's use is itself the shape
    /// the chart is there to show.
    ///
    /// - Parameter volumeMidpoints: One coverage midpoint per citing volume (volumes whose
    ///   date range does not parse are simply absent).
    /// - Returns: Contiguous era buckets, or an empty array when the volumes reach fewer than
    ///   two eras — a single bar states nothing the section header does not.
    static func citedOverTime(volumeMidpoints: [Int]) -> [CollectionEraCount] {
        var counts: [Int: Int] = [:]
        for year in volumeMidpoints {
            counts[eraIndex(forMidpointYear: year), default: 0] += 1
        }
        guard counts.count >= 2,
              let first = counts.keys.min(), let last = counts.keys.max() else { return [] }
        return (first...last).map {
            CollectionEraCount(era: coverageEras[$0], volumeCount: counts[$0] ?? 0)
        }
    }

    // MARK: - The generated caption

    /// The chart's prose reading of itself — "enters the record with … peaks across … fades
    /// after …", generated from the buckets rather than written per collection.
    ///
    /// The clauses are guarded, not decorative — each one is a claim about the chart drawn
    /// directly above it, and a caption that contradicts its own chart is worse than no caption.
    ///
    /// "Peaks" is claimed only when three things hold: some era carries two or more citing
    /// volumes (one per era is the noise floor, not a trend); the eras tied at the maximum form
    /// **one unbroken run** (a maximum that recurs after a dip has no single peak — see
    /// ``peakRun(in:at:)``); and that run does not cover the whole width (a collection cited
    /// evenly throughout peaks nowhere). "Fades" is claimed only when citations continue past
    /// the peak run at a lower level — which, because the run holds *every* bucket at the
    /// maximum, is exactly when the chart really does fall away.
    ///
    /// Returns an empty string for fewer than two buckets — the caller renders no chart there.
    static func timelineNarrative(for buckets: [CollectionEraCount]) -> String {
        guard buckets.count >= 2,
              let firstEra = buckets.first(where: { $0.volumeCount > 0 })?.era,
              let lastEra = buckets.last(where: { $0.volumeCount > 0 })?.era else { return "" }

        let peak = buckets.map(\.volumeCount).max() ?? 0
        let run = peakRun(in: buckets, at: peak)

        guard peak >= 2, let run, run.count < buckets.count,
              let runStart = run.first?.era, let runEnd = run.last?.era else {
            return String(format: String(
                localized: "collection.detail.timeline.narrative.flat %@ %@",
                defaultValue: "This collection enters the record with the %1$@ volumes and runs through the %2$@ volumes."),
                firstEra.fullLabel, lastEra.fullLabel)
        }

        let peakSpan = runStart == runEnd
            ? runStart.fullLabel
            : "\(runStart.startYear)–\(runEnd.endYear)"
        let entersAtItsPeak = firstEra.index == runStart.index

        guard lastEra.index > runEnd.index else {
            return String(format: String(
                localized: "collection.detail.timeline.narrative.peak %@ %@",
                defaultValue: "This collection enters the record with the %1$@ volumes and peaks across the %2$@ volumes."),
                firstEra.fullLabel, peakSpan)
        }
        // Naming the same era as both the entrance and the peak reads as a stutter, so the
        // sentence says it once — the collection arrived at full strength.
        if entersAtItsPeak {
            return String(format: String(
                localized: "collection.detail.timeline.narrative.entersAtPeak %@ %@",
                defaultValue: "This collection enters the record at its peak with the %1$@ volumes and fades after the %2$@ volumes."),
                peakSpan, lastEra.fullLabel)
        }
        return String(format: String(
            localized: "collection.detail.timeline.narrative.fade %@ %@ %@",
            defaultValue: "This collection enters the record with the %1$@ volumes, peaks across the %2$@ volumes, and fades after the %3$@ volumes."),
            firstEra.fullLabel, peakSpan, lastEra.fullLabel)
    }

    /// The eras tied at `peak` — but only when they form **one unbroken run**, and `nil` otherwise.
    ///
    /// Returning the first run and ignoring later recurrences is what a forward scan does, and it
    /// is wrong: measured on the shipped artifact, 9 of the 600 collections that chart at all have
    /// their maximum recur after a dip. `Department of the Treasury` is cited by two 1955–1957
    /// volumes and two 1977–1980 volumes, so a first-run answer names 1955–1957 as the peak and
    /// then claims a fade — with the last bar drawn exactly as tall as the first. Such a
    /// collection has no single peak, and `nil` is the honest answer.
    private static func peakRun(in buckets: [CollectionEraCount],
                                at peak: Int) -> [CollectionEraCount]? {
        let atPeak = buckets.indices.filter { buckets[$0].volumeCount == peak }
        guard let start = atPeak.first, let end = atPeak.last else { return nil }
        guard atPeak.count == end - start + 1 else { return nil }
        return Array(buckets[start...end])
    }
}
