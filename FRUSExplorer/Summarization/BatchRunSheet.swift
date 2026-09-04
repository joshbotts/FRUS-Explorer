// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - BatchRunSheet

/// The batch summarization run form, as its own sheet (S-3d).
///
/// ## What changed
/// `BackgroundSummarizationSettingsView` — six section groups covering scope, prompt, concurrency,
/// background continuation, start/stop and live progress — used to be **embedded** at the bottom of
/// the Summarization pane, below the prompt lists. On iOS it was nested inside another `Section`,
/// which is malformed: a `Section` emitting `Section`s. The practical effect was that the pane had
/// two jobs and you had to scroll past one to reach the other, and that a running batch's progress
/// ticks re-rendered the prompt list along with everything else on the screen.
///
/// The pane now keeps one job — prompts — and the run is a door: "New Batch Run…" opens this. The
/// form itself is unchanged and still shared by both platforms; only its presentation moved.
///
/// ## Dismissal is not cancellation
/// Closing the sheet does not stop a run. The run is owned by `BackgroundSummarizationService` and
/// continues; the pane's "Last run" row is where its outcome shows up. The footer says so, because
/// a sheet that looks like a modal task usually *is* one and this one is not.
///
/// Version history:
///   1.0 — S-3d: initial implementation
struct BatchRunSheet: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        String(localized: "settings.summarization.runSheet.title", defaultValue: "New Batch Run")
    }

    private var footer: String {
        String(localized: "settings.summarization.runSheet.footer",
               defaultValue: "Closing this doesn’t stop a run. Progress and the result appear on the Summarization screen.")
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    #if os(macOS)
    /// Header + form + bottom bar — the repo's macOS sheet idiom (no `NavigationStack` in a sheet).
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(footer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form { BackgroundSummarizationSettingsView() }
                .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "settings.summarization.runSheet.done",
                              defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 520)
        .environment(appState)
    }
    #else
    private var iOSBody: some View {
        NavigationStack {
            Form {
                BackgroundSummarizationSettingsView()
                Section {
                    EmptyView()
                } footer: {
                    Text(footer)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // Applied to the sheet's own body, NOT to the embedded settings view: that is a Group
            // of six Sections, and a Group replicates its modifiers per child — six Done buttons,
            // and it would compile.
            .keyboardDismissBar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.summarization.runSheet.done",
                                  defaultValue: "Done")) { dismiss() }
                }
            }
        }
        .environment(appState)
    }
    #endif
}
