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
/// - Scope type picker (Volume / Subseries / User Tag / Saved Search / Date Range / My Volume Scopes)
/// - Scope detail control (volume selector, subseries selector, etc.)
/// - Prompt picker
/// - Start / Stop button
/// - Progress bar and status label
///
/// Designed to be embedded in a `List` or `Form` inside a Settings screen.
///
/// Version history:
///   1.0 — Session 21: initial implementation
///   1.1 — #367: "My Volume Scopes" scope — summarize a saved `CustomVolumeScope`'s
///          downloaded member volumes (a snapshot; summarization reads the TEI, not the
///          FTS index, so the gate is downloaded rather than indexed)
struct BackgroundSummarizationSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]
    @Query private var allTagAssignments: [DocumentTagAssignment]
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var allSavedSearches: [SavedSearch]
    @Query(sort: \CustomVolumeScope.name) private var allCustomScopes: [CustomVolumeScope]

    // MARK: - Scope State

    @State private var scopeType: ScopeType = .volume
    @State private var selectedVolumeId: String = ""
    @State private var selectedSubseries: String = ""
    @State private var selectedUserTagId: UUID? = nil
    @State private var selectedSavedSearchId: UUID? = nil
    @State private var selectedCustomScopeId: UUID? = nil
    @State private var dateRangeEarliest: String = ""
    @State private var dateRangeLatest: String = ""

    // MARK: - Prompt Selection

    @State private var selectedPromptId: UUID? = nil

    // MARK: - Concurrency

    @State private var concurrencyLimit: Int = 2

    /// iOS only: keep summarizing in the background (BGProcessingTask) after the app
    /// is suspended. Opt-in. Mirrors the key read by `BackgroundSummarizationRequestStore`.
    @AppStorage("frus.backgroundSummarization.continueInBackground")
    private var continueInBackground = false

    // MARK: - Body

    var body: some View {
        Group {
            scopeSection
            promptSection
            concurrencySection
            #if os(iOS)
            backgroundContinuationSection
            #endif
            controlSection
            progressSection
        }
    }

    #if os(iOS)
    // MARK: - Background Continuation Section

    @ViewBuilder
    private var backgroundContinuationSection: some View {
        Section {
            Toggle(String(localized: "bg.summarizer.continue.label",
                          defaultValue: "Continue in the background"),
                   isOn: $continueInBackground)
                .onChange(of: continueInBackground) { _, on in
                    if !on { BackgroundSummarizationRequestStore.clear() }
                }
        } footer: {
            Text(String(localized: "bg.summarizer.continue.hint",
                        defaultValue: "When on, summarization resumes opportunistically while the device is idle, a few documents at a time, even after you close the app. Uses the on-device model and some battery."))
        }
    }
    #endif

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
            case .userTag:
                userTagPicker
            case .savedSearch:
                savedSearchPicker
            case .dateRange:
                dateRangePickers
            case .customScope:
                customScopePicker
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
    private var userTagPicker: some View {
        if allUserTags.isEmpty {
            Text(String(localized: "bg.summarizer.scope.userTag.empty",
                        defaultValue: "No user tags created yet. Add tags to documents first."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker(
                String(localized: "bg.summarizer.scope.userTag.picker",
                       defaultValue: "Tag"),
                selection: $selectedUserTagId
            ) {
                Text(String(localized: "bg.summarizer.scope.userTag.none",
                            defaultValue: "Select a tag…"))
                    .tag(UUID?.none)
                ForEach(allUserTags) { tag in
                    Text(tag.name).tag(UUID?.some(tag.id))
                }
            }
            .onAppear {
                if selectedUserTagId == nil, let first = allUserTags.first {
                    selectedUserTagId = first.id
                }
            }
        }
    }

    @ViewBuilder
    private var savedSearchPicker: some View {
        if allSavedSearches.isEmpty {
            Text(String(localized: "bg.summarizer.scope.savedSearch.empty",
                        defaultValue: "No saved searches yet. Save a search first using the bookmark button in Search."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker(
                String(localized: "bg.summarizer.scope.savedSearch.picker",
                       defaultValue: "Search"),
                selection: $selectedSavedSearchId
            ) {
                Text(String(localized: "bg.summarizer.scope.savedSearch.none",
                            defaultValue: "Select a saved search…"))
                    .tag(UUID?.none)
                ForEach(allSavedSearches) { search in
                    Text(search.name).tag(UUID?.some(search.id))
                }
            }
            .onAppear {
                if selectedSavedSearchId == nil, let first = allSavedSearches.first {
                    selectedSavedSearchId = first.id
                }
            }
            if let id = selectedSavedSearchId,
               let search = allSavedSearches.first(where: { $0.id == id }),
               let kw = search.searchParameters.keywords, !kw.isEmpty {
                Text(kw)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
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

    @ViewBuilder
    private var customScopePicker: some View {
        if allCustomScopes.isEmpty {
            Text(String(localized: "bg.summarizer.scope.customScope.empty",
                        defaultValue: "No volume scopes yet. Create one in Settings → Volume Scopes."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker(
                String(localized: "bg.summarizer.scope.customScope.picker",
                       defaultValue: "Scope"),
                selection: $selectedCustomScopeId
            ) {
                Text(String(localized: "bg.summarizer.scope.customScope.none",
                            defaultValue: "Select a scope…"))
                    .tag(UUID?.none)
                ForEach(allCustomScopes) { scope in
                    Text(scope.name).tag(UUID?.some(scope.id))
                }
            }
            .onAppear {
                if selectedCustomScopeId == nil, let first = allCustomScopes.first {
                    selectedCustomScopeId = first.id
                }
            }
            // Honest "N of M downloaded" line: a run summarizes the DOWNLOADED members
            // (summarization reads the TEI, not the index), so a scope with none downloaded
            // can't start.
            if let scope = selectedCustomScope {
                let downloaded = selectedCustomScopeDownloadedIds.count
                if downloaded == 0 {
                    Text(String(localized: "bg.summarizer.scope.customScope.noneDownloaded",
                                defaultValue: "None of this scope's volumes are downloaded yet — download them first."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: String(
                        localized: "bg.summarizer.scope.customScope.downloaded %lld %lld",
                        defaultValue: "%lld of %lld volumes downloaded"),
                        Int64(downloaded), Int64(scope.volumeIds.count)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The currently-selected custom scope record, if any.
    private var selectedCustomScope: CustomVolumeScope? {
        guard let id = selectedCustomScopeId else { return nil }
        return allCustomScopes.first(where: { $0.id == id })
    }

    /// The DOWNLOADED member volume ids of the selected custom scope — the snapshot a
    /// `.customScope` run summarizes. Summarization parses each volume's TEI directly and
    /// never reads the FTS index, so the gate here is **downloaded**, not indexed —
    /// matching the sibling Volume/Subseries scopes in this picker (and deliberately unlike
    /// the FTS-grain "My Volume Scopes" surfaces in Search / Word Cloud / analytics, which
    /// gate on indexed because they query the index). Empty when nothing is selected or no
    /// member is downloaded; the service re-filters to downloaded at run time as well, so an
    /// all-un-downloaded scope safely enumerates nothing rather than inverting to the corpus.
    private var selectedCustomScopeDownloadedIds: Set<String> {
        guard let scope = selectedCustomScope else { return [] }
        return Set(scope.volumeIds).intersection(downloadedVolumeIdSet)
    }

    /// The ids of every currently-downloaded volume (the summarization gate).
    private var downloadedVolumeIdSet: Set<String> {
        Set(downloadedVolumes.map(\.volumeId))
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
                // Dim the label when Start is disabled (e.g. a custom scope with no indexed
                // members, #367) so an explicit accent tint doesn't make a disabled control
                // read as tappable.
                .foregroundStyle(isRunning ? .red : (canStart ? Color.accentColor : Color.secondary))
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
        case .volume:       return !selectedVolumeId.isEmpty
        case .subseries:    return !selectedSubseries.isEmpty
        case .userTag:      return selectedUserTagId != nil && !allUserTags.isEmpty
        case .savedSearch:  return selectedSavedSearchId != nil && !allSavedSearches.isEmpty
        case .dateRange:    return !dateRangeEarliest.isEmpty && !dateRangeLatest.isEmpty
        // Require at least one downloaded member — an all-un-downloaded scope would
        // enumerate nothing, so block Start (with the picker's "none downloaded" note)
        // rather than silently no-op the run.
        case .customScope:  return !selectedCustomScopeDownloadedIds.isEmpty
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

        let all = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        var urls: [String: URL] = [:]
        for entry in all where dm.isVolumeDownloaded(entry.volumeId) {
            urls[entry.volumeId] = dm.volumeURL(for: entry.volumeId)
        }

        let promptSnapshot = SummarizationPromptSnapshot(from: prompt)
        Task {
            // buildScope() is async because .savedSearch must execute the search
            // service to enumerate matching documents before the run starts.
            let scope = await buildScope()
            // Persist the run so the iOS BGProcessingTask can resume it after the
            // app is suspended (no-op unless "Continue in the background" is on).
            BackgroundSummarizationRequestStore.save(
                BackgroundSummarizationRequest(scope: scope, promptId: promptId))
            await service.start(
                scope: scope,
                promptSnapshot: promptSnapshot,
                provider: AppleIntelligenceProvider.shared,
                concurrencyLimit: concurrencyLimit,
                downloadedVolumeURLs: urls,
                manifestEntries: all,
                activeProjectId: appState.activeProjectId
            )
        }
    }

    private func stopSummarization() {
        // Also drop any persisted background run so it doesn't resume after stop.
        BackgroundSummarizationRequestStore.clear()
        guard let service = appState.backgroundSummarizationService else { return }
        Task { await service.stop() }
    }

    private func buildScope() async -> SummarizationScope {
        switch scopeType {
        case .volume:    return .volume(volumeId: selectedVolumeId)
        case .subseries: return .subseries(subseries: selectedSubseries)
        case .userTag:
            // Pre-compute "volumeId/documentId" keys from DocumentTagAssignment records.
            let keys: Set<String>
            if let tagId = selectedUserTagId {
                keys = Set(allTagAssignments
                    .filter { $0.tagId == tagId }
                    .map { "\($0.volumeId)/\($0.documentId)" })
            } else {
                keys = []
            }
            return .userTag(documentKeys: keys)
        case .savedSearch:
            // Execute the saved search now to enumerate matching documents.
            // This is the async step: the search service queries the FTS5 index.
            guard let searchId = selectedSavedSearchId,
                  let savedSearch = allSavedSearches.first(where: { $0.id == searchId }),
                  let searchService = appState.searchService else {
                return .savedSearch(documentKeys: [])
            }
            // Use a high explicit limit so the scope covers all matching documents,
            // not just the default page of 20. Saved-search summarization should
            // enqueue every document the query matches, not just the first page.
            let results = (try? await searchService.search(
                parameters: savedSearch.searchParameters,
                limit: 10_000)) ?? []
            let keys = Set(results.map { "\($0.volumeId)/\($0.documentId)" })
            #if DEBUG
            print("[BgSummarizer] Saved search '\(savedSearch.name)' resolved \(keys.count) documents")
            #endif
            return .savedSearch(documentKeys: keys)
        case .dateRange: return .dateRange(earliest: dateRangeEarliest, latest: dateRangeLatest)
        case .customScope:
            // Snapshot the scope's DOWNLOADED member ids now, so a persisted background run
            // stays self-contained and is unaffected by later edits or deletion of the scope
            // — the same pre-resolution userTag/savedSearch do. The service re-filters to
            // downloaded at run time as well, so a member deleted before a BGTask wake drops
            // out safely.
            return .customScope(volumeIds: selectedCustomScopeDownloadedIds)
        }
    }

    // MARK: - ScopeType

    private enum ScopeType: String, CaseIterable, Identifiable {
        case volume, subseries, userTag, savedSearch, dateRange, customScope
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .volume:       return String(localized: "bg.summarizer.scope.type.volume",      defaultValue: "Volume")
            case .subseries:    return String(localized: "bg.summarizer.scope.type.subseries",   defaultValue: "Subseries")
            case .userTag:      return String(localized: "bg.summarizer.scope.type.userTag",     defaultValue: "User Tag")
            case .savedSearch:  return String(localized: "bg.summarizer.scope.type.savedSearch", defaultValue: "Saved Search")
            case .dateRange:    return String(localized: "bg.summarizer.scope.type.dateRange",   defaultValue: "Date Range")
            case .customScope:  return String(localized: "bg.summarizer.scope.type.customScope", defaultValue: "My Volume Scopes")
            }
        }
    }
}
