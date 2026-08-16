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
    /// Bumped to re-run the loader after an action.
    @State private var reloadToken = 0

    var body: some View {
        Section {
            if report.isAvailable {
                summaryRow
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

    // MARK: - Why there is no progress row
    //
    // The issue asks to "report download progress to users", and this section deliberately reports
    // **none**. Three measurements, not a preference:
    //
    // 1. **There is no progress to read.** `SemanticShardFetcher` transfers with
    //    `URLSession.download(from:)`, a one-shot `async` call with no progress callback. The
    //    obvious one-line fix — passing a delegate to `download(from:delegate:)` — compiles, reads
    //    correctly, and delivers zero callbacks, so it would ship a bar pinned at 0%.
    // 2. **The window is shorter than any refresh.** A shard is ~148 KB and fetches in roughly
    //    0.065–0.185 s. A one-shot read in `.task` misses essentially every real fetch, and — worse
    //    — an in-flight row painted from such a read never clears, on a window this file's twin
    //    documents as being left open overnight. A row that is usually absent and occasionally
    //    stuck is worse than no row.
    // 3. **The app's own precedent is state-only for a payload 43× larger.** Volume XML has a
    //    median of ~5.3 MB and its Active Downloads row shows a title and a Cancel button, no
    //    bytes. Giving a 148 KB shard strictly more fidelity than the 5.3 MB download beside it
    //    would read as a bug.
    //
    // What a reader actually needs is the **outcome**, and that is what the two rows above give:
    // how much is here, and what went wrong. If live progress is ever wanted it needs an observable
    // on `AppState` written by the fetch itself — not a poll — and that is a separate change.

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
    }

    /// Human byte sizes, one formatter for every figure in this section.
    private static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
