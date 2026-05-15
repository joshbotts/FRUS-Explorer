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
/// 1. Toolbar — research note, user tag, collection, citation, cross-reference actions
/// 2. Summary strip — active generated summary with "View others" control
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
struct DocumentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let entry: DocumentBrowserEntry

    @State private var vm: DocumentViewModel?

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
        vm = DocumentViewModel(
            entry: entry,
            parser: FRUSDocumentParser(),
            subjectTagStore: appState.subjectTagStore
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
                    onCrossRefTap: { _, _ in }
                )

                Divider().padding(.horizontal)

                // Tag chips
                DocumentTagSection(vm: vm)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                // Cross-project note indicator
                if vm.crossProjectNoteCount > 0 {
                    CrossProjectNoteIndicator(count: vm.crossProjectNoteCount)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
            }
        }
        .toolbar { documentToolbar(vm: vm) }
        .sheet(item: $vm.selectedPerson) { person in
            PersonDetailSheet(person: person)
        }
        .sheet(item: $vm.selectedGloss) { gloss in
            GlossDetailSheet(gloss: gloss)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func documentToolbar(vm: DocumentViewModel) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Add research note
            Button {
                // Wired in Session 14
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
                    // Wired in Session 13
                } label: {
                    Label(
                        String(localized: "document.toolbar.viewCitation", defaultValue: "View Citation"),
                        systemImage: "doc.text"
                    )
                }
                Button {
                    // Wired in Session 13
                } label: {
                    Label(
                        String(localized: "document.toolbar.copyCitation", defaultValue: "Copy Citation"),
                        systemImage: "doc.on.clipboard"
                    )
                }
            } label: {
                Label(
                    String(localized: "document.toolbar.citation", defaultValue: "Citation"),
                    systemImage: "quote.opening"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.citation.a11y", defaultValue: "Citation options")
            )

            // Cross-references
            Button {
                // Wired in Session 17 (Cross-Reference Graph)
            } label: {
                Label(
                    String(localized: "document.toolbar.crossRef", defaultValue: "Cross-References"),
                    systemImage: "arrow.triangle.branch"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.crossRef.a11y", defaultValue: "Explore cross-references")
            )
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
        }
        .padding(.vertical, 8)
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
                if tag.confidence == .stringMatch {
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
        // Resolved accessibility pattern per spec §18: "<name>, subject tag"
        .accessibilityLabel("\(tag.displayName), subject tag")
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
    let count: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                    Text("\(count) notes from other projects")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(count) research notes from other projects")
            .accessibilityHint(
                isExpanded
                    ? String(localized: "document.crossProject.collapse.hint",
                             defaultValue: "Collapse")
                    : String(localized: "document.crossProject.expand.hint",
                             defaultValue: "Expand to reveal")
            )

            if isExpanded {
                Text(String(localized: "document.crossProject.detail",
                            defaultValue: "Switch projects to view these notes."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - PersonDetailSheet

private struct PersonDetailSheet: View {
    let person: PersonEntry
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
