// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - LotClaimantsIndexTests

/// The divided-lot index (#675 / N-8b) and the artifact it ships.
///
/// NARA divides a lot file across several series as readily as it consolidates several into one.
/// `central-files-index.json` stores one `naId` per lot, so wherever NARA divided one the app
/// named a single series and said nothing about the rest.
///
/// Version history:
///   1.0 — Session 2026-08-05: #675 / N-8b
@Suite("Lot claimants index")
struct LotClaimantsIndexTests {

    private func loadIndex() throws -> LotClaimantsIndex {
        let url = try #require(
            Bundle(for: ClaimantsBundleToken.self).url(forResource: "lot-claimants-index",
                                                       withExtension: "json")
                ?? Bundle.main.url(forResource: "lot-claimants-index", withExtension: "json"),
            "lot-claimants-index.json must be enrolled as a bundle resource")
        return try JSONDecoder().decode(LotClaimantsIndex.self, from: Data(contentsOf: url))
    }

    // MARK: The artifact

    @Test("The shipped artifact decodes and every entry is genuinely divided")
    func artifactIsWellFormed() throws {
        let index = try loadIndex()
        #expect(index.schemaVersion == 1)
        #expect(!index.lots.isEmpty)
        for entry in index.lots {
            // A single-claimant row would be noise: central-files-index already resolves it.
            #expect(entry.claimants.count > 1,
                    "\(entry.lotNumber) has \(entry.claimants.count) claimant(s) — only divided lots belong here")
            #expect(entry.lotNumber == LotResolutionAcceptance.foldControlNumber(entry.lotNumber),
                    "\(entry.lotNumber) is not in folded form, so no lookup will match it")
        }
    }

    @Test("Claimant NAIDs are unique within a lot and every claimant is usable")
    func claimantsAreWellFormed() throws {
        for entry in try loadIndex().lots {
            let naIds = entry.claimants.map(\.naId)
            #expect(Set(naIds).count == naIds.count, "\(entry.lotNumber) lists a NAID twice")
            for c in entry.claimants {
                #expect(!c.naId.isEmpty)
                #expect(!c.title.isEmpty, "\(entry.lotNumber)/\(c.naId) has no title to show")
                #expect(URL(string: c.catalogURL) != nil)
                #expect(["controlNumber", "consolidationNote"].contains(c.evidence),
                        "unknown evidence kind \(c.evidence)")
            }
        }
    }

    @Test("Entries and claimants are in a stable order")
    func artifactIsDeterministic() throws {
        // A generator that reordered between runs would produce a diff on every regeneration
        // and make review impossible.
        let index = try loadIndex()
        #expect(index.lots.map(\.lotNumber) == index.lots.map(\.lotNumber).sorted())
        for entry in index.lots {
            #expect(entry.claimants.map(\.naId) == entry.claimants.map(\.naId).sorted(),
                    "\(entry.lotNumber) claimants are not in NAID order")
        }
    }

    @Test("Provenance is recorded — which harvest this came from")
    func provenanceIsPresent() throws {
        let index = try loadIndex()
        #expect(index.harvestGenerated?.isEmpty == false,
                "no harvest stamp: a stale artifact would be indistinguishable from a fresh one")
        #expect(index.note?.isEmpty == false)
    }

    // MARK: Lookup

    @Test("Lookup folds the raw citation forms")
    func lookupFolds() throws {
        let index = try loadIndex()
        let key = try #require(index.lots.first?.lotNumber)
        #expect(index.claimants(forRawLot: key)?.isEmpty == false)
        #expect(index.claimants(forRawLot: key.lowercased())?.isEmpty == false)
        #expect(index.claimants(forRawLot: "Lot \(key)")?.isEmpty == false)
        #expect(index.claimants(forRawLot: "99Z9") == nil)
        #expect(index.claimants(forRawLot: "") == nil)
    }

    @Test("An undivided lot returns nil, so the bundled card still shows")
    func undividedLotsAreNotClaimed() throws {
        let index = try loadIndex()
        // 64D199 resolves to one series and must keep its confident bundled card.
        #expect(index.claimants(forRawLot: "64D199") == nil)
    }

    @Test("A single-claimant entry is refused even if the artifact ever contains one")
    func singleClaimantEntryIsRefused() throws {
        // The shipped artifact holds only divided lots, so this guard has no live example —
        // which is precisely why it needs a synthetic one. Without it, a generator change that
        // started emitting every lot would make the app show a one-item "candidates" card in
        // place of the confident bundled card, for 800+ lots.
        let synthetic = LotClaimantsIndex(
            schemaVersion: 1, generated: "2026-08-05", note: nil, harvestGenerated: "2026-07-30",
            lots: [
                .init(lotNumber: "64D199", claimants: [
                    LotClaimant(naId: "602231", title: "Only One", recordGroup: "59",
                                hmsMlrEntryNumbers: nil, dateRange: nil, evidence: "controlNumber"),
                ]),
                .init(lotNumber: "64D563", claimants: [
                    LotClaimant(naId: "1", title: "A", recordGroup: "59",
                                hmsMlrEntryNumbers: nil, dateRange: nil, evidence: "controlNumber"),
                    LotClaimant(naId: "2", title: "B", recordGroup: "59",
                                hmsMlrEntryNumbers: nil, dateRange: nil, evidence: "controlNumber"),
                ]),
            ])
        #expect(synthetic.claimants(forRawLot: "64D199") == nil,
                "a lot with one claimant must fall through to the bundled card")
        #expect(LotClaimantsIndex.candidatesOutcome(forRawLot: "64D199", in: synthetic) == nil)
        #expect(synthetic.claimants(forRawLot: "64D563")?.count == 2)
    }

    // MARK: The rendered outcome

    @Test("A divided lot becomes the .candidates outcome, with every claimant")
    func dividedLotBecomesCandidates() throws {
        let index = try loadIndex()
        let entry = try #require(index.lots.max(by: { $0.claimants.count < $1.claimants.count }))
        let outcome = try #require(
            LotClaimantsIndex.candidatesOutcome(forRawLot: entry.lotNumber, in: index))
        guard case .candidates(let series, let rationale, _, _) = outcome else {
            Issue.record("divided lot did not map to .candidates"); return
        }
        #expect(series.count == entry.claimants.count,
                "the render drops claimants — the whole point is that none is omitted")
        #expect(rationale.contains("\(entry.claimants.count)"),
                "the rationale does not tell the reader how many series NARA divided this into")
        #expect(Set(series.map(\.naId)) == Set(entry.claimants.map(\.naId)))
    }

    @Test("An undivided lot yields no candidates outcome")
    func undividedLotYieldsNoOutcome() throws {
        #expect(LotClaimantsIndex.candidatesOutcome(forRawLot: "64D199",
                                                    in: try loadIndex()) == nil)
        #expect(LotClaimantsIndex.candidatesOutcome(forRawLot: "64D563", in: nil) == nil)
    }

    // MARK: Agreement with the bundle it supplements

    @Test("The bundle's chosen naId is among the claimants for every divided lot")
    func bundleChoiceIsAlwaysAClaimant() throws {
        // If it were not, the bundle would be naming a series NARA does not associate with the
        // lot — a different and much worse defect than an undisclosed pick.
        let index = try loadIndex()
        let url = try #require(
            Bundle(for: ClaimantsBundleToken.self).url(forResource: "central-files-index",
                                                       withExtension: "json")
                ?? Bundle.main.url(forResource: "central-files-index", withExtension: "json"))
        struct Shape: Decodable { struct Lot: Decodable { let lotNumber: String; let naId: String }
                                  let lotFiles: [Lot] }
        let bundle = try JSONDecoder().decode(Shape.self, from: Data(contentsOf: url))
        var checked = 0
        for row in bundle.lotFiles {
            guard let claimants = index.claimants(forRawLot: row.lotNumber) else { continue }
            checked += 1
            #expect(claimants.contains { $0.naId == row.naId },
                    "\(row.lotNumber): the bundle names \(row.naId), which claims no such lot")
        }
        #expect(checked > 50, "guard is vacuous — only \(checked) divided lots matched the bundle")
    }
}

