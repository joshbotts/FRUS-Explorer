// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - BoundedTitleHeader

/// A full, selectable volume/section title that heads a detail view but is bounded in
/// height so it can never crowd out the content below it.
///
/// FRUS titles for older volumes carry appended clauses hundreds of characters long
/// (`frus1865p4` runs 618) and are stored with the TEI source's embedded newlines and
/// indentation, so they render as tall multi-line blocks. The corpus-browser detail column
/// (`CorpusVolumeDetailView` / `CorpusSectionDocumentView`) is a **non-scrolling** `VStack`
/// with the title above a greedy `List`/phase view; an unbounded `fixedSize` title there
/// overflowed the fixed-height column and pushed the volume's contents entirely out of view.
///
/// This header measures the title's natural wrapped height and takes exactly that — up to
/// `maxHeight`, beyond which it scrolls internally. Short titles hug their content (no empty
/// band); paragraph-length titles are capped and scrollable, leaving the content list room
/// to render. The full value also remains available via the window's navigation title.
///
/// The height cap scales with the user's Dynamic Type / text-size setting (`@ScaledMetric`,
/// relative to `.headline`) so that at large text sizes proportionally more of the title
/// stays visible before it scrolls, rather than the fixed 120 pt hiding ever more of it.
///
/// Version history:
///   1.0 — Session 2026-07-08: fixes the long-title blank-detail regression from the
///          "complete long titles wrap on every platform" change (57f6b33)
///   1.1 — Session 2026-07-08 (#238 Session 1): extracted from `SupportingViews.swift`
///          into its own file and promoted `private` → `internal` so it is reusable by any
///          non-scrolling detail column; `maxHeight` is now a `@ScaledMetric` so the cap
///          grows with Dynamic Type; added `.isHeader` + combined accessibility element and
///          a `.help(title)` hover tooltip carrying the complete value
struct BoundedTitleHeader: View {
    /// The complete title text to display.
    let title: String

    /// The tallest the header may grow before it starts scrolling internally.
    ///
    /// Scaled with the user's text-size setting (relative to `.headline`) so larger type
    /// gets a proportionally taller cap; the base value matches the prior fixed 120 pt.
    @ScaledMetric(relativeTo: .headline) private var maxHeight: CGFloat = 120

    /// The title's natural wrapped height at the current column width, measured live.
    @State private var naturalHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical) {
            Text(title)
                .font(.headline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
        }
        // Hug short titles (height == natural), cap tall ones (height == maxHeight, scrolls).
        // Starts at 0 before the first measurement — a briefly-collapsed header is harmless,
        // whereas a nil/greedy height would reintroduce the very overflow this guards against.
        .frame(height: min(naturalHeight, maxHeight))
        .scrollDisabled(naturalHeight <= maxHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Read as a single heading element carrying the complete title, regardless of how
        // much is visually clipped by the height cap; `.help` surfaces the full value on hover.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .help(title)
    }
}
