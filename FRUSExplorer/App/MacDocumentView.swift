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
///   1.1 — Session 91: removed private EditorialNoteBadge and TagChip; now uses
///          shared FRUSTheme components (EditorialNoteBadge, FRUSTagChip)
///   1.2 — Session 100: logEvent(.documentOpen) in .task
///   1.3 — Session 103: highlight mode toolbar toggle + DocumentHighlightTextView +
///          color-picker popover + DocumentHighlight SwiftData insertion
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

    // MARK: Highlight Mode
    @State private var showHighlightMode = false
    @State private var highlightTextSelection: NSRange? = nil
    @State private var showHighlightColorPicker = false

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
        Group {
            if showHighlightMode {
                highlightModeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                normalModeScrollView
            }
        }
        .task {
            await loadDocument()
            appState.logEvent(.documentOpen(
                volumeId: entry.volumeId,
                documentId: entry.documentId,
                title: entry.header.isEmpty ? entry.documentId : entry.header
            ))
        }
        .userActivity(AppActivityTypes.document, element: entry) { entry, activity in
            activity.title = entry.header.isEmpty ? entry.documentId : entry.header
            activity.userInfo = ["volumeId": entry.volumeId, "documentId": entry.documentId]
            activity.isEligibleForHandoff = true
        }
        .sheet(item: $vm.selectedPerson) { person in
            PersonDetailSheet(
                person: person,
                mentionCount: vm.selectedPersonMentionCount,
                onFindAllMentions: {
                    appState.pendingSearch = SearchParameters(personRef: person.ref)
                }
            )
        }
        .sheet(item: $vm.selectedGloss) { gloss in
            GlossDetailSheet(gloss: gloss)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleHighlightMode) {
                    Image(systemName: showHighlightMode
                          ? "pencil.tip.crop.circle.fill"
                          : "pencil.tip.crop.circle")
                }
                .help(showHighlightMode
                      ? String(localized: "doc.highlightMode.exit",
                               defaultValue: "Exit Highlight Mode")
                      : String(localized: "doc.highlightMode.enter",
                               defaultValue: "Highlight Mode"))
                .disabled(vm.renderModel == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showHighlightColorPicker = true
                } label: {
                    Image(systemName: "paintbrush.pointed")
                }
                .help(String(localized: "doc.createHighlight",
                             defaultValue: "Create Highlight"))
                .disabled(!showHighlightMode || (highlightTextSelection?.length ?? 0) == 0)
                .opacity(showHighlightMode ? 1 : 0)
                .popover(isPresented: $showHighlightColorPicker) {
                    highlightColorPicker
                }
            }
        }
    }

    // MARK: - Normal Mode

    private var normalModeScrollView: some View {
        ScrollView {
            // VStack (not LazyVStack) so each child receives a concrete width
            // proposal, allowing FlowLayout to correctly reflow inline text.
            VStack(alignment: .leading, spacing: 0) {

                documentIdentityView
                    .padding(.bottom, 6)

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

                    if appState.summarizationService != nil {
                        SummaryBlockView(vm: vm)
                            .padding(.bottom, 24)
                    }

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

                volumeNavigationView
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.top, 28)
        }
    }

    // MARK: - Highlight Mode

    @ViewBuilder
    private var highlightModeContent: some View {
        if let renderModel = vm.renderModel {
            VStack(spacing: 0) {
                documentIdentityView
                    .padding(.horizontal, 48)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                Divider()
                DocumentHighlightTextView(
                    renderModel: renderModel,
                    selectionRange: $highlightTextSelection
                )
                Divider()
                volumeNavigationView
                    .padding(.horizontal, 48)
                    .padding(.vertical, 10)
            }
        } else if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.loadError {
            ContentUnavailableView(
                "Could not load document",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }

    // MARK: - Highlight Color Picker

    private var highlightColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "doc.highlight.pickColor",
                        defaultValue: "Highlight Color"))
                .font(.headline)
            HStack(spacing: 10) {
                ForEach(DocumentHighlight.Color.allCases, id: \.rawValue) { color in
                    Button {
                        createHighlight(color: color)
                        showHighlightColorPicker = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(swiftUIColor(for: color))
                                .frame(width: 32, height: 32)
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(color.rawValue.capitalized)
                }
            }
        }
        .padding(16)
    }

    private func swiftUIColor(for color: DocumentHighlight.Color) -> Color {
        switch color {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        }
    }

    // MARK: - Highlight Actions

    private func toggleHighlightMode() {
        showHighlightMode.toggle()
        if !showHighlightMode {
            highlightTextSelection = nil
            showHighlightColorPicker = false
        }
    }

    @MainActor
    private func createHighlight(color: DocumentHighlight.Color) {
        guard let range = highlightTextSelection else { return }
        let highlight = DocumentHighlight(
            volumeId: entry.volumeId,
            documentId: entry.documentId,
            startOffset: range.location,
            endOffset: range.location + range.length,
            colorTag: color.rawValue,
            // Session 103 placeholder — Session 105 replaces with SHA-256(rawXML ++ kVersion)
            renderingVersion: ASTToRenderNodeConverter.kVersion
        )
        modelContext.insert(highlight)
        highlightTextSelection = nil
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
                        FRUSTagChip(label: tag.displayName, style: .system)
                    }
                    ForEach(userTags) { tag in
                        FRUSTagChip(label: "◆ \(tag.name)", style: .user)
                    }
                }
            }
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

#endif // os(macOS)
