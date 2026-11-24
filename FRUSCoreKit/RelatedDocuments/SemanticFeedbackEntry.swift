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
///
/// Version history:
///   1.0 — V-3 follow-up: initial implementation, in the app's `SemanticFeedbackLog.swift`
///   1.1 — 2026-11-23: FRUS Explorer Light's S26a — FRUSCoreKit's, and public, with its file's coding
///          (``fileData(_:)``, ``exportData(_:)``, ``entries(from:)``), which the app's log, an actor
///          that stays in the app, reads and writes through; every field and its key are as they were
public struct SemanticFeedbackEntry: Codable, Identifiable, Sendable, Hashable {

    /// What the tester said about the row.
    public enum Verdict: String, Codable, Sendable, CaseIterable {
        /// A neighbour a historian would want.
        case helpful
        /// A neighbour that wastes the reader's time.
        case notHelpful
    }

    /// Stable identity for lists and de-duplication.
    public var id: String { "\(recordedAt.timeIntervalSince1970)-\(anchor)-\(neighbour)" }

    /// When the verdict was given.
    public let recordedAt: Date
    /// The anchor, as `volumeId/documentId`.
    public let anchor: String
    /// The neighbour being judged, as `volumeId/documentId`.
    public let neighbour: String
    /// The verdict.
    public let verdict: Verdict
    /// The approximate cosine the row was ranked on, so a verdict can be read against the score that
    /// produced it — "everything above 0.9 is good, everything below 0.7 is noise" is a finding.
    /// Since B4 it is the cosine through the generation's calibration, the score the row showed
    /// (`retrieval.calibratedDocumentScore`); a generation without one, the 300m's, logged the raw
    /// cosine. `provenanceDigest` says which, and the key keeps its name so earlier verdicts decode.
    public let cosine: Double?
    /// The anchor's coverage era, from the app's own `CoverageEra` banding rather than a second one,
    /// of the anchor's year in the index (`RelatedDocumentsRequest.resolvedAnchorYear(pipeline:)`),
    /// so it does not depend on the door that opened the anchor. `nil` for an anchor that neither the
    /// index nor its dateline dates, and, in a file written before 2026-10-19 (plan of record §6g),
    /// for many dated anchors too: the export's `anchor` key is what bands those.
    /// **This is the field the whole log exists for.**
    public let era: String?
    /// Whether anchor and neighbour are in the same volume — the corpus-scale measurement found 78%
    /// of top-1 neighbours are volume-mates, and whether that reads as useful or as an echo is a
    /// judgement only a reader can make.
    public let sameVolume: Bool?
    /// The artifact generation the verdict describes. A re-harvest invalidates it, and without this
    /// there would be no way to tell which vectors were being judged.
    public let provenanceDigest: String?

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
    public init(recordedAt: Date, anchor: String, neighbour: String, verdict: Verdict,
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

// MARK: - The file's coding

extension SemanticFeedbackEntry {

    /// The log file's bytes for `entries` (`semantic-feedback.json`): a JSON array with each date in
    /// ISO 8601 and each object's keys sorted.
    ///
    /// - Parameter entries: The verdicts, oldest first.
    /// - Returns: The file's bytes.
    /// - Throws: The encoder's error, which no entry of finite numbers gives.
    public static func fileData(_ entries: [SemanticFeedbackEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(entries)
    }

    /// The export's bytes for `entries`, the file a reader shares: the log file's coding,
    /// pretty-printed.
    ///
    /// - Parameter entries: The verdicts, oldest first.
    /// - Returns: The export's bytes.
    /// - Throws: The encoder's error, which no entry of finite numbers gives.
    public static func exportData(_ entries: [SemanticFeedbackEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    /// The verdicts a log file or an export holds.
    ///
    /// - Parameter data: The bytes of either.
    /// - Returns: The verdicts, in the file's order.
    /// - Throws: `DecodingError` when the bytes are not such a file.
    public static func entries(from data: Data) throws -> [SemanticFeedbackEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SemanticFeedbackEntry].self, from: data)
    }
}
