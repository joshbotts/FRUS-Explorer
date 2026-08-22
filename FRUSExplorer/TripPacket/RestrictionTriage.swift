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

// MARK: - RestrictionSeverity

/// How badly a series' access status affects a planned visit (#830 T-1, decision D4).
///
/// Ordered worst-first, because that is the order the packet prints and the order a researcher
/// needs: a fully restricted series changes whether the trip is worth taking, and an unrestricted
/// one changes nothing.
enum RestrictionSeverity: Int, Comparable, Sendable, CaseIterable {
    /// NARA states the series is closed. 138 of 695 — 19.9%.
    case fully = 0
    /// Some of it is closed.
    case partly = 1
    /// NARA has not ruled it out.
    case possibly = 2
    /// **NARA has said nothing**, which is not the same as saying it is open.
    ///
    /// Kept as its own level rather than folded into ``unrestricted``, because the difference is
    /// exactly the one a researcher would be misled by. The index's vocabulary carries
    /// "Undetermined" and no row uses it today, so in practice this is the *absent* status — a
    /// series the catalogue has not classified, or a citation that never reached a series at all.
    case unknown = 3
    /// NARA states it is open.
    case unrestricted = 4

    static func < (lhs: RestrictionSeverity, rhs: RestrictionSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Classifies NARA's own access-status string.
    ///
    /// Matched on the prefix rather than on equality, because the index's statuses are
    /// `Restricted - Fully` / `- Partly` / `- Possibly` and a punctuation change upstream should
    /// degrade to ``unknown`` rather than silently read as open.
    static func from(accessStatus: String?) -> RestrictionSeverity {
        guard let status = accessStatus?.trimmingCharacters(in: .whitespaces), !status.isEmpty else {
            return .unknown
        }
        if status.hasPrefix("Restricted") {
            if status.contains("Fully")    { return .fully }
            if status.contains("Partly")   { return .partly }
            if status.contains("Possibly") { return .possibly }
            return .partly   // an unrecognised degree of restriction is still a restriction
        }
        if status.hasPrefix("Unrestricted") { return .unrestricted }
        return .unknown
    }

    /// Whether this level should be surfaced before the researcher travels.
    ///
    /// ``unknown`` counts. A series the catalogue cannot classify is precisely the one worth
    /// asking staff about, and omitting it would make the triage's silence look like a clearance.
    var warrantsAdvanceContact: Bool { self != .unrestricted }
}

// MARK: - RestrictionTriage

/// What a researcher should know about access before travelling (#830 T-1, decision D4).
///
/// ## Why this is in the first shipping cut
/// It was scoped into T-3 and D4 moved it forward, and the measurement is the whole argument:
/// **481 of 695 series (69.2%) carry some restriction and 138 (19.9%) are Restricted — Fully.**
/// A researcher who flies to College Park to pull a closed series has lost the trip. The data to
/// warn them shipped with #663/F-7 months ago, and no other page in the packet answers a question
/// that large.
///
/// ## What it does not do
/// It reports NARA's stated status and nothing else. It does not predict whether a pull will
/// succeed, does not interpret a FOIA exemption, and never says a record IS available — the packet's
/// standing rule is that availability language is always "confirm with staff" (A6).
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1, per D4
struct RestrictionTriage: Equatable, Sendable {

    /// One series the planned reading touches.
    struct Row: Equatable, Sendable, Identifiable {
        /// The series NAID.
        let naId: String
        /// NARA's stated access status, verbatim; `nil` when it states none.
        let accessStatus: String?
        /// NARA's stated exemptions, e.g. `FOIA (b)(1) National Security`.
        let accessRestrictions: [String]
        /// How many of the reader's documents cite this series.
        let documentCount: Int
        /// The severity this row sorts and prints by.
        let severity: RestrictionSeverity
        var id: String { naId }
    }

    /// Rows worst-first, then by how much of the reading they affect, then by NAID for a total order.
    let rows: [Row]

    /// Documents whose citation never reached a series, so nothing can be said about their access.
    ///
    /// Reported rather than dropped. A triage that silently covered 40% of a reading list would
    /// read as a clean bill of health for the other 60%.
    let unresolvedDocumentCount: Int

    /// Series the reading touches that warrant contact before travelling.
    var needingAdvanceContact: [Row] { rows.filter(\.severity.warrantsAdvanceContact) }

    /// Whether there is anything to say at all.
    var isEmpty: Bool { rows.isEmpty && unresolvedDocumentCount == 0 }

    /// Builds the triage from the series a reading list cites.
    ///
    /// - Parameters:
    ///   - documentCountsByNaId: series NAID → how many of the reader's documents cite it.
    ///   - unresolvedDocumentCount: documents whose citation reached no series.
    ///   - facts: the series-facts lookup; injected so tests drive the real rule.
    static func build(
        documentCountsByNaId: [String: Int],
        unresolvedDocumentCount: Int,
        facts: (String) -> SeriesFactsIndex.Facts? = { SeriesFactsIndexStore.shared?.facts(forNaId: $0) }
    ) -> RestrictionTriage {
        let rows = documentCountsByNaId.map { naId, count -> Row in
            let f = facts(naId)
            return Row(naId: naId,
                       accessStatus: f?.accessStatus,
                       accessRestrictions: f?.accessRestrictions ?? [],
                       documentCount: count,
                       severity: .from(accessStatus: f?.accessStatus))
        }
        .sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }
            if lhs.documentCount != rhs.documentCount { return lhs.documentCount > rhs.documentCount }
            return lhs.naId < rhs.naId
        }
        return RestrictionTriage(rows: rows, unresolvedDocumentCount: unresolvedDocumentCount)
    }
}
