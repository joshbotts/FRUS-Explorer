// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - FlowLayout

/// A minimal wrapping layout: lays children left to right, wrapping at the proposed width.
///
/// `SampleTermsRow` needs words of varying size to reflow inside a settings form whose width the
/// user can change; no stock SwiftUI container does that. The macOS Search window's filter token
/// row (M-4) needs the same thing for the same reason, which is why this moved out of
/// `WordCloudSettingsView` rather than being written a second time — the repo already carries one
/// other wrapping layout (`BreadcrumbFlowLayout`), and a third implementation of "lay out left to
/// right and wrap" would be a third thing that can drift.
///
/// Version history:
///   1.0 — S-5b: initial implementation
///   1.1 — M-4: promoted out of `WordCloudSettingsView.swift` unchanged so the Search window's
///          token row can share it
struct FlowLayout: Layout {

    /// Gap between items, horizontally and between rows.
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: width)
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height } +
            spacing * CGFloat(max(0, rows.count - 1))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, max(widest, 0)), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                // Clamp to the container: a single term wider than the row cannot be wrapped
                // (it is one word with `lineLimit(1)`), so proposing its ideal width would draw
                // it straight past the section's edge. Proposing the bound lets it ellipsize.
                let width = min(size.width, bounds.width)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(width: width, height: size.height))
                x += width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
