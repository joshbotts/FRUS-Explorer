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
import SourceExplorerExportGeneratorCore
import SourceNoteKit

// MARK: - DecimalChannelMeasurement

/// Prices the decimal channel #784 deferred and #834 proposes, **without building it** (#834,
/// commit 1 of 4).
///
/// ## Why a measurement ships before a grammar
/// #834 makes two things binding before any harvest:
///
/// 1. *"Re-run the own-class measurement first"* — #784 recorded that **56%** of decimal footnote
///    hits were the citing document's *own* class, and that figure decides whether the harvest
///    excludes same-class references or merely flags them. The 56% is quoted in
///    `FootnoteCitationGrammar`'s doc comment but has **no reproducible basis in the tree**: no
///    data file, no test, and the rule that produced it is unrecorded. It is treated here as
///    unmeasured.
/// 2. *"Re-measure through `DocumentFootnoteExtractor`"* — a later issue comment counted 579,563
///    footnotes where the extractor counts 470,827 over the same 552 volumes, and instructed that
///    no figure reach shipped copy until it is re-derived through the real extractor. Two figures
///    from that scan are already in shipped help text.
///
/// So this pass answers those questions and writes a report. It touches no bundled artifact, no
/// app struct, and no database schema.
///
/// ## The three rules, and why the count is a function of the rule
/// #834 mandates *"anchor-first grammar only; never route through `decimalClassLocation`"*, where
/// an anchor is a self-identifying **repository phrase**. But
/// `CollectionKeying.centralFilesAnchorSegment` matches only `central files` and `central foreign
/// policy` — **post-war naming**. The pre-war footnotes the issue exists to reach are spelled
/// `file No. 711.684/11`. If the mandated rule cannot see them, #834's premise fails under its own
/// constraint, and no amount of grammar work fixes that. The report therefore gives three yields:
///
/// - **namesRepository** — the mandated rule.
/// - **namesFileNumber** — the era-appropriate label. Still self-identifying (the label states that
///   what follows is a central-file number), still not a shape match.
/// - **shapeOnly** — the upper bound, and the rule `decimalClassLocation`'s own contract warns
///   against: *"callers gate by classification … so box numbers or council-document ids in other
///   repositories' citations can never masquerade as a class."* Reported so the permitted rules
///   are priced against something, never as a proposal.
///
/// ## The own-class comparison
/// The citing document's own class comes from `ExportClassification.derivedKeys(for:note:)` over
/// `DocumentNoteExtractor` notes — the identical call `ProvenanceFlowIndexRunner` uses, so "own
/// class" here means what it means in `provenance-flow-index.json`. Three outcomes are counted
/// separately and they are NOT interchangeable: the candidate matches the citing document's class,
/// it differs, or **the citing document has no class at all** — the last is not evidence either
/// way, and folding it into "differs" would inflate the channel's apparent worth.
///
/// ## Read the samples
/// #784's safety verdict rested on reading samples, and both `Ibid.` defects in the lot/library
/// channel were found that way rather than by tests. `SAMPLE_OUTPUT` writes every candidate
/// stratified across the rules; the report's numbers are not to be trusted before it is read.
///
/// Version history:
///   1.0 — Session 2026-08-20: #834 commit 1
public enum DecimalChannelMeasurement {

    // MARK: - Report

    /// One rule's yield, sliced the ways the design fork needs.
    public struct RuleYield: Codable, Sendable {
        /// Candidates the rule admits.
        public var candidates = 0
        /// …of which the class equals the citing document's own class.
        public var ownClass = 0
        /// …of which the class differs from the citing document's own class.
        public var differentClass = 0
        /// …of which the citing document has NO class, so no comparison is possible. Counted apart
        /// because calling these "different" would manufacture evidence.
        public var citingDocumentUnclassed = 0
        /// …of which the key is subject-numeric (`POL 27 VIET S`), which #834 puts out of scope.
        public var subjectNumeric = 0
        /// …of which the clause would be refused by the absence-claim guard.
        public var refusedAbsence = 0
        /// …of which the clause would be refused as a publication citation.
        public var refusedPublication = 0
        /// Distinct class keys.
        public var distinctKeys = 0
        /// Distinct volumes contributing at least one candidate.
        public var volumes = 0
    }

