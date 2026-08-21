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

    /// The query to count user tags against, or `nil` to show no counts.
    ///
    /// Supplied by the host because on macOS `vm` is the filter sheet's own view model and
    /// does not carry the search's keywords — see `SearchViewModel.loadUserTagCounts`.
    var tagCountParameters: SearchParameters? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// User-defined volume scopes (#258), live via @Query so newly created/synced scopes
    /// appear in the picker without plumbing. (Per the sketch's corrected §4 contract this
    /// re-renders the MENU only — an applied scope is a seeded snapshot.)
    @Query(sort: \CustomVolumeScope.name) private var customScopes: [CustomVolumeScope]
    @Query(sort: \WorkingCorpus.name) private var workingCorpora: [WorkingCorpus]
    /// Names the corpus that refused to apply, so the refusal is visible rather than a dead tap.
    @State private var corpusWarningName: String?
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

    /// Sort direction for the *unselected* portion of the volume/subseries pickers (#377).
    /// Volume/subseries ids are year-prefixed, so ascending = oldest first. Selected items
    /// always float to the top (in chronological order) regardless.
    @State private var volumeSortAscending = true

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
                // Working corpora ABOVE volume scopes: it is the section users could not find,
                // and with only the project picker and a collapsed date row above it, its header
                // clears the fold in every configuration. Person ABOVE document type because it
                // is the sole editor of its filter on macOS (the Type chip in the search bar is
                // not), and because it holds this Form's ONLY TextField — keeping it high limits
                // how far an initial first responder can scroll the panel.
                if showVolumeScopeSections          { workingCorpusSection }
                if showVolumeScopeSections          { customScopeSection }
                if showVolumeScopeSections          { subjectFacetSection }
                if showVolumeScopeSections          { volumeScopeSectionMac }
                personSection
                // `documentTypeSection` is DELIBERATELY ABSENT on macOS (M-4 §5). The Search
                // window's token row is now the editor for document type, and the comment above —
                // "the Type chip in the search bar is not [the editor]" — describes the state
                // before it: three chips that set the filter but explained nothing. The token's
                // menu carries the same three options and the same three tooltips.
                //
                // This is the one intentional divergence between the two bodies, and
                // `FilterPanelCollapseTests` is updated to say so rather than being worked around.
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
                // Working corpora ABOVE volume scopes: it is the section users could not find,
                // and with only the project picker and a collapsed date row above it, its header
                // clears the fold in every configuration. Person ABOVE document type because it
                // is the sole editor of its filter on macOS (the Type chip in the search bar is
                // not), and because it holds this Form's ONLY TextField — keeping it high limits
                // how far an initial first responder can scroll the panel.
                if showVolumeScopeSections          { workingCorpusSection }
                if showVolumeScopeSections          { customScopeSection }
                if showVolumeScopeSections          { subjectFacetSection }
                if showVolumeScopeSections          { volumeScopeSectioniOS }
                personSection
                documentTypeSection
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
                        // #312 follow-up: full-row tap target — both modifiers, in this order.
                        // Person names are short, so without the frame an autocomplete suggestion
                        // is only tappable on its glyphs under `.buttonStyle(.plain)`.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
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
        collapsibleSection(
            .userTags,
            title: String(localized: "search.section.usertags", defaultValue: "My Tags"),
            summary: selectionSummary(vm.selectedUserTagIds.count),
            footer: vm.hasUserTagCounts
                ? Text(String(localized: "search.usertags.countFooter",
                              defaultValue: "Counts are documents in your current results carrying that tag."))
                : Text("")
        ) {
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
                    HStack {
                        Text(tag.name)
                        Spacer()
                        tagCountLabel(for: tag)
                    }
                }
                .accessibilityLabel(tagAccessibilityLabel(for: tag))
            }
        }
        // On demand, when the sheet opens — never eagerly. One SQL pass over the match set,
        // measured at parity with a facet section and flat in tag count.
        .task(id: vm.availableUserTags.count) {
            guard let tagCountParameters else { return }
            await vm.loadUserTagCounts(
                matching: tagCountParameters, tags: vm.availableUserTags,
                service: appState.searchService, pipeline: appState.indexingPipeline)
        }
    }

    /// The trailing count for one tag, or a placeholder while counting.
    @ViewBuilder
    private func tagCountLabel(for tag: UserTag) -> some View {
        if vm.isCountingUserTags {
            ProgressView().controlSize(.small)
        } else if vm.hasUserTagCounts {
            // Zero is an answer worth showing — "this tag is not in these results" is exactly
            // what a researcher wants to know before toggling it on.
            Text((vm.userTagCounts[tag.id.uuidString] ?? 0).formatted())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    /// The whole fact, for VoiceOver, rather than a name and an unexplained number.
    private func tagAccessibilityLabel(for tag: UserTag) -> String {
        guard vm.hasUserTagCounts else { return tag.name }
        let count = vm.userTagCounts[tag.id.uuidString] ?? 0
        return String(localized: "search.usertags.a11y",
                      defaultValue: "\(tag.name): \(count) documents in your current results")
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
    // MARK: - Collapsible groups

    /// Which of the collapsible groups the user has opened this session.
    ///
    /// View state only — never persisted. A filter panel that remembered its disclosure state
    /// across launches would open differently for the same collection of filters depending on
    /// history, which is the opposite of the predictability this change is for.
    @State private var expandedGroups: Set<FilterGroup> = []

    /// The groups that collapse. Deliberately a closed set: the panel's cheap sections
    /// (date, type, person, the field toggles) stay open, because collapsing a one-row section
    /// costs a click and saves nothing.
    private enum FilterGroup: Hashable {
        case workingCorpus, customScope, subjectFacet, userTags
    }

    /// A binding that is `true` whenever the group is open **or** must be.
    ///
    /// The force term is what makes collapsing safe here. `customScopeSection` hosts
    /// `scopeWarningName` and `subjectFacetSection` is its fallback host, so a warning inside a
    /// collapsed group would be a silent no-op — precisely the failure this file already fixed
    /// once (see the fallback comment in `subjectFacetSection`). A group holding a refusal, or an
    /// applied corpus whose coverage is partial, opens itself and cannot be shut while that
    /// remains true.
    private func groupExpansion(_ group: FilterGroup, forced: Bool) -> Binding<Bool> {
        Binding(
            get: { forced || expandedGroups.contains(group) },
            set: { open in
                if open { expandedGroups.insert(group) } else { expandedGroups.remove(group) }
            }
        )
    }

    /// A section whose rows collapse behind a disclosure carrying the group's own summary.
    ///
    /// The summary is the whole point. A collapsed group that showed only its title would trade
    /// "scroll to find it" for "click to find out", which is not an improvement; a collapsed group
    /// that says *Inside "planning" · 7,500 of 67,034 matches* answers the question without the
    /// click. `Section` keeps the footer, so the explanatory prose still sits under the group.
    private func collapsibleSection<Content: View>(
        _ group: FilterGroup,
        title: String,
        summary: String?,
        forced: Bool = false,
        footer: Text,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // `content()` is evaluated eagerly rather than passed through as a closure: the parameter
        // is non-escaping, and `DisclosureGroup`'s content builder escapes. Eager evaluation is
        // also what SwiftUI does with a Section's body anyway — the disclosure controls
        // visibility, not construction.
        let rows = content()
        return Section {
            DisclosureGroup(isExpanded: groupExpansion(group, forced: forced)) {
                rows
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                    Spacer()
                    if let summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        } footer: {
            footer
        }
    }

    /// What the collapsed working-corpus group says without being opened.
    ///
    /// Carries the applied corpus's name **and** its capture provenance, because
    /// `workingCorpusRow`'s own comment states this is the moment the truncation has to be
    /// legible — so the collapsed form has to carry that fact too, not just a count.
    private var workingCorpusSummary: String {
        guard let name = vm.appliedWorkingCorpusName else {
            return selectionSummary(0)
        }
        let applied = String(localized: "search.corpus.summary.applied %@",
                             defaultValue: "Inside “\(name)”")
        guard let corpus = workingCorpora.first(where: { $0.name == name }),
              let source = corpus.sourceDescription, !source.isEmpty else { return applied }
        return "\(applied) · \(source)"
    }

    /// `true` when the working-corpus group holds something the user must not have to click for:
    /// a refusal warning, or an applied corpus this device can only partly reach.
    private var workingCorpusNeedsAttention: Bool {
        if corpusWarningName != nil { return true }
        guard let name = vm.appliedWorkingCorpusName,
              let corpus = workingCorpora.first(where: { $0.name == name }) else { return false }
        let resolution = WorkingCorpusResolver(
            indexedVolumeIds: Set(vm.availableVolumes.map(\.volumeId))).resolve(corpus)
        return !resolution.isComplete
    }

    @ViewBuilder
    private var customScopeSection: some View {
        if !customScopes.isEmpty {
            // Forced open by a refusal: this section is `scopeWarningName`'s primary host, and a
            // warning nobody can see is the same bug as no warning at all.
            collapsibleSection(
                .customScope,
                title: String(localized: "search.section.customScopes",
                              defaultValue: "My Volume Scopes"),
                summary: selectionSummary(customScopes.count),
                forced: scopeWarningName != nil,
                footer: Text(String(localized: "search.scope.custom.footer",
                                    defaultValue: "Applying a scope fills the volume picker with its indexed members. Manage scopes in Settings."))
            ) {
                ForEach(customScopes) { scope in
                    customScopeRow(scope)
                }
                if let warning = scopeWarningName {
                    noneIndexedWarning(warning)
                }
            }
            // The stale-clear onChange handlers moved to the Form (both bodies): attached here
            // they only ran when the user HAD custom scopes, so a no-scopes user's facet state
            // never stale-cleared (cumulative-review fix).
        }
    }

    /// Working corpora — the document-grain scope (M-1).
    ///
    /// Separate from "My Volume Scopes" rather than folded in with it, because the two are different
    /// grains and mixing them would make a list where tapping one row narrows to a set of volumes
    /// and the next narrows to a set of documents, with nothing saying which.
    @ViewBuilder
    private var workingCorpusSection: some View {
        if !workingCorpora.isEmpty {
            collapsibleSection(
                .workingCorpus,
                title: String(localized: "search.section.workingCorpora",
                              defaultValue: "My Working Corpora"),
                summary: workingCorpusSummary,
                forced: workingCorpusNeedsAttention,
                footer: Text(String(localized: "search.corpus.footer",
                                    defaultValue: "A working corpus is a fixed set of documents. Applying one searches only inside it. Manage them in Settings."))
            ) {
                ForEach(workingCorpora) { corpus in
                    workingCorpusRow(corpus)
                }
                if vm.appliedWorkingCorpusName != nil {
                    Button(role: .destructive) {
                        vm.clearWorkingCorpus()
                    } label: {
                        Label(String(localized: "search.corpus.clear",
                                     defaultValue: "Clear working corpus"),
                              systemImage: "xmark.circle")
                    }
                }
            }
        }
    }

    /// One corpus row: name, and how much of it this device can actually reach.
    @ViewBuilder
    private func workingCorpusRow(_ corpus: WorkingCorpus) -> some View {
        let resolution = WorkingCorpusResolver(
            indexedVolumeIds: Set(vm.availableVolumes.map(\.volumeId))).resolve(corpus)
        let isApplied = vm.appliedWorkingCorpusName == corpus.name
        Button {
            // Refuses rather than degrading, exactly as an unindexed volume scope does: applying a
            // corpus none of whose documents are indexed would otherwise set an empty gate and
            // return nothing, which reads as "no matches for your query" rather than "you have not
            // indexed this corpus".
            guard !resolution.indexedKeys.isEmpty else {
                corpusWarningName = corpus.name
                return
            }
            vm.appliedWorkingCorpusKeys = resolution.indexedKeys
            vm.appliedWorkingCorpusName = corpus.name
            vm.appliedWorkingCorpusId = corpus.id
            vm.appliedWorkingCorpusTruncation = corpus.truncationAtCapture
            corpusWarningName = nil
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(corpus.name)
                    Text(resolution.coverageDescription)
                        .font(.caption)
                        .foregroundStyle(resolution.isComplete ? Color.secondary : Color.orange)
                    // What the set IS, beneath what this device can reach of it. These are two
                    // different facts and both matter here: coverage is about this device, while
                    // `sourceDescription` says whether the corpus was ever the whole answer to its
                    // query. This is the moment the researcher decides to work inside it, so it is
                    // the moment the truncation has to be legible.
                    if let source = corpus.sourceDescription, !source.isEmpty {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if isApplied {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isApplied ? [.isSelected] : [])
        if corpusWarningName == corpus.name {
            Label(String(format: String(
                localized: "search.corpus.noneIndexed %@",
                defaultValue: "None of “%@” is indexed on this device yet — download and index its volumes first."),
                corpus.name), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
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
            // Forced open when it is hosting the refusal warning — which happens exactly when the
            // user has no custom scopes, so the primary host does not render.
            collapsibleSection(
                .subjectFacet,
                title: String(localized: "search.section.subject",
                              defaultValue: "By Subject · Detected Topics"),
                summary: subjectFacetLabel ?? selectionSummary(0),
                forced: customScopes.isEmpty && scopeWarningName != nil,
                footer: Text(String(localized: "search.subject.facet.footer",
                                    defaultValue: "Experimental. These topics are detected automatically from the text, not editorial subject headings, so some are wrong. Choosing a category finds volumes where that topic is one of their most distinctive. The volume picker then fills with the matches you have indexed."))
            ) {
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

    /// Subseries ordered for the picker (#377): selected first (chronological), then
    /// unselected in the current sort direction — so the volumes you've chosen are always at
    /// the top, easy to review or remove.
    private var orderedSubseries: [(subseries: String, volumes: [VolumeManifestEntry])] {
        let groups = subseriesGroups   // already chronological
        let selected = groups.filter { vm.selectedSubseriesIds.contains($0.subseries) }
        let unselected = groups.filter { !vm.selectedSubseriesIds.contains($0.subseries) }
        return selected + (volumeSortAscending ? unselected : unselected.reversed())
    }

    /// Volumes ordered for the picker (#377), flattened across subseries: selected first
    /// (chronological), then unselected in the current sort direction. Floating the selected
    /// volumes to the top makes a large scope (e.g. a just-applied custom scope) reviewable
    /// without scrolling the whole indexed corpus.
    private var orderedVolumes: [VolumeManifestEntry] {
        let all = vm.availableVolumes.sorted { $0.volumeId < $1.volumeId }
        let selected = all.filter { vm.selectedVolumeIds.contains($0.volumeId) }
        let unselected = all.filter { !vm.selectedVolumeIds.contains($0.volumeId) }
        return selected + (volumeSortAscending ? unselected : unselected.reversed())
    }

    /// A compact control flipping the picker sort direction (oldest ⇄ newest first).
    private var volumeSortControl: some View {
        Picker(
            String(localized: "search.scope.sort.label", defaultValue: "Order"),
            selection: $volumeSortAscending
        ) {
            Text(String(localized: "search.scope.sort.oldest", defaultValue: "Oldest first")).tag(true)
            Text(String(localized: "search.scope.sort.newest", defaultValue: "Newest first")).tag(false)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "search.scope.sort.a11y",
                                   defaultValue: "Sort order for unselected volumes"))
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

    /// Pushed multi-select list of subseries (each toggles a whole subseries). Selected
    /// subseries float to the top; the rest follow the sort control (#377).
    private var subseriesSelectionList: some View {
        List {
            Section { volumeSortControl }
            ForEach(orderedSubseries, id: \.subseries) { group in
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

    /// Pushed multi-select list of individual volumes (#377): selected volumes float to the
    /// top, the rest follow the sort control. Flattened across subseries (each row captions
    /// its subseries) so the chosen volumes are always reviewable without hunting through the
    /// whole indexed corpus.
    private var volumeSelectionList: some View {
        List {
            Section { volumeSortControl }
            ForEach(orderedVolumes) { volume in
                Button {
                    toggleVolume(volume.volumeId)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(volume.title)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(volume.subseries)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        .navigationTitle(String(localized: "search.section.volumes", defaultValue: "Volumes"))
    }

    // MARK: macOS — disclosure pickers

    /// macOS volume-scope section: two `DisclosureGroup`s of checkbox toggles. The
    /// macOS filter sheet deliberately avoids `NavigationStack`, so selection stays
    /// inline within the fixed-frame sheet instead of pushing.
    private var volumeScopeSectionMac: some View {
        Section {
            volumeSortControl

            DisclosureGroup {
                ForEach(orderedSubseries, id: \.subseries) { group in
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
                ForEach(orderedVolumes) { volume in
                    Toggle(isOn: volumeBinding(volume.volumeId)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(volume.title)
                            Text(volume.subseries)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            // iOS only (M-4). On macOS front matter is a token in the Search window's filter row,
            // where it is visible whenever it is narrowing — this toggle was buried three sections
            // down in a popover, which is why an excluded-front-matter saved search could be in
            // force with nothing on screen saying so.
            #if os(iOS)
            Toggle(
                String(localized: "search.scope.frontMatter",
                       defaultValue: "Include front matter"),
                isOn: $vm.includeFrontMatter
            )
            #endif
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

    /// #308 Phase 3: the COMPLETE volume-grain map when the document index is bundled.
    ///
    /// The profile map is top-15 per volume, so a category's volume set was the union of volumes
    /// where one of its subjects happened to RANK — measured, 11.7% of real memberships. Falls back
    /// to the profiles when the index is absent, which is the pre-Phase-3 behaviour unchanged.
    ///
    /// Computed per access and not cached: it is only read while the facet sheet is open, and a
    /// cached copy would be a second thing to invalidate for a saving nobody would notice.
    private var resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]] {
        DocumentSubjectStore.shared?.subjectsByVolume
            ?? VolumeSubjectProfilesStore.shared?.resolvedByVolume
            ?? [:]
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
                            defaultValue: "Detected topics (experimental). These are inferred from the text, not editorial subject headings, so some are wrong. A volume appears when a topic is among its most distinctive, not merely mentioned. Categories are broad. Open a sub-category to narrow the list."))
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
