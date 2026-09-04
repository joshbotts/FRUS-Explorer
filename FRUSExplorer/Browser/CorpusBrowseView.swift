// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI
import SwiftData

// MARK: - CorporaAxis

/// The working-corpora browse axis's pure logic (#1051 B-4, A-6): row captions, the
/// truncation disclosure, the per-volume document grouping, the three-tier date sort key,
/// and the degraded-row state decider — split from the views for testability.
///
/// ## The settled stances this encodes
/// - **Capture-only.** A corpus is captured from a result set — Search results or the
///   semantic map's lasso. Browse lists and opens corpora; it never creates one (the
///   owner-authored design stance in `WorkingCorporaView`, which stands).
/// - **Coverage is by VOLUME membership, never header presence** — editorial notes are
///   indexed but headerless, so `header == nil` is not evidence a volume is unindexed
///   (`WorkingCorpusResolver` owns the arithmetic and the sentence).
/// - **Truncation-at-capture is three states, not two** (`CaptureTruncation`): an
///   `unrecorded` legacy corpus is said out loud, never collapsed into "complete".
///
/// Version history:
///   1.0 — #1051 B-4: initial implementation
enum CorporaAxis {

    /// One member document, split from its `"volumeId/documentId"` key.
    struct DocumentRef: Identifiable, Equatable {
        let key: String
        let volumeId: String
        let documentId: String

        var id: String { key }
    }

    /// One volume's run of member documents.
    struct VolumeSection: Identifiable {
        let volumeId: String
        let documents: [DocumentRef]

        var id: String { volumeId }
    }

    /// What a degraded row's capsule offers (R-3: the list never blocks; ACTIONS gate).
    enum RowState: Equatable {
        /// The volume is indexed — the row opens the document.
        case open
        /// Downloaded but not indexed — the capsule offers Index.
        case needsIndex
        /// Not on this device — the capsule offers Download.
        case needsDownload
    }

    /// The display name — corpora, like scopes, may be saved unnamed.
    ///
    /// - Parameter corpus: The corpus.
    /// - Returns: The name, or the untitled placeholder.
    static func displayName(_ corpus: WorkingCorpus) -> String {
        corpus.name.isEmpty
            ? String(localized: "browser.corpora.untitled", defaultValue: "Untitled Corpus")
            : corpus.name
    }

