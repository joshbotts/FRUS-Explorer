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

// MARK: - TripPacketTopicSentence

/// The inquiry's topic sentence — seeded from the project, edited by the researcher (#830 T-1, D8).
///
/// ## Why seeded-and-editable rather than quoted
/// A project's research question is exactly NARA's "succinct description of your research
/// interest", so it is the right default. But it is an **internal note written for the
/// researcher's own use**, and the draft is an email to NARA reference staff. So the packet
/// pre-fills and lets them edit — and **the exporter reads the edited value, never the stored one**.
/// A quoted string baked into the export would send NARA a private note.
struct TripPacketTopicSentence: Equatable, Sendable {

    /// What the project holds, if anything.
    let seed: String?
    /// What the researcher typed, if they have.
    var edited: String?

    /// What an export prints: the edit if there is one, else the seed, else the placeholder.
    ///
    /// A project with no research question gets the placeholder rather than an empty paragraph —
    /// an inquiry with a blank topic is the one thing A3 says never to send ("never 'everything
    /// you have'").
    var forExport: String {
        if let edited, !edited.trimmingCharacters(in: .whitespaces).isEmpty { return edited }
        if let seed, !seed.trimmingCharacters(in: .whitespaces).isEmpty { return seed }
        return Self.placeholder
    }

    /// Whether the researcher still needs to write this.
    var needsAttention: Bool { forExport == Self.placeholder }

    /// Shown when neither a seed nor an edit exists — deliberately an instruction, not filler.
    static let placeholder = String(
        localized: "packet.topic.placeholder",
        defaultValue: "[Describe your research topic in one or two sentences — narrow and specific. NARA asks for a succinct description, never “everything you have”.]")

    /// Seeds from a project's research question.
    static func seeded(from researchQuestion: String?) -> TripPacketTopicSentence {
        TripPacketTopicSentence(seed: researchQuestion, edited: nil)
    }
}

// MARK: - TripPacketModel

/// Everything the trip packet knows, assembled from data the app already holds (#830 T-1).
///
/// ## What this is, and what it refuses to be
/// A pure aggregation over the builder's form-aware target keys (`TripPacketBuilder.targetKey`)
/// and the pointed-at reference channel. It computes: where each target is served
/// (``ResearchFacilityResolver``), what is restricted (``RestrictionTriage`` at plan level,
/// ``TargetRestriction`` at target level), and which records must be read digitized or on film
/// (``MandatorySubstitutes``).
///
/// **It prints no institutional fact the owner has not confirmed.** Those live in
/// ``RepositoryFactTable``, which ships ONE row (College Park, address and inquiry email confirmed
/// 2026-08-22) — and even there, a field with no `verifiedDate` is unprintable, so the appointment
/// policy is omitted rather than printed undated. A chapter for a presidential library renders its
/// heading and its confirm-before-you-travel prompt (D11) and nothing else. The packet builds, and
/// the gap is visible rather than filled with a guess.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
///   1.1 — Session 2026-08-22: #830 T-3, the A6 substitutes aggregate
///   1.2 — Session 2026-08-23: #830 — the group carries what the builder was computing and
///          discarding (the full `ArchivalResolution`, the provenance category, the series
///          years, and the per-document rows), which is the prerequisite for chapter 5's
///          series names, chapter 6's worked examples, A3's four-field records line, A5's
///          verbatim unresolved notes, and chapter 3's per-document roster
///   2.0 — Archive Visits Phase 1: the RESEARCH TARGET becomes the working grain. A target is
///          one archival unit under a claim-free, form-aware key (§2b of the design: decimal
///          CLASS / normalized lot / repository|collection / raw note), holding its drawn-from
///          seedings (the documents published from it) and its pointed-at seedings (the
///          footnotes citing it unprinted, lot + library kinds only) — the two claims itemized
///          inside one row, their counts never summed (#783). Lot targets carry a claimant-aware
///          restriction line (123 divided lots ship; a single-NAID answer would print one
///          claimant's status as the lot's). The checklist and advance-notice flags leave the
///          model with their chapters (owner: ch1/ch7 dropped).
struct TripPacketModel: Equatable, Sendable {

