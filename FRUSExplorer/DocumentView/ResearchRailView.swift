// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

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

    // MARK: Environment

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
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
         onAddNoteToHighlight: @escaping (UUID) -> Void) {
        self.entry = entry
        self.vm = vm
        self.pendingHighlightLink = pendingHighlightLink
        self.onAddNote = onAddNote
        self.onEditNote = onEditNote
        self.onAddNoteToHighlight = onAddNoteToHighlight
        let vId = entry.volumeId
        let dId = entry.documentId
        _documentNotes = Query(
            filter: #Predicate<ResearchNote> { $0.volumeId == vId && $0.documentId == dId },
            sort: \.lastModified, order: .reverse)
        _documentTagAssignments = Query(
            filter: #Predicate<DocumentTagAssignment> { $0.volumeId == vId && $0.documentId == dId })
        _memberships = Query(
            filter: #Predicate<CollectionEntry> {
                $0.volumeId == vId && $0.documentId == dId && $0.kind == "document"
            },
            sort: \.sortOrder)
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
        }
        .padding(.horizontal, hInset)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tile grid

    private var tileGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            #if os(macOS)
            railTile("quote.closing",
                     String(localized: "researchRail.tile.cite", defaultValue: "Cite"),
                     help: String(localized: "researchRail.tile.cite.help",
                                  defaultValue: "Cite this document — copy a formatted citation or export BibTeX/RIS")) {
                showCitePopover = true
            }
            .popover(isPresented: $showCitePopover, arrowEdge: .bottom) {
                CitationPopoverView(entry: entry)
            }
            railTile(WordCloudGlyph.symbol,
                     String(localized: "researchRail.tile.wordCloud", defaultValue: "Word Cloud"),
                     help: String(localized: "researchRail.tile.wordCloud.help",
                                  defaultValue: "Show a word cloud of this document's most frequent terms"),
                     action: openWordCloud)
            railTile("archivebox",
                     String(localized: "researchRail.tile.sources", defaultValue: "Sources"),
                     help: String(localized: "researchRail.tile.sources.help",
                                  defaultValue: "Resolve this document's source note in the NARA Catalog or RG-59 records"),
                     action: openSources)
            railTile("point.3.connected.trianglepath.dotted",
                     String(localized: "researchRail.tile.graph", defaultValue: "Graph"),
                     help: String(localized: "researchRail.tile.graph.help",
                                  defaultValue: "Show this document's cross-reference graph"),
                     action: openGraph)
            railTile("doc.on.doc",
                     String(localized: "researchRail.tile.related", defaultValue: "Related"),
                     help: String(localized: "researchRail.tile.related.help",
                                  defaultValue: "Find related documents by archival provenance, cross-references, date, and shared people"),
                     action: openRelated)
            railTile("square.and.arrow.up",
                     String(localized: "researchRail.tile.share", defaultValue: "Share"),
                     help: String(localized: "researchRail.tile.share.help",
                                  defaultValue: "Share or export this document")) {
                showSharePopover = true
            }
            .popover(isPresented: $showSharePopover, arrowEdge: .bottom) {
                DocumentSharePopover(entry: entry)
            }
            #endif
            // iOS tile presentations are Phase D.
        }
        .padding(.horizontal, hInset)
        .padding(.vertical, 8)
    }

    /// A single square grid tile: centred glyph over a caption label, on a subtle rounded fill.
    /// `help` restores the per-tile tooltip the retired strip carried (C1b review F5) — the
    /// caption is small, so hover text explains what each glyph does.
    private func railTile(_ glyph: String, _ label: String, help: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
        .help(help)
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
                // iOS Summary body (SummaryStripView + generate states) is Phase D.
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

    /// The distinct collections this document belongs to, sorted by name. `memberships` sorts by
    /// `CollectionEntry.sortOrder` — a *within-collection* position, meaningless across collections
    /// — so the deduped result is re-sorted by name for a stable, readable order (C1b review F7).
    private var membershipCollections: [Collection] {
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
    /// old set-only action was dead when mounted in a document window).
    private func openWordCloud() {
        appState.pendingWordCloud = .document(volumeId: entry.volumeId, documentId: entry.documentId)
        openWindow(id: "frus.wordcloud")
        bringMacWindowToFront(id: "frus.wordcloud")
    }

    /// Opens the Source Explorer window, priming the source-note fields only as a fallback —
    /// `MacDocumentView.loadDocument()` pre-sets `currentSourceNote` from the live XML parse.
    private func openSources() {
        if appState.currentSourceNote == nil {
            appState.currentSourceNote = entry.sourceNote ?? ""
            if let dl = entry.dateline,
               let m = dl.range(of: #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#, options: .regularExpression) {
                appState.currentSourceNoteYear = Int(dl[m])
            }
            appState.currentSourceNoteHeader     = entry.header
            appState.currentSourceNoteDateline   = entry.dateline
            appState.currentSourceNoteVolumeId   = entry.volumeId
            appState.currentSourceNoteDocumentId = entry.documentId
        }
        openWindow(id: "frus.sourceExplorer")
        bringMacWindowToFront(id: "frus.sourceExplorer")
    }

    /// Opens the cross-reference graph window anchored on this document.
    private func openGraph() {
        appState.currentGraphEntry = entry
        openWindow(id: "frus.crossReferenceGraph")
        bringMacWindowToFront(id: "frus.crossReferenceGraph")
    }

    /// Opens the value-based Related Documents window (focuses an existing equal-request window).
    private func openRelated() {
        openWindow(value: RelatedDocumentsRequest(
            anchor: DocumentKey(volumeId: entry.volumeId, documentId: entry.documentId),
            anchorYear: MacDocumentView.extractYear(from: entry.dateline),
            weights: relatedWeights,
            scope: .allIndexed))
    }
    #endif
}
