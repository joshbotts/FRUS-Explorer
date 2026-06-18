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
/// ## Removed Advanced-Text Controls (Session 2026-06-08)
/// The Phrase, Prefix-wildcard, Excluded-terms fields and the Keyword-mode (AND/OR)
/// picker were removed from this sheet — `FTS5InlineQueryParser` now lets users
/// express all four directly in the main search box (`"phrase"`, `term*`, `-word`,
/// `OR`). The underlying `SearchViewModel` properties they bound to (`phrase`,
/// `prefixWildcard`, `excludedTermsText`, `booleanMode`) are retained, but only as
/// legacy/backward-compatibility state restored from `SavedSearch`/`pendingSearch`
/// snapshots created before this change — they are no longer user-editable here.
///
/// Version history:
///   1.0 — Session 62: extracted from SearchView.filterPanel (F-002)
///   1.1 — Session 2026-06-08: removed Advanced Text section (Phrase, Prefix
///          wildcard, Excluded terms, Keyword-mode picker) — superseded by
///          `FTS5InlineQueryParser` inline syntax in the main search box
///   1.2 — Session 163: added the Volume & Subseries scope section — two combining
///          multi-select pickers (iOS push-in `NavigationLink` lists; macOS inline
///          `DisclosureGroup` checkboxes) writing `vm.selectedSubseriesIds` /
///          `vm.selectedVolumeIds`. Shown only when `vm.availableVolumes` is non-empty.
struct SearchFilterView: View {

