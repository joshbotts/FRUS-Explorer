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
        defaultValue: "[Describe your research topic in one or two sentences — narrow and specific. NARA asks for a succinct description, never \"everything you have\".]")

    /// Seeds from a project's research question.
    static func seeded(from researchQuestion: String?) -> TripPacketTopicSentence {
        TripPacketTopicSentence(seed: researchQuestion, edited: nil)
    }
}

// MARK: - TripPacketModel

/// Everything the trip packet knows, assembled from data the app already holds (#830 T-1).
///
/// ## What this is, and what it refuses to be
/// A pure aggregation over `CollectionGeneratedBlocks.archivalSourceRows`' grouping key, which
/// already carries repository / record group / lot / series. It computes: where each group is
/// served (``ResearchFacilityResolver``), what is restricted (``RestrictionTriage``), which
/// advance-notice criteria fire (``AdvanceNoticeFlags``), and the checklist those produce
/// (``TripChecklist``).
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

    /// The groups, most-cited first.
    let groups: [Group]
    /// Access triage across the whole reading list.
    let triage: RestrictionTriage
    /// Records that must be read online or on film instead of pulled (A6).
    let substitutes: MandatorySubstitutes
    /// Which A4 criteria fired.
    let flags: AdvanceNoticeFlags
    /// The pre-arrival checklist.
    let checklist: TripChecklist
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
    ///   - groups: `(key, label, category, repository, resolution, documents)` per archival
    ///     group, as `archivalSourceRows` already computes them — the resolution whole,
    ///     never pre-reduced to its NAID, and the count DERIVED from the documents so the
    ///     roster and the headline cannot disagree (v1.2).
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
                  repository: String?, resolution: ArchivalResolution?,
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

        // The triage keys on NAIDs; the display names ride beside them so chapter 5 can
        // say which series is closed rather than pointing at a number (v1.2).
        var countsByNaId: [String: Int] = [:]
        var titlesByNaId: [String: String] = [:]
        for group in groups {
            guard let resolution = group.resolution else { continue }
            countsByNaId[resolution.naId, default: 0] += group.documents.count
            titlesByNaId[resolution.naId] = resolution.displaySeriesTitle ?? resolution.title
        }

        let flags = AdvanceNoticeFlags.evaluate(documentYears: documentYears,
                                                unresolvedLotCount: unresolvedLotCount)
        return TripPacketModel(
            groups: built,
            triage: .build(documentCountsByNaId: countsByNaId,
                           seriesTitles: titlesByNaId,
                           unresolvedDocumentCount: unresolvedDocumentCount, facts: facts),
            substitutes: substitutes(citedFiles),
            flags: flags,
            checklist: .build(flags: flags),
            topicSentence: .seeded(from: researchQuestion))
    }
}
