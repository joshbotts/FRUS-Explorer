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
/// ## Document-level suppression
/// `BrowserView.levelView` does **not** inject this bar when the current level is
/// `.document`. A full corpus-to-document path wraps to 2–3 rows on a narrow screen,
/// occupying ~100 pt and blocking the document header. The navigation bar title and
/// back button are sufficient once inside a document.
///
/// Version history:
///   1.0 — Session 32: initial implementation
///   1.1 — Session 50: replaced horizontal ScrollView with BreadcrumbFlowLayout so long
///          paths wrap to multiple lines instead of scrolling off-screen
///   1.2 — Session 56: expand interactive crumb tap targets to 44 pt minimum vertical
///          height (HIG requirement for touch targets on iOS)
///   1.3 — Session 121: bar is suppressed at the document level in BrowserView.levelView
///          to prevent the wrapped multi-row path from blocking document content
///   1.4 — Session 1 / #237: individual crumbs are width-capped (tail-truncated) so a
///          paragraph-length volume title can't blow up the flow layout; the full label
///          stays available to VoiceOver
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

    /// The widest a single crumb may render before its label tail-truncates. A volume
    /// crumb carries the full volume title (`entry.title`), which for older volumes can run
    /// hundreds of characters — uncapped, one crumb becomes an enormous block that blows up
    /// the wrapping flow layout. The full string stays available to VoiceOver via
    /// `accessibilityLabel`. (#237)
    private static let maxCrumbWidth: CGFloat = 220

    @ViewBuilder
    private func crumbButton(label: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        if isCurrent {
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: Self.maxCrumbWidth, alignment: .leading)
                .accessibilityLabel(label)
                // Non-interactive current crumb: match the padding of interactive crumbs
                // so the bar height stays consistent as the user navigates.
                .padding(.vertical, 12)
        } else {
            Button(action: action) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.maxCrumbWidth, alignment: .leading)
                    .accessibilityLabel(label)
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
        case .people:
            return String(localized: "browser.breadcrumb.people", defaultValue: "People")
        case .subjects:
            return String(localized: "browser.breadcrumb.subjects", defaultValue: "Topics")
        case .subseriesIndex:
            return String(localized: "browser.breadcrumb.subseriesIndex", defaultValue: "Subseries")
        case .catalogue:
            return String(localized: "browser.breadcrumb.catalogue", defaultValue: "All Volumes")
        case .volumeList(let spec):
            return spec.title
        case .administrations:
            return String(localized: "browser.breadcrumb.administrations",
                          defaultValue: "Administrations")
        case .editors:
            return String(localized: "browser.breadcrumb.editors", defaultValue: "Editors")
        case .scopes:
            return String(localized: "browser.breadcrumb.scopes", defaultValue: "My Scopes")
        case .scopeEditor:
            return String(localized: "browser.breadcrumb.scopeEditor", defaultValue: "Edit Scope")
        case .corpora:
            return String(localized: "browser.breadcrumb.corpora", defaultValue: "Working Corpora")
        case .corpusDocuments(_, let name):
            return name
        case .archives:
            return String(localized: "browser.breadcrumb.archives", defaultValue: "Archives")
        case .archivalCollection(_, let name):
            return name
        case .clusters:
            return String(localized: "browser.breadcrumb.clusters", defaultValue: "Clusters")
        case .clusterDocuments(_, let label):
            return label
        }
    }
}
