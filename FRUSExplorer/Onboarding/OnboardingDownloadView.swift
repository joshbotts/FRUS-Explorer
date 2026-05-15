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

/// Third step of onboarding: download confirmation and progress.
///
/// Shows selected volumes, total storage estimate, and a "Start Downloads" button.
/// Downloads are non-blocking — the "Continue" button is always enabled so the user
/// can proceed to project setup while downloads run in the background.
///
/// Version history:
///   1.0 — Session 10: initial implementation
@MainActor
struct OnboardingDownloadView: View {

    @Bindable var viewModel: OnboardingViewModel
    @Environment(AppState.self) private var appState

    @State private var downloadsEnqueued = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "onboarding.download.title",
                                    defaultValue: "Download Volumes"))
                            .font(.title.bold())
                        Text(String(localized: "onboarding.download.subtitle",
                                    defaultValue: "Selected volumes will be downloaded to your device for full-text search and browsing."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Storage summary
                    storageSummary

                    Divider()

                    // Volume list
                    selectedVolumeList

                    // Download queue status
                    if !appState.downloadQueue.isEmpty {
                        downloadQueueStatus
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            footerButtons
        }
    }

    // MARK: - Subviews

    private var storageSummary: some View {
        HStack(spacing: 16) {
            Image(systemName: "internaldrive")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "onboarding.download.storageEstimate",
                            defaultValue: "Estimated download size"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedBytes(viewModel.selectedBytes))
                    .font(.headline)
            }
            Spacer()
            Text(String(localized: "onboarding.download.volumeCount",
                        defaultValue: "\(viewModel.selectedVolumeIds.count) volumes"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var selectedVolumeList: some View {
        let allVolumes = viewModel.displayVolumes.filter { viewModel.selectedVolumeIds.contains($0.volumeId) }
        let newVolumes = viewModel.newlyAvailableVolumes.filter { viewModel.selectedVolumeIds.contains($0.filename) }

        VStack(alignment: .leading, spacing: 8) {
            if !newVolumes.isEmpty {
                Text(String(localized: "onboarding.download.newlyAvailable.header",
                            defaultValue: "Newly Available"))
                    .font(.headline)
                ForEach(newVolumes) { volume in
                    downloadRowNew(volume: volume)
                }
            }

            if !allVolumes.isEmpty {
                Text(String(localized: "onboarding.download.known.header",
                            defaultValue: "Selected Volumes"))
                    .font(.headline)
                ForEach(allVolumes) { volume in
                    downloadRowKnown(volume: volume)
                }
            }
        }
    }

    private func downloadRowKnown(volume: VolumeManifestEntry) -> some View {
        HStack(spacing: 12) {
            downloadStatusIcon(for: volume.volumeId)
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.title)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(formattedBytes(volume.sizeBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func downloadRowNew(volume: NewlyAvailableVolume) -> some View {
        HStack(spacing: 12) {
            downloadStatusIcon(for: volume.filename)
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.filename)
                    .font(.subheadline)
                Text(formattedBytes(volume.sizeBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func downloadStatusIcon(for volumeId: String) -> some View {
        if appState.downloadQueue.contains(volumeId) {
            return AnyView(
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 20, height: 20)
            )
        } else {
            return AnyView(
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            )
        }
    }

    private var downloadQueueStatus: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(String(localized: "onboarding.download.queue.status",
                        defaultValue: "\(appState.downloadQueue.count) downloads in progress"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var footerButtons: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.step = .volumePicker
            } label: {
                Text(String(localized: "onboarding.download.back", defaultValue: "Back"))
            }
            .buttonStyle(.bordered)

            Spacer()

            if !downloadsEnqueued {
                Button {
                    Task {
                        if let dm = appState.downloadManager {
                            await viewModel.enqueueSelectedDownloads(downloadManager: dm)
                            downloadsEnqueued = true
                        }
                    }
                } label: {
                    Text(String(localized: "onboarding.download.startDownloads",
                                defaultValue: "Start Downloads"))
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.downloadManager == nil)
            }

            Button {
                viewModel.step = .projectSetup
                #if DEBUG
                print("[Onboarding] Step: downloadConfirm → projectSetup")
                #endif
            } label: {
                Text(String(localized: "onboarding.download.continue", defaultValue: "Continue"))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(downloadsEnqueued ? .accentColor : .secondary)
        }
        .padding()
    }

    // MARK: - Helpers

    private func formattedBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
