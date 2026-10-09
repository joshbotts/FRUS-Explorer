// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
// `accessibilitySpeechAnnouncementPriority`, for `TransientToast.announcement(_:)`.
import Accessibility

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
/// ## Toolbar rule (R-8) — this modifier is NOT enough on its own
/// The "VoiceOver name | all" row above is false for a **toolbar item that
/// collapses into the iPadOS navigation-bar overflow**. Measured on iPad
/// (iPadOS 26.5, `OverflowBarButtonItem` expanded): the overflow row is a UIKit
/// menu row whose accessible name is re-derived from the *content of the item's
/// `label:` closure* — a `Label`'s text if there is one, otherwise the image's
/// own accessibility name, which for `Image(systemName:)` is the **raw SF Symbol
/// string**. Modifiers applied outside the label closure — `accessibilityLabel`,
/// and therefore this one — decorate only the in-bar representation and are not
/// carried across. Overflow does not *drop* the name; it recomputes it, and
/// `.accessibilityLabel` loses to the label content even when both are present.
///
/// So for anything inside a `.toolbar`, write the name into the label closure:
///
/// ```swift
/// // ✅ announces "Analysis Tools" in the bar AND in the overflow
/// Menu { … } label: { Label(name, systemImage: "chart.bar.xaxis") }
///     .controlHelp(name, detail: …, systemImage: "chart.bar.xaxis")
///
/// // ❌ announces "chart.bar.xaxis" once the item overflows
/// Menu { … } label: { Image(systemName: "chart.bar.xaxis") }
///     .controlHelp(name, detail: …, systemImage: "chart.bar.xaxis")
/// ```
///
/// A bare `Label` still renders **icon-only** in the bar on both platforms, so
/// this costs nothing visually — do not add `.labelStyle(.iconOnly)`, which is
/// what strips the text the overflow needs. `ToolbarAccessibilityAuditTests`
/// enforces the rule across the source tree.
///
/// Version history:
///   1.0 — Session 162: initial implementation
///   1.1 — Wave R / R-8: documented the toolbar rule above. The modifier is
///          unchanged; what changed is the claim it makes — an icon-only toolbar
///          control needs its name in the label closure as well.
///   1.2 — 2026-09-30: #1483 — the examples name the graph's reset control "Reset view", the
///          text `graph.resetView.a11y` ships with.
private struct ControlHelpModifier: ViewModifier {

    /// Short control name ("Reset view") — VoiceOver label and the Large
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
    /// button whose visible content is just an icon. Inside a `.toolbar` the
    /// label closure must *also* carry the name as a `Label` — see the toolbar
    /// rule on `ControlHelpModifier`; this modifier alone does not survive the
    /// iPadOS overflow.
    ///
    /// ```swift
    /// Button { vm.resetViewport() } label: {
    ///     Label(name, systemImage: "arrow.up.left.and.down.right.magnifyingglass")
    /// }
    /// .controlHelp(
    ///     String(localized: "graph.resetView.a11y", defaultValue: "Reset view"),
    ///     detail: String(localized: "graph.resetView.help",
    ///                    defaultValue: "Restore the graph’s pan and zoom to their original position"),
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

// MARK: - TransientToast

/// The transient toast's timing and what VoiceOver is told when one is shown (#1594).
///
/// The toast is the only sign of three results: an Archives Visit duplicated, an inquiry topic
/// re-seeded from the project, and documents added to a collection. Until #1594 nothing posted
/// an announcement for it, so a VoiceOver user heard nothing, and the capsule was gone before it
/// could be found by touch; a reader who chose Duplicate and heard nothing could choose it again
/// and make a second copy.
///
/// **The announcement is posted late and at high priority, and neither was heard on a device.**
/// A toast is raised as a menu closes or a sheet is dismissed, which is when VoiceOver moves its
/// focus and speaks the element it lands on. An announcement posted at that moment at the default
/// priority can be dropped or cut off. So it waits ``announcementDelay`` and is posted at
/// `.high`, which interrupts what is being spoken and is not itself interrupted. Check both
/// values with VoiceOver on an iPhone and on the Mac before changing either.
///
/// Version history:
///   1.0 — 2026-10-09: #1594 — initial implementation
enum TransientToast {

    /// How long a toast stays up.
    static let duration: Duration = .seconds(2.6)

    /// How long after a toast appears its announcement is posted: long enough for a closing menu
    /// or sheet to have finished moving VoiceOver's focus.
    static let announcementDelay: Duration = .seconds(0.5)

    /// What VoiceOver is sent for a toast: its words, at high priority.
    ///
    /// - Parameter message: The toast's text.
    /// - Returns: The announcement.
    static func announcement(_ message: String) -> AttributedString {
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        return announcement
    }
}

// MARK: - TransientToastModifier

/// A brief confirmation toast pinned to the top of a view, auto-dismissing after ~2.6s
/// (Composer redesign 5). Set `message` to a non-nil string to show it; it clears itself.
/// A capsule with the material background so it reads over any content, announced to VoiceOver
/// (``TransientToast``; it said so from 2026-07-12 and posted nothing until #1594).
private struct TransientToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.quaternary))
                        .shadow(radius: 8, y: 2)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                        .task(id: message) {
                            // A second toast set while this one is up cancels this task. The
                            // sleeps used to be `try?`, so the cancelled task went on to clear
                            // the message, and with it the toast that had just replaced its own.
                            do {
                                try await Task.sleep(for: TransientToast.announcementDelay)
                                AccessibilityNotification.Announcement(TransientToast.announcement(message)).post()
                                try await Task.sleep(for: TransientToast.duration - TransientToast.announcementDelay)
                            } catch {
                                return
                            }
                            withAnimation { self.message = nil }
                        }
                }
            }
            .animation(.spring(duration: 0.3), value: message)
    }
}

public extension View {

    /// Shows a brief, auto-dismissing confirmation toast at the top of the view (Composer redesign
    /// 5). Bind a `@State String?`; set it to show, and it clears itself after a moment.
    func transientToast(_ message: Binding<String?>) -> some View {
        modifier(TransientToastModifier(message: message))
    }
}
