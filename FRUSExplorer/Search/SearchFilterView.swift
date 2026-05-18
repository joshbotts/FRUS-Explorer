// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - SearchFilterView

/// Sheet presenting all advanced search filters.
///
/// Extracted from `SearchView.filterPanel` in Session 62 (F-002) to support
/// the `.searchable`-based search bar. All filter logic and bindings are identical;
/// the presentation model changes from an inline expandable VStack to a sheet.
///
/// ## Presentation
/// - **iOS**: sheet with `.medium, .large` detents
/// - **macOS**: sheet with a fixed minimum frame
///
/// ## Person Autocomplete
/// `personSearchText` and `personSuggestions` are local state here (moved from
/// `SearchView`) because they are purely filter-scoped display state.
///
/// ## Toolbar
/// - **Done** (confirmationAction) — always visible; dismisses the sheet
/// - **Clear** (cancellationAction) — visible only when `vm.hasActiveFilters`;
///   clears all filter fields and the person search text
///
/// Version history:
///   1.0 — Session 62: extracted from SearchView.filterPanel (F-002)
struct SearchFilterView: View {

    @Bindable var vm: SearchViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Live text typed in the person-name search field.
    @State private var personSearchText: String = ""
    /// Person entries matching `personSearchText`, shown as a suggestion list.
    @State private var personSuggestions: [PersonEntry] = []

    var body: some View {
        NavigationStack {
            Form {
                advancedTextSection
                dateRangeSection
                documentTypeSection
                personSection
                if !vm.availableSubjectTags.isEmpty { subjectTagsSection }
                if !vm.availableUserTags.isEmpty    { userTagsSection }
                scopeSection
                if vm.hasActiveFilters              { clearSection }
            }
            .navigationTitle(
                String(localized: "search.filters.title", defaultValue: "Filters")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "search.filters.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
                if vm.hasActiveFilters {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "search.filters.clear",
                                      defaultValue: "Clear"),
                               role: .destructive) {
                            vm.clearFilters()
                            personSearchText  = ""
                            personSuggestions = []
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #else
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    // MARK: - Advanced Text

    private var advancedTextSection: some View {
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
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
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
    }

    // MARK: - Document Type

    private var documentTypeSection: some View {
        Section {
            Picker(
                String(localized: "search.doctype.label",
                       defaultValue: "Document type"),
                selection: $vm.documentTypeFilter
            ) {
                Text(String(localized: "search.doctype.all",
                            defaultValue: "All"))
                    .tag(DocumentTypeFilter.all)
                Text(String(localized: "search.doctype.documents",
                            defaultValue: "Documents only"))
                    .tag(DocumentTypeFilter.documentsOnly)
                Text(String(localized: "search.doctype.editorial",
                            defaultValue: "Editorial notes only"))
                    .tag(DocumentTypeFilter.editorialNotesOnly)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(
                String(localized: "search.doctype.a11y",
                       defaultValue: "Document type filter")
            )
        } header: {
            Text(String(localized: "search.section.doctype",
                        defaultValue: "Document Type"))
        }
    }

    // MARK: - Person Autocomplete

    @ViewBuilder
    private var personSection: some View {
        Section {
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
                    if !vm.personRefText.isEmpty { vm.personRefText = "" }
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
    }

    // MARK: - Subject Tags

    private var subjectTagsSection: some View {
        Section {
            ForEach(vm.availableSubjectTags) { tag in
                Toggle(
                    isOn: Binding(
                        get: { vm.selectedSubjectTagIds.contains(tag.subjectId) },
                        set: { on in
                            if on { vm.selectedSubjectTagIds.insert(tag.subjectId) }
                            else  { vm.selectedSubjectTagIds.remove(tag.subjectId) }
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
                    String(localized: "search.subjecttag.a11y",
                           defaultValue: "\(tag.displayName), \(tag.category.rawValue)")
                )
            }
        } header: {
            Text(String(localized: "search.section.subjecttags",
                        defaultValue: "Subject Tags"))
        }
    }

    // MARK: - User Tags

    private var userTagsSection: some View {
        Section {
            ForEach(vm.availableUserTags) { tag in
                Toggle(
                    isOn: Binding(
                        get: { vm.selectedUserTagIds.contains(tag.id) },
                        set: { on in
                            if on { vm.selectedUserTagIds.insert(tag.id) }
                            else  { vm.selectedUserTagIds.remove(tag.id) }
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

    // MARK: - Search Scope

    private var scopeSection: some View {
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
    }

    // MARK: - Clear Filters

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                vm.clearFilters()
                personSearchText  = ""
                personSuggestions = []
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
