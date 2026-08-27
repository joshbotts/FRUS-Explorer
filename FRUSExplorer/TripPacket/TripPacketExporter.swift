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

/// Renders a ``TripPacketModel`` as the Archive Visit packet — the three core deliverables the
/// design narrowed the artifact to (Archive-Visit-Plan-Design §3), in repository-grouped order:
///
/// - **(a) Repository visit-planning links** — ``RepositoryFactTable``'s per-facility link pairs,
///   rendered once per repository. This, not prose, is how the app "points users toward
///   repository-specific guidance."
/// - **(b) The target list** — one row per research target under its repository, carrying the
///   consultation metadata (the A3 records line, the claimant-aware access line, NARA's no-box
///   rule on central-file targets) and **every seeding itemized by claim**: drawn-from seedings
///   quote the source note's file designation, pointed-at seedings quote the footnote citation
///   verbatim with its anchor and its `Ibid.` disclosure. Counts never sum across claims (§3d).
/// - **(c) The inquiry email, per repository** — chapter 2's machinery, now central: letterhead,
///   the editable topic sentence, the records of interest, A5's verbatim help-me-locate items for
///   both channels, and the divided-lot questions (§3a: a divided lot IS a question).
///
/// The plan-level **coverage report** (§3c) travels with every export regardless of scope — it is
/// the one honest home for the facts that no longer have a chapter: the substitute denominators
/// and the layered-digitization warning, the restriction claimants measured vs unmeasured, the
/// refs channel's reach, and the pre-1946 filing-practice explainer.
///
/// ## Plain text, deliberately
/// The inquiry draft is an **email a researcher sends to reference staff**, so it has to survive
/// being pasted into a mail client. The whole packet is therefore plain text rather than
/// attributed strings or HTML: one format, no lossy step between what is reviewed and what is
/// sent. (The PDF share renders THIS string paginated — same content, never a second composition.)
///
/// ## English, deliberately — the packet's language policy (#830)
/// Every string in this type is a raw literal, and that is a decision rather than a gap. The
/// packet is a document addressed to United States archives: the inquiry is an email to reference
/// staff, and the appendix quotes NARA's own English guidance verbatim (an attributed quotation
/// must not be translated). A localized packet would send NARA a letter in the researcher's UI
/// language — so the EXPORTED document stays English by design, like `HTMLCollectionExporter`'s
/// content, while everything the app itself shows around it is localized as usual.
///
/// ## Every section can be empty, and none of them lies about it
/// The packet is generated before a trip is booked, from a reading list that may cite records the
/// app cannot place. So each section has a defined behaviour when its input is missing, and none
/// of them is "omit silently": an unplaceable target is reported as needing confirmation, an
/// unconfirmed fact is left out with the surrounding sentence adjusted, and the coverage report
/// prints unconditionally.
///
/// ## Scoping (§3, export-scoping amendment)
/// `facilityScope` renders one repository's self-contained slice — its links, its targets, its
/// draft — as a render filter over the same sections, never a second pipeline. The coverage
/// report still describes the WHOLE plan, and says so, because the honesty block is not divisible.
///
/// ## What it refuses to print
/// Anything in ``RepositoryFactTable`` without a `verifiedDate`. The exporter reads `printable`
/// rather than `value`, so this is a property of the data path and not of the copy.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2, chapters 1-3, 5-7
///   1.1 — Session 2026-08-22: #830 T-3, chapter 4 (mandatory substitutes, A6)
///   1.2 — Session 2026-08-23: #830 — the data-starved chapters get their data
///   1.3 — Archive Visits Phase 0: chapter 3's roster joins the truncation grammar
///   2.0 — Archive Visits Phase 1: the seven-chapter packet inverts into the narrowed
///          (a)/(b)/(c) artifact (§3). Chapters 1, 3 and 7 dropped; chapter 4 folds to
///          per-seeding markers and chapter 5 to per-target access lines, their homeless
///          facts landing in the coverage report; chapter 6 becomes an opt-in appendix
///          (default off) with the Example-8 gate fixed to "any non-central-file target"
///   2.1 — Archive Visits Phase 3: renders a PLAN — `deliverables` gates the (a)/(b)/(c)
///          sections per §3b, and `overlay` joins the plan's stored state (tier grouping
///          within each repository, exclusions, notes, and the stored-rows coverage line)
struct TripPacketExporter {

