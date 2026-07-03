// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionEntryInspector

/// A "what does this document contribute" surface for one collection entry: its identity
/// (header, volume), the user's own annotations for it (research notes, highlights, tags,
/// AI summary), its archival provenance (source note, cross-reference count), and — from
/// Authoring Phase 5 — the entry's headnote controls (the first read-write affordance on
/// the way to the full Phase 5 inspector).
///
/// Opened from an entry row so the manager is a place to *see* the full range of
/// document-level data while composing — volume-derived and user-generated alike. It reuses
/// the app's existing stores (`CrossReferenceStore`, `IndexingPipeline`, SwiftData) and reads
/// no new data. Cross-reference *inclusion* in exports is deferred (decision D4, Phase 3);
/// here the count is informational.
///
/// Version history:
///   1.0 — Collections rework Phase 2: editorial data surface
///   1.1 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
///   1.2 — Authoring Phase 5: the "first non-empty summary" display became prompt-aware
///          (prefers the collection's `summaryPromptId`, labels the producing prompt);
///          new Headnote section — toggle `includeHeadnote` and pick the
///          `GeneratedSummary` (`headnoteSummaryId`) rendered above the body in exports
struct CollectionEntryInspector: View {

    /// One stored summary choice for the headnote picker: identity, producing-prompt
    /// label, and a short preview.
    private struct SummaryChoice: Identifiable {
        /// The `GeneratedSummary.id`.
        let id: UUID
        /// The producing prompt's display name, or a fallback when the prompt is gone.
        let promptName: String
        /// The summary text (used for the preview row).
        let text: String
    }

