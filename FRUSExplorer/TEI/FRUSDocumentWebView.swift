// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import WebKit

// MARK: - FRUSSelectionEvent

/// The decoded outcome of a `selectionChanged` message from the selection bridge JS — a pure
/// value so decoding is unit-testable without a `WKScriptMessage` (which has no public
/// initializer). See `decodeFRUSSelectionEvent(from:)`.
enum FRUSSelectionEvent: Equatable {
    /// No live selection (collapsed/cleared).
    case cleared
    /// A valid in-document selection with flat-text Unicode-scalar offsets and its raw text.
    case ranged(start: Int, end: Int, text: String)
    /// An out-of-document (footnote) selection: no offsets, but the raw selected `text` and the
    /// enclosing `blockText` (the footnote body), used to characterise the note's citations (#269).
    case footnote(text: String, blockText: String)
}

/// Decodes a `selectionChanged` message body into a `FRUSSelectionEvent`.
///
/// Returns `nil` for a malformed body (missing/non-integer `start`/`end`) or a degenerate
/// in-document range (`end <= start`). A footnote body with a missing/empty `blockText` falls
/// back to the raw selected text, so the footnote branch always has some block context.
func decodeFRUSSelectionEvent(from body: [String: Any]) -> FRUSSelectionEvent? {
    guard let start = body["start"] as? Int, let end = body["end"] as? Int else { return nil }
    let text = (body["text"] as? String) ?? ""
    if start < 0 {
        guard !text.isEmpty else { return .cleared }
        let block = (body["blockText"] as? String) ?? ""
        return .footnote(text: text, blockText: block.isEmpty ? text : block)
    }
    guard end > start else { return nil }
    return .ranged(start: start, end: end, text: text)
}

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

    /// Called with the broken-ref detail (or `nil`) when an unresolvable `<ref>` is tapped.
    public var onBrokenRefTap: ((BrokenRefInfo?) -> Void)? = nil

    // MARK: Selection callbacks (Session 145)

    /// Called with `(start, end, text, blockText)` when the user selects text in the WKWebView.
    /// `start` and `end` are Unicode-scalar offsets into `buildFlatText(from: model)`.
    /// `text` is the raw selected string from `window.getSelection().toString()`,
    /// suitable for pre-populating the NARA Catalog lookup field.
    /// `blockText` is the enclosing footnote body for a footnote selection (`start == -1`),
    /// or an empty string for an in-document selection (whose block context Swift derives
    /// from the offsets); it lets the footnote NARA path characterise the note's citations (#269).
    var onSelectionChanged: ((Int, Int, String, String) -> Void)? = nil

    /// Called when the selection is collapsed or cleared.
    var onSelectionCleared: (() -> Void)? = nil

    /// Called when the user taps within a non-stale highlight range.
    /// `(startOffset, endOffset)` uniquely identifies the highlight so the
    /// caller can look it up in SwiftData and offer to delete it.
    var onHighlightTapped: ((Int, Int) -> Void)? = nil

    /// Called when the user picks "Highlight" from the iOS text-selection edit
    /// menu. Unused on macOS.
    var onEditMenuHighlight: (() -> Void)? = nil

    /// Called when the user picks "Look Up in NARA Catalog" from the iOS
    /// text-selection edit menu. Unused on macOS.
    var onEditMenuNARALookup: (() -> Void)? = nil

    /// Returns `true` when the current selection lies inside the document body
    /// (valid flat-text offsets), so the edit menu's Highlight action is only
    /// offered where a highlight can actually be created. Unused on macOS.
    var canHighlightSelection: (() -> Bool)? = nil

    /// Stored highlights to render via the CSS Custom Highlight API after each
    /// page load. Updated highlights are re-rendered without a full HTML reload.
    var highlights: [DocumentHighlight] = []

    // MARK: Environment

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("frus.display.textSize") private var textSize: TextSizePreference = .medium

    // MARK: Body

    public var body: some View {
        #if os(macOS)
        _FRUSDocumentWebViewMac(
            model:              model,
            colorScheme:        colorScheme,
            textSize:           textSize,
            highlights:         highlights,
            onPersonTap:        onPersonTap,
            onGlossTap:         onGlossTap,
            onCrossRefTap:      onCrossRefTap,
            onBrokenRefTap:     onBrokenRefTap,
            onSelectionChanged: onSelectionChanged,
            onSelectionCleared: onSelectionCleared,
            onHighlightTapped:  onHighlightTapped
        )
        #else
        _FRUSDocumentWebViewiOS(
            model:              model,
            colorScheme:        colorScheme,
            textSize:           textSize,
            highlights:         highlights,
            onPersonTap:        onPersonTap,
            onGlossTap:         onGlossTap,
            onCrossRefTap:      onCrossRefTap,
            onBrokenRefTap:     onBrokenRefTap,
            onSelectionChanged: onSelectionChanged,
            onSelectionCleared: onSelectionCleared,
            onHighlightTapped:  onHighlightTapped,
            onEditMenuHighlight:   onEditMenuHighlight,
            onEditMenuNARALookup:  onEditMenuNARALookup,
            canHighlightSelection: canHighlightSelection
        )
        #endif
    }
}

