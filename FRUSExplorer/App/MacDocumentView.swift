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

/// Displays a single FRUS document in the main macOS window.
///
/// ## Content Regions (top to bottom)
/// 1. Document identity line (doc number, volume ID, editorial note badge)
/// 2. Document body rendered by `FRUSDocumentRenderer` (macOS node-based renderer)
/// 3. Inline AI summary block (Apple Intelligence, collapsible)
/// 4. Footnote section (numbered, rendered by `FootnoteSectionView`)
/// 5. Tag row (system subject tags + user tags)
/// 6. Volume navigation (prev / next document in volume)
///
/// ## Navigation
/// Prev/next navigation appends to `navigationPath` (owned by `MainWindowView`) so
/// the back button history is preserved. Cross-reference link taps set
/// `AppState.pendingBrowseDocument`, which `MainWindowView.onChange` consumes and
/// appends to the path.
///
/// ## Session 68c Note
/// The new macOS architecture uses `NavigationStack` (not `NavigationSplitView`), so
/// each navigation push creates a fresh view instance with fresh `@State`. The
/// `task(id:)` pattern from Session 68c is not needed here — `loadDocument()` is
/// called once per view lifetime via a plain `.task {}`.
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; replaces BrowserView-centric architecture)
@MainActor
struct MacDocumentView: View {

    let entry: DocumentBrowserEntry
    @Binding var navigationPath: [DocumentBrowserEntry]

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var vm: DocumentViewModel
    @State private var activeFootnoteLabel: String? = nil
    @State private var prevEntry: DocumentBrowserEntry? = nil
    @State private var nextEntry: DocumentBrowserEntry? = nil
    @State private var sourceExplorerItem: IdentifiableSourceNote? = nil

    // MARK: - Init

