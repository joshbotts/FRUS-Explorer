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
struct BrowserBreadcrumbBar: View {

    let path: [BrowserViewModel.BrowserLevel]
    /// Called with the index to pop to (0-based into `path`), or `nil` to clear.
    let onNavigate: (Int?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                // Root crumb — always present
                crumbButton(label: String(localized: "browser.breadcrumb.root",
                                         defaultValue: "FRUS"),
                            isCurrent: path.isEmpty) {
                    onNavigate(nil)
                }

                ForEach(Array(path.enumerated()), id: \.offset) { index, level in
                    separator
                    crumbButton(label: level.breadcrumbLabel,
                                isCurrent: index == path.count - 1) {
                        onNavigate(index)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
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
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .leading)
        } else {
            Button(action: action) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)
            }
            .buttonStyle(.plain)
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