/// Anchors `Bundle(for:)` to the test bundle.
private final class ClaimantsBundleToken {}

// MARK: - LotClaimantsWiringAuditTests

/// That both Source Explorer views render divided lots, and prefer them over the single card.
///
/// The suite above proves the data and the mapping; neither proves anything renders. Precedence
/// matters as much as presence here: if the bundled single-series card still wins, the app keeps
/// asserting one series and the artifact is inert.
///
/// Version history:
///   1.0 — Session 2026-08-05: #675 / N-8b
@Suite("Lot claimants wiring")
struct LotClaimantsWiringAuditTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 5_000, "\(path) is implausibly small")
        return text
    }

    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Both views consult the claimants index")
    func bothPlatformsConsultTheIndex() throws {
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let src = Self.code(try Self.source(path))
            #expect(src.contains("LotClaimantsIndex.candidatesOutcome("),
                    "\(path) never asks whether NARA divided the lot")
            #expect(src.contains("LotClaimantsIndexStore.shared"),
                    "\(path) does not read the bundled claimants index")
        }
    }

    @Test("A divided lot takes precedence over the single bundled card")
    func dividedLotWinsOverTheSingleCard() throws {
        // The ordering is the fix. With the bundled card first, the artifact changes nothing.
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let src = Self.code(try Self.source(path))
            let divided = try #require(src.range(of: "LotClaimantsIndex.candidatesOutcome("),
                                       "\(path): no divided-lot branch")
            let single = try #require(src.range(of: "lotFile(forRawLot:"),
                                      "\(path): no bundled-card branch")
            #expect(divided.lowerBound < single.lowerBound,
                    "\(path): the single bundled card is checked first, so divided lots never show")
            #expect(src.contains("} else if"),
                    "\(path): the two branches are not exclusive — both cards could render")
        }
    }
}
