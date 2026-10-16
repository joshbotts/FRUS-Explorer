// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - KeepingCurrentSection

/// Volumes & Storage's **Keeping Current** section, mounted by both hubs (#1660).
///
/// One shared view, as `SemanticStorageSection` and `VolumeUpdateReviewSection` are (the #900
/// rule): the two hubs are hand-maintained twins, and their copies of this section had already
/// drifted — the Mac drew a row's Update button over the volume's title (`.overlay`), where
/// iPhone and iPad laid the two side by side. Only the two buttons at the top differ by platform,
/// as they did: bordered buttons with tooltips on the Mac, rows with a detail line on iPhone and
/// iPad.
///
/// What the rows say comes from `KeepingCurrentModel`, held by `AppState`.
///
/// Version history:
///   1.0 — #1660: initial implementation, replacing each hub's own section
struct KeepingCurrentSection: View {

    @Environment(AppState.self) private var appState

    private var model: KeepingCurrentModel { appState.keepingCurrent }

    /// Whether the device holds no volume to check.
    private var hasNoVolumes: Bool {
        appState.downloadedVolumes.report?.perVolume.isEmpty ?? true
    }

    var body: some View {
        Section {
            listButtons

            if let problem = model.listProblem {
                SettingsStatusRow(
                    label: KeepingCurrentCopy.listProblemLabel,
                    detail: KeepingCurrentCopy.listProblem(problem),
                    state: .warning
                )
            }

            if !model.rows.isEmpty {
                ForEach(model.rows) { row in
                    KeepingCurrentRow(row: row) {
                        Task { await model.update(row.id, downloads: appState.downloadManager) }
                    }
                }
                if model.offersUpdateAll {
                    Button {
                        Task { await model.updateAll(downloads: appState.downloadManager) }
                    } label: {
                        Text(String(localized: "settings.hub.corrections.updateAll",
                                    defaultValue: "Update All"))
                    }
                    #if os(macOS)
                    .buttonStyle(.borderedProminent)
                    #endif
                }
            } else if model.hasChecked && !model.isChecking && model.listProblem == nil {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.corrections.upToDate",
                                  defaultValue: "All downloaded volumes are up to date"),
                    detail: String(localized: "settings.hub.corrections.upToDate.detail",
                                   defaultValue: "Nothing has changed upstream since you downloaded them."),
                    state: .ok
                )
            }
        } header: {
            Text(String(localized: "settings.hub.keepingCurrent.header",
                        defaultValue: "Keeping Current"))
        } footer: {
            Text(String(localized: "settings.hub.keepingCurrent.footer",
                        defaultValue: "Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved."))
            #if os(macOS)
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
        }
    }

    // MARK: - Check for Corrections · Refresh Available List

    private func check() {
        Task {
            await model.check(manifest: appState.manifestStore,
                              downloads: appState.downloadManager,
                              isOnline: appState.isOnline)
        }
    }

    private func refreshList() {
        Task { await model.refreshList(manifest: appState.manifestStore, isOnline: appState.isOnline) }
    }

    @ViewBuilder
    private var listButtons: some View {
        #if os(macOS)
        HStack(spacing: 10) {
            Button(action: check) {
                if model.isChecking {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "settings.hub.corrections.checking",
                                    defaultValue: "Checking…"))
                    }
                } else {
                    Text(String(localized: "settings.hub.corrections.button",
                                defaultValue: "Check for Corrections"))
                }
            }
            .buttonStyle(.bordered)
            // Not disabled for want of the published list: a check reads it first (#1660).
            .disabled(model.isChecking || hasNoVolumes)
            .controlHelp(
                String(localized: "settings.hub.corrections.a11y",
                       defaultValue: "Check downloaded volumes for upstream corrections"),
                detail: String(localized: "settings.hub.corrections.help",
                               defaultValue: "Compares each downloaded volume against the FRUS repository and lists any that changed since you downloaded them"),
                systemImage: "arrow.triangle.2.circlepath"
            )

            Button(action: refreshList) {
                if model.isRefreshingList {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "settings.hub.catalog.refreshing",
                                    defaultValue: "Refreshing…"))
                    }
                } else {
                    Text(String(localized: "settings.hub.catalog.button",
                                defaultValue: "Refresh Available List"))
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.isRefreshingList || !appState.isOnline)
            .controlHelp(
                // .v2 / .v2: both promised newly published volumes appearing in the download
                // browser. They cannot — that browser reads `diffResult.known`, a filter over
                // the BUNDLED manifest, which can only shrink (D-1).
                String(localized: "settings.hub.catalog.a11y.v2",
                       defaultValue: "Re-read the published volume list"),
                detail: String(localized: "settings.hub.catalog.help.v2",
                               defaultValue: "Re-reads the FRUS repository’s volume list, refreshing each volume’s download link and size and dropping any the Office of the Historian has withdrawn"),
                systemImage: "arrow.clockwise"
            )
        }
        #else
        Button(action: check) {
            if model.isChecking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "settings.hub.corrections.checking",
                                defaultValue: "Checking…"))
                }
            } else {
                SettingsNavRow(
                    label: String(localized: "settings.hub.corrections.button",
                                  defaultValue: "Check for Corrections"),
                    systemImage: "arrow.triangle.2.circlepath",
                    detail: String(localized: "settings.hub.corrections.detail",
                                   defaultValue: "Re-download volumes changed upstream.")
                )
            }
        }
        .buttonStyle(.plain)
        // Not disabled for want of the published list: a check reads it first (#1660).
        .disabled(model.isChecking || hasNoVolumes)

        Button(action: refreshList) {
            if model.isRefreshingList {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "settings.hub.catalog.refreshing",
                                defaultValue: "Refreshing…"))
                }
            } else {
                SettingsNavRow(
                    label: String(localized: "settings.hub.catalog.button",
                                  defaultValue: "Refresh Available List"),
                    systemImage: "arrow.clockwise",
                    // .v2: the old text promised newly published volumes. It cannot deliver
                    // them — every download surface reads `diffResult.known`, a filter over
                    // the BUNDLED manifest, so a volume published since this build shipped
                    // has no row to appear in (D-1 left that gap silent). What the refresh
                    // does deliver is real: corrected download URLs and sizes, and volumes
                    // withdrawn upstream dropping out of the list.
                    detail: String(localized: "settings.hub.catalog.detail.v2",
                                   defaultValue: "Re-read the published list to refresh sizes and download links.")
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isRefreshingList || !appState.isOnline)
        #endif
    }
}

