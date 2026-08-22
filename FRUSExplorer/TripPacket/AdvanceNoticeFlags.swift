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

// MARK: - AdvanceNoticeFlag

/// One reason NARA asks for extra advance notice, per requirement A4 (#830 T-1, decision D9).
///
/// ## Why only two of A4's three criteria are flags
/// A4 names three: sensitive agencies, records dated 1960s and later, and lot numbers that "do not
/// always carry over". The first fires on **81.4% of source notes** — because FRUS *is* State
/// Department records — and a chip lit on every row carries no information while costing the two
/// informative chips their salience.
///
/// So D9 splits them by what they discriminate. The date test (21.3%) and the unresolved-lot test
/// (43.0% of lot notes, 2.4% of all) vary between projects and are ``AdvanceNoticeFlag``s. The
/// sensitive-agency criterion is true of essentially every project and prints **once**, as
/// ``AdvanceNoticeFlags/standingSentence``. A4's requirement that the packet quote *which* criterion
/// fired is still met either way: the chips quote theirs, and the standing sentence quotes the FAQ's.
enum AdvanceNoticeFlag: String, CaseIterable, Sendable, Equatable {

    /// Records dated 1960 or later. Fires on 21.3% of notes.
    case recentRecords

    /// Lot-file citations the app could not resolve to a series — NARA's own caution that lot
    /// numbers "do not always carry over".
    case unresolvedLotCitations

    /// The criterion this flag quotes, in NARA's words, so the packet never paraphrases the reason
    /// a researcher is being told to write early.
    var quotedCriterion: String {
        switch self {
        case .recentRecords:
            return String(localized: "packet.a4.recent.criterion",
                          defaultValue: "records dated in the 1960s and later")
        case .unresolvedLotCitations:
            return String(localized: "packet.a4.lots.criterion",
                          defaultValue: "lot-file numbers, which do not always carry over")
        }
    }
}

// MARK: - AdvanceNoticeFlags

/// The A4 flag engine: which advance-notice criteria a reading list actually trips (#830 T-1).
///
/// Pure and date-independent — D5 requires the lead-time checklist to work with or without a visit
/// date, and the flags are the same either way.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1, per D9
struct AdvanceNoticeFlags: Equatable, Sendable {

    /// The flags this reading list trips, in stable order.
    let flags: [AdvanceNoticeFlag]
    /// Documents dated 1960 or later.
    let recentDocumentCount: Int
    /// Lot citations that reached no series.
    let unresolvedLotCount: Int

    /// The sensitive-agency criterion, printed once whatever the reading list contains (D9).
    ///
    /// Not conditional, and that is the point: it fires on 81.4% of notes, so a version that
    /// checked would print it almost always while implying the cases where it did not were
    /// somehow exempt. It quotes the FAQ's own list rather than paraphrasing.
    static var standingSentence: String {
        String(localized: "packet.a4.standing",
               defaultValue: "NARA asks for extra advance notice for records of sensitive agencies — \"such as State, Defense, Justice, the FBI, and the intelligence agencies\". Essentially every document in this packet is State Department material, so this applies throughout.")
    }

    /// The earliest document year that counts as "recent" for A4. NARA's wording is "the 1960s and
    /// later", so the boundary is the decade's first year.
    static let recentRecordsThreshold = 1960

    /// Computes the flags for a reading list.
    ///
    /// - Parameters:
    ///   - documentYears: each document's year, where known. A document with no year cannot trip
    ///     the date test and is not counted — an unknown date is not a recent one.
    ///   - unresolvedLotCount: lot citations that reached no series.
    static func evaluate(documentYears: [Int?], unresolvedLotCount: Int) -> AdvanceNoticeFlags {
        let recent = documentYears.compactMap { $0 }.filter { $0 >= recentRecordsThreshold }.count
        var flags: [AdvanceNoticeFlag] = []
        if recent > 0 { flags.append(.recentRecords) }
        if unresolvedLotCount > 0 { flags.append(.unresolvedLotCitations) }
        return AdvanceNoticeFlags(flags: flags,
                                  recentDocumentCount: recent,
                                  unresolvedLotCount: unresolvedLotCount)
    }
}
