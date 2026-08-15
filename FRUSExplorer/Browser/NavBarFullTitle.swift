// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - TwoLineNavTitleView

/// A navigation-bar principal title that wraps to two lines, doubling the usable title
/// space over the system inline title (one tail-truncated line).
///
/// FRUS volume and compilation titles begin with the constant boilerplate
/// "Foreign Relations of the United States, …", so a single inline line often shows only
/// the boilerplate and truncates the distinctive tail. Rendered as a two-line principal
/// `ToolbarItem`, the example titles fit almost entirely. Paragraph-length 19th-century
/// titles still cannot fit any navigation bar — the complete value stays available in the
/// in-content title header (which scrolls) and, for VoiceOver, in this view's
/// `accessibilityLabel`, which always carries the full untruncated string.
///
/// Mirrors the existing principal-toolbar precedent in `ArchivalNeighborsSheet`.
///
/// ## The parent line (UI review F-17)
/// A compilation screen shows the compilation's title and, on regular-width iPad, nothing that
/// names the volume it belongs to: `breadcrumbBarIfAppropriate` returns `EmptyView()` there
/// because a pinned top inset composites under the floating tab bar (#238), and the Back button
/// carries one ancestor at most. `parent` restores that one level in a container the tab bar
/// cannot occlude — the principal item itself.
///
/// It is **one** level, not a path, and that is deliberate. The review asked for the full
/// breadcrumb back; a navigation bar is not a breadcrumb container, and the level that actually
/// loses its ancestor is the compilation. Measured against the shipped hierarchy: the volume
/// screen's own title already names its series and period, and the document screen has never had
/// a breadcrumb on any platform (Session 121).
///
/// Version history:
///   1.0 — Session 1 / #237: initial implementation
///   1.1 — CW-10 (UI review F-17): optional `parent` line, following `ArchivalNeighborsSheet`'s
///         stacked principal item
struct TwoLineNavTitleView: View {
    /// The complete title; shown wrapped to two lines and exposed in full to VoiceOver.
    let title: String

    /// The one ancestor worth naming — today the volume a compilation sits in — or `nil` for a
    /// screen whose own title already places it.
    var parent: String?

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                // One line when a parent rides below: two lines of subheadline plus a caption
                // overflows an inline navigation bar, and the full title is in the content header
                // either way. Without a parent this is #237's original two-line behaviour.
                .lineLimit(parent == nil ? 2 : 1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            if let parent {
                Text(parent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        // VoiceOver reads the complete title, not the visually truncated lines — and reads the
        // two lines as ONE header rather than as two unrelated labels, which is what the
        // container would otherwise announce.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(title: title, parent: parent))
        .accessibilityAddTraits(.isHeader)
    }

    /// The spoken form: the title, then the ancestor that places it.
    ///
    /// Separate and `static` so it can be tested without standing up a navigation bar — the
    /// string a VoiceOver reader hears is the whole point of the parent line for them, and a
    /// label assembled inline in `body` is unreachable from a test.
    ///
    /// - Parameters:
    ///   - title: The screen's own title, in full.
    ///   - parent: The ancestor's short name, or `nil`.
    /// - Returns: The accessibility label.
    static func accessibilityLabel(title: String, parent: String?) -> String {
        guard let parent, !parent.isEmpty else { return title }
        return String(format: String(localized: "nav.title.withParent %@ %@",
                                     defaultValue: "%1$@, in %2$@"),
                      title, parent)
    }
}