    /// The packet to render.
    let model: TripPacketModel
    /// The plan's name, for the header.
    let projectName: String
    /// When non-nil, render only this facility's slice — the export-scoping amendment.
    /// The value is a `ResearchFacility.chapterHeading`.
    var facilityScope: String? = nil
    /// The per-plan deliverable toggles (§3b) — (a)/(b)/(c) on by default, the citation
    /// appendix off. An ephemeral packet renders with the defaults; a plan's stored toggles
    /// travel with it, so the same plan renders the same artifact on every device.
    var deliverables: ArchiveVisitDeliverables = ArchiveVisitDeliverables()
    /// A plan's stored per-target state, joined at render time (Archive Visits Phase 3):
    /// exclusions filter the rendered targets, tier assignments group and order them within
    /// each repository (Unprioritized last), notes ride the rows, and the stored-row
    /// accounting feeds the coverage report. `nil` for an ephemeral packet.
    var overlay: ArchiveVisitOverlay? = nil
    /// When the export was generated, for the header's snapshot caveat. Optional so tests
    /// stay deterministic without injecting a calendar.
    var generatedOn: Date? = nil
    /// How many documents seeded the plan, and how many this device could read — the seed
    /// half of the coverage report, in the resolver's both-numbers grammar. `nil` when the
    /// caller has no seed accounting (the model cannot know it: an unreadable document
    /// never reached the builder).
    var seededDocumentCount: Int? = nil
    var resolvedDocumentCount: Int? = nil
    /// The curated repository facts, injected so tests drive the real table rather than a mirror.
    ///
    /// **Two lookups, because the packet genuinely has two key spaces.** A facility section is
    /// headed by a place (`National Archives at College Park`) and looks its row up here; a
    /// library in the confirm-prompt is a REPOSITORY the corpus cites, looked up by the name the
    /// citation used (`row(for:)` canonicalizes either). Neither can serve the other: `Department
    /// of State` folds to itself, not to a NARA facility.
    var factTable: RepositoryFactTable = .current

    /// The whole packet, gated by the plan's deliverable toggles (§3b). The header and the
    /// coverage report are not deliverables and always render — the honesty block is not
    /// optional (§3c).
    func export() -> String {
        var sections = [header]
        if deliverables.includeLinks || deliverables.includeTargets {
            for facility in orderedFacilities(in: scopedTargets) {
                sections.append(facilitySection(facility))
            }
        }
        if deliverables.includeInquiry { sections.append(inquiryDrafts) }
        if deliverables.includeTargets, facilityScope == nil, !unplacedTargets.isEmpty {
            sections.append(confirmBeforeYouTravel)
        }
        sections.append(coverageReport)
        if deliverables.includeCitationCrib { sections.append(citationCrib) }
        return sections.joined(separator: "\n\n")
    }

    // MARK: - The targets in scope

    /// The targets this export renders — the whole plan, or one facility's slice, minus
    /// whatever the plan's stored state excludes.
    var scopedTargets: [TripPacketModel.Target] {
        let included = model.targets.filter { overlay?.excludedKeys.contains($0.key) != true }
        guard let facilityScope else { return included.filter(\.canHeadChapter) }
        return included.filter { $0.facility.chapterHeading == facilityScope }
    }

    /// Targets no repository can serve — the confirm-prompt set (D11), reported rather than
    /// dropped: a collection the packet cannot place is exactly what the reader must ring
    /// ahead about.
    var unplacedTargets: [TripPacketModel.Target] {
        model.targets.filter { !$0.canHeadChapter }
    }

    // MARK: - Header