    /// One archival group the reading list touches.
    struct Group: Equatable, Sendable, Identifiable {

        /// One document in the group — the roster row chapter 3 prints and the verbatim
        /// note A5 quotes.
        ///
        /// Everything is MATERIALIZED at build (the citation is a formatted string, the
        /// note is the stored text), matching the model's whole design: the packet is a
        /// snapshot the exporter renders, never a set of lookups the exporter performs.
        struct DocumentRef: Equatable, Sendable, Identifiable {
            /// The document's volume.
            let volumeId: String
            /// The document's id within it.
            let documentId: String
            /// The history.state.gov-style citation, formatted at build.
            let citation: String
            /// The file or folder designation the source note cites (a decimal or
            /// subject-numeric file number, a lot's folder), when the parser found one.
            let fileDesignation: String?
            /// The source note as printed in FRUS — what A5 quotes verbatim when the
            /// citation resolves to no NARA series.
            let sourceNote: String

            var id: String { "\(volumeId)/\(documentId)" }
        }

        /// The grouping key from `archivalSourceRows`.
        let id: String
        /// What to call it.
        let label: String
        /// Where it is served — or an honest refusal.
        let facility: ResearchFacility
        /// How many of the reader's documents cite it.
        let documentCount: Int
        /// The curated row, when one exists. `nil` for every row at T-1.
        let facts: RepositoryFactRow?
        /// The parser's provenance category — what kind of filing system the citation names.
        let category: SourceProvenanceCategory?
        /// The FULL archival resolution, when the citation reached one — title, catalog
        /// URL, HMS/MLR entry numbers, series title. Previously reduced to its `naId` at
        /// this exact seam, which left chapter 5 printing bare NAIDs and A3's four-field
        /// line with nothing to print.
        let resolution: ArchivalResolution?
        /// NARA's inclusive years for the resolved series, when the facts index has them.
        let seriesYears: String?
        /// The group's documents, in reading-list order.
        let documents: [DocumentRef]

        /// Whether this group can head a packet chapter (D3).
        var canHeadChapter: Bool { facility.chapterHeading != nil }

        /// A3's four-field records line — RG · entry · series title · NAID — or `nil`
        /// when the citation resolved to no series. Composed here so chapter 2 and
        /// chapter 3 cannot format the same fields differently.
        var recordsLine: String? {
            guard let resolution else { return nil }
            var parts: [String] = []
            if let rg = resolution.recordGroup { parts.append("RG \(rg)") }
            let entries = resolution.seriesHmsMlrEntryNumbers ?? resolution.hmsMlrEntryNumbers
            if let entries, !entries.isEmpty {
                parts.append("Entry \(entries.joined(separator: ", "))")
            }
            parts.append(resolution.displaySeriesTitle ?? resolution.title)
            parts.append("NAID \(resolution.seriesNaId ?? resolution.naId)")
            if let seriesYears { parts.append(seriesYears) }
            return parts.joined(separator: " · ")
        }
    }

    /// One footnote citation of an archival unit FRUS did not print — a POINTED-AT seeding.
    ///
    /// The claim lives here, on the seeding, never on the target's key: "the document's
    /// footnotes cite this, unprinted" is a different assertion from "the document was
    /// published from this file", and the two are itemized under separate headings inside
    /// one target row (§3d — the evidence-grain form of the #783 separation).
    struct RefSeeding: Equatable, Sendable {
        /// The citing document's volume.
        let volumeId: String
        /// The citing document's id.
        let documentId: String
        /// The history.state.gov-style citation, formatted at build.
        let citation: String
        /// Which footnote carries the reference (the note's ordinal in the document).
        let footnoteNumber: Int
        /// The footnote citation as printed — quoted verbatim, the packet's discipline.
        let rawText: String
        /// Whether an `Ibid.` supplied the unit — disclosed on the rendered line, because an
        /// inherited citation is the previous footnote's assertion, not this one's.
        let inherited: Bool
    }