// MARK: - KeepingCurrentRow

/// One listed volume: its title and id, a line when it is a side-loaded copy or its update
/// failed, and, beside them, Update, Retry or where its update stands (#1660).
///
/// The title takes the width the control leaves and wraps there. The Mac drew its Update button
/// in an overlay on the title, which a long early title ran under (#1660's screenshot); iPhone
/// and iPad already laid them side by side, and limited the title to two lines, which could hide
/// the part number that tells two volumes apart. No limit now.
///
/// Version history:
///   1.0 — #1660: initial implementation
private struct KeepingCurrentRow: View {

    let row: KeepingCurrentModel.Row
    /// Update or Retry.
    let update: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.entry.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.entry.volumeId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Until the update is done: then the published copy has replaced the reader's.
                if row.isSideloaded && row.status != .updated {
                    note(KeepingCurrentCopy.sideloaded, systemImage: "exclamationmark.triangle.fill", tint: .orange)
                }
                if case .failed(let failure) = row.status {
                    note(KeepingCurrentCopy.failure(failure), systemImage: "xmark.octagon.fill", tint: .red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            control
                .fixedSize()
        }
    }

    /// A caption line with a tinted symbol; the text stays secondary, so it keeps its contrast.
    private func note(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var control: some View {
        switch row.status {
        case .available:
            rowButton(String(localized: "settings.hub.corrections.update", defaultValue: "Update"),
                      accessibilityLabel: String(localized: "settings.hub.corrections.update.a11y",
                                                 defaultValue: "Update \(row.entry.volumeId)"))
        case .failed:
            rowButton(KeepingCurrentCopy.retry,
                      accessibilityLabel: String(localized: "settings.hub.corrections.retry.a11y",
                                                 defaultValue: "Retry the update of \(row.entry.volumeId)"))
        case .queued:
            Text(KeepingCurrentCopy.queued)
                .foregroundStyle(.secondary)
        case .downloading:
            progress(KeepingCurrentCopy.downloading)
        case .alreadyDownloading:
            progress(KeepingCurrentCopy.alreadyDownloading)
        case .indexing:
            progress(KeepingCurrentCopy.indexing)
        case .updated:
            Label {
                Text(KeepingCurrentCopy.updated)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
        }
    }

    private func rowButton(_ title: String, accessibilityLabel: String) -> some View {
        Button(title, action: update)
            #if os(macOS)
            .buttonStyle(.bordered)
            #else
            .buttonStyle(.borderless)
            #endif
            .accessibilityLabel(accessibilityLabel)
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