    /// Title, the claim-separated counts, and the snapshot caveat.
    var header: String {
        var out = ["# Archive visit packet: \(projectName)", ""]
        if let facilityScope {
            out.append("Scoped to \(facilityScope) — one repository's slice of the plan. The "
                       + "coverage report below still describes the whole plan.")
            out.append("")
        }
        let targets = scopedTargets
        let facilities = orderedFacilities(in: targets)
        let drawnDocuments = Set(targets.flatMap { $0.drawnFrom.map(\.id) }).count
        let footnotes = targets.reduce(0) { $0 + $1.pointedAt.count }
        // Two counts, never summed: a document published FROM a file and a footnote that
        // CITES one are different assertions (§3d), and a single total would erase that.
        var counts = "\(targets.count) research target\(targets.count == 1 ? "" : "s")"
        if !facilities.isEmpty {
            counts += " across \(facilities.count) "
                + (facilities.count == 1 ? "repository" : "repositories")
        }
        if drawnDocuments > 0 {
            counts += " · drawn from \(drawnDocuments) document\(drawnDocuments == 1 ? "" : "s")"
        }
        if footnotes > 0 {
            counts += " · cited by \(footnotes) footnote\(footnotes == 1 ? "" : "s")"
        }
        out.append(counts)
        out.append("")
        var caveat = ""
        if let generatedOn {
            caveat += "Generated \(Self.stampFormatter.string(from: generatedOn)). "
        }
        caveat += "Series resolutions and access statuses are this app's bundled snapshot of "
            + "NARA's catalog — confirm against the live catalog and with reference staff "
            + "before you travel."
        out.append(caveat)
        return out.joined(separator: "\n")
    }

    // MARK: - Deliverables (a) + (b): one section per repository

    /// A facility's visit-planning links and its target rows.
    func facilitySection(_ facility: String) -> String {
        var out = ["## \(facility)", ""]
        // Deliverable (a): the curated link pairs, worst-freshness rule applied per link
        // (D12). Only ever `printable` — an unverified link is omitted, never printed
        // undated (D7). A facility without a curated row simply has no links block.
        if deliverables.includeLinks, let row = factTable.row(for: facility) {
            let links = Self.linkLines(row.links)
            if !links.isEmpty {
                out.append("Plan your visit:")
                for line in links { out.append("- \(line)") }
                out.append("")
            }
        }
        // Deliverable (b): the target rows — within a repository, grouped by the plan's
        // priority tiers in tier order, Unprioritized last (§5: repository → priority),
        // label-sorted within a tier so the order is deterministic.
        if deliverables.includeTargets {
            let targets = scopedTargets
                .filter { $0.facility.chapterHeading == facility }
                .sorted {
                    let l = overlay?.tierOrderIndex(for: $0.key) ?? Int.max
                    let r = overlay?.tierOrderIndex(for: $1.key) ?? Int.max
                    if l != r { return l < r }
                    return $0.label < $1.label
                }
            for target in targets {
                out.append(contentsOf: targetRows(target))
            }
        }
        while out.last == "" { out.removeLast() }
        return out.joined(separator: "\n")
    }

