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
/// ## After the fold (#372 item 1)
/// Those seven lots are now *in* central-files, and the shipped `lots` map is `{}`. The
/// volume-sources **lot** arm therefore has no witness in the bundle and is exercised by
/// injection instead; the **record-group** branch, which is twenty times larger, is untouched
/// and still measured against the real artifact. The arm is kept rather than deleted because a
/// re-harvest can mint new orphans at any time — `lotsToWrite` exists to carry exactly those —
/// and because the tests that pin it are the only thing standing between a future orphan and
/// silence. What is no longer true is that any *shipped* lot depends on it.
///
/// Version history:
///   1.0 — Session 2026-08-05: #372 / N-5 PR 1
///   1.1 — Session 2026-08-19: #372 item 1 — the orphans folded into central-files
@Suite("ArchivalResolver — central-files first, volume-sources second")
struct ArchivalResolverTests {

    private func central() throws -> CentralFilesIndex {
        try #require(CentralFilesIndexStore.shared, "central-files-index.json must decode")
    }
    private func volumes() throws -> VolumeSourcesIndex {
        try #require(VolumeSourcesIndexStore.shared, "volume-sources-index.json must decode")
    }
    /// The FRONT-MATTER resolution under test, against both real bundles.
    private func resolve(rg: String? = nil, lot: String? = nil,
                         text: String = "Record Group 59, Records of the Department of State")
        throws -> ArchivalResolution? {
        ArchivalResolver.frontMatterResolution(recordGroup: rg, lotFile: lot,
                                               entryText: text,
                                               centralFiles: try central(),
                                               volumeSources: try volumes())
    }

    /// The DOCUMENT resolution under test — lot only; there is no record group to pass.
    private func resolveDoc(lot: String?) throws -> ArchivalResolution? {
        ArchivalResolver.documentResolution(lotFile: lot,
                                            centralFiles: try central(),
                                            volumeSources: try volumes())
    }

    // MARK: - Precedence

