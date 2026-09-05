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

// MARK: - ProvenanceMountTests

/// Where wave PV's chip is actually mounted, and that both of its answers can occur (PV-3).
///
/// **The split this row renders is real, and the first test proves it rather than assuming it.**
/// The plan's §1c measured 3,411 of 4,429 authority collections (77%) as clustered from FRUS front
/// matter alone against 1,018 (23%) carrying a NARA identifier. If that had drifted to 100/0 in
/// either direction, one of the two chips would be dead code shipping a distinction no reader ever
/// sees — and nothing else in the suite would notice.
///
/// The remaining tests are narrow source scans, scoped to a single function each. They exist for
/// the failure this repo has a record of: `SourceExplorerView` and `MacSourceExplorerView` are
/// hand-maintained twins that drift on exactly this kind of edit, and a chip added to one is a
/// vocabulary that disagrees with itself across platforms.
///
/// Version history:
///   1.0 — PV-3: initial implementation
@Suite("Provenance chip mounts")
struct ProvenanceMountTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// The file with its `//` comment lines removed.
    ///
    /// **Written because the first version of `mountsNeverLookUpByArtifact` failed against its own
    /// documentation.** The chip mounts carry a comment saying the source is "never fetched from
    /// `BundledArtifactProvenance.source(ofArtifact:)`", and a plain scan matched that sentence —
    /// a test asserting something about prose rather than about code. Anything that forbids an API
    /// must look at what the file *calls*.
    private func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// The body of one function, so a scan cannot match an identical line elsewhere in the file.
    private func body(of declaration: String, in source: String) throws -> String {
        let start = try #require(source.range(of: declaration),
                                 "\(declaration) is gone — the mount moved or was renamed")
        let rest = source[start.upperBound...]
        // The next declaration at the same indentation ends this one.
        if let end = rest.range(of: "\n    // MARK:") ?? rest.range(of: "\n    private ") {
            return String(rest[..<end.lowerBound])
        }
        return String(rest)
    }

    // MARK: - Both answers occur

    /// Neither chip is dead code: the shipped authority holds records of both kinds.
    @Test("The 77/23 split is real, so both chips can appear")
    func bothHalvesOfTheSplitExist() throws {
        let url = try #require(
            Bundle(for: ProvenanceMountBundleToken.self)
                .url(forResource: "collection-authority", withExtension: "json")
                ?? Bundle.main.url(forResource: "collection-authority", withExtension: "json"),
            "collection-authority.json must be enrolled as a bundle resource")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let root = try #require(object as? [String: Any])
        let collections = try #require(root["collections"] as? [[String: Any]])
        #expect(!collections.isEmpty, "the guard is vacuous if the authority is empty")

        var withNAID = 0, withoutNAID = 0
        for record in collections {
            let naId = record["naId"] as? String
            if let naId, !naId.isEmpty { withNAID += 1 } else { withoutNAID += 1 }
        }
        #expect(withNAID + withoutNAID == collections.count)
        // Both chips must be reachable. The exact ratio is free to move — what may not is either
        // half emptying, which would make one of PV-3's two badges unreachable.
        #expect(withNAID > 0, "no collection carries a NARA identifier, so the Tier-2 chip is dead")
        #expect(withoutNAID > 0, "every collection carries one, so the Tier-1 half is dead")

        // **Carrying a NAID is necessary but not sufficient**, and the difference is a real guard
        // rather than a technicality: `CollectionDetailView.showsCatalogLink` withholds the whole
        // catalog section when the NAID traces to a mis-resolution the #335 audit flagged, so a
        // record can have one and still never show the Tier-2 chip. Check the condition the view
        // actually uses.
        if let central = CentralFilesIndexStore.shared {
            let trusted = collections.filter { record in
                guard let naId = record["naId"] as? String, !naId.isEmpty else { return false }
                guard record["catalogURL"] as? String != nil else { return false }
                return !central.isUntrustworthyNAID(naId)
            }
            #expect(!trusted.isEmpty,
                    "every NAID is either untrusted or has no URL, so the Tier-2 chip never renders")
        }
    }

    // MARK: - The twins agree

    /// The chip is mounted on the same claim in both Source Explorers.
    @Test("Both Source Explorer twins badge the collection card")
    func bothTwinsBadgeTheCard() throws {
        let ios = try body(of: "private var archivalCollectionSection: some View {",
                           in: try source("FRUSExplorer/SourceExplorer/SourceExplorerView.swift"))
        let mac = try body(of: "private var collectionBox: some View {",
                           in: try source("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"))
        for (name, block) in [("iOS archivalCollectionSection", ios), ("macOS collectionBox", mac)] {
            #expect(block.contains("ProvenanceChip(source: .frusText)"),
                    Comment(rawValue: "\(name) does not badge the collection card as FRUS-derived"))
        }
    }

    // MARK: - The card's two halves get different answers

    /// The whole point of §1c: identity and catalogue identifier are not the same claim.
    @Test("The detail view badges its identity half and its catalog half differently")
    func detailViewSeparatesTheHalves() throws {
        let file = try source("FRUSExplorer/SourceExplorer/CollectionDetailView.swift")
        let overview = try body(of: "private var overviewSection: some View {", in: file)
        let catalog = try body(of: "private var catalogSection: some View {", in: file)

        #expect(overview.contains("ProvenanceChip(source: .frusText)"),
                "the identity half is clustered from FRUS front matter and must say so")
        #expect(!overview.contains("ProvenanceChip(source: .naraCatalog)"),
                "the identity half does not read a NARA value")
        #expect(catalog.contains("ProvenanceChip(source: .naraCatalog)"),
                "the NAID and catalogue link are NARA's, not FRUS's")
        #expect(!catalog.contains("ProvenanceChip(source: .frusText)"),
                "captioning a NAID as FRUS-derived is the §1a error the wave exists to avoid")
    }

    // MARK: - The prohibition

    /// **The mount names the source; it never looks one up by artifact filename.**
    ///
    /// `BundledArtifactProvenance` holds one entry per file and answers `.naraCatalog` for
    /// `collection-authority.json` — for *both* halves of a record. Routing a chip through it would
    /// caption the collection's FRUS-clustered identity as a catalogue value.
    @Test("No mount derives its source from the artifact table")
    func mountsNeverLookUpByArtifact() throws {
        var scanned = 0
        for path in ["FRUSExplorer/SourceExplorer/CollectionDetailView.swift",
                     "FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let file = try code(path)
            #expect(!file.contains("source(ofArtifact:"),
                    Comment(rawValue: "\(path) resolves a chip's source by filename"))
            scanned += 1
        }
        #expect(scanned == 3, "the mount sweep ran over \(scanned) files")
    }
}

/// Bundle anchor for the resource lookup above.
private final class ProvenanceMountBundleToken {}
