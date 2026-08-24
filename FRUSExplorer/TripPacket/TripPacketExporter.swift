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
/// (The PDF share renders THIS string paginated — same content, never a second composition.)
///
/// ## English, deliberately — the packet's language policy (#830)
/// Every string in this type is a raw literal, and that is a decision rather than a gap. The
/// packet is a document addressed to United States archives: chapter 2 is an email to NARA
/// reference staff, chapters 4 and 6 quote NARA's own English guidance verbatim (an attributed
/// quotation must not be translated), and the checklist quotes the research-visit FAQ. A
/// localized packet would send NARA a letter in the researcher's UI language and translate
/// quotations out of their attributability — so the EXPORTED document stays English by design,
/// like `HTMLCollectionExporter`'s content, while everything the app itself shows around it
/// (`TripPacketSheet`, the entry points) is localized as usual.
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
///   1.1 — Session 2026-08-22: #830 T-3, chapter 4 (mandatory substitutes, A6)
///   1.2 — Session 2026-08-23: #830 — the data-starved chapters get their data: chapter 2
///          prints A3's four-field records line and A5's verbatim unresolved notes, chapter 3
///          gains the per-document roster (FRUS citation · file/folder · blank Box), chapter 5
///          names its series, discloses its truncation and carries A10's withdrawal-notice/
///          FOIA/MDR explainer, and chapter 6 prints the worked examples transcribed from the
///          deposited "Citing Foreign Affairs Records" (D13/D17), pre-filled from the packet
struct TripPacketExporter {

    /// The packet to render.
    let model: TripPacketModel
    /// The project's name, for the cover.
    let projectName: String
    /// The visit date, when the researcher has one (D5).
    let arrival: Date?
    /// Injected so the export is deterministic under test.
    var calendar: Calendar = .current
    /// The curated repository facts, injected so tests drive the real table rather than a mirror.
    ///
    /// **Two lookups, because the packet genuinely has two key spaces.** A facility section is
    /// headed by a place (`National Archives at College Park`) and looks its row up here; a library
    /// in the confirm-prompt is a REPOSITORY the corpus cites, and reads the row the model already
    /// resolved onto its group. Neither can serve the other: `Department of State` folds to itself,
    /// not to a NARA facility, so a group-keyed lookup would never reach the College Park row.
    var factTable: RepositoryFactTable = .current

