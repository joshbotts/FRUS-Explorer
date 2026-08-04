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

// MARK: - CuratedLotResolutionsTests

/// The hand-curated lot outcomes (#375 / N-3) and — the load-bearing half — the
/// **containment** rule that keeps a non-deterministic outcome out of every bundle whose
/// render surfaces cannot express doubt.
///
/// Version history:
///   1.0 — Session 2026-08-03: #375 curated lot outcomes
@Suite("Curated lot resolutions")
struct CuratedLotResolutionsTests {

    /// The shipped curated artifact, or a failure if it is missing/malformed.
    private func loadCurated() throws -> CuratedLotResolutions {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: "curated-lot-resolutions",
                                              withExtension: "json")
                ?? Bundle.main.url(forResource: "curated-lot-resolutions", withExtension: "json"),
            "curated-lot-resolutions.json must be enrolled as a bundle resource")
        return try JSONDecoder().decode(CuratedLotResolutions.self, from: Data(contentsOf: url))
    }

    /// Any bundled JSON resource, decoded as a dictionary.
    private func loadJSONObject(_ name: String) throws -> [String: Any] {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")
                ?? Bundle.main.url(forResource: name, withExtension: "json"),
            "\(name).json must be enrolled as a bundle resource")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try #require(object as? [String: Any])
    }

    // MARK: Shape

    @Test("The shipped artifact decodes and every row yields a typed outcome")
    func everyRowIsWellFormed() throws {
        let curated = try loadCurated()
        #expect(curated.schemaVersion == 1)
        #expect(!curated.lots.isEmpty)
        for lot in curated.lots {
            #expect(lot.outcome != nil,
                    "\(lot.lotNumber) has kind '\(lot.kind)' but not the fields that kind requires — a malformed row is silently treated as uncurated, so this must never ship")
            #expect(lot.lotNumber == CentralFilesIndex.normalizeLot(lot.lotNumber),
                    "\(lot.lotNumber) is not in normalizeLot form, so no lookup will ever match it")
        }
    }

    @Test("Lot keys are unique — a duplicate would make the outcome depend on file order")
    func lotKeysAreUnique() throws {
        let keys = try loadCurated().lots.map(\.lotNumber)
        #expect(Set(keys).count == keys.count)
    }

    @Test("Every stored URL parses")
    func urlsParse() throws {
        for lot in try loadCurated().lots {
            switch lot.outcome {
            case .possible(let series, _):
                #expect(series.url != nil, "\(lot.lotNumber): catalogURL does not parse")
            case .candidates(let series, _, _, let seeAll):
                for candidate in series {
                    #expect(candidate.url != nil,
                            "\(lot.lotNumber)/\(candidate.naId): catalogURL does not parse")
                }
                if lot.seeAllURL != nil { #expect(seeAll != nil) }
            case .referral(let referral):
                if lot.browseURL != nil { #expect(referral.url != nil) }
            case nil:
                Issue.record("\(lot.lotNumber) produced no outcome")
            }
        }
    }

    // MARK: Lookup

    @Test("Lookup normalizes the same raw forms CentralFilesIndex does")
    func lookupNormalizes() throws {
        let curated = try loadCurated()
        // Pick the first curated lot rather than hard-coding one, so the test survives
        // curation growing without pinning today's contents.
        let key = try #require(curated.lots.first?.lotNumber)
        #expect(curated.record(forRawLot: key)?.lotNumber == key)
        #expect(curated.record(forRawLot: key.lowercased())?.lotNumber == key)
        #expect(curated.record(forRawLot: "Lot \(key)")?.lotNumber == key)
        #expect(curated.record(forRawLot: "99Z9") == nil)
    }

    @Test("A curated record group overrides the parser's RG-59 default")
    func curatedRecordGroupIsAvailable() throws {
        let curated = try loadCurated()
        // The parser defaults every non-F lot to RG-59 (SourceNoteParser.lotFileRecordGroup),
        // so a curated lot NARA holds elsewhere is only labelled correctly if curation wins.
        // At least one curated row must carry a record group, or the override is dead code.
        #expect(curated.lots.contains { $0.recordGroup != nil })
        for lot in curated.lots where lot.recordGroup != nil {
            #expect(curated.recordGroup(forRawLot: lot.lotNumber) == lot.recordGroup)
        }
    }

    // MARK: Containment — the rule that keeps doubt from being rendered as certainty

    @Test("No curated lot is also a confident resolution in central-files-index")
    func curatedLotsAreNotInCentralFilesIndex() throws {
        let curated = try loadCurated()
        let index = try loadJSONObject("central-files-index")
        let lotFiles = (index["lotFiles"] as? [[String: Any]]) ?? []
        let confident = Set(lotFiles.compactMap { $0["lotNumber"] as? String })
        #expect(!confident.isEmpty, "guard is vacuous if the bundle has no lots")
        for lot in curated.lots {
            #expect(!confident.contains(lot.lotNumber),
                    "\(lot.lotNumber) is curated as non-deterministic AND present in central-files-index.json, where SourceExplorerView renders it with 'Resolved from the bundled index'. Remove one.")
        }
    }

    @Test("No curated lot reaches volume-sources-index, whose render surface is an icon-only link")
    func curatedLotsAreNotInVolumeSourcesIndex() throws {
        let curated = try loadCurated()
        let index = try loadJSONObject("volume-sources-index")
        let lots = (index["lots"] as? [String: Any]) ?? [:]
        #expect(!lots.isEmpty, "guard is vacuous if the bundle has no lots")
        for lot in curated.lots {
            #expect(lots[lot.lotNumber] == nil,
                    "\(lot.lotNumber) is curated as non-deterministic AND resolvable through volume-sources-index.json. VolumeSourcesView renders that as a bare building.columns icon link and CollectionGeneratedBlocks flattens it into a two-field export row — neither can state a caveat.")
        }
    }

    @Test("No curated lot carries a NAID in collection-authority, which captions one as resolved")
    func curatedLotsHaveNoAuthorityNAID() throws {
        let curated = try loadCurated()
        let authority = try loadJSONObject("collection-authority")
        let collections = (authority["collections"] as? [[String: Any]]) ?? []
        #expect(!collections.isEmpty, "guard is vacuous if the authority has no records")
        let curatedKeys = Set(curated.lots.map { "lot:" + $0.lotNumber })
        for record in collections {
            guard let id = record["id"] as? String, curatedKeys.contains(id) else { continue }
            let naId = record["naId"] as? String
            #expect(naId == nil || naId?.isEmpty == true,
                    "\(id) carries naId \(naId ?? "?") in collection-authority.json. CollectionDetailView captions a NAID with 'resolved offline from the bundled index; no API key required' — a claim curation cannot make.")
        }
    }

    @Test("A curated NAID may still be a CONFIDENT resolution for a different lot")
    func confidenceBelongsToTheEdgeNotTheNAID() throws {
        let curated = try loadCurated()
        let index = try loadJSONObject("central-files-index")
        let lotFiles = (index["lotFiles"] as? [[String: Any]]) ?? []

        // Conference Files (NAID 602875) is a control-number resolution for nine lots and a
        // possible match for four curated ones. If a future change tried to express curated
        // doubt by denylisting the NAID — the #351 `untrustworthyNAIDs` shape — it would
        // suppress those nine certain resolutions too. This test states why that shape is wrong.
        var curatedNAIDs: Set<String> = []
        for lot in curated.lots {
            if case .possible(let series, _)? = lot.outcome { curatedNAIDs.insert(series.naId) }
        }
        guard !curatedNAIDs.isEmpty else { return }
        let sharedWithConfident = lotFiles
            .compactMap { $0["naId"] as? String }
            .filter { curatedNAIDs.contains($0) }
        #expect(!sharedWithConfident.isEmpty,
                "expected at least one curated NAID to also be a confident resolution elsewhere; if this ever becomes false the comment above should be revisited, not the rule")
    }
}

