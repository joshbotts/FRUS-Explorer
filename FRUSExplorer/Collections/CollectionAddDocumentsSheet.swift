// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionDocumentPick

/// A document reference selected in the Add Documents sheet, carrying enough display
/// metadata (header, volume title, date) to render a row without another index round-trip.
///
/// Version history:
///   1.0 — Authoring Phase 3: initial implementation
struct CollectionDocumentPick: Identifiable, Hashable, Sendable {

    /// The document's `xml:id` within its volume (e.g. `"d42"`).
    let documentId: String

    /// The volume the document belongs to (e.g. `"frus1969-76v01"`).
    let volumeId: String

    /// Indexed document header, when available.
    var header: String?

    /// Manifest display title of the containing volume, when available.
    var volumeTitle: String?

    /// ISO-8601 document date from the index, when available.
    var dateISO: String?

    /// The canonical `"volumeId/documentId"` key shared with the entry-data loaders.
    var key: String { "\(volumeId)/\(documentId)" }

    /// Identity is the document key — one pick per document across all tabs.
    var id: String { key }

    /// Hashes only the document identity, so display metadata enrichment never
    /// changes set membership.
    func hash(into hasher: inout Hasher) { hasher.combine(key) }

    /// Equality is document identity only (see `hash(into:)`).
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key }
}

// MARK: - CollectionCitationLineResolver

/// The pure per-line citation resolution pipeline behind the sheet's Citations tab.
///
/// Splits pasted text into non-empty lines and classifies each line into exactly one
/// bucket — resolved, ambiguous, or unresolved — so no input line is ever silently
/// dropped. Parsing and matching are injected as closures, so the pipeline is unit
/// testable without a `CitationMatchingEngine` (or any database).
///
/// ## Line classification
/// 1. A `history.state.gov/historicaldocuments/{volumeId}/{documentId}` URL is exact
///    by construction (the site path components ARE the TEI identifiers) → resolved
///    directly, no engine round-trip.
/// 2. Otherwise the line is parsed (`CitationParser` in production); a non-actionable
///    parse is unresolved.
/// 3. The matcher's ranked results are inspected: a lone document-level match with an
///    exact strategy resolves; document-level matches behind a fuzzy/best-guess
///    strategy or with competing candidates are ambiguous (the top match is surfaced
///    with its rank note); volume-only matches (empty `documentId`, e.g. an
///    un-downloaded volume) and empty result sets are unresolved with the engine's
///    own explanation. Two guards keep "resolved" honest: a document-level hit that
///    the engine itself outranked with a volume-only candidate (e.g. the better-fit
///    volume isn't downloaded) is at most ambiguous, and a parse that identifies no
///    volume at all (no subseries, no volume number — the engine then matched
///    against an arbitrary manifest slice) is at most ambiguous.
///
/// Version history:
///   1.0 — Authoring Phase 3: initial implementation
///   1.1 — Authoring Phase 3 review: never bucket a line "resolved" when the engine's
///          own top-ranked candidate was volume-only, or when the parse carried no
///          volume identity; URL matcher lowercases the volume id (canonical form)
struct CollectionCitationLineResolver: Sendable {

    // MARK: - Outcome

    /// The bucket a single pasted line landed in.
    enum Outcome: Equatable, Sendable {
        /// Confident match: the line maps to exactly this document.
        case resolved(volumeId: String, documentId: String, note: String?)
        /// A plausible top match with competition or a correction applied; `note`
        /// explains the ranking so the user can review before adding.
        case ambiguous(volumeId: String, documentId: String, note: String)
        /// No document-level match; `reason` is always shown, never silently dropped.
        case unresolved(reason: String)
    }

    // MARK: - LineResult

    /// One pasted line together with its classification.
    struct LineResult: Identifiable, Sendable {
        /// Stable row identity for SwiftUI lists.
        let id = UUID()
        /// The original (trimmed) input line.
        let line: String
        /// The bucket the line resolved into.
        let outcome: Outcome
    }

    // MARK: - Injected stages

    /// Parses a raw citation line into structured fields (`CitationParser.parse` in
    /// production; a stub in tests).
    let parse: @Sendable (String) -> CitationInput

    /// Resolves parsed fields to ranked matches (`CitationMatchingEngine.match` in
    /// production; a stub in tests).
    let match: @Sendable (CitationInput) async throws -> [CitationMatch]

    // MARK: - Line splitting

    /// Splits pasted text into trimmed, non-empty lines.
    static func lines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - history.state.gov URL recognition

    /// Extracts an exact document reference from a history.state.gov document URL
    /// embedded anywhere in the line, e.g.
    /// `https://history.state.gov/historicaldocuments/frus1969-76v01/d42`.
    ///
    /// The volume component must carry the `frus` prefix and the document component
    /// must be a `d`-number — the same identifiers used by `CollectionEntry`, so a
    /// hit needs no engine resolution. Matching is case-insensitive (retyped or
    /// OCR'd links), and both components are normalized to lowercase — the canonical
    /// form of every FRUS TEI identifier. Returns `nil` when the line carries no
    /// such URL.
    static func documentReference(inURLLine line: String) -> (volumeId: String, documentId: String)? {
        let pattern = #"history\.state\.gov/historicaldocuments/(frus[A-Za-z0-9\-]+)/(d\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let volRange = Range(m.range(at: 1), in: line),
              let docRange = Range(m.range(at: 2), in: line) else { return nil }
        return (volumeId: String(line[volRange]).lowercased(),
                documentId: String(line[docRange]).lowercased())
    }

