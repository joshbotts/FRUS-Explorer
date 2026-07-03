// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

/// Classification outcome labels for `ParsedSourceNote`, in fixed report order.
///
/// Version history:
///   1.0 — Source Explorer Phase 2 (Session 2026-07-03): initial implementation
///   1.1 — Source Explorer Phase 2 step 2 (Session 2026-07-03): added
///          `.namedFileSeries` (parser grammar v2 new case)
public enum EvalOutcome: Int, CaseIterable, Sendable {
    /// `.centralFiles` — decimal/File-No. central-file citation.
    case centralFiles
    /// `.cfpfFile` — Central Foreign Policy File reel / AAD reference.
    case cfpfFile
    /// `.lotFile` — State Department lot file.
    case lotFile
    /// `.presidentialLibrary` — presidential-library collection.
    case presidentialLibrary
    /// `.naraCollection` — NARA/WNRC record group citation.
    case naraCollection
    /// `.ciaCollection` — CIA job-number citation.
    case ciaCollection
    /// `.namedFileSeries` — named office-file series / manuscript collection.
    case namedFileSeries
    /// `.foreignGovernmentArchive` — non-US archive.
    case foreignGovernmentArchive
    /// `.previouslyPublished` — books/journals/other FRUS volumes.
    case previouslyPublished
    /// `.unrecognized` — no grammar rule matched (the number Phase 2 drives down).
    case unrecognized

    /// Maps a parse result to its report outcome.
    ///
    /// - Parameter parsed: A `SourceNoteParser.parse(_:)` result.
    public init(parsed: ParsedSourceNote) {
        switch parsed {
        case .centralFiles:             self = .centralFiles
        case .cfpfFile:                 self = .cfpfFile
        case .lotFile:                  self = .lotFile
        case .presidentialLibrary:      self = .presidentialLibrary
        case .naraCollection:           self = .naraCollection
        case .ciaCollection:            self = .ciaCollection
        case .namedFileSeries:          self = .namedFileSeries
        case .foreignGovernmentArchive: self = .foreignGovernmentArchive
        case .previouslyPublished:      self = .previouslyPublished
        case .unrecognized:             self = .unrecognized
        }
    }

    /// Report row label (the `ParsedSourceNote` case name).
    public var label: String {
        switch self {
        case .centralFiles:             return "centralFiles"
        case .cfpfFile:                 return "cfpfFile"
        case .lotFile:                  return "lotFile"
        case .presidentialLibrary:      return "presidentialLibrary"
        case .naraCollection:           return "naraCollection"
        case .ciaCollection:            return "ciaCollection"
        case .namedFileSeries:          return "namedFileSeries"
        case .foreignGovernmentArchive: return "foreignGovernmentArchive"
        case .previouslyPublished:      return "previouslyPublished"
        case .unrecognized:             return "unrecognized"
        }
    }
}

/// Accumulates per-era × per-outcome counts plus capped unrecognized samples, and
/// renders the deterministic diffable report text.
///
/// Determinism: no timestamps or environment data in the body; eras render in
/// chronological order and outcomes in fixed `EvalOutcome` order; samples are the
/// first `sampleCap` distinct unrecognized texts per era in corpus (file) order, so
/// re-runs over the same csv produce byte-identical output.
///
/// Version history:
///   1.0 — Source Explorer Phase 2 (Session 2026-07-03): initial implementation
public struct EvalReport {

    /// Maximum distinct unrecognized samples retained per era.
    public let sampleCap: Int

    /// counts[era][outcome] — note tallies.
    private var counts: [[Int]]
    /// Distinct volume ids seen per era.
    private var volumes: [Set<String>]
    /// First-seen distinct unrecognized parser inputs per era, capped at `sampleCap`.
    private var samples: [[String]]
    /// Dedupe sets backing `samples`.
    private var sampleSeen: [Set<String>]
    /// Rows whose volume id yielded no era bucket (should stay zero).
    private(set) var unbucketedRows = 0

    /// Creates an empty report accumulator.
    ///
    /// - Parameter sampleCap: Max distinct unrecognized samples kept per era (default 25).
    public init(sampleCap: Int = 25) {
        self.sampleCap = sampleCap
        let eraCount = EraBucket.allCases.count
        counts = Array(repeating: Array(repeating: 0, count: EvalOutcome.allCases.count),
                       count: eraCount)
        volumes = Array(repeating: [], count: eraCount)
        samples = Array(repeating: [], count: eraCount)
        sampleSeen = Array(repeating: [], count: eraCount)
    }