    /// A coverage band. Bands are this measurement's own, not the app's era vocabulary — #834's
    /// claim is about 1910–1945 specifically, which no shipped band isolates.
    public struct BandReport: Codable, Sendable {
        public var band = ""
        public var volumes = 0
        public var documentsScanned = 0
        public var footnotesScanned = 0
        public var byRule: [String: RuleYield] = [:]
    }

    /// The whole report.
    public struct Report: Codable, Sendable {
        public var generated = ""
        public var volumesScanned = 0
        public var documentsScanned = 0
        /// The denominator the issue insists on: `DocumentFootnoteExtractor`'s own count.
        public var footnotesScanned = 0
        public var overall: [String: RuleYield] = [:]
        public var bands: [BandReport] = []
        /// The most-cited class keys, so the report can be read against the corpus rather than
        /// only summed. Key → candidate count, shape-only rule (the widest).
        public var topClassKeys: [String: Int] = [:]
    }

    /// One reviewable candidate.
    public struct Sample: Codable, Sendable {
        public var volumeId = ""
        public var documentId = ""
        public var classKey = ""
        public var rule = ""
        public var isSubjectNumeric = false
        public var refusal: String?
        public var citingDocumentClass: String?
        public var ownClass = false
        public var clause = ""
    }

    // MARK: - Entry point

    /// Runs the measurement and writes the report.
    ///
    /// - Parameters:
    ///   - sampleEvery: Every Nth candidate is written to `samplePath`. Sampling is per RULE, so a
    ///     rule that admits few candidates is still represented — a flat stride over the merged
    ///     stream would fill the file with shape-only hits and show almost none of the mandated
    ///     rule's, which is the one under judgement.
    public static func run(volumesDir: URL, manifestPath: String, labelsPath: String,
                           reportPath: String, samplePath: String?, sampleEvery: Int,
                           generated: String) throws {
        let schedule = try ScheduleValidator(labelsPath: labelsPath)
        let manifest = try manifestEntries(manifestPath: manifestPath)
        let shippable = Set(manifest.map(\.volumeId))
        let bandOf = Dictionary(uniqueKeysWithValues: manifest.map {
            ($0.volumeId, band(forMidpointYear: midpointYear(of: $0.dateRange)))
        })

        let allFiles = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        let files = allFiles.filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        guard !files.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }
        generatorLog("[DecimalMeasure] \(files.count) shippable volumes of \(allFiles.count) on disk")

        let parser = SourceNoteParser()
        var report = Report()
        report.generated = generated

        // Accumulators, keyed rule -> band -> tally, so a band report and the overall report are
        // the same numbers summed differently rather than two independent counts.
        var tallies: [String: [String: RuleYield]] = [:]
        var keysByRuleBand: [String: [String: Set<String>]] = [:]
        var volumesByRuleBand: [String: [String: Set<String>]] = [:]
        var bandVolumes: [String: Set<String>] = [:]
        var bandDocuments: [String: Int] = [:]
        var bandFootnotes: [String: Int] = [:]
        var shapeOnlyKeyCounts: [String: Int] = [:]
        var samples: [Sample] = []
        var seenPerRule: [String: Int] = [:]

