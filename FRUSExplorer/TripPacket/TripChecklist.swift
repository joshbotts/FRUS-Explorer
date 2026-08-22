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

// MARK: - TripChecklistItem

/// One dated thing a researcher must do before arriving (#830 T-1, decision D5).
struct TripChecklistItem: Equatable, Sendable, Identifiable {

    /// A stable identity for the row, independent of how it is worded.
    let id: String
    /// What to do.
    let action: String
    /// How far ahead, in days. Negative means before arrival.
    let leadDays: Int
    /// The A4 criterion that escalated this row, when one did.
    let escalatedBy: AdvanceNoticeFlag?

    /// The row as printed, in whichever of D5's two forms applies.
    ///
    /// - Parameter arrival: the visit date, when the researcher has one.
    /// - Parameter calendar: injected so the test does not depend on the machine's locale.
    func line(arrival: Date?, calendar: Calendar = .current) -> String {
        guard let arrival,
              let by = calendar.date(byAdding: .day, value: -leadDays, to: arrival) else {
            return String(format: String(localized: "packet.checklist.relative %@ %lld",
                                         defaultValue: "%@ — at least %lld days before you arrive"),
                          action, Int64(leadDays))
        }
        return String(format: String(localized: "packet.checklist.absolute %@ %@",
                                     defaultValue: "%@ — by %@"),
                      action, by.formatted(date: .abbreviated, time: .omitted))
    }
}

// MARK: - TripChecklist

/// The pre-arrival checklist, in D5's two forms.
///
/// ## Why the visit date is optional
/// A packet is most useful **before** the trip is booked, so requiring a date would gate the packet
/// on the decision the packet exists to inform. With a date the rows print absolutely ("by 12
/// September"); without one they print the same rows relatively ("at least 28 days before you
/// arrive"). The rows themselves — and the A4 escalation that produces them — are identical, which
/// is what makes this a presentation choice rather than two features.
///
/// ## What is not here
/// No institutional facts. Every lead time below comes from the plan's own requirements table
/// (A1–A9), not from a claim about a particular facility's hours, address or appointment policy —
/// those are the four owner-confirmable facts T-1 may not print. A row that would need one is
/// absent rather than approximated.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1, per D5 and D9
struct TripChecklist: Equatable, Sendable {

    /// The rows, soonest-deadline last (so the most urgent lead time reads first).
    let items: [TripChecklistItem]
    /// The standing sentence D9 requires, printed once above the rows.
    let standingSentence: String = AdvanceNoticeFlags.standingSentence

    /// Builds the checklist for a reading list's flags.
    ///
    /// - Parameter flags: the A4 evaluation, which escalates two of the rows.
    static func build(flags: AdvanceNoticeFlags) -> TripChecklist {
        var items: [TripChecklistItem] = [
            // A2: a reference inquiry is part of appointment scheduling outside DC and is strongly
            // encouraged for the DC-area rooms. Four weeks is the plan's own baseline.
            TripChecklistItem(
                id: "inquiry",
                action: String(localized: "packet.checklist.inquiry",
                               defaultValue: "Send your reference inquiry — to one address only"),
                leadDays: 28, escalatedBy: nil),
            // A1: appointments are strongly encouraged in the DC area and REQUIRED elsewhere. The
            // row does not say which applies, because that is per-facility policy and is one of the
            // four facts the owner has not confirmed.
            TripChecklistItem(
                id: "appointment",
                action: String(localized: "packet.checklist.appointment",
                               defaultValue: "Book your appointment, and confirm whether this facility requires one"),
                leadDays: 14, escalatedBy: nil),
        ]

        // A4 escalations: the two criteria that discriminate (D9). Each row quotes the criterion
        // that produced it, so a researcher can see why they are being told to write earlier.
        if flags.flags.contains(.recentRecords) {
            items.append(TripChecklistItem(
                id: "a4.recent",
                action: String(format: String(
                    localized: "packet.checklist.a4.recent %lld",
                    defaultValue: "Write earlier: %lld of your documents are dated 1960 or later, and NARA asks for extra notice for records dated in the 1960s and later"),
                    Int64(flags.recentDocumentCount)),
                leadDays: 42, escalatedBy: .recentRecords))
        }
        if flags.flags.contains(.unresolvedLotCitations) {
            items.append(TripChecklistItem(
                id: "a4.lots",
                action: String(format: String(
                    localized: "packet.checklist.a4.lots %lld",
                    defaultValue: "Write earlier: %lld lot citations could not be resolved to a series, and NARA cautions that lot-file numbers do not always carry over"),
                    Int64(flags.unresolvedLotCount)),
                leadDays: 42, escalatedBy: .unresolvedLotCitations))
        }

        // Longest lead time first: the thing that must happen soonest is the thing to read first.
        return TripChecklist(items: items.sorted {
            $0.leadDays != $1.leadDays ? $0.leadDays > $1.leadDays : $0.id < $1.id
        })
    }
}
