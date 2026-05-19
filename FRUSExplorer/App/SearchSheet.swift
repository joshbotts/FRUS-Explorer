// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI

// MARK: - SearchSheet

/// Full-text search sheet presented over the main macOS window.
///
/// ## Layout (top to bottom)
/// 1. Search input + Tips toggle + Cancel button
/// 2. Scope toggles (Documents · Notes · Summaries · Collections)
/// 3. Filter row (Date · Volume/subseries · Tagged · Advanced…)
/// 4. Document type selector (Both / Primary only / Editorial notes only)
/// 5. Sort bar (result count with page range · page size picker · sort order)
/// 6. Results list (current page of `pagedResults`)
/// 7. Pagination bar (prev · page indicator · next)
/// 8. Tips panel (collapsible)
///
/// ## Resizability
/// The sheet uses `idealWidth`/`idealHeight` plus `.infinity` max so macOS lets
/// the user drag it to any size.
///
/// ## Advanced Filters
/// Tapping "Advanced…" in the filter row opens `SearchFilterView` as a sheet.
/// On dismiss, `searchVM.applyAdvancedFilters()` copies filter state back into
/// `parameters` and bumps `parametersVersion`, which triggers a new search via
/// `.task(id: searchVM.searchTrigger)`.
///
/// ## Interaction
/// Selecting a result appends to `navigationPath` and dismisses the sheet.
/// Right-clicking a result offers "Open in new window" (future session).
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; uses MacSearchViewModel)
///   1.1 — Add pagination, page size picker, Advanced Filters sheet, resizable frame
struct SearchSheet: View {
    @Binding var navigationPath: [DocumentBrowserEntry]

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchVM = MacSearchViewModel()
    @State private var showAdvancedFilters = false

