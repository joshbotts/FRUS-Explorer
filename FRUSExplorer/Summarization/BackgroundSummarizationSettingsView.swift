// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - BackgroundSummarizationSettingsView

/// Settings section for configuring and running background summarization.
///
/// ## Layout
/// - Scope type picker (Volume / Subseries / Subject Tag / Date Range)
/// - Scope detail control (volume selector, subseries selector, etc.)
/// - Prompt picker
/// - Start / Stop button
/// - Progress bar and status label
///
/// Designed to be embedded in a `List` or `Form` inside a Settings screen.
///
/// Version history:
///   1.0 — Session 21: initial implementation
struct BackgroundSummarizationSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    // MARK: - Scope State

    @State private var scopeType: ScopeType = .volume
    @State private var selectedVolumeId: String = ""
    @State private var selectedSubseries: String = ""
    @State private var selectedSubjectId: String = ""
    @State private var dateRangeEarliest: String = ""
    @State private var dateRangeLatest: String = ""

    // MARK: - Prompt Selection

    @State private var selectedPromptId: UUID? = nil

    // MARK: - Concurrency

    @State private var concurrencyLimit: Int = 2

    // MARK: - Body

    var body: some View {
        Group {
            scopeSection
            promptSection
            concurrencySection
            controlSection
            progressSection
        }
    }

    // MARK: - Scope Section

    @ViewBuilder
    private var scopeSection: some View {
        Section(String(localized: "bg.summarizer.scope.header", defaultValue: "Scope")) {
            Picker(
                String(localized: "bg.summarizer.scope.type.label", defaultValue: "Summarize"),
                selection: $scopeType
            ) {
                ForEach(ScopeType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            switch scopeType {
            case .volume:
                volumePicker
            case .subseries:
                subsiesPicker
            case .subjectTag:
                subjectTagPicker
            case .dateRange:
                dateRangePickers
            }
        }
    }

    @ViewBuilder
    private var volumePicker: some View {
        let volumes = downloadedVolumes
        if volumes.isEmpty {
            Text(String(localized: "bg.summarizer.scope.volume.empty",
                        defaultValue: "No downloaded volumes."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker(
                String(localized: "bg.summarizer.scope.volume.picker",
                       defaultValue: "Volume"),
                selection: $selectedVolumeId
            ) {
                ForEach(volumes, id: \.volumeId) { v in
                    Text(v.title).tag(v.volumeId)
                }
            }
            .onAppear {
                if selectedVolumeId.isEmpty, let first = volumes.first {
                    selectedVolumeId = first.volumeId
                }
            }
        }
    }

    @ViewBuilder
    private var subsiesPicker: some View {
        let options = availableSubseries
        if options.isEmpty {
            Text(String(localized: "bg.summarizer.scope.subseries.empty",
                        defaultValue: "No downloaded volumes."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker(
                String(localized: "bg.summarizer.scope.subseries.picker",
                       defaultValue: "Subseries"),
                selection: $selectedSubseries
            ) {
                ForEach(options, id: \.self) { sub in
                    Text(sub).tag(sub)
                }
            }
            .onAppear {
                if selectedSubseries.isEmpty, let first = options.first {
                    selectedSubseries = first
                }
            }
        }
    }

    @ViewBuilder
    private var subjectTagPicker: some View {
        TextField(
            String(localized: "bg.summarizer.scope.tag.placeholder",
                   defaultValue: "Subject ID (e.g. s_berlin_crisis)"),
            text: $selectedSubjectId
        )
        .autocorrectionDisabled()
        #if os(iOS)
        .textInputAutocapitalization(.never)
        #endif
    }

    @ViewBuilder
    private var dateRangePickers: some View {
        HStack {
            TextField(
                String(localized: "bg.summarizer.scope.dateRange.earliest",
                       defaultValue: "Earliest (YYYY)"),
                text: $dateRangeEarliest
            )
            #if os(iOS)
            .keyboardType(.numbersAndPunctuation)
            #endif
            Text("–").foregroundStyle(.secondary)
            TextField(
                String(localized: "bg.summarizer.scope.dateRange.latest",
                       defaultValue: "Latest (YYYY)"),
                text: $dateRangeLatest
            )
            #if os(iOS)
            .keyboardType(.numbersAndPunctuation)
            #endif
        }
    }

    // MARK: - Prompt Section

    @ViewBuilder
    private var promptSection: some View {
        Section(String(localized: "bg.summarizer.prompt.header", defaultValue: "Prompt")) {
            if allPrompts.isEmpty {
                Text(String(localized: "bg.summarizer.prompt.empty",
                            defaultValue: "No prompts available. Create one in Summarization Prompts."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                Picker(
                    String(localized: "bg.summarizer.prompt.picker.label", defaultValue: "Prompt"),
                    selection: $selectedPromptId
                ) {
                    ForEach(allPrompts) { prompt in
                        Text(prompt.name).tag(Optional(prompt.id))
                    }
                }
                .onAppear {
                    if selectedPromptId == nil {
                        selectedPromptId = allPrompts.first?.id
                    }
                }
            }
        }
    }

    // MARK: - Concurrency Section

    @ViewBuilder
    private var concurrencySection: some View {
        Section(String(localized: "bg.summarizer.concurrency.header",
                       defaultValue: "Concurrency")) {
            Stepper(
                String(localized: "bg.summarizer.concurrency.label",
                       defaultValue: "\(concurrencyLimit) parallel document\(concurrencyLimit == 1 ? "" : "s")"),
                value: $concurrencyLimit,
                in: 1...6
            )
            Text(String(localized: "bg.summarizer.concurrency.hint",
                        defaultValue: "Higher values summarize faster but may exceed the model's rate limit."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Control Section

    @ViewBuilder
    private var controlSection: some View {
        let isRunning = appState.backgroundSummarizationProgress.state.isRunning

        Section {
            Button {
                if isRunning {
                    stopSummarization()
                } else {
                    startSummarization()
                }
            } label: {
                Label(
                    isRunning
                        ? String(localized: "bg.summarizer.control.stop", defaultValue: "Stop")
                        : String(localized: "bg.summarizer.control.start", defaultValue: "Start"),
                    systemImage: isRunning ? "stop.fill" : "play.fill"
                )
                .foregroundStyle(isRunning ? .red : .accentColor)
            }
            .disabled(!canStart && !isRunning)
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private var progressSection: some View {
        let state = appState.backgroundSummarizationProgress.state
        if state != .idle {
            Section(String(localized: "bg.summarizer.progress.header", defaultValue: "Progress")) {
                progressContent(state: state)
            }
        }
    }

    @ViewBuilder
    private func progressContent(state: BackgroundSummarizationState) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case .running(let processed, let total, let docId):
            VStack(alignment: .leading, spacing: 6) {
                if total > 0 {
                    ProgressView(value: Double(processed), total: Double(total))
                } else {
                    ProgressView()
                }
                Text(progressLabel(processed: processed, total: total, currentId: docId))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        case .completed(let processed):
            Label(
                String(localized: "bg.summarizer.progress.completed",
                       defaultValue: "Completed — \(processed) document\(processed == 1 ? "" : "s") summarized"),
                systemImage: "checkmark.circle"
            )
            .foregroundStyle(.green)
            .font(.callout)
        case .cancelled:
            Label(
                String(localized: "bg.summarizer.progress.cancelled", defaultValue: "Cancelled"),
                systemImage: "xmark.circle"
            )
            .foregroundStyle(.secondary)
            .font(.callout)
        case .failed(let desc):
            Label(desc, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - Helpers

    private var downloadedVolumes: [VolumeManifestEntry] {
        guard let dm = appState.downloadManager else { return [] }
        let all = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return all.filter { dm.isVolumeDownloaded($0.volumeId) }
    }

    private var availableSubseries: [String] {
        let seen = Set(downloadedVolumes.map(\.subseries))
        return seen.sorted()
    }

    private var canStart: Bool {
        guard !allPrompts.isEmpty, selectedPromptId != nil else { return false }
        switch scopeType {
        case .volume:      return !selectedVolumeId.isEmpty
        case .subseries:   return !selectedSubseries.isEmpty
        case .subjectTag:  return !selectedSubjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .dateRange:   return !dateRangeEarliest.isEmpty && !dateRangeLatest.isEmpty
        }
    }

    private func progressLabel(processed: Int, total: Int, currentId: String?) -> String {
        if total == 0 {
            return String(localized: "bg.summarizer.progress.enumerating",
                          defaultValue: "Enumerating documents…")
        }
        let base = "\(processed) / \(total)"
        if let id = currentId {
            return "\(base) — \(id)"
        }
        return base
    }

    private func startSummarization() {
        guard let service = appState.backgroundSummarizationService,
              let promptId = selectedPromptId,
              let prompt = allPrompts.first(where: { $0.id == promptId }),
              let dm = appState.downloadManager else { return }

        let scope = buildScope()
        let all = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        var urls: [String: URL] = [:]
        for entry in all where dm.isVolumeDownloaded(entry.volumeId) {
            urls[entry.volumeId] = dm.volumeURL(for: entry.volumeId)
        }

        let promptSnapshot = SummarizationPromptSnapshot(from: prompt)
        Task {
            await service.start(
                scope: scope,
                promptSnapshot: promptSnapshot,
                provider: AppleIntelligenceProvider.shared,
                concurrencyLimit: concurrencyLimit,
                downloadedVolumeURLs: urls,
                manifestEntries: all,
                subjectTagStore: appState.subjectTagStore,
                activeProjectId: appState.activeProjectId
            )
        }
    }

    private func stopSummarization() {
        guard let service = appState.backgroundSummarizationService else { return }
        Task { await service.stop() }
    }

    private func buildScope() -> SummarizationScope {
        switch scopeType {
        case .volume:    return .volume(volumeId: selectedVolumeId)
        case .subseries: return .subseries(subseries: selectedSubseries)
        case .subjectTag: return .subjectTag(subjectId: selectedSubjectId.trimmingCharacters(in: .whitespacesAndNewlines))
        case .dateRange: return .dateRange(earliest: dateRangeEarliest, latest: dateRangeLatest)
        }
    }

    // MARK: - ScopeType

    private enum ScopeType: String, CaseIterable, Identifiable {
        case volume, subseries, subjectTag, dateRange
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .volume:     return String(localized: "bg.summarizer.scope.type.volume",     defaultValue: "Volume")
            case .subseries:  return String(localized: "bg.summarizer.scope.type.subseries",  defaultValue: "Subseries")
            case .subjectTag: return String(localized: "bg.summarizer.scope.type.tag",        defaultValue: "Subject Tag")
            case .dateRange:  return String(localized: "bg.summarizer.scope.type.dateRange",  defaultValue: "Date Range")
            }
        }
    }
}
