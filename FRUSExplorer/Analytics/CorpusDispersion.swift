// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CorpusDispersion

/// How widely a term's matches spread across volumes, and whether they concentrate.
///
/// ## The finding this exists to make visible
/// "182 documents" describes two completely different results. A term spread across 150 volumes is
/// part of the corpus's working vocabulary; the same count concentrated in three volumes is a
/// specific episode. The Corpus Analytics charts show *when* matches occur and never *how narrowly*,
/// so the two are indistinguishable on screen.
///
/// The corpus makes the point sharply. Searching `"Article 43"`, 1949 holds 11 matching documents —
/// and one of them, `frus1949v01/d102`, carries 54 of that year's 92 occurrences. A frequency count
/// alone reads that year as a topic fading out; it is one document discussing it at length.
///
/// ## Why volumes, and why the counts must come from the whole being decomposed
/// A volume count reads no year, so this measure is immune to the volume-start-year fallback that
/// lands undated documents in a manufactured year bucket. A "spans N years" figure computed from the
/// year series would inherit that fabrication, which is why there isn't one.
///
/// The counts must also come from the *same set* whose total is printed beside them. Corpus
/// Analytics prints the line beside its "View N documents" link, and since #1756 takes both from
/// the keys of the one search the link opens (`AnalyticsSearchHandoff.Match`): every match, or the
/// documents Search lists for the years the reader narrowed. Until then the counts came from the
/// volume breakdown, which ignores the years, while the link's total followed them, so the parts
/// disagreed with the whole exactly when a custom range was set — the moment a researcher is
/// looking closely.
///
/// ## Separate from the view so the gate is testable
/// The 25% concentration gate is a claim about when a number is worth stating. Left in a view body
/// it would be a rule nothing could check; here its boundaries are asserted.
///
/// Version history:
///   1.0 — R-2 PR-C: initial implementation
///   1.1 — #1756 (docs only): the counts come from the hand-off search's keys, not the volume breakdown
struct CorpusDispersion: Equatable {

    /// How many volumes contain at least one match.
    let volumes: Int

    /// How many volumes are indexed on this device.
    ///
    /// The denominator is deliberately the device's index, not the manifest's 553 published volumes:
    /// a share of the published series would be a claim about data this device does not have.
    let indexedVolumeCount: Int

    /// The share of all matches held by the three volumes with the most, in `0...1`.
    let topThreeShare: Double

    /// `topThreeShare` as a whole percentage, for display.
    var topThreePercent: Int { Int((topThreeShare * 100).rounded()) }

    /// Whether the concentration is worth saying out loud.
    ///
    /// Two conditions, both load-bearing:
    ///
    /// - **≥ 25%** — following `FacetPanelView`'s precedent ("Computed, never templated"): measured
    ///   across 552 volumes, a common term's top three hold about 1.7%, and announcing that as a
    ///   concentration
    ///   would train the reader to ignore the line.
    /// - **more than three volumes** — with three or fewer, "the top 3 hold 100%" is arithmetic, not
    ///   a finding. The volume count already said it.
    var showsConcentration: Bool { topThreeShare >= 0.25 && volumes > 3 }

    /// Builds a dispersion summary from a term's per-volume match counts.
    ///
    /// - Parameters:
    ///   - volumeCounts: match count per volume, in any order. Volumes with no matches are ignored
    ///     whether they are absent from the array or present as zeros, so `volumes` always means
    ///     "volumes that contain the term".
    ///   - indexedVolumeCount: volumes indexed on this device.
    /// - Returns: `nil` when there is nothing to describe — no volumes with matches, or no matches at
    ///   all. `nil` means "say nothing", never "spread across 0 volumes".
    static func make(volumeCounts: [Int], indexedVolumeCount: Int) -> CorpusDispersion? {
        let positive = volumeCounts.filter { $0 > 0 }
        guard !positive.isEmpty else { return nil }
        let total = positive.reduce(0, +)
        guard total > 0 else { return nil }
        let topThree = positive.sorted(by: >).prefix(3).reduce(0, +)
        return CorpusDispersion(
            volumes: positive.count,
            indexedVolumeCount: indexedVolumeCount,
            topThreeShare: Double(topThree) / Double(total)
        )
    }
}
