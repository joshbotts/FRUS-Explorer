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
import Testing
@testable import FRUSExplorer

// MARK: - SourceExplorerProvenanceTests

/// P-1's per-row provenance rules, and the twin coverage that keeps them mounted on both platforms.
///
/// PV-3 badged the Source Explorer sections that are uniformly one tier and left three alone
/// because their tier is decided per row. This suite pins the three rules and the eight mounts.
///
/// Version history:
///   1.0 — P-1: initial implementation
@Suite("Source Explorer per-row provenance (P-1)")
struct SourceExplorerProvenanceTests {

    // MARK: Fixtures

    /// The shipped curated artifact, decoded the way `CuratedLotResolutionsTests` decodes it.
    private func loadCurated() throws -> CuratedLotResolutions {
        let url = try #require(
            Bundle(for: SourceExplorerProvenanceBundleToken.self).url(forResource: "curated-lot-resolutions",
                                              withExtension: "json")
                ?? Bundle.main.url(forResource: "curated-lot-resolutions", withExtension: "json"),
            "curated-lot-resolutions.json must be enrolled as a bundle resource")
        return try JSONDecoder().decode(CuratedLotResolutions.self, from: Data(contentsOf: url))
    }

    /// A citation carrying nothing but the anchor under test.
    private func citation(anchor: String) -> ExternalCitation {
        ExternalCitation(anchor: anchor, repository: nil, collection: nil, lotFile: nil,
                         lotFileNorm: nil, fileId: nil, inherited: false,
                         rawText: "raw", noteOrdinal: 1)
    }

    /// A source file, read from the repository root.
    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        // Without this a truncated or empty read makes every negative assertion below pass.
        #expect(text.count > 5_000, "\(path) read back as \(text.count) characters — moved or truncated?")
        return text
    }

    /// `text` with comment bodies removed, so a comment can neither satisfy a positive assertion
    /// nor break a negative one.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("//") ? "" : String(line)
            }
            .joined(separator: "\n")
    }

    /// Every member declaration that encloses an occurrence of `token`.
    ///
    /// Attributes each hit to the `var`/`func` it actually sits in, rather than slicing a window
    /// between markers — a window that overruns its declaration lets a chip mounted on a
    /// neighbouring section satisfy an assertion about this one.
    private static func enclosingMembers(of token: String, in text: String) -> [String] {
        var current = "<file scope>"
        var found: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: #"(?:var|func)\s+(\w+)"#, options: .regularExpression) {
                current = String(trimmed[range]).split(separator: " ").last.map(String.init) ?? current
            }
            if line.contains(token) { found.append(current) }
        }
        return found
    }

    private static let iOSTwin = "FRUSExplorer/SourceExplorer/SourceExplorerView.swift"
    private static let macTwin = "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"

    // MARK: The lot-file record group rule

    @Test("A curated record group is the catalogue's answer; an uncurated one is the volumes'")
    func lotRecordGroupSourceBranchesOnWhichLookupAnswered() {
        #expect(SourceExplorerProvenance.lotRecordGroupSource(curated: "RG-43") == .naraCatalog)
        #expect(SourceExplorerProvenance.lotRecordGroupSource(curated: "RG-59") == .naraCatalog)
        #expect(SourceExplorerProvenance.lotRecordGroupSource(curated: nil) == .frusText)
    }

    /// The rule cannot be written as a value comparison, and this is the row that proves it.
    ///
    /// `54D270` is curated, and curation's answer is `RG-59` — **exactly** what the parser's pure
    /// rule produces for a lot with no F-designator. An implementation that asked "does the curated
    /// value differ from the parsed one?" would call this row uncurated and badge it `.frusText`.
    @Test("54D270 is curated and its record group equals the parser's, so value comparison fails")
    func aValueComparisonWouldMisreadTheCuratedRow() throws {
        let curated = try loadCurated()
        let answer = try #require(curated.recordGroup(forRawLot: "54D270"),
                                  "54D270 is a curated lot in the shipped artifact")
        #expect(answer == "RG-59")
        #expect(SourceNoteParser.lotFileRecordGroup("54D270") == "RG-59")
        #expect(answer == SourceNoteParser.lotFileRecordGroup("54D270"),
                "the two producers agree here — which is why the branch may not compare them")
        #expect(SourceExplorerProvenance.lotRecordGroupSource(curated: answer) == .naraCatalog)
    }

    /// The single row where the value moves, kept beside the one above so both halves are pinned.
    @Test("M88 is the one curated lot whose record group differs from the parsed answer")
    func theOneRowWhereTheValueMoves() throws {
        let curated = try loadCurated()
        let answer = try #require(curated.recordGroup(forRawLot: "M88"))
        #expect(answer == "RG-43")
        #expect(SourceNoteParser.lotFileRecordGroup("M88") == "RG-59")
        #expect(SourceExplorerProvenance.lotRecordGroupSource(curated: answer) == .naraCatalog)
    }

    /// Measured, not asserted: how many curated rows a value comparison would misclassify.
    @Test("Every shipped curated lot answers, and all but one agree with the parser")
    func theWholeCuratedSetIsCatalogueSourced() throws {
        let curated = try loadCurated()
        var answered = 0
        var agreeWithParser = 0
        for lot in curated.lots {
            guard let rg = curated.recordGroup(forRawLot: lot.lotNumber) else { continue }
            answered += 1
            #expect(SourceExplorerProvenance.lotRecordGroupSource(curated: rg) == .naraCatalog)
            if rg == SourceNoteParser.lotFileRecordGroup(lot.lotNumber) { agreeWithParser += 1 }
        }
        #expect(answered == 20, "the shipped artifact answers for \(answered) lots")
        #expect(agreeWithParser == 19,
                "\(agreeWithParser) of \(answered) curated answers equal the parser's, so a value comparison would misclassify every one of them")
    }

    @Test("An uncurated lot falls back to the volumes' own rule")
    func anUncuratedLotIsFRUSText() throws {
        let curated = try loadCurated()
        #expect(curated.recordGroup(forRawLot: "58D5") == nil,
                "58D5 must stay uncurated for this test to mean anything")
        #expect(SourceExplorerProvenance.lotRecordGroupSource(
            curated: curated.recordGroup(forRawLot: "58D5")) == .frusText)
    }

    // MARK: The unprinted-pointer rule

    @Test("A central-file-class pointer is the schedule's; a lot or library pointer is FRUS's")
    func unprintedPointerBranchesOnTheAnchor() {
        #expect(SourceExplorerProvenance.unprintedPointerSource(
            for: citation(anchor: "centralFileClass")) == .stateDeptSchedule)
        #expect(SourceExplorerProvenance.unprintedPointerSource(
            for: citation(anchor: "lotFile")) == .frusText)
        #expect(SourceExplorerProvenance.unprintedPointerSource(
            for: citation(anchor: "presidentialLibrary")) == .frusText)
    }

    /// `anchor` is a `String`, so an unrecognised value is reachable in a way an enum would forbid.
    @Test("An unrecognised anchor falls to the volumes, not to the schedule")
    func anUnknownAnchorDefaultsToFRUSText() {
        #expect(SourceExplorerProvenance.unprintedPointerSource(
            for: citation(anchor: "somethingNobodyHasWrittenYet")) == .frusText)
    }

    // MARK: Reachability — neither branch is dead code

    /// Both anchor kinds occur in the shipped corpus artifact.
    ///
    /// **This proves the branch is reachable in principle, not that any given device has both.**
    /// The view reads the device's `external_citations` table, which holds only the volumes that
    /// reader downloaded; the artifact is corpus-wide evidence and its counts are not the table's.
    @Test("Both unprinted-pointer branches are reachable in the shipped corpus")
    func bothUnprintedBranchesAreReachable() throws {
        let url = try #require(
            Bundle(for: SourceExplorerProvenanceBundleToken.self).url(forResource: "external-citation-index",
                                              withExtension: "json")
                ?? Bundle.main.url(forResource: "external-citation-index", withExtension: "json"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let root = try #require(object as? [String: Any])
        let coverage = try #require(root["coverage"] as? [String: Any])
        let lot = (coverage["lotReferences"] as? Int) ?? 0
        let library = (coverage["libraryReferences"] as? Int) ?? 0
        let decimal = (coverage["decimalReferences"] as? Int) ?? 0
        #expect(lot + library > 0, "no lot or library references — the .frusText arm is unreachable")
        #expect(decimal > 0, "no decimal references — the .stateDeptSchedule arm is unreachable")
    }

    // MARK: Twin coverage

    /// Every mount, in both twins, attributed to the member it actually sits in.
    ///
    /// Set equality rather than `contains`: a chip that drifts into a neighbouring section fails,
    /// and a missing chip fails. The Mac lot chip is attributed to `provenanceRow` because that
    /// twin routes its rows through the shared helper, where the iOS twin writes `LabeledContent`
    /// inline — so the two sets are not the same names, and pinning them separately is the point.
    @Test("Both twins mount exactly the P-1 chips, in exactly the expected members")
    func bothTwinsMountTheSameChips() throws {
        let expected: [String: Set<String>] = [
            Self.iOSTwin: ["archivalCollectionSection", "unprintedRow",
                           "countrySeriesSection", "lotFilePanel"],
            Self.macTwin: ["collectionBox", "unprintedBox",
                           "countrySeriesBox", "provenanceRow"],
        ]
        var swept = 0
        for (path, want) in expected {
            let text = Self.code(try Self.source(path))
            let got = Set(Self.enclosingMembers(of: "ProvenanceChip(source:", in: text))
            #expect(got == want, "\(path) mounts chips in \(got.sorted())")
            swept += 1
        }
        // Without this, deleting an entry from `expected` leaves the test green.
        #expect(swept == 2, "the twin sweep ran over \(swept) files")
    }

    /// The country-series section carries BOTH tiers in BOTH twins.
    ///
    /// This is the assertion that fails in both directions: a twin that badges only the NARA half,
    /// and a twin that badges more than its sibling.
    @Test("Both twins badge the country-series section with both sources")
    func countrySeriesCarriesBothTiersInBothTwins() throws {
        let members = [Self.iOSTwin: "countrySeriesSection", Self.macTwin: "countrySeriesBox"]
        var swept = 0
        for (path, member) in members {
            let text = Self.code(try Self.source(path))
            var sources: Set<String> = []
            var current = "<file scope>"
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let r = trimmed.range(of: #"(?:var|func)\s+(\w+)"#, options: .regularExpression) {
                    current = String(trimmed[r]).split(separator: " ").last.map(String.init) ?? current
                }
                guard current == member, line.contains("ProvenanceChip(source:") else { continue }
                if line.contains(".frusText") { sources.insert("frusText") }
                if line.contains(".naraCatalog") { sources.insert("naraCatalog") }
            }
            #expect(sources == ["frusText", "naraCatalog"],
                    "\(path) \(member) badges \(sources.sorted())")
            swept += 1
        }
        #expect(swept == 2, "the country-series sweep ran over \(swept) files")
    }

    /// Both twins reach the shared rules rather than re-deciding locally.
    @Test("Both twins call the shared per-row rules")
    func bothTwinsCallTheSharedRules() throws {
        var swept = 0
        for path in [Self.iOSTwin, Self.macTwin] {
            let text = Self.code(try Self.source(path))
            #expect(text.contains("SourceExplorerProvenance.lotRecordGroupSource("),
                    "\(path) does not call lotRecordGroupSource")
            #expect(text.contains("SourceExplorerProvenance.unprintedPointerSource("),
                    "\(path) does not call unprintedPointerSource")
            swept += 1
        }
        #expect(swept == 2, "the shared-rule sweep ran over \(swept) files")
    }

    /// The strongest anti-drift assertion available: a twin cannot quietly re-implement the branch.
    ///
    /// The anchor string lives in `SourceExplorerProvenance` and nowhere else, so a future edit
    /// that inlines `citation.anchor == "centralFileClass"` into one twin is caught here rather
    /// than becoming a second copy that can disagree.
    @Test("Neither twin re-implements the anchor branch")
    func neitherTwinNamesTheAnchorLiteral() throws {
        var swept = 0
        for path in [Self.iOSTwin, Self.macTwin] {
            let text = Self.code(try Self.source(path))
            #expect(!text.contains("centralFileClass"),
                    "\(path) names the anchor literal — the branch belongs in SourceExplorerProvenance")
            swept += 1
        }
        #expect(swept == 2, "the anchor-literal sweep ran over \(swept) files")
    }

    /// The curated disclosure stays where PV-3 put it.
    ///
    /// `curatedLotSection` and `curatedLotBox` already carry a `ConfidenceChip` and say in prose
    /// that the match was made by collection name rather than a control number, and every one of
    /// the 20 curated lots renders that card. Repeating the sentence on the record-group chip would
    /// reinstate exactly the redundancy PV-3's Q-3 correction removed.
    @Test("Neither twin repeats the curated disclosure on the record-group row")
    func neitherTwinRepeatsTheCuratedDisclosure() throws {
        var swept = 0
        for path in [Self.iOSTwin, Self.macTwin] {
            let text = Self.code(try Self.source(path))
            #expect(!text.contains("curatedDisclosure"),
                    "\(path) repeats the curated disclosure — see PV-3's Q-3 correction")
            swept += 1
        }
        #expect(swept == 2, "the disclosure sweep ran over \(swept) files")
    }

    /// The call sites pass the CURATED answer, not the merged one.
    ///
    /// This is the mutation the rule tests cannot catch, because they exercise the function and not
    /// its argument. `effectiveRG` is non-nil wherever the row renders at all, so passing it makes
    /// every lot read `.naraCatalog` — the chip would be present, correctly typed, and always
    /// wrong. A source scan on the argument name is the only guard available.
    @Test("Both twins pass the curated answer to the rule, never the merged value")
    func bothTwinsPassTheUnmergedCuratedValue() throws {
        var swept = 0
        for path in [Self.iOSTwin, Self.macTwin] {
            let text = Self.code(try Self.source(path))
            #expect(text.contains("curated: curatedRG"),
                    "\(path) must pass the curated answer under its own name")
            #expect(!text.contains("curated: effectiveRG"),
                    "\(path) passes the merged value — every lot would read as the catalogue's")
            #expect(!text.contains("curated: r)") && !text.contains("curated: rg)"),
                    "\(path) passes the merged value under another name")
            swept += 1
        }
        #expect(swept == 2, "the argument sweep ran over \(swept) files")
    }

    /// The Mac helper must be an overload, not a defaulted parameter.
    ///
    /// A default would compile at all ~30 existing `provenanceRow` call sites and badge none of
    /// them, which is indistinguishable from success.
    @Test("The Mac provenance row is an explicit overload, not a defaulted parameter")
    func theMacRowHelperIsAnOverload() throws {
        let text = Self.code(try Self.source(Self.macTwin))
        #expect(text.contains("provenanceRow(label: String, value: String) -> some View"),
                "the two-argument form must survive for the rows that carry no chip")
        #expect(text.contains("provenance: ProvenanceSource) -> some View"),
                "the badged form must be a separate overload")
        #expect(!text.contains("provenance: ProvenanceSource = "),
                "a defaulted parameter would badge nothing at every existing call site")
    }
}

/// Locates the test bundle. `CuratedLotResolutionsTests` declares its own `private` token, which is
/// file-scoped, so this suite needs one of its own rather than reaching for that.
private final class SourceExplorerProvenanceBundleToken {}
