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
///   1.1 — Wave R-1: the switch now gates reading history and search history as well as the
///          session log, so both recording footers were rewritten (new keys) to say so and to
///          warn that History and Recents drain when it is off; the Manage footer no longer
///          calls reading history "separate"; the `@AppStorage` key comes from `AppState`
///   1.2 — Wave R-4: iOS gained a `SearchHistoryEntry` writer, so the iOS recording footer
///          (new key `…trail.v2`) now names the Project Home surfaces that fill as a result —
///          Recently Read, Recent Searches, Documents Visited and Searches Run
///   1.3 — Wave R-2a: sessions are derived, not stored, so four pieces of copy stopped being
///          true and were replaced under **new keys** (`…trail.mac.v2`, `…trail.v3`,
///          `…activity.footer.derived`, `…manage.footer.whole`, `…delete.message.trail`):
///          the recording footers now name exports as well, the activity footer no longer says
///          "no other part of the app reads this log", and — the load-bearing one — the delete
///          reaches the **whole** trail (`HistoryTrailAdmin.deleteAll`) instead of the retired
///          session tables, so the warning had to grow to match. The macOS empty-state fence is
///          gone: it existed because macOS wrote no `.searchSubmit` event
///   1.4 — Wave R-2a review fixes: the delete confirmation quotes the **exact** activity count
///          (`…delete.message.trail.v2`) instead of a session count derived from a 1,000-activity
///          scan, which understated an unbounded delete by 10–20×
struct ResearchSessionsView: View {

    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    /// Settings is a sibling window on macOS: the user can go on reading in the main window and
    /// come back, and the counts here would otherwise be whatever they were when the pane opened.
    @Environment(\.controlActiveState) private var controlActiveState
    #else
    @Environment(\.scenePhase) private var scenePhase
    #endif

    /// The one switch. Bound to the key `AppState` owns so the string is written down once
    /// (Wave R-1) — and so it stays obvious that this control now governs three writers, not one.
    @AppStorage(AppState.researchLoggingPreferenceKey) private var loggingEnabled = true

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
                // Wave R-2a: the whole trail, not just the retired session tables. Sessions are
                // derived from these rows now, so a delete that spared them would leave every
                // session the dialog just counted still on screen.
                HistoryTrailAdmin.deleteAll(context: modelContext)
                refresh()
            }
            Button(String(localized: "settings.sessions.delete.cancel",
                          defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            // New key again (`…message.trail.v2`), because the magnitude changed and the sentence
            // with it. `…message.trail` quoted `summary.sessionCount`, which is derived from a
            // 1,000-activity scan while `deleteAll` is unbounded: a measured run announced "1000
            // sessions" and destroyed 1,200 of them. The activity count is three `fetchCount`s and
            // is therefore exact at any size, so that is what an irreversible, CloudKit-propagating
            // delete is allowed to promise. No String Catalog ships, so rewriting the old key's
            // text in place would be a silent collision.
            Text(String(format: String(localized: "settings.sessions.delete.message.trail.v2 %@",
                                       defaultValue: "%@ will be permanently deleted from this device. If iCloud sync is on, the same records go from iCloud too. A session is made of every document you opened, every search you ran, and every collection you exported. Your notes, highlights, tags, and collections are not affected."),
                        ResearchSessionsSummary.events(summary.eventCount)))
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
            // The label stays "Log Research Sessions" (owner decision, Wave R-0 Q3), so it does
            // not hint that the switch also governs reading history, search history and exports.
            // It governs all three: since Wave R-1 `DocumentViewModel.recordReadingHistory` and
            // both `recordSearchHistory` writers consult `AppState.isResearchLoggingEnabled`, and
            // since Wave R-2a so does `ExportHistoryRecorder`. The whole explanatory burden
            // therefore lands here, and the footer has to carry the behaviour change too: turning
            // the switch off drains History and the Project Home recents, because those surfaces
            // are fed by the store now gated.
            //
            // Still two keys, because the two platforms *name* their surfaces differently — macOS
            // has the History window and Recents, iOS has the History screen and Project Home's
            // cards and tiles. Both texts got new keys again in R-2a (`…mac.v2`, `…v3`) rather
            // than being rewritten in place: there is no String Catalog, so reusing a key with
            // different text is a silent collision.
            //
            // What is no longer different is the substance. Before R-2a the two platforms wrote
            // *different stores* for a search, so which surface emptied depended on the device;
            // now there is one record of each kind and one sentence describing it.
            #if os(macOS)
            Text(String(localized: "settings.sessions.logging.footer.trail.mac.v2",
                        defaultValue: "Despite the name, this switch covers everything the app remembers about your work. That means the documents you open, the text of the searches you run, and the collections you export. The app keeps one record of each. The History window, a project's Recents, and the Session Log all read those same records. The Session Log groups them into sessions, and a session ends after 30 minutes of inactivity. The records stay on this device, and in your private iCloud database if iCloud sync is on. Turn the switch off and all of that recording stops. History and Recents will thin out and eventually be empty. That is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it."))
            #else
            Text(String(localized: "settings.sessions.logging.footer.trail.v3",
                        defaultValue: "Despite the name, this switch covers everything the app remembers about your work. That means the documents you open, the text of the searches you run, and the collections you export. The app keeps one record of each. The History screen, a project's Recently Read and Recent Searches cards, its Documents Visited and Searches Run counts, and the Session Log all read those same records. The Session Log groups them into sessions, and a session ends after 30 minutes of inactivity. The records stay on this device, and in your private iCloud database if iCloud sync is on. Turn the switch off and all of that recording stops. Those surfaces will thin out and eventually be empty. That is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it."))
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
                // One key on both platforms since Wave R-2a. The macOS variant existed because
                // the session log read `SessionEvent`, which macOS never wrote for a search — so
                // "run a search" would have been a promise the Mac did not keep. The log is
                // derived from `SearchHistoryEntry` now, of which macOS has always been a
                // producer, so the sentence is true on both and the fence is gone.
                Text(String(localized: "settings.sessions.activity.footer.empty",
                            defaultValue: "Nothing has been recorded yet. Open a document or run a search and it will appear here."))
            } else {
                // New key (`…footer.derived`). The old text said "no other part of the app reads
                // this log", which was true of the `SessionEvent` store and is false of what the
                // log now reads: the same reading, search and export history the History surface
                // and Project Home are built from.
                Text(String(localized: "settings.sessions.activity.footer.derived",
                            defaultValue: "The app does not store sessions. It works them out from the times you opened documents, ran searches, and exported collections. A gap of 30 minutes starts a new session. The same records fill the History screen and a project's Recents."))
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
            // Reworded again for Wave R-2a, under a new key (`…footer.whole`). R-1's text said
            // this button "does not reach" the reading and search history. It does now: sessions
            // are derived from that history, so deleting sessions *is* deleting it. The gap R-1
            // had to be honest about is closed, and the copy has to say so or it under-warns
            // about a destructive action.
            Text(String(localized: "settings.sessions.manage.footer.whole",
                        defaultValue: "This deletes the whole record of your work: every document you opened, every search you ran, and every collection you exported. It goes from this device, and from your iCloud database if iCloud sync is on. Your notes, highlights, tags, and collections are not touched. To delete single entries instead, use the History screen."))
        }
    }

    // MARK: - State

    private func refresh() {
        summary = ResearchSessionsSummary.fetch(from: modelContext)
    }
}
