// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - VolumeUpdateReviewSection

/// The storage hubs' post-update summary (Volume-Update-Annotation-Integrity design §5.5, R-5 P2):
/// what the last volume updates did to the documents the reader has annotated, per volume, and
/// one control that takes them to the review surface.
///
/// One shared view mounted by BOTH hubs — `VolumesStorageHubView` and `MacVolumesStorageHub` are
/// hand-maintained twins, and a section written twice is two places for the same numbers to
/// drift (the #900 rule, for the same reason).
///
/// The numbers come from two facts the app already holds and nothing else: the unreviewed rows of
/// `document_revisions`, and the reader's annotated documents as `ResearchView` counts them
/// (`ResearchDocumentAggregation.annotatedKeys`, six sources). So the count here is the count on
/// the Research sidebar's "Changed by an update" row, by construction. Reloaded on appearance and
/// whenever an indexing batch finishes, which is when a re-download's rows land.
///
/// The Research tab carries no badge by owner decision (`MainTabView`); this section and the
/// sidebar row are where the count waits, which is what §5.5's "nothing modal, nothing at launch"
/// asked for. Reviewing a change — confirm, repair, delete — is P3; until then the list stays.
///
/// Version history:
///   1.0 — R-5 P2: initial implementation
///   1.1 — R-5 P3: per-volume Mark Reviewed; reloads on the review token
struct VolumeUpdateReviewSection: View {

    @Environment(AppState.self) private var appState
    /// R-5 P3b-2: the volume-grain Mark Reviewed mints one ledger row per changed document.
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    // The six annotation sources, exactly as ResearchView queries them.
    @Query private var notes: [ResearchNote]
    @Query private var tagAssignments: [DocumentTagAssignment]
    @Query private var collections: [Collection]
    @Query private var highlights: [DocumentHighlight]
    @Query private var summaries: [GeneratedSummary]
    @Query private var visitDocuments: [ArchiveVisitDocument]

    /// Every unreviewed, stamped revision row, across volumes.
    @State private var revisions: [IndexingPipeline.DocumentRevision] = []
    /// The volume whose changes the reader is about to stamp as reviewed (R-5 P3); drives the dialog.
    @State private var volumeToReview: VolumeUpdateReview.VolumeSummary?
    /// Set once the first read has returned, so the "nothing waiting" row is a finding and not a
    /// placeholder shown before the table was consulted.
    @State private var loaded = false

    /// How many per-volume rows to list before folding the rest into a count.
    private static let rowCap = 6

    private var annotatedKeys: Set<String> {
        ResearchDocumentAggregation.annotatedKeys(
            notes: notes, tagAssignments: tagAssignments, collections: collections,
            highlights: highlights, summaries: summaries, visitDocuments: visitDocuments)
    }

    private var summariesByVolume: [VolumeUpdateReview.VolumeSummary] {
        VolumeUpdateReview.summaries(revisions: revisions, annotatedKeys: annotatedKeys)
    }

