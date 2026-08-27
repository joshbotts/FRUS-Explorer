// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CollectionAuthorityGeneratorCore
import GeneratorKit
import SourceNoteKit

// MARK: - IbidGapMeasurement

/// Measures the bare-`Ibid.` gap in the decimal channel (#1014 step 1 / W-1) — **without
/// harvesting it**.
///
/// ## The question, stated as the issue states it
/// The explicit form (`Ibid., Central Files, 611.93/8–2255`) is already harvested, because the
/// class is written in the clause. The gap is a **bare** `Ibid.` inheriting a class named in an
/// earlier footnote. #1014's only size estimate is an extrapolation from the lot/library
/// channel's 9.0% inheritance rate (~2,600 references) and says of itself that it "should not be
/// quoted as a finding". This pass produces the real number, per era band, and ends in a
/// go/no-go.
///
/// ## Why `MEASURE_DECIMAL=1` could not answer it
/// That harness counts what `FootnoteCitationScanner.classCandidates(inNote:)` returns, and that
/// function takes a **single note** — it cannot see the preceding footnote `ibidReach` is
/// measured against — and requires a class **inside the clause**, so a bare `Ibid.` is
/// structurally invisible to it. The missing instrument is `FootnoteIbidGapWalker` in
/// `SourceNoteKit`, which lives beside the clause splitter for the same reason
/// `classCandidates` does: a walk that re-implemented the clauses would drift.
///
/// ## What counts as the gap, and what is counted apart
/// The walker's slot is *the source last cited*, which class candidates and lot/library
/// citations compete for in clause order — because that is what `Ibid.` means on the page. Only
/// a bare `Ibid.` whose referent is a class the **shipped harvest rule admits** (serial +
/// composes + shared vocabulary, no refusal, not subject-numeric — the exact guard chain in
/// `ExternalCitationIndexRunner.build`) counts toward the gap. Everything else is disclosed in
/// its own bucket: a refused-class referent (inheriting it would price a rule nobody proposes),
/// an archival referent (the existing channel already inherits it), a referent beyond
/// `ibidReach` (prices the cap), one lost to a publication clear (prices refusal 3), and no
/// referent at all.
///
/// ## Parity is measured, not assumed
/// The walker re-derives the direct channel with the same injected rule as it walks, and
/// `directAdmitted` is reported beside the artifact's own `decimalReferences` figure — over the
/// same corpus the two must agree, and a mismatch means the walker is measuring a nearby grammar
/// rather than the shipped one.
///
/// ## Read the samples
/// Both `Ibid.` defects in the lot/library channel were found by reading samples, and #1014's
/// definition of done says so. `SAMPLE_OUTPUT` writes every Nth observation **per outcome**, so
/// the rare buckets are represented rather than drowned by the common ones.
///
/// Version history:
///   1.0 — Session 2026-08-27: #1014 W-1
public enum IbidGapMeasurement {

    // MARK: - Report

    /// One scope's tallies (a band, or the whole corpus).
    public struct GapTally: Codable, Sendable {
        /// Every bare standalone `Ibid.` clause seen — the denominator all buckets sum to.
        public var bareIbidClauses = 0
        /// THE GAP: the referent is a class the shipped rule admits, within reach.
        public var inheritsAdmittedClass = 0
        /// …of which the state was re-armed by an earlier bare `Ibid.` (a chain).
        public var chainedInheritances = 0
        /// Distance from the arming footnote, admitted inheritances only. Keys "1"/"2"/"3".
        public var admittedDistanceHistogram: [String: Int] = [:]
        /// The referent is a class the shipped rule refuses, by the first failing guard.
        public var inheritsRefusedClass: [String: Int] = [:]
        /// The referent is a lot or library — the existing channel's inheritance, not a gap.
        public var lastCitedArchival = 0
        /// The referent class is farther back than `ibidReach`. Keys are distances ("4", "5",
        /// "6+"); prices the cap.
        public var beyondReach: [String: Int] = [:]
        /// …of which the class would have been admitted.
        public var beyondReachAdmitted = 0
        /// A publication citation cleared an in-reach class state (refusal 3).
        public var blockedByPublication = 0
        /// …of which the cleared class would have been admitted.
        public var blockedByPublicationAdmitted = 0
        /// Nothing citable precedes the `Ibid.` in its document.
        public var noPriorCitation = 0
        /// `Ibid., Central Files, 684A.86/8–956` — an `Ibid.` clause carrying its own admitted
        /// class. Already harvested; context for the `ibidStandsAlone` decision in step 2.
        public var explicitIbidAdmitted = 0
        /// Clauses carrying both an archival anchor and a class candidate — a rule would have
        /// to choose.
        public var ambiguousClauses = 0
        /// The direct channel re-derived with the same rule — the parity figure and the
        /// denominator the gap is a percentage of.
        public var directAdmitted = 0
        /// Admitted candidates in clauses an archival anchor won — the runner's independent
        /// passes count these in `decimalReferences`, so parity is `directAdmitted` PLUS this.
        public var directAdmittedInArchivalClauses = 0
        /// Distinct class keys the gap would add references to.
        public var distinctInheritedKeys = 0
        /// Volumes contributing at least one gap reference.
        public var volumesWithGap = 0
    }