    /// Deliverable (b): one target's row — metadata, then its seedings itemized by claim.
    /// A plan's tier rides the heading as a bracket prefix ("[Day one] Lot 67 D 54" — the 1g
    /// grammar), and its note rides the row.
    func targetRows(_ target: TripPacketModel.Target) -> [String] {
        let tierPrefix = overlay.flatMap { overlay in
            overlay.tier(for: target.key).map { "[\(overlay.displayName(for: $0))] " }
        } ?? ""
        var out = ["### \(tierPrefix)\(target.label)", ""]
        out.append(Self.claimCounts(target))
        if let note = overlay?.notes[target.key] {
            out.append("Note: \(note)")
        }
        if let line = target.recordsLine {
            out.append(line)
            if let url = target.resolution?.catalogURL { out.append(url) }
        }
        out.append(contentsOf: Self.restrictionLines(target.restriction))
        if Self.isCentralFileTarget(target) {
            // §3a's one crib fold: NARA's guidance asks that central-file citations carry
            // no box number, so the row says so once rather than leaving a blank column
            // to be misread as missing data.
            out.append("No box numbers, on purpose: NARA's citation guidance asks that "
                       + "central-file citations carry none; boxes are assigned at the pull "
                       + "desk from NARA's own finding aids.")
        }

        // The drawn-from claim: documents PUBLISHED from this unit, each with its FRUS
        // link and the file designation its source note cites — chapter 3's one unique
        // payload, moved to the seeding row it always belonged on (§3a).
        if !target.drawnFrom.isEmpty {
            out.append("")
            out.append("Published from this file:")
            let shown = target.drawnFrom.prefix(Self.seedingRowLimit)
            for document in shown {
                var line = "  - \(document.citation)"
                if let designation = document.fileDesignation { line += " — file \(designation)" }
                out.append(line)
                out.append("    " + FRUSCanonicalURL.string(volumeId: document.volumeId,
                                                            documentId: document.documentId))
                // Chapter 4's fold: the substitute marker at the grain the match actually
                // has — this document's citation landed in a digitized range or filmed
                // roll, so it is read that way rather than pulled (A6 is an obligation).
                if let naIds = model.substitutes.matchesByDocument[document.id],
                   let first = naIds.first {
                    let title = substituteTitlesByNaId[first] ?? "NAID \(first)"
                    var marker = "    Digitized or filmed — use \(title) (NAID \(first)) "
                        + "instead of pulling"
                    if naIds.count > 1 {
                        marker += "; \(naIds.count - 1) further "
                            + (naIds.count == 2 ? "unit claims" : "units claim")
                            + " this document — NARA's digitization is layered, so check "
                            + "which covers it"
                    }
                    out.append(marker + ".")
                }
            }
            if target.drawnFrom.count > shown.count {
                let n = target.drawnFrom.count - shown.count
                out.append("  …and \(n) more document\(n == 1 ? "" : "s") — the app carries "
                           + "the full list.")
            }
        }

        // The pointed-at claim: footnotes citing this unit, unprinted — quoted verbatim,
        // the packet's discipline (A5; #784's safety verdict rests on reading the words).
        if !target.pointedAt.isEmpty {
            out.append("")
            out.append("Cited in footnotes, not printed — FRUS's editors point at this file "
                       + "without publishing from it:")
            let shown = target.pointedAt.prefix(Self.seedingRowLimit)
            for seeding in shown {
                out.append("  - \(seeding.citation), footnote \(seeding.footnoteNumber)")
                out.append("    Cited as: \(seeding.rawText)")
                if seeding.inherited {
                    // An inherited citation is the PREVIOUS footnote's assertion of the
                    // unit; hiding that would put words in this footnote's mouth.
                    out.append("    (The file is inherited from the preceding footnote's "
                               + "citation — this note cites it as \"Ibid.\".)")
                }
                out.append("    " + FRUSCanonicalURL.string(volumeId: seeding.volumeId,
                                                            documentId: seeding.documentId))
            }
            if target.pointedAt.count > shown.count {
                let n = target.pointedAt.count - shown.count
                out.append("  …and \(n) more citation\(n == 1 ? "" : "s") — the app carries "
                           + "the full list.")
            }
        }
        out.append("")
        return out
    }

    // MARK: - Deliverable (c): inquiry drafts

