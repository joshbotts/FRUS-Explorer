// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// DocumentView and all its supporting types are iOS-only.
// macOS uses MacDocumentView (App/MacDocumentView.swift) with the new window-based architecture.
#if os(iOS)

// MARK: - DocumentSheet

/// Identifies which sheet is currently active in `DocumentView`.
///
/// A single enum replaces 7 independent `@State` boolean/optional sheet triggers.
/// SwiftUI can only present one sheet at a time; the enum makes that contract
/// explicit and eliminates impossible states (e.g. two sheets open simultaneously).
///
/// Version history:
///   1.0 — Session 59: initial implementation (F-024)
enum DocumentSheet: Identifiable {
    case personDetail(PersonEntry)
    case glossDetail(GlossEntry)
    case citation(String)
    case noteEditor
    case crossReferenceGraph
    case summarizePromptPicker
    case sourceExplorer(String)

    var id: String {
        switch self {
        case .personDetail(let p):    return "person-\(p.ref)"
        case .glossDetail(let g):     return "gloss-\(g.term)"
        case .citation:               return "citation"
        case .noteEditor:             return "noteEditor"
        case .crossReferenceGraph:    return "crossReferenceGraph"
        case .summarizePromptPicker:  return "summarizePromptPicker"
        case .sourceExplorer:         return "sourceExplorer"
        }
    }
}

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
///   1.3 — Session 56: collapse 6–7 toolbar icons into 2 direct buttons + 1 overflow Menu
///          (HIG: ≤ 4 toolbar items on iPhone); Source Explorer, Cross-References,
///          Summarize, and Citation sub-actions move inside the overflow "More" menu
///   1.3 — Session 27: Q5 curated badge icon; Q1 confidence-aware a11y label; tag hint
///   1.4 — Session 40: personMentionStore wired; PersonDetailSheet gains mention count + Find all mentions
///   1.5 — Session 44: handleCrossRefTap wired cross-platform via pendingBrowseDocument
///   1.6 — Session 54: OpenURLAction handles frusexplorer://doc/… links from AttributedString cross-refs
///   1.7 — Session 59: consolidate 7 sheet modifiers into single .sheet(item: $activeSheet) via
///          DocumentSheet enum (F-024); add .presentationDetents on PersonDetail/Gloss/Citation (F-006)
///   1.8 — Session 65: pass `embedInScrollView: false` to FRUSDocumentRenderer to eliminate
///          nested ScrollViews (fixes scroll-stuck bug and unblocks link/tap hit-testing);
///          extend \.openURL handler to route frusexplorer://person/ and frusexplorer://gloss/
///          URLs to the person/gloss detail sheets via vm.personsByRef / vm.termsByRef
///   1.9 — Session 66: fix empty navigation title and breadcrumb for cross-reference targets;
///          navigationTitle now uses vm.documentTitle (set after parse) falling back to
///          entry.header or entry.documentId; handleCrossRefTap uses docId as placeholder header
///          so the breadcrumb is non-empty while the document loads
///   2.0 — Session 68: fix cross-reference and search-result document loading. Both paths
///          reached DocumentView as a prop update on an existing view instance (NavigationSplitView
///          detail column reuse), leaving vm stale for the old entry. Replaced .onAppear with
///          .task(id: documentId/volumeId): the task auto-cancels and restarts when the entry
///          identity changes, resetting vm and re-bootstrapping for the new document. Same-entry
///          reappearance is a no-op because bootstrapViewModel guards on vm == nil.
///   2.1 — Session 92: FRUSTheme tokens applied — documentHorizontalPadding replaces
///          .padding(.horizontal) magic numbers; sectionLabelSize/Weight/Kerning on the
///          tag section header; tagChipSpacing on the chip row; EditorialNoteBadge added
///          at the top of the document body for editorial note entries (iOS parity with macOS)
///   2.2 — Session 104: highlight mode toolbar toggle + DocumentHighlightTextView (UITextView
///          UIViewRepresentable) + color-picker sheet + DocumentHighlight SwiftData insertion
///   2.3 — Session 105: renderingVersion uses SHA-256(flatText ++ kVersion) via
///          ASTToRenderNodeConverter.renderingVersion(for:)
struct DocumentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let entry: DocumentBrowserEntry

    @State private var vm: DocumentViewModel?
    /// Drives the single consolidated sheet for all DocumentView-level presentations (F-024).
    @State private var activeSheet: DocumentSheet?

    // MARK: Highlight Mode
    @State private var showHighlightMode = false
    @State private var highlightTextSelection: NSRange? = nil
    @State private var showHighlightColorPicker = false

    var body: some View {
        Group {
            if let vm {
                loadedView(vm: vm)
            } else {
                ProgressView(String(localized: "document.initializing",
                                    defaultValue: "Opening document…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Use .task(id:) rather than .onAppear so that SwiftUI auto-cancels and
        // restarts the task whenever the entry identity changes. This is necessary
        // because NavigationSplitView reuses the same DocumentView instance when the
        // detail column's last path element changes from one .document entry to another
        // (cross-reference taps and search-result selections both hit this path).
        // When reused, `entry` is updated as a prop but `@State var vm` retains the
        // old DocumentViewModel — so the body shows the old document until we reset.
        //
        // The id string encodes both documentId and volumeId so cross-volume references
        // (same docId, different volume) also trigger a reset.
        .task(id: entry.documentId + "/" + entry.volumeId) {
            // Reset vm if we detect view reuse for a different entry.
            // bootstrapViewModel() alone is not enough because it guards on vm == nil.
            if let existingVm = vm,
               existingVm.entry.documentId != entry.documentId
                   || existingVm.entry.volumeId != entry.volumeId {
                vm = nil
            }
            bootstrapViewModel()
            appState.logEvent(.documentOpen(
                volumeId: entry.volumeId,
                documentId: entry.documentId,
                title: entry.header.isEmpty ? entry.documentId : entry.header
            ))
        }
        // vm.documentTitle is set after the document loads; it provides a real
        // title for cross-reference targets, which are created with header: "".
        // Falls back to entry.header (known at browse time) or to entry.documentId
        // as a last resort so the navigation bar is never blank.
        .navigationTitle(vm?.documentTitle ?? (entry.header.isEmpty ? entry.documentId : entry.header))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .userActivity(AppActivityTypes.document, element: entry) { entry, activity in
            activity.title = entry.header.isEmpty ? entry.documentId : entry.header
            activity.userInfo = ["volumeId": entry.volumeId, "documentId": entry.documentId]
            activity.isEligibleForHandoff = true
        }
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
        Group {
            if showHighlightMode {
                DocumentHighlightTextView(
                    renderModel: model,
                    selectionRange: $highlightTextSelection
                )
            } else {
                ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Summary strip
                if let summary = vm.activeSummary {
                    SummaryStripView(
                        vm: vm,
                        summary: summary,
                        totalCount: vm.summaries.count
                    )
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.top, 12)
                    Divider()
                }

                // Editorial note badge — matches the identity line pattern on macOS.
                // Shown once at the top of the document body so readers know immediately
                // that this entry is an editorial note, not a primary source document.
                if entry.isEditorialNote {
                    EditorialNoteBadge()
                        .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                        .padding(.top, 12)
                }

                // Document body — embedInScrollView: false because this LazyVStack
                // is already inside DocumentView's own ScrollView.  Nested ScrollViews
                // capture all scroll and click events on macOS, which breaks link taps
                // and prevents scrolling back to the top of a long document.
                FRUSDocumentRenderer(
                    model: model,
                    embedInScrollView: false,
                    onPersNameTap: { person in
                        vm.selectedPerson = person   // retained so .task(id:) fires for mention loading
                        if let person { activeSheet = .personDetail(person) }
                    },
                    onGlossTap: { entry in
                        if let entry { activeSheet = .glossDetail(entry) }
                    },
                    onCrossRefTap: { target, targetVolumeId in
                        handleCrossRefTap(target: target, targetVolumeId: targetVolumeId)
                    }
                )

                Divider().padding(.horizontal, FRUSTheme.documentHorizontalPadding)

                // Tag chips
                DocumentTagSection(vm: vm)
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
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
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.bottom, 12)
                }
            }
            } // end ScrollView
            } // end Group
        }
        .toolbar { documentToolbar(vm: vm) }
        // Single consolidated sheet driven by the DocumentSheet enum (F-024).
        // One .sheet modifier is cheaper than 7 and makes the "only one sheet at a
        // time" constraint explicit in the type system.
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .personDetail(let person):
                PersonDetailSheet(
                    person: person,
                    mentionCount: vm.selectedPersonMentionCount,
                    onFindAllMentions: {
                        activeSheet = nil
                        appState.pendingSearch = SearchParameters(personRef: person.ref)
                    }
                )
            case .glossDetail(let gloss):
                GlossDetailSheet(gloss: gloss)
            case .citation(let text):
                CitationSheetView(citation: text)
            case .noteEditor:
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    indexingPipeline: appState.indexingPipeline
                )
            case .crossReferenceGraph:
                if let store = appState.crossReferenceStore {
                    CrossReferenceGraphView(
                        entry: entry,
                        crossReferenceStore: store,
                        downloadedVolumeIds: downloadedVolumeIds
                    )
                }
            case .summarizePromptPicker:
                SummarizationPromptPickerSheet(
                    vm: vm,
                    service: appState.summarizationService,
                    activeProjectId: appState.activeProjectId
                )
            case .sourceExplorer(let note):
                SourceExplorerView(rawSourceNote: note)
            }
        }
        .sheet(isPresented: $showHighlightColorPicker) {
            highlightColorPickerSheet
        }
        // Load the mention count for the selected person from the FTS index.
        // vm.selectedPerson is set alongside activeSheet so the task id fires correctly.
        .task(id: vm.selectedPerson?.ref) {
            guard let person = vm.selectedPerson else { return }
            await vm.loadPersonMentionCount(for: person)
        }
        // Clear the persisted person selection when any sheet closes so the
        // mention-count task does not re-fire with a stale ref after dismissal.
        // Uses activeSheet?.id (String?) rather than activeSheet directly because
        // DocumentSheet associated-value types (PersonEntry, GlossEntry) are not
        // necessarily Equatable — String? always is.
        .onChange(of: activeSheet?.id) { _, newId in
            if newId == nil { vm.selectedPerson = nil }
        }
        // Handle frusexplorer:// deep-link URLs emitted by FRUSDocumentRenderer's
        // AttributedString rendering path.  Three URL forms are supported:
        //
        //   frusexplorer://doc/{volumeId}/{documentId}
        //     Cross-reference navigation.  volumeId is "_" when the renderer
        //     had no explicit target volume (same volume as current document).
        //
        //   frusexplorer://person/{ref}
        //     Opens the PersonDetailSheet for the persName entry whose xml:id
        //     matches {ref}.  Resolved via vm.personsByRef.
        //
        //   frusexplorer://gloss/{ref}
        //     Opens the GlossDetailSheet for the glossary entry whose xml:id
        //     matches {ref}.  Resolved via vm.termsByRef.
        //
        // SwiftUI routes Text(AttributedString) link taps through this
        // \.openURL environment action on iOS.  On macOS the same routing
        // applies when the frusexplorer:// scheme is registered in Info.plist.
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "frusexplorer" else { return .systemAction }
            let parts = url.pathComponents.filter { $0 != "/" }
            switch url.host {
            case "doc":
                guard parts.count == 2 else { return .systemAction }
                let volComponent = parts[0]
                let docId        = parts[1]
                let targetVol    = volComponent == "_" ? nil : volComponent
                handleCrossRefTap(target: docId, targetVolumeId: targetVol)
                return .handled
            case "person":
                guard let ref = parts.first, !ref.isEmpty else { return .systemAction }
                if let person = vm.personsByRef[ref] {
                    vm.selectedPerson = person
                    activeSheet = .personDetail(person)
                }
                return .handled
            case "gloss":
                guard let ref = parts.first, !ref.isEmpty else { return .systemAction }
                if let gloss = vm.termsByRef[ref] {
                    activeSheet = .glossDetail(gloss)
                }
                return .handled
            default:
                return .systemAction
            }
        })
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
            activeSheet = .crossReferenceGraph
            #if DEBUG
            print("[DocumentView] Cross-ref: \(volId) not downloaded, opening graph")
            #endif
            return
        }

        let crossEntry = DocumentBrowserEntry(
            documentId: docId,
            volumeId: volId,
            documentNumber: nil,
            // Use docId as a non-empty placeholder so the breadcrumb label is
            // visible while the document loads. DocumentView replaces the navigation
            // title with vm.documentTitle once the XML has been parsed.
            header: docId,
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

    /// Document toolbar.
    ///
    /// ## Layout (HIG: ≤ 4 toolbar items on iPhone)
    /// 1. **Add Note** — direct button; most frequently used secondary action
    /// 2. **Tag Document** — direct button; fast single-tap action
    /// 3. **More ···** — overflow `Menu` containing all remaining actions:
    ///    Citation sub-menu, Cross-References, Source Explorer (conditional),
    ///    and Summarize (conditional). This keeps the toolbar uncluttered on
    ///    small screens while every action remains reachable in one extra tap.
    @ToolbarContentBuilder
    private func documentToolbar(vm: DocumentViewModel) -> some ToolbarContent {
        if showHighlightMode {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "document.toolbar.highlightDone",
                              defaultValue: "Done")) {
                    toggleHighlightMode()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showHighlightColorPicker = true
                } label: {
                    Image(systemName: "paintbrush.pointed")
                }
                .accessibilityLabel(
                    String(localized: "document.toolbar.createHighlight.a11y",
                           defaultValue: "Create highlight")
                )
                .disabled((highlightTextSelection?.length ?? 0) == 0)
            }
        } else {
            ToolbarItemGroup(placement: .primaryAction) {

                // 1. Add research note (direct — high frequency)
                Button {
                    activeSheet = .noteEditor
                } label: {
                    Label(
                        String(localized: "document.toolbar.addNote", defaultValue: "Add Research Note"),
                        systemImage: "note.text.badge.plus"
                    )
                }
                .accessibilityLabel(
                    String(localized: "document.toolbar.addNote.a11y", defaultValue: "Add research note")
                )

                // 2. Tag document (direct — fast single-tap)
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

                // 3. Highlight mode toggle
                Button {
                    toggleHighlightMode()
                } label: {
                    Image(systemName: "pencil.tip.crop.circle")
                }
                .accessibilityLabel(
                    String(localized: "document.toolbar.highlightMode.a11y",
                           defaultValue: "Highlight mode")
                )

                // 4. More — overflow menu containing all secondary actions
                moreMenu(vm: vm)
            }
        }
    }

    /// Overflow "More" menu: Citation, Cross-References, Source Explorer (conditional),
    /// Summarize (conditional). Keeps the toolbar at ≤ 3 items on all screen sizes.
    @ViewBuilder
    private func moreMenu(vm: DocumentViewModel) -> some View {
        Menu {
            // Citation sub-menu
            Menu {
                Button {
                    if let citation = vm.formattedCitation {
                        activeSheet = .citation(citation)
                    }
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

            // Cross-references
            Button {
                activeSheet = .crossReferenceGraph
            } label: {
                Label(
                    String(localized: "document.toolbar.crossRef", defaultValue: "Cross-References"),
                    systemImage: "arrow.triangle.branch"
                )
            }

            // Source Explorer — only when a source note is present
            if let sourceNote = vm.sourceNote {
                Button {
                    activeSheet = .sourceExplorer(sourceNote)
                } label: {
                    Label(
                        String(localized: "document.toolbar.sourceExplorer",
                               defaultValue: "Source Explorer"),
                        systemImage: "archivebox"
                    )
                }
            }

            // Summarize — only when Apple Intelligence is available
            if appState.summarizationService != nil
                && AppleIntelligenceProvider.shared.isAvailable {
                Divider()
                Button {
                    activeSheet = .summarizePromptPicker
                } label: {
                    if vm.isSummarizing {
                        Label(
                            String(localized: "document.toolbar.summarizing",
                                   defaultValue: "Summarizing…"),
                            systemImage: "sparkles"
                        )
                    } else {
                        Label(
                            String(localized: "document.toolbar.summarize",
                                   defaultValue: "Summarize with AI"),
                            systemImage: "sparkles"
                        )
                    }
                }
                .disabled(vm.isSummarizing || vm.documentPlainText.isEmpty)
            }
        } label: {
            Label(
                String(localized: "document.toolbar.more", defaultValue: "More"),
                systemImage: "ellipsis.circle"
            )
        }
        .accessibilityLabel(
            String(localized: "document.toolbar.more.a11y", defaultValue: "More document actions")
        )
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
        guard let range = highlightTextSelection,
              let model = vm?.renderModel else { return }
        let highlight = DocumentHighlight(
            volumeId: entry.volumeId,
            documentId: entry.documentId,
            startOffset: range.location,
            endOffset: range.location + range.length,
            colorTag: color.rawValue,
            renderingVersion: ASTToRenderNodeConverter.renderingVersion(for: model)
        )
        modelContext.insert(highlight)
        highlightTextSelection = nil
    }

    private func swiftUIColor(for color: DocumentHighlight.Color) -> Color {
        switch color {
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .pink:   return .pink
        }
    }

    // MARK: - Highlight Color Picker Sheet

    private var highlightColorPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(String(localized: "doc.highlight.pickColor",
                            defaultValue: "Highlight Color"))
                    .font(.headline)
                HStack(spacing: 16) {
                    ForEach(DocumentHighlight.Color.allCases, id: \.rawValue) { color in
                        Button {
                            createHighlight(color: color)
                            showHighlightColorPicker = false
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(swiftUIColor(for: color))
                                    .frame(width: 44, height: 44)
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.rawValue.capitalized)
                    }
                }
            }
            .padding()
            .navigationTitle(String(localized: "doc.highlight.sheet.title",
                                    defaultValue: "Choose Color"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "doc.highlight.sheet.cancel",
                                  defaultValue: "Cancel")) {
                        showHighlightColorPicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
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
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 220)
        #endif
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
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #else
        .frame(minWidth: 400, minHeight: 340)
        #endif
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
            .font(.system(size: FRUSTheme.sectionLabelSize, weight: FRUSTheme.sectionLabelWeight))
            .kerning(FRUSTheme.sectionLabelKerning)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FRUSTheme.tagChipSpacing) {
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
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
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
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 220)
        #endif
    }
}

#endif // os(iOS)
