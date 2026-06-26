// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftData
import SwiftUI

/// Presentation mode for the word cloud.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
enum WordCloudViewMode: String, CaseIterable {
    /// Spiral tag cloud.
    case cloud
    /// Ranked term/count list (also the accessibility representation of the cloud).
    case list

    /// Localised toolbar label.
    var label: String {
        switch self {
        case .cloud: return String(localized: "wordcloud.mode.cloud", defaultValue: "Cloud")
        case .list:  return String(localized: "wordcloud.mode.list", defaultValue: "List")
        }
    }

    /// SF Symbol for the segmented control.
    var systemImage: String {
        switch self {
        case .cloud: return "cloud"
        case .list:  return "list.number"
        }
    }
}

/// Observable progress holder for long-running (corpus/subseries) computation.
///
/// Main-actor isolated so the service's `@Sendable` progress callback can update
/// it from a hop to the main actor and SwiftUI observes the change.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 3 progress reporting
@MainActor @Observable final class WordCloudProgressModel {
    /// Fraction complete in `0...1`, or `nil` when indeterminate / idle.
    var fraction: Double?
}

/// Displays a word cloud for a `WordCloudScope` — the most frequent meaningful
/// terms across the document(s) the scope resolves to.
///
/// Two modes share one data set: a spiral tag **cloud** (font size ∝ √count) and
/// a ranked **list**. The list doubles as the cloud's `accessibilityRepresentation`,
/// since a scattered cloud is opaque to VoiceOver. Tapping any term hands off to
/// Search via `pendingSearch`. The view can be exported as PNG, PDF, or CSV.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudView: View {

    /// The body of material to visualise.
    let scope: WordCloudScope

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Excludes FRUS-boilerplate words ("telegram", "department", …) in addition
    /// to the always-on English stopwords. Persisted; defaults on.
    @AppStorage("frus.wordcloud.excludeBoilerplate") private var excludeBoilerplate = true

    @State private var viewMode: WordCloudViewMode = .cloud
    @State private var result: WordCloudResult = .empty
    @State private var title: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var placements: [PlacedWord] = []
    @State private var loadTask: Task<Void, Never>?
    @State private var exportItem: WordCloudExportItem?
    @State private var progressModel = WordCloudProgressModel()
    @State private var hiddenWords: Set<String> = []
    @State private var comparisonScope: WordCloudScope?

    @Query(sort: \Collection.name) private var collections: [Collection]
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    /// Maximum terms requested from the service (the cloud places a subset).
    /// Shared with the background precompute so their cache keys match.
    private static let termLimit = WordCloudLoader.standardTermLimit

    /// Colour palette — all system colours so the cloud adapts to light/dark mode.
    private static let palette: [Color] = [
        .blue, .teal, .indigo, .purple, .pink, .orange, .green, .red, .cyan, .mint
    ]

    var body: some View {
        NavigationStack {
            Group {
                if appState.wordFrequencyService == nil {
                    unavailablePlaceholder
                } else if isLoading {
                    loadingView
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if result.terms.isEmpty {
                    emptyView
                } else {
                    content
                }
            }
            .navigationTitle(String(localized: "wordcloud.title", defaultValue: "Word Cloud"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .navigationDestination(item: $comparisonScope) { secondary in
                WordCloudComparisonView(primary: scope, secondary: secondary)
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task(id: TaskKey(signature: scope.signature, exclude: excludeBoilerplate)) {
            await load()
        }
        .sheet(item: $exportItem) { item in
            WordCloudShareSheet(item: item)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            scopeHeader
            Divider()
            switch viewMode {
            case .cloud: cloudCanvas
            case .list:  rankedList
            }
        }
    }

    private var scopeHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(String(
                    format: String(localized: "wordcloud.provenance %lld %lld",
                                   defaultValue: "%lld terms from %lld documents"),
                    Int64(result.terms.count), Int64(result.documentCount)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// The spiral tag cloud, with each word an individually tappable, accessible element.
    private var cloudCanvas: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(placements) { word in
                    Text(word.term)
                        .font(.system(size: word.fontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(Self.palette[word.colorIndex % Self.palette.count])
                        .position(word.center)
                        .onTapGesture { search(for: word.term) }
                        .contextMenu { wordContextMenu(term: word.term) }
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .task(id: LayoutKey(width: geo.size.width, height: geo.size.height,
                                signature: scope.signature, exclude: excludeBoilerplate,
                                termCount: result.terms.count)) {
                placements = WordCloudLayout.place(terms: result.terms, in: geo.size)
            }
        }
        .accessibilityRepresentation { rankedList }
    }

    /// Ranked term list — also the accessibility representation of the cloud.
    private var rankedList: some View {
        let maxCount = result.terms.first?.count ?? 1
        return List {
            ForEach(Array(result.terms.enumerated()), id: \.element.id) { index, term in
                Button { search(for: term.term) } label: {
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 28, alignment: .trailing)
                        Text(term.term)
                            .font(.body)
                        Spacer()
                        weightBar(count: term.count, maxCount: maxCount)
                        Text("\(term.count)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: term.term))
                .accessibilityValue(Text(String(
                    format: String(localized: "wordcloud.occurrences %lld",
                                   defaultValue: "%lld occurrences"),
                    Int64(term.count)
                )))
                .accessibilityHint(String(localized: "wordcloud.tap.hint",
                                          defaultValue: "Search for this term"))
                .contextMenu { wordContextMenu(term: term.term) }
            }
        }
        .listStyle(.plain)
    }

    /// A proportional bar visualising a term's share of the top count.
    private func weightBar(count: Int, maxCount: Int) -> some View {
        let fraction = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(0.55))
            .frame(width: 60 * fraction, height: 6)
            .frame(width: 60, alignment: .leading)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            if let fraction = progressModel.fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 240)
                Text(verbatim: "\(Int(fraction * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
            Text(scope == .corpus
                 ? String(localized: "wordcloud.loading.corpus",
                          defaultValue: "Analyzing the corpus — this can take a moment…")
                 : String(localized: "wordcloud.loading", defaultValue: "Building word cloud…"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyView: some View {
        ContentUnavailableView(
            String(localized: "wordcloud.empty.title", defaultValue: "No Terms"),
            systemImage: "cloud",
            description: Text(String(
                localized: "wordcloud.empty.detail",
                defaultValue: "There's no indexed text in this scope yet. Download and index the relevant volumes, then try again."
            ))
        )
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            String(localized: "wordcloud.error.title", defaultValue: "Couldn't Build Word Cloud"),
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "wordcloud.unavailable.title", defaultValue: "Word Cloud Unavailable"),
            systemImage: "cloud.slash",
            description: Text(String(
                localized: "wordcloud.unavailable.detail",
                defaultValue: "The search index could not be opened, so word clouds are unavailable."
            ))
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
        }
        #endif
        ToolbarItem(placement: .principal) {
            Picker(String(localized: "wordcloud.mode.label", defaultValue: "View"),
                   selection: $viewMode) {
                ForEach(WordCloudViewMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Toggle(String(localized: "wordcloud.filter.boilerplate",
                              defaultValue: "Hide common diplomatic words"),
                       isOn: $excludeBoilerplate)
                if !hiddenWords.isEmpty {
                    Button {
                        resetHiddenWords()
                    } label: {
                        Label(String(format: String(localized: "wordcloud.filter.showHidden %lld",
                                                     defaultValue: "Show %lld hidden words"),
                                     Int64(hiddenWords.count)),
                              systemImage: "eye")
                    }
                }
                Divider()
                compareMenu
                Divider()
                Section(String(localized: "wordcloud.export.section", defaultValue: "Export")) {
                    Button {
                        exportItem = WordCloudExporter.csv(terms: result.terms, title: title)
                    } label: {
                        Label(String(localized: "wordcloud.export.csv", defaultValue: "CSV…"),
                              systemImage: "tablecells")
                    }
                    Button {
                        exportItem = WordCloudExporter.image(
                            terms: result.terms, title: title, format: .png,
                            palette: Self.palette
                        )
                    } label: {
                        Label(String(localized: "wordcloud.export.png", defaultValue: "Image (PNG)…"),
                              systemImage: "photo")
                    }
                    Button {
                        exportItem = WordCloudExporter.image(
                            terms: result.terms, title: title, format: .pdf,
                            palette: Self.palette
                        )
                    } label: {
                        Label(String(localized: "wordcloud.export.pdf", defaultValue: "PDF…"),
                              systemImage: "doc.richtext")
                    }
                }
            } label: {
                Label(String(localized: "wordcloud.menu", defaultValue: "Options"),
                      systemImage: "ellipsis.circle")
            }
            .disabled(result.terms.isEmpty)
        }
    }

    /// "Compare with…" submenu: pick a second scope (corpus, a collection, or a
    /// tag) to view side by side with the current one.
    @ViewBuilder
    private var compareMenu: some View {
        Menu {
            if scope != .corpus {
                Button(String(localized: "wordcloud.compare.corpus", defaultValue: "Corpus")) {
                    comparisonScope = .corpus
                }
            }
            if !collections.isEmpty {
                Menu(String(localized: "wordcloud.compare.collections", defaultValue: "Collection")) {
                    ForEach(collections) { collection in
                        let candidate = WordCloudScope.collection(id: collection.id)
                        if candidate != scope {
                            Button(collection.name.isEmpty
                                   ? String(localized: "wordcloud.compare.untitled", defaultValue: "Untitled")
                                   : collection.name) {
                                comparisonScope = candidate
                            }
                        }
                    }
                }
            }
            if !tags.isEmpty {
                Menu(String(localized: "wordcloud.compare.tags", defaultValue: "Tag")) {
                    ForEach(tags) { tag in
                        let candidate = WordCloudScope.userTag(id: tag.id)
                        if candidate != scope {
                            Button(tag.name) { comparisonScope = candidate }
                        }
                    }
                }
            }
        } label: {
            Label(String(localized: "wordcloud.compare.menu", defaultValue: "Compare with…"),
                  systemImage: "rectangle.split.2x1")
        }
    }

    // MARK: - Loading & Actions

    /// Resolves the scope and computes its top terms, cancelling any in-flight load.
    private func load() async {
        guard appState.wordFrequencyService != nil else { return }
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil
        progressModel.fraction = nil
        hiddenWords = WordCloudOverrides.hidden(for: scope.signature)

        // Heavy scopes (corpus, subseries) report determinate progress and persist
        // their result to disk. The handler hops to the main actor to update state.
        let model = progressModel
        let handler: WordCloudProgress = { processed, total in
            Task { @MainActor in
                model.fraction = total > 0 ? Double(processed) / Double(total) : nil
            }
        }

        do {
            let (computed, loadedTitle) = try await WordCloudLoader.load(
                scope: scope, excludeBoilerplate: excludeBoilerplate,
                hiddenWords: hiddenWords, limit: Self.termLimit,
                appState: appState, modelContext: modelContext, progress: handler
            )
            if Task.isCancelled { return }
            title = loadedTitle
            result = computed
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        progressModel.fraction = nil
        isLoading = false
    }

    /// Shared context-menu actions for a word (cloud glyph or list row).
    @ViewBuilder
    private func wordContextMenu(term: String) -> some View {
        Button {
            search(for: term)
        } label: {
            Label(String(localized: "wordcloud.word.search", defaultValue: "Search for this term"),
                  systemImage: "magnifyingglass")
        }
        Button(role: .destructive) {
            hideWord(term)
        } label: {
            Label(String(localized: "wordcloud.word.hide", defaultValue: "Hide this word"),
                  systemImage: "eye.slash")
        }
    }

    /// Hides `term` from this scope's cloud: persists the override and removes it
    /// from the current result immediately (no recompute), so the effect is instant
    /// while future loads/exports honour it too.
    private func hideWord(_ term: String) {
        WordCloudOverrides.hide(term, for: scope.signature)
        hiddenWords.insert(term.lowercased())
        result = WordCloudResult(
            terms: result.terms.filter { $0.term != term },
            documentCount: result.documentCount,
            totalTokenCount: result.totalTokenCount
        )
    }

    /// Clears this scope's hidden-word overrides and recomputes.
    private func resetHiddenWords() {
        WordCloudOverrides.reset(for: scope.signature)
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    /// Hands off to Search pre-filled with `term`, mirroring the Analytics → Search handoff.
    private func search(for term: String) {
        appState.pendingSearch = SearchParameters(keywords: term)
        #if DEBUG
        print("[WordCloudView] Handoff to Search — term: \"\(term)\"")
        #endif
        dismiss()
    }

    // MARK: - Recompute Keys

    /// Drives a reload when the scope or stopword policy changes.
    private struct TaskKey: Equatable {
        let signature: String
        let exclude: Bool
    }

    /// Drives a spiral relayout when the canvas size, scope, or policy changes.
    private struct LayoutKey: Equatable {
        let width: CGFloat
        let height: CGFloat
        let signature: String
        let exclude: Bool
        let termCount: Int
    }
}

#if os(macOS)
/// Content for the macOS `frus.wordcloud` window. Reads the current scope from
/// `appState.pendingWordCloud`, re-creating the cloud when the scope changes.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudWindowContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let scope = appState.pendingWordCloud {
            WordCloudView(scope: scope)
                .id(scope.signature)
        } else {
            ContentUnavailableView(
                String(localized: "wordcloud.window.empty.title", defaultValue: "No Word Cloud"),
                systemImage: "cloud",
                description: Text(String(
                    localized: "wordcloud.window.empty.detail",
                    defaultValue: "Open a word cloud from a document, volume, collection, tag, saved search, or the corpus."
                ))
            )
        }
    }
}
#endif
