// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - ArchivalResolverTests

/// Pins `ArchivalResolver` — the central-files-first precedence the corpus browser's Sources
/// outline and the Collections "Sources & Archives" export block both resolve through
/// (#372 / N-5 PR 1) — against the **real bundled artifacts**.
///
/// ## What these tests are defending
/// The change is a *layering*, and every interesting way to get it wrong collapses it into a
/// *replacement*. Measured over the owner's 501-volume index with the shipped readers:
///
/// | | documents | front-matter nodes |
/// |---|---|---|
/// | gained | **733** | **98** |
/// | lost | 0 | 0 |
/// | NARA link changed | 0 | 0 |
///
/// Zero losses is a property of the fallback, not of the data. Drop the volume-sources arm and
/// seven lots go dark; drop the record-group branch and **14,187 document rows and 6,373 nodes**
/// go dark, because central-files has no record-group map at all. Both failure modes are held
/// by tests below, so neither can be "simplified" away silently.
///
/// Version history:
///   1.0 — Session 2026-08-05: #372 / N-5 PR 1
@Suite("ArchivalResolver — central-files first, volume-sources second")
struct ArchivalResolverTests {

    private func central() throws -> CentralFilesIndex {
        try #require(CentralFilesIndexStore.shared, "central-files-index.json must decode")
    }
    private func volumes() throws -> VolumeSourcesIndex {
        try #require(VolumeSourcesIndexStore.shared, "volume-sources-index.json must decode")
    }
    /// The resolution under test, against both real bundles.
    private func resolve(rg: String? = nil, lot: String? = nil) throws -> ArchivalResolution? {
        ArchivalResolver.resolution(recordGroup: rg, lotFile: lot,
                                    centralFiles: try central(), volumeSources: try volumes())
    }

    // MARK: - Precedence

