// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

// MARK: - HTMLTemplate

/// Assembles a complete HTML document from a `FRUSDocumentRenderModel` and the current
/// app theme, built by FRUSCoreKit's `ReaderPage`.
///
/// The output is a full `<!DOCTYPE html>` document (not a fragment) suitable for
/// loading directly into `WKWebView` via `loadHTMLString(_:baseURL:)`.
///
/// ## Structure
/// ```
/// <!DOCTYPE html>
/// <html lang="en">
/// <head>
///   <style>
///     :root { /* CSS variables from FRUSTheme.cssVariables */ }
///     /* static layout and typography CSS (documentCSS) */
///   </style>
/// </head>
/// <body>
///   <!-- FRUSRenderNodeHTMLSerializer output -->
/// </body>
/// </html>
/// ```
///
/// ## CSS layering
/// - **Dynamic layer** (`FRUSTheme.cssVariables`): CSS custom properties for colors,
///   font sizes, and font family. Updated whenever the system appearance or the user's
///   text-size preference changes.
/// - **Static layer** (`HTMLTemplate.documentCSS`): Layout, typography rules, table
///   styles, editorial note decoration, and footnote popover styles. All values
///   reference `var(--...)` custom properties; no hard-coded colors or sizes.
///
/// ## Session history
///   1.0 — Session 141: initial implementation; CSS inlined as Swift string constant.
///          Session 146 will refactor `HTMLCollectionExporter` to use this template,
///          and `frus-print.css` will be added as an additional CSS layer.
///   1.1 — FRUSCoreKit, part 1: the fragment is written by `FRUSRenderNodeHTMLSerializer.reader`,
///          FRUSCoreKit's name for the reader's serializer settings, which do not change
///   1.2 — Session 2026-10-05 (FRUS Explorer Light, S8a): the page, `documentCSS` and `figureCSS`
///          moved to FRUSCoreKit's `ReaderPage`, which `build`, `documentCSS` and `figureCSS`
///          forward to with the same bytes, so FRUS Explorer Light serves the app's page
enum HTMLTemplate {

    // MARK: - Public API

    /// Builds a complete HTML document for the given model and app theme.
    ///
    /// - Parameters:
    ///   - model: The render model to display.
    ///   - colorScheme: The current `ColorScheme` from the SwiftUI environment.
    ///   - textSize: The user's text size preference (defaults to `.medium`).
    /// - Returns: A `String` suitable for `WKWebView.loadHTMLString(_:baseURL:)`.
    static func build(
        model: FRUSDocumentRenderModel,
        colorScheme: ColorScheme,
        textSize: TextSizePreference = .medium
    ) -> String {
        // FRUSCoreKit's `ReaderPage.build`, with the reader's serializer: classification chips on
        // source footnotes (Source Explorer Phase 5), which exports leave off, and figure images
        // named by `frusexplorer://figure/` URLs (#1516), which `FRUSURLSchemeHandler` answers from
        // the device's figure store.
        ReaderPage.build(model: model, appearance: ReaderAppearance(colorScheme), textSize: textSize)
    }

    // MARK: - Static CSS

    /// The rules a figure is drawn by (#1516): `ReaderPage.figureCSS`, in FRUSCoreKit.
    static var figureCSS: String { ReaderPage.figureCSS }

    /// The reader's stylesheet: `ReaderPage.documentCSS`, in FRUSCoreKit.
    static var documentCSS: String { ReaderPage.documentCSS }
}
