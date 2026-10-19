// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SemanticSearchFallbackView

/// The zero-result semantic fallback (V-5 s3) — the narrow first surface the judged sitting
/// itself recommended: when the KEYWORD search returns nothing, offer the one route that
/// answers natural-language questions. Rescued 4 of the sitting's 25 queries.
///
/// SHARED by both platforms' search surfaces, the `QueryZeroResultView` precedent, and mounted
/// ONLY in Keywords mode: the Meaning mode (V-5 hybrid page) runs the semantic route as the
/// primary engine through the view models, and mounting this beside it would run every query
/// twice. The offer card, score chip, and beyond-library row are the shared views in
/// `SemanticSearchSharedViews.swift`, so this surface and the Meaning mode cannot drift on copy.
///
/// Version history:
///   1.0 — V-5 s3
///   1.1 — V-5 hybrid page: offer/consent/row internals extracted to the shared views
///   1.2 — Session 2026-09-30: #1527 — the unscored sentences come from `SemanticUnscoredCopy`,
///         with the count of volumes whose match files are really downloading
///   1.3 — Session 2026-09-30, review round 1: #1527 — that count is the searcher's own,
///         `Results.downloadingVolumes`, rather than an ask count gated on the switch at caption time
///   1.4 — 2026-10-19: #1685 — the phase machine is `SemanticFallbackSearch`, whose runs write only while they are
///         the view's, and the offer card's search runs in the view's one task, keyed on the host's search and on
///         the card's requests, where it ran in a `Task` nothing cancelled
struct SemanticSearchFallbackView: View {

    /// The executed query, verbatim (the submitted one, never the live field).
    let query: String
    /// The host's executed-search version — the re-run trigger.
    let searchVersion: Int
    /// Whether the host's search had active filters, so the caption can say they were ignored.
    let hasActiveFilters: Bool
    /// Opens a document the reader holds — each platform routes its own way.
    let openEntry: (DocumentBrowserEntry) -> Void

    @Environment(AppState.self) private var appState

    /// What the surface shows, and the runs that decide it (#1685).
    @State private var search = SemanticFallbackSearch()

    /// How many times the offer card has asked for the search since the model came down: part of the key of the
    /// view's one task, so the card's search runs in that task, and is cancelled with it when the host's search
    /// changes or the view goes away.
    @State private var offerRequests = 0

    /// What the view's one task is keyed on.
    private struct RunKey: Equatable {
        /// The host's executed-search version.
        let searchVersion: Int
        /// The offer card's requests.
        let offerRequests: Int
    }

    var body: some View {
        // A VStack, not a Group, and the distinction is a recorded trap: Group applies
        // modifiers PER CHILD, so with `.hidden` rendering an EmptyView the `.task` below
        // would attach to that EmptyView and never fire — the phase machine would be stuck
        // at `.hidden` forever. The VStack is a real container; its task always runs.
        VStack(spacing: 0) {
            switch search.phase {
            case .hidden:
                EmptyView()
            case .offer:
                SemanticModelOfferCard {
                    offerRequests += 1
                }
            case .searching:
                searchingRow
            case .results(let hits, let unscored, let unscoredVolumes, let downloadingVolumes):
                resultsSection(hits, unscored: unscored, unscoredVolumes: unscoredVolumes,
                               downloadingVolumes: downloadingVolumes)
            case .empty(let unscoredVolumes, let downloadingVolumes):
                emptyCard(unscoredVolumes: unscoredVolumes, downloadingVolumes: downloadingVolumes)
            case .failed(let message):
                failedRow(message)
            }
        }
        .task(id: RunKey(searchVersion: searchVersion, offerRequests: offerRequests)) {
            await search.enter(query: query, engine: engine)
        }
    }

    // MARK: - What a run asks of the app

    /// The model's status, the search and the lookup of its hits, or `nil` while the semantic stack is absent.
    private var engine: SemanticFallbackSearch.Engine? {
        guard let searcher = appState.semanticQuerySearcher else { return nil }
        return SemanticFallbackSearch.Engine(
            modelStatus: { await appState.semanticModelStatus() },
            search: { query in try await searcher.search(query) },
            resolve: { hits in await resolve(hits) })
    }

