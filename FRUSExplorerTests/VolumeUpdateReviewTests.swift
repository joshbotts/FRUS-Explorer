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

    /// P3b-1's wiring, as a scan: the Erase-only clear, the vanished-row routing, the two FTS pushes
    /// through the selection, and the export sheet's revision lookup.
    @Test("P3b-1 wiring: Erase-only clear, vanished rows route to the sheet, both pushes select, export consults revisions")
    func p3b1Wiring() throws {
        // The Erase-only clear: inside performReset's body, on a live line, AFTER resetLocalData.
        let settings = try Self.source("Settings/SettingsView.swift")
        let bodyStart = try #require(settings.range(of: "private func performReset()")).upperBound
        let bodyEnd = settings.range(of: "\n    }\n", range: bodyStart..<settings.endIndex)?.upperBound ?? settings.endIndex
        let liveLines = settings[bodyStart..<bodyEnd].split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        let resetLine = try #require(liveLines.firstIndex { $0.contains("ResetService.resetLocalData(") })
        let clearLine = try #require(liveLines.firstIndex { $0.contains("clearDocumentRevisions()") })
        #expect(clearLine > resetLine, "the clear must follow the index wipe")
        let reset = try Self.source("Settings/ResetService.swift")
        #expect(!reset.contains("clearDocumentRevisions"), "Reset This Device must keep the baselines")
        let research = try Self.source("Research/ResearchView.swift")
        #expect(research.contains("case .reviewSheet:\n            reviewEntry = entry\n            return"))
        #expect(research.contains("vanishedDocumentKeys()"))
        let app = try Self.source("App/FRUSExplorerApp.swift")
        #expect(app.components(separatedBy: "GeneratedSummary.newestNonDraftPerDocument(").count - 1 == 2)
        #expect(app.components(separatedBy: "GeneratedSummary.draftOnlyDocuments(").count - 1 == 2)
        #expect(app.contains("_ = appState.indexedVolumeIds.remove(volumeId)\n                        // R-5 P3b-1"), "removal must signal the readers")
        let export = try Self.source("Collections/CollectionExportSheet.swift")
        #expect(export.contains("ExcerptVerifier.upgradingVanished(outcomes, changeKinds: changeKinds)"))
    }

    /// R-5 P3b-4. Every claim here is about a CALL the sheet makes, not about a string in the
    /// file: the pure rules are pinned by `ExcerptReviewTests`, and a sheet that computed the right
    /// answer and never called them would pass every one of those tests.
    ///
    /// The `upgradingVanished` line is the one that matters most. Without it a quotation on a
    /// document an update removed reads "this volume is not on this device" — the exact Q-7 (g)
    /// misreport P3b-1 fixed on the export path, and this sheet is the only route a vanished
    /// document has.
    @Test("P3b-4 wiring: the sheet checks quotations through the shipped rules, and the parse gate admits them")
    func p3b4Wiring() throws {
        let sheet = try Self.source("DocumentView/DocumentChangeReviewSheet.swift")
        // The verifier, then the vanished upgrade, then the sentences — through the shipped types.
        #expect(sheet.contains("ExcerptVerifier.verify(pairs.map(\\.1), bodyTexts: bodies)"),
                "the sheet must run the export check, not a private comparison")
        // The ARGUMENT, not just the call: `upgradingVanished(outcomes, changeKinds: [:])` compiles,
        // reads as wired, and re-opens the exact Q-7 (g) misreport. The sibling pin on the export
        // sheet at the top of this file has always named its arguments for the same reason.
        #expect(sheet.contains("""
        let upgraded = ExcerptVerifier.upgradingVanished(
            outcomes, changeKinds: ["\\(volumeId)/\\(documentId)": revision?.changeKind ?? ""])