    /// The corpora-list row caption: count · origin · capture date.
    ///
    /// - Parameter corpus: The corpus.
    /// - Returns: The caption.
    static func rowCaption(_ corpus: WorkingCorpus) -> String {
        var parts = [String(localized: "browser.corpora.row.count",
                            defaultValue: "\(corpus.documentCount) documents")]
        if let source = corpus.sourceDescription, !source.isEmpty {
            parts.append(source)
        } else if let query = corpus.sourceQuery, !query.isEmpty {
            parts.append(String(localized: "browser.corpora.row.query",
                                defaultValue: "captured from “\(query)”"))
        }
        if let captured = corpus.capturedAt {
            parts.append(captured.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " · ")
    }

    /// The truncation disclosure line, or `nil` when the capture was complete.
    ///
    /// - Parameter truncation: The corpus's `truncationAtCapture`.
    /// - Returns: The amber line for a truncated capture, the quiet line for an
    ///   unrecorded one, `nil` for a complete one.
    static func truncationLine(_ truncation: WorkingCorpus.CaptureTruncation,
                               documentCount: Int) -> String? {
        switch truncation {
        case .truncated(let total?):
            return String(localized: "browser.corpora.truncated",
                          defaultValue: "Saved \(documentCount) of \(total) matches")
        case .truncated(nil):
            return String(localized: "browser.corpora.truncated.noTotal",
                          defaultValue: "The capture stopped short of every match")
        case .complete:
            return nil
        case .unrecorded:
            return String(localized: "browser.corpora.unrecorded",
                          defaultValue: "Capture completeness not recorded")
        }
    }

    /// Groups a corpus's keys into per-volume sections, volumes ordered by id.
    /// Malformed keys (no `/`) are skipped, never invented into rows.
    ///
    /// - Parameter keys: The corpus's `documentKeys`.
    /// - Returns: The sections; document order within each is settled by the view after
    ///   dates load (`sortKey(dateISO:volumeEarliest:)`).
    static func volumeSections(from keys: [String]) -> [VolumeSection] {
        var byVolume: [String: [DocumentRef]] = [:]
        for key in keys {
            let parts = key.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let ref = DocumentRef(key: key, volumeId: String(parts[0]), documentId: String(parts[1]))
            byVolume[ref.volumeId, default: []].append(ref)
        }
        return byVolume.keys.sorted().map { VolumeSection(volumeId: $0, documents: byVolume[$0] ?? []) }
    }

    /// The canonical three-tier date sort key (the Collections precedent, imported
    /// deliberately): per-document ISO date → the volume's earliest coverage date →
    /// a `"9999"` sentinel so dateless rows sort last.
    ///
    /// - Parameters:
    ///   - dateISO: The document's `date_iso`, when its volume is indexed.
    ///   - volumeEarliest: The volume's manifest `dateRange.earliest`.
    /// - Returns: The sortable key.
    static func sortKey(dateISO: String?, volumeEarliest: String?) -> String {
        dateISO ?? volumeEarliest ?? "9999"
    }

    /// Orders one section's documents by the three-tier key, ties by document id.
    ///
    /// - Parameters:
    ///   - documents: The section's refs.
    ///   - dates: Per-document ISO dates keyed by `"volumeId/documentId"`.
    ///   - volumeEarliest: The section volume's earliest coverage date.
    /// - Returns: The ordered refs.
    static func ordered(
        _ documents: [DocumentRef],
        dates: [String: String],
        volumeEarliest: String?
    ) -> [DocumentRef] {
        documents.sorted {
            let a = sortKey(dateISO: dates[$0.key], volumeEarliest: volumeEarliest)
            let b = sortKey(dateISO: dates[$1.key], volumeEarliest: volumeEarliest)
            if a != b { return a < b }
            return $0.documentId < $1.documentId
        }
    }

    /// The R-3 action decider: what a row can do, from its VOLUME's device state.
    ///
    /// - Parameters:
    ///   - volumeIndexed: Whether the volume is indexed here.
    ///   - volumeDownloaded: Whether the volume's XML is on disk.
    /// - Returns: The row state.
    static func rowState(volumeIndexed: Bool, volumeDownloaded: Bool) -> RowState {
        if volumeIndexed { return .open }
        return volumeDownloaded ? .needsIndex : .needsDownload
    }
}

// MARK: - CorporaIndexView

/// The Working Corpora level (#1051 B-4, design 1i): the user's captured document sets,
/// newest first — list and open, never create (the capture surfaces are Search results
/// and the semantic map's lasso, and the footer says so).
///
/// Shared across both platforms behind one `onOpen` closure.
///
/// Version history:
///   1.0 — #1051 B-4: initial implementation
struct CorporaIndexView: View {

    /// Opens a corpus's document drill.
    let onOpen: @MainActor (UUID, String) -> Void

    @Query(sort: \WorkingCorpus.capturedAt, order: .reverse)
    private var corpora: [WorkingCorpus]

    var body: some View {
        List {
            if corpora.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "browser.corpora.empty.title",
                               defaultValue: "No Working Corpora"),
                        systemImage: "tray.full",
                        description: Text(String(
                            localized: "browser.corpora.empty.detail",
                            defaultValue: "A working corpus is a fixed set of documents captured from a result set — use “Save as Working Corpus” on Search results or the semantic map’s lasso."))
                    )
                }
            } else {
                Section {
                    ForEach(corpora) { corpus in
                        row(corpus)
                    }
                } footer: {
                    Text(String(localized: "browser.corpora.footer",
                                defaultValue: "A corpus is captured from a result set — in Search results or with the semantic map’s lasso — and syncs via iCloud. There is nothing to create here."))
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "browser.corpora.title", defaultValue: "Working Corpora"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func row(_ corpus: WorkingCorpus) -> some View {
        Button {
            onOpen(corpus.id, CorporaAxis.displayName(corpus))
            #if DEBUG
            print("[CorporaIndexView] Navigate → corpus \(corpus.id)")
            #endif
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(CorporaAxis.displayName(corpus))
                    .font(.body)
                Text(CorporaAxis.rowCaption(corpus))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let line = CorporaAxis.truncationLine(corpus.truncationAtCapture,
                                                        documentCount: corpus.documentCount) {
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(corpus.truncationAtCapture == .unrecorded
                                         ? Color.secondary : Color.orange)
                }
            }
            // Both modifiers, in this order — the #312 full-row tap-target idiom.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(localized: "browser.corpora.row.a11y",
                   defaultValue: "\(CorporaAxis.displayName(corpus)), \(corpus.documentCount) documents")
        )
        .help(String(localized: "browser.corpora.row.help",
                     defaultValue: "Browse this corpus’s documents, grouped by volume"))
    }
}