    /// 751 lot keys are in both bundles. They agree on every rendered field, and differ only in
    /// `matchType` — central-files says `"control"`, volume-sources `"lot"` — which is exactly
    /// what makes `matchType` the usable witness for *which bundle answered*.
    @Test("A lot in both bundles is answered by central-files")
    func centralFilesWinsOnSharedKeys() throws {
        let shared = "53 D 413"
        #expect(try volumes().resolution(recordGroup: nil, lotFile: shared)?.matchType == "lot",
                "fixture guard: volume-sources must still carry this lot, or the test proves nothing")
        let hit = try #require(try resolve(lot: shared))
        #expect(hit.matchType == "control", "central-files must answer first")
        // Both bundles carry the same NAID here — the precedence changes the source, not the link.
        #expect(hit.naId == "2127212")
    }

    /// The repoint's actual value: 220 lot keys resolve only in central-files.
    @Test("A lot only central-files knows now resolves")
    func centralFilesOnlyLotResolves() throws {
        // 60 D 224 — the largest of the 220 by document reach (211 documents).
        #expect(try volumes().resolution(recordGroup: nil, lotFile: "60–D 224") == nil,
                "fixture guard: volume-sources must NOT know this lot")
        #expect(try resolve(lot: "60–D 224")?.naId == "592873")
        // A second, differently-spelled case: the bundles normalize the raw citation themselves.
        #expect(try resolve(lot: "65A987")?.naId == "2945755")
    }

    /// The reason this is a fallback and not a swap. All seven, by name — a replacement would
    /// take each of them to `nil`.
    @Test("All seven volume-sources-only lots still resolve")
    func volumeSourcesOnlyLotsSurvive() throws {
        let expected = ["64 D 171": "40967113", "67 D 317": "40967285",
                        "67 D 333": "40967285", "68 D 393": "5634081",
                        "70 D 449": "40967285", "74 D 267": "1257163",
                        "78 D 26": "824653"]
        for (lot, naId) in expected {
            #expect(try central().lotFile(forRawLot: lot) == nil,
                    "fixture guard: central-files must NOT know \(lot)")
            #expect(try resolve(lot: lot)?.naId == naId,
                    "\(lot) must still resolve through the volume-sources fallback")
        }
    }

    /// The shape production actually calls with — a record group **and** a lot together.
    ///
    /// Every other lot test here passes `recordGroup: nil`, which no call site ever does:
    /// `VolumeSourcesView` passes `entry.recordGroup`, and `CollectionContentResolver` passes
    /// the group's. Adversarial review found that both lot arms could therefore be gated on
    /// `recordGroup == nil` and disabled for all real traffic with the suite green.
    @Test("Both lot arms answer in the shape the call sites use — record group AND lot")
    func lotArmsAnswerWithARecordGroupPresent() throws {
        // Central-files arm, with the record group the citation carries.
        #expect(try resolve(rg: "59", lot: "60–D 224")?.naId == "592873")
        #expect(try resolve(rg: "RG-59", lot: "60–D 224")?.naId == "592873",
                "the stored record_group form must not change the lot answer either")
        // Volume-sources fallback arm, likewise. 70 D 449 is an RG 306 lot.
        #expect(try resolve(rg: "306", lot: "70 D 449")?.naId == "40967285")
        // And the shared-key precedence still prefers central-files.
        #expect(try resolve(rg: "59", lot: "53 D 413")?.matchType == "control")
    }

    /// The bridge is a ten-field memberwise copy between two types with several same-typed
    /// adjacent fields, so a transposition compiles. `naId` alone would not notice
    /// `title` ↔ `catalogURL` swapping — and those are exactly the two the surfaces render.
    @Test("Every bridged field survives the crossing")
    func bridgeCopiesEveryFieldFaithfully() throws {
        let entry = try #require(try central().lotFile(forRawLot: "60–D 224"))
        let bridged = ArchivalResolution(lotFileEntry: entry)
        #expect(bridged.naId == entry.naId)
        #expect(bridged.title == entry.title)
        #expect(bridged.catalogURL == entry.catalogURL)
        #expect(bridged.recordGroup == entry.recordGroup)
        #expect(bridged.matchType == entry.matchType)
        #expect(bridged.hmsMlrEntryNumbers == entry.hmsMlrEntryNumbers)
        #expect(bridged.levelOfDescription == entry.levelOfDescription)
        #expect(bridged.seriesNaId == entry.seriesNaId)
        #expect(bridged.seriesTitle == entry.seriesTitle)
        #expect(bridged.seriesHmsMlrEntryNumbers == entry.seriesHmsMlrEntryNumbers)
        // The values must also be distinguishable, or a transposition of two equal fields
        // would pass every line above.
        #expect(bridged.title != bridged.catalogURL)
        #expect(bridged.naId != bridged.title)
        #expect(bridged.url != nil, "catalogURL must still parse — it is what the Link opens")
        #expect(bridged.displaySeriesTitle == entry.displaySeriesTitle,
                "the accessor both surfaces read for the file-series caption")
    }

    /// The same crossing, over every lot both bundles carry. If the bridge dropped or
    /// transposed a rendered field, 751 rows would say so at once.
    @Test("Across all 751 shared lots the bridge agrees with volume-sources on every rendered field")
    func bridgeAgreesWithVolumeSourcesCorpusWide() throws {
        var compared = 0
        for entry in try central().lotFiles {
            guard let vs = try volumes().lots[entry.lotNumber] else { continue }
            let bridged = ArchivalResolution(lotFileEntry: entry)
            compared += 1
            #expect(bridged.naId == vs.naId, "naId differs on \(entry.lotNumber)")
            #expect(bridged.title == vs.title, "title differs on \(entry.lotNumber)")
            #expect(bridged.catalogURL == vs.catalogURL, "catalogURL differs on \(entry.lotNumber)")
            #expect(bridged.recordGroup == vs.recordGroup, "recordGroup differs on \(entry.lotNumber)")
            #expect(bridged.levelOfDescription == vs.levelOfDescription,
                    "levelOfDescription differs on \(entry.lotNumber)")
            #expect(bridged.hmsMlrEntryNumbers == vs.hmsMlrEntryNumbers,
                    "hmsMlrEntryNumbers differ on \(entry.lotNumber)")
            // `matchType` is the one field that legitimately differs — "control" vs "lot" —
            // and nothing renders it.
        }
        #expect(compared == 751, "expected 751 shared lot keys; compared \(compared)")
    }

    // MARK: - Rules that must survive

    /// Predates this type and survives it: a citation naming a lot resolves *only* through that
    /// lot. Falling back to the record group would stamp "General Records of the Department of
    /// State" on every lot the bundles cannot place — a link that looks like an answer.
    @Test("An unresolvable lot never falls back to its record group")
    func unresolvedLotDoesNotBorrowTheRecordGroup() throws {
        let nonsense = "99 D 9999"
        #expect(try central().lotFile(forRawLot: nonsense) == nil)
        #expect(try volumes().resolution(recordGroup: nil, lotFile: nonsense) == nil)
        // RG 59 IS in the record-group map, so a leak would resolve here.
        #expect(try volumes().recordGroups["59"] != nil, "fixture guard: RG 59 must be mapped")
        #expect(try resolve(rg: "59", lot: nonsense) == nil,
                "a named-but-unresolved lot must not borrow its record group's link")
    }

    /// The same rule, pinned one layer down — and it needs its own test.
    ///
    /// `ArchivalResolver` passes `recordGroup: nil` on the lot branch, so if
    /// `VolumeSourcesIndex.resolution` were changed to fall through from an unresolved lot to
    /// the record group, **nothing measured through the resolver would notice**: there is no
    /// record group to fall through to. Mutation testing found exactly that — the end-to-end
    /// rule was held by the conjunction of two independent decisions and by neither alone, so
    /// each mutation on its own left the suite green.
    @Test("VolumeSourcesIndex itself refuses to borrow the record group for a named lot")
    func volumeSourcesEnforcesTheLotOnlyRule() throws {
        let index = try volumes()
        #expect(index.recordGroups["59"] != nil, "fixture guard: RG 59 must be mapped")
        #expect(index.resolution(recordGroup: "59", lotFile: nil) != nil,
                "fixture guard: the record-group branch must work, or the next line is vacuous")
        #expect(index.resolution(recordGroup: "59", lotFile: "99 D 9999") == nil,
                "a named-but-unresolved lot must not fall through to its record group")
    }

    /// Central-files has no record-group map. This branch carries 14,187 document rows and
    /// 6,373 front-matter nodes — twenty times the lot path's gain — and must reach
    /// volume-sources untouched.
    @Test("A lot-less citation still resolves through the record-group map")
    func recordGroupBranchIsUntouched() throws {
        let hit = try #require(try resolve(rg: "59"))
        #expect(hit.naId == "388")
        #expect(hit.title == "General Records of the Department of State")
        // …and the same for a non-State group, so the branch is not special-cased to 59.
        #expect(try resolve(rg: "306") != nil)
        #expect(try resolve(rg: "84") != nil)
    }

    @Test("No citation at all resolves to nothing")
    func emptyInputResolvesToNil() throws {
        #expect(try resolve() == nil)
        #expect(try resolve(rg: "", lot: "") == nil)
        #expect(try resolve(rg: "   ", lot: "   ") == nil)
    }

    // MARK: - The refusals ride along

    /// `#321` (`ancestryLacksRecordGroup`) and `#351` (`fileUnit`) are enforced inside
    /// `CentralFilesIndex.lotFile(forRawLot:)`. They currently refuse nothing on the shipped
    /// bundle — all 971 entries are unflagged and `series`-level — so a synthetic index is the
    /// only way to prove the resolver honours them rather than reading `lotFiles` directly.
    @Test("A refused central-files entry does not become a resolution")
    func refusedEntriesAreNotSurfaced() throws {
        #expect(try central().untrustworthyNAIDs.isEmpty,
                "shipped bundle currently trips neither guard — hence the synthetic fixture below")
        for json in [#"{"levelOfDescription":"fileUnit"}"#, #"{"ancestryLacksRecordGroup":true}"#] {
            let index = try Self.syntheticCentralFiles(lot: "11D11", extra: json)
            #expect(index.lotFile(forRawLot: "11 D 11") == nil,
                    "guard precondition failed for \(json)")
            #expect(ArchivalResolver.resolution(recordGroup: "59", lotFile: "11 D 11",
                                                centralFiles: index,
                                                volumeSources: try volumes()) == nil,
                    "a refused entry must resolve to nothing — not to the record group, not by reading past the guard")
        }
    }

    /// A one-entry central-files index whose lot carries `extra`'s fields.
    private static func syntheticCentralFiles(lot: String, extra: String) throws -> CentralFilesIndex {
        let entry = #"{"lotNumber":"\#(lot)","recordGroup":"59","naId":"1","title":"t","#
            + #""catalogURL":"https://catalog.archives.gov/id/1","matchType":"control"}"#
        // Merge `extra` into the entry object.
        let merged = String(entry.dropLast()) + "," + String(extra.dropFirst())
        // `numericalFile` is the one non-defaulted key on the index; nothing here reads it.
        let doc = #"{"generated":"2026-01-01","numericalFile":{"microfilm":"M862","seriesNaId":"654171","rolls":[]},"#
            + #""lotFiles":[\#(merged)]}"#
        return try JSONDecoder().decode(CentralFilesIndex.self, from: Data(doc.utf8))
    }

    // MARK: - Wiring

    /// The convenience overload is what both call sites actually invoke. If it read the wrong
    /// store — or one store and not the other — every test above would still pass.
    @Test("The bundled-store overload agrees with the injected one")
    func conveniencOverloadUsesBothBundles() throws {
        for lot in ["60–D 224", "64 D 171", "53 D 413"] {
            #expect(ArchivalResolver.resolution(recordGroup: nil, lotFile: lot)?.naId
                    == (try resolve(lot: lot))?.naId, "convenience overload diverged on \(lot)")
        }
        #expect(ArchivalResolver.resolution(recordGroup: "59", lotFile: nil)?.naId == "388")
    }

    /// Both render surfaces must go through the resolver. A call site left on
    /// `VolumeSourcesIndexStore.shared?.resolution` compiles, renders, and silently keeps the
    /// old behaviour — no test above would catch it, because neither surface is unit-testable
    /// end-to-end (the Collections suite drives `archivalResolution` through a *fake* data
    /// source with a hardcoded link dictionary).
    @Test("Neither archival render surface still resolves through volume-sources directly")
    func bothCallSitesUseTheResolver() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        for path in ["FRUSExplorer/Browser/VolumeSourcesView.swift",
                     "FRUSExplorer/Collections/CollectionContentResolver.swift"] {
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            // Drop full-line comments: this file's own prose names the old call.
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            #expect(code.contains("ArchivalResolver.resolution("),
                    "\(path) no longer routes through ArchivalResolver")
            #expect(!code.contains("VolumeSourcesIndexStore.shared?.resolution("),
                    "\(path) still resolves through volume-sources directly, bypassing the precedence")
        }
    }
}
