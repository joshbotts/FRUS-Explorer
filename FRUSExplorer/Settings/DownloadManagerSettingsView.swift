// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

/// Settings panel for bulk-downloading volumes by scope.
///
/// Moved from onboarding in Session 49. Power users access this after initial
/// setup to download additional subseries or subject-tagged groups without going
/// through onboarding again.
///
/// ## Scope Options
/// - **Entire Corpus** — enqueues all known volumes.
/// - **By Subseries** — enqueues all volumes for one subseries.
/// - **By Subject Tag** — enqueues all volumes tagged with a specific subject tag.
/// - **Single Volume** — enqueues one volume by ID search.
///
/// Downloads are non-blocking: tapping "Download" returns immediately; progress is
/// visible in the "Active Downloads" section of Volume Management.
///
/// Version history:
///   1.0 — Session 49: initial implementation (extracted/expanded from old onboarding)
///   1.1 — Session 67: macOS scroll affordance — remove maxHeight: .infinity from Form
struct DownloadManagerSettingsView: View {

    @Environment(AppState.self) private var appState

    @State private var selectedScope: DownloadScope = .corpus
    @State private var selectedSubseries: String = ""
    @State private var selectedTagSlug: String = ""
    @State private var singleVolumeSearch: String = ""
    @State private var enqueuedMessage: String? = nil

    private var allSubseries: [String] {
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        let unique = Set(source.map(\.subseries))
        return unique.sorted { lhsYear(from: $0) > lhsYear(from: $1) }
    }

    private func lhsYear(from subseries: String) -> Int {
        Int(subseries.prefix(4)) ?? 0
    }

    private var allTagSlugs: [TagTaxonomyEntry] {
        appState.volumeLevelTagStore.allEntries
            .sorted { $0.displayName < $1.displayName }
    }

    private var singleVolumeResults: [VolumeManifestEntry] {
        let query = singleVolumeSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return source.filter {
            $0.title.lowercased().contains(lower) || $0.volumeId.lowercased().contains(lower)
        }.prefix(20).map { $0 }
    }

    private var canEnqueue: Bool {
        guard appState.downloadManager != nil else { return false }
        switch selectedScope {
        case .corpus:        return true
        case .subseries:     return !selectedSubseries.isEmpty
        case .volume(let id): return !id.isEmpty
        }
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.downloadManager.scope.header",
                           defaultValue: "Download Scope")) {
                Picker(
                    String(localized: "settings.downloadManager.scope.label",
                           defaultValue: "Scope"),
                    selection: Binding(
                        get: { scopePickerTag },
                        set: { tag in
                            switch tag {
                            case 0: selectedScope = .corpus
                            case 1: selectedScope = .subseries(selectedSubseries)
                            case 2: selectedScope = .volume(singleVolumeSearch.trimmingCharacters(in: .whitespacesAndNewlines))
                            default: break
                            }
                        }
                    )
                ) {
                    Text(String(localized: "settings.downloadManager.scope.corpus",
                                defaultValue: "Entire Corpus")).tag(0)
                    Text(String(localized: "settings.downloadManager.scope.subseries",
                                defaultValue: "By Subseries")).tag(1)
                    Text(String(localized: "settings.downloadManager.scope.volume",
                                defaultValue: "Single Volume")).tag(2)
                }

                if case .subseries = selectedScope {
                    Picker(
                        String(localized: "settings.downloadManager.subseries.label",
                               defaultValue: "Subseries"),
                        selection: $selectedSubseries
                    ) {
                        Text(String(localized: "settings.downloadManager.subseries.placeholder",
                                    defaultValue: "Select…")).tag("")
                        ForEach(allSubseries, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .onChange(of: selectedSubseries) { _, newValue in
                        selectedScope = .subseries(newValue)
                    }
                }

                if case .volume = selectedScope {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(
                            String(localized: "settings.downloadManager.volume.placeholder",
                                   defaultValue: "Title or volume ID…"),
                            text: $singleVolumeSearch
                        )
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onChange(of: singleVolumeSearch) { _, newValue in
                            selectedScope = .volume(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }

                    if !singleVolumeResults.isEmpty {
                        ForEach(singleVolumeResults) { entry in
                            Button {
                                singleVolumeSearch = entry.volumeId
                                selectedScope = .volume(entry.volumeId)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title).font(.callout).foregroundStyle(.primary).lineLimit(1)
                                        Text(entry.volumeId).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if case .volume(let id) = selectedScope, id == entry.volumeId {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section {
                Button {
                    enqueue()
                } label: {
                    Label(
                        String(localized: "settings.downloadManager.enqueue.button",
                               defaultValue: "Download"),
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(!canEnqueue)
                .accessibilityLabel(
                    String(localized: "settings.downloadManager.enqueue.a11y",
                           defaultValue: "Start downloading selected volumes")
                )

                if let msg = enqueuedMessage {
                    Label(msg, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            }

            Section {
                Text(String(localized: "settings.downloadManager.note",
                            defaultValue: "Downloads run in the background. Monitor progress in Volume Management → Active Downloads."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "settings.downloadManager.title",
                                defaultValue: "Download Manager"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
    }

    // MARK: - Helpers

    private var scopePickerTag: Int {
        switch selectedScope {
        case .corpus:    return 0
        case .subseries: return 1
        case .volume:    return 2
        }
    }

    private func enqueue() {
        guard let dm = appState.downloadManager else { return }
        enqueuedMessage = nil

        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        let toEnqueue: [VolumeManifestEntry]
        switch selectedScope {
        case .corpus:
            toEnqueue = source
        case .subseries(let id):
            toEnqueue = source.filter { $0.subseries == id }
        case .volume(let id):
            toEnqueue = source.filter { $0.volumeId == id }
        }

        Task {
            for entry in toEnqueue {
                let url = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(entry.filename)"
                await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: url)
            }
            await MainActor.run {
                let count = toEnqueue.count
                enqueuedMessage = String(
                    localized: "settings.downloadManager.enqueued",
                    defaultValue: "\(count) volume\(count == 1 ? "" : "s") queued for download.")
            }
            #if DEBUG
            print("[Settings] Download Manager enqueued \(toEnqueue.count) volumes.")
            #endif
        }
    }
}