    /// The advance-inquiry draft, one per facility.
    ///
    /// One draft per facility, because A3 asks for one agency or a group of closely related
    /// agencies per inquiry and A2 requires sending to **only one address**. A packet that
    /// produced a single letter naming three repositories would violate both.
    var inquiryDrafts: String {
        var out = ["## Advance inquiry", ""]

        let placeable = scopedTargets
        if placeable.isEmpty {
            out.append("No target in this packet resolved to a facility, so there is no inquiry "
                       + "to draft."
                       + (facilityScope == nil && !unplacedTargets.isEmpty
                          ? " The collections below still need confirming before you travel."
                          : ""))
        }
        for facility in orderedFacilities(in: placeable) {
            let targets = placeable.filter { $0.facility.chapterHeading == facility }
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
            for target in targets.prefix(Self.recordsOfInterestLimit) {
                out.append("  - \(target.label) (\(Self.claimCounts(target)))")
                // A3's four fields — RG · entry · series title · NAID — in NARA's own
                // format, with the catalog link, whenever the citation resolved. This is
                // what the effective-inquiry spec asks the records be identified by.
                if let line = target.recordsLine {
                    out.append("    \(line)")
                    if let url = target.resolution?.catalogURL { out.append("    \(url)") }
                }
            }
            if targets.count > Self.recordsOfInterestLimit {
                let n = targets.count - Self.recordsOfInterestLimit
                out.append("  - …and \(n) further target\(n == 1 ? "" : "s"), listed above.")
            }
            // A5: every source note whose citation reached no NARA series appears VERBATIM,
            // with its FRUS citation, as a help-me-locate item — because NARA's own FAQ
            // says resolving poorly-described records "cannot be done effectively on an ad
            // hoc basis while researchers wait in a research room", and the lot numbers
            // FRUS prints "do not always carry over into use by the National Archives"
            // (both quoted from the deposited research-visit FAQ). The consultation desk
            // is the day-of fallback; this is the advance route.
            let unresolvedDrawn = targets.filter {
                $0.form == .lotFile && $0.resolution == nil && !$0.drawnFrom.isEmpty
            }
            if !unresolvedDrawn.isEmpty {
                out.append("")
                out.append("Please help me locate the following. FRUS cites them as printed "
                           + "below; this file designation may be one that did not carry over "
                           + "into use by the National Archives:")
                for target in unresolvedDrawn {
                    out.append("  - \(target.label) (\(Self.claimCounts(target)))")
                    for document in target.drawnFrom.prefix(Self.unresolvedNoteLimit) {
                        out.append("      \(document.citation)")
                        out.append("      Cited as: \(document.sourceNote)")
                    }
                    // Disclose a truncation rather than trailing off — the reader is
                    // pasting this into an email and must know the list is partial.
                    if target.drawnFrom.count > Self.unresolvedNoteLimit {
                        let n = target.drawnFrom.count - Self.unresolvedNoteLimit
                        out.append("      …and \(n) further "
                                   + (n == 1 ? "citation" : "citations")
                                   + " from the same file, in the target list above.")
                    }
                }
            }
            // The pointed-at channel's help-me-locate: files FRUS's editors cite in
            // footnotes without printing from them, unresolved against the catalog. The
            // same A5 rule, applied to the other claim — with the claim stated, because
            // "the editors cite it" is a different warrant than "the document came from it".
            let unresolvedPointed = targets.filter {
                $0.form == .lotFile && $0.resolution == nil
                    && $0.drawnFrom.isEmpty && !$0.pointedAt.isEmpty
            }
            if !unresolvedPointed.isEmpty {
                out.append("")
                out.append("FRUS's editors also cite the following files in footnotes without "
                           + "printing documents from them. The citations are quoted as printed; "
                           + "these designations too may not have carried over:")
                for target in unresolvedPointed {
                    out.append("  - \(target.label) (\(Self.claimCounts(target)))")
                    for seeding in target.pointedAt.prefix(Self.unresolvedNoteLimit) {
                        out.append("      \(seeding.citation), footnote \(seeding.footnoteNumber)")
                        out.append("      Cited as: \(seeding.rawText)")
                    }
                    if target.pointedAt.count > Self.unresolvedNoteLimit {
                        let n = target.pointedAt.count - Self.unresolvedNoteLimit
                        out.append("      …and \(n) further "
                                   + (n == 1 ? "citation" : "citations")
                                   + " of the same file, in the target list above.")
                    }
                }
            }
            // §3a: a divided lot routes into the inquiry AS A QUESTION, because that is what
            // it is — NARA's catalog holds several correct answers, and only an archivist
            // can say which series serves this reader's records.
            let divided = targets.filter { $0.restriction?.isDivided == true }
            if !divided.isEmpty {
                out.append("")
                out.append("Questions:")
                for target in divided {
                    guard let restriction = target.restriction else { continue }
                    var question = "  - NARA's catalog lists \(restriction.claimantCount) series "
                        + "claiming \(target.label)"
                    if restriction.unmeasuredClaimantCount > 0 {
                        question += ", \(restriction.unmeasuredClaimantCount) with no recorded "
                            + "access status"
                    }
                    question += " — which should I consult for the records above, and is it open?"
                    out.append(question)
                }
            }
            out.append("")
        }
        while out.last == "" { out.removeLast() }
        return out.joined(separator: "\n")
    }

    // MARK: - Confirm before you travel

