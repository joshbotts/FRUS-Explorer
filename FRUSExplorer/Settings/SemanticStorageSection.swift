// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SemanticStorageSection

/// The storage hubs' semantic-vectors section (#900).
///
/// ## One view, both hubs, on purpose
/// `VolumesStorageHubView` (iOS, ~1,850 lines) and `MacVolumesStorageHub` (~1,960) are
/// hand-maintained twins: their section order, copy and behaviour match because someone keeps them
/// matching, not because anything enforces it. Adding this to each separately would put four
/// numbers and six sentences in two places, and the repo has a recorded defect from exactly that
/// shape — a Settings toggle that shipped on one platform and was invisible on the other for
/// months. So both hubs mount **this**, and there is nothing to keep in step.
///
/// ## What it may claim
/// Two of the report's figures are authoritative (what is on disk, what is published) and two are
/// structurally partial (failures this session, refusals for volumes something has asked about).
/// `SemanticStorageReport` carries that distinction and the sentence that discloses it; this view
/// renders it and does not re-word it.
///
/// Version history:
///   1.0 — #900
struct SemanticStorageSection: View {

    @Environment(AppState.self) private var appState

    /// The current figures. Reloaded on appearance and after any action that changes them.
    @State private var report: SemanticStorageReport = .unavailable
    /// Set while a destructive action runs, so the buttons cannot be pressed twice.
    @State private var busy = false
    /// Shards this device could fetch right now — published, missing, and for a volume it holds.
    @State private var awaiting: [String] = []
    /// The off switch (#926). Device-local, like the cellular-downloads twin beside it.
    @AppStorage(SettingsKeys.autoDownloadSemanticShards)
    private var autoDownload: Bool = true
    /// Bumped to re-run the loader after an action.
    @State private var reloadToken = 0

    var body: some View {
        Section {
            if report.isAvailable {
                summaryRow
                if let progress = appState.semanticShardDownload {
                    downloadProgressRow(progress)
                } else if !awaiting.isEmpty {
                    downloadButton
                }
                autoDownloadToggle
                problemsRow
                if !report.failures.isEmpty { retryButton }
                if report.volumesOnDisk > 0 { removeButton }
            } else {
                unavailableRow
            }
        } header: {
            Text(String(localized: "settings.vectors.header", defaultValue: "Semantic Vectors"))
        } footer: {
            Text(String(
                localized: "settings.vectors.footer",
                defaultValue: "Vectors let the app find documents that are about the same thing, not just ones sharing a word. A volume’s vectors download with the volume and are removed with it."))
        }
        .task(id: reloadToken) { await reload() }
    }

    // MARK: - Rows

    /// How much is here, against how much there is.
    ///
    /// Both halves of the ratio are authoritative: the numerator is a directory listing and the
    /// denominator is the bundled manifest, so neither is an estimate.
    private var summaryRow: some View {
        SettingsNavRow(
            label: String(localized: "settings.vectors.downloaded.label",
                          defaultValue: "Downloaded"),
            systemImage: "point.3.connected.trianglepath.dotted",
            detail: String(
                format: String(localized: "settings.vectors.downloaded.detail %@ %@",
                               defaultValue: "%@ of %@ on this device."),
                Self.bytes(report.bytesOnDisk), Self.bytes(report.bytesPublished)),
            value: String(
                format: String(localized: "settings.vectors.downloaded.value %lld %lld",
                               defaultValue: "%lld of %lld"),
                Int64(report.volumesOnDisk), Int64(report.volumesPublished))
        )
    }

    // MARK: - Why there is no PER-FILE progress, but there is per-shard progress
    //
    // #900 asked to "report download progress"; #925 shipped none, and this adds a count. Both are
    // the same rule applied at two granularities, so neither contradicts the other:
    //
    // * **Within one shard there is nothing to read.** The transfer is a one-shot
    //   `URLSession.download(from:)` with no progress callback — passing a delegate to
    //   `download(from:delegate:)` compiles and delivers zero callbacks, so a bar would sit at 0%.
    //   The file is ~145 KB and lands in about 0.1 s; a bar would be a flash even if it worked.
    // * **Across many shards the completed COUNT is observable and worth showing.** A manual
    //   download of 340 volumes is a minutes-long action, and "downloading 12 of 340" is a true
    //   sentence the app can produce. That is `AppState.SemanticShardDownloadProgress`.
    //
    // What is still not shown is an in-flight row for the AUTOMATIC path: that fetch is one file,
    // fired from a background task, and a one-shot read of its state is stale before it renders —
    // measured in #925, which wrote such a row and deleted it rather than ship one that sticks.

