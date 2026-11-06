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
///   reader opens it (which it then remembers), and bounded in height when open.
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: row.symbol)
                .foregroundStyle(.secondary)
                .frame(minWidth: 22)
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
/// collapsed until the reader opens it and remembered once they have, whose rows are bounded in
/// height so they can never crowd the volume's structure out of the Mac's `CorpusVolumeDetailView`.
/// As `BoundedSubjectsBlock` does, the open block hugs a short section and scrolls inside a tall
/// one, the cap scaled with the user's text size.
struct BoundedVolumeAnnotationsBlock: View {
    /// What the rows say.
    let presentation: VolumeAnnotationsPresentation

    /// Whether the reader has opened the section; it stays open for the next volume.
    @AppStorage("frus.browser.volumeAnnotations.expanded") private var isExpanded = false

    /// The tallest the open block may grow before it scrolls internally.
    @ScaledMetric(relativeTo: .body) private var maxHeight: CGFloat = 200

    /// The rows' natural height at the current column width, measured live.
    @State private var naturalHeight: CGFloat = 0

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    VolumeAnnotationsRows(presentation: presentation)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
            }
            // Hug a short section (height == natural), cap a tall one (scrolls internally).
            .frame(height: min(naturalHeight, maxHeight))
            .scrollDisabled(naturalHeight <= maxHeight)
        } label: {
            Text(VolumeAnnotationsPresentation.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("volume.annotations.header")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
