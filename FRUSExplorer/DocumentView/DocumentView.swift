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
///   1.1 — Session 121: `addToCollection` case added (Bug 3 — iOS had no document-level
///          collection membership control; only tag-based membership was available)
enum DocumentSheet: Identifiable {
    case personDetail(PersonEntry)
    case glossDetail(GlossEntry)
    case citation(String)
    case noteEditor
    case noteEditorForHighlight(UUID)
    case crossReferenceGraph
    case summarizePromptPicker
    case sourceExplorer(String)
    case editNote(ResearchNote)
    /// User-tag picker — lets the user toggle or create document-level tags on iOS.
    case tagPicker
    /// Collection picker — lets the user add this document to an existing collection
    /// or create a new one directly from the document view.
    case addToCollection
    /// Person link was tapped but the lookup returned nil — volume not indexed or
    /// persons list not yet available for this volume.
    case personNotFound
    /// Gloss link was tapped but the lookup returned nil.
    case glossNotFound
    /// User selected text in the document and chose "Look Up in NARA Catalog".
    case naraLookup(text: String)

    var id: String {
        switch self {
        case .personDetail(let p):             return "person-\(p.ref)"
        case .glossDetail(let g):              return "gloss-\(g.term)"
        case .citation:                        return "citation"
        case .noteEditor:                      return "noteEditor"
        case .noteEditorForHighlight(let hId): return "noteEditorForHighlight-\(hId)"
        case .crossReferenceGraph:             return "crossReferenceGraph"
        case .summarizePromptPicker:           return "summarizePromptPicker"
        case .sourceExplorer:                  return "sourceExplorer"
        case .editNote(let note):              return "editNote-\(note.id)"
        case .tagPicker:                       return "tagPicker"
        case .addToCollection:                 return "addToCollection"
        case .personNotFound:                  return "personNotFound"
        case .glossNotFound:                   return "glossNotFound"
        case .naraLookup:                      return "naraLookup"
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
///   2.4 — Session 106: @Query for stored highlights; overlay rendering; stale warning banner;
///          DocumentSheet.noteEditorForHighlight; note anchoring to highlights
///   2.5 — Session 107: iPad (.regular) side panel for research notes; DocumentSheet.editNote;
///          @Query documentNotes; iPadDocumentLayout + notesPanel
///   2.6 — Session 108: @Environment(\.openWindow); Source Explorer opens in new window on iPad;
///          "Open in New Window" menu item routes to DocumentWindowID Stage Manager scene
///   2.7 — Session 109: Notes panel hidden during highlight mode; notesPanel frame fill fix;
///          note count badge; CollectionEditorView iPadCollectionLayout frame fix
///   2.8 — Session 110: Replace HStack notes panel with .inspector(isPresented:) — system-
///          managed width, collapsible; Notes toggle button in .topBarLeading (iPad only);
///          toggleHighlightMode() closes inspector; remove iPadDocumentLayout HStack
///   2.9 — Session 120: DocumentSheet.tagPicker added; tag toolbar button wired to show
///          TagPickerSheetView (replaces empty Session-14 stub on iOS)
///   3.0 — Session 121: TagPickerSheetView now saves tag associations via IndexingPipeline
///          (Bug 2 — selected tags were stored in @State only and lost on dismiss);
///          DocumentSheet.addToCollection + CollectionPickerSheetView added (Bug 3 — iOS
///          had no document-level collection membership control); "Add to Collection"
///          button added to moreMenu
///   3.1 — Session 2026-06-07: edge-tap "page-turn" navigation — invisible
///          leading/trailing tap zones (documentEdgeNavigationOverlay) open the
///          previous/next document in the volume, ebook-reader style. Active only
///          in Read mode (!panelVisible — the existing "Read"/"Research" segmented
///          toggle) so research-mode interaction (selection, highlighting, panel
///          use) is never disrupted by inadvertent edge taps. Adjacent entries are
///          resolved by DocumentViewModel.loadAdjacentEntries, mirroring
///          MacDocumentView's existing prevEntry/nextEntry chevron buttons.
struct DocumentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let entry: DocumentBrowserEntry

    @State private var vm: DocumentViewModel?
    /// Drives the single consolidated sheet for all DocumentView-level presentations (F-024).
    @State private var activeSheet: DocumentSheet?

    // MARK: Highlight state
    @State private var showHighlightColorPicker = false
    /// The `DocumentHighlight.id` of the most recently created highlight.
    /// Non-nil while the "Add Note to Highlight" toolbar button should be enabled.
    @State private var pendingHighlightLink: UUID? = nil
    /// WebKit selection range — `(start, end)` Unicode-scalar offsets.
    /// Set by `onSelectionChanged` from `FRUSDocumentWebView`.
    @State private var webKitSelectionRange: (Int, Int)? = nil
    /// Raw selected text from the WebKit renderer. Pre-populates the NARA lookup field.
    @State private var webKitSelectedText: String? = nil
    /// Offsets of a tapped highlight pending the user's delete confirmation.
    @State private var highlightToDelete: (Int, Int)? = nil
    /// Research panel accordion state (persisted; shared with macOS via AppStorage).
    @AppStorage("frus.document.researchPanel.visible")  private var panelVisible    = true
    @AppStorage("frus.document.researchPanel.summary")  private var summaryExpanded = true
    @AppStorage("frus.document.researchPanel.notes")    private var notesExpanded   = true
    @AppStorage("frus.document.researchPanel.tags")     private var tagsExpanded    = false
    /// Controls the trailing notes inspector panel (iPad only; on iPhone the button
    /// that sets this is hidden, keeping the panel closed).
    @State private var showNotesPanel = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openWindow) private var openWindow

    @Query private var highlights:             [DocumentHighlight]
    @Query private var documentNotes:          [ResearchNote]
    @Query private var documentTagAssignments: [DocumentTagAssignment]
    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]

