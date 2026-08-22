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

// MARK: - TripPacketExporter

/// Renders a ``TripPacketModel`` as the researcher's packet (#830 T-2).
///
/// ## Plain text, deliberately
/// Chapter 2's inquiry draft is an **email a researcher sends to NARA reference staff**, so it has
/// to survive being pasted into a mail client. The whole packet is therefore plain text rather than
/// attributed strings or HTML: one format, no lossy step between what is reviewed and what is sent.
///
/// ## Every chapter can be empty, and none of them lies about it
/// The packet is generated before a trip is booked, from a project that may cite records the app
/// cannot place. So each chapter has a defined behaviour when its input is missing, and none of
/// them is "omit silently": an unplaceable group is reported as needing confirmation, an
/// unconfirmed fact is left out with the surrounding sentence adjusted, and a chapter with nothing
/// in it says so.
///
/// ## What it refuses to print
/// Anything in ``RepositoryFactTable`` without a `verifiedDate`. As of 2026-08-22 that is the NACP
/// appointment policy, every presidential library, and the whole non-NARA tail. The exporter reads
/// `printable` rather than `value`, so this is a property of the data path and not of the copy.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2, chapters 1-3, 5-7
struct TripPacketExporter {

    /// The packet to render.
    let model: TripPacketModel
    /// The project's name, for the cover.
    let projectName: String
    /// The visit date, when the researcher has one (D5).
    let arrival: Date?
    /// Injected so the export is deterministic under test.
    var calendar: Calendar = .current

    /// The whole packet.
    func export() -> String {
        [cover, inquiryDrafts, pullWorksheet, restrictionTriage, citationCrib, visitDayCard]
            .joined(separator: "\n\n")
    }

    // MARK: - Chapter 1: cover and checklist

