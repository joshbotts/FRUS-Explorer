// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - AnalyticsYearRangeBar

/// Compact year-range filter bar for the Corpus analytics charts.
///
/// Two clamped year-entry fields (each a `Stepper` wrapping an editable `TextField`)
/// separated by an en-dash, with a "Reset" affordance shown only when the range has
/// been narrowed away from its defaults. Extracted verbatim from `AnalyticsView` in
/// Prep-B so the forthcoming Corpus dashboards (CA-5+) can reuse the exact control
/// without duplicating it; `AnalyticsView` composes it unchanged.
///
/// The parent owns the range as two `@Binding` integers and supplies the bounds
/// context (`corpusMaxYear`, `isCompactWidth`, `isCustom`) plus the reset action, so
/// this view stays free of any `AppState` / manifest dependency.
///
/// Version history:
///   1.0 — Prep-B (analytics CA-track): lifted from `AnalyticsView.yearRangeBar` /
///          `yearEntryField` with identical appearance and behavior.
///   1.1 — Session 3 review / #236: the year fields' width scales with Dynamic Type
///          via `@ScaledMetric` (the fixed 44pt clipped four digits at AX sizes).
struct AnalyticsYearRangeBar: View {

    /// Start year of the range. Clamped on write to `1776...end`.
    @Binding var start: Int
    /// End year of the range. Clamped on write to `start...corpusMaxYear`.
    @Binding var end: Int

    /// The year fields' width: 44pt at the default type size, scaling with the
    /// `.caption` text style so four digits stay legible at accessibility Dynamic
    /// Type sizes instead of clipping.
    @ScaledMetric(relativeTo: .caption) private var yearFieldWidth: CGFloat = 44

    /// Most recent corpus year — the upper bound and the reset target for `end`.
    let corpusMaxYear: Int
    /// Retained for API stability across the seven `AnalyticsYearRangeBar` call sites (the chip
    /// presentation no longer varies by width); previously dropped the "Year range:" label on iPhone.
    let isCompactWidth: Bool
    /// `true` when the range has been narrowed away from the `1861...corpusMaxYear`
    /// default; drives the "Reset" button's visibility.
    let isCustom: Bool
    /// Resets the range to its default span (`1861...corpusMaxYear`). Owned by the
    /// parent so the default constants live in one place.
    let onReset: () -> Void

    /// Whether the range-picker popover is presented.
    @State private var isRangePopoverPresented = false

