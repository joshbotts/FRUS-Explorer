// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI
import SwiftData

// MARK: - ResearchStripView

/// Persistent research action toolbar displayed between the titlebar and the document body.
///
/// Contains: Add to collection · Add note · Tag · Cite (popover) · collapse chevron.
/// Collapses to a "+" re-expand button when `isCollapsed` is true.
///
/// Version history:
///   1.0 — New UI scaffolding
struct ResearchStripView: View {

    let entry: DocumentBrowserEntry?
    @Binding var isCollapsed: Bool
    @Binding var showCitationPopover: Bool

    @Environment(AppState.self) private var appState

    @State private var showAddToCollection: Bool = false
    @State private var showAddNote: Bool = false
    @State private var showTagPicker: Bool = false

    private var isDisabled: Bool { entry == nil }

    var body: some View {
        HStack(spacing: 6) {
            if isCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isCollapsed = false }
                } label: {
                    Image(systemName: "plus.circle").font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.vertical, 5)
                Spacer()
            } else {
                Text("Research")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .padding(.leading, 16)

                ResearchStripButton(
                    title: "Add to collection",
                    systemImage: "folder.badge.plus",
                    isDisabled: isDisabled
                ) { showAddToCollection = true }

                ResearchStripButton(
                    title: "Add note",
                    systemImage: "note.text.badge.plus",
                    isDisabled: isDisabled
                ) { showAddNote = true }

                ResearchStripButton(
                    title: "Tag",
                    systemImage: "tag",
                    isDisabled: isDisabled
                ) { showTagPicker = true }

                // Cite — opens citation popover
                Button {
                    showCitationPopover = true
                } label: {
                    Label("Cite", systemImage: "quote.closing")
                        .font(.system(size: 11))
                        .foregroundStyle(isDisabled ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isDisabled ? Color.clear : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isDisabled ? Color.clear : Color.accentColor.opacity(0.3),
                            lineWidth: 0.5
                        )
                )
                .disabled(isDisabled)
                .popover(isPresented: $showCitationPopover, arrowEdge: .bottom) {
                    if let entry { CitationPopoverView(entry: entry) }
                }

                Spacer()

                // Collapse chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isCollapsed = true }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
            }
        }
        .frame(height: 32)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .sheet(isPresented: $showAddToCollection) {
            // CollectionEditorView(collection: nil) creates a new collection.
            CollectionEditorView(collection: nil)
        }
        .sheet(isPresented: $showAddNote) {
            if let entry {
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId
                )
            }
        }
        .sheet(isPresented: $showTagPicker) {
            if let entry { MacTagPickerSheet(entry: entry) }
        }
    }
}

// MARK: - ResearchStripButton

private struct ResearchStripButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(isDisabled ? .tertiary : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(isDisabled ? 0 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.secondary.opacity(isDisabled ? 0 : 0.2), lineWidth: 0.5)
        )
        .disabled(isDisabled)
    }
}

// MARK: - SummaryBlockView

/// Inline AI summary block rendered within the document body.
///
/// Shows the most recent summary with prompt label and history cycling controls.
/// Collapses to a "Summarize" prompt when no summary exists.
/// Hidden entirely when `SummarizationService` is unavailable.
///
/// Version history:
///   1.0 — New UI scaffolding
struct SummaryBlockView: View {
    @Bindable var vm: DocumentViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showPromptPicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row
            HStack(alignment: .center) {
                Label("AI summary", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.7)

                if vm.activeSummary != nil {
                    Text("· custom prompt")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Button("Change prompt") { showPromptPicker = true }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $showPromptPicker) {
                            SummaryPromptPickerView(vm: vm)
                        }

                    if vm.summaries.count > 1 {
                        Text("·").foregroundStyle(.tertiary).font(.system(size: 10))
                        HStack(spacing: 2) {
                            Button {
                                if vm.activeSummaryIndex < vm.summaries.count - 1 {
                                    vm.activeSummaryIndex += 1
                                }
                            } label: {
                                Image(systemName: "chevron.left").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.activeSummaryIndex >= vm.summaries.count - 1)

                            Text("\(vm.activeSummaryIndex + 1)/\(vm.summaries.count)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)

                            Button {
                                if vm.activeSummaryIndex > 0 { vm.activeSummaryIndex -= 1 }
                            } label: {
                                Image(systemName: "chevron.right").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.activeSummaryIndex <= 0)
                        }
                    }

                    Button("Regenerate") { Task { await regenerateSummary() } }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(vm.isSummarizing)
                }
            }