// MARK: - View modifier extensions

extension FRUSDocumentWebView {

    /// Supplies the stored highlights to render via the CSS Custom Highlight API.
    func highlights(_ newHighlights: [DocumentHighlight]) -> FRUSDocumentWebView {
        var copy = self; copy.highlights = newHighlights; return copy
    }

    /// Registers a callback for when the user makes a text selection in the web view.
    /// `start` and `end` are Unicode-scalar offsets; `text` is the raw selected string.
    func onSelectionChanged(_ handler: @escaping (Int, Int, String, String) -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onSelectionChanged = handler; return copy
    }

    /// Registers a callback for when the selection is collapsed or cleared.
    func onSelectionCleared(_ handler: @escaping () -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onSelectionCleared = handler; return copy
    }

    /// Registers a callback fired when the user taps inside a rendered highlight.
    /// `(startOffset, endOffset)` matches `DocumentHighlight.startOffset`/`endOffset`
    /// so the caller can fetch and delete the record from SwiftData.
    func onHighlightTapped(_ handler: @escaping (Int, Int) -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onHighlightTapped = handler; return copy
    }

    /// Registers the action for "Highlight" in the iOS text-selection edit menu.
    /// No effect on macOS.
    func onEditMenuHighlight(_ handler: @escaping () -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onEditMenuHighlight = handler; return copy
    }

    /// Registers the action for "Look Up in NARA Catalog" in the iOS
    /// text-selection edit menu. No effect on macOS.
    func onEditMenuNARALookup(_ handler: @escaping () -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onEditMenuNARALookup = handler; return copy
    }

