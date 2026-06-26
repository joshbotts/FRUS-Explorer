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
///   1.7 — Session 154: applies the default document mode preference
///          (Read/Research/remember-last) to `panelVisible` once per document open
@MainActor
struct MacDocumentView: View {

    let entry: DocumentBrowserEntry
    @Binding var navigationPath: [DocumentBrowserEntry]
    let highlightCoordinator: HighlightCoordinator

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// Opens external (non-FRUS) cross-reference URLs in the system browser.
    @Environment(\.openURL) private var openURL

    @State private var vm: DocumentViewModel
    @State private var prevEntry: DocumentBrowserEntry? = nil
    @State private var nextEntry: DocumentBrowserEntry? = nil
    @State private var showPersonNotFound = false
    @State private var showGlossNotFound  = false
    /// Offsets of the highlight the user tapped; drives the delete-confirmation alert.
    @State private var highlightToDelete: (Int, Int)? = nil
    @State private var showTagPicker = false
    @State private var showAddNote = false
    @State private var noteToEdit: ResearchNote? = nil

    @Query private var highlights:              [DocumentHighlight]
    @Query private var documentNotes:           [ResearchNote]
    @Query private var documentTagAssignments:  [DocumentTagAssignment]
    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]

    // Research panel: persisted accordion state (shared with ResearchStripView)
    @AppStorage("frus.document.researchPanel.visible")   private var panelVisible    = true
    @AppStorage("frus.document.researchPanel.summary")   private var summaryExpanded = true
    @AppStorage("frus.document.researchPanel.notes")     private var notesExpanded   = true
    @AppStorage("frus.document.researchPanel.tags")      private var tagsExpanded    = false
    /// Which mode (Read/Research/remember-last) a document opens in (Session 154).
    @AppStorage(SettingsKeys.defaultDocumentMode) private var defaultDocumentMode: DefaultDocumentMode = .rememberLast

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
            // Apply the default document mode on open. .rememberLast leaves
            // panelVisible untouched, preserving the prior cross-document
            // persistence; .read/.research force it, but ResearchStripView's
            // segmented control can still switch modes live afterwards.
            switch defaultDocumentMode {
            case .read:         panelVisible = false
            case .research:     panelVisible = true
            case .rememberLast: break
            }
            await loadDocument()
            highlightCoordinator.createWebKitHighlightAction = createWebKitHighlight(color:)
            appState.logEvent(.documentOpen(
                volumeId: entry.volumeId,
                documentId: entry.documentId,
                title: entry.header.isEmpty ? entry.documentId : entry.header
            ))
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.pendingWordCloud = .document(
                        volumeId: entry.volumeId, documentId: entry.documentId)
                } label: {
                    Label(String(localized: "document.toolbar.wordCloud", defaultValue: "Word Cloud"),
                          systemImage: "cloud")
                }
                .help(String(localized: "document.toolbar.wordCloud.help",
                             defaultValue: "Visualise the most frequent terms in this document"))
            }
        }
        .userActivity(AppActivityTypes.document, element: entry) { entry, activity in
            activity.title = entry.header.isEmpty ? entry.documentId : entry.header
            activity.userInfo = ["volumeId": entry.volumeId, "documentId": entry.documentId]
            activity.isEligibleForHandoff = true
        }
        .sheet(isPresented: $showTagPicker) {
            MacTagPickerSheet(
                entry: entry,
                indexingPipeline: appState.indexingPipeline,
                initialTagIds: Set(documentTagAssignments.map(\.tagId))
            )
        }
        .sheet(isPresented: $showAddNote) {
            ResearchNoteEditorView(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                activeProjectId: appState.activeProjectId,
                indexingPipeline: appState.indexingPipeline
            )
        }
        .sheet(item: $noteToEdit) { note in
            ResearchNoteEditorView(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                activeProjectId: appState.activeProjectId,
                noteToEdit: note,
                indexingPipeline: appState.indexingPipeline
            )
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
                .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
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
            .onSelectionChanged { start, end, text in
                if start >= 0 {
                    highlightCoordinator.webKitSelectionRange = (start, end)
                } else {
                    // Footnote selection: text available but no valid offset range.
                    highlightCoordinator.webKitSelectionRange = nil
                }
                highlightCoordinator.webKitSelectedText = text.isEmpty ? nil : text
            }
            .onSelectionCleared {
                highlightCoordinator.webKitSelectionRange = nil
                // webKitSelectedText intentionally preserved for NARA lookup.
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
                .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Document Year Extraction

    /// Extracts a 4-digit year from a dateline string.
    /// Duplicated from DocumentView; kept here so MacDocumentView has no cross-file dependency.
    static func extractYear(from dateline: String?) -> Int? {
        guard let dl = dateline else { return nil }
        let pattern = #"\b(19[0-9]{2}|20[0-2][0-9])\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: dl, range: NSRange(dl.startIndex..., in: dl)),
              let range = Range(match.range(at: 1), in: dl)
        else { return nil }
        return Int(dl[range])
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
                        .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
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
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(documentNotes) { note in
                        Button { noteToEdit = note } label: {
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
                        showAddNote = true
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

            // ── Tags ─────────────────────────────────────────────────────────
            let appliedTags = appliedUserTags
            panelSectionHeader(
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
                            showTagPicker = true
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
                    .font(.system(size: 11, weight: .semibold))
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
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tag Helpers

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

            // Just the document's own identifier — no "of N in this volume" suffix.
            // `volumeEntry.documentCount` doesn't reflect the volume's true document
            // count (it read 0 for every volume), so that phrasing was always wrong;
            // the identifier alone is the part that's actually useful here.
            Text(entry.documentNumber.map { "Doc \($0)" } ?? entry.documentId)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

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
        // Clear the pre-populated source note so the Sources button can't show
        // stale data from the previous document while the new one is loading.
        appState.currentSourceNote = nil
        appState.currentSourceNoteYear = nil
        appState.currentSourceNoteHeader = nil
        appState.currentSourceNoteDateline = nil
        appState.currentSourceNoteVolumeId = nil
        appState.currentSourceNoteDocumentId = nil

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
            personMentionStore: appState.personMentionStore,
            astCache: appState.documentASTCache
        )

        await vm.load(volumeURL: volumeURL)

        // Pre-populate appState.currentSourceNote from the live-parsed source note so
        // ResearchStripView's Sources button always works, even when the DocumentBrowserEntry
        // was created via a cross-reference tap (which sets sourceNote: nil).
        // This ensures the macOS source explorer uses the same data source as iOS.
        let year = Self.extractYear(from: entry.dateline)
        appState.currentSourceNoteYear = year
        appState.currentSourceNoteHeader = entry.header
        appState.currentSourceNoteDateline = entry.dateline
        appState.currentSourceNoteVolumeId = entry.volumeId
        appState.currentSourceNoteDocumentId = entry.documentId
        if let note = vm.sourceNote ?? entry.sourceNote {
            appState.currentSourceNote = note
        } else if let year, year < 1906 {
            // Pre-1906 documents carry no source note; open the explorer anyway so the
            // country-series classifier can resolve the archival roll.
            appState.currentSourceNote = ""
        }

        vm.recordReadingHistory(projectId: appState.activeProjectId, in: modelContext)
        vm.loadSummaries(context: modelContext)
        vm.refreshCrossProjectNoteCount(
            activeProjectId: appState.activeProjectId,
            context: modelContext
        )

        // Load adjacent entries for prev/next navigation buttons. The reading
        // sequence spans the whole volume — front matter, body, and back matter —
        // so Prev/Next never skips structured front-matter sections (Persons,
        // Sources, Table of Contents, Index) the search index leaves out.
        if let pipeline = appState.indexingPipeline {
            if let docs = try? await pipeline.readingSequence(forVolume: entry.volumeId),
               let idx = docs.firstIndex(where: { $0.documentId == entry.documentId }) {
                prevEntry = idx > 0 ? docs[idx - 1] : nil
                nextEntry = idx + 1 < docs.count ? docs[idx + 1] : nil
            }
        }

        #if DEBUG
        print("[MacDocumentView] Loaded \(entry.volumeId)/\(entry.documentId)")
        #endif
    }

    /// Routes a tapped in-document cross-reference through
    /// `FRUSURLSchemeHandler.resolveCrossRefTarget` (Session 162). The previous
    /// implementation only stripped a *leading* `#`, so cross-volume targets
    /// (`frus1964-68v18#d65`) navigated to a bogus document ID, and it silently
    /// skipped printed-page references instead of resolving them.
    private func handleCrossRefTap(target: String, volumeId: String?) {
        switch FRUSURLSchemeHandler.resolveCrossRefTarget(target, volumeId: volumeId) {
        case .document(let targetVolumeId, let documentId):
            navigateToCrossRef(documentId: documentId,
                               volumeId: targetVolumeId ?? entry.volumeId)

        case .page(let targetVolumeId, let page):
            resolvePageReference(page: page,
                                 volumeId: targetVolumeId ?? entry.volumeId)

        case .external(let url):
            openURL(url)

        case .unresolved:
            #if DEBUG
            print("[MacDocumentView] Cross-ref skipped (unresolvable target): \(target)")
            #endif
        }
    }

    /// Pushes `documentId` in `volumeId` onto the navigation stack.
    private func navigateToCrossRef(documentId: String, volumeId: String) {
        guard !documentId.isEmpty else { return }
        let dest = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            // Use the ID as placeholder header — loadDocument() fills the real title
            // after parsing, matching the breadcrumb approach.
            header: documentId
        )
        navigationPath.append(dest)

        #if DEBUG
        print("[MacDocumentView] Cross-ref tap → \(volumeId)/\(documentId)")
        #endif
    }

    /// Resolves a printed-page reference to its containing document and opens it.
    private func resolvePageReference(page: Int, volumeId: String) {
        guard let store = appState.pageRangeStore else {
            #if DEBUG
            print("[MacDocumentView] Page ref: PageRangeStore unavailable")
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
                    print("[MacDocumentView] Page ref: p. \(page) of \(volumeId) not in page index")
                    #endif
                }
            }
        }
    }

    private func handlePersonTap(_ person: PersonEntry) {
        vm.selectedPerson = person
        // Session 162 link audit: the count was never loaded on macOS, so the
        // person sheet always claimed "Not found in indexed documents".
        Task { await vm.loadPersonMentionCount(for: person) }
    }

    private func handleGlossTap(_ gloss: GlossEntry) {
        vm.selectedGloss = gloss
    }

}