    /// Cover, counts, and the pre-arrival checklist with its A4 escalation.
    var cover: String {
        var out = ["# Research trip packet: \(projectName)", ""]
        out.append("\(model.groups.count) archival groups · "
                   + "\(model.groups.reduce(0) { $0 + $1.documentCount }) documents")
        if let arrival {
            out.append("Visit: \(arrival.formatted(date: .long, time: .omitted))")
        } else {
            // D5: the packet is most useful BEFORE the trip is booked, so a missing date is a
            // normal state and the checklist below prints relatively.
            out.append("No visit date set — deadlines below are relative to your arrival.")
        }
        out.append("")
        out.append("## Before you go")
        out.append(model.checklist.standingSentence)
        out.append("")
        for item in model.checklist.items {
            out.append("- [ ] " + item.line(arrival: arrival, calendar: calendar))
        }
        if !model.needingConfirmation.isEmpty {
            out.append("")
            let n = model.needingConfirmation.count
            out.append("- [ ] Confirm the location of "
                       + (n == 1 ? "1 collection" : "\(n) collections")
                       + " this packet could not place — see \"Confirm before you travel\".")
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Chapter 2: inquiry drafts

    /// The advance-inquiry draft, plus D11's confirm-prompt for anything unplaceable.
    ///
    /// One draft per facility, because A3 asks for one agency or a group of closely related
    /// agencies per inquiry and A2 requires sending to **only one address**. A packet that produced
    /// a single letter naming three repositories would violate both.
    var inquiryDrafts: String {
        var out = ["## Advance inquiry", ""]

        let placeable = model.groups.filter(\.canHeadChapter)
        if placeable.isEmpty {
            out.append("No group in this packet resolved to a facility, so there is no inquiry to "
                       + "draft. The collections below still need confirming before you travel.")
        }
        for facility in orderedFacilities(in: placeable) {
            let groups = placeable.filter { $0.facility.chapterHeading == facility }
            out.append("### \(facility)")
            if let row = RepositoryFactTable.current.row(for: facility) {
                // Only ever `printable` — an unverified fact is omitted, never printed undated (D7).
                if let email = row.inquiryEmail.printable { out.append("To: \(email)") }
                if let address = row.address.printable { out.append(address) }
                if row.appointmentPolicy.printable == nil {
                    // A1 distinguishes DC-area rooms from other facilities; which applies here is
                    // unconfirmed, so the packet asks rather than asserts.
                    out.append("Check whether this facility requires an appointment before you write.")
                }
            }
            out.append("")
            out.append("Topic: \(model.topicSentence.forExport)")
            out.append("")
            out.append("Records of interest:")
            for group in groups.prefix(12) {
                out.append("  - \(group.label) (\(group.documentCount) documents)")
            }
            if groups.count > 12 {
                out.append("  - …and \(groups.count - 12) further groups, listed in the pull worksheet.")
            }
            out.append("")
        }

        // D11: libraries get A12's actual ask, not a drafted letter. At collection grain the packet
        // can name neither series nor NAID, so a letter would imply a precision the data lacks.
        if !model.needingConfirmation.isEmpty {
            out.append("### Confirm before you travel")
            out.append("These collections could not be placed at a facility from the data this app "
                       + "holds. NARA's own advice is to write, phone or email ahead to confirm the "
                       + "materials are at that location before you travel.")
            out.append("")
            for group in model.needingConfirmation {
                out.append("  - \(group.label) (\(group.documentCount) documents)")
                if case .confirmBeforeTravelling(let named) = group.facility {
                    out.append("    Cited as \(named). Records centres transfer their holdings, so "
                               + "ask staff where these records are now.")
                }
            }
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Chapter 3: pull worksheet

    /// Group → documents, with a blank box column for the reading room.
    ///
    /// `numberingNote` is deliberately absent: D10 dropped it, because the app-reachable count is
    /// **1 of 622** series and the ordering instruction a researcher needs is the
    /// RG / entry / series / box line this worksheet already prints.
    var pullWorksheet: String {
        var out = ["## Pull worksheet", ""]
        if model.groups.isEmpty {
            out.append("No archival groups — this project's documents carry no resolvable source notes.")
            return out.joined(separator: "\n")
        }
        // GROUPED BY FACILITY, and that is not formatting. A worksheet is carried into a reading
        // room and its rows become pull slips; one flat table mixing College Park with a
        // presidential library invites a researcher to request material that is a plane ride away.
        let placeable = model.groups.filter(\.canHeadChapter)
        for facility in orderedFacilities(in: placeable) {
            out.append("### \(facility)")
            out.append("")
            out.append("| Group | Documents | Box |")
            out.append("|---|---:|---|")
            for group in placeable where group.facility.chapterHeading == facility {
                out.append("| \(group.label) | \(group.documentCount) | |")
            }
            out.append("")
        }
        if !model.needingConfirmation.isEmpty {
            out.append("### Location not confirmed")
            out.append("")
            out.append("Do not take these to a reading room until you have confirmed where they are.")
            out.append("")
            out.append("| Group | Documents | Box |")
            out.append("|---|---:|---|")
            for group in model.needingConfirmation {
                out.append("| \(group.label) | \(group.documentCount) | |")
            }
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Chapter 5: restriction triage

    /// What may not be readable, worst first (D4).
    var restrictionTriage: String {
        var out = ["## Access restrictions", ""]
        let triage = model.triage
        if triage.isEmpty {
            out.append("Nothing to report: no cited series and no unplaced documents.")
            return out.joined(separator: "\n")
        }
        let flagged = triage.needingAdvanceContact
        if flagged.isEmpty {
            out.append("Every series this packet cites is recorded as unrestricted. Availability "
                       + "still depends on the records themselves — confirm with staff.")
        } else {
            out.append("\(flagged.count) of \(triage.rows.count) cited series "
                       + (flagged.count == 1 ? "carries" : "carry")
                       + " a restriction or no stated status. A closed series cannot be pulled, so "
                       + "raise these in your inquiry rather than on arrival.")
            out.append("")
            for row in flagged.prefix(20) {
                let status = row.accessStatus ?? "No status recorded"
                out.append("  - NAID \(row.naId) — \(status) (\(row.documentCount) documents)")
                if !row.accessRestrictions.isEmpty {
                    out.append("    \(row.accessRestrictions.joined(separator: "; "))")
                }
            }
        }
        if triage.unresolvedDocumentCount > 0 {
            out.append("")
            let n = triage.unresolvedDocumentCount
            out.append((n == 1 ? "1 document cites" : "\(n) documents cite")
                       + " no series this app could resolve, so nothing is known about "
                       + (n == 1 ? "its" : "their") + " access. Not covered by the list above.")
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Chapter 6: citation crib

    /// NARA's citation guidance, **attributed and not ratified** (D13).
    ///
    /// Citation form is governed by the publisher, and publishers disagree. So the packet reports a
    /// recommendation as NARA's own rather than prescribing one — which is already this app's
    /// posture elsewhere, where `CitationStyle` ships three styles and marks one "Recommended".
    ///
    /// The quotations themselves await the three citation PDFs being deposited at
    /// `Planning/reference/`; until then this chapter prints its frame and says what is missing,
    /// rather than paraphrasing guidance nobody has checked.
    var citationCrib: String {
        [
            "## Citing what you find",
            "",
            "Citation form is governed by your publisher, and publishers disagree. NARA publishes "
                + "its own guidance (General Information Leaflet 17, and \"Citing Foreign Affairs "
                + "Records\"); this packet reports that guidance as NARA's rather than "
                + "prescribing it.",
            "",
            "The worked examples for this packet's own series are not yet included — they quote "
                + "NARA's PDFs, which have not been deposited in this repository, and a paraphrase "
                + "would be exactly the unattributed prescription this chapter avoids.",
        ].joined(separator: "\n")
    }

    // MARK: - Chapter 7: visit-day card

    /// What does not rot (T-0 §3.2).
    ///
    /// Pull times, the 5:15 cutoff, the consultation area's floor and hours and the Wednesday
    /// specialist window are all **negated** — one person's calendar is the fastest-rotting claim
    /// available, and a trip booked around a slot that no longer exists is a trip lost. Two of
    /// A14's four room rules fail A14's own "changes packing or planning" test and are also absent.
    var visitDayCard: String {
        var out = ["## On the day", ""]
        // Day-0 registration is one of the four owner-confirmable facts and is NOT yet confirmed,
        // so it is described as something to check rather than asserted as a requirement.
        out.append("- Check whether you need to register for a researcher ID card on arrival, and "
                   + "allow time for it.")
        out.append("- Lockers are provided; laptops, cameras and flatbed or overhead scanners are "
                   + "allowed. Auto-feed and hand-held scanners and personal copiers are not.")
        out.append("- NARA staff cannot undertake research for you, but a consultation desk and "
                   + "dedicated foreign-affairs reference staff exist — ask at the reference desk.")
        out.append("- Records that are digitised or on microfilm must be used in those forms where "
                   + "they are available.")
        return out.joined(separator: "\n")
    }

    /// Facilities in the order their groups appear, de-duplicated — so the packet's chapter order
    /// follows how much of the reading each facility holds.
    private func orderedFacilities(in groups: [TripPacketModel.Group]) -> [String] {
        var seen = Set<String>()
        return groups.compactMap { $0.facility.chapterHeading }
            .filter { seen.insert($0).inserted }
    }
}