    /// Supplies the predicate gating the edit menu's Highlight action to
    /// selections with valid in-document offsets. No effect on macOS.
    func canHighlightSelection(_ predicate: @escaping () -> Bool) -> FRUSDocumentWebView {
        var copy = self; copy.canHighlightSelection = predicate; return copy
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
/// - Holds a reference to the `FRUSURLSchemeHandler`.
/// - Stores pending highlights and calls `renderHighlights(on:)` after each
///   page load and whenever highlights change without a full HTML reload.
final class _FRUSWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, @unchecked Sendable {

    /// Signature of the most-recently loaded content. Initialized to `.empty` so
    /// the first real document always triggers a load.
    var lastSignature: WebViewSignature = .empty

    /// The scheme handler registered with this view's `WKWebViewConfiguration`.
    /// Set by `makeNSView`/`makeUIView`; updated (not replaced) on each `update` call.
    var schemeHandler: FRUSURLSchemeHandler?

    // MARK: Highlight state

    /// Most-recently supplied highlights; rendered after every page load and on
    /// direct update when only highlights changed (no full HTML reload needed).
    var pendingHighlights: [DocumentHighlight] = []

    /// The `renderingVersion` for the currently loaded document; used to compute
    /// `HighlightDTO.isStale`.
    var currentRenderingVersion: String = ""

    /// IDs of the last highlights passed to `updateNSView`/`updateUIView`, used to
    /// detect changes that require a `renderHighlights` call without a full reload.
    var lastHighlightIds: [UUID] = []

    // MARK: Selection state (Session 145)

    /// Fired when JS reports a valid text selection `{start, end, text}`.
    var onSelectionChanged: ((Int, Int, String, String) -> Void)?
    /// Fired when JS reports the selection was cleared (`{start: -1, end: -1}`).
    var onSelectionCleared: (() -> Void)?
    /// Fired when the user taps inside a rendered highlight range.
    var onHighlightTapped: ((Int, Int) -> Void)?

    // MARK: WKScriptMessageHandler

    /// Receives `selectionChanged` messages from `frus-selection.js` / `kSelectionJS`.
    ///
    /// The body carries `"start"`, `"end"`, and (for non-empty selections) `"text"`; a
    /// footnote selection additionally carries `"blockText"` (the enclosing note body).
    /// `start == -1` with empty text signals selection cleared; `start >= 0 && end > start`
    /// is a valid in-document range in flat-text Unicode-scalar offsets. Decoding is factored
    /// into the pure `decodeFRUSSelectionEvent(from:)` so it is unit-testable without a
    /// `WKScriptMessage` (which has no public initializer).
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }

        switch message.name {
        case "selectionChanged":
            switch decodeFRUSSelectionEvent(from: body) {
            case .cleared:
                onSelectionCleared?()
            case .footnote(let text, let blockText):
                // Out-of-document (footnote) selection: sentinel offsets, but raw text plus
                // the enclosing block so the NARA path can characterise the note's citations.
                onSelectionChanged?(-1, -1, text, blockText)
            case .ranged(let start, let end, let text):
                // In-document selection: block context is derived Swift-side from the offsets,
                // so no blockText is threaded here.
                onSelectionChanged?(start, end, text, "")
            case nil:
                break
            }

        case "highlightTapped":
            guard let start = body["startOffset"] as? Int,
                  let end   = body["endOffset"]   as? Int else { return }
            onHighlightTapped?(start, end)

        default:
            break
        }
    }

    // MARK: CSS Custom Highlight API

    /// Serialises `pendingHighlights` to JSON and calls
    /// `window.FRUSHighlights.render(...)` on the given web view.
    ///
    /// Safe to call with an empty array — `FRUSHighlights.render([])` just calls
    /// `CSS.highlights.clear()`, which removes any stale paints from a prior page.
    func renderHighlights(on webView: WKWebView) async {
        let dtos = pendingHighlights.map { h in
            DocumentHighlight.HighlightDTO(h, currentVersion: currentRenderingVersion)
        }
        guard let json = try? JSONEncoder().encode(dtos),
              let jsonStr = String(data: json, encoding: .utf8) else { return }
        let script = "if(window.FRUSHighlights){window.FRUSHighlights.render(\(jsonStr))}"
        _ = try? await webView.evaluateJavaScript(script)

        #if DEBUG
        let staleCount = dtos.filter { $0.isStale }.count
        if staleCount > 0 {
            print("[FRUSDocumentWebView] renderHighlights: \(dtos.count) highlights, "
                  + "\(staleCount) stale")
        }
        #endif
    }

    // MARK: WKNavigationDelegate

