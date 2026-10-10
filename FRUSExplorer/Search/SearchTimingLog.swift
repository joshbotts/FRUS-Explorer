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
/// Version history:
///   1.0 — #1577 lane 1: initial implementation
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
