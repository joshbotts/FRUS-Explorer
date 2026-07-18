// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SelectionBarState

/// Visibility and anchor state for the ``FloatingSelectionBar`` (Research-rail Phase B).
///
/// Owns the bar's bounding-rect anchor and a *debounced* hide. The WKWebView fires a spurious
/// `selectioncleared` the instant a bar/menu tap blurs it (the documented false-clear race), so a
/// clear schedules a short-delayed hide that a subsequent ``present(rect:atFootnote:)`` cancels —
/// the bar survives the blur, yet still dismisses on a *real* clear, a scroll, or navigation
/// (``hideNow()``, no debounce).
///
/// `@MainActor`-isolated because it is mutated only from SwiftUI selection callbacks and drives a
/// view; the debounced hide runs as a main-actor `Task`.
@MainActor
@Observable
final class SelectionBarState {

    /// The live selection's bounding rect in web-view point space, or `nil` when the bar is hidden.
    private(set) var anchor: CGRect?

    /// `true` when the selection is a footnote / out-of-document selection (sentinel offsets): the
    /// highlight dots and Excerpt are unavailable there, leaving Look Up + Note.
    private(set) var atFootnote = false

    /// The pending debounced-hide task, cancelled by `present`/`hideNow` (not observed).
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    /// Whether the bar is currently shown.
    var isVisible: Bool { anchor != nil }

    /// Shows or moves the bar to `rect`, cancelling any pending debounced hide.
    /// - Parameters:
    ///   - rect: The selection's bounding rect in web-view point space.
    ///   - atFootnote: `true` for a footnote/out-of-document selection (dots + Excerpt disabled).
    func present(rect: CGRect, atFootnote: Bool) {
        hideTask?.cancel()
        hideTask = nil
        self.anchor = rect
        self.atFootnote = atFootnote
    }

    /// Schedules a debounced hide that tolerates the false-clear blur. A `present` before it fires
    /// cancels it; a real clear lets it elapse and the bar dismisses.
    /// - Parameter milliseconds: Debounce window (default 200 ms).
    func scheduleHide(after milliseconds: Int = 200) {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard !Task.isCancelled else { return }
            self?.anchor = nil
            self?.hideTask = nil
        }
    }

    /// Hides the bar immediately (scroll, zoom, or navigation) with no debounce.
    func hideNow() {
        hideTask?.cancel()
        hideTask = nil
        anchor = nil
    }
}

// MARK: - FloatingSelectionBar

/// The floating selection bar (Research-rail Phase B): four highlight-colour dots · Excerpt ·
/// Look Up · Note, shown anchored at the text selection on every platform and mode.
///
/// This view is presentation-only — the anchoring geometry and action wiring live in each document
/// view (``DocumentView`` on iOS, `MacDocumentView` on macOS). The four dots create a highlight in
/// the tapped colour; Excerpt freezes the passage into a collection; Look Up hands the text to the
/// NARA Source Explorer; Note opens the note composer. For a footnote/out-of-document selection
/// there are no flat-text offsets, so the dots and Excerpt are disabled, leaving Look Up + Note.
///
/// `compact` (iPhone) drops the verb labels, leaving icons only. Fonts are Dynamic-Type-relative
/// and each control carries an enlarged hit target so the compact pill stays reachably tappable.
struct FloatingSelectionBar: View {

    /// `true` for a footnote/out-of-document selection: the dots and Excerpt are disabled.
    let atFootnote: Bool

    /// iPhone layout: icon-only verbs (no text labels).
    let compact: Bool

    /// Creates a highlight of the tapped colour from the current selection.
    let onHighlight: (DocumentHighlight.Color) -> Void

    /// Freezes the selection into a collection excerpt.
    let onExcerpt: () -> Void

    /// Hands the selected text to the NARA Source Explorer.
    let onLookUp: () -> Void

