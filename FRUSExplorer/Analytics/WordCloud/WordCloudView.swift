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
/// **Corpus Analytics** (`pendingAnalytics`) for a **corpus-wide** frequency view of
/// that term across the series — the same for every cloud scope, since seeing a term's
/// arc across the whole FRUS run is the feature's point. For volume- and
/// subseries-scoped clouds the word context menu adds an "analyze within this
/// volume/subseries" option, and a direct "Search for this term" shortcut is always
/// offered. The view can be exported as PNG, PDF, or CSV.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — Session 164: word taps hand off to Corpus Analytics rather than Search,
///          corpus-wide by default; volume/subseries clouds get an optional scoped
///          handoff via the word context menu; Search stays on the context menu
struct WordCloudView: View {

    /// The body of material to visualise.
    let scope: WordCloudScope

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Excludes FRUS-boilerplate words ("telegram", "department", …) in addition
    /// to the always-on English stopwords. Persisted; defaults on.
    @AppStorage(WordCloudSettings.Keys.excludeBoilerplate) private var excludeBoilerplate = true

    // Word-cloud criteria mirrored from Settings so changing any of them recomputes
    // an open cloud. The list-based stop lists are covered by `settingsRevision`.
    @AppStorage(WordCloudSettings.Keys.filterMarkings) private var filterMarkings = true
    @AppStorage(WordCloudSettings.Keys.foldPlurals) private var foldPlurals = true
    @AppStorage(WordCloudSettings.Keys.minLength) private var minLength = WordCloudSettings.defaultMinLength
    @AppStorage(WordCloudSettings.Keys.minCount) private var minCount = WordCloudSettings.defaultMinCount
    @AppStorage(WordCloudSettings.Keys.revision) private var settingsRevision = 0

    // Device-local appearance: typeface and packing density. Changing either restyles
    // and re-lays out an open cloud (both feed `LayoutKey`).
    @AppStorage(WordCloudSettings.Keys.fontDesign) private var fontDesignRaw = WordCloudFontDesign.rounded.rawValue
    @AppStorage(WordCloudSettings.Keys.density) private var densityRaw = WordCloudDensity.balanced.rawValue