    /// A lot target's access status, stated at the grain the data supports (§3a).
    ///
    /// NARA divides a lot across several series as readily as it consolidates (123 divided
    /// lots ship, one claimed by 13 series), and the series carry DIFFERENT access statuses —
    /// so this is one line stating the worst COVERED status, the series it belongs to, and how
    /// many claimants are unmeasured. Never a badge: a badge invents certainty.
    struct TargetRestriction: Equatable, Sendable {
        /// NARA's own words for the most severe measured status ("Restricted - Partly").
        let worstCoveredStatus: String
        /// Its severity, for ordering.
        let worstSeverity: RestrictionSeverity
        /// The claimant series that status belongs to.
        let claimantSeriesTitle: String?
        /// How many series claim this lot in NARA's catalog (1 = undivided).
        let claimantCount: Int
        /// Claimants with no measured access status — absence of a ruling, not openness.
        let unmeasuredClaimantCount: Int
        /// Whether NARA divides this lot across several series — routed into the inquiry
        /// draft as a question when true, because a divided lot IS a question.
        var isDivided: Bool { claimantCount > 1 }
    }

    /// One research target: an archival unit under a claim-free, form-aware key.
    struct Target: Equatable, Sendable, Identifiable {
        /// Which citation form keyed this target (§2b's table).
        enum Form: String, Equatable, Sendable {
            /// A central-file class (`611.51`) — the unit a researcher consults, NOT the
            /// per-document file number (which is the seeding's detail). Keying on the file
            /// number was measured to mint one target per document for the corpus's
            /// commonest citation form.
            case decimalClass
            /// A lot file, keyed on `SourceNoteParser.lotFileNorm` — the same normalizer
            /// `external_citations.lot_file_norm` stores, so the two claims merge exactly.
            case lotFile
            /// A repository|collection pair (libraries, named collections).
            case collection
            /// An unrecognized citation, keyed on its raw text so distinct notes never merge.
            case raw
        }

        /// The claim-free key (`form|identity`).
        let key: String
        let form: Form
        /// What to call it.
        let label: String
        /// Where it is served — or an honest refusal.
        let facility: ResearchFacility
        let category: SourceProvenanceCategory?
        /// The curated repository row, when the cited repository has one — what puts D11's
        /// ask beside the page that answers it for a library the packet cannot place.
        let facts: RepositoryFactRow?
        /// The full resolution, when the citation reached one.
        let resolution: ArchivalResolution?
        /// NARA's inclusive years for the resolved series.
        let seriesYears: String?
        /// Documents published FROM this unit (their source notes name it).
        let drawnFrom: [Group.DocumentRef]
        /// Footnotes citing this unit, unprinted.
        let pointedAt: [RefSeeding]
        /// The claimant-aware access line, when anything is measured or divided.
        let restriction: TargetRestriction?

        var id: String { key }
        var canHeadChapter: Bool { facility.chapterHeading != nil }

        /// A3's four-field records line — shared composition with ``Group/recordsLine``.
        var recordsLine: String? {
            TripPacketModel.recordsLine(resolution: resolution, seriesYears: seriesYears)
        }
    }

    /// The groups, most-cited first — the DRAWN-FROM channel as built, kept for the
    /// substitute/coverage denominators and the unresolved accounting. The artifact renders
    /// from ``targets``.
    let groups: [Group]
    /// The research targets, assembled from both channels (§2), in facility-then-label order.
    let targets: [Target]
    /// Access triage across the whole reading list — the plan-level line and the inquiry's
    /// questions; per-target status lives on ``Target/restriction``.
    let triage: RestrictionTriage
    /// Records that must be read online or on film instead of pulled (A6) — the coverage
    /// report's denominators; per-seeding markers come from ``MandatorySubstitutes/matchesByDocument``.
    let substitutes: MandatorySubstitutes
    /// The coverage report's refs line: how many seeded documents the pointed-at channel found
    /// references on, over how many it scanned (references exist on ~4% of documents —
    /// measured 2026-08-26 over the full 552-volume index, 13,750 of 316,839
    /// corpus-wide, and a thin channel must read as sparse data, not as a failed scan).
    struct ReferenceCoverage: Equatable, Sendable {
        let documentsWithReferences: Int
        let documentsScanned: Int
    }
    let referenceCoverage: ReferenceCoverage
    /// Whether every seeded document with a known year predates 1946 — the coverage report's
    /// empty-refs explainer. Lot files and presidential libraries are a post-war filing
    /// practice (measured for #784: the pre-war decades yield 0/0/2 references at the shipped
    /// scope), so an empty pointed-at channel on a pre-1946 reading list is the filing
    /// practice, not a failed scan — and only this flag lets the report say which.
    let seededSpanPredates1946: Bool
    /// The inquiry's topic sentence.
    var topicSentence: TripPacketTopicSentence