/// Anchors `Bundle(for:)` to the test bundle so the shipped resources resolve under the
/// app host as well as a plain unit-test run.
private final class BundleToken {}

// MARK: - CuratedLotWiringAuditTests

/// A curated outcome must have a live render site on **both** Source Explorer views, and
/// neither may borrow the confident card's caption.
///
/// ## The bug this exists to stop happening again
/// The data tests above all pass with `curatedLotSection` and `curatedLotBox` deleted from
/// the two views: they assert the artifact's shape and its containment, never that anything
/// renders it. That is the mirrored-wiring trap the repo has hit repeatedly — a suite that is
/// green because it tests a parallel implementation rather than the shipping one.
///
/// A source scan proves the call is in the file. It cannot prove the file is on screen, which
/// is why every PR touching these views also carries a visual-review checklist. What it *can*
/// prove is the thing that silently regresses: one platform being updated and the other not
/// (`project_dual_settings_views`), and a hedged branch acquiring an unhedged caption.
///
/// Version history:
///   1.0 — Session 2026-08-03: #375 curated lot outcomes
@Suite("Curated lot wiring")
struct CuratedLotWiringAuditTests {

    /// The repo root, derived from this file's location.
    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Reads a source file, refusing an implausibly small one — a truncated read would make
    /// every "does it contain X" assertion below pass or fail for the wrong reason.
    private static func source(_ path: String) throws -> String {
        let text = try String(contentsOf: Self.root.appending(path: path), encoding: .utf8)
        #expect(text.count > 5_000, "\(path) is implausibly small — did it move or get truncated?")
        return text
    }

