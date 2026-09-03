// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - DocumentChangeReviewSheet

/// The per-document review surface for a volume update (design §5.4–§5.6, R-5 P3): what the
/// re-index recorded, every highlight on the document with its standing and the two actions the
/// reader can take on it, the other annotations the app cannot judge, and the document-level
/// disposition that stamps `reviewed_at`.
///
/// One shared view, reached three ways: the change banner's *Review…* control in both document
/// twins (which pass the open document's `renderingVersion`), and the Research list's *Review
/// Changes…* row action (which passes none, so the sheet judges against the revision row's
/// `body_hash` — P1 pinned the two equal). A vanished document never reaches a document view at
/// all, so the Research route is the only one an orphan has, and the sheet works with no render
/// model: nothing here needs one.
///
/// What it refuses, per §7: it never re-anchors, never deletes on its own, and never says an
/// annotation is wrong — only what two hashes can prove.
///
/// Version history:
///   1.0 — R-5 P3: initial implementation
struct DocumentChangeReviewSheet: View {

    let volumeId: String
    let documentId: String
    /// The document's header, for the title.
    let title: String
    /// The open document's `renderingVersion`, when the caller has one; nil falls back to the
    /// revision row's `bodyHash`.
    let currentVersion: String?

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var highlights: [DocumentHighlight]
    @Query private var notes: [ResearchNote]
    @Query private var tagAssignments: [DocumentTagAssignment]
    @Query private var entries: [CollectionEntry]
    @Query private var summaries: [GeneratedSummary]
    @Query private var visitDocuments: [ArchiveVisitDocument]

    @State private var revision: IndexingPipeline.DocumentRevision?
    @State private var loaded = false
    @State private var highlightToDelete: DocumentHighlight?
    @State private var stamping = false