    var body: some View {
        Section {
            if loaded {
                let all = summariesByVolume
                let totals = VolumeUpdateReview.totals(of: all)
                if all.isEmpty {
                    SettingsStatusRow(
                        label: String(localized: "settings.updateReview.none.label",
                                      defaultValue: "No changes waiting"),
                        detail: String(localized: "settings.updateReview.none.detail",
                                       defaultValue: "No volume update on this device has changed a document since it was last indexed."),
                        state: .ok)
                } else {
                    SettingsStatusRow(
                        label: String(localized: "settings.updateReview.summary.label",
                                      defaultValue: "Updates changed documents"),
                        detail: Self.summaryDetail(totals),
                        state: totals.annotatedDocuments > 0 ? .warning : .ok
                    ) {
                        if totals.annotatedDocuments > 0 { openResearchButton }
                    }
                    let annotated = all.filter { $0.annotatedDocuments > 0 }
                    ForEach(annotated.prefix(Self.rowCap)) { volume in
                        volumeRow(volume)
                    }
                    if annotated.count > Self.rowCap {
                        Text(String(localized: "settings.updateReview.more %lld",
                                    defaultValue: "And \(annotated.count - Self.rowCap) more volumes with changed annotated documents."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(String(localized: "settings.updateReview.loading", defaultValue: "Checking for changed documents…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "settings.updateReview.header", defaultValue: "After an Update"))
        } footer: {
            // Two keys, split on the platform, because the two halves of the last sentence are
            // both platform-specific: Research is a TAB on iOS and a WINDOW on macOS (the button
            // three lines above already branches on exactly that), and the destination differs.
            // Same key with two texts would be the silent collision the localized-key lesson
            // warns about; `SettingsView`'s citation-style footer is the shipped precedent.
            //
            // Both wordings also drop the old promise that a changed document "opens with a
            // banner". Since P3b-1 a VANISHED document opens the review sheet instead — no
            // document view can load a document the update removed — and the vanished count is
            // printed two rows above this footer, so the old text contradicted its own section.
            #if os(macOS)
            Text(String(localized: "settings.updateReview.footer.mac.v2",
                        defaultValue: "When a volume is updated, the app compares every document with the copy it indexed before and records which ones changed. A document counts as yours if it carries a note, tag, highlight, quotation, collection entry, summary, or archive-visit plan. The Research window lists the changed ones under “Changed by an update”. Opening one shows a banner saying whether its text moved or only its notes and heading changed — unless the update removed the document altogether, in which case it opens the review sheet, the only surface that can still reach it."))
            #else
            Text(String(localized: "settings.updateReview.footer.v2",
                        defaultValue: "When a volume is updated, the app compares every document with the copy it indexed before and records which ones changed. A document counts as yours if it carries a note, tag, highlight, quotation, collection entry, summary, or archive-visit plan. The Research tab lists the changed ones under “Changed by an update”. Opening one shows a banner saying whether its text moved or only its notes and heading changed — unless the update removed the document altogether, in which case it opens the review sheet, the only surface that can still reach it."))
            #endif
        }
        .task { await reload() }
        .onChange(of: appState.indexingBatch) { _, batch in
            if batch == nil { Task { await reload() } }
        }
        // R-5 P3: a review write anywhere re-reads the set.
        .onChange(of: appState.revisionReviewToken) { _, _ in Task { await reload() } }
    }

    // MARK: - Rows

    /// One volume: its title from the manifest when the app has one, else the id.
    private func volumeRow(_ volume: VolumeUpdateReview.VolumeSummary) -> some View {
        SettingsStatusRow(
            label: appState.manifestStore.entry(forVolumeId: volume.volumeId)?.title ?? volume.volumeId,
            detail: Self.volumeDetail(volume),
            state: .warning
        ) {
            Button(String(localized: "settings.updateReview.markVolumeReviewed", defaultValue: "Mark Reviewed")) {
                volumeToReview = volume
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        // R-5 P3: the volume-grain disposition. It stamps every changed document in the volume —
        // annotated or not, which is what lets the headline count reach zero — and says so.
        .confirmationDialog(
            String(localized: "settings.updateReview.markVolume.title %lld",
                   defaultValue: "Mark \(volumeToReview?.changedDocuments ?? 0) changed documents as reviewed?"),
            isPresented: Binding(get: { volumeToReview?.id == volume.id },
                                 set: { if !$0 { volumeToReview = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.updateReview.markVolume.confirm", defaultValue: "Mark Reviewed")) {
                let id = volume.volumeId
                volumeToReview = nil
                Task { await markVolumeReviewed(id) }
            }
            Button(String(localized: "settings.updateReview.markVolume.cancel", defaultValue: "Cancel"), role: .cancel) {
                volumeToReview = nil
            }
        } message: {
            Text(String(localized: "settings.updateReview.markVolume.message.v2",
                        defaultValue: "This marks every changed document in the volume as reviewed. With iCloud sync it reaches your other devices too, a few seconds after they next sync or when they next open. Highlights stay flagged until you confirm each one, and the next update re-opens anything that changes again."))
        }
    }

    /// Stamps the volume, then reloads and tells the other readers.
    ///
    /// **One ledger row per changed document (R-5 P3b-2), and the fan-out is deliberate.** The
    /// review is per document — that is the grain the reader's other devices need — so a volume
    /// where the Office of the Historian corrected many documents mints many rows in one tap.
    /// They are small and byte-identical across devices, and `markVolumeRevisionsReviewed`
    /// returns only a count, so the rows are minted from the revisions this section already holds
    /// rather than from its result.
    private func markVolumeReviewed(_ volumeId: String) async {
        guard let pipeline = appState.indexingPipeline else { return }
        for revision in revisions where revision.volumeId == volumeId
            && revision.changedAt != nil && revision.reviewedAt == nil && !revision.contentHash.isEmpty {
            AnnotationReviewStore.record(kind: .document, volumeId: revision.volumeId,
                                         documentId: revision.documentId,
                                         contentHash: revision.contentHash,
                                         changeKind: revision.changeKind, context: modelContext)
        }
        try? modelContext.save()
        _ = try? await pipeline.markVolumeRevisionsReviewed(volumeId: volumeId)
        await reload()
        appState.revisionReviewToken += 1
    }

    private var openResearchButton: some View {
        Button(String(localized: "settings.updateReview.openResearch", defaultValue: "Open Research")) {
            #if os(iOS)
            appState.pendingTab = Handoff(target: .anyWindow, payload: .research)
            #else
            appState.bindTool(.research, to: nil)
            openWindow.fronting(id: "frus.research")
            #endif
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Sentences

    /// The totals in one sentence: how many documents, in how many volumes, how many are the reader's.
    static func summaryDetail(_ t: VolumeUpdateReview.Totals) -> String {
        String(localized: "settings.updateReview.summary.detail %lld %lld %lld",
               defaultValue: "\(t.changedDocuments) documents changed in \(t.volumes) updated volumes. \(t.annotatedDocuments) of them carry your research.")
    }

    /// A volume's line: the reader's changed documents, split by what moved.
    ///
    /// Each count names only what two hashes can prove — text, apparatus, gone — and never that an
    /// annotation is wrong. A zero part is left out rather than printed, so a volume where only
    /// footnotes changed does not say "0 text changes".
    static func volumeDetail(_ v: VolumeUpdateReview.VolumeSummary) -> String {
        var parts: [String] = []
        if v.body > 0 {
            parts.append(String(localized: "settings.updateReview.part.body %lld",
                                defaultValue: "\(v.body) with changed text"))
        }
        if v.apparatus > 0 {
            parts.append(String(localized: "settings.updateReview.part.apparatus %lld",
                                defaultValue: "\(v.apparatus) with changed footnotes, source note, or heading"))
        }
        if v.vanished > 0 {
            parts.append(String(localized: "settings.updateReview.part.vanished %lld",
                                defaultValue: "\(v.vanished) no longer in the volume"))
        }
        let lead = String(localized: "settings.updateReview.volume.lead %lld %lld",
                          defaultValue: "\(v.annotatedDocuments) of \(v.changedDocuments) changed documents carry your research")
        return parts.isEmpty ? lead + "." : lead + ": " + parts.joined(separator: ", ") + "."
    }

    // MARK: - Loading

    private func reload() async {
        guard let pipeline = appState.indexingPipeline else { loaded = true; return }
        let rows = (try? await pipeline.unreviewedDocumentRevisions()) ?? []
        revisions = rows
        loaded = true
    }
}
