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
/// does not. Each row is one accessibility element; the group headings are headers. Given `onOpen`,
/// a row, and an absent row too, opens its layer's page on the Editors’ Annotations axis (§5.4).
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane B
///   1.1 — 2026-11-08: sixteen rows; `text.badge.minus` (21 pt at 17) is narrower than `person.3`
///   1.1 — 2026-11-06: lane C — `onOpen`: each row opens its layer's page on the axis
struct VolumeAnnotationsSection: View {

    /// Where the section is mounted.
    enum Host {
        /// A `Section` of a `List`.
        case list
        /// A height-bounded block in a column that does not scroll. `room` is the column's height
        /// below the blocks above this one, which the block shares with what follows it.
        case column(room: CGFloat)
    }

    /// The volume whose annotations are shown.
    let volumeId: String
    /// Where the section is mounted.
    let host: Host
    /// Opens a layer's page on the axis; `nil` leaves the rows still.
    var onOpen: (@MainActor (AnnotationLayer) -> Void)? = nil

    var body: some View {
        if let presentation = VolumeAnnotationsPresentation(volumeId: volumeId) {
            switch host {
            case .list:
                Section {
                    VolumeAnnotationsRows(presentation: presentation, onOpen: onOpen)
                } header: {
                    Text(VolumeAnnotationsPresentation.title)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("volume.annotations.header")
                }
            case .column(let room):
                BoundedVolumeAnnotationsBlock(presentation: presentation, room: room, onOpen: onOpen)
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
    /// Opens a layer's page on the axis; `nil` leaves the rows still.
    var onOpen: (@MainActor (AnnotationLayer) -> Void)? = nil

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
                opening(row.layer, label: row.accessibilityLabel,
                        identifier: "volume.annotations.\(row.id)") {
                    VolumeAnnotationsRowView(row: row, opens: onOpen != nil)
                }
            }
        }
        if !presentation.absent.isEmpty {
            DisclosureGroup(isExpanded: $showsAbsent) {
                ForEach(presentation.absent) { row in
                    opening(row.layer, label: row.accessibilityLabel,
                            identifier: "volume.annotations.absent.\(row.id)") {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label)
                                if !row.note.isEmpty {
                                    Text(row.note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if onOpen != nil { VolumeAnnotationsRowView.chevron }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } label: {
                Text(presentation.absentTitle)
                    .togglesDisclosure($showsAbsent)
            }
            .accessibilityIdentifier("volume.annotations.absent")
        }
    }

    /// A row as one accessibility element: a button that opens `layer`'s page when the host passed
    /// `onOpen`, and a still row otherwise.
    @ViewBuilder
    private func opening<Content: View>(_ layer: AnnotationLayer, label: String, identifier: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        if let onOpen {
            Button {
                onOpen(layer)
                #if DEBUG
                print("[VolumeAnnotationsRows] Open → \(layer.rawValue)")
                #endif
            } label: {
                content()
                    // Both modifiers, in this order — the #312 full-row tap-target idiom.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityHint(String(localized: "browser.volume.annotations.row.hint",
                                      defaultValue: "Opens what the editors did, and the volumes that carry it."))
            .accessibilityIdentifier(identifier)
        } else {
            content()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
        }
    }
}

// MARK: - VolumeAnnotationsRowView

/// One layer: its symbol, its name and its counts, and, when the row opens the layer's page, a
/// chevron. The text wraps at any size and is never truncated. What VoiceOver reads is set by the
/// row's container (`VolumeAnnotationsRows`), as one sentence.
struct VolumeAnnotationsRowView: View {
    /// The layer.
    let row: VolumeAnnotationsPresentation.Row
    /// `true` when the row opens the layer's page.
    var opens: Bool = false

    /// The trailing mark of a row that opens a page, as Browse's rows draw it.
    static var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    // The symbols' column, as wide as the widest of the sixteen, `person.3`, at the body size, so
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
            if opens {
                Spacer(minLength: 8)
                Self.chevron
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - BoundedVolumeAnnotationsBlock

/// The section in a column that does not scroll: a disclosure headed "Editors’ Annotations",
/// collapsed until the reader opens it and remembered once they have, whose rows can never crowd the
/// volume's structure out of the Mac's `CorpusVolumeDetailView`.
///
/// Open, the rows hug a short section and scroll inside a tall one, as `BoundedSubjectsBlock`'s
/// chips do, but their cap is not fixed: they take at most half the room the column has below Top
/// subjects, less the block's own title and padding, so the structure keeps the other half; never
/// more than 200 pt, and never less than about two rows. The host measures that room and passes it
/// in. A fixed cap of 200 left the structure no room in the 440 pt minimum window: measured in the
/// check copy on 2026-11-06, Front Matter and Contents fell below the window's edge. Nor could the
/// column's `VStack` share the room by itself: given a flexible height, the rows still took their
/// full 200 inside the Mac's `DisclosureGroup`, which lays its content out at its ideal size.
struct BoundedVolumeAnnotationsBlock: View {
    /// What the rows say.
    let presentation: VolumeAnnotationsPresentation

    /// The column's height below the blocks above this one, shared with the volume's structure.
    let room: CGFloat
    /// Opens a layer's page on the axis; `nil` leaves the rows still.
    var onOpen: (@MainActor (AnnotationLayer) -> Void)? = nil

    /// Whether the reader has opened the section; it stays open for the next volume.
    @AppStorage("frus.browser.volumeAnnotations.expanded") private var isExpanded = false

    /// The tallest the open rows may grow before they scroll internally.
    @ScaledMetric(relativeTo: .body) private var maxHeight: CGFloat = 200

    /// The least the open rows are given when the column is short: about two rows, so the block still
    /// shows what it holds and scrolls to the rest.
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 64

    /// The block's own title, the disclosure's spacing and the padding, which the room pays for too.
    @ScaledMetric(relativeTo: .headline) private var chromeHeight: CGFloat = 40

    /// The rows' natural height at the current column width, measured live.
    @State private var naturalHeight: CGFloat = 0

    /// The most the open rows may take: half the room, less the block's chrome, within the floor and
    /// the cap.
    private var rowsCap: CGFloat {
        min(maxHeight, max(minHeight, room / 2 - chromeHeight))
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    VolumeAnnotationsRows(presentation: presentation, onOpen: onOpen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
            }
            // Hug a short section (height == natural), cap a tall one (scrolls internally). Starts at
            // 0 before the first measurement, as `BoundedSubjectsBlock` does.
            .frame(height: min(naturalHeight, rowsCap))
            .scrollDisabled(naturalHeight <= rowsCap)
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
