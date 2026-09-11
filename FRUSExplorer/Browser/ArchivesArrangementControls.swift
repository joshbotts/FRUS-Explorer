// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - Controls row

/// What an Expand All / Collapse All button acts on.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation
struct ArchivesExpansion {
    /// The sections on screen, by id.
    let sectionIDs: [String]
    /// The ids the reader has closed.
    let collapsed: Binding<Set<String>>
    /// Whether the button is unavailable — while searching, when a search already opens every
    /// match; before the sections are built; or when the list has no sections at all.
    let isDisabled: Bool
}

/// The row of arrangement controls above an Archives list — shared by the Classes lens and by
/// ``CollectionBrowserView`` in all three of its hosts, so there is one row and not three.
///
/// **It degrades rather than overflowing.** Three labelled buttons — `By Record Group`, `Document
/// Count, Descending`, `Collapse All` — do not fit one row on a narrow iPhone, so the row tries, in
/// order: everything labelled; the expand button reduced to its icon (its title stays its
/// accessibility name); and finally every control on its own line.
///
/// **And the choice between those depends only on the space, never on what is selected.** Each
/// button reserves the width of the widest label it can show, so picking a sort or a grouping cannot
/// push the row into another layout. It did before the review caught it — and because each layout
/// builds its own copy of the menus, the reflow rebuilt the menu the reader had just used, moved the
/// list and dropped VoiceOver and keyboard focus.
///
/// It carries no horizontal padding of its own: pinned above a list the host adds it, and inside a
/// list row the row's insets already provide it.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation
struct ArchivesControlsRow<Menus: View>: View {
    /// The expand/collapse control, or `nil` for a row without one.
    let expansion: ArchivesExpansion?
    /// The host's menus.
    @ViewBuilder let menus: () -> Menus

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                menus()
                if let expansion { ArchivesExpansionButton(expansion: expansion, compact: false) }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                menus()
                if let expansion { ArchivesExpansionButton(expansion: expansion, compact: true) }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 6) {
                menus()
                if let expansion { ArchivesExpansionButton(expansion: expansion, compact: false) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A label as wide as the widest of its candidates, whichever one it is showing.
///
/// The candidates are laid out invisibly under the real label and hidden from assistive technology;
/// the control around it states its own accessible name.
private struct ArchivesReservedLabel: View {
    /// The text on show.
    let title: String
    /// Every text this label can show, the one on show included.
    let candidates: [String]
    /// The symbol beside it.
    let systemImage: String

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(candidates, id: \.self) { candidate in
                Label(candidate, systemImage: systemImage)
                    .hidden()
                    .accessibilityHidden(true)
            }
            Label(title, systemImage: systemImage)
        }
    }
}

// MARK: - Expand All / Collapse All

/// Opens every section on screen when all are closed, otherwise closes them all.
///
/// Its accessibility label IS its visible text, so Voice Control can name it without the input-label
/// override the two menus need — and it is set explicitly, so the icon-only form keeps it.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation
struct ArchivesExpansionButton: View {
    /// What it acts on.
    let expansion: ArchivesExpansion
    /// Whether to show the icon alone.
    let compact: Bool

    var body: some View {
        let allCollapsed = ArchivesArrangement.allCollapsed(
            expansion.sectionIDs, collapsed: expansion.collapsed.wrappedValue)
        let title = ArchivesArrangement.expansionTitle(allCollapsed: allCollapsed)
        Button {
            expansion.collapsed.wrappedValue = ArchivesArrangement.togglingAll(
                expansion.sectionIDs, collapsed: expansion.collapsed.wrappedValue)
        } label: {
            ArchivesReservedLabel(
                title: title, candidates: ArchivesArrangement.expansionTitles,
                systemImage: allCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                .labelStyle(ArchivesExpansionLabelStyle(compact: compact))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(expansion.isDisabled || expansion.sectionIDs.isEmpty)
        // Stated, because the custom label style drops the title in the compact form and the name
        // would go with it. It is the visible text, so Label in Name holds either way.
        .accessibilityLabel(title)
        .help(title)
    }
}

/// Title and icon, or icon alone — chosen at run time, which `.labelStyle` cannot switch between
/// directly because the two built-in styles are different types.
private struct ArchivesExpansionLabelStyle: LabelStyle {
    let compact: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.icon
        } else {
            HStack(spacing: 4) {
                configuration.icon
                configuration.title
            }
        }
    }
}

// MARK: - Sort

/// The sort control both counting lenses share: a key and a direction, with the current choice
/// named on the button so a reader can see what the list is ordered by without opening it.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation, in `ArchivesBrowseView`
///   1.1 — 2026-09-10: moved here and made internal, so Source Explorer's list draws the same menu;
///          reserves its widest label, so choosing a sort cannot reflow the row
struct ArchivesSortMenu: View {
    /// The lens's sort.
    @Binding var sort: ArchivesArrangement.Sort
    /// How this lens names each key — "Name" for collections, "Class Number" for classes.
    let label: (ArchivesArrangement.SortKey) -> String

