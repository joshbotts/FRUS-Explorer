// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import WebKit

// MARK: - SelectionPayload

/// A live text selection reported to `onSelectionChanged` — offsets, text, footnote block, and
/// the bounding geometry that anchors the floating selection bar. A struct (not a positional
/// tuple) so the growing payload stays readable.
struct SelectionPayload: Equatable {
    /// Flat-text Unicode-scalar start offset, or `-1` for an out-of-document (footnote) selection.
    let start: Int
    /// Flat-text end offset, or `-1` for a footnote selection.
    let end: Int
    /// The raw selected string (`window.getSelection().toString()`), for pre-populating NARA lookup.
    let text: String
    /// The enclosing footnote body for a footnote selection, else `""` (#269).
    let blockText: String
    /// The selection's bounding rect in the web view's own point space (viewport CSS px at
    /// `scale == 1`), or `nil` when unavailable — anchors the floating selection bar.
    let rect: CGRect?
    /// `visualViewport.scale` at capture (`1` when unavailable / unzoomed), so iOS can correct
    /// for pinch zoom (macOS never magnifies).
    let scale: CGFloat

    /// Creates a payload. `blockText`/`rect`/`scale` default so tests and in-document callers stay terse.
    init(start: Int, end: Int, text: String, blockText: String = "",
         rect: CGRect? = nil, scale: CGFloat = 1) {
        self.start = start
        self.end = end
        self.text = text
        self.blockText = blockText
        self.rect = rect
        self.scale = scale
    }

    /// `true` when the selection has valid in-document flat-text offsets (so it is highlightable);
    /// `false` for a footnote / out-of-document selection.
    var hasOffsets: Bool { start >= 0 && end > start }
}

// MARK: - FRUSSelectionEvent

/// The decoded outcome of a `selectionChanged` message from the selection bridge JS — a pure
/// value so decoding is unit-testable without a `WKScriptMessage` (which has no public
/// initializer). See `decodeFRUSSelectionEvent(from:)`.
enum FRUSSelectionEvent: Equatable {
    /// No live selection (collapsed/cleared).
    case cleared
    /// A live selection — in-document when `payload.hasOffsets`, else a footnote selection.
    case selection(SelectionPayload)
}

/// Decodes a `selectionChanged` message body into a `FRUSSelectionEvent`.
///
/// Returns `nil` for a malformed body (missing/non-integer `start`/`end`) or a degenerate
/// in-document range (`end <= start`). A footnote body with a missing/empty `blockText` falls
/// back to the raw selected text, so the footnote branch always has some block context. `rect`
/// and `scale` are tolerant — absent/malformed geometry decodes to `rect: nil, scale: 1`, so
/// older payload shapes (pre-rect) still decode cleanly.
func decodeFRUSSelectionEvent(from body: [String: Any]) -> FRUSSelectionEvent? {
    guard let start = body["start"] as? Int, let end = body["end"] as? Int else { return nil }
    let text = (body["text"] as? String) ?? ""
    let rect = decodeSelectionRect(body["rect"])
    let scale = CGFloat((body["scale"] as? NSNumber)?.doubleValue ?? 1)
    if start < 0 {
        guard !text.isEmpty else { return .cleared }
        let block = (body["blockText"] as? String) ?? ""
        return .selection(SelectionPayload(start: -1, end: -1, text: text,
                                           blockText: block.isEmpty ? text : block,
                                           rect: rect, scale: scale))
    }
    guard end > start else { return nil }
    return .selection(SelectionPayload(start: start, end: end, text: text, rect: rect, scale: scale))
}