// MARK: - CorpusDocumentsView

/// A working corpus's document drill (#1051 B-4) — **Browse's first degraded-row
/// surface**, importing the Collections/semantic-map precedent deliberately rather than
/// Browse's own volume-level gate: the list ALWAYS renders, coverage is stated once at
/// the top, and only the ACTIONS gate (Open needs the volume indexed; a missing volume's
/// affordance is Download or Index, never a dead end).
///
/// Display metadata comes from the BULK paths (`CrossReferenceStore.documentHeaders` +
/// `IndexingPipeline.datesByDocumentKey`, both internally chunked since Session 129) — a
/// corpus can hold 7,500 keys and per-key queries were rejected at that scale. Headers
/// are display sugar, never a coverage oracle: editorial notes are indexed-but-headerless,
/// so openability follows VOLUME membership (`WorkingCorpusResolver`'s rule).
///
/// Version history:
///   1.0 — #1051 B-4: initial implementation
struct CorpusDocumentsView: View {

    /// The corpus under browse, resolved live (a deletion elsewhere becomes the explicit
    /// unavailable state, not a stale list).
    let corpusId: UUID
    /// Opens an indexed document — iOS pushes `.document`, macOS routes through the
    /// corpus browser's document host. A metadata-less entry is an accepted navigation
    /// payload (the semantic map's precedent): the reader parses TEI.
    let onOpenDocument: @MainActor (DocumentBrowserEntry) -> Void

    @Query private var corpora: [WorkingCorpus]
    @Environment(AppState.self) private var appState

    /// Bulk-loaded display metadata, keyed by `"volumeId/documentId"`.
    @State private var headers: [String: String] = [:]
    @State private var dates: [String: String] = [:]
    /// The engagement partition behind the row badges and the coverage line (W-13). `nil` until
    /// the first gather lands; the list renders unbadged in the meantime rather than blocking.
    @State private var coverage: EngagementCoverage?
    /// Bumped by ``EngagementObserver`` whenever a visit, note, highlight or collection lands, so
    /// the gather re-runs. Navigation edges cannot do this job — opening a document from this very
    /// list is the case they miss.
    @State private var engagementRevision = 0
    @Environment(\.modelContext) private var modelContext