    /// `text` with every full-line `//` comment removed, so an assertion cannot be satisfied
    /// by a comment that merely *mentions* the call it is looking for.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Whether `name` is **invoked** in `text`, as distinct from merely declared.
    ///
    /// The distinction is the whole point: a first draft of this suite asserted only that
    /// `text.contains("curatedLotSection(")`, which the `private func curatedLotSection(…)`
    /// declaration satisfies on its own. Deleting the call site left the audit green — the
    /// exact regression the audit exists to catch. Dropping declaration lines first closes it.
    private static func callsFunction(_ name: String, in text: String) -> Bool {
        code(text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.contains("func \(name)(") }
            .joined(separator: "\n")
            .contains("\(name)(")
    }

    @Test("Both Source Explorer views consult the curated store and render its outcome")
    func bothPlatformsRenderCuratedOutcomes() throws {
        let ios = Self.code(try Self.source("FRUSExplorer/SourceExplorer/SourceExplorerView.swift"))
        let mac = Self.code(try Self.source("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"))

        #expect(ios.contains("CuratedLotResolutionsStore.shared"),
                "SourceExplorerView never reads the curated store — iOS/iPadOS users see no curated outcome")
        #expect(Self.callsFunction("curatedLotSection", in: ios),
                "SourceExplorerView never CALLS curatedLotSection — the declaration alone renders nothing")
        #expect(mac.contains("CuratedLotResolutionsStore.shared"),
                "MacSourceExplorerView never reads the curated store — Mac users see no curated outcome")
        #expect(Self.callsFunction("curatedLotBox", in: mac),
                "MacSourceExplorerView never CALLS curatedLotBox — the declaration alone renders nothing")
    }

    @Test("Both views let curation override the parser's record-group default")
    func bothPlatformsHonourTheCuratedRecordGroup() throws {
        let ios = Self.code(try Self.source("FRUSExplorer/SourceExplorer/SourceExplorerView.swift"))
        let mac = Self.code(try Self.source("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"))
        // Without this, a curated RG-43 collection is labelled "RG 59" from the parser's
        // conservative default — and searched under RG 59 in the fallback URL.
        #expect(ios.contains("curated?.recordGroup"),
                "SourceExplorerView shows the parser's record group for curated lots")
        #expect(mac.contains("CuratedLotResolutionsStore.shared?.recordGroup(forRawLot:"),
                "MacSourceExplorerView shows the parser's record group for curated lots")
    }

    @Test("No curated branch borrows the confident card's 'resolved from the bundled index' caption")
    func curatedBranchesAreNotCaptionedAsResolved() throws {
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let text = try Self.source(path)
            // The confident caption is keyed `source.explorer.lotFile.bundled.note`. It must
            // appear exactly once per file — in the bundled card — and never inside a curated one.
            let occurrences = text.components(separatedBy: "source.explorer.lotFile.bundled.note").count - 1
            #expect(occurrences == 1,
                    "\(path) uses the confident 'Resolved from the bundled index' caption \(occurrences) times; a curated outcome must never carry it")
        }
    }

    @Test("The shared confidence chip is used, not a third copy of the capsule")
    func confidenceChipIsShared() throws {
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let text = Self.code(try Self.source(path))
            #expect(text.contains("ConfidenceChip(confidence:"),
                    "\(path) does not use the shared ConfidenceChip")
            #expect(!text.contains("Color.orange.opacity(0.18)"),
                    "\(path) still inlines the confidence capsule — that duplication is what ConfidenceChip replaced")
        }
    }
}