    /// After each successful page load, paint any pending highlights.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            await renderHighlights(on: webView)
        }
    }

    /// Allows the initial HTML load and dispatches `frusexplorer://` link taps.
    ///
    /// When the tapped link uses the `frusexplorer` scheme, the person/gloss/cross-ref
    /// callback is fired here (via `FRUSURLSchemeHandler.dispatch(url:)`) and the
    /// navigation is cancelled. Cancelling is required so the scheme handler's empty
    /// response can't replace the document — but it also prevents the scheme handler's
    /// `webView(_:start:)` from running, so this is the only reliable place to dispatch
    /// interactive links (the scheme task does not start on macOS once cancelled).
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, url.scheme == "frusexplorer" else {
            return .allow
        }
        let handler = schemeHandler
        await MainActor.run { handler?.dispatch(url: url) }
        return .cancel
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
    let highlights:     [DocumentHighlight]
    var onPersonTap:        ((PersonEntry?) -> Void)?
    var onGlossTap:         ((GlossEntry?) -> Void)?
    var onCrossRefTap:      ((String, String?) -> Void)?
    var onBrokenRefTap:     ((BrokenRefInfo?) -> Void)?
    var onSelectionChanged: ((Int, Int, String, String) -> Void)?
    var onSelectionCleared: (() -> Void)?
    var onHighlightTapped:  ((Int, Int) -> Void)?

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        let handler = FRUSURLSchemeHandler()
        context.coordinator.schemeHandler = handler

        let webView = WKWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration.frusExplorerConfiguration(
                schemeHandler:  handler,
                messageHandler: context.coordinator
            )
        )
        webView.navigationDelegate = context.coordinator
        webView.autoresizingMask   = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
        let newHighlightIds  = highlights.map(\.id)
        let highlightsChanged = newHighlightIds != context.coordinator.lastHighlightIds

        // Always sync highlight state before any reload/render decision.
        context.coordinator.pendingHighlights        = highlights
        context.coordinator.currentRenderingVersion  = renderingVersion
        context.coordinator.lastHighlightIds         = newHighlightIds

        let sig = WebViewSignature(
            documentId:  model.documentId,
            colorScheme: colorScheme,
            textSize:    textSize
        )
        // Always sync selection callbacks (lightweight — just closure assignments)
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.onSelectionCleared = onSelectionCleared
        context.coordinator.onHighlightTapped  = onHighlightTapped

        if context.coordinator.lastSignature != sig {
            context.coordinator.lastSignature = sig
            context.coordinator.schemeHandler?.register(model: model)
            context.coordinator.schemeHandler?.onPersonTap   = onPersonTap
            context.coordinator.schemeHandler?.onGlossTap    = onGlossTap
            context.coordinator.schemeHandler?.onCrossRefTap = onCrossRefTap
            context.coordinator.schemeHandler?.onBrokenRefTap = onBrokenRefTap
            let html = HTMLTemplate.build(model: model, colorScheme: colorScheme, textSize: textSize)
            webView.loadHTMLString(html, baseURL: nil)
        } else if highlightsChanged {
            Task { @MainActor in
                await context.coordinator.renderHighlights(on: webView)
            }
        }
    }

    func makeCoordinator() -> _FRUSWebViewCoordinator { _FRUSWebViewCoordinator() }
}

#else

// MARK: - iOS Edit-Menu WKWebView

/// `WKWebView` subclass that adds research actions to the text-selection edit menu.
///
/// Since iOS 16, the web view's edit menu is assembled through the responder
/// chain's `buildMenu(with:)` using the context menu system, so a subclass can
/// append its own inline actions. This puts "Highlight" and "Look Up in NARA
/// Catalog" directly on the selection — the platform-native location — instead of
/// requiring a round-trip through the navigation-bar overflow menu.
final class _FRUSEditMenuWebView: WKWebView {

    /// Action for the "Highlight" edit-menu item (opens the colour picker).
    var onEditMenuHighlight: (() -> Void)?

    /// Action for the "Look Up in NARA Catalog" edit-menu item.
    var onEditMenuNARALookup: (() -> Void)?

    /// Gates the Highlight item to selections with valid in-document offsets
    /// (footnote/popover selections yield text but no highlightable range).
    var canHighlightSelection: (() -> Bool)?

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        // Only augment the selection edit menu (context system) — never the
        // app's main menu (iPad hardware-keyboard menu bar).
        guard builder.system == .context else { return }