    /// One band's report.
    public struct BandReport: Codable, Sendable {
        public var band = ""
        public var volumes = 0
        public var documentsScanned = 0
        public var footnotesScanned = 0
        public var tally = GapTally()
    }

    /// The whole report.
    public struct Report: Codable, Sendable {
        public var generated = ""
        public var volumesScanned = 0
        public var documentsScanned = 0
        public var footnotesScanned = 0
        public var overall = GapTally()
        public var bands: [BandReport] = []
        /// The class keys the gap cites most, admitted inheritances only.
        public var topInheritedKeys: [String: Int] = [:]
    }

    /// One reviewable observation.
    public struct Sample: Codable, Sendable {
        public var volumeId = ""
        public var documentId = ""
        public var band = ""
        public var outcome = ""
        public var classKey = ""
        public var distance = 0
        public var chained = false
        public var armingClause = ""
        public var ibidClause = ""
    }

    // MARK: - Entry point

    /// Runs the measurement and writes the report.
    public static func run(volumesDir: URL, manifestPath: String, labelsPath: String,
                           reportPath: String, samplePath: String?, sampleEvery: Int,
                           generated: String) throws {
        let schedule = try DecimalChannelMeasurement.ScheduleValidator(labelsPath: labelsPath)
        let manifest = try DecimalChannelMeasurement.manifestEntries(manifestPath: manifestPath)
        let shippable = Set(manifest.map(\.volumeId))
        let bandOf = Dictionary(uniqueKeysWithValues: manifest.map {
            ($0.volumeId, DecimalChannelMeasurement.band(
                forMidpointYear: DecimalChannelMeasurement.midpointYear(of: $0.dateRange)))
        })

        let allFiles = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        let files = allFiles.filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        guard !files.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }
        generatorLog("[IbidGap] \(files.count) shippable volumes of \(allFiles.count) on disk")

        // The SHIPPED admission rule — the shared chain, with this caller's schedule injected.
        // Returned as the first failing guard's name so a refused inheritance can say WHY in
        // the report and the samples.
        let verdict = FootnoteIbidGapWalker.shippedAdmissionVerdict { schedule.composes($0) }

        var report = Report()
        report.generated = generated
        var bandTallies: [String: GapTally] = [:]
        var bandVolumes: [String: Set<String>] = [:]
        var bandDocuments: [String: Int] = [:]
        var bandFootnotes: [String: Int] = [:]
        var inheritedKeysByBand: [String: Set<String>] = [:]
        var gapVolumesByBand: [String: Set<String>] = [:]
        var inheritedKeyCounts: [String: Int] = [:]
        var samples: [Sample] = []
        var seenPerOutcome: [String: Int] = [:]

