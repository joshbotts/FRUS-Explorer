// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import WebKit

// MARK: - FRUSDocumentWebView

/// SwiftUI document renderer backed by `WKWebView`.
///
/// Replaces `FRUSDocumentRenderer` (SwiftUI VStack path) as the primary document
/// display surface beginning in Session 142. Session 141 adds the view and confirms
/// correct HTML rendering and CSS theming on both platforms; interactive callbacks
/// are wired in Session 142.
///
/// ## Usage
/// ```swift
/// FRUSDocumentWebView(model: renderModel)
///     .frame(maxWidth: .infinity, maxHeight: .infinity)
/// ```
///
/// With callbacks (Session 142+):
/// ```swift
/// FRUSDocumentWebView(
///     model: model,
///     onPersonTap:   { ref in vm.handlePersonTap(ref: ref) },
///     onGlossTap:    { ref in vm.handleGlossTap(ref: ref) },
///     onCrossRefTap: { target, vol in handleCrossRefTap(target: target, volumeId: vol) }
/// )
/// ```
///
/// ## Reload strategy
/// `FRUSDocumentWebView` uses `WebViewSignature` to detect when the underlying HTML
/// must be rebuilt and reloaded. The signature covers:
/// - `model.documentId` — the rendered document
/// - `colorScheme` — system appearance (light / dark)
/// - `textSize` — user text-size preference
///
/// A change to any of these three values triggers a full `loadHTMLString` call. This
/// is acceptable because the web view is always displaying a single document; the
/// reload is imperceptible at human timescales (~10–50 ms for typical FRUS documents).
///
/// ## Interactive callbacks
/// Callbacks receive the raw ref key from the `frusexplorer://` URL (e.g. `"p_HK1"`
/// for `frusexplorer://person/p_HK1`). The caller is responsible for resolving the
/// key to a `PersonEntry` or `GlossEntry` via the render model's lookup tables.
/// Session 142 adds `FRUSURLSchemeHandler` which drives these callbacks from
/// `WKURLSchemeHandler`; the `StubFRUSURLSchemeHandler` registered in Session 141
/// absorbs the navigation silently.
///
/// ## Session history
///   1.0 — Session 141: initial implementation; HTML display + theming; no callbacks
///   1.1 — Session 142: `FRUSURLSchemeHandler` replaces stub; callbacks dispatched
///   1.2 — Session 144: `renderHighlights(_:)` called after page load
///   1.3 — Session 145: `selectionChanged` message handler registered
public struct FRUSDocumentWebView: View {

    /// The document to render.
    public let model: FRUSDocumentRenderModel

    // MARK: Callbacks (wired in Session 142)

    /// Raw person ref key (e.g. `"p_HK1"` from `frusexplorer://person/p_HK1`).
    /// Resolve to a `PersonEntry` via the volume's persons lookup before displaying.
    public var onPersonTap: ((String) -> Void)? = nil

    /// Raw gloss ref key (e.g. `"t_NSC1"` from `frusexplorer://gloss/t_NSC1`).
    /// Resolve to a `GlossEntry` via the volume's terms lookup before displaying.
    public var onGlossTap: ((String) -> Void)? = nil

    /// Cross-reference target doc ID and optional source volume ID.
    public var onCrossRefTap: ((String, String?) -> Void)? = nil

    // MARK: Environment

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("frus.display.textSize") private var textSize: TextSizePreference = .medium

    // MARK: Body

    public var body: some View {
        #if os(macOS)
        _FRUSDocumentWebViewMac(
            model:          model,
            colorScheme:    colorScheme,
            textSize:       textSize,
            onPersonTap:    onPersonTap,
            onGlossTap:     onGlossTap,
            onCrossRefTap:  onCrossRefTap
        )
        #else
        _FRUSDocumentWebViewiOS(
            model:          model,
            colorScheme:    colorScheme,
            textSize:       textSize,
            onPersonTap:    onPersonTap,
            onGlossTap:     onGlossTap,
            onCrossRefTap:  onCrossRefTap
        )
        #endif
    }
}

// MARK: - Signature

/// Equality key used by the coordinator to decide whether to reload the web view.
///
/// Captures the three inputs that, when changed, require a new `loadHTMLString` call.
struct WebViewSignature: Equatable {
    let documentId:  String
    let colorScheme: ColorScheme
    let textSize:    TextSizePreference

    static let empty = WebViewSignature(
        documentId:  "",
        colorScheme: .light,
        textSize:    .medium
    )
}

