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
/// separated by an en-dash — stacked, without it, in a compact-width window — with a
/// "Reset" affordance shown only when the range has been narrowed away from its defaults.
/// Extracted verbatim from `AnalyticsView` in
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
///   1.1 — Session 3 review / #236: the year fields' width scaled with Dynamic Type via
///          `@ScaledMetric` (44 pt at the default size), meant to stop four digits clipping at
///          AX sizes. It did not: 44 pt was the field's OUTER width, `.roundedBorder` insets the
///          text inside it, and at the DEFAULT size the fields drew "18…" / "19…" (iPhone 17,
///          iOS 26.3 and 27.0, measured 2026-09-18). At AX sizes the widened row also outgrew an
///          iPhone popover and cut off the start field's leading edge. Superseded by 1.3.
///   1.2 — 2026-09-18: the year text fields carry accessibility identifiers for UI tests.
///   1.3 — 2026-09-19: each year field is as wide as a hidden twin showing "8888" in the same
///          font and style (`YearFieldSizer`), so the style's own insets are counted at every text
///          size; in a compact-width window (every iPhone in portrait) the two fields stack, because whole
///          years side by side do not fit a narrow iPhone's popover (`YearFieldsLayout`). The
///          title still truncates ("Year ra…") at AX-XXXL on iPhone, as it did before: letting it
///          wrap was tried and measured, and the popover, which sizes from the title's one-line
///          ideal, then cut the stacked End field off its bottom.
struct AnalyticsYearRangeBar: View {

    /// Start year of the range. Clamped on write to `1776...end`.
    @Binding var start: Int
    /// End year of the range. Clamped on write to `start...corpusMaxYear`.
    @Binding var end: Int

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

    /// How the control presents: `.bar` (default) keeps the full-width HStack+padding wrapper the six
    /// existing callers rely on; `.chip` renders just the 44pt `rangeChip` for the Corpus consolidated
    /// filter row (Wave B).
    enum Presentation { case bar, chip }
    var presentation: Presentation = .bar

    /// Whether the range-picker popover is presented.
    @State private var isRangePopoverPresented = false