    /// Resolves hits for display: indexed documents get their own header from `document_cache`
    /// (the `candidateRecords` fence, used here as a LOOKUP rather than a fence); the rest get
    /// their volume's manifest title and the not-downloaded treatment.
    private func resolve(_ hits: [SemanticQuerySearcher.Hit]) async -> [SemanticFallbackSearch.ResolvedHit] {
        let indexed = appState.indexedVolumeIds
        let keys = hits.filter { indexed.contains($0.volumeID) }
            .map { DocumentKey(volumeId: $0.volumeID, documentId: $0.documentID) }
        let records = (try? await appState.indexingPipeline?
            .candidateRecords(forKeys: keys)) ?? [:]
        return hits.map { hit in
            let record = records[DocumentKey(volumeId: hit.volumeID, documentId: hit.documentID)]
            let entry = appState.manifestStore.entry(forVolumeId: hit.volumeID)
            return SemanticFallbackSearch.ResolvedHit(
                volumeID: hit.volumeID,
                documentID: hit.documentID,
                score: hit.score,
                header: record?.header,
                dateline: record?.dateline,
                documentNumber: record?.documentNumber,
                isEditorialNote: record?.isEditorialNote ?? false,
                volumeTitle: entry?.title ?? hit.volumeID,
                isOpenable: record != nil,
                isDownloadable: entry?.downloadUrl != nil)
        }
    }

    // MARK: - Cards

