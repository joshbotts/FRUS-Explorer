// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - FeatureFlags

/// Compile-time feature flags that guard transitional migration paths.
///
/// All flags are `static let` constants — the compiler eliminates dead code for
/// whichever branch is not taken, so there is no runtime cost. Flip a flag to
/// `false` to revert to the legacy code path for debugging.
///
/// ## WebKit renderer migration (Sessions 141–147)
/// The `useWebKitRenderer` flag controls whether `FRUSDocumentWebView` or the
/// legacy `FRUSDocumentRenderer` is shown in `DocumentView` and `MacDocumentView`.
/// The legacy renderer and `DocumentHighlightTextView` are retained until Session 147
/// confirms the WebKit path is stable across all document types, then both files are
/// deleted and this flag is removed.
///
/// Highlight mode (`DocumentHighlightTextView`) is **always** shown regardless of
/// `useWebKitRenderer` until Session 145 migrates it to the JS selection API.
enum FeatureFlags {

    /// When `true`, document bodies are rendered by `FRUSDocumentWebView` (WKWebView
    /// backed by `FRUSRenderNodeHTMLSerializer`).
    ///
    /// When `false`, the legacy `FRUSDocumentRenderer` (SwiftUI VStack) is used.
    /// Set to `false` to compare the two renderers side by side during development.
    static let useWebKitRenderer: Bool = true
}