"""),
                "the vanished upgrade must be fed this document's own recorded change kind")
        // ONE call, not two: composing the finding and the capture line in the view is what
        // produced a vanished row saying "nothing to check against" above "captured from an
        // earlier version". `ExcerptReview.lines` owns the pairing and is tested on it.
        #expect(sheet.contains("ExcerptReview.lines(outcome: $0,"),
                "the row must compose through the tested entry point")
        #expect(sheet.contains("storedVersion: entry.excerptRenderingVersion,"),
                "design Q-7 (f): the stored version must be READ, which nothing did before P3b-4")
        #expect(!sheet.contains("ExcerptReview.captureLine("),
                "the view must not pair the two sentences itself")
        #expect(sheet.contains("ExcerptReview.isWarning(outcome)"),
                "only a genuine miss may colour as a warning")
        // The section is mounted, and the task runs the check.
        #expect(sheet.contains("if !excerpts.isEmpty { excerptsSection }"))
        #expect(sheet.contains("await verifyExcerpts()"))
        // The parse gate: without excerpts in it, `searchedVersion` is never computed for a
        // document carrying only quotations, so on the Research route — where `currentVersion` is
        // nil — the capture would be judged against the revision row's `bodyHash`, the INDEX's
        // copy, which can predate a re-download that has not been re-indexed yet.
        #expect(sheet.contains("guard !isVanished, !highlights.isEmpty || !excerpts.isEmpty else { return }"))
        // The rows are READS. A write here would be the first writer of the ledger's annotationId
        // and would cost a tenth CloudKit promotion against the design's "No deploy".
        let excerptSection = try #require(sheet.range(of: "// MARK: - Quotations (R-5 P3b-4)"))
        let sectionEnd = sheet.range(of: "/// The other annotations on the document",
                                     range: excerptSection.upperBound..<sheet.endIndex)?.lowerBound
            ?? sheet.endIndex
        let body = String(sheet[excerptSection.upperBound..<sectionEnd])
        #expect(!body.isEmpty, "the Quotations section must exist for this scan to mean anything")
        #expect(!body.contains("AnnotationReviewStore.record"), "an excerpt row must not write a ledger row")
        #expect(!body.contains("modelContext.delete"), "deletion belongs to the collection editor")
        #expect(!body.contains("HighlightReview.move"), "nothing renders from the anchors; a move would be invisible")

        // The rider, scoped to the control rather than the file: the Research sidebar's
        // per-collection number counts DISTINCT DOCUMENTS under the same kind rule, so it equals
        // the length of the list the row opens. It used to be `documentEntries.count` — every
        // entry of every kind — which counted headings and prose blocks as documents, and after
        // P3b-4 would additionally have counted an excerpt and its own document entry as two.
        let research = try Self.source("Research/ResearchView.swift")
        let countStart = try #require(research.range(of: "private var sortedCollectionsWithCounts:")).upperBound
        let countEnd = research.range(of: "\n    }\n", range: countStart..<research.endIndex)?.upperBound
            ?? research.endIndex
        let counter = String(research[countStart..<countEnd])
        // The behaviour is pinned by `ResearchDocumentAggregationTests.sidebarCountIsDistinctDocuments`;
        // this only checks the view reaches it, since a private computed property on a View cannot
        // be called from a test.
        #expect(counter.contains("ResearchDocumentAggregation.distinctDocumentKeys(in:"),
                "the sidebar count must go through the tested rule")
        #expect(!counter.contains("(collection.documentEntries ?? []).count"),
                "counting every entry of every kind names headings and prose blocks as documents")
    }

    /// R-5 P3b-5, design Q-11 (b) and (i). Both halves are CALLS, scoped to the control rather
    /// than to the file: the note-row title has its own pure test, and the rail's live-parse
    /// preference cannot be called from a test at all (a private computed property on a `View`),
    /// so a scan of the two sites it must reach is the only pin available.
    @Test("P3b-5 wiring: the sheet opens notes and tags, and the rail prefers the live parse")
    func p3b5Wiring() throws {
        let sheet = try Self.source("DocumentView/DocumentChangeReviewSheet.swift")
        // The editors are presented from INSIDE this sheet. Declaring them on any of the three
        // mounts would be a no-op that ghost-presents later: SwiftUI will not present an
        // ancestor's sheet over a descendant's.
        #expect(sheet.contains(".sheet(item: $noteToOpen) { request in"))
        #expect(sheet.contains("ResearchNoteEditorView("))
        #expect(sheet.contains("noteToEdit: request.note,"),
                "the editor must be handed the note carried by the item, never one re-derived")
        #expect(sheet.contains(".sheet(isPresented: $editingTags)"))
        #expect(sheet.contains("UserTagPickerSheet("))
        #expect(sheet.contains("initialTagIds: Set(tagAssignments.map(\\.tagId))"),
                "the picker must open on the tags this document already carries")
        // The rows that reach them.
        #expect(sheet.contains("noteToOpen = NoteEditorRequest(note: note)"))
        #expect(sheet.contains("editingTags = true"))
        // The plan route. One row per PLAN, resolved through `planId` rather than the back-
        // reference the model says is managed by its parent, and labelled only "open" — the editor
        // takes a whole plan and opens on its Targets tab with no way to focus a seed.
        #expect(sheet.contains(".sheet(item: $planToOpen) { plan in"))
        #expect(sheet.contains("ArchiveVisitEditorView(plan: plan)"))
        #expect(sheet.contains("FetchDescriptor<ArchiveVisitPlan>(predicate: #Predicate { $0.id == id })"),
                "the plan must be resolved by id, not read off the seed's parent back-reference")
        #expect(sheet.contains("document.review.other.openPlan %@"))
        // Scoped to the SHIPPED strings, not the file: the rationale comment three lines above the
        // control uses the same words to explain why the label may not say them, and a file-wide
        // scan matched that instead of a label.
        let shippedCopy = sheet.split(separator: "\n")
            .filter { $0.contains("defaultValue:") }
            .joined(separator: "\n")
        #expect(!shippedCopy.contains("show this document"),
                "no shipped label may promise the editor will focus the seeded document")
        #expect(shippedCopy.contains("Open the plan"))
        // The reworded footer is a NEW key: no String Catalog ships, so editing the old one in
        // place would have silently changed shipped copy.
        #expect(sheet.contains("document.review.other.footer.v2"))
        #expect(!sheet.contains("\"document.review.other.footer\","),
                "the superseded key must not still be emitted")

        let rail = try Self.source("DocumentView/ResearchRailView.swift")
        // Q-11 (i): the sentence and BOTH writes prefer the live parse. Fixing only the sentence
        // would leave a correct claim above a button that writes the stale value into the index.
        #expect(rail.contains("parsedIsEditorialNote: displayedParsedIsEditorialNote,"),
                "the FRUS-tags-this-as sentence must read the live parse")
        #expect(rail.contains("parsedIsEditorialNote: displayedParsedIsEditorialNote ?? override.parsedIsEditorialNote)"),
                "un-overriding must restore FRUS's CURRENT answer, not the one recorded at override time")
        #expect(rail.contains("parsedIsEditorialNote: displayedParsedIsEditorialNote ?? effective,"),
                "creating an override must freeze the live observation")
        #expect(rail.contains("vm.parsedIsEditorialNote ?? parsedIsEditorialNote"),
                "the live parse comes from the view model, never the index: once an override exists the index column IS the override")
        // Not snapshotted in `loadClassification`: that runs from `.task(id: entry.id)`, which does
        // not re-fire when the document finishes loading.
        #expect(!rail.contains("displayedParsedIsEditorialNote = "),
                "the live parse must be computed, not captured into state")

        // The SECOND Undo. Settings has no open document, so it re-derives the parse from the TEI
        // on disk — it cannot read the index, where the override has already been written. Fixing
        // only the rail would leave two buttons labelled "Restore FRUS's Classification" putting
        // back different values.
        let corrections = try Self.source("Settings/ClassificationCorrectionsView.swift")
        #expect(corrections.contains("DocumentClassificationOverrideStore.liveParsedIsEditorialNote("))
        #expect(corrections.contains("parsedIsEditorialNote: live ?? frozen.parsedIsEditorialNote)"))
        #expect(!corrections.contains("let restore = override.snapshot"),
                "the stale snapshot must no longer be the restore value")
        // The parse suspends, and this type's rule is that Undo re-fetches by id at action time —
        // another device can delete the override while the sheet is open. So VALUES cross the
        // await and the model is fetched again after it.
        #expect(corrections.contains("let frozen = override.snapshot"))
        #expect(corrections.contains("guard let current = (try? modelContext.fetch(descriptor))?.first else {"))
        #expect(corrections.contains("DocumentClassificationOverrideStore.remove(current, context: modelContext)"),
                "the removal must act on the RE-FETCHED row, never one held across the parse")
        // And the rule itself reads the TEI. Scoped to the FUNCTION, not the file: this file is
        // heavily doc-commented and a whole-file negative scan matches prose, which is the trap
        // recorded as "match a call, not a window".
        let model = try Self.source("Models/DocumentClassificationOverride.swift")
        let ruleStart = try #require(model.range(of: "static func liveParsedIsEditorialNote(")).lowerBound
        let ruleEnd = model.range(of: "\n    }\n", range: ruleStart..<model.endIndex)?.upperBound
            ?? model.endIndex
        let rule = String(model[ruleStart..<ruleEnd])
        #expect(rule.contains("return ast.isShapedAsEditorialNote"))
        #expect(!rule.contains("effectiveIsEditorialNote"),
                "the live-parse rule must not reach for the index column, which IS the override")
        #expect(!rule.contains("document_cache"))

        // The rail's live value has ONE producer, and it is write-only outside this feature: delete
        // the assignment and `displayedParsedIsEditorialNote` silently returns the frozen snapshot
        // forever while every assertion above still passes.
        let vm = try Self.source("DocumentView/DocumentViewModel.swift")
        #expect(vm.contains("parsedIsEditorialNote = ast.isShapedAsEditorialNote"),
                "the view model must record the RAW parse before the override reshapes the AST")
        let assign = try #require(vm.range(of: "parsedIsEditorialNote = ast.isShapedAsEditorialNote"))
        let reshape = try #require(vm.range(of: "ast = ast.applyingClassificationOverride("))
        #expect(assign.upperBound < reshape.lowerBound,
                "recording it AFTER the reshape would make the parse equal the override")
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