    private var searchingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(String(localized: "search.semantic.searching",
                        defaultValue: "Searching by meaning…"))
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Zero scorable hits: name the warm-up, never claim absence.
    private func emptyCard(unscoredVolumes: Int, downloadingVolumes: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(localized: "search.semantic.empty.title",
                         defaultValue: "No semantic matches yet"),
                  systemImage: SemanticGlyph.feature)
                .font(.headline)
            Text(unscoredVolumes > 0
                ? SemanticUnscoredCopy.warming(volumes: unscoredVolumes, downloading: downloadingVolumes)
                : String(localized: "search.semantic.empty.none",
                         defaultValue: "Nothing in the scorable corpus reads close to this search."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func failedRow(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Results

    private func resultsSection(
        _ hits: [SemanticFallbackSearch.ResolvedHit], unscored: Int, unscoredVolumes: Int, downloadingVolumes: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "search.semantic.results.title",
                         defaultValue: "Semantic matches (experimental)"),
                  systemImage: SemanticGlyph.feature)
                .font(.headline)
            Text(disclosureCaption(unscored: unscored, unscoredVolumes: unscoredVolumes,
                                   downloadingVolumes: downloadingVolumes))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(hits) { hit in
                hitRow(hit)
                Divider()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The honesty block: meaning-based, filter-blind, and what was dropped.
    private func disclosureCaption(unscored: Int, unscoredVolumes: Int,
                                   downloadingVolumes: Int) -> String {
        var parts: [String] = [String(
            localized: "search.semantic.results.caption",
            defaultValue: "Ranked by meaning, not keywords, across the whole series — your exact words may not appear.")]
        if hasActiveFilters {
            parts.append(String(localized: "search.semantic.results.filters",
                                defaultValue: "Your filters are not applied here."))
        }
        if unscored > 0 {
            parts.append(SemanticUnscoredCopy.unscored(
                candidates: unscored, volumes: unscoredVolumes, downloading: downloadingVolumes))
        }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private func hitRow(_ hit: SemanticFallbackSearch.ResolvedHit) -> some View {
        if hit.isOpenable {
            Button {
                openEntry(DocumentBrowserEntry(
                    documentId: hit.documentID,
                    volumeId: hit.volumeID,
                    documentNumber: hit.documentNumber,
                    header: hit.header ?? hit.documentID,
                    dateline: hit.dateline,
                    sourceNote: nil,
                    isEditorialNote: hit.isEditorialNote))
            } label: {
                openableRowLabel(hit)
            }
            .buttonStyle(.plain)
        } else {
            SemanticUndownloadedRow(
                volumeID: hit.volumeID,
                documentID: hit.documentID,
                score: hit.score,
                volumeTitle: hit.volumeTitle,
                isDownloadable: hit.isDownloadable)
        }
    }

    private func openableRowLabel(_ hit: SemanticFallbackSearch.ResolvedHit) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(hit.header ?? hit.documentID)
                .font(.callout)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                if let dateline = hit.dateline {
                    Text(dateline).font(.caption).foregroundStyle(.secondary)
                }
                Text(hit.volumeTitle).font(.caption).foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            SemanticScoreChip(score: hit.score)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - SemanticFallbackSearch

/// The zero-result offer's state machine, apart from its view so that its runs can be driven (#1685).
///
/// `SemanticSearchFallbackView` stays mounted from one zero-result keyword search to the next, and its search runs in
/// the view's task, which a new search replaces. Cancelling that task did not stop the run: the search across the
/// series it runs, `SemanticQuerySearcher.search(_:limit:)`, checks for cancellation nowhere (a search inside a set
/// does, between its steps), and the run wrote ``phase`` after its waits whatever had happened meanwhile. So
/// after two zero-result searches in a row the first one's matches could land under the second, whichever finished
/// last writing the card — the shape #1648 fixed in the two search view models, here in a view of its own. And the
/// offer card's button started a `Task` of its own that nothing cancelled at all.
///
/// Each run now takes a number as it starts, from a `SearchRunLedger`, the view models' rule, and after each of its
/// waits asks whether it is still the latest run, and still not cancelled, before it writes anything. A run a later
/// search replaced writes nothing, nor does one whose view has gone away.
///
/// Version history:
///   1.0 — #1685: the phase machine of `SemanticSearchFallbackView` 1.3, with the runs' check
@MainActor
@Observable
final class SemanticFallbackSearch {

    /// What the surface is currently showing.
    enum Phase: Equatable {
        /// Nothing to show (semantic stack absent, or no query).
        case hidden
        /// The model is not downloaded; the shared offer card is up (it owns consent,
        /// progress, and failure internally).
        case offer
        /// The semantic search is running.
        case searching
        /// Ranked hits, resolved for display.
        case results([ResolvedHit], unscored: Int, unscoredVolumes: Int, downloadingVolumes: Int)
        /// The search ran and nothing was scorable.
        case empty(unscoredVolumes: Int, downloadingVolumes: Int)
        /// The search failed, in words.
        case failed(String)
    }

    /// One hit, resolved against the index (openable) or the manifest (not downloaded).
    struct ResolvedHit: Equatable, Identifiable {
        let volumeID: String
        let documentID: String
        let score: Double
        /// The document's own header when this device has it indexed; `nil` otherwise.
        let header: String?
        let dateline: String?
        let documentNumber: String?
        let isEditorialNote: Bool
        /// The volume's manifest title — always available, the not-downloaded row's headline.
        let volumeTitle: String
        /// Whether the reader can open it here (indexed = downloaded and rendered).
        let isOpenable: Bool
        /// Whether the manifest carries a download URL (side-loaded volumes do not).
        let isDownloadable: Bool
        var id: String { "\(volumeID)/\(documentID)" }
    }

    /// What a run asks of the app: the view builds it from `AppState`, and a test stands in for each part.
    struct Engine {
        /// The encoder model's status: whether the semantic stack booted, and whether the model is on disk.
        var modelStatus: @MainActor () async -> AppState.SemanticModelStatus
        /// The search itself, `SemanticQuerySearcher.search(_:limit:)`.
        var search: @MainActor (String) async throws -> SemanticQuerySearcher.Results
        /// The hits, resolved against the index and the manifest for display.
        var resolve: @MainActor ([SemanticQuerySearcher.Hit]) async -> [ResolvedHit]
    }

    /// What the surface shows.
    private(set) var phase: Phase = .hidden

    /// The runs started, numbered, so that a run another one replaced writes nothing.
    @ObservationIgnored private var runs = SearchRunLedger()

    /// Decides the phase for an executed search, and runs the search when it can. Each call is a new run, which
    /// replaces any still under way.
    ///
    /// - Parameters:
    ///   - query: The executed query, verbatim.
    ///   - engine: What the run asks of the app, or `nil` while the semantic stack is absent.
    func enter(query: String, engine: Engine?) async {
        let run = runs.startRun()
        guard let engine, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            phase = .hidden
            return
        }
        let status = await engine.modelStatus()
        guard isCurrent(run) else { return }
        guard status.isAvailable else {
            phase = .hidden
            return
        }
        guard status.isPresent else {
            phase = .offer
            return
        }
        await runSearch(query: query, engine: engine, run: run)
    }

    /// Runs the search for `run`, and writes its outcome only while `run` is still the latest.
    private func runSearch(query: String, engine: Engine, run: Int) async {
        phase = .searching
        do {
            let results = try await engine.search(query)
            guard isCurrent(run) else { return }
            let resolved = await engine.resolve(results.hits)
            guard isCurrent(run) else { return }
            // The searcher counts a volume as downloading only when its fetch request said a
            // download is under way (#1527).
            let downloading = results.downloadingVolumes
            if resolved.isEmpty {
                phase = .empty(unscoredVolumes: results.unscoredVolumes,
                               downloadingVolumes: downloading)
            } else {
                phase = .results(resolved, unscored: results.unscoredCandidates,
                                 unscoredVolumes: results.unscoredVolumes,
                                 downloadingVolumes: downloading)
            }
        } catch SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded {
            guard isCurrent(run) else { return }
            phase = .offer
        } catch SemanticQuerySearcher.SearchUnavailable.queryTooLong {
            guard isCurrent(run) else { return }
            phase = .failed(String(
                localized: "search.semantic.tooLong",
                defaultValue: "This search is too long for the model. Try a shorter phrasing."))
        } catch {
            guard isCurrent(run) else { return }
            phase = .failed(String(
                localized: "search.semantic.failed",
                defaultValue: "Semantic search could not run. Try again."))
        }
    }

    /// Whether `run` may still write: no later run has started, and its task has not been cancelled, which SwiftUI
    /// does to the view's task when the host's search changes and when the view goes away.
    private func isCurrent(_ run: Int) -> Bool {
        runs.isLatest(run) && !Task.isCancelled
    }
}
