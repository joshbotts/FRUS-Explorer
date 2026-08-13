// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// One tester's verdict on one semantic neighbour.
///
/// **Every field exists to answer a question the retired blind panel would have answered.** The
/// panel graded 100 rows, era-stratified, because the program's open question was never "is this
/// good" but "is this good *before 1900*" — and `era` is what carries that here. A feedback log
/// without it would record enthusiasm and prove nothing.
///
/// Decoding is deliberately lenient on everything except the pair and the verdict: `SemanticFeedbackLog`
/// swallows a decode failure and returns an empty array, so a non-optional property added in a later
/// version would silently erase every verdict a tester had already recorded.
struct SemanticFeedbackEntry: Codable, Identifiable, Sendable, Hashable {

    /// What the tester said about the row.
    enum Verdict: String, Codable, Sendable, CaseIterable {
        /// A neighbour a historian would want.
        case helpful
        /// A neighbour that wastes the reader's time.
        case notHelpful
    }

    /// Stable identity for lists and de-duplication.
    var id: String { "\(recordedAt.timeIntervalSince1970)-\(anchor)-\(neighbour)" }

    /// When the verdict was given.
    let recordedAt: Date
    /// The anchor, as `volumeId/documentId`.
    let anchor: String
    /// The neighbour being judged, as `volumeId/documentId`.
    let neighbour: String
    /// The verdict.
    let verdict: Verdict
    /// The approximate cosine the row was ranked on, so a verdict can be read against the score that
    /// produced it — "everything above 0.9 is good, everything below 0.7 is noise" is a finding.
    let cosine: Double?
    /// The anchor's coverage era, from the app's own `CoverageEra` banding rather than a second one.
    /// **This is the field the whole log exists for.**
    let era: String?
    /// Whether anchor and neighbour are in the same volume — the corpus-scale measurement found 78%
    /// of top-1 neighbours are volume-mates, and whether that reads as useful or as an echo is a
    /// judgement only a reader can make.
    let sameVolume: Bool?
    /// The artifact generation the verdict describes. A re-harvest invalidates it, and without this
    /// there would be no way to tell which vectors were being judged.
    let provenanceDigest: String?

    /// Creates an entry.
    /// - Parameters:
    ///   - recordedAt: Timestamp.
    ///   - anchor: Anchor composite key.
    ///   - neighbour: Neighbour composite key.
    ///   - verdict: The tester's verdict.
    ///   - cosine: The score the row was ranked on.
    ///   - era: The anchor's coverage era.
    ///   - sameVolume: Whether the pair share a volume.
    ///   - provenanceDigest: The vector generation judged.
    init(recordedAt: Date, anchor: String, neighbour: String, verdict: Verdict,
         cosine: Double?, era: String?, sameVolume: Bool?, provenanceDigest: String?) {
        self.recordedAt = recordedAt
        self.anchor = anchor
        self.neighbour = neighbour
        self.verdict = verdict
        self.cosine = cosine
        self.era = era
        self.sameVolume = sameVolume
        self.provenanceDigest = provenanceDigest
    }
}

/// The tester feedback path for the experimental semantic axis.
///
/// ## Why this exists at all
///
/// The design specified a blind panel — 100 era-stratified rows, graded before the axis could ship —
/// and the owner retired it (2026-08-12) in favour of tester judgement. That trade only holds if
/// testers can actually report, so this is the other half of the decision: **an experiment nobody can
/// report on is not evidence-gathering, it is just shipping.**
///
/// ## Why it is not a `@Model`
///
/// A SwiftData model — or a stored property on one — changes the CloudKit schema and needs a
/// Production deploy before the build ships; #488 is what happens when that is missed. Beta feedback
/// is not worth that tax, and it should not sync in any case: it is a tester's notes about the app,
/// not their research. This follows `SyncDiagnosticsLog` instead — an actor over a bounded JSON file
/// in Application Support, local by construction.
///
/// Version history:
///   1.0 — V-3 follow-up: initial implementation
actor SemanticFeedbackLog {

    /// The shared app-wide log.
    static let shared = SemanticFeedbackLog()

    /// Maximum verdicts retained. Generous because a tester's verdicts are the evidence, not
    /// telemetry — but bounded, because an unbounded file on a device is somebody's bug report.
    private let maxEntries = 2_000

    /// In-memory copy, loaded lazily.
    private var cache: [SemanticFeedbackEntry]?

    /// The durable file, alongside the sync diagnostics log. Never Caches — the OS may purge it, and
    /// purging a tester's verdicts silently would be worse than not collecting them.
    static var fileURL: URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        let directory = base.appendingPathComponent("FRUSExplorer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("semantic-feedback.json")
    }

    /// Records a verdict.
    ///
    /// A second verdict on the same pair **replaces** the first rather than appending: a tester who
    /// changes their mind has one opinion, not two, and counting both would let one row's
    /// indecision outweigh ten rows of agreement.
    ///
    /// - Parameter entry: The verdict to record.
    func record(_ entry: SemanticFeedbackEntry) {
        var rows = loaded()
        rows.removeAll { $0.anchor == entry.anchor && $0.neighbour == entry.neighbour }
        rows.append(entry)
        if rows.count > maxEntries { rows.removeFirst(rows.count - maxEntries) }
        persist(rows)
    }

    /// The verdict already recorded for a pair, if any — so a row can show what the tester said.
    ///
    /// - Parameters:
    ///   - anchor: Anchor composite key.
    ///   - neighbour: Neighbour composite key.
    /// - Returns: The recorded verdict.
    func verdict(anchor: String, neighbour: String) -> SemanticFeedbackEntry.Verdict? {
        loaded().last { $0.anchor == anchor && $0.neighbour == neighbour }?.verdict
    }

    /// Every recorded verdict, oldest first.
    func entries() -> [SemanticFeedbackEntry] { loaded() }

    /// A short summary for the Settings screen: totals, and the split by era.
    ///
    /// The era split is surfaced rather than buried in the export because it is the number that says
    /// whether the feedback can answer the question it replaced. Zero pre-1900 verdicts after a beta
    /// means the panel was retired and nothing took its place.
    ///
    /// - Returns: Total, helpful count, and per-era totals sorted by era name.
    func summary() -> (total: Int, helpful: Int, byEra: [(era: String, count: Int)]) {
        let rows = loaded()
        var eras: [String: Int] = [:]
        for row in rows { eras[row.era ?? "unknown", default: 0] += 1 }
        return (total: rows.count,
                helpful: rows.filter { $0.verdict == .helpful }.count,
                byEra: eras.map { (era: $0.key, count: $0.value) }.sorted { $0.era < $1.era })
    }

    /// The export payload: pretty-printed JSON with ISO-8601 dates.
    ///
    /// - Returns: The encoded verdicts, or `nil` when encoding fails.
    func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(loaded())
    }

    /// Deletes every recorded verdict.
    func clear() {
        cache = []
        if let url = Self.fileURL { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Persistence

    /// Loads on first access, caching thereafter.
    private func loaded() -> [SemanticFeedbackEntry] {
        if let cache { return cache }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var rows: [SemanticFeedbackEntry] = []
        if let url = Self.fileURL, let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([SemanticFeedbackEntry].self, from: data) {
            rows = decoded
        }
        cache = rows
        return rows
    }

    /// Writes atomically and updates the cache.
    /// - Parameter rows: The rows to persist.
    private func persist(_ rows: [SemanticFeedbackEntry]) {
        cache = rows
        guard let url = Self.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(rows) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