        for file in files {
            let data = try Data(contentsOf: file)
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            let band = bandOf[volumeId] ?? DecimalChannelMeasurement.Band.unknown.rawValue
            bandVolumes[band, default: []].insert(volumeId)

            var walker = FootnoteIbidGapWalker(admissionVerdict: verdict)
            for document in DocumentFootnoteExtractor.extract(fromXML: data) {
                report.documentsScanned += 1
                bandDocuments[band, default: 0] += 1
                bandFootnotes[band, default: 0] += document.footnotes.count
                report.footnotesScanned += document.footnotes.count

                walker.beginDocument()
                for note in document.footnotes {
                    let result = walker.scan(note: note)
                    var tally = bandTallies[band] ?? GapTally()
                    tally.directAdmitted += result.directAdmitted
                    tally.directAdmittedInArchivalClauses += result.directAdmittedInArchivalClauses
                    tally.explicitIbidAdmitted += result.explicitIbidAdmitted
                    tally.ambiguousClauses += result.ambiguousClauses

                    for observation in result.observations {
                        tally.bareIbidClauses += 1
                        var sample = Sample(volumeId: volumeId,
                                            documentId: document.documentId, band: band,
                                            armingClause: observation.armingClause,
                                            ibidClause: observation.ibidClause)
                        switch observation.outcome {
                        case let .inheritsAdmittedClass(key, distance, chained):
                            tally.inheritsAdmittedClass += 1
                            if chained { tally.chainedInheritances += 1 }
                            tally.admittedDistanceHistogram["\(distance)", default: 0] += 1
                            inheritedKeysByBand[band, default: []].insert(key)
                            gapVolumesByBand[band, default: []].insert(volumeId)
                            inheritedKeyCounts[key, default: 0] += 1
                            sample.outcome = "inheritsAdmittedClass"
                            sample.classKey = key
                            sample.distance = distance
                            sample.chained = chained
                        case let .inheritsRefusedClass(key, reason, distance):
                            tally.inheritsRefusedClass[reason, default: 0] += 1
                            sample.outcome = "inheritsRefusedClass.\(reason)"
                            sample.classKey = key
                            sample.distance = distance
                        case .lastCitedIsArchival:
                            tally.lastCitedArchival += 1
                            sample.outcome = "lastCitedIsArchival"
                        case let .beyondReach(key, distance, admitted):
                            let bucket = distance >= 6 ? "6+" : "\(distance)"
                            tally.beyondReach[bucket, default: 0] += 1
                            if admitted { tally.beyondReachAdmitted += 1 }
                            sample.outcome = "beyondReach"
                            sample.classKey = key
                            sample.distance = distance
                        case let .blockedByPublication(key, admitted):
                            tally.blockedByPublication += 1
                            if admitted { tally.blockedByPublicationAdmitted += 1 }
                            sample.outcome = "blockedByPublication"
                            sample.classKey = key
                        case .noPriorCitation:
                            tally.noPriorCitation += 1
                            sample.outcome = "noPriorCitation"
                        }
                        let seen = (seenPerOutcome[sample.outcome] ?? 0) + 1
                        seenPerOutcome[sample.outcome] = seen
                        if sampleEvery > 0, (seen - 1) % sampleEvery == 0 {
                            samples.append(sample)
                        }
                    }
                    bandTallies[band] = tally
                }
            }
        }

        report.volumesScanned = files.count
        var overall = GapTally()
        var allInheritedKeys: Set<String> = []
        var allGapVolumes: Set<String> = []
        for band in DecimalChannelMeasurement.Band.allCases {
            let key = band.rawValue
            guard var tally = bandTallies[key] else { continue }
            tally.distinctInheritedKeys = inheritedKeysByBand[key]?.count ?? 0
            tally.volumesWithGap = gapVolumesByBand[key]?.count ?? 0
            bandTallies[key] = tally
            overall.bareIbidClauses += tally.bareIbidClauses
            overall.inheritsAdmittedClass += tally.inheritsAdmittedClass
            overall.chainedInheritances += tally.chainedInheritances
            overall.admittedDistanceHistogram.merge(tally.admittedDistanceHistogram, uniquingKeysWith: +)
            overall.inheritsRefusedClass.merge(tally.inheritsRefusedClass, uniquingKeysWith: +)
            overall.lastCitedArchival += tally.lastCitedArchival
            overall.beyondReach.merge(tally.beyondReach, uniquingKeysWith: +)
            overall.beyondReachAdmitted += tally.beyondReachAdmitted
            overall.blockedByPublication += tally.blockedByPublication
            overall.blockedByPublicationAdmitted += tally.blockedByPublicationAdmitted
            overall.noPriorCitation += tally.noPriorCitation
            overall.explicitIbidAdmitted += tally.explicitIbidAdmitted
            overall.ambiguousClauses += tally.ambiguousClauses
            overall.directAdmitted += tally.directAdmitted
            overall.directAdmittedInArchivalClauses += tally.directAdmittedInArchivalClauses
            allInheritedKeys.formUnion(inheritedKeysByBand[key] ?? [])
            allGapVolumes.formUnion(gapVolumesByBand[key] ?? [])
        }
        overall.distinctInheritedKeys = allInheritedKeys.count
        overall.volumesWithGap = allGapVolumes.count
        report.overall = overall
        for band in DecimalChannelMeasurement.Band.allCases {
            guard let volumes = bandVolumes[band.rawValue], !volumes.isEmpty else { continue }
            var entry = BandReport()
            entry.band = band.rawValue
            entry.volumes = volumes.count
            entry.documentsScanned = bandDocuments[band.rawValue] ?? 0
            entry.footnotesScanned = bandFootnotes[band.rawValue] ?? 0
            entry.tally = bandTallies[band.rawValue] ?? GapTally()
            report.bands.append(entry)
        }
        report.topInheritedKeys = Dictionary(uniqueKeysWithValues:
            inheritedKeyCounts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
                .prefix(40).map { ($0.key, $0.value) })

