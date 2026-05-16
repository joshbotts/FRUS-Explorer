// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - DocumentView

/// Renders a single FRUS document using the TEI rendering pipeline.
///
/// ## Layout (top to bottom)
/// 1. Toolbar — research note, user tag, collection, citation, cross-reference, summarize actions
/// 2. Summary strip — active generated summary with "View others" control and chunked indicator
/// 3. Document body — `FRUSDocumentRenderer` with persName/gloss/ref callbacks
/// 4. Tag section — subject tag chips and user tag chips
/// 5. Cross-project note indicator — disclosure if notes from other projects exist
///
/// ## Accessibility
/// - Tag chips use the resolved pattern `"\(name), subject tag"` per spec §18.
/// - VoiceOver reading order: natural document order (header → dateline → body → tags).
///
/// ## Open Questions (resolved for Session 12)
/// - VoiceOver label: `"\(tagName), subject tag"` — confirmed by the spec note in §18.
/// - Reading order: natural SwiftUI layout order, top-to-bottom.
///
/// Version history:
///   1.0 — Session 12: initial implementation
///   1.1 — Session 20: add summarize toolbar button, prompt picker sheet, wasChunked indicator
///   1.2 — Session 23: add source explorer toolbar button and sheet
///   1.3 — Session 27: Q5 curated badge icon; Q1 confidence-aware a11y label; tag hint
///   1.4 — Session 40: personMentionStore wired; PersonDetailSheet gains mention count + Find all mentions
///   1.5 — Session 44: handleCrossRefTap wired cross-platform via pendingBrowseDocument
struct DocumentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let entry: DocumentBrowserEntry

    @State private var vm: DocumentViewModel?
    @State private var showGraph = false

    var body: some View {
        Group {
            if let vm {
                loadedView(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { bootstrapViewModel() }
        .navigationTitle(entry.header)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Bootstrap

    private func bootstrapViewModel() {
        guard vm == nil else { return }
        let allVolumes = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let volumeEntry = allVolumes.first { $0.volumeId == entry.volumeId }
        vm = DocumentViewModel(
            entry: entry,
            volumeEntry: volumeEntry,
            parser: FRUSDocumentParser(),
            subjectTagStore: appState.subjectTagStore,
            personMentionStore: appState.personMentionStore
        )
        guard let vm else { return }
        guard let dm = appState.downloadManager,
              dm.isVolumeDownloaded(entry.volumeId) else { return }
        let url = dm.volumeURL(for: entry.volumeId)
        Task {
            await vm.load(volumeURL: url)
            if vm.renderModel != nil {
                vm.recordReadingHistory(projectId: appState.activeProjectId, in: modelContext)
                vm.loadSummaries(context: modelContext)
                vm.refreshCrossProjectNoteCount(
                    activeProjectId: appState.activeProjectId, context: modelContext
                )
            }
        }
    }

    // MARK: - Loaded View

    @ViewBuilder
    private func loadedView(vm: DocumentViewModel) -> some View {
        if vm.isLoading {
            ProgressView(String(localized: "document.loading", defaultValue: "Loading document…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.loadError {
            ContentUnavailableView(
                String(localized: "document.error.title", defaultValue: "Failed to Load"),
                systemImage: "exclamationmark.triangle",
                description: Text(err.localizedDescription)
            )
        } else if let model = vm.renderModel {
            documentContent(vm: vm, model: model)
        }
    }

    // MARK: - Document Content

    @ViewBuilder
    private func documentContent(vm: DocumentViewModel, model: FRUSDocumentRenderModel) -> some View {
        @Bindable var vm = vm
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Summary strip
                if let summary = vm.activeSummary {
                    SummaryStripView(
                        vm: vm,
                        summary: summary,
                        totalCount: vm.summaries.count
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)
                    Divider()
                }

                // Document body
                FRUSDocumentRenderer(
                    model: model,
                    onPersNameTap: { person in vm.selectedPerson = person },
                    onGlossTap:    { entry in vm.selectedGloss = entry },
                    onCrossRefTap: { target, targetVolumeId in
                        handleCrossRefTap(target: target, targetVolumeId: targetVolumeId)
                    }
                )

                Divider().padding(.horizontal)

                // Tag chips
                DocumentTagSection(vm: vm)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                // Cross-project note indicator
                if !vm.crossProjectNotes.isEmpty {
                    CrossProjectNoteIndicator(
                        notes: vm.crossProjectNotes,
                        activeProjectId: appState.activeProjectId,
                        onPromote: { note in
                            guard let pid = appState.activeProjectId else { return }
                            note.projectIds = note.projectIds + [pid]
                            vm.refreshCrossProjectNoteCount(
                                activeProjectId: appState.activeProjectId,
                                context: modelContext
                            )
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
        }
        .toolbar { documentToolbar(vm: vm) }
        .sheet(item: $vm.selectedPerson) { person in
            PersonDetailSheet(
                person: person,
                mentionCount: vm.selectedPersonMentionCount,
                onFindAllMentions: {
                    vm.selectedPerson = nil
                    appState.pendingSearch = SearchParameters(personRef: person.ref)
                }
            )
        }
        .task(id: vm.selectedPerson?.ref) {
            guard let person = vm.selectedPerson else { return }
            await vm.loadPersonMentionCount(for: person)
        }
        .sheet(item: $vm.selectedGloss) { gloss in
            GlossDetailSheet(gloss: gloss)
        }
        .sheet(isPresented: $vm.showCitationSheet) {
            if let citation = vm.formattedCitation {
                CitationSheetView(citation: citation)
            }
        }
        .sheet(isPresented: $vm.showNoteEditor) {
            ResearchNoteEditorView(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                activeProjectId: appState.activeProjectId
            )
        }
        .sheet(isPresented: $showGraph) {
            if let store = appState.crossReferenceStore {
                CrossReferenceGraphView(
                    entry: entry,
                    crossReferenceStore: store,
                    downloadedVolumeIds: downloadedVolumeIds
                )
            }
        }
        .sheet(isPresented: $vm.showSummarizeSheet) {
            SummarizationPromptPickerSheet(
                vm: vm,
                service: appState.summarizationService,
                activeProjectId: appState.activeProjectId
            )
        }
        .sheet(isPresented: $vm.showSourceExplorer) {
            if let note = vm.sourceNote {
                SourceExplorerView(rawSourceNote: note)
            }
        }
    }

    private var downloadedVolumeIds: Set<String> {
        guard let dm = appState.downloadManager else { return [] }
        let known = appState.manifestStore.diffResult?.known ?? []
        return Set(known.compactMap { dm.isVolumeDownloaded($0.volumeId) ? $0.volumeId : nil })
    }

    // MARK: - Cross-Reference Navigation

    /// Resolves a cross-reference `<ref>` tap to document navigation.
    ///
    /// Extracts the document ID from `target` (strips a leading `#` or takes the
    /// fragment after `#`). Determines the target volume from `targetVolumeId` if
    /// provided, otherwise falls back to the current document's volume.
    ///
    /// If the target volume is not downloaded, falls back to the cross-reference
    /// graph sheet (`showGraph = true`). Otherwise:
    /// - **iOS**: sets `appState.activeTab = .browse` so the Browse tab comes to
    ///   the foreground, then writes `appState.pendingBrowseDocument`.
    /// - **macOS**: writes `appState.pendingBrowseDocument` directly.
    ///
    /// `BrowserView.onChange(of: appState.pendingBrowseDocument)` observes the write
    /// and appends the entry to the navigation stack/split-view path.
    ///
    /// The `DocumentBrowserEntry` is constructed with an empty `header` because the
    /// document title is not known until the XML is parsed. `DocumentView` repopulates
    /// the navigation title from the AST on load — the placeholder is visible only
    /// during the push animation.
    ///
    /// Version history:
    ///   1.0 — Session 44: initial implementation
    private func handleCrossRefTap(target: String, targetVolumeId: String?) {
        let docId: String
        if target.hasPrefix("#") {
            docId = String(target.dropFirst())
        } else {
            docId = target.components(separatedBy: "#").last ?? target
        }
        guard !docId.isEmpty else { return }
        let volId = targetVolumeId ?? entry.volumeId

        guard let dm = appState.downloadManager, dm.isVolumeDownloaded(volId) else {
            showGraph = true
            #if DEBUG
            print("[DocumentView] Cross-ref: \(volId) not downloaded, opening graph")
            #endif
            return
        }

        let crossEntry = DocumentBrowserEntry(
            documentId: docId,
            volumeId: volId,
            documentNumber: nil,
            header: "",
            dateline: nil,
            sourceNote: nil
        )
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        appState.pendingBrowseDocument = crossEntry

        #if DEBUG
        print("[DocumentView] Cross-ref tap → \(volId)/\(docId)")
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func documentToolbar(vm: DocumentViewModel) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Add research note
            Button {
                vm.showNoteEditor = true
            } label: {
                Label(
                    String(localized: "document.toolbar.addNote", defaultValue: "Add Research Note"),
                    systemImage: "note.text.badge.plus"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.addNote.a11y", defaultValue: "Add research note")
            )

            // Add user tag
            Button {
                // Wired in Session 14
            } label: {
                Label(
                    String(localized: "document.toolbar.addTag", defaultValue: "Tag Document"),
                    systemImage: "tag"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.addTag.a11y", defaultValue: "Tag document")
            )

            // Citation
            Menu {
                Button {
                    vm.showCitationSheet = true
                } label: {
                    Label(
                        String(localized: "document.toolbar.viewCitation", defaultValue: "View Citation"),
                        systemImage: "doc.text"
                    )
                }
                .disabled(vm.formattedCitation == nil)
                Button {
                    if let citation = vm.formattedCitation {
                        copyToPasteboard(citation)
                    }
                } label: {
                    Label(
                        String(localized: "document.toolbar.copyCitation", defaultValue: "Copy Citation"),
                        systemImage: "doc.on.clipboard"
                    )
                }
                .disabled(vm.formattedCitation == nil)
            } label: {
                Label(
                    String(localized: "document.toolbar.citation", defaultValue: "Citation"),
                    systemImage: "quote.opening"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.citation.a11y", defaultValue: "Citation options")
            )

            // Source Explorer — only shown when a source note is present
            if vm.sourceNote != nil {
                Button {
                    vm.showSourceExplorer = true
                } label: {
                    Label(
                        String(localized: "document.toolbar.sourceExplorer",
                               defaultValue: "Source Explorer"),
                        systemImage: "archivebox"
                    )
                }
                .accessibilityLabel(
                    String(localized: "document.toolbar.sourceExplorer.a11y",
                           defaultValue: "Open NARA Source Explorer")
                )
            }

            // Cross-references
            Button {
                showGraph = true
            } label: {
                Label(
                    String(localized: "document.toolbar.crossRef", defaultValue: "Cross-References"),
                    systemImage: "arrow.triangle.branch"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.crossRef.a11y", defaultValue: "Explore cross-references")
            )

            // Summarize — only shown when Apple Intelligence is available
            if appState.summarizationService != nil
                && AppleIntelligenceProvider.shared.isAvailable {
                Button {
                    vm.showSummarizeSheet = true
                } label: {
                    if vm.isSummarizing {
                        ProgressView()
                    } else {
                        Label(
                            String(localized: "document.toolbar.summarize",
                                   defaultValue: "Summarize"),
                            systemImage: "sparkles"
                        )
                    }
                }
                .disabled(vm.isSummarizing || vm.documentPlainText.isEmpty)
                .accessibilityLabel(
                    String(localized: "document.toolbar.summarize.a11y",
                           defaultValue: "Generate AI summary")
                )
            }
        }
    }

    // MARK: - Clipboard

    private func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - CitationSheetView

private struct CitationSheetView: View {
    let citation: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(citation)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(
                String(localized: "document.citation.title", defaultValue: "Citation")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.sheet.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SummaryStripView

private struct SummaryStripView: View {
    @Bindable var vm: DocumentViewModel
    let summary: GeneratedSummary
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(
                    String(localized: "document.summary.label", defaultValue: "Summary"),
                    systemImage: "sparkles"
                )
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                Spacer()
                if totalCount > 1 {
                    Button {
                        vm.activeSummaryIndex = (vm.activeSummaryIndex + 1) % totalCount
                    } label: {
                        Text(String(localized: "document.summary.next",
                                    defaultValue: "Next"))
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        String(localized: "document.summary.next.a11y",
                               defaultValue: "View next summary")
                    )
                }
            }
            Text(summary.responseText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            if summary.wasChunked {
                Label(
                    String(localized: "document.summary.chunked",
                           defaultValue: "Summarized in sections"),
                    systemImage: "info.circle"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - SummarizationPromptPickerSheet

private struct SummarizationPromptPickerSheet: View {
    let vm: DocumentViewModel
    let service: SummarizationService?
    let activeProjectId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    var body: some View {
        NavigationStack {
            List {
                ForEach(allPrompts) { prompt in
                    Button {
                        dismiss()
                        guard let service else { return }
                        Task {
                            await vm.generateSummary(
                                prompt: prompt,
                                provider: AppleIntelligenceProvider.shared,
                                service: service,
                                activeProjectId: activeProjectId,
                                context: modelContext
                            )
                        }
                    } label: {
                        PromptPickerRow(prompt: prompt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(
                String(localized: "document.summarize.picker.title",
                       defaultValue: "Choose a Prompt")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "document.summarize.picker.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if allPrompts.isEmpty {
                    ContentUnavailableView(
                        String(localized: "document.summarize.picker.empty.title",
                               defaultValue: "No Prompts"),
                        systemImage: "sparkles",
                        description: Text(
                            String(localized: "document.summarize.picker.empty.detail",
                                   defaultValue: "Add a prompt in Settings → Summarization Prompts.")
                        )
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - PromptPickerRow

private struct PromptPickerRow: View {
    let prompt: SummarizationPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(prompt.name).font(.body)
                if prompt.isStandard {
                    Text(String(localized: "prompt.picker.row.standard",
                                defaultValue: "Standard"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(formatLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var formatLabel: String {
        switch prompt.responseFormat {
        case .general:
            return String(localized: "prompt.picker.row.format.general",
                          defaultValue: "General prose")
        case .structured(let schema):
            let names = schema.fields.map(\.name).joined(separator: ", ")
            return String(localized: "prompt.picker.row.format.structured",
                          defaultValue: "Structured: \(names)")
        }
    }
}

// MARK: - DocumentTagSection

private struct DocumentTagSection: View {
    let vm: DocumentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !vm.subjectTags.isEmpty {
                subjectTagChips
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var subjectTagChips: some View {
        Text(String(localized: "document.tags.subject.header", defaultValue: "Subject Tags"))
            .font(.caption.bold())
            .foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(vm.subjectTags) { tag in
                    DocumentTagChip(tag: tag)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - DocumentTagChip

private struct DocumentTagChip: View {
    let tag: SubjectTag

    var body: some View {
        Button {
            // Wired in Session 16 (Search View) — tap navigates to search filtered by tag
        } label: {
            HStack(spacing: 4) {
                Text(tag.displayName)
                    .font(.caption)
                // Q5: non-color distinction between curated (checkmark) and string-match (question mark)
                if tag.confidence == .curated {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tagBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        // Q1: "<name>, subject tag" — .isButton trait appends "button" in VoiceOver announcement
        // Q5: label distinguishes confidence tier for low-sighted users
        .accessibilityLabel(tag.confidence == .curated
            ? "\(tag.displayName), subject tag"
            : "\(tag.displayName), approximate subject tag match")
        .accessibilityHint(String(localized: "document.tag.chip.hint",
                                  defaultValue: "Filters search results by this tag"))
        .accessibilityAddTraits(.isButton)
    }

    private var tagBackground: Color {
        switch tag.category {
        case .people: return Color.blue.opacity(0.12)
        case .places: return Color.green.opacity(0.12)
        case .topics: return Color.orange.opacity(0.12)
        }
    }
}

// MARK: - CrossProjectNoteIndicator

private struct CrossProjectNoteIndicator: View {
    let notes: [ResearchNote]
    let activeProjectId: UUID?
    let onPromote: (ResearchNote) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                    Text("\(notes.count) notes from other projects")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(notes.count) research notes from other projects")
            .accessibilityHint(
                isExpanded
                    ? String(localized: "document.crossProject.collapse.hint",
                             defaultValue: "Collapse")
                    : String(localized: "document.crossProject.expand.hint",
                             defaultValue: "Expand to reveal")
            )

            if isExpanded {
                if activeProjectId != nil {
                    ForEach(notes, id: \.id) { note in
                        CrossProjectNoteRow(note: note, onPromote: { onPromote(note) })
                    }
                } else {
                    Text(String(localized: "document.crossProject.detail",
                                defaultValue: "Switch projects to view these notes."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 24)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - CrossProjectNoteRow

private struct CrossProjectNoteRow: View {
    let note: ResearchNote
    let onPromote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if note.bodyText.isEmpty {
                Text(String(localized: "document.crossProject.emptyNote",
                            defaultValue: "Empty note"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(note.bodyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(String(localized: "document.crossProject.promote",
                          defaultValue: "Add to project")) {
                onPromote()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .accessibilityLabel(
                String(localized: "document.crossProject.promote.a11y",
                       defaultValue: "Add this note to the current project")
            )
        }
        .padding(.leading, 24)
        .padding(.vertical, 4)
    }
}

// MARK: - PersonDetailSheet

private struct PersonDetailSheet: View {
    let person: PersonEntry
    let mentionCount: Int
    let onFindAllMentions: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(person.name).font(.headline)
                    if let desc = person.description {
                        Text(desc).font(.body).foregroundStyle(.secondary)
                    }
                }

                Section {
                    if mentionCount > 0 {
                        Label(
                            String(
                                localized: "document.persons.mentionCount",
                                defaultValue: "Mentioned in \(mentionCount) indexed \(mentionCount == 1 ? "document" : "documents")"
                            ),
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                        Button {
                            dismiss()
                            onFindAllMentions()
                        } label: {
                            Label(
                                String(localized: "document.persons.findAll",
                                       defaultValue: "Find all mentions"),
                                systemImage: "magnifyingglass"
                            )
                        }
                        .accessibilityLabel(
                            String(localized: "document.persons.findAll.a11y",
                                   defaultValue: "Find all documents mentioning this person")
                        )
                    } else {
                        Text(String(localized: "document.persons.noMentions",
                                    defaultValue: "Not found in indexed documents"))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text(String(localized: "document.persons.section.indexed",
                                defaultValue: "In Indexed Documents"))
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle(
                String(localized: "document.persons.title", defaultValue: "List of Persons")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.sheet.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - GlossDetailSheet

private struct GlossDetailSheet: View {
    let gloss: GlossEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(gloss.term).font(.headline)
                    if let def = gloss.definition {
                        Text(def).font(.body).foregroundStyle(.secondary)
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle(
                String(localized: "document.terms.title", defaultValue: "Terms and Abbreviations")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.sheet.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