    /// The resolved typeface family for the cloud.
    private var fontDesign: WordCloudFontDesign { WordCloudFontDesign(rawValue: fontDesignRaw) ?? .rounded }
    /// The resolved packing density for the cloud.
    private var density: WordCloudDensity { WordCloudDensity(rawValue: densityRaw) ?? .balanced }

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
    @State private var lens: WordCloudLens = .allTerms

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
                } else if result.terms.isEmpty && lens == .allTerms {
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
        .task(id: TaskKey(signature: scope.signature, exclude: excludeBoilerplate,
                          lens: lens, settings: settingsToken)) {
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
            lensBar
            if lens.colorsBySentiment { sentimentLegend }
            Divider()
            if belowSignalThreshold {
                insufficientSignalView
            } else {
                switch viewMode {
                case .cloud: cloudCanvas
                case .list:  rankedList
                }
            }
        }
    }

    /// `true` when the active lens depends on semantic signal the current scope
    /// doesn't contain enough of to be meaningful.
    private var belowSignalThreshold: Bool {
        lens.isSignalDependent && result.terms.count < lens.minimumSignalTerms
    }

    /// Horizontally-scrolling lens selector. A scrolling chip bar rather than a
    /// fixed segmented control because there are more lenses than fit a phone width.
    private var lensBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(WordCloudLens.allCases) { option in
                    lensChip(option)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .accessibilityLabel(String(localized: "wordcloud.lens.label", defaultValue: "Show"))
    }

    /// One selectable lens chip.
    private func lensChip(_ option: WordCloudLens) -> some View {
        let selected = option == lens
        return Button {
            lens = option
        } label: {
            Label(option.label, systemImage: option.systemImage)
                .font(.caption.weight(selected ? .semibold : .regular))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(selected
                                   ? Color.accentColor
                                   : Color.secondary.opacity(0.15))
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Colour key shown under the lens bar while the sentiment lens is active.
    private var sentimentLegend: some View {
        HStack(spacing: 14) {
            Label(String(localized: "wordcloud.sentiment.positive", defaultValue: "Positive"),
                  systemImage: "circle.fill")
                .foregroundStyle(.green)
            Label(String(localized: "wordcloud.sentiment.negative", defaultValue: "Negative"),
                  systemImage: "circle.fill")
                .foregroundStyle(.red)
            Spacer()
        }
        .font(.caption2)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    /// Shown when a signal-dependent lens (entities, concepts, sentiment) finds too
    /// few matching terms in the current scope to be worth displaying.
    private var insufficientSignalView: some View {
        ContentUnavailableView(
            String(localized: "wordcloud.lens.insufficient.title", defaultValue: "Not Enough Signal"),
            systemImage: lens.systemImage,
            description: Text(String(
                format: String(localized: "wordcloud.lens.insufficient.detail %@",
                               defaultValue: "There aren't enough %@ in this scope to fill a cloud. Try a broader scope or a different lens."),
                lens.label.lowercased()
            ))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The colour for a word: sentiment polarity under the sentiment lens, otherwise
    /// the rank-based palette.
    private func wordColor(term: String, colorIndex: Int) -> Color {
        if lens.colorsBySentiment {
            switch WordCloudLexicons.polarity(of: term) {
            case .positive: return .green
            case .negative: return .red
            case .none:     return .secondary
            }
        }
        return Self.palette[colorIndex % Self.palette.count]
    }

    private var scopeHeader: some View {
        HStack(spacing: 8) {
            WordCloudGlyph()
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
                        .font(.system(size: word.fontSize, weight: .semibold, design: fontDesign.swiftUIDesign))
                        .foregroundStyle(wordColor(term: word.term, colorIndex: word.colorIndex))
                        .fixedSize()
                        .rotationEffect(.degrees(word.rotationDegrees))
                        .position(word.center)
                        .onTapGesture { analyze(for: word.term) }
                        .contextMenu { wordContextMenu(term: word.term) }
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .task(id: LayoutKey(width: geo.size.width, height: geo.size.height,
                                signature: scope.signature, exclude: excludeBoilerplate,
                                lens: lens, termCount: result.terms.count,
                                fontDesign: fontDesign, density: density)) {
                placements = WordCloudLayout.place(
                    terms: result.terms, in: geo.size,
                    spacingScale: density.spacingScale, widthFactor: fontDesign.widthFactor
                )
            }
        }
        .accessibilityRepresentation { rankedList }
    }

    /// Ranked term list — also the accessibility representation of the cloud.
    private var rankedList: some View {
        let maxCount = result.terms.first?.count ?? 1
        return List {
            ForEach(Array(result.terms.enumerated()), id: \.element.id) { index, term in
                Button { analyze(for: term.term) } label: {
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 28, alignment: .trailing)
                        Text(term.term)
                            .font(.body)
                            .foregroundStyle(lens.colorsBySentiment
                                             ? wordColor(term: term.term, colorIndex: index)
                                             : Color.primary)
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
            systemImage: WordCloudGlyph.fallbackSymbol,
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
            FeatureInfoButton(
                heading: String(localized: "wordcloud.info.heading", defaultValue: "About the Word Cloud"),
                items: [
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.shows.title", defaultValue: "What you're seeing"),
                        detail: String(localized: "wordcloud.info.shows.detail",
                                       defaultValue: "The most frequent meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, or the whole corpus — each sized by how often it appears.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.lenses.title", defaultValue: "Lenses"),
                        detail: String(localized: "wordcloud.info.lenses.detail",
                                       defaultValue: "The lens chips narrow the cloud to a kind of term — People, Places, Organizations, Topics, Actions, Descriptors, Concepts, or Sentiment — using on-device language analysis.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.filters.title", defaultValue: "What's filtered out"),
                        detail: String(localized: "wordcloud.info.filters.detail",
                                       defaultValue: "Common stopwords are always removed. You can also hide diplomatic boilerplate and maintain your own hidden-word lists (globally or per lens) in Settings → Word Cloud.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.tap.title", defaultValue: "Tapping a word"),
                        detail: String(localized: "wordcloud.info.tap.detail",
                                       defaultValue: "Charts how often that term appears across the whole corpus in Corpus Analytics; the word's menu also offers a scoped chart and a direct Search.")),
                ]
            )
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if isDateRangeScope {
                    Button {
                        viewInChronology()
                    } label: {
                        Label(String(localized: "wordcloud.viewInChronology",
                                     defaultValue: "View in Chronology"),
                              systemImage: "calendar.day.timeline.left")
                    }
                    Divider()
                }
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
                            palette: Self.palette, sentimentColors: lens.colorsBySentiment
                        )
                    } label: {
                        Label(String(localized: "wordcloud.export.png", defaultValue: "Image (PNG)…"),
                              systemImage: "photo")
                    }
                    Button {
                        exportItem = WordCloudExporter.image(
                            terms: result.terms, title: title, format: .pdf,
                            palette: Self.palette, sentimentColors: lens.colorsBySentiment
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
                hiddenWords: hiddenWords, limit: Self.termLimit, lens: lens,
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
        // Default handoff — corpus-wide frequency of the term across the whole series,
        // matching a plain tap.
        Button {
            analyze(for: term)
        } label: {
            Label(String(localized: "wordcloud.word.analyze", defaultValue: "Analyze in Corpus Analytics"),
                  systemImage: "chart.bar.xaxis")
        }
        // Optional scoped handoff — only offered for volume/subseries clouds, where
        // Analytics can restrict the chart to the cloud's own volumes.
        if let scopedLabel = scopedAnalyzeMenuLabel {
            Button {
                analyze(for: term, scoped: true)
            } label: {
                Label(scopedLabel, systemImage: "chart.bar.xaxis.ascending")
            }
        }
        Button {
            search(for: term)
        } label: {
            Label(String(localized: "wordcloud.word.search", defaultValue: "Search for this term"),
                  systemImage: "magnifyingglass")
        }
        Button(role: .destructive) {
            hideWordGlobally(term)
        } label: {
            Label(String(localized: "wordcloud.word.hide.global",
                         defaultValue: "Hide this word in all word clouds"),
                  systemImage: "eye.slash")
        }
        Button(role: .destructive) {
            hideWordInLens(term)
        } label: {
            Label(String(localized: "wordcloud.word.hide.lens",
                         defaultValue: "Hide this word in this lens"),
                  systemImage: "eye.slash.circle")
        }
    }

    /// Hides `term` from **every** word cloud by adding it to the global custom stop
    /// list (`WordCloudSettings`), and removes it from the current result immediately
    /// for instant feedback. Persisting bumps the settings revision, so any open cloud
    /// recomputes from the authoritative list on the next pass. Manage/un-hide these in
    /// Settings → Word Cloud.
    private func hideWordGlobally(_ term: String) {
        WordCloudSettings.addGlobalStopword(term)
        removeTermFromResult(term)
    }

    /// Hides `term` only under the currently-selected lens (its per-lens custom stop
    /// list), so it stays visible under other lenses. Removes it from the current
    /// result immediately.
    private func hideWordInLens(_ term: String) {
        WordCloudSettings.addLensStopword(term, lens: lens)
        removeTermFromResult(term)
    }

    /// Removes `term` from the displayed result without a recompute, so a hide takes
    /// effect instantly. Case-insensitive because the stop lists store lowercased words.
    private func removeTermFromResult(_ term: String) {
        let lower = term.lowercased()
        result = WordCloudResult(
            terms: result.terms.filter { $0.term.lowercased() != lower },
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

    /// Primary word-tap action: hands off to Corpus Analytics seeded with `term`.
    ///
    /// By default the handoff is **corpus-wide**, regardless of the cloud's own scope —
    /// the point of the feature is to see how a term that caught the user's eye appears
    /// across the whole FRUS series, which is more revealing than a scope-local count.
    /// Pass `scoped: true` (the volume/subseries-only context-menu action) to instead
    /// restrict Analytics to the cloud's volumes via `analyticsScope()`. From Analytics
    /// the researcher reaches the matching documents through its built-in "View in
    /// Search" gateway.
    private func analyze(for term: String, scoped: Bool = false) {
        let volumeIds: [String]?
        let label: String?
        if scoped {
            (volumeIds, label) = analyticsScope()
        } else {
            (volumeIds, label) = (nil, nil)
        }
        appState.pendingAnalytics = AnalyticsParameters(
            term: term, scopeVolumeIds: volumeIds, scopeLabel: label
        )
        #if DEBUG
        print("[WordCloudView] Handoff to Corpus Analytics — term: \"\(term)\", scope: \(label ?? "corpus"), volumes: \(volumeIds?.count ?? 0)")
        #endif
        #if os(iOS)
        // Corpus Analytics is presented from the Browse tab on iOS; bring it forward
        // so the analytics sheet (opened by `BrowserView` on `pendingAnalytics`) is visible.
        appState.activeTab = .browse
        #endif
        dismiss()
    }

    /// Label for the optional scoped-analytics context-menu action, or `nil` when the
    /// cloud's scope only supports a corpus-wide handoff. Only volume- and
    /// subseries-scoped clouds can meaningfully restrict Analytics to their own
    /// volumes; corpus, document, collection, tag, and saved-search clouds offer just
    /// the corpus-wide handoff.
    private var scopedAnalyzeMenuLabel: String? {
        switch scope {
        case .volume:
            return String(localized: "wordcloud.word.analyze.volume",
                          defaultValue: "Analyze within this volume")
        case .subseries:
            return String(localized: "wordcloud.word.analyze.subseries",
                          defaultValue: "Analyze within this subseries")
        case .corpus, .document, .collection, .userTag, .savedSearch, .dateRange:
            return nil
        }
    }

    /// Translates `scope` into the volume-ID scope Corpus Analytics understands, for
    /// the optional scoped context-menu handoff.
    ///
    /// Analytics buckets by whole volumes, so only the volume-aligned scopes carry
    /// through: `.volume` → that volume, `.subseries` → the subseries' volumes. The
    /// remaining scopes — `.corpus`, plus the sub-volume / document-set scopes
    /// `.document`, `.collection`, `.userTag`, and `.savedSearch`, which Analytics
    /// cannot express at volume granularity — return `(nil, nil)` (corpus-wide); these
    /// scopes never reach this method because `scopedAnalyzeMenuLabel` hides the
    /// scoped action for them.
    ///
    /// - Returns: The volume-ID scope and its display label, or `(nil, nil)` for a
    ///   corpus-wide query.
    private func analyticsScope() -> (volumeIds: [String]?, label: String?) {
        switch scope {
        case let .volume(volumeId):
            return ([volumeId], title.isEmpty ? volumeId : title)
        case let .subseries(subseriesId):
            let volumeIds = appState.manifestStore.bundledEntries
                .filter { $0.subseries == subseriesId }
                .map(\.volumeId)
            guard !volumeIds.isEmpty else { return (nil, nil) }
            return (volumeIds, title.isEmpty ? subseriesId : title)
        case .corpus, .document, .collection, .userTag, .savedSearch, .dateRange:
            return (nil, nil)
        }
    }

    /// Secondary action: hands off to Search pre-filled with `term`, mirroring the
    /// Analytics → Search handoff. Still offered in the word context menu for users
    /// who want to jump straight to the documents rather than via Analytics.
    private func search(for term: String) {
        appState.pendingSearch = SearchParameters(keywords: term)
        #if DEBUG
        print("[WordCloudView] Handoff to Search — term: \"\(term)\"")
        #endif
        dismiss()
    }

    /// Whether this cloud is scoped to a date range, gating the "View in Chronology"
    /// handoff (only a date-range cloud maps cleanly back onto the Chronology browser).
    private var isDateRangeScope: Bool {
        if case .dateRange = scope { return true }
        return false
    }

    /// Opens the Chronology browser for this cloud's date range — the inverse of the
    /// "Word Cloud for this range" handoff from Chronology. Only meaningful for a
    /// `.dateRange` scope.
    private func viewInChronology() {
        guard case let .dateRange(startISO, endISO) = scope else { return }
        appState.pendingChronology = ChronologyParameters(
            rangeStart: WordCloudScope.day(fromISO: startISO),
            rangeEnd: WordCloudScope.day(fromISO: endISO)
        )
        #if DEBUG
        print("[WordCloudView] Handoff to Chronology — range: \(startISO)…\(endISO)")
        #endif
        #if os(macOS)
        openWindow(id: "frus.chronology")
        #else
        // Chronology is presented from the Browse tab on iOS; surface it and dismiss
        // this sheet so `BrowserView` can present it on the `pendingChronology` change.
        appState.activeTab = .browse
        dismiss()
        #endif
    }

    // MARK: - Recompute Keys

    /// A token summarising the Settings-driven criteria; changing any of them (or a
    /// custom stop list, via the revision) recomputes the cloud.
    private var settingsToken: String {
        "m\(filterMarkings ? 1 : 0)f\(foldPlurals ? 1 : 0)l\(minLength)c\(minCount)r\(settingsRevision)"
    }

    /// Drives a reload when the scope, stopword policy, lens, or criteria change.
    private struct TaskKey: Equatable {
        let signature: String
        let exclude: Bool
        let lens: WordCloudLens
        let settings: String
    }

    /// Drives a spiral relayout when the canvas size, scope, policy, or lens changes.
    private struct LayoutKey: Equatable {
        let width: CGFloat
        let height: CGFloat
        let signature: String
        let exclude: Bool
        let lens: WordCloudLens
        let termCount: Int
        let fontDesign: WordCloudFontDesign
        let density: WordCloudDensity
    }
}

#if os(macOS)
/// Content for the macOS `frus.wordcloud` window.
///
/// Seeds its scope from `appState.pendingWordCloud` (set by whichever surface opened
/// the window) and tracks subsequent hand-offs, but also hosts a `WordCloudScopeBar`
/// so the user can retarget the cloud to any available scope — corpus, subseries,
/// volume, collection, tag, or saved search — directly from this app-level window.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   2.0 — Word Cloud: in-window scope picker
struct WordCloudWindowContent: View {
    @Environment(AppState.self) private var appState

    /// The scope currently displayed; `nil` until one is chosen or handed off.
    @State private var scope: WordCloudScope?

    var body: some View {
        VStack(spacing: 0) {
            WordCloudScopeBar(scope: $scope)
            Divider()
            if let scope {
                WordCloudView(scope: scope)
                    .id(scope.signature)
            } else {
                ContentUnavailableView(
                    String(localized: "wordcloud.window.empty.title", defaultValue: "No Word Cloud"),
                    systemImage: WordCloudGlyph.fallbackSymbol,
                    description: Text(String(
                        localized: "wordcloud.window.empty.detail",
                        defaultValue: "Pick a scope above, or open a word cloud from a document, volume, collection, tag, saved search, or the corpus."
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if scope == nil { scope = appState.pendingWordCloud } }
        .onChange(of: appState.pendingWordCloud) { _, handedOff in
            if let handedOff { scope = handedOff }
        }
    }
}

/// A compact scope selector for the macOS word-cloud window.
///
/// Presents a single menu listing every scope the cloud can target: the whole
/// corpus, a subseries, a specific volume (grouped under its subseries), or a user
/// collection / tag / saved search. The button shows a readable label for the
/// current scope so the window always says what it's analysing.
///
/// Version history:
///   1.0 — Word Cloud: in-window scope picker
private struct WordCloudScopeBar: View {
    /// The scope binding shared with `WordCloudWindowContent`.
    @Binding var scope: WordCloudScope?

    @Environment(AppState.self) private var appState
    @Query(sort: \Collection.name) private var collections: [Collection]
    @Query(sort: \UserTag.name) private var tags: [UserTag]
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var savedSearches: [SavedSearch]

    /// The known volume manifest entries (diffed if available, else bundled).
    private var entries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    /// The distinct subseries names, in manifest order.
    private var subseriesList: [String] {
        var seen = Set<String>()
        var all: [String] = []
        for entry in entries where seen.insert(entry.subseries).inserted { all.append(entry.subseries) }
        return all
    }

    /// The volumes belonging to a subseries.
    private func volumes(in subseries: String) -> [VolumeManifestEntry] {
        entries.filter { $0.subseries == subseries }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(String(localized: "wordcloud.scopeBar.label", defaultValue: "Scope"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                Button(String(localized: "wordcloud.scope.corpus", defaultValue: "Entire Corpus")) {
                    scope = .corpus
                }
                Menu(String(localized: "wordcloud.scope.subseries", defaultValue: "Subseries")) {
                    ForEach(subseriesList, id: \.self) { sub in
                        Button(sub) { scope = .subseries(subseriesId: sub) }
                    }
                }
                Menu(String(localized: "wordcloud.scope.volume", defaultValue: "Volume")) {
                    ForEach(subseriesList, id: \.self) { sub in
                        Menu(sub) {
                            ForEach(volumes(in: sub)) { vol in
                                Button(vol.title.isEmpty ? vol.volumeId : vol.title) {
                                    scope = .volume(volumeId: vol.volumeId)
                                }
                            }
                        }
                    }
                }
                if !collections.isEmpty {
                    Menu(String(localized: "wordcloud.scope.collection", defaultValue: "Collection")) {
                        ForEach(collections) { collection in
                            Button(collection.name.isEmpty
                                   ? String(localized: "wordcloud.scope.untitled", defaultValue: "Untitled")
                                   : collection.name) {
                                scope = .collection(id: collection.id)
                            }
                        }
                    }
                }
                if !tags.isEmpty {
                    Menu(String(localized: "wordcloud.scope.tag", defaultValue: "Tag")) {
                        ForEach(tags) { tag in
                            Button(tag.name) { scope = .userTag(id: tag.id) }
                        }
                    }
                }
                if !savedSearches.isEmpty {
                    Menu(String(localized: "wordcloud.scope.savedSearch", defaultValue: "Saved Search")) {
                        ForEach(savedSearches) { search in
                            Button(search.name.isEmpty
                                   ? String(localized: "wordcloud.scope.untitled", defaultValue: "Untitled")
                                   : search.name) {
                                scope = .savedSearch(id: search.id)
                            }
                        }
                    }
                }
                Divider()
                Button(String(localized: "wordcloud.scope.dateRange", defaultValue: "Date Range")) {
                    scope = defaultDateRangeScope()
                }
            } label: {
                Text(currentLabel)
                    .font(.subheadline.weight(.semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            if case let .dateRange(startISO, endISO) = scope {
                DatePicker("", selection: Binding(
                    get: { WordCloudScope.day(fromISO: startISO) ?? .distantPast },
                    set: { scope = .dateRange(startISO: WordCloudScope.isoDay(from: $0), endISO: endISO) }
                ), in: ...(WordCloudScope.day(fromISO: endISO) ?? .now), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .accessibilityLabel(String(localized: "wordcloud.scope.dateRange.from", defaultValue: "Range start"))
                Text(verbatim: "–").foregroundStyle(.tertiary)
                DatePicker("", selection: Binding(
                    get: { WordCloudScope.day(fromISO: endISO) ?? .now },
                    set: { scope = .dateRange(startISO: startISO, endISO: WordCloudScope.isoDay(from: $0)) }
                ), in: (WordCloudScope.day(fromISO: startISO) ?? .distantPast)..., displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .accessibilityLabel(String(localized: "wordcloud.scope.dateRange.to", defaultValue: "Range end"))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// A sensible default date-range scope when the user first picks "Date Range":
    /// the corpus's most recent year, mirroring the Chronology browser's default.
    private func defaultDateRangeScope() -> WordCloudScope {
        let corpus = appState.manifestStore.corpusDateRange
        let cal = Calendar(identifier: .gregorian)
        let end = corpus.upperBound
        let start = cal.date(byAdding: .year, value: -1, to: end) ?? corpus.lowerBound
        return .dateRange(startISO: WordCloudScope.isoDay(from: start),
                          endISO: WordCloudScope.isoDay(from: end))
    }

    /// A readable label for the current scope, resolved against the manifest and
    /// the user's SwiftData records.
    private var currentLabel: String {
        guard let scope else {
            return String(localized: "wordcloud.scope.choose", defaultValue: "Choose scope…")
        }
        switch scope {
        case .corpus:
            return String(localized: "wordcloud.scope.corpus", defaultValue: "Entire Corpus")
        case let .subseries(subseriesId):
            return subseriesId
        case let .volume(volumeId):
            return entries.first { $0.volumeId == volumeId }?.title ?? volumeId
        case let .document(_, documentId):
            return String(format: String(localized: "wordcloud.scope.document %@",
                                          defaultValue: "Document %@"), documentId)
        case let .collection(id):
            return collections.first { $0.id == id }?.name
                ?? String(localized: "wordcloud.scope.collection", defaultValue: "Collection")
        case let .userTag(id):
            return tags.first { $0.id == id }?.name
                ?? String(localized: "wordcloud.scope.tag", defaultValue: "Tag")
        case let .savedSearch(id):
            return savedSearches.first { $0.id == id }?.name
                ?? String(localized: "wordcloud.scope.savedSearch", defaultValue: "Saved Search")
        case let .dateRange(startISO, endISO):
            return WordCloudScope.dateRangeTitle(startISO: startISO, endISO: endISO)
        }
    }
}
#endif