            // Body
            if vm.isSummarizing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Summarizing…").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            } else if let summary = vm.activeSummary {
                Text(summary.responseText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            } else {
                Button("Summarize this document") { Task { await regenerateSummary() } }
                    .font(.system(size: 13))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func regenerateSummary() async {
        guard let service = appState.summarizationService else { return }
        let provider = AppleIntelligenceProvider.shared
        // Default prompt nil — picked in prompt picker popover.
        // If no prompt is selected, SummarizationService uses the standard prompt.
        if let prompts = try? modelContext.fetch(
            FetchDescriptor<SummarizationPrompt>(sortBy: [SortDescriptor(\.createdAt)])
        ), let prompt = prompts.first {
            await vm.generateSummary(
                prompt: prompt,
                provider: provider,
                service: service,
                activeProjectId: appState.activeProjectId,
                context: modelContext
            )
        }
    }
}

// MARK: - FootnoteSectionView

/// Renders the footnote block at the bottom of a document.
///
/// Each footnote is rendered with its display label and body content.
/// Cross-reference links within footnotes are tappable.
/// The `activeFootnoteLabel` binding highlights a footnote in response
/// to a superscript tap in the document body.
///
/// Version history:
///   1.0 — New UI scaffolding
struct FootnoteSectionView: View {
    let footnotes: [FRUSRenderNode]
    @Binding var activeFootnoteLabel: String?
    let onCrossRefTap: (String, String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("Footnotes")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.7)
                .padding(.bottom, 2)