    init(volumeId: String, documentId: String, title: String, currentVersion: String? = nil) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.title = title
        self.currentVersion = currentVersion
        let key = "\(volumeId)/\(documentId)"
        _highlights = Query(filter: #Predicate<DocumentHighlight> {
            $0.volumeId == volumeId && $0.documentId == documentId
        }, sort: [SortDescriptor(\DocumentHighlight.startOffset)])
        _notes = Query(filter: #Predicate<ResearchNote> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _tagAssignments = Query(filter: #Predicate<DocumentTagAssignment> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _entries = Query(filter: #Predicate<CollectionEntry> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _summaries = Query(filter: #Predicate<GeneratedSummary> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _visitDocuments = Query(filter: #Predicate<ArchiveVisitDocument> { $0.documentKey == key })
    }

    // MARK: - Derived

    /// The version highlights are judged against.
    private var effectiveVersion: String? {
        if let currentVersion, !currentVersion.isEmpty { return currentVersion }
        if let bodyHash = revision?.bodyHash, !bodyHash.isEmpty { return bodyHash }
        return nil
    }

    /// A vanished document: no text to judge against, every annotation an orphan.
    private var isVanished: Bool { revision?.changeKind == "vanished" }

    /// Whether the row can still be stamped.
    private var canMarkReviewed: Bool {
        guard let revision else { return false }
        return revision.changedAt != nil && revision.reviewedAt == nil
    }

    private var highlightsStale: Bool {
        highlights.contains { HighlightReview.status(of: $0, currentVersion: effectiveVersion) != .aligned
            && HighlightReview.status(of: $0, currentVersion: effectiveVersion) != .unverifiable }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                changeSection
                if !highlights.isEmpty { highlightsSection }
                othersSection
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.review.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 440)
        #endif
        .task { await loadRevision() }
        .confirmationDialog(
            String(localized: "highlight.delete.title", defaultValue: "Remove Highlight"),
            isPresented: Binding(get: { highlightToDelete != nil },
                                 set: { if !$0 { highlightToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "highlight.delete.confirm", defaultValue: "Remove"), role: .destructive) {
                if let highlight = highlightToDelete {
                    HighlightReview.delete(highlight, in: modelContext)
                    appState.revisionReviewToken += 1
                }
                highlightToDelete = nil
            }
            Button(String(localized: "highlight.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                highlightToDelete = nil
            }
        } message: {
            Text(String(localized: "highlight.delete.message",
                        defaultValue: "This highlight will be permanently removed."))
        }
    }

    // MARK: - Sections

    /// What the re-index recorded, in the banner's own words, and the document-level disposition.
    private var changeSection: some View {
        Section {
            if !loaded {
                Text(String(localized: "document.review.loading", defaultValue: "Reading the change record…"))
                    .foregroundStyle(.secondary)
            } else if isVanished {
                Label(String(localized: "document.review.vanished",
                             defaultValue: "This document is no longer in the volume after an update. Everything you attached to it is kept until you remove it."),
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if let line = DocumentChangeBanner.line(revision: revision, highlightsStale: highlightsStale) {
                Label(line, systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
            } else {
                Label(String(localized: "document.review.noChange",
                             defaultValue: "No change to this document is recorded on this device."),
                      systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            if canMarkReviewed {
                Button {
                    Task { await markReviewed() }
                } label: {
                    Label(String(localized: "document.review.markReviewed", defaultValue: "Mark Reviewed"),
                          systemImage: "checkmark.circle")
                }
                .disabled(stamping)
                .accessibilityIdentifier("document.review.markReviewed")
            }
        } header: {
            Text(String(localized: "document.review.change.header", defaultValue: "What Changed"))
        } footer: {
            if canMarkReviewed {
                Text(String(localized: "document.review.change.footer.v2",
                            defaultValue: "Marking the document reviewed clears it from “Changed by an update”. With iCloud sync it reaches your other devices too, a few seconds after they next sync or when they next open. Highlights stay flagged until you confirm each one, and the next update re-opens the document if it changes again."))
            }
        }
    }

    /// Every highlight on the document, with its standing and its two actions.
    private var highlightsSection: some View {
        Section {
            ForEach(highlights) { highlight in
                highlightRow(highlight)
            }
        } header: {
            Text(String(localized: "document.review.highlights.header", defaultValue: "Highlights"))
        } footer: {
            Text(String(localized: "document.review.highlights.footer",
                        defaultValue: "Confirm keeps a highlight exactly where it is and clears its warning everywhere you are signed in. The app never moves a highlight on its own."))
        }
    }

    private func highlightRow(_ highlight: DocumentHighlight) -> some View {
        let status = HighlightReview.status(of: highlight, currentVersion: effectiveVersion)
        return VStack(alignment: .leading, spacing: 6) {
            if highlight.selectedText.isEmpty {
                Text(String(localized: "document.review.highlight.noPassage", defaultValue: "Highlighted passage"))
                    .italic()
                    .foregroundStyle(.secondary)
            } else {
                Text(highlight.selectedText)
                    .lineLimit(4)
            }
            Text(Self.statusLine(status, vanished: isVanished))
                .font(.caption)
                .foregroundStyle(isVanished ? Color.red : (status == .aligned ? Color.secondary : Color.orange))
            HStack(spacing: 12) {
                if !isVanished, case .stale = status, let version = effectiveVersion {
                    Button(String(localized: "document.review.highlight.confirm", defaultValue: "Confirm")) {
                        HighlightReview.confirm(highlight, currentVersion: version)
                        appState.revisionReviewToken += 1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button(String(localized: "document.review.highlight.remove", defaultValue: "Remove…"), role: .destructive) {
                    highlightToDelete = highlight
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    /// The other annotations on the document: counted, never judged.
    private var othersSection: some View {
        let documentEntries = entries.filter { $0.kind == CollectionEntryKind.document.rawValue }.count
        let liveSummaries = summaries.filter { !$0.isHeadnoteDraft }.count
        let parts: [String] = [
            notes.isEmpty ? nil : String(localized: "document.review.other.notes %lld",
                                         defaultValue: "\(notes.count) notes"),
            tagAssignments.isEmpty ? nil : String(localized: "document.review.other.tags %lld",
                                                  defaultValue: "\(tagAssignments.count) tags"),
            documentEntries == 0 ? nil : String(localized: "document.review.other.collections %lld",
                                                defaultValue: "in \(documentEntries) collections"),
            liveSummaries == 0 ? nil : String(localized: "document.review.other.summaries %lld",
                                              defaultValue: "\(liveSummaries) summaries"),
            visitDocuments.isEmpty ? nil : String(localized: "document.review.other.visit",
                                                  defaultValue: "in an archive-visit plan"),
        ].compactMap { $0 }
        return Section {
            if parts.isEmpty {
                Text(String(localized: "document.review.other.none", defaultValue: "No other annotations on this document."))
                    .foregroundStyle(.secondary)
            } else {
                Text(parts.joined(separator: " · "))
            }
        } header: {
            Text(String(localized: "document.review.other.header", defaultValue: "Other Annotations"))
        } footer: {
            Text(String(localized: "document.review.other.footer",
                        defaultValue: "These carry no position in the text, so the app cannot judge them against the change. Review them by eye; a summary describes the text as it was when it was written."))
        }
    }

    // MARK: - Sentences

    /// One line per standing. Says what two hashes prove and nothing more.
    static func statusLine(_ status: HighlightReview.Status, vanished: Bool) -> String {
        if vanished {
            return String(localized: "document.review.highlight.orphaned",
                          defaultValue: "The document it was made on is no longer in the volume.")
        }
        switch status {
        case .aligned:
            return String(localized: "document.review.highlight.aligned",
                          defaultValue: "Matches the current text.")
        case .stale(hasPassage: true):
            return String(localized: "document.review.highlight.stale",
                          defaultValue: "Made against an earlier version of the text — its position may have moved.")
        case .stale(hasPassage: false):
            return String(localized: "document.review.highlight.stale.noPassage",
                          defaultValue: "Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye.")
        case .unverifiable:
            return String(localized: "document.review.highlight.unverifiable",
                          defaultValue: "This device has no record to compare it against.")
        }
    }

    // MARK: - Actions

    private func loadRevision() async {
        revision = await DocumentChangeBanner.revision(volumeId: volumeId, documentId: documentId,
                                                       pipeline: appState.indexingPipeline)
        loaded = true
    }

    private func markReviewed() async {
        guard let pipeline = appState.indexingPipeline else { return }
        stamping = true
        defer { stamping = false }
        // R-5 P3b-2: the ledger row FIRST, from the hash the reader is dispositioning — it is what
        // carries this review to the reader's other devices. The local stamp follows.
        if let hash = revision?.contentHash, !hash.isEmpty {
            AnnotationReviewStore.record(kind: .document, volumeId: volumeId, documentId: documentId,
                                         contentHash: hash, changeKind: revision?.changeKind,
                                         context: modelContext)
            try? modelContext.save()
        }
        _ = try? await pipeline.markDocumentRevisionReviewed(volumeId: volumeId, documentId: documentId)
        await loadRevision()
        appState.revisionReviewToken += 1
    }
}
