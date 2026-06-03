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
///   1.3 — Session 103: highlight mode toggle + DocumentHighlightTextView +
///          color-picker popover + DocumentHighlight SwiftData insertion
///   1.4 — Session 105: renderingVersion uses SHA-256(flatText ++ kVersion) via
///          ASTToRenderNodeConverter.renderingVersion(for:)
///   1.5 — Session 106: @Query for stored highlights; overlay rendering; stale warning banner;
///          note anchoring
///   1.6 — Highlight controls + Sources moved to ResearchStripView; state managed via
///          HighlightCoordinator passed from MainWindowView
@MainActor
struct MacDocumentView: View {

    let entry: DocumentBrowserEntry
    @Binding var navigationPath: [DocumentBrowserEntry]
    let highlightCoordinator: HighlightCoordinator

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var vm: DocumentViewModel
    @State private var prevEntry: DocumentBrowserEntry? = nil
    @State private var nextEntry: DocumentBrowserEntry? = nil
    @State private var showPersonNotFound = false
    @State private var showGlossNotFound  = false
    /// Offsets of the highlight the user tapped; drives the delete-confirmation alert.
    @State private var highlightToDelete: (Int, Int)? = nil

    @Query private var highlights:              [DocumentHighlight]
    @Query private var documentNotes:           [ResearchNote]
    @Query private var documentTagAssignments:  [DocumentTagAssignment]
    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]

    // Research panel: persisted accordion state (shared with ResearchStripView)
    @AppStorage("frus.document.researchPanel.visible")   private var panelVisible    = true
    @AppStorage("frus.document.researchPanel.summary")   private var summaryExpanded = true
    @AppStorage("frus.document.researchPanel.notes")     private var notesExpanded   = true
    @AppStorage("frus.document.researchPanel.tags")      private var tagsExpanded    = false

    // MARK: - Init

    init(entry: DocumentBrowserEntry,
         navigationPath: Binding<[DocumentBrowserEntry]>,
         highlightCoordinator: HighlightCoordinator) {
        self.entry = entry
        self._navigationPath = navigationPath
        self.highlightCoordinator = highlightCoordinator
        // DocumentViewModel constructed here; services injected in .task below
        // because @Environment is not accessible at init time.
        self._vm = State(initialValue: DocumentViewModel(
            entry: entry,
            volumeEntry: nil,
            parser: FRUSDocumentParser(),
            subjectTagStore: SubjectTagStore()
        ))
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

    // MARK: - Body

    var body: some View {
        Group {
            if let renderModel = vm.renderModel {
                webKitDocumentView(renderModel: renderModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            } else {
                // Pre-load state: .task hasn't fired yet, or downloadManager wasn't
                // ready. Never show a blank view — show a spinner so the user sees
                // the document area is active.
                ProgressView()
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            await loadDocument()
            highlightCoordinator.createWebKitHighlightAction = createWebKitHighlight(color:)
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
        .alert(
            String(localized: "personNotFound.title",
                   defaultValue: "Person Information Unavailable"),
            isPresented: $showPersonNotFound
        ) {
            Button(String(localized: "personNotFound.dismiss", defaultValue: "OK")) {}
        } message: {
            Text(String(localized: "personNotFound.detail",
                        defaultValue: "Detailed information about this person isn't available for this volume. To populate person data, re-index the volume in Settings → Volumes."))
        }
        .alert(
            String(localized: "glossNotFound.title",
                   defaultValue: "Term Definition Unavailable"),
            isPresented: $showGlossNotFound
        ) {
            Button(String(localized: "glossNotFound.dismiss", defaultValue: "OK")) {}
        } message: {
            Text(String(localized: "glossNotFound.detail",
                        defaultValue: "A definition for this term isn't available for this volume. To populate term data, re-index the volume in Settings → Volumes."))
        }
        .alert(
            String(localized: "highlight.delete.title",
                   defaultValue: "Remove Highlight"),
            isPresented: Binding(
                get:  { highlightToDelete != nil },
                set:  { if !$0 { highlightToDelete = nil } }
            )
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
    }

    // MARK: - WebKit document view (Session 142+)

    /// Document view for the WebKit rendering path.
    ///
    /// `WKWebView` handles all scrolling, typography, and footnote display (HTML
    /// Popover API).  The document identity line and highlights banner are pinned
    /// above the web view; volume navigation is fixed below. `SummaryBlockView`
    /// is omitted from this path until Session 147 finalises the WebKit migration.
    private func webKitDocumentView(renderModel: FRUSDocumentRenderModel) -> some View {
        VStack(spacing: 0) {
            // Identity + highlights banner (non-scrollable header)
            documentIdentityView
                .padding(.horizontal, 48)
                .padding(.top, 18)
                .padding(.bottom, 10)

            Divider()

            // Stale highlight banner (WebKit path)
            let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: renderModel)
            if highlights.contains(where: { $0.renderingVersion != renderingVersion }) {
                staleHighlightBanner
            }

            // Document body — WKWebView handles scrolling, tables, footnotes, and highlights.
            FRUSDocumentWebView(
                model: renderModel,
                onPersonTap: { person in
                    vm.selectedPerson = person
                    if let person {
                        handlePersonTap(person)
                    } else {
                        showPersonNotFound = true
                    }
                },
                onGlossTap: { entry in
                    if let entry {
                        handleGlossTap(entry)
                    } else {
                        showGlossNotFound = true
                    }
                },
                onCrossRefTap: { target, volumeId in
                    handleCrossRefTap(target: target, volumeId: volumeId)
                }
            )
            .highlights(highlights)
            .onSelectionChanged { start, end in
                highlightCoordinator.webKitSelectionRange = (start, end)
            }
            .onSelectionCleared {
                highlightCoordinator.webKitSelectionRange = nil
            }
            .onHighlightTapped { start, end in
                highlightToDelete = (start, end)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Research panel — accordion of Notes, Tags, Summary
            if panelVisible {
                Divider()
                macResearchPanel(vm: vm)
            }

            Divider()

            volumeNavigationView
                .padding(.horizontal, 48)
                .padding(.top, 12)
                .padding(.bottom, 20)
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

    // MARK: - Research Panel (accordion below document body)

    /// Accordion panel with three independently expandable sections:
    /// Notes · Tags · Summary. Visibility and per-section expansion are
    /// persisted via AppStorage so the state survives document navigation.
    @ViewBuilder
    private func macResearchPanel(vm: DocumentViewModel) -> some View {
        VStack(spacing: 0) {
            // ── Summary ───────────────────────────────────────────────────────
            if appState.summarizationService != nil || vm.activeSummary != nil {
                let summaryPreview = vm.activeSummary.map { s in
                    String(s.responseText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
                }
                panelSectionHeader(
                    title: String(localized: "panel.summary.title", defaultValue: "Summary"),
                    badge: nil,
                    isExpanded: $summaryExpanded,
                    preview: summaryPreview
                )
                if summaryExpanded {
                    Divider()
                    SummaryBlockView(vm: vm)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 8)
                }
                Divider()
            }

            // ── Notes ────────────────────────────────────────────────────────
            panelSectionHeader(
                title: String(localized: "panel.notes.title", defaultValue: "Notes"),
                badge: documentNotes.isEmpty ? nil : "\(documentNotes.count)",
                isExpanded: $notesExpanded
            )
            if notesExpanded {
                Divider()
                if documentNotes.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text").foregroundStyle(.tertiary)
                        Text(String(localized: "panel.notes.empty",
                                    defaultValue: "No notes yet — click Add note in the research strip to create one."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(documentNotes) { note in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(note.bodyText.isEmpty
                                     ? String(localized: "panel.notes.emptyNote", defaultValue: "Empty note")
                                     : note.bodyText)
                                    .font(.callout)
                                    .foregroundStyle(note.bodyText.isEmpty ? .tertiary : .primary)
                                    .lineLimit(3)
                                Text(note.lastModified ?? .now, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 8)
                            if note.id != documentNotes.last?.id { Divider() }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Divider()

            // ── Tags ─────────────────────────────────────────────────────────
            let userTagNames = documentTagAssignments
                .compactMap { a in allUserTags.first(where: { $0.id == a.tagId })?.name }
                .sorted()
            panelSectionHeader(
                title: String(localized: "panel.tags.title", defaultValue: "Tags"),
                badge: userTagNames.isEmpty ? nil : "\(userTagNames.count)",
                isExpanded: $tagsExpanded
            )
            if tagsExpanded {
                Divider()
                if userTagNames.isEmpty && vm.subjectTags.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "tag").foregroundStyle(.tertiary)
                        Text(String(localized: "panel.tags.empty",
                                    defaultValue: "No tags applied — click Tag in the research strip to add one."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if !userTagNames.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(userTagNames, id: \.self) { name in
                                    FRUSTagChip(label: name, style: .user)
                                }
                            }
                            .padding(.horizontal, 48)
                        }
                        if !vm.subjectTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(vm.subjectTags) { tag in
                                        FRUSTagChip(label: tag.displayName, style: .system)
                                    }
                                }
                                .padding(.horizontal, 48)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    /// Reusable accordion section header: label + optional badge + chevron.
    private func panelSectionHeader(
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
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .kerning(0.7)
                    .foregroundStyle(.secondary)
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 2)
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
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Highlight Deletion

    /// Finds the `DocumentHighlight` matching the given flat-text offsets and
    /// deletes it from SwiftData. Called after the user confirms deletion via
    /// the tap-on-highlight context alert.
    @MainActor
    private func deleteHighlight(startOffset: Int, endOffset: Int) {
        // Match by volume + document + offsets — the combination is unique per highlight.
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
        print("[MacDocumentView] Deleted highlight [\(startOffset)–\(endOffset)] from \(did)")
        #endif
    }

    // MARK: - Highlight Actions (WebKit path)

    /// Creates a `DocumentHighlight` from the WebKit flat-text selection range.
    ///
    /// Called by `HighlightCoordinator.createWebKitHighlightAction` (registered in `.task`)
    /// when the user taps "Highlight" in `ResearchStripView` while a selection is active.
    @MainActor
    private func createWebKitHighlight(color: DocumentHighlight.Color) {
        guard let range = highlightCoordinator.webKitSelectionRange,
              let model = vm.renderModel else { return }
        let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
        // Extract the selected text from the flat-text representation so it's
        // available for display in the Research window without re-parsing.
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
            renderingVersion: renderingVersion
        )
        modelContext.insert(highlight)
        highlightCoordinator.webKitSelectionRange = nil
        highlightCoordinator.pendingHighlightLink = highlight.id
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
                .help(String(
                    localized: "document.nav.previous.help",
                    defaultValue: "Previous document in this volume"
                ))
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
                .help(String(
                    localized: "document.nav.next.help",
                    defaultValue: "Next document in this volume"
                ))
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadDocument() async {
        // Wait for the download manager to be bootstrapped if it isn't yet.
        // This can happen when a document is opened very early in the app lifecycle
        // (e.g. from a URL handler or Handoff) before bootApp() completes.
        var attempts = 0
        while appState.downloadManager == nil, attempts < 20 {
            try? await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
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
