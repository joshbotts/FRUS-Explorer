// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - SemanticModelSection

/// The storage hubs' query-encoder model section (V-5 s2) — download, progress, remove.
///
/// One shared view mounted by BOTH hand-maintained hub twins, for `SemanticStorageSection`'s
/// reason; a parity test pins the mounts and bans `settings.model.` strings from either hub.
///
/// ## The download button downloads
///
/// Through build 50 it presented a consent sheet instead: EmbeddingGemma 300m was provided under
/// the Gemma Terms of Use, whose use restrictions had to flow down to every reader, and pressing
/// Download in that sheet was the agreement. EmbeddingGemma 2 is licensed under Apache 2.0, which
/// has no restriction to flow down, so the sheet retired with the 300m (B4, the owner's decision of
/// 2026-10-15). Pressing the button is still the consent the #926 principle asks for, as Download
/// Missing Vectors is: the row states the size and that the model runs on this device before
/// anything is fetched.
///
/// Version history:
///   1.0 — V-5 s2
///   1.1 — B4 (#1659): the consent sheet retires, and the button downloads EmbeddingGemma 2
struct SemanticModelSection: View {

    @Environment(AppState.self) private var appState

    /// The model's current state. Reloaded on appearance and after any action that changes it.
    @State private var status: AppState.SemanticModelStatus = .unavailable
    /// Set while removal runs, so the button cannot be pressed twice.
    @State private var busy = false
    /// Bumped to re-run the loader after an action.
    @State private var reloadToken = 0

    var body: some View {
        Section {
            if status.isAvailable {
                if let progress = appState.semanticModelDownload {
                    progressRow(progress)
                } else if status.isPresent {
                    presentRow
                } else {
                    downloadButton
                }
                if let failure = status.failure {
                    failureRow(failure)
                }
                if status.isPresent {
                    modelPathRow
                    removeButton
                }
            } else {
                unavailableRow
            }
        } header: {
            Text(String(localized: "settings.model.header",
                        defaultValue: "Natural-Language Search"))
        } footer: {
            // Names the price, the standing, and whose model it is — the reader deciding whether
            // to spend 310 MB deserves all three in one place. "Experimental" is a finding, not
            // hedging, for the vectors footer's reason.
            Text(String(
                localized: "settings.model.footer",
                defaultValue: "Lets the app understand searches phrased as questions, using a language model that runs entirely on this device — Google’s EmbeddingGemma 2, an optional 310 MB download. The feature is experimental."))
        }
        .task(id: reloadToken) { await reload() }
    }

    // MARK: - Rows

    /// The verified model is on disk.
    private var presentRow: some View {
        SettingsNavRow(
            label: String(localized: "settings.model.present.label",
                          defaultValue: "Search Model"),
            systemImage: SemanticGlyph.feature,
            detail: String(
                format: String(localized: "settings.model.present.detail %@",
                               defaultValue: "Downloaded and verified — %@ on this device."),
                Self.bytes(status.bytesOnDisk))
        )
    }

    /// Starts the download; the progress row replaces it while the transfer runs.
    private var downloadButton: some View {
        Button {
            Task {
                await appState.downloadSemanticModel()
                reloadToken += 1
            }
        } label: {
            SettingsNavRow(
                label: String(localized: "settings.model.download.label",
                              defaultValue: "Download Search Model"),
                systemImage: "arrow.down.circle",
                detail: String(localized: "settings.model.download.detail",
                               defaultValue: "One 310 MB download. Runs on this device only; nothing you search leaves it.")
            )
        }
        .buttonStyle(.plain)
        .disabled(busy || !appState.isOnline)
    }

    /// BYTES, not a count — one large file, observable through the download delegate, the
    /// opposite trade from the shard rows and documented at `AppState.semanticModelDownload`.
    private func progressRow(_ progress: AppState.SemanticModelDownloadProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress.fraction) {
                Text(String(
                    format: String(localized: "settings.model.progress %@ %@",
                                   defaultValue: "Downloading — %@ of %@"),
                    Self.bytes(Int(progress.bytesReceived)),
                    Self.bytes(Int(progress.bytesExpected))))
            }
            Button(String(localized: "settings.model.cancel", defaultValue: "Stop")) {
                Task {
                    await appState.cancelSemanticModelDownload()
                    reloadToken += 1
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
    }

    /// The last failure, in the words `AppState.describeModelError` chose — one vocabulary for
    /// both hubs.
    private func failureRow(_ failure: String) -> some View {
        SettingsStatusRow(
            label: String(localized: "settings.model.failure.label", defaultValue: "Problem"),
            detail: failure,
            state: .warning
        )
    }

    /// Where the validated weights are, so they can be reused rather than re-downloaded.
    ///
    /// The app has already fetched this GGUF and checked it against the pinned length and SHA-256.
    /// A researcher pointing their own tooling at the corpus — the audience
    /// `Docs/Agentic-Analysis-Guide.md` §A.7 is written for — otherwise fetches 310 MB again and
    /// trusts a URL, when the copy on this disk is the one the app itself validated. Shown only
    /// when a verified copy is present, because a path to a file that failed its check is worse
    /// than no path.
    ///
    /// macOS gets Finder and the pasteboard; iOS gets the path read-only, since there is no route
    /// to the container from another process anyway.
    @ViewBuilder
    private var modelPathRow: some View {
        // From the status, never from the store. Reading the actor here was a strict-concurrency
        // warning AND two filesystem stats per body pass; `reload()` already awaits the same actor.
        if let url = status.verifiedURL {
            #if os(macOS)
            HStack {
                Text(String(localized: "settings.model.path.label", defaultValue: "Model File"))
                Spacer()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label(String(localized: "settings.model.path.reveal",
                                 defaultValue: "Show in Finder"),
                          systemImage: "folder")
                }
                .buttonStyle(.link)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path, forType: .string)
                } label: {
                    Label(String(localized: "settings.model.path.copy",
                                 defaultValue: "Copy Path"),
                          systemImage: "doc.on.doc")
                }
                .buttonStyle(.link)
            }
            #else
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "settings.model.path.label", defaultValue: "Model File"))
                Text(url.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            #endif
        }
    }

    /// Removes the model file. Non-destructive to everything else, and the copy says so.
    private var removeButton: some View {
        Button(role: .destructive) {
            Task {
                busy = true
                await appState.removeSemanticModel()
                reloadToken += 1
                busy = false
            }
        } label: {
            SettingsNavRow(
                label: String(localized: "settings.model.remove.label",
                              defaultValue: "Remove Search Model"),
                systemImage: "trash",
                detail: String(
                    format: String(localized: "settings.model.remove.detail %@",
                                   defaultValue: "Frees %@. Everything else — volumes, notes, keyword search — stays exactly as it is. You can download it again any time."),
                    Self.bytes(status.bytesOnDisk))
            )
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    /// Shown when the semantic stack never booted — a build state, not a library state.
    private var unavailableRow: some View {
        SettingsStatusRow(
            label: String(localized: "settings.model.unavailable.label",
                          defaultValue: "Not available"),
            detail: String(localized: "settings.model.unavailable.detail",
                           defaultValue: "This version of the app cannot use the search model. Nothing is wrong with your library."),
            state: .warning
        )
    }

    // MARK: - Loading

    private func reload() async {
        status = await appState.semanticModelStatus()
    }

    /// Human byte sizes, one formatter for every figure in this section.
    private static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