    /// D11: libraries and unplaceable collections get A12's actual ask, not a drafted letter.
    /// At collection grain the packet can name neither series nor NAID, so a letter would imply
    /// a precision the data lacks.
    var confirmBeforeYouTravel: String {
        var out = ["### Confirm before you travel"]
        out.append("These collections could not be placed at a facility from the data this app "
                   + "holds. NARA's own advice is to write, phone or email ahead to confirm the "
                   + "materials are at that location before you travel.")
        out.append("")
        for target in unplacedTargets {
            out.append("  - \(target.label) (\(Self.claimCounts(target)))")
            if case .confirmBeforeTravelling(let named) = target.facility {
                out.append("    Cited as \(named). Records centres transfer their holdings, so "
                           + "ask staff where these records are now.")
            }
            // D11's other half: the ask, beside the page that answers it. `facts` is the
            // curated row for the REPOSITORY the citation named — a library never resolves
            // to a facility heading (D3), so it never reaches the facility sections' lookup.
            if let row = target.facts {
                for line in Self.linkLines(row.links) { out.append("    \(line)") }
            }
        }
        return out.joined(separator: "\n")
    }

    // MARK: - The coverage report (§3c)

    /// The plan-level honesty block — one home for every fact whose chapter folded, stated in
    /// true denominators. **Prints unconditionally and travels with every export**, scoped or
    /// not: an empty channel with no caveat would read as a clearance, which is the exact
    /// error the folded chapters existed to prevent.
    var coverageReport: String {
        var out = ["## What this packet covers", ""]

        // The seeds, in the resolver's both-numbers grammar — both numbers even when
        // complete, because "51 of 51" tells the reader the test ran everywhere (1h).
        if let seeded = seededDocumentCount, let resolved = resolvedDocumentCount {
            var line = "\(resolved) of \(seeded) seeding "
                + (seeded == 1 ? "document" : "documents") + " indexed on this device"
            if resolved < seeded {
                let missing = seeded - resolved
                line += " — targets from the other \(missing) may be missing"
            }
            out.append(line + ".")
        }

        // The plan's stored state, when there is one (1h): how many stored rows still derive,
        // and what the researcher excluded — both disclosed, never silently applied.
        if let overlay, overlay.storedKeyCount > 0 {
            let deriving = overlay.storedKeyCount - overlay.orphanKeys.count
            var line = "\(deriving) of \(overlay.storedKeyCount) stored target "
                + (overlay.storedKeyCount == 1 ? "row derives" : "rows derive")
                + " from the current seeds"
            if !overlay.orphanKeys.isEmpty {
                let n = overlay.orphanKeys.count
                line += " — \(n) kept and labeled, never deleted"
            }
            out.append(line + ".")
        }
        if let overlay, !overlay.excludedKeys.isEmpty {
            let n = overlay.excludedKeys.count
            out.append("\(n) target\(n == 1 ? "" : "s") excluded from this export by you.")
        }

        // The targets, split honestly: resolved / cited-but-unresolved / unplaceable.
        let all = model.targets
        let resolved = all.filter { $0.resolution != nil }.count
        let unplaced = unplacedTargets.count
        var targetsLine = "\(all.count) research target\(all.count == 1 ? "" : "s"): "
            + "\(resolved) resolve\(resolved == 1 ? "s" : "") to a NARA series"
        if unplaced > 0 {
            targetsLine += "; \(unplaced) could not be placed at any repository and "
                + (unplaced == 1 ? "is" : "are") + " listed under \"Confirm before you travel\""
                + (facilityScope == nil ? "" : " in the full-plan export")
        }
        out.append(targetsLine + ".")
        if let facilityScope {
            let excluded = all.filter {
                $0.canHeadChapter && $0.facility.chapterHeading != facilityScope
            }.count
            if excluded > 0 {
                out.append("This export renders only \(facilityScope); \(excluded) "
                           + "target\(excluded == 1 ? "" : "s") at other repositories "
                           + (excluded == 1 ? "is" : "are") + " not shown here.")
            }
        }
        out.append("")

        // The pointed-at channel's reach. References of this kind sit on a small minority
        // of documents corpus-wide, so a thin list must read as sparse data, never as a
        // failed scan — and on a pre-1946 reading list the emptiness is the filing practice.
        let refs = model.referenceCoverage
        if refs.documentsScanned > 0 {
            out.append("Footnote references were scanned on \(refs.documentsScanned) "
                       + "document\(refs.documentsScanned == 1 ? "" : "s"); "
                       + "\(refs.documentsWithReferences) "
                       + (refs.documentsWithReferences == 1 ? "carries" : "carry")
                       + " at least one reference to a lot file or library collection.")
            if refs.documentsWithReferences == 0, model.seededSpanPredates1946 {
                out.append("For records before 1946 that is the filing practice, not a gap: "
                           + "lot files and presidential libraries are a post-war practice, "
                           + "and earlier footnotes cite central decimal files — which this "
                           + "packet already covers through the documents' own source notes.")
            } else {
                out.append("References of this kind exist on a small minority of FRUS "
                           + "documents, so a short list is expected and not a failure to look.")
            }
            out.append("")
        }

        // Chapter 4's homeless facts (§3a): the obligation quote, the denominators, the
        // partial-digitization count, the layered-digitization warning, and the closing
        // citation rule. The rule is quoted and attributed, not paraphrased — it is an
        // obligation the reading room enforces, so a pull slip written against a filmed
        // record is a slip that gets declined.
        if !model.substitutes.rows.isEmpty {
            out.append("NARA's research-visit guidance states the substitute rule as an "
                       + "obligation: \"Researchers must use microfilm and online resources "
                       + "when those options are available.\" The affected documents are "
                       + "marked on their targets above.")
        }
        out.append(model.substitutes.coverageNote)
        if model.substitutes.rows.contains(where: { !$0.isSoleClaimant }) {
            out.append("More than one digitized unit claims some of these documents — NARA's "
                       + "digitization is layered, so check that the unit named on a document's "
                       + "line covers it.")
        }
        if !model.substitutes.rows.isEmpty {
            // From NARA's "Citing Foreign Affairs Records": the substitute changes the
            // citation, and a reader who only records the URL cannot reconstruct the
            // reference.
            out.append("When you cite a digitized or filmed record, NARA's guidance asks for "
                       + "the microfilm publication number, and for online records \"the "
                       + "elements noted above, not just the URL\".")
        }
        out.append("")

        // Chapter 5's plan-level line, and the claimant grain the per-target lines rest on.
        let triage = model.triage
        if !triage.isEmpty {
            let flagged = triage.needingAdvanceContact
            if flagged.isEmpty {
                out.append("Every series this packet cites is recorded as unrestricted. "
                           + "Availability still depends on the records themselves — confirm "
                           + "with staff.")
            } else {
                out.append("\(flagged.count) of \(triage.rows.count) cited series "
                           + (flagged.count == 1 ? "carries" : "carry")
                           + " a restriction or no stated status — each affected target's row "
                           + "states it, worst covered status first. A closed series cannot be "
                           + "pulled, so raise these in your inquiry rather than on arrival.")
            }
            let divided = model.targets.compactMap(\.restriction).filter(\.isDivided)
            let unmeasured = divided.reduce(0) { $0 + $1.unmeasuredClaimantCount }
            if !divided.isEmpty {
                let total = divided.reduce(0) { $0 + $1.claimantCount }
                out.append("Access status measured for \(total - unmeasured) of \(total) "
                           + "claimant series across this plan's \(divided.count) divided "
                           + (divided.count == 1 ? "lot" : "lots") + ".")
            }
            if unmeasured > 0 {
                out.append("Across divided lots, \(unmeasured) claimant "
                           + (unmeasured == 1 ? "series carries" : "series carry")
                           + " no recorded access status — absence of a ruling, not openness.")
            }
            if triage.unresolvedDocumentCount > 0 {
                let n = triage.unresolvedDocumentCount
                out.append((n == 1 ? "1 document cites" : "\(n) documents cite")
                           + " no series this app could resolve, so nothing is known about "
                           + (n == 1 ? "its" : "their") + " access.")
            }
        }
        while out.last == "" { out.removeLast() }
        return out.joined(separator: "\n")
    }

