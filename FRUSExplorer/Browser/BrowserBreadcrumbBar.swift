// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - BrowserBreadcrumbBar

/// A horizontally scrollable breadcrumb trail showing the current navigation depth
/// within the Browser view.
///
/// Each crumb is a tappable button that pops `navigationPath` back to that level.
/// The rightmost (current) crumb is styled as primary text and is not interactive.
/// A fixed root crumb labelled "FRUS" always appears first; tapping it clears the
/// path entirely and returns to `CorpusView` in the detail pane.
///
/// ## Platform behaviour
/// The bar is added via `.safeAreaInset(edge: .top)` in `BrowserView.levelView` so
/// it floats below the navigation bar and scrolls content insets correctly on both
/// `NavigationSplitView` (iPad/macOS) and `NavigationStack` (iPhone) layouts.
///
/// Version history:
///   1.0 — Session 32: initial implementation
///   1.1 — Session 50: replaced horizontal ScrollView with BreadcrumbFlowLayout so long
///          paths wrap to multiple lines instead of scrolling off-screen
///   1.2 — Session 56: expand interactive crumb tap targets to 44 pt minimum vertical
///          height (HIG requirement for touch targets on iOS)
struct BrowserBreadcrumbBar: View {

    let path: [BrowserViewModel.BrowserLevel]
    /// Called with the index to pop to (0-based into `path`), or `nil` to clear.
    let onNavigate: (Int?) -> Void

    var body: some View {
        BreadcrumbFlowLayout(horizontalSpacing: 4, verticalSpacing: 4) {
            // Root crumb — always present, no separator
            crumbButton(label: String(localized: "browser.breadcrumb.root",
                                     defaultValue: "FRUS"),
                        isCurrent: path.isEmpty) {
                onNavigate(nil)
            }

            // Each subsequent crumb is a "separator + button" pair laid out as one unit
            // so the separator and its crumb never split across rows.
            ForEach(Array(path.enumerated()), id: \.offset) { index, level in
                HStack(spacing: 2) {
                    separator
                    crumbButton(label: level.breadcrumbLabel,
                                isCurrent: index == path.count - 1) {
                        onNavigate(index)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Private

    private var separator: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func crumbButton(label: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        if isCurrent {
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
                // Non-interactive current crumb: match the padding of interactive crumbs
                // so the bar height stays consistent as the user navigates.
                .padding(.vertical, 12)
        } else {
            Button(action: action) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // Vertical padding expands the rendered hit area to ≥ 44 pt
                    // (caption text ≈ 12 pt + 12 pt top + 12 pt bottom = 36 pt visual,
                    //  but .contentShape expands the tap zone to the full padded frame).
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - BreadcrumbFlowLayout

/// A custom SwiftUI `Layout` that wraps breadcrumb chips to new rows when they
/// overflow the available width — analogous to CSS `flex-wrap: wrap`.
///
/// ## Testability
/// `computeRowAssignments(itemWidths:containerWidth:horizontalSpacing:)` is a
/// `static` method so unit tests can verify wrapping behaviour without a render pass.
///
/// Version history:
///   1.0 — Session 50: initial implementation
struct BreadcrumbFlowLayout: Layout {

    /// Horizontal gap between items on the same row.
    var horizontalSpacing: CGFloat = 4

    /// Vertical gap between rows.
    var verticalSpacing: CGFloat = 4

    // MARK: - Row Assignment (static for testability)

    /// Assigns each item to a row, greedily packing items left-to-right and wrapping
    /// when the next item would exceed `containerWidth`.
    ///
    /// - Parameters:
    ///   - itemWidths: Measured width of each item, in layout order.
    ///   - containerWidth: Available width from the parent proposal.
    ///   - horizontalSpacing: Gap inserted between consecutive items on the same row.
    /// - Returns: An array whose element at index `i` is the 0-based row number
    ///   assigned to item `i`.
    static func computeRowAssignments(
        itemWidths: [CGFloat],
        containerWidth: CGFloat,
        horizontalSpacing: CGFloat
    ) -> [Int] {
        var assignments: [Int] = []
        var currentRow = 0
        var rowWidth: CGFloat = 0

        for (i, width) in itemWidths.enumerated() {
            if i == 0 {
                rowWidth = width
                assignments.append(0)
            } else {
                let needed = rowWidth + horizontalSpacing + width
                if needed <= containerWidth {
                    rowWidth = needed
                    assignments.append(currentRow)
                } else {
                    currentRow += 1
                    rowWidth = width
                    assignments.append(currentRow)
                }
            }
        }
        return assignments
    }

    // MARK: - Layout Protocol

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let containerWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let assignments = Self.computeRowAssignments(
            itemWidths: sizes.map(\.width),
            containerWidth: containerWidth,
            horizontalSpacing: horizontalSpacing
        )
        let rowCount = (assignments.max() ?? 0) + 1
        var maxHeightPerRow = [CGFloat](repeating: 0, count: rowCount)
        for (i, row) in assignments.enumerated() {
            maxHeightPerRow[row] = max(maxHeightPerRow[row], sizes[i].height)
        }
        let totalHeight = maxHeightPerRow.reduce(0, +)
            + CGFloat(rowCount - 1) * verticalSpacing
        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let containerWidth = bounds.width
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let assignments = Self.computeRowAssignments(
            itemWidths: sizes.map(\.width),
            containerWidth: containerWidth,
            horizontalSpacing: horizontalSpacing
        )
        let rowCount = (assignments.max() ?? 0) + 1

        // Row heights
        var maxHeightPerRow = [CGFloat](repeating: 0, count: rowCount)
        for (i, row) in assignments.enumerated() {
            maxHeightPerRow[row] = max(maxHeightPerRow[row], sizes[i].height)
        }

        // Row top y-offsets
        var rowY = [CGFloat](repeating: 0, count: rowCount)
        var y = bounds.minY
        for row in 0..<rowCount {
            rowY[row] = y
            y += maxHeightPerRow[row] + verticalSpacing
        }

        // Place subviews left-to-right within each row
        var rowX = [CGFloat](repeating: bounds.minX, count: rowCount)
        for (i, subview) in subviews.enumerated() {
            let row = assignments[i]
            subview.place(
                at: CGPoint(x: rowX[row], y: rowY[row]),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: sizes[i].width, height: maxHeightPerRow[row])
            )
            rowX[row] += sizes[i].width + horizontalSpacing
        }
    }
}

// MARK: - BrowserLevel breadcrumb label

extension BrowserViewModel.BrowserLevel {

    /// Short display label for use in the breadcrumb bar.
    var breadcrumbLabel: String {
        switch self {
        case .corpus:
            return String(localized: "browser.breadcrumb.corpus", defaultValue: "Corpus")
        case .subseries(let group):
            return group.subseries
        case .volume(let entry):
            return entry.title
        case .compilation(_, let section):
            return section.title
        case .document(let entry):
            if let num = entry.documentNumber {
                return String(localized: "browser.breadcrumb.doc",
                              defaultValue: "Doc. \(num)")
            }
            return String(entry.header.prefix(40))
        }
    }
}