    var body: some View {
        VStack(spacing: 0) {

            searchInputRow
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                scopeRow
                filterRow
                documentTypeRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            sortBar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            Divider()

            resultsList

            if searchVM.totalPages > 1 {
                Divider()
                paginationBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            if searchVM.showTips {
                Divider()
                tipsPanel
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 640, idealWidth: 820, maxWidth: .infinity,
               minHeight: 500, idealHeight: 680, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.15), value: searchVM.showTips)
        .task(id: searchVM.searchTrigger) {
            await searchVM.performSearch(service: appState.searchService)
        }
        .sheet(isPresented: $showAdvancedFilters,
               onDismiss: { searchVM.applyAdvancedFilters() }) {
            SearchFilterView(vm: searchVM.filterVM)
        }
    }

    // MARK: - Search Input Row

    private var searchInputRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

                TextField("Search documents, notes, summaries…", text: $searchVM.queryText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit { Task { await searchVM.performSearch(service: appState.searchService) } }

                if !searchVM.queryText.isEmpty {
                    Button {
                        searchVM.queryText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )

            Button {
                searchVM.showTips.toggle()
            } label: {
                Label("Tips", systemImage: "questionmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(searchVM.showTips ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    // MARK: - Scope Row

    private var scopeRow: some View {
        HStack(spacing: 6) {
            Text("Search in")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            ScopeChip(label: "Documents",   isOn: $searchVM.scopeDocuments)
            ScopeChip(label: "Notes",       isOn: $searchVM.scopeNotes)
            ScopeChip(label: "Summaries",   isOn: $searchVM.scopeSummaries)
            ScopeChip(label: "Collections", isOn: $searchVM.scopeCollections)
        }
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack(spacing: 8) {
            FilterChip(
                label: "Date",
                value: searchVM.dateRangeLabel,
                isActive: searchVM.parameters.dateRange != nil
            ) { searchVM.clearDateFilter() }

            Divider().frame(height: 16)

            FilterChip(
                label: "Volume / subseries",
                value: searchVM.volumeFilterLabel,
                isActive: searchVM.parameters.volumeIds != nil
            ) { searchVM.clearVolumeFilter() }

            Divider().frame(height: 16)

            FilterChip(
                label: "Tagged",
                value: searchVM.tagFilterLabel,
                isActive: !searchVM.parameters.userTagIds.isEmpty
            ) { searchVM.clearTagFilter() }

            Divider().frame(height: 16)

            Button {
                searchVM.syncToFilterVM()
                showAdvancedFilters = true
            } label: {
                HStack(spacing: 3) {
                    if searchVM.activeFilterSummary != nil {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Text("Advanced…")
                        .font(.system(size: 11))
                        .foregroundStyle(searchVM.activeFilterSummary != nil
                            ? Color.accentColor : Color.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open advanced search filters")
        }
    }

    // MARK: - Document Type Row

    private var documentTypeRow: some View {
        HStack(spacing: 6) {
            Text("Type")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            ForEach(DocumentTypeFilter.searchUIOptions, id: \.label) { option in
                Button {
                    searchVM.setDocumentTypeFilter(option.filter)
                } label: {
                    Text(option.label)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            searchVM.parameters.documentTypeFilter == option.filter
                                ? Color.green.opacity(0.15)
                                : Color.secondary.opacity(0.08)
                        )
                        .foregroundStyle(
                            searchVM.parameters.documentTypeFilter == option.filter
                                ? Color.green : Color.secondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    searchVM.parameters.documentTypeFilter == option.filter
                                        ? Color.green.opacity(0.4)
                                        : Color.secondary.opacity(0.2),
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            if searchVM.isSearching {
                ProgressView().controlSize(.small)
                Text("Searching…").font(.system(size: 11)).foregroundStyle(.secondary)
            } else if !searchVM.queryText.isEmpty {
                resultCountLabel
            }

            Spacer()

            pageSizePicker

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("Sort").font(.system(size: 11)).foregroundStyle(.tertiary)

                ForEach(SearchSortOrder.allCases, id: \.self) { order in
                    Button {
                        searchVM.sortOrder = order
                    } label: {
                        Text(order.label)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                searchVM.sortOrder == order
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                searchVM.sortOrder == order ? Color.accentColor : Color.secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        searchVM.sortOrder == order
                                            ? Color.accentColor.opacity(0.3)
                                            : Color.secondary.opacity(0.15),
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var resultCountLabel: some View {
        let total = searchVM.results.count
        let start = searchVM.currentPage * searchVM.pageSize + 1
        let end   = min(start + searchVM.pageSize - 1, total)

        if total == 0 {
            Text("No results")
                .font(.system(size: 11, weight: .medium))
        } else if total <= searchVM.pageSize {
            Text("\(total) result\(total == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
        } else {
            Text("\(start)–\(end) of \(total) results")
                .font(.system(size: 11, weight: .medium))
        }
    }

    private var pageSizePicker: some View {
        HStack(spacing: 4) {
            Text("Show")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Menu {
                ForEach(MacSearchViewModel.pageSizeOptions, id: \.self) { size in
                    Button("\(size)") { searchVM.pageSize = size }
                }
            } label: {
                Text("\(searchVM.pageSize)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(searchVM.pagedResults, id: \.id) { result in
            SearchResultRow(result: result)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.visible, edges: .bottom)
                .contentShape(Rectangle())
                .onTapGesture { navigateToResult(result) }
                .contextMenu {
                    Button("Open in new window") {
                        // openWindow API — deferred to future session
                    }
                }
        }
        .listStyle(.plain)
    }

    // MARK: - Pagination Bar

    private var paginationBar: some View {
        HStack(spacing: 12) {
            Button {
                if searchVM.currentPage > 0 { searchVM.currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(searchVM.currentPage == 0)

            Text("Page \(searchVM.currentPage + 1) of \(searchVM.totalPages)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                if searchVM.currentPage < searchVM.totalPages - 1 {
                    searchVM.currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(searchVM.currentPage >= searchVM.totalPages - 1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tips Panel

    private var tipsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search tips")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.7)

            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 6) {
                TipItem(code: "\"exact phrase\"",    description: "match words in order")
                TipItem(code: "Rusk OR Bundy",       description: "either term")
                TipItem(code: "blockade -quarantine", description: "exclude a term")
                TipItem(code: nil, description: "Date filter uses TEI <date @when> — only dated documents match")
                TipItem(code: nil, description: "Person filter searches indexed <persName> mentions across volumes")
                TipItem(code: nil, description: "Scope toggles persist across sessions; adjust in Settings")
            }
        }
    }

    // MARK: - Actions

    private func navigateToResult(_ result: SearchResult) {
        let entry = DocumentBrowserEntry(
            documentId: result.documentId,
            volumeId: result.volumeId,
            documentNumber: result.documentNumber,
            header: result.header,
            dateline: result.dateline,
            sourceNote: result.sourceNote,
            isEditorialNote: result.isEditorialNote
        )
        navigationPath.append(entry)
        dismiss()
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(result.volumeId) · Doc \(result.documentNumber ?? result.documentId)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)

                if result.isEditorialNote {
                    Text("editorial note")
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Spacer()

                if let dateline = result.dateline {
                    Text(dateline)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Text(result.header)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)

            SnippetView(snippet: result.snippet)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !result.userTagIds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(result.userTagIds.prefix(3), id: \.self) { tag in
                        Text("◆ \(tag)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.08))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
    }
}

// MARK: - SnippetView

/// Renders an FTS5 snippet string where `<b>` / `</b>` delimiters mark matched terms.
private struct SnippetView: View {
    let snippet: String

    var body: some View {
        (try? AttributedString(styledSnippet(snippet), including: \.swiftUI))
            .map { Text($0) } ?? Text(snippet)
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
                span.foregroundColor = .init(.systemYellow)
                span.font = .system(size: 12, weight: .medium)
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

// MARK: - Scope Chip

private struct ScopeChip: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isOn ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isOn ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let value: String?
    let isActive: Bool
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.tertiary)

            if isActive, let value {
                HStack(spacing: 3) {
                    Text(value).font(.system(size: 11)).foregroundStyle(Color.accentColor)
                    Button { onClear() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                )
            } else {
                Text("any")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .italic()
            }
        }
    }
}

// MARK: - Tip Item

private struct TipItem: View {
    let code: String?
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            if let code {
                Text(code)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(.secondary)
                Text("—").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Text(description).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}

// MARK: - DocumentTypeFilter helpers

extension DocumentTypeFilter {
    struct UIOption {
        let label: String
        let filter: DocumentTypeFilter
    }
    static let searchUIOptions: [UIOption] = [
        UIOption(label: "Both",              filter: .all),
        UIOption(label: "Primary documents", filter: .documentsOnly),
        UIOption(label: "Editorial notes",   filter: .editorialNotesOnly),
    ]
}

#endif // os(macOS)
