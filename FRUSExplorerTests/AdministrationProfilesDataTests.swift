// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftUI
@testable import FRUSExplorer

// MARK: - AdministrationProfilesDataTests

/// Pure derivation tests for the "Administration Profiles" dashboard (Series
/// Analytics SA-2b): the `AdministrationProfilesIndex` decode contract, the
/// `AdministrationProfilesData` derivations from a constructed fixture (the
/// editorial-note toggle on document counts and proportions, volumes-per-year,
/// zero-doc hiding, party-color mapping, empty/nil safety), and one integration
/// guard that the *actual* bundled `administration-profiles-index.json` decodes
/// with the expected headline figures.
///
/// These assert the model only — no SwiftUI view is instantiated.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
///   1.1 — Session 3 / #236: subseries-scope recompute tests (scoped counts,
///          coverage-span hiding, nil-scope identity, in-scope volume shares) and
///          the bundled-index volumes[]-sums-equal-totals invariant guard
struct AdministrationProfilesDataTests {

    // MARK: Fixtures

    /// A small constructed index: two populated administrations (a two-year term
    /// and a four-year term) plus one all-zero later administration that must be
    /// hidden. Volume totals are set so proportions are exact.
    private func fixture() -> AdministrationProfilesIndex {
        AdministrationProfilesIndex(
            schemaVersion: 1,
            generated: "2026-07-05",
            totalDocumentsPointDated: 100 + 40,
            totalDocumentsRangeDated: 10 + 4,
            totalDocumentsUndated: 0,
            volumesCovered: 3,
            administrations: [
                // Two-year term, 100 point + 10 range docs, 2 volumes.
                AdministrationProfile(
                    id: "alpha", number: 40, president: "Alice Alpha", party: "Republican",
                    start: "1970-01-01", end: "1972-01-01",
                    pointDocCount: 100, rangeDocCount: 10,
                    volumeCount: 2, volumeCountPointOnly: 2,
                    coverageEarliest: 1970, coverageLatest: 1972,
                    volumes: [
                        // volA total: 100 point / 20 range → alpha share 50/100 point.
                        AdministrationVolume(volumeId: "volA", pointDocs: 50, rangeDocs: 5),
                        AdministrationVolume(volumeId: "volB", pointDocs: 50, rangeDocs: 5),
                    ]
                ),
                // Four-year term, 40 point + 4 range docs, 6 volumes.
                AdministrationProfile(
                    id: "beta", number: 41, president: "Bob M. Beta", party: "Democratic",
                    start: "1972-01-01", end: "1976-01-01",
                    pointDocCount: 40, rangeDocCount: 4,
                    volumeCount: 6, volumeCountPointOnly: 6,
                    coverageEarliest: 1972, coverageLatest: 1976,
                    volumes: [
                        AdministrationVolume(volumeId: "volA", pointDocs: 40, rangeDocs: 10),
                    ]
                ),
                // All-zero later administration — must be hidden.
                AdministrationProfile(
                    id: "gamma", number: 42, president: "Carol Gamma", party: "Republican",
                    start: "1976-01-01", end: "1980-01-01",
                    pointDocCount: 0, rangeDocCount: 0,
                    volumeCount: 0, volumeCountPointOnly: 0,
                    coverageEarliest: nil, coverageLatest: nil,
                    volumes: []
                ),
            ],
            volumeTotals: [
                "volA": VolumeTotals(pointDocs: 100, rangeDocs: 20, undatedDocs: 0),
                "volB": VolumeTotals(pointDocs: 200, rangeDocs: 0, undatedDocs: 0),
            ]
        )
    }

    // MARK: Party mapping

    @Test("PoliticalParty: raw strings map to stable cases and colors")
    func partyMapping() {
        #expect(PoliticalParty.from(raw: "Republican") == .republican)
        #expect(PoliticalParty.from(raw: "democratic") == .democratic)
        #expect(PoliticalParty.from(raw: "National Union") == .nationalUnion)
        #expect(PoliticalParty.from(raw: "Whig") == .other)
        // Colors are stable and distinct across the three real parties.
        #expect(PoliticalParty.republican.color == Color.red)
        #expect(PoliticalParty.democratic.color == Color.blue)
        #expect(PoliticalParty.nationalUnion.color == Color.orange)
        #expect(PoliticalParty.ordered.count == 4)
    }