    /// Records one parsed note.
    ///
    /// - Parameters:
    ///   - volumeId: The row's volume id (bucketed to an era).
    ///   - outcome: The parse outcome.
    ///   - parserInput: The normalized text fed to the parser (sampled when
    ///     unrecognized).
    public mutating func record(volumeId: String, outcome: EvalOutcome, parserInput: String) {
        guard let era = EraBucket(volumeId: volumeId) else {
            unbucketedRows += 1
            return
        }
        counts[era.rawValue][outcome.rawValue] += 1
        volumes[era.rawValue].insert(volumeId)
        if outcome == .unrecognized,
           samples[era.rawValue].count < sampleCap,
           !sampleSeen[era.rawValue].contains(parserInput) {
            sampleSeen[era.rawValue].insert(parserInput)
            samples[era.rawValue].append(parserInput)
        }
    }

    /// Total notes recorded for `era`.
    ///
    /// - Parameter era: The era bucket.
    public func total(for era: EraBucket) -> Int {
        counts[era.rawValue].reduce(0, +)
    }

    /// Notes recorded for `era` with `outcome`.
    ///
    /// - Parameters:
    ///   - era: The era bucket.
    ///   - outcome: The classification outcome.
    public func count(for era: EraBucket, outcome: EvalOutcome) -> Int {
        counts[era.rawValue][outcome.rawValue]
    }

    /// Renders the full diffable report.
    ///
    /// - Parameter corpusDescription: One line describing the input (path + filter),
    ///   included verbatim in the header.
    public func render(corpusDescription: String) -> String {
        var out: [String] = []
        out.append("SourceNoteParser classification eval")
        out.append("corpus: \(corpusDescription)")
        out.append("normalization: IndexingPipeline post-Phase-1 replica " +
                   "(head-note Source:-paragraph selection, [Source:] wrapper collapse, " +
                   "whitespace normalization) — see NotePreparation.swift for documented gaps")
        out.append("")

        let grandTotal = EraBucket.allCases.map { total(for: $0) }.reduce(0, +)
        out.append(String(format: "TOTAL NOTES: %d", grandTotal))
        if unbucketedRows > 0 {
            out.append("unbucketed rows (no frusYYYY volume id): \(unbucketedRows)")
        }
        out.append("")

        // Per-era outcome tables.
        for era in EraBucket.allCases {
            let eraTotal = total(for: era)
            guard eraTotal > 0 else { continue }
            out.append("=== era \(era.label)  (volumes: \(volumes[era.rawValue].count), " +
                       "notes: \(eraTotal))")
            for outcome in EvalOutcome.allCases {
                let n = count(for: era, outcome: outcome)
                guard n > 0 else { continue }
                out.append(Self.row(outcome.label, n, of: eraTotal))
            }
            out.append("")
        }

        // Overall outcome table.
        out.append("=== OVERALL")
        for outcome in EvalOutcome.allCases {
            let n = EraBucket.allCases.map { count(for: $0, outcome: outcome) }.reduce(0, +)
            out.append(Self.row(outcome.label, n, of: grandTotal))
        }
        out.append("")

        // Unrecognized rate summary (the Phase 2 target metric).
        out.append("=== UNRECOGNIZED RATE BY ERA (Phase 2 targets: <10% 1906-1963, <15% overall)")
        for era in EraBucket.allCases {
            let eraTotal = total(for: era)
            guard eraTotal > 0 else { continue }
            out.append(Self.row(era.label, count(for: era, outcome: .unrecognized), of: eraTotal))
        }
        let unrecTotal = EraBucket.allCases.map { count(for: $0, outcome: .unrecognized) }
            .reduce(0, +)
        out.append(Self.row("overall", unrecTotal, of: grandTotal))
        out.append("")

        // Capped unrecognized samples for grammar work.
        out.append("=== UNRECOGNIZED SAMPLES (first \(sampleCap) distinct per era, corpus order, " +
                   "truncated to 200 chars)")
        for era in EraBucket.allCases where !samples[era.rawValue].isEmpty {
            out.append("--- \(era.label)")
            for sample in samples[era.rawValue] {
                out.append("  | " + String(sample.prefix(200)))
            }
        }
        out.append("")
        return out.joined(separator: "\n")
    }

    /// Formats one aligned `label  count (percent)` report row.
    private static func row(_ label: String, _ n: Int, of total: Int) -> String {
        let pct = total > 0 ? Double(n) * 100 / Double(total) : 0
        let padded = label.padding(toLength: max(26, label.count), withPad: " ", startingAt: 0)
        return "  " + padded + String(format: " %8d  (%5.1f%%)", n, pct)
    }
}
