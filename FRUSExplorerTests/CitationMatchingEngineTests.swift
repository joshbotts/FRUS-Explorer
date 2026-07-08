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

        // 2) Parse it back, mirroring the fixed CitationLookupView.performLookup wiring
        //    (the title fragment is forwarded, not dropped).
        let parsed = CitationParser().parse(citation)
        let input = CitationInput(
            subseries: parsed.subseries,
            volumeNumber: parsed.volumeNumber,
            documentNumber: parsed.documentNumber,
            titleFragment: parsed.titleFragment
        )

        // 3) Match against the six real entries (index-free manifestOnly path — no SearchService).
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: entries),
            searchService: nil, pageRangeStore: nil, downloadedVolumeIds: []
        )
        let results = try await engine.match(input: input)

        // 4) It must resolve to frus1863p2 — NOT frus1863p1 (wrong part) and NOT any frus1864
        //    (the print-year subseries group).
        #expect(results.first?.volumeId == "frus1863p2")
        #expect(!results.contains { $0.volumeId == "frus1863p1" })
        #expect(!results.contains { $0.volumeId.hasPrefix("frus1864") })
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
}

