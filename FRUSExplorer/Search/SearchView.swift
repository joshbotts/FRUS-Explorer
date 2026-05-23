// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - SearchView

/// Full composable search view with keyword search, advanced filters, and a results list.
///
/// ## Layout
/// Uses SwiftUI's `.searchable` modifier to place the keyword field in the navigation
/// bar (on iOS) or toolbar (on macOS). Advanced filters are presented via a separate
/// `SearchFilterView` sheet, opened with the filter toolbar button.
///
/// ## Navigation
/// Uses its own `NavigationStack` so document navigation stays within the search
/// context without affecting the browser's navigation stack.
///
/// ## Suffix Wildcard
/// Only prefix wildcards are supported by FTS5 (`negoti*`). This limitation is
/// documented in `SearchFilterView`'s advanced text section and in `SearchViewModel`.
///
/// Version history:
///   1.0 — Session 16: initial implementation
///   1.1 — Session 38: document type filter section added to filter panel
///   1.2 — Session 40: person ref filter field added; `initialParameters` support
///   1.3 — Session 41: person ref field replaced with autocomplete picker backed by SQLite
///   1.4 — Session 44: Done button and dismiss guarded to non-iOS (Search is a tab on iOS)
///   1.5 — Session 62: replaced custom `searchInputRow` with `.searchable` modifier;
///          filter panel extracted to `SearchFilterView` sheet (F-002); `personSearchText`
///          and `personSuggestions` moved to `SearchFilterView`
///   1.6 — Session 88: timeline toggle button; `DocumentTimelineView` replaces results list when active
struct SearchView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @State private var vm: SearchViewModel
    @State private var showTimeline = false
    private let initialParameters: SearchParameters?

    init(
        searchService: SearchService,
        subjectTagStore: SubjectTagStore,
        initialParameters: SearchParameters? = nil
    ) {
        _vm = State(initialValue: SearchViewModel(
            searchService: searchService,
            subjectTagStore: subjectTagStore
        ))
        self.initialParameters = initialParameters
    }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack(path: $vm.navigationPath) {
            resultsSection
                .navigationTitle(
                    String(localized: "search.title", defaultValue: "Search")
                )
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                // System search bar — integrates with the navigation bar on iOS
                // and the toolbar area on macOS (inspector context).
                .searchable(
                    text: $vm.keywords,
                    prompt: String(localized: "search.keywords.placeholder",
                                   defaultValue: "Keywords…")
                )
                // Fire search on keyboard Return / iOS "Search" button.
                .onSubmit(of: .search) {
                    Task { await vm.search() }
                }
                // Clearing the search bar resets results so the view returns to
                // the initial "enter keywords" prompt state.
                .onChange(of: vm.keywords) { _, newValue in
                    if newValue.isEmpty {
                        vm.results    = []
                        vm.hasSearched = false
                        vm.searchError = nil
                    }
                }
                .toolbar {
                    #if !os(iOS)
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "search.done",
                                      defaultValue: "Done")) {
                            dismiss()
                        }
                    }
                    #endif
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            vm.showFilterPanel = true
                        } label: {
                            Image(systemName: vm.hasActiveFilters
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityLabel(
                            String(localized: "search.filters.toggle.a11y",
                                   defaultValue: "Toggle filters")
                        )
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showTimeline.toggle()
                        } label: {
                            Image(systemName: showTimeline ? "chart.bar.fill" : "chart.bar")
                        }
                        .accessibilityLabel(
                            showTimeline
                                ? String(localized: "search.timeline.hide.a11y",
                                         defaultValue: "Hide timeline")
                                : String(localized: "search.timeline.show.a11y",
                                         defaultValue: "Show timeline")
                        )
                        .disabled(vm.results.isEmpty)
                    }
                }
                // Advanced filter sheet — iOS uses detents; macOS uses a fixed frame
                // declared inside SearchFilterView.
                .sheet(isPresented: $vm.showFilterPanel) {
                    SearchFilterView(vm: vm)
                        .environment(appState)
                        .modelContainer(modelContext.container)
                }
                .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                    #if os(iOS)
                    DocumentView(entry: entry)
                    #else
                    MacDocumentView(entry: entry, navigationPath: .constant([]))
                    #endif
                }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 520)
        #endif
        .task {
            if let params = initialParameters {
                vm.applyParameters(params)
            }
            await vm.loadAvailableSubjectTags()
            vm.loadAvailableUserTags(context: modelContext)
            if let pid = appState.activeProjectId {
                let descriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { $0.id == pid }
                )
                let project = try? modelContext.fetch(descriptor).first
                vm.applyProjectDefaults(project)
            }
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if vm.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.searchError {
            ContentUnavailableView(
                String(localized: "search.error.title", defaultValue: "Search Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if vm.hasSearched && vm.results.isEmpty {
            ContentUnavailableView(
                String(localized: "search.empty.title", defaultValue: "No Results"),
                systemImage: "magnifyingglass",
                description: Text(String(localized: "search.empty.detail",
                                         defaultValue: "Try different keywords or adjust your filters."))
            )
        } else if !vm.results.isEmpty {
            resultCountHeader
            if showTimeline {
                DocumentTimelineView(
                    items: vm.results.map {
                        DocumentTimelineView.Item(
                            volumeId: $0.volumeId,
                            documentId: $0.documentId,
                            header: $0.header
                        )
                    },
                    onSelect: { item in
                        if let r = vm.results.first(where: {
                            $0.volumeId == item.volumeId && $0.documentId == item.documentId
                        }) {
                            vm.navigationPath.append(vm.makeEntry(from: r))
                        }
                    }
                )
            } else {
                resultsList
            }
        } else {
            // Initial prompt — no search has been performed yet.
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(String(localized: "search.prompt",
                            defaultValue: "Enter keywords to search the FRUS corpus."))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var resultCountHeader: some View {
        HStack {
            Text(
                String(
                    format: String(localized: "search.count %lld",
                                   defaultValue: "%lld results"),
                    Int64(vm.resultCount)
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var resultsList: some View {
        List {
            ForEach(vm.results) { result in
                Button {
                    vm.navigationPath.append(vm.makeEntry(from: result))
                } label: {
                    SearchResultRow(
                        result: result,
                        onSubjectTagTap: { tagId in
                            vm.selectedSubjectTagIds.insert(tagId)
                            Task { await vm.search() }
                        },
                        onUserTagTap: { tagId in
                            if let uuid = UUID(uuidString: tagId) {
                                vm.selectedUserTagIds.insert(uuid)
                                Task { await vm.search() }
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(result.header)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let result: SearchResult
    let onSubjectTagTap: (String) -> Void
    let onUserTagTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header + document number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let num = result.documentNumber {
                    Text("\(num).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(result.header)
                    .font(.headline)
                    .lineLimit(2)
            }

            // Dateline
            if let dateline = result.dateline {
                Text(dateline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Volume ID
            Text(result.volumeId)
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Snippet — render <b>…</b> markers as highlighted text
            if !result.snippet.isEmpty {
                SearchSnippetView(snippet: result.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 1)
            }

            // Subject tag chips
            if !result.subjectTagIds.isEmpty {
                SearchTagChipsRow(
                    tagIds: result.subjectTagIds,
                    systemImage: "tag",
                    onTap: onSubjectTagTap
                )
            }

            // User tag chips
            if !result.userTagIds.isEmpty {
                SearchTagChipsRow(
                    tagIds: result.userTagIds,
                    systemImage: "person.crop.circle.badge.plus",
                    onTap: onUserTagTap
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SearchSnippetView

/// Renders an FTS5 snippet where `<b>` / `</b>` delimiters mark matched terms.
///
/// Matched terms are shown in the accent colour with medium weight; the surrounding
/// context text uses the inherited foreground style. Mirrors `SnippetView` in
/// `SearchSheet.swift` (used by the macOS search sheet and iOS search view).
private struct SearchSnippetView: View {
    let snippet: String

    var body: some View {
        (try? AttributedString(styledSnippet(snippet), including: \.swiftUI))
            .map { Text($0) } ?? Text(plainSnippet)
    }

    private var plainSnippet: String {
        snippet
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
    }

    private func styledSnippet(_ raw: String) throws -> AttributedString {
        var result = AttributedString()
        var remainder = raw
        while !remainder.isEmpty {
            if let openRange = remainder.range(of: "<b>"),
               let closeRange = remainder.range(of: "</b>",
                   range: openRange.upperBound..<remainder.endIndex) {
                let before = String(remainder[..<openRange.lowerBound])
                if !before.isEmpty { result += AttributedString(before) }
                let highlighted = String(remainder[openRange.upperBound..<closeRange.lowerBound])
                var span = AttributedString(highlighted)
                span.swiftUI.foregroundColor = .accentColor
                span.swiftUI.font = .caption.weight(.medium)
                result += span
                remainder = String(remainder[closeRange.upperBound...])
            } else {
                result += AttributedString(remainder)
                break
            }
        }
        return result
    }
}

// MARK: - SearchTagChipsRow

private struct SearchTagChipsRow: View {
    let tagIds: [String]
    let systemImage: String
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tagIds, id: \.self) { tagId in
                    Button {
                        onTap(tagId)
                    } label: {
                        Label(tagId, systemImage: systemImage)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "search.tagchip.a11y",
                               defaultValue: "Filter by \(tagId)")
                    )
                }
            }
        }
    }
}