    init(corpusId: UUID, onOpenDocument: @escaping @MainActor (DocumentBrowserEntry) -> Void) {
        self.corpusId = corpusId
        self.onOpenDocument = onOpenDocument
        _corpora = Query(filter: #Predicate<WorkingCorpus> { $0.id == corpusId })
    }

    private var corpus: WorkingCorpus? { corpora.first }

    var body: some View {
        Group {
            if let corpus {
                documentList(for: corpus)
            } else {
                ContentUnavailableView(
                    String(localized: "browser.corpora.unavailable.title",
                           defaultValue: "Corpus Unavailable"),
                    systemImage: "tray.full",
                    description: Text(String(
                        localized: "browser.corpora.unavailable.detail",
                        defaultValue: "This corpus no longer exists — it may have been deleted on another device."))
                )
            }
        }
        .navigationTitle(corpus.map(CorporaAxis.displayName)
                         ?? String(localized: "browser.corpora.title.fallback",
                                   defaultValue: "Corpus"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Re-keyed on the indexed-volume count so finishing an index pass upgrades the
        // degraded rows without navigating away.
        .task(id: "\(corpusId)-\(appState.indexedVolumeIds.count)") {
            await loadMetadata()
        }
        // Re-keyed on the active project (the scope of every count) and on the observer's
        // revision (any new visit, note, highlight or collection).
        .task(id: "\(corpusId)-\(appState.activeProjectId?.uuidString ?? "-")-\(engagementRevision)") {
            await loadCoverage()
        }
        .background {
            EngagementObserver { engagementRevision = $0 }
        }
    }

    @ViewBuilder
    private func documentList(for corpus: WorkingCorpus) -> some View {
        let resolution = WorkingCorpusResolver(indexedVolumeIds: appState.indexedVolumeIds)
            .resolve(corpus)
        List {
            // Coverage ONCE at the top, in the resolver's own vocabulary — orange while
            // incomplete (the WorkingCorporaView precedent). The list below never blocks.
            Section {
                Text(resolution.coverageDescription)
                    .font(.caption)
                    .foregroundStyle(resolution.isComplete ? Color.secondary : Color.orange)
                if let coverage {
                    // The sibling sentence: how much of the corpus has been worked on, in the
                    // same place and the same voice as how much of it this device can reach.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(coverage.coverageDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let breakdown = coverage.breakdownDescription {
                            Text(breakdown)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if let caveat = coverage.loggingCaveat {
                            Text(caveat)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            ForEach(CorporaAxis.volumeSections(from: corpus.documentKeys)) { section in
                volumeSection(section)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    @ViewBuilder
    private func volumeSection(_ section: CorporaAxis.VolumeSection) -> some View {
        let entry = appState.manifestStore.entry(forVolumeId: section.volumeId)
        let state = CorporaAxis.rowState(
            volumeIndexed: appState.indexedVolumeIds.contains(section.volumeId),
            volumeDownloaded: appState.downloadManager?.isVolumeDownloaded(section.volumeId) ?? false
        )
        // Reading the queue in body keeps the capsule live while a download runs.
        let isDownloading = appState.downloadQueue.contains(section.volumeId)
        Section(entry?.title ?? section.volumeId) {
            ForEach(CorporaAxis.ordered(section.documents, dates: dates,
                                        volumeEarliest: entry?.dateRange.earliest)) { ref in
                documentRow(ref, state: state, entry: entry, isDownloading: isDownloading,
                            engagement: coverage?.state(for: ref.key) ?? .untouched)
            }
        }
    }

    @ViewBuilder
    private func documentRow(_ ref: CorporaAxis.DocumentRef,
                             state: CorporaAxis.RowState,
                             entry: VolumeManifestEntry?,
                             isDownloading: Bool,
                             engagement: DocumentEngagement.State) -> some View {
        switch state {
        case .open:
            Button {
                onOpenDocument(DocumentBrowserEntry(
                    documentId: ref.documentId,
                    volumeId: ref.volumeId,
                    documentNumber: nil,
                    header: headers[ref.key] ?? ref.documentId,
                    dateline: nil,
                    sourceNote: nil
                ))
                #if DEBUG
                print("[CorpusDocumentsView] Open \(ref.key)")
                #endif
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headers[ref.key] ?? ref.documentId)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        if let date = dates[ref.key] {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    // Both modifiers, in this order — the #312 full-row tap-target idiom.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    engagementBadge(engagement)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .needsIndex, .needsDownload:
            // The degraded row: gray ids, and the affordance — never a dead end.
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ref.volumeId) · \(ref.documentId)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "browser.corpora.row.notIndexed",
                                defaultValue: "Not indexed on this device"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                engagementBadge(engagement)
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else if state == .needsDownload {
                    Button {
                        if let entry, let dm = appState.downloadManager {
                            Task { await dm.enqueueDownload(entry) }
                        }
                    } label: {
                        Text(String(localized: "browser.corpora.download",
                                    defaultValue: "Download"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(entry?.downloadUrl == nil || appState.downloadManager == nil)
                    .help(String(localized: "browser.corpora.download.help",
                                 defaultValue: "Download this volume to open its documents"))
                } else {
                    Button {
                        if let pipeline = appState.indexingPipeline {
                            Task { try? await pipeline.indexVolume(ref.volumeId) }
                        }
                    } label: {
                        Text(String(localized: "browser.corpora.index", defaultValue: "Index"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.indexingPipeline == nil)
                    .help(String(localized: "browser.corpora.index.help",
                                 defaultValue: "Index this downloaded volume to open its documents"))
                }
            }
        }
    }

    /// The row badge — an icon only, and nothing at all for an untouched document.
    ///
    /// A systematic review is mostly untouched rows; marking each of them would put a glyph on
    /// every line and make the worked-on ones harder to pick out, which is the opposite of the job.
    /// The label is carried for VoiceOver, which has no absence to perceive.
    ///
    /// - Parameter engagement: The strongest engagement recorded against this document.
    @ViewBuilder
    private func engagementBadge(_ engagement: DocumentEngagement.State) -> some View {
        if let symbol = engagement.symbolName {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(engagement == .annotated ? Color.accentColor : Color.secondary)
                .accessibilityLabel(engagement.label)
        }
    }

    /// Partitions the corpus by engagement, off the main actor.
    ///
    /// Scoped to the active project when there is one, and to the whole device when there is not —
    /// "have I read this" is worth answering for a reader who has never made a project.
    private func loadCoverage() async {
        guard let corpus else { return }
        let keys = corpus.documentKeys
        guard !keys.isEmpty else {
            coverage = nil
            return
        }
        coverage = await DocumentEngagementService.coverage(
            forCorpusKeys: keys,
            project: appState.activeProjectId,
            container: modelContext.container
        )
        #if DEBUG
        print("[CorpusDocumentsView] Coverage: \(coverage?.engagedCount ?? 0) of \(keys.count) worked on")
        #endif
    }

    /// The bulk metadata load — one chunked call per store, never per-key queries.
    private func loadMetadata() async {
        guard let corpus else { return }
        let keys = CorporaAxis.volumeSections(from: corpus.documentKeys)
            .flatMap(\.documents)
            .map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        guard !keys.isEmpty else { return }
        if let store = appState.crossReferenceStore,
           let loaded = try? await store.documentHeaders(for: keys) {
            headers = loaded
        }
        if let pipeline = appState.indexingPipeline,
           let loaded = try? await pipeline.datesByDocumentKey(keys) {
            dates = loaded
        }
        #if DEBUG
        print("[CorpusDocumentsView] Loaded \(headers.count) headers, \(dates.count) dates for \(keys.count) keys")
        #endif
    }
}

// MARK: - EngagementObserver

/// A hidden, always-mounted `@Query` observer that tells `CorpusDocumentsView` when to re-gather
/// its coverage (W-13 session 1).
///
/// ## Why an observer and not a navigation trigger
/// The change this must catch is *the reader opened a document from this list, read it, annotated
/// it and came back*. `navigationPath` and `scenePhase` both miss it — a pushed detail leaves this
/// view mounted and the scene continuously active, and on iPad the document may open in a sibling
/// window that touches neither. `@Query` observes the shared `ModelContainer`, so it fires
/// whichever route the write came from.
///
/// ## What it costs, stated rather than hidden
/// Four unfiltered queries are live while the list is on screen, so all four tables are faulted in.
/// That is the price of the guarantee, and it buys only a **revision counter** — the rows
/// themselves are never read. The token is built from counts, which catches every insert and
/// delete; re-tagging an existing note into a different project while this list is open is the one
/// change it will miss.
///
/// Version history:
///   1.0 — W-13 session 1: initial implementation
private struct EngagementObserver: View {

    /// Called with a monotonic revision whenever any observed table changes size.
    private let onRevision: (Int) -> Void

    @Query private var visits: [ReadingHistoryEntry]
    @Query private var notes: [ResearchNote]
    @Query private var highlights: [DocumentHighlight]
    @Query private var collections: [Collection]

    /// Creates the observer.
    ///
    /// - Parameter onRevision: Receives the revision token.
    init(onRevision: @escaping (Int) -> Void) {
        self.onRevision = onRevision
    }

    /// The change signal. Not an identity — only its *inequality* is used.
    private var revision: Int {
        var hasher = Hasher()
        hasher.combine(visits.count)
        hasher.combine(notes.count)
        hasher.combine(highlights.count)
        hasher.combine(collections.count)
        return hasher.finalize()
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear { onRevision(revision) }
            .onChange(of: revision) { _, new in onRevision(new) }
    }
}

// MARK: - iOS mounts

#if os(iOS)

/// The iOS mount of the Working Corpora level (`BrowserLevel.corpora`).
///
/// Version history:
///   1.0 — #1051 B-4: initial implementation
struct BrowseCorporaLevel: View {
    let vm: BrowserViewModel

    var body: some View {
        CorporaIndexView(onOpen: { [vm] id, name in
            vm.navigationPath.append(.corpusDocuments(id: id, name: name))
        })
    }
}

/// The iOS mount of a corpus's document drill (`BrowserLevel.corpusDocuments`) — indexed
/// rows push `.document` in the Browse stack.
///
/// Version history:
///   1.0 — #1051 B-4: initial implementation
struct BrowseCorpusDocumentsLevel: View {
    let vm: BrowserViewModel
    let corpusId: UUID

    var body: some View {
        CorpusDocumentsView(corpusId: corpusId, onOpenDocument: { [vm] entry in
            vm.navigationPath.append(.document(entry))
        })
    }
}

#endif // os(iOS)