    // MARK: Zero-doc hiding + ordering

    @Test("AdministrationProfilesData: zero-document administrations are hidden, order is chronological")
    func zeroDocHiddenChronological() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        #expect(data.profiles.map(\.id) == ["alpha", "beta"])
        #expect(!data.profiles.contains { $0.id == "gamma" })
    }

    // MARK: documentCount toggle

    @Test("AdministrationProfilesData: documentCount honors the editorial-note toggle")
    func documentCountToggle() {
        let off = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        let on = AdministrationProfilesData(index: fixture(), includeEditorialNotes: true)

        let alphaOff = off.profiles.first { $0.id == "alpha" }
        #expect(alphaOff?.documentCount == 100)   // point only
        let alphaOn = on.profiles.first { $0.id == "alpha" }
        #expect(alphaOn?.documentCount == 110)    // point + range

        // Point/range fields are stable regardless of the toggle.
        #expect(alphaOn?.pointDocCount == 100)
        #expect(alphaOn?.rangeDocCount == 10)
        #expect(off.includesEditorialNotes == false)
        #expect(on.includesEditorialNotes == true)
    }

    // MARK: The editorial-notes toggle reaches the volume count (#791)

    /// An index where the two volume counts differ — the shape every other fixture here lacks.
    ///
    /// `delta` covers four volumes, but one of them (`volD`) ties to it only through a
    /// range-dated editorial note. With the toggle off that volume is not evidence the
    /// administration is covered, so the count is three.
    private func editorialNotesFixture() -> AdministrationProfilesIndex {
        AdministrationProfilesIndex(
            schemaVersion: 1, generated: "2026-08-09",
            totalDocumentsPointDated: 30, totalDocumentsRangeDated: 6,
            totalDocumentsUndated: 0, volumesCovered: 4,
            administrations: [
                AdministrationProfile(
                    id: "delta", number: 50, president: "Dana Delta", party: "Democratic",
                    start: "1970-01-01", end: "1972-01-01",
                    pointDocCount: 30, rangeDocCount: 6,
                    volumeCount: 4, volumeCountPointOnly: 3,
                    coverageEarliest: 1970, coverageLatest: 1972,
                    volumes: [
                        AdministrationVolume(volumeId: "volA", pointDocs: 10, rangeDocs: 2),
                        AdministrationVolume(volumeId: "volB", pointDocs: 10, rangeDocs: 2),
                        AdministrationVolume(volumeId: "volC", pointDocs: 10, rangeDocs: 0),
                        // The one that only an editorial note ties to this administration.
                        AdministrationVolume(volumeId: "volD", pointDocs: 0, rangeDocs: 2),
                    ]
                ),
            ],
            volumeTotals: [
                "volA": VolumeTotals(pointDocs: 10, rangeDocs: 2, undatedDocs: 0),
                "volB": VolumeTotals(pointDocs: 10, rangeDocs: 2, undatedDocs: 0),
                "volC": VolumeTotals(pointDocs: 10, rangeDocs: 0, undatedDocs: 0),
                "volD": VolumeTotals(pointDocs: 0, rangeDocs: 2, undatedDocs: 0),
            ])
    }

    @Test("The volume count follows the editorial-notes toggle, whole-series")
    func volumeCountFollowsTheToggle() throws {
        // #791. Before the fix this chart read `volumeCount` unconditionally, so a volume tied to
        // an administration only by a range-dated editorial note counted toward it even with the
        // toggle off — the state the dashboard's own caveats call "the firmer point-dated data".
        // Measured on the shipped artifact, 14 of 26 populated administrations were affected and
        // the series total fell from 879 to 856.
        let index = editorialNotesFixture()

        let excluded = AdministrationProfilesData(index: index, includeEditorialNotes: false)
        let withoutNotes = try #require(excluded.profiles.first)
        #expect(withoutNotes.volumeCount == 3, """
            With editorial notes excluded the volume count is \(withoutNotes.volumeCount). volD \
            reaches this administration only through a range-dated note, so it is not evidence \
            of coverage under the point-dated reading.
            """)

        let included = AdministrationProfilesData(index: index, includeEditorialNotes: true)
        let withNotes = try #require(included.profiles.first)
        #expect(withNotes.volumeCount == 4)
        #expect(withNotes.volumesPerAdministrationYear
                > withoutNotes.volumesPerAdministrationYear, """
                The volumes-per-year figure did not move with the toggle. That ratio is the whole \
                chart #791 was about, and the toggle's own subtitle promises it governs every \
                count and proportion.
                """)
    }

    @Test("A scoped volume count follows the toggle the same way")
    func scopedVolumeCountFollowsTheToggle() throws {
        // The scoped path re-sums the per-volume rows rather than reading the scalars, so it is a
        // second implementation of the same rule and can drift from the first.
        let index = editorialNotesFixture()
        let scope: Set<String> = ["volC", "volD"]

        let excluded = AdministrationProfilesData(index: index, includeEditorialNotes: false,
                                                  scopeVolumeIds: scope)
        #expect(try #require(excluded.profiles.first).volumeCount == 1,
                "only volC carries a point-dated document in scope")

        let included = AdministrationProfilesData(index: index, includeEditorialNotes: true,
                                                  scopeVolumeIds: scope)
        #expect(try #require(included.profiles.first).volumeCount == 2)
    }

    @Test("The scoped and unscoped paths agree when the scope is everything")
    func scopedAndUnscopedAgree() throws {
        // The two branches read different fields — the scalars versus the per-volume rows — so
        // nothing but a test keeps them saying the same thing.
        let index = editorialNotesFixture()
        let everything: Set<String> = ["volA", "volB", "volC", "volD"]
        for toggle in [false, true] {
            let unscoped = AdministrationProfilesData(index: index, includeEditorialNotes: toggle)
            let scoped = AdministrationProfilesData(index: index, includeEditorialNotes: toggle,
                                                    scopeVolumeIds: everything)
            #expect(try #require(unscoped.profiles.first).volumeCount
                    == (try #require(scoped.profiles.first).volumeCount),
                    "the two paths disagree with editorial notes \(toggle ? "on" : "off")")
        }
    }

    // MARK: volumesPerAdministrationYear

    @Test("AdministrationProfilesData: volumesPerAdministrationYear = volumeCount / termYears")
    func volumesPerYearSpotValue() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        let alpha = data.profiles.first { $0.id == "alpha" }!
        // 2-year term, 2 volumes → 1.0/year.
        #expect(abs(alpha.termYears - 2.0) < 0.01)
        #expect(abs(alpha.volumesPerAdministrationYear - 1.0) < 0.01)

        let beta = data.profiles.first { $0.id == "beta" }!
        // 4-year term, 6 volumes → 1.5/year.
        #expect(abs(beta.termYears - 4.0) < 0.01)
        #expect(abs(beta.volumesPerAdministrationYear - 1.5) < 0.01)
    }

    @Test("AdministrationProfilesData: a nil end date yields zero term-years and zero density")
    func nullEndGuarded() {
        let index = AdministrationProfilesIndex(
            schemaVersion: 1, generated: "2026-07-05",
            totalDocumentsPointDated: 5, totalDocumentsRangeDated: 0, totalDocumentsUndated: 0,
            volumesCovered: 1,
            administrations: [
                AdministrationProfile(
                    id: "sitting", number: 47, president: "Sitting President", party: "Republican",
                    start: "2025-01-20", end: nil,
                    pointDocCount: 5, rangeDocCount: 0, volumeCount: 3, volumeCountPointOnly: 3,
                    coverageEarliest: 2025, coverageLatest: 2025, volumes: []
                ),
            ],
            volumeTotals: [:]
        )
        let profile = AdministrationProfilesData(index: index, includeEditorialNotes: false).profiles.first
        #expect(profile?.termYears == 0)
        #expect(profile?.volumesPerAdministrationYear == 0)
    }

    // MARK: Per-volume proportion, both toggle states

    @Test("AdministrationProfilesData: per-volume proportion = docs / volumeTotal (toggle off)")
    func proportionToggleOff() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        let alphaVolumes = data.volumeShares(for: "alpha")
        // Sorted by documentCount desc; volA and volB both 50, so both present.
        let volA = alphaVolumes.first { $0.id == "volA" }!
        // alpha point docs in volA = 50, volA total point = 100 → 0.5.
        #expect(volA.documentCount == 50)
        #expect(abs(volA.proportion - 0.5) < 1e-9)

        let volB = alphaVolumes.first { $0.id == "volB" }!
        // volB total point = 200, alpha = 50 → 0.25.
        #expect(volB.documentCount == 50)
        #expect(abs(volB.proportion - 0.25) < 1e-9)
    }

    @Test("AdministrationProfilesData: per-volume proportion honors the editorial-note toggle")
    func proportionToggleOn() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: true)
        let alphaVolumes = data.volumeShares(for: "alpha")
        let volA = alphaVolumes.first { $0.id == "volA" }!
        // alpha in volA = 50 point + 5 range = 55; volA total = 100 point + 20 range = 120 → 55/120.
        #expect(volA.documentCount == 55)
        #expect(abs(volA.proportion - 55.0 / 120.0) < 1e-9)
    }

    @Test("AdministrationProfilesData: any-overlap can push a volume's summed proportion over 100%")
    func proportionCanExceedHundred() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        // volA appears in both alpha (50/100) and beta (40/100) → summed 0.9; still
        // each per-row proportion is ≤ 1, but the sum is meaningful evidence that
        // overlap accumulates. Assert both rows exist for volA.
        let alphaVolA = data.volumeShares(for: "alpha").first { $0.id == "volA" }
        let betaVolA = data.volumeShares(for: "beta").first { $0.id == "volA" }
        #expect(alphaVolA != nil)
        #expect(betaVolA != nil)
        #expect(abs((betaVolA?.proportion ?? 0) - 0.4) < 1e-9)  // 40/100
    }

    @Test("AdministrationProfilesData: a missing volume total yields a zero proportion, no crash")
    func missingVolumeTotalSafe() {
        let index = AdministrationProfilesIndex(
            schemaVersion: 1, generated: "2026-07-05",
            totalDocumentsPointDated: 10, totalDocumentsRangeDated: 0, totalDocumentsUndated: 0,
            volumesCovered: 1,
            administrations: [
                AdministrationProfile(
                    id: "x", number: 40, president: "X", party: "Republican",
                    start: "1970-01-01", end: "1974-01-01",
                    pointDocCount: 10, rangeDocCount: 0, volumeCount: 1, volumeCountPointOnly: 1,
                    coverageEarliest: 1970, coverageLatest: 1974,
                    volumes: [AdministrationVolume(volumeId: "missing", pointDocs: 10, rangeDocs: 0)]
                ),
            ],
            volumeTotals: [:]  // no total for "missing"
        )
        let share = AdministrationProfilesData(index: index, includeEditorialNotes: false)
            .volumeShares(for: "x").first
        #expect(share?.documentCount == 10)
        #expect(share?.proportion == 0)  // denominator 0 → guarded to 0
    }

    // MARK: most-documented default

    @Test("AdministrationProfilesData: mostDocumentedProfile picks the largest count")
    func mostDocumented() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        #expect(data.mostDocumentedProfile?.id == "alpha")  // 100 > 40
    }

    // MARK: Empty safety

    @Test("AdministrationProfilesData: a nil index yields empty collections, no crash")
    func nilIndexSafe() {
        let data = AdministrationProfilesData(index: nil, includeEditorialNotes: false)
        #expect(data.profiles.isEmpty)
        #expect(data.volumeShares.isEmpty)
        #expect(data.totalDocumentsPointDated == 0)
        #expect(data.totalDocumentsRangeDated == 0)
        #expect(data.volumesCovered == 0)
        #expect(data.mostDocumentedProfile == nil)
        #expect(data.volumeShares(for: "anything").isEmpty)
    }

    @Test("AdministrationProfilesData: an all-zero index shows no profiles but stays safe")
    func allZeroSafe() {
        let index = AdministrationProfilesIndex(
            schemaVersion: 1, generated: "2026-07-05",
            totalDocumentsPointDated: 0, totalDocumentsRangeDated: 0, totalDocumentsUndated: 0,
            volumesCovered: 0,
            administrations: [
                AdministrationProfile(
                    id: "z", number: 48, president: "Z", party: "Democratic",
                    start: "2029-01-20", end: "2033-01-20",
                    pointDocCount: 0, rangeDocCount: 0, volumeCount: 0, volumeCountPointOnly: 0,
                    coverageEarliest: nil, coverageLatest: nil, volumes: []
                ),
            ],
            volumeTotals: [:]
        )
        let data = AdministrationProfilesData(index: index, includeEditorialNotes: true)
        #expect(data.profiles.isEmpty)
    }

    // MARK: Decode tolerance

    @Test("AdministrationProfilesIndex: a JSON payload missing keys decodes without crashing")
    func tolerantDecode() throws {
        // Missing volumeTotals + missing several admin scalar keys.
        let json = """
        {
          "schemaVersion": 1,
          "generated": "2026-07-05",
          "totalDocumentsPointDated": 5,
          "volumesCovered": 1,
          "administrations": [
            { "id": "solo", "number": 40, "president": "Solo", "party": "Republican",
              "start": "1970-01-01", "end": "1974-01-01", "pointDocCount": 5,
              "volumes": [ { "volumeId": "v", "pointDocs": 5 } ] }
          ]
        }
        """
        let index = try JSONDecoder().decode(
            AdministrationProfilesIndex.self, from: Data(json.utf8)
        )
        #expect(index.schemaVersion == 1)
        #expect(index.totalDocumentsRangeDated == 0)  // missing → 0
        #expect(index.volumeTotals.isEmpty)           // missing → empty
        let admin = index.administrations.first
        #expect(admin?.rangeDocCount == 0)            // missing → 0
        #expect(admin?.volumeCount == 0)              // missing → 0
        #expect(admin?.coverageEarliest == nil)       // missing → nil
        #expect(admin?.volumes.first?.rangeDocs == 0) // missing → 0
    }

    // MARK: Integration — the bundled artifact

    /// Guards that the real `administration-profiles-index.json` is bundled and
    /// matches the schema, with the SA-2a headline figures. This proves the
    /// resource is in the built product and that Nixon and Ford are attributed as
    /// distinct administrations.
    @Test("Bundled administration-profiles-index.json decodes with the expected headline figures")
    func bundledArtifactDecodes() throws {
        let url = try #require(
            Bundle.main.url(forResource: "administration-profiles-index", withExtension: "json"),
            "administration-profiles-index.json must be bundled as an app resource"
        )
        let data = try Data(contentsOf: url)
        let index = try JSONDecoder().decode(AdministrationProfilesIndex.self, from: data)
        #expect(index.schemaVersion == 1)
        #expect(index.volumesCovered == 552)

        // ~26 administrations are populated (Lincoln … G.H.W. Bush).
        let populated = index.administrations.filter { $0.pointDocCount > 0 || $0.rangeDocCount > 0 }
        #expect(populated.count == 26, "expected ~26 populated administrations; got \(populated.count)")

        // Nixon and Ford are DISTINCT administrations with distinct point counts.
        let nixon = index.administrations.first { $0.id == "nixon" }
        let ford = index.administrations.first { $0.id == "ford" }
        #expect(nixon?.pointDocCount == 13611)
        #expect(ford?.pointDocCount == 4333)
        #expect(nixon?.president == "Richard M. Nixon")
        #expect(ford?.president == "Gerald R. Ford")

        // The derivation over the real data hides zero-doc administrations and
        // stays sound.
        let derived = AdministrationProfilesData(index: index, includeEditorialNotes: false)
        #expect(derived.profiles.count == 26)
        #expect(derived.profiles.allSatisfy { $0.documentCount > 0 })
        #expect(derived.mostDocumentedProfile != nil)

        // Grover Cleveland's two non-consecutive terms decode as DISTINCT
        // administrations (the chart keys x-position on the id, so they never
        // merge into one bar).
        let clevelands = index.administrations.filter { $0.president == "Grover Cleveland" }
        #expect(clevelands.count == 2, "Cleveland's two terms must be distinct administrations")
        #expect(Set(clevelands.map(\.id)).count == 2)
    }

    // MARK: Axis-label disambiguation

    /// The two overview charts key the x-position on the distinct administration
    /// id, so same-name administrations render as separate bars; their axis labels
    /// are disambiguated by appending the term start year. This guards the fix for
    /// the SA-2b review finding where both charts collapsed Grover Cleveland's two
    /// terms into one stacked bar.
    // @MainActor: axisLabels is a static helper on the dashboard `View`, so it is
    // main-actor-isolated; this is the only caller that reaches it from off-main.
    @Test @MainActor
    func axisLabelsDisambiguateSameLastName() {
        let profiles = AdministrationProfilesData(index: fixtureWithClevelandLikeTerms(),
                                                  includeEditorialNotes: false).profiles
        let labels = AdministrationProfilesDashboard.axisLabels(for: profiles)

        // Each administration gets its own label keyed on its distinct id.
        #expect(labels.count == profiles.count)
        #expect(Set(labels.keys).count == profiles.count)

        // The two "Cleveland" administrations get distinct, year-disambiguated
        // labels; the lone "Alpha" stays a bare last name.
        #expect(labels["cleveland-1"] == "Cleveland 1885")
        #expect(labels["cleveland-2"] == "Cleveland 1893")
        #expect(labels["alpha"] == "Alpha")
    }

    /// Two administrations sharing the last name "Cleveland" (distinct ids/terms)
    /// plus one uniquely named administration.
    private func fixtureWithClevelandLikeTerms() -> AdministrationProfilesIndex {
        AdministrationProfilesIndex(
            schemaVersion: 1, generated: "2026-07-05",
            totalDocumentsPointDated: 300, totalDocumentsRangeDated: 0, totalDocumentsUndated: 0,
            volumesCovered: 3,
            administrations: [
                AdministrationProfile(
                    id: "cleveland-1", number: 22, president: "Grover Cleveland", party: "Democratic",
                    start: "1885-03-04", end: "1889-03-04",
                    pointDocCount: 100, rangeDocCount: 0, volumeCount: 4, volumeCountPointOnly: 4,
                    coverageEarliest: 1885, coverageLatest: 1889, volumes: []
                ),
                AdministrationProfile(
                    id: "cleveland-2", number: 24, president: "Grover Cleveland", party: "Democratic",
                    start: "1893-03-04", end: "1897-03-04",
                    pointDocCount: 120, rangeDocCount: 0, volumeCount: 4, volumeCountPointOnly: 4,
                    coverageEarliest: 1893, coverageLatest: 1897, volumes: []
                ),
                AdministrationProfile(
                    id: "alpha", number: 23, president: "Alice Alpha", party: "Republican",
                    start: "1889-03-04", end: "1893-03-04",
                    pointDocCount: 80, rangeDocCount: 0, volumeCount: 2, volumeCountPointOnly: 2,
                    coverageEarliest: 1889, coverageLatest: 1893, volumes: []
                ),
            ],
            volumeTotals: [:]
        )
    }

    // MARK: Subseries scope (#236)

    @Test("scope: counts recompute from the in-scope volumes' breakdown")
    func scopeRecomputesFromBreakdown() {
        // volA touches both alpha (50 point / 5 range) and beta (40 point / 10 range).
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false,
                                              scopeVolumeIds: ["volA"])
        let alpha = data.profiles.first { $0.id == "alpha" }
        let beta = data.profiles.first { $0.id == "beta" }
        #expect(alpha?.pointDocCount == 50)   // volA only (was 100 whole-series)
        #expect(alpha?.rangeDocCount == 5)
        #expect(alpha?.documentCount == 50)   // toggle off
        #expect(alpha?.volumeCount == 1)      // one in-scope contributing volume
        #expect(beta?.pointDocCount == 40)
        #expect(beta?.volumeCount == 1)
    }

    @Test("scope: an administration no in-scope volume touches drops out")
    func scopeDropsUntouchedAdministration() {
        // volB touches only alpha; beta has no volB row → beta must disappear.
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false,
                                              scopeVolumeIds: ["volB"])
        #expect(data.profiles.map(\.id) == ["alpha"])
        #expect(data.profiles.first?.pointDocCount == 50)
    }

    @Test("scope: the editorial-note toggle still applies under a scope")
    func scopeHonorsEditorialToggle() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: true,
                                              scopeVolumeIds: ["volA"])
        // alpha volA: 50 point + 5 range = 55 with the toggle on.
        #expect(data.profiles.first { $0.id == "alpha" }?.documentCount == 55)
    }

    @Test("scope: per-administration coverage span is dropped (cannot be re-derived per scope)")
    func scopeDropsCoverageSpan() {
        let scoped = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false,
                                                scopeVolumeIds: ["volA"])
        for profile in scoped.profiles {
            #expect(profile.coverageEarliest == nil)
            #expect(profile.coverageLatest == nil)
        }
        // Whole-series (nil scope) keeps the span.
        let whole = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        #expect(whole.profiles.first { $0.id == "alpha" }?.coverageEarliest == 1970)
    }

    @Test("scope: nil scope is identical to the un-parameterised whole-series result")
    func nilScopeUnchanged() {
        let whole = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false)
        let explicit = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false,
                                                  scopeVolumeIds: nil)
        #expect(whole.profiles.map(\.pointDocCount) == explicit.profiles.map(\.pointDocCount))
        #expect(whole.profiles.map(\.documentCount) == explicit.profiles.map(\.documentCount))
    }

    @Test("scope: proportions restrict to in-scope volume rows")
    func scopeRestrictsVolumeShares() {
        let data = AdministrationProfilesData(index: fixture(), includeEditorialNotes: false,
                                              scopeVolumeIds: ["volA"])
        // alpha's share rows should now list only volA.
        #expect(data.volumeShares(for: "alpha").map(\.id) == ["volA"])
    }

    // MARK: Bundled-index invariant (the scoped recompute's correctness rests on this)

    @Test("bundled index: each administration's pointDocCount equals the sum of its volumes[] pointDocs")
    func bundledIndexVolumeSumsMatchTotals() async {
        // Under a whole-series (all-volume) scope the recompute sums volumes[]; it can only
        // equal the pre-aggregated pointDocCount when volumes[] is complete (not truncated).
        guard let index = await MainActor.run(body: { AdministrationProfilesStore().index }) else {
            return // resource unavailable in this host — nothing to assert
        }
        for admin in index.administrations {
            let summedPoint = admin.volumes.reduce(0) { $0 + $1.pointDocs }
            let summedRange = admin.volumes.reduce(0) { $0 + $1.rangeDocs }
            #expect(summedPoint == admin.pointDocCount,
                    "\(admin.id): volumes[] pointDocs sum \(summedPoint) != pointDocCount \(admin.pointDocCount)")
            #expect(summedRange == admin.rangeDocCount,
                    "\(admin.id): volumes[] rangeDocs sum \(summedRange) != rangeDocCount \(admin.rangeDocCount)")
        }
    }
}

// MARK: - AdministrationPresetMenuTests

/// Tests for `AdministrationPresetMenu.presets(from:corpusMaxYear:currentYear:)` — the
/// bounding/clamping contract that keeps a preset write inside the host year bar's
/// eagerly-built `start...corpusMaxYear` field bounds (Session 3 review: a raw
/// post-corpus term start, e.g. Clinton's 1993 against a 1992 corpus ceiling, formed
/// an invalid `ClosedRange` and trapped).
///
/// Lives beside `AdministrationProfilesDataTests` because it exercises the same
/// `AdministrationProfile` fixture shape; no SwiftUI view is instantiated.
///
/// Version history:
///   1.0 — Session 3 review / #236: preset bounding + clamping regression tests
struct AdministrationPresetMenuTests {

    /// A minimal profile fixture — only `number`/`start`/`end` matter to the presets.
    private func profile(number: Int, president: String, start: String, end: String?) -> AdministrationProfile {
        AdministrationProfile(
            id: president.lowercased(), number: number, president: president, party: "Republican",
            start: start, end: end, pointDocCount: 0, rangeDocCount: 0,
            volumeCount: 0, volumeCountPointOnly: 0,
            coverageEarliest: nil, coverageLatest: nil, volumes: []
        )
    }

    @Test("presets: terms entirely past the corpus ceiling are dropped (the crash input)")
    func postCorpusTermsDropped() {
        let admins = [
            profile(number: 36, president: "Lyndon B. Johnson", start: "1963-11-22", end: "1969-01-20"),
            profile(number: 42, president: "Bill Clinton", start: "1993-01-20", end: "2001-01-20"),
            profile(number: 47, president: "Sitting", start: "2025-01-20", end: nil),
        ]
        let presets = AdministrationPresetMenu.presets(from: admins, corpusMaxYear: 1992, currentYear: 2026)
        // Clinton (1993–2001) and the open 2025– term never intersect 1861...1992:
        // offering them would write a start year past the ceiling and trap the year bar.
        #expect(presets.map(\.profile.number) == [36])
        #expect(presets.first?.start == 1963)
        #expect(presets.first?.end == 1969)
    }

    @Test("presets: a term straddling the corpus ceiling is clamped to it")
    func straddlingTermClamped() {
        let admins = [profile(number: 41, president: "George Bush", start: "1989-01-20", end: "1993-01-20")]
        let presets = AdministrationPresetMenu.presets(from: admins, corpusMaxYear: 1992, currentYear: 2026)
        #expect(presets.count == 1)
        #expect(presets.first?.start == 1989)
        #expect(presets.first?.end == 1992)
    }

    @Test("presets: a term straddling the 1861 floor is clamped up to it")
    func preFloorTermClamped() {
        let admins = [profile(number: 15, president: "James Buchanan", start: "1857-03-04", end: "1861-03-04")]
        let presets = AdministrationPresetMenu.presets(from: admins, corpusMaxYear: 1992, currentYear: 2026)
        // 1857–1861 intersects the span only at the floor year: clamps to 1861...1861,
        // still a valid (degenerate) range for the year bar.
        #expect(presets.first?.start == 1861)
        #expect(presets.first?.end == 1861)
        // A term entirely before the floor is dropped.
        let early = [profile(number: 1, president: "George Washington", start: "1789-04-30", end: "1797-03-04")]
        #expect(AdministrationPresetMenu.presets(from: early, corpusMaxYear: 1992, currentYear: 2026).isEmpty)
    }

    @Test("presets: every preset stays inside floorYear...corpusMaxYear with start <= end, in number order")
    func presetsAlwaysWithinHostBounds() async {
        // The bundled index end-to-end: no preset it yields may ever escape the host
        // bounds, whatever administrations the index carries.
        guard let index = await MainActor.run(body: { AdministrationProfilesStore().index }) else {
            return // resource unavailable in this host — nothing to assert
        }
        let corpusMaxYear = 1992
        let presets = AdministrationPresetMenu.presets(from: index.administrations,
                                                       corpusMaxYear: corpusMaxYear,
                                                       currentYear: 2026)
        #expect(!presets.isEmpty)
        for preset in presets {
            #expect(preset.start >= AdministrationPresetMenu.floorYear)
            #expect(preset.end <= corpusMaxYear)
            #expect(preset.start <= preset.end)
        }
        #expect(presets.map(\.profile.number) == presets.map(\.profile.number).sorted())
        // The bundled index's post-corpus administrations (Clinton onward) are gone.
        #expect(!presets.contains { $0.profile.id == "clinton" })
    }
}
