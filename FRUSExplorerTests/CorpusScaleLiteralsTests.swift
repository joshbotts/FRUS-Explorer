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

// MARK: - CorpusScaleLiteralsTests

/// R-3 of the New-Volume-Release-Plan (§7.1, W-2): the nine user-visible strings that hard-coded
/// `552` now derive their numbers, and this suite keeps them derived.
///
/// **Why a scan and not only value tests.** Seven of the nine live in SwiftUI bodies no unit test
/// drives, so the guard that holds is a scan of each string's own `defaultValue` for the
/// corpus-scale literals that shipped in it — scoped to the string, not the file, so an unrelated
/// `552` elsewhere in a file neither hides nor triggers a failure. The two helpers that CAN be
/// driven are.
///
/// **The finding that justifies the whole row:** the collections card said the authority "reaches
/// 356" volumes and a test pinned that as measured; the shipped authority had named **365** since
/// its 2026-08-19 re-clustering. A literal pinned by a source scan is a number that goes stale
/// with nothing to notice.
///
/// Version history:
///   1.0 — R-3: initial implementation
@Suite("R-3 — corpus-scale literals stay derived")
struct CorpusScaleLiteralsTests {

    // MARK: - The helpers

    /// The one token, the one substitution, with the reader's grouping separators.
    @Test("The Research Guide token becomes the count, grouped, and nothing else changes")
    func educationTokenSubstitution() {
        let prose = "All {{volumes}} volumes are now available as structured digital texts."
        #expect(IndexingEducationView.substituted(prose, volumeCount: 553)
                == "All 553 volumes are now available as structured digital texts.")
        // A four-digit future prints with its separator — the same `formatted()` the appendix uses.
        #expect(IndexingEducationView.substituted(prose, volumeCount: 1_000).contains("1,000"))
        // A paragraph without the token is returned byte-identical.
        let plain = "The TEI format preserves document structure."
        #expect(IndexingEducationView.substituted(plain, volumeCount: 553) == plain)
    }

    /// The `+` is a floor, kept on purpose: the live manifest can list volumes the bundle does not.
    @Test("The onboarding caption prints the count and keeps its floor")
    @MainActor
    func onboardingCaption() {
        let caption = OnboardingView.captionCorpus(volumeCount: 553)
        #expect(caption.hasPrefix("553+"), "\(caption)")
        #expect(!caption.contains("552"))
    }

    // MARK: - The scan

    /// Every one of the nine strings, by its own key, must be free of the literals that shipped
    /// in it. The `seen == 9` guard is what keeps this from passing on a renamed key.
    @Test("No corpus-scale literal has returned to any of the nine strings")
    func noLiteralInTheNineStrings() throws {
        let sites: [(file: String, key: String)] = [
            ("Onboarding/OnboardingView.swift", "onboarding.scope.caption.corpus.v2 %lld"),
            ("Browser/SubjectIndexView.swift", "subjects.index.coverage.v2 %lld %lld"),
            ("Theme/FRUSTheme.swift", "archival.info.flows.detail.v2"),
            ("SeriesAnalytics/AdministrationProfilesDashboard.swift", "series.admin.caveats.body.v2 %lld"),
            ("SeriesAnalytics/SeriesProductionDashboard.swift", "series.chart.cumulative.caption.v2 %lld"),
            ("SeriesAnalytics/SeriesProductionDashboard.swift", "series.caveats.body.v2 %lld"),
            ("SeriesAnalytics/SourceProvenanceDashboard.swift", "series.provenance.caveats.body.v2 %lld %lld"),
            ("SeriesAnalytics/SeriesGeographyDashboard.swift", "series.geography.caveats.body.v2 %lld %lld"),
            ("SeriesAnalytics/TopCollectionsCard.swift", "series.provenance.topCollections.method.v3 %lld %lld"),
        ]
        // The literals that shipped: the catalog count and the four ratios measured against it.
        let literals = ["552", "522", "551", "254", "356"]
        var seen = 0
        for site in sites {
            let source = try Self.source(site.file)
            // The string's OWN defaultValue: from its key to the closing `")` of that call.
            guard let keyRange = source.range(of: "\"\(site.key)\"") else {
                Issue.record("key \(site.key) is gone from \(site.file)"); continue
            }
            guard let start = source.range(of: "defaultValue:", range: keyRange.upperBound..<source.endIndex),
                  let end = source.range(of: "\")", range: start.upperBound..<source.endIndex) else {
                Issue.record("no defaultValue after \(site.key)"); continue
            }
            let payload = String(source[start.upperBound..<end.lowerBound])
            seen += 1
            for literal in literals where payload.contains(literal) {
                Issue.record("\(site.key) carries the literal \(literal) again: …\(payload.suffix(80))")
            }
        }
        #expect(seen == sites.count, "only \(seen) of \(sites.count) strings were found — a renamed key hides a regression")
    }

    /// The Research Guide's prose table carries the token, not the number.
    @Test("The Research Guide prose carries the token")
    func educationProseCarriesTheToken() throws {
        let source = try Self.source("Onboarding/IndexingEducationView.swift")
        #expect(source.contains("All {{volumes}} volumes are now available"))
        #expect(!source.contains("All 552 volumes"))
    }

    // MARK: - Helpers

    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer").appendingPathComponent(relative)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
