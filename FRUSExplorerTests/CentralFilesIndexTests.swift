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

// MARK: - CentralFilesIndexTests

/// Tests for the app-side Central Files index model: JSON decoding (matching the
/// generated contract), File No. → roll lookup, and the bundled index sanity.
struct CentralFilesIndexTests {

    /// A JSON sample shaped exactly like the generated `central-files-index.json`.
    private let sampleJSON = """
    {
      "schemaVersion" : 1,
      "generated" : "2026-06-16",
      "numericalFile" : {
        "microfilm" : "M862",
        "seriesNaId" : "654171",
        "rolls" : [
          { "caseStart" : 682, "caseEnd" : 699, "naId" : "19174810",
            "title" : "Numerical File: 682-699",
            "catalogURL" : "https://catalog.archives.gov/id/19174810" },
          { "caseStart" : 7179, "caseEnd" : 7187, "naId" : "19779414",
            "title" : "Numerical File: 7179-7187",
            "catalogURL" : "https://catalog.archives.gov/id/19779414" },
          { "caseStart" : 14319, "caseEnd" : 14319, "naId" : "r1",
            "title" : "Numerical File: 14319/51-14319/120", "catalogURL" : "u1" },
          { "caseStart" : 14319, "caseEnd" : 14330, "naId" : "r2",
            "title" : "Numerical File: 14319/121-14330", "catalogURL" : "u2" }
        ]
      }
    }
    """

    private func decodeSample() throws -> CentralFilesIndex {
        try JSONDecoder().decode(CentralFilesIndex.self, from: Data(sampleJSON.utf8))
    }

    @Test("Decodes the generated JSON contract")
    func decodesContract() throws {
        let index = try decodeSample()
        #expect(index.schemaVersion == 1)
        #expect(index.numericalFile.microfilm == "M862")
        #expect(index.numericalFile.seriesNaId == "654171")
        #expect(index.numericalFile.rolls.count == 4)
    }

    @Test("Resolves the golden File No. citations to the correct roll")
    func resolvesGoldenCitations() throws {
        let index = try decodeSample()
        // Doc 6: File No. 7187; Doc 7: File No. 697/43.
        #expect(index.numericalFile.rolls(forFileNumber: "7187").map(\.naId) == ["19779414"])
        #expect(index.numericalFile.rolls(forFileNumber: "697/43").map(\.naId) == ["19174810"])
    }

