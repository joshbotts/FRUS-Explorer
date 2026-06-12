// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ControlHelpModifier

/// Unified "what does this control do" affordances for icon-only controls,
/// driven by a single (label, detail) string pair per control.
///
/// SwiftUI's `help(_:)` renders a visible tooltip **only on macOS** — on iOS it
/// contributes nothing visual. This modifier fans the same strings out to every
/// surface each platform actually has:
///
/// | Surface | Platform | Source |
/// |---|---|---|
/// | VoiceOver name | all | `label` |
/// | Hover tooltip | macOS | `detail` |
/// | VoiceOver hint | iOS/iPadOS | `detail` |
/// | Large Content Viewer (long-press HUD at accessibility Dynamic Type sizes) | iOS/iPadOS | `label` + `systemImage` |
///
/// A pointer-hover tooltip for iPad (UIKit's `UIToolTipInteraction`) was
/// considered and deliberately omitted: SwiftUI's `help` doesn't bridge to it,
/// and an overlay view would have to win pointer hit-testing without stealing
/// touches — a fragile hack. TipKit popovers cover proactive discovery instead.
///
/// Version history:
///   1.0 — Session 162: initial implementation
private struct ControlHelpModifier: ViewModifier {

    /// Short control name ("Reset View") — VoiceOver label and the Large
    /// Content Viewer title.
    let label: String
    /// One-sentence explanation — the macOS tooltip and iOS VoiceOver hint.
    let detail: String
    /// SF Symbol shown in the Large Content Viewer HUD, ideally matching the
    /// control's own icon. Optional; the HUD shows text alone without it.
    let systemImage: String?

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .accessibilityLabel(label)
            .help(detail)
        #else
        content
            .accessibilityLabel(label)
            .accessibilityHint(detail)
            .accessibilityShowsLargeContentViewer {
                if let systemImage {
                    Label(label, systemImage: systemImage)
                } else {
                    Text(label)
                }
            }
        #endif
    }
}

// MARK: - View + controlHelp

extension View {
    /// Applies the app's standard discoverability affordances for an icon-only
    /// control: VoiceOver label everywhere, a hover tooltip on macOS, and a
    /// VoiceOver hint plus Large Content Viewer entry on iOS/iPadOS.
    ///
    /// Use this instead of separate `accessibilityLabel`/`help` calls on any
    /// button whose visible content is just an icon:
    ///
    /// ```swift
    /// Button { vm.resetViewport() } label: {
    ///     Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
    /// }
    /// .controlHelp(
    ///     String(localized: "graph.resetView.a11y", defaultValue: "Reset View"),
    ///     detail: String(localized: "graph.resetView.help",
    ///                    defaultValue: "Restore the graph's pan and zoom to their original position"),
    ///     systemImage: "arrow.up.left.and.down.right.magnifyingglass"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - label: Short control name; becomes the VoiceOver label and the
    ///     Large Content Viewer title.
    ///   - detail: One-sentence explanation; becomes the macOS tooltip and the
    ///     iOS VoiceOver hint.
    ///   - systemImage: SF Symbol for the Large Content Viewer HUD, ideally the
    ///     control's own icon.
    func controlHelp(_ label: String, detail: String, systemImage: String? = nil) -> some View {
        modifier(ControlHelpModifier(label: label, detail: detail, systemImage: systemImage))
    }
}
