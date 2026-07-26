// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - DataRecoveryView

/// Settings → System → **Data & Recovery** — your data out, and your app back on its feet (S-4b).
///
/// ## What this replaces
/// Three root rows — "Research Data", "Sync Diagnostics", and "Reset App" — that were really one
/// subject seen from three angles: getting your work out of the app, finding out what the app
/// thinks is wrong, and putting it back together. With Connections (S-4a) this brings the System
/// group down to four rows.
///
/// ## The recovery ladder
/// The three repair actions were always ordered least- to most-destructive, but you had to read a
/// paragraph above each to learn which was which. Each rung now states **what survives** on the row
/// itself, before you tap: *nothing is deleted* → *volumes and index only* → its own screen with
/// two confirmations. A reader scanning for the smallest thing that might help finds it first.
///
/// Version history:
///   1.0 — S-4b: initial implementation
struct DataRecoveryView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var syncSummary = SyncLogSummary()
    @State private var showSyncResetConfirmation = false
    @State private var showLocalResetConfirmation = false
    @State private var isResetting = false
    /// macOS presents the two sub-screens as sheets; iOS pushes.
    @State private var sheet: SubScreen? = nil

    /// The two screens this door leads to.
    enum SubScreen: String, Identifiable {
        case brokenReferences, syncLog, eraseEverything
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            DataExportSections()

            if BrokenRefsIndexStore.shared != nil {
                Section {
                    link(.brokenReferences,
                         label: String(localized: "settings.dataRecovery.reports.brokenRefs",
                                       defaultValue: "Broken Cross-References"),
                         detail: String(localized: "settings.dataRecovery.reports.brokenRefs.detail",
                                        defaultValue: "For the Office of the Historian"),
                         value: "CSV · JSON")
                } header: {
                    Text(String(localized: "settings.dataRecovery.reports.header",
                                defaultValue: "Reports"))
                }
            }

            Section {
                link(.syncLog,
                     label: String(localized: "settings.dataRecovery.syncLog",
                                   defaultValue: "Sync Log"),
                     detail: syncSummary.text())
            } header: {
                Text(String(localized: "settings.dataRecovery.diagnostics.header",
                            defaultValue: "Diagnostics"))
            }

            recoverySection
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.pane.dataRecovery",
                                defaultValue: "Data & Recovery"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadSyncSummary() }
        #if os(macOS)
        .sheet(item: $sheet) { screen in
            VStack(spacing: 0) {
                subScreen(screen)
                Divider()
                HStack {
                    Spacer()
                    Button(String(localized: "settings.dataRecovery.done", defaultValue: "Done")) {
                        sheet = nil
                        Task { await loadSyncSummary() }
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .frame(minWidth: 520, minHeight: 460)
        }
        #endif
        .confirmationDialog(
            String(localized: "settings.dataRecovery.fixSync.title",
                   defaultValue: "Re-download everything from iCloud?"),
            isPresented: $showSyncResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.dataRecovery.fixSync.confirm",
                          defaultValue: "Fix iCloud Sync"), role: .destructive) {
                performSyncReset()
            }
            Button(String(localized: "settings.connections.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.dataRecovery.fixSync.message",
                        defaultValue: "The local copy of your synced data is cleared and pulled down again. Nothing in iCloud is deleted, so nothing is lost — the app returns to onboarding while it restores."))
        }
        .confirmationDialog(
            String(localized: "settings.dataRecovery.resetDevice.title",
                   defaultValue: "Remove volumes and the index from this device?"),
            isPresented: $showLocalResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.dataRecovery.resetDevice.confirm",
                          defaultValue: "Reset This Device"), role: .destructive) {
                performLocalReset()
            }
            Button(String(localized: "settings.connections.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.dataRecovery.resetDevice.message",
                        defaultValue: "Downloaded volumes and the search index go; your notes, highlights, tags, collections and projects stay in iCloud and come back on the next launch. You will need to download volumes again."))
        }
    }

    // MARK: - Recovery ladder

    @ViewBuilder
    private var recoverySection: some View {
        Section {
            Button {
                showSyncResetConfirmation = true
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.dataRecovery.fixSync",
                                  defaultValue: "Fix iCloud Sync"),
                    systemImage: "arrow.triangle.2.circlepath.icloud",
                    detail: String(localized: "settings.dataRecovery.fixSync.detail",
                                   defaultValue: "Re-download from iCloud — nothing is deleted")
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isResetting)

            Button {
                showLocalResetConfirmation = true
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.dataRecovery.resetDevice",
                                  defaultValue: "Reset This Device"),
                    systemImage: "internaldrive",
                    detail: String(localized: "settings.dataRecovery.resetDevice.detail",
                                   defaultValue: "Volumes & index only — iCloud data survives")
                )
                .foregroundStyle(.red)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isResetting)

            link(.eraseEverything,
                 label: String(localized: "settings.dataRecovery.erase",
                               defaultValue: "Erase Everything…"),
                 detail: String(localized: "settings.dataRecovery.erase.detail",
                                defaultValue: "Every note, tag, collection and project, on every device"),
                 destructive: true)
        } header: {
            Text(String(localized: "settings.dataRecovery.recovery.header",
                        defaultValue: "Recovery"))
        } footer: {
            Text(String(localized: "settings.dataRecovery.recovery.footer",
                        defaultValue: "In order of how much they take away. Try the first one first — it is the one that deletes nothing."))
        }
    }

    // MARK: - Navigation

    /// One row that leads somewhere: a push on iOS, a sheet on macOS (a Settings window has no
    /// navigation chrome of its own).
    @ViewBuilder
    private func link(_ screen: SubScreen,
                      label: String,
                      detail: String,
                      value: String? = nil,
                      destructive: Bool = false) -> some View {
        #if os(macOS)
        Button {
            sheet = screen
        } label: {
            HStack {
                SettingsNavRow(label: label, detail: detail, value: value)
                    .foregroundStyle(destructive ? Color.red : Color.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #else
        NavigationLink {
            subScreen(screen)
                .onDisappear { Task { await loadSyncSummary() } }
        } label: {
            SettingsNavRow(label: label, detail: detail, value: value)
                .foregroundStyle(destructive ? Color.red : Color.primary)
        }
        #endif
    }

    @ViewBuilder
    private func subScreen(_ screen: SubScreen) -> some View {
        switch screen {
        case .brokenReferences: BrokenReferencesReportView()
        case .syncLog:          SyncDiagnosticsView()
        case .eraseEverything:  EraseEverythingView()
        }
    }

    // MARK: - State

    private func loadSyncSummary() async {
        let entries = await SyncDiagnosticsLog.shared.entries()
        syncSummary = SyncLogSummary.make(
            entries: entries.map { (timestamp: $0.timestamp, hasError: $0.errorCode != nil) })
    }

    // MARK: - Recovery actions

    /// Clears the local SwiftData store so the container re-downloads from CloudKit. Nothing in
    /// iCloud is deleted.
    private func performSyncReset() {
        isResetting = true
        let fm = FileManager.default
        let appSupportURLs = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        for base in appSupportURLs {
            // Standard SwiftData store location (bundle-id based).
            if let bundleId = Bundle.main.bundleIdentifier {
                let dir = base.appendingPathComponent(bundleId, isDirectory: true)
                if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                    for file in files where file.pathExtension == "sqlite" {
                        try? fm.removeItem(at: file)
                    }
                }
            }
            // The named app-support directory this app also uses. The `frus` prefix guard keeps
            // the FTS5 search index — which is not synced and would have to be rebuilt from XML.
            let namedDir = base.appendingPathComponent("FRUSExplorer", isDirectory: true)
            if let files = try? fm.contentsOfDirectory(at: namedDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "sqlite"
                                         && !file.lastPathComponent.hasPrefix("frus") {
                    try? fm.removeItem(at: file)
                }
            }
        }
        appState.hasCompletedOnboarding = false
        isResetting = false
    }

    /// Deletes downloaded volumes and the search index, leaving the local SwiftData store and
    /// iCloud-synced data untouched.
    private func performLocalReset() {
        isResetting = true
        Task {
            await ResetService.resetLocalData(appState: appState)
            await MainActor.run { isResetting = false }
        }
    }
}

// MARK: - BrokenReferencesReportView

/// The Office of the Historian's broken-cross-reference report, on its own screen (S-4b).
///
/// It used to be the last section of the export pane, beside the researcher's own data exports —
/// which put a QA artifact for one institution in the same list as "your notes". Same two files,
/// its own door, and the door says who it is for.
///
/// Version history:
///   1.0 — S-4b: extracted from `ResearchDataExportView`
struct BrokenReferencesReportView: View {

    @State private var csvURL: URL?
    @State private var jsonURL: URL?

    var body: some View {
        Form {
            Section {
                Text(String(localized: "settings.export.brokenRefs.footer",
                            defaultValue: "The corpus-wide list of cross-references in the printed FRUS volumes that point to a document, page, or volume not present in the corpus. The CSV lists distinct broken targets; the fuller per-occurrence spreadsheet with source line numbers is generated offline."))
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "settings.dataRecovery.reports.about", defaultValue: "About"))
            }

            Section {
                if let csvURL {
                    ShareLink(item: csvURL) {
                        Label(String(localized: "settings.export.brokenRefs.csv",
                                     defaultValue: "Export as CSV"), systemImage: "tablecells")
                    }
                } else {
                    preparingRow
                }
                if let jsonURL {
                    ShareLink(item: jsonURL) {
                        Label(String(localized: "settings.export.brokenRefs.json",
                                     defaultValue: "Export as JSON"), systemImage: "doc.badge.arrow.up")
                    }
                } else {
                    preparingRow
                }
            } header: {
                Text(String(localized: "settings.dataRecovery.reports.files", defaultValue: "Files"))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.dataRecovery.reports.brokenRefs",
                                defaultValue: "Broken Cross-References"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { prepare() }
    }

    @ViewBuilder
    private var preparingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(String(localized: "settings.export.preparing", defaultValue: "Preparing export…"))
                .foregroundStyle(.secondary)
        }
    }

    /// Writes the bundled broken-refs index to temporary CSV + JSON files for `ShareLink`.
    private func prepare() {
        guard let index = BrokenRefsIndexStore.shared else { return }
        do {
            let csv = BrokenRefsReportExporter.csv(from: index)
            let csvPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("frus-broken-cross-references.csv")
            try Data(csv.utf8).write(to: csvPath, options: .atomic)
            csvURL = csvPath

            let jsonPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("frus-broken-cross-references.json")
            try BrokenRefsReportExporter.jsonData().write(to: jsonPath, options: .atomic)
            jsonURL = jsonPath
        } catch {
            #if DEBUG
            print("[BrokenReferencesReportView] export prep failed — \(error)")
            #endif
        }
    }
}