        var actions: [UIAction] = []
        if canHighlightSelection?() ?? false, let highlightAction = onEditMenuHighlight {
            actions.append(UIAction(
                title: String(localized: "document.editMenu.highlight",
                              defaultValue: "Highlight"),
                image: UIImage(systemName: "paintbrush.pointed")
            ) { _ in highlightAction() })
        }
        if let lookupAction = onEditMenuNARALookup {
            actions.append(UIAction(
                title: String(localized: "document.editMenu.naraLookup",
                              defaultValue: "Look Up in NARA Catalog"),
                image: UIImage(systemName: "magnifyingglass.circle")
            ) { _ in lookupAction() })
        }
        guard !actions.isEmpty else { return }
        builder.insertSibling(
            UIMenu(options: .displayInline, children: actions),
            afterMenu: .standardEdit
        )
    }
}

// MARK: - iOS Representable

/// iOS-specific `UIViewRepresentable` shell for `WKWebView`.
struct _FRUSDocumentWebViewiOS: UIViewRepresentable {

    let model:          FRUSDocumentRenderModel
    let colorScheme:    ColorScheme
    let textSize:       TextSizePreference
    let highlights:     [DocumentHighlight]
    var onPersonTap:        ((PersonEntry?) -> Void)?
    var onGlossTap:         ((GlossEntry?) -> Void)?
    var onCrossRefTap:      ((String, String?) -> Void)?
    var onBrokenRefTap:     ((BrokenRefInfo?) -> Void)?
    var onSelectionChanged: ((Int, Int, String, String) -> Void)?
    var onSelectionCleared: (() -> Void)?
    var onHighlightTapped:  ((Int, Int) -> Void)?
    var onEditMenuHighlight:   (() -> Void)?
    var onEditMenuNARALookup:  (() -> Void)?
    var canHighlightSelection: (() -> Bool)?

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> WKWebView {
        let handler = FRUSURLSchemeHandler()
        context.coordinator.schemeHandler = handler

        let webView = _FRUSEditMenuWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration.frusExplorerConfiguration(
                schemeHandler:  handler,
                messageHandler: context.coordinator
            )
        )
        webView.navigationDelegate = context.coordinator
        webView.isOpaque                     = false
        webView.backgroundColor              = .clear
        webView.scrollView.backgroundColor   = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
        let newHighlightIds  = highlights.map(\.id)
        let highlightsChanged = newHighlightIds != context.coordinator.lastHighlightIds

        context.coordinator.pendingHighlights        = highlights
        context.coordinator.currentRenderingVersion  = renderingVersion
        context.coordinator.lastHighlightIds         = newHighlightIds

        let sig = WebViewSignature(
            documentId:  model.documentId,
            colorScheme: colorScheme,
            textSize:    textSize
        )
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.onSelectionCleared = onSelectionCleared
        context.coordinator.onHighlightTapped  = onHighlightTapped

        if let editMenuWebView = webView as? _FRUSEditMenuWebView {
            editMenuWebView.onEditMenuHighlight   = onEditMenuHighlight
            editMenuWebView.onEditMenuNARALookup  = onEditMenuNARALookup
            editMenuWebView.canHighlightSelection = canHighlightSelection
        }

        if context.coordinator.lastSignature != sig {
            context.coordinator.lastSignature = sig
            context.coordinator.schemeHandler?.register(model: model)
            context.coordinator.schemeHandler?.onPersonTap   = onPersonTap
            context.coordinator.schemeHandler?.onGlossTap    = onGlossTap
            context.coordinator.schemeHandler?.onCrossRefTap = onCrossRefTap
            context.coordinator.schemeHandler?.onBrokenRefTap = onBrokenRefTap
            let html = HTMLTemplate.build(model: model, colorScheme: colorScheme, textSize: textSize)
            webView.loadHTMLString(html, baseURL: nil)
        } else if highlightsChanged {
            Task { @MainActor in
                await context.coordinator.renderHighlights(on: webView)
            }
        }
    }

    func makeCoordinator() -> _FRUSWebViewCoordinator { _FRUSWebViewCoordinator() }
}

#endif
