// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
import TipKit

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
///   1.2 — Authoring Phase 5 (excerpts): `addSelectionAsExcerpt` — the collection picker
///          reused with a frozen selection capture (creation path b)
///   Session 09: `subjectTagStore` no longer passed to `DocumentViewModel` (the
///         document-level subject taxonomy was retired).
///   1.3 — Session 7 / #240B: `brokenRefExplanation` — the explanation sheet for
///          unresolvable cross-references degraded by the broken-refs index.
enum DocumentSheet: Identifiable {
    case personDetail(PersonEntry)
    case glossDetail(GlossEntry)
    case citation
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
    /// Collection picker in excerpt mode (Authoring Phase 5): inserts the captured
    /// text selection into the chosen collection as a frozen `.excerpt` entry.
    case addSelectionAsExcerpt(CollectionExcerptCapture)
    /// Person link was tapped but the lookup returned nil — volume not indexed or
    /// persons list not yet available for this volume.
    case personNotFound
    /// Gloss link was tapped but the lookup returned nil.
    case glossNotFound
    /// User selected text in the document and chose "Look Up in NARA Catalog".
    /// `blockContext` is the enclosing footnote body for a footnote selection (#269), else `nil`.
    case naraLookup(text: String, blockContext: String?)
    /// An unresolvable cross-reference was tapped — explains why it can't be followed (#240).
    case brokenRefExplanation(BrokenRefInfo)
    /// The #308 find-related list, on surfaces without multiple windows (iPhone / non-Stage-Manager
    /// iPad). Where windows exist the caller opens the `RelatedDocumentsRequest` window instead.
    case relatedDocuments(RelatedDocumentsRequest)
    /// The Research rail as an iPhone bottom sheet (Phase D). On iPad the rail is the trailing
    /// `.inspector` instead; on iPhone it folds into this consolidated sheet (owner decision D2).
    case researchRail

