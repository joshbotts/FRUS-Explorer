// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeAnnotationsSection

/// A volume page's "Editors’ Annotations": what editorial annotation the volume carries, in three
/// groups, and the standard layers it lacks behind a collapsed disclosure
/// (`Planning/Editors-Annotations-Design-2026-11-06.md`, §5).
///
/// One view, mounted by both volume pages, as `SemanticStorageSection` is by both storage hubs:
/// the two pages are hand-maintained twins, and a section written twice is two places to drift.
/// - **`.list`:** a `Section` in iPhone and iPad's `VolumeView`, right after the metadata header.
/// - **`.column`:** a block in the Mac's `CorpusVolumeDetailView`, below Top subjects. That column
///   does not scroll, and within its 440 pt minimum window it already holds a title of up to 120 pt
///   and Top subjects of up to 180 pt, so here the section is a disclosure, collapsed until the
///   reader opens it (which it then remembers). Open, its rows share the room left below Top
///   subjects with the volume's structure (`BoundedVolumeAnnotationsBlock`).
///
/// It renders for every volume the bundled file holds, downloaded or not, and nothing for one it
/// does not. Each row is one accessibility element; the group headings are headers.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane B
struct VolumeAnnotationsSection: View {

    /// Where the section is mounted.
    enum Host {
        /// A `Section` of a `List`.
        case list
        /// A height-bounded block in a column that does not scroll.
        case column
    }

    /// The volume whose annotations are shown.
    let volumeId: String
    /// Where the section is mounted.
    let host: Host

    var body: some View {
        if let presentation = VolumeAnnotationsPresentation(volumeId: volumeId) {
            switch host {
            case .list:
                Section {
                    VolumeAnnotationsRows(presentation: presentation)
                } header: {
                    Text(VolumeAnnotationsPresentation.title)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("volume.annotations.header")
                }
            case .column:
                BoundedVolumeAnnotationsBlock(presentation: presentation)
            }
        }
    }
}

// MARK: - VolumeAnnotationsRows

/// The section's rows: each group's heading and rows, then the disclosure of the standard layers
/// the volume lacks. Shared by both hosts.
struct VolumeAnnotationsRows: View {
    /// What the rows say.
    let presentation: VolumeAnnotationsPresentation

    /// Whether the disclosure is open; collapsed by default (§5.2).
    @State private var showsAbsent = false

    var body: some View {
        ForEach(presentation.groups) { group in
            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("volume.annotations.group.\(group.id.rawValue)")
            ForEach(group.rows) { row in
                VolumeAnnotationsRowView(row: row)
            }
        }
        if !presentation.absent.isEmpty {
            DisclosureGroup(isExpanded: $showsAbsent) {
                ForEach(presentation.absent) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label)
                        if !row.note.isEmpty {
                            Text(row.note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.accessibilityLabel)
                    .accessibilityIdentifier("volume.annotations.absent.\(row.id)")
                }
            } label: {
                Text(presentation.absentTitle)
                    .togglesDisclosure($showsAbsent)
            }
            .accessibilityIdentifier("volume.annotations.absent")
        }
    }
}

// MARK: - VolumeAnnotationsRowView

/// One layer: its symbol, its name and its counts, read by VoiceOver as one sentence. The text
/// wraps at any size and is never truncated.
struct VolumeAnnotationsRowView: View {
    /// The layer.
    let row: VolumeAnnotationsPresentation.Row

    // The symbols' column, as wide as the widest of the fifteen, `person.3`, at the body size, so
    // every row's text starts at the same place: 28 pt at the Mac's 13 pt body and 36 at iOS's
    // 17 (measured with AppKit, 2026-11-06). A floor of 22 let five symbols push their text right
    // on iOS, by up to 14 pt, and `person.3` on the Mac. It scales with the text, as the symbols do.
    #if os(macOS)
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 28
    #else
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 36
    #endif

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: row.symbol)
                .foregroundStyle(.secondary)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                Text(row.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityIdentifier("volume.annotations.\(row.id)")
    }
}

// MARK: - BoundedVolumeAnnotationsBlock

/// The section in a column that does not scroll: a disclosure headed "Editors’ Annotations",
/// collapsed until the reader opens it and remembered once they have, whose rows can never crowd the
/// volume's structure out of the Mac's `CorpusVolumeDetailView`.
///
/// Open, the rows hug a short section and scroll inside a tall one, as `BoundedSubjectsBlock`'s
/// chips do, but their height is not fixed: it may fall from the cap to a floor of about two rows.
/// The column's `VStack` gives its fixed blocks their height first and then shares what is left
/// between its flexible children, these rows and the structure list, so in a short window the two
/// split the room below Top subjects, and in a tall one the rows reach their cap. A fixed cap of 200
/// left the structure no room at all in the 440 pt minimum window: measured in the check copy on
/// 2026-11-06, Front Matter and Contents fell below the window's edge.
struct BoundedVolumeAnnotationsBlock: View {
    /// What the rows say.
    let presentation: VolumeAnnotationsPresentation

    /// Whether the reader has opened the section; it stays open for the next volume.
    @AppStorage("frus.browser.volumeAnnotations.expanded") private var isExpanded = false

    /// The tallest the open rows may grow before they scroll internally.
    @ScaledMetric(relativeTo: .body) private var maxHeight: CGFloat = 200

    /// The least the open rows are given when the column is short: about two rows, so the block still
    /// shows what it holds and scrolls to the rest.
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 64

    /// The rows' natural height at the current column width, measured live.
    @State private var naturalHeight: CGFloat = 0

    /// The height the rows were given, measured live, so that they scroll only when they need to.
    @State private var shownHeight: CGFloat = 0

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    VolumeAnnotationsRows(presentation: presentation)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
            }
            // Hug a short section; give a tall one what the column can spare, between the floor and
            // the cap, and let it scroll. Both bounds start at 0 before the first measurement.
            .frame(minHeight: min(naturalHeight, minHeight), maxHeight: min(naturalHeight, maxHeight))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
            .scrollDisabled(naturalHeight <= shownHeight + 0.5)
        } label: {
            Text(VolumeAnnotationsPresentation.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("volume.annotations.header")
                .togglesDisclosure($isExpanded)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Disclosure titles

private extension View {
    /// On the Mac, a click on a disclosure's title opens and closes it, as one on its triangle does.
    /// A Mac `DisclosureGroup` toggles from the triangle alone, a target a few points wide, and the
    /// walk of the check copy on 2026-11-06 clicked "Editors’ Annotations" first, to no effect.
    /// iOS toggles from the whole row already, so there this changes nothing.
    func togglesDisclosure(_ isExpanded: Binding<Bool>) -> some View {
        #if os(macOS)
        contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.wrappedValue.toggle() } }
        #else
        self
        #endif
    }
}