/// Decodes a `{x,y,w,h}` rect dictionary from a selection message body — JS numbers arrive as
/// `NSNumber` (and plain `Double`/`Int` from unit tests bridge the same way). Returns `nil` when
/// absent or any field is missing/non-numeric, so a bar consumer treats it as "no anchor".
func decodeSelectionRect(_ value: Any?) -> CGRect? {
    guard let d = value as? [String: Any],
          let x = (d["x"] as? NSNumber)?.doubleValue,
          let y = (d["y"] as? NSNumber)?.doubleValue,
          let w = (d["w"] as? NSNumber)?.doubleValue,
          let h = (d["h"] as? NSNumber)?.doubleValue else { return nil }
    return CGRect(x: x, y: y, width: w, height: h)
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

    /// Called with a `SelectionPayload` when the user selects text in the WKWebView — offsets,
    /// raw text, the footnote `blockText` (#269), and the bounding `rect`/`scale` that anchor the
    /// floating selection bar (`rect` is in the web view's own point space).
    var onSelectionChanged: ((SelectionPayload) -> Void)? = nil

    /// Called when the selection is collapsed or cleared.
    var onSelectionCleared: (() -> Void)? = nil

    /// Called (throttled) when the document scrolls inside the web view while a selection is
    /// live — the anchoring `rect` has gone stale, so a floating bar consumer should dismiss.
    var onSelectionScrolled: (() -> Void)? = nil

    /// Called when the user taps within a non-stale highlight range.
    /// `(startOffset, endOffset)` uniquely identifies the highlight so the
    /// caller can look it up in SwiftData and offer to delete it.
    var onHighlightTapped: ((Int, Int) -> Void)? = nil

    /// Stored highlights to render via the CSS Custom Highlight API after each
    /// page load. Updated highlights are re-rendered without a full HTML reload.
    var highlights: [DocumentHighlight] = []

    #if os(macOS)
    /// Find-in-document controller (#363 #5). The macOS representable hands it the live
    /// `WKWebView` so `WKWebView.find(_:configuration:)` can drive the find bar. `nil`
    /// where find-in-document isn't wired (macOS has no native find bar; iOS uses
    /// `isFindInteractionEnabled` instead, so this is macOS-only).
    var findController: DocumentFindController? = nil
    #endif

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
            findController:     findController,
            onPersonTap:        onPersonTap,
            onGlossTap:         onGlossTap,
            onCrossRefTap:      onCrossRefTap,
            onBrokenRefTap:     onBrokenRefTap,
            onSelectionChanged: onSelectionChanged,
            onSelectionCleared: onSelectionCleared,
            onSelectionScrolled: onSelectionScrolled,
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
            onSelectionScrolled: onSelectionScrolled,
            onHighlightTapped:  onHighlightTapped
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

    #if os(macOS)
    /// Attaches the find-in-document controller (#363 #5) so ⌘F can drive
    /// `WKWebView.find` on this document's web view. macOS-only — iOS uses the
    /// web view's native `isFindInteractionEnabled`.
    func findController(_ controller: DocumentFindController) -> FRUSDocumentWebView {
        var copy = self; copy.findController = controller; return copy
    }
    #endif

    /// Registers a callback for when the user makes a text selection in the web view. The
    /// `SelectionPayload` carries the flat-text offsets, raw text, footnote `blockText`, and the
    /// bounding `rect`/`scale` that anchor the floating selection bar.
    func onSelectionChanged(_ handler: @escaping (SelectionPayload) -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onSelectionChanged = handler; return copy
    }

    /// Registers a callback for when the selection is collapsed or cleared.
    func onSelectionCleared(_ handler: @escaping () -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onSelectionCleared = handler; return copy
    }

    /// Registers a callback fired (throttled) when a live selection scrolls inside the web view,
    /// so an anchored floating bar can dismiss before its rect goes stale.
    func onSelectionScrolled(_ handler: @escaping () -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onSelectionScrolled = handler; return copy
    }

    /// Registers a callback fired when the user taps inside a rendered highlight.
    /// `(startOffset, endOffset)` matches `DocumentHighlight.startOffset`/`endOffset`
    /// so the caller can fetch and delete the record from SwiftData.
    func onHighlightTapped(_ handler: @escaping (Int, Int) -> Void) -> FRUSDocumentWebView {
        var copy = self; copy.onHighlightTapped = handler; return copy
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

    /// Fired when JS reports a valid text selection.
    var onSelectionChanged: ((SelectionPayload) -> Void)?
    /// Fired when JS reports the selection was cleared (`{start: -1, end: -1}`).
    var onSelectionCleared: (() -> Void)?
    /// Fired (throttled) when the document scrolls with a live selection — the anchor rect is stale.
    var onSelectionScrolled: (() -> Void)?
    /// Fired when the user taps inside a rendered highlight range.
    var onHighlightTapped: ((Int, Int) -> Void)?

    // MARK: WKScriptMessageHandler

    /// Receives `selectionChanged`, `selectionScrolled`, and `highlightTapped` messages from
    /// `frus-selection.js` / `kSelectionJS`.
    ///
    /// A `selectionChanged` body carries `"start"`, `"end"`, `"text"`, and — per selection kind —
    /// `"blockText"` (footnote body) plus `"rect"`/`"scale"` (bar-anchor geometry). `start == -1`
    /// with empty text signals selection cleared; `start >= 0 && end > start` is a valid
    /// in-document range in flat-text Unicode-scalar offsets. `selectionScrolled` (empty body) is
    /// the throttled stale-rect hide signal. Decoding is factored into the pure
    /// `decodeFRUSSelectionEvent(from:)` so it is unit-testable without a `WKScriptMessage`.
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
            case .selection(let payload):
                // In-document (`payload.hasOffsets`) or footnote selection; the payload carries
                // the offsets/text/blockText plus the rect/scale that anchor the floating bar.
                onSelectionChanged?(payload)
            case nil:
                break
            }

        case "selectionScrolled":
            // A live selection scrolled inside the web view: the anchoring rect is now stale.
            onSelectionScrolled?()

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
    /// Find-in-document controller (#363 #5); receives the live `WKWebView` on creation.
    var findController:     DocumentFindController?
    var onPersonTap:        ((PersonEntry?) -> Void)?
    var onGlossTap:         ((GlossEntry?) -> Void)?
    var onCrossRefTap:      ((String, String?) -> Void)?
    var onBrokenRefTap:     ((BrokenRefInfo?) -> Void)?
    var onSelectionChanged: ((SelectionPayload) -> Void)?
    var onSelectionCleared: (() -> Void)?
    var onSelectionScrolled: (() -> Void)?
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
        // Hand the live web view to the find controller (#363 #5). Deferred off the view-update
        // pass so the controller's @Observable state isn't mutated mid-render.
        if let findController {
            Task { @MainActor in findController.webView = webView }
        }
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
        context.coordinator.onSelectionScrolled = onSelectionScrolled
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
    var onSelectionChanged: ((SelectionPayload) -> Void)?
    var onSelectionCleared: (() -> Void)?
    var onSelectionScrolled: (() -> Void)?
    var onHighlightTapped:  ((Int, Int) -> Void)?

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> WKWebView {
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
        webView.isOpaque                     = false
        webView.backgroundColor              = .clear
        webView.scrollView.backgroundColor   = .clear
        // #363 #5: the native find interaction — a hardware-keyboard ⌘F (or the system edit
        // menu) presents iOS/iPadOS's built-in find bar over the document. macOS has no
        // equivalent, so it uses the custom `DocumentFindBar` instead.
        webView.isFindInteractionEnabled = true
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
        context.coordinator.onSelectionScrolled = onSelectionScrolled
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

#endif