    var id: String {
        switch self {
        case .personDetail(let p):             return "person-\(p.ref)"
        case .glossDetail(let g):              return "gloss-\(g.term)"
        case .brokenRefExplanation(let i):     return "brokenRef-\(i.id)"
        case .citation:                        return "citation"
        case .noteEditor:                      return "noteEditor"
        case .noteEditorForHighlight(let hId): return "noteEditorForHighlight-\(hId)"
        case .crossReferenceGraph:             return "crossReferenceGraph"
        case .summarizePromptPicker:           return "summarizePromptPicker"
        case .sourceExplorer:                  return "sourceExplorer"
        case .editNote(let note):              return "editNote-\(note.id)"
        case .tagPicker:                       return "tagPicker"
        case .addToCollection:                 return "addToCollection"
        case .addSelectionAsExcerpt:           return "addSelectionAsExcerpt"
        case .personNotFound:                  return "personNotFound"
        case .glossNotFound:                   return "glossNotFound"
        case .naraLookup:                      return "naraLookup"
        case .relatedDocuments(let r):         return "relatedDocs-\(r.anchor.compositeString)"
        case .researchRail:                    return "researchRail"
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
///   3.2 — Session 2026-06-07: removed the app-owned "More" `Menu` wrapper
///          (and its nested Citation sub-menu) from the iOS document toolbar.
///          On iPhone the items overflowed into the system's own "···"
///          button, which then contained our "More" — a wasted, confusing
///          two-level "···" → "More" → tools hierarchy. All actions (Citation
///          view/copy, Add to Collection, Cross-References, NARA Lookup,
///          Source Explorer, Open in New Window, Summarize) now sit as flat,
///          direct items in the single `ToolbarItemGroup(placement:
///          .primaryAction)`; the system overflow — when triggered — is the
///          one and only "···" menu and surfaces every tool in one tap.
///   3.3 — Session 2026-06-07: added "Share Citation" to the document
///          toolbar — a `ShareLink` presenting the system share sheet with a
///          message combining the formatted citation and the document's
///          canonical history.state.gov URL (`DocumentViewModel
///          .shareableCitationMessage`), mirroring the new "Share Citation"
///          item added to the macOS citation popover's Export menu.
///   3.4 — Session 154: added Reading preferences — edge-tap page-turn zones
///          can be disabled (`edgeTapNavigationEnabled`), and a default
///          document mode (Read/Research/remember-last) is applied to
///          `panelVisible` once per document open.
///   3.5 — Session 159: "Open in New Window" gated on
///          `@Environment(\.supportsMultipleWindows)` instead of
///          `sizeClass == .regular` (iPad/Mac parity Phase 5). The size-class
///          proxy is true on every iPad, so the button previously appeared for
///          all iPad users but `openWindow` silently no-ops without Stage
///          Manager; the new gate offers it only when a second window can open.
///   3.6 — Authoring Phase 5 review fixes: highlight `selectedText` and excerpt
///          captures re-extract via `flatTextExcerpt` (block-aware — paragraph breaks
///          survive as "\n\n" instead of fusing at the flat text's zero-width block
///          seams); `lastValidSelectionRange` preserves the in-document selection
///          offsets across the system overflow menu's false `selectioncleared` blur so
///          the iPhone "Add Selection as Excerpt" path keeps its A9 anchors.
///   3.7 — Session 2026-07-03 (people-eval findings F+G): PersonDetailSheet's "Find all
///          mentions" now switches to the Search tab (it set `pendingSearch` but never
///          `activeTab`, so on iOS nothing visibly happened) and searches the resolved
///          rollup identity (`vm.selectedPersonRollupId`, matching the displayed count)
///          instead of the cross-volume-colliding raw `personRef`.
///   3.8 — Session 2026-07-04 (UI audit A3): highlight color picker swatches use the
///          localized `displayName` for their accessibility label and show the color's
///          initial under Differentiate Without Color
///   3.9 — Dynamic Type pass 2026-07-04 (UI audit A1/A2): not-found empty-state
///          glyphs scale via `@ScaledMetric` (capped at accessibility3); the tag
///          button + panel disclosure chevron use scalable caption text; the
///          highlight color-picker sheet gains a `.medium` detent so its content
///          isn't clipped by the fixed 180 pt detent at large Dynamic Type sizes.
///   3.10 — Dynamic Type review 2026-07-04: not-found glyph caps enforced in code
///          via `FRUSTheme.cappedGlyphSize` (the `.dynamicTypeSize` cap was inert
///          on a `.system(size:)` font); the highlight color-picker sheet content
///          is wrapped in a `ScrollView` so the grown chrome scrolls instead of
///          clipping at the smallest (`.height(180)`) detent.
///   3.11 — Wave R / R-8: the research-rail toolbar toggle names itself in its `Label`. This
///          toolbar holds one item and cannot overflow today; the shape is normalised so that
///          adding a second item can never silently rename this one to its SF Symbol.
struct DocumentView: View {

    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    @Environment(\.modelContext) private var modelContext

    let entry: DocumentBrowserEntry

    /// Where a document-to-document jump should go, when this view is **not** hosted by the
    /// Browse tab (#750 / audit H-10, M-15).
    ///
    /// Cross-reference taps and edge-tap page-turns default to `openTab(.browse)` +
    /// `openBrowseDocument`, which is right for the Browse stack and wrong everywhere else. Three
    /// sheets push `DocumentView` on their **own** stacks — Chronology, Citation Lookup, and the
    /// in-document cross-reference graph — and for those the Browse append happened *beneath the
    /// still-presented sheet*: the tap looked dead, and the user later found a pile of documents on
    /// a stack they never navigated, with their chronology or lookup context gone.
    ///
    /// A host that passes this keeps the jump inside its own stack, so the reader stays where they
    /// are. `nil` (the Browse tab, the macOS document window, Search's pushed reader) keeps the
    /// existing routing untouched.
    var onNavigateToDocument: ((DocumentBrowserEntry, DocumentJump) -> Void)? = nil

    /// Point size of the "…unavailable" empty-state glyphs (person / gloss not
    /// found sheets), scaled with Dynamic Type relative to `.largeTitle` so the
    /// glyph tracks the message text. Clamped via `FRUSTheme.cappedGlyphSize`
    /// at each site.
    @ScaledMetric(relativeTo: .largeTitle) private var notFoundGlyphSize: CGFloat = 44

    @State private var vm: DocumentViewModel?
    /// Drives the single consolidated sheet for all DocumentView-level presentations (F-024).
    @State private var activeSheet: DocumentSheet?
    /// Set when a cross-reference targets a document in an undownloaded volume; drives a
    /// prompt offering to download it (or view the connection graph) rather than silently
    /// redirecting.
    @State private var crossRefDownloadVolumeId: String? = nil
    /// Selected detent for the cross-reference graph sheet; starts at `.large`
    /// so the graph never opens half-height (Session 161).
    @State private var graphSheetDetent: PresentationDetent = .large

    // MARK: Highlight state
    /// The `DocumentHighlight.id` of the most recently created highlight. Non-nil while the rail's
    /// transient "Add Note to Highlight" row should appear (its dot was just tapped on the floating
    /// selection bar); cleared once the linked note is composed.
    @State private var pendingHighlightLink: UUID? = nil
    /// WebKit selection range — `(start, end)` Unicode-scalar offsets.
    /// Set by `onSelectionChanged` from `FRUSDocumentWebView`.
    @State private var webKitSelectionRange: (Int, Int)? = nil
    /// Raw selected text from the WebKit renderer. Pre-populates the NARA lookup field.
    @State private var webKitSelectedText: String? = nil
    /// The enclosing footnote body for a footnote selection (the JS `blockText`, #269), or
    /// `nil` for an in-document selection. Feeds the NARA lookup's candidate-citation scan.
    @State private var webKitSelectedBlockText: String? = nil
    /// Visibility + anchor for the floating selection bar (Research-rail Phase B). Driven straight
    /// from the selection payload's `rect`/`scale`; owns the debounced hide that survives the
    /// false-clear blur. (The bar reads the rect from the payload in `onSelectionChanged`, so no
    /// separate rect/scale `@State` is kept.)
    @State private var selectionBar = SelectionBarState()
    /// The last *valid in-document* selection range, preserved across the false
    /// `selectioncleared` the system overflow "···" menu fires when it blurs the web
    /// view (see `onSelectionCleared`). `webKitSelectedText` already survives that
    /// blur for the NARA button; this is its offset twin, so the "Add Selection as
    /// Excerpt" action — which on iPhone lives behind that overflow menu — still
    /// captures the A9 anchors (offsets + rendering version) instead of freezing
    /// text-only. Nil'd whenever a selection with no valid offsets replaces it.
    @State private var lastValidSelectionRange: (Int, Int)? = nil
    /// Offsets of a tapped highlight pending the user's delete confirmation.
    @State private var highlightToDelete: (Int, Int)? = nil
    /// Research rail visibility (persisted; shared with macOS via AppStorage). On iPad it drives the
    /// trailing `.inspector`; on iPhone it shadows the `.researchRail` sheet's presence and gates the
    /// Read-mode edge-tap zones. The per-accordion expansion keys are owned by ``ResearchRailView``.
    @AppStorage("frus.document.researchPanel.visible")  private var panelVisible    = true
    /// The user's persisted find-related weight tuning (#308), captured into the request on open.
    @AppStorage("frus.related.weights") private var relatedWeights = AxisWeights.default
    /// Whether the Read-mode edge-tap "page-turn" zones are active (Session 154).
    @AppStorage(SettingsKeys.edgeTapNavigationEnabled) private var edgeTapNavigationEnabled = true
    /// Which mode (Read/Research/remember-last) a document opens in (Session 154).
    @AppStorage(SettingsKeys.defaultDocumentMode) private var defaultDocumentMode: DefaultDocumentMode = .rememberLast

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openWindow) private var openWindow
    // NO `@Environment(\.openURL)` HERE — deliberately, and do not re-add it.
    //
    // This view INSTALLS an `OpenURLAction` (see `documentContent`) to route frusexplorer://
    // links, so reading the same key made it depend on a value it also writes. `OpenURLAction`
    // wraps a closure and never compares equal to the previous one, so every body evaluation
    // published a "new" value, invalidating the view that read it, which rebuilt the action.
    // Measured on iPad with the body counter armed: 750+ `DocumentView.body` evaluations for ONE
    // document open, accelerating 3/s → 31/s, with `_printChanges` naming `_openURL` each time —
    // enough main-thread work to trip the 10s scene-update watchdog.
    //
    // External (non-FRUS) cross-reference URLs now go straight to `UIApplication.shared.open`
    // in `handleCrossRefTap`.
    /// `true` only when the platform can actually open a second window — Stage
    /// Manager on iPad; never on iPhone or a non-Stage-Manager iPad. Gates the
    /// "Open in New Window" affordance so it isn't offered where `openWindow`
    /// would silently no-op. `sizeClass == .regular` is true on *all* iPads and
    /// is therefore the wrong proxy for multi-window capability.
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    /// `true` on iPhone — the rail presents as a bottom sheet there; iPad (and any regular-width
    /// idiom) gets the trailing `.inspector`. Uses `userInterfaceIdiom`, not `sizeClass`, because an
    /// iPhone Plus/Max in landscape reports `.regular` yet must still use the sheet (the same idiom
    /// probe `Browser/BrowserView` uses).
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    @Query private var highlights:             [DocumentHighlight]
    @Query private var documentNotes:          [ResearchNote]
    @Query private var documentTagAssignments: [DocumentTagAssignment]
    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]

    // MARK: - Init

    /// - Parameter onNavigateToDocument: where document-to-document jumps go when this reader is
    ///   hosted by a sheet rather than the Browse tab (#750). See the property's doc comment.
    init(entry: DocumentBrowserEntry,
         onNavigateToDocument: ((DocumentBrowserEntry, DocumentJump) -> Void)? = nil) {
        self.entry = entry
        self.onNavigateToDocument = onNavigateToDocument
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
                // A different document is loading into this reused view. Clear ALL selection-derived
                // state — not just the geometry — because Phase B made the range/text load-bearing:
                // `createHighlight` falls back to `lastValidSelectionRange`, and the floating bar,
                // NARA look-up, and note-linking read `webKitSelected*`/`pendingHighlightLink`. The
                // reloaded web view won't reliably fire `selectioncleared`, so anything left set here
                // would act against the NEW document — a wrong-offset highlight, or a note bound to
                // the outgoing document's highlight. (macOS clears the equivalent block in
                // HighlightCoordinator.reset(); this is the iOS twin the Phase-A note deferred.)
                clearSelectionState()
            }
            // Apply the default document mode on open (owner decision D2). On iPad/Mac the rail is the
            // persistent trailing inspector: .read closes it, .research opens it (via `panelVisible`),
            // .rememberLast leaves the persisted state untouched (defaults open).
            //
            // On iPhone the rail is a TRANSIENT bottom sheet, and per #404 it is ALWAYS user-triggered
            // — never auto-presented by the default mode, because a sheet covering the document on
            // every open is intrusive. So every mode resolves to CLOSED on iPhone (which also makes a
            // fresh install's unset `panelVisible` key, defaulting `true`, read as closed).
            switch defaultDocumentMode {
            case .read:
                panelVisible = false
            case .research:
                panelVisible = !isPhone
            case .rememberLast:
                if isPhone { panelVisible = false }
            }
            // #404: the iPhone rail is user-triggered only, so never leave its sheet up across a
            // document open — including SwiftUI view reuse, where a sheet raised for the PREVIOUS
            // document would otherwise persist over the new one. No-op on a fresh open (activeSheet is
            // already nil); inert on iPad/Mac, where the rail is the inspector and `activeSheet` is
            // never `.researchRail`. The `onChange` below keeps `panelVisible` in sync on dismissal.
            if isPhone, activeSheet?.id == "researchRail" { activeSheet = nil }
            // Wave R-2a: the `appState.logEvent(.documentOpen(…))` that used to sit here is gone.
            // It recorded the open a second time, ~50 lines from
            // `DocumentViewModel.recordReadingHistory` below, into a store nothing but the session
            // log read — the duplication this wave exists to remove. Reading history is the trail.
            bootstrapViewModel()
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
            personMentionStore: appState.personMentionStore,
            astCache: appState.documentASTCache
        )
        guard let vm else { return }
        guard let dm = appState.downloadManager,
              dm.isVolumeDownloaded(entry.volumeId) else { return }
        let url = dm.volumeURL(for: entry.volumeId)
        // Live-parse the publication year from the volume's TEI XML so the
        // citation tools show the volume's actual print year rather than a
        // coverage-range value that may be indexed in the bundled manifest
        // (mirrors CitationPopoverView.loadPublicationYear on macOS).
        Task {
            await vm.loadPublicationYear(from: url)
        }
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
        // Summarization failures must be visible even when the research panel is
        // hidden (Read mode) — previously they were logged and silently dropped.
        .alert(
            String(localized: "summary.error.title", defaultValue: "Summarization Failed"),
            isPresented: Binding(
                get: { vm.summarizationError != nil },
                set: { if !$0 { vm.summarizationError = nil } }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { }
        } message: {
            Text(vm.summarizationError ?? "")
        }
        .alert(
            String(localized: "document.crossref.download.title",
                   defaultValue: "Volume Not Downloaded"),
            isPresented: Binding(
                get: { crossRefDownloadVolumeId != nil },
                set: { if !$0 { crossRefDownloadVolumeId = nil } }
            ),
            presenting: crossRefDownloadVolumeId
        ) { volumeId in
            Button(String(localized: "document.crossref.download.confirm",
                          defaultValue: "Download Volume")) {
                if let dm = appState.downloadManager,
                   let entry = appState.manifestStore.entry(forVolumeId: volumeId) {
                    Task { await dm.enqueueDownload(entry) }
                }
                crossRefDownloadVolumeId = nil
            }
            Button(String(localized: "document.crossref.download.viewGraph",
                          defaultValue: "View Connections")) {
                crossRefDownloadVolumeId = nil
                activeSheet = .crossReferenceGraph
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                crossRefDownloadVolumeId = nil
            }
        } message: { volumeId in
            let title = appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
            Text(String(format: String(localized: "document.crossref.download.message %@",
                                        defaultValue: "The linked document is in “%@”, which isn't downloaded yet. Download it to open the document, or view how it connects to this one."),
                        title))
        }
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
                        // Search the resolved cross-corpus rollup identity — the same identity
                        // whose count the sheet displays. The raw per-volume `ref` is shared by
                        // unrelated people across volumes, so it is only the fallback when the
                        // rollup isn't built yet (people-eval finding G).
                        if let rollupId = vm.selectedPersonRollupId {
                            appState.openSearch(SearchParameters(personRollupId: rollupId,
                                                                      personLabel: person.name), from: sceneID)
                        } else {
                            appState.openSearch(SearchParameters(personRef: person.ref,
                                                                      personLabel: person.name), from: sceneID)
                        }
                        #if os(iOS)
                        // Switch to the Search tab so the handoff is visible — without this the
                        // sheet dismissed and nothing happened (people-eval finding F).
                        appState.openTab(.search, from: sceneID)
                        #endif
                    }
                )
            case .glossDetail(let gloss):
                GlossDetailSheet(gloss: gloss)
            case .citation:
                CitationSheetView(vm: vm)
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
                    // The graph benefits from extra vertical room — large layouts and
                    // the force-directed simulation are easier to read at full height.
                    // Opens at .large (Session 161: a half-height canvas was the
                    // weakest first impression of the feature); the user can still
                    // drag down to .medium as a system gesture.
                    .presentationDetents([.medium, .large], selection: $graphSheetDetent)
                    // #752 (audit L-39): sheets do not reliably inherit `\.sceneID`. Its sibling
                    // `.relatedDocuments` case injects this; without it, cross-references inside a
                    // document pushed in the graph sheet posted to `.anyWindow`.
                    .environment(\.sceneID, sceneID)
                } else {
                    // #757 (audit L-44): a nil store used to present a COMPLETELY BLANK sheet — this
                    // `if let` had no else, and neither entry point checked the store first. The
                    // store is nil during search-infrastructure boot and briefly while the read-only
                    // stores are recreated after an in-session reindex, so this is reachable, not
                    // theoretical. Says "still starting" instead, reusing #753's placeholder.
                    BootPlaceholderView(
                        detail: String(localized: "graphSheet.preparing.detail",
                                       defaultValue: "The cross-reference graph will appear in a moment."))
                        .presentationDetents([.medium, .large], selection: $graphSheetDetent)
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
                    },
                    documentHeader: entry.header,
                    documentDateline: entry.dateline,
                    documentVolumeId: entry.volumeId,
                    documentId: entry.documentId
                )
            case .tagPicker:
                UserTagPickerSheet(
                    entry: entry,
                    indexingPipeline: appState.indexingPipeline,
                    initialTagIds: Set(documentTagAssignments.map(\.tagId))
                )
            case .addToCollection:
                CollectionPickerSheet(entry: entry)
            case .addSelectionAsExcerpt(let capture):
                CollectionPickerSheet(entry: entry, excerpt: capture)
            case .personNotFound:
                personNotFoundSheet
            case .glossNotFound:
                glossNotFoundSheet
            case .naraLookup(let text, let blockContext):
                NARACatalogLookupView(initialText: text, blockContext: blockContext)
            case .brokenRefExplanation(let info):
                BrokenRefExplanationSheet(info: info)
                    .presentationDetents([.medium])
            case .relatedDocuments(let request):
                RelatedDocumentsSheet(appState: appState, request: request)
                    // #338 step 4: publish this window's scene id so RelatedDocuments' open-document
                    // action targets THIS window (a sheet doesn't reliably inherit `\.sceneID`).
                    .environment(\.sceneID, sceneID)
            case .researchRail:
                // iPhone bottom-sheet rail (iPad uses the trailing .inspector). medium/large detents
                // + a visible drag indicator (owner decision D2 / plan §5). Swipe-dismiss writes
                // panelVisible = false via the activeSheet onChange below.
                researchRail(vm: vm)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
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
        // Trailing Research rail — iPad only (Phase D). The binding reads `panelVisible` on iPad and
        // is pinned false on iPhone, where the rail is the `.researchRail` bottom sheet instead; this
        // keeps the shared `panelVisible` mode bit (edge-tap gate, macOS ⌘⇧R parity) but presents the
        // right surface per idiom. On compact width SwiftUI would otherwise auto-present the inspector
        // AS a sheet, colliding with the `.researchRail` sheet — the `!isPhone` guard prevents that.
        .inspector(isPresented: Binding(
            get: { !isPhone && panelVisible },
            set: { if !isPhone { panelVisible = $0 } }
        )) {
            researchRail(vm: vm)
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
        .onChange(of: activeSheet?.id) { oldId, newId in
            sheetIdentityChanged(from: oldId, to: newId)
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

    /// Reacts to the presented sheet changing identity.
    ///
    /// Extracted from the `.onChange` closure because `documentContent`'s modifier chain crossed
    /// the type checker's budget once `VolumeManifestEntry.downloadUrl` became optional (#777).
    /// The reported line is wherever the solver gave up, not the cause; a named method is solved
    /// on its own and takes the chain back under.
    private func sheetIdentityChanged(from oldId: String?, to newId: String?) {
        // Clear the persisted person selection when any sheet closes so the mention-count task
        // does not re-fire with a stale ref after dismissal.
        if newId == nil { vm?.selectedPerson = nil }
        // iPhone: `panelVisible` shadows "the rail sheet is up". Leaving `.researchRail` by ANY
        // path — swipe, the toggle, or a tile swapping the sheet for its target — writes false, so
        // the shared mode bit stays truthful and the Read-mode edge-tap zones re-enable once the
        // target is also dismissed (the gate additionally requires `activeSheet == nil`). On iPad
        // the rail is the `.inspector`, so `activeSheet` never becomes `.researchRail` there and
        // this is inert. (D2.)
        if oldId == "researchRail" { panelVisible = false }
    }

    // MARK: - Tool Windows (iPad Stage Manager) / sheet fallback

    /// Shows this document's cross-reference graph. When the platform can open a
    /// second window (Stage Manager on iPad), it opens the value-based graph scene with a
    /// `GraphWindowRequest` describing this document (#317 — self-describing, so the window
    /// survives a background/relaunch); otherwise it presents the in-place sheet so the graph
    /// is reachable on every device.
    private func openCrossReferenceGraph() {
        // #597 Phase 0: the `ExploreCrossReferencesTip().invalidate(…)` that used to sit here was
        // an orphan. Its `.popoverTip` was attached to a Cross-References toolbar button the
        // Research Rail redesign removed, so the tip could never display — while this call kept
        // marking it invalidated on every document open, burning the id for every existing user.
        // That is why the tip was deleted rather than re-anchored. Phase 1 adds its replacement
        // under a new type; when it lands, its `.invalidate` belongs here.
        if supportsMultipleWindows {
            appState.openAuxWindow(GraphWindowRequest(entry: entry), from: sceneID, using: openWindow)
        } else {
            activeSheet = .crossReferenceGraph
        }
    }

    /// Resolves this document's source note in the Source Explorer. When multi-window is
    /// available (Stage Manager on iPad), it opens the value-based Source Explorer scene with a
    /// `SourceExplorerRequest` carrying the note + display fields (#317 — self-describing, so a
    /// restored window rebuilds correctly); otherwise the in-place sheet.
    private func openSourceExplorer(vm: DocumentViewModel) {
        if supportsMultipleWindows {
            appState.openAuxWindow(SourceExplorerRequest(
                rawSourceNote: vm.sourceNote ?? "",
                documentYear: Self.extractYear(from: entry.dateline),
                documentHeader: entry.header,
                documentDateline: entry.dateline,
                documentVolumeId: entry.volumeId,
                documentId: entry.documentId
            ), from: sceneID, using: openWindow)
        } else {
            activeSheet = .sourceExplorer(vm.sourceNote ?? "")
        }
    }

    /// Opens this document's #308 find-related list. When multi-window is available (Stage Manager on
    /// iPad), it opens the value-based `RelatedDocumentsRequest` window (self-describing, so a restored
    /// window rebuilds correctly with its tuning); otherwise the in-place sheet. The request captures
    /// the user's persisted weight tuning and the document's coverage year.
    private func openRelatedDocuments() {
        let request = RelatedDocumentsRequest(
            anchor: DocumentKey(volumeId: entry.volumeId, documentId: entry.documentId),
            anchorYear: Self.extractYear(from: entry.dateline),
            weights: relatedWeights,
            scope: .allIndexed)
        if supportsMultipleWindows {
            appState.openAuxWindow(request, from: sceneID, using: openWindow)
        } else {
            activeSheet = .relatedDocuments(request)
        }
    }

    // MARK: - Tag Helpers


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
    ///
    /// It first tries the strict "Month D, YYYY" parse (`CentralFilesClassifier.datelineDateISO`,
    /// the same parse that drives roll/geo resolution downstream) so a stray 4-digit token in a
    /// footnote-bearing dateline blob can't hijack the year via first-match. It then falls back to
    /// a loose 18xx–20xx (through 2029) scan for datelines with no parseable Month-D-YYYY (e.g.
    /// bare-year editorial notes). Widening to 18xx lets pre-1906 FRUS datelines reach the Source
    /// Explorer's pre-1906 country-series resolution (issue #215). Keep in sync with the fallback
    /// pattern in `MacDocumentView.extractYear` and the inline extractor in `SupportingViews`.
    static func extractYear(from dateline: String?) -> Int? {
        guard let dl = dateline else { return nil }
        if let iso = CentralFilesClassifier.datelineDateISO(from: dl),
           let year = Int(iso.prefix(4)) {
            return year
        }
        let pattern = #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#
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
    /// - **iOS**: sets `appState.pendingTab = .browse` so the Browse tab comes to
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
    /// Routes a tapped in-document cross-reference through
    /// `FRUSURLSchemeHandler.resolveCrossRefTarget` (Session 162): documents
    /// navigate (footnote-suffixed ids resolve to their base document), printed
    /// pages resolve via `PageRangeStore`, and absolute URLs open externally.
    private func handleCrossRefTap(target: String, targetVolumeId: String?) {
        switch FRUSURLSchemeHandler.resolveCrossRefTarget(target, volumeId: targetVolumeId) {
        case .document(let volumeId, let documentId):
            navigateToCrossRef(documentId: documentId, volumeId: volumeId ?? entry.volumeId)

        case .page(let volumeId, let page):
            resolvePageReference(page: page, volumeId: volumeId ?? entry.volumeId)

        case .external(let url):
            // NOT `openURL(url)`. That was `@Environment(\.openURL)` — the very value this view
            // REPLACES a few lines below, in `documentContent`'s
            // `.environment(\.openURL, OpenURLAction { … })`. Reading it made DocumentView depend
            // on an environment key it also writes, and because `OpenURLAction` wraps a closure it
            // is never equal to the previous one: every body evaluation installed a "new" value,
            // which invalidated the view that read it, which rebuilt the action. Measured on an
            // iPad with the body counter armed: 750+ evaluations of `DocumentView.body` for ONE
            // document open, accelerating 3/s → 31/s, `_printChanges` naming `_openURL` every
            // time — enough main-thread work to trip the 10s scene-update watchdog.
            //
            // Going straight to the system opener also expresses the intent better: this case is
            // an ordinary http(s) link, and routing it through the app's own frusexplorer://
            // interceptor only to have it fall through to `.systemAction` was a detour.
            UIApplication.shared.open(url)

        case .unresolved:
            #if DEBUG
            print("[DocumentView] Cross-ref skipped (unresolvable target): \(target)")
            #endif
        }
    }

    /// Opens `documentId` in `volumeId`, or the cross-reference graph when the
    /// volume isn't downloaded.
    private func navigateToCrossRef(documentId: String, volumeId: String) {
        guard !documentId.isEmpty else { return }
        guard let dm = appState.downloadManager, dm.isVolumeDownloaded(volumeId) else {
            crossRefDownloadVolumeId = volumeId
            #if DEBUG
            print("[DocumentView] Cross-ref: \(volumeId) not downloaded, offering download")
            #endif
            return
        }

        let crossEntry = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            documentNumber: nil,
            // Use documentId as a non-empty placeholder so the breadcrumb label is
            // visible while the document loads. DocumentView replaces the navigation
            // title with vm.documentTitle once the XML has been parsed.
            header: documentId,
            dateline: nil,
            sourceNote: nil
        )
        // A sheet-hosted reader follows the reference inside its own stack (#750).
        if let onNavigateToDocument {
            onNavigateToDocument(crossEntry, .push)
            #if DEBUG
            print("[DocumentView] Cross-ref tap → host stack: \(volumeId)/\(documentId)")
            #endif
            return
        }
        #if os(iOS)
        appState.openTab(.browse, from: sceneID)
        #endif
        appState.openBrowseDocument(crossEntry, from: sceneID)

        #if DEBUG
        print("[DocumentView] Cross-ref tap → \(volumeId)/\(documentId)")
        #endif
    }

    /// Resolves a printed-page reference to its containing document and opens it.
    private func resolvePageReference(page: Int, volumeId: String) {
        guard let store = appState.pageRangeStore else {
            #if DEBUG
            print("[DocumentView] Page ref: PageRangeStore unavailable")
            #endif
            return
        }
        Task {
            let documentId = (try? await store.document(forPage: page, inVolume: volumeId)) ?? nil
            await MainActor.run {
                if let documentId {
                    navigateToCrossRef(documentId: documentId, volumeId: volumeId)
                } else {
                    #if DEBUG
                    print("[DocumentView] Page ref: p. \(page) of \(volumeId) not in page index")
                    #endif
                }
            }
        }
    }

    // MARK: - Toolbar

    /// Document toolbar — collapsed to a single **Research rail toggle** (Phase D).
    ///
    /// The redesign moved every former toolbar action onto the rail (its tiles + the
    /// Summary/Notes/Tags/Collections accordions) or the floating selection bar, so the navigation
    /// bar now carries just this one control. Back is free (the enclosing `NavigationStack`). The
    /// toggle shows/hides the rail: on iPad the trailing `.inspector`, on iPhone the `.researchRail`
    /// bottom sheet. "Open in New Window" lives in the rail header on iPad (D8); the summarize-failure
    /// alert and the retired color picker's replacement (the floating bar's colour dots) live outside
    /// the toolbar, so nothing is stranded by the collapse.
    @ToolbarContentBuilder
    private func documentToolbar(vm: DocumentViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                toggleRail()
            } label: {
                // R-8: named `Label`, not a bare `Image`. This toolbar holds one item and
                // so cannot overflow today; the shape is normalised so that adding a
                // second item can never silently rename this one to its SF Symbol.
                Label(Self.researchRailName, systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(railToggleActive ? Color.accentColor : Color.primary)
            }
            .controlHelp(
                Self.researchRailName,
                detail: String(localized: "document.toolbar.panelMode.hint",
                               defaultValue: "Read mode also enables edge-tap navigation to the previous and next document in this volume"),
                systemImage: "doc.text.magnifyingglass"
            )
            .accessibilityAddTraits(railToggleActive ? [.isSelected] : [])
            .accessibilityIdentifier("researchRailToggle")
            // #597 Phase 1. On iPhone the rail is forced closed on every open (#404), so this one
            // unlabelled glyph is the only door to every document-scoped tool.
            //
            // iPHONE ONLY, and the gate is load-bearing. `DocumentView` is also the iPad reader,
            // where `panelVisible = !isPhone` means the rail is already open — the tip would point
            // at tools the user can see. Worse, it presented a UIPopover in the SAME main-thread
            // pass that reflows the split view for the `.inspector` and inserts the WKWebView,
            // which drove a view-graph update loop: 90s of CPU in 101s (89%), the main thread never
            // returning to the run loop, the spinner still animating off the render server, no
            // touch ever handled, and a `scene-update` watchdog kill at 10s. The doc comment above
            // and #634's PR body both asserted this was already iPhone-only. It never was — there
            // was no gate. `popoverTip` takes an optional, so `nil` is the entire fix.
            .popoverTip(isPhone ? ResearchRailTip() : nil)
        }
    }

    /// The rail toggle's name, read from its `Label` (what an overflowed toolbar row would
    /// announce) as well as from `.controlHelp`. One definition, so the two cannot drift.
    static var researchRailName: String {
        String(localized: "document.toolbar.researchRail.a11y", defaultValue: "Research panel")
    }

    /// Whether the rail is currently visible — accent-tints the toggle. iPad reads `panelVisible`
    /// (the `.inspector` binding); iPhone reads whether the `.researchRail` sheet is up.
    private var railToggleActive: Bool {
        isPhone ? (activeSheet?.id == "researchRail") : panelVisible
    }

    /// Shows/hides the rail from the toolbar toggle. iPad drives the `.inspector` via `panelVisible`;
    /// iPhone presents/dismisses the `.researchRail` sheet — dismissing writes `panelVisible = false`
    /// (via the `activeSheet` onChange) so Research mode and the edge-tap gate stay coherent (D2).
    private func toggleRail() {
        // The user found the door — retire the tip that pointed at it.
        ResearchRailTip().invalidate(reason: .actionPerformed)
        if isPhone {
            if activeSheet?.id == "researchRail" {
                activeSheet = nil
            } else {
                panelVisible = true
                activeSheet = .researchRail
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { panelVisible.toggle() }
        }
    }

    /// Builds the shared Research rail for this document, wiring the iOS-specific note-composer and
    /// tool presentations. Note editing presents `DocumentView`'s sheets; the tiles route through
    /// ``openRailTool(_:)``. Mounted twice — the iPad `.inspector` and the iPhone `.researchRail`
    /// sheet — so the closures are captured here once.
    private func researchRail(vm: DocumentViewModel) -> some View {
        ResearchRailView(
            entry: entry,
            vm: vm,
            pendingHighlightLink: pendingHighlightLink,
            onAddNote: { activeSheet = .noteEditor },
            onEditNote: { note in activeSheet = .editNote(note) },
            onAddNoteToHighlight: { highlightId in
                pendingHighlightLink = nil
                activeSheet = .noteEditorForHighlight(highlightId)
            },
            onOpenTool: { tool in openRailTool(tool, vm: vm) })
        // #338 step 2: the rail is presented via `.inspector` (iPad) / `.researchRail` sheet
        // (iPhone) — neither reliably inherits `\.sceneID` (review Finding 1), so publish it
        // explicitly here so the rail's Word Cloud tile addresses its hand-off to THIS window.
        .environment(\.sceneID, sceneID)
    }

    /// Fulfils a rail tile/summary tap with `DocumentView`'s existing iOS presentation. Cite and
    /// Summarize present consolidated sheets; Sources/Graph/Related reuse the same handlers the old
    /// toolbar used (which open a Stage-Manager window when available, else an in-place sheet); Word
    /// Cloud rides the app-level `pendingWordCloud` hand-off observed in `MainTabView`.
    private func openRailTool(_ tool: ResearchRailTool, vm: DocumentViewModel) {
        switch tool {
        case .cite:
            activeSheet = .citation
        case .wordCloud:
            // Word Cloud is the one tool NOT presented through `activeSheet` — it rides the
            // app-level `pendingWordCloud` sheet on `MainTabView`, an ANCESTOR of this view. On
            // iPhone the rail is a live `.sheet` (`.researchRail`), and SwiftUI won't present the
            // ancestor sheet over a descendant one, so the tap would be a dead no-op (and the
            // word cloud would later ghost-present when the rail is dismissed). Set the hand-off
            // then dismiss the rail sheet — the same set-then-dismiss order `ChronologyView` uses.
            // On iPad the rail is the `.inspector` column (not a sheet), so nothing to dismiss.
            appState.openWordCloud(.document(
                volumeId: entry.volumeId, documentId: entry.documentId), from: sceneID)
            if activeSheet?.id == "researchRail" { activeSheet = nil }
        case .sources:
            openSourceExplorer(vm: vm)
        case .graph:
            openCrossReferenceGraph()
        case .related:
            openRelatedDocuments()
        case .summarize:
            activeSheet = .summarizePromptPicker
        }
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
                    .font(.system(size: FRUSTheme.cappedGlyphSize(notFoundGlyphSize, base: 44)))
                    .foregroundStyle(.secondary)
                Text(String(localized: "personNotFound.title",
                            defaultValue: "Person Information Unavailable"))
                    .font(.headline)
                Text(String(localized: "personNotFound.detail",
                            defaultValue: "Detailed information about this person isn't available for this volume. To populate person data, re-index the volume in Settings → Volumes & Storage."))
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
                    .font(.system(size: FRUSTheme.cappedGlyphSize(notFoundGlyphSize, base: 44)))
                    .foregroundStyle(.secondary)
                Text(String(localized: "glossNotFound.title",
                            defaultValue: "Term Definition Unavailable"))
                    .font(.headline)
                Text(String(localized: "glossNotFound.detail",
                            defaultValue: "A definition for this term isn't available for this volume. To populate term data, re-index the volume in Settings → Volumes & Storage."))
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
                },
                onBrokenRefTap: { info in
                    if let info { activeSheet = .brokenRefExplanation(info) }
                }
            )
            .highlights(highlights)
            .onSelectionChanged { selection in
                if selection.hasOffsets {
                    // In-document selection with valid offsets — enables highlights + lookup.
                    webKitSelectionRange = (selection.start, selection.end)
                    // Preserved past the overflow-menu blur for excerpt capture; must
                    // always describe the same selection as webKitSelectedText, so it
                    // is nil'd on the footnote branch below and for empty text.
                    lastValidSelectionRange = selection.text.isEmpty ? nil : (selection.start, selection.end)
                    webKitSelectedBlockText = nil
                } else {
                    // Footnote / out-of-document selection — text only, no valid offsets.
                    // Clear the range so highlight creation is not offered, but keep the
                    // text so NARA lookup remains available, plus the enclosing note body
                    // so the lookup can characterise the footnote's citations (#269).
                    webKitSelectionRange = nil
                    lastValidSelectionRange = nil
                    webKitSelectedBlockText = selection.blockText.isEmpty ? nil : selection.blockText
                }
                webKitSelectedText = selection.text.isEmpty ? nil : selection.text
                // Drive the floating selection bar (Phase B) straight from the payload. Anchor it
                // at the selection rect, but hide it while pinch-zoomed (D4) — the rect is in
                // unzoomed point space, so a zoomed anchor would be wrong. A footnote/out-of-document
                // selection disables the dots + Excerpt (no offsets), keeping Look Up + Note.
                if let rect = selection.rect, !selection.text.isEmpty,
                   abs(selection.scale - 1) < 0.01 {
                    selectionBar.present(rect: rect, atFootnote: !selection.hasOffsets)
                } else {
                    selectionBar.hideNow()
                }
            }
            .onSelectionCleared {
                // Only clear the offset range. webKitSelectedText is intentionally
                // preserved so the NARA lookup button stays available after the selection
                // is released (e.g. when the user opens the More menu on iOS, which causes
                // the WebView to blur and fire a false selectioncleared event).
                // webKitSelectedText is cleared when the NARA lookup button is tapped.
                // lastValidSelectionRange is likewise preserved so the overflow-menu
                // "Add Selection as Excerpt" action still captures the A9 anchors.
                webKitSelectionRange = nil
                // Debounced so the bar survives the false `selectioncleared` the web view fires
                // when a floating-bar tap blurs it; a real clear lets it elapse.
                selectionBar.scheduleHide()
            }
            .onSelectionScrolled {
                // The anchor rect is stale after a scroll (or a pinch-zoom / rotation, which the JS
                // also routes here) — hide the bar immediately so it never floats over stale text.
                selectionBar.hideNow()
            }
            .onHighlightTapped  { start, end in highlightToDelete = (start, end) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            documentEdgeNavigationOverlay(vm: vm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                floatingSelectionBarOverlay(vm: vm)
            }
            // The inline Summary/Notes/Tags accordion is retired (Phase D) — the shared Research rail
            // (iPad `.inspector` / iPhone `.researchRail` sheet) is now the one research surface.
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Floating Selection Bar (Research-rail Phase B)

    /// The floating selection bar overlay: a debounced, rect-anchored ``FloatingSelectionBar``
    /// carrying the four highlight-colour dots plus Excerpt · Look Up · Note, replacing the former
    /// iOS text-selection edit-menu verbs. Anchored *below* the selection (`below: true`) so the
    /// system edit menu (Copy, Look Up, Translate) keeps the space above it (D3). The dots create a
    /// highlight; Excerpt/Look Up/Note reuse the same flows the toolbar and NARA hand-off use, all
    /// of which read the blur-surviving `lastValidSelectionRange`/`webKitSelectedText`.
    @ViewBuilder
    private func floatingSelectionBarOverlay(vm: DocumentViewModel) -> some View {
        GeometryReader { proxy in
            if let anchor = selectionBar.anchor {
                FloatingSelectionBar(
                    atFootnote: selectionBar.atFootnote,
                    compact: sizeClass == .compact,
                    onHighlight: { color in
                        createHighlight(color: color)
                        selectionBar.hideNow()
                    },
                    onExcerpt: {
                        if let capture = selectionExcerptCapture(vm: vm) {
                            activeSheet = .addSelectionAsExcerpt(capture)
                        }
                        selectionBar.hideNow()
                    },
                    onLookUp: {
                        let text = webKitSelectedText ?? ""
                        let blockContext = webKitSelectedBlockText
                        webKitSelectedText = nil
                        webKitSelectedBlockText = nil
                        activeSheet = .naraLookup(text: text, blockContext: blockContext)
                        selectionBar.hideNow()
                    },
                    onNote: {
                        // Always a document note — NOT linked to `pendingHighlightLink`. Creating a
                        // highlight hides the bar, so a bar tap here can only ever land on a *later,
                        // different* selection; linking to the still-pending earlier highlight would
                        // silently misattribute the note. The labeled toolbar "Add Note to Highlight"
                        // (which fires immediately after highlighting) remains the linked path.
                        activeSheet = .noteEditor
                        selectionBar.hideNow()
                    }
                )
                .modifier(FloatingSelectionBarPositioner(
                    // gap 22 clears the WKWebView selection drag-handle that hangs below maxY, so the
                    // user can still grab it to extend the selection without hitting the bar (M3).
                    selection: anchor, container: proxy.size, below: true, gap: 22))
            }
        }
        .allowsHitTesting(selectionBar.isVisible)
        .animation(.easeOut(duration: 0.25), value: selectionBar.isVisible)
    }

    // MARK: - Edge-Tap Document Navigation (Read mode "page-turn")

    /// Invisible leading/trailing edge-tap zones that navigate to the previous/next
    /// document in the current volume — an ebook-reader-style "page-turn" gesture.
    ///
    /// Shown only when:
    ///  - **The user has not disabled it** (`edgeTapNavigationEnabled`,
    ///    `SettingsKeys.edgeTapNavigationEnabled`, default on). Some readers
    ///    trigger the zones accidentally; this is an escape hatch (Session 154).
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
    ///   1.1 — Session 154: gated on `edgeTapNavigationEnabled` preference
    ///   1.2 — Phase D: also suppressed while ANY DocumentView sheet is up (`activeSheet != nil`) —
    ///          on iPhone the rail sheet keeps `panelVisible` false, so without this term the zones
    ///          would stay live under person/citation/NARA/rail sheets and steal edge taps.
    @ViewBuilder
    private func documentEdgeNavigationOverlay(vm: DocumentViewModel) -> some View {
        if !panelVisible && edgeTapNavigationEnabled && activeSheet == nil {
            // #597 Phase 1: the tip needs no `Tip.Rule` — this `if` IS the rule. The overlay only
            // exists when the capability is live, so the anchor cannot appear while it is not.
            HStack(spacing: 0) {
                documentEdgeTapZone(
                    adjacentEntry: vm.previousEntry,
                    systemImage: "chevron.left",
                    label: String(localized: "document.nav.previous.a11y",
                                  defaultValue: "Previous document"),
                    hint: String(localized: "document.nav.previous.hint",
                                 defaultValue: "Opens the previous document in this volume"),
                    // Exactly one zone carries the tip: the leading one when it renders, else
                    // the trailing one. At a volume boundary the empty zone shows nothing, so
                    // the anchor follows whichever strip actually exists.
                    showsTip: vm.previousEntry != nil
                )
                Spacer(minLength: 0)
                documentEdgeTapZone(
                    adjacentEntry: vm.nextEntry,
                    systemImage: "chevron.right",
                    label: String(localized: "document.nav.next.a11y",
                                  defaultValue: "Next document"),
                    hint: String(localized: "document.nav.next.hint",
                                 defaultValue: "Opens the next document in this volume"),
                    showsTip: vm.previousEntry == nil
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Let the zones themselves opt into hit-testing; the HStack/Spacer must
            // not swallow taps meant for the web view's central reading column.
            .allowsHitTesting(true)
            // NO `.popoverTip` HERE. #597 Phase 1 anchored the tip on this HStack "so the popover
            // is centred over the reading area" — but `.popoverTip` presents with
            // `attachmentAnchor: .rect(.bounds)`, and these bounds ARE the reading area. While a
            // popover is up, `UIPopoverPresentationController` installs a full-window blocker with
            // `passthroughViews == nil`: a TAP dismisses it, a PAN is simply swallowed. So the
            // document would not scroll, and because scrolling never dismissed the tip it never
            // recorded an impression, so `MaxDisplayCount(3)` never counted down and the block was
            // permanent. The tip now hangs off one 56pt zone (below), which is what it points at.
        }
    }

    /// A single transparent edge-tap zone. Renders nothing (and accepts no taps)
    /// when `adjacentEntry` is `nil`, so volume boundaries show no dead tap area.
    @ViewBuilder
    private func documentEdgeTapZone(
        adjacentEntry: DocumentBrowserEntry?,
        systemImage: String,
        label: String,
        hint: String,
        showsTip: Bool = false
    ) -> some View {
        if let adjacentEntry {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: FRUSTheme.documentEdgeTapZoneWidth)
                .onTapGesture {
                    // The gesture was found — retire the tip that revealed it.
                    EdgeTapNavigationTip().invalidate(reason: .actionPerformed)
                    navigateToAdjacentDocument(adjacentEntry)
                }
                // A 56pt anchor, not the whole reading area — see the note on the overlay above.
                // `popoverTip` takes an optional, so the non-tip zone passes `nil`.
                .popoverTip(showsTip ? EdgeTapNavigationTip() : nil)
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
        // A sheet-hosted reader turns the page inside its own stack (#750).
        if let onNavigateToDocument {
            onNavigateToDocument(adjacent, .replace)
            #if DEBUG
            print("[DocumentView] Edge-tap page-turn → host stack: \(adjacent.volumeId)/\(adjacent.documentId)")
            #endif
            return
        }
        #if os(iOS)
        appState.openTab(.browse, from: sceneID)
        #endif
        appState.openBrowseDocument(adjacent, from: sceneID)
        #if DEBUG
        print("[DocumentView] Edge-tap page-turn → \(adjacent.volumeId)/\(adjacent.documentId)")
        #endif
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

    /// Drops every piece of text-selection state when this view is reused for a different document
    /// (see the `.task(id:)` reset), so no offsets/text/highlight-link from the outgoing document
    /// can act against the incoming one — the iOS counterpart to macOS's `HighlightCoordinator.reset()`.
    /// Load-bearing since Phase B: `createHighlight` falls back to `lastValidSelectionRange`, and the
    /// floating bar / NARA look-up read `webKitSelected*`.
    @MainActor
    private func clearSelectionState() {
        selectionBar.hideNow()
        webKitSelectionRange = nil
        lastValidSelectionRange = nil
        webKitSelectedText = nil
        webKitSelectedBlockText = nil
        pendingHighlightLink = nil
    }

    @MainActor
    private func createHighlight(color: DocumentHighlight.Color) {
        // Fall back to the blur-surviving `lastValidSelectionRange`: tapping a floating-bar dot
        // blurs the web view, which fires a false `selectioncleared` that nils `webKitSelectionRange`
        // before this runs (the same race excerpt capture already guards against). Both track the
        // same in-document selection, so the fallback recovers the correct offsets.
        guard let range = webKitSelectionRange ?? lastValidSelectionRange,
              let model = vm?.renderModel else { return }
        let rv = ASTToRenderNodeConverter.renderingVersion(for: model)
        // Block-aware extraction: a selection spanning paragraph boundaries keeps its
        // "\n\n" breaks instead of fusing at the flat text's zero-width block seams —
        // this string is also what excerpt captures freeze (CollectionExcerpts).
        let selectedText = flatTextExcerpt(from: model, start: range.0, end: range.1) ?? ""
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

    // MARK: - Excerpt Capture (Authoring Phase 5)

    /// Freezes the current text selection into an excerpt capture (creation path b).
    ///
    /// What the selection APIs expose (see `FRUSDocumentWebView.onSelectionChanged`):
    /// an in-document selection reports flat-text offsets (`webKitSelectionRange`, kept
    /// alive across the overflow-menu blur by `lastValidSelectionRange`) plus the raw
    /// text; a footnote/out-of-document selection reports text only. When offsets
    /// exist, the passage is re-extracted block-aware from the flat text
    /// (`flatTextExcerpt` — the same canonicalization `createHighlight` stores, with
    /// paragraph breaks restored at block seams) and the document's current
    /// `renderingVersion` is recorded; otherwise the raw selection text is frozen with
    /// `nil` anchors — a fully valid excerpt under A9, just not precision-renderable
    /// later. Anchors are only ever stored alongside the re-extracted text, so they
    /// always delimit the flat-text span the frozen passage came from.
    ///
    /// - Parameter vm: The document view model (render model source).
    /// - Returns: The capture, or `nil` when no selection text is available.
    @MainActor
    private func selectionExcerptCapture(vm: DocumentViewModel) -> CollectionExcerptCapture? {
        var text = webKitSelectedText ?? ""
        var start: Int? = nil
        var end: Int? = nil
        var renderingVersion: String? = nil
        if let range = webKitSelectionRange ?? lastValidSelectionRange,
           let model = vm.renderModel,
           let sliced = flatTextExcerpt(from: model, start: range.0, end: range.1) {
            text = sliced
            start = range.0
            end = range.1
            renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
        }
        guard !text.isEmpty else { return nil }
        return CollectionExcerptCapture(
            text: text,
            volumeId: entry.volumeId,
            documentId: entry.documentId,
            start: start,
            end: end,
            renderingVersion: renderingVersion,
            colorTag: nil)
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

// MARK: - DocumentShareMenu

/// Document-level Share / Export toolbar menu (iOS) — independent of the citation
/// sheet. Owns the actions that *send the document somewhere*: into the user's
/// Zotero library via the Web API, out as a Zotero-importable file (BibTeX/RIS), or
/// via the system share sheet. Citation viewing/copying stays on the Citation menu.
///
/// Version history:
///   1.0 — Document Share/Export control split out from the citation sheet
struct DocumentShareMenu<LabelContent: View>: View {
    let vm: DocumentViewModel
    /// The `Menu`'s tap target. The default construction (see the extension below) uses the standard
    /// "Share" `Label`; the Research rail passes a tile-shaped label (Phase D).
    let label: () -> LabelContent
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    init(vm: DocumentViewModel, @ViewBuilder label: @escaping () -> LabelContent) {
        self.vm = vm
        self.label = label
    }

    @State private var bibtexFileURL: URL?
    @State private var risFileURL: URL?
    @State private var zoteroItem: ZoteroJSONExporter.Item?
    @State private var zoteroSending = false
    @State private var zoteroResult: ZoteroSendResult?
    @State private var zoteroError: String?

    var body: some View {
        Menu {
            if ZoteroAccountStore.shared.isConnected, zoteroItem != nil {
                Button {
                    Task { await sendToZoteroLibrary() }
                } label: {
                    Label(String(localized: "document.share.sendZoteroLibrary",
                                 defaultValue: "Send to Zotero Library…"), systemImage: "books.vertical")
                }
                .disabled(zoteroSending)
                Divider()
            }
            if let bibtexFileURL {
                ShareLink(item: bibtexFileURL) {
                    Label(String(localized: "document.share.bibtexFile",
                                 defaultValue: "Export Zotero file (BibTeX)…"), systemImage: "doc")
                }
            }
            if let risFileURL {
                ShareLink(item: risFileURL) {
                    Label(String(localized: "document.share.risFile",
                                 defaultValue: "Export Zotero file (RIS)…"), systemImage: "doc")
                }
            }
            if let message = vm.shareableCitationMessage {
                ShareLink(item: message) {
                    Label(String(localized: "document.share.citation",
                                 defaultValue: "Share Citation…"), systemImage: "quote.bubble")
                }
            }
        } label: {
            label()
        }
        .controlHelp(
            String(localized: "document.toolbar.share", defaultValue: "Share"),
            detail: String(localized: "document.toolbar.share.help",
                           defaultValue: "Send this document to your Zotero library, export a Zotero file, or share its citation"),
            systemImage: "square.and.arrow.up"
        )
        .task(id: vm.entry.documentId) { prepareExportFiles() }
        .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
        .alert(
            String(localized: "document.share.zotero.error.title", defaultValue: "Couldn't Send to Zotero"),
            isPresented: Binding(get: { zoteroError != nil }, set: { if !$0 { zoteroError = nil } }),
            presenting: zoteroError
        ) { _ in
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { Text($0) }
    }

    /// Pushes this single document (with its tags + notes) into the user's Zotero
    /// library via the Web API. No collection is created — it lands in My Library.
    private func sendToZoteroLibrary() async {
        guard let item = zoteroItem else { return }
        let store = ZoteroAccountStore.shared
        guard let apiKey = store.retrieveKey(), let userID = store.userID else {
            zoteroError = ZoteroAPIError.missingCredentials.errorDescription
            return
        }
        zoteroSending = true
        defer { zoteroSending = false }
        do {
            let result = try await ZoteroAPIClient().send(
                items: [item], collectionName: nil,
                apiKey: apiKey, userID: userID, username: store.username)
            zoteroResult = result
        } catch {
            zoteroError = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func zoteroResultMessage(_ result: ZoteroSendResult) -> String {
        String(format: String(localized: "document.share.zotero.result %lld %lld",
                              defaultValue: "Added %lld document and %lld notes to Zotero."),
               Int64(result.addedItems), Int64(result.addedNotes))
    }

    /// Writes the BibTeX and RIS exports to temporary files for `ShareLink`, and
    /// resolves the document's Zotero item (carrying tags + notes) for the Web API send.
    private func prepareExportFiles() {
        if let bibtex = vm.bibtexCitation {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(vm.entry.volumeId)-\(vm.entry.documentId).bib")
            if (try? bibtex.write(to: url, atomically: true, encoding: .utf8)) != nil {
                bibtexFileURL = url
            }
        }
        let resolved = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: vm.entry.documentId, volumeId: vm.entry.volumeId, context: modelContext)
        if let item = vm.zoteroItem(tags: resolved.tags, notes: resolved.notes) {
            zoteroItem = item
            let ris = RISExporter().export(zoteroItem: item)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(vm.entry.volumeId)-\(vm.entry.documentId).ris")
            if (try? ris.write(to: url, atomically: true, encoding: .utf8)) != nil {
                risFileURL = url
            }
        }
    }
}


// MARK: - CitationSheetView

/// Displays a formatted citation string in a sheet with Copy/Done actions and
/// an Export menu (BibTeX/RIS copy plus "Send to Zotero" share actions).
///
/// `formattedCitation` wraps the FRUS series title in Markdown italic syntax
/// (`_Foreign Relations of the United States_…`, see
/// `HistoryAtStateCitationFormatter.italicizedTitle`). Plain `Text(String)`
/// does not interpret Markdown for runtime strings, so the underscores would
/// render literally; parsing into an `AttributedString` first renders the
/// series title in actual italics — mirroring `CitationPopoverView` on macOS.
///
/// Version history:
///   1.0 — Session 59: initial implementation
///   1.1 — Session 155: added Export menu (Copy BibTeX/RIS, "Send to Zotero"
///          BibTeX/JSON share actions); takes `vm` instead of a raw string
private struct CitationSheetView: View {
    let vm: DocumentViewModel
    @Environment(\.dismiss) private var dismiss

    private var citation: String {
        vm.formattedCitation ?? ""
    }

    /// The citation parsed as inline Markdown so `_…_` renders as italics;
    /// falls back to the raw string if parsing fails.
    private var attributedCitation: AttributedString {
        (try? AttributedString(
            markdown: citation,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(citation)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(attributedCitation)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // One-tap copy of the formatted prose citation (italic markers stripped) —
                    // restores the discrete "Copy Citation" the old toolbar Citation menu carried,
                    // which the Cite rail tile → this sheet otherwise dropped (Phase D review).
                    Button {
                        if let plain = vm.plainTextFormattedCitation {
                            copyToPasteboard(plain)
                        }
                    } label: {
                        Label(String(localized: "document.citation.copy", defaultValue: "Copy Citation"),
                              systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.plainTextFormattedCitation == nil)

                    exportMenu
                }
                .padding()
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

    // MARK: - Export Menu

    @ViewBuilder
    private var exportMenu: some View {
        Menu {
            Button {
                if let bibtex = vm.bibtexCitation {
                    copyToPasteboard(bibtex)
                }
            } label: {
                Label(String(localized: "document.citation.copyBibtex", defaultValue: "Copy BibTeX"), systemImage: "doc.on.clipboard")
            }
            .disabled(vm.bibtexCitation == nil)

            Button {
                if let ris = vm.risCitation {
                    copyToPasteboard(ris)
                }
            } label: {
                Label(String(localized: "document.citation.copyRis", defaultValue: "Copy RIS"), systemImage: "doc.on.clipboard")
            }
            .disabled(vm.risCitation == nil)
        } label: {
            Label(String(localized: "document.citation.copyAs", defaultValue: "Copy as…"),
                  systemImage: "doc.on.doc")
        }
    }

    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - SummaryStripView

struct SummaryStripView: View {
    @Bindable var vm: DocumentViewModel
    let summary: GeneratedSummary
    let totalCount: Int

    /// Number of lines shown before the summary is collapsed behind "Show more".
    private static let collapsedLineLimit = 4

    /// Whether the full summary text is shown. Collapsed by default so a long
    /// summary doesn't dominate the pinned header; tapping expands it inline.
    @State private var isExpanded = false

    /// `true` once the collapsed text is detected to overflow `collapsedLineLimit`
    /// lines — gates whether the "Show more" control appears at all.
    @State private var isTruncated = false

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
                .lineLimit(isExpanded ? nil : Self.collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    // Behind the (possibly clamped) text, try to fit the full text
                    // into the same proposed height. If it doesn't fit, the visible
                    // text is truncated and the "Show more" control should appear.
                    ViewThatFits(in: .vertical) {
                        Text(summary.responseText)
                            .font(.callout)
                            .hidden()
                            .accessibilityHidden(true)
                        Color.clear
                            .onAppear { isTruncated = true }
                            .accessibilityHidden(true)
                    }
                }
            if isTruncated || isExpanded {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Text(isExpanded
                         ? String(localized: "document.summary.showLess", defaultValue: "Show less")
                         : String(localized: "document.summary.showMore", defaultValue: "Show more"))
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderless)
            }
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
                                   defaultValue: "Add a prompt in Settings → Summarization.")
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
        // #312 follow-up: full-row tap target — both modifiers, in this order. Prompt names are
        // short, so without the frame most of this picker row is dead under `.buttonStyle(.plain)`.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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

// (Document-level subject tags were fully retired in Session 09: the display layer was
// removed earlier, and the underlying SubjectTagStore / DocumentViewModel.subjectTags /
// bundled taxonomy were dropped for low signal-to-noise. The successor is the
// volume-level subject-profiles feature in the volume browser.)

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

// The iOS document-level user-tag picker is now the shared `UserTagPickerSheet`
// (`DocumentView/UserTagPickerSheet.swift`), consolidated with the former macOS
// `MacTagPickerSheet` (Session 1 / #242).


#endif // os(iOS)
