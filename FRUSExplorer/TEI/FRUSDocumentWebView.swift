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

    // MARK: Callbacks

    /// Called with the resolved `PersonEntry` (or `nil`) when a persName link is tapped.
    /// `FRUSURLSchemeHandler` builds a ref→entry lookup from the render model so the
    /// resolved entry is available without any extra work at the call site.
    public var onPersonTap: ((PersonEntry?) -> Void)? = nil

    /// Called with the resolved `GlossEntry` (or `nil`) when a gloss link is tapped.
    public var onGlossTap: ((GlossEntry?) -> Void)? = nil

    /// Called with the target document ID and optional source volume ID.
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
/// - Holds a reference to the `FRUSURLSchemeHandler` so `updateNSView`/`updateUIView`
///   can update its callbacks and model lookups without recreating the web view.
final class _FRUSWebViewCoordinator: NSObject, WKNavigationDelegate {

    /// Signature of the most-recently loaded content. Initialized to `.empty` so
    /// the first real document always triggers a load.
    var lastSignature: WebViewSignature = .empty

    /// The scheme handler registered with this view's `WKWebViewConfiguration`.
    /// Set by `makeNSView`/`makeUIView`; updated (not replaced) on each `update` call.
    var schemeHandler: FRUSURLSchemeHandler?

    // MARK: WKNavigationDelegate

    /// Allows the initial HTML load and blocks all external navigations.
    /// `frusexplorer://` navigations are intercepted by `FRUSURLSchemeHandler`
    /// before the navigation policy delegate is consulted, so they never reach
    /// this method in practice. The check is kept as a belt-and-suspenders guard.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard navigationAction.request.url?.scheme != "frusexplorer" else { return .cancel }
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
    var onPersonTap:    ((PersonEntry?) -> Void)?
    var onGlossTap:     ((GlossEntry?) -> Void)?
    var onCrossRefTap:  ((String, String?) -> Void)?

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        // Create a per-view scheme handler so its lookup tables are scoped to this
        // document instance. Store on the coordinator so updateNSView can update it.
        let handler = FRUSURLSchemeHandler()
        context.coordinator.schemeHandler = handler

        let webView = WKWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration.frusExplorerConfiguration(schemeHandler: handler)
        )
        webView.navigationDelegate = context.coordinator
        webView.autoresizingMask   = [.width, .height]
        // Transparent until HTML loads — avoids a white-background flash.
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
        context.coordinator.lastSignature = sig

        // Update scheme handler lookups and callbacks before reloading so
        // any link tapped on the new page resolves to the correct entries.
        context.coordinator.schemeHandler?.register(model: model)
        context.coordinator.schemeHandler?.onPersonTap   = onPersonTap
        context.coordinator.schemeHandler?.onGlossTap    = onGlossTap
        context.coordinator.schemeHandler?.onCrossRefTap = onCrossRefTap

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
    var onPersonTap:    ((PersonEntry?) -> Void)?
    var onGlossTap:     ((GlossEntry?) -> Void)?
    var onCrossRefTap:  ((String, String?) -> Void)?

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> WKWebView {
        let handler = FRUSURLSchemeHandler()
        context.coordinator.schemeHandler = handler

        let webView = WKWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration.frusExplorerConfiguration(schemeHandler: handler)
        )
        webView.navigationDelegate = context.coordinator
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
        context.coordinator.lastSignature = sig

        context.coordinator.schemeHandler?.register(model: model)
        context.coordinator.schemeHandler?.onPersonTap   = onPersonTap
        context.coordinator.schemeHandler?.onGlossTap    = onGlossTap
        context.coordinator.schemeHandler?.onCrossRefTap = onCrossRefTap

        let html = HTMLTemplate.build(model: model, colorScheme: colorScheme, textSize: textSize)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> _FRUSWebViewCoordinator { _FRUSWebViewCoordinator() }
}

#endif
