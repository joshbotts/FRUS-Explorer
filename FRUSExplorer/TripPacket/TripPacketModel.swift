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
/// ``RepositoryFactTable``, which ships with zero rows — so a chapter for a presidential library
/// renders its heading and its confirm-before-you-travel prompt (D11) and nothing else. The packet
/// builds, and the gap is visible rather than filled with a guess.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
struct TripPacketModel: Equatable, Sendable {

    /// One archival group the reading list touches.
    struct Group: Equatable, Sendable, Identifiable {
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

        /// Whether this group can head a packet chapter (D3).
        var canHeadChapter: Bool { facility.chapterHeading != nil }
    }

    /// The groups, most-cited first.
    let groups: [Group]
    /// Access triage across the whole reading list.
    let triage: RestrictionTriage
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
    ///   - groups: `(key, label, category, repository, seriesNaId, documentCount)` per archival
    ///     group, as `archivalSourceRows` already computes them.
    ///   - documentYears: each document's year where known, for the A4 date test.
    ///   - unresolvedLotCount: lot citations that reached no series.
    ///   - unresolvedDocumentCount: documents whose citation reached no series at all.
    ///   - researchQuestion: the project's, for D8's seed.
    ///   - table: the curated repository facts. Defaults to the shipping (empty) table.
    ///   - facts: the series-facts lookup; injected so tests drive the real rules.
    static func build(
        groups: [(key: String, label: String, category: SourceProvenanceCategory?,
                  repository: String?, seriesNaId: String?, documentCount: Int)],
        documentYears: [Int?],
        unresolvedLotCount: Int,
        unresolvedDocumentCount: Int,
        researchQuestion: String?,
        table: RepositoryFactTable = .current,
        facts: (String) -> SeriesFactsIndex.Facts? = { SeriesFactsIndexStore.shared?.facts(forNaId: $0) }
    ) -> TripPacketModel {
        let built = groups.map { group in
            Group(id: group.key,
                  label: group.label,
                  facility: ResearchFacilityResolver.facility(
                      naId: group.seriesNaId, category: group.category,
                      repository: group.repository, facts: facts),
                  documentCount: group.documentCount,
                  facts: group.repository.flatMap { table.row(for: $0) })
        }
        .sorted { $0.documentCount != $1.documentCount
            ? $0.documentCount > $1.documentCount : $0.id < $1.id }

        var countsByNaId: [String: Int] = [:]
        for group in groups {
            guard let naId = group.seriesNaId else { continue }
            countsByNaId[naId, default: 0] += group.documentCount
        }

        let flags = AdvanceNoticeFlags.evaluate(documentYears: documentYears,
                                                unresolvedLotCount: unresolvedLotCount)
        return TripPacketModel(
            groups: built,
            triage: .build(documentCountsByNaId: countsByNaId,
                           unresolvedDocumentCount: unresolvedDocumentCount, facts: facts),
            flags: flags,
            checklist: .build(flags: flags),
            topicSentence: .seeded(from: researchQuestion))
    }
}
