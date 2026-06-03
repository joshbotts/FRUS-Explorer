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

    /// Returns the shared `WKWebViewConfiguration` used by all `FRUSDocumentWebView` instances.
    ///
    /// ## Session history
    /// - **Session 141**: Registers `StubFRUSURLSchemeHandler` so the WebKit engine never
    ///   triggers a navigation error for `frusexplorer://` links while interactive dispatch
    ///   is not yet wired. The `WKNavigationDelegate` in `FRUSDocumentWebView` blocks
    ///   those links with `.cancel` as a secondary guard.
    /// - **Session 142**: `StubFRUSURLSchemeHandler` is replaced by `FRUSURLSchemeHandler`,
    ///   which dispatches person/gloss/cross-reference taps to Swift callbacks.
    /// - **Session 143**: `WKUserScript` injections for the JS flat-text offset engine
    ///   are added here (`frus-offset-engine.js`).
    /// - **Session 144**: `frus-highlights.js` injected here.
    /// - **Session 145**: `frus-selection.js` injected and `selectionChanged` message
    ///   handler registered here.
    static func frusExplorerConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // Intercept frusexplorer:// navigations so WebKit never reports a load error.
        // Session 142 replaces StubFRUSURLSchemeHandler with the real FRUSURLSchemeHandler.
        config.setURLSchemeHandler(StubFRUSURLSchemeHandler(), forURLScheme: "frusexplorer")

        // Preferences
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false   // no JS until Session 143
        config.defaultWebpagePreferences = prefs

        return config
    }
}

// MARK: - Stub URL scheme handler (Session 141 only)

/// Silently absorbs all `frusexplorer://` navigations with an empty 200-OK response.
///
/// This prevents WebKit from raising a navigation error when the user taps a
/// persName, gloss, or cross-reference link before `FRUSURLSchemeHandler` is
/// wired up in Session 142.  The stub is replaced in Session 142; nothing in the
/// app depends on the response body it returns.
private final class StubFRUSURLSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let url = urlSchemeTask.request.url
            ?? URL(string: "frusexplorer://noop")!
        let response = URLResponse(
            url: url,
            mimeType: "text/plain",
            expectedContentLength: 0,
            textEncodingName: nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(Data())
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