            ForEach(Array(footnotes.enumerated()), id: \.offset) { _, node in
                if case .footnoteBody(_, _, _, _, let label, let children) = node {
                    // Strip leading/trailing lineBreak and pageBreak nodes that would
                    // otherwise add blank lines at the top and bottom of each footnote.
                    let filteredChildren = children.filter {
                        if case .lineBreak = $0 { return false }
                        if case .pageBreak = $0 { return false }
                        return true
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text(label)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                            .frame(minWidth: 18, alignment: .trailing)
                            .padding(.top, 1)

                        FRUSDocumentRenderer(
                            nodes: filteredChildren,
                            onFootnoteTap: { _ in },
                            onPersonTap: { _ in },
                            onGlossTap: { _ in },
                            onCrossRefTap: onCrossRefTap,
                            // Tighter spacing: footnote paragraphs should
                            // not appear double-spaced like body paragraphs.
                            blockSpacing: 2
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        activeFootnoteLabel == label
                            ? Color.accentColor.opacity(0.06)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - StatusBarView

/// Persistent status bar at the bottom of the main macOS window.
///
/// Three zones:
/// - Left: indexed volume count (stable, low-noise)
/// - Centre: active background task with progress bar and ETA
/// - Right: CloudKit sync state
///
/// Progress is driven by `AppState.currentIndexingProgress` (now cross-platform)
/// and `AppState.downloadQueue`.
///
/// Version history:
///   1.0 — New UI scaffolding
struct StatusBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {

            // Left: index count
            HStack(spacing: 5) {
                Circle()
                    .fill(indexedCount > 0 ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text("\(indexedCount) volume\(indexedCount == 1 ? "" : "s") indexed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Centre: active task
            if let task = activeTask {
                HStack(spacing: 6) {
                    Image(systemName: task.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(task.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let progress = task.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 60)
                            .tint(.green)
                        if let eta = task.eta {
                            Text(eta)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer()

            // Right: sync state
            Label("Synced", systemImage: "checkmark.icloud")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Computed

    private var indexedCount: Int {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return 0 }
        let entries = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return entries.filter {
            dm.isVolumeDownloaded($0.volumeId) &&
            (try? pipeline.isVolumeIndexed($0.volumeId)) == true
        }.count
    }

    private struct ActiveTask {
        let label: String
        let systemImage: String
        let progress: Double?
        let eta: String?
    }

    private var activeTask: ActiveTask? {
        if let update = appState.currentIndexingProgress {
            let progress: Double? = update.totalDocuments > 0
                ? Double(update.completedDocuments) / Double(update.totalDocuments)
                : nil
            let eta: String? = {
                guard update.docsPerSecond > 0,
                      update.totalDocuments > update.completedDocuments else { return nil }
                let remaining = update.totalDocuments - update.completedDocuments
                let seconds = Double(remaining) / update.docsPerSecond
                return "~\(Int(seconds.rounded()))s"
            }()
            return ActiveTask(
                label: "Indexing \(update.volumeId)…",
                systemImage: "square.and.arrow.down",
                progress: progress,
                eta: eta
            )
        }

        if !appState.downloadQueue.isEmpty {
            return ActiveTask(
                label: "\(appState.downloadQueue.count) download\(appState.downloadQueue.count == 1 ? "" : "s") queued",
                systemImage: "arrow.down.circle",
                progress: nil,
                eta: nil
            )
        }

        return nil
    }
}

// MARK: - CitationPopoverView

/// Popover displaying a formatted FRUS citation for the current document.
///
/// Three styles: history.state.gov (default), Chicago, Turabian.
/// Volume editors are sourced from `VolumeManifestEntry.editors`.
/// The general editor is intentionally excluded per history.state.gov guidance.
///
/// Version history:
///   1.0 — New UI scaffolding
struct CitationPopoverView: View {
    let entry: DocumentBrowserEntry

    @Environment(AppState.self) private var appState
    @State private var selectedStyle: CitationPopoverStyle = .historyStateDotGov

    private var volumeEntry: VolumeManifestEntry? {
        appState.manifestStore.entry(forVolumeId: entry.volumeId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Label("Citation", systemImage: "quote.closing")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

            // Document identity
            VStack(alignment: .leading, spacing: 2) {
                Text("Doc \(entry.documentNumber ?? entry.documentId) · \(entry.volumeId)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(entry.header)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }

            // Style picker
            Picker("Style", selection: $selectedStyle) {
                ForEach(CitationPopoverStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Citation text
            Text(formattedCitation)
                .font(.custom("Georgia", size: 12))
                .lineSpacing(4)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
                )

            // Metadata
            if let vol = volumeEntry {
                VStack(alignment: .leading, spacing: 3) {
                    if !vol.editors.isEmpty {
                        metaRow("Volume editors", vol.editors.joined(separator: ", "))
                    }
                    let pubYear: String = {
                        guard let pd = vol.publicationDate else { return "n.d." }
                        let t = pd.trimmingCharacters(in: .whitespaces)
                        if t.count >= 4, Int(t.prefix(4)) != nil { return String(t.prefix(4)) }
                        return "n.d."
                    }()
                    metaRow("Published", "Government Printing Office, \(pubYear)")
                    if let docNum = entry.documentNumber {
                        metaRow("Document no.", docNum)
                    }
                }
                .font(.system(size: 11))
            }

            // Canonical URL
            if let url = canonicalURL {
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(url)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            // Actions
            HStack(spacing: 6) {
                Button {
                    copyToClipboard(formattedCitation)
                } label: {
                    Label("Copy citation", systemImage: "doc.on.doc").font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let url = canonicalURL {
                    Button {
                        copyToClipboard(url)
                    } label: {
                        Label("Copy URL", systemImage: "link").font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    // Zotero export — deferred to future session
                } label: {
                    Label("Zotero", systemImage: "square.and.arrow.up").font(.system(size: 11))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

        }
        .padding(14)
        .frame(width: 440)
    }

    // MARK: - Formatted Citation

    private var formattedCitation: String {
        guard let vol = volumeEntry else {
            return "Citation unavailable — volume metadata not loaded."
        }
        let editors = vol.editors.isEmpty ? nil : "eds. \(vol.editors.joined(separator: " and "))"
        // publicationDate is typically a bare 4-digit year ("2003") or an ISO date.
        // If it looks like a year, use it directly; otherwise fall back to "n.d."
        let year: String = {
            guard let pd = vol.publicationDate else { return "n.d." }
            // Accept bare 4-digit year or ISO date whose first 4 chars are digits.
            let trimmed = pd.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 4, Int(trimmed.prefix(4)) != nil { return String(trimmed.prefix(4)) }
            return "n.d."
        }()
        let docNum = entry.documentNumber.map { "Document \($0)" } ?? entry.documentId
        let urlPart = canonicalURL.map { "\n\($0) [accessed \(accessedDate)]" } ?? ""
        // vol.title already contains the full series name, e.g.
        // "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy"
        // so we use it directly without prepending "Foreign Relations of the United States, [subseries], ".
        let volTitle = vol.title

        switch selectedStyle {
        case .historyStateDotGov:
            return "\"\(entry.header),\" in\u{202F}*\(volTitle)*\(editors.map { ",\n eds. \($0)" } ?? ""), (Washington: Government Printing Office, \(year)), \(docNum).\(urlPart)"

        case .chicago:
            return "\"\(entry.header),\" in *\(volTitle)*\(editors.map { ", \($0)" } ?? ""), (Washington, DC: Government Printing Office, \(year)), \(docNum).\(urlPart)"

        case .turabian:
            return "\"\(entry.header).\" In *\(volTitle)*\(editors.map { ". \($0)" } ?? ""). Washington, DC: Government Printing Office, \(year). \(docNum).\(urlPart)"
        }
    }

    private var canonicalURL: String? {
        "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
    }

    private var accessedDate: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            Text(value).foregroundStyle(.primary)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - CitationPopoverStyle
// Renamed from CitationStyle to avoid conflict with Citation/CitationFormatter.CitationStyle.

private enum CitationPopoverStyle: String, CaseIterable, Identifiable {
    case historyStateDotGov
    case chicago
    case turabian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .historyStateDotGov: return "history.state.gov"
        case .chicago:            return "Chicago"
        case .turabian:           return "Turabian"
        }
    }
}

// MARK: - MacTagPickerSheet

/// macOS document-level user-tag picker.
///
/// Lists all `UserTag` records from SwiftData and lets the user toggle which tags
/// apply to this document. Tags are stored as `userTagIds` on a dedicated
/// `DocumentUserTag` record (note: the full document-level tag persistence model
/// is scaffolded here; complete write-back requires a `DocumentUserTag` SwiftData
/// model to be added in a future session).
struct MacTagPickerSheet: View {
    let entry: DocumentBrowserEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @State private var selectedTagIds: Set<UUID> = []
    @State private var newTagName: String = ""

    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    Section {
                        Text("No user tags yet. Type a name below to create one.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    Section("Your Tags") {
                        ForEach(allTags) { tag in
                            Toggle(isOn: Binding(
                                get: { selectedTagIds.contains(tag.id) },
                                set: { on in
                                    if on { selectedTagIds.insert(tag.id) }
                                    else  { selectedTagIds.remove(tag.id) }
                                }
                            )) {
                                Text(tag.name)
                            }
                        }
                    }
                }

                Section("New Tag") {
                    HStack {
                        TextField("Tag name…", text: $newTagName)
                            .onSubmit { createTag() }
                        Button("Add", action: createTag)
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle("Tags — \(entry.documentNumber.map { "Doc \($0)" } ?? entry.documentId)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 340, minHeight: 300)
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = UserTag(name: name)
        modelContext.insert(tag)
        selectedTagIds.insert(tag.id)
        newTagName = ""
    }
}

struct SummaryPromptPickerView: View {
    @Bindable var vm: DocumentViewModel
    var body: some View { Text("Prompt picker").padding() }
}

// MARK: - PersonDetailSheet (macOS)
// The iOS PersonDetailSheet is private to DocumentView/DocumentView.swift.
// This macOS version is used by MacDocumentView.

struct PersonDetailSheet: View {
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
                            "Mentioned in \(mentionCount) indexed \(mentionCount == 1 ? "document" : "documents")",
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        Button {
                            dismiss()
                            onFindAllMentions()
                        } label: {
                            Label("Find all mentions", systemImage: "magnifyingglass")
                        }
                    } else {
                        Text("Not found in indexed documents")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text("In Indexed Documents")
                }
            }
            .listStyle(.inset)
            .navigationTitle("List of Persons")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - GlossDetailSheet (macOS)

struct GlossDetailSheet: View {
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
            .listStyle(.inset)
            .navigationTitle("Glossary")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 240)
    }
}

// MARK: - CorpusBrowserWindowView

/// Standalone macOS window listing all FRUS subseries and their volumes.
///
/// Uses a `NavigationSplitView`: subseries in the sidebar, volumes in the detail
/// column. Selecting a volume pushes a document list in the detail column.
/// Selecting a document sets `AppState.pendingBrowseDocument`, which
/// `MainWindowView.onChange` consumes and pushes onto the main window's navigation stack.
///
/// Corpus data comes entirely from `AppState.manifestStore` (bundled + live manifest);
/// no download is required to browse the catalogue.
struct CorpusBrowserWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSubseries: String? = nil
    @State private var selectedVolume: VolumeManifestEntry? = nil
    @State private var searchText: String = ""

    private var allEntries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    private var subseries: [String] {
        var seen = Set<String>()
        return allEntries.compactMap { e in
            seen.insert(e.subseries).inserted ? e.subseries : nil
        }.sorted()
    }

    private func volumes(for sub: String) -> [VolumeManifestEntry] {
        allEntries.filter { $0.subseries == sub }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar: subseries list
            List(selection: $selectedSubseries) {
                ForEach(subseries, id: \.self) { sub in
                    let count = volumes(for: sub).count
                    HStack {
                        Text(sub)
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .tag(sub)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Corpus Browser")
            .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        } detail: {
            if let sub = selectedSubseries {
                volumeList(for: sub)
            } else {
                ContentUnavailableView(
                    "Select a Subseries",
                    systemImage: "books.vertical",
                    description: Text("Choose a subseries from the list to browse its volumes.")
                )
            }
        }
        .frame(minWidth: 520, minHeight: 440)
    }

    @ViewBuilder
    private func volumeList(for subseries: String) -> some View {
        let vols = volumes(for: subseries)
        let filtered: [VolumeManifestEntry] = searchText.isEmpty ? vols : vols.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.volumeId.localizedCaseInsensitiveContains(searchText)
        }

        List(filtered) { vol in
            VStack(alignment: .leading, spacing: 2) {
                Text(vol.title)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(vol.volumeId)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if let dm = appState.downloadManager, dm.isVolumeDownloaded(vol.volumeId) {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedVolume = vol
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search volumes…")
        .navigationTitle(subseries)
        .sheet(item: $selectedVolume) { vol in
            CorpusVolumeDocumentListView(volume: vol)
        }
    }
}

// MARK: - CorpusVolumeDocumentListView

/// Sheet presenting the document list for a volume selected in the corpus browser.
/// Tapping a document posts it to `AppState.pendingBrowseDocument` so the main window
/// navigates to it, then dismisses this sheet.
private struct CorpusVolumeDocumentListView: View {
    let volume: VolumeManifestEntry
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var documents: [DocumentBrowserEntry] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading documents…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if documents.isEmpty {
                    ContentUnavailableView(
                        "Volume Not Downloaded",
                        systemImage: "arrow.down.circle",
                        description: Text("Download this volume in Settings → Volume Management to browse its documents.")
                    )
                } else {
                    List(documents, id: \.documentId) { doc in
                        Button {
                            appState.pendingBrowseDocument = doc
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                if let num = doc.documentNumber {
                                    Text("Document \(num)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Text(doc.header.isEmpty ? doc.documentId : doc.header)
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle(volume.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 400)
        .task { await loadDocuments() }
    }

    private func loadDocuments() async {
        guard let pipeline = appState.indexingPipeline else {
            isLoading = false
            return
        }
        documents = (try? await pipeline.documents(forVolume: volume.volumeId)) ?? []
        isLoading = false
    }
}

struct CrossReferenceGraphWindowView: View {
    var body: some View {
        Text("Cross-Reference Graph")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SourceExplorerWindowView: View {
    var body: some View {
        Text("Source Explorer")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif // os(macOS)
