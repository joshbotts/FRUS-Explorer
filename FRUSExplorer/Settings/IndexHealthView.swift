// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - IndexHealthView

/// Compact "Index Health" block for the Storage settings pane, shared by the
/// iOS `StorageManagementView` and the macOS Storage pane.
///
/// Merges three previously disconnected facts about the search index into one
/// display (Session 162, user request):
///
/// 1. **Status** — whether the index is being updated right now
///    (`AppState.currentIndexingProgress != nil`), has a version-triggered
///    update pending (`needsDateReindex` / `needsFTSRebuildReindex` — normally
///    started automatically at launch), or is current.
/// 2. **Format version** — the installed date-index version vs.
///    `IndexingPipeline.currentDateIndexVersion`, so the pane shows *which*
///    generation of the extraction pipeline built the on-disk index.
/// 3. **Integrity** — the manual "Check Integrity" button (SQLite
///    `quick_check` + FTS5 `integrity-check`; the expensive on-demand
///    diagnostic) with its inline result list.
///
/// The status row is passive observation; only the integrity check runs work,
/// and it is disabled while any indexing is active (its own activity, the
/// host's batch operations via `actionsDisabled`, or a live re-index).
///
/// Version history:
///   1.0 — Session 162: initial implementation
struct IndexHealthView: View {

    @Environment(AppState.self) private var appState

    /// Host-supplied extra disable for the integrity button — e.g. a
    /// Settings-triggered batch (Reindex All / Delete Index & Rebuild) in flight.
    var actionsDisabled: Bool = false

    /// `true` while `checkIndexIntegrity()` is running.
    @State private var integrityCheckRunning = false
    /// Result of the most recent integrity check: `nil` before the first run,
    /// empty when no problems were found, else one string per problem.
    @State private var integrityCheckResult: [String]? = nil

    // MARK: - Derived status

    /// The three states the status row can report.
    private enum HealthStatus {
        /// A volume is being parsed/indexed right now.
        case updating
        /// The on-disk index was built by an older pipeline version; the
        /// automatic background re-index has not (yet) completed.
        case updatePending
        /// Index format is current and nothing is running.
        case upToDate
    }

    /// Installed date-index version from UserDefaults (0 before the first index).
    private var installedVersion: Int {
        UserDefaults.standard.integer(forKey: IndexingPipeline.dateIndexVersionKey)
    }

    /// Latest version of the indexing process shipped in this build.
    private var currentVersion: Int {
        IndexingPipeline.currentDateIndexVersion
    }

    private var status: HealthStatus {
        if appState.currentIndexingProgress != nil { return .updating }
        if let pipeline = appState.indexingPipeline,
           pipeline.needsDateReindex || pipeline.needsFTSRebuildReindex {
            return .updatePending
        }
        return .upToDate
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                statusIcon
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusTitle)
                        .font(.callout)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                integrityButton
            }
            .accessibilityElement(children: .combine)

            integrityResultRows
        }
    }

    // MARK: - Status row

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .updating:
            ProgressView()
                .controlSize(.small)
        case .updatePending:
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.orange)
        case .upToDate:
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.green)
        }
    }

    private var statusTitle: String {
        switch status {
        case .updating:
            return String(localized: "indexHealth.status.updating",
                          defaultValue: "Updating index…")
        case .updatePending:
            return String(localized: "indexHealth.status.pending",
                          defaultValue: "Index update pending")
        case .upToDate:
            return String(localized: "indexHealth.status.current",
                          defaultValue: "Index up to date")
        }
    }

    private var statusDetail: String {
        switch status {
        case .updating:
            return String(
                format: String(localized: "indexHealth.detail.updating %lld",
                               defaultValue: "Rebuilding to format version %lld"),
                Int64(currentVersion)
            )
        case .updatePending:
            return String(
                format: String(localized: "indexHealth.detail.pending %lld %lld",
                               defaultValue: "Built with format version %lld — version %lld update runs automatically"),
                Int64(installedVersion), Int64(currentVersion)
            )
        case .upToDate:
            return String(
                format: String(localized: "indexHealth.detail.current %lld",
                               defaultValue: "Format version %lld"),
                Int64(currentVersion)
            )
        }
    }

    // MARK: - Integrity check

    private var integrityButton: some View {
        Button {
            Task { await runIndexIntegrityCheck() }
        } label: {
            if integrityCheckRunning {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "settings.storage.integrity.running",
                                defaultValue: "Checking…"))
                }
                .font(.callout)
            } else {
                Label(
                    String(localized: "indexHealth.integrity.button",
                           defaultValue: "Check Integrity"),
                    systemImage: "stethoscope"
                )
                .font(.callout)
            }
        }
        .buttonStyle(.bordered)
        .disabled(actionsDisabled
                  || integrityCheckRunning
                  || status == .updating
                  || appState.indexingPipeline == nil)
        .controlHelp(
            String(localized: "settings.storage.integrity.a11y",
                   defaultValue: "Check the search index for corruption"),
            detail: String(localized: "indexHealth.integrity.help",
                           defaultValue: "Run the full SQLite and FTS5 corruption diagnostic on the search index — may take a moment on a large index"),
            systemImage: "stethoscope"
        )
    }

    @ViewBuilder
    private var integrityResultRows: some View {
        if let result = integrityCheckResult {
            if result.isEmpty {
                Label(
                    String(localized: "settings.storage.integrity.ok",
                           defaultValue: "No problems found"),
                    systemImage: "checkmark.circle"
                )
                .foregroundStyle(.green)
                .font(.callout)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                    Text(String(localized: "settings.storage.integrity.suggestion",
                                defaultValue: "Try \"Delete Index & Rebuild\" above to fix these problems."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Runs `IndexingPipeline.checkIndexIntegrity()` and stores the result for display.
    private func runIndexIntegrityCheck() async {
        guard let pipeline = appState.indexingPipeline else { return }
        integrityCheckRunning = true
        integrityCheckResult = nil
        do {
            integrityCheckResult = try await pipeline.checkIndexIntegrity()
        } catch {
            integrityCheckResult = [error.localizedDescription]
        }
        integrityCheckRunning = false
    }
}