        for file in files {
            let data = try Data(contentsOf: file)
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            let volumeBand = bandOf[volumeId] ?? Band.unknown.rawValue
            bandVolumes[volumeBand, default: []].insert(volumeId)

            // The citing document's own class — the identical call ProvenanceFlowIndexRunner
            // makes, so "own class" is the same thing it is in provenance-flow-index.json.
            var classOf: [String: String] = [:]
            for note in DocumentNoteExtractor.extract(fromXML: data) where !note.documentId.isEmpty {
                let parsed = parser.parse(note.note)
                if let cls = ExportClassification.derivedKeys(for: parsed, note: note.note)
                    .decimalClass {
                    classOf[note.documentId] = cls
                }
            }

            for document in DocumentFootnoteExtractor.extract(fromXML: data) {
                report.documentsScanned += 1
                bandDocuments[volumeBand, default: 0] += 1
                bandFootnotes[volumeBand, default: 0] += document.footnotes.count
                report.footnotesScanned += document.footnotes.count
                let ownClass = classOf[document.documentId]

                for note in document.footnotes {
                    for candidate in FootnoteCitationScanner.classCandidates(inNote: note) {
                        // A candidate counts under EVERY rule that admits it: the rules are nested
                        // (repository ⊂ anchored-somehow ⊂ shape), and reporting them as disjoint
                        // buckets would make "what does relaxing the rule buy" unanswerable.
                        var rules = [Rule.shapeOnly]
                        if candidate.evidence.namesRepository { rules.append(.namesRepository) }
                        if candidate.evidence.namesFileNumber { rules.append(.namesFileNumber) }
                        if candidate.evidence.carriesSerial {
                            rules.append(.carriesSerial)
                            if candidate.classKey.contains(".") { rules.append(.carriesSerialDotted) }
                            if schedule.composes(candidate.classKey) {
                                rules.append(.carriesSerialComposing)
                            }
                        }
                        if !candidate.evidence.shapeOnly { rules.append(.anySelfIdentifying) }

                        for rule in rules {
                            let key = rule.rawValue
                            var tally = tallies[key]?[volumeBand] ?? RuleYield()
                            tally.candidates += 1
                            if candidate.isSubjectNumeric { tally.subjectNumeric += 1 }
                            switch candidate.refusal {
                            case "absenceClaim": tally.refusedAbsence += 1
                            case "publication": tally.refusedPublication += 1
                            default: break
                            }
                            if let ownClass {
                                if ownClass == candidate.classKey {
                                    tally.ownClass += 1
                                } else {
                                    tally.differentClass += 1
                                }
                            } else {
                                tally.citingDocumentUnclassed += 1
                            }
                            tallies[key, default: [:]][volumeBand] = tally
                            keysByRuleBand[key, default: [:]][volumeBand, default: []]
                                .insert(candidate.classKey)
                            volumesByRuleBand[key, default: [:]][volumeBand, default: []]
                                .insert(volumeId)

                            let seen = (seenPerRule[key] ?? 0) + 1
                            seenPerRule[key] = seen
                            if sampleEvery > 0, seen % sampleEvery == 0 {
                                samples.append(Sample(
                                    volumeId: volumeId, documentId: document.documentId,
                                    classKey: candidate.classKey, rule: key,
                                    isSubjectNumeric: candidate.isSubjectNumeric,
                                    refusal: candidate.refusal,
                                    citingDocumentClass: ownClass,
                                    ownClass: ownClass == candidate.classKey,
                                    clause: candidate.clause))
                            }
                        }
                        shapeOnlyKeyCounts[candidate.classKey, default: 0] += 1
                    }
                }
            }
        }

        report.volumesScanned = files.count
        for rule in Rule.allCases {
            let key = rule.rawValue
            var merged = RuleYield()
            var allKeys: Set<String> = []
            var allVolumes: Set<String> = []
            for (band, tally) in tallies[key] ?? [:] {
                merged.candidates += tally.candidates
                merged.ownClass += tally.ownClass
                merged.differentClass += tally.differentClass
                merged.citingDocumentUnclassed += tally.citingDocumentUnclassed
                merged.subjectNumeric += tally.subjectNumeric
                merged.refusedAbsence += tally.refusedAbsence
                merged.refusedPublication += tally.refusedPublication
                allKeys.formUnion(keysByRuleBand[key]?[band] ?? [])
                allVolumes.formUnion(volumesByRuleBand[key]?[band] ?? [])
            }
            merged.distinctKeys = allKeys.count
            merged.volumes = allVolumes.count
            report.overall[key] = merged
        }
        for band in Band.allCases {
            var entry = BandReport()
            entry.band = band.rawValue
            entry.volumes = bandVolumes[band.rawValue]?.count ?? 0
            entry.documentsScanned = bandDocuments[band.rawValue] ?? 0
            entry.footnotesScanned = bandFootnotes[band.rawValue] ?? 0
            for rule in Rule.allCases {
                var tally = tallies[rule.rawValue]?[band.rawValue] ?? RuleYield()
                tally.distinctKeys = keysByRuleBand[rule.rawValue]?[band.rawValue]?.count ?? 0
                tally.volumes = volumesByRuleBand[rule.rawValue]?[band.rawValue]?.count ?? 0
                entry.byRule[rule.rawValue] = tally
            }
            report.bands.append(entry)
        }
        report.topClassKeys = Dictionary(uniqueKeysWithValues:
            shapeOnlyKeyCounts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
                .prefix(40).map { ($0.key, $0.value) })