        // A run that saw no bare `Ibid.` or re-derived no direct channel is a broken walker,
        // not a quiet corpus: the #784 measurement counted 13,432 `(Ibid., …)` occurrences and
        // the shipped channel admits tens of thousands of direct references.
        guard overall.bareIbidClauses > 0, overall.directAdmitted > 0 else {
            throw GapError.brokenWalker(bareIbid: overall.bareIbidClauses,
                                        direct: overall.directAdmitted,
                                        volumes: files.count)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        try encoder.encode(report).write(to: URL(fileURLWithPath: reportPath))
        if let samplePath {
            try encoder.encode(samples).write(to: URL(fileURLWithPath: samplePath))
            generatorLog("[IbidGap] \(samples.count) samples → \(samplePath)")
        }
        logSummary(report, reportPath: reportPath)
    }

    // MARK: - Errors

    public enum GapError: Error, CustomStringConvertible {
        case brokenWalker(bareIbid: Int, direct: Int, volumes: Int)

        public var description: String {
            switch self {
            case let .brokenWalker(bareIbid, direct, volumes):
                return """
                    [IbidGap] \(bareIbid) bare Ibid. clauses and \(direct) direct admissions \
                    over \(volumes) volumes. The corpus carries thousands of both, so a zero \
                    means the walker is broken, not that the gap is empty. Refusing to write.
                    """
            }
        }
    }

    // MARK: - Logging

    private static func logSummary(_ report: Report, reportPath: String) {
        let o = report.overall
        generatorLog("""
        [IbidGap] \(report.volumesScanned) volumes, \(report.documentsScanned) documents, \
        \(report.footnotesScanned) body footnotes
          bare Ibid. clauses: \(o.bareIbidClauses)
          THE GAP (inherits admitted class): \(o.inheritsAdmittedClass) \
        (\(percent(o.inheritsAdmittedClass, of: o.directAdmitted)) of the direct channel's \
        \(o.directAdmitted)), \(o.chainedInheritances) chained, distances \
        \(o.admittedDistanceHistogram.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))
          refused-class referents: \(o.inheritsRefusedClass.values.reduce(0, +)) \
        (\(o.inheritsRefusedClass.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")))
          archival referents (existing channel): \(o.lastCitedArchival)
          beyond reach: \(o.beyondReach.values.reduce(0, +)) (\(o.beyondReachAdmitted) admitted); \
        blocked by publication: \(o.blockedByPublication) (\(o.blockedByPublicationAdmitted) admitted); \
        no prior citation: \(o.noPriorCitation)
          explicit Ibid. already harvested: \(o.explicitIbidAdmitted); ambiguous clauses: \
        \(o.ambiguousClauses)
          parity: direct \(o.directAdmitted) + \(o.directAdmittedInArchivalClauses) in \
        archival-won clauses = \(o.directAdmitted + o.directAdmittedInArchivalClauses) vs the \
        artifact's decimalReferences
        """)
        for band in report.bands {
            let t = band.tally
            generatorLog("""
              [\(band.band)] \(band.volumes) volumes — gap \(t.inheritsAdmittedClass) vs direct \
            \(t.directAdmitted) (\(percent(t.inheritsAdmittedClass, of: t.directAdmitted))), \
            bare Ibid. \(t.bareIbidClauses), archival \(t.lastCitedArchival), \
            refused \(t.inheritsRefusedClass.values.reduce(0, +))
            """)
        }
        generatorLog("[IbidGap] report → \(reportPath)")
    }

    private static func percent(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        return String(format: "%.1f%%", Double(value) / Double(total) * 100)
    }
}