// TagRowView removed — document-level subject tags are no longer shown in the UI.

// MARK: - TrailingIconLabelStyle

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: - MacDocumentWindowView

/// Standalone macOS document window hosting one document as a full research
/// workspace — research strip, document body, and status bar — so a window opened
/// via `openWindow(value: DocumentWindowID(...))` is self-sufficient rather than a
/// bare document with no tools.
///
/// macOS gathers windows from the same `WindowGroup(for: DocumentWindowID.self)`
/// into native tabs (Window ▸ Merge All Windows / the window tab bar), which is how
/// a researcher views several documents as tabs in one frame. Each window owns its
/// own navigation stack and `HighlightCoordinator`, independent of the main window
/// and of every other document window.
///
/// Version history:
///   1.0 — Session 159: initial implementation (iPad/Mac parity Phase 2 —
///          macOS native window tabbing)
struct MacDocumentWindowView: View {

    /// The document this window opened for.
    let windowID: DocumentWindowID

    @Environment(AppState.self) private var appState

    /// This window's own navigation stack — cross-reference taps push within the
    /// window rather than affecting the main window or other document windows.
    @State private var navigationPath: [DocumentBrowserEntry] = []
    /// This window's own highlight state (text selection, pending highlight link).
    @State private var highlightCoordinator = HighlightCoordinator()
    /// NARA Catalog Lookup sheet item (see `MainWindowView` for the `.sheet(item:)` rationale).
    @State private var naraLookupItem: NARACatalogLookupItem? = nil

