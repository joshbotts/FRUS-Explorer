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

// MARK: - ProvenanceStatementTests

/// The sentences that reach a footnote (PV-1).
///
/// This is the only part of wave PV a reader can cite from: a chip cannot travel into a PDF
/// somebody else opens. So the suite pins what the block says, that it says only what the export
/// used, and that it reaches every renderer rather than one.
///
/// Version history:
///   1.0 — PV-1: initial implementation
@Suite("Provenance statements in exports")
struct ProvenanceStatementTests {

    // MARK: - The statement

    @Test("Nothing in, nothing out")
    func emptySourcesProduceNoBlock() {
        #expect(ProvenanceStatement.lines(for: []).isEmpty)
        #expect(ProvenanceStatement.block(for: []).isEmpty)
    }

    /// Ordered from the volumes outward, so two exports listing the same sources read alike.
    @Test("Sources are ordered by tier, then by label")
    func orderedFromTheVolumesOutward() {
        let lines = ProvenanceStatement.lines(for: [.appModel, .naraCatalog, .frusText])
        #expect(lines.count == 3)
        #expect(lines[0] == ProvenanceSource.frusText.methodSentence)
        #expect(lines[1] == ProvenanceSource.naraCatalog.methodSentence)
        #expect(lines[2] == ProvenanceSource.appModel.methodSentence)
    }

    /// A joined sentence must name what it joined to — otherwise it tells a reader they may not
    /// say "FRUS shows" without telling them what they may say instead.
    @Test("A joined source names its partner in the sentence")
    func joinedSourceNamesThePartner() {
        let line = ProvenanceStatement.lines(for: [.naraCatalog])[0]
        #expect(line.contains(ProvenanceSource.naraCatalog.partnerName))
        #expect(line.contains("National Archives"))
    }

    /// Q-3: the owner's own archival judgement is disclosed where it applies.
    @Test("Curated resolutions are disclosed, and only when present")
    func curatedDisclosureIsConditional() {
        let without = ProvenanceStatement.lines(for: [.naraCatalog])
        let with = ProvenanceStatement.lines(for: [.naraCatalog], includesCuratedResolutions: true)
        #expect(!without.contains(ProvenanceSource.curatedDisclosure))
        #expect(with.contains(ProvenanceSource.curatedDisclosure))
        #expect(with.count == without.count + 1)
    }

    // MARK: - The derivation

    private func doc(_ id: String, depth: CollectionBodyDepth = .full) -> CollectionExportItem {
        .document(CollectionExportDocument(
            documentId: id, volumeId: "v1", sortOrder: 0, bodyDepth: depth,
            title: "T", titleOverride: nil, date: nil, bodyText: "b", noteTexts: []))
    }

    /// Derived from the items, never declared — an export cannot claim a source it did not use.
    @Test("A plain document collection claims the volumes and nothing else")
    func plainCollectionIsFRUSOnly() {
        #expect([doc("d1"), doc("d2")].provenanceSources == [.frusText])
    }

    /// The one case where the exported prose is not the record's.
    @Test("A summary-only body adds the model")
    func summaryOnlyAddsTheModel() {
        #expect([doc("d1", depth: .summaryOnly)].provenanceSources == [.frusText, .appModel])
    }

    /// Headings carry no content and must not manufacture a claim.
    @Test("Headings alone produce no sources, and so no block")
    func headingsClaimNothing() {
        let items: [CollectionExportItem] = [.heading("A", level: 1)]
        #expect(items.provenanceSources.isEmpty)
        #expect(CollectionColophon.sourceLines(for: items).isEmpty)
    }

    // MARK: - Reach

    /// **The W-13 failure this must not repeat**: a fact added to one renderer ships in one format
    /// and vanishes from the other two. The sources block is built once, in the shared colophon,
    /// and all three rich renderers call it.
    @Test("All three rich renderers emit the shared sources block")
    func everyRendererEmitsTheBlock() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        for file in ["FRUSExplorer/Collections/PDFCollectionExporter.swift",
                     "FRUSExplorer/Collections/DocxCollectionExporter.swift",
                     "FRUSExplorer/Collections/CollectionItemHTMLRenderer.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            #expect(source.contains("CollectionColophon.sourceLines(for: items)"),
                    Comment(rawValue: "\(file) must emit the shared sources block, not its own"))
        }
    }

    /// A trimmed plate is the artifact most likely to be shared detached from its CSV, so the
    /// designation may drop caveats but never the sources.
    @Test("A plate designation cannot drop the sources block")
    func plateTrimKeepsTheSources() {
        var p = AnalyticsProvenance(figureTitle: "F", axisLabel: "A", indexedVolumeCount: 552)
        p.sources = [.frusText, .naraCatalog]
        let sourceLines = ProvenanceStatement.lines(for: p.sources)
        #expect(sourceLines.allSatisfy { p.allCaveats.contains($0) })
        // Designate only the corpus caveat — the tightest possible trim.
        p.plateCaveats = [p.corpusCaveat]
        #expect(sourceLines.allSatisfy { p.plateCaveatLines.contains($0) },
                "a figure whose sources are unstated is what this wave exists to prevent")
        #expect(p.plateCaveatLines.contains(p.corpusCaveat))
    }
}
