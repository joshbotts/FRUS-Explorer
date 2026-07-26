// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ResearchSessionsView

/// Settings → Research → Research Sessions — what the app records about your work, and control
/// over it.
///
/// ## Why this is its own pane
/// The "Log Research Sessions" switch used to be a section of the Notes pane. It landed there for
/// want of anywhere better — macOS's Notes pane was the only Research destination with room — and
/// it never belonged: the log is about documents opened and searches run, not about notes. The
/// giveaway was that `SettingsPane.notes` had to carry the keywords "logging", "sessions",
/// "history", "privacy" and "trail" so that a reader hunting for a recording switch could find a
/// pane called *Notes*.
///
/// With a viewer and a delete beside it, the switch is one of three rows that answer the same
/// question — what does this app keep about me, can I see it, can I get rid of it — and that is a
/// destination rather than a section.
///
/// ## Three sections, in the order the questions get asked
/// 1. **Recording** — the switch, and a plain statement of what goes into the log.
/// 2. **Recorded Activity** — how much there is, and a door to the whole thing.
/// 3. **Manage** — delete it.
///
/// Version history:
///   1.0 — initial implementation: the pane, the log viewer's first construction site, and the
///          first way to delete recorded sessions on either platform
struct ResearchSessionsView: View {

    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    /// Settings is a sibling window on macOS: the user can go on reading in the main window and
    /// come back, and the counts here would otherwise be whatever they were when the pane opened.
    @Environment(\.controlActiveState) private var controlActiveState
    #else
    @Environment(\.scenePhase) private var scenePhase
    #endif

    @AppStorage("researchSessionLoggingEnabled") private var loggingEnabled = true

    @State private var summary: ResearchSessionsSummary = .empty
    @State private var showsDeleteConfirmation = false
    @State private var showsLog = false

    var body: some View {
        Form {
            recordingSection
            recordedActivitySection
            manageSection
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.pane.researchSessions",
                                defaultValue: "Research Sessions"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .task { refresh() }
        #if os(macOS)
        .onChange(of: controlActiveState) { _, state in
            if state != .inactive { refresh() }
        }
        #else
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        #endif
        // The log is a sheet on macOS (the Settings window has no navigation chrome to push into)
        // and a push on iOS — the same split the Notes pane uses for its full note list.
        #if os(macOS)
        .sheet(isPresented: $showsLog, onDismiss: refresh) {
            VStack(spacing: 0) {
                SessionLogView()
                Divider()
                HStack {
                    Spacer()
                    Button(String(localized: "settings.sessions.done", defaultValue: "Done")) {
                        showsLog = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .frame(minWidth: 520, minHeight: 460)
        }
        #else
        .navigationDestination(isPresented: $showsLog) {
            SessionLogView().onDisappear { refresh() }
        }
        #endif
        .confirmationDialog(
            String(localized: "settings.sessions.delete.title",
                   defaultValue: "Delete Recorded Sessions?"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.sessions.delete.confirm",
                          defaultValue: "Delete"), role: .destructive) {
                ResearchSessionAdmin.deleteAll(context: modelContext)
                refresh()
            }
            Button(String(localized: "settings.sessions.delete.cancel",
                          defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "settings.sessions.delete.message %@",
                                       defaultValue: "%@ will be permanently deleted from this device and, if iCloud sync is on, from iCloud. Your notes, highlights, tags and collections are not affected."),
                        ResearchSessionsSummary.sessions(summary.sessionCount)))
        }
    }

    // MARK: - Sections

    private var recordingSection: some View {
        Section {
            Toggle(String(localized: "settings.notes.logging",
                          defaultValue: "Log Research Sessions"),
                   isOn: $loggingEnabled)
        } header: {
            Text(String(localized: "settings.sessions.recording.header",
                        defaultValue: "Recording"))
        } footer: {
            // What goes in the log, stated plainly — including the search text, which is the part
            // a reader would not guess and has the most right to know.
            //
            // Two keys, because the two platforms genuinely record different things: the only
            // `.searchSubmit` call site is `SearchViewModel.search()`, which is the iOS search
            // model. `MacSearchViewModel` has no logging call, so searches run in the macOS
            // Search window are never recorded. Sessions sync, though, so a Mac user WILL see
            // searches their iPhone recorded — which is why the Mac sentence says "not here"
            // rather than "not recorded". (Whether to close that gap is a separate decision:
            // doing it would start collecting search text on a platform that currently does not.)
            #if os(macOS)
            Text(String(localized: "settings.sessions.logging.footer.mac",
                        defaultValue: "Records the documents you open, grouped into sessions that end after 30 minutes of inactivity. Searches are recorded on iPhone and iPad but not here. Kept on this device and, if iCloud sync is on, in your private iCloud database. Turning it off stops new recording; sessions already recorded are kept until you delete them."))
            #else
            Text(String(localized: "settings.sessions.logging.footer",
                        defaultValue: "Records the documents you open and the text of the searches you run, grouped into sessions that end after 30 minutes of inactivity. Kept on this device and, if iCloud sync is on, in your private iCloud database. Turning it off stops new recording; sessions already recorded are kept until you delete them."))
            #endif
        }
    }

    @ViewBuilder
    private var recordedActivitySection: some View {
        Section {
            Button {
                showsLog = true
            } label: {
                HStack {
                    SettingsNavRow(
                        label: String(localized: "settings.sessions.log",
                                      defaultValue: "Session Log"),
                        detail: summary.text())
                    Spacer(minLength: 8)
                    // iOS draws no chevron here because this is a plain Button, not a
                    // NavigationLink — the push is driven by `showsLog` so both platforms share
                    // one control. So both platforms need the glyph.
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(summary.isEmpty)
        } header: {
            Text(String(localized: "settings.sessions.activity.header",
                        defaultValue: "Recorded Activity"))
        } footer: {
            if summary.isEmpty {
                // Fenced for the same reason the recording footer is: running a search records
                // nothing on macOS, so telling a Mac user to try one would be a promise the app
                // does not keep. The recording footer got this right and this one did not.
                #if os(macOS)
                Text(String(localized: "settings.sessions.activity.footer.empty.mac",
                            defaultValue: "Nothing has been recorded yet. Open a document and it will appear here."))
                #else
                Text(String(localized: "settings.sessions.activity.footer.empty",
                            defaultValue: "Nothing has been recorded yet. Open a document or run a search and it will appear here."))
                #endif
            } else {
                Text(String(localized: "settings.sessions.activity.footer",
                            defaultValue: "No other part of the app reads this log — it is groundwork for a research-trail view. It is here so that what is recorded is something you can look at."))
            }
        }
    }

    @ViewBuilder
    private var manageSection: some View {
        Section {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Text(String(localized: "settings.sessions.deleteAll",
                            defaultValue: "Delete Recorded Sessions…"))
                    .foregroundStyle(summary.isEmpty ? Color.secondary : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(summary.isEmpty)
        } header: {
            Text(String(localized: "settings.sessions.manage.header", defaultValue: "Manage"))
        } footer: {
            Text(String(localized: "settings.sessions.manage.footer",
                        defaultValue: "Deletes every recorded session and its events. Nothing else is touched — your notes, highlights, tags, collections and reading history are separate and stay put."))
        }
    }

    // MARK: - State

    private func refresh() {
        summary = ResearchSessionsSummary.fetch(from: modelContext)
    }
}
