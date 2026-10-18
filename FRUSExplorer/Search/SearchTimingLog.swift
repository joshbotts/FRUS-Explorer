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
import OSLog

// MARK: - SearchTimingLog

/// Two timing lines in the system log, for the two searches that run inside a document set
/// (#1577 lane 1).
///
/// ## Why they exist
///
/// Search Within These Results (#1577) runs one engine inside the other's results, and both of its
/// halves were unmeasured on a phone: the recorded figures are an M1 Max's, and they cover scoring
/// rows already located with their match files mapped. What a phone spends encoding the question,
/// resolving a few thousand keys and first touching many match files was not known, and neither
/// was the joined form of the keyword statement, which any document set turns on. These lines let
/// the owner read both from a device before the interface is built on them.
///
/// ## What they record
///
/// Counts and durations, and nothing else: no query text, no document or volume id, no corpus
/// name. Every field is a number the app computed, so each line is public in the log.
///
/// They are written at `notice`, which the system keeps, so they are in a release build's log and
/// can be read from a connected device in Console with the filter
/// `subsystem:bottsywattsy.FRUS-Explorer category:SearchTiming`.
///
/// Since #1577 lane 6 a third line times a ranking of a held list's whole match, beside the line its search inside the
/// set writes: reading the match's keys, narrowing them, ranking them, and fetching the rows the held list did not hold.
///
/// Version history:
///   1.0 — #1577 lane 1: initial implementation
///   1.1 — #1577 lane 6: ``WholeMatch``, the line for a ranking of a held list's whole match
enum SearchTimingLog {

