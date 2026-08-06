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

// MARK: - SourceOutlineExpansionTests

/// Pins the volume Sources outline opening **expanded**.
///
/// A bare `OutlineGroup` starts every disclosure collapsed and offers no way to open them all,
/// which put the individual lot files — the most actionable rows on this surface, and the ones
/// history.state.gov/historicaldocuments/<volume>/sources shows in full — three taps down under
/// "National Archives and Records Administration ▸ Record Group 59 ▸ Lot Files". Measured on the
/// owner's index: only **4,268 of 34,152** outline rows were reachable without a tap, while
/// **17,204** sit at depth ≥ 2, which is where every lot file lives.
///
/// Version history:
///   1.0 — Session 2026-08-05: default-expanded Sources outline
@Suite("Volume Sources outline — default expansion")
struct SourceOutlineExpansionTests {

    private func entry(_ text: String, depth: Int) -> VolumeSourceEntry {
        VolumeSourceEntry(kind: .item, depth: depth, isHeading: depth == 0, rawText: text)
    }

    /// The `frus1961-63v25` shape: a repository, a record group under it, a "Lot Files" group
    /// under that, and the lots under that. Four levels — the depth that made the lot files
    /// invisible.
    private func tree() -> [SourceTreeNode] {
        VolumeSourcesView.buildTree([
            entry("National Archives and Records Administration", depth: 0),
            entry("Record Group 59, Records of the Department of State", depth: 1),
            entry("Lot Files", depth: 2),
            entry("Conference Files: Lot 65 D 366", depth: 3),
            entry("Conference Files: Lot 65 D 533", depth: 3),
            entry("Washington National Records Center, Suitland, Maryland", depth: 0),
            entry("Record Group 306, Records of the U.S. Information Agency", depth: 1),
            entry("USIA Files: Lot 64 D 171", depth: 2),
        ])
    }

    @Test("Every branch at every depth is expandable, and leaves are not")
    func expandableIDsCoversEveryBranch() {
        let nodes = tree()
        let ids = VolumeSourcesView.expandableIDs(nodes)
        // NARA, RG 59, Lot Files, WNRC, RG 306 — five branches; the three lots are leaves.
        #expect(ids.count == 5, "expected 5 expandable branches, got \(ids.count)")
        // Deep branches must be included, or the lots stay hidden behind the last triangle.
        let nara = try? #require(nodes.first)
        let rg59 = nara?.children?.first
        let lotFiles = rg59?.children?.first
        #expect(lotFiles.map { ids.contains($0.id) } == true,
                "the deepest branch — the one directly above the lot files — must expand")
        #expect(lotFiles?.children?.allSatisfy { !ids.contains($0.id) } == true,
                "a lot row is a leaf and must not be listed as expandable")
    }

    @Test("An outline with no branches yields no expandable ids")
    func flatOutlineHasNoBranches() {
        let flat = VolumeSourcesView.buildTree([entry("A", depth: 0), entry("B", depth: 0)])
        #expect(VolumeSourcesView.expandableIDs(flat).isEmpty)
    }

    /// The seeding is one line inside an async view method, so a source audit is the honest
    /// guard: without it every branch is closed on load and the fix is inert.
    @Test("loadSources seeds the expansion set from the freshly built tree")
    func loadSourcesSeedsTheExpansionSet() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(
            path: "FRUSExplorer/Browser/VolumeSourcesView.swift"), encoding: .utf8)
        // Drop full-line comments and the declaration itself, so neither can satisfy this.
        let code = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.hasPrefix("//") && !t.hasPrefix("static func expandableIDs")
            }
            .joined(separator: "\n")
        #expect(code.contains("expandedNodes = Self.expandableIDs(collectionTree)"),
                "loadSources no longer seeds expandedNodes — the outline would open collapsed")
        #expect(!code.contains("OutlineGroup(collectionTree"),
                "the bare OutlineGroup is back; it cannot be opened by default")
    }
}
