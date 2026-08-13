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
///   1.1 — Wave R-7: an **iCloud Schema** row in Diagnostics, beside the Sync Log, reporting
///          whether the CloudKit container has been taught about everything this build stores.
///          #488 shipped without that answer being available anywhere in the app.
///   1.2 — Wave R-6: the Sync Log row counts errors the app could not describe separately from
///          errors it could, so a `partialFailure` with no sub-errors no longer reads the same
///          as a fully diagnosed one.
///   1.3 — **Fix iCloud Sync now clears a store.** It matched files by the extension `sqlite`
///          while both stores are named `*.store`, so it had never once deleted anything — it
///          only returned the app to onboarding, which made the no-op look like a repair. The
///          work moved to ``PendingStoreReset``, performed at the next launch (the only moment
///          nothing holds the files open) against an explicit file list.
struct DataRecoveryView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if os(macOS) && DEBUG
    /// Opens the semantic map's own window; a Metal surface does not survive this pane's sheets.
    @Environment(\.openWindow) private var openWindow
    #endif

    @State private var syncSummary = SyncLogSummary()
    @State private var showSyncResetConfirmation = false
    @State private var showLocalResetConfirmation = false
    @State private var isResetting = false
    /// Shown after a sync reset is requested, because the work happens at the next launch and the
    /// user has to be told that nothing has visibly changed yet.
    @State private var showRelaunchNotice = false
    /// macOS presents the two sub-screens as sheets; iOS pushes.
    @State private var sheet: SubScreen? = nil

    /// The screens this door leads to.
    enum SubScreen: String, Identifiable {
        case brokenReferences, syncLog, schemaStatus, semanticFeedback, eraseEverything
        #if DEBUG
        case semanticMapSpike
        #endif
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
                if appState.cloudKitSyncEnabled { schemaRow }
                // The semantic axis ships experimental because a quality gate was traded for
                // tester judgement; this is where that judgement is collected and exported.
                link(.semanticFeedback,
                     label: String(localized: "settings.dataRecovery.semanticFeedback",
                                   defaultValue: "Semantic Match Feedback"),
                     detail: String(
                        localized: "settings.dataRecovery.semanticFeedback.detail",
                        defaultValue: "Rate experimental semantic matches and export your verdicts"))
                #if DEBUG
                // V-4a: a measurement, not a feature. Debug-only until the map surface exists.
                link(.semanticMapSpike,
                     label: "Semantic Map",
                     detail: "The corpus as a map of its own vocabulary")
                #endif
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
                        defaultValue: "This clears the local copy of your synced data and downloads it again. Nothing in iCloud is deleted, so nothing is lost. The app returns to onboarding while it restores. The clearing happens the next time the app starts, so quit and reopen it."))
        }
        // The reset is performed at the next launch, before any store is opened — the only moment
        // no connection is holding the files. Without this the button would appear to do nothing.
        .alert(String(localized: "settings.dataRecovery.fixSync.relaunch.title",
                      defaultValue: "Quit and Reopen to Finish"),
               isPresented: $showRelaunchNotice) {
            Button(String(localized: "settings.dataRecovery.fixSync.relaunch.ok",
                          defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.dataRecovery.fixSync.relaunch.message",
                        defaultValue: "Your local copy will be cleared and re-downloaded from iCloud the next time FRUS Explorer starts. Nothing has been deleted yet, and nothing in iCloud is affected."))
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

    // MARK: - iCloud schema (Wave R-7)

    /// The schema-deploy state, beside the Sync Log because it explains the class of sync failure
    /// the log records but cannot name (#488).
    ///
    /// ## Who this is for
    /// A developer or a tester, which is why it lives in **Diagnostics** and not on a screen a
    /// researcher passes through. An undeployed schema is a release-process failure, so it gets no
    /// alert, no badge, no red — a researcher who wanders in should find a fact, not an alarm. It
    /// is nonetheless shown rather than hidden, because on the one build where this mattered the
    /// user-visible symptom was silent: sync simply stopped working, with nothing anywhere saying
    /// why.
    ///
    /// The row is present in **both** states. "Everything deployed" is the answer a tester needs
    /// when they are asked whether the schema is the problem, and a row that only ever appears
    /// when something is wrong cannot be checked in advance — or screenshotted for a bug report.
    ///
    /// Hidden entirely when CloudKit is off for this session: with a local-only store the deploy
    /// state is not a fact about anything the user can observe.
    @ViewBuilder
    private var schemaRow: some View {
        if CloudKitSchemaInventory.isProductionSchemaCurrent {
            link(.schemaStatus,
                 label: String(localized: "settings.dataRecovery.schema",
                               defaultValue: "iCloud Schema"),
                 detail: String(localized: "settings.dataRecovery.schema.detail.current",
                                defaultValue: "Published \(CloudKitSchemaInventory.deployedOn) — matches this version of the app"),
                 value: String(localized: "settings.dataRecovery.schema.value.current",
                               defaultValue: "Up to date"))
        } else {
            let pending = CloudKitSchemaInventory.identifiersAwaitingDeploy.count
            link(.schemaStatus,
                 label: String(localized: "settings.dataRecovery.schema",
                               defaultValue: "iCloud Schema"),
                 detail: pending == 1
                     ? String(localized: "settings.dataRecovery.schema.detail.pending.one",
                              defaultValue: "One addition in this version is not published yet")
                     : String(localized: "settings.dataRecovery.schema.detail.pending",
                              defaultValue: "\(pending) additions in this version are not published yet"),
                 value: String(localized: "settings.dataRecovery.schema.value.pending",
                               defaultValue: "Update pending"))
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
                    // Was "nothing is deleted", which was true only by accident: the action deleted
                    // nothing at all. It clears this device's copy at the next launch, and the row
                    // now says which of those two facts it means.
                    detail: String(localized: "settings.dataRecovery.fixSync.detail",
                                   defaultValue: "Re-download from iCloud at next launch")
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
                 detail: String(localized: "settings.dataRecovery.erase.detail.trail",
                                defaultValue: "Every note, tag, collection, project and recorded session, on every device"),
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
            #if DEBUG
            // The semantic map is a Metal surface and does not survive a SwiftUI sheet — see the
            // `frus.semanticMap` scene for the measurement. It gets a window of its own.
            if screen == .semanticMapSpike {
                openWindow.fronting(id: "frus.semanticMap")
                return
            }
            #endif
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
        case .schemaStatus:     SchemaDeployStatusView()
        case .semanticFeedback: SemanticFeedbackView()
        #if DEBUG
        case .semanticMapSpike: SemanticMapSpikeView(appState: appState)
        #endif
        case .eraseEverything:  EraseEverythingView()
        }
    }

    // MARK: - State

    private func loadSyncSummary() async {
        let entries = await SyncDiagnosticsLog.shared.entries()
        syncSummary = SyncLogSummary.make(
            entries: entries.map {
                .init(timestamp: $0.timestamp,
                      hasError: $0.errorCode != nil,
                      // Wave R-6: an error the app could not describe is counted separately, so
                      // the row stops reading the same for a diagnosed and an undiagnosed failure.
                      isUndiagnosed: $0.isUndiagnosedFailure)
            })
    }

    // MARK: - Recovery actions

    /// Requests that the local SwiftData stores be cleared at the next launch, so the container
    /// re-downloads from CloudKit. Nothing in iCloud is deleted.
    ///
    /// ## Why this only sets a flag
    /// Two reasons, and the first is a bug this replaces. The previous implementation deleted, from
    /// two Application Support directories, every file whose extension was `sqlite` — but this
    /// app's stores are `default.store` and `FRUSExplorerLocal.store`. Neither loop could ever
    /// match, on any platform, so the button had never cleared a store in its life. It set
    /// `hasCompletedOnboarding = false`, the app returned to onboarding and reported the data it
    /// already had, and the whole thing read as a successful repair.
    ///
    /// The second reason is why the fix is not simply a corrected file list: at this point the
    /// container is open on those files. Deleting them here unlinks them from under a live SQLite
    /// connection, so the rest of the session writes to an unnamed inode and CloudKit's mirroring
    /// state is torn mid-flight. ``PendingStoreReset`` therefore records the request and
    /// ``ModelContainer/makeFRUSContainer()`` performs it at the next launch, before any store is
    /// opened — with an explicit file list, never a pattern, because `frus.db` (the multi-gigabyte
    /// FTS5 index) and `volumes/` live in the same directory.
    private func performSyncReset() {
        isResetting = true
        PendingStoreReset.request()
        // Onboarding is where the restore-in-progress state is explained, and the stores really are
        // about to be empty. Set here rather than at launch so the flag is durable if the user
        // quits from Settings.
        appState.hasCompletedOnboarding = false
        isResetting = false
        showRelaunchNotice = true
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

// MARK: - SchemaDeployStatusView

/// Settings → Data & Recovery → **iCloud Schema** — whether the iCloud container has been taught
/// about everything this version of the app can store (Wave R-7).
///
/// ## Why a screen and not a line
/// #488 shipped because nothing anywhere connected "sync stopped working" to "the schema was never
/// deployed". The row next door states the answer; this screen carries what a bug report needs:
/// which identifiers are outstanding, in CloudKit's own vocabulary, copyable in one tap. The
/// diagnosis that took a CloudKit Console session and a `git diff` becomes a paste.
///
/// ## Two audiences, in order
/// The first section is written for whoever opened it — a plain statement of what is or is not
/// happening to their data, with the honest "nothing you can do from here". The identifier list
/// and the deploy checklist come after, for the developer who receives the report. Nobody is
/// alarmed and nobody is patronised.
///
/// Version history:
///   1.0 — Wave R-7: initial implementation
struct SchemaDeployStatusView: View {

    /// Set briefly after a successful copy so the button can confirm.
    @State private var didCopy = false

    var body: some View {
        Form {
            Section {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "settings.dataRecovery.schema.about",
                            defaultValue: "About"))
            }

            Section {
                SettingsNavRow(
                    label: String(localized: "settings.dataRecovery.schema.state",
                                  defaultValue: "State"),
                    value: CloudKitSchemaInventory.isProductionSchemaCurrent
                        ? String(localized: "settings.dataRecovery.schema.value.current",
                                 defaultValue: "Up to date")
                        : String(localized: "settings.dataRecovery.schema.value.pending",
                                 defaultValue: "Update pending"))
                SettingsNavRow(
                    label: String(localized: "settings.dataRecovery.schema.lastPublished",
                                  defaultValue: "Last published"),
                    detail: String(localized: "settings.dataRecovery.schema.lastPublished.detail",
                                   defaultValue: "App version \(CloudKitSchemaInventory.deployedThroughBuild)"),
                    value: CloudKitSchemaInventory.deployedOn)
                SettingsNavRow(
                    label: String(localized: "settings.dataRecovery.schema.recordTypes",
                                  defaultValue: "Kinds of record"),
                    detail: String(localized: "settings.dataRecovery.schema.recordTypes.detail",
                                   defaultValue: "\(CloudKitSchemaInventory.fieldCount) fields across them"),
                    value: "\(CloudKitSchemaInventory.recordTypeCount)")
            } header: {
                Text(String(localized: "settings.dataRecovery.schema.status.header",
                            defaultValue: "Status"))
            }

            if !CloudKitSchemaInventory.isProductionSchemaCurrent {
                Section {
                    ForEach(CloudKitSchemaInventory.identifiersAwaitingDeploy, id: \.self) { id in
                        Text(id)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                } header: {
                    Text(String(localized: "settings.dataRecovery.schema.awaiting.header",
                                defaultValue: "Not Yet Published"))
                } footer: {
                    Text(String(localized: "settings.dataRecovery.schema.awaiting.footer",
                                defaultValue: "Records that use these will fail to upload until the developer publishes the schema update in the CloudKit Dashboard. Everything else syncs normally."))
                }
            }

            Section {
                Button {
                    copyReport()
                } label: {
                    Label(didCopy
                          ? String(localized: "settings.dataRecovery.schema.copied",
                                   defaultValue: "Copied")
                          : String(localized: "settings.dataRecovery.schema.copy",
                                   defaultValue: "Copy Report"),
                          systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
            } footer: {
                Text(String(localized: "settings.dataRecovery.schema.copy.footer",
                            defaultValue: "Paste this into a bug report alongside the Sync Log."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.dataRecovery.schema",
                                defaultValue: "iCloud Schema"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The plain-language paragraph, in the state it is actually in. Written for the person
    /// holding the device, not for the person who will fix it.
    private var explanation: String {
        if CloudKitSchemaInventory.isProductionSchemaCurrent {
            return String(localized: "settings.dataRecovery.schema.about.current",
                          defaultValue: "iCloud has to be told about each kind of record the app saves before it will accept one. Everything this version saves has been published, so nothing is being held back for this reason.")
        }
        return String(localized: "settings.dataRecovery.schema.about.pending",
                      defaultValue: "iCloud has to be told about each kind of record the app saves before it will accept one. Some additions in this version have not been published yet. Records that use them will not upload until they are. Everything else keeps syncing. This is a problem with the app, not with your account. There is nothing you can do here except report it.")
    }

    /// The copyable report: the state, the marker, and the outstanding identifiers. Only names
    /// this app defines — no user content, matching the sync log's redaction contract.
    private func reportText() -> String {
        var lines = [
            "FRUS Explorer — iCloud schema",
            "state: \(CloudKitSchemaInventory.isProductionSchemaCurrent ? "up to date" : "update pending")",
            "last published: build \(CloudKitSchemaInventory.deployedThroughBuild) (\(CloudKitSchemaInventory.deployedOn))",
            "record types: \(CloudKitSchemaInventory.recordTypeCount)",
            "fields: \(CloudKitSchemaInventory.fieldCount)",
        ]
        if !CloudKitSchemaInventory.isProductionSchemaCurrent {
            lines.append("awaiting deploy:")
            lines.append(contentsOf: CloudKitSchemaInventory.identifiersAwaitingDeploy
                .map { "  \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    /// Copies the report and flips the button label for a moment.
    private func copyReport() {
        let text = reportText()
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
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
                            defaultValue: "Every cross-reference in the printed FRUS volumes that points to a document, page, or volume the corpus does not contain. The list covers the whole corpus. The CSV names each broken target once, not once for every occurrence. A fuller spreadsheet, with one row per occurrence and its source line number, is produced by a separate tool rather than in the app."))
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
