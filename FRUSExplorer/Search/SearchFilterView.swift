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
/// - **iOS**: sheet with `.medium, .large` detents; filters apply on dismiss
/// - **macOS**: live popover anchored to the Search window's "Advanced…" button
///   (UI audit C4) — edits apply to the result list immediately (the presenter
///   observes `SearchViewModel.advancedFilterSignature`); Done just closes the
///   popover, as does clicking anywhere outside it
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
///   1.3 — Session 2026-07-04 (macOS UI audit C4): macOS presentation changed from a
///          modal sheet to a live popover (view content unchanged — the popover host
///          drives live application; `dismiss()` closes the popover)
struct SearchFilterView: View {

    @Bindable var vm: SearchViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// User-defined volume scopes (#258), live via @Query so newly created/synced scopes
    /// appear in the picker without plumbing. (Per the sketch's corrected §4 contract this
    /// re-renders the MENU only — an applied scope is a seeded snapshot.)
    @Query(sort: \CustomVolumeScope.name) private var customScopes: [CustomVolumeScope]
    /// Name of the scope whose apply attempt found no indexed members (the inline warning),
    /// or `nil`. Cleared on a successful apply. Shared by the custom-scope and subject-facet
    /// rows — both seed the volume picker through the same #258 indexed-resolution guard.
    @State private var scopeWarningName: String?

    /// Whether the two-level subject-category facet picker is presented (#308 Phase 1).
    @State private var showSubjectFacet = false
    /// The label of the currently-applied subject facet (category or "category · sub-category"),
    /// or `nil`. Snapshot semantics like custom scopes: a label, not a live query field.
    @State private var subjectFacetLabel: String?
    /// The exact volume selection the subject facet seeded, or `nil` when no facet is applied.
    /// Lets the stale-clear `onChange` distinguish the facet's OWN seeding (which must not clear
    /// the label it just set — `onChange` fires after the whole apply transaction) from a manual
    /// picker edit / Clear Filters / custom-scope apply (which must clear it: the label would
    /// otherwise keep describing a selection that no longer matches it).
    @State private var subjectFacetSeededIds: [String]?

    /// Live text typed in the person-name search field.
    @State private var personSearchText: String = ""
    /// Person entries matching `personSearchText`, shown as a suggestion list.
    @State private var personSuggestions: [PersonEntry] = []