    init(entry: DocumentBrowserEntry, navigationPath: Binding<[DocumentBrowserEntry]>) {
        self.entry = entry
        self._navigationPath = navigationPath
        // DocumentViewModel constructed here; services injected in .task below
        // because @Environment is not accessible at init time.
        self._vm = State(initialValue: DocumentViewModel(
            entry: entry,
            volumeEntry: nil,
            parser: FRUSDocumentParser(),
            subjectTagStore: SubjectTagStore()
        ))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            // VStack (not LazyVStack) so each child receives a concrete width
            // proposal, allowing FlowLayout to correctly reflow inline text.
            VStack(alignment: .leading, spacing: 0) {

                // Identity line
                documentIdentityView
                    .padding(.bottom, 6)

                // Document body + footnotes + summary
                if let renderModel = vm.renderModel {
                    FRUSDocumentRenderer(
                        nodes: renderModel.bodyNodes,
                        onFootnoteTap: { label in activeFootnoteLabel = label },
                        onPersonTap: { person in
                            vm.selectedPerson = person
                            if let person { handlePersonTap(person) }
                        },
                        onGlossTap: { entry in
                            if let entry { handleGlossTap(entry) }
                        },
                        onCrossRefTap: { target, volumeId in
                            handleCrossRefTap(target: target, volumeId: volumeId)
                        }
                    )
                    .padding(.bottom, 20)

                    // Inline summary block
                    if appState.summarizationService != nil {
                        SummaryBlockView(vm: vm)
                            .padding(.bottom, 24)
                    }

                    // Footnote section
                    if !renderModel.footnotes.isEmpty {
                        FootnoteSectionView(
                            footnotes: renderModel.footnotes,
                            activeFootnoteLabel: $activeFootnoteLabel,
                            onCrossRefTap: { target, volumeId in
                                handleCrossRefTap(target: target, volumeId: volumeId)
                            }
                        )
                        .padding(.bottom, 20)
                    }
                } else if vm.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity)
                } else if let error = vm.loadError {
                    ContentUnavailableView(
                        "Could not load document",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                    .padding(.top, 40)
                }

                // Volume navigation
                volumeNavigationView
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.top, 28)
        }
        .task { await loadDocument() }
        .toolbar {
            if let sourceNote = vm.sourceNote {
                ToolbarItem {
                    Button {
                        sourceExplorerItem = IdentifiableSourceNote(note: sourceNote)
                    } label: {
                        Label(
                            String(localized: "document.toolbar.sourceExplorer",
                                   defaultValue: "Source Explorer"),
                            systemImage: "archivebox"
                        )
                    }
                    .help(String(localized: "document.toolbar.sourceExplorer",
                                 defaultValue: "Source Explorer"))
                }
            }
        }
        // Source Explorer sheet
        .sheet(item: $sourceExplorerItem) { item in
            MacSourceExplorerView(rawSourceNote: item.note)
        }
        // Person sheet
        .sheet(item: $vm.selectedPerson) { person in
            PersonDetailSheet(
                person: person,
                mentionCount: vm.selectedPersonMentionCount,
                onFindAllMentions: {
                    appState.pendingSearch = SearchParameters(personRef: person.ref)
                }
            )
        }
        // Gloss sheet
        .sheet(item: $vm.selectedGloss) { gloss in
            GlossDetailSheet(gloss: gloss)
        }
    }

    // MARK: - Document Identity

    private var documentIdentityView: some View {
        HStack(spacing: 8) {
            if let docNum = entry.documentNumber {
                Text("Document \(docNum)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            Text(entry.volumeId)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if entry.isEditorialNote {
                EditorialNoteBadge()
            }
        }
    }

    // MARK: - Volume Navigation

    private var volumeNavigationView: some View {
        HStack {
            if let prev = prevEntry {
                Button {
                    navigationPath.append(prev)
                } label: {
                    Label(
                        "Doc \(prev.documentNumber ?? prev.documentId)",
                        systemImage: "chevron.left"
                    )
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            if let volumeEntry = appState.manifestStore.entry(forVolumeId: entry.volumeId) {
                Text(
                    "\(entry.documentNumber.map { "Doc \($0)" } ?? entry.documentId) " +
                    "of \(volumeEntry.documentCount) in this volume"
                )
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }

            Spacer()

            if let next = nextEntry {
                Button {
                    navigationPath.append(next)
                } label: {
                    Label(
                        "Doc \(next.documentNumber ?? next.documentId)",
                        systemImage: "chevron.right"
                    )
                    .font(.system(size: 11))
                    .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadDocument() async {
        guard let dm = appState.downloadManager else { return }
        let volumeURL = dm.volumeURL(for: entry.volumeId)

        let volumeEntry = appState.manifestStore.entry(forVolumeId: entry.volumeId)
        vm = DocumentViewModel(
            entry: entry,
            volumeEntry: volumeEntry,
            parser: FRUSDocumentParser(),
            subjectTagStore: appState.subjectTagStore,
            personMentionStore: appState.personMentionStore
        )

        await vm.load(volumeURL: volumeURL)
        vm.recordReadingHistory(projectId: appState.activeProjectId, in: modelContext)
        vm.loadSummaries(context: modelContext)
        vm.refreshCrossProjectNoteCount(
            activeProjectId: appState.activeProjectId,
            context: modelContext
        )

        // Load adjacent entries for prev/next navigation buttons.
        if let pipeline = appState.indexingPipeline {
            if let docs = try? await pipeline.documents(forVolume: entry.volumeId),
               let idx = docs.firstIndex(where: { $0.documentId == entry.documentId }) {
                prevEntry = idx > 0 ? docs[idx - 1] : nil
                nextEntry = idx + 1 < docs.count ? docs[idx + 1] : nil
            }
        }

        #if DEBUG
        print("[MacDocumentView] Loaded \(entry.volumeId)/\(entry.documentId)")
        #endif
    }

    private func handleCrossRefTap(target: String, volumeId: String?) {
        let stripped = target.hasPrefix("#") ? String(target.dropFirst()) : target
        let lower = stripped.lowercased()

        // Skip non-document anchors: external URLs, page refs, footnote anchors,
        // and figure/table refs that encode position rather than a document ID.
        guard !stripped.hasPrefix("http"),
              !lower.hasPrefix("page"),
              !lower.hasPrefix("pg"),
              !lower.hasPrefix("fn"),
              !lower.hasPrefix("note"),
              !lower.hasPrefix("fig"),
              !lower.hasPrefix("tbl"),
              !stripped.isEmpty
        else {
            #if DEBUG
            print("[MacDocumentView] Cross-ref skipped (non-document target): \(target)")
            #endif
            return
        }

        let resolvedVolumeId = volumeId ?? entry.volumeId
        let dest = DocumentBrowserEntry(
            documentId: stripped,
            volumeId: resolvedVolumeId,
            // Use stripped ID as placeholder header — loadDocument() fills the real title
            // after parsing, matching the breadcrumb approach.
            header: stripped
        )
        navigationPath.append(dest)

        #if DEBUG
        print("[MacDocumentView] Cross-ref tap → \(resolvedVolumeId)/\(stripped)")
        #endif
    }

    private func handlePersonTap(_ person: PersonEntry) {
        vm.selectedPerson = person
        // Mention count loaded by .task(id: vm.selectedPerson?.ref) in future session.
    }

    private func handleGlossTap(_ gloss: GlossEntry) {
        vm.selectedGloss = gloss
    }

}

// MARK: - EditorialNoteBadge

private struct EditorialNoteBadge: View {
    var body: some View {
        Text("Editorial note")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.purple.opacity(0.12))
            .foregroundStyle(.purple)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - TagRowView

/// Displays system subject tags and user-defined tags for a document.
struct TagRowView: View {
    let systemTags: [SubjectTag]
    let userTags: [UserTag]

    var body: some View {
        if systemTags.isEmpty && userTags.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(systemTags) { tag in
                        TagChip(label: tag.displayName, style: .system)
                    }
                    ForEach(userTags) { tag in
                        TagChip(label: "◆ \(tag.name)", style: .user)
                    }
                }
            }
        )
    }
}

private struct TagChip: View {
    enum Style { case system, user }
    let label: String
    let style: Style

    var body: some View {
        Text(label)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                style == .user
                    ? Color.accentColor.opacity(0.12)
                    : Color.secondary.opacity(0.10)
            )
            .foregroundStyle(style == .user ? Color.accentColor : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        style == .user
                            ? Color.accentColor.opacity(0.3)
                            : Color.secondary.opacity(0.2),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - TrailingIconLabelStyle

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: - IdentifiableSourceNote

/// `Identifiable` wrapper around a raw source note string for use with `.sheet(item:)`.
private struct IdentifiableSourceNote: Identifiable {
    let id = UUID()
    let note: String
}

#endif // os(macOS)