    #if os(iOS)
    /// The PRESENTING bar's width class, read here rather than inside the popover, whose traits are
    /// its own. Compact (every iPhone in portrait) stacks the year fields; see `YearFieldsLayout`.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Whether the popover's year fields stack rather than share a row (`YearFieldsLayout`).
    private var stacksYearFields: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }


    var body: some View {
        switch presentation {
        case .bar:
            HStack(spacing: 10) {
                rangeChip
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        case .chip:
            rangeChip
        }
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
            // 44pt as a standalone bar (the 7 `.bar` callers); in the consolidated filter row the
            // chip sizes with its `.controlSize(.small)` siblings instead (Wave B).
            .frame(minHeight: presentation == .bar ? 44 : nil)
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
            HStack {
                Text(String(localized: "analytics.yearRange.label",
                            defaultValue: "Year range:"))
                    .font(.headline)
                #if os(iOS)
                Spacer()
                // MEASURED, not assumed, and TWICE (`KeyboardDismissBarReachTests`).
                //
                // The year fields are `.numberPad` — no return key — and on a default range the
                // popover's only other control, Reset, is hidden, so there was no way to put the
                // keyboard down at all. Two obvious fixes were tried and BOTH are inert here:
                // `.keyboardDismissBar()` (the shared modifier) never renders, and a Done gated
                // on a parent `@FocusState` never appears either. A `.popover` is a DETACHED
                // hosting environment — the same shape as #950's sidebar footer — so neither
                // `.keyboard` toolbar placement nor the presenting view's focus state crosses
                // into it. The test proves the field is focused (typing moves its value) and
                // counts Done buttons before and after, so neither result was a missed tap.
                //
                // Hence a plain, always-present button owned by the popover's own content. It
                // also gives the popover the dismiss control it has never had.
                Button(String(localized: "common.keyboard.done", defaultValue: "Done")) {
                    KeyboardDismissBar.dismiss()
                    isRangePopoverPresented = false
                }
                .font(.callout.weight(.semibold))
                .accessibilityIdentifier("yearRangeDone")
                #endif
            }

            YearFieldsLayout(stacked: stacksYearFields) { stacked in
                yearEntryField(
                    value: $start,
                    bounds: 1776...end,
                    accessibilityLabel: String(localized: "analytics.yearRange.start.a11y",
                                               defaultValue: "Start year"),
                    identifier: "analytics.yearRange.startField"
                )

                // Side by side only: alone on a line of its own it would read as a minus sign,
                // and top-to-bottom order already says start, then end.
                if !stacked {
                    Text(verbatim: "–")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }

                yearEntryField(
                    value: $end,
                    bounds: start...corpusMaxYear,
                    accessibilityLabel: String(localized: "analytics.yearRange.end.a11y",
                                               defaultValue: "End year"),
                    identifier: "analytics.yearRange.endField"
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
    ///
    /// `identifier` names the TEXT FIELD for UI tests, which cannot tell it from the term field
    /// any other way: both are text fields with a value, and iOS 27 lists the term field (behind
    /// the popover) FIRST where iOS 26 listed the year fields first, so a "first field with a
    /// value" query tapped the covered term field and typed into nothing
    /// (`KeyboardDismissBarReachTests`, 2026-09-18).
    ///
    /// The field's width is NOT a number here. `YearFieldSizer` — the same control in the same
    /// font and style, showing "8888" — decides it, and the real field is laid over the sizer,
    /// where it is proposed exactly the sizer's size and takes it (1.3).
    private func yearEntryField(
        value: Binding<Int>,
        bounds: ClosedRange<Int>,
        accessibilityLabel: String,
        identifier: String
    ) -> some View {
        // Clamp on write so a typed (or stepped) value can never escape `bounds`.
        let clamped = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, bounds.lowerBound), bounds.upperBound) }
        )
        return Stepper(value: clamped, in: bounds) {
            YearFieldSizer()
                .overlay {
                    TextField(
                        String(localized: "analytics.yearRange.field.placeholder",
                               defaultValue: "Year"),
                        value: clamped,
                        format: YearFieldChrome.format
                    )
                    .modifier(YearFieldChrome())
                    .accessibilityIdentifier(identifier)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Year fields

/// The year-range popover's field row: side by side in a regular-width window and on macOS, two
/// rows — Start above End, each field with its stepper — in a compact-width one (every iPhone in
/// portrait; Plus and Pro Max iPhones are regular width in landscape and get the row).
///
/// **Why compact width always stacks, measured.** A year field is sized never to compress
/// (`YearFieldSizer`), and the side-by-side row is two fields plus about 232 pt that does not shrink
/// (two `UIStepper`s, which do not grow with Dynamic Type, the gaps and the dash — 1.2's default
/// row, 351.7 pt of popover around two 44-pt fields, less 32 pt of padding). At the DEFAULT text
/// size that is ~349 pt (fields of 58.3 pt), and an iPhone popover offers its window width less
/// 20 pt, less the popover's own padding: 350 pt on a 402-pt iPhone 17 (one point to spare), 338 on
/// a 390-pt iPhone 17e, ~323 on a 375-pt phone — and from XL up not even the iPhone 17 has room. So
/// four whole digits side by side do not fit a narrow iPhone even at the default size. Two earlier versions of 1.3 were measured and rejected: stacking only at
/// `isAccessibilitySize` left the row overflowing 375–393-pt iPhones from XL (worse than 1.2
/// there); and `ViewThatFits` stacked at the right widths but not in time — a popover sizes itself
/// from its content's IDEAL size, which `ViewThatFits` reports as the row's, so the popover kept
/// the row's height and the stacked End field hung out of its bottom (iPhone 17e, every size).
///
/// So the decision is made BEFORE the popover sizes itself, from the PRESENTING bar's horizontal
/// size class (a popover is a detached hosting environment with traits of its own — see the note
/// on the popover's Done button). In a regular-width iPad window the row fits at every size,
/// accessibility sizes included (measured on iPad Pro 13-inch and iPad mini, iOS 27). `AnyLayout`
/// keeps the fields' identity across a size-class change, so a rotation does not end an edit.
///
/// Version history:
///   1.0 — 2026-09-19: initial implementation (the year fields' width fix, `AnalyticsYearRangeBar` 1.3).
private struct YearFieldsLayout<Content: View>: View {
    /// Whether the fields stack: decided by the presenting bar, not here.
    let stacked: Bool
    /// The row's contents, told whether they are stacked (the en-dash is drawn only side by side).
    @ViewBuilder let content: (_ stacked: Bool) -> Content

    var body: some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            content(stacked)
        }
    }
}

/// The year field's look — hidden label, trailing alignment, font, text-field style and number
/// format — stated once, so `YearFieldSizer` and the real field in
/// `AnalyticsYearRangeBar.yearEntryField` cannot drift apart. A sizer in another font or style
/// would measure a field nobody sees.
///
/// Version history:
///   1.0 — 2026-09-19: initial implementation (the year fields' width fix, `AnalyticsYearRangeBar` 1.3).
private struct YearFieldChrome: ViewModifier {
    /// The year's format: no grouping separator, so 1861 never reads "1,861".
    static let format: IntegerFormatStyle<Int> = .number.grouping(.never)

    func body(content: Content) -> some View {
        content
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .font(.caption.monospacedDigit())
            .textFieldStyle(.roundedBorder)
    }
}

/// An invisible, inert year field showing "8888", whose ideal size IS the width a year field
/// needs.
///
/// **Why a real `TextField` and not a `Text`.** The width 1.1 lacked was the STYLE's, not the
/// digits': `.roundedBorder` insets its text by an amount the platform keeps private, so a
/// constant, or a constant scaled by `@ScaledMetric`, is a guess about that inset. What the twin
/// reports is MEASURED — 58.3 pt at the default size on iPhone 17, iOS 26.3 and 27.0 — and it is
/// more than digits plus the drawn inset: four caption digits are ~30.2 pt, which leaves ~28 pt,
/// while 1.2's 44-pt field drew "18…" and so drew its inset at no more than ~10 pt a side. How the
/// field's ideal width spends the difference is not public and is not guessed at here; the point of
/// measuring the control itself is that nothing has to be.
///
/// **No caret allowance, and that was measured too.** A 2-pt trailing allowance, for the insertion
/// point after the last digit, was tried and deleted: with the caret after the last digit a field
/// exactly this wide still shows all four digits (`YearRangeFieldWidthTests` step 5), and the test
/// passed at every size with the allowance and without it. `.fixedSize()`
/// asks the field for its ideal width, which is its content plus the style's own insets, so this
/// measures the control that actually renders, at the reader's text size and weight.
///
/// **Why "8888" and not the value on show.** With `.monospacedDigit()` every digit shares one
/// advance, so any four-digit year is exactly as wide as this; and a width that followed the value
/// would reflow the popover as the reader types (a transient fifth digit before the clamp) and
/// collapse when a field is cleared.
///
/// It is hidden, disabled — never a focus or Tab stop — and hidden from assistive technology: the
/// `ArchivesReservedLabel` pattern (Browse ▸ Archives). The overlay laid on it from outside is
/// none of those things, because these modifiers apply inside this view only.
///
/// Version history:
///   1.0 — 2026-09-19: initial implementation (the year fields' width fix, `AnalyticsYearRangeBar` 1.3).
private struct YearFieldSizer: View {
    /// 1.1's DEFAULT-size width, as a floor and never as the reason four digits fit: should a
    /// platform ever report a smaller ideal width, the field is no narrower than 1.1's was at the
    /// default size. The outer `.fixedSize()` is what makes the MEASURED width binding: without it
    /// a crowded row could propose anything down to the floor, and 44 pt is exactly the width that
    /// truncated.
    private static let minimumWidth: CGFloat = 44

    var body: some View {
        TextField(value: .constant(8888), format: YearFieldChrome.format, prompt: nil) {
            EmptyView()
        }
        .modifier(YearFieldChrome())
        .fixedSize()
        .frame(minWidth: Self.minimumWidth)
        .fixedSize()
        .disabled(true)
        .hidden()
        .accessibilityHidden(true)
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
///
/// Version history:
///   1.0 — #189-B: initial implementation
///   1.1 — #1274: the Topic-index door switches to the Browse tab on iOS, tells a sheet host to
///          close first, and is withheld where the hand-off cannot be delivered
struct AnalyticsScopeBar: View {

    /// Shared app state — for the Topic-index door (#1040). `@Environment` is safe here for the
    /// reasons `SeriesScopeBar` records: every host holds it, every scene provides it, no previews.
    @Environment(AppState.self) private var appState
    /// The scene this bar renders in, so the hand-off addresses the presenting window (#338).
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

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
    /// Invoked just before the Topic-index door navigates away, so a host presented as a SHEET can
    /// close itself first (#1274). `nil` in a host that must stay — every window passes none.
    ///
    /// Injected rather than read as `@Environment(\.dismiss)`, because this bar is the content of
    /// five iOS window scenes and five macOS windows as well as of seven iOS sheet presentations,
    /// and in a window `dismiss()` closes the scene: the reader's first landmark tap would shut the
    /// window they were reading. `CrossReferenceAnalyticsView` argues the same rule at its own
    /// `onNavigate`. (The seven: `BrowserView`'s four, the tab shell's Archival Analytics sheet,
    /// the semantic map opened from a document, and the Research Guide's own Archival sheet — the
    /// nested one, where the door has two sheets to close and `ArchivalAnalyticsView` closes both.)
    var onNavigateAway: (() -> Void)? = nil

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
            // A category is a HEADING, not a scope (#1040) — see `narrowingCategories`.
            ForEach(ScopeFacets.narrowingCategories(resolvedByVolume: resolved)) { category in
                Menu(category.label) {
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

            // #1040: where a reader goes when no topic AREA narrows enough. Subject grain does, and
            // since #1023 there is a surface for it. After the categories — the finer alternative,
            // not the headline.
            topicIndexDoor
          }
        }
    }

    /// The Topic-index door, and — on iOS — whether it is offered at all (#1023, #1274).
    ///
    /// **On iOS the door is WITHHELD where this hand-off cannot be delivered**, because the two
    /// halves of it fail differently and the pair is worse than neither. This bar is the content of
    /// five iOS window scenes as well as of the sheets listed on `onNavigateAway`, and none of those
    /// scenes publishes a scene id, so on a Full Screen Apps iPad `sceneID` is nil here. With an
    /// undeliverable scene `openSubjectExplorer` addresses something no Browse view can consume,
    /// while `openTab` falls back to ANY window — so the pair would leave a background main window
    /// sitting on an empty Browse tab, which is worse than the honest no-op it replaced.
    /// Withholding the control is the house answer to a door into a context that cannot receive it,
    /// and it is what the facet panel already does with this same door.
    ///
    /// **`.anyWindow` is tested beside nil, and that is not belt-and-braces.** This is the one
    /// hand-off consumed STRICTLY — `BrowserView.consumePendingSubjectExplorer` takes no
    /// `orAnyWindow:` — so `.anyWindow` is as undeliverable here as nil while `openTab` accepts it.
    /// Nothing hands this bar `.anyWindow` today; several `sceneID ?? .anyWindow` injections
    /// elsewhere in the tree are one presentation away from it.
    ///
    /// **The sheet presentations are unaffected, and that was measured rather than assumed**:
    /// a probe sheet presented from `MainTabView` with no injection at all read the tab shell's own
    /// scene id, so a sheet inherits `\.sceneID` and the guard only ever closes a door in a window.
    ///
    /// The test is `SceneID.tabHandoffOpensInFront(from:)`, which the rail's topic chips and the
    /// person sheet's Find all mentions are gated on too; since #1351 it also refuses a BORROWED
    /// scene, the launcher's identity an aux window republishes, which delivers both halves to a
    /// window the reader is not in.
    ///
    /// No withhold on macOS: `openSubjectExplorer` self-addresses the Topics window there and
    /// never reads the scene.
    @ViewBuilder
    private var topicIndexDoor: some View {
        #if os(macOS)
        Divider()
        topicIndexButton
        #else
        if SceneID.tabHandoffOpensInFront(from: sceneID) {
            Divider()
            topicIndexButton
        }
        #endif
    }

    /// The door itself: hand the Topic index to this scene, then put it in front of the reader.
    ///
    /// On iOS the tab switch is the whole of #1274 — without it the index is written to a Browse
    /// tab nobody is looking at, opening out of sight and replacing whatever history Browse held.
    /// The host is notified BEFORE the hand-off, matching the ordering `CrossReferenceAnalyticsView`
    /// records: a sheet's dismissal must not race the push it is getting out of the way of.
    private var topicIndexButton: some View {
        Button(String(localized: "analytics.scope.subject.browseIndex",
                      defaultValue: "Browse all topics…")) {
            #if os(macOS)
            appState.openSubjectExplorer(.all, from: sceneID)
            openWindow.fronting(id: "frus.subjects")
            #else
            onNavigateAway?()
            appState.openSubjectExplorer(.all, from: sceneID)
            appState.openTab(.browse, from: sceneID)
            #endif
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

    /// How the selector presents: `.bar` (default) is the full-width labelled bar the existing
    /// callers use; `.chip` is a compact bordered menu chip for the Corpus consolidated filter row.
    enum Presentation { case bar, chip }
    var presentation: Presentation = .bar

    var body: some View {
        switch presentation {
        case .bar:  barBody
        case .chip: chipBody
        }
    }

    /// The scope selector's menu items — the whole-corpus / By-Subseries / By-Volume / My Volume
    /// Scopes / By-Detected-Topic tree — shared verbatim by both presentations.
    @ViewBuilder private var scopeMenuItems: some View {
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
        // #308 Phase 3: the COMPLETE volume-grain map when the document index is bundled — the
        // profile map is top-15 per volume (10.8% of memberships). Falls back to profiles.
        if let resolved = DocumentSubjectStore.shared?.subjectsByVolume
            ?? VolumeSubjectProfilesStore.shared?.resolvedByVolume,
           !resolved.isEmpty {
            Divider()
            subjectScopeMenu(resolved)
        }
    }

    /// Full-width labelled bar (default): leading icon, the menu, and a trailing clear button.
    private var barBody: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .foregroundStyle(.secondary)
                .font(.caption)
            Menu {
                scopeMenuItems
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

    /// Compact bordered menu chip (Wave B) for the consolidated filter row: scope name + chevron.
    /// The "Whole corpus" clear action stays reachable via the menu's own first item.
    private var chipBody: some View {
        Menu {
            scopeMenuItems
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.caption2)
                Text(currentLabel)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .controlHelp(
            String(localized: "analytics.scope.menu.a11y", defaultValue: "Analysis scope"),
            detail: String(localized: "analytics.scope.menu.help",
                           defaultValue: "Restrict the analysis to a subseries or a single volume, or chart the whole corpus."),
            systemImage: "scope"
        )
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