    // MARK: - Truncation grammar

    /// How many seedings a target's per-claim list prints before its remainder line.
    /// Matches the packet's 12/8/20 grammar — the 8 tier, like the verbatim-notes cap.
    static let seedingRowLimit = 8
    /// How many targets the inquiry's records-of-interest list names before deferring.
    static let recordsOfInterestLimit = 12
    /// How many verbatim unresolved citations print per target in the inquiry's
    /// help-me-locate lists before they defer to the target list.
    static let unresolvedNoteLimit = 8

    // MARK: - Appendix: citation crib (opt-in, §3a)

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
        // ALL the plan's targets, not just the placeable ones: a library the packet cannot
        // place still yields records the researcher will cite. A facility scope narrows it,
        // like every other section.
        let targets = facilityScope == nil
            ? model.targets
            : model.targets.filter { $0.facility.chapterHeading == facilityScope }
        let centralTargets = targets.filter(Self.isCentralFileTarget)
        let designations = centralTargets.flatMap(\.drawnFrom).compactMap(\.fileDesignation)

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

        // Every non-central target: NARA's own note says Example 8 "also serves as a model
        // that can be followed for all other records entries other than those of the
        // Department of State central files" — so the gate is "not a central-file target",
        // not "a lot file" (§3a fixed the live defect: the old gate skipped collections and
        // raw targets NARA's note plainly covers). Pre-filled from the first RESOLVED
        // non-central target — series title, entry, record group — when the packet has one.
        let nonCentral = targets.filter { !Self.isCentralFileTarget($0) }
        if !nonCentral.isEmpty {
            var prefill = ["⟨Sender⟩ to ⟨recipient⟩, ⟨Type⟩, ⟨date⟩, file ⟨folder title⟩, "
                           + "⟨series title⟩, Entry ⟨entry number⟩, RG ⟨record group⟩: "
                           + "⟨record group title⟩, U.S. National Archives."]
            if let resolved = nonCentral.first(where: { $0.resolution != nil }),
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

    // MARK: - Shared renderers

    /// The claim-separated counts line — "drawn from 3 documents · cited by 2 footnotes",
    /// NEVER "5" (§3d: counts do not sum across claims, because a document published from a
    /// file and a footnote citing one are different assertions).
    static func claimCounts(_ target: TripPacketModel.Target) -> String {
        var parts: [String] = []
        if !target.drawnFrom.isEmpty {
            let n = target.drawnFrom.count
            parts.append("drawn from \(n) document\(n == 1 ? "" : "s")")
        }
        if !target.pointedAt.isEmpty {
            let n = target.pointedAt.count
            parts.append("cited by \(n) footnote\(n == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// The claimant-aware access line (§3a) — one line, never a badge.
    static func restrictionLines(_ restriction: TripPacketModel.TargetRestriction?) -> [String] {
        guard let restriction else { return [] }
        if restriction.worstCoveredStatus.isEmpty {
            // Divided, nothing measured: "several series, none measured" is itself the
            // question, and the inquiry carries it.
            return ["Access: NARA divides this lot across \(restriction.claimantCount) series "
                    + "and records an access status for none of them — ask reference staff "
                    + "which series holds these records and whether it is open."]
        }
        if restriction.claimantCount > 1 {
            var line = "Access: \(restriction.worstCoveredStatus)"
            if let series = restriction.claimantSeriesTitle {
                line += " — the status of \(series), one of \(restriction.claimantCount) series "
                    + "claiming this lot"
            } else {
                line += " — the worst status among \(restriction.claimantCount) series claiming "
                    + "this lot"
            }
            if restriction.unmeasuredClaimantCount > 0 {
                let n = restriction.unmeasuredClaimantCount
                line += "; \(n) claimant\(n == 1 ? " carries" : "s carry") no recorded status"
            }
            return [line + "."]
        }
        return ["Access: \(restriction.worstCoveredStatus)."]
    }

    /// Whether a target is a central-file target — the no-box rule's gate, and the crib's.
    static func isCentralFileTarget(_ target: TripPacketModel.Target) -> Bool {
        target.category == .centralDecimalFile || target.category == .centralForeignPolicyFile
    }

    /// Substitute-unit titles by NAID, for the per-seeding markers.
    private var substituteTitlesByNaId: [String: String] {
        Dictionary(uniqueKeysWithValues: model.substitutes.rows.map { ($0.naId, $0.title) })
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

    /// ISO-8601 dates for link stamps and the header's generation stamp — see rule 3 on
    /// ``linkLines(_:asOf:)``.
    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Facilities in the order their targets appear, de-duplicated — the model sorts targets
    /// facility-first, so the packet's section order is alphabetical by facility.
    private func orderedFacilities(in targets: [TripPacketModel.Target]) -> [String] {
        var seen = Set<String>()
        return targets.compactMap { $0.facility.chapterHeading }
            .filter { seen.insert($0).inserted }
    }
}
