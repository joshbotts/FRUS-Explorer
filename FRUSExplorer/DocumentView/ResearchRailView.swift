// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ResearchRailTool

/// A document-scoped tool the Research rail asks its host to open (Phase D iOS routing).
///
/// On macOS every tile self-opens a window or popover, so this is unused there. On iOS the tiles have
/// no `openWindow`, and the target presentations (citation sheet, Source Explorer, cross-reference
/// graph, Related list, the word-cloud hand-off, the summarize prompt picker) are owned by
/// `DocumentView` — so the rail signals intent through `onOpenTool` and the host presents. `share`
/// is deliberately absent: it is a `Menu` and stays self-owned in the rail on both platforms.
enum ResearchRailTool {
    /// Cite this document (iOS: the `.citation` sheet).
    case cite
    /// Word cloud of this document's terms (iOS: `appState.pendingWordCloud`).
    case wordCloud
    /// Resolve the source note in the Source Explorer.
    case sources
    /// This document's cross-reference graph.
    case graph
    /// Find related documents.
    case related
    /// Reveal this document on the semantic map.
    case semanticMap
    /// Generate a summary (iOS: the `.summarizePromptPicker` sheet).
    case summarize
}

// MARK: - ResearchRailView

/// The trailing **Research rail** — the shared document research surface introduced by the
/// Research-rail redesign (Phase C1). It replaces the macOS research strip + bottom accordion with
/// one panel: a `RESEARCH` header, a 3×2 grid of document-scoped action tiles, and a stack of
/// expandable accordions (Summary · Notes · Tags · Collections).
///
/// ## Ownership
/// The rail is largely self-contained — it owns its tile actions (macOS windows/popovers), its tag
/// and collection pickers, and re-declares the notes/tags/collection-membership `@Query`s from
/// `entry`. Only note *editing* is injected (`onAddNote`/`onEditNote`), because it differs by
/// platform (macOS opens the note-composer window; iOS presents a sheet) and is shared with the
/// ⌘⇧N Document-menu command.
///
/// ## Platform status
/// C1 mounts the rail on **macOS only** (inside `MacDocumentView.webKitDocumentView`); the grid
/// tiles + expanded Summary are wired under `#if os(macOS)`. The chrome (header, accordion headers,
/// note/tag/collection rows) is platform-neutral; iOS adoption (filling the `#if os(iOS)` seams and
/// mounting in `DocumentView`) is Phase D.
///
/// The Subjects accordion that shipped in the old panels is deliberately retired here (owner
/// decision D1); `VolumeSubjectsChips` survives on its volume-browser / People surfaces.
struct ResearchRailView: View {

    /// The document whose research surface this rail shows.
    let entry: DocumentBrowserEntry

    /// The document view model — the Summary block reads its `activeSummary`.
    let vm: DocumentViewModel

    /// Opens the note composer for a new document note (macOS: window; iOS: sheet — Phase D).
    let onAddNote: () -> Void

    /// Opens the note composer to edit an existing note.
    let onEditNote: (ResearchNote) -> Void

    /// The just-created highlight awaiting an optional linked note, or `nil`. When non-nil the Notes
    /// accordion offers a transient "Add Note to Highlight" — the macOS counterpart to the retired
    /// strip's conditional button (C1b review F1). Passed fresh each render so it appears/vanishes
    /// as the highlight is created/consumed.
    let pendingHighlightLink: UUID?

    /// Opens the note composer for a note linked back to `pendingHighlightLink`.
    let onAddNoteToHighlight: (UUID) -> Void

    /// Asks the host to open a document tool (iOS tile/summary routing — see ``ResearchRailTool``).
    /// Defaults to a no-op so the macOS mount, whose tiles self-open windows, need not pass it.
    let onOpenTool: (ResearchRailTool) -> Void

    // MARK: Environment

    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    @Environment(\.modelContext) private var modelContext
    // Available on both platforms: macOS opens the tile windows; iPadOS opens a second document
    // window from the rail header (D8 — Stage Manager).
    @Environment(\.openWindow) private var openWindow
    #if os(macOS)
    /// The identity of the document host this rail is mounted in (set at each host root).
    /// Tile launches stamp it as the spawned tool's provenance, so the tool's document
    /// opens route back to THIS window — the rail never needs to know which window it
    /// lives in (provenance PR 2).
    @Environment(\.documentHostID) private var documentHostID
    #endif
    #if os(iOS)
    /// Gates the rail-header "Open in New Window" icon to iPad Stage Manager (D8).
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    #endif