    /// The entry whose document is being inspected.
    let entry: CollectionEntry

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var header: String?
    @State private var volumeTitle = ""
    @State private var sourceNote: String?
    @State private var summaryPreview: String?
    @State private var summaryPromptName: String?
    @State private var summaryChoices: [SummaryChoice] = []
    @State private var noteTexts: [String] = []
    @State private var tags: [String] = []
    @State private var highlightCount = 0
    @State private var crossRefCount = 0
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                identitySection
                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text(String(localized: "collection.inspector.loading",
                                        defaultValue: "Loading document details…"))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    annotationsSection
                    headnoteSection
                    provenanceSection
                }
            }
            .navigationTitle(String(localized: "collection.inspector.title",
                                    defaultValue: "Document Details"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
            .task { await load() }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    private var identitySection: some View {
        Section {
            if let header, !header.isEmpty {
                Text(header).font(.headline).textSelection(.enabled)
            }
            LabeledContent(String(localized: "collection.inspector.document", defaultValue: "Document"),
                           value: entry.documentId)
            LabeledContent(String(localized: "collection.inspector.volume", defaultValue: "Volume"),
                           value: volumeTitle.isEmpty ? entry.volumeId : volumeTitle)
        }
    }

    @ViewBuilder private var annotationsSection: some View {
        Section(String(localized: "collection.inspector.yourData", defaultValue: "Your Annotations")) {
            if noteTexts.isEmpty {
                Label(String(localized: "collection.inspector.noNotes", defaultValue: "No research notes"),
                      systemImage: "note.text")
                    .foregroundStyle(.secondary).font(.callout)
            } else {
                ForEach(Array(noteTexts.enumerated()), id: \.offset) { _, text in
                    Label { Text(text).font(.callout).lineLimit(3) }
                        icon: { Image(systemName: "note.text") }
                }
            }

            Label {
                Text(highlightCount == 1
                     ? String(localized: "collection.inspector.highlight.one", defaultValue: "1 highlight")
                     : String(localized: "collection.inspector.highlight.many",
                              defaultValue: "\(highlightCount) highlights"))
                    .font(.callout)
                    .foregroundStyle(highlightCount == 0 ? .secondary : .primary)
            } icon: { Image(systemName: "highlighter") }

            if !tags.isEmpty {
                Label { Text(tags.joined(separator: ", ")).font(.callout) }
                    icon: { Image(systemName: "tag") }
            }

            if let summaryPreview, !summaryPreview.isEmpty {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        // Prompt-aware label (Phase 5): name the producing prompt when known.
                        Text(summaryPromptName.map { name in
                            String(localized: "collection.inspector.summaryFromPrompt",
                                   defaultValue: "AI summary — \(name)")
                        } ?? String(localized: "collection.inspector.summary",
                                    defaultValue: "AI summary"))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(summaryPreview).font(.callout).lineLimit(3)
                    }
                } icon: { Image(systemName: "sparkles") }
            }
        }
    }

    /// Headnote controls (Authoring Phase 5): opt a document entry into an italic
    /// abstract above its body in exports/preview, and — when stored summaries exist —
    /// choose which `GeneratedSummary` supplies it (labeled by producing prompt;
    /// "Automatic" = the resolver's fallback pick, preferring the collection's prompt).
    @ViewBuilder private var headnoteSection: some View {
        Section(String(localized: "collection.inspector.headnote", defaultValue: "Headnote")) {
            Toggle(String(localized: "collection.inspector.headnote.toggle",
                          defaultValue: "Show a summary above the document"),
                   isOn: Binding(get: { entry.includeHeadnote },
                                 set: { entry.includeHeadnote = $0 }))

            if entry.includeHeadnote {
                if summaryChoices.isEmpty {
                    Text(String(localized: "collection.inspector.headnote.none",
                                defaultValue: "No stored summaries for this document. Exports will show a placeholder until one is generated in the document view."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(String(localized: "collection.inspector.headnote.pick",
                                  defaultValue: "Summary"),
                           selection: Binding(get: { entry.headnoteSummaryId },
                                              set: { entry.headnoteSummaryId = $0 })) {
                        Text(String(localized: "collection.inspector.headnote.automatic",
                                    defaultValue: "Automatic"))
                            .tag(UUID?.none)
                        ForEach(summaryChoices) { choice in
                            Text(choice.promptName).tag(UUID?.some(choice.id))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var provenanceSection: some View {
        Section(String(localized: "collection.inspector.provenance", defaultValue: "Provenance")) {
            if let sourceNote, !sourceNote.isEmpty {
                Label { Text(sourceNote).font(.callout).textSelection(.enabled) }
                    icon: { Image(systemName: "archivebox") }
            } else {
                Label(String(localized: "collection.inspector.noSource",
                             defaultValue: "No archival source note indexed"),
                      systemImage: "archivebox")
                    .foregroundStyle(.secondary).font(.callout)
            }
            if crossRefCount > 0 {
                Label {
                    Text(crossRefCount == 1
                         ? String(localized: "collection.inspector.crossRef.one",
                                  defaultValue: "1 cross-reference")
                         : String(localized: "collection.inspector.crossRef.many",
                                  defaultValue: "\(crossRefCount) cross-references"))
                        .font(.callout)
                } icon: { Image(systemName: "arrow.triangle.branch") }
            }
        }
    }

    /// Gathers the document's data from the app's existing stores. Fast SwiftData reads run
    /// inline; header / cross-refs / source note come from the actor-isolated stores.
    private func load() async {
        let vid = entry.volumeId
        let did = entry.documentId

        volumeTitle = appState.manifestStore.entry(forVolumeId: vid)?.title ?? ""

        let (docTags, docNotes) = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: did, volumeId: vid, context: modelContext)
        tags = docTags
        noteTexts = docNotes

        let highlights = (try? modelContext.fetch(FetchDescriptor<DocumentHighlight>(
            predicate: #Predicate { $0.volumeId == vid && $0.documentId == did }))) ?? []
        highlightCount = highlights.count

        let summaries = ((try? modelContext.fetch(FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.volumeId == vid && $0.documentId == did }))) ?? [])
            .filter { !$0.responseText.isEmpty }
        // Prompt-aware pick (Phase 5): prefer the summary produced by the collection's
        // configured prompt; else fall back to the first non-empty one (prior behavior).
        let prompts = (try? modelContext.fetch(FetchDescriptor<SummarizationPrompt>())) ?? []
        let promptNames = Dictionary(prompts.map { ($0.id, $0.name) },
                                     uniquingKeysWith: { first, _ in first })
        let collectionPromptId = entry.collection?.summaryPromptId
        let shown = collectionPromptId.flatMap { pid in summaries.first { $0.promptId == pid } }
            ?? summaries.first
        summaryPreview = shown?.responseText
        summaryPromptName = shown.flatMap { promptNames[$0.promptId] }
        summaryChoices = summaries.map { summary in
            SummaryChoice(
                id: summary.id,
                promptName: promptNames[summary.promptId]
                    ?? String(localized: "collection.inspector.headnote.unknownPrompt",
                              defaultValue: "Deleted prompt"),
                text: summary.responseText)
        }

        if let store = appState.crossReferenceStore {
            header = (try? await store.documentHeaders(
                for: [(volumeId: vid, documentId: did)]))?["\(vid)/\(did)"]
            let inbound = (try? await store.inboundEdges(forDocumentId: did, volumeId: vid))?.count ?? 0
            let outbound = (try? await store.outboundEdges(forDocumentId: did, volumeId: vid))?.count ?? 0
            crossRefCount = inbound + outbound
        }

        sourceNote = try? await appState.indexingPipeline?
            .fetchDocumentSourceNote(volumeId: vid, documentId: did)

        isLoading = false
    }
}