    var body: some View {
        let summary = ArchivesArrangement.sortSummary(sort, label: label)
        Menu {
            Picker(String(localized: "browser.archives.sort.by", defaultValue: "Sort By"),
                   selection: Binding(get: { sort.key }, set: { sort = sort.selecting($0) })) {
                ForEach(ArchivesArrangement.SortKey.allCases) { key in
                    Text(label(key)).tag(key)
                }
            }
            .pickerStyle(.inline)
            Picker(String(localized: "browser.archives.sort.order", defaultValue: "Order"),
                   selection: $sort.ascending) {
                Text(ArchivesArrangement.Sort.directionLabel(ascending: true)).tag(true)
                Text(ArchivesArrangement.Sort.directionLabel(ascending: false)).tag(false)
            }
            .pickerStyle(.inline)
        } label: {
            ArchivesReservedLabel(
                title: summary, candidates: ArchivesArrangement.sortSummaries(label: label),
                systemImage: "arrow.up.arrow.down")
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "browser.archives.sort.a11y", defaultValue: "Sort"))
        .accessibilityValue(summary)
        // Voice Control and Full Keyboard Access name a control by its INPUT labels, which default
        // to the accessibility label — so without these, a reader who sees "Document Count,
        // Descending" on the button and says it gets nothing (WCAG 2.5.3, Label in Name). VoiceOver
        // still reads the label and the value above.
        .accessibilityInputLabels([
            summary, label(sort.key),
            String(localized: "browser.archives.sort.a11y", defaultValue: "Sort"),
        ])
    }
}

// MARK: - Group

/// The collection list's grouping control: repository, record group, or none — the counterpart of
/// the Classes lens's division by filing era.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation, in `ArchivesBrowseView`
///   1.1 — 2026-09-10: moved here, made internal, given the Ungrouped option, and made to reserve
///          its widest label
struct ArchivesGroupingMenu: View {
    /// The stored grouping's raw value.
    @Binding var groupingRaw: String

    private var grouping: ArchivesArrangement.CollectionGrouping {
        ArchivesArrangement.CollectionGrouping(rawValue: groupingRaw) ?? .repository
    }

    var body: some View {
        Menu {
            Picker(String(localized: "browser.archives.group.by", defaultValue: "Group By"),
                   selection: Binding(get: { grouping }, set: { groupingRaw = $0.rawValue })) {
                ForEach(ArchivesArrangement.CollectionGrouping.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            ArchivesReservedLabel(
                title: grouping.summary,
                candidates: ArchivesArrangement.CollectionGrouping.allCases.map(\.summary),
                systemImage: "rectangle.stack")
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "browser.archives.group.a11y",
                                   defaultValue: "Group By"))
        .accessibilityValue(grouping.label)
        // The visible text must be speakable, for the reason the sort menu's note gives.
        .accessibilityInputLabels([
            grouping.summary, grouping.label,
            String(localized: "browser.archives.group.a11y", defaultValue: "Group By"),
        ])
    }
}

// MARK: - Section header

/// A collapsible section header: a chevron, the title, and the section's size, so a closed section
/// still says what it holds.
///
/// A Button rather than `Section(isExpanded:)`: the system's collapsible sections draw their
/// disclosure only in sidebar-style lists, and these lists are inset on both platforms.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation
struct ArchivesSectionHeader: View {
    /// The section's title.
    let title: String
    /// Its size — `34 collections`.
    let detail: String
    /// Whether its rows are shown.
    let isExpanded: Bool
    /// Whether the header can be toggled. Off while searching, when every match is shown regardless.
    var isCollapsible: Bool = true
    /// Flips the section.
    let onToggle: () -> Void

    var body: some View {
        if isCollapsible {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                    Text(verbatim: title)
                    Spacer(minLength: 8)
                    Text(verbatim: detail)
                        .monospacedDigit()
                }
                // Both modifiers, in this order — the #312 full-row tap-target idiom.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded
                ? String(localized: "browser.archives.section.expanded", defaultValue: "Expanded")
                : String(localized: "browser.archives.section.collapsed", defaultValue: "Collapsed"))
            .accessibilityHint(isExpanded
                ? String(localized: "browser.archives.section.collapseHint",
                         defaultValue: "Hides this group’s rows")
                : String(localized: "browser.archives.section.expandHint",
                         defaultValue: "Shows this group’s rows"))
            .accessibilityAddTraits(.isHeader)
        } else {
            HStack(spacing: 6) {
                Text(verbatim: title)
                Spacer(minLength: 8)
                Text(verbatim: detail)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }
}