    /// This surface's persisted snippet-length override (#189-C); `0` follows the global default.
    @AppStorage(SearchDefaults.snippetLineCountMainOverrideKey) private var mainSnippetOverride = 0

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
                        clearAllFilters()
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                if showProjectScopeSection          { projectScopeSection }
                dateRangeSection
                if showVolumeScopeSections          { customScopeSection }
                if showVolumeScopeSections          { subjectFacetSection }
                if showVolumeScopeSections          { volumeScopeSectionMac }
                documentTypeSection
                personSection
                if !vm.availableUserTags.isEmpty    { userTagsSection }
                scopeSection
                resultPreviewSection
            }
            .formStyle(.grouped)
            .sheet(isPresented: $showSubjectFacet) {
                SubjectCategoryFacetPicker { ids, label in applySubjectFacet(ids, label: label) }
            }
            // Stale-clear on the Form (not inside a gated section) so it runs for every user.
            .onChange(of: vm.selectedVolumeIds) { _, newIds in clearStaleScopeState(newVolumeIds: newIds) }
            .onChange(of: vm.selectedSubseriesIds) { _, newIds in
                scopeWarningName = nil
                // A manual subseries pick means the facet label no longer describes the filter;
                // the facet's own apply only ever CLEARS subseries (newIds empty), so skip that.
                if !newIds.isEmpty { subjectFacetLabel = nil; subjectFacetSeededIds = nil }
            }

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
                if showProjectScopeSection          { projectScopeSection }
                dateRangeSection
                if showVolumeScopeSections          { customScopeSection }
                if showVolumeScopeSections          { subjectFacetSection }
                if showVolumeScopeSections          { volumeScopeSectioniOS }
                documentTypeSection
                personSection
                if !vm.availableUserTags.isEmpty    { userTagsSection }
                scopeSection
                resultPreviewSection
                if vm.hasActiveFilters              { clearSection }
            }
            .sheet(isPresented: $showSubjectFacet) {
                SubjectCategoryFacetPicker { ids, label in applySubjectFacet(ids, label: label) }
            }
            // Stale-clear on the Form (not inside a gated section) so it runs for every user.
            .onChange(of: vm.selectedVolumeIds) { _, newIds in clearStaleScopeState(newVolumeIds: newIds) }
            .onChange(of: vm.selectedSubseriesIds) { _, newIds in
                scopeWarningName = nil
                // A manual subseries pick means the facet label no longer describes the filter;
                // the facet's own apply only ever CLEARS subseries (newIds empty), so skip that.
                if !newIds.isEmpty { subjectFacetLabel = nil; subjectFacetSeededIds = nil }
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
                            clearAllFilters()
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

    // MARK: - Result Preview (#189-C)

    /// Per-surface snippet-length override for the main search results — "Follow global" defers
    /// to the Settings default.
    private var resultPreviewSection: some View {
        Section {
            SnippetLengthOverridePicker(override: $mainSnippetOverride)
        } header: {
            Text(String(localized: "search.filter.resultPreview.header", defaultValue: "Result Preview"))
        } footer: {
            Text(String(localized: "search.filter.resultPreview.footer",
                        defaultValue: "Lines of matched context shown per result on this screen."))
        }
    }

    // MARK: - Date Range

    // MARK: - Project Scope (#377 Phase 2)

    /// Whether the **History** scope option is offered — the active project has engaged
    /// documents, or History is currently selected (so the control never vanishes while it
    /// is the reason results are gated).
    private var showHistoryOption: Bool {
        !vm.projectEngagedDocumentKeys.isEmpty || vm.projectScope == .history
    }

    /// Whether the **Focus** scope option is offered — the active project has focus subjects
    /// that resolve to volumes, or Focus is currently selected (#377 Phase 2b).
    private var showFocusOption: Bool {
        !vm.projectFocusVolumeIds.isEmpty || vm.projectScope == .focus
    }

    /// Whether to show the project-scope picker at all: whenever either project mode is
    /// available, or a non-`off` scope is active (so the way back to "Entire corpus" is
    /// always in reach).
    private var showProjectScopeSection: Bool {
        showHistoryOption || showFocusOption || vm.projectScope != .off
    }

    /// Whether the manual volume-scoping sections (custom scope, subject facet, volume/
    /// subseries pickers) show. They appear in every scope, including **Focus** — a manual
    /// volume selection (or an applied custom scope) *overrides* the subject-derived Focus
    /// scope, so the researcher can steer discovery by their own volumes instead of the
    /// project's subjects (#377 Phase 2b, owner refinement).
    private var showVolumeScopeSections: Bool {
        !vm.availableVolumes.isEmpty
    }

    /// Scopes the search to the active project — **History** (its engaged documents) or
    /// **Focus** (the volumes its subjects define, optionally excluding already-engaged
    /// documents). See the `show*Option` helpers for which modes are offered.
    private var projectScopeSection: some View {
        Section {
            Picker(
                String(localized: "search.projectscope.label", defaultValue: "Scope"),
                selection: $vm.projectScope
            ) {
                Text(String(localized: "search.projectscope.off",
                            defaultValue: "Entire corpus"))
                    .tag(ProjectSearchScope.off)
                if showHistoryOption {
                    Text(String(localized: "search.projectscope.history", defaultValue: "History"))
                        .tag(ProjectSearchScope.history)
                }
                if showFocusOption {
                    Text(String(localized: "search.projectscope.focus", defaultValue: "Focus"))
                        .tag(ProjectSearchScope.focus)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(
                String(localized: "search.projectscope.a11y", defaultValue: "Project search scope")
            )

            if vm.projectScope == .focus {
                Toggle(
                    String(localized: "search.projectscope.onlynew",
                           defaultValue: "Only new to this project"),
                    isOn: $vm.projectOnlyNew
                )
            }
        } header: {
            Text(vm.projectScopeName
                 ?? String(localized: "search.section.projectscope", defaultValue: "Project"))
        } footer: {
            projectScopeFooter
        }
    }

    /// A scope-specific explanation under the picker.
    @ViewBuilder
    private var projectScopeFooter: some View {
        switch vm.projectScope {
        case .history:
            let n = vm.projectEngagedDocumentKeys.count
            Text(n == 1
                ? String(localized: "search.projectscope.footer.history.one",
                         defaultValue: "History limits results to the 1 document you've collected, annotated, or opened in this project.")
                : String(localized: "search.projectscope.footer.history.other",
                         defaultValue: "History limits results to the \(n) documents you've collected, annotated, or opened in this project."))
        case .focus:
            // A manual volume selection overrides the subject-derived scope (owner
            // refinement); the footer names whichever is driving the search.
            let usingManual = !vm.effectiveVolumeIds.isEmpty
            let count = usingManual ? vm.effectiveVolumeIds.count : vm.projectFocusVolumeIds.count
            let volumesClause: String = usingManual
                ? (count == 1
                    ? String(localized: "search.projectscope.focus.manual.one",
                             defaultValue: "your 1 selected volume")
                    : String(localized: "search.projectscope.focus.manual.other",
                             defaultValue: "your \(count) selected volumes"))
                : (count == 1
                    ? String(localized: "search.projectscope.focus.subjects.one",
                             defaultValue: "the 1 volume your project's subjects define")
                    : String(localized: "search.projectscope.focus.subjects.other",
                             defaultValue: "the \(count) volumes your project's subjects define"))
            Text(vm.projectOnlyNew
                 ? String(localized: "search.projectscope.footer.focus.onlynew",
                          defaultValue: "Focus searches \(volumesClause), excluding documents you've already engaged.")
                 : String(localized: "search.projectscope.footer.focus",
                          defaultValue: "Focus searches \(volumesClause)."))
        case .off:
            Text(String(localized: "search.projectscope.footer.off",
                        defaultValue: "Choose History to search only what you've engaged, or Focus to discover across the volumes your project's subjects define."))
        }
    }

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

    // MARK: - Custom Scopes (#258 Phase 1)

    /// User-defined named volume scopes, applied by SEEDING the two pickers below —
    /// snapshot semantics by design (the reviewed sketch's §4 v1 contract): picking a
    /// scope copies its currently-indexed members into `selectedVolumeIds`; later edits
    /// to the scope do not retroactively change this search until it is re-picked.
    ///
    /// The `IndexedResolution` invariant is enforced here: a scope with no indexed
    /// members shows a warning and seeds NOTHING — it must never fall through to an
    /// unscoped (whole-corpus) search under the scope's label.
    @ViewBuilder
    private var customScopeSection: some View {
        if !customScopes.isEmpty {
            Section {
                ForEach(customScopes) { scope in
                    customScopeRow(scope)
                }
                if let warning = scopeWarningName {
                    noneIndexedWarning(warning)
                }
            } header: {
                Text(String(localized: "search.section.customScopes",
                            defaultValue: "My Volume Scopes"))
            } footer: {
                Text(String(localized: "search.scope.custom.footer",
                            defaultValue: "Applying a scope fills the volume picker with its indexed members. Manage scopes in Settings."))
            }
            // The stale-clear onChange handlers moved to the Form (both bodies): attached here
            // they only ran when the user HAD custom scopes, so a no-scopes user's facet state
            // never stale-cleared (cumulative-review fix).
        }
    }

    /// The shared "no indexed members" refusal warning, rendered by whichever section owns the
    /// refusing control: the custom-scopes section when the user has scopes, else the subject
    /// facet section — so the #258 warn+refuse is never a silent no-op (cumulative-review fix:
    /// it previously rendered ONLY inside the `!customScopes.isEmpty` gate).
    private func noneIndexedWarning(_ name: String) -> some View {
        Label(String(format: String(
            localized: "search.scope.custom.noneIndexed %@",
            defaultValue: "No volumes of “%@” are indexed yet — download and index its volumes first."),
            name),
              systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    /// One scope row: name + "N of M indexed", applying on tap per the invariant above.
    @ViewBuilder
    private func customScopeRow(_ scope: CustomVolumeScope) -> some View {
        let indexedSet = Set(vm.availableVolumes.map(\.volumeId))
        let resolution = CustomScopeResolver.indexedResolution(
            memberVolumeIds: scope.volumeIds, indexed: indexedSet)
        Button {
            switch resolution {
            case .resolved(let ids):
                vm.selectedVolumeIds = ids.sorted()
                vm.selectedSubseriesIds = []
                scopeWarningName = nil
                // A scope apply supersedes any applied subject facet — clear its provenance
                // explicitly rather than via the selection onChange, which never fires when
                // the scope resolves to the byte-identical volume set the facet seeded.
                subjectFacetLabel = nil
                subjectFacetSeededIds = nil
            case .noIndexedMembers, .scopeUnavailable:
                scopeWarningName = scope.name
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(scope.name)
                    Group {
                        if case .resolved(let ids) = resolution {
                            Text(String(format: String(
                                localized: "search.scope.custom.indexed %lld %lld",
                                defaultValue: "%lld of %lld volumes indexed"),
                                Int64(ids.count), Int64(scope.volumeIds.count)))
                        } else {
                            Text(String(localized: "search.scope.custom.none",
                                        defaultValue: "No indexed volumes"))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "search.scope.custom.hint",
                                  defaultValue: "Fills the volume picker with this scope's indexed volumes"))
    }

    // MARK: - Subject Category Facet (#308 Phase 1)

    /// The "By Subject" facet: the top two taxonomy levels (category, sub-category) as a
    /// volume-scope filter, from the bundled volume-subject profiles. Volume-grain — a
    /// "characteristic subjects" filter, not a document-level tag (that grain is gated on
    /// #261). Applies by seeding the volume picker through the same indexed-resolution guard
    /// as custom scopes. Shown only when the profiles are bundled (visibility-gate).
    @ViewBuilder
    private var subjectFacetSection: some View {
        if VolumeSubjectProfilesStore.shared != nil {
            Section {
                Button {
                    showSubjectFacet = true
                } label: {
                    HStack {
                        Label(String(localized: "search.subject.facet.button",
                                     defaultValue: "Filter by detected topic…"),
                              systemImage: "text.book.closed")
                        Spacer()
                        if let subjectFacetLabel {
                            Text(subjectFacetLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                // Fallback surface for the refusal warning: with zero custom scopes the
                // custom-scopes section (the warning's primary home) does not render at all,
                // which used to make the facet's warn+refuse a silent no-op.
                if customScopes.isEmpty, let warning = scopeWarningName {
                    noneIndexedWarning(warning)
                }
            } header: {
                Text(String(localized: "search.section.subject",
                            defaultValue: "By Subject · Detected Topics"))
            } footer: {
                Text(String(localized: "search.subject.facet.footer",
                            defaultValue: "Experimental. These are automatically detected topics, not editorial subject headings, and may include mistags. Filters to volumes where a category is among their most characteristic detected topics, filling the volume picker with the indexed matches."))
            }
        }
    }

    /// Applies a subject facet's manifest volume set through the #258 indexed-resolution guard
    /// (review F5): a category with no indexed members warns and seeds nothing (never falls
    /// through to a whole-corpus search); otherwise it seeds `selectedVolumeIds` and clears the
    /// subseries selection, exactly like `customScopeRow`.
    private func applySubjectFacet(_ volumeIds: Set<String>, label: String) {
        let indexedSet = Set(vm.availableVolumes.map(\.volumeId))
        switch CustomScopeResolver.indexedResolution(
            memberVolumeIds: Array(volumeIds), indexed: indexedSet) {
        case .resolved(let hit):
            vm.selectedVolumeIds = hit.sorted()
            vm.selectedSubseriesIds = []
            subjectFacetLabel = label
            subjectFacetSeededIds = hit.sorted()
            scopeWarningName = nil
        case .noIndexedMembers, .scopeUnavailable:
            scopeWarningName = label
            subjectFacetLabel = nil
            subjectFacetSeededIds = nil
        }
    }

    /// The single Clear Filters action shared by all three clear controls (macOS header, iOS
    /// toolbar, iOS clear section): resets the view model AND this view's local facet/warning
    /// state directly — the `onChange` stale-clears alone miss the case where the selection was
    /// already empty when Clear was pressed (no change event fires), which would leave a facet
    /// refusal warning or label displayed over a cleared filter set.
    private func clearAllFilters() {
        vm.clearFilters()
        personSearchText  = ""
        personSuggestions = []
        scopeWarningName = nil
        subjectFacetLabel = nil
        subjectFacetSeededIds = nil
    }

    /// The stale-state clears shared by both bodies, attached to the Form so they run
    /// regardless of which sections are visible (they previously lived inside the
    /// custom-scopes section's `!customScopes.isEmpty` gate and never ran for no-scope users).
    /// The facet label survives only the facet's OWN seeding (`subjectFacetSeededIds`); any
    /// other selection change — manual picker edits, Clear Filters, a custom-scope apply —
    /// means the label no longer describes the active filter.
    private func clearStaleScopeState(newVolumeIds: [String]) {
        scopeWarningName = nil
        if newVolumeIds != (subjectFacetSeededIds ?? []) {
            subjectFacetLabel = nil
            subjectFacetSeededIds = nil
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
                clearAllFilters()
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

// MARK: - SubjectCategoryFacetPicker (#308 Phase 1)

/// A two-level subject-category picker for the search filter (#308 — the top two taxonomy
/// levels as facets, subject level reserved for a later drill-down). Categories are the outer
/// level; each expands to its sub-categories. Applying a category or a (category, sub-category)
/// hands its manifest-wide volume set back through `onApply`; the caller runs the
/// indexed-resolution guard. Volume-grain, from the bundled profiles — "characteristic
/// subjects," not document-level tags.
///
/// Platform-split chrome (the #332 rule): a `NavigationStack`/`.searchable` inside a macOS
/// sheet renders sidebar artifacts, so macOS gets a plain VStack; the list is shared.
private struct SubjectCategoryFacetPicker: View {

    /// Applies the chosen facet: its manifest volume set + a human-readable label.
    let onApply: (Set<String>, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]] {
        VolumeSubjectProfilesStore.shared?.resolvedByVolume ?? [:]
    }

    /// Categories, filtered by the search text (matches the category or any of its sub-categories).
    private var categories: [ScopeFacets.CategoryEntry] {
        let all = ScopeFacets.categoryCatalog(resolvedByVolume: resolvedByVolume)
        guard !searchText.isEmpty else { return all }
        return all.filter { cat in
            cat.label.localizedCaseInsensitiveContains(searchText)
                || ScopeFacets.subCategoryCatalog(forCategory: cat.label, resolvedByVolume: resolvedByVolume)
                    .contains { $0.subcategory.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var pickerTitle: String {
        String(localized: "search.subject.facet.title", defaultValue: "Filter by Detected Topic")
    }
    private var searchPrompt: String {
        String(localized: "search.subject.facet.prompt", defaultValue: "Search categories")
    }

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack { Text(pickerTitle).font(.headline); Spacer() }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(searchPrompt, text: $searchText).textFieldStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
            Divider()
            catalogList.listStyle(.inset)
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(minWidth: 420, minHeight: 500)
        #else
        NavigationStack {
            catalogList
                .searchable(text: $searchText, prompt: searchPrompt)
                .navigationTitle(pickerTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                    }
                }
        }
        #endif
    }

    /// The two-level list, shared by both chromes: a `DisclosureGroup` per category whose first
    /// child applies the whole category and whose remaining children apply each sub-category.
    private var catalogList: some View {
        List {
            Section {
                ForEach(categories) { category in
                    DisclosureGroup {
                        // "All of <category>" — applies the whole (coarse) category.
                        facetButton(
                            title: String(format: String(
                                localized: "search.subject.facet.wholeCategory %@",
                                defaultValue: "All of %@"), category.label),
                            reach: category.volumeCount,
                            volumeIds: ScopeFacets.volumeIds(forCategory: category.label,
                                                            resolvedByVolume: resolvedByVolume),
                            label: category.label)
                        // Sub-categories — where the facet actually discriminates (F3).
                        ForEach(ScopeFacets.subCategoryCatalog(forCategory: category.label,
                                                              resolvedByVolume: resolvedByVolume)) { sub in
                            facetButton(
                                title: sub.subcategory,
                                reach: sub.volumeCount,
                                volumeIds: ScopeFacets.volumeIds(forCategory: sub.category,
                                                                subcategory: sub.subcategory,
                                                                resolvedByVolume: resolvedByVolume),
                                label: "\(sub.category) · \(sub.subcategory)")
                        }
                    } label: {
                        reachRow(category.label, category.volumeCount, emphasize: true)
                    }
                }
            } footer: {
                Text(String(localized: "search.subject.facet.picker.footer",
                            defaultValue: "Detected topics (experimental) — automatically inferred from the text, not editorial subject headings, so some may be mistagged. A volume appears where a topic is among its most distinctive, not merely mentioned. Category filters are broad; drill into a sub-category to narrow."))
                    // Let the long explanation wrap to its full height rather than truncating to
                    // one clipped line in the macOS inset list footer (#361).
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// One applying row: title + reach; taps hand the volume set back and dismiss.
    @ViewBuilder
    private func facetButton(title: String, reach: Int,
                             volumeIds: Set<String>, label: String) -> some View {
        Button {
            onApply(volumeIds, label)
            dismiss()
        } label: {
            reachRow(title, reach, emphasize: false)
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "search.subject.facet.row.hint",
                                  defaultValue: "Filters the search to this subject's volumes"))
    }

    /// A label + "in N volumes" reach caption (the honest-reach surfacing, F3).
    private func reachRow(_ title: String, _ reach: Int, emphasize: Bool) -> some View {
        HStack {
            Text(title).font(emphasize ? .body.weight(.medium) : .callout)
            Spacer()
            Text(String(format: String(localized: "search.subject.facet.reach %lld",
                                       defaultValue: "%lld vols"), Int64(reach)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
