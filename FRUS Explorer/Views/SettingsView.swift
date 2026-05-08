// Views/SettingsView.swift
// Application settings: catalogue management, storage, AI summaries, caches, and about.
// Presented as a macOS Settings window (Cmd+,) or an iPadOS tab.

import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(SummaryStore.self) private var summaryStore

    @State private var confirmDeleteAll = false
    @State private var confirmPurgeAllSummaries = false

    var body: some View {
        Form {
            catalogueSection
            storageSection
            summariesSection
            cachesSection
            aboutSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
#if os(macOS)
        .frame(width: 460)
#endif
    }

    // MARK: - Catalogue

    private var catalogueSection: some View {
        Section {
            // Connection status
            LabeledContent("Connection") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isOnline ? Color.frusRuby : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(store.isOnline ? "Online" : "Offline")
                        .foregroundStyle(.secondary)
                }
            }

            // Refresh catalogue
            if store.catalogueState == .loading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.75)
                    Text("Checking for new volumes…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Task { await store.loadCatalogue() }
                } label: {
                    Label("Check for New Volumes", systemImage: "arrow.clockwise")
                }
                .disabled(!store.isOnline)
            }

            // Concurrent download limit
            Stepper(
                "Simultaneous Downloads: \(store.maxConcurrentDownloads)",
                value: Binding(
                    get: { store.maxConcurrentDownloads },
                    set: { store.setMaxConcurrentDownloads($0) }
                ),
                in: 1...8
            )

        } header: {
            Text("Catalogue")
        } footer: {
            Text("Higher simultaneous download counts are faster but use more bandwidth and may hit GitHub API limits.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section("Storage") {
            let usage = store.localDiskUsage

            LabeledContent("Downloaded Volumes") {
                Text("\(usage.count) volume\(usage.count == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: usage.bytes, countStyle: .file))")
                    .foregroundStyle(.secondary)
            }

            // Re-index all
            if store.isReindexingAll {
                let (current, total) = store.reindexAllProgress
                HStack(spacing: 10) {
                    ProgressView(value: total > 0 ? Double(current) / Double(total) : 0)
                        .progressViewStyle(.linear)
                    Text("\(current) / \(total)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Task { await store.reindexAllDownloadedVolumes() }
                } label: {
                    Label("Re-index All Downloaded Volumes", systemImage: "arrow.clockwise.circle")
                }
                .disabled(store.localVolumeIDs.isEmpty)
            }

            // Delete all
            Button(role: .destructive) {
                confirmDeleteAll = true
            } label: {
                Label("Delete All Downloaded Volumes…", systemImage: "trash")
            }
            .disabled(store.localVolumeIDs.isEmpty)
            .confirmationDialog(
                "Delete All Downloaded Volumes?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                let n = store.localVolumeIDs.count
                Button("Delete \(n) Volume\(n == 1 ? "" : "s")", role: .destructive) {
                    for id in store.localVolumeIDs {
                        store.deleteVolume(id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let n = store.localVolumeIDs.count
                Text("This removes \(n) volume\(n == 1 ? "" : "s") from your device. They can be re-downloaded from the catalogue at any time.")
            }
        }
    }

    // MARK: - AI Summaries

    private var summariesSection: some View {
        Section {
            let count = summaryStore.records.count
            LabeledContent("Stored Summaries") {
                Text(count == 0
                     ? "None"
                     : "\(count) across \(summaryStore.profileStats.count) profile\(summaryStore.profileStats.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                confirmPurgeAllSummaries = true
            } label: {
                Label("Purge All Summaries…", systemImage: "wand.and.rays.inverse")
            }
            .disabled(count == 0)
            .confirmationDialog(
                "Purge All AI Summaries?",
                isPresented: $confirmPurgeAllSummaries,
                titleVisibility: .visible
            ) {
                Button("Purge All", role: .destructive) {
                    summaryStore.purgeAll()
                    store.clearSummaryCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all \(summaryStore.records.count) stored summaries across every profile. Summaries are regenerated on demand when you view documents.")
            }
        } header: {
            Text("AI Summaries")
        } footer: {
            Text("Per-profile summary management is available in the Research tab.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Caches

    private var cachesSection: some View {
        Section {
            Button {
                store.clearLoadedVolumes()
            } label: {
                Label("Clear In-Memory Volume Data", systemImage: "memorychip")
            }
            .disabled(store.loadedVolumes.isEmpty)

            Button {
                store.clearTitleCache()
            } label: {
                Label("Clear Volume Title Cache", systemImage: "textformat.characters")
            }
            .disabled(store.volumeTitleCache.isEmpty)
        } header: {
            Text("Caches")
        } footer: {
            Text("Clearing in-memory data frees RAM; volumes reload from disk on next use. The title cache is rebuilt automatically when volumes are next parsed.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            LabeledContent("Build") {
                Text(appBuild)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Link(destination: URL(string: "https://history.state.gov/historicaldocuments")!) {
                Label("history.state.gov", systemImage: "arrow.up.right.square")
            }
            Link(destination: URL(string: "https://github.com/HistoryAtState/frus")!) {
                Label("FRUS Source Repository on GitHub", systemImage: "arrow.up.right.square")
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
