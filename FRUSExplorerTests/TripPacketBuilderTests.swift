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

/// Pins the documents → packet bridge (#830 T-2; two channels since Archive Visits Phase 1).
///
/// Drives a stub `TripPacketReferenceDataSource`, because that protocol IS the seam the
/// scope doc names ("both entry points feed the same aggregation") and a test that bypassed it
/// would prove nothing about the surfaces that will use it.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
///   2.0 — Archive Visits Phase 1: the stub grows the refs-channel query; the shared-key test
///          becomes the form-aware key tests (§2b — the packet's keys now deliberately diverge
///          from the Sources block's document-grain key); the A4 flag tests left with their
///          chapter
///   2.1 — #1392 review: a central-file designation is the file number alone
@Suite("Trip packet builder (#830 T-2)")
struct TripPacketBuilderTests {

    /// A stub vending exactly what the builder consumes.
    @MainActor
    private struct Stub: TripPacketReferenceDataSource {
        var sources: [CollectionGeneratedBlocks.SourceRecord] = []
        var dates: [String: DocumentDateMetadata] = [:]
        var citations: [String: [ExternalCitation]] = [:]

        func citation(volumeId: String, documentId: String) -> String { "\(volumeId)/\(documentId)" }
        func dateMetadata(for documents: [(volumeId: String, documentId: String)])
            async -> [String: DocumentDateMetadata] { dates }
        func documentSources(for documents: [(volumeId: String, documentId: String)])
            async -> [CollectionGeneratedBlocks.SourceRecord] { sources }
        func externalCitations(for documents: [(volumeId: String, documentId: String)])
            async -> [String: [ExternalCitation]] { citations }
        func archivalResolution(recordGroup: String?, lotFile: String?)
            -> CollectionGeneratedBlocks.ArchivalLink? { nil }
        func personMentions(for documents: [(volumeId: String, documentId: String)])
            async -> [CollectionGeneratedBlocks.PersonMention] { [] }
        func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] { [] }
    }

    private func record(_ volume: String, _ document: String, era: String?,
                        repository: String? = nil, lot: String? = nil,
                        series: String? = nil, rg: String? = "59",
                        rawText: String = "note")
        -> CollectionGeneratedBlocks.SourceRecord {
        .init(volumeId: volume, documentId: document, repository: repository,
              recordGroup: rg, lotFile: lot, seriesName: series,
              rawText: rawText, citationEra: era)
    }

    private func date(_ iso: String) -> DocumentDateMetadata {
        DocumentDateMetadata(dateISO: iso, dateISOMax: nil, precision: nil, certainty: nil)
    }

    /// The parser's own classification decides the facility — never a second classifier derived
    /// from the parsed fields.
    @MainActor
    @Test("The citation era becomes the provenance category, and places the group")
    func citationEraPlacesTheGroup() async {
        let stub = Stub(sources: [record("v1", "d1", era: "decimal", series: "762.00",
                                         rawText: "Department of State, Central Files, 762.00/2-148")])
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
        let stub = Stub(sources: [record("v1", "d1", era: nil, rg: nil)])
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

    /// The indexed dates feed the coverage report's pre-1946 flag — the wiring, driven
    /// through the real builder (the rule itself is pinned in `TripPacketModelTests`).
    @MainActor
    @Test("Document years reach the pre-1946 flag")
    func documentYearsReachThePreWarFlag() async {
        let stub = Stub(sources: [record("v1", "d1", era: "decimal"),
                                  record("v1", "d2", era: "decimal")],
                        dates: ["v1/d1": date("1914-06-24"), "v1/d2": date("1915-02-21")])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2")], researchQuestion: nil, dataSource: stub)
        #expect(model.seededSpanPredates1946)
    }

    /// An unresolved lot is still PLACED at College Park, because not knowing its series is
    /// not the same as not knowing its building.
    ///
    /// **The fixture lot is synthetic on purpose.** This first used `71 D 483`, checked against
    /// `central-files-index.json` with a Python string compare that found no match — but the app
    /// resolves it to NAID 56190687, because `lotFile(forRawLot:)` applies the shared
    /// fold-normalisation that compare did not. A real lot number is a fixture whose truth depends
    /// on a bundled artifact and on tokenisation; a synthetic one cannot resolve by construction.
    @MainActor
    @Test("An unresolved lot is still placed")
    func unresolvedLotIsPlaced() async {
        let stub = Stub(sources: [record("v1", "d1", era: "lot_file", lot: "99 Z 999")])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1")], researchQuestion: nil, dataSource: stub)
        #expect(model.groups[0].canHeadChapter, """
            An unresolved lot was filed as unplaceable. It is an RG 59 record: its series is \
            unknown, its building is not.
            """)
        #expect(model.groups[0].resolution == nil)
    }

    // MARK: - Form-aware keys (§2b)

    /// Central files key on the CLASS, not the per-document file number: the Sources block's
    /// key rides the file identifier and minted one "target" per document for the corpus's
    /// commonest citation form.
    @MainActor
    @Test("Decimal citations fold to one class target")
    func decimalCitationsFoldToTheClass() async {
        let stub = Stub(sources: [
            record("v1", "d1", era: "decimal",
                   rawText: "Department of State, Central Files, 762.00/2-148"),
            record("v1", "d2", era: "decimal",
                   rawText: "Department of State, Central Files, 762.00/3-548"),
        ])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2")], researchQuestion: nil, dataSource: stub)
        #expect(model.targets.count == 1, """
            Two file numbers in one class must be ONE target — the class is what a researcher \
            consults; the file number is the seeding's detail.
            """)
        #expect(model.targets[0].key == "class|762.00")
        #expect(model.targets[0].form == .decimalClass)
        #expect(model.targets[0].drawnFrom.count == 2)
    }

    /// Lots fold by `lotFileNorm`, so the corpus's spelling variants land on one target —
    /// the same normalizer `external_citations.lot_file_norm` stores.
    @MainActor
    @Test("Lot spelling variants fold to one normalized target")
    func lotVariantsFoldByNorm() async {
        let stub = Stub(sources: [
            record("v1", "d1", era: "lot_file", lot: "64 D 199"),
            record("v1", "d2", era: "lot_file", lot: "64D199"),
            record("v1", "d3", era: "lot_file", lot: "64-D-199"),
        ])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2"), ("v1", "d3")],
            researchQuestion: nil, dataSource: stub)
        #expect(model.targets.count == 1, "three spellings of one lot must be one target")
        #expect(model.targets[0].key == "lot|64D199")
        #expect(model.targets[0].form == .lotFile)
        #expect(model.targets[0].drawnFrom.count == 3)
    }

    /// The builder's key prefixes and the model's form detection are two switch statements
    /// that must agree — this is the round trip.
    @MainActor
    @Test("targetKey and the model's form detection agree for every form")
    func targetKeyRoundTripsThroughFormDetection() async {
        let stub = Stub(sources: [
            record("v1", "d1", era: "decimal",
                   rawText: "Department of State, Central Files, 611.51/4-750"),
            record("v1", "d2", era: "lot_file", lot: "60 D 627"),
            record("v1", "d3", era: "structured", repository: "Truman Library",
                   series: "President's Secretary's Files", rg: nil),
            record("v1", "d4", era: nil, rg: nil),
        ])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2"), ("v1", "d3"), ("v1", "d4")],
            researchQuestion: nil, dataSource: stub)
        let formsByKey = Dictionary(uniqueKeysWithValues: model.targets.map { ($0.key, $0.form) })
        #expect(formsByKey["class|611.51"] == .decimalClass)
        #expect(formsByKey["lot|60D627"] == .lotFile)
        #expect(formsByKey["coll|Truman Library|President's Secretary's Files"] == .collection)
        #expect(formsByKey["r|note"] == .raw)
    }

    // MARK: - The refs channel

    /// The pointed-at channel: class citations are filtered (the anchor #784 defers), lot
    /// citations merge onto the drawn-from target by the shared norm, and the coverage pair
    /// counts documents with a RELEVANT reference over documents scanned.
    @MainActor
    @Test("The refs channel filters class anchors and merges lots by norm")
    func refsChannelFiltersAndMerges() async {
        let lotCitation = ExternalCitation(
            anchor: "lotFile", repository: "Department of State", collection: nil,
            lotFile: "64 D 199", lotFileNorm: "64D199", fileId: "CF 1", inherited: false,
            rawText: "Not printed. (Lot 64 D 199, CF 1)", noteOrdinal: 2, noteLabel: "6")
        let classCitation = ExternalCitation(
            anchor: "centralFileClass", repository: "Department of State", collection: nil,
            lotFile: nil, lotFileNorm: nil, fileId: nil, inherited: false,
            rawText: "740.00119 Control (Germany)/6-2447", noteOrdinal: 3,
            decimalClass: "740.00119", noteLabel: "7")
        let stub = Stub(
            sources: [record("v1", "d1", era: "lot_file", lot: "64D199")],
            citations: ["v1/d1": [lotCitation],
                        "v1/d2": [classCitation]])
        let model = await TripPacketBuilder.build(
            documents: [("v1", "d1"), ("v1", "d2")], researchQuestion: nil, dataSource: stub)
        // One target: the drawn-from lot, with the footnote merged onto it by norm.
        #expect(model.targets.count == 1, """
            The class citation must not mint a target (#784 defers the class anchor), and \
            the lot citation must merge onto the drawn-from target, not duplicate it.
            """)
        #expect(model.targets[0].drawnFrom.count == 1)
        #expect(model.targets[0].pointedAt.count == 1)
        #expect(model.targets[0].pointedAt[0].rawText == "Not printed. (Lot 64 D 199, CF 1)")
        #expect(model.targets[0].pointedAt[0].footnoteLabel == "6", """
            The packet must cite the number the VOLUME printed, stored beside the ordinal at \
            harvest (#1322). This stub's note sits at ordinal 2 and prints "6", so the old \
            `noteOrdinal + 1` gives 3 and `+ 2` gives 4 — both wrong, and both plausible.
            """)
        // d2's only reference was a class citation — filtered, so it does NOT count as a
        // document with references; both documents were scanned.
        #expect(model.referenceCoverage.documentsWithReferences == 1)
        #expect(model.referenceCoverage.documentsScanned == 2)
    }

    /// `referenceKey` speaks the same vocabulary as `targetKey` — the merge above depends
    /// on it, so the mapping is pinned directly too.
    @MainActor
    @Test("referenceKey mints the same key vocabulary")
    func referenceKeyMatchesVocabulary() {
        let lot = ExternalCitation(
            anchor: "lotFile", repository: "Department of State", collection: nil,
            lotFile: "60 D 627", lotFileNorm: "60D627", fileId: nil, inherited: false,
            rawText: "x", noteOrdinal: 0)
        let lotKey = TripPacketBuilder.referenceKey(for: lot)
        #expect(lotKey.key == "lot|60D627")
        #expect(lotKey.form == .lotFile)
        #expect(lotKey.lotAsPrinted == "60 D 627")

        let library = ExternalCitation(
            anchor: "presidentialLibrary", repository: "Truman Library",
            collection: "President's Secretary's Files", lotFile: nil, lotFileNorm: nil,
            fileId: nil, inherited: false, rawText: "x", noteOrdinal: 0)
        let libraryKey = TripPacketBuilder.referenceKey(for: library)
        #expect(libraryKey.key == "coll|Truman Library|President's Secretary's Files")
        #expect(libraryKey.form == .collection)
    }

    // MARK: - Central-file designations (#1392 review)

    /// A central-file designation is the file number alone, because the packet continues it
    /// mid-sentence — on the drawn-from line and inside the citation appendix's NARA template,
    /// which printed "file 611.93/12–854. Secret., …".
    ///
    /// Every note is real corpus text, parsed by the real `SourceNoteParser`, one fixture per
    /// branch of `centralFileDesignation(_:)` and one per shape it must leave alone:
    ///
    /// - the classification-marking cut, alone (a subject-numeric designator has no slash), and
    ///   taking precedence (DEF 1-4 INDIA's remark holds a slash, "S/S", and a later abbreviation
    ///   a slash-only rule would cut at, leaving "…Drafted in S/S by Grant G");
    /// - the after-the-last-slash cut, alone ("Drafted by" and "Personal and Secret" are not
    ///   markings to the frus-sources test);
    /// - the closing period with no boundary at all;
    /// - three shapes a plain first-sentence cut would break: an abbreviation before the item
    ///   ("E. W."), a first slash inside the infix ("Douglas/52 … Co. Inc./5"), and a personnel
    ///   file with no slash and no marking ("J. Leighton").
    @MainActor
    @Test("A central-file designation keeps its file number and drops the note's next sentences")
    func centralFileDesignationIsTheFileNumber() {
        let parser = SourceNoteParser()
        let cases: [(note: String, designation: String)] = [
            // frus1964-68v01/d123 — the marking cut, alone.
            ("Source: Department of State, Central Files, POL 15 VIET S. Secret; Limdis. "
                + "Repeated to CINCPAC.", "POL 15 VIET S"),
            // frus1955-57v01/d51 — the commonest tail: 882 designations run on "Secret. Drafted".
            ("Source: Department of State, Central Files, 751G.00/3–155. Secret. Drafted by "
                + "Young and Kidder.", "751G.00/3–155"),
            // frus1961-63v19/d303 — the marking cut takes precedence.
            ("Source: Department of State, Central Files, DEF 1-4 INDIA. Secret. Drafted in S/S "
                + "by Grant G. Hilliker, cleared by McGeorge Bundy, and approved by Hilliker. "
                + "Repeated to Karachi and New Delhi.", "DEF 1-4 INDIA"),
            // frus1955-57v01/d168 — the after-the-slash cut, alone.
            ("Source: Department of State, Central Files, 751G.00/5–355. Drafted by Young and "
                + "cleared by Robertson, MacArthur, Dulles, and with Tyler and Murphy in "
                + "substance. Sent also priority to Paris.", "751G.00/5–355"),
            // frus1955-57v01/d27 — "Personal and Secret" opens with no marking level.
            ("Source: Department of State, Central Files, 751G.00/2–155. Personal and Secret.",
             "751G.00/2–155"),
            // frus1955-57v03/d166 — only the closing period.
            ("Source: Department of State, Central Files, 761.00/4–956.", "761.00/4–956"),
            // frus1942v02/d392, frus1938v01/d367, frus1946v09/d711 — left whole.
            ("740.0011 (E. W.)/11–742: Telegram", "740.0011 (E. W.)/11–742"),
            ("711.00111 Lic. Douglas/52 Aircraft Co. Inc./5: Telegram",
             "711.00111 Lic. Douglas/52 Aircraft Co. Inc./5"),
            ("123 Stuart, J. Leighton: Telegram", "123 Stuart, J. Leighton"),
        ]
        for (note, designation) in cases {
            let parsed = parser.parse(note)
            // The parser's identifier must still begin with the designation (a fixture-drift
            // check); since #1460 it is usually the designation itself, so the cut's own teeth
            // are the raw shape held after this loop.
            let raw = TripPacketBuilder.centralFileIdentifier(from: parsed)
            #expect(raw?.hasPrefix(designation) == true,
                    "fixture drift: the parser no longer reads this as a central file: \(note)")
            #expect(TripPacketBuilder.fileDesignation(from: parsed) == designation, """
                expected "\(designation)", got "\(TripPacketBuilder.fileDesignation(from: parsed) ?? "nil")" \
                from the parser's "\(raw ?? "nil")"
                """)
        }
        // Since #1460 the parser itself stops at the citation sentence's full stop, so its raw
        // identifier no longer carries the marking; the builder's cut stays as the second line,
        // and is held on the raw shape the parser used to store.
        #expect(TripPacketBuilder.centralFileIdentifier(from: parser.parse(cases[1].note))
                == "751G.00/3–155")
        #expect(TripPacketBuilder.fileDesignation(from: .centralFiles(
            recordGroup: "RG-59",
            fileIdentifier: "751G.00/3–155. Secret. Drafted by Young and Kidder.")) == "751G.00/3–155")
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
