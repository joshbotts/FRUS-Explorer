// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - CitationMatchingEngineTests

@MainActor
struct CitationMatchingEngineTests {

    // MARK: - Helpers

    /// Returns a minimal `VolumeManifestEntry` for test fixtures.
    private func makeVolume(
        volumeId: String,
        subseries: String,
        title: String,
        documentCount: Int = 50,
        publicationDate: String = "1969"
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId,
            filename: "\(volumeId).xml",
            subseries: subseries,
            title: title,
            dateRange: DateRange(earliest: "1969-01-01", latest: "1969-12-31"),
            publicationDate: publicationDate,
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: documentCount,
            sizeBytes: 0,
            tags: []
        )
    }

    private func makeManifestStore(volumes: [VolumeManifestEntry]) -> ManifestStore {
        ManifestStore(bundledEntries: volumes)
    }

    // MARK: - Era Detection Tests

    @Test("CitationMatchingEngineTest: isPreModernVolume — pre-1955 volume identified correctly")
    func preModernVolumeDetectionTest() async {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )
        let oldVol  = makeVolume(volumeId: "frus1861v01", subseries: "1861", title: "FRUS 1861")
        let newVol  = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76", title: "FRUS 1969-76 Vol I")
        let oldVol2 = makeVolume(volumeId: "frus1950v01", subseries: "1950", title: "FRUS 1950")

        await #expect(engine.isPreModernVolume(oldVol))
        await #expect(!engine.isPreModernVolume(newVol))
        await #expect(engine.isPreModernVolume(oldVol2))
    }

    @Test("CitationMatchingEngineTest: isMicroficheSupplement — microfiche volumes detected")
    func microficheDetectionTest() async {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )
        let micro  = makeVolume(volumeId: "frus1969-76v01micro", subseries: "1969-76",
                                title: "FRUS 1969-76 Vol I Microfiche Supplement")
        let normal = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                                title: "FRUS 1969-76 Vol I")

        await #expect(engine.isMicroficheSupplement(micro))
        await #expect(!engine.isMicroficheSupplement(normal))
    }

    @Test("CitationMatchingEngineTest: isMicroficheSupplement — the five microfiche supplements, and not the printed 1914–1918 World War supplements (#1474 review round 3)")
    func microficheRuleIsTheMicroficheSupplementsAlone() async throws {
        let engine = manifestEngine([])
        // A printed supplement, titled as the manifest titles it: its pages are a book's.
        let worldWar = makeVolume(volumeId: "frus1917Supp01v01", subseries: "1917",
                                  title: "Papers Relating to the Foreign Relations of the United States, 1917, Supplement 1, The World War")
        await #expect(!engine.isMicroficheSupplement(worldWar))
        // A microfiche supplement whose title does not say so: the id is the only sign.
        let untitled = makeVolume(volumeId: "frus1961-63v07-09mSupp", subseries: "1961-63",
                                  title: "Foreign Relations of the United States, 1961–1963, Volumes VII, VIII, IX, Arms Control; National Security Policy; Foreign Economic Policy")
        await #expect(engine.isMicroficheSupplement(untitled))
        // The id's `msupp` is matched in any case. (A retyped link never reaches this in lower
        // case: `match(reference:)` hands it the manifest's entry, spelled `mSupp`. This row pins
        // the case-insensitive test itself.)
        let lowerCase = makeVolume(volumeId: "frus1955-57v03msupp", subseries: "1955-57", title: "China")
        await #expect(engine.isMicroficheSupplement(lowerCase))

        // Over the bundled manifest, exactly the five volumes whose facsimile page breaks, which
        // restart with every document, are interleaved with typeset breaks that run on
        // (`measure_supplement_scope.py`, round 3). A sixth volume carries facsimile breaks,
        // `frus1981-88v16`, whose 88 documents each number theirs from 1; it is not a microfiche
        // supplement, and both page rules run there.
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self, from: Data(contentsOf: url))
        var skipped: [String] = []
        for entry in entries {
            if await engine.isMicroficheSupplement(entry) { skipped.append(entry.volumeId) }
        }
        #expect(skipped.sorted() == ["frus1955-57v03mSupp", "frus1958-60v03mSupp", "frus1958-60v05mSupp",
                                     "frus1961-63v07-09mSupp", "frus1961-63v10-12mSupp"], "\(skipped)")
    }

    // MARK: - Volume Resolution Tests

    @Test("CitationMatchingEngineTest: resolveVolume — exact subseries match narrows candidates")
    func volumeResolutionSubseriesTest() async {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76", title: "FRUS 1969-76 Vol I")
        let v2 = makeVolume(volumeId: "frus1977-80v01", subseries: "1977-80", title: "FRUS 1977-80 Vol I")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1, v2]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let candidates = await engine.resolveVolume(subseries: "1969-76", volumeNumber: nil, titleFragment: nil)
        #expect(candidates.count == 1)
        #expect(candidates.first?.volumeId == "frus1969-76v01")
    }

    @Test("CitationMatchingEngineTest: resolveVolume — title fragment narrows ambiguous volume list")
    func volumeResolutionTitleFragmentTest() async {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol I Foundations of Foreign Policy")
        let v2 = makeVolume(volumeId: "frus1969-76v02", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol II Vietnam")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1, v2]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let candidates = await engine.resolveVolume(
            subseries: "1969-76",
            volumeNumber: nil,
            titleFragment: "Vietnam"
        )
        #expect(candidates.count == 1)
        #expect(candidates.first?.volumeId == "frus1969-76v02")
    }

    // MARK: - Manifest-Only Tests

    @Test("CitationMatchingEngineTest: undownloaded volume returns requiresDownload = true")
    func undownloadedVolumeTest() async throws {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol I", documentCount: 50)
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []  // not downloaded
        )

        let input = CitationInput(subseries: "1969-76", volumeNumber: "I", documentNumber: 10)
        let results = try await engine.match(input: input)

        #expect(!results.isEmpty)
        let first = results.first
        #expect(first?.requiresDownload == true)
        #expect(first?.volumeManifestEntry != nil)
        #expect(first?.matchStrategy == .manifestOnly)
    }

    // MARK: - Round-trip / print-year subseries correction (#216)

    /// The six real pre-1906 "Papers Relating to Foreign Affairs" part volumes that collide on the
    /// 1864 *print* year: `frus1863p1/p2` (subseries 1863) and `frus1864p1..p4` (subseries 1864).
    /// Titles carry the embedded newlines the TEI manifest holds, so the token match is exercised
    /// against real-shaped data. They differ only by First/Second Session and Part I/II/III/IV.
    private func pre1906PartFixture() -> [VolumeManifestEntry] {
        func title(session: String, part: String) -> String {
            "Papers Relating to Foreign Affairs, Accompanying the Annual\n"
            + "                    Message of the President to the \(session) Session Thirty-eighth Congress, Part\n"
            + "                    \(part)"
        }
        return [
            makeVolume(volumeId: "frus1863p1", subseries: "1863", title: title(session: "First",  part: "I"),   documentCount: 0, publicationDate: "1864"),
            makeVolume(volumeId: "frus1863p2", subseries: "1863", title: title(session: "First",  part: "II"),  documentCount: 0, publicationDate: "1864"),
            makeVolume(volumeId: "frus1864p1", subseries: "1864", title: title(session: "Second", part: "I"),   documentCount: 0, publicationDate: "1864"),
            makeVolume(volumeId: "frus1864p2", subseries: "1864", title: title(session: "Second", part: "II"),  documentCount: 0, publicationDate: "1865"),
            makeVolume(volumeId: "frus1864p3", subseries: "1864", title: title(session: "Second", part: "III"), documentCount: 0, publicationDate: "1865"),
            makeVolume(volumeId: "frus1864p4", subseries: "1864", title: title(session: "Second", part: "IV"),  documentCount: 0, publicationDate: "1866"),
        ]
    }

    @Test("CitationMatchingEngineTest: the app's own frus1863p2/d1 citation round-trips back to frus1863p2 (#216)")
    func roundTripPre1906PartVolume() async throws {
        let entries = pre1906PartFixture()
        let p2 = entries[1]

        // 1) Format the app's own citation for frus1863p2 / Document 1 (its only year is the 1864
        //    print year; the title is the sole disambiguator).
        let formatter = HistoryAtStateCitationFormatter()
        let citation = formatter.format(
            document: FRUSDocumentMetadata(documentId: "frus1863p2_d1", documentNumber: "1",
                                           header: "Mr. Seward to Mr. Adams.",
                                           dateline: "Department of State, Washington, July 6, 1863."),
            volume: FRUSVolumeMetadata(p2)
        )
        #expect(citation.contains("1864"))
        #expect(citation.contains("First Session"))
        #expect(citation.contains("Part II"))

        // 2) Parse it back and hand the engine the parse WHOLE, as CitationLookupView.performLookup
        //    does through `CitationLookupFields.input` since #1474 — title fragment, and the
        //    "Part II" the parser now reads as part 2, included. (This test used to copy four
        //    fields by hand, the pattern #1474 removed from BatchCitationRunner because it dropped
        //    every field added since; a copy without the part never ran part matching here.)
        let parsed = CitationParser().parse(citation)
        #expect(parsed.partNumber == 2)

        // 3) Match against the six real entries (index-free manifestOnly path — no SearchService).
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: entries),
            searchService: nil, pageRangeStore: nil, downloadedVolumeIds: []
        )
        let results = try await engine.match(input: parsed)

        // 4) It must resolve to frus1863p2 — NOT frus1863p1 (wrong part) and NOT any frus1864
        //    (the print-year subseries group).
        #expect(results.first?.volumeId == "frus1863p2")
        #expect(!results.contains { $0.volumeId == "frus1863p1" })
        #expect(!results.contains { $0.volumeId.hasPrefix("frus1864") })

        // The citation's only year is 1864, which frus1863p2's subseries is not — but it is the year
        // the volume was printed, so every cited field is met and the row keeps the plain "Volume
        // identified" label rather than #1474's best guess.
        #expect(results.first?.confidenceLabel == ConfidenceLabels.manifestOnly)
        #expect(results.first?.correctionNote == nil)
    }

    @Test("CitationMatchingEngineTest: resolveVolume lets a title fragment override a print-year subseries (#216)")
    func resolveVolumeTitleCorrectsSubseries() async {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: pre1906PartFixture()),
            searchService: nil, pageRangeStore: nil, downloadedVolumeIds: []
        )
        // subseries "1864" is the wrong (print-year) group; the frus1863p2 title fragment corrects it.
        let corrected = await engine.resolveVolume(
            subseries: "1864",
            volumeNumber: nil,
            titleFragment: "Papers Relating to Foreign Affairs Accompanying the Annual Message of the President to the First Session Thirty-eighth Congress Part II"
        )
        #expect(corrected.first?.volumeId == "frus1863p2")

        // And when the title agrees with the subseries, resolution stays put (no false override).
        let agree = await engine.resolveVolume(
            subseries: "1864",
            volumeNumber: nil,
            titleFragment: "Papers Relating to Foreign Affairs Accompanying the Annual Message of the President to the Second Session Thirty-eighth Congress Part III"
        )
        #expect(agree.first?.volumeId == "frus1864p3")
    }

    // MARK: - No-Match Tests

    @Test("CitationMatchingEngineTest: completely unresolvable citation returns empty results")
    func noMatchTest() async throws {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let input = CitationInput(subseries: "1999-00", volumeNumber: "XXII", documentNumber: 5)
        let results = try await engine.match(input: input)
        // Either empty or a best-guess with no real document
        let hasRealDocuments = results.contains { !$0.documentId.isEmpty && !$0.requiresDownload }
        #expect(!hasRealDocuments)
    }

    // MARK: - Non-Actionable Input Test

    @Test("CitationMatchingEngineTest: non-actionable input returns empty results without error")
    func nonActionableInputTest() async throws {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let input = CitationInput()  // no fields set
        let results = try await engine.match(input: input)
        #expect(results.isEmpty)
    }

    // MARK: - Subseries Normalization Tests

    @Test("CitationMatchingEngineTest: subseries with en dash normalizes to match hyphen in manifest")
    func subseriesNormalizationTest() async {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol I")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        // En dash variant should still resolve
        let candidates = await engine.resolveVolume(subseries: "1969–76", volumeNumber: nil, titleFragment: nil)
        #expect(!candidates.isEmpty)
        #expect(candidates.first?.volumeId == "frus1969-76v01")
    }

    // MARK: - Pre-Modern Label Test

    @Test("CitationMatchingEngineTest: pre-modern volume detection returns correct era bool")
    func preModernEraTest() async {
        let v1955 = makeVolume(volumeId: "frus1955-57v01", subseries: "1955-57", title: "FRUS 1955-57 Vol I")
        let v1954 = makeVolume(volumeId: "frus1952-54v01", subseries: "1952-54", title: "FRUS 1952-54 Vol I")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        // 1955-57 straddles the boundary: subseries starts at 1955, not before 1955
        await #expect(!engine.isPreModernVolume(v1955))
        // 1952-54 is pre-modern
        await #expect(engine.isPreModernVolume(v1954))
    }

    // MARK: - Parts and whole-word volume numerals (#1474)

    /// Real 1952–1954 manifest rows, titles as the manifest spells them (embedded line breaks
    /// included): three part volumes beside single volumes whose numerals contain the cited ones.
    private func fiftyTwoFixture() -> [VolumeManifestEntry] {
        func title(_ rest: String) -> String { "Foreign Relations of the United States, 1952–1954, \(rest)" }
        let rows: [(String, String)] = [
            ("frus1952-54v01p1", "General:\n                    Economic and Political Matters, Volume I, Part 1"),
            ("frus1952-54v01p2", "General:\n                    Economic and Political Matters, Volume I, Part 2"),
            ("frus1952-54v02p1", "National\n                    Security Affairs, Volume II, Part 1"),
            ("frus1952-54v02p2", "National\n                    Security Affairs, Volume II, Part 2"),
            ("frus1952-54v03", "United\n                    Nations Affairs, Volume III"),
            ("frus1952-54v04", "The\n                    American Republics, Volume IV"),
            ("frus1952-54v05p1", "Western\n                    European Security, Volume V, Part 1"),
            ("frus1952-54v05p2", "Western\n                    European Security, Volume V, Part 2"),
            ("frus1952-54v06p1", "Western\n                    Europe and Canada, Volume VI, Part 1"),
            ("frus1952-54v07p1", "Germany\n                    and Austria, Volume VII, Part 1"),
            ("frus1952-54v08", "Eastern\n                    Europe; Soviet Union; Eastern Mediterranean, Volume VIII"),
        ]
        return rows.map { makeVolume(volumeId: $0.0, subseries: "1952-54", title: title($0.1)) }
    }

    /// An engine over `volumes`, none downloaded — the manifest-only path, no index needed.
    private func manifestEngine(_ volumes: [VolumeManifestEntry]) -> CitationMatchingEngine {
        CitationMatchingEngine(manifestStore: makeManifestStore(volumes: volumes),
                               searchService: nil, pageRangeStore: nil, downloadedVolumeIds: [])
    }

    @Test("CitationMatchingEngineTest: resolveVolume — a named part narrows Volume II to that part (#1474)")
    func partNarrowsResolution() async {
        let engine = manifestEngine(fiftyTwoFixture())
        let partTwo = await engine.resolveVolume(subseries: "1952-54", volumeNumber: "II",
                                                 partNumber: 2, titleFragment: nil)
        #expect(partTwo.map(\.volumeId) == ["frus1952-54v02p2"])
        let partOne = await engine.resolveVolume(subseries: "1952-54", volumeNumber: "II",
                                                 partNumber: 1, titleFragment: nil)
        #expect(partOne.map(\.volumeId) == ["frus1952-54v02p1"])
    }

    @Test("CitationMatchingEngineTest: resolveVolume — a volume numeral is a whole word: II is not III, V is not VI–VIII, I is not II–IV (#1474)")
    func volumeNumeralIsAWholeWord() async {
        let engine = manifestEngine(fiftyTwoFixture())
        let two = await engine.resolveVolume(subseries: "1952-54", volumeNumber: "II", titleFragment: nil)
        #expect(two.map(\.volumeId) == ["frus1952-54v02p1", "frus1952-54v02p2"])
        let five = await engine.resolveVolume(subseries: "1952-54", volumeNumber: "V", titleFragment: nil)
        #expect(five.map(\.volumeId) == ["frus1952-54v05p1", "frus1952-54v05p2"])
        let one = await engine.resolveVolume(subseries: "1952-54", volumeNumber: "I", titleFragment: nil)
        #expect(one.map(\.volumeId) == ["frus1952-54v01p1", "frus1952-54v01p2"])
    }

    @Test("CitationMatchingEngineTest: resolveVolume — an Arabic volume number typed in Structured Entry matches its Roman volume (#1474)")
    func arabicVolumeNumberMatches() async {
        let engine = manifestEngine(fiftyTwoFixture())
        let two = await engine.resolveVolume(subseries: "1952-54", volumeNumber: "2", titleFragment: nil)
        #expect(two.map(\.volumeId) == ["frus1952-54v02p1", "frus1952-54v02p2"])
        let eight = await engine.resolveVolume(subseries: "1952-54", volumeNumber: "8", titleFragment: nil)
        #expect(eight.map(\.volumeId) == ["frus1952-54v08"])
    }

    @Test("CitationMatchingEngineTest: resolveVolume — a part volume matches its numeral, and a VII–IX microfiche supplement is not Volume VII (#1474)")
    func partVolumeMatchesItsNumeral() async {
        // The id ends in the part, not in "vNN", and the title breaks the line between "Volume"
        // and the numeral: the old rule matched this volume to nothing.
        let korea = makeVolume(volumeId: "frus1964-68v29p1", subseries: "1964-68",
                               title: "Foreign Relations of the United States, 1964–1968, Volume\n                    XXIX, Part 1, Korea")
        let china = makeVolume(volumeId: "frus1964-68v30", subseries: "1964-68",
                               title: "Foreign Relations of the United States, 1964–1968, Volume\n                    XXX, China")
        // A range id names no single volume, so the supplement must not answer a citation of the
        // printed Volume VII beside it.
        let armsControl = makeVolume(volumeId: "frus1961-63v07", subseries: "1961-63",
                                     title: "Foreign Relations of the United States, 1961–1963, Volume\n                    VII, Arms Control and Disarmament")
        let supplement = makeVolume(volumeId: "frus1961-63v07-09mSupp", subseries: "1961-63",
                                    title: "Foreign Relations of the United States, 1961–1963, Volumes\n                    VII, VIII, IX, Arms Control; National Security Policy; Foreign Economic\n                    Policy")
        let engine = manifestEngine([korea, china, armsControl, supplement])
        let xxix = await engine.resolveVolume(subseries: "1964-68", volumeNumber: "XXIX", titleFragment: nil)
        #expect(xxix.map(\.volumeId) == ["frus1964-68v29p1"])
        let vii = await engine.resolveVolume(subseries: "1961-63", volumeNumber: "VII", titleFragment: nil)
        #expect(vii.map(\.volumeId) == ["frus1961-63v07"])
    }

    @Test("CitationMatchingEngineTest: a cited year the volume's title prints, or the year it was printed, meets the subseries (#1474)")
    func titleYearsAndPrintYearMeetTheSubseries() async throws {
        let conferences = makeVolume(volumeId: "frus1941-43", subseries: "1941-43",
                                     title: "Foreign Relations of the United States, The Conferences at\n                    Washington, 1941–1942, and Casablanca, 1943",
                                     publicationDate: "1958")
        let fortiethCongress = makeVolume(volumeId: "frus1868p1", subseries: "1868",
                                          title: "Papers Relating to Foreign Affairs, Accompanying the Annual\n                    Message of the President to the Third Session of the Fortieth Congress, Part\n                    I",
                                          publicationDate: "1869")
        let engine = manifestEngine([conferences, fortiethCongress])

        // No volume's subseries is 1941-42, but the one found prints "1941–1942" in its title.
        let titleYear = try await engine.match(input: CitationInput(subseries: "1941-42", documentNumber: 1,
                                                                    titleFragment: "Conferences Washington"))
        #expect(titleYear.first?.volumeId == "frus1941-43")
        #expect(titleYear.first?.confidenceLabel == ConfidenceLabels.manifestOnly)

        // No volume's subseries is 1869, the year frus1868p1 was printed and is cited by.
        let printYear = try await engine.match(input: CitationInput(subseries: "1869", partNumber: 1,
                                                                    documentNumber: 1))
        #expect(printYear.first?.volumeId == "frus1868p1")
        #expect(printYear.first?.confidenceLabel == ConfidenceLabels.manifestOnly)

        // The control: a year neither carries is still a best guess.
        let neither = try await engine.match(input: CitationInput(subseries: "1870", partNumber: 1,
                                                                  documentNumber: 1))
        #expect(neither.first?.volumeId == "frus1868p1")
        #expect(neither.first?.confidenceLabel != ConfidenceLabels.manifestOnly)
    }

    @Test("CitationMatchingEngineTest: resolveVolume — a volume that is not a numeral (E–5) matches the title that names it (#1474)")
    func nonNumeralVolumeMatchesItsTitle() async {
        let volumes = [
            makeVolume(volumeId: "frus1969-76v05", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume V, United Nations, 1969–1972"),
            makeVolume(volumeId: "frus1969-76ve05p1", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume\n                    E–5, Part 1, Documents on Sub-Saharan Africa, 1969–1972"),
            makeVolume(volumeId: "frus1969-76ve05p2", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume\n                    E–5, Part 2, Documents on North Africa, 1969–1972"),
            makeVolume(volumeId: "frus1969-76ve15p2Ed2", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume\n                    E–15, Part 2, Documents on Western Europe, 1973–1976, Second, Revised Edition"),
            makeVolume(volumeId: "frus1969-76ve01", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume\n                    E–1, Documents on Global Issues, 1969–1972"),
            makeVolume(volumeId: "frus1969-76ve10", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume\n                    E–10, Documents on American Republics, 1969–1972"),
        ]
        let engine = manifestEngine(volumes)
        // Typed with a hyphen or with the title's own en dash.
        for typed in ["E-5", "E–5", "e-5"] {
            let found = await engine.resolveVolume(subseries: "1969-76", volumeNumber: typed, titleFragment: nil)
            #expect(found.map(\.volumeId) == ["frus1969-76ve05p1", "frus1969-76ve05p2"], "\(typed)")
        }
        // And whole: a cited E-1 is a PREFIX of E–10 and E–15, so this is the case the closing
        // lookahead exists for (E-5 can never match E–15 with or without it). Without it, E-1 took
        // eleven volumes of the bundled manifest, E–10 through E–16, beside E–1's own.
        let one = await engine.resolveVolume(subseries: "1969-76", volumeNumber: "E-1", titleFragment: nil)
        #expect(one.map(\.volumeId) == ["frus1969-76ve01"])
    }

    @Test("CitationMatchingEngineTest: a volume that fails a cited field is offered as a best guess, not as the volume identified (#1474)")
    func unmetFieldRelabelsManifestOnly() async throws {
        let engine = manifestEngine(fiftyTwoFixture())
        // No 1952–54 volume is Volume XX, so every candidate is a volume the citation does not name.
        let unmet = try await engine.match(input: CitationInput(subseries: "1952-54", volumeNumber: "XX",
                                                                documentNumber: 5))
        #expect(!unmet.isEmpty)
        for result in unmet {
            #expect(result.requiresDownload, "\(result.volumeId)")
            #expect(result.confidenceLabel != ConfidenceLabels.manifestOnly, "\(result.volumeId)")
            #expect(result.confidenceLabel.contains("XX"), "\(result.confidenceLabel)")
            #expect(result.correctionNote != nil, "\(result.volumeId)")
        }

        // A volume that meets every cited field keeps the plain label and no note.
        let met = try await engine.match(input: CitationInput(subseries: "1952-54", volumeNumber: "II",
                                                              partNumber: 2, documentNumber: 41))
        #expect(met.map(\.volumeId) == ["frus1952-54v02p2"])
        #expect(met.first?.confidenceLabel == ConfidenceLabels.manifestOnly)
        #expect(met.first?.correctionNote == nil)
    }

    @Test("CitationMatchingEngineTest: the app's own citations of every bundled volume, in all three formats, never come back as a best guess (#1474)")
    func ownCitationsAreNeverBestGuesses() async throws {
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self, from: Data(contentsOf: url))
        #expect(entries.count > 500, "the bundled manifest decoded to \(entries.count) volumes")
        let engine = manifestEngine(entries)
        let parser = CitationParser()
        // The floor is how many round-trip to their own volume FIRST, measured on 2026-09-26. The
        // rest are ranked below a sibling or missed, as they were before #1474 (frus1919v01 below
        // frus1919Parisv01, the Turabian pre-1906 parts on their print-year neighbours, …); the
        // floor keeps a change to volume matching from quietly adding to them, as counting the
        // v10-12 microfiche supplement as Volume XII briefly did.
        let formats: [(name: String, formatter: any CitationFormatter, floor: Int)] = [
            ("history.state.gov", HistoryAtStateCitationFormatter(), 548),
            ("Chicago", ChicagoCitationFormatter(), 545),
            ("Turabian", TurabianCitationFormatter(), 532),
        ]
        for format in formats {
            var ownFirst = 0
            var bestGuesses: [String] = []
            for entry in entries {
                let citation = format.formatter.format(
                    document: FRUSDocumentMetadata(documentId: "d1", documentNumber: "1",
                                                   header: "Header", dateline: "Dateline"),
                    volume: FRUSVolumeMetadata(entry))
                let results = try await engine.match(input: parser.parse(citation))
                guard let first = results.first, first.volumeId == entry.volumeId else { continue }
                ownFirst += 1
                if first.confidenceLabel != ConfidenceLabels.manifestOnly {
                    bestGuesses.append("\(entry.volumeId): \(first.confidenceLabel)")
                }
            }
            // The measured count, for whoever next moves the floor.
            print("[CitationRoundTrip] \(format.name): \(ownFirst) of \(entries.count) resolve first to their own volume")
            #expect(bestGuesses.isEmpty, "\(format.name): \(bestGuesses)")
            #expect(ownFirst >= format.floor,
                    "\(format.name): \(ownFirst) of \(entries.count) citations resolve first to their own volume")
        }
    }

    @Test("CitationMatchingEngineTest: a footnote that opens with the document's date resolves to the volume it cites, and not as a best guess, over the bundled manifest (#1474 review round 3)")
    func datedFootnoteResolvesToItsVolume() async throws {
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self, from: Data(contentsOf: url))
        let engine = manifestEngine(entries)
        // Read as the subseries 1962, which no volume has, this fell back to the whole manifest and
        // came back as Volume V labelled "Best guess — … the cited subseries 1962"; v2, with no
        // such label, looked up Public Diplomacy's Volume VI first.
        let results = try await engine.match(input: CitationParser().parse(
            "Memorandum of Conversation, Moscow, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84"))
        #expect(results.map(\.volumeId) == ["frus1961-63v05"])
        #expect(results.first?.confidenceLabel == ConfidenceLabels.manifestOnly,
                "\(results.first?.confidenceLabel ?? "nil")")
    }

    @Test("CitationMatchingEngineTest: a link resolves to exactly the volume it names, even one prose cannot name (#1474)")
    func linkNamesItsVolume() async throws {
        let volumes = [
            makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972"),
            makeVolume(volumeId: "frus1969-76ve05p1", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume\n                    E–5, Part 1, Documents on Sub-Saharan Africa, 1969–1972"),
            makeVolume(volumeId: "frus1969-76ve05p2", subseries: "1969-76",
                       title: "Foreign Relations of the United States, 1969–1976, Volume\n                    E–5, Part 2, Documents on North Africa, 1969–1972"),
            makeVolume(volumeId: "frus1919Parisv01", subseries: "1919",
                       title: "Papers Relating to the Foreign Relations of the United States, The Paris Peace Conference, 1919, Volume I"),
            makeVolume(volumeId: "frus1919v01", subseries: "1919",
                       title: "Papers Relating to the Foreign Relations of the United States, 1919, Volume I"),
        ]
        let engine = manifestEngine(volumes)
        let parser = CitationParser()

        let eVolume = try await engine.match(input: parser.parse(
            FRUSCanonicalURL.string(volumeId: "frus1969-76ve05p1", documentId: "d10")))
        #expect(eVolume.map(\.volumeId) == ["frus1969-76ve05p1"])
        #expect(eVolume.first?.requiresDownload == true)
        #expect(eVolume.first?.confidenceLabel == ConfidenceLabels.manifestOnly)

        let paris = try await engine.match(input: parser.parse(
            FRUSCanonicalURL.string(volumeId: "frus1919Parisv01", documentId: "d5")))
        #expect(paris.map(\.volumeId) == ["frus1919Parisv01"])

        // A retyped, lower-cased link still reaches the manifest's own spelling.
        let lowered = try await engine.match(input: parser.parse(
            "https://history.state.gov/historicaldocuments/frus1919parisv01/d5"))
        #expect(lowered.map(\.volumeId) == ["frus1919Parisv01"])

        // An id the manifest does not have resolves to nothing, not to a sibling.
        let unknown = try await engine.match(input: parser.parse(
            FRUSCanonicalURL.string(volumeId: "frus1969-76ve99", documentId: "d10")))
        #expect(unknown.isEmpty)
    }

    @Test("CitationMatchingEngineTest: an E-volume link's fields, looked up in Structured Entry, still name that E-volume (#1474 review round 1)")
    func eVolumeLinkFieldsNameTheVolume() async throws {
        func eTitle(_ rest: String) -> String {
            "Foreign Relations of the United States, 1969–1976, Volume\n                    \(rest)"
        }
        let engine = manifestEngine([
            makeVolume(volumeId: "frus1969-76ve05p1", subseries: "1969-76",
                       title: eTitle("E–5, Part 1, Documents on Sub-Saharan Africa, 1969–1972")),
            makeVolume(volumeId: "frus1969-76ve05p2", subseries: "1969-76",
                       title: eTitle("E–5, Part 2, Documents on North Africa, 1969–1972")),
            makeVolume(volumeId: "frus1969-76ve14p1", subseries: "1969-76",
                       title: eTitle("E–14, Part 1, Documents on Arms Control and Nonproliferation, 1973–1976")),
        ])
        let parser = CitationParser()
        let url = FRUSCanonicalURL.string(volumeId: "frus1969-76ve05p1", documentId: "d10")
        let fields = CitationLookupFields().refreshed(forPaste: url, mode: .paste, parser: parser)
        #expect(fields.volume == "E-5")
        // Switched to Structured Entry, the link is not forwarded and the fields decide. Without the
        // E-number they named every 1969–76 Part 1, and a downloaded E–14 could answer as exact.
        let structured = try await engine.match(input: fields.input(mode: .structured, pasteText: url, parser: parser))
        #expect(structured.map(\.volumeId) == ["frus1969-76ve05p1"])
    }
}

// MARK: - CitationLookupIndexedTests

/// Citation Lookup against a real index (#1474): the parser, the form's fields and the matching
/// engine together, over small TEI volumes indexed by the real pipeline, so the document-number,
/// page and link strategies run their production lookups rather than a stub.
@Suite("Citation Lookup — fields, parts and links against a real index (#1474)")
struct CitationLookupIndexedTests {

    /// One fixture document: its id, printed number, and the pages it carries.
    private struct Doc {
        let id: String
        let number: String
        let pages: [Int]
        /// Page breaks between the previous document and this one, outside both — the corpus's
        /// commonest place for the break a document begins after (#1474 review rounds 2 and 3:
        /// 122,637 of the page breaks of the 548 volumes the page rules check sit there), which the
        /// index records against no document at all.
        var pagesBefore: [Int] = []
        /// Whether `pages` are a microfiche supplement's facsimile pages, which restart with every
        /// document (`<pb type="facsimile">`) — the index records them as arabic pages all the
        /// same (#1474 review round 3).
        var facsimile = false
        /// Page breaks inside the document div BEFORE its heading: the document opens at the top
        /// of a fresh page, on the break it carries itself (#1503).
        var pagesAtTop: [Int] = []
        /// Page breaks written between the previous document and this one exactly as spelled —
        /// `"[31]"` is a page printed without its number, as the nineteenth-century volumes write
        /// the first page of a section (#1503: 364 documents begin on one).
        var rawBreaksBefore: [String] = []
        /// Extra TEI appended to the document's body, e.g. a footnote holding a page reference.
        var body = ""
    }

    /// Creates a temporary directory, calls `body`, and cleans up after.
    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCitationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// Writes a minimal TEI volume whose documents carry `@n` and `<pb>` page breaks, with any
    /// `pagesBefore` breaks written between documents, as the corpus writes them.
    private func writeVolume(_ volumeId: String, _ docs: [Doc], to volDir: URL) throws {
        func breaks(_ pages: [Int]) -> String {
            pages.map { "<pb n=\"\($0)\" xml:id=\"pg_\($0)\"/>" }.joined()
        }
        // Facsimile pages repeat their numbers from one document to the next, so each break's id
        // is its document's.
        func facsimileBreaks(_ pages: [Int], of doc: Doc) -> String {
            pages.map { "<pb n=\"\($0)\" type=\"facsimile\" xml:id=\"\(doc.id)_pg_\($0)\"/>" }.joined()
        }
        func docBreaks(_ pages: [Int], of doc: Doc) -> String {
            doc.facsimile ? facsimileBreaks(pages, of: doc) : breaks(pages)
        }
        let divs = docs.map { doc in
            doc.rawBreaksBefore.map { "<pb n=\"\($0)\"/>" }.joined()
                + docBreaks(doc.pagesBefore, of: doc)
                + "<div type=\"document\" xml:id=\"\(doc.id)\" n=\"\(doc.number)\">"
                + docBreaks(doc.pagesAtTop, of: doc)
                + "<head>\(doc.number). Memorandum \(doc.id)</head>"
                + docBreaks(doc.pages, of: doc)
                + "<p>Text of \(doc.id).</p>\(doc.body)</div>"
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>1990</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="compilation" xml:id="comp1">
          \(divs)
          </div></body></text>
        </TEI>
        """
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("\(volumeId).xml"))
    }

    /// A manifest row for a fixture volume.
    private func entry(_ volumeId: String, _ subseries: String, _ title: String,
                       documentCount: Int = 0) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId, filename: "\(volumeId).xml", subseries: subseries, title: title,
            dateRange: DateRange(earliest: "1961-01-01", latest: "1963-12-31"),
            publicationDate: "1990", status: .published, editors: [], generalEditor: nil,
            documentCount: documentCount, sizeBytes: 0, tags: [])
    }

    /// Indexes `volumes` with the real pipeline, every one downloaded, and hands `body` an engine
    /// wired the way `AppState` wires it: the search service and the page-range store over one index.
    private func withEngine(
        _ volumes: [(entry: VolumeManifestEntry, docs: [Doc])],
        _ body: (CitationMatchingEngine) async throws -> Void
    ) async throws {
        try await withIndex(volumes) { engine, _ in try await body(engine) }
    }

    /// What `withEngine` builds, handed over whole: the engine, the page-range store it reads (the
    /// one the reader's page links call too), and the index's database file.
    private struct Index {
        let pages: PageRangeStore
        let databaseURL: URL
        let pipeline: IndexingPipeline
        let volumesDirectory: URL
    }

    /// `withEngine`, also handing `body` the page-range store and the database behind it.
    private func withIndex(
        _ volumes: [(entry: VolumeManifestEntry, docs: [Doc])],
        _ body: (CitationMatchingEngine, Index) async throws -> Void
    ) async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            for volume in volumes {
                try writeVolume(volume.entry.volumeId, volume.docs, to: volDir)
                try await pipeline.indexVolume(volume.entry.volumeId)
            }
            let service = SearchService(fts5Store: store, pipeline: pipeline)
            let databaseURL = dir.appendingPathComponent("test.sqlite")
            let pages = try PageRangeStore(databaseURL: databaseURL)
            let entries = volumes.map(\.entry)
            let manifestStore = await MainActor.run { ManifestStore(bundledEntries: entries) }
            let engine = CitationMatchingEngine(manifestStore: manifestStore, searchService: service,
                                                pageRangeStore: pages,
                                                downloadedVolumeIds: Set(entries.map(\.volumeId)))
            try await body(engine, Index(pages: pages, databaseURL: databaseURL, pipeline: pipeline,
                                         volumesDirectory: volDir))
        }
    }

    /// Volume V and Volume XIV of 1961–63, both carrying a document 84. XIV's d8 begins on page 50,
    /// below the end of d7 — its heading comes before its own first break, 51 — so page 50 is d8's
    /// (#1503; until then the page lookup answered d7, the document still running when page 50
    /// began). XIV's d84 begins at the top of page 199, on a break between documents: the fixture
    /// leaves out pages 52–198.
    private var sixtyOneVolumes: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [
            (entry("frus1961-63v05", "1961-63",
                   "Foreign Relations of the United States, 1961–1963, Volume V,\n                    Soviet Union",
                   documentCount: 85),
             [Doc(id: "d83", number: "83", pages: [180]), Doc(id: "d84", number: "84", pages: [181]),
              Doc(id: "d85", number: "85", pages: [182])]),
            (entry("frus1961-63v14", "1961-63",
                   "Foreign Relations of the United States, 1961–1963, Volume\n                    XIV, Berlin Crisis, 1961–1962",
                   documentCount: 84),
             [Doc(id: "d7", number: "7", pages: [49, 50]), Doc(id: "d8", number: "8", pages: [51]),
              Doc(id: "d84", number: "84", pages: [200], pagesBefore: [199])]),
        ]
    }

    /// Whether a strategy is the best-guess one (it carries an explanation, so `==` needs one).
    private func isBestGuess(_ strategy: MatchStrategy) -> Bool {
        if case .bestGuess = strategy { return true }
        return false
    }

    @Test("The issue's sequence: a page-only citation pasted after 'vol. V, doc. 84' finds page 50, not document 84 (#1474)")
    func pageOnlyCitationAfterDocumentCitation() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let parser = CitationParser()
            let first = "FRUS, 1961–1963, vol. V, doc. 84"
            var fields = CitationLookupFields().refreshed(forPaste: first, mode: .paste, parser: parser)
            let firstMatches = try await engine.match(input: fields.input(mode: .paste, pasteText: first, parser: parser))
            #expect(firstMatches.first?.volumeId == "frus1961-63v05")
            #expect(firstMatches.first?.documentId == "d84")
            #expect(firstMatches.first?.matchStrategy == .exactDocumentNumber)

            let second = "FRUS, 1961–1963, vol. XIV, p. 50"
            fields = fields.refreshed(forPaste: second, mode: .paste, parser: parser)
            let matches = try await engine.match(input: fields.input(mode: .paste, pasteText: second, parser: parser))
            #expect(matches.first?.volumeId == "frus1961-63v14")
            #expect(matches.first?.documentId == "d8")
            #expect(matches.first?.matchStrategy == .pageRange)
            #expect(!matches.contains { $0.documentId == "d84" })
        }
    }

    @Test("Exact match only when every cited field is met: a document found in a volume that is not the cited Volume XX is a best guess (#1474)")
    func unmetVolumeIsNotExact() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let matches = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XX",
                                                                      documentNumber: 84))
            #expect(!matches.isEmpty)
            #expect(matches.first?.documentId == "d84")
            for match in matches {
                #expect(isBestGuess(match.matchStrategy), "\(match.volumeId): \(match.matchStrategy)")
                #expect(match.confidenceLabel != ConfidenceLabels.exactMatch)
                #expect(match.confidenceLabel.contains("XX"), "\(match.confidenceLabel)")
                #expect(match.correctionNote != nil)
            }

            // The control: the cited volume, so an exact match.
            let met = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "V",
                                                                  documentNumber: 84))
            #expect(met.map(\.volumeId) == ["frus1961-63v05"])
            #expect(met.first?.matchStrategy == .exactDocumentNumber)
            #expect(met.first?.confidenceLabel == ConfidenceLabels.exactMatch)
        }
    }

    @Test("Exact match only when every cited field is met: a part the volume does not have makes it a best guess (#1474)")
    func unmetPartIsNotExact() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let matches = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "V",
                                                                      partNumber: 2, documentNumber: 84))
            #expect(matches.first?.volumeId == "frus1961-63v05")
            #expect(matches.first?.documentId == "d84")
            #expect(isBestGuess(matches.first?.matchStrategy ?? .exactDocumentNumber))
            #expect(matches.first?.confidenceLabel.contains("part 2") == true)
        }
    }

    @Test("Exact match only when every cited field is met: a subseries no volume has makes it a best guess (#1474)")
    func unmetSubseriesIsNotExact() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let matches = try await engine.match(input: CitationInput(subseries: "1999-00", volumeNumber: "V",
                                                                      documentNumber: 84))
            #expect(matches.first?.volumeId == "frus1961-63v05")
            #expect(matches.first?.documentId == "d84")
            #expect(isBestGuess(matches.first?.matchStrategy ?? .exactDocumentNumber))
            #expect(matches.first?.confidenceLabel.contains("1999-00") == true)
        }
    }

    @Test("A page match, and a nearest-document match, in a volume the citation does not name are best guesses too (#1474)")
    func unmetPageAndFuzzyAreBestGuesses() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let byPage = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XX",
                                                                     pageNumber: 50))
            let pageHit = try #require(byPage.first { $0.documentId == "d8" })
            #expect(isBestGuess(pageHit.matchStrategy), "\(pageHit.matchStrategy)")
            // The best guess keeps how it was found: the page-match label moves to its note
            // (#1474 review round 1), beside the warning.
            #expect(pageHit.correctionNote?.contains("pages 50–51") == true, "\(pageHit.correctionNote ?? "nil")")
            #expect(pageHit.correctionNote?.contains(ConfidenceLabels.unmetFieldsNote) == true)

            // Document 500 is past the end of both volumes: the nearest-document fallback runs on
            // the first candidate, which is not the cited Volume XX either. NOTE this half protects
            // a path the app cannot reach today: the fallback needs a manifest `documentCount`, the
            // fixture gives 85, and every one of the 553 bundled rows carries 0. It is kept because
            // the relabel is the same code as the page half's, and a manifest that gains counts
            // would reach it.
            let fuzzy = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XX",
                                                                    documentNumber: 500))
            let nearest = try #require(fuzzy.first { $0.documentId == "d85" })
            #expect(isBestGuess(nearest.matchStrategy), "\(nearest.matchStrategy)")
            // …and keeps its own note, which is the only place the substituted number is named.
            #expect(nearest.correctionNote?.contains("nearest available document is 85") == true,
                    "\(nearest.correctionNote ?? "nil")")

            // The control: the same fallback in the cited volume keeps its own label.
            let cited = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "V",
                                                                    documentNumber: 500))
            #expect(cited.first?.matchStrategy == .fuzzyDocumentNumber(nearest: 85))
        }
    }

    /// Volume II of 1952–54 in two parts, and Volume III, each with a document 41.
    private var fiftyTwoVolumes: [(entry: VolumeManifestEntry, docs: [Doc])] {
        func title(_ rest: String) -> String { "Foreign Relations of the United States, 1952–1954, \(rest)" }
        return [
            (entry("frus1952-54v02p1", "1952-54", title("National\n                    Security Affairs, Volume II, Part 1")),
             [Doc(id: "d41", number: "41", pages: [300])]),
            (entry("frus1952-54v02p2", "1952-54", title("National\n                    Security Affairs, Volume II, Part 2")),
             [Doc(id: "d41", number: "41", pages: [1050])]),
            (entry("frus1952-54v03", "1952-54", title("United\n                    Nations Affairs, Volume III")),
             [Doc(id: "d41", number: "41", pages: [90])]),
        ]
    }

    @Test("Structured Entry names Part 2 and gets Part 2's document; an unnamed part never admits Volume III (#1474)")
    func structuredPartResolvesThatPart() async throws {
        try await withEngine(fiftyTwoVolumes) { engine in
            let parser = CitationParser()
            var fields = CitationLookupFields()
            fields.subseries = "1952-54"
            fields.volume = "II"
            fields.part = "2"
            fields.document = "41"
            let structured = try await engine.match(input: fields.input(mode: .structured, pasteText: "", parser: parser))
            #expect(structured.first?.volumeId == "frus1952-54v02p2")
            #expect(!structured.contains { $0.volumeId == "frus1952-54v02p1" })

            // Pasted, the same citation lands on the same part.
            let pasted = "FRUS, 1952–1954, vol. II, pt. 2, doc. 41"
            let pastedFields = CitationLookupFields().refreshed(forPaste: pasted, mode: .paste, parser: parser)
            let fromPaste = try await engine.match(input: pastedFields.input(mode: .paste, pasteText: pasted, parser: parser))
            #expect(fromPaste.first?.volumeId == "frus1952-54v02p2")

            // No part named: both parts may answer, Volume III may not.
            fields.part = ""
            let noPart = try await engine.match(input: fields.input(mode: .structured, pasteText: "", parser: parser))
            #expect(Set(noPart.map(\.volumeId)) == ["frus1952-54v02p1", "frus1952-54v02p2"])
        }
    }

    /// frus1865p1 around its letter-suffixed document, which only a link can name.
    private var letterSuffixVolume: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [(entry("frus1865p1", "1865",
                "Papers Relating to Foreign Affairs, Accompanying the Annual\n                    Message of the President to the First Session Thirty-ninth Congress, Part\n                    I"),
          [Doc(id: "d373", number: "373", pages: [410]), Doc(id: "d373a", number: "373a", pages: [411]),
           Doc(id: "d374", number: "374", pages: [412])])]
    }

    @Test("A pasted history.state.gov link opens exactly the document it names, d373a included (#1474)")
    func linkResolvesExactly() async throws {
        try await withEngine(letterSuffixVolume + sixtyOneVolumes) { engine in
            let parser = CitationParser()
            let url = FRUSCanonicalURL.string(volumeId: "frus1865p1", documentId: "d373a")
            let fields = CitationLookupFields().refreshed(forPaste: url, mode: .paste, parser: parser)
            let matches = try await engine.match(input: fields.input(mode: .paste, pasteText: url, parser: parser))
            #expect(matches.count == 1)
            #expect(matches.first?.volumeId == "frus1865p1")
            #expect(matches.first?.documentId == "d373a")
            #expect(matches.first?.confidenceLabel == ConfidenceLabels.exactMatch)

            // A page link finds the page in exactly that volume.
            let pageURL = "https://history.state.gov/historicaldocuments/frus1961-63v14/pg_50"
            let pageMatches = try await engine.match(input: parser.parse(pageURL))
            #expect(pageMatches.first?.volumeId == "frus1961-63v14")
            #expect(pageMatches.first?.documentId == "d8")
            #expect(pageMatches.first?.matchStrategy == .pageRange)

            // A document the volume does not have is not answered with a different one: the link
            // still names the volume, and that is the one answer (#1474 review round 1).
            let missing = try await engine.match(input: parser.parse(
                FRUSCanonicalURL.string(volumeId: "frus1961-63v05", documentId: "d999")))
            #expect(missing.map(\.volumeId) == ["frus1961-63v05"])
            #expect(missing.first?.documentId == "")
            #expect(missing.first?.requiresDownload == false)
        }
    }

    @Test("A link to a volume or a section, beside the document or page it cites, finds that document in the linked volume (#1474 review round 1)")
    func volumeLinkBesideProse() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let parser = CitationParser()
            // The review's case: before this round the link overrode the prose, dropped `doc. 84`,
            // and found nothing in the downloaded volume.
            let text = "FRUS, 1961–1963, vol. V, doc. 84, https://history.state.gov/historicaldocuments/frus1961-63v05."
            let fields = CitationLookupFields().refreshed(forPaste: text, mode: .paste, parser: parser)
            let matches = try await engine.match(input: fields.input(mode: .paste, pasteText: text, parser: parser))
            #expect(matches.map(\.volumeId) == ["frus1961-63v05"])
            #expect(matches.first?.documentId == "d84")
            #expect(matches.first?.matchStrategy == .exactDocumentNumber)

            // A section link beside a page finds the document on that page, in the linked volume.
            let section = try await engine.match(input: parser.parse(
                "FRUS, 1961–1963, vol. XIV, p. 50 (https://history.state.gov/historicaldocuments/frus1961-63v14/ch3)."))
            #expect(section.map(\.documentId) == ["d8"])
            #expect(section.first?.matchStrategy == .pageRange)

            // Nothing beside it: the link still names its volume, and the one answer says so.
            for bare in ["https://history.state.gov/historicaldocuments/frus1961-63v14",
                         "https://history.state.gov/historicaldocuments/frus1961-63v14/ch3"] {
                let volumeOnly = try await engine.match(input: parser.parse(bare))
                #expect(volumeOnly.count == 1, "\(bare)")
                #expect(volumeOnly.first?.volumeId == "frus1961-63v14", "\(bare)")
                #expect(volumeOnly.first?.documentId == "", "\(bare)")
                #expect(volumeOnly.first?.requiresDownload == false, "\(bare)")
                #expect(volumeOnly.first?.volumeManifestEntry?.volumeId == "frus1961-63v14", "\(bare)")
                #expect(volumeOnly.first?.matchStrategy == .manifestOnly, "\(bare)")
                // Not "download to find the specific document": the volume is downloaded.
                #expect(volumeOnly.first?.confidenceLabel != ConfidenceLabels.manifestOnly, "\(bare)")
            }
        }
    }

    /// Volumes whose document ids are not `d` plus digits and letters, or carry a capital: 866 of
    /// the corpus's 314,571 document ids have the first shape (frus1945Berlinv02's 217 `d710a-1`,
    /// frus1958-60v05mSupp's 628 `eta_d1`, the frus1981-88 appendices), and `d550A` is the second.
    private var oddIdVolumes: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [
            (entry("frus1945Berlinv02", "1945",
                   "Foreign Relations of the United States: Diplomatic Papers, The Conference of Berlin (The Potsdam Conference), 1945, Volume II"),
             [Doc(id: "d709", number: "709", pages: [1]), Doc(id: "d710a-1", number: "710a-1", pages: [2])]),
            (entry("frus1958-60v05mSupp", "1958-60",
                   "Foreign Relations of the United States, 1958–1960, American Republics, Volume V, Microfiche Supplement"),
             [Doc(id: "eta_d1", number: "1", pages: [])]),
            (entry("frus1981-88v05", "1981-88",
                   "Foreign Relations of the United States, 1981–1988, Volume V, European Security, 1981–1988"),
             [Doc(id: "d1", number: "1", pages: [10]), Doc(id: "appA", number: "A", pages: [900])]),
            (entry("frus1955-57v03mSupp", "1955-57",
                   "Foreign Relations of the United States, 1955–1957, China, Volume III, Microfiche Supplement"),
             [Doc(id: "d550", number: "550", pages: []), Doc(id: "d550A", number: "550A", pages: [])]),
        ]
    }

    @Test("A link resolves every document-id shape in the corpus, as written and retyped in lower case (#1474 review round 1)")
    func linkResolvesEveryIdShape() async throws {
        try await withEngine(oddIdVolumes) { engine in
            let parser = CitationParser()
            let links = [("frus1945Berlinv02", "d710a-1"), ("frus1958-60v05mSupp", "eta_d1"),
                         ("frus1981-88v05", "appA"), ("frus1955-57v03mSupp", "d550A")]
            for (volumeId, documentId) in links {
                let url = FRUSCanonicalURL.string(volumeId: volumeId, documentId: documentId)
                let matches = try await engine.match(input: parser.parse(url))
                #expect(matches.map(\.documentId) == [documentId], "\(url)")
                #expect(matches.first?.matchStrategy == .exactDocumentNumber, "\(url)")
            }
            // A retyped link in lower case still reaches d550A, and not its neighbour d550.
            let retyped = try await engine.match(input: parser.parse(
                "https://history.state.gov/historicaldocuments/frus1955-57v03msupp/d550a"))
            #expect(retyped.map(\.documentId) == ["d550A"])
        }
    }

    @Test("A document number the cited page contradicts is a best guess, and the document on that page follows it (#1474 review round 1)")
    func pageContradictingTheDocumentIsNotExact() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            // Volume XIV's d84 is printed on pages 199–200; page 50 is where d8 begins.
            let matches = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XIV",
                                                                      documentNumber: 84, pageNumber: 50))
            let first = try #require(matches.first)
            #expect(first.documentId == "d84")
            #expect(isBestGuess(first.matchStrategy), "\(first.matchStrategy)")
            #expect(first.confidenceLabel.contains("page 50"), "\(first.confidenceLabel)")
            #expect(first.confidenceLabel != ConfidenceLabels.exactMatch)
            #expect(first.correctionNote != nil)
            #expect(matches.contains { $0.documentId == "d8" && $0.matchStrategy == .pageRange })
            // The label shows the pages the check accepts — 199, the page d84 begins on, as well as
            // its one break, 200 — and not the break alone, "pages 200–200" (review round 2).
            #expect(first.confidenceLabel == ConfidenceLabels.bestGuess(
                ConfidenceLabels.pageOutside(page: 50, first: 199, last: 200)), "\(first.confidenceLabel)")
            #expect(first.confidenceLabel.contains("(199–200)"), "\(first.confidenceLabel)")

            // A page AFTER the document's last break is outside it too (review round 2: every miss
            // above was below the first break, so the upper bound went untested). d7 ends on page
            // 50; page 51 is d8's, which follows.
            let pastTheEnd = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XIV",
                                                                         documentNumber: 7, pageNumber: 51))
            #expect(pastTheEnd.first?.documentId == "d7")
            #expect(isBestGuess(pastTheEnd.first?.matchStrategy ?? .exactDocumentNumber),
                    "\(pastTheEnd.first?.matchStrategy as Any)")
            #expect(pastTheEnd.first?.confidenceLabel.contains("(48–50)") == true,
                    "\(pastTheEnd.first?.confidenceLabel ?? "nil")")
            #expect(pastTheEnd.contains { $0.documentId == "d8" && $0.matchStrategy == .pageRange })

            // A page the document is printed on keeps the exact match, alone.
            let agreeing = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XIV",
                                                                       documentNumber: 84, pageNumber: 200))
            #expect(agreeing.map(\.documentId) == ["d84"])
            #expect(agreeing.first?.matchStrategy == .exactDocumentNumber)

            // So does the page a document begins on part-way down, whose page break is the
            // previous document's: d8's first break is 51, and it starts on page 50 below d7.
            let startPage = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XIV",
                                                                        documentNumber: 8, pageNumber: 50))
            #expect(startPage.map(\.documentId) == ["d8"])
            #expect(startPage.first?.matchStrategy == .exactDocumentNumber)
        }
    }

    /// Volume V of 1961–63 with documents that carry no page break of their own, as a third of the
    /// corpus's documents do (#1474 review round 2). d17 sits between d16's break 40 and d18's 41,
    /// so it is printed on page 40. d19 follows a break the corpus writes BETWEEN documents — 43,
    /// after d18 closes and before d19 opens — which until #1503 the index recorded against no
    /// document: it is printed on 43, while the last break the index held before it was d18's 42.
    /// Since #1503 the index records the page each document begins on, so both are exact: d17 on
    /// 40, d19 on 43 alone. d20's heading comes before its own break, 44, so it begins on 43 too.
    private var noBreakVolume: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [(entry("frus1961-63v05", "1961-63",
                "Foreign Relations of the United States, 1961–1963, Volume V,\n                    Soviet Union"),
          [Doc(id: "d16", number: "16", pages: [40]),
           Doc(id: "d17", number: "17", pages: []),
           Doc(id: "d18", number: "18", pages: [41, 42]),
           Doc(id: "d19", number: "19", pages: [], pagesBefore: [43]),
           Doc(id: "d20", number: "20", pages: [44])])]
    }

    @Test("A document with no page break of its own is checked against the cited page too (#1474 review round 2)")
    func documentWithNoPageBreakIsChecked() async throws {
        try await withEngine(noBreakVolume) { engine in
            func lookUp(_ document: Int, _ page: Int) async throws -> [CitationMatch] {
                try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "V",
                                                            documentNumber: document, pageNumber: page))
            }
            // The review's case: `vol. V, doc. 17, p. 500` was an exact match, because d17 has no
            // page break and so no page range, and no range meant no check.
            let wrongPage = try await lookUp(17, 500)
            #expect(wrongPage.first?.documentId == "d17")
            #expect(isBestGuess(wrongPage.first?.matchStrategy ?? .exactDocumentNumber),
                    "\(wrongPage.first?.matchStrategy as Any)")
            // One page between the breaks around it, so the label names that page.
            #expect(wrongPage.first?.confidenceLabel == ConfidenceLabels.bestGuess(
                ConfidenceLabels.pageOutside(page: 500, first: 40, last: 40)),
                    "\(wrongPage.first?.confidenceLabel ?? "nil")")
            #expect(wrongPage.first?.confidenceLabel.contains("(40)") == true)
            #expect(wrongPage.first?.correctionNote?.contains(ConfidenceLabels.pageOutsideNote) == true)

            // The page it is on keeps the exact match, alone.
            let rightPage = try await lookUp(17, 40)
            #expect(rightPage.map(\.documentId) == ["d17"])
            #expect(rightPage.first?.matchStrategy == .exactDocumentNumber)

            // d19 is printed on 43, a break between documents. "The last recorded break before it"
            // would say 42 and demote this correct citation; the page it begins on keeps it exact.
            let unrecordedBreak = try await lookUp(19, 43)
            #expect(unrecordedBreak.map(\.documentId) == ["d19"])
            #expect(unrecordedBreak.first?.matchStrategy == .exactDocumentNumber)

            // Page 44 is d20's: d19 is a best guess naming the one page it is on, and d20 follows by
            // page. Until #1503 the label read "(42–43)", a bound from d18's last break to the page
            // before d20's first, when d19 begins, and ends, on 43.
            let nextDocumentsPage = try await lookUp(19, 44)
            #expect(nextDocumentsPage.first?.documentId == "d19")
            #expect(isBestGuess(nextDocumentsPage.first?.matchStrategy ?? .exactDocumentNumber))
            #expect(nextDocumentsPage.first?.confidenceLabel == ConfidenceLabels.bestGuess(
                ConfidenceLabels.pageOutside(page: 44, first: 43, last: 43)),
                    "\(nextDocumentsPage.first?.confidenceLabel ?? "nil")")
            #expect(nextDocumentsPage.contains { $0.documentId == "d20" && $0.matchStrategy == .pageRange })

            // #1503: a page-only citation of page 43 is d19 AND d20, both beginning there; d19,
            // first in the volume, is listed first, and neither is vouched for.
            let pageOnly = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "V",
                                                                       pageNumber: 43))
            #expect(pageOnly.map(\.documentId) == ["d19", "d20"])
            #expect(pageOnly.allSatisfy { $0.matchStrategy == .sharedPage(documents: 2) },
                    "\(pageOnly.map(\.matchStrategy))")
        }
    }

    // MARK: - The page a document begins on (#1503)

    /// Volume V of 1961–63 laid out as the corpus prints its d15–d21 (#1503), with each document's
    /// first page placed in one of the three ways the corpus places it:
    /// - **a break between documents**, just before the div, recorded against no document before
    ///   #1503 (97,413 of the corpus's arabic breaks sit there): d15, d16, d17 and d20 — d16 and d17
    ///   carry no break of their own;
    /// - **part-way down a page**, whose break is the previous document's: d18 begins on 48 below
    ///   d17, and d19 on 49 below d18, whose own first break is that 49 — the verifier's
    ///   frus1961-63v05 case;
    /// - **at the top of a page whose break it carries itself**, before its heading: d21.
    ///
    /// d14 opens the fixture with no break before it, so only its own break, 38, places it — the
    /// case the page lookup falls back to its own breaks for. d15 holds a footnote of page
    /// references, which the index resolves to documents.
    private var startPageVolume: [(entry: VolumeManifestEntry, docs: [Doc])] {
        let references = "<note n=\"1\" xml:id=\"d15fn1\">See <ref target=\"#pg_49\">p. 49</ref>, "
            + "<ref target=\"#pg_48\">p. 48</ref>, <ref target=\"#pg_51\">p. 51</ref> and "
            + "<ref target=\"#pg_53\">p. 53</ref>.</note>"
        return [(entry("frus1961-63v05", "1961-63",
                       "Foreign Relations of the United States, 1961–1963, Volume V,\n                    Soviet Union"),
                 [Doc(id: "d14", number: "14", pages: [38]),
                  Doc(id: "d15", number: "15", pages: [40, 41, 42, 43, 44, 45, 46], pagesBefore: [39],
                      body: references),
                  Doc(id: "d16", number: "16", pages: [], pagesBefore: [47]),
                  Doc(id: "d17", number: "17", pages: [], pagesBefore: [48]),
                  Doc(id: "d18", number: "18", pages: [49]),
                  Doc(id: "d19", number: "19", pages: [50]),
                  Doc(id: "d20", number: "20", pages: [52, 53, 54], pagesBefore: [51]),
                  Doc(id: "d21", number: "21", pages: [56], pagesAtTop: [55])])]
    }

    /// A page-only citation of Volume V of 1961–63.
    private func lookUpPage(_ page: Int, _ engine: CitationMatchingEngine) async throws -> [CitationMatch] {
        try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "V", pageNumber: page))
    }

    @Test("A page-only citation finds the document that begins on the page: after a break between documents, part-way down a page, or at the top of one (#1503)")
    func pageCitationFindsTheDocumentThatBeginsThere() async throws {
        try await withIndex(startPageVolume) { engine, index in
            // Part-way down a page: d19 begins on 49, below the end of d18, whose own break is 49.
            // Before #1503 the page went to d18, the document still running when page 49 began.
            let midPage = try await lookUpPage(49, engine)
            #expect(midPage.map(\.documentId) == ["d19"])
            #expect(midPage.first?.matchStrategy == .pageRange)
            #expect(midPage.first?.confidenceLabel
                    == "Matched by page number — this document begins on page 49 (pages 49–50)",
                    "\(midPage.first?.confidenceLabel ?? "nil")")

            // After a break between documents, which the index recorded against no document, so
            // the page found nothing — d16 has no break of its own at all, and is printed on 47
            // alone.
            for (page, document) in [(47, "d16"), (51, "d20")] {
                let hits = try await lookUpPage(page, engine)
                #expect(hits.map(\.documentId) == [document], "p. \(page): \(hits.map(\.documentId))")
                #expect(hits.first?.matchStrategy == .pageRange, "p. \(page)")
            }
            #expect(try await lookUpPage(47, engine).first?.confidenceLabel
                    == "Matched by page number — this document begins on page 47 and ends on it")

            // At the top of a page whose break the document carries before its heading: it begins
            // on that break's page, not on the page d20 ends on.
            let topOfPage = try await lookUpPage(55, engine)
            #expect(topOfPage.map(\.documentId) == ["d21"])
            #expect(topOfPage.first?.confidenceLabel
                    == "Matched by page number — this document begins on page 55 (pages 55–56)",
                    "\(topOfPage.first?.confidenceLabel ?? "nil")")

            // The control: a page no document begins on is the document printed on it — the pages
            // it is printed on counted from the page it begins on, 51, not its first break, 52.
            let inside = try await lookUpPage(53, engine)
            #expect(inside.map(\.documentId) == ["d20"])
            #expect(inside.first?.confidenceLabel
                    == "Matched by page number — page 53 falls within this document (pages 51–54)",
                    "\(inside.first?.confidenceLabel ?? "nil")")

            // A document nothing precedes is placed by its own break alone, on one page here.
            let ownBreakOnly = try await lookUpPage(38, engine)
            #expect(ownBreakOnly.map(\.documentId) == ["d14"])
            #expect(ownBreakOnly.first?.confidenceLabel
                    == "Matched by page number — this document is printed on page 38",
                    "\(ownBreakOnly.first?.confidenceLabel ?? "nil")")

            // The reader's page links read the same store.
            #expect(try await index.pages.document(forPage: 49, inVolume: "frus1961-63v05") == "d19")
            #expect(try await index.pages.document(forPage: 51, inVolume: "frus1961-63v05") == "d20")
        }
    }

    @Test("When several documents begin on the cited page, the lookup offers every one and vouches for none — in Citation Lookup, Batch and Add Documents (#1503)")
    func sharedPageIsAmbiguous() async throws {
        try await withIndex(startPageVolume) { engine, _ in
            // d17 begins on 48 after the break before it, and d18 below it: its own first break is 49.
            let shared = try await lookUpPage(48, engine)
            #expect(shared.map(\.documentId) == ["d17", "d18"])
            for match in shared {
                #expect(match.matchStrategy != .pageRange, "\(match.documentId): \(match.matchStrategy)")
                #expect(match.matchStrategy != .exactDocumentNumber, "\(match.documentId)")
                #expect(match.confidenceLabel != ConfidenceLabels.exactMatch, "\(match.documentId)")
                #expect(match.confidenceLabel
                        == "Possible match — one of 2 documents that begin on page 48", "\(match.confidenceLabel)")
                #expect(match.correctionNote?.hasPrefix("A page alone cannot say") == true,
                        "\(match.correctionNote ?? "nil")")
            }
            #expect(BatchCitationOutcome.classify(matches: shared) == .ambiguous(count: 2))

            // In a volume the citation does not name, each is a best guess whose note keeps both
            // the count and what to do about it.
            let unnamed = try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "XX",
                                                                      pageNumber: 48))
            #expect(unnamed.map(\.documentId) == ["d17", "d18"])
            for match in unnamed {
                #expect(isBestGuess(match.matchStrategy), "\(match.matchStrategy)")
                #expect(match.correctionNote?.contains("one of 2 documents that begin on page 48") == true,
                        "\(match.correctionNote ?? "nil")")
                #expect(match.correctionNote?.contains("A page alone cannot say") == true,
                        "\(match.correctionNote ?? "nil")")
            }

            // Add Documents, over the real parser and engine: never bucketed "resolved".
            let parser = CitationParser()
            let resolver = CollectionCitationLineResolver(parse: { parser.parse($0) },
                                                          match: { try await engine.match(input: $0) })
            let outcome = await resolver.resolve(line: "FRUS, 1961–1963, vol. V, p. 48")
            if case .ambiguous(let volumeId, let documentId, _) = outcome {
                #expect(volumeId == "frus1961-63v05")
                #expect(documentId == "d17")
            } else {
                Issue.record("p. 48 in Add Documents should be ambiguous, got \(outcome)")
            }
            // The control: the page one document begins on resolves to it.
            #expect(await resolver.resolve(line: "FRUS, 1961–1963, vol. V, p. 49")
                    == .resolved(volumeId: "frus1961-63v05", documentId: "d19", note: nil))
        }
    }

    @Test("A page reference is stored against the document that begins on that page (#1503)")
    func pageReferenceIsStoredAgainstTheDocumentBeginningThere() async throws {
        try await withIndex(startPageVolume) { _, index in
            // d15's footnote cites pp. 49, 48, 51 and 53, in that order. Before #1503: d18 (running
            // when 49 began), `pg_48` and `pg_51` left unresolved (breaks between documents), d20.
            // Page 48 is where d17 and d18 both begin, and the first in the volume is stored.
            let targets = try crossReferenceTargets(from: "d15", in: "frus1961-63v05", databaseURL: index.databaseURL)
            #expect(targets == ["d19", "d17", "d20", "d20"])
        }
    }

    /// The `target_document_id` of every cross-reference `documentId` of `volumeId` makes, in the
    /// order the index stored them — read straight from the table the graph and analytics read.
    private func crossReferenceTargets(from documentId: String, in volumeId: String,
                                       databaseURL: URL) throws -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let handle = db else {
            sqlite3_close(db)
            throw NSError(domain: "CitationLookupIndexedTests", code: 1)
        }
        defer { sqlite3_close_v2(handle) }
        var stmt: OpaquePointer?
        let sql = """
            SELECT target_document_id FROM cross_references
            WHERE source_volume_id = ? AND source_document_id = ? ORDER BY rowid
            """
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "CitationLookupIndexedTests", code: 2)
        }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, volumeId, -1, transient)
        sqlite3_bind_text(stmt, 2, documentId, -1, transient)
        var targets: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            targets.append(sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "")
        }
        return targets
    }

    /// Volume E–2 of 1969–76 as the E-volumes that number their pages per document print it — 14 of
    /// the 22, and frus1981-88v16 (#1503): each document's facsimile page 1 breaks just before it,
    /// between documents, and its later pages break inside it. Twelve documents, two more than a
    /// lookup lists.
    private var perDocumentVolume: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [(entry("frus1969-76ve02", "1969-76",
                "Foreign Relations of the United States, 1969–1976, Volume\n                    E–2, Documents on Global Issues, 1969–1972"),
          (1...12).map { Doc(id: "d\($0)", number: "\($0)", pages: [2, 3], pagesBefore: [1], facsimile: true) })]
    }

    @Test("A volume that numbers its pages per document answers a page-only citation as ambiguous, listing ten of the documents printed on the page and naming how many there are (#1503)")
    func perDocumentPaginationIsAmbiguous() async throws {
        try await withEngine(perDocumentVolume) { engine in
            func lookUp(page: Int, document: Int? = nil) async throws -> [CitationMatch] {
                try await engine.match(input: CitationInput(subseries: "1969-76", volumeNumber: "E-2",
                                                            documentNumber: document, pageNumber: page))
            }
            // Page 1, which every document begins on, and page 2, which every document is printed on.
            for page in [1, 2] {
                let hits = try await lookUp(page: page)
                #expect(hits.map(\.documentId) == (1...10).map { "d\($0)" }, "p. \(page)")
                for match in hits {
                    #expect(match.matchStrategy != .pageRange, "p. \(page), \(match.documentId)")
                    #expect(match.confidenceLabel.contains("12 documents"), "\(match.confidenceLabel)")
                }
                // Batch counts every document on the page, not the ten listed.
                #expect(BatchCitationOutcome.classify(matches: hits) == .ambiguous(count: 12), "p. \(page)")
            }
            // The control: a document number names one document, and its page is checked.
            let named = try await lookUp(page: 3, document: 5)
            #expect(named.map(\.documentId) == ["d5"])
            #expect(named.first?.matchStrategy == .exactDocumentNumber)
            let wrongPage = try await lookUp(page: 9, document: 5)
            #expect(wrongPage.first?.documentId == "d5")
            #expect(isBestGuess(wrongPage.first?.matchStrategy ?? .exactDocumentNumber))
        }
    }

    @Test("A document a republication inserts is checked against the page it is printed on (#1503)")
    func insertedDocumentIsCheckedAgainstItsPage() async throws {
        let volume = entry("frus1961-63v06", "1961-63",
                           "Foreign Relations of the United States, 1961–1963, Volume\n                    VI, Kennedy-Khrushchev Exchanges")
        let first = [Doc(id: "d1", number: "1", pages: [11], pagesBefore: [10]),
                     Doc(id: "d3", number: "3", pages: [13], pagesBefore: [12])]
        // The republication inserts d2, with no break of its own, below d1 on page 11.
        let republished = [first[0], Doc(id: "d2", number: "2", pages: []), first[1]]
        try await withIndex([(volume, first)]) { engine, index in
            try writeVolume(volume.volumeId, republished, to: index.volumesDirectory)
            try await index.pipeline.indexVolume(volume.volumeId)
            func lookUp(document: Int?, page: Int) async throws -> [CitationMatch] {
                try await engine.match(input: CitationInput(subseries: "1961-63", volumeNumber: "VI",
                                                            documentNumber: document, pageNumber: page))
            }
            // Its page is checked: page 13 is d3's. Before #1503 the check read the order documents
            // entered the index, in which d2 comes last, found no break after it, and checked nothing.
            let wrongPage = try await lookUp(document: 2, page: 13)
            #expect(wrongPage.first?.documentId == "d2")
            #expect(isBestGuess(wrongPage.first?.matchStrategy ?? .exactDocumentNumber),
                    "\(wrongPage.first?.matchStrategy as Any)")
            #expect(wrongPage.first?.confidenceLabel.contains("(11)") == true,
                    "\(wrongPage.first?.confidenceLabel ?? "nil")")
            // The control: the page it is printed on.
            let rightPage = try await lookUp(document: 2, page: 11)
            #expect(rightPage.map(\.documentId) == ["d2"])
            #expect(rightPage.first?.matchStrategy == .exactDocumentNumber)
            // And a page-only citation of page 11 is d2, which begins there, not d1.
            #expect(try await lookUp(document: nil, page: 11).map(\.documentId) == ["d2"])
        }
    }

    @Test("A document that begins on a page printed without its number — [31] — is found by that page (#1503)")
    func unnumberedPageIsAPage() async throws {
        let volume = entry("frus1861", "1861",
                           "Papers Relating to Foreign Affairs, Accompanying the Annual Message of the President to the Second Session Thirty-seventh Congress")
        try await withEngine([(volume, [Doc(id: "d1", number: "1", pages: [30], pagesBefore: [29]),
                                        Doc(id: "d2", number: "2", pages: [32], rawBreaksBefore: ["[31]"])])]) { engine in
            let byPage = try await engine.match(input: CitationInput(subseries: "1861", pageNumber: 31))
            #expect(byPage.map(\.documentId) == ["d2"])
            #expect(byPage.first?.confidenceLabel.contains("begins on page 31") == true,
                    "\(byPage.first?.confidenceLabel ?? "nil")")
            // The control: its document number with that page is not a best guess, d2 being printed
            // on 31–32.
            let named = try await engine.match(input: CitationInput(subseries: "1861", documentNumber: 2,
                                                                    pageNumber: 31))
            #expect(named.first?.documentId == "d2")
            #expect(named.first?.matchStrategy == .superimposedDocumentNumber)
        }
    }

    @Test("A link's fallback checks the page too: a volume link beside a document number the cited page contradicts is a best guess (#1474 review round 2)")
    func linkFallbackChecksThePage() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let parser = CitationParser()
            // Volume XIV's d84 is printed on pages 199–200; page 50 is where d8 begins. The link
            // names the volume, or a chapter, and the prose the document and the page.
            for link in ["https://history.state.gov/historicaldocuments/frus1961-63v14",
                         "https://history.state.gov/historicaldocuments/frus1961-63v14/ch3"] {
                let text = "FRUS, 1961–1963, vol. XIV, doc. 84, p. 50, \(link)"
                let matches = try await engine.match(input: parser.parse(text))
                #expect(matches.map(\.documentId) == ["d84", "d8"], "\(text)")
                #expect(isBestGuess(matches.first?.matchStrategy ?? .exactDocumentNumber),
                        "\(matches.first?.matchStrategy as Any)")
                #expect(matches.first?.confidenceLabel.contains("page 50") == true, "\(text)")
                #expect(matches.last?.matchStrategy == .pageRange, "\(text)")
            }
        }
    }

    @Test("A link's fallback checks the volume the prose names: vol. XIV beside a Volume V link is a best guess (#1474 review round 2)")
    func linkFallbackChecksTheProseVolume() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let parser = CitationParser()
            // The link decides the volume — V — and the prose the document, 84; but the prose also
            // names Volume XIV, which V is not. Both volumes hold a document 84, so this is exactly
            // the citation whose writer may have meant the other one.
            let text = "FRUS, 1961–1963, vol. XIV, doc. 84, https://history.state.gov/historicaldocuments/frus1961-63v05"
            let fields = CitationLookupFields().refreshed(forPaste: text, mode: .paste, parser: parser)
            let matches = try await engine.match(input: fields.input(mode: .paste, pasteText: text, parser: parser))
            #expect(matches.map(\.volumeId) == ["frus1961-63v05"])
            #expect(matches.first?.documentId == "d84")
            #expect(isBestGuess(matches.first?.matchStrategy ?? .exactDocumentNumber),
                    "\(matches.first?.matchStrategy as Any)")
            #expect(matches.first?.confidenceLabel == ConfidenceLabels.bestGuess(
                ConfidenceLabels.unmetFields([ConfidenceLabels.cited(.volume("XIV"))])),
                    "\(matches.first?.confidenceLabel ?? "nil")")
            // The volume IS one the citation names — in its link — so the note says what happened
            // rather than "a volume the citation does not name".
            #expect(matches.first?.correctionNote == ConfidenceLabels.linkProseNote)

            // The same for a document the prose finds by page: vol. V's page beside a XIV link.
            let byPage = try await engine.match(input: parser.parse(
                "FRUS, 1961–1963, vol. V, p. 50, https://history.state.gov/historicaldocuments/frus1961-63v14"))
            #expect(byPage.map(\.documentId) == ["d8"])
            #expect(isBestGuess(byPage.first?.matchStrategy ?? .pageRange), "\(byPage.first?.matchStrategy as Any)")
            #expect(byPage.first?.confidenceLabel.contains("volume V") == true,
                    "\(byPage.first?.confidenceLabel ?? "nil")")

            // The control: prose that agrees with its link stays exact (`volumeLinkBesideProse`
            // pins the page case), and a link naming the document by its own id decides alone.
            let agreeing = try await engine.match(input: parser.parse(
                "FRUS, 1961–1963, vol. V, doc. 84, https://history.state.gov/historicaldocuments/frus1961-63v05"))
            #expect(agreeing.first?.matchStrategy == .exactDocumentNumber)
            let byId = try await engine.match(input: parser.parse(
                "FRUS, 1961–1963, vol. XIV, doc. 12, https://history.state.gov/historicaldocuments/frus1961-63v05/d84"))
            #expect(byId.map(\.documentId) == ["d84"])
            #expect(byId.first?.matchStrategy == .exactDocumentNumber)
        }
    }

    @Test("A footnote that opens with the document's date finds the document it cites as an exact match, beside a link or not (#1474 review round 3)")
    func datedFootnoteIsExact() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let parser = CitationParser()
            let dated = "Memorandum of Conversation, Moscow, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84"
            // Read as the subseries 1962, both of these were Volume V's document 84 labelled
            // "Best guess — this volume does not match the cited subseries 1962", and the linked one
            // carried a note saying the citation's text named a different volume, which it does not.
            for text in [dated, dated + ", https://history.state.gov/historicaldocuments/frus1961-63v05"] {
                let fields = CitationLookupFields().refreshed(forPaste: text, mode: .paste, parser: parser)
                let matches = try await engine.match(input: fields.input(mode: .paste, pasteText: text, parser: parser))
                #expect(matches.map(\.volumeId) == ["frus1961-63v05"], "\(text)")
                #expect(matches.first?.documentId == "d84", "\(text)")
                #expect(matches.first?.matchStrategy == .exactDocumentNumber,
                        "\(text): \(matches.first?.matchStrategy as Any)")
                #expect(matches.first?.confidenceLabel == ConfidenceLabels.exactMatch,
                        "\(text): \(matches.first?.confidenceLabel ?? "nil")")
            }

            // The control: text beside the link that really names another subseries is still told so.
            let other = try await engine.match(input: parser.parse(
                "FRUS, 1964–1968, vol. V, doc. 84, https://history.state.gov/historicaldocuments/frus1961-63v05"))
            #expect(other.map(\.documentId) == ["d84"])
            #expect(other.first?.confidenceLabel == ConfidenceLabels.bestGuess(
                ConfidenceLabels.unmetFields([ConfidenceLabels.cited(.subseries("1964-68"))])),
                    "\(other.first?.confidenceLabel ?? "nil")")
            #expect(other.first?.correctionNote == ConfidenceLabels.linkProseNote)
        }
    }

    /// Volume X of 1952–54, whose title prints "Iran, 1951–1954": a year before its subseries, in
    /// which 149 of its document divs are dated — 122 historical documents and 27 editorial notes
    /// (`frus:doc-dateTime-min`, corpus `550a8c5c5`; #1474 review rounds 4 and 5). A pre-1955
    /// volume, so a document found by its number is labelled as one whose number was assigned
    /// digitally.
    private var iranVolume: (entry: VolumeManifestEntry, docs: [Doc]) {
        (entry("frus1952-54v10", "1952-54",
               "Foreign Relations of the United States, 1952–1954, Iran,\n                    1951–1954, Volume X"),
         [Doc(id: "d5", number: "5", pages: [10])])
    }

    /// The volumes #1474 review round 5 cites beside links, titled as the manifest titles them:
    /// Volume V of 1961–63, whose document 1 is a National Intelligence Estimate dated December 1,
    /// 1960; `sixtyOneVolumes`' Volume XIV; Volume XXIII of 1964–68, Congo, whose title prints
    /// 1960–1968; Volume I of Japan, 1931–1941; and the Iran volume.
    private var linkedVolumes: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [
            (entry("frus1961-63v05", "1961-63",
                   "Foreign Relations of the United States, 1961–1963, Volume V,\n                    Soviet Union",
                   documentCount: 85),
             [Doc(id: "d1", number: "1", pages: [1]), Doc(id: "d84", number: "84", pages: [181])]),
            sixtyOneVolumes[1],
            (entry("frus1964-68v23", "1964-68",
                   "Foreign Relations of the United States, 1964–1968, Volume\n                    XXIII, Congo, 1960–1968"),
             [Doc(id: "d5", number: "5", pages: [7])]),
            (entry("frus1931-41v01", "1931-41",
                   "Papers Relating to the Foreign Relations of the United\n                    States, Japan, 1931–1941, Volume I"),
             [Doc(id: "d12", number: "12", pages: [40])]),
            iranVolume,
        ]
    }

    @Test("Beside a link, the text's year is checked against the link's volume only when it follows the series' name: a dated note naming the series only in its link is an exact match, and FRUS with another subseries is a best guess (#1474 review rounds 4 and 5)")
    func linkProseYearIsCheckedOnlyAfterTheSeriesName() async throws {
        try await withEngine(linkedVolumes) { engine in
            let parser = CitationParser()
            let v05 = "https://history.state.gov/historicaldocuments/frus1961-63v05"
            // The link is the note's only "frus", so its text reads its first year: the document's
            // date, which names no volume and is not checked. The fourth row names the series with
            // no year after it. Round 3 made all four "Best guess — this volume does not match the
            // cited subseries …" under a note saying the text named a different volume; round 4,
            // which met a year inside the years the volume covers, still did so to the two dated
            // 1960 — Volume V's document 1 is dated December 1, 1960, before its 1961–63.
            let exact: [(text: String, document: String)] = [
                ("National Intelligence Estimate, December 1, 1960, vol. V, doc. 1, \(v05)", "d1"),
                ("Memorandum of Conversation, Moscow, May 5, 1962, vol. V, doc. 84, \(v05)", "d84"),
                ("Memorandum of Conversation, Moscow, May 5, 1962, 1961–1963, vol. V, doc. 84, \(v05)", "d84"),
                ("National Intelligence Estimate, December 1, 1960, FRUS, vol. V, doc. 1, \(v05)", "d1"),
            ]
            for row in exact {
                let fields = CitationLookupFields().refreshed(forPaste: row.text, mode: .paste, parser: parser)
                let matches = try await engine.match(input: fields.input(mode: .paste, pasteText: row.text,
                                                                         parser: parser))
                #expect(matches.map(\.documentId) == [row.document], "\(row.text)")
                #expect(matches.first?.volumeId == "frus1961-63v05", "\(row.text)")
                #expect(matches.first?.matchStrategy == .exactDocumentNumber,
                        "\(row.text): \(matches.first?.matchStrategy as Any)")
                #expect(matches.first?.confidenceLabel == ConfidenceLabels.exactMatch,
                        "\(row.text): \(matches.first?.confidenceLabel ?? "nil")")
                #expect(matches.first?.correctionNote == nil, "\(row.text)")
            }

            // A document the text finds by page is held to the same rule.
            let byPage = try await engine.match(input: parser.parse(
                "Memorandum, Berlin, May 5, 1962, vol. XIV, p. 50, https://history.state.gov/historicaldocuments/frus1961-63v14"))
            #expect(byPage.map(\.documentId) == ["d8"])
            #expect(byPage.first?.matchStrategy == .pageRange, "\(byPage.first?.matchStrategy as Any)")

            // The Iran volume's 1951, a year before its subseries that its documents carry: exact
            // because the text reads it as its first year, a date — not, as round 4 had it, because
            // the title's span covers it.
            let iran = try await engine.match(input: parser.parse(
                "Telegram, Tehran, August 19, 1951, vol. X, doc. 5, https://history.state.gov/historicaldocuments/frus1952-54v10"))
            #expect(iran.map(\.documentId) == ["d5"])
            #expect(iran.first?.matchStrategy == .superimposedDocumentNumber, "\(iran.first?.matchStrategy as Any)")
            #expect(iran.first?.correctionNote == nil)

            // A year after the series' name names a volume of the series, and is checked strictly,
            // as round 3 checked it. `FRUS, 1961–1963, vol. XXIII` is Southeast Asia, not the Congo
            // volume of 1964–68 the link names, though that volume's title prints 1960–1968; and
            // `FRUS, 1933, vol. I` is 1933's General volume, not Volume I of Japan, 1931–1941.
            // Round 4 made both exact matches, because each year falls inside the linked volume's.
            // The Japan volume is pre-1955, so its best guess keeps how its document was found,
            // after the note.
            let digitally = ConfidenceLabels.linkProseNote + "\n" + ConfidenceLabels.superimposedDocumentNumber
            let bestGuesses: [(text: String, document: String, cited: String, note: String)] = [
                ("FRUS, 1961–1963, vol. XXIII, doc. 5, https://history.state.gov/historicaldocuments/frus1964-68v23",
                 "d5", "1961-63", ConfidenceLabels.linkProseNote),
                ("FRUS, 1933, vol. I, doc. 12, https://history.state.gov/historicaldocuments/frus1931-41v01",
                 "d12", "1933", digitally),
                ("FRUS, 1964–1968, vol. V, doc. 84, \(v05)", "d84", "1964-68", ConfidenceLabels.linkProseNote),
            ]
            for row in bestGuesses {
                let matches = try await engine.match(input: parser.parse(row.text))
                #expect(matches.map(\.documentId) == [row.document], "\(row.text)")
                #expect(matches.first?.confidenceLabel == ConfidenceLabels.bestGuess(
                    ConfidenceLabels.unmetFields([ConfidenceLabels.cited(.subseries(row.cited))])),
                        "\(row.text): \(matches.first?.confidenceLabel ?? "nil")")
                #expect(matches.first?.correctionNote == row.note,
                        "\(row.text): \(matches.first?.correctionNote ?? "nil")")
            }

            // Batch shows the note dated 1960 as resolved, and the Southeast Asia citation as the
            // best guess it is.
            let entries = CitationBlockSplitter.split(
                "1. National Intelligence Estimate, December 1, 1960, vol. V, doc. 1, \(v05)\n"
                    + "2. FRUS, 1961–1963, vol. XXIII, doc. 5, https://history.state.gov/historicaldocuments/frus1964-68v23")
            #expect(entries.count == 2)
            let collector = BatchRowCollector()
            await BatchCitationRunner.run(entries: entries, engine: engine, parser: parser) { row in
                collector.rows.append(row)
            }
            let rows = await collector.rows
            #expect(rows.count == 2)
            #expect(rows.first?.outcome == .resolved, "\(rows.first?.outcome as Any)")
            #expect(rows.last?.outcome == .ambiguous(count: 1), "\(rows.last?.outcome as Any)")
        }
    }

    /// A printed 1914–1918 World War supplement, titled as the manifest titles one. d2 has no page
    /// break of its own, between d1's 2 and d3's 3, so it is printed on page 2.
    private var worldWarSupplement: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [(entry("frus1917Supp01v01", "1917",
                "Papers Relating to the Foreign Relations of the United States, 1917, Supplement 1, The World War"),
          [Doc(id: "d1", number: "1", pages: [1, 2]),
           Doc(id: "d2", number: "2", pages: []),
           Doc(id: "d3", number: "3", pages: [3, 4])])]
    }

    @Test("A printed World War supplement is looked up and checked by page, and a range never starts at page 0 (#1474 review round 3)")
    func worldWarSupplementIsCheckedByPage() async throws {
        try await withEngine(worldWarSupplement) { engine in
            // The page check: d3 is printed on pages 2–4, not 50. Before round 3 the word
            // "Supplement" in the title turned the check off, and this was a plain match.
            let wrongPage = try await engine.match(input: CitationInput(subseries: "1917", documentNumber: 3, pageNumber: 50))
            #expect(wrongPage.first?.documentId == "d3")
            #expect(isBestGuess(wrongPage.first?.matchStrategy ?? .superimposedDocumentNumber),
                    "\(wrongPage.first?.matchStrategy as Any)")
            #expect(wrongPage.first?.confidenceLabel.contains("(2–4)") == true,
                    "\(wrongPage.first?.confidenceLabel ?? "nil")")

            // d1's first break is page 1: no page comes before it, so the label reads 1–2, not 0–2.
            let firstDocument = try await engine.match(input: CitationInput(subseries: "1917", documentNumber: 1, pageNumber: 50))
            #expect(firstDocument.first?.confidenceLabel == ConfidenceLabels.bestGuess(
                ConfidenceLabels.pageOutside(page: 50, first: 1, last: 2)),
                    "\(firstDocument.first?.confidenceLabel ?? "nil")")
            #expect(firstDocument.first?.confidenceLabel.contains("(0–") == false)

            // The page strategy: a page-only citation finds the document printed there. Before
            // round 3 it found nothing in this volume.
            let byPage = try await engine.match(input: CitationInput(subseries: "1917", pageNumber: 4))
            #expect(byPage.map(\.documentId) == ["d3"])
            #expect(byPage.first?.matchStrategy == .pageRange)

            // The control: a page the document is on keeps its plain label. (A document number
            // assigned digitally does not stop the lookup, so the page's documents follow: d2 and
            // d3 both begin on page 2 — #1503; before it, d1, whose own break page 2 is, followed.)
            let agreeing = try await engine.match(input: CitationInput(subseries: "1917", documentNumber: 2, pageNumber: 2))
            #expect(agreeing.first?.documentId == "d2")
            #expect(agreeing.first?.matchStrategy == .superimposedDocumentNumber,
                    "\(agreeing.first?.matchStrategy as Any)")
            #expect(agreeing.dropFirst().map(\.documentId) == ["d2", "d3"])
        }
    }

    /// A microfiche supplement whose title does not say so — `frus1961-63v07-09mSupp`'s does not —
    /// with facsimile pages restarting at 1 in every document.
    private var microficheSupplement: [(entry: VolumeManifestEntry, docs: [Doc])] {
        [(entry("frus1961-63v07-09mSupp", "1961-63",
                "Foreign Relations of the United States, 1961–1963, Volumes VII, VIII, IX, Arms Control; National Security Policy; Foreign Economic Policy"),
          [Doc(id: "d1", number: "1", pages: [1, 2], facsimile: true),
           Doc(id: "d2", number: "2", pages: [1], facsimile: true),
           Doc(id: "d3", number: "3", pages: [1, 2, 3], facsimile: true)])]
    }

    @Test("A microfiche supplement is neither looked up nor checked by page, though its title does not name the microfiche (#1474 review round 3)")
    func microficheSupplementIsNotCheckedByPage() async throws {
        try await withEngine(microficheSupplement) { engine in
            // d2's one facsimile page is page 1 of the document, not a page of a book: page 3 says
            // nothing about it. Before round 3 this was "page 3 is outside the pages this document
            // may be printed on (0–1)".
            let matches = try await engine.match(input: CitationInput(subseries: "1961-63", documentNumber: 2, pageNumber: 3))
            #expect(matches.map(\.documentId) == ["d2"])
            #expect(matches.first?.matchStrategy == .exactDocumentNumber, "\(matches.first?.matchStrategy as Any)")

            // Every document has a page 1, so a page-only citation names none of them. Before round 3
            // it returned whichever one the page table offered first, as a match by page.
            let byPage = try await engine.match(input: CitationInput(subseries: "1961-63", pageNumber: 1))
            #expect(byPage.isEmpty, "\(byPage.map(\.documentId))")
        }
    }

    @Test("A best guess does not stop the lookup: a later volume carrying every cited field still answers (#1474 review round 1)")
    func bestGuessDoesNotHideTheCitedVolume() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            // No volume's subseries is 1961-62, so the fallback keeps both. Volume XIV's title
            // prints "1961–1962", so it carries the cited year and Volume V does not — and V comes
            // first. Stopping at V's hit, whose strategy was exact before it was qualified, would
            // hide XIV's own document 84.
            let matches = try await engine.match(input: CitationInput(subseries: "1961-62", documentNumber: 84))
            #expect(matches.map(\.volumeId) == ["frus1961-63v05", "frus1961-63v14"])
            #expect(isBestGuess(matches.first?.matchStrategy ?? .exactDocumentNumber))
            #expect(matches.last?.matchStrategy == .exactDocumentNumber)
            #expect(matches.last?.confidenceLabel == ConfidenceLabels.exactMatch)
        }
    }

    @Test("Batch triage shows a lone best guess as one, not as resolved (#1474 review round 1)")
    func batchRowShowsALoneBestGuess() async throws {
        try await withEngine(sixtyOneVolumes) { engine in
            let entries = CitationBlockSplitter.split(
                "1. FRUS, 1961–1963, vol. V, pt. 2, doc. 84.\n2. FRUS, 1961–1963, vol. V, doc. 84.")
            #expect(entries.count == 2)
            let collector = BatchRowCollector()
            await BatchCitationRunner.run(entries: entries, engine: engine, parser: CitationParser()) { row in
                collector.rows.append(row)
            }
            let rows = await collector.rows
            #expect(rows.count == 2)
            // Volume V has no part 2, so its document 84 is the one candidate and a best guess —
            // which Paste mode calls it, and which this row drew as a green "Resolved".
            #expect(rows.first?.outcome == .ambiguous(count: 1))
            #expect(rows.first?.loneCandidateLabel?.contains("part 2") == true,
                    "\(rows.first?.loneCandidateLabel ?? "nil")")
            // The control: the cited volume's own document 84.
            #expect(rows.last?.outcome == .resolved)
            #expect(rows.last?.loneCandidateLabel == nil)
        }
    }

    @Test("Batch triage forwards a pasted link, so its row resolves to the linked document (#1474)")
    func batchRowResolvesALink() async throws {
        try await withEngine(letterSuffixVolume) { engine in
            let entries = CitationBlockSplitter.split(
                FRUSCanonicalURL.string(volumeId: "frus1865p1", documentId: "d373a"))
            #expect(entries.count == 1)
            let collector = BatchRowCollector()
            await BatchCitationRunner.run(entries: entries, engine: engine, parser: CitationParser()) { row in
                collector.rows.append(row)
            }
            let rows = await collector.rows
            #expect(rows.count == 1)
            #expect(rows.first?.outcome == .resolved)
            #expect(rows.first?.primaryMatch?.volumeId == "frus1865p1")
            #expect(rows.first?.primaryMatch?.documentId == "d373a")
        }
    }
}

/// Collects batch rows on the main actor, where `BatchCitationRunner` delivers them.
@MainActor
private final class BatchRowCollector {
    /// The rows delivered so far, in delivery order.
    var rows: [BatchCitationRow] = []
}