    // MARK: - Resolution

    /// Resolves every non-empty line of `text`, preserving input order.
    func resolve(text: String) async -> [LineResult] {
        var results: [LineResult] = []
        for line in Self.lines(from: text) {
            results.append(LineResult(line: line, outcome: await resolve(line: line)))
        }
        return results
    }

    /// Classifies a single line (see the type doc comment for the bucketing rules).
    func resolve(line: String) async -> Outcome {
        // 1. Exact document URL — no engine needed.
        if let ref = Self.documentReference(inURLLine: line) {
            return .resolved(volumeId: ref.volumeId, documentId: ref.documentId, note: nil)
        }

        // 2. Parse; a line with no usable fields can't be matched.
        let input = parse(line)
        guard input.isActionable else {
            return .unresolved(reason: String(
                localized: "collection.addDocs.citations.unparseable",
                defaultValue: "Couldn't read this line as a FRUS citation or document link"))
        }

        // 3. Match and bucket the ranked results.
        let matches: [CitationMatch]
        do {
            matches = try await match(input)
        } catch {
            return .unresolved(reason: error.localizedDescription)
        }

        let documentLevel = matches.filter { !$0.documentId.isEmpty }
        if let top = documentLevel.first {
            // The engine's own top-ranked candidate may be volume-only (e.g. the
            // better-fit volume isn't downloaded, so the engine stopped at a
            // manifest match and moved on). Presenting a lower-ranked document hit
            // as confident would silently discard that competitor — surface it.
            if let overallTop = matches.first, overallTop.rank != top.rank {
                return .ambiguous(
                    volumeId: top.volumeId, documentId: top.documentId,
                    note: String(
                        localized: "collection.addDocs.citations.outranked",
                        defaultValue: "\(top.confidenceLabel) — but the engine ranked \(overallTop.volumeId) higher: \(overallTop.confidenceLabel)"))
            }
            // A parse with no volume identity at all matched against an arbitrary
            // slice of the manifest — never confident, whatever the strategy says.
            if input.subseries == nil && input.volumeNumber == nil {
                return .ambiguous(
                    volumeId: top.volumeId, documentId: top.documentId,
                    note: String(
                        localized: "collection.addDocs.citations.noVolumeIdentity",
                        defaultValue: "\(top.confidenceLabel) — the citation doesn't identify a volume, so this match is a guess"))
            }
            if Self.isExactStrategy(top.matchStrategy),
               top.matchStrategy == .exactDocumentNumber || documentLevel.count == 1 {
                return .resolved(volumeId: top.volumeId, documentId: top.documentId,
                                 note: top.correctionNote)
            }
            return .ambiguous(volumeId: top.volumeId, documentId: top.documentId,
                              note: rankNote(for: top, of: documentLevel.count))
        }

        // Volume-only results (e.g. an un-downloaded volume) carry an explanation.
        if let top = matches.first {
            return .unresolved(reason: top.confidenceLabel)
        }
        return .unresolved(reason: String(
            localized: "collection.addDocs.citations.noMatch",
            defaultValue: "No match found in the local manifest or index"))
    }

    /// Whether a match strategy identifies its document with confidence (as opposed
    /// to a nearest-neighbor or best-guess correction).
    private static func isExactStrategy(_ strategy: MatchStrategy) -> Bool {
        switch strategy {
        case .exactDocumentNumber, .superimposedDocumentNumber, .pageRange:
            return true
        case .fuzzyDocumentNumber, .titleFragmentMatch, .manifestOnly, .bestGuess:
            return false
        }
    }

    /// Builds the user-facing rank note for an ambiguous top match: the engine's own
    /// confidence label, plus the candidate count when there was competition.
    private func rankNote(for top: CitationMatch, of candidateCount: Int) -> String {
        guard candidateCount > 1 else { return top.confidenceLabel }
        return String(
            localized: "collection.addDocs.citations.topOf",
            defaultValue: "\(top.confidenceLabel) — top of \(candidateCount) candidates")
    }
}

// MARK: - CollectionDocumentDiscovery

/// Pure helpers shared by the Add Documents sheet and both collection editors:
/// tag-union gathering, duplicate-key detection (A4), and the append-entries
/// mutation that now allows duplicates.
///
/// Version history:
///   1.0 — Authoring Phase 3: initial implementation
enum CollectionDocumentDiscovery {

    /// The canonical `"volumeId/documentId"` key used across the collection editors.
    static func documentKey(volumeId: String, documentId: String) -> String {
        "\(volumeId)/\(documentId)"
    }

    /// Gathers every document carrying `tagId`, from BOTH annotation types — research
    /// notes tagged with it (`ResearchNote.userTagIds`) and direct document tag
    /// assignments (`DocumentTagAssignment`) — deduplicated, note-derived documents
    /// first, each source in its own stable order.
    @MainActor
    static func tagDocumentRefs(
        tagId: UUID,
        notes: [ResearchNote],
        assignments: [DocumentTagAssignment]
    ) -> [(documentId: String, volumeId: String)] {
        var seen: Set<String> = []
        var refs: [(documentId: String, volumeId: String)] = []
        for note in notes where note.userTagIds.contains(tagId) {
            let key = documentKey(volumeId: note.volumeId, documentId: note.documentId)
            if seen.insert(key).inserted {
                refs.append((documentId: note.documentId, volumeId: note.volumeId))
            }
        }
        for assignment in assignments where assignment.tagId == tagId {
            let key = documentKey(volumeId: assignment.volumeId, documentId: assignment.documentId)
            if seen.insert(key).inserted {
                refs.append((documentId: assignment.documentId, volumeId: assignment.volumeId))
            }
        }
        return refs
    }

