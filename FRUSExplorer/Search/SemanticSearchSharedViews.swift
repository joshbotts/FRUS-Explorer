// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SemanticScoreChip

/// The semantic score, as every semantic surface shows it: a rounded percentage on the axis's
/// self-normalising scale. One view, so the fallback card, the Meaning mode's rows, and the
/// beyond-library rows cannot drift on format.
struct SemanticScoreChip: View {
    let score: Double

    var body: some View {
        let percent = Int((min(1.0, max(0.0, score)) * 100).rounded())
        Text(String(format: String(
            localized: "search.semantic.row.score %lld",
            defaultValue: "Semantic match · %lld%%"), Int64(percent)))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

// MARK: - SemanticUndownloadedRow

/// A semantic hit in a volume this device has not downloaded — the #262 presentation: the
/// volume's manifest title, the document's id, no invented metadata, and the way to get it.
struct SemanticUndownloadedRow: View {
    let volumeID: String
    let documentID: String
    let score: Double
    let volumeTitle: String
    /// Whether the manifest carries a download URL for this volume.
    let isDownloadable: Bool

    @Environment(AppState.self) private var appState
    /// Local queued-state so the button reads "queued" after the tap, the graph's pattern.
    @State private var downloadQueued = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(format: String(
                localized: "search.semantic.row.undownloaded %@ %@",
                defaultValue: "Document %1$@ in %2$@"),
                documentID, volumeTitle))
                .font(.callout)
                .multilineTextAlignment(.leading)
            Text(String(localized: "search.semantic.row.notDownloaded",
                        defaultValue: "Volume not downloaded — its documents are shown without titles until you download it."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                SemanticScoreChip(score: score)
                if downloadQueued {
                    Text(String(localized: "search.semantic.row.downloadQueued",
                                defaultValue: "Download queued"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isDownloadable {
                    Button {
                        queueDownload()
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

    private func queueDownload() {
        guard let entry = appState.manifestStore.entry(forVolumeId: volumeID),
              let downloadManager = appState.downloadManager else { return }
        downloadQueued = true
        Task { await downloadManager.enqueueDownload(entry) }
    }
}

// MARK: - SemanticModelOfferCard

/// The model offer, self-contained: card → the SAME consent sheet Settings uses (no download
/// path around the Gemma flow-down) → byte progress → verification → `onModelReady`. Mounted by
/// the zero-result fallback and by the Meaning mode's model-absent state, so the two surfaces
/// offer identical terms.
struct SemanticModelOfferCard: View {

    /// Runs once the model is downloaded AND verified — the mounting surface re-runs its search.
    let onModelReady: () -> Void

    @Environment(AppState.self) private var appState
    @State private var showingConsent = false
    @State private var downloading = false
    @State private var failure: String?

    var body: some View {
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
            if downloading {
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
            } else {
                Button {
                    showingConsent = true
                } label: {
                    Text(String(localized: "search.semantic.offer.button",
                                defaultValue: "Download Search Model…"))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appState.isOnline)
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .sheet(isPresented: $showingConsent) {
            SemanticModelConsentSheet {
                showingConsent = false
                Task { await downloadModel() }
            } onCancel: {
                showingConsent = false
            }
        }
    }

    private func downloadModel() async {
        downloading = true
        failure = nil
        await appState.downloadSemanticModel()
        let status = await appState.semanticModelStatus()
        downloading = false
        if status.isPresent {
            onModelReady()
        } else {
            failure = status.failure ?? String(
                localized: "search.semantic.downloadFailed",
                defaultValue: "The model could not be downloaded. You can try again from the button above, or from Settings.")
        }
    }
}