    /// The off switch, and the only place the reader learns these downloads happen at all.
    ///
    /// Default ON, matching what the app has always done: a switch whose *introduction* changed
    /// behaviour for people who never touched it would be a worse trade than the request it saves.
    private var autoDownloadToggle: some View {
        Toggle(isOn: $autoDownload) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "settings.vectors.auto.label",
                            defaultValue: "Download With Volumes"))
                Text(String(
                    format: String(localized: "settings.vectors.auto.detail %@",
                                   defaultValue: "Adds about %@ per volume. Turn this off to fetch them yourself."),
                    Self.bytes(report.perVolumeEstimate)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityHint(String(
            localized: "settings.vectors.auto.a11y",
            defaultValue: "When off, a volume's vectors are only fetched when you ask for them here"))
    }

    /// Fetches every shard this device is missing for the volumes it holds.
    private var downloadButton: some View {
        Button {
            Task {
                await appState.downloadAllSemanticShards()
                reloadToken += 1
            }
        } label: {
            SettingsNavRow(
                label: String(localized: "settings.vectors.download.label",
                              defaultValue: "Download Missing Vectors"),
                systemImage: "arrow.down.circle",
                detail: String(
                    format: String(localized: "settings.vectors.download.detail %lld %@",
                                   defaultValue: "%lld volumes on this device have none yet — about %@."),
                    Int64(awaiting.count), Self.bytes(awaiting.count * report.perVolumeEstimate))
            )
        }
        .buttonStyle(.plain)
        .disabled(busy || !appState.isOnline)
    }

    /// A COUNT, not a byte bar.
    ///
    /// One shard is a single `URLSession.download(from:)` with no progress callback, so
    /// bytes-within-a-file are not observable — but across many files the completed count is, and it
    /// is what a reader wants from a bulk action anyway. #925 refused to show a per-file bar for
    /// exactly this reason; this is the same rule reaching the opposite, honest answer at a
    /// different granularity.
    private func downloadProgressRow(_ progress: AppState.SemanticShardDownloadProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress.fraction) {
                Text(String(
                    format: String(localized: "settings.vectors.download.progress %lld %lld",
                                   defaultValue: "Downloading %lld of %lld"),
                    Int64(progress.completed), Int64(progress.total)))
            }
            if progress.failed > 0 {
                Text(String(
                    format: String(localized: "settings.vectors.download.failed %lld",
                                   defaultValue: "%lld could not be fetched — see Problems below."),
                    Int64(progress.failed)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(String(localized: "settings.vectors.download.cancel", defaultValue: "Stop")) {
                appState.cancelSemanticShardDownload()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
    }

    /// What has gone wrong that the app has actually noticed.
    ///
    /// The caption comes from `SemanticStorageReport` rather than being written here, because it
    /// carries a disclosure — the scan behind it is partial — that must not be re-worded into a
    /// clean bill of health by either platform.
    private var problemsRow: some View {
        SettingsStatusRow(
            label: String(localized: "settings.vectors.problems.label", defaultValue: "Problems"),
            detail: report.problemsCaption,
            state: report.problemVolumeIDs.isEmpty ? .ok : .warning
        )
    }

    /// Clears the remembered failures so the next request can try again.
    ///
    /// The fetcher deliberately remembers a failure for the session so the lazy path does not retry
    /// on every query — right for a query, wrong for someone who has just reconnected. This is the
    /// half that was missing: `clearFailures()` existed and had no caller anywhere in the app.
    private var retryButton: some View {
        Button {
            Task {
                busy = true
                await appState.retrySemanticShardFetches()
                reloadToken += 1
                busy = false
            }
        } label: {
            SettingsNavRow(
                label: String(localized: "settings.vectors.retry.label",
                              defaultValue: "Try Failed Downloads Again"),
                systemImage: "arrow.clockwise",
                detail: String(localized: "settings.vectors.retry.detail",
                               defaultValue: "Forgets this session’s failures so the next search can re-request them.")
            )
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    /// Removes every shard on disk.
    ///
    /// Non-destructive to the library: the volumes and their index are untouched, and semantic
    /// search degrades to the bundled corpus-wide tier rather than stopping — which is what the
    /// detail line says, because "remove vectors" otherwise reads as "break search".
    private var removeButton: some View {
        Button(role: .destructive) {
            Task {
                busy = true
                await appState.semanticShardStore?.removeAllShards()
                reloadToken += 1
                busy = false
            }
        } label: {
            SettingsNavRow(
                label: String(localized: "settings.vectors.remove.label",
                              defaultValue: "Remove Downloaded Vectors"),
                systemImage: "trash",
                detail: String(
                    format: String(localized: "settings.vectors.remove.detail %@",
                                   defaultValue: "Frees %@. Your volumes and search index are untouched; related-document results become less precise until the vectors download again."),
                    Self.bytes(report.bytesOnDisk))
            )
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    /// Shown when the semantic stack never booted.
    ///
    /// Distinct from "nothing downloaded", which is a library state. This is a build state: the
    /// bundled artifacts are missing or pinned to a different generation, so the store cannot exist
    /// at all. Saying "0 of 552" here would invite a reader to go looking for a download that
    /// cannot happen.
    private var unavailableRow: some View {
        SettingsStatusRow(
            label: String(localized: "settings.vectors.unavailable.label",
                          defaultValue: "Not available"),
            detail: String(localized: "settings.vectors.unavailable.detail",
                           defaultValue: "This build has no semantic vectors, so related-document search is unavailable. Nothing is wrong with your library."),
            state: .warning
        )
    }

    // MARK: - Loading

    private func reload() async {
        report = await appState.semanticStorageReport()
        awaiting = await appState.semanticShardsAwaitingDownload()
    }

    /// Human byte sizes, one formatter for every figure in this section.
    private static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
