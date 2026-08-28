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
/// itself recommended: when the lexical expression returns nothing, offer the one route that
/// answers natural-language questions. Rescued 4 of the sitting's 25 queries outright.
///
/// SHARED by both platforms' search surfaces, the `QueryZeroResultView` precedent: iOS mounts it
/// under the zero-result branch of `SearchView.resultsSection`, macOS under `SearchSheet`'s
/// `hasZeroResults` branch. Each host passes its own document-opening closure; everything else —
/// states, copy, rows — lives here once.
///
/// ## What each state claims
///
/// - Model absent: an OFFER, not a download — the button opens the same consent sheet the
///   Settings section uses (`SemanticModelConsentSheet`), because the sheet's sentence is the
///   Gemma flow-down and no path may download around it.
/// - Results: corpus-wide, deliberately unfenced (unlike the Related axis) — a hit in a volume
///   the reader lacks is shown with its manifest title and a download affordance, the
///   cross-reference graph's #262 presentation. The caption owns two disclosures: filters are
///   ignored, and candidates without shards were dropped (with the count), never silently.
/// - Empty: names the warm-up honestly — the match files are downloading, try again — rather
///   than claiming the corpus holds nothing.
///
/// Version history:
///   1.0 — V-5 s3
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

    /// What the surface is currently showing.
    private enum Phase: Equatable {
        /// Nothing to show (semantic stack absent, or no query).
        case hidden
        /// The model is not downloaded; the offer card is up.
        case offer
        /// The model download is running (progress read from `appState.semanticModelDownload`).
        case downloading
        /// The semantic search is running.
        case searching
        /// Ranked hits, resolved for display.
        case results([ResolvedHit], unscored: Int, unscoredVolumes: Int)
        /// The search ran and nothing was scorable.
        case empty(unscoredVolumes: Int)
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
        var id: String { "\(volumeID)/\(documentID)" }
    }

    @State private var phase: Phase = .hidden
    @State private var showingConsent = false
    /// Volumes whose download this surface has queued, for the queued-state button.
    @State private var requestedVolumeDownloads: Set<String> = []

    var body: some View {
        // A VStack, not a Group, and the distinction is a recorded trap: Group applies
        // modifiers PER CHILD, so with `.hidden` rendering an EmptyView the `.task` below
        // would attach to that EmptyView and never fire — the phase machine would be stuck
        // at `.hidden` forever. The VStack is a real container; its task always runs.
        VStack(spacing: 0) {
            switch phase {
            case .hidden:
                EmptyView()
            case .offer:
                offerCard
            case .downloading:
                downloadingCard
            case .searching:
                searchingRow
            case .results(let hits, let unscored, let unscoredVolumes):
                resultsSection(hits, unscored: unscored, unscoredVolumes: unscoredVolumes)
            case .empty(let unscoredVolumes):
                emptyCard(unscoredVolumes: unscoredVolumes)
            case .failed(let message):
                failedRow(message)
            }
        }
        .task(id: searchVersion) { await enter() }
        .sheet(isPresented: $showingConsent) {
            SemanticModelConsentSheet {
                showingConsent = false
                Task { await downloadModelThenSearch() }
            } onCancel: {
                showingConsent = false
            }
        }
    }

    // MARK: - State machine

    /// Decides the initial phase for this executed search, and runs the search when it can.
    private func enter() async {
        requestedVolumeDownloads = []
        guard appState.semanticQuerySearcher != nil,
              !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            phase = .hidden
            return
        }
        let status = await appState.semanticModelStatus()
        guard status.isAvailable else {
            phase = .hidden
            return
        }
        guard status.isPresent else {
            phase = appState.semanticModelDownload != nil ? .downloading : .offer
            return
        }
        await runSearch()
    }

    /// The consent sheet said yes: download, then — if the file verified — search immediately,
    /// so the reader's question is answered by the same gesture that fetched the tool.
    private func downloadModelThenSearch() async {
        phase = .downloading
        await appState.downloadSemanticModel()
        let status = await appState.semanticModelStatus()
        if status.isPresent {
            await runSearch()
        } else {
            phase = .failed(status.failure ?? String(
                localized: "search.semantic.downloadFailed",
                defaultValue: "The model could not be downloaded. You can try again from the button above, or from Settings."))
        }
    }

    private func runSearch() async {
        guard let searcher = appState.semanticQuerySearcher else {
            phase = .hidden
            return
        }
        phase = .searching
        do {
            let results = try await searcher.search(query)
            let resolved = await resolve(results.hits)
            if resolved.isEmpty {
                phase = .empty(unscoredVolumes: results.unscoredVolumes)
            } else {
                phase = .results(resolved, unscored: results.unscoredCandidates,
                                 unscoredVolumes: results.unscoredVolumes)
            }
        } catch SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded {
            phase = .offer
        } catch SemanticQuerySearcher.SearchUnavailable.queryTooLong {
            phase = .failed(String(
                localized: "search.semantic.tooLong",
                defaultValue: "This search is too long for the model. Try a shorter phrasing."))
        } catch {
            phase = .failed(String(
                localized: "search.semantic.failed",
                defaultValue: "Semantic search could not run. Try again."))
        }
    }

    /// Resolves hits for display: indexed documents get their own header from `document_cache`
    /// (the `candidateRecords` fence, used here as a LOOKUP rather than a fence); the rest get
    /// their volume's manifest title and the not-downloaded treatment.
    private func resolve(_ hits: [SemanticQuerySearcher.Hit]) async -> [ResolvedHit] {
        let indexed = appState.indexedVolumeIds
        let keys = hits.filter { indexed.contains($0.volumeID) }
            .map { DocumentKey(volumeId: $0.volumeID, documentId: $0.documentID) }
        let records = (try? await appState.indexingPipeline?
            .candidateRecords(forKeys: keys)) ?? [:]
        return hits.map { hit in
            let record = records[DocumentKey(volumeId: hit.volumeID, documentId: hit.documentID)]
            let volumeTitle = appState.manifestStore.entry(forVolumeId: hit.volumeID)?.title
                ?? hit.volumeID
            return ResolvedHit(
                volumeID: hit.volumeID,
                documentID: hit.documentID,
                score: hit.score,
                header: record?.header,
                dateline: record?.dateline,
                documentNumber: record?.documentNumber,
                isEditorialNote: record?.isEditorialNote ?? false,
                volumeTitle: volumeTitle,
                isOpenable: record != nil)
        }
    }

    // MARK: - Cards

    /// The offer: what the button does, what it costs, and that a sheet will ask properly.
    private var offerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "search.semantic.offer.title",
                         defaultValue: "Search by meaning (experimental)"),
                  systemImage: SemanticGlyph.feature)
                .font(.headline)
            Text(String(
                localized: "search.semantic.offer.body",
                defaultValue: "Keyword search found nothing, but the app can also search by what a question means — including questions whose words never appear in the documents. This needs a one-time 229 MB model download that runs entirely on this device."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showingConsent = true
            } label: {
                Text(String(localized: "search.semantic.offer.button",
                            defaultValue: "Download Search Model…"))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.isOnline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    /// Byte progress, mirrored from the Settings section's source of truth.
    private var downloadingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let progress = appState.semanticModelDownload {
                ProgressView(value: progress.fraction) {
                    Text(String(localized: "search.semantic.downloading",
                                defaultValue: "Downloading the search model…"))
                }
            } else {
                ProgressView {
                    Text(String(localized: "search.semantic.verifying",
                                defaultValue: "Verifying the search model…"))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
    private func emptyCard(unscoredVolumes: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(localized: "search.semantic.empty.title",
                         defaultValue: "No semantic matches yet"),
                  systemImage: SemanticGlyph.feature)
                .font(.headline)
            Text(unscoredVolumes > 0
                ? String(format: String(
                    localized: "search.semantic.empty.warming %lld",
                    defaultValue: "Match files for %lld volumes are still downloading in the background. Searching again in a moment may find more."),
                    Int64(unscoredVolumes))
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
        _ hits: [ResolvedHit], unscored: Int, unscoredVolumes: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "search.semantic.results.title",
                         defaultValue: "Semantic matches (experimental)"),
                  systemImage: SemanticGlyph.feature)
                .font(.headline)
            Text(disclosureCaption(unscored: unscored, unscoredVolumes: unscoredVolumes))
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
    private func disclosureCaption(unscored: Int, unscoredVolumes: Int) -> String {
        var parts: [String] = [String(
            localized: "search.semantic.results.caption",
            defaultValue: "Ranked by meaning, not keywords, across the whole series — your exact words may not appear.")]
        if hasActiveFilters {
            parts.append(String(localized: "search.semantic.results.filters",
                                defaultValue: "Your filters are not applied here."))
        }
        if unscored > 0 {
            parts.append(String(format: String(
                localized: "search.semantic.results.unscored %lld %lld",
                defaultValue: "%lld possible matches in %lld volumes could not be scored yet; their match files are downloading."),
                Int64(unscored), Int64(unscoredVolumes)))
        }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private func hitRow(_ hit: ResolvedHit) -> some View {
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
            undownloadedRow(hit)
        }
    }

    private func openableRowLabel(_ hit: ResolvedHit) -> some View {
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
            scoreChip(hit.score)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The #262 presentation: the volume's title, the document's id, no invented metadata, and
    /// the way to get it.
    private func undownloadedRow(_ hit: ResolvedHit) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(format: String(
                localized: "search.semantic.row.undownloaded %@ %@",
                defaultValue: "Document %1$@ in %2$@"),
                hit.documentID, hit.volumeTitle))
                .font(.callout)
                .multilineTextAlignment(.leading)
            Text(String(localized: "search.semantic.row.notDownloaded",
                        defaultValue: "Volume not downloaded — its documents are shown without titles until you download it."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                scoreChip(hit.score)
                if requestedVolumeDownloads.contains(hit.volumeID) {
                    Text(String(localized: "search.semantic.row.downloadQueued",
                                defaultValue: "Download queued"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if appState.manifestStore.entry(forVolumeId: hit.volumeID)?.downloadUrl != nil {
                    Button {
                        queueVolumeDownload(hit.volumeID)
                    } label: {
                        Text(String(localized: "search.semantic.row.download",
                                    defaultValue: "Download Volume"))
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!appState.isOnline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The axis's score presentation, in this surface's own key.
    private func scoreChip(_ score: Double) -> some View {
        let percent = Int((min(1.0, max(0.0, score)) * 100).rounded())
        return Text(String(format: String(
            localized: "search.semantic.row.score %lld",
            defaultValue: "Semantic match · %lld%%"), Int64(percent)))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func queueVolumeDownload(_ volumeID: String) {
        guard let entry = appState.manifestStore.entry(forVolumeId: volumeID),
              let downloadManager = appState.downloadManager else { return }
        requestedVolumeDownloads.insert(volumeID)
        Task { await downloadManager.enqueueDownload(entry) }
    }
}