        // A run that finds nothing is a broken detector, not an empty corpus — and a report of
        // zeroes would be read as "the channel is not there" rather than "the measurement failed".
        guard (report.overall[Rule.shapeOnly.rawValue]?.candidates ?? 0) > 0 else {
            throw MeasurementError.noCandidates(volumes: files.count,
                                                footnotes: report.footnotesScanned)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        try encoder.encode(report).write(to: URL(fileURLWithPath: reportPath))
        if let samplePath {
            try encoder.encode(samples).write(to: URL(fileURLWithPath: samplePath))
            generatorLog("[DecimalMeasure] \(samples.count) samples → \(samplePath)")
        }
        logSummary(report, reportPath: reportPath)
    }

    // MARK: - Rules and bands

    /// The three rules, nested widest-last.
    public enum Rule: String, CaseIterable, Sendable {
        /// #834's mandated rule: the clause names the repository.
        case namesRepository
        /// The era-appropriate label: the clause says `file No.`.
        case namesFileNumber
        /// The class carries its document serial (`793.94/9732`) — self-identifying without a
        /// label. Found by READING SAMPLES of the shape-only rule, not by design.
        case carriesSerial
        /// Any of the three above — the rule a harvest would actually run.
        case anySelfIdentifying
        /// `carriesSerial` restricted to keys that carry a DOT.
        ///
        /// **Kept only as a rejected comparison.** A first pass read the serial rule's dotless hits
        /// as false positives; the owner corrected that — dotless decimal file numbers are real,
        /// and the parser admits them deliberately. Composing `222` against the shipped schedule
        /// gives *Extradition / Ecuador*, a perfectly good key. The dot buys nothing that
        /// composition does not buy better, and this row exists so the discarded rule is priced
        /// rather than merely abandoned.
        case carriesSerialDotted
        /// `carriesSerial` restricted to keys that COMPOSE under the 1910-1949 schedule shipped in
        /// `decimal-class-labels.json` — class digit + country number, the filing system's own
        /// grammar. This is the rule with the best evidence behind it.
        ///
        /// **Two limits, both real, and neither is a detail.** The shipped country table is known
        /// INCOMPLETE — #828's analysis measured ~290 distinct 1910-49 codes against the 198 that
        /// shipped — so a key that fails to compose is not thereby proven false. And there is NO
        /// shipped schedule for 1950 onward (parsed, measured, deliberately skipped because the
        /// classification was renumbered), so for post-war volumes this rule is testing keys
        /// against a schedule that does not govern them. Read it for the pre-war band, which is
        /// the band #834 is about; treat the post-war row as uninterpretable.
        case carriesSerialComposing
        /// Shape alone — the upper bound, measured to be heavily contaminated. Never a proposal.
        case shapeOnly
    }

    /// Coverage bands. `preWar` is the band #834's claim is about.
    public enum Band: String, CaseIterable, Sendable {
        case preDecimal = "before 1910"
        case preWar = "1910-1945"
        case postWar = "1946 and later"
        case unknown = "no coverage dates"
    }

    static func band(forMidpointYear year: Int?) -> String {
        guard let year else { return Band.unknown.rawValue }
        if year < 1910 { return Band.preDecimal.rawValue }
        if year <= 1945 { return Band.preWar.rawValue }
        return Band.postWar.rawValue
    }

    /// The midpoint of the coverage span, by the leading four digits of each ISO endpoint — the
    /// same reading `SourceProvenanceIndex.coverageDecade` uses, computed locally because this
    /// module does not depend on that one and the runner already declares its own manifest struct.
    static func midpointYear(of range: ManifestEntry.DateRange?) -> Int? {
        guard let range else { return nil }
        let first = year(of: range.earliest)
        let last = year(of: range.latest)
        switch (first, last) {
        case let (.some(a), .some(b)): return (a + b) / 2
        case let (.some(a), nil): return a
        case let (nil, .some(b)): return b
        default: return nil
        }
    }

    private static func year(of iso: String?) -> Int? {
        guard let iso, iso.count >= 4 else { return nil }
        return Int(iso.prefix(4))
    }

    // MARK: - Schedule composition

    /// Tests a class key against the State Department's own 1910-1949 classification schedule, as
    /// parsed by #828 into `decimal-class-labels.json`.
    ///
    /// The filing system is COMPOSITIONAL — class digit + country number + subject suffix — which
    /// is why a table of 9 classes and 198 countries can price a key it has never seen. This asks
    /// only the first two: does the key open with a real class digit followed by a real country
    /// number? The subject suffix is deliberately not required, because the shipped subject
    /// vocabulary covers classes 6 and 8 only.
    public struct ScheduleValidator {
        private let classes: Set<String>
        private let countries: Set<String>