    @Bindable var vm: SearchViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Live text typed in the person-name search field.
    @State private var personSearchText: String = ""
    /// Person entries matching `personSearchText`, shown as a suggestion list.
    @State private var personSuggestions: [PersonEntry] = []

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS Body
    // NavigationStack inside a macOS sheet can push Form content outside the visible
    // bounds. Use a plain VStack with explicit button bar instead.

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "search.filters.title", defaultValue: "Filters"))
                    .font(.headline)
                Spacer()
                if vm.hasActiveFilters {
                    Button(String(localized: "search.filters.clear", defaultValue: "Clear"),
                           role: .destructive) {
                        vm.clearFilters()
                        personSearchText  = ""
                        personSuggestions = []
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                dateRangeSection
                if !vm.availableVolumes.isEmpty     { volumeScopeSectionMac }
                documentTypeSection
                personSection
                if !vm.availableUserTags.isEmpty    { userTagsSection }
                scopeSection
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "search.filters.done", defaultValue: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 420, minHeight: 480)
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        NavigationStack {
            Form {
                dateRangeSection
                if !vm.availableVolumes.isEmpty     { volumeScopeSectioniOS }
                documentTypeSection
                personSection
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
        // iOS sheet sizing only — macOS sizes `macBody` via `.frame(...)`. Guarded for
        // consistency with the other detent sheets (and to keep the iOS-only modifier
        // out of the macOS build, where `iOSBody` is compiled but never presented).
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
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
                            defaultValue: "Documents without a parseable date are excluded. Documents with only a year or month in their dateline are treated as January 1 of that period and may appear as false positives near range boundaries."))
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

            // Active filter badge — a name-typed personRef filter, or a cross-corpus rollup handed
            // off from the People browser's "Find all mentions" (shown by its display label).
            if vm.personRollupId != nil || !vm.personRefText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.personLabel ?? vm.personRefText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        vm.personRefText  = ""
                        vm.personRollupId = nil
                        vm.personLabel    = nil
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

    // MARK: - Volume & Subseries Scope

    /// Indexed volumes grouped by subseries, sorted chronologically (subseries IDs
    /// begin with a year, so a string sort is chronological). Drives both the iOS
    /// push-in pickers and the macOS disclosure pickers.
    private var subseriesGroups: [(subseries: String, volumes: [VolumeManifestEntry])] {
        Dictionary(grouping: vm.availableVolumes, by: { $0.subseries })
            .map { (subseries: $0.key, volumes: $0.value.sorted { $0.volumeId < $1.volumeId }) }
            .sorted { $0.subseries < $1.subseries }
    }

    /// "<n> selected" / "Any" trailing summary for a picker row.
    private func selectionSummary(_ count: Int) -> String {
        count == 0
            ? String(localized: "search.scope.any", defaultValue: "Any")
            : String(format: String(localized: "search.scope.selectedCount %lld",
                                    defaultValue: "%lld selected"), Int64(count))
    }

    /// Explanatory footer shared by both platforms: the two pickers combine as a union.
    private var volumeScopeFooter: Text {
        Text(String(localized: "search.scope.volume.footer",
                    defaultValue: "Subseries and volumes combine: results include every document in the chosen subseries plus any individually chosen volumes. Only indexed volumes are listed."))
    }

    // MARK: iOS — push-in pickers

    /// iOS volume-scope section: two `NavigationLink` rows that push multi-select
    /// lists. Idiomatic for the iOS filter sheet's `NavigationStack`.
    private var volumeScopeSectioniOS: some View {
        Section {
            NavigationLink {
                subseriesSelectionList
            } label: {
                HStack {
                    Text(String(localized: "search.section.subseries", defaultValue: "Subseries"))
                    Spacer()
                    Text(selectionSummary(vm.selectedSubseriesIds.count))
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                volumeSelectionList
            } label: {
                HStack {
                    Text(String(localized: "search.section.volumes", defaultValue: "Volumes"))
                    Spacer()
                    Text(selectionSummary(vm.selectedVolumeIds.count))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "search.section.volumeScope", defaultValue: "Limit to Volumes"))
        } footer: {
            volumeScopeFooter
        }
    }

    /// Pushed multi-select list of subseries (each toggles a whole subseries).
    private var subseriesSelectionList: some View {
        List {
            ForEach(subseriesGroups, id: \.subseries) { group in
                Button {
                    toggleSubseries(group.subseries)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.subseries)
                                .foregroundStyle(.primary)
                            Text(String(format: String(localized: "search.scope.volumeCount %lld",
                                                        defaultValue: "%lld volumes"),
                                        Int64(group.volumes.count)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vm.selectedSubseriesIds.contains(group.subseries) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(group.subseries)
                .accessibilityAddTraits(
                    vm.selectedSubseriesIds.contains(group.subseries) ? .isSelected : []
                )
            }
        }
        .navigationTitle(String(localized: "search.section.subseries", defaultValue: "Subseries"))
    }

    /// Pushed multi-select list of individual volumes, grouped under subseries headers.
    private var volumeSelectionList: some View {
        List {
            ForEach(subseriesGroups, id: \.subseries) { group in
                Section(group.subseries) {
                    ForEach(group.volumes) { volume in
                        Button {
                            toggleVolume(volume.volumeId)
                        } label: {
                            HStack {
                                Text(volume.title)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Spacer()
                                if vm.selectedVolumeIds.contains(volume.volumeId) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(volume.title)
                        .accessibilityAddTraits(
                            vm.selectedVolumeIds.contains(volume.volumeId) ? .isSelected : []
                        )
                    }
                }
            }
        }
        .navigationTitle(String(localized: "search.section.volumes", defaultValue: "Volumes"))
    }

    // MARK: macOS — disclosure pickers

    /// macOS volume-scope section: two `DisclosureGroup`s of checkbox toggles. The
    /// macOS filter sheet deliberately avoids `NavigationStack`, so selection stays
    /// inline within the fixed-frame sheet instead of pushing.
    private var volumeScopeSectionMac: some View {
        Section {
            DisclosureGroup {
                ForEach(subseriesGroups, id: \.subseries) { group in
                    Toggle(isOn: subseriesBinding(group.subseries)) {
                        Text(verbatim: "\(group.subseries) (\(group.volumes.count))")
                    }
                }
            } label: {
                HStack {
                    Text(String(localized: "search.section.subseries", defaultValue: "Subseries"))
                    Spacer()
                    Text(selectionSummary(vm.selectedSubseriesIds.count))
                        .foregroundStyle(.secondary)
                }
            }

            DisclosureGroup {
                ForEach(subseriesGroups, id: \.subseries) { group in
                    ForEach(group.volumes) { volume in
                        Toggle(isOn: volumeBinding(volume.volumeId)) {
                            Text(volume.title)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(String(localized: "search.section.volumes", defaultValue: "Volumes"))
                    Spacer()
                    Text(selectionSummary(vm.selectedVolumeIds.count))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "search.section.volumeScope", defaultValue: "Limit to Volumes"))
        } footer: {
            volumeScopeFooter
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Selection mutation helpers

    /// Toggles a subseries in/out of `vm.selectedSubseriesIds`.
    private func toggleSubseries(_ id: String) {
        if vm.selectedSubseriesIds.contains(id) {
            vm.selectedSubseriesIds.remove(id)
        } else {
            vm.selectedSubseriesIds.insert(id)
        }
    }

    /// Toggles an individual volume in/out of `vm.selectedVolumeIds`.
    private func toggleVolume(_ id: String) {
        if let index = vm.selectedVolumeIds.firstIndex(of: id) {
            vm.selectedVolumeIds.remove(at: index)
        } else {
            vm.selectedVolumeIds.append(id)
        }
    }

    /// Checkbox binding for a subseries toggle (macOS disclosure picker).
    private func subseriesBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { vm.selectedSubseriesIds.contains(id) },
            set: { isOn in
                if isOn { vm.selectedSubseriesIds.insert(id) }
                else    { vm.selectedSubseriesIds.remove(id) }
            }
        )
    }

    /// Checkbox binding for an individual-volume toggle (macOS disclosure picker).
    private func volumeBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { vm.selectedVolumeIds.contains(id) },
            set: { isOn in
                if isOn {
                    if !vm.selectedVolumeIds.contains(id) { vm.selectedVolumeIds.append(id) }
                } else {
                    vm.selectedVolumeIds.removeAll { $0 == id }
                }
            }
        )
    }

    // MARK: - Search Scope

    private var scopeSection: some View {
        Section {
            Toggle(
                String(localized: "search.scope.documentText",
                       defaultValue: "Include document text"),
                isOn: $vm.includeDocumentText
            )
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
            Toggle(
                String(localized: "search.scope.frontMatter",
                       defaultValue: "Include front matter"),
                isOn: $vm.includeFrontMatter
            )
            if !vm.includeDocumentText {
                Text(String(localized: "search.scope.documentText.help",
                            defaultValue: "Document text is excluded. Results will match only in summaries and/or research notes."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
