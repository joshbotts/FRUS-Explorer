// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SyncDiagnosticsView

/// Settings screen that surfaces the local, redacted CloudKit sync-telemetry log (#188-C.1) so a
/// tester can read it, copy it, or export it to send to the developer — complementing the
/// server-side CloudKit Console logs. Everything shown is on the redaction allow-list: event
/// types, timing, and error codes only — never record identifiers, account identity, or content.
struct SyncDiagnosticsView: View {

    /// The human-readable log dump (env header + one line per event).
    @State private var text = ""
    /// Whether any events have been recorded (gates the copy / export / clear actions).
    @State private var hasEntries = false
    /// The exported text file's URL, for `ShareLink`.
    @State private var exportURL: URL?
    /// `true` until the first load completes.
    @State private var isLoading = true

    var body: some View {
        Form {
            Section {
                Text(String(localized: "settings.syncDiag.about",
                            defaultValue: "A local, on-device record of iCloud sync events. It contains no personal information and nothing about your documents — only event types, timing, and error codes. Export it to help diagnose sync problems."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.syncDiag.log.header", defaultValue: "Recent Sync Events")) {
                if isLoading {
                    HStack { ProgressView(); Spacer() }
                } else {
                    ScrollView {
                        Text(text)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 340)
                }
            }

            Section {
                #if os(iOS)
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label(String(localized: "settings.syncDiag.copy", defaultValue: "Copy to Clipboard"),
                          systemImage: "doc.on.doc")
                }
                .disabled(!hasEntries)
                #endif

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(String(localized: "settings.syncDiag.export", defaultValue: "Export…"),
                              systemImage: "square.and.arrow.up")
                    }
                    .disabled(!hasEntries)
                }

                Button(role: .destructive) {
                    Task {
                        await SyncDiagnosticsLog.shared.clear()
                        await reload()
                    }
                } label: {
                    Label(String(localized: "settings.syncDiag.clear", defaultValue: "Clear Log"),
                          systemImage: "trash")
                }
                .disabled(!hasEntries)
            }
        }
        .navigationTitle(String(localized: "settings.syncDiag.title", defaultValue: "Sync Diagnostics"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await reload() }
    }

    /// Reloads the log text, entry-presence flag, and export URL from the actor.
    private func reload() async {
        isLoading = true
        hasEntries = await !SyncDiagnosticsLog.shared.entries().isEmpty
        text = await SyncDiagnosticsLog.shared.formattedText()
        exportURL = await SyncDiagnosticsLog.shared.exportURL()
        isLoading = false
    }
}