// MARK: - Shared Coordinator

/// Shared navigation delegate for both the macOS and iOS web view representables.
///
/// Responsibilities:
/// - Tracks the last-rendered `WebViewSignature` to suppress no-op reloads.
/// - Stores the interactive callbacks so the scheme handler (Session 142) can
///   call them from the navigation event.
/// - Blocks `frusexplorer://` navigations with `.cancel` in Session 141 as a
///   secondary guard behind `StubFRUSURLSchemeHandler`.
final class _FRUSWebViewCoordinator: NSObject, WKNavigationDelegate {

    /// Signature of the most-recently loaded content. Initialized to `.empty` so
    /// the first real document always triggers a load.
    var lastSignature: WebViewSignature = .empty

    // Callbacks registered on each `update` call.
    var onPersonTap:   ((String) -> Void)?
    var onGlossTap:    ((String) -> Void)?
    var onCrossRefTap: ((String, String?) -> Void)?

    // MARK: WKNavigationDelegate

    /// Blocks `frusexplorer://` navigations silently in Session 141.
    /// Replaced by actual dispatch in Session 142 when `FRUSURLSchemeHandler`
    /// calls the Swift callbacks directly; this delegate method then only
    /// handles non-frusexplorer navigations (which are always `.cancel` for
    /// a locally-loaded HTML document with no external resources).
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard navigationAction.request.url?.scheme != "frusexplorer" else { return .cancel }
        // Allow the initial `about:blank` → document navigation.
        return .allow
    }

    #if DEBUG
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        print("[FRUSDocumentWebView] provisional navigation failed: \(error.localizedDescription)")
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        print("[FRUSDocumentWebView] navigation failed: \(error.localizedDescription)")
    }
    #endif
}

// MARK: - macOS Representable

#if os(macOS)

/// macOS-specific `NSViewRepresentable` shell for `WKWebView`.
struct _FRUSDocumentWebViewMac: NSViewRepresentable {

    let model:          FRUSDocumentRenderModel
    let colorScheme:    ColorScheme
    let textSize:       TextSizePreference
    var onPersonTap:    ((String) -> Void)?
    var onGlossTap:     ((String) -> Void)?
    var onCrossRefTap:  ((String, String?) -> Void)?

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration.frusExplorerConfiguration()
        )
        webView.navigationDelegate = context.coordinator
        webView.autoresizingMask   = [.width, .height]
        // Transparent until HTML loads — avoids a white-background flash on load.
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let sig = WebViewSignature(
            documentId:  model.documentId,
            colorScheme: colorScheme,
            textSize:    textSize
        )
        guard context.coordinator.lastSignature != sig else { return }
        context.coordinator.lastSignature   = sig
        context.coordinator.onPersonTap     = onPersonTap
        context.coordinator.onGlossTap      = onGlossTap
        context.coordinator.onCrossRefTap   = onCrossRefTap

        let html = HTMLTemplate.build(model: model, colorScheme: colorScheme, textSize: textSize)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> _FRUSWebViewCoordinator { _FRUSWebViewCoordinator() }
}

#else

// MARK: - iOS Representable

/// iOS-specific `UIViewRepresentable` shell for `WKWebView`.
struct _FRUSDocumentWebViewiOS: UIViewRepresentable {

    let model:          FRUSDocumentRenderModel
    let colorScheme:    ColorScheme
    let textSize:       TextSizePreference
    var onPersonTap:    ((String) -> Void)?
    var onGlossTap:     ((String) -> Void)?
    var onCrossRefTap:  ((String, String?) -> Void)?

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration.frusExplorerConfiguration()
        )
        webView.navigationDelegate = context.coordinator
        // Transparent until HTML loads so the app background shows through.
        webView.isOpaque                     = false
        webView.backgroundColor              = .clear
        webView.scrollView.backgroundColor   = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let sig = WebViewSignature(
            documentId:  model.documentId,
            colorScheme: colorScheme,
            textSize:    textSize
        )
        guard context.coordinator.lastSignature != sig else { return }
        context.coordinator.lastSignature   = sig
        context.coordinator.onPersonTap     = onPersonTap
        context.coordinator.onGlossTap      = onGlossTap
        context.coordinator.onCrossRefTap   = onCrossRefTap

        let html = HTMLTemplate.build(model: model, colorScheme: colorScheme, textSize: textSize)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> _FRUSWebViewCoordinator { _FRUSWebViewCoordinator() }
}

#endif
