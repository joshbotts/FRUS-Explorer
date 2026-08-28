// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SemanticModelSection

/// The storage hubs' query-encoder model section (V-5 s2) — download, progress, remove.
///
/// One shared view mounted by BOTH hand-maintained hub twins, for `SemanticStorageSection`'s
/// reason; a parity test pins the mounts and bans `settings.model.` strings from either hub.
///
/// ## The consent sheet is a licence surface, not chrome
///
/// The download button does not download. It presents a sheet carrying the sentence the Gemma
/// compliance runbook (§4) specifies — the model is Google's, provided under the Gemma Terms of
/// Use, and downloading is agreeing to use it consistently with them — with the Terms one tap
/// away. Pressing Download inside that sheet is the act of consent (the #926 principle), and
/// together with the custom App Store EULA it is the licence's required use-restriction flow-down.
/// Rewording this copy is a compliance change, not a copy edit.
///
/// Version history:
///   1.0 — V-5 s2
struct SemanticModelSection: View {

    @Environment(AppState.self) private var appState

    /// The model's current state. Reloaded on appearance and after any action that changes it.
    @State private var status: AppState.SemanticModelStatus = .unavailable
    /// Whether the consent sheet is up.
    @State private var showingConsent = false
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
                if status.isPresent { removeButton }
            } else {
                unavailableRow
            }
        } header: {
            Text(String(localized: "settings.model.header",
                        defaultValue: "Natural-Language Search"))
        } footer: {
            // Names the price, the standing, and whose model it is — the reader deciding whether
            // to spend 229 MB deserves all three in one place. "Experimental" is a finding, not
            // hedging, for the vectors footer's reason.
            Text(String(
                localized: "settings.model.footer",
                defaultValue: "Lets the app understand searches phrased as questions, using a language model that runs entirely on this device — Google's EmbeddingGemma, an optional 229 MB download. The feature is experimental. The model is provided under the Gemma Terms of Use; see About ▸ Legal for the terms."))
        }
        .task(id: reloadToken) { await reload() }
        .sheet(isPresented: $showingConsent) {
            SemanticModelConsentSheet {
                showingConsent = false
                Task {
                    await appState.downloadSemanticModel()
                    reloadToken += 1
                }
            } onCancel: {
                showingConsent = false
            }
        }
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

    /// Opens the consent sheet; the sheet's Download button does the downloading.
    private var downloadButton: some View {
        Button {
            showingConsent = true
        } label: {
            SettingsNavRow(
                label: String(localized: "settings.model.download.label",
                              defaultValue: "Download Search Model"),
                systemImage: "arrow.down.circle",
                detail: String(localized: "settings.model.download.detail",
                               defaultValue: "One 229 MB download. Runs on this device only; nothing you search leaves it.")
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

// MARK: - SemanticModelConsentSheet

/// The consent sheet the download button presents — the in-app half of the Gemma flow-down.
///
/// The sentence is the compliance runbook's (§4), verbatim in substance: whose model this is,
/// which terms govern it, and that downloading is agreeing. The Terms link opens the live page;
/// the bundled copy of the terms lives in About ▸ Legal, and the line below the buttons says so.
struct SemanticModelConsentSheet: View {

    /// Runs when the reader presses Download — the act of consent.
    let onDownload: () -> Void
    /// Runs when the reader declines.
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "settings.model.consent.title",
                        defaultValue: "Download Search Model"))
                .font(.title3.bold())
            Text(String(
                localized: "settings.model.consent.body",
                defaultValue: "This optional 229 MB download is Google's EmbeddingGemma model, provided under and subject to the Gemma Terms of Use, including its Prohibited Use Policy. By downloading it you agree to use it consistently with those terms."))
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: AboutLinks.gemmaTerms) {
                Link(String(localized: "settings.model.consent.terms",
                            defaultValue: "View the Gemma Terms of Use"),
                     destination: url)
            }
            Text(String(
                localized: "settings.model.consent.bundled",
                defaultValue: "A copy of the terms is also in About ▸ Legal ▸ Full Notices."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(String(localized: "settings.model.consent.cancel",
                              defaultValue: "Cancel"), role: .cancel) {
                    onCancel()
                }
                Spacer()
                Button {
                    onDownload()
                } label: {
                    Text(String(localized: "settings.model.consent.download",
                                defaultValue: "Agree and Download"))
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(24)
        #if os(macOS)
        .frame(minWidth: 420, maxWidth: 480)
        #endif
        .presentationDetents([.medium])
    }
}
