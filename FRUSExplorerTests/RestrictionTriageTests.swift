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

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - RestrictionTriageTests

/// Pins the trip packet's restriction triage (#830 T-1, decision D4).
///
/// D4 promoted this out of T-3 and into the first shipping cut on one measurement: **481 of 695
/// series are restricted to some degree and 138 are Restricted — Fully.** A researcher who flies to
/// College Park to pull a closed series has lost the trip.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
@Suite("Restriction triage (#830 T-1)")
struct RestrictionTriageTests {

    /// D4's measurement, checked against the shipped artifact rather than quoted from the plan. If
    /// this ever falls away, the argument for promoting the triage falls with it.
    @MainActor
    @Test("The restriction rates D4 rests on still hold")
    func restrictionRatesStillHold() throws {
        let index = try #require(SeriesFactsIndexStore.shared,
                                 "series-facts-index.json must decode from the app bundle")
        var counts: [RestrictionSeverity: Int] = [:]
        for naId in index.byNaId.keys {
            let severity = RestrictionSeverity.from(accessStatus: index.facts(forNaId: naId)?.accessStatus)
            counts[severity, default: 0] += 1
        }
        let total = counts.values.reduce(0, +)
        let restricted = (counts[.fully] ?? 0) + (counts[.partly] ?? 0) + (counts[.possibly] ?? 0)
        #expect(total > 600, "expected the ~695-series index; got \(total)")
        #expect(counts[.fully] ?? 0 >= 100, """
            Only \(counts[.fully] ?? 0) series are Restricted — Fully. Measured at 138 (19.9%) when \
            D4 promoted this into the first cut; a large fall would be worth re-reading that decision.
            """)
        #expect(Double(restricted) / Double(total) > 0.5, """
            \(restricted) of \(total) series are restricted. D4's argument is that this is the \
            largest unanswered question in the packet.
            """)
    }

    /// Worst-first is the whole point of the ordering: the row that changes whether the trip is
    /// worth taking must not be below one that changes nothing.
    @Test("Rows sort worst-first, then by how much of the reading they affect")
    func rowsSortWorstFirst() {
        let statuses = ["a": "Unrestricted", "b": "Restricted - Possibly",
                        "c": "Restricted - Fully", "d": "Restricted - Partly", "e": nil]
        let triage = RestrictionTriage.build(
            documentCountsByNaId: ["a": 50, "b": 5, "c": 1, "d": 9, "e": 3],
            unresolvedDocumentCount: 0,
            facts: { naId in
                SeriesFactsIndex.Facts(accessStatus: statuses[naId] ?? nil, accessRestrictions: [],
                                       useStatus: nil, useRestrictions: [], extent: nil,
                                       referenceUnit: nil, findingAids: [], years: nil)
            })
        #expect(triage.rows.map(\.naId) == ["c", "d", "b", "e", "a"], """
            Got \(triage.rows.map(\.naId)). A fully-restricted series citing ONE document must \
            outrank an unrestricted series citing fifty — severity first, volume second.
            """)
    }

    /// Ties on severity break by reach, so the biggest problem leads.
    @Test("Equal severity sorts by how many documents it affects")
    func tiesBreakByReach() {
        let triage = RestrictionTriage.build(
            documentCountsByNaId: ["x": 2, "y": 40, "z": 9],
            unresolvedDocumentCount: 0,
            facts: { _ in
                SeriesFactsIndex.Facts(accessStatus: "Restricted - Fully", accessRestrictions: [],
                                       useStatus: nil, useRestrictions: [], extent: nil,
                                       referenceUnit: nil, findingAids: [], years: nil)
            })
        #expect(triage.rows.map(\.naId) == ["y", "z", "x"])
    }

    /// **The distinction that would mislead a researcher.** No stated status is not a clearance.
    @Test("An absent status is unknown, never unrestricted")
    func absentStatusIsNotAClearance() {
        #expect(RestrictionSeverity.from(accessStatus: nil) == .unknown)
        #expect(RestrictionSeverity.from(accessStatus: "") == .unknown)
        #expect(RestrictionSeverity.from(accessStatus: "  ") == .unknown)
        #expect(RestrictionSeverity.unknown.warrantsAdvanceContact, """
            A series NARA has not classified is exactly the one worth asking staff about. Treating \
            it as clear would make the triage's silence look like a clearance.
            """)
        #expect(!RestrictionSeverity.unrestricted.warrantsAdvanceContact)
    }

    /// An unrecognised degree of restriction is still a restriction — it must not degrade to open.
    @Test("An unfamiliar restriction wording degrades safely")
    func unfamiliarWordingDegradesSafely() {
        #expect(RestrictionSeverity.from(accessStatus: "Restricted — Somewhat") == .partly, """
            An unrecognised degree of restriction must stay restricted. If upstream changes its \
            punctuation, the failure has to be a too-cautious warning, never a missing one.
            """)
        #expect(RestrictionSeverity.from(accessStatus: "Undetermined") == .unknown)
    }

    /// Documents whose citation reached no series must be reported, not dropped.
    @Test("Unresolved documents are counted rather than hidden")
    func unresolvedDocumentsAreReported() {
        let triage = RestrictionTriage.build(
            documentCountsByNaId: [:], unresolvedDocumentCount: 120, facts: { _ in nil })
        #expect(triage.rows.isEmpty)
        #expect(triage.unresolvedDocumentCount == 120)
        #expect(!triage.isEmpty, """
            A triage covering nothing but 120 unplaced documents must not report itself as empty — \
            silence there reads as a clean bill of health for a reading list nobody checked.
            """)
    }

    /// Only the rows worth acting on reach the advance-contact list.
    @Test("Advance contact covers everything except a stated clearance")
    func advanceContactCoversEverythingButClearance() {
        let statuses = ["open": "Unrestricted", "closed": "Restricted - Fully", "silent": nil]
        let triage = RestrictionTriage.build(
            documentCountsByNaId: ["open": 1, "closed": 1, "silent": 1],
            unresolvedDocumentCount: 0,
            facts: { naId in
                SeriesFactsIndex.Facts(accessStatus: statuses[naId] ?? nil, accessRestrictions: [],
                                       useStatus: nil, useRestrictions: [], extent: nil,
                                       referenceUnit: nil, findingAids: [], years: nil)
            })
        #expect(Set(triage.needingAdvanceContact.map(\.naId)) == ["closed", "silent"])
    }
}