    /// The document the window opened for, as a `DocumentBrowserEntry`.
    private var rootEntry: DocumentBrowserEntry {
        DocumentBrowserEntry(
            documentId: windowID.documentId,
            volumeId: windowID.volumeId,
            header: windowID.header
        )
    }

    /// The document currently shown (the navigation stack's top, or the root).
    private var currentEntry: DocumentBrowserEntry {
        navigationPath.last ?? rootEntry
    }

    var body: some View {
        VStack(spacing: 0) {
            ResearchStripView(
                entry: currentEntry,
                highlightCoordinator: highlightCoordinator,
                onNARALookup: { text in
                    naraLookupItem = NARACatalogLookupItem(text: text)
                }
            )
            .sheet(item: $naraLookupItem) { item in
                NARACatalogLookupView(initialText: item.text)
            }

            NavigationStack(path: $navigationPath) {
                MacDocumentView(
                    entry: rootEntry,
                    navigationPath: $navigationPath,
                    highlightCoordinator: highlightCoordinator
                )
                .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                    MacDocumentView(
                        entry: entry,
                        navigationPath: $navigationPath,
                        highlightCoordinator: highlightCoordinator
                    )
                }
            }

            StatusBarView()
        }
        // Window/tab title — the document's heading, falling back to its id.
        .navigationTitle(currentEntry.header.isEmpty ? currentEntry.documentId : currentEntry.header)
        .onChange(of: currentEntry) { _, _ in
            highlightCoordinator.reset()
        }
    }
}

#endif // os(macOS)
