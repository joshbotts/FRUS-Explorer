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

/// Full composable search sheet with keyword/phrase/filter controls and a results list.
///
/// ## Layout
/// 1. **Search input row** — keyword field + Search button; always visible
/// 2. **Filter panel** — expandable; contains advanced text options, date range,
///    subject tag multi-select, user tag multi-select, and content scope toggles
/// 3. **Results** — count header + scrollable list; each row navigates to `DocumentView`
///
/// ## Navigation
/// Uses its own `NavigationStack` so document navigation stays within the sheet
/// without affecting the browser's navigation stack.
///
/// ## Suffix Wildcard
/// Only prefix wildcards are supported by FTS5 (`negoti*`). This limitation is
/// documented in the filter panel's help text and in `SearchViewModel`.
///
/// Version history:
///   1.0 — Session 16: initial implementation
///   1.1 — Session 38: document type filter section added to filter panel
///   1.2 — Session 40: person ref filter field added; `initialParameters` support
///   1.3 — Session 41: person ref field replaced with autocomplete picker backed by SQLite
///   1.4 — Session 44: Done button and dismiss guarded to non-iOS (Search is a tab on iOS)
struct SearchView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @State private var vm: SearchViewModel
    private let initialParameters: SearchParameters?

    /// Live text typed by the user in the person name search field.
    @State private var personSearchText: String = ""
    /// Person entries matching `personSearchText`, shown as a dropdown.
    @State private var personSuggestions: [PersonEntry] = []

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
            VStack(spacing: 0) {
                searchInputRow
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                if vm.showFilterPanel {
                    Divider()
                    filterPanel
                        .frame(maxHeight: 380)
                }

                Divider()
                resultsSection
            }
            .navigationTitle(
                String(localized: "search.title", defaultValue: "Search")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if !os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "search.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        vm.showFilterPanel.toggle()
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
            }
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                DocumentView(entry: entry)
            }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 520)
        #endif
        .task {
            if let params = initialParameters {
                vm.applyParameters(params)
                // Pre-populate the display field from the ref when launched via pendingSearch.
                // We show the ref value directly since a name lookup would require a volumeId.
                personSearchText = params.personRef ?? ""
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

    // MARK: - Search Input Row

    private var searchInputRow: some View {
        @Bindable var vm = vm
        return HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    String(localized: "search.keywords.placeholder",
                           defaultValue: "Keywords…"),
                    text: $vm.keywords
                )
                .textFieldStyle(.plain)
                .onSubmit {
                    Task { await vm.search() }
                }
                .accessibilityLabel(
                    String(localized: "search.keywords.a11y",
                           defaultValue: "Search keywords")
                )
                if !vm.keywords.isEmpty {
                    Button {
                        vm.clearAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "search.clear.a11y", defaultValue: "Clear search")
                    )
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Button {
                Task { await vm.search() }
            } label: {
                Text(String(localized: "search.button", defaultValue: "Search"))
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isSearching || vm.keywords.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Filter Panel

    @ViewBuilder
    private var filterPanel: some View {
        @Bindable var vm = vm
        ScrollView {
            Form {
                // Advanced text options
                Section {
                    TextField(
                        String(localized: "search.phrase.placeholder",
                               defaultValue: "Exact phrase"),
                        text: $vm.phrase
                    )
                    .accessibilityLabel(
                        String(localized: "search.phrase.a11y", defaultValue: "Exact phrase")
                    )

                    HStack {
                        TextField(
                            String(localized: "search.prefix.placeholder",
                                   defaultValue: "Prefix wildcard (e.g. negoti)"),
                            text: $vm.prefixWildcard
                        )
                        .accessibilityLabel(
                            String(localized: "search.prefix.a11y",
                                   defaultValue: "Prefix wildcard")
                        )
                        Text("*")
                            .foregroundStyle(.secondary)
                    }
                    Text(String(localized: "search.prefix.help",
                                defaultValue: "Only prefix wildcards are supported. Suffix wildcards (e.g. *ate) are not valid FTS5 syntax."))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        String(localized: "search.excluded.placeholder",
                               defaultValue: "Excluded terms (comma-separated)"),
                        text: $vm.excludedTermsText
                    )
                    .accessibilityLabel(
                        String(localized: "search.excluded.a11y",
                               defaultValue: "Excluded terms, comma separated")
                    )

                    Picker(
                        String(localized: "search.boolean.label",
                               defaultValue: "Keyword mode"),
                        selection: $vm.booleanMode
                    ) {
                        Text(String(localized: "search.boolean.and",
                                    defaultValue: "All keywords (AND)"))
                            .tag(FTS5Query.BooleanMode.and)
                        Text(String(localized: "search.boolean.or",
                                    defaultValue: "Any keyword (OR)"))
                            .tag(FTS5Query.BooleanMode.or)
                    }
                } header: {
                    Text(String(localized: "search.section.advanced",
                                defaultValue: "Advanced Text"))
                }

                // Date range
                Section {
                    Toggle(
                        String(localized: "search.daterange.toggle",
                               defaultValue: "Limit by date"),
                        isOn: $vm.dateRangeEnabled
                    )
                    if vm.dateRangeEnabled {
                        DatePicker(
                            String(localized: "search.daterange.start",
                                   defaultValue: "From"),
                            selection: $vm.dateRangeStart,
                            in: ...vm.dateRangeEnd,
                            displayedComponents: .date
                        )
                        DatePicker(
                            String(localized: "search.daterange.end",
                                   defaultValue: "To"),
                            selection: $vm.dateRangeEnd,
                            in: vm.dateRangeStart...,
                            displayedComponents: .date
                        )
                        Text(String(localized: "search.daterange.help",
                                    defaultValue: "Documents without a parseable date are excluded when a date range is active."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "search.section.daterange",
                                defaultValue: "Date Range"))
                }

                // Document type
                Section {
                    @Bindable var vm = vm
                    Picker(
                        String(localized: "search.doctype.label", defaultValue: "Document type"),
                        selection: $vm.documentTypeFilter
                    ) {
                        Text(String(localized: "search.doctype.all", defaultValue: "All"))
                            .tag(DocumentTypeFilter.all)
                        Text(String(localized: "search.doctype.documents", defaultValue: "Documents only"))
                            .tag(DocumentTypeFilter.documentsOnly)
                        Text(String(localized: "search.doctype.editorial", defaultValue: "Editorial notes only"))
                            .tag(DocumentTypeFilter.editorialNotesOnly)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(
                        String(localized: "search.doctype.a11y", defaultValue: "Document type filter")
                    )
                } header: {
                    Text(String(localized: "search.section.doctype", defaultValue: "Document Type"))
                }

                // Person autocomplete filter (Session 41)
                Section {
                    @Bindable var vm = vm
                    TextField(
                        String(localized: "search.personref.placeholder",
                               defaultValue: "Search by person name…"),
                        text: $personSearchText
                    )
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .accessibilityLabel(
                        String(localized: "search.personref.a11y",
                               defaultValue: "Person name search")
                    )
                    .onChange(of: personSearchText) { _, query in
                        let trimmed = query.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty {
                            personSuggestions = []
                            if vm.personRefText.isEmpty == false { vm.personRefText = "" }
                        } else {
                            Task {
                                personSuggestions = (try? await appState.personMentionStore?
                                    .personsMatchingName(trimmed)) ?? []
                            }
                        }
                    }

                    // Suggestion list
                    if !personSuggestions.isEmpty {
                        ForEach(personSuggestions) { person in
                            Button {
                                vm.personRefText  = person.ref
                                personSearchText  = person.name
                                personSuggestions = []
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                        .font(.body)
                                    if let desc = person.description {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(person.name)
                        }
                    }

                    // Active filter badge
                    if !vm.personRefText.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vm.personRefText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                vm.personRefText  = ""
                                personSearchText  = ""
                                personSuggestions = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                String(localized: "search.personref.clear.a11y",
                                       defaultValue: "Clear person filter")
                            )
                        }
                    }

                    Text(String(localized: "search.personref.help",
                                defaultValue: "Type a person's name to filter results to documents that mention them."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "search.section.personref",
                                defaultValue: "Person"))
                }

                // Subject tags
                if !vm.availableSubjectTags.isEmpty {
                    Section {
                        ForEach(vm.availableSubjectTags) { tag in
                            Toggle(
                                isOn: Binding(
                                    get: { vm.selectedSubjectTagIds.contains(tag.subjectId) },
                                    set: { on in
                                        if on { vm.selectedSubjectTagIds.insert(tag.subjectId) }
                                        else { vm.selectedSubjectTagIds.remove(tag.subjectId) }
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tag.displayName)
                                    Text(tag.category.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel(
                                "\(tag.displayName), \(tag.category.rawValue)"
                            )
                        }
                    } header: {
                        Text(String(localized: "search.section.subjecttags",
                                    defaultValue: "Subject Tags"))
                    }
                }

                // User tags
                if !vm.availableUserTags.isEmpty {
                    Section {
                        ForEach(vm.availableUserTags) { tag in
                            Toggle(
                                isOn: Binding(
                                    get: { vm.selectedUserTagIds.contains(tag.id) },
                                    set: { on in
                                        if on { vm.selectedUserTagIds.insert(tag.id) }
                                        else { vm.selectedUserTagIds.remove(tag.id) }
                                    }
                                )
                            ) {
                                Text(tag.name)
                            }
                            .accessibilityLabel(tag.name)
                        }
                    } header: {
                        Text(String(localized: "search.section.usertags",
                                    defaultValue: "My Tags"))
                    }
                }

                // Content scope
                Section {
                    Toggle(
                        String(localized: "search.scope.summaries",
                               defaultValue: "Include summaries"),
                        isOn: $vm.includeSummaries
                    )
                    Toggle(
                        String(localized: "search.scope.notes",
                               defaultValue: "Include research notes"),
                        isOn: $vm.includeNotes
                    )
                } header: {
                    Text(String(localized: "search.section.scope",
                                defaultValue: "Search Scope"))
                }

                // Clear filters button
                if vm.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            vm.clearFilters()
                        } label: {
                            Label(
                                String(localized: "search.clearfilters",
                                       defaultValue: "Clear Filters"),
                                systemImage: "xmark.circle"
                            )
                        }
                        .accessibilityLabel(
                            String(localized: "search.clearfilters.a11y",
                                   defaultValue: "Clear all filters")
                        )
                    }
                }
            }
            #if os(iOS)
            .scrollContentBackground(.hidden)
            #endif
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if vm.isSearching {
            Spacer()
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        } else if let err = vm.searchError {
            Spacer()
            ContentUnavailableView(
                String(localized: "search.error.title", defaultValue: "Search Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
            Spacer()
        } else if vm.hasSearched && vm.results.isEmpty {
            Spacer()
            ContentUnavailableView(
                String(localized: "search.empty.title", defaultValue: "No Results"),
                systemImage: "magnifyingglass",
                description: Text(String(localized: "search.empty.detail",
                                         defaultValue: "Try different keywords or adjust your filters."))
            )
            Spacer()
        } else if !vm.results.isEmpty {
            resultCountHeader
            resultsList
        } else {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text(String(localized: "search.prompt",
                            defaultValue: "Enter keywords to search the FRUS corpus."))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
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

            // Snippet (strip <b> markers)
            let cleanSnippet = result.snippet
                .replacingOccurrences(of: "<b>", with: "")
                .replacingOccurrences(of: "</b>", with: "")
            if !cleanSnippet.isEmpty {
                Text(cleanSnippet)
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
                    .accessibilityLabel("Filter by \(tagId)")
                }
            }
        }
    }
}