    @Test("Parses the case number from File No. strings, ignoring labels and sub-docs")
    func parsesCaseNumber() {
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "7187") == 7187)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "697/43") == 697)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "File No. 17529.") == 17529)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "no digits") == nil)
    }

    @Test("Returns all rolls when a case is split across rolls")
    func returnsAllRollsForSplitCase() throws {
        let index = try decodeSample()
        // Case 14319 spans r1 (sub-docs 51–120) and r2 (121–14330).
        #expect(index.numericalFile.rolls(forFileNumber: "14319/77").map(\.naId) == ["r1", "r2"])
        // 14325 is only on r2.
        #expect(index.numericalFile.rolls(forFileNumber: "14325").map(\.naId) == ["r2"])
    }

    @Test("Returns no rolls for a case in a coverage gap")
    func gapReturnsEmpty() throws {
        let index = try decodeSample()
        #expect(index.numericalFile.rolls(forFileNumber: "5000").isEmpty)  // between 699 and 7179
    }

    // MARK: - #354 item 5: the decimal-era format gate
    //
    // Both surfaces that resolve Numerical File rolls gate on `documentYear` being
    // 1906–1910, and the decimal file opened in the MIDDLE of 1910. Measured over the
    // corpus export, 334 documents sit inside that year gate carrying a decimal citation
    // — 327 of them dated 1910. Without the form gate `caseNumber` took their first run of
    // digits and returned a real case number belonging to an unrelated case, which the
    // roll lookup then resolved to a real digitised roll. The researcher was sent to a
    // specific microfilm roll that does not hold the document, with nothing to signal it.

    /// The corpus's decimal citations, verbatim, must yield no case number.
    @Test("Decimal-era citations produce no case number")
    func decimalFormsAreGated() {
        for fileNumber in [
            "215.1/84",       // frus1908/d594
            "358.117/1–2",    // frus1909/d515
            "835.415A/97",    // frus1910/d19
            "864.56/12",      // frus1910/d37
            "825.00/69",      // frus1910/d109
            "211.63 Or5/2",   // frus1910/d50 — a space inside the class, not after the dot
            "811B.5034",      // frus1910/d54 — no sub-document suffix at all
        ] {
            #expect(CentralFilesIndex.caseNumber(fromFileNumber: fileNumber) == nil,
                    Comment(rawValue: """
                            \(fileNumber) resolved case \
                            \(CentralFilesIndex.caseNumber(fromFileNumber: fileNumber) ?? -1) — \
                            a decimal citation was read as a Numerical File case.
                            """))
        }
    }

    /// The fourteen documents that a rule reasoned about rather than measured would miss.
    ///
    /// `511. 4A1/914` and `812. 415A/7` are `511.4A1` and `812.415A` with a space
    /// transcribed into the decimal point. The first version of the gate required an
    /// alphanumeric *immediately* after the dot and let all fourteen through, still
    /// resolving cases 511 and 812. The corpus measurement is what caught it.
    @Test("A space transcribed into the decimal point is still decimal-era")
    func spacedDecimalPointIsGated() {
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "511. 4A1/914") == nil)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "812. 415A/7") == nil)
    }

    /// `811B.5034`'s decimal point follows a **letter**, so the gate cannot be "a dot after
    /// a digit" — the obvious alternative rule, which would let it resolve case 811.
    @Test("A decimal point after a letter still gates")
    func decimalPointAfterLetterIsGated() {
        #expect(CentralFilesIndex.isDecimalFileForm("811B.5034"))
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "811B.5034") == nil)
    }

    /// The gate must cost the Numerical File nothing. Measured over the same 2,787
    /// in-year identifiers: 334 gated, **0** whose case number changed any other way.
    @Test("Numerical File citations are untouched by the gate")
    func numericalFormsSurviveTheGate() {
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "7187") == 7187)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "697/43") == 697)
        // The abbreviation dot in the label is not a decimal point — this is why the rule
        // starts reading at the first digit instead of at the start of the string.
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "File No. 17529.") == 17529)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "14319/77") == 14319)
        #expect(!CentralFilesIndex.isDecimalFileForm("File No. 17529."))
        #expect(!CentralFilesIndex.isDecimalFileForm("697/43"))
    }

    /// The `/` clause, which has **zero traffic** inside the year gate and is kept anyway.
    ///
    /// Measured over all 2,787 identifiers on 1906–1910 documents, removing it changes no
    /// verdict — so nothing else in this suite would notice its removal, and it is pinned
    /// here rather than left to a mutation that survives silently. It is kept because
    /// `caseNumber(fromFileNumber:)` is a general entry point and a slash genuinely closes
    /// the case number: 183 identifiers elsewhere in the corpus carry a trailing
    /// `101/2-2162. Secret.`-style clause that would otherwise read as decimal.
    @Test("A dot after the sub-document slash is not a decimal point")
    func dotAfterSlashIsNotDecimal() {
        #expect(!CentralFilesIndex.isDecimalFileForm("697/43."))
        #expect(!CentralFilesIndex.isDecimalFileForm("101/2-2162. Secret."))
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "697/43.") == 697)
    }

    /// End to end against the **bundled** index, so the test fails if the gate stops being
    /// reached from the lookup the two views actually call.
    ///
    /// `697.1/43` is built to be caught: its leading digits are case 697, which the bundled
    /// index really does resolve to roll `19174810` (the assertion directly above pins
    /// that). Before the gate this decimal citation returned that roll.
    @Test("A decimal citation resolves no roll through the bundled index")
    func decimalCitationResolvesNoRoll() throws {
        let index = try #require(CentralFilesIndexStore.shared,
                                 "central-files-index.json should be bundled and decodable")
        #expect(index.numericalFile.rolls(forFileNumber: "697/43").contains { $0.naId == "19174810" },
                "fixture guard: case 697 must resolve, or the negative below proves nothing")
        #expect(index.numericalFile.rolls(forFileNumber: "697.1/43").isEmpty,
                "a decimal citation was resolved to a Numerical File roll")
        #expect(index.numericalFile.rolls(forFileNumber: "215.1/84").isEmpty)
    }

    @Test("Lot file decodes and resolves from a raw source-note lot number")
    func lotFileLookup() throws {
        let json = """
        {
          "schemaVersion": 3, "generated": "2026-06-16",
          "numericalFile": { "microfilm": "M862", "seriesNaId": "654171", "rolls": [] },
          "lotFiles": [
            { "lotNumber": "64D199", "recordGroup": "59", "naId": "602231",
              "title": "The Secretary's Memorandums of Conversation",
              "catalogURL": "https://catalog.archives.gov/id/602231", "matchType": "control" }
          ]
        }
        """
        let index = try JSONDecoder().decode(CentralFilesIndex.self, from: Data(json.utf8))
        // Raw spellings from source notes normalize to the bundle's compact key.
        #expect(index.lotFile(forRawLot: "64 D 199")?.naId == "602231")
        #expect(index.lotFile(forRawLot: "Lot 64-D 199")?.naId == "602231")
        #expect(index.lotFile(forRawLot: "64D199")?.matchType == "control")
        #expect(index.lotFile(forRawLot: "99Z9") == nil)
    }

    @Test("normalizeLot matches the generator's compact form")
    func normalizesLot() {
        #expect(CentralFilesIndex.normalizeLot("63 D 135") == "63D135")
        #expect(CentralFilesIndex.normalizeLot("61–D 146") == "61D146")
        #expect(CentralFilesIndex.normalizeLot("Lot 56 F 28") == "56F28")
    }

    @Test("The bundled index loads, parses, and resolves the golden citations")
    func bundledIndexResolvesGolden() throws {
        // Guards against the resource being dropped from the bundle or the schema drifting.
        let index = try #require(CentralFilesIndexStore.shared,
                                 "central-files-index.json should be bundled and decodable")
        #expect(index.numericalFile.microfilm == "M862")
        #expect(index.numericalFile.rolls.count > 1000)
        #expect(index.numericalFile.rolls(forFileNumber: "7187").contains { $0.naId == "19779414" })
        #expect(index.numericalFile.rolls(forFileNumber: "697/43").contains { $0.naId == "19174810" })
    }

    // MARK: - #315 HMS/MLR enrichment (contract on the shipped artifact)
    //
    // These assert against the REAL bundled resource, not a fixture: the enrichment is
    // produced by an owner-run harvest against a live API, so the artifact — not the code
    // that made it — is what ships. A bad harvest is invisible to the generator's own unit
    // tests and would surface only as wrong identifiers in front of a researcher at NARA.
    // Verified numbers are from the 2026-07-15 run (639/639 NAIDs, 0 misses).

    @Test("The bundled lot files carry HMS/MLR entry numbers")
    func bundledLotFilesAreEnriched() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        let lots = index.lotFiles
        #expect(lots.count > 1_000, "expected ~1,065 lot entries (978 + the #372 1b supplement's 87)")

        let withEntries = lots.filter { !($0.hmsMlrEntryNumbers ?? []).isEmpty }
        // 946/979 at the verified run; the floor guards against an un-enriched or
        // half-failed harvest being committed, without pinning an exact count.
        // NB: a single literal, not `"…" + "…"` — #expect's comment parameter is `Comment?`,
        // and only a string LITERAL converts implicitly; a concatenation is a String expression
        // and fails to compile. This exact mistake broke the whole test target at v2 ace0097.
        #expect(withEntries.count > 900,
                "expected ~946 lot entries with an HMS/MLR entry number — a much lower count means the harvest did not run or largely failed")
    }

    /// The discrimination that matters: no internal `HMS Record Entry ID` (`HS1-…`) and no
    /// declassification project number (`NND …` / `RC …`) may ever reach a researcher as if
    /// it were a citable entry number. This checks the shipped values, not the filter.
    @Test("No internal or declassification identifiers leaked into the entry numbers")
    func bundledEntryNumbersHaveNoLeakage() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        let values = Set(index.lotFiles.flatMap { $0.hmsMlrEntryNumbers ?? [] })
        #expect(!values.isEmpty)
        let leaked = values.filter {
            $0.hasPrefix("HS1-") || $0.hasPrefix("NND ") || $0.hasPrefix("RC ")
        }
        #expect(leaked.isEmpty, "internal/declassification identifiers leaked: \(leaked.sorted())")
    }

    /// The artifact must be deterministic: NARA returns entry numbers in an arbitrary order
    /// (50 of 61 multi-entry records came back unsorted), so the generator sorts them. If a
    /// future harvest ships unsorted arrays, the sort regressed.
    @Test("Bundled entry numbers are naturally sorted")
    func bundledEntryNumbersAreSorted() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        for lot in index.lotFiles {
            guard let entries = lot.hmsMlrEntryNumbers, entries.count > 1 else { continue }
            let sorted = entries.sorted {
                switch $0.compare($1, options: [.numeric], range: nil, locale: nil) {
                case .orderedAscending:  return true
                case .orderedDescending: return false
                case .orderedSame:       return $0 < $1
                }
            }
            #expect(entries == sorted, "lot \(lot.lotNumber) ships unsorted: \(entries)")
        }
    }

    /// After the #352 post-validated re-harvest, **every** bundled lot resolves to a *series* — a
    /// State Department lot file IS a series, and a `fileUnit` match is the wrong-collection class
    /// (60 D 627 → "Operation Mongoose") the post-validation rejects. So the bundle carries no
    /// non-series lot and no untrustworthy NAID; the #351 render guards become no-ops (nothing to
    /// suppress). Exact NAIDs/entry numbers are intentionally not pinned — a re-harvest may shift a
    /// lot to another record that also indexes it — but the *shape* invariant is stable.
    @Test("Every bundled lot is series-level; no fileUnit mis-resolutions remain (#352)")
    func everyBundledLotIsSeriesLevel() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        let nonSeries = index.lotFiles.filter { $0.levelOfDescription != nil && !$0.isSeriesLevel }
        #expect(nonSeries.isEmpty,
                "no lot may be non-series after the #352 re-harvest; found \(nonSeries.map(\.lotNumber))")
        #expect(index.untrustworthyNAIDs.isEmpty, "a clean bundle exposes no untrustworthy NAIDs")
        // A corpus-staple series lot resolves, is series-level, and carries its enrichment. Only
        // the stable NAID is pinned (64 D 199 → 602231, the PPS-era Secretary's memoranda).
        let known = try #require(index.lotFile(forRawLot: "64 D 199"))
        #expect(known.isSeriesLevel)
        #expect(known.naId == "602231")
        #expect(!(known.hmsMlrEntryNumbers ?? []).isEmpty, "an enriched series lot carries an entry number")
    }

    /// The artifact-level enforcement of the O-7 decision, added with #372 item 1b.
    ///
    /// ## What could go wrong that nothing else catches
    /// A lot's record group is *derived* from its designator — a `D` lot is RG 59, an `F` lot is
    /// RG 84 — so a bundled row whose `recordGroup` is anything else is a claim that NARA holds
    /// this lot somewhere FRUS did not say. The owner settled how that claim may be made: a
    /// **measured table** (`LotResolutionAcceptance.crossRecordGroupLots`, 37 lots), never a
    /// blanket rule, because a bare control number can collide by coincidence — the harvest
    /// offers RG 76 "Maps … Northeastern Boundary" for a key of `20` that came out of the
    /// citation grammar mis-reading "Lot 64 199".
    ///
    /// Item 1b's supplement pass admits rows from a 4.5 GB harvest that cannot be re-run in CI,
    /// so the generator's own refusal is unverifiable here. This checks the *result* instead:
    /// every cross-record-group row in the shipped bundle must be one the shared rule would
    /// accept today. A future pass that widened the policy — or a hand-edit — fails this.
    ///
    /// Measured on the shipped bundle: **30** of 1,065 rows sit outside the group their
    /// designator implies — RG 306 ×17, RG 84 ×6 (D-lots NARA holds with the posts), RG 353 ×3,
    /// RG 43 ×3, and RG 59 ×1 (`84F53`, an F-lot NARA holds centrally) — and every one is
    /// sanctioned. That is exactly the 30 of the table's 37 rows that have reached the bundle;
    /// the other 7 are cited only in footnotes or front matter, so the supplement's cited-lot
    /// denominator never contained them. Note most RG 84 rows are NOT crossings: an F-lot cited
    /// as RG 84 and held in RG 84 agrees, which is why the count is 30 and not 57.
    @Test("Every cross-record-group row is one the shared acceptance rule sanctions")
    func crossRecordGroupRowsAreSanctioned() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        var crossed = 0
        for lot in index.lotFiles {
            // `lotFileRecordGroup` returns the PREFIXED form ("RG-59"), and `LotFileEntry`
            // stores the bare one ("59") — the two-form split `ArchivalResolver`'s own doc
            // comment warns about. Without `bareRG` every row reads as a crossing and this
            // test fires 1,035 times against a correct artifact; it did, on the first run.
            let cited = CollectionKeying.bareRG(
                SourceNoteParser.lotFileRecordGroup(lot.lotNumber)) ?? "59"
            guard lot.recordGroup != cited else { continue }
            crossed += 1
            // Driven through the shared rule rather than by reading the table, so this pins the
            // POLICY and not a literal — a row admitted by some other route still fails.
            #expect(LotResolutionAcceptance.isAcceptable(
                recordGroup: cited,
                normalizedLot: lot.lotNumber,
                candidateRecordGroup: lot.recordGroup,
                levelOfDescription: lot.levelOfDescription ?? "series",
                variantControlNumbers: [lot.lotNumber]),
                    """
                    \(lot.lotNumber) is bundled under RG \(lot.recordGroup) but FRUS cites it as \
                    RG \(cited), and the O-7 table does not sanction that crossing
                    """)
        }
        #expect(crossed > 20,
                "guard is vacuous — only \(crossed) cross-record-group rows found, expected 30")
    }

    /// The #321 app-side guard: entries whose resolved record has no record-group ancestry —
    /// measured 0/16 precision, every one a presidential-library staff file — must be
    /// invisible through the accessor, so the Source Explorers fall back to the live lookup
    /// instead of shipping a confidently wrong NARA link.
    @Test("Flagged mis-resolutions are treated as unresolved by the accessor")
    func flaggedEntriesAreUnresolvedThroughAccessor() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        let flagged = index.lotFiles.filter { $0.ancestryLacksRecordGroup == true }
        // 16 at the 2026-07-15 harvest. If a future resolver fix (#321) re-harvests cleanly,
        // this set may legitimately empty — the guard then simply has nothing to do, and the
        // loop below is vacuously satisfied. The count expectation documents today's reality
        // without blocking that future: it asserts only when any flags exist at all.
        if !flagged.isEmpty {
            for lot in flagged {
                #expect(index.lotFile(forRawLot: lot.lotNumber) == nil,
                        "flagged lot \(lot.lotNumber) leaked through the #321 guard")
            }
            // The known Ford-library case from the measurement, pinned explicitly.
            #expect(index.lotFile(forRawLot: "32 D 66") == nil)
        }
        // Unflagged entries must be unaffected by the guard.
        #expect(index.lotFile(forRawLot: "81 D 208") != nil)
    }

    /// The #321 guard exercised against a SYNTHETIC fixture, independent of the bundle's
    /// content. The bundled-artifact test above went vacuous the day #340 pruned the 16
    /// flagged lots from the shipped index (by design — it only loops when flags exist), which
    /// left the accessor's `ancestryLacksRecordGroup` branch with no executing coverage
    /// anywhere. This fixture keeps the guard permanently under test: a flagged entry must be
    /// invisible through the accessor, an unflagged sibling must resolve, and the flag must
    /// not leak through lot-number normalization.
    @Test("The #321 guard drops flagged entries in a synthetic index")
    func flaggedGuardSyntheticFixture() throws {
        let json = """
        {
          "numericalFile": { "seriesNaId": "654171", "microfilm": "M862", "rolls": [] },
          "lotFiles": [
            { "lotNumber": "32D66", "recordGroup": "RG 59", "naId": "1", "title": "Ford Library staff file",
              "catalogURL": "https://catalog.archives.gov/id/1", "matchType": "control",
              "ancestryLacksRecordGroup": true },
            { "lotNumber": "81D208", "recordGroup": "RG 59", "naId": "2", "title": "Human Rights Country Files",
              "catalogURL": "https://catalog.archives.gov/id/2", "matchType": "control" }
          ]
        }
        """
        let index = try JSONDecoder().decode(CentralFilesIndex.self, from: Data(json.utf8))
        // The flagged entry is present in the data but invisible through the accessor —
        // including via every raw spelling the normalizer folds to the same key.
        #expect(index.lotFiles.contains { $0.lotNumber == "32D66" })
        #expect(index.lotFile(forRawLot: "32 D 66") == nil)
        #expect(index.lotFile(forRawLot: "Lot 32-D 66") == nil)
        // The unflagged sibling resolves normally.
        #expect(index.lotFile(forRawLot: "81 D 208")?.naId == "2")
    }

    /// The #351 guard against a SYNTHETIC fixture: a `fileUnit`-level lot resolution — a
    /// control-number query that landed on a folder inside another collection (the #335-audited
    /// 60 D 627 → "Operation Mongoose" class) — must be invisible through the accessor, while a
    /// `series`-level sibling resolves, and a `nil`-level (un-enriched) entry is still accepted
    /// (absent evidence is not evidence of a fileUnit).
    @Test("The #351 guard drops fileUnit-level entries in a synthetic index")
    func fileUnitGuardSyntheticFixture() throws {
        let json = """
        {
          "numericalFile": { "seriesNaId": "654171", "microfilm": "M862", "rolls": [] },
          "lotFiles": [
            { "lotNumber": "60D627", "recordGroup": "RG 59", "naId": "609235170",
              "title": "Files Pertaining to Operation Mongoose",
              "catalogURL": "https://catalog.archives.gov/id/609235170", "matchType": "control",
              "levelOfDescription": "fileUnit" },
            { "lotNumber": "64D199", "recordGroup": "RG 59", "naId": "602231",
              "title": "Conference Files", "catalogURL": "https://catalog.archives.gov/id/602231",
              "matchType": "control", "levelOfDescription": "series" },
            { "lotNumber": "70D100", "recordGroup": "RG 59", "naId": "3", "title": "Un-enriched lot",
              "catalogURL": "https://catalog.archives.gov/id/3", "matchType": "control" }
          ]
        }
        """
        let index = try JSONDecoder().decode(CentralFilesIndex.self, from: Data(json.utf8))
        // The fileUnit entry is present in the data but invisible through the accessor —
        // including via every raw spelling the normalizer folds to the same key.
        #expect(index.lotFiles.contains { $0.lotNumber == "60D627" })
        #expect(index.lotFile(forRawLot: "60 D 627") == nil)
        #expect(index.lotFile(forRawLot: "Lot 60-D 627") == nil)
        #expect(index.lotFiles.first { $0.lotNumber == "60D627" }?.isFileUnitLevel == true)
        // A series-level sibling resolves normally, and an un-enriched (nil-level) entry is
        // not swept up by the guard.
        #expect(index.lotFile(forRawLot: "64 D 199")?.naId == "602231")
        #expect(index.lotFile(forRawLot: "70 D 100")?.naId == "3")
        // The fileUnit NAID is exposed as untrustworthy (so the sibling bundles' render-time
        // guards suppress it); the series and un-enriched NAIDs are not.
        #expect(index.untrustworthyNAIDs == ["609235170"])
        #expect(index.isUntrustworthyNAID("609235170"))
        #expect(!index.isUntrustworthyNAID("602231"))
        #expect(!index.isUntrustworthyNAID("3"))
        #expect(!index.isUntrustworthyNAID(nil))
        #expect(!index.isUntrustworthyNAID(""))
    }

    /// An OCR-mangled country-roll date (a stray case number in the title parsed as an
    /// implausible year) must be ignored, not used to *exclude* the roll from date-filtered
    /// queries (NARA review 2026-07-17; 8 such rolls measured, 7 of them date-inverted).
    @Test("A mangled country-roll date is ignored, not used to silently exclude the roll")
    func countryRollMangledDateDoesNotExclude() {
        // "…- August 31, 139" → endISO 1596 makes the range inverted; the valid start is kept.
        let inverted = CountryRoll(naId: "1", title: "x", geoKeys: ["US"],
                                   startISO: "1895-07-07", endISO: "1596-08-31",
                                   catalogURL: "u", fileUnitNaId: nil, fileUnitTitle: nil)
        #expect(inverted.matches(geoKey: "US", dateISO: "1896-01-01"),
                "the roll must not vanish from an in-range date query")
        // "Nov. 1, 11186 -" → startISO 1318 (pre-1780) is ignored; the valid end filters.
        let badStart = CountryRoll(naId: "2", title: "x", geoKeys: ["US"],
                                   startISO: "1318-11-01", endISO: "1887-05-31",
                                   catalogURL: "u", fileUnitNaId: nil, fileUnitTitle: nil)
        #expect(badStart.matches(geoKey: "US", dateISO: "1886-01-01"))
        #expect(!badStart.matches(geoKey: "US", dateISO: "1900-01-01"))   // past the valid end
        // BOTH bounds in-window but inverted ("January 10, 1870 - March 31, 1861": 1870 > 1861) —
        // the larger, 151-roll class. Unguarded it would be unsatisfiable; instead geography wins.
        let inWindowInverted = CountryRoll(naId: "4", title: "x", geoKeys: ["FR"],
                                           startISO: "1870-01-10", endISO: "1861-03-31",
                                           catalogURL: "u", fileUnitNaId: nil, fileUnitTitle: nil)
        #expect(inWindowInverted.matches(geoKey: "FR", dateISO: "1865-06-01"),
                "an in-window inverted range must not silently hide the roll")
        #expect(!inWindowInverted.matches(geoKey: "US", dateISO: "1865-06-01"))   // wrong geo still excluded
        // A clean range still filters precisely and honours geography.
        let clean = CountryRoll(naId: "3", title: "x", geoKeys: ["US"],
                                startISO: "1890-01-01", endISO: "1895-12-31",
                                catalogURL: "u", fileUnitNaId: nil, fileUnitTitle: nil)
        #expect(clean.matches(geoKey: "US", dateISO: "1892-06-01"))
        #expect(!clean.matches(geoKey: "US", dateISO: "1899-01-01"))
        #expect(!clean.matches(geoKey: "FR", dateISO: "1892-06-01"))
        // The plausibility filter itself.
        #expect(CountryRoll.plausibleDate("1596-08-31") == nil)
        #expect(CountryRoll.plausibleDate("1318-11-01") == nil)
        #expect(CountryRoll.plausibleDate("1887-05-31") == "1887-05-31")
        #expect(CountryRoll.plausibleDate(nil) == nil)
    }
}