    /// Groups that cannot head a chapter, and therefore need the confirm-prompt treatment (D11).
    ///
    /// Reported rather than dropped: a library the packet cannot place is exactly what the reader
    /// must ring ahead about, and silently omitting it would leave part of their reading unplanned.
    var needingConfirmation: [Group] { groups.filter { !$0.canHeadChapter } }

    /// Assembles the packet.
    ///
    /// - Parameters:
    ///   - groups: `(key, label, category, repository, lotAsPrinted, resolution, documents)`
    ///     per archival group — the resolution whole, never pre-reduced to its NAID, the
    ///     count DERIVED from the documents so the roster and the headline cannot disagree
    ///     (v1.2), and the lot AS PRINTED riding along because the claimants lookup folds
    ///     the raw citation itself and the display label is not that (2.0).
    ///   - documentYears: each document's year where known, for the A4 date test.
    ///   - citedFiles: each document's cited file number and year, for the A6 substitute lookup.
    ///     One entry per document, carrying `nil` where the note named no file — passing the nils
    ///     is what keeps the chapter's denominator honest. The year is load-bearing rather than
    ///     incidental: it is what separates a 1906–1910 case number from a dotless decimal class.
    ///   - unresolvedLotCount: lot citations that reached no series.
    ///   - unresolvedDocumentCount: documents whose citation reached no series at all.
    ///   - researchQuestion: the project's, for D8's seed.
    ///   - table: the curated repository facts. Defaults to the shipping (empty) table.
    ///   - facts: the series-facts lookup; injected so tests drive the real rules.
    static func build(
        groups: [(key: String, label: String, category: SourceProvenanceCategory?,
                  repository: String?, lotAsPrinted: String?,
                  resolution: ArchivalResolution?,
                  documents: [Group.DocumentRef])],
        documentYears: [Int?],
        citedFiles: [MandatorySubstitutes.CitedFile] = [],
        unresolvedLotCount: Int,
        unresolvedDocumentCount: Int,
        researchQuestion: String?,
        table: RepositoryFactTable = .current,
        facts: (String) -> SeriesFactsIndex.Facts? = { SeriesFactsIndexStore.shared?.facts(forNaId: $0) },
        substitutes: ([MandatorySubstitutes.CitedFile]) -> MandatorySubstitutes = {
            MandatorySubstitutes.build(citedFiles: $0)
        },
        references: [(key: String, form: Target.Form, label: String,
                      repository: String?, lotAsPrinted: String?,
                      seedings: [RefSeeding])] = [],
        referenceCoverage: ReferenceCoverage = .init(documentsWithReferences: 0,
                                                     documentsScanned: 0),
        claimants: (String) -> [LotClaimant]? = {
            LotClaimantsIndexStore.shared?.claimants(forRawLot: $0)
        }
    ) -> TripPacketModel {
        let built = groups.map { group in
            Group(id: group.key,
                  label: group.label,
                  facility: ResearchFacilityResolver.facility(
                      naId: group.resolution?.naId, category: group.category,
                      repository: group.repository, facts: facts),
                  documentCount: group.documents.count,
                  facts: group.repository.flatMap { table.row(for: $0) },
                  category: group.category,
                  resolution: group.resolution,
                  seriesYears: group.resolution.flatMap { facts($0.naId)?.years },
                  documents: group.documents)
        }
        .sorted { $0.documentCount != $1.documentCount
            ? $0.documentCount > $1.documentCount : $0.id < $1.id }

        // The triage keys on NAIDs; the display names ride beside them so the plan-level
        // line can say which series is closed rather than pointing at a number (v1.2).
        var countsByNaId: [String: Int] = [:]
        var titlesByNaId: [String: String] = [:]
        for group in groups {
            guard let resolution = group.resolution else { continue }
            countsByNaId[resolution.naId, default: 0] += group.documents.count
            titlesByNaId[resolution.naId] = resolution.displaySeriesTitle ?? resolution.title
        }

        // ── Target assembly (2.0). Both channels land under the same claim-free keys: a
        // drawn-from group whose builder key matches a reference group's key becomes ONE
        // target with both claims itemized inside it — never a summed count.
        //
        // The claimants lookup needs the lot AS PRINTED (`LotClaimantsIndexStore` folds it
        // itself), which the display label is not — so it rides the tuple, keyed back here.
        let lotAsPrintedByKey = Dictionary(
            groups.map { ($0.key, $0.lotAsPrinted) },
            uniquingKeysWith: { first, _ in first })
        var targets: [Target] = []
        var targetIndexByKey: [String: Int] = [:]
        for group in built {
            let form: Target.Form
            switch group.category {
            case .centralDecimalFile, .centralForeignPolicyFile:
                form = group.id.hasPrefix("class|") ? .decimalClass : .raw
            case .lotFile: form = .lotFile
            case .unrecognized, nil: form = group.id.hasPrefix("r|") ? .raw : .collection
            default: form = .collection
            }
            targetIndexByKey[group.id] = targets.count
            targets.append(Target(
                key: group.id, form: form, label: group.label,
                facility: group.facility, category: group.category,
                facts: group.facts,
                resolution: group.resolution, seriesYears: group.seriesYears,
                drawnFrom: group.documents, pointedAt: [],
                restriction: Self.restriction(
                    form: form, resolution: group.resolution,
                    lotAsPrinted: lotAsPrintedByKey[group.id] ?? nil,
                    facts: facts, claimants: claimants)))
        }
        for reference in references {
            if let index = targetIndexByKey[reference.key] {
                let existing = targets[index]
                targets[index] = Target(
                    key: existing.key, form: existing.form, label: existing.label,
                    facility: existing.facility, category: existing.category,
                    facts: existing.facts,
                    resolution: existing.resolution, seriesYears: existing.seriesYears,
                    drawnFrom: existing.drawnFrom,
                    pointedAt: reference.seedings,
                    restriction: existing.restriction)
                continue
            }
            // A pointed-at-only target: FRUS cites it and never printed from it — the
            // "beyond FRUS" case the channel exists for. Lots resolve through the same
            // offline route the drawn-from channel uses.
            let resolution = reference.form == .lotFile
                ? reference.lotAsPrinted.flatMap { ArchivalResolver.documentResolution(lotFile: $0) }
                : nil
            let category: SourceProvenanceCategory? =
                reference.form == .lotFile ? .lotFile : .presidentialLibrary
            targetIndexByKey[reference.key] = targets.count
            targets.append(Target(
                key: reference.key, form: reference.form, label: reference.label,
                facility: ResearchFacilityResolver.facility(
                    naId: resolution?.naId, category: category,
                    repository: reference.repository, facts: facts),
                category: category,
                facts: reference.repository.flatMap { table.row(for: $0) },
                resolution: resolution,
                seriesYears: resolution.flatMap { facts($0.naId)?.years },
                drawnFrom: [],
                pointedAt: reference.seedings,
                restriction: Self.restriction(
                    form: reference.form, resolution: resolution,
                    lotAsPrinted: reference.lotAsPrinted,
                    facts: facts, claimants: claimants)))
        }
        // Facility order first (the artifact groups by repository), label second — stable
        // and deterministic, since Phase 1 has no user tiers yet.
        targets.sort {
            let left = $0.facility.chapterHeading ?? "\u{FFFF}"
            let right = $1.facility.chapterHeading ?? "\u{FFFF}"
            if left != right { return left < right }
            return $0.label < $1.label
        }

        _ = unresolvedLotCount

        // ch1's A4 date test left with its chapter (owner: dropped); the years' surviving job
        // is the coverage report's empty-refs explainer.
        let knownYears = documentYears.compactMap(\.self)
        let predates1946 = !knownYears.isEmpty && knownYears.allSatisfy { $0 < 1946 }

        return TripPacketModel(
            groups: built,
            targets: targets,
            triage: .build(documentCountsByNaId: countsByNaId,
                           seriesTitles: titlesByNaId,
                           unresolvedDocumentCount: unresolvedDocumentCount, facts: facts),
            substitutes: substitutes(citedFiles),
            referenceCoverage: referenceCoverage,
            seededSpanPredates1946: predates1946,
            topicSentence: .seeded(from: researchQuestion))
    }

