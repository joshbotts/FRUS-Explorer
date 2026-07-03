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

/// The **per-entry control surface** for one collection entry (Authoring Phase 5): its
/// identity (header, volume), the user's own annotations for it (research notes,
/// highlights, tags, AI summary), its archival provenance (source note, cross-reference
/// count), the headnote controls, and the per-entry **export overrides** — highlights
/// (with per-highlight selection, A8), research notes, source note, footnotes, summary
/// prompt, and the related-documents line (A10). Every override is optional: "Default"
/// inherits the nearest ancestor heading's section default, else the collection setting
/// — resolved in exactly one place, `CollectionContentResolver`.
///
/// A **heading entry** presented here shows the section-defaults variant instead: the
/// same override controls, applied to every document the section owns (unless a
/// document sets its own).
///
/// Opened from an entry row so the manager is a place to *see* — and now *shape* — the
/// full range of document-level data while composing. It reuses the app's existing
/// stores (`CrossReferenceStore`, `IndexingPipeline`, SwiftData) and reads no new data.
///
/// Version history:
///   1.0 — Collections rework Phase 2: editorial data surface
///   1.1 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
///   1.2 — Authoring Phase 5: the "first non-empty summary" display became prompt-aware
///          (prefers the collection's `summaryPromptId`, labels the producing prompt);
///          new Headnote section — toggle `includeHeadnote` and pick the
///          `GeneratedSummary` (`headnoteSummaryId`) rendered above the body in exports
///   1.3 — Authoring Phase 5 (excerpts): the highlight count became a highlight *list*
///          (colour chip + passage preview) with a per-highlight "Insert as Excerpt"
///          action (creation path c) — the capture is handed to the presenting editor
///          via `onInsertExcerpt`, which appends through the shared `CollectionExcerpts`
///          factory; highlights without stored text stay listed but not insertable
///   1.4 — Authoring Phase 5 (read-write inspector): the Export Overrides section
///          (highlights / notes / source note / footnotes / summary prompt / related
///          documents, each Default-On-Off), per-highlight include checkboxes writing
///          `selectedHighlightIds` (empty = all; unselecting every passage turns
///          highlights off for the entry, since the empty set means "all"), the
///          excerpts-in-this-collection list, and the heading (section-defaults)
///          variant. Honesty audit: the footnote override carries a caption naming its
///          real reach (HTML exports + preview; PDF/DOCX footnotes are ungated — a
///          pre-existing gap), and tags keep reading as data, not a control
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

    /// One highlight row offered for excerpt insertion (Authoring Phase 5).
    private struct HighlightChoice: Identifiable {
        /// The source highlight's id — row identity only, never serialized.
        let id: UUID
        /// The ready-to-insert capture; `nil` when the highlight has no stored text
        /// (pre-Session-131), which leaves the row visible but not insertable.
        let capture: CollectionExcerptCapture?
        /// The highlight's colour, for the row chip.
        let color: DocumentHighlight.Color
    }

    /// One summarization prompt offered by the summary-prompt override picker.
    private struct PromptChoice: Identifiable {
        /// The `SummarizationPrompt.id`.
        let id: UUID
        /// The prompt's display name.
        let name: String
    }

    /// The entry whose document is being inspected.
    let entry: CollectionEntry

    /// Appends an excerpt entry to the owning collection (Authoring Phase 5, creation
    /// path c) — supplied by the presenting editor so its entry list stays in sync.
    /// `nil` (e.g. a future read-only presentation) hides the insert buttons.
    var onInsertExcerpt: ((CollectionExcerptCapture) -> Void)? = nil

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
    /// The document's highlights as insertable rows (Authoring Phase 5).
    @State private var highlightChoices: [HighlightChoice] = []
    /// Ids of highlights inserted as excerpts during this presentation — feedback only.
    @State private var insertedHighlightIds: Set<UUID> = []
    @State private var crossRefCount = 0
    @State private var isLoading = true
    /// The summarization prompts offered by the summary-prompt override picker.
    @State private var promptChoices: [PromptChoice] = []

    /// Whether this presentation is the heading (section-defaults) variant.
    private var isHeading: Bool { entry.entryKind == .heading }

    var body: some View {
        NavigationStack {
            List {
                if isHeading {
                    headingIdentitySection
                    sectionDefaultsSection
                } else {
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
                        overridesSection
                        headnoteSection
                        excerptsSection
                        provenanceSection
                    }
                }
            }
            .navigationTitle(isHeading
                ? String(localized: "collection.inspector.section.title",
                         defaultValue: "Section Details")
                : String(localized: "collection.inspector.title",
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

    /// Identity for the heading (section-defaults) variant.
    private var headingIdentitySection: some View {
        Section {
            LabeledContent(String(localized: "collection.inspector.section.heading",
                                  defaultValue: "Section"),
                           value: (entry.text?.isEmpty == false)
                               ? (entry.text ?? "")
                               : String(localized: "collection.inspector.section.untitled",
                                        defaultValue: "Untitled section"))
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

            // Per-highlight rows (Authoring Phase 5): an include checkbox (A8 —
            // `selectedHighlightIds`, empty = all), passage preview + colour chip,
            // each insertable as a frozen excerpt entry when the editor supplied the
            // append action and the highlight has stored text.
            ForEach(highlightChoices) { choice in
                HStack(alignment: .top, spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { highlightIncluded(choice.id) },
                        set: { setHighlightIncluded(choice.id, $0) }
                    )) {
                        EmptyView()
                    }
                    .labelsHidden()
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #else
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    #endif
                    .accessibilityLabel(String(localized: "collection.inspector.highlight.include",
                                               defaultValue: "Include this passage when highlights apply"))
                    Circle()
                        .fill(choice.color.swiftUIColor)
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                        .accessibilityLabel(choice.color.displayName)
                    if let capture = choice.capture {
                        Text(capture.text)
                            .font(.caption)
                            .lineLimit(3)
                        Spacer(minLength: 8)
                        if onInsertExcerpt != nil {
                            if insertedHighlightIds.contains(choice.id) {
                                Label(String(localized: "collection.inspector.excerpt.inserted",
                                             defaultValue: "Inserted"),
                                      systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .labelStyle(.titleAndIcon)
                            } else {
                                Button(String(localized: "collection.inspector.excerpt.insert",
                                              defaultValue: "Insert as Excerpt")) {
                                    onInsertExcerpt?(capture)
                                    insertedHighlightIds.insert(choice.id)
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        }
                    } else {
                        Text(String(localized: "collection.inspector.excerpt.noText",
                                    defaultValue: "No stored passage text — open the document and re-create this highlight to excerpt it."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !highlightChoices.isEmpty {
                Text(String(localized: "collection.inspector.highlight.selectionCaption",
                            defaultValue: "Checked passages are included when highlights apply to this document. Unselecting every passage turns highlights off for it."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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

    // MARK: - Export overrides (Authoring Phase 5)

    /// A Default / On / Off picker bound to one optional-Bool override field.
    /// "Default" (`nil`) inherits the section default, else the collection setting.
    private func overridePicker(_ title: String, _ binding: Binding<Bool?>) -> some View {
        Picker(title, selection: binding) {
            Text(String(localized: "collection.inspector.override.default",
                        defaultValue: "Default"))
                .tag(Bool?.none)
            Text(String(localized: "collection.inspector.override.on",
                        defaultValue: "On"))
                .tag(Bool?.some(true))
            Text(String(localized: "collection.inspector.override.off",
                        defaultValue: "Off"))
                .tag(Bool?.some(false))
        }
        .pickerStyle(.menu)
    }

    /// The shared override controls — the same six fields serve a document entry (its
    /// own overrides) and a heading entry (its section defaults); only the containing
    /// section's copy differs. Every control here is functional: highlights, notes, and
    /// source note gate all three export formats and the preview; footnotes carry an
    /// honest caption naming their real reach.
    @ViewBuilder private var overrideControls: some View {
        overridePicker(String(localized: "collection.inspector.override.highlights",
                              defaultValue: "Highlights"),
                       Binding(get: { entry.applyHighlightsOverride },
                               set: { entry.applyHighlightsOverride = $0 }))
        overridePicker(String(localized: "collection.inspector.override.notes",
                              defaultValue: "Research notes"),
                       Binding(get: { entry.includeNotesOverride },
                               set: { entry.includeNotesOverride = $0 }))
        overridePicker(String(localized: "collection.inspector.override.sourceNote",
                              defaultValue: "Source note"),
                       Binding(get: { entry.includeSourceNoteOverride },
                               set: { entry.includeSourceNoteOverride = $0 }))
        overridePicker(String(localized: "collection.inspector.override.footnotes",
                              defaultValue: "Footnotes"),
                       Binding(get: { entry.includeFootnotesOverride },
                               set: { entry.includeFootnotesOverride = $0 }))
        Text(String(localized: "collection.inspector.override.footnotes.caption",
                    defaultValue: "The footnote setting applies to HTML exports and the live preview; PDF and Word exports always include footnotes."))
            .font(.caption2)
            .foregroundStyle(.secondary)

        Picker(String(localized: "collection.inspector.override.prompt",
                      defaultValue: "Summary prompt"),
               selection: Binding(get: { entry.summaryPromptIdOverride },
                                  set: { entry.summaryPromptIdOverride = $0 })) {
            Text(String(localized: "collection.inspector.override.default",
                        defaultValue: "Default"))
                .tag(UUID?.none)
            ForEach(promptChoices) { choice in
                Text(choice.name).tag(UUID?.some(choice.id))
            }
        }
        .pickerStyle(.menu)

        overridePicker(String(localized: "collection.inspector.override.related",
                              defaultValue: "Related documents"),
                       Binding(get: { entry.includeRelatedDocuments },
                               set: { entry.includeRelatedDocuments = $0 }))
        Text(String(localized: "collection.inspector.override.related.caption",
                    defaultValue: "Adds a \u{201C}See also\u{201D} line listing cross-referenced documents that are also in this collection. Off unless turned on here or on the section."))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    /// The document entry's Export Overrides section.
    @ViewBuilder private var overridesSection: some View {
        Section(String(localized: "collection.inspector.overrides",
                       defaultValue: "Export Overrides")) {
            overrideControls
            Text(String(localized: "collection.inspector.overrides.caption",
                        defaultValue: "Default follows the section's setting when its heading sets one, else the collection's composition."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// The heading entry's Section Defaults variant: the same controls, applied to
    /// every document the section owns unless a document sets its own override.
    @ViewBuilder private var sectionDefaultsSection: some View {
        Section(String(localized: "collection.inspector.sectionDefaults",
                       defaultValue: "Section Defaults")) {
            overrideControls
            Text(String(localized: "collection.inspector.sectionDefaults.caption",
                        defaultValue: "Documents in this section use these settings unless they set their own. Default falls through to the collection's composition."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Per-highlight selection (A8)

    /// Whether a highlight is included when highlights apply: an empty
    /// `selectedHighlightIds` means **all** (the pre-override behavior).
    private func highlightIncluded(_ id: UUID) -> Bool {
        entry.selectedHighlightIds.isEmpty || entry.selectedHighlightIds.contains(id)
    }

    /// Writes one highlight's inclusion, keeping the canonical A8 forms: a selection of
    /// every highlight collapses back to the empty set (so future highlights keep
    /// flowing in automatically), and unselecting the last passage turns the entry's
    /// highlight override off — the empty set cannot mean "none", so "none" is
    /// expressed as `applyHighlightsOverride = false` (the row caption says so).
    private func setHighlightIncluded(_ id: UUID, _ include: Bool) {
        let allIds = highlightChoices.map(\.id)
        var selected = entry.selectedHighlightIds.isEmpty ? allIds : entry.selectedHighlightIds
        if include {
            if !selected.contains(id) { selected.append(id) }
        } else {
            selected.removeAll { $0 == id }
        }
        if Set(selected).isSuperset(of: allIds) {
            entry.selectedHighlightIds = []
        } else if selected.isEmpty {
            entry.selectedHighlightIds = []
            entry.applyHighlightsOverride = false
        } else {
            entry.selectedHighlightIds = selected
        }
    }

    // MARK: - Excerpts in this collection (Authoring Phase 5)

    /// The excerpt entries this collection already carries from this document — shown so
    /// the inspector is the one place to see a document's whole contribution. Rows are
    /// read-only here; excerpts are moved and deleted in the collection list itself.
    private var documentExcerpts: [CollectionEntry] {
        (entry.collection?.documentEntries ?? [])
            .filter {
                $0.entryKind == .excerpt
                    && $0.volumeId == entry.volumeId
                    && $0.documentId == entry.documentId
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The "Excerpts in This Collection" section; hidden when there are none.
    @ViewBuilder private var excerptsSection: some View {
        let excerpts = documentExcerpts
        if !excerpts.isEmpty {
            Section(String(localized: "collection.inspector.excerpts",
                           defaultValue: "Excerpts in This Collection")) {
                ForEach(excerpts, id: \.id) { excerpt in
                    Label {
                        Text(excerpt.text ?? "")
                            .font(.callout.italic())
                            .lineLimit(3)
                    } icon: {
                        Image(systemName: "text.quote")
                    }
                }
                Text(String(localized: "collection.inspector.excerpts.caption",
                            defaultValue: "Reorder or delete excerpts in the collection list. Insert new ones from the highlight rows above."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
    /// The heading variant needs only the prompt list for its section-defaults picker.
    private func load() async {
        // Prompt choices power the summary-prompt override picker in both variants.
        let allPrompts = (try? modelContext.fetch(FetchDescriptor<SummarizationPrompt>())) ?? []
        promptChoices = allPrompts.map { PromptChoice(id: $0.id, name: $0.name) }

        guard !isHeading else {
            isLoading = false
            return
        }

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
        highlightChoices = highlights
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            .map { HighlightChoice(id: $0.id,
                                   capture: CollectionExcerpts.capture(from: $0),
                                   color: $0.color) }

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
