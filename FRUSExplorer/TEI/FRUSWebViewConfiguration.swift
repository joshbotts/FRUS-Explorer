// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import WebKit

// MARK: - WKWebViewConfiguration factory

extension WKWebViewConfiguration {

    /// Returns a `WKWebViewConfiguration` with the given `FRUSURLSchemeHandler`
    /// registered for the `frusexplorer://` custom URL scheme.
    ///
    /// Each `FRUSDocumentWebView` instance creates its own `FRUSURLSchemeHandler`
    /// and calls this factory so the handler's per-document person/gloss lookup
    /// tables are correctly scoped to that view.
    ///
    /// ## Session history
    /// - **Session 141**: Used `StubFRUSURLSchemeHandler`; handler not yet parameterised.
    /// - **Session 142**: Handler is passed in; dispatches person/gloss/cross-ref taps.
    /// - **Session 143**: `WKUserScript` injections for `frus-offset-engine.js` added.
    /// - **Session 144**: `frus-highlights.js` injected.
    /// - **Session 145**: `frus-selection.js` injected; `selectionChanged` message
    ///   handler registered.
    /// - **Session 2026-10-24 (FRUS Explorer Light, S15a)**: the three scripts are FRUSCoreKit's,
    ///   public and unchanged (`FRUSCoreKit/TEI/ReaderAnnotationScripts.swift`), so the web
    ///   edition's reader serves the same bytes; this injects them as before.
    /// - Parameters:
    ///   - schemeHandler:   Per-view `FRUSURLSchemeHandler` for `frusexplorer://` dispatch.
    ///   - messageHandler:  Receives `selectionChanged` messages from the selection JS.
    ///                      Typically `_FRUSWebViewCoordinator` which conforms to
    ///                      `WKScriptMessageHandler`.
    static func frusExplorerConfiguration(
        schemeHandler:  FRUSURLSchemeHandler,
        messageHandler: any WKScriptMessageHandler
    ) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "frusexplorer")

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let ucc = config.userContentController

        // 1. Offset engine — sets window.FRUSOffsets.{flatText, charToNode}
        ucc.addUserScript(WKUserScript(
            source: kOffsetEngineJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        // 2. Highlights renderer — defines window.FRUSHighlights.render(highlights)
        ucc.addUserScript(WKUserScript(
            source: kHighlightsJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        // 3. Selection listener — posts selectionChanged messages to Swift
        ucc.addUserScript(WKUserScript(
            source: kSelectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        ucc.add(messageHandler, name: "selectionChanged")
        ucc.add(messageHandler, name: "selectionScrolled")
        ucc.add(messageHandler, name: "highlightTapped")

        return config
    }
}