    // MARK: Accordion expansion (shared keys — survive navigation, stay in sync with any callers)

    @AppStorage("frus.document.researchPanel.summary")     private var summaryExpanded     = true
    @AppStorage("frus.document.researchPanel.notes")       private var notesExpanded       = true
    @AppStorage("frus.document.researchPanel.tags")        private var tagsExpanded        = false
    /// New in C1: the Collections membership accordion's expansion state.
    @AppStorage("frus.document.researchPanel.collections") private var collectionsExpanded = false
    @AppStorage("frus.related.weights") private var relatedWeights = AxisWeights.default

    // MARK: Data (re-declared from `entry`)

    @Query private var documentNotes: [ResearchNote]
    @Query private var documentTagAssignments: [DocumentTagAssignment]
    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]
    /// The document's `.document`-kind collection entries — which collections it belongs to (D5:
    /// excerpt/heading/prose/generated entries are excluded via `kind == "document"`).
    @Query private var memberships: [CollectionEntry]

    // MARK: Self-owned presentation state

    @State private var showTagPicker = false
    @State private var showAddToCollection = false
    #if os(macOS)
    @State private var showCitePopover = false
    @State private var showSharePopover = false
    #endif

    /// Horizontal inset for the rail's content (tighter than the full-width panel's
    /// `documentHorizontalPadding`, since the rail is ~300 pt wide).
    private let hInset: CGFloat = 14

    init(entry: DocumentBrowserEntry,
         vm: DocumentViewModel,
         pendingHighlightLink: UUID?,
         onAddNote: @escaping () -> Void,
         onEditNote: @escaping (ResearchNote) -> Void,
         onAddNoteToHighlight: @escaping (UUID) -> Void,
         onOpenTool: @escaping (ResearchRailTool) -> Void = { _ in }) {
        self.entry = entry
        self.vm = vm
        self.pendingHighlightLink = pendingHighlightLink
        self.onAddNote = onAddNote
        self.onEditNote = onEditNote
        self.onAddNoteToHighlight = onAddNoteToHighlight
        self.onOpenTool = onOpenTool
        let vId = entry.volumeId
        let dId = entry.documentId
        _documentNotes = Query(
            filter: #Predicate<ResearchNote> { $0.volumeId == vId && $0.documentId == dId },
            sort: \.lastModified, order: .reverse)
        _documentTagAssignments = Query(
            filter: #Predicate<DocumentTagAssignment> { $0.volumeId == vId && $0.documentId == dId })
        _memberships = Query(
            filter: Self.membershipPredicate(volumeId: vId, documentId: dId),
            sort: \.sortOrder)
    }

    /// The `CollectionEntry` filter backing the Collections accordion's `memberships` `@Query`: this
    /// document's `.document`-kind entries only (owner decision D5 — headings/prose/excerpts are
    /// composed-collection structure, not memberships). Extracted so the Phase-E unit test guards the
    /// PRODUCTION predicate rather than a hand-copy that could silently drift.
    nonisolated static func membershipPredicate(volumeId: String, documentId: String) -> Predicate<CollectionEntry> {
        #Predicate<CollectionEntry> {
            $0.volumeId == volumeId && $0.documentId == documentId && $0.kind == "document"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                tileGrid
                // `summaryAccordion` carries its OWN leading divider (only when it renders — the
                // section vanishes with no summarization service + no stored summary), so there's
                // no double hairline between the tile grid and Notes on non-AI hardware (C1b F6).
                summaryAccordion
                Divider()
                notesAccordion
                Divider()
                tagsAccordion
                Divider()
                collectionsAccordion
            }
        }
        .sheet(isPresented: $showTagPicker) {
            UserTagPickerSheet(
                entry: entry,
                indexingPipeline: appState.indexingPipeline,
                initialTagIds: Set(documentTagAssignments.map(\.tagId)))
        }
        .sheet(isPresented: $showAddToCollection) {
            CollectionPickerSheet(entry: entry)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(String(localized: "researchRail.header", defaultValue: "Research"))
                .font(.system(size: FRUSTheme.sectionLabelSize, weight: FRUSTheme.sectionLabelWeight))
                .kerning(FRUSTheme.sectionLabelKerning)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Spacer()
            // UI review F-9. The six tile captions are `.caption2`, and the sentence explaining
            // each one reached only a Mac pointer: `.help` renders a tooltip on macOS alone. It is
            // not inert on iOS — the SDK documents it as setting the accessibility hint, so
            // VoiceOver has always spoken these — but a *sighted* iPad reader had no way to get
            // them. This button is that way, and it costs no new copy: the rows are the same
            // `RailTileCopy` values the tiles are built from.
            //
            // A `FeatureInfoButton`, deliberately, NOT a TipKit tip. `DocumentView`'s note on
            // `.popoverTip(isPhone ? ResearchRailTip() : nil)` records what a tip in the iPad
            // reader did: presented during the same main-thread pass that reflows the inspector
            // and inserts the WKWebView, it drove a view-graph update loop — 90s of CPU in 101s
            // and a `scene-update` watchdog kill at 10s. This popover is user-initiated, so it
            // cannot present during that reflow.
            FeatureInfoButton(heading: Self.toolsInfoHeading, items: RailTileCopy.infoItems)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            #if os(iOS)
            // D8: the rail header is the iPad "Open in New Window" home (Stage Manager). Hidden on
            // iPhone (single window) — `supportsMultipleWindows` is false there.
            if supportsMultipleWindows {
                Button {
                    appState.openAuxWindow(DocumentWindowID(
                        volumeId: entry.volumeId,
                        documentId: entry.documentId,
                        header: vm.documentTitle ?? entry.header), from: sceneID, using: openWindow)
                } label: {
                    Image(systemName: "rectangle.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "researchRail.openInNewWindow.a11y",
                                           defaultValue: "Open document in a new window"))
            }
            #endif
        }
        .padding(.horizontal, hInset)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            #if os(macOS)
            railTile("quote.closing", RailTileCopy.cite) {
                showCitePopover = true
            }
            .popover(isPresented: $showCitePopover, arrowEdge: .bottom) {
                CitationPopoverView(entry: entry)
            }
            railTile(WordCloudGlyph.symbol, RailTileCopy.wordCloud, action: openWordCloud)
            railTile("archivebox", RailTileCopy.sources, action: openSources)
            railTile("point.3.connected.trianglepath.dotted", RailTileCopy.graph, action: openGraph)
            railTile("doc.on.doc", RailTileCopy.related, action: openRelated)
            railTile("point.3.filled.connected.trianglepath.dotted", RailTileCopy.semanticMap,
                     action: openSemanticMap)
            railTile("square.and.arrow.up", RailTileCopy.share) {
                showSharePopover = true
            }
            .popover(isPresented: $showSharePopover, arrowEdge: .bottom) {
                DocumentSharePopover(entry: entry)
            }
            #endif
            #if os(iOS)
            // iOS has no `openWindow` for the reading-scoped tools, so the tiles route through the
            // host (`onOpenTool` → `DocumentView`'s existing sheet/window presentations). Share is the
            // exception — it's a `Menu`, so it stays self-owned here (mirroring the macOS Share tile).
            railTile("quote.closing", RailTileCopy.cite) { onOpenTool(.cite) }
            railTile(WordCloudGlyph.symbol, RailTileCopy.wordCloud) { onOpenTool(.wordCloud) }
            railTile("archivebox", RailTileCopy.sources) { onOpenTool(.sources) }
            railTile("point.3.connected.trianglepath.dotted", RailTileCopy.graph) { onOpenTool(.graph) }
            railTile("doc.on.doc", RailTileCopy.related) { onOpenTool(.related) }
            railTile("point.3.filled.connected.trianglepath.dotted", RailTileCopy.semanticMap) {
                onOpenTool(.semanticMap)
            }
            DocumentShareMenu(vm: vm) {
                tileLabel("square.and.arrow.up", RailTileCopy.share.title)
            }
            #endif
        }
        .padding(.horizontal, hInset)
        .padding(.vertical, 8)
    }

    /// Heading for the tools info popover (UI review F-9).
    static var toolsInfoHeading: String {
        String(localized: "researchRail.tools.info.heading", defaultValue: "Document tools")
    }

    /// The visual of one square grid tile — a centred glyph over a caption on a subtle rounded fill.
    /// Extracted so both the `Button` tiles and the iOS Share `Menu` tile read identically.
    private func tileLabel(_ glyph: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: glyph)
                .font(.system(size: 15))
            Text(label)
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    /// A single square grid tile: centred glyph over a caption label, on a subtle rounded fill.
    ///
    /// The explanation restores the per-tile tooltip the retired strip carried (C1b review F5) —
    /// the caption is `.caption2`, so a sentence says what the glyph does. It goes through
    /// `.controlHelp` rather than `.help` as of CW-6b (UI review F-9): `.help` renders a tooltip
    /// on macOS only, so the whole fan-out — VoiceOver hint, Large Content Viewer entry — reached
    /// nobody on iPad. `controlHelp` is this repo's own answer to that, built in Session 162 and
    /// simply never adopted here. The visible-to-a-sighted-iPad-reader half is the header's
    /// `FeatureInfoButton`; this half is everything else.
    ///
    /// The `accessibilityLabel` `controlHelp` sets is the same string the tile already displays,
    /// so the VoiceOver name is unchanged — worth stating because a blind conversion elsewhere in
    /// the app could overwrite a better-chosen label with a tooltip's subject.
    private func railTile(_ glyph: String, _ copy: RailTileCopy.Entry,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            tileLabel(glyph, copy.title)
        }
        .buttonStyle(.plain)
        .controlHelp(copy.title, detail: copy.detail, systemImage: glyph)
    }

    // MARK: - Accordions

    @ViewBuilder private var summaryAccordion: some View {
        if appState.summarizationService != nil || vm.activeSummary != nil {
            Divider()
            let preview = vm.activeSummary.map {
                String($0.responseText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            }
            accordionHeader(
                title: String(localized: "panel.summary.title", defaultValue: "Summary"),
                badge: nil,
                isExpanded: $summaryExpanded,
                preview: preview)
            if summaryExpanded {
                Divider()
                #if os(macOS)
                SummaryBlockView(vm: vm)
                    .padding(.horizontal, hInset)
                    .padding(.vertical, 8)
                #endif
                #if os(iOS)
                // Donated from the retired `iOSResearchPanel` Summary section (Summarize's new home).
                // The generate trigger routes through the host (`.summarizePromptPicker` sheet); the
                // failure alert stays on `DocumentView` so it also shows in Read mode.
                if let summary = vm.activeSummary {
                    SummaryStripView(vm: vm, summary: summary, totalCount: vm.summaries.count)
                        .padding(.horizontal, hInset)
                        .padding(.vertical, 8)
                } else if vm.isSummarizing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "panel.summary.generating", defaultValue: "Summarizing…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, hInset)
                    .padding(.vertical, 12)
                } else if AppleIntelligenceProvider.shared.isAvailable {
                    Button {
                        onOpenTool(.summarize)
                    } label: {
                        Label(String(localized: "panel.summary.generate",
                                     defaultValue: "Summarize this Document"),
                              systemImage: "sparkles")
                            .font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .disabled(vm.documentPlainText.isEmpty)
                    .padding(.horizontal, hInset)
                    .padding(.vertical, 12)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.tertiary)
                        Text(String(localized: "panel.summary.unavailable",
                                    defaultValue: "Apple Intelligence is not available on this device, so new summaries cannot be generated. Summaries from your other devices still appear here via iCloud."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, hInset)
                    .padding(.vertical, 12)
                }
                #endif
            }
        }
    }

    @ViewBuilder private var notesAccordion: some View {
        accordionHeader(
            title: String(localized: "panel.notes.title", defaultValue: "Notes"),
            badge: documentNotes.isEmpty ? nil : "\(documentNotes.count)",
            isExpanded: $notesExpanded)
        if notesExpanded {
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                ForEach(documentNotes) { note in
                    Button {
                        onEditNote(note)
                    } label: {
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
                        .padding(.horizontal, hInset)
                        .padding(.vertical, 8)
                        // #312 follow-up: the inner Text already carries a greedy frame, so this
                        // only needs the shape to make the row's gaps hit-testable.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
                // Transient: appears right after a highlight is created (its dot tapped on the
                // floating bar), so the note anchors back to that highlight — the macOS restoration
                // of the retired strip's conditional "Add Note" verb (C1b review F1).
                if let link = pendingHighlightLink {
                    Button {
                        onAddNoteToHighlight(link)
                    } label: {
                        Label(String(localized: "panel.notes.addToHighlight",
                                     defaultValue: "Add Note to Highlight"),
                              systemImage: "highlighter")
                            .font(.callout)
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // #312 follow-up: frame was already here; the shape completes the pair so the
                            // whole action row is tappable, not just its label glyphs.
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, hInset)
                    .padding(.vertical, 10)
                    Divider()
                }
                Button {
                    onAddNote()
                } label: {
                    Label(String(localized: "panel.notes.add", defaultValue: "Add Note"),
                          systemImage: "plus.circle")
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // #312 follow-up: frame was already here; the shape completes the pair so the
                        // whole action row is tappable, not just its label glyphs.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, hInset)
                .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder private var tagsAccordion: some View {
        let appliedTags = appliedUserTags
        accordionHeader(
            title: String(localized: "panel.tags.title", defaultValue: "Tags"),
            badge: appliedTags.isEmpty ? nil : "\(appliedTags.count)",
            isExpanded: $tagsExpanded)
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
                        showTagPicker = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            if appliedTags.isEmpty {
                                Text(String(localized: "panel.tags.add", defaultValue: "Add Tag"))
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
                .padding(.horizontal, hInset)
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder private var collectionsAccordion: some View {
        let cols = membershipCollections
        accordionHeader(
            title: String(localized: "panel.collections.title", defaultValue: "Collections"),
            badge: cols.isEmpty ? nil : "\(cols.count)",
            isExpanded: $collectionsExpanded)
        if collectionsExpanded {
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                if cols.isEmpty {
                    Text(String(localized: "panel.collections.empty",
                                defaultValue: "Not in any collection yet."))
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, hInset)
                        .padding(.vertical, 8)
                }
                ForEach(cols) { collection in
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(collection.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, hInset)
                    .padding(.vertical, 6)
                    Divider()
                }
                Button {
                    showAddToCollection = true
                } label: {
                    Label(String(localized: "panel.collections.add", defaultValue: "Add to Collection"),
                          systemImage: "plus.circle")
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // #312 follow-up: frame was already here; the shape completes the pair so the
                        // whole action row is tappable, not just its label glyphs.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, hInset)
                .padding(.vertical, 10)
            }
        }
    }

    /// The shared accordion section header (donated from the old panels' `panelSectionHeader`):
    /// uppercase title + optional count badge + optional collapsed preview + chevron.
    private func accordionHeader(
        title: String,
        badge: String?,
        isExpanded: Binding<Bool>,
        preview: String? = nil
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                if let preview, !isExpanded.wrappedValue {
                    Text(preview + "…")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, hInset)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tag helpers (donated)

    private var appliedUserTags: [UserTag] {
        let assignedIds = Set(documentTagAssignments.map(\.tagId))
        return allUserTags.filter { assignedIds.contains($0.id) }
    }

    private func removeUserTag(_ tag: UserTag) {
        let vId = entry.volumeId
        let dId = entry.documentId
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

    // MARK: - Collections helper

    /// The distinct collections this document belongs to, sorted by name (from the `memberships`
    /// `@Query`). See ``distinctCollections(from:)`` for the pure dedup/orphan-drop/sort.
    private var membershipCollections: [Collection] {
        Self.distinctCollections(from: memberships)
    }

    /// Reduces membership entries to the distinct collections they belong to, sorted by name.
    ///
    /// - Drops entries whose `collection` relationship is nil (orphans — a collection deleted under
    ///   `.nullify`), and de-duplicates when a document has more than one entry in the same
    ///   collection. `memberships` arrives sorted by `CollectionEntry.sortOrder` — a *within*-
    ///   collection position, meaningless across collections — so the result is re-sorted by name for
    ///   a stable, readable order (C1b review F7). Extracted as an internal `nonisolated` static so
    ///   the Phase-E unit tests can exercise it off the main actor without mounting the view.
    nonisolated static func distinctCollections(from memberships: [CollectionEntry]) -> [Collection] {
        var seen = Set<UUID>()
        var result: [Collection] = []
        for entry in memberships {
            guard let collection = entry.collection, !seen.contains(collection.id) else { continue }
            seen.insert(collection.id)
            result.append(collection)
        }
        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // MARK: - Tile actions (macOS)

    #if os(macOS)
    /// Opens the document-scoped Word Cloud window. The rail opens it DIRECTLY (the
    /// `pendingWordCloud` → openWindow observer lives only in `MainWindowView`, so the strip's
    /// old set-only action was dead when mounted in a document window). The cloud is bound
    /// to this rail's host window, so its Search/Analytics/Chronology hand-offs route back here.
    private func openWordCloud() {
        appState.openWordCloud(.document(volumeId: entry.volumeId, documentId: entry.documentId), from: sceneID)
        appState.bindTool(.wordCloud, to: documentHostID)
        openWindow.fronting(id: "frus.wordcloud")
    }

    /// Opens the Source Explorer window, re-priming the source-note fields from the rail's own
    /// `entry` whenever the globals describe a DIFFERENT document (§6.1 leak fix: with two
    /// document windows open, the older window's tile used to open the newer document's note
    /// because it only primed when the globals were nil). The same-document case is left
    /// untouched so `MacDocumentView.loadDocument()`'s richer live-XML-parse priming wins.
    private func openSources() {
        if appState.currentSourceNoteDocumentId != entry.documentId
            || appState.currentSourceNoteVolumeId != entry.volumeId {
            appState.currentSourceNote = entry.sourceNote ?? ""
            appState.currentSourceNoteYear = nil
            if let dl = entry.dateline,
               let m = dl.range(of: #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#, options: .regularExpression) {
                appState.currentSourceNoteYear = Int(dl[m])
            }
            appState.currentSourceNoteHeader     = entry.header
            appState.currentSourceNoteDateline   = entry.dateline
            appState.currentSourceNoteVolumeId   = entry.volumeId
            appState.currentSourceNoteDocumentId = entry.documentId
        }
        appState.bindTool(.sourceExplorer, to: documentHostID)
        // #369 BUG-8: signal the Source Explorer window to snapshot the note NOW (fresh window via
        // its `.task`; an already-open window via `.onChange(of: sourceNoteFocusID)`), so it stops
        // binding the shared globals live and can't be flickered by another window's `loadDocument`.
        appState.sourceNoteFocusID = UUID()
        openWindow.fronting(id: "frus.sourceExplorer")
    }

    /// Opens the cross-reference graph window anchored on this document, bound to this
    /// rail's host window so "View Document" routes back here.
    private func openGraph() {
        appState.currentGraphEntry = entry
        appState.bindTool(.graph, to: documentHostID)
        // M-2: per-document window (see ResearchView's twin).
        openWindow(value: GraphWindowRequest(entry: entry))
    }

    /// Opens the value-based Related Documents window (focuses an existing equal-request
    /// window), binding the request instance to this rail's host window BEFORE the open so
    /// row taps route back here.
    private func openRelated() {
        let request = RelatedDocumentsRequest(
            anchor: DocumentKey(volumeId: entry.volumeId, documentId: entry.documentId),
            anchorYear: MacDocumentView.extractYear(from: entry.dateline),
            weights: relatedWeights,
            scope: .allIndexed)
        appState.bindTool(.relatedDocuments(request), to: documentHostID)
        openWindow(value: request)
    }

    /// Opens the semantic map focused on this document.
    ///
    /// The request carries the document key, which is part of `SemanticMapRequest`'s identity — so
    /// revealing a second document opens its own window rather than focusing the first and leaving
    /// it pointed at the previous one.
    private func openSemanticMap() {
        appState.bindTool(.semanticAnalytics, to: documentHostID)
        openWindow(value: SemanticMapRequest(
            volumeIDs: nil, scopeLabel: nil, lensRawValue: SemanticMapLens.cluster.rawValue,
            focusDocumentKey: "\(entry.volumeId)/\(entry.documentId)"))
    }
    #endif
}

// MARK: - RailTileCopy

/// The six document tools' names and explanations, defined once.
///
/// **This exists because the strings had two copies and F-9 needed a third.** Each
/// `railTile` call spelled its caption and sentence inline, and the macOS and
/// iOS tile blocks each carry a full set — so `researchRail.tile.cite.help` appeared twice before
/// the header's info popover wanted it a third time. Three literals per string is three places for
/// one to drift, and a drifted `help` is invisible: nothing renders the two side by side.
///
/// The `String(localized:)` calls stay literal here so string extraction still finds them; what
/// moved is where they are written, not how.
///
/// Version history:
///   1.0 — CW-6b (UI review F-9): extracted from the tile call sites
enum RailTileCopy {

    /// One tool's caption and its one-sentence explanation.
    struct Entry {
        /// The tile's visible caption, also its VoiceOver name.
        let title: String
        /// The sentence explaining what the tool does — the macOS tooltip, the iOS VoiceOver
        /// hint and Large Content Viewer detail, and a row in the header's info popover.
        let detail: String
    }

    /// Semantic Map — where this document sits in the corpus's language.
    static var semanticMap: Entry {
        Entry(title: String(localized: "researchRail.tile.semanticMap", defaultValue: "On the Map"),
              detail: String(localized: "researchRail.tile.semanticMap.help",
                             defaultValue: "Show where this document sits on the semantic map, among the documents whose language is most like it"))
    }

    /// Cite — the citation popover / sheet.
    static var cite: Entry {
        Entry(title: String(localized: "researchRail.tile.cite", defaultValue: "Cite"),
              detail: String(localized: "researchRail.tile.cite.help",
                             defaultValue: "Cite this document — copy a formatted citation or export BibTeX/RIS"))
    }

    /// Word Cloud — this document's most frequent terms.
    static var wordCloud: Entry {
        Entry(title: String(localized: "researchRail.tile.wordCloud", defaultValue: "Word Cloud"),
              detail: String(localized: "researchRail.tile.wordCloud.help",
                             defaultValue: "Show a word cloud of this document's most frequent terms"))
    }

    /// Sources — the archival source note, resolved.
    static var sources: Entry {
        Entry(title: String(localized: "researchRail.tile.sources", defaultValue: "Sources"),
              detail: String(localized: "researchRail.tile.sources.help",
                             defaultValue: "Resolve this document's source note in the NARA Catalog or RG-59 records"))
    }

    /// Graph — the cross-reference graph.
    static var graph: Entry {
        Entry(title: String(localized: "researchRail.tile.graph", defaultValue: "Graph"),
              detail: String(localized: "researchRail.tile.graph.help",
                             defaultValue: "Show this document's cross-reference graph"))
    }

    /// Related — ranked related documents.
    static var related: Entry {
        Entry(title: String(localized: "researchRail.tile.related", defaultValue: "Related"),
              detail: String(localized: "researchRail.tile.related.help",
                             defaultValue: "Find related documents by archival provenance, cross-references, date, and shared people"))
    }

    /// Share — the share/export menu.
    static var share: Entry {
        Entry(title: String(localized: "researchRail.tile.share", defaultValue: "Share"),
              detail: String(localized: "researchRail.tile.share.help",
                             defaultValue: "Share or export this document"))
    }

    /// Every tool, in tile order — the rows of the header's info popover.
    ///
    /// Share is included even though it is the one tile that never needed this fix (it is a
    /// `Menu`, not a `railTile`, and already carries `.controlHelp` from `DocumentShareMenu`):
    /// a popover that explained five of the six tiles on screen would read as an omission.
    static var infoItems: [FeatureInfoItem] {
        [cite, wordCloud, sources, graph, related, share]
            .map { FeatureInfoItem(title: $0.title, detail: $0.detail) }
    }
}