    /// Central-files answers first when both bundles carry a lot.
    ///
    /// The fold (#372 / N-5 PR 2) made the shipped bundles **disjoint**, so there is no longer a
    /// real lot to witness this with — which is exactly why the precedence now has to be tested
    /// against an **injected** volume-sources that does carry the key. Testing it against the
    /// bundle would silently become vacuous the moment the artifact is regenerated.
    @Test("A lot in both bundles is answered by central-files")
    func centralFilesWinsOnSharedKeys() throws {
        let shared = "53 D 413"                       // central-files: naId 2127212, matchType "control"
        #expect(try central().lotFile(forRawLot: shared)?.naId == "2127212",
                "fixture guard: central-files must carry this lot")
        // A volume-sources that also claims it, with a DIFFERENT NAID so the winner is unambiguous.
        let rival = try Self.syntheticVolumeSources(lot: "53D413", naId: "999999")
        #expect(rival.resolution(recordGroup: nil, lotFile: shared)?.naId == "999999",
                "fixture guard: the rival must really answer, or the test proves nothing")
        let hit = try #require(ArchivalResolver.documentResolution(
            lotFile: shared, centralFiles: try central(), volumeSources: rival))
        #expect(hit.naId == "2127212", "central-files must answer first")
        #expect(hit.matchType == "control")
    }

    /// A one-entry volume-sources index claiming `lot`.
    private static func syntheticVolumeSources(lot: String, naId: String) throws -> VolumeSourcesIndex {
        let doc = #"""
        {"recordGroups":{},"majorCollections":[],
         "lots":{"\#(lot)":{"naId":"\#(naId)","catalogURL":"https://catalog.archives.gov/id/\#(naId)",
                            "title":"rival","matchType":"lot"}}}
        """#
        return try JSONDecoder().decode(VolumeSourcesIndex.self, from: Data(doc.utf8))
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

    /// The seven lots that used to exist only in volume-sources, by name and NAID.
    ///
    /// `FOLD_VOLUME_SOURCES` (#372 item 1) moved them into central-files, so what this pins is
    /// no longer *which* bundle answers but that the same seven answers survived the move. The
    /// fixture guard is therefore inverted from what PR 1 shipped — it now requires central-files
    /// to know each one, which is what fails if the fold's rows are ever dropped or re-harvested
    /// away, and the resolver assertion below is unchanged.
    static let foldedOrphans = ["64 D 171": "40967113", "67 D 317": "40967285",
                                "67 D 333": "40967285", "68 D 393": "5634081",
                                "70 D 449": "40967285", "74 D 267": "1257163",
                                "78 D 26": "824653"]

    @Test("All seven folded lots still resolve, now through central-files")
    func volumeSourcesOnlyLotsSurvive() throws {
        for (lot, naId) in Self.foldedOrphans {
            #expect(try central().lotFile(forRawLot: lot)?.naId == naId,
                    "central-files must carry \(lot) — the fold is what put it there")
            #expect(try resolve(lot: lot)?.naId == naId,
                    "\(lot) must still resolve, whichever bundle answers")
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
        // Volume-sources fallback arm, likewise — against an INJECTED index, because after the
        // fold (#372 item 1) the shipped `lots` map is empty and no real lot witnesses this arm.
        // `70 D 449` was the witness until then; it is an RG 306 lot and central-files now
        // answers it, which is why the injected rival claims a different key.
        let orphan = try Self.syntheticVolumeSources(lot: "99D999", naId: "40967285")
        #expect(ArchivalResolver.frontMatterResolution(
            recordGroup: "306", lotFile: "99 D 999",
            entryText: "Record Group 306, Records of the U.S. Information Agency",
            centralFiles: try central(), volumeSources: orphan)?.naId == "40967285",
                "the fallback arm must answer with a record group present, not only without one")
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

    /// The fold's invariant, replacing the corpus-wide bridge cross-check.
    ///
    /// Until #372 / N-5 PR 2 this suite compared the bridged central-files record against
    /// volume-sources' own copy across all **751** lots both bundles carried — a genuinely strong
    /// check, and one the fold deliberately destroys by removing the duplicate. Nothing is lost
    /// silently: per-field fidelity is still pinned by `bridgeCopiesEveryFieldFaithfully`, whose
    /// title/catalogURL and hmsMlr/seriesHmsMlr transposition mutations both fail without it.
    ///
    /// What replaces it is the invariant that makes the duplicate unnecessary: the two maps are
    /// **disjoint**, and what volume-sources keeps is exactly what central-files cannot answer.
    ///
    /// ## Why the emptiness assertion inverted (#372 item 1)
    /// PR 2 asserted `!vs.lots.isEmpty`, because an empty map then meant `lotsToWrite`'s
    /// carry-forward had silently dropped the seven orphans — the one way disjointness could be
    /// achieved by losing data. `FOLD_VOLUME_SOURCES` removed that reading: the seven were
    /// admitted into central-files, so an empty map is now the fold's endpoint rather than a gap,
    /// and the map went to `{}` on the next volume-sources run exactly as designed.
    ///
    /// Emptiness cannot be asserted on its own either — it is satisfied by deleting the seven
    /// from both bundles. So the pin moved to where the data went: every lot the map used to
    /// carry must resolve, through whichever bundle now answers it. That is
    /// ``volumeSourcesOnlyLotsSurvive``, and the loop below keeps this test honest for any
    /// entry a future harvest re-adds.
    @Test("The two lot maps are disjoint, and volume-sources keeps exactly the orphans")
    func lotMapsAreDisjoint() throws {
        let cf = try central(), vs = try volumes()
        let overlap = vs.lots.keys.filter { cf.lotFile(forRawLot: $0) != nil }
        #expect(overlap.isEmpty,
                "volume-sources still duplicates \(overlap.count) lots central-files answers: \(overlap.sorted().prefix(10))")
        for key in vs.lots.keys {
            #expect(cf.lotFile(forRawLot: key) == nil)
            #expect(ArchivalResolver.documentResolution(lotFile: key, centralFiles: cf,
                                                        volumeSources: vs) != nil,
                    "\(key) is carried but does not resolve")
        }
        // …and disjointness is not being bought by losing lots: the seven the map used to hold
        // are all still answerable. Their new home is pinned by name in `foldedOrphans`.
        for (lot, naId) in Self.foldedOrphans {
            #expect(ArchivalResolver.documentResolution(lotFile: lot, centralFiles: cf,
                                                        volumeSources: vs)?.naId == naId,
                    "\(lot) went dark in the fold — it is in neither bundle now")
        }
    }

    /// `majorCollections[].resolved` is no longer serialized (#372 / N-5 PR 2): 932 objects,
    /// 307,810 bytes, 20.4% of the artifact, decoded on every launch and read by nothing. The
    /// app struct no longer declares it, so only the raw JSON can hold this.
    @Test("The artifact carries no per-collection resolved records")
    func majorCollectionsCarryNoResolvedRecords() throws {
        let url = try #require(Bundle.main.url(forResource: "volume-sources-index",
                                               withExtension: "json"))
        let json = try #require(try JSONSerialization.jsonObject(
            with: Data(contentsOf: url)) as? [String: Any])
        let collections = try #require(json["majorCollections"] as? [[String: Any]])
        #expect(collections.count > 2_000, "fixture guard: the authority must still be here")
        #expect(collections.allSatisfy { $0["resolved"] == nil },
                "\(collections.filter { $0["resolved"] != nil }.count) collections still carry a resolved record")
    }

    // MARK: - A row must NAME its record group, not inherit one

    /// The `frus1961-63v25` canary, verbatim.
    ///
    /// The volume nests "USIA Historical Collection" under the heading "Lot Files … Record
    /// Group 59" — exactly as history.state.gov does — so the indexer stores RG 59 on it and on
    /// its descriptive child. Both linked to *General Records of the Department of State*.
    /// USIA's records are **RG 306**, which the same volume names correctly a few rows later.
    @Test("A row that only inherited its record group gets no catalogue link")
    func inheritedRecordGroupEarnsNoLink() throws {
        #expect(try volumes().recordGroups["59"] != nil, "fixture guard: RG 59 is mapped")
        #expect(try resolve(rg: "59", text: "USIA Historical Collection") == nil)
        #expect(try resolve(rg: "59", text: "Reference works, visual materials, transcripts of "
                            + "oral histories, and copies of official records documenting the "
                            + "activities and history of the USIA and its predecessor agencies") == nil)
        // …and the same for a specific series borrowing RG 383's link.
        #expect(try resolve(rg: "383", text: "ACDA/DD Files: FRC 77 A 17") == nil)
    }

    /// The rows that keep their link: they name the record group themselves.
    @Test("A row that names its record group keeps its catalogue link")
    func namedRecordGroupKeepsItsLink() throws {
        #expect(try resolve(rg: "59", text: "Record Group 59, Records of the Department of State")?
            .naId == "388")
        #expect(try resolve(rg: "383", text: "Record Group 383, Records of the Arms Control and "
                            + "Disarmament Agency")?.naId == "685")
        // The pointer row names RG 59 mid-sentence and legitimately links to it.
        #expect(try resolve(rg: "59", text: "Lot Files. These files may be transferred to the "
                            + "National Archives and Records Administration at College Park, "
                            + "Maryland, Record Group 59.")?.naId == "388")
    }

    /// A row naming a *different* record group from the one it inherited must not resolve to
    /// either — the stored value is the lookup key, and disagreement means the row is not the
    /// header for what it sits under.
    @Test("A row naming a different record group than it inherited resolves to nothing")
    func mismatchedRecordGroupResolvesToNothing() throws {
        #expect(try volumes().recordGroups["306"] != nil, "fixture guard: RG 306 is mapped")
        #expect(try resolve(rg: "59", text: "Record Group 306, Records of the U.S. Information "
                            + "Agency") == nil)
    }

    /// A lot row is unaffected: it resolves through its lot and never consults the text.
    @Test("A lot row still resolves regardless of its text")
    func lotRowsIgnoreTheRecordGroupRule() throws {
        #expect(try resolve(rg: "306", lot: "64 D 171", text: "USIA Files: Lot 64 D 171")?
            .naId == "40967113")
        #expect(try resolve(rg: "59", lot: "60–D 224", text: "anything at all")?.naId == "592873")
    }

    // MARK: - Document citations get no record-group link

    /// The N-5 follow-up decision. A document citation names something far more specific than
    /// a record group; answering it with "General Records of the Department of State" is a
    /// category, not a resolution.
    ///
    /// The rule is structural — `documentResolution` has **no** `recordGroup` parameter — so
    /// this test is really pinning the *signature*. If someone re-adds the parameter and wires
    /// the branch back, the corpus check below is what notices.
    @Test("A document citation never resolves through its record group")
    func documentCitationsGetNoRecordGroupLink() throws {
        // A lot-less decimal citation: RG 59 is mapped, so the old branch would have answered.
        #expect(try volumes().recordGroups["59"] != nil, "fixture guard: RG 59 is mapped")
        #expect(try resolveDoc(lot: nil) == nil)
        #expect(try resolveDoc(lot: "") == nil)
        #expect(try resolveDoc(lot: "   ") == nil)
        // …while the same inputs on the FRONT-MATTER path still resolve. That contrast is the
        // whole change: one surface keeps the branch, the other loses it.
        #expect(try resolve(rg: "59", lot: nil)?.naId == "388")
    }

    /// The document path keeps everything the lot half earned in #692.
    @Test("A document citation still resolves through its lot, both arms")
    func documentCitationsStillResolveLots() throws {
        #expect(try resolveDoc(lot: "60–D 224")?.naId == "592873", "central-files arm")
        #expect(try resolveDoc(lot: "70 D 449")?.naId == "40967285", "volume-sources fallback arm")
        #expect(try resolveDoc(lot: "53 D 413")?.matchType == "control", "precedence intact")
        #expect(try resolveDoc(lot: "99 D 9999") == nil, "an unresolvable lot is still nil")
    }

    /// The bundled-store overload must lose the branch too — the injected one proving it is
    /// not enough, since the call site uses the convenience form.
    @Test("The bundled-store document overload has no record-group branch either")
    func bundledDocumentOverloadHasNoRecordGroupBranch() throws {
        #expect(ArchivalResolver.documentResolution(lotFile: nil) == nil)
        #expect(ArchivalResolver.documentResolution(lotFile: "60–D 224")?.naId == "592873")
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
        // Each row must name its OWN record group — see `namedRecordGroupKeepsItsLink`.
        #expect(try resolve(rg: "306",
                            text: "Record Group 306, Records of the U.S. Information Agency") != nil)
        #expect(try resolve(rg: "84", text: "Record Group 84, Foreign Service Posts") != nil)
    }

    /// The front-matter branch normalizes the record group before the lookup, so it cannot
    /// become form-sensitive the way the document branch was.
    ///
    /// `volume_sources` stores these bare today — 0 of 7,374 rows carry the prefix — so this
    /// is defence, not a live fix. It matters because the *reason* the document branch was
    /// removed was a form mismatch, and leaving the surviving branch exposed to the same
    /// mismatch would be the identical bug one surface over.
    @Test("The front-matter branch is not sensitive to the record-group's stored form")
    func frontMatterBranchNormalizesTheForm() throws {
        #expect(try resolve(rg: "59")?.naId == "388")
        #expect(try resolve(rg: "RG-59")?.naId == "388", "the parser's inferred form must work too")
        #expect(try resolve(rg: "RG 59")?.naId == "388", "and the spaced spelling")
        #expect(try resolve(rg: "rg-59")?.naId == "388", "and lower case")
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
    /// bundle — all 978 entries are unflagged and `series`-level — so a synthetic index is the
    /// only way to prove the resolver honours them rather than reading `lotFiles` directly.
    @Test("A refused central-files entry does not become a resolution")
    func refusedEntriesAreNotSurfaced() throws {
        #expect(try central().untrustworthyNAIDs.isEmpty,
                "shipped bundle currently trips neither guard — hence the synthetic fixture below")
        for json in [#"{"levelOfDescription":"fileUnit"}"#, #"{"ancestryLacksRecordGroup":true}"#] {
            let index = try Self.syntheticCentralFiles(lot: "11D11", extra: json)
            #expect(index.lotFile(forRawLot: "11 D 11") == nil,
                    "guard precondition failed for \(json)")
            #expect(ArchivalResolver.frontMatterResolution(recordGroup: "59", lotFile: "11 D 11",
                                                           entryText: "Record Group 59",
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
            #expect(ArchivalResolver.frontMatterResolution(recordGroup: nil, lotFile: lot, entryText: "x")?.naId
                    == (try resolve(lot: lot))?.naId, "convenience overload diverged on \(lot)")
        }
        #expect(ArchivalResolver.frontMatterResolution(recordGroup: "59", lotFile: nil,
                                                      entryText: "Record Group 59, Records of the Department of State")?.naId == "388")
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
        // Each surface must use ITS OWN entry point. An "either one" assertion would pass
        // while the Collections block called `frontMatterResolution` and kept the very
        // record-group branch this change removes.
        let expected = [
            "FRUSExplorer/Browser/VolumeSourcesView.swift":
                ("ArchivalResolver.frontMatterResolution(", "ArchivalResolver.documentResolution("),
            "FRUSExplorer/Collections/CollectionContentResolver.swift":
                ("ArchivalResolver.documentResolution(", "ArchivalResolver.frontMatterResolution("),
        ]
        for (path, calls) in expected {
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            // Drop full-line comments: this file's own prose names the other call.
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            #expect(code.contains(calls.0), "\(path) must resolve through \(calls.0)")
            #expect(!code.contains(calls.1),
                    "\(path) uses the OTHER surface's entry point (\(calls.1)) — the record-group branch belongs to front matter only")
            #expect(!code.contains("VolumeSourcesIndexStore.shared?.resolution("),
                    "\(path) still resolves through volume-sources directly, bypassing the precedence")
        }
    }
}