    /// The log both lines are written to.
    static let logger = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "SearchTiming")

    // MARK: - A Meaning search inside a document set

    /// What `SemanticQuerySearcher.search(_:within:limit:)` spent, by stage.
    struct MeaningInSet: Equatable, Sendable {
        /// Distinct documents in the set.
        let setSize: Int
        /// Of those, the documents the bundled vectors hold a row for.
        let withVector: Int
        /// Volumes whose match file was asked for, on the device or not.
        let volumes: Int
        /// Documents scored.
        let ranked: Int
        /// Encoding the question: the model's load, where it was not resident, and the embedding.
        let encode: Duration
        /// Resolving the set's keys to corpus rows.
        let resolve: Duration
        /// Asking the shard store for each volume's match file, which maps one not yet open.
        let shards: Duration
        /// Exact scoring and the sort.
        let score: Duration
    }

    /// The line for a Meaning search inside a set.
    ///
    /// - Parameter timing: The search's counts and stage durations.
    /// - Returns: The line, such as `meaning-in-set docs=1000 vectors=987 volumes=14 ranked=950
    ///   encode_ms=412.3 resolve_ms=1.2 shards_ms=38.0 score_ms=0.9`.
    static func line(_ timing: MeaningInSet) -> String {
        "meaning-in-set docs=\(timing.setSize) vectors=\(timing.withVector)"
            + " volumes=\(timing.volumes) ranked=\(timing.ranked)"
            + " encode_ms=\(milliseconds(timing.encode))"
            + " resolve_ms=\(milliseconds(timing.resolve))"
            + " shards_ms=\(milliseconds(timing.shards))"
            + " score_ms=\(milliseconds(timing.score))"
    }

    /// Writes the line for a Meaning search inside a set.
    ///
    /// - Parameter timing: The search's counts and stage durations.
    static func record(_ timing: MeaningInSet) {
        let text = line(timing)
        logger.notice("\(text, privacy: .public)")
    }

    // MARK: - A keyword search inside a document set

    /// What a keyword search inside a document set took, as a search view model saw it.
    ///
    /// The rows and the whole-match count are two statements sent to the index at once, and the
    /// index runs one at a time. So ``rows`` is the wait for the rows, which is what a reader
    /// waits for, and it holds the count statement's time too whenever the index took that one
    /// first. It is an upper bound on the row statement alone, never an under-statement.
    struct GatedKeyword: Equatable, Sendable {
        /// Documents in the set the search ran inside.
        let setSize: Int
        /// Rows returned.
        let rowCount: Int
        /// From sending both statements until the rows were in hand.
        let rows: Duration
        /// From sending both statements until the count was in hand as well.
        let total: Duration
    }

    /// The line for a keyword search inside a set.
    ///
    /// - Parameter timing: The search's counts and durations.
    /// - Returns: The line, such as `gated-keyword docs=100 rows=37 rows_ms=812.5 total_ms=901.0`.
    static func line(_ timing: GatedKeyword) -> String {
        "gated-keyword docs=\(timing.setSize) rows=\(timing.rowCount)"
            + " rows_ms=\(milliseconds(timing.rows))"
            + " total_ms=\(milliseconds(timing.total))"
    }

    /// Writes the line for a keyword search inside a set.
    ///
    /// - Parameter timing: The search's counts and durations.
    static func record(_ timing: GatedKeyword) {
        let text = line(timing)
        logger.notice("\(text, privacy: .public)")
    }

    // MARK: - A ranking of a held list's whole match (#1577 lane 6)

    /// What `SemanticSearchBackend.rankWholeMatch(query:base:match:parameters:limit:)` spent, by step. The ranking's
    /// own stages, the question's encoding among them, are in the `meaning-in-set` line it writes beside this one.
    struct WholeMatch: Equatable, Sendable {
        /// Documents the list's whole match holds.
        let matchSize: Int
        /// Of those, the documents ranked inside: less the rows hidden as reviewed, inside a working corpus.
        let setSize: Int
        /// Whether the match's keys were the list's own, kept from an earlier question, so the index was not asked.
        let keysKept: Bool
        /// Ranked documents listed, at most the ceiling.
        let ranked: Int
        /// Of those, the documents whose rows the held list did not hold, fetched again with their snippets.
        let refetched: Int
        /// Rows listed after the filters, the unranked among them.
        let listed: Int
        /// Reading the match's keys from the index (`SearchService.matchKeys(parameters:)`).
        let keys: Duration
        /// Narrowing them to the set, and signing it for the trail.
        let set: Duration
        /// The search inside the set: the encoding, the keys' resolution, the match files and the scoring.
        let rank: Duration
        /// The keyword search run again for the rows the held list did not hold.
        let refetch: Duration
    }

    /// The line for a ranking of a held list's whole match.
    ///
    /// - Parameter timing: The ranking's counts and step durations.
    /// - Returns: The line, such as `whole-match docs=35275 set=35262 kept=0 ranked=1000 refetched=812 listed=1000
    ///   keys_ms=731.0 set_ms=48.2 rank_ms=212.9 refetch_ms=804.4`.
    static func line(_ timing: WholeMatch) -> String {
        "whole-match docs=\(timing.matchSize) set=\(timing.setSize) kept=\(timing.keysKept ? 1 : 0)"
            + " ranked=\(timing.ranked) refetched=\(timing.refetched) listed=\(timing.listed)"
            + " keys_ms=\(milliseconds(timing.keys))"
            + " set_ms=\(milliseconds(timing.set))"
            + " rank_ms=\(milliseconds(timing.rank))"
            + " refetch_ms=\(milliseconds(timing.refetch))"
    }

    /// Writes the line for a ranking of a held list's whole match.
    ///
    /// - Parameter timing: The ranking's counts and step durations.
    static func record(_ timing: WholeMatch) {
        let text = line(timing)
        logger.notice("\(text, privacy: .public)")
    }

    // MARK: - Formatting

    /// A duration in milliseconds to one decimal place, with a full stop whatever the device's
    /// region writes: the line is read by a person and by `grep`, never shown in the app.
    ///
    /// - Parameter duration: The duration.
    /// - Returns: Such as `412.3`.
    static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        let value = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