    /// Returns the document keys that appear on MORE than one document entry — the
    /// set behind the "Also in collection" badge (A4). Computed once at the pane
    /// level; heading/prose entries never contribute.
    @MainActor
    static func duplicateDocumentKeys(in entries: [CollectionEntry]) -> Set<String> {
        var counts: [String: Int] = [:]
        for entry in entries where entry.entryKind == .document {
            counts[documentKey(volumeId: entry.volumeId, documentId: entry.documentId), default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    /// Appends document entries for `refs` at the end of `sortedEntries` in the given
    /// order, inserting each into `modelContext`.
    ///
    /// **Duplicates are allowed** (decision A4): a document legitimately appears in
    /// two places (e.g. two future sections), so documents already in the collection
    /// are appended again rather than silently skipped, and the editors mark repeats
    /// with an "Also in collection" badge instead. Insertion is always at the end of
    /// the entry list, in selection order (section-aware placement arrives with
    /// Phase 4).
    @MainActor
    static func appendEntries(
        _ refs: [(documentId: String, volumeId: String)],
        collection: Collection,
        sortedEntries: inout [CollectionEntry],
        modelContext: ModelContext
    ) {
        var next = sortedEntries.count
        for ref in refs {
            let entry = CollectionEntry(
                collectionId: collection.id,
                documentId: ref.documentId,
                volumeId: ref.volumeId,
                sortOrder: next
            )
            entry.collection = collection
            modelContext.insert(entry)
            sortedEntries.append(entry)
            next += 1
        }
    }
}

// MARK: - CollectionAddDocumentsSheet

/// In-editor document discovery: one sheet, four ways to find documents, one shared
/// multi-selection (Authoring Phase 3).
///
/// ## Tabs
/// - **Search** — FTS5 keyword search over the local index (slim rows, not the full
///   `SearchView`).
/// - **Browse** — two levels only: manifest volume list → indexed document list, with
///   the existing download affordance for un-downloaded volumes.
/// - **Citations** — paste footnotes, a bibliography, or history.state.gov links; each
///   line is resolved through `CollectionCitationLineResolver` and shown per-line
///   (resolved pre-selected, ambiguous with a rank note, unresolved clearly marked).
/// - **Tags** — pick a `UserTag`; documents gathered from note tags ∪ direct
///   `DocumentTagAssignment` rows, pre-selected.
///
/// All tabs toggle membership in the same ordered selection; the persistent bottom bar
/// adds the selection to the collection (appended at the end of the entry list, in
/// selection order). Documents already in the collection show an "In collection"
/// indicator but stay selectable — duplicates are allowed (A4).
///
/// ## Platform layout
/// On macOS, `NavigationStack { List }` inside a `.sheet()` renders as a collapsed
/// split-column, so the macOS body is a plain `VStack` with an explicit button bar
/// (the `CollectionEditorView.macBody` pattern). iOS uses a `NavigationStack` with a
/// bottom-inset add bar.
///
/// Version history:
///   1.0 — Authoring Phase 3: initial implementation, replacing `AddByTagSheet`
///   1.1 — Authoring Phase 3 review: pre-selection (tags, citations) no longer reverts
///          explicit deselections; O(1) selection membership via a parallel key set;
///          macOS Add button no longer captures Return from the text fields; Browse
///          "Downloading…" tracks the live download queue (failure restores the
///          Download button); clearing the search field restores the search hint
struct CollectionAddDocumentsSheet: View {

    // MARK: - Inputs

    /// All user tags, for the Tags tab.
    let allTags: [UserTag]

    /// All research notes, for note-tag gathering on the Tags tab.
    let allNotes: [ResearchNote]

    /// Keys (`"volumeId/documentId"`) of documents already in the collection, for the
    /// "In collection" row indicator. Rows stay selectable — duplicates are allowed (A4).
    let existingDocumentKeys: Set<String>

    /// Receives the ordered selection when the user confirms.
    let onAdd: ([CollectionDocumentPick]) -> Void

    // MARK: - Environment

    /// Shared services: search, manifest, indexing pipeline, citation engine, downloads.
    @Environment(AppState.self) private var appState

    /// Dismisses the sheet.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Queries

    /// Direct document-tag assignments, unioned with note tags on the Tags tab.
    @Query private var tagAssignments: [DocumentTagAssignment]

    // MARK: - Tabs

    /// The sheet's four discovery surfaces.
    private enum DiscoveryTab: Hashable, CaseIterable {
        /// FTS5 keyword search.
        case search
        /// Volume → document drill-down.
        case browse
        /// Pasted citations / URLs.
        case citations
        /// User-tag gathering.
        case tags

        /// Localized segment title.
        var title: String {
            switch self {
            case .search:
                return String(localized: "collection.addDocs.tab.search", defaultValue: "Search")
            case .browse:
                return String(localized: "collection.addDocs.tab.browse", defaultValue: "Browse")
            case .citations:
                return String(localized: "collection.addDocs.tab.citations", defaultValue: "Citations")
            case .tags:
                return String(localized: "collection.addDocs.tab.tags", defaultValue: "Tags")
            }
        }
    }

    // MARK: - State

    /// The active tab.
    @State private var tab: DiscoveryTab = .search

    /// The shared ordered selection all tabs add to / remove from.
    @State private var selection: [CollectionDocumentPick] = []

    /// The keys of `selection`, mirrored for O(1) membership checks (`isSelected`,
    /// Select All's all-selected test) — the ordered array alone made every check a
    /// linear scan, quadratic over large volumes. Kept in sync by `toggle(_:)`,
    /// `select(_:)`, and the Select All / Deselect All handler.
    @State private var selectedKeys: Set<String> = []

    /// Keys the user explicitly deselected in this sheet session. Pre-selection
    /// passes (tag drill-ins, citation Resolve) skip them, so re-entering a tag or
    /// re-running Resolve never silently reverts an explicit deselection. An explicit
    /// re-selection (row tap, Select All) clears the key again.
    @State private var explicitlyDeselectedKeys: Set<String> = []

    // Search tab
    /// Current search field text (debounced into `runSearch`).
    @State private var searchText = ""
    /// Latest search results.
    @State private var searchResults: [SearchResult] = []
    /// `true` while a search query runs.
    @State private var isSearching = false
    /// `true` once any search has completed (drives the empty state).
    @State private var hasSearched = false

    // Browse tab
    /// Volume-list filter text (title or id).
    @State private var browseFilter = ""
    /// The drilled-into volume; `nil` shows the volume list (level 1).
    @State private var browseVolume: VolumeManifestEntry?
    /// Documents of the drilled-into (indexed) volume.
    @State private var browseDocuments: [DocumentBrowserEntry] = []
    /// `true` while the volume's document list loads.
    @State private var isLoadingBrowseDocuments = false
    /// Volume ids whose download was requested from this sheet but hasn't yet reached
    /// the observable download queue. Bridges the tap → queue-callback gap only: once
    /// a volume appears in `appState.downloadQueue`, the queue owns the in-progress
    /// state and the id is dropped (see the `onChange` in `body`), so a failed
    /// download falls back to the Download button instead of a permanent spinner.
    @State private var requestedDownloads: Set<String> = []

    // Citations tab
    /// The paste area's raw text.
    @State private var citationText = ""
    /// Per-line resolution results; `nil` before the first Resolve.
    @State private var citationResults: [CollectionCitationLineResolver.LineResult]?
    /// `true` while a Resolve pass runs.
    @State private var isResolvingCitations = false
    /// Headers fetched for resolved citation refs, keyed `"volumeId/documentId"`.
    @State private var citationHeaders: [String: String] = [:]

    // Tags tab
    /// The drilled-into tag; `nil` shows the tag list.
    @State private var selectedTag: UserTag?
    /// Gathered picks for the drilled-into tag.
    @State private var tagPicks: [CollectionDocumentPick] = []

    // MARK: - Body

    var body: some View {
        platformBody
            // Once a requested volume reaches the observable queue, the queue owns
            // its "Downloading…" state; dropping the local flag here means a failed
            // download (which leaves the queue without ever indexing) restores the
            // Download button so the user can retry.
            .onChange(of: appState.downloadQueue) { _, queue in
                requestedDownloads.subtract(queue)
            }
    }

    /// The platform-specific sheet shell.
    private var platformBody: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS Body

    #if os(macOS)
    /// macOS shell: title bar, tab picker, active tab, explicit bottom button bar.
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "collection.addDocs.title",
                            defaultValue: "Add Documents"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            tabPicker
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Divider()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button(String(localized: "collection.addDocs.cancel",
                              defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                // Deliberately NOT .keyboardShortcut(.defaultAction): a default
                // button's Return key-equivalent fires before the focused text
                // field's editor sees the key, so Return in the Search or Browse
                // filter fields would commit-and-dismiss the sheet mid-flow.
                addButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 560, minHeight: 480)
    }
    #endif

    // MARK: - iOS Body

    /// iOS shell: navigation stack, tab picker pinned above the active tab, bottom
    /// safe-area add bar.
    private var iOSBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                tabContent
            }
            .navigationTitle(String(localized: "collection.addDocs.title",
                                    defaultValue: "Add Documents"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.addDocs.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    addButton
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }

    // MARK: - Shared chrome

    /// The Search | Browse | Citations | Tags segmented control.
    private var tabPicker: some View {
        Picker(String(localized: "collection.addDocs.tab.picker", defaultValue: "Find documents"),
               selection: $tab) {
            ForEach(DiscoveryTab.allCases, id: \.self) { t in
                Text(t.title).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// The active tab's content.
    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .search:    searchTab
        case .browse:    browseTab
        case .citations: citationsTab
        case .tags:      tagsTab
        }
    }

    /// The persistent "Add N Documents" confirmation button, disabled at zero.
    private var addButton: some View {
        Button {
            onAdd(selection)
            dismiss()
        } label: {
            Text(String(
                format: String(localized: "collection.addDocs.add %lld",
                               defaultValue: "Add %lld Document(s)"),
                Int64(selection.count)))
        }
        .disabled(selection.isEmpty)
    }

    // MARK: - Selection

    /// Whether the given document key is currently selected (O(1) via `selectedKeys`).
    private func isSelected(_ key: String) -> Bool {
        selectedKeys.contains(key)
    }

    /// Toggles a pick in/out of the shared selection (append order preserved). An
    /// explicit deselection is remembered so pre-selection passes never undo it.
    private func toggle(_ pick: CollectionDocumentPick) {
        if selectedKeys.contains(pick.key) {
            selection.removeAll { $0.key == pick.key }
            selectedKeys.remove(pick.key)
            explicitlyDeselectedKeys.insert(pick.key)
        } else {
            selection.append(pick)
            selectedKeys.insert(pick.key)
            explicitlyDeselectedKeys.remove(pick.key)
        }
    }

    /// Explicitly adds picks that aren't yet selected (Select All). Overrides any
    /// remembered deselection — the user asked for these by name.
    private func select(_ picks: [CollectionDocumentPick]) {
        for pick in picks where !selectedKeys.contains(pick.key) {
            selection.append(pick)
            selectedKeys.insert(pick.key)
            explicitlyDeselectedKeys.remove(pick.key)
        }
    }

    /// Adds picks on behalf of an automatic pre-selection pass (tag drill-in,
    /// citation Resolve) — skips any key the user explicitly deselected, so
    /// re-entering a tag or re-running Resolve respects earlier deselections.
    private func preselect(_ picks: [CollectionDocumentPick]) {
        select(picks.filter { !explicitlyDeselectedKeys.contains($0.key) })
    }

    // MARK: - Search tab

    /// FTS5 keyword search with slim, selection-toggling result rows.
    private var searchTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "collection.addDocs.search.placeholder",
                                 defaultValue: "Search indexed documents"),
                          text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await runSearch(debounce: false) } }
                if isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if searchResults.isEmpty {
                // "No results" only after a search actually completed for the current
                // text — not while one is in flight, and not after the field was
                // cleared (runSearch resets `hasSearched` for short/empty queries).
                emptyState(
                    hasSearched && !isSearching
                        ? String(localized: "collection.addDocs.search.noResults",
                                 defaultValue: "No results. Only downloaded and indexed volumes are searchable.")
                        : String(localized: "collection.addDocs.search.hint",
                                 defaultValue: "Search the full text of your indexed volumes."))
            } else {
                List(searchResults) { result in
                    let pick = pickFrom(result)
                    DiscoveryPickRow(
                        pick: pick,
                        isSelected: isSelected(pick.key),
                        inCollection: existingDocumentKeys.contains(pick.key),
                        badges: badges(editorial: result.isEditorialNote,
                                       frontMatter: result.isFrontMatter)
                    ) { toggle(pick) }
                }
                .listStyle(.plain)
            }
        }
        // Debounced live search: edits settle for ~0.35 s before the query runs.
        .task(id: searchText) {
            await runSearch(debounce: true)
        }
    }

    /// Runs the FTS5 search for the current field text (≥ 2 characters), capped at
    /// 100 results — insert-focused, deliberately not the full Search experience.
    private func runSearch(debounce: Bool) async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if debounce {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
        }
        guard query.count >= 2, let service = appState.searchService else {
            searchResults = []
            // Un-latch the empty state: a cleared/too-short field shows the search
            // hint again, not "No results" left over from the previous query.
            hasSearched = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        var params = SearchParameters()
        params.keywords = query
        let results = (try? await service.search(parameters: params, limit: 100)) ?? []
        if Task.isCancelled { return }
        searchResults = results
        hasSearched = true
    }

    /// Builds a pick (with display metadata) from a search result.
    private func pickFrom(_ result: SearchResult) -> CollectionDocumentPick {
        CollectionDocumentPick(
            documentId: result.documentId,
            volumeId: result.volumeId,
            header: result.header.isEmpty ? nil : result.header,
            volumeTitle: volumeTitle(for: result.volumeId),
            dateISO: result.dateISO)
    }

    /// Row badges for editorial-note / front-matter results.
    private func badges(editorial: Bool, frontMatter: Bool) -> [String] {
        var badges: [String] = []
        if editorial {
            badges.append(String(localized: "collection.addDocs.badge.editorial",
                                 defaultValue: "Editorial note"))
        }
        if frontMatter {
            badges.append(String(localized: "collection.addDocs.badge.frontMatter",
                                 defaultValue: "Front matter"))
        }
        return badges
    }

    // MARK: - Browse tab

    /// Two-level drill-down: manifest volume list → indexed document list. Deliberately
    /// NOT the corpus Browser — no subseries/compilation levels.
    @ViewBuilder
    private var browseTab: some View {
        if let volume = browseVolume {
            browseDocumentLevel(volume)
        } else {
            browseVolumeLevel
        }
    }

    /// The manifest entries, live diff preferred.
    private var manifestEntries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    /// Level 1: the filterable volume list with downloaded/indexed state.
    private var browseVolumeLevel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "collection.addDocs.browse.filter",
                                 defaultValue: "Filter volumes by title or ID"),
                          text: $browseFilter)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            List(filteredVolumes) { volume in
                Button {
                    browseVolume = volume
                    browseDocuments = []
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(volume.title)
                                .font(.callout)
                                .lineLimit(2)
                            Text([volume.volumeId, volumeStateLabel(volume.volumeId)]
                                    .joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    /// Volumes matching the filter text (title or id, case-insensitive).
    private var filteredVolumes: [VolumeManifestEntry] {
        let filter = browseFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !filter.isEmpty else { return manifestEntries }
        return manifestEntries.filter {
            $0.title.lowercased().contains(filter) || $0.volumeId.lowercased().contains(filter)
        }
    }

    /// Localized downloaded/indexed state for a volume row.
    private func volumeStateLabel(_ volumeId: String) -> String {
        if appState.indexedVolumeIds.contains(volumeId) {
            return String(localized: "collection.addDocs.browse.state.indexed",
                          defaultValue: "Indexed")
        }
        if appState.downloadManager?.isVolumeDownloaded(volumeId) == true {
            return String(localized: "collection.addDocs.browse.state.downloaded",
                          defaultValue: "Downloaded, not indexed")
        }
        return String(localized: "collection.addDocs.browse.state.notDownloaded",
                      defaultValue: "Not downloaded")
    }

    /// Level 2: the selected volume's document list (indexed), or the un-downloaded /
    /// un-indexed affordances.
    private func browseDocumentLevel(_ volume: VolumeManifestEntry) -> some View {
        let isIndexed = appState.indexedVolumeIds.contains(volume.volumeId)
        let isDownloaded = appState.downloadManager?.isVolumeDownloaded(volume.volumeId) == true
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    browseVolume = nil
                    browseDocuments = []
                } label: {
                    Label(String(localized: "collection.addDocs.browse.back",
                                 defaultValue: "Volumes"),
                          systemImage: "chevron.left")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                Spacer()
                if isIndexed && !browseDocuments.isEmpty {
                    selectAllButton(for: volume)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Text(volume.title)
                .font(.callout.bold())
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider()

            if isIndexed {
                if isLoadingBrowseDocuments {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(browseDocuments) { doc in
                        let pick = pickFrom(doc, volume: volume)
                        DiscoveryPickRow(
                            pick: pick,
                            isSelected: isSelected(pick.key),
                            inCollection: existingDocumentKeys.contains(pick.key),
                            badges: badges(editorial: doc.isEditorialNote, frontMatter: false)
                        ) { toggle(pick) }
                    }
                    .listStyle(.plain)
                }
            } else if isDownloaded {
                emptyState(String(localized: "collection.addDocs.browse.notIndexed",
                                  defaultValue: "This volume is downloaded but not yet indexed. Indexing normally starts right after download — give it a moment, or check Settings if it doesn't."))
            } else {
                notDownloadedState(volume)
            }
        }
        // Load (or reload) the document list whenever the volume or its indexed state
        // changes — a download enqueued here indexes automatically, flips
        // `appState.indexedVolumeIds`, and this task re-fires with the fresh list.
        .task(id: "\(volume.volumeId)|\(isIndexed)") {
            guard isIndexed else { return }
            isLoadingBrowseDocuments = true
            defer { isLoadingBrowseDocuments = false }
            let docs = (try? await appState.indexingPipeline?
                .documents(forVolume: volume.volumeId)) ?? []
            if Task.isCancelled { return }
            browseDocuments = docs
        }
    }

    /// Select-all / deselect-all affordance for the drilled-into volume.
    private func selectAllButton(for volume: VolumeManifestEntry) -> some View {
        let picks = browseDocuments.map { pickFrom($0, volume: volume) }
        let allSelected = picks.allSatisfy { isSelected($0.key) }
        return Button(allSelected
            ? String(localized: "collection.addDocs.browse.deselectAll",
                     defaultValue: "Deselect All")
            : String(localized: "collection.addDocs.browse.selectAll",
                     defaultValue: "Select All")) {
            if allSelected {
                let keys = Set(picks.map(\.key))
                selection.removeAll { keys.contains($0.key) }
                selectedKeys.subtract(keys)
                // Explicit bulk deselection: remember it, like a per-row toggle.
                explicitlyDeselectedKeys.formUnion(keys)
            } else {
                select(picks)
            }
        }
        .font(.callout)
    }

    /// The un-downloaded volume state: explanation + the existing `DownloadManager`
    /// enqueue path (the same one the preview's download bar and the Browser use).
    ///
    /// "Downloading…" is driven by the live download queue (plus the brief
    /// tap-to-callback bridge in `requestedDownloads`), so a failed download — which
    /// leaves the queue — restores the Download button for a retry instead of
    /// spinning forever.
    private func notDownloadedState(_ volume: VolumeManifestEntry) -> some View {
        let inFlight = requestedDownloads.contains(volume.volumeId)
            || appState.downloadQueue.contains(volume.volumeId)
        return VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(String(localized: "collection.addDocs.browse.notDownloaded",
                        defaultValue: "This volume isn't downloaded. Download and index it to browse its documents here."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if inFlight {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "collection.addDocs.browse.downloading",
                                defaultValue: "Downloading…"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(String(localized: "collection.addDocs.browse.download",
                              defaultValue: "Download")) {
                    // Only show progress when something was actually enqueued.
                    guard let dm = appState.downloadManager else { return }
                    requestedDownloads.insert(volume.volumeId)
                    Task { await dm.enqueueDownload(volumeId: volume.volumeId,
                                                    downloadUrl: volume.downloadUrl) }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Builds a pick from a browser entry.
    private func pickFrom(_ doc: DocumentBrowserEntry, volume: VolumeManifestEntry) -> CollectionDocumentPick {
        CollectionDocumentPick(
            documentId: doc.documentId,
            volumeId: volume.volumeId,
            header: doc.header.isEmpty ? nil : doc.header,
            volumeTitle: volume.title,
            dateISO: nil)
    }

    // MARK: - Citations tab

    /// Paste area + Resolve button + per-line results. Every pasted line gets a row:
    /// resolved (pre-selected), ambiguous (top match, rank note), or unresolved.
    private var citationsTab: some View {
        VStack(spacing: 0) {
            TextEditor(text: $citationText)
                .font(.callout.monospaced())
                .frame(minHeight: 96, maxHeight: 150)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .overlay(alignment: .topLeading) {
                    if citationText.isEmpty {
                        Text(String(localized: "collection.addDocs.citations.placeholder",
                                    defaultValue: "Paste citations or history.state.gov links, one per line…"))
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Spacer()
                if isResolvingCitations {
                    ProgressView().controlSize(.small)
                }
                Button(String(localized: "collection.addDocs.citations.resolve",
                              defaultValue: "Resolve")) {
                    Task { await resolveCitations() }
                }
                .disabled(isResolvingCitations
                          || citationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if let results = citationResults {
                if results.isEmpty {
                    emptyState(String(localized: "collection.addDocs.citations.empty",
                                      defaultValue: "Nothing to resolve — paste at least one line."))
                } else {
                    List(results) { result in
                        citationRow(result)
                    }
                    .listStyle(.plain)
                }
            } else {
                emptyState(String(localized: "collection.addDocs.citations.hint",
                                  defaultValue: "Each line is resolved against the FRUS manifest and your local index — footnotes, bibliography entries, and document links all work."))
            }
        }
    }

    /// One per-line result row: a selectable match row or an unresolved marker.
    @ViewBuilder
    private func citationRow(_ result: CollectionCitationLineResolver.LineResult) -> some View {
        switch result.outcome {
        case .resolved(let volumeId, let documentId, let note):
            let pick = citationPick(volumeId: volumeId, documentId: documentId)
            DiscoveryPickRow(
                pick: pick,
                isSelected: isSelected(pick.key),
                inCollection: existingDocumentKeys.contains(pick.key),
                badges: [],
                sourceLine: result.line,
                note: note,
                noteIsWarning: false
            ) { toggle(pick) }
        case .ambiguous(let volumeId, let documentId, let note):
            let pick = citationPick(volumeId: volumeId, documentId: documentId)
            DiscoveryPickRow(
                pick: pick,
                isSelected: isSelected(pick.key),
                inCollection: existingDocumentKeys.contains(pick.key),
                badges: [],
                sourceLine: result.line,
                note: note,
                noteIsWarning: true
            ) { toggle(pick) }
        case .unresolved(let reason):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.line)
                        .font(.callout)
                        .lineLimit(2)
                    Text(String(localized: "collection.addDocs.citations.noMatchPrefix",
                                defaultValue: "No match — \(reason)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// Builds a pick for a citation match, using the fetched header when available.
    private func citationPick(volumeId: String, documentId: String) -> CollectionDocumentPick {
        let key = CollectionDocumentDiscovery.documentKey(volumeId: volumeId, documentId: documentId)
        return CollectionDocumentPick(
            documentId: documentId,
            volumeId: volumeId,
            header: citationHeaders[key],
            volumeTitle: volumeTitle(for: volumeId),
            dateISO: nil)
    }

    /// Runs the per-line pipeline over the paste area, fetches headers for the matched
    /// refs, and pre-selects the confidently resolved lines (ambiguous ones await the
    /// user's review).
    private func resolveCitations() async {
        guard let engine = appState.citationMatchingEngine else {
            citationResults = CollectionCitationLineResolver.lines(from: citationText).map {
                .init(line: $0, outcome: .unresolved(reason: String(
                    localized: "collection.addDocs.citations.noEngine",
                    defaultValue: "Citation lookup is unavailable")))
            }
            return
        }
        isResolvingCitations = true
        defer { isResolvingCitations = false }

        let parser = CitationParser()
        let resolver = CollectionCitationLineResolver(
            parse: { parser.parse($0) },
            match: { try await engine.match(input: $0) })
        let results = await resolver.resolve(text: citationText)

        // Enrich matched refs with indexed headers (absent for unindexed volumes).
        var refs: [(volumeId: String, documentId: String)] = []
        for result in results {
            switch result.outcome {
            case .resolved(let vol, let doc, _), .ambiguous(let vol, let doc, _):
                refs.append((volumeId: vol, documentId: doc))
            case .unresolved:
                break
            }
        }
        if let store = appState.crossReferenceStore,
           let headers = try? await store.documentHeaders(for: refs) {
            citationHeaders = headers
        }

        citationResults = results

        // Pre-select the confident matches, in line order (skipping any the user
        // explicitly deselected on an earlier Resolve pass).
        var picks: [CollectionDocumentPick] = []
        for result in results {
            if case .resolved(let vol, let doc, _) = result.outcome {
                picks.append(citationPick(volumeId: vol, documentId: doc))
            }
        }
        preselect(picks)
    }

    // MARK: - Tags tab

    /// Two levels: the tag list (with union counts), then the gathered documents for a
    /// tag — note-carried tags ∪ direct `DocumentTagAssignment` rows — pre-selected.
    @ViewBuilder
    private var tagsTab: some View {
        if let tag = selectedTag {
            tagDocumentLevel(tag)
        } else {
            tagListLevel
        }
    }

    /// Level 1: all user tags with the count of documents each would gather.
    private var tagListLevel: some View {
        Group {
            if allTags.isEmpty {
                emptyState(String(localized: "collection.addDocs.tags.none",
                                  defaultValue: "No user tags yet. Tag documents or research notes to gather them here."))
            } else {
                List(allTags) { tag in
                    Button {
                        openTag(tag)
                    } label: {
                        HStack {
                            Label(tag.name, systemImage: "tag")
                            Spacer()
                            Text("\(tagRefCount(tag))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    /// The union count for a tag row (notes ∪ assignments, deduplicated).
    private func tagRefCount(_ tag: UserTag) -> Int {
        CollectionDocumentDiscovery.tagDocumentRefs(
            tagId: tag.id, notes: allNotes, assignments: tagAssignments).count
    }

    /// Level 2: the gathered, pre-selected document rows for the drilled-into tag.
    private func tagDocumentLevel(_ tag: UserTag) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    selectedTag = nil
                    tagPicks = []
                } label: {
                    Label(String(localized: "collection.addDocs.tags.back",
                                 defaultValue: "Tags"),
                          systemImage: "chevron.left")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                Spacer()
                Label(tag.name, systemImage: "tag")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if tagPicks.isEmpty {
                emptyState(String(localized: "collection.addDocs.tags.empty",
                                  defaultValue: "No documents carry this tag."))
            } else {
                List(tagPicks) { pick in
                    DiscoveryPickRow(
                        pick: pick,
                        isSelected: isSelected(pick.key),
                        inCollection: existingDocumentKeys.contains(pick.key),
                        badges: []
                    ) { toggle(pick) }
                }
                .listStyle(.plain)
            }
        }
        // Enrich the gathered refs with indexed headers once per drill-in.
        .task(id: tag.id) {
            let keys = tagPicks.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
            guard !keys.isEmpty, let store = appState.crossReferenceStore,
                  let headers = try? await store.documentHeaders(for: keys) else { return }
            if Task.isCancelled { return }
            tagPicks = tagPicks.map { pick in
                var enriched = pick
                enriched.header = headers[pick.key] ?? pick.header
                return enriched
            }
            // Refresh headers on any already-selected copies of these picks too.
            selection = selection.map { pick in
                var enriched = pick
                enriched.header = headers[pick.key] ?? pick.header
                return enriched
            }
        }
    }

    /// Drills into a tag: gathers the union refs, builds picks, and pre-selects them.
    private func openTag(_ tag: UserTag) {
        let refs = CollectionDocumentDiscovery.tagDocumentRefs(
            tagId: tag.id, notes: allNotes, assignments: tagAssignments)
        tagPicks = refs.map { ref in
            CollectionDocumentPick(
                documentId: ref.documentId,
                volumeId: ref.volumeId,
                header: nil,
                volumeTitle: volumeTitle(for: ref.volumeId),
                dateISO: nil)
        }
        selectedTag = tag
        preselect(tagPicks)
    }

    // MARK: - Shared helpers

    /// The manifest display title for a volume id (`nil` when unknown, so rows fall
    /// back to the raw id).
    private func volumeTitle(for volumeId: String) -> String? {
        manifestEntries.first(where: { $0.volumeId == volumeId })?.title
    }

    /// A centered, secondary explanatory message filling the tab area.
    private func emptyState(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - DiscoveryPickRow

/// A slim, selection-toggling document row shared by all four tabs of the Add
/// Documents sheet: leading checkmark, header (or raw id), a caption line with
/// document id · volume · date, optional badges, and — on the Citations tab — the
/// original pasted line plus the resolver's note.
///
/// Version history:
///   1.0 — Authoring Phase 3: initial implementation
///   1.1 — Session 2026-07-04 (UI audit A5): `.isSelected` trait mirrors the
///          checkmark-symbol swap so selection isn't conveyed by iconography alone
private struct DiscoveryPickRow: View {

    /// The document this row represents.
    let pick: CollectionDocumentPick

    /// Whether the document is in the sheet's shared selection.
    let isSelected: Bool

    /// Whether the document is already in the collection (subtle indicator; the row
    /// stays selectable — duplicates are allowed, A4).
    let inCollection: Bool

    /// Short badges (e.g. "Editorial note", "Front matter").
    var badges: [String] = []

    /// The original pasted citation line (Citations tab only).
    var sourceLine: String? = nil

    /// A resolver note — a correction, or an ambiguity rank note (Citations tab only).
    var note: String? = nil

    /// Whether `note` flags ambiguity (rendered orange) rather than plain information.
    var noteIsWarning: Bool = false

    /// Toggles the document's membership in the shared selection.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.body)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.header ?? pick.documentId)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text([
                        pick.header != nil ? pick.documentId : nil,
                        pick.volumeTitle ?? pick.volumeId,
                        pick.dateISO,
                    ].compactMap(\.self).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let sourceLine {
                        Text(sourceLine)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    if let note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(noteIsWarning ? Color.orange : Color.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if !badges.isEmpty || inCollection {
                        HStack(spacing: 6) {
                            ForEach(badges, id: \.self) { badge in
                                Text(badge)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15),
                                                in: Capsule())
                            }
                            if inCollection {
                                Label(String(localized: "collection.addDocs.inCollection",
                                             defaultValue: "In collection"),
                                      systemImage: "checkmark.rectangle.stack")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 1)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(
            localized: "collection.addDocs.row.accessibility",
            defaultValue: "\(pick.header ?? pick.documentId), \(selectionStateLabel)"))
        // A5: expose selection as a trait, not just the symbol swap / label suffix.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Localized selection state for the accessibility label.
    private var selectionStateLabel: String {
        isSelected
            ? String(localized: "collection.addDocs.row.selected", defaultValue: "selected")
            : String(localized: "collection.addDocs.row.notSelected", defaultValue: "not selected")
    }
}