    // MARK: - Init

    init(entry: DocumentBrowserEntry) {
        self.entry = entry
        let vId = entry.volumeId
        let dId = entry.documentId
        self._highlights = Query(
            filter: #Predicate<DocumentHighlight> { h in
                h.volumeId == vId && h.documentId == dId
            },
            sort: \DocumentHighlight.createdAt
        )
        self._documentNotes = Query(
            filter: #Predicate<ResearchNote> { n in
                n.volumeId == vId && n.documentId == dId
            },
            sort: \ResearchNote.lastModified,
            order: .reverse
        )
        self._documentTagAssignments = Query(
            filter: #Predicate<DocumentTagAssignment> { a in
                a.volumeId == vId && a.documentId == dId
            }
        )
    }

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
                // Adjacent-document lookup powers the Read-mode edge-tap "page-turn"
                // gesture (documentEdgeNavigationOverlay). Loaded unconditionally —
                // the overlay itself is hidden in Research mode and at volume boundaries.
                await vm.loadAdjacentEntries(pipeline: appState.indexingPipeline)
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
        } else {
            // No model yet and no error — volume may not be downloaded, or the
            // initial render frame before bootstrapViewModel() fires. Show a spinner
            // so the view never appears completely blank to the user.
            ProgressView(String(localized: "document.initializing",
                                defaultValue: "Opening document…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Document Content

    @ViewBuilder
    private func documentContent(vm: DocumentViewModel, model: FRUSDocumentRenderModel) -> some View {
        webKitDocumentContent(vm: vm, model: model)
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
            case .noteEditorForHighlight(let hlId):
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    linkedHighlightId: hlId,
                    indexingPipeline: appState.indexingPipeline
                )
            case .editNote(let note):
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    noteToEdit: note,
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
                SourceExplorerView(
                    rawSourceNote: note,
                    documentYear: Self.extractYear(from: entry.dateline),
                    indexingPipeline: appState.indexingPipeline,
                    onRelatedDocumentTapped: { [self] vid, did in
                        handleCrossRefTap(target: did, targetVolumeId: vid)
                    }
                )
            case .tagPicker:
                TagPickerSheetView(
                    entry: entry,
                    indexingPipeline: appState.indexingPipeline,
                    initialTagIds: Set(documentTagAssignments.map(\.tagId))
                )
            case .addToCollection:
                CollectionPickerSheetView(entry: entry)
            case .personNotFound:
                personNotFoundSheet
            case .glossNotFound:
                glossNotFoundSheet
            case .naraLookup(let text):
                NARACatalogLookupView(initialText: text)
            }
        }
        .sheet(isPresented: $showHighlightColorPicker) {
            highlightColorPickerSheet
        }
        .confirmationDialog(
            String(localized: "highlight.delete.title", defaultValue: "Remove Highlight"),
            isPresented: Binding(
                get:  { highlightToDelete != nil },
                set:  { if !$0 { highlightToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "highlight.delete.confirm", defaultValue: "Remove"),
                role: .destructive
            ) {
                if let (start, end) = highlightToDelete {
                    deleteHighlight(startOffset: start, endOffset: end)
                }
                highlightToDelete = nil
            }
            Button(String(localized: "highlight.delete.cancel", defaultValue: "Cancel"),
                   role: .cancel) {
                highlightToDelete = nil
            }
        } message: {
            Text(String(localized: "highlight.delete.message",
                        defaultValue: "This highlight will be permanently removed."))
        }
        // Trailing inspector panel for research notes (iPad).
        // On iPhone the toggle button is hidden, so showNotesPanel stays false.
        .inspector(isPresented: $showNotesPanel) {
            notesPanel
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

    // MARK: - Tag Helpers

    private var appliedUserTags: [UserTag] {
        let assignedIds = Set(documentTagAssignments.map(\.tagId))
        return allUserTags.filter { assignedIds.contains($0.id) }
    }

    private func removeUserTag(_ tag: UserTag) {
        let vId = entry.volumeId
        let dId = entry.documentId
        // Capture remaining IDs before deleting so the FTS5 string is correct.
        let remaining = documentTagAssignments
            .filter { $0.tagId != tag.id }
            .map { $0.tagId.uuidString }
        let tagString: String? = remaining.isEmpty ? nil : remaining.joined(separator: " ")
        for assignment in documentTagAssignments where assignment.tagId == tag.id {
            modelContext.delete(assignment)
        }
        try? modelContext.save()
        guard let pipeline = appState.indexingPipeline else { return }
        Task.detached(priority: .utility) {
            try? await pipeline.updateUserTagIds(volumeId: vId, documentId: dId, userTagIds: tagString)
        }
    }

    // MARK: - Document Year Extraction

    /// Extracts a 4-digit year from a dateline string such as
    /// "Washington, January 15, 1946" or "Moscow, April 3, 1963".
    /// Returns `nil` when no plausible year is found.
    static func extractYear(from dateline: String?) -> Int? {
        guard let dl = dateline else { return nil }
        let pattern = #"\b(19[0-9]{2}|20[0-2][0-9])\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: dl, range: NSRange(dl.startIndex..., in: dl)),
              let range = Range(match.range(at: 1), in: dl)
        else { return nil }
        return Int(dl[range])
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
        ToolbarItemGroup(placement: .primaryAction) {

            // 1. Add research note
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

            // 2. Tag document
            Button {
                activeSheet = .tagPicker
            } label: {
                Label(
                    String(localized: "document.toolbar.addTag", defaultValue: "Tag Document"),
                    systemImage: "tag"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.addTag.a11y", defaultValue: "Tag document")
            )

            // 3. Create highlight — enabled when text is selected in the web view
            Button {
                showHighlightColorPicker = true
            } label: {
                Image(systemName: "paintbrush.pointed")
            }
            .disabled(webKitSelectionRange == nil)
            .accessibilityLabel(
                String(localized: "document.toolbar.createHighlight.a11y",
                       defaultValue: "Create highlight")
            )
            .sheet(isPresented: $showHighlightColorPicker) {
                highlightColorPickerSheet
            }

            // 4. Research panel toggle — segmented Read / Research picker.
            // Binding wraps the AppStorage Bool so the layout transition can be
            // animated; the segmented control's own selection animation handles the
            // visual state change without an additional withAnimation call.
            Picker(
                String(localized: "document.toolbar.panelMode",
                       defaultValue: "View mode"),
                selection: Binding(
                    get: { panelVisible },
                    set: { newVal in
                        withAnimation(.easeInOut(duration: 0.2)) { panelVisible = newVal }
                    }
                )
            ) {
                Text(String(localized: "document.toolbar.panelMode.read",
                            defaultValue: "Read"))
                    .tag(false)
                Text(String(localized: "document.toolbar.panelMode.research",
                            defaultValue: "Research"))
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityLabel(
                String(localized: "document.toolbar.panelMode.a11y",
                       defaultValue: "Toggle reading or research view")
            )
            .accessibilityHint(
                String(localized: "document.toolbar.panelMode.hint",
                       defaultValue: "Read mode also enables edge-tap navigation to the previous and next document in this volume")
            )

            // 5. More — overflow menu
            moreMenu(vm: vm)
        }
        // Notes panel toggle — leading nav bar position on iPad
        if sizeClass == .regular {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showNotesPanel.toggle()
                } label: {
                    Image(systemName: "note.text")
                        .foregroundStyle(showNotesPanel ? Color.accentColor : Color.primary)
                }
                .accessibilityLabel(
                    showNotesPanel
                        ? String(localized: "document.toolbar.notesPanel.hide.a11y",
                                 defaultValue: "Hide notes panel")
                        : String(localized: "document.toolbar.notesPanel.show.a11y",
                                 defaultValue: "Show notes panel")
                )
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

            // Add to Collection
            Button {
                activeSheet = .addToCollection
            } label: {
                Label(
                    String(localized: "document.toolbar.addToCollection",
                           defaultValue: "Add to Collection"),
                    systemImage: "folder.badge.plus"
                )
            }
            .accessibilityLabel(
                String(localized: "document.toolbar.addToCollection.a11y",
                       defaultValue: "Add document to a collection")
            )

            // Cross-references
            Button {
                activeSheet = .crossReferenceGraph
            } label: {
                Label(
                    String(localized: "document.toolbar.crossRef", defaultValue: "Cross-References"),
                    systemImage: "arrow.triangle.branch"
                )
            }

            // NARA Catalog Lookup — available when text is selected anywhere in the
            // document (body or footnotes). Shown when webKitSelectedText is non-nil;
            // this persists after the More-menu blur event so the selected text is
            // still accessible when the user taps the menu item.
            if webKitSelectedText != nil {
                Button {
                    let text = webKitSelectedText ?? ""
                    webKitSelectedText = nil   // clear after capturing so button goes away
                    activeSheet = .naraLookup(text: text)
                } label: {
                    Label(
                        String(localized: "document.toolbar.naraLookup",
                               defaultValue: "Look Up in NARA Catalog"),
                        systemImage: "magnifyingglass.circle"
                    )
                }
            }

            // Source Explorer — always available for all documents.
            // On iPad (regular width) opens in a new Stage Manager window;
            // on iPhone falls back to a sheet.
            Button {
                let note = vm.sourceNote ?? ""
                if sizeClass == .regular {
                    appState.currentSourceNote = note
                    appState.currentSourceNoteYear = Self.extractYear(from: entry.dateline)
                    openWindow(id: "frus.sourceExplorer.ios")
                } else {
                    activeSheet = .sourceExplorer(note)
                }
            } label: {
                Label(
                    String(localized: "document.toolbar.sourceExplorer",
                           defaultValue: "Source Explorer"),
                    systemImage: "archivebox"
                )
            }

            // Open in New Window — iPad Stage Manager only
            if sizeClass == .regular {
                Divider()
                Button {
                    openWindow(value: DocumentWindowID(
                        volumeId: entry.volumeId,
                        documentId: entry.documentId,
                        header: vm.documentTitle ?? entry.header
                    ))
                } label: {
                    Label(
                        String(localized: "document.toolbar.openInNewWindow",
                               defaultValue: "Open in New Window"),
                        systemImage: "square.on.square"
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

    // MARK: - Stale Highlight Banner

    private var staleHighlightBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(String(localized: "highlight.stale.warning",
                        defaultValue: "Some highlights may be misaligned — the document has been updated since they were created."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
    }

    // MARK: - Person / Gloss Not Found Sheets

    /// Shown when a persName link is tapped but the person data isn't in the index.
    /// This happens when a volume hasn't been indexed yet, or when the index was built
    /// before the Session 130 parser fix that correctly reads `xml:id` from persons lists.
    /// The sheet provides actionable guidance (re-index the volume) rather than silently
    /// doing nothing.
    private var personNotFoundSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(String(localized: "personNotFound.title",
                            defaultValue: "Person Information Unavailable"))
                    .font(.headline)
                Text(String(localized: "personNotFound.detail",
                            defaultValue: "Detailed information about this person isn't available for this volume. To populate person data, re-index the volume in Settings → Volumes."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle(String(localized: "personNotFound.navTitle",
                                    defaultValue: "Person"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "personNotFound.dismiss",
                                  defaultValue: "Done")) {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// Shown when a gloss link is tapped but the term data isn't in the index.
    private var glossNotFoundSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(String(localized: "glossNotFound.title",
                            defaultValue: "Term Definition Unavailable"))
                    .font(.headline)
                Text(String(localized: "glossNotFound.detail",
                            defaultValue: "A definition for this term isn't available for this volume. To populate term data, re-index the volume in Settings → Volumes."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle(String(localized: "glossNotFound.navTitle",
                                    defaultValue: "Term"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "glossNotFound.dismiss",
                                  defaultValue: "Done")) {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - WebKit document content (Session 142+)

    /// Document view for the WebKit rendering path (`FeatureFlags.useWebKitRenderer == true`).
    ///
    /// `WKWebView` handles all scrolling and footnote display (HTML Popover API).
    /// Header items (summary strip, editorial badge, highlights banner) are pinned
    /// above the web view. `DocumentTagSection` and volume navigation are omitted
    /// from this path until Session 147 finalises the WebKit migration.
    @ViewBuilder
    private func webKitDocumentContent(
        vm: DocumentViewModel,
        model: FRUSDocumentRenderModel
    ) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            // Non-scrollable header
            if let summary = vm.activeSummary {
                SummaryStripView(vm: vm, summary: summary, totalCount: vm.summaries.count)
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.top, 12)
                Divider()
            }
            if entry.isEditorialNote {
                EditorialNoteBadge()
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            // Stale highlight banner — shown when any stored highlight's
            // renderingVersion doesn't match the current document version.
            let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
            if highlights.contains(where: { $0.renderingVersion != renderingVersion }) {
                staleHighlightBanner
            }

            // Document body — WKWebView handles scrolling, footnotes, and highlights.
            // The edge-tap navigation overlay is layered on top via ZStack rather than
            // composed as a sibling, so it can float over the web view without
            // participating in its layout or scrolling.
            ZStack {
            FRUSDocumentWebView(
                model: model,
                onPersonTap: { person in
                    vm.selectedPerson = person
                    if let person {
                        activeSheet = .personDetail(person)
                    } else {
                        // Lookup failed — persons not yet indexed for this volume,
                        // or the person ref doesn't match any entry in the index.
                        activeSheet = .personNotFound
                    }
                },
                onGlossTap: { entry in
                    if let entry {
                        activeSheet = .glossDetail(entry)
                    } else {
                        activeSheet = .glossNotFound
                    }
                },
                onCrossRefTap: { target, targetVolumeId in
                    handleCrossRefTap(target: target, targetVolumeId: targetVolumeId)
                }
            )
            .highlights(highlights)
            .onSelectionChanged { start, end, text in
                if start >= 0 {
                    // In-document selection with valid offsets — enables highlights + lookup.
                    webKitSelectionRange = (start, end)
                } else {
                    // Footnote / out-of-document selection — text only, no valid offsets.
                    // Clear the range so highlight creation is not offered, but keep the
                    // text so NARA lookup remains available.
                    webKitSelectionRange = nil
                }
                webKitSelectedText = text.isEmpty ? nil : text
            }
            .onSelectionCleared {
                // Only clear the offset range. webKitSelectedText is intentionally
                // preserved so the NARA lookup button stays available after the selection
                // is released (e.g. when the user opens the More menu on iOS, which causes
                // the WebView to blur and fire a false selectioncleared event).
                // webKitSelectedText is cleared when the NARA lookup button is tapped.
                webKitSelectionRange = nil
            }
            .onHighlightTapped  { start, end in highlightToDelete = (start, end) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            documentEdgeNavigationOverlay(vm: vm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Research panel — accordion of Notes, Tags, Summary
            if panelVisible {
                Divider()
                iOSResearchPanel(vm: vm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Edge-Tap Document Navigation (Read mode "page-turn")

    /// Invisible leading/trailing edge-tap zones that navigate to the previous/next
    /// document in the current volume — an ebook-reader-style "page-turn" gesture.
    ///
    /// Shown only when:
    ///  - **Read mode is active** (`!panelVisible` — the "Read"/"Research" segmented
    ///    control in the toolbar; see `documentToolbar`). Research mode hides the
    ///    zones entirely so taps near the edges while annotating, selecting text, or
    ///    using the research panel are never misread as page-turns.
    ///  - **An adjacent document exists** in that direction (`vm.previousEntry`/
    ///    `vm.nextEntry`, populated by `DocumentViewModel.loadAdjacentEntries`).
    ///    No zone is shown at the first/last document of a volume.
    ///
    /// Each zone is a narrow, fully transparent strip pinned to its edge —
    /// `FRUSTheme.documentEdgeTapZoneWidth` is chosen to sit mostly outside the
    /// reading column (which begins at `documentHorizontalPadding`), minimising
    /// overlap with inline `<persName>`/`<gloss>`/cross-reference links so WKWebView
    /// still receives taps on in-column content. A `Spacer` between the two zones
    /// guarantees the entire central reading area is never intercepted.
    ///
    /// Version history:
    ///   1.0 — Session 2026-06-07: initial implementation
    @ViewBuilder
    private func documentEdgeNavigationOverlay(vm: DocumentViewModel) -> some View {
        if !panelVisible {
            HStack(spacing: 0) {
                documentEdgeTapZone(
                    adjacentEntry: vm.previousEntry,
                    systemImage: "chevron.left",
                    label: String(localized: "document.nav.previous.a11y",
                                  defaultValue: "Previous document"),
                    hint: String(localized: "document.nav.previous.hint",
                                 defaultValue: "Opens the previous document in this volume")
                )
                Spacer(minLength: 0)
                documentEdgeTapZone(
                    adjacentEntry: vm.nextEntry,
                    systemImage: "chevron.right",
                    label: String(localized: "document.nav.next.a11y",
                                  defaultValue: "Next document"),
                    hint: String(localized: "document.nav.next.hint",
                                 defaultValue: "Opens the next document in this volume")
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Let the zones themselves opt into hit-testing; the HStack/Spacer must
            // not swallow taps meant for the web view's central reading column.
            .allowsHitTesting(true)
        }
    }

    /// A single transparent edge-tap zone. Renders nothing (and accepts no taps)
    /// when `adjacentEntry` is `nil`, so volume boundaries show no dead tap area.
    @ViewBuilder
    private func documentEdgeTapZone(
        adjacentEntry: DocumentBrowserEntry?,
        systemImage: String,
        label: String,
        hint: String
    ) -> some View {
        if let adjacentEntry {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: FRUSTheme.documentEdgeTapZoneWidth)
                .onTapGesture {
                    navigateToAdjacentDocument(adjacentEntry)
                }
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityHint(hint)
                .accessibilityAddTraits(.isButton)
                #if DEBUG
                // Visualise the otherwise-invisible tap zones during development.
                // FRUS_DEBUG_EDGE_TAP_ZONES is unset by default — set it in the
                // scheme's environment variables to enable the overlay tint.
                .overlay {
                    if ProcessInfo.processInfo.environment["FRUS_DEBUG_EDGE_TAP_ZONES"] != nil {
                        Image(systemName: systemImage)
                            .foregroundStyle(.secondary)
                            .background(Color.accentColor.opacity(0.08))
                    }
                }
                #endif
        } else {
            Color.clear
                .frame(width: FRUSTheme.documentEdgeTapZoneWidth)
                .allowsHitTesting(false)
        }
    }

    /// Navigates to a sibling document within the same volume, triggered by the
    /// edge-tap "page-turn" gesture.
    ///
    /// Reuses the same cross-reference navigation pathway as `handleCrossRefTap`
    /// (`appState.pendingBrowseDocument`, observed by `BrowserView.onChange` which
    /// appends the entry to the Browse tab's navigation stack) — the identical
    /// mechanism `MacDocumentView`'s prev/next chevron buttons use on macOS
    /// (`navigationPath.append(prev/next)`). `DocumentView` can be presented from
    /// several navigation contexts (Search, Citation Lookup, Cross-Reference Graph,
    /// Browse), so routing every document-to-document jump through the Browse tab
    /// keeps behaviour predictable and consistent with existing in-document navigation.
    private func navigateToAdjacentDocument(_ adjacent: DocumentBrowserEntry) {
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        appState.pendingBrowseDocument = adjacent
        #if DEBUG
        print("[DocumentView] Edge-tap page-turn → \(adjacent.volumeId)/\(adjacent.documentId)")
        #endif
    }

    // MARK: - iOS Research Panel

    @ViewBuilder
    private func iOSResearchPanel(vm: DocumentViewModel) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            // ── Summary ────────────────────────────────────────────────────────
            if appState.summarizationService != nil || vm.activeSummary != nil {
                iOSPanelSectionHeader(
                    title: String(localized: "panel.summary.title", defaultValue: "Summary"),
                    badge: nil,
                    isExpanded: $summaryExpanded
                )
                if summaryExpanded, let summary = vm.activeSummary {
                    Divider()
                    SummaryStripView(vm: vm, summary: summary, totalCount: vm.summaries.count)
                        .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                        .padding(.vertical, 8)
                } else if summaryExpanded {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.tertiary)
                        Text(String(localized: "panel.summary.empty",
                                    defaultValue: "No summary yet — tap More → Summarize with AI."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
                Divider()
            }

            // ── Notes ─────────────────────────────────────────────────────────
            iOSPanelSectionHeader(
                title: String(localized: "panel.notes.title", defaultValue: "Notes"),
                badge: documentNotes.isEmpty ? nil : "\(documentNotes.count)",
                isExpanded: $notesExpanded
            )
            if notesExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(documentNotes) { note in
                        Button { activeSheet = .editNote(note) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(note.bodyText.isEmpty
                                     ? String(localized: "panel.notes.emptyNote", defaultValue: "Empty note")
                                     : note.bodyText)
                                    .font(.callout)
                                    .foregroundStyle(note.bodyText.isEmpty ? .tertiary : .primary)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(note.lastModified ?? .now, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    Button {
                        activeSheet = .noteEditor
                    } label: {
                        Label(
                            String(localized: "panel.notes.add", defaultValue: "Add Note"),
                            systemImage: "plus.circle"
                        )
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.vertical, 10)
                }
            }
            Divider()

            // ── Tags ───────────────────────────────────────────────────────────
            let appliedTags = appliedUserTags
            iOSPanelSectionHeader(
                title: String(localized: "panel.tags.title", defaultValue: "Tags"),
                badge: appliedTags.isEmpty ? nil : "\(appliedTags.count)",
                isExpanded: $tagsExpanded
            )
            if tagsExpanded {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appliedTags) { tag in
                            FRUSTagChip(label: tag.name, style: .user) {
                                removeUserTag(tag)
                            }
                        }
                        Button {
                            activeSheet = .tagPicker
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                if appliedTags.isEmpty {
                                    Text(String(localized: "panel.tags.add",
                                                defaultValue: "Add Tag"))
                                }
                            }
                            .font(.system(size: FRUSTheme.captionSize, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, FRUSTheme.tagPaddingV)
                            .background(Color.accentColor.opacity(0.10))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func iOSPanelSectionHeader(
        title: String,
        badge: String?,
        isExpanded: Binding<Bool>
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Highlight Actions

    /// Deletes the `DocumentHighlight` matching `startOffset`/`endOffset` from SwiftData.
    @MainActor
    private func deleteHighlight(startOffset: Int, endOffset: Int) {
        let vid = entry.volumeId
        let did = entry.documentId
        let predicate = #Predicate<DocumentHighlight> { h in
            h.volumeId == vid && h.documentId == did
                && h.startOffset == startOffset && h.endOffset == endOffset
        }
        guard let hl = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first else {
            return
        }
        modelContext.delete(hl)
        #if DEBUG
        print("[DocumentView] Deleted highlight [\(startOffset)–\(endOffset)] from \(did)")
        #endif
    }

    @MainActor
    private func createHighlight(color: DocumentHighlight.Color) {
        guard let range = webKitSelectionRange,
              let model = vm?.renderModel else { return }
        let rv = ASTToRenderNodeConverter.renderingVersion(for: model)
        let flat = buildFlatText(from: model)
        let selectedText: String
        if let r = Range(NSRange(location: range.0, length: range.1 - range.0), in: flat) {
            selectedText = String(flat[r])
        } else {
            selectedText = ""
        }
        let highlight = DocumentHighlight(
            volumeId:         entry.volumeId,
            documentId:       entry.documentId,
            startOffset:      range.0,
            endOffset:        range.1,
            colorTag:         color.rawValue,
            selectedText:     selectedText,
            renderingVersion: rv
        )
        modelContext.insert(highlight)
        webKitSelectionRange = nil
        pendingHighlightLink = highlight.id
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

    private var notesPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "document.notesPanel.title",
                            defaultValue: "Research Notes"))
                    .font(.headline)
                if !documentNotes.isEmpty {
                    Text("\(documentNotes.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                Spacer()
                Button {
                    activeSheet = .noteEditor
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(
                    String(localized: "document.notesPanel.add.a11y",
                           defaultValue: "Add research note")
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if documentNotes.isEmpty {
                ContentUnavailableView(
                    String(localized: "document.notesPanel.empty.title",
                           defaultValue: "No Notes"),
                    systemImage: "note.text",
                    description: Text(
                        String(localized: "document.notesPanel.empty.detail",
                               defaultValue: "Tap + to add a research note for this document.")
                    )
                )
                .frame(maxHeight: .infinity)
            } else {
                List(documentNotes) { note in
                    Button {
                        activeSheet = .editNote(note)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.bodyText.isEmpty
                                 ? String(localized: "document.notesPanel.emptyNote",
                                          defaultValue: "Empty note")
                                 : note.bodyText)
                                .font(.callout)
                                .foregroundStyle(note.bodyText.isEmpty ? .tertiary : .primary)
                                .lineLimit(4)
                            Text(note.lastModified ?? .now, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        note.bodyText.isEmpty
                            ? String(localized: "document.notesPanel.emptyNote.a11y",
                                     defaultValue: "Empty note")
                            : note.bodyText
                    )
                }
                .listStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .secondarySystemBackground))
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

// DocumentTagSection and DocumentTagChip removed — document-level subject tags
// are no longer shown in the UI. The SubjectTagStore and DocumentViewModel.subjectTags
// remain populated for potential future use; only the display layer is removed.

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

// MARK: - TagPickerSheetView (iOS)

/// iOS document-level user-tag picker.
///
/// Lists all `UserTag` records from SwiftData and lets the user toggle which tags
/// apply to this document. A "New Tag" field lets the user create tags inline.
/// Presented from `DocumentView`'s toolbar "Tag Document" button.
///
/// ## Persistence
/// On appear the view reads the current tag IDs stored in `IndexingPipeline`'s
/// `document_cache` and pre-populates `selectedTagIds`. When the user taps Done,
/// the updated set is written back to both `document_cache` and the FTS5 index via
/// `IndexingPipeline.updateUserTagIds`. If `indexingPipeline` is nil (document not
/// yet indexed), the selection is a no-op and the sheet dismisses normally.
///
/// Version history:
///   1.0 — Session 120: initial implementation; replaces empty Session-14 stub
///   1.1 — Session 121: loads existing tags on appear; saves via IndexingPipeline.updateUserTagIds
///          on Done (Bug 2 — selection was stored in @State only, lost on dismiss)
///   1.2 — Session 130: `documentTaggingGeneration` increment added
private struct TagPickerSheetView: View {

    let entry: DocumentBrowserEntry
    let indexingPipeline: IndexingPipeline?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @State private var selectedTagIds: Set<UUID>
    @State private var newTagName: String = ""
    /// Tags inserted during this session — deleted if the user cancels rather than
    /// saves, preventing orphan UserTag records when Cancel is tapped.
    @State private var newlyCreatedTags: [UserTag] = []

    init(entry: DocumentBrowserEntry,
         indexingPipeline: IndexingPipeline?,
         initialTagIds: Set<UUID>) {
        self.entry = entry
        self.indexingPipeline = indexingPipeline
        _selectedTagIds = State(initialValue: initialTagIds)
    }

    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    Section {
                        Text(String(localized: "document.tags.empty",
                                    defaultValue: "No tags yet. Type a name below to create one."))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    Section(String(localized: "document.tags.yourTags",
                                   defaultValue: "Your Tags")) {
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

                Section(String(localized: "document.tags.newTag",
                               defaultValue: "New Tag")) {
                    HStack {
                        TextField(
                            String(localized: "document.tags.newTag.placeholder",
                                   defaultValue: "Tag name…"),
                            text: $newTagName
                        )
                        .onSubmit { createTag() }
                        Button(
                            String(localized: "document.tags.addButton",
                                   defaultValue: "Add"),
                            action: createTag
                        )
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle(
                String(
                    localized: "document.tags.sheet.title",
                    defaultValue: "Tags — \(entry.documentNumber.map { "Doc \($0)" } ?? entry.documentId)"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "document.tags.cancel",
                                  defaultValue: "Cancel")) { cancelAndDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.tags.done",
                                  defaultValue: "Done")) {
                        saveAndDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = UserTag(name: name)
        modelContext.insert(tag)
        newlyCreatedTags.append(tag)
        selectedTagIds.insert(tag.id)
        newTagName = ""
    }

    private func cancelAndDismiss() {
        for tag in newlyCreatedTags { modelContext.delete(tag) }
        dismiss()
    }

    private func saveAndDismiss() {
        // SwiftData write and sheet dismissal happen immediately on the main thread.
        // The FTS5 virtual table update (delete + full re-insert) can take 100–500 ms
        // on iPhone storage; running it in the background eliminates the visible lag.
        syncAssignmentsToSwiftData()
        dismiss()
        guard let pipeline = indexingPipeline else { return }
        let tagString = selectedTagIds.isEmpty
            ? nil
            : selectedTagIds.map(\.uuidString).joined(separator: " ")
        let vId = entry.volumeId
        let dId = entry.documentId
        Task.detached(priority: .utility) {
            try? await pipeline.updateUserTagIds(
                volumeId: vId,
                documentId: dId,
                userTagIds: tagString
            )
        }
    }

    /// Identical to MacTagPickerSheet.syncAssignmentsToSwiftData() — see that method
    /// for documentation. Separate copy for this iOS-only private struct.
    private func syncAssignmentsToSwiftData() {
        let vId = entry.volumeId
        let dId = entry.documentId
        let descriptor = FetchDescriptor<DocumentTagAssignment>(
            predicate: #Predicate<DocumentTagAssignment> { a in
                a.volumeId == vId && a.documentId == dId
            }
        )
        for assignment in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(assignment)
        }
        for tagId in selectedTagIds {
            modelContext.insert(DocumentTagAssignment(
                volumeId: vId, documentId: dId, tagId: tagId
            ))
        }
        try? modelContext.save()
    }
}

// MARK: - CollectionPickerSheetView (iOS)

/// iOS document-level collection picker.
///
/// Presents a searchable list of all collections so the user can add this document
/// to an existing collection or create a new one. Tapping a collection row inserts a
/// `CollectionEntry` and briefly shows a confirmation checkmark before auto-dismissing.
/// The "New Collection" toolbar button opens `CollectionEditorView` inline.
///
/// This is the iOS-styled counterpart of the macOS `CollectionPickerSheet` in
/// `SupportingViews.swift`. The two share identical logic; the only differences
/// are list style and the absence of a fixed frame (iOS manages size via presentation
/// detents instead).
///
/// Version history:
///   1.0 — Session 121: initial implementation (Bug 3 — iOS had no document-level
///          collection membership control)
private struct CollectionPickerSheetView: View {

    let entry: DocumentBrowserEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.lastModified, order: .reverse) private var collections: [Collection]

    @State private var searchText: String = ""
    @State private var showNewCollection = false
    @State private var addedCollectionId: UUID? = nil

    private var filtered: [Collection] {
        guard !searchText.isEmpty else { return collections }
        return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "collection.picker.empty.title",
                               defaultValue: "No Collections"),
                        systemImage: "folder",
                        description: Text(
                            String(localized: "collection.picker.empty.detail",
                                   defaultValue: "Create a collection using the button above.")
                        )
                    )
                } else {
                    List(filtered) { collection in
                        Button {
                            addDocument(to: collection)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(collection.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    let count = collection.documentEntries?.count ?? 0
                                    Text(
                                        String(
                                            localized: "collection.picker.documentCount",
                                            defaultValue: "\(count) \(count == 1 ? "document" : "documents")"
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if addedCollectionId == collection.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .accessibilityLabel(
                                            String(localized: "collection.picker.added.a11y",
                                                   defaultValue: "Added")
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(collection.name)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(
                        text: $searchText,
                        prompt: String(localized: "collection.picker.search.prompt",
                                       defaultValue: "Search collections")
                    )
                }
            }
            .navigationTitle(
                String(localized: "collection.picker.title",
                       defaultValue: "Add to Collection")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.picker.cancel",
                                  defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewCollection = true
                    } label: {
                        Label(
                            String(localized: "collection.picker.newCollection",
                                   defaultValue: "New Collection"),
                            systemImage: "folder.badge.plus"
                        )
                    }
                    .accessibilityLabel(
                        String(localized: "collection.picker.newCollection.a11y",
                               defaultValue: "Create a new collection")
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }

    private func addDocument(to collection: Collection) {
        let existing = collection.documentEntries ?? []
        // Guard against duplicates — show checkmark and dismiss if already a member.
        guard !existing.contains(where: {
            $0.documentId == entry.documentId && $0.volumeId == entry.volumeId
        }) else {
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
            return
        }

        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let collectionEntry = CollectionEntry(
            collectionId: collection.id,
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            sortOrder: nextOrder
        )
        modelContext.insert(collectionEntry)
        collection.documentEntries?.append(collectionEntry)

        addedCollectionId = collection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }
}

#endif // os(iOS)
