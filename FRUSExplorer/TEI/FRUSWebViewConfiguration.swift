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
    static func frusExplorerConfiguration(
        schemeHandler: FRUSURLSchemeHandler
    ) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "frusexplorer")

        // JavaScript disabled until Session 143 injects user scripts.
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs

        return config
    }
}