// MARK: - W-8: the chronological-run consular tail in the bundle

/// The bundled index's three consular-tail series (W-8, harvested OFFLINE from the
/// record-group shard) and the date-only resolution path they ride.
struct ConsularTailBundleTests {

    @Test("The bundle carries all three tail series at their NARA-stated volume counts")
    func bundleCarriesTailSeries() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        // Counts are NARA's own fileUnitCount per series, verified by the offline pass.
        let expected: [(CentralFilesSeriesCategory, String, Int)] = [
            (.consularInstructions, "604019", 7),
            (.notesToForeignConsuls, "1076611", 4),
            (.notesFromForeignConsuls, "1076629", 11),
        ]
        for (category, seriesNaId, rollCount) in expected {
            let series = try #require(index.series(category: category),
                                      "\(category.rawValue) missing from the bundle")
            #expect(series.seriesNaId == seriesNaId)
            #expect(series.rolls.count == rollCount)
            // Chronological runs carry NO geography — the reason matchesDate exists.
            #expect(series.rolls.allSatisfy { $0.geoKeys.isEmpty })
        }
    }

    @Test("The tail golden checks resolve through the bundle by date alone")
    func tailGoldenChecks() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        let goldens: [(CentralFilesSeriesCategory, String, String)] = [
            (.consularInstructions, "1810-05-01", "220862827"),
            (.notesToForeignConsuls, "1866-01-15", "40038222"),
            (.notesFromForeignConsuls, "1864-06-01", "216891526"),
        ]
        for (category, dateISO, expectedNaId) in goldens {
            let series = try #require(index.series(category: category))
            let hits = series.rolls(containingDate: dateISO)
            #expect(hits.contains { $0.naId == expectedNaId },
                    "\(category.rawValue) @ \(dateISO) should include \(expectedNaId)")
        }
    }

    @Test("A date outside a tail series' coverage resolves to nothing, never to everything")
    func tailCoverageGapsAreHonest() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        // Consular Instructions' volumes end in 1834 (NARA describes no later volumes) —
        // an 1890 instruction must miss, not match the whole run.
        let instructions = try #require(index.series(category: .consularInstructions))
        #expect(instructions.rolls(containingDate: "1890-06-01").isEmpty)
        // Notes to Foreign Consuls starts 1853.
        let notesTo = try #require(index.series(category: .notesToForeignConsuls))
        #expect(notesTo.rolls(containingDate: "1850-01-01").isEmpty)
    }
}
