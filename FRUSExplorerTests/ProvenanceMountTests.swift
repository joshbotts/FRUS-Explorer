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

    // MARK: - The capture moments (PV-4)

    /// The sheet says what is being captured, in both platform bodies.
    ///
    /// `CollectionPickerSheet` is one struct with two bodies and its shared seams are `String`s
    /// (`pickerTitle` is consumed as a `Text` on macOS and a `.navigationTitle` on iOS), so nothing
    /// carries a view across the platform split. A chip added to one body travels to neither.
    @Test("Both bodies of the collection picker badge what is being captured")
    func bothPickerBodiesBadgeTheCapture() throws {
        let file = try source("FRUSExplorer/Collections/CollectionPickerSheet.swift")
        let mac = try body(of: "private var macBody: some View {", in: file)
        let ios = try body(of: "private var iOSBody: some View {", in: file)
        for (name, block) in [("macBody", mac), ("iOSBody", ios)] {
            #expect(block.contains("ProvenanceChip(source: .frusText)"),
                    Comment(rawValue: "CollectionPickerSheet.\(name) does not say what it captures"))
        }
    }

    /// **The one capture whose membership is the model's, and it must not say `.frusText`.**
    ///
    /// The documents in a lassoed set are FRUS's; what is not FRUS's is that these particular ones
    /// are together. A reader who writes "these documents cluster" is reporting the app's reading of
    /// the language, and the saved corpus records only `sourceDescription: "Semantic map
    /// selection"` — which names the mechanism without saying it is a model.
    @Test("The map lasso badges its capture as the model's, not the volumes'")
    func lassoCaptureBadgesTheModel() throws {
        let file = try source("FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift")
        #expect(file.contains("ProvenanceChip(source: .appModel)"),
                "the lasso capture does not say the set is the model's grouping")
        #expect(!file.contains("ProvenanceChip(source: .frusText)"),
                "a lassoed set's membership is not the volumes' claim")
    }

    /// **A copied citation carries no provenance sentence, and that is a decision.**
    ///
    /// PV-1 puts a sources block in exported *artifacts* because a chip cannot travel into a PDF.
    /// A citation is different in kind: it is pasted straight into somebody's footnote, so a
    /// sentence appended to it would be pasted too. The app already understands the distinction —
    /// `naraExportText` embeds a caveat in a durable NARA record copy precisely because "the chip in
    /// the UI does not travel into a research note" — and the line between the two is what the
    /// payload becomes, not whether it leaves the app.
    ///
    /// This pins the refusal so a later, well-meant change cannot quietly pollute a footnote.
    @Test("A copied or shared citation carries no provenance sentence")
    func citationPayloadsStayClean() throws {
        let file = try code("FRUSExplorer/DocumentView/DocumentViewModel.swift")
        var checked = 0
        for property in ["var plainTextFormattedCitation", "var shareableCitationMessage",
                         "var bibtexCitation"] {
            guard let range = file.range(of: property) else {
                Issue.record(Comment(rawValue: "\(property) is gone — the citation payloads moved"))
                continue
            }
            let rest = String(file[range.lowerBound...].prefix(900))
            #expect(!rest.contains("ProvenanceStatement"),
                    Comment(rawValue: "\(property) injects a provenance sentence into a payload a reader pastes into a footnote"))
            #expect(!rest.contains("methodSentence"),
                    Comment(rawValue: "\(property) injects a method sentence into a citation"))
            checked += 1
        }
        #expect(checked == 3, "the citation sweep ran over \(checked) payloads")
    }

    // MARK: - Person rollups (PV-5)

    /// **The wave's clearest per-claim case**: two secondary-styled lines about one person, one
    /// above the other, from different sources.
    ///
    /// `indexEntry.entry.description` is the volumes' own words; `authorityEntry?.r` is the Office
    /// of the Historian's register. Nothing distinguished them, so a reader quoting "FRUS describes
    /// him as…" could not tell which line they had. Unlike PV-3's Source Explorer — where each
    /// section turned out to be uniformly one source — this really is the §1c shape, and the badge
    /// has to attach per claim.
    @Test("The person card badges the volumes' description and the register's role differently")
    func personIdentityClaimsAreBadgedSeparately() throws {
        let file = try source("FRUSExplorer/Browser/PersonIndexView.swift")
        let detail = try body(of: "private var detailList: some View {", in: file)
        #expect(detail.contains("ProvenanceChip(source: .frusText)"),
                "the volumes' own description must say it is the volumes'")
        #expect(detail.contains("ProvenanceChip(source: .ohPeopleRegister)"),
                "the register's role must not read as the volumes'")
    }

    /// The career footer is the second grain the chip had to compose in — a `Section` footer
    /// beside existing prose, against the inline `VStack` above.
    ///
    /// The footer already named POCOM. What it did not say is that *attaching this career to this
    /// person* is a join the app made, which is what a reader needs before concluding from an empty
    /// Career section that somebody held no post.
    @Test("The career section badges the join, not only the register")
    func careerFooterBadgesTheJoin() throws {
        let file = try source("FRUSExplorer/Browser/PersonIndexView.swift")
        let career = try body(of: "private func careerSection(_ career: POCOMCareer) -> some View {",
                              in: file)
        #expect(career.contains("ProvenanceChip(source: .ohPeopleRegister)"),
                "the career section does not say the attachment is a join")
        #expect(career.contains("people.detail.career.source"),
                "the chip supplements the POCOM sentence — it does not replace it")
    }

    /// **The People LIST is deliberately unbadged, and the reason is measured.**
    ///
    /// Three things rule it out and any one would be enough. Its subtitle is uniformly Tier 1 —
    /// `FRUSASTNode.roleEraSubtitle` is `role ?? description` plus the era, all read from the TEI,
    /// so a chip there would never vary (§6's refusal of search results). The row already carries a
    /// name, a subtitle, a duplicate hint, a count capsule and a chevron. And it is a `Button` with
    /// `.accessibilityElement(children: .combine)` **and its own** `.accessibilityLabel`, which is
    /// exactly the container that swallows a chip's own announcement — so a chip there would be
    /// silent to VoiceOver unless `accessibilityLabelText` folded the sentence in, which is why
    /// `ProvenanceChip.accessibilityLabel(for:)` is callable on its own.
    ///
    /// This test pins the row's shape, so the day one of those three stops being true, whoever
    /// changes it is told the exclusion rested on it.
    @Test("The People list row stays unbadged, and the three reasons still hold")
    func peopleListRowRemainsUnbadged() throws {
        let file = try source("FRUSExplorer/Browser/PersonIndexView.swift")
        let row = try body(of: "private struct PersonIndexRow: View {", in: file)
        #expect(!row.contains("ProvenanceChip("),
                "a chip in a dense list row would be invariant, crowded, and unannounced")
        #expect(row.contains(".accessibilityElement(children: .combine)")
                && row.contains(".accessibilityLabel(accessibilityLabelText)"),
                "the container-label hazard that rules a chip out here is gone — revisit the exclusion")

        // The subtitle's Tier-1 uniformity is the other leg, and it lives in the TEI type.
        let ast = try source("FRUSExplorer/TEI/FRUSASTNode.swift")
        let subtitle = try body(of: "var roleEraSubtitle: String? {", in: ast)
        #expect(!subtitle.contains("authority") && !subtitle.contains("pocom"),
                "the row subtitle now mixes sources, so the invariance argument no longer holds")
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
