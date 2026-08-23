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

// MARK: - TripPacketBuilderTests

/// Pins the documents → packet bridge (#830 T-2).
///
/// Drives a stub `CollectionGeneratedBlockDataSource`, because that protocol IS the seam the
/// scope doc names ("both entry points feed the same aggregation") and a test that bypassed it
/// would prove nothing about the surfaces that will use it.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
@Suite("Trip packet builder (#830 T-2)")
struct TripPacketBuilderTests {

    /// A stub vending exactly what the builder consumes.
    @MainActor
    private struct Stub: CollectionGeneratedBlockDataSource {
        var sources: [CollectionGeneratedBlocks.SourceRecord] = []
        var dates: [String: DocumentDateMetadata] = [:]

        func citation(volumeId: String, documentId: String) -> String { "\(volumeId)/\(documentId)" }
        func dateMetadata(for documents: [(volumeId: String, documentId: String)])
            async -> [String: DocumentDateMetadata] { dates }
        func documentSources(for documents: [(volumeId: String, documentId: String)])
            async -> [CollectionGeneratedBlocks.SourceRecord] { sources }
        func archivalResolution(recordGroup: String?, lotFile: String?)
            -> CollectionGeneratedBlocks.ArchivalLink? { nil }
        func personMentions(for documents: [(volumeId: String, documentId: String)])
            async -> [CollectionGeneratedBlocks.PersonMention] { [] }
        func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] { [] }
    }

    private func record(_ volume: String, _ document: String, era: String?,
                        repository: String? = nil, lot: String? = nil,
                        series: String? = nil, rg: String? = "59")
        -> CollectionGeneratedBlocks.SourceRecord {
        .init(volumeId: volume, documentId: document, repository: repository,
              recordGroup: rg, lotFile: lot, seriesName: series,
              rawText: "note", citationEra: era)
    }

    private func date(_ iso: String) -> DocumentDateMetadata {
        DocumentDateMetadata(dateISO: iso, dateISOMax: nil, precision: nil, certainty: nil)
    }

    /// The parser's own classification decides the facility — never a second classifier derived
    /// from the parsed fields.
    @MainActor
    @Test("The citation era becomes the provenance category, and places the group")
    func citationEraPlacesTheGroup() async {
        let stub = Stub(sources: [record("v1", "d1", era: "decimal", series: "762.00")])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1")], researchQuestion: nil, dataSource: stub)
        #expect(model.groups.count == 1)
        #expect(model.groups[0].facility
            == .servedAt(facility: ResearchFacilityResolver.collegePark,
                         provenance: "Department of State"))
        #expect(model.groups[0].canHeadChapter)
    }

    /// A record with no `citation_era` — legacy rows, and rows the parser could not classify —
    /// must not crash or be silently placed. It has no category, so it falls to `unknown`.
    @MainActor
    @Test("A record with no citation era is unplaced, not misplaced")
    func missingCitationEraIsUnplaced() async {
        let stub = Stub(sources: [record("v1", "d1", era: nil)])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1")], researchQuestion: nil, dataSource: stub)
        #expect(model.groups[0].facility == .unknown)
        #expect(model.needingConfirmation.count == 1, """
            An unclassifiable citation must be REPORTED as needing confirmation, not quietly \
            placed at whichever facility happens to be commonest.
            """)
    }

    /// Documents with no indexed source note are counted, never dropped.
    @MainActor
    @Test("Documents with no source note are reported as unresolved")
    func documentsWithoutSourceNotesAreCounted() async {
        let stub = Stub(sources: [record("v1", "d1", era: "decimal")])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2"), ("v1", "d3")],
            researchQuestion: nil, dataSource: stub)
        #expect(model.triage.unresolvedDocumentCount == 2, """
            Two of three documents have no indexed source note and must be reported. A packet \
            silently covering part of a reading list reads as a clean bill of health for the rest.
            """)
    }

    /// A4's date test reads the indexed dates.
    @MainActor
    @Test("Document years drive the A4 date flag")
    func documentYearsDriveTheDateFlag() async {
        let stub = Stub(sources: [record("v1", "d1", era: "decimal"),
                                  record("v1", "d2", era: "decimal")],
                        dates: ["v1/d1": date("1948-06-24"), "v1/d2": date("1972-02-21")])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2")], researchQuestion: nil, dataSource: stub)
        #expect(model.flags.flags.contains(.recentRecords))
        #expect(model.flags.recentDocumentCount == 1)
    }

    /// An unresolved lot raises A4's lot flag — and is still PLACED at College Park, because not
    /// knowing its series is not the same as not knowing its building.
    ///
    /// **The fixture lot is synthetic on purpose.** This first used `71 D 483`, checked against
    /// `central-files-index.json` with a Python string compare that found no match — but the app
    /// resolves it to NAID 56190687, because `lotFile(forRawLot:)` applies the shared
    /// fold-normalisation that compare did not. A real lot number is a fixture whose truth depends
    /// on a bundled artifact and on tokenisation; a synthetic one cannot resolve by construction.
    @MainActor
    @Test("An unresolved lot flags A4 but is still placed")
    func unresolvedLotFlagsButIsPlaced() async {
        let stub = Stub(sources: [record("v1", "d1", era: "lot_file", lot: "99 Z 999")])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1")], researchQuestion: nil, dataSource: stub)
        #expect(model.flags.flags.contains(.unresolvedLotCitations))
        #expect(model.groups[0].canHeadChapter, """
            An unresolved lot was filed as unplaceable. It is an RG 59 record: its series is \
            unknown, its building is not.
            """)
    }

    /// The packet groups the SAME way the Sources block does — by construction, not by agreement.
    @MainActor
    @Test("Grouping matches the collection Sources block")
    func groupingMatchesTheSourcesBlock() async {
        let a = record("v1", "d1", era: "lot_file", lot: "64 D 199")
        let b = record("v1", "d2", era: "lot_file", lot: "64 D 199")
        let c = record("v1", "d3", era: "lot_file", lot: "71 D 483")
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2"), ("v1", "d3")],
            researchQuestion: nil, dataSource: Stub(sources: [a, b, c]))
        #expect(model.groups.count == 2, "two distinct lots, two groups")
        #expect(model.groups[0].documentCount == 2, "the shared lot carries two documents")
        #expect(model.groups[0].id == CollectionGeneratedBlocks.tripPacketGroupKey(for: a), """
            The packet's group key differs from the Sources block's. They must be the same \
            function, or the two surfaces can disagree about which archives a project draws on.
            """)
    }

    /// D8: the research question reaches the topic sentence.
    @MainActor
    @Test("The project's research question seeds the topic sentence")
    func researchQuestionSeedsTheTopic() async {
        let model = await TripPacketBuilder.build(
            documents: [], researchQuestion: "US policy toward Berlin, 1948",
            dataSource: Stub())
        #expect(model.topicSentence.forExport == "US policy toward Berlin, 1948")
        #expect(!model.topicSentence.needsAttention)
    }
}
