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

// MARK: - VolumeUpdateReviewTests

/// The per-volume arithmetic behind the storage hubs' post-update summary (design §5.5), and the
/// mount-parity scan that keeps the section shared between the two hand-maintained hubs.
///
/// Version history:
///   1.0 — R-5 P2: initial implementation
@Suite("Volume update review — the hub's per-volume change set")
struct VolumeUpdateReviewTests {

    private func row(_ volumeId: String, _ documentId: String, kind: String?,
                     stamped: Bool = true, reviewed: Bool = false) -> IndexingPipeline.DocumentRevision {
        IndexingPipeline.DocumentRevision(
            volumeId: volumeId, documentId: documentId, contentHash: "c", bodyHash: "b",
            changedAt: stamped ? "2026-09-03T12:00:00Z" : nil, changeKind: kind,
            reviewedAt: reviewed ? "2026-09-03T13:00:00Z" : nil)
    }

    @Test("Counts split annotated documents by kind, against the volume's whole change set")
    func countsPerVolume() {
        let revisions = [
            row("v1", "d1", kind: "body"),
            row("v1", "d2", kind: "apparatus"),
            row("v1", "d3", kind: "vanished"),
            row("v1", "d4", kind: "body"),          // not annotated: counts in changed only
            row("v1", "d5", kind: "apparatus"),     // not annotated
        ]
        let summaries = VolumeUpdateReview.summaries(
            revisions: revisions, annotatedKeys: ["v1/d1", "v1/d2", "v1/d3", "v9/d1"])
        #expect(summaries == [
            .init(volumeId: "v1", changedDocuments: 5, annotatedDocuments: 3,
                  body: 1, apparatus: 1, vanished: 1)
        ])
        #expect(VolumeUpdateReview.totals(of: summaries)
                == .init(changedDocuments: 5, volumes: 1, annotatedDocuments: 3))
    }

    @Test("Unstamped and reviewed rows are not changes")
    func unstampedAndReviewedAreSilent() {
        let revisions = [
            row("v1", "d1", kind: nil, stamped: false),
            row("v1", "d2", kind: "body", reviewed: true),
            row("v2", "d1", kind: "body"),
        ]
        let summaries = VolumeUpdateReview.summaries(revisions: revisions,
                                                     annotatedKeys: ["v1/d1", "v1/d2", "v2/d1"])
        #expect(summaries.map(\.volumeId) == ["v2"])
        #expect(summaries[0].annotatedDocuments == 1)
    }

    /// The fixture is built so that ONLY the full three-key order yields it: `vA` has the most
    /// annotated documents but the fewest changed; `vB` and `vC` tie on annotated and differ on
    /// changed; `vC` and `vD` tie on both and differ only by id — and every id-only sort would
    /// put `vA` first by accident, so the ids are chosen to sort the other way.
    @Test("Ordering is annotated desc, then changed desc, then volume id — a total order")
    func totalOrder() {
        let revisions = [
            row("vD", "d1", kind: "body"), row("vD", "d2", kind: "body"),
            row("vC", "d1", kind: "body"), row("vC", "d2", kind: "body"),
            row("vB", "d1", kind: "body"), row("vB", "d2", kind: "body"), row("vB", "d3", kind: "body"),
            row("vA", "d1", kind: "body"),
        ]
        let annotated: Set<String> = ["vA/d1", "vB/d1", "vC/d1", "vD/d1"]
        // vA: annotated 1, changed 1. vB: 1, 3. vC: 1, 2. vD: 1, 2.
        // Make vA win on annotated by giving it a second annotated change.
        let more = revisions + [row("vA", "d2", kind: "apparatus")]
        let summaries = VolumeUpdateReview.summaries(revisions: more,
                                                     annotatedKeys: annotated.union(["vA/d2"]))
        #expect(summaries.map(\.volumeId) == ["vA", "vB", "vC", "vD"])
        #expect(summaries.map(\.annotatedDocuments) == [2, 1, 1, 1])
        #expect(summaries.map(\.changedDocuments) == [2, 3, 2, 2])
    }

    @Test("A volume whose changes touch nothing annotated is listed last, not dropped")
    func unannotatedVolumeIsListedLast() {
        let summaries = VolumeUpdateReview.summaries(
            revisions: [row("v1", "d1", kind: "body"), row("v2", "d1", kind: "body")],
            annotatedKeys: ["v2/d1"])
        #expect(summaries.map(\.volumeId) == ["v2", "v1"])
        #expect(summaries[1].annotatedDocuments == 0)
        #expect(summaries[1].changedDocuments == 1)
    }

    @Test("Nothing in, nothing out")
    func empty() {
        #expect(VolumeUpdateReview.summaries(revisions: [], annotatedKeys: ["v1/d1"]).isEmpty)
        #expect(VolumeUpdateReview.totals(of: []) == .init(changedDocuments: 0, volumes: 0, annotatedDocuments: 0))
    }

    // MARK: - The section's sentences (statics on a View, hence main-actor)

    @Test("The volume line omits zero parts rather than printing them")
    @MainActor
    func volumeDetailOmitsZeroParts() {
        let onlyApparatus = VolumeUpdateReview.VolumeSummary(
            volumeId: "v1", changedDocuments: 5, annotatedDocuments: 2, body: 0, apparatus: 2, vanished: 0)
        #expect(VolumeUpdateReviewSection.volumeDetail(onlyApparatus)
                == "2 of 5 changed documents carry your research: 2 with changed footnotes, source note, or heading.")
        let allThree = VolumeUpdateReview.VolumeSummary(
            volumeId: "v1", changedDocuments: 4, annotatedDocuments: 3, body: 1, apparatus: 1, vanished: 1)
        #expect(VolumeUpdateReviewSection.volumeDetail(allThree)
                == "3 of 4 changed documents carry your research: 1 with changed text, 1 with changed footnotes, source note, or heading, 1 no longer in the volume.")
        let unknownKind = VolumeUpdateReview.VolumeSummary(
            volumeId: "v1", changedDocuments: 2, annotatedDocuments: 1, body: 0, apparatus: 0, vanished: 0)
        #expect(VolumeUpdateReviewSection.volumeDetail(unknownKind)
                == "1 of 2 changed documents carry your research.")
    }

    @Test("The summary sentence carries the three totals in order")
    @MainActor
    func summaryDetailCarriesTotals() {
        let t = VolumeUpdateReview.Totals(changedDocuments: 12, volumes: 3, annotatedDocuments: 4)
        #expect(VolumeUpdateReviewSection.summaryDetail(t)
                == "12 documents changed in 3 updated volumes. 4 of them carry your research.")
    }

    // MARK: - Mount parity (a source scan, and it says so)

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("FRUSExplorer/\(relative)"), encoding: .utf8)
    }

    @Test("Both hubs mount VolumeUpdateReviewSection, and neither re-declares its copy")
    func bothHubsMountTheSharedSection() throws {
        for hub in ["Settings/VolumesStorageHubView.swift", "Settings/MacVolumesStorageHub.swift"] {
            let s = try Self.source(hub)
            #expect(s.contains("VolumeUpdateReviewSection()"),
                    "\(hub) must mount the shared section — a per-hub copy is the drift #900 exists to prevent")
            #expect(!s.contains("settings.updateReview."), "\(hub) must not carry the section's strings")
        }
    }

    /// The Research filter's three arms — the sidebar row, the document list, the empty state —
    /// each switch on `.updated`. A scan, not a behaviour test: the aggregation and the change line
    /// are pinned above through the real functions; this only says the case reaches every arm.
    @Test("ResearchView wires the .updated case through its sidebar, list, and empty state")
    func researchViewWiresUpdated() throws {
        let s = try Self.source("Research/ResearchView.swift")
        #expect(s.contains("sidebarRow(.updated)"), "the sidebar row")
        #expect(s.contains("\"research.sidebar.updated\""), "the sidebar row's label")
        #expect(s.contains("\"research.list.updated\""), "the list title")
        #expect(s.contains("\"research.empty.noDocs.updated\""), "the empty state")
        #expect(s.contains("unreviewedDocumentRevisions()"), "the filter reads the pipeline's unreviewed rows")
        #expect(s.contains("allAnnotatedKeys.intersection(unreviewedRevisions.keys)"), "the filter is the intersection")
    }

    /// R-5 P3's mounts: the review sheet from both twins' banners and from the Research row, the
    /// hub's per-volume stamp, and the widened repaint signature. A scan, and it says so.
    @Test("P3 mounts: both twins open the review sheet, Research offers it, the hub stamps, the web view compares signatures")
    func p3Mounts() throws {
        for twin in ["DocumentView/DocumentView.swift", "App/MacDocumentView.swift"] {
            let s = try Self.source(twin)
            #expect(s.contains("DocumentChangeReviewSheet(volumeId: entry.volumeId"), "\(twin) must present the shared sheet")
            #expect(s.contains("onReview:"), "\(twin) must give the banner its Review control")
            #expect(s.contains("appState.revisionReviewToken"), "\(twin) must reload on a review write")
        }
        let research = try Self.source("Research/ResearchView.swift")
        #expect(research.contains("\"research.action.reviewChanges\""))
        #expect(research.contains("DocumentChangeReviewSheet(volumeId: entry.volumeId"))
        #expect(research.contains("appState.revisionReviewToken"))
        let hub = try Self.source("Settings/VolumeUpdateReviewSection.swift")
        #expect(hub.contains("markVolumeRevisionsReviewed(volumeId:"))
        #expect(hub.contains(".confirmationDialog("), "the volume-grain stamp must confirm first")
        let web = try Self.source("TEI/FRUSDocumentWebView.swift")
        #expect(web.contains("lastHighlightSignature") && !web.contains("lastHighlightIds"))
    }

    @Test("Both document-view twins mount DocumentChangeBanner and neither keeps a private banner")
    func bothTwinsMountTheSharedBanner() throws {
        for twin in ["DocumentView/DocumentView.swift", "App/MacDocumentView.swift"] {
            let s = try Self.source(twin)
            #expect(s.contains("DocumentChangeBanner(revision: revision,"), "\(twin) must mount the shared banner")
            #expect(!s.contains("staleHighlightBanner"), "\(twin) must not keep its pre-P2 private banner")
            #expect(!s.contains("highlight.stale.warning"), "\(twin) must not re-declare the banner's copy")
        }
    }
}