    /// Opens the note composer (a document-level note; the highlight-linked path lives on the
    /// toolbar's labeled "Add Note to Highlight").
    let onNote: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DocumentHighlight.Color.allCases, id: \.self) { color in
                Button {
                    onHighlight(color)
                } label: {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 0.5))
                        // Enlarge the hit target well beyond the 16 pt dot so near-misses between
                        // adjacent dots don't fall through the transparent overlay to the web view.
                        .frame(width: 30, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(atFootnote)
                .opacity(atFootnote ? 0.3 : 1)
                .accessibilityLabel(Text(String(
                    localized: "selectionBar.highlightColor.a11y",
                    defaultValue: "Highlight \(color.displayName)")))
            }

            separator

            verbButton(
                title: String(localized: "selectionBar.excerpt", defaultValue: "Excerpt"),
                systemImage: "text.quote",
                enabled: !atFootnote,
                action: onExcerpt
            )
            verbButton(
                title: String(localized: "selectionBar.lookUp", defaultValue: "Look Up"),
                systemImage: "magnifyingglass.circle",
                enabled: true,
                action: onLookUp
            )
            verbButton(
                title: String(localized: "selectionBar.note", defaultValue: "Note"),
                systemImage: "note.text.badge.plus",
                enabled: true,
                action: onNote
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(.sRGB, red: 28 / 255, green: 28 / 255, blue: 30 / 255, opacity: 0.95))
        )
        // Absorb taps that land on the pill but not on a control (padding, the separator, a disabled
        // dot) so they can't fall through to the web view and clear the selection out from under the
        // bar the user is aiming at.
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
        .fixedSize()
        .transition(.fadeUp)
    }

    /// A vertical hairline separating the colour dots from the verb buttons.
    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 4)
    }

    /// A single verb button — icon + label (or icon only when `compact`), dimmed when disabled.
    /// - Parameters:
    ///   - title: The localised verb label, also used as the accessibility label.
    ///   - systemImage: SF Symbol name.
    ///   - enabled: `false` dims and disables the button (e.g. Excerpt on a footnote selection).
    ///   - action: Invoked on tap.
    @ViewBuilder
    private func verbButton(
        title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if compact {
                    Image(systemName: systemImage)
                        .font(.body)
                        .frame(minWidth: 34)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: systemImage)
                        Text(title)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            // A 40 pt-tall hit target (Dynamic-Type-relative fonts still keep the row reachable).
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(Text(title))
    }

    // MARK: - Geometry

    /// Computes the bar's centre point so it sits centred over `selection` and fully inside
    /// `container`, flipping to the other side if the preferred side would clip.
    ///
    /// Pure and deterministic (no view state) so the clamping can be unit-tested. Coordinates are
    /// the web view's own point space (top-left origin), matching the `rect` the selection bridge
    /// reports at `scale == 1`.
    ///
    /// - Parameters:
    ///   - selection: The selection's bounding rect.
    ///   - barSize: The measured size of the bar.
    ///   - container: The size of the coordinate space the bar is positioned within.
    ///   - below: `true` anchors the bar *below* the selection (iOS — leaves room above for the
    ///     system edit menu); `false` anchors it *above* (macOS).
    ///   - gap: Vertical gap between the selection edge and the bar (default 8 pt).
    /// - Returns: The centre point to pass to `.position(x:y:)`.
    static func anchorCenter(
        selection: CGRect,
        barSize: CGSize,
        in container: CGSize,
        below: Bool,
        gap: CGFloat = 8
    ) -> CGPoint {
        let halfW = barSize.width / 2
        let halfH = barSize.height / 2
        let margin: CGFloat = 8

        // Horizontal: centre over the selection, clamped so the whole bar stays on-screen.
        let minX = halfW + margin
        let maxX = max(minX, container.width - halfW - margin)
        let x = min(max(selection.midX, minX), maxX)

        // Vertical: preferred side, flipping to the other if it would clip past the container edge.
        let centreAbove = selection.minY - gap - halfH
        let centreBelow = selection.maxY + gap + halfH
        var cy = below ? centreBelow : centreAbove
        if below, cy + halfH + margin > container.height {
            cy = centreAbove
        } else if !below, cy - halfH - margin < 0 {
            cy = centreBelow
        }
        let minY = halfH + margin
        let maxY = max(minY, container.height - halfH - margin)
        cy = min(max(cy, minY), maxY)

        return CGPoint(x: x, y: cy)
    }
}

// MARK: - Positioner

/// Measures the bar's intrinsic size and positions it centre-clamped over a selection rect within
/// a container. Shared by both document views; `below` selects the anchoring side.
struct FloatingSelectionBarPositioner: ViewModifier {

    /// The selection's bounding rect in the container's coordinate space.
    let selection: CGRect

    /// The size of the coordinate space the bar is positioned within.
    let container: CGSize

    /// `true` anchors below the selection (iOS); `false` above (macOS).
    let below: Bool

    /// Vertical gap between the selection edge and the bar. iOS passes a larger value to clear the
    /// WKWebView selection drag-handle that hangs below the selection.
    var gap: CGFloat = 8

    /// The bar's measured intrinsic size (`.zero` until the first layout pass).
    @State private var barSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { barSize = $0 }
            .position(
                barSize == .zero
                    // Pre-measure fallback (one frame): sit at the selection edge, no clamping yet.
                    ? CGPoint(x: selection.midX, y: below ? selection.maxY : selection.minY)
                    : FloatingSelectionBar.anchorCenter(
                        selection: selection, barSize: barSize, in: container, below: below, gap: gap)
            )
    }
}

// MARK: - fadeUp transition

private extension AnyTransition {
    /// The bar's entrance: fade in while rising a few points (the design's "fadeUp").
    static var fadeUp: AnyTransition {
        .modifier(
            active: _FadeUpModifier(offset: 6, opacity: 0),
            identity: _FadeUpModifier(offset: 0, opacity: 1)
        )
    }
}

/// Backing modifier for ``AnyTransition/fadeUp`` — offsets vertically and fades.
private struct _FadeUpModifier: ViewModifier {
    /// Vertical offset applied while the bar is entering/leaving.
    let offset: CGFloat
    /// Opacity applied while the bar is entering/leaving.
    let opacity: Double
    func body(content: Content) -> some View {
        content.offset(y: offset).opacity(opacity)
    }
}