    /// A3's four-field records line, shared by ``Group`` and ``Target`` so no surface can
    /// compose the same fields differently.
    static func recordsLine(resolution: ArchivalResolution?, seriesYears: String?) -> String? {
        guard let resolution else { return nil }
        var parts: [String] = []
        if let rg = resolution.recordGroup { parts.append("RG \(rg)") }
        let entries = resolution.seriesHmsMlrEntryNumbers ?? resolution.hmsMlrEntryNumbers
        if let entries, !entries.isEmpty {
            parts.append("Entry \(entries.joined(separator: ", "))")
        }
        parts.append(resolution.displaySeriesTitle ?? resolution.title)
        parts.append("NAID \(resolution.seriesNaId ?? resolution.naId)")
        if let seriesYears { parts.append(seriesYears) }
        return parts.joined(separator: " · ")
    }

    /// The claimant-aware restriction line for a lot target (§3a), or the resolved series'
    /// own status for anything else that resolved.
    ///
    /// Rejected renderings, recorded so they stay rejected: *most-severe-across-claimants
    /// presented as the lot's status* invents certainty; *unanimity-or-silence* goes quiet on
    /// most divided lots; *single-pick* (the pre-Phase-1 behavior) printed one claimant's
    /// status as if it were the lot's. This states the worst COVERED status, names its
    /// series, and counts the unmeasured.
    static func restriction(
        form: Target.Form,
        resolution: ArchivalResolution?,
        lotAsPrinted: String?,
        facts: (String) -> SeriesFactsIndex.Facts?,
        claimants: (String) -> [LotClaimant]?
    ) -> TargetRestriction? {
        if form == .lotFile, let lotAsPrinted,
           let all = claimants(lotAsPrinted), !all.isEmpty {
            var measured: [(title: String, status: String, severity: RestrictionSeverity)] = []
            var unmeasured = 0
            for claimant in all {
                if let status = facts(claimant.naId)?.accessStatus, !status.isEmpty {
                    measured.append((claimant.title, status,
                                     RestrictionSeverity.from(accessStatus: status)))
                } else {
                    unmeasured += 1
                }
            }
            guard let worst = measured.min(by: { $0.severity < $1.severity }) else {
                // Nothing measured at all: only worth a line when the lot is divided,
                // because "several series, none measured" is itself the question.
                return all.count > 1
                    ? TargetRestriction(worstCoveredStatus: "",
                                        worstSeverity: .unknown,
                                        claimantSeriesTitle: nil,
                                        claimantCount: all.count,
                                        unmeasuredClaimantCount: unmeasured)
                    : nil
            }
            return TargetRestriction(worstCoveredStatus: worst.status,
                                     worstSeverity: worst.severity,
                                     claimantSeriesTitle: worst.title,
                                     claimantCount: all.count,
                                     unmeasuredClaimantCount: unmeasured)
        }
        // Non-lot (or claimant-less): the resolved series' own status, when measured.
        guard let resolution,
              let status = facts(resolution.seriesNaId ?? resolution.naId)?.accessStatus,
              !status.isEmpty else { return nil }
        return TargetRestriction(worstCoveredStatus: status,
                                 worstSeverity: RestrictionSeverity.from(accessStatus: status),
                                 claimantSeriesTitle: nil,
                                 claimantCount: 1,
                                 unmeasuredClaimantCount: 0)
    }
}