    var body: some View {
        HStack(spacing: 10) {
            rangeChip
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// The tappable range chip (design Win 2): a single 44pt tabular readout
    /// ("1914–1953 ⌄") that opens the range picker in a popover, replacing the two
    /// inline steppers whose ▲▼ hit areas were well under the 44pt touch target. The
    /// chip doubles as the at-a-glance readout of the active range.
    private var rangeChip: some View {
        Button {
            isRangePopoverPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(verbatim: "\(start)–\(end)")
                    .font(.caption.monospacedDigit())
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "analytics.yearRange.chip.a11y",
                                   defaultValue: "Year range"))
        .accessibilityValue(Text(verbatim: "\(start)–\(end)"))
        .popover(isPresented: $isRangePopoverPresented) {
            rangePickerPopover
                // Keep it a popover (not an adapted sheet) on iPhone too.
                .presentationCompactAdaptation(.popover)
        }
    }

    /// The popover content — the two clamped stepper fields plus Reset (the controls
    /// that were formerly inline). A popover here is deliberate: fine adjustment lives
    /// behind the chip rather than crowding the filter row.
    private var rangePickerPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "analytics.yearRange.label",
                        defaultValue: "Year range:"))
                .font(.headline)

            HStack(spacing: 10) {
                yearEntryField(
                    value: $start,
                    bounds: 1776...end,
                    accessibilityLabel: String(localized: "analytics.yearRange.start.a11y",
                                               defaultValue: "Start year")
                )

                Text(verbatim: "–")
                    .foregroundStyle(.tertiary)
                    .font(.caption)

                yearEntryField(
                    value: $end,
                    bounds: start...corpusMaxYear,
                    accessibilityLabel: String(localized: "analytics.yearRange.end.a11y",
                                               defaultValue: "End year")
                )
            }

            if isCustom {
                Button {
                    onReset()
                } label: {
                    Text(String(localized: "analytics.yearRange.reset",
                                defaultValue: "Reset"))
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
                .help(String(
                    localized: "analytics.yearRange.reset.help",
                    defaultValue: "Reset the year range to 1861 – current year (the full FRUS corpus span)"
                ))
            }
        }
        .padding()
        .frame(minWidth: 260)
    }

    /// A year value rendered as an editable, clamped text field paired with an
    /// up/down stepper. Typing commits a value (clamped into `bounds`), letting
    /// the user jump directly to a year instead of stepping one at a time; the
    /// stepper remains for fine adjustment.
    private func yearEntryField(
        value: Binding<Int>,
        bounds: ClosedRange<Int>,
        accessibilityLabel: String
    ) -> some View {
        // Clamp on write so a typed (or stepped) value can never escape `bounds`.
        let clamped = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, bounds.lowerBound), bounds.upperBound) }
        )
        return Stepper(value: clamped, in: bounds) {
            TextField(
                String(localized: "analytics.yearRange.field.placeholder", defaultValue: "Year"),
                value: clamped,
                format: .number.grouping(.never)
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .font(.caption.monospacedDigit())
            .frame(width: yearFieldWidth)
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - AnalyticsViewModePicker

/// The chart-vs-table segmented control for the Corpus analytics toolbar.
///
/// A two-segment `Picker` (bar-chart glyph / bulleted-list glyph) bound to an
/// `AnalyticsViewMode`. Extracted from `AnalyticsView`'s toolbar in Prep-B so the
/// same control can be reused by the forthcoming Corpus dashboards; the parent
/// supplies the binding and a `disabled` flag (the analytics view disables it until
/// a term is committed). Appearance and behavior are identical to the inline version.
///
/// Version history:
///   1.0 — Prep-B (analytics CA-track): lifted from `AnalyticsView.toolbarContent`
///          (the view-mode segment) with identical appearance and behavior.
struct AnalyticsViewModePicker: View {

    /// The active presentation mode.
    @Binding var viewMode: AnalyticsViewMode
    /// `true` to disable the control (e.g. before a term has been committed).
    var isDisabled: Bool

    var body: some View {
        Picker(
            String(localized: "analytics.viewMode.picker", defaultValue: "Display"),
            selection: $viewMode
        ) {
            Image(systemName: "chart.bar")
                .tag(AnalyticsViewMode.chart)
                .accessibilityLabel(
                    String(localized: "analytics.viewMode.chart.a11y", defaultValue: "Chart")
                )
            Image(systemName: "list.bullet")
                .tag(AnalyticsViewMode.table)
                .accessibilityLabel(
                    String(localized: "analytics.viewMode.table.a11y", defaultValue: "Table")
                )
        }
        .pickerStyle(.segmented)
        .disabled(isDisabled)
        .help(String(
            localized: "analytics.viewMode.picker.help",
            defaultValue: "Switch between chart visualisation and a tabular list of the same data"
        ))
    }
}

// MARK: - AnalyticsScopeBar

/// A reusable analysis-scope selector for the analytics screens (#189-B).
///
/// Names the active scope — the whole corpus, a subseries, or a single volume — and lets the
/// user change it from a menu, invoking `onChange` so the host can re-run its queries with the
/// updated `scopeVolumeIds`. Uses the same `CorpusAnalyticsService.subseries(fromVolumeId:)`
/// bucketing the charts use, so scope labels line up with the By-Subseries bars.
struct AnalyticsScopeBar: View {

    /// The indexed volume IDs available to scope over (typically `AppState.indexedVolumeIds`).
    let indexedVolumeIds: Set<String>
    /// Resolves a volume ID to its display title (from the manifest).
    let volumeTitle: (String) -> String
    /// The active volume scope; `nil` means the whole corpus.
    @Binding var scopeVolumeIds: [String]?
    /// User-defined volume scopes (#258 Phase 3), live via `@Query` — the menu re-renders
    /// as scopes are created/synced. Requires the hosting scene to inject the model
    /// container (the three macOS analytics windows gained it in the same commit).
    @Query(sort: \CustomVolumeScope.name) private var customScopes: [CustomVolumeScope]
    /// Human-readable label for the active scope; `nil` when whole-corpus.
    @Binding var scopeLabel: String?
    /// Invoked after the scope changes so the host can re-run its queries.
    let onChange: () -> Void

    /// The distinct subseries spanned by the indexed corpus, sorted.
    private var indexedSubseries: [String] {
        Set(indexedVolumeIds.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0) })
            .sorted()
    }

    /// The indexed volume IDs in a subseries, sorted.
    private func volumes(inSubseries subseries: String) -> [String] {
        indexedVolumeIds
            .filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == subseries }
            .sorted()
    }

    /// Name of the active scope for the menu label.
    private var currentLabel: String {
        scopeVolumeIds == nil
            ? String(localized: "analytics.scope.wholeCorpus", defaultValue: "Whole corpus")
            : (scopeLabel ?? String(localized: "analytics.scope.custom", defaultValue: "Selected volumes"))
    }

    /// Applies a new scope (or clears it when nil/empty) and notifies the host to re-run.
    private func setScope(_ ids: [String]?, label: String?) {
        let cleaned = (ids?.isEmpty == true) ? nil : ids
        scopeVolumeIds = cleaned
        scopeLabel = cleaned == nil ? nil : label
        onChange()
    }

    /// One custom-scope menu item (#258 Phase 3): enabled with "N of M" when the scope has
    /// indexed members (applying seeds the resolved, non-empty set — snapshot semantics);
    /// disabled with an honest "none indexed" when it does not, so the `IndexedResolution`
    /// invariant holds by construction in this menu — an empty set can never reach
    /// `setScope`'s empty→nil (whole-corpus) fallback.
    @ViewBuilder
    private func customScopeItem(_ scope: CustomVolumeScope) -> some View {
        switch CustomScopeResolver.indexedResolution(memberVolumeIds: scope.volumeIds,
                                                     indexed: indexedVolumeIds) {
        case .resolved(let ids):
            Button {
                setScope(ids.sorted(), label: scope.name)
            } label: {
                Text(String(format: String(
                    localized: "analytics.scope.customScope %@ %lld %lld",
                    defaultValue: "%@ (%lld of %lld indexed)"),
                    scope.name, Int64(ids.count), Int64(scope.volumeIds.count)))
            }
        case .noIndexedMembers, .scopeUnavailable:
            Button {
                // Unreachable: disabled below. Present for the shared Button shape.
            } label: {
                Text(String(format: String(
                    localized: "analytics.scope.customScope.none %@",
                    defaultValue: "%@ — none indexed yet"), scope.name))
            }
            .disabled(true)
        }
    }

    /// The "By Subject" facet sub-menu (#308 Phase 1): a category menu whose first item scopes
    /// to the whole (coarse) category and whose remaining items scope to each sub-category —
    /// where the facet actually discriminates (review F3). Volume-grain, from the bundled
    /// profiles.
    ///
    /// Cumulative-review fix: every seeded set is **intersected with `indexedVolumeIds`** and
    /// zero-indexed entries render disabled with an honest "none indexed yet" — the same
    /// treatment as the custom-scope items in this menu. Analytics dashboards only have data
    /// for indexed volumes, so seeding the raw manifest-wide profile set silently produced
    /// empty (or partial-looking) charts for topics whose volumes aren't indexed.
    @ViewBuilder
    private func subjectScopeMenu(
        _ resolved: [String: [VolumeSubjectProfiles.ResolvedSubject]]
    ) -> some View {
        Menu(String(localized: "analytics.scope.bySubject", defaultValue: "By Detected Topic")) {
          Section(String(localized: "analytics.scope.subject.experimental",
                         defaultValue: "Detected topics — experimental")) {
            ForEach(ScopeFacets.categoryCatalog(resolvedByVolume: resolved)) { category in
                Menu(category.label) {
                    subjectFacetItem(
                        baseLabel: String(format: String(
                            localized: "analytics.scope.subject.wholeCategory %@",
                            defaultValue: "All of %@"), category.label),
                        scopeLabel: category.label,
                        profileVolumeIds: ScopeFacets.volumeIds(forCategory: category.label,
                                                                resolvedByVolume: resolved))
                    ForEach(ScopeFacets.subCategoryCatalog(forCategory: category.label,
                                                          resolvedByVolume: resolved)) { sub in
                        subjectFacetItem(
                            baseLabel: sub.subcategory,
                            scopeLabel: "\(sub.category) · \(sub.subcategory)",
                            profileVolumeIds: ScopeFacets.volumeIds(forCategory: sub.category,
                                                                    subcategory: sub.subcategory,
                                                                    resolvedByVolume: resolved))
                    }
                }
            }
          }
        }
    }

    /// One subject-facet menu item: enabled with an honest "N of M indexed" count when the
    /// topic's profile volumes intersect the index (seeding only the indexed subset, so the
    /// `setScope` empty→nil inversion can never fire), disabled with "none indexed yet"
    /// otherwise — the `customScopeItem` idiom applied to the facet.
    @ViewBuilder
    private func subjectFacetItem(baseLabel: String, scopeLabel: String,
                                  profileVolumeIds: Set<String>) -> some View {
        let indexed = profileVolumeIds.intersection(indexedVolumeIds)
        if indexed.isEmpty {
            Button {
                // Unreachable: disabled below. Present for the shared Button shape.
            } label: {
                Text(String(format: String(
                    localized: "analytics.scope.subject.none %@",
                    defaultValue: "%@ — none indexed yet"), baseLabel))
            }
            .disabled(true)
        } else {
            Button {
                setScope(indexed.sorted(), label: scopeLabel)
            } label: {
                Text(String(format: String(
                    localized: "analytics.scope.subject.indexed %@ %lld %lld",
                    defaultValue: "%@ (%lld of %lld indexed)"),
                    baseLabel, Int64(indexed.count), Int64(profileVolumeIds.count)))
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .foregroundStyle(.secondary)
                .font(.caption)
            Menu {
                Button {
                    setScope(nil, label: nil)
                } label: {
                    Label(String(localized: "analytics.scope.wholeCorpus", defaultValue: "Whole corpus"),
                          systemImage: scopeVolumeIds == nil ? "checkmark" : "globe")
                }
                let subseries = indexedSubseries
                if !subseries.isEmpty {
                    Divider()
                    Menu(String(localized: "analytics.scope.bySubseries", defaultValue: "By Subseries")) {
                        ForEach(subseries, id: \.self) { sub in
                            Button(sub) { setScope(volumes(inSubseries: sub), label: sub) }
                        }
                    }
                    Menu(String(localized: "analytics.scope.byVolume", defaultValue: "By Volume")) {
                        ForEach(subseries, id: \.self) { sub in
                            Menu(sub) {
                                ForEach(volumes(inSubseries: sub), id: \.self) { volumeId in
                                    Button(volumeTitle(volumeId)) {
                                        setScope([volumeId], label: volumeTitle(volumeId))
                                    }
                                }
                            }
                        }
                    }
                }
                // #258 Phase 3 — user-defined scopes as a third section. The invariant:
                // only a NON-EMPTY resolved set may reach setScope (whose empty→nil guard
                // would otherwise invert an empty scope into whole-corpus). Zero-indexed
                // scopes render disabled with an honest count — they cannot seed anything.
                if !customScopes.isEmpty {
                    Divider()
                    Menu(String(localized: "analytics.scope.customScopes",
                                defaultValue: "My Volume Scopes")) {
                        ForEach(customScopes) { scope in
                            customScopeItem(scope)
                        }
                    }
                }
                // #308 Phase 1 — subject category / sub-category facet (volume-grain, from the
                // bundled profiles). Each item intersects its profile volume set with
                // `indexedVolumeIds` and disables at zero (the custom-scope idiom above), so
                // every set reaching `setScope` is non-empty AND indexed — the empty→nil
                // "no filter" inversion cannot fire, and no dashboard is scoped to volumes it
                // has no data for. Content is built lazily when the sub-menu opens.
                if let resolved = VolumeSubjectProfilesStore.shared?.resolvedByVolume,
                   !resolved.isEmpty {
                    Divider()
                    subjectScopeMenu(resolved)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(format: String(localized: "analytics.scope.label %@",
                                                defaultValue: "Scope: %@"), currentLabel))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
            }
            .controlHelp(
                String(localized: "analytics.scope.menu.a11y", defaultValue: "Analysis scope"),
                detail: String(localized: "analytics.scope.menu.help",
                               defaultValue: "Restrict the analysis to a subseries or a single volume, or chart the whole corpus."),
                systemImage: "scope"
            )
            Spacer()
            if scopeVolumeIds != nil {
                Button {
                    setScope(nil, label: nil)
                } label: {
                    Text(String(localized: "analytics.scope.clear", defaultValue: "Whole corpus"))
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

// MARK: - AnalyticsCollapsibleSection

/// A collapsible chart section for the analytics dashboards (#207/#209): a tappable header
/// (title + chevron) that expands/collapses a chart body, with an optional strip of
/// chart-specific controls pinned at the top of the disclosed body.
///
/// Wrapping each chart lets users focus on one at a time, and hosting a chart's own controls
/// inside its section (instead of a shared toolbar) makes it unambiguous which chart a control
/// like "By decade" or "Out-degree" affects. The parent owns the expansion `@Binding` (typically
/// `@AppStorage`, so the choice persists), and each screen uses distinct keys so the sections
/// don't share state.
///
/// Modeled on `DocumentView.iOSPanelSectionHeader` (same chevron/animation language). Children
/// stay individually accessible; the header carries expanded/collapsed value + a header trait.
///
/// Version history:
///   1.0 — #207 (analytics UI): shared collapsible chart section.
struct AnalyticsCollapsibleSection<Controls: View, Content: View>: View {

    /// Localized section title, shown in the header and used as its accessibility label.
    let title: String
    /// Whether the section is expanded. Owned (and typically persisted) by the parent.
    @Binding var isExpanded: Bool
    /// Chart-specific controls pinned at the top of the disclosed body (empty for chartless
    /// sections). Rendered only when expanded.
    @ViewBuilder var controls: () -> Controls
    /// The chart/table body. Rendered only when expanded.
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(isExpanded
                                ? String(localized: "analytics.section.expanded", defaultValue: "Expanded")
                                : String(localized: "analytics.section.collapsed", defaultValue: "Collapsed"))

            if isExpanded {
                controls()
                content()
            }
        }
    }
}

extension AnalyticsCollapsibleSection where Controls == EmptyView {
    /// Convenience for a section with no chart-specific controls.
    init(title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, isExpanded: isExpanded, controls: { EmptyView() }, content: content)
    }
}
