// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - FRUSTheme

/// Cross-platform design token namespace for FRUS Explorer.
///
/// `FRUSTheme` is an uninhabited enum so it cannot be instantiated — all members
/// are static constants. Platform-conditional values (e.g. document padding) use
/// `#if os(macOS)` / `#else` so the correct value is baked in at compile time.
///
/// ## Usage
/// Reference tokens directly: `FRUSTheme.captionSize`, `FRUSTheme.tagCornerRadius`.
/// Shared UI components (`EditorialNoteBadge`, `FRUSTagChip`) are defined below
/// and use these tokens so visual updates propagate everywhere automatically.
///
/// Version history:
///   1.0 — Session 91: initial design token system + shared components
enum FRUSTheme {

    // MARK: Typography

    static let captionSize: CGFloat = 11
    static let captionSmallSize: CGFloat = 10
    static let sectionLabelSize: CGFloat = 10
    static let sectionLabelWeight: Font.Weight = .medium
    static let sectionLabelKerning: CGFloat = 0.8

    // MARK: Document Layout

    #if os(macOS)
    static let documentHorizontalPadding: CGFloat = 48
    static let documentTopPadding: CGFloat = 28
    #else
    static let documentHorizontalPadding: CGFloat = 16
    static let documentTopPadding: CGFloat = 16
    #endif
    static let sectionSpacing: CGFloat = 20

    // MARK: Tag Chips

    static let tagCornerRadius: CGFloat = 4
    static let tagPaddingH: CGFloat = 8
    static let tagPaddingV: CGFloat = 3

    static let systemTagBackground  = Color.secondary.opacity(0.10)
    static let systemTagForeground  = Color.secondary
    static let systemTagBorderColor = Color.secondary.opacity(0.2)
    static let userTagBackground    = Color.accentColor.opacity(0.12)
    static let userTagForeground    = Color.accentColor
    static let userTagBorderColor   = Color.accentColor.opacity(0.3)

    // MARK: Semantic Colors

    static let editorialNoteBackground = Color.purple.opacity(0.12)
    static let editorialNoteForeground = Color.purple

    // MARK: Chrome

    static let stripHeight: CGFloat = 32
    static let statusBarHeight: CGFloat = 24
}

// MARK: - EditorialNoteBadge

/// Inline badge marking editorial notes in the document identity line.
///
/// Shared across macOS and iOS. Previously a `private struct` inside
/// `MacDocumentView` (macOS-only); extracted here so iOS document views
/// can render it without duplicating the style.
struct EditorialNoteBadge: View {
    var body: some View {
        Text(String(localized: "badge.editorialNote", defaultValue: "Editorial note"))
            .font(.system(size: FRUSTheme.captionSmallSize, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(FRUSTheme.editorialNoteBackground)
            .foregroundStyle(FRUSTheme.editorialNoteForeground)
            .clipShape(RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius))
    }
}

// MARK: - FRUSTagChip

/// System and user tag chip for document tag rows.
///
/// Two visual styles:
/// - `.system`: secondary tint — subject taxonomy tags assigned by the search index
/// - `.user`: accent tint   — tags created by the researcher
///
/// Note: iOS `DocumentTagChip` (in `DocumentView.swift`) uses a Capsule shape and
/// category-based colors — intentionally different from this chip, which targets the
/// compact tag row on macOS and iPad.
struct FRUSTagChip: View {
    enum Style { case system, user }
    let label: String
    let style: Style

    var body: some View {
        Text(label)
            .font(.system(size: FRUSTheme.captionSize))
            .padding(.horizontal, FRUSTheme.tagPaddingH)
            .padding(.vertical, FRUSTheme.tagPaddingV)
            .background(style == .user ? FRUSTheme.userTagBackground : FRUSTheme.systemTagBackground)
            .foregroundStyle(style == .user ? FRUSTheme.userTagForeground : FRUSTheme.systemTagForeground)
            .clipShape(RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius)
                    .strokeBorder(
                        style == .user ? FRUSTheme.userTagBorderColor : FRUSTheme.systemTagBorderColor,
                        lineWidth: 0.5
                    )
            )
    }
}