    /// The whole packet.
    func export() -> String {
        [cover, inquiryDrafts, pullWorksheet, mandatorySubstitutes, restrictionTriage,
         citationCrib, visitDayCard]
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
            if let row = factTable.row(for: facility) {
                // Only ever `printable` — an unverified fact is omitted, never printed undated (D7).
                if let email = row.inquiryEmail.printable { out.append("To: \(email)") }
                if let address = row.address.printable { out.append(address) }
                // Everything from here to "Topic:" is the DRAFT'S letterhead — a researcher pastes
                // from "Topic:" down into an email. Notes addressed to the researcher rather than
                // to NARA therefore go under an explicit label, or a link meant for the sender
                // reads as something they were supposed to send.
                var notes: [String] = []
                if let policy = row.appointmentPolicy.printable {
                    notes.append("Appointments: \(policy)")
                } else if !row.links.isEmpty {
                    // D15: the policy is IN FLUX, so it was negated into a link rather than left
                    // pending. A sentence that rots between the packet being printed and the trip
                    // being taken is worse than a pointer to the page that always says the truth.
                    notes.append("Appointment policy changes — check NARA's current guidance.")
                }
                notes.append(contentsOf: Self.linkLines(row.links))
                if !notes.isEmpty {
                    out.append("")
                    out.append("Before you write:")
                    for note in notes { out.append("  \(note)") }
                }
            }
            out.append("")
            out.append("Topic: \(model.topicSentence.forExport)")
            out.append("")
            out.append("Records of interest:")
            for group in groups.prefix(12) {
                out.append("  - \(group.label) (\(group.documentCount) documents)")
                // A3's four fields — RG · entry · series title · NAID — in NARA's own
                // format, with the catalog link, whenever the citation resolved. This is
                // what the effective-inquiry spec asks the records be identified by.
                if let line = group.recordsLine {
                    out.append("    \(line)")
                    if let url = group.resolution?.catalogURL { out.append("    \(url)") }
                }
            }
            if groups.count > 12 {
                out.append("  - …and \(groups.count - 12) further groups, listed in the pull worksheet.")
            }
            // A5: every source note whose citation reached no NARA series appears VERBATIM,
            // with its FRUS citation, as a help-me-locate item — because NARA's own FAQ
            // says resolving poorly-described records "cannot be done effectively on an ad
            // hoc basis while researchers wait in a research room", and the lot numbers
            // FRUS prints "do not always carry over into use by the National Archives"
            // (both quoted from the deposited research-visit FAQ). The consultation desk
            // is the day-of fallback; this is the advance route.
            let unresolved = groups.filter { $0.category == .lotFile && $0.resolution == nil }
            if !unresolved.isEmpty {
                out.append("")
                out.append("Please help me locate the following. FRUS cites them as printed "
                           + "below; this file designation may be one that did not carry over "
                           + "into use by the National Archives:")
                for group in unresolved {
                    out.append("  - \(group.label) (\(group.documentCount) documents)")
                    for document in group.documents.prefix(Self.unresolvedNoteLimit) {
                        out.append("      \(document.citation)")
                        out.append("      Cited as: \(document.sourceNote)")
                    }
                    // Disclose a truncation rather than trailing off — the reader is
                    // pasting this into an email and must know the list is partial.
                    if group.documents.count > Self.unresolvedNoteLimit {
                        let n = group.documents.count - Self.unresolvedNoteLimit
                        out.append("      …and \(n) further "
                                   + (n == 1 ? "citation" : "citations")
                                   + " from the same file, listed in the pull worksheet.")
                    }
                }
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
                // D11's other half: the ask, beside the page that answers it. `facts` is the row
                // the MODEL resolved for this group's repository — the one lookup that reaches a
                // library, since a library never resolves to a facility heading (D3) and so never
                // reaches the facility-keyed lookup above.
                if let row = group.facts {
                    for line in Self.linkLines(row.links) { out.append("    \(line)") }
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
        // A6 asks substitutes to lead. The chapter numbering puts them after this table, so the
        // table defers to them explicitly — and generally rather than per row, because a substitute
        // is range-grain and a worksheet row is group-grain, so naming the affected rows here would
        // assert a correspondence the data does not support.
        if !model.substitutes.isEmpty {
            out.append("Some of these records are digitized or on film and must be read that way — "
                       + "see \"Use these instead of pulling\" before writing slips.")
            out.append("")
        }
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
            for group in placeable where group.facility.chapterHeading == facility {
                out.append("")
                out.append("**\(group.label)** (\(group.documentCount) documents)")
                // The scope's series line: title · entry · NAID → Catalog link · dates —
                // the same composed A3 line the inquiry prints, so the two chapters cannot
                // disagree about how a series is identified.
                if let line = group.recordsLine {
                    out.append("\(line)")
                    if let url = group.resolution?.catalogURL { out.append("\(url)") }
                }
                out.append("")
                // The per-document roster: FRUS citation · the file/folder designation the
                // note cites · a blank Box column for the reading room. The box is blank by
                // design — the packet never fabricates a box number; boxes are assigned at
                // the pull desk from NARA's own finding aids.
                out.append("| FRUS citation | File / folder | Box |")
                out.append("|---|---|---|")
                for document in group.documents {
                    out.append("| \(document.citation) | \(document.fileDesignation ?? "") | |")
                }
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

    // MARK: - Chapter 4: mandatory substitutes

    /// Records NARA requires be read online or on film rather than pulled (A6).
    ///
    /// The rule is quoted and attributed, not paraphrased: it is an obligation the reading room
    /// enforces, so a pull slip written against a filmed record is a slip that gets declined. That
    /// is why this chapter sits before the access triage rather than reading as a convenience list.
    ///
    /// **The coverage sentence is not boilerplate and always prints**, including — especially — when
    /// the chapter is empty. The app sees two routes, both narrow (digitised decimal ranges reach
    /// 2.9% of decimal citations, concentrated in the WWI file; the M862 rolls reach 1906–1910
    /// only). An empty chapter with no caveat would read as a clearance to pull everything, which
    /// is the exact error A6 exists to prevent.
    var mandatorySubstitutes: String {
        var out = ["## Use these instead of pulling", ""]
        out.append("NARA's research-visit guidance states the rule as an obligation: "
                   + "\"Researchers must use microfilm and online resources when those options are "
                   + "available.\"")
        out.append("")

        let substitutes = model.substitutes
        if substitutes.isEmpty {
            out.append(substitutes.coverageNote)
            return out.joined(separator: "\n")
        }

        let rows = substitutes.rows
        let shown = rows.prefix(Self.substituteRowLimit)
        for row in shown {
            var line = "  - \(row.title) — \(row.documentCount) "
                + (row.documentCount == 1 ? "document" : "documents")
                + " (\(row.route.label), NAID \(row.naId)"
            if row.objectCount > 0 { line += ", \(row.objectCount) images" }
            line += ")"
            out.append(line)
            if let url = row.catalogURL { out.append("    \(url.absoluteString)") }
            if !row.isSoleClaimant {
                out.append("    More than one digitized unit claims these documents — NARA's "
                           + "digitization is layered, so check this one covers yours.")
            }
        }
        // Disclose a truncation rather than trailing off. A list that silently stopped would read
        // as complete, and the reader would pull the records it did not mention.
        if rows.count > shown.count {
            out.append("")
            out.append("\(rows.count - shown.count) further "
                       + (rows.count - shown.count == 1 ? "unit is" : "units are")
                       + " not listed here; the full set is in Source Explorer.")
        }
        out.append("")
        out.append(substitutes.coverageNote)
        out.append("")
        // From NARA's "Citing Foreign Affairs Records": the substitute changes the citation, and a
        // reader who only records the URL cannot reconstruct the reference.
        out.append("When you cite one of these, NARA's guidance asks for the microfilm publication "
                   + "number, and for online records \"the elements noted above, not just the URL\".")
        return out.joined(separator: "\n")
    }

    /// How many substitute rows print before the chapter discloses a remainder.
    private static let substituteRowLimit = 20

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
            let shown = flagged.prefix(Self.triageRowLimit)
            for row in shown {
                let status = row.accessStatus ?? "No status recorded"
                // The series NAME leads when the resolution carried one — a bare NAID is a
                // number the reader cannot act on; the NAID rides along for the pull slip.
                let name = row.seriesTitle.map { "\($0) — NAID \(row.naId)" } ?? "NAID \(row.naId)"
                out.append("  - \(name) — \(status) (\(row.documentCount) documents)")
                if !row.accessRestrictions.isEmpty {
                    out.append("    \(row.accessRestrictions.joined(separator: "; "))")
                }
            }
            // Disclose a truncation rather than trailing off (the chapter-4 rule). The
            // dropped tail here would be CLOSED SERIES on a large project — precisely what
            // this chapter exists to surface before someone books a flight.
            if flagged.count > shown.count {
                out.append("")
                let n = flagged.count - shown.count
                out.append("\(n) further flagged "
                           + (n == 1 ? "series is" : "series are")
                           + " not listed here. Every cited series' status is on its NARA "
                           + "catalog page; raise the full set in your inquiry.")
            }
        }
        if triage.unresolvedDocumentCount > 0 {
            out.append("")
            let n = triage.unresolvedDocumentCount
            out.append((n == 1 ? "1 document cites" : "\(n) documents cite")
                       + " no series this app could resolve, so nothing is known about "
                       + (n == 1 ? "its" : "their") + " access. Not covered by the list above.")
        }
        // A10's second half: what the slip of paper where a document used to be MEANS, and
        // that a remedy exists. Explanatory rather than procedural — it names no time or
        // place, so it rots slowly (the T-0 walkthrough's reason for keeping it) — and it
        // matters before the trip: with restricted series in the reading list, the reader
        // should know the remedy exists before deciding the trip is worth taking.
        out.append("")
        out.append("If a folder you pull holds a withdrawal notice where a document should be, "
                   + "the document was removed as classified or otherwise restricted — it is "
                   + "not lost. The notice identifies what was withdrawn, and you can request "
                   + "a declassification review of it under FOIA or through Mandatory "
                   + "Declassification Review (MDR); ask the reference desk how to file either. "
                   + "Copies of previously classified documents may carry declassification "
                   + "stamps — record them, since they are part of the document's history.")
        return out.joined(separator: "\n")
    }

    /// How many flagged triage rows print before the chapter discloses a remainder.
    private static let triageRowLimit = 20

    /// How many verbatim unresolved citations print per group in the inquiry's
    /// help-me-locate list before it defers to the pull worksheet.
    private static let unresolvedNoteLimit = 8

    // MARK: - Chapter 6: citation crib

    /// NARA's citation guidance, **attributed and not ratified** (D13).
    ///
    /// Citation form is governed by the publisher, and publishers disagree. So the packet reports a
    /// recommendation as NARA's own rather than prescribing one — which is already this app's
    /// posture elsewhere, where `CitationStyle` ships three styles and marks one "Recommended".
    ///
    /// ## The worked examples are TRANSCRIPTIONS, and that is the verification story
    /// Every quoted form below is transcribed from NARA Research Services' *Citing Foreign
    /// Affairs Records* (September 2023), deposited at
    /// `Planning/reference/nara-citing-foreign-affairs-records-2023-09.md` (D17 — the
    /// governing guidance for these records; GIL 17 is optional background). Checking this
    /// chapter is a transcription check against that file, never a judgement call — which is
    /// exactly the tier T-0 §3.5 moved it into. A packet series type with no transcribed
    /// example gets the pointer to the guidance, not a paraphrase.
    ///
    /// The pre-fill under each quotation substitutes only what the packet KNOWS (the file
    /// number, the series title, the entry, the record group); everything read off the
    /// physical document — correspondents, type, date — stays as a marked placeholder.
    var citationCrib: String {
        var out = [
            "## Citing what you find",
            "",
            "Citation form is governed by your publisher, and publishers disagree. NARA publishes "
                + "its own guidance (\"Citing Foreign Affairs Records\", Research Services, "
                + "September 2023, and General Information Leaflet 17); this packet reports that "
                + "guidance as NARA's rather than prescribing it.",
        ]
        let examples = cribExamples
        if examples.isEmpty {
            out.append("")
            out.append("None of this packet's series types is among the worked examples NARA's "
                       + "guidance illustrates; consult the guidance itself for your records.")
        }
        for example in examples {
            out.append("")
            out.append("### \(example.heading)")
            out.append("")
            out.append("NARA's \"Citing Foreign Affairs Records\" gives this form"
                       + (example.naraContext.isEmpty ? ":" : " (\(example.naraContext)):"))
            out.append("")
            for line in example.quotedForm { out.append("> \(line)") }
            if !example.prefill.isEmpty {
                out.append("")
                out.append("For this packet's own documents — fill ⟨…⟩ from the document in "
                           + "front of you:")
                for line in example.prefill { out.append("  \(line)") }
            }
        }
        out.append("")
        out.append("NARA's guidance also asks that a first citation carry the full series title "
                   + "and record group, that central-file citations carry NO box number, and that "
                   + "citations to online records \"include the elements noted above, not just "
                   + "the URL\".")
        return out.joined(separator: "\n")
    }

    /// One worked example the crib prints.
    struct CribExample {
        /// The section heading naming the series type.
        let heading: String
        /// Which of NARA's examples this is, for the attribution sentence.
        let naraContext: String
        /// NARA's long and short forms, transcribed VERBATIM from the deposited guidance.
        let quotedForm: [String]
        /// The template instantiated with the packet's own fields, placeholders for the rest.
        let prefill: [String]
    }

    /// The examples matching this packet's series types, decimal first.
    ///
    /// Selection is by the FORM of the packet's own file designations, not by era fields:
    /// a dotted number (`611.93/12-854`) is a Central Decimal File citation and a
    /// letter-led designator (`POL 17-3 JORDAN`) is a Subject-Numeric one, whatever year
    /// the document carries — the same by-the-number rule the catalog client documents.
    var cribExamples: [CribExample] {
        var out: [CribExample] = []
        let centralGroups = model.groups.filter {
            $0.category == .centralDecimalFile || $0.category == .centralForeignPolicyFile
        }
        let designations = centralGroups.flatMap(\.documents).compactMap(\.fileDesignation)

        // Decimal: date-form suffixes (`/12-854`) get NARA's Example 5; consecutive
        // numbering gets Example 2. One example, chosen by what the packet actually holds.
        if let decimal = designations.first(where: { $0.first?.isNumber == true }) {
            let dateForm = DecimalFileSegment.suffixYear(from: decimal) != nil
            let band = DecimalFileSegment.segment(for: decimal, fallbackYear: nil)
                .map { "\($0) " } ?? ""
            out.append(CribExample(
                heading: "Central Decimal File",
                naraContext: dateForm
                    ? "Example 5, telegram with date numbering"
                    : "Example 2, telegram with consecutive numbering",
                quotedForm: dateForm ? Self.naraExample5 : Self.naraExample2,
                prefill: [
                    "⟨Sender⟩ to ⟨recipient⟩, ⟨Type and number⟩, ⟨date⟩, file \(decimal), "
                        + "\(band)Central Decimal File, RG 59: General Records of the "
                        + "Department of State, U.S. National Archives.",
                ]))
        }

        if let subjectNumeric = designations.first(where: { $0.first?.isLetter == true }) {
            out.append(CribExample(
                heading: "Subject-Numeric File",
                naraContext: "Example 7, airgram",
                quotedForm: Self.naraExample7,
                prefill: [
                    "⟨Sender⟩ to ⟨recipient⟩, ⟨Type and number⟩, ⟨date⟩, file \(subjectNumeric), "
                        + "⟨years⟩ Subject-Numeric File, RG 59: General Records of the "
                        + "Department of State, U.S. National Archives.",
                ]))
        }

        // Lot files and every other non-central entry: NARA's own note says Example 8 "also
        // serves as a model that can be followed for all other records entries other than
        // those of the Department of State central files". Pre-filled from the first
        // RESOLVED lot — series title, entry, record group — when the packet has one.
        let lotGroups = model.groups.filter { $0.category == .lotFile }
        if !lotGroups.isEmpty {
            var prefill = ["⟨Sender⟩ to ⟨recipient⟩, ⟨Type⟩, ⟨date⟩, file ⟨folder title⟩, "
                           + "⟨series title⟩, Entry ⟨entry number⟩, RG ⟨record group⟩: "
                           + "⟨record group title⟩, U.S. National Archives."]
            if let resolved = lotGroups.first(where: { $0.resolution != nil }),
               let resolution = resolved.resolution {
                let entries = resolution.seriesHmsMlrEntryNumbers ?? resolution.hmsMlrEntryNumbers
                prefill.append("For \(resolved.label): "
                    + "⟨Sender⟩ to ⟨recipient⟩, ⟨Type⟩, ⟨date⟩, file ⟨folder title⟩, "
                    + (resolution.displaySeriesTitle ?? resolution.title)
                    + (entries?.first.map { ", Entry \($0)" } ?? "")
                    + (resolution.recordGroup.map { ", RG \($0)" } ?? "")
                    + ", U.S. National Archives.")
            }
            out.append(CribExample(
                heading: "Lot files and other records entries",
                naraContext: "Example 8, which NARA notes \"also serves as a model that can be "
                    + "followed for all other records entries other than those of the Department "
                    + "of State central files\"",
                quotedForm: Self.naraExample8,
                prefill: prefill))
        }
        return out
    }

    // MARK: NARA's transcribed forms (verify against
    // Planning/reference/nara-citing-foreign-affairs-records-2023-09.md — a transcription
    // check, per T-0 §3.5; these strings must match the deposit character for character).

    static let naraExample2 = [
        "(long) U.S. Embassy Germany to Department of State, Telegram 507, June 17, 1939, file "
            + "840.48 REFUGEES/1677, 1930-39 Central Decimal File, RG 59: General Records of the "
            + "Department of State, U.S. National Archives. Available on National Archives "
            + "Microfilm Publication M1284.",
        "(short) Germany to State, Telegram 507, June 17, 1939, 840.48 REFUGEES/1677, 1930-39 "
            + "CDF, RG 59, USNA. M1284.",
    ]

    static let naraExample5 = [
        "(long) U.S. Embassy Great Britain to Department of State, Telegram 2684, December 8, "
            + "1954, file 611.93/12-854, 1950-54 Central Decimal File, RG 59: General Records of "
            + "the Department of State, U.S. National Archives.",
        "(short) Great Britain to State, Telegram 2684, December 8, 1954, 611.93/12-854, 1950-54 "
            + "CDF, RG 59, USNA.",
    ]

    static let naraExample7 = [
        "(long) U.S. Embassy Jordan to Department of State, Airgram A-477, April 19, 1965, file "
            + "POL 17-3 JORDAN, 1964-66 Subject-Numeric File, RG 59: General Records of the "
            + "Department of State, U.S. National Archives.",
        "(short) Jordan to State, Airgram A-477, April 19, 1965, POL 17-3 JORDAN, 1964-66 SNF, "
            + "RG 59, USNA.",
    ]

    static let naraExample8 = [
        "(long) CU/AP (Rodis) to CU (McLaughlin), Memorandum, November 5, 1965, file Sports "
            + "General, Interagency Youth Committee General Records, Entry P-5, RG 353: Records "
            + "of Inter- and Intra-department Committee, U.S. National Archives.",
        "(short) CU/AP to CU, November 5, 1965, Sports General, IAYC General Records, Entry P-5, "
            + "RG 353, USNA.",
    ]

    // MARK: - Chapter 7: visit-day card

    /// What does not rot (T-0 §3.2).
    ///
    /// Pull times, the 5:15 cutoff, the consultation area's floor and hours and the Wednesday
    /// specialist window are all **negated** — one person's calendar is the fastest-rotting claim
    /// available, and a trip booked around a slot that no longer exists is a trip lost. Two of
    /// A14's four room rules fail A14's own "changes packing or planning" test and are also absent.
    var visitDayCard: String {
        var out = ["## On the day", ""]
        // Day-0 registration: CONFIRMED by the owner 2026-08-22, so it is asserted rather than
        // hedged. The rider is the useful half — the card itself must be collected in person, but
        // much of the process can be finished beforehand, which changes how long day 0 takes.
        out.append("- A researcher ID card must be obtained in person when you arrive. Several of "
                   + "the steps can be completed in advance — do them before you travel, and allow "
                   + "time on arrival for the rest.")
        out.append("- Lockers are provided; laptops, cameras and flatbed or overhead scanners are "
                   + "allowed. Auto-feed and hand-held scanners and personal copiers are not.")
        out.append("- NARA staff cannot undertake research for you, but a consultation desk and "
                   + "dedicated foreign-affairs reference staff exist — ask at the reference desk.")
        out.append("- Records that are digitized or on microfilm must be used in those forms where "
                   + "they are available.")
        // The pages that answer what this card deliberately does not assert (T-0 §3.2: pull times,
        // the 5:15 cutoff, the consultation area's hours and the Wednesday specialist window are
        // all negated as printed facts precisely because they rot).
        let links = Self.linkLines(factTable.row(for: ResearchFacilityResolver.collegePark)?.links ?? [])
        if !links.isEmpty {
            out.append("")
            out.append("Hours, pull schedules and room rules change. Check before you travel:")
            for line in links { out.append("- \(line)") }
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Links

    /// Renders a row's links, worst-freshness rule applied per link (D12).
    ///
    /// ## Three rules, and each is the difference between a useful line and a misleading one
    /// 1. **An unstamped link does not print.** `isPrintable` is the gate, exactly as `printable`
    ///    gates a prose fact — a URL is an institutional claim like any other, and one nobody has
    ///    checked is the claim most likely to be wrong.
    /// 2. **A stale stamp degrades the sentence, never the row.** Past the freshness window the
    ///    line appends when it was last checked and says to confirm. Withholding the link would
    ///    leave the reader with nothing where they previously had something slightly old, and
    ///    failing the build would punish a release for NARA's site staying still.
    /// 3. **The date is printed in ISO form, not localised.** This line is pasted into an email to
    ///    reference staff and read months later; `8/22/26` is ambiguous across the Atlantic and
    ///    this packet's whole subject is transatlantic archives.
    static func linkLines(_ links: [RepositoryLink], asOf now: Date = Date()) -> [String] {
        links.filter(\.isPrintable).map { link in
            var line = "\(link.label): \(link.url)"
            if link.isStale(asOf: now), let checked = link.verifiedDate {
                line += " — last checked \(Self.stampFormatter.string(from: checked)); "
                    + "confirm current guidance"
            }
            return line
        }
    }

    /// ISO-8601 dates for link stamps — see rule 3 on ``linkLines(_:asOf:)``.
    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Facilities in the order their groups appear, de-duplicated — so the packet's chapter order
    /// follows how much of the reading each facility holds.
    private func orderedFacilities(in groups: [TripPacketModel.Group]) -> [String] {
        var seen = Set<String>()
        return groups.compactMap { $0.facility.chapterHeading }
            .filter { seen.insert($0).inserted }
    }
}