        public init(labelsPath: String) throws {
            struct Payload: Decodable {
                struct Schedule: Decodable {
                    let id: String
                    let classes: [String: String]
                    let countries: [String: String]
                }
                let schedules: [Schedule]
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: labelsPath))
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            // The 1910-1949 schedule specifically. A later schedule would answer a different
            // question, and none ships today.
            guard let schedule = payload.schedules.first(where: { $0.id == "1910-1949" })
                    ?? payload.schedules.first else {
                throw MeasurementError.noSchedule(labelsPath)
            }
            classes = Set(schedule.classes.keys)
            countries = Set(schedule.countries.keys.map { $0.lowercased() })
        }

        /// Whether `key` opens with a schedule class digit and a schedule country number.
        ///
        /// Country numbers are two digits with an optional letter suffix (`51r` is Algeria), so the
        /// longer match is tried first — otherwise `851R.00` would test `51` (France) and silently
        /// attribute an Algerian file to France.
        public func composes(_ key: String) -> Bool {
            // Delegates to the shared rule so the artifact and the indexed table cannot disagree
            // about the same footnote — see `DecimalScheduleComposition`.
            DecimalScheduleComposition.composes(key, classes: classes, countries: countries)
        }
    }

    // MARK: - Manifest

    /// Only the two fields this pass needs. Declared locally, matching
    /// `ExternalCitationIndexRunner.shippableVolumeIds`' own inline manifest struct.
    public struct ManifestEntry: Decodable, Sendable {
        public struct DateRange: Decodable, Sendable {
            public let earliest: String?
            public let latest: String?
        }
        public let volumeId: String
        public let dateRange: DateRange?
    }

    static func manifestEntries(manifestPath: String) throws -> [ManifestEntry] {
        let url = URL(fileURLWithPath: manifestPath)
        return try JSONDecoder().decode([ManifestEntry].self, from: Data(contentsOf: url))
    }

    // MARK: - Errors

    public enum MeasurementError: Error, CustomStringConvertible {
        case noCandidates(volumes: Int, footnotes: Int)
        case noSchedule(String)

        public var description: String {
            switch self {
            case let .noCandidates(volumes, footnotes):
                return """
                    [DecimalMeasure] found NO class candidates in \(footnotes) footnotes over \
                    \(volumes) volumes. The corpus cites decimal classes in tens of thousands of \
                    source notes, so zero here means the detector is broken, not that the channel \
                    is empty. Refusing to write a report of zeroes.
                    """
            case let .noSchedule(path):
                return "[DecimalMeasure] no classification schedule in \(path)"
            }
        }
    }

    // MARK: - Logging

    private static func logSummary(_ report: Report, reportPath: String) {
        generatorLog("""
        [DecimalMeasure] \(report.volumesScanned) volumes, \(report.documentsScanned) documents, \
        \(report.footnotesScanned) body footnotes (DocumentFootnoteExtractor's own count)
        """)
        for rule in Rule.allCases {
            guard let y = report.overall[rule.rawValue] else { continue }
            let comparable = y.ownClass + y.differentClass
            generatorLog("""
              \(rule.rawValue.padding(toLength: 16, withPad: " ", startingAt: 0)) \
            \(y.candidates) candidates in \(y.volumes) volumes, \(y.distinctKeys) keys — \
            own-class \(y.ownClass)/\(comparable) (\(percent(y.ownClass, of: comparable))), \
            unclassed citer \(y.citingDocumentUnclassed), subject-numeric \(y.subjectNumeric), \
            refused \(y.refusedAbsence + y.refusedPublication)
            """)
        }
        for band in report.bands where band.volumes > 0 {
            let parts = Rule.allCases.map { rule -> String in
                let y = band.byRule[rule.rawValue] ?? RuleYield()
                return "\(rule.rawValue) \(y.candidates)"
            }.joined(separator: ", ")
            generatorLog("  [\(band.band)] \(band.volumes) volumes — \(parts)")
        }
        generatorLog("[DecimalMeasure] report → \(reportPath)")
    }

    private static func percent(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        return String(format: "%.1f%%", Double(value) / Double(total) * 100)
    }
}
