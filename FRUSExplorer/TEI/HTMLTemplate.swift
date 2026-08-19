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
/// app theme.
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
///
/// - Note: The `documentCSS` string constant could be moved to a bundle resource
///   (`frus-document.css`) in a future session if live-editing of CSS during
///   development becomes a priority. For now, inline keeps the build simple.
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
        // Reading views opt into classification chips on source footnotes
        // (Source Explorer Phase 5); exports construct their own serializer with
        // the default (off) so exported output is unchanged.
        let fragment = FRUSRenderNodeHTMLSerializer(annotateSourceClassification: true)
            .serialize(model)
        let cssVars  = FRUSTheme.cssVariables(colorScheme: colorScheme, textSize: textSize)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <style>
        \(cssVars)
        \(documentCSS)
          </style>
        </head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }

    // MARK: - Static CSS

    /// Layout and typography CSS that references CSS custom properties set by
    /// `FRUSTheme.cssVariables`.  All color and size values use `var(--...)` so
    /// the stylesheet works correctly in both light and dark mode and at every
    /// user text-size preference without modification.
    static let documentCSS = """
    /* ─── Reset ────────────────────────────────────────────────────────────── */
    *, *::before, *::after { box-sizing: border-box; }

    html, body {
      margin: 0;
      padding: 0;
      background-color: var(--color-background);
      color: var(--color-primary);
      font-family: var(--font-family);
      font-size: var(--font-size-body);
      line-height: 1.65;
      -webkit-text-size-adjust: none;
    }

    /* ─── Document wrapper ──────────────────────────────────────────────────── */
    /* A maximum measure, reversing the earlier "no max-width, the user can resize freely"
       decision. The 2026-08-14 UI review (X-1, the package's one CRITICAL, filed on Mac and
       iPad independently) measured the consequence of that freedom: ~150-300 characters per
       line on a resized Mac window, ~190 on a 13-inch iPad — two to four times the ~66-char
       typographic measure, on the surface the whole app exists to serve. 70ch tracks the
       reader's own font size, and margin:auto keeps the column centered, so a wide window
       adds margin rather than line length. iPhone is narrower than 70ch and unaffected. */
    .frus-document {
      max-width: 70ch;
      margin: 0 auto;
      padding: 24px 48px 48px;
    }

    /* ─── Heading ───────────────────────────────────────────────────────────── */
    h2.doc-heading {
      font-size: var(--font-size-heading);
      font-weight: 600;
      line-height: 1.3;
      margin: 0 0 0.65em;
      color: var(--color-primary);
    }

    /* ─── Dateline ──────────────────────────────────────────────────────────── */
    p.dateline {
      font-size: var(--font-size-dateline);
      color: var(--color-secondary);
      margin: 0 0 1.25em;
    }

    /* ─── Body paragraphs ───────────────────────────────────────────────────── */
    p.body {
      margin: 0 0 0.875em;
    }

    /* ─── Letter blocks ─────────────────────────────────────────────────────── */
    .letter-opener,
    .letter-closer {
      margin-bottom: 0.875em;
    }

    p.salutation {
      margin-bottom: 0.5em;
      font-style: italic;
    }

    /* ─── Editorial notes ───────────────────────────────────────────────────── */
    .editorial-note {
      border-left: 3px solid var(--color-editorial-border);
      background-color: var(--color-editorial-bg);
      padding: 0.75em 1em;
      margin: 1em 0;
      border-radius: 0 4px 4px 0;
    }

    .editorial-note p.body:last-child { margin-bottom: 0; }

    /* ─── Attachments ───────────────────────────────────────────────────────── */
    section.attachment {
      border-top: 1.5px solid var(--color-secondary);
      margin-top: 2.5em;
      padding-top: 1.75em;
    }

    h3.attachment-heading {
      font-size: calc(var(--font-size-body) * 1.1);
      font-weight: 600;
      margin: 0 0 0.7em;
      line-height: 1.3;
    }

    /* ─── Title page ────────────────────────────────────────────────────────── */
    .title-page {
      text-align: center;
      padding: 2em 0;
    }

    /* ─── Tables ────────────────────────────────────────────────────────────── */
    .frus-table {
      border-collapse: collapse;
      width: 100%;
      margin: 1em 0;
      font-size: 0.92em;
    }

    .frus-table td {
      border: 1px solid var(--color-table-border);
      padding: 0.4em 0.65em;
      vertical-align: top;
    }

    /* ─── Lists ─────────────────────────────────────────────────────────────── */
    .frus-list {
      margin: 0.5em 0 0.875em;
      padding-left: 1.5em;
    }

    .frus-list.simple {
      list-style: none;
      padding-left: 0;
    }

    .frus-list li { margin-bottom: 0.3em; }

    /* ─── Inline formatting ─────────────────────────────────────────────────── */
    .small-caps { font-variant: small-caps; }
    .underline  { text-decoration: underline; }

    .supplied {
      font-style: italic;
      color: var(--color-secondary);
    }

    s.sic {
      text-decoration: line-through;
      color: var(--color-secondary);
    }

    em.formula {
      font-family: Georgia, 'Times New Roman', serif;
    }

    /* ─── Interactive links ─────────────────────────────────────────────────── */
    a.pers-name {
      color: var(--color-pers-name);
      text-decoration: none;
      cursor: pointer;
    }
    a.pers-name:hover { text-decoration: underline; }

    a.gloss {
      color: var(--color-accent);
      text-decoration: none;
      border-bottom: 1px dotted var(--color-accent);
      cursor: pointer;
    }
    a.gloss:hover { border-bottom-style: solid; }

    a.cross-ref {
      color: var(--color-accent);
      text-decoration: none;
      cursor: pointer;
    }
    a.cross-ref:hover { text-decoration: underline; }

    /* Unresolvable cross-reference (issue #240): muted, dotted underline, help cursor,
       and a superscript marker so it reads as broken without relying on colour alone. */
    a.cross-ref-broken {
      color: var(--color-secondary);
      text-decoration: none;
      border-bottom: 1px dotted var(--color-secondary);
      cursor: help;
    }
    a.cross-ref-broken .cross-ref-broken-mark {
      font-size: 0.72em;
      vertical-align: super;
      margin-left: 1px;
    }

    /* ─── Footnote markers ──────────────────────────────────────────────────── */
    button.fn-marker {
      -webkit-appearance: none;
      appearance: none;
      background: none;
      border: none;
      padding: 0 1px;
      margin: 0;
      color: var(--color-accent);
      font-size: 0.72em;
      vertical-align: super;
      line-height: 0;
      cursor: pointer;
      font-family: var(--font-family);
    }

    /* ─── Footnote popovers (HTML Popover API) ──────────────────────────────── */
    aside.footnote {
      font-size: var(--font-size-footnote);
      color: var(--color-footnote-text);
      background: var(--color-background);
      border: 1px solid var(--color-table-border);
      border-radius: 10px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.18);
      padding: 12px 16px;
      max-width: 340px;
      margin: 0;
      position-area: block-end span-inline-end;
    }

    aside.footnote p.body { margin: 0; }
    aside.footnote p.body + p.body { margin-top: 0.5em; }

    /* ─── Classification chip (source footnotes; Source Explorer Phase 5) ───── */
    /* Quiet, semantic: secondary text in a hairline capsule — the text is the
       signal (no color coding), matching the native ClassificationChip view. */
    .classification-chip {
      display: inline-block;
      font-size: calc(var(--font-size-footnote) * 0.85);
      font-weight: 500;
      color: var(--color-secondary);
      border: 1px solid var(--color-table-border);
      border-radius: 999px;
      padding: 0 8px;
      margin-left: 6px;
      white-space: nowrap;
      vertical-align: baseline;
    }

    /* ─── Page breaks (screen: invisible; Session 146 print CSS shows them) ─── */
    .page-break { display: none; }

    /* ─── Unknown passthrough elements ─────────────────────────────────────── */
    span.unknown { /* renders as inline span; no decoration */ }

    /* ─── Visible footnote section (below body, outside .frus-document) ────── */
    .footnotes-section {
      padding: 0 48px 48px;
    }

    hr.fn-rule {
      border: none;
      border-top: 1px solid var(--color-table-border);
      margin: 0 0 1.25em;
    }

    h2.fn-section-heading {
      font-size: calc(var(--font-size-body) * 0.9);
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: var(--color-secondary);
      margin: 0 0 0.75em;
    }

    .fn-list {
      padding-left: 1.5em;
      font-size: var(--font-size-footnote);
      color: var(--color-footnote-text);
      /* #985: the <ol> counter is positional, so it numbered the source note 1 and pushed every
         printed footnote number down by one — and in the volumes whose notes run continuously
         across a printed page (44.2% of documents with numbered notes; frus1915 runs to n=99) it
         restarted at 1 and disagreed outright. 134,697 of 268,465 documents with notes were
         affected. The label span below carries the volume's own number instead. */
      list-style: none;
      padding-left: 0;
    }

    /* #988: a cross-reference can name a specific footnote, and the reader is scrolled to it.
       The offset keeps it clear of the viewport edge; the wash says which note was meant, since
       the endnote list is a wall of similar-looking entries. */
    .fn-list-item {
      scroll-margin-block: 30vh;
    }

    .fn-list-item.fn-arrived {
      animation: fn-arrived-flash 2.4s ease-out;
      border-radius: 4px;
    }

    @keyframes fn-arrived-flash {
      0%   { background-color: var(--color-accent-wash, rgba(120, 170, 255, 0.35)); }
      70%  { background-color: var(--color-accent-wash, rgba(120, 170, 255, 0.35)); }
      100% { background-color: transparent; }
    }

    /* The wash is the affordance; the motion is not. Under Reduce Motion the class still lands
       and still tints, it just does not animate. The SCROLL is gated separately, in the script
       that adds this class — an explicit `behavior` argument overrides `scroll-behavior`, so a
       CSS-only guard here would leave the larger motion running. */
    @media (prefers-reduced-motion: reduce) {
      .fn-list-item.fn-arrived {
        animation: none;
        background-color: var(--color-accent-wash, rgba(120, 170, 255, 0.35));
      }
    }

    .fn-list-item {
      margin-bottom: 0.5em;
      line-height: 1.55;
      /* room for the label, which now hangs in the margin like a printed footnote */
      padding-left: 2.2em;
      text-indent: -2.2em;
    }

    .fn-list-label {
      /* #985: the number as PRINTED IN THE VOLUME — the number a citation names. */
      display: inline-block;
      min-width: 1.8em;
      text-indent: 0;
      color: var(--color-accent);
    }

    /* The archival/bullet mark shown for a note the volume printed without a number. Sized in em
       so it tracks --font-size-body through the four TextSizePreference steps, and filled with
       currentColor so it takes the accent colour and the dark-mode palette for free. */
    .fn-glyph {
      width: 1em;
      height: 1em;
      vertical-align: -0.12em;
    }

    /* The marker button sets line-height:0 for superscript alignment, which gives a replaced
       element no line box to sit in. Restoring it locally keeps the glyph from overlapping the
       line above without disturbing the numeric markers. */
    button.fn-marker-unnumbered {
      line-height: 1;
      vertical-align: baseline;
      font-size: 0.9em;
    }

    .fn-list-item p.body { margin: 0; display: inline; }

    /* ─── CSS Custom Highlight API — document highlights (Session 144) ──────── */
    /* Color names map 1:1 to DocumentHighlight.Color raw values.                */
    ::highlight(frus-yellow) { background-color: rgba(255, 214,   0, 0.40); }
    ::highlight(frus-green)  { background-color: rgba(  0, 200,  83, 0.40); }
    ::highlight(frus-blue)   { background-color: rgba(  0, 122, 255, 0.40); }
    ::highlight(frus-pink)   { background-color: rgba(255,  45,  85, 0.40); }
    ::highlight(frus-stale)  { background-color: rgba(255, 149,   0, 0.30); }
    """
}
