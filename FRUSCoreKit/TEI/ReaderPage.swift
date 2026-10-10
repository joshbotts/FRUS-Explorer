// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ReaderAppearance

/// The reader's two palettes, which `ReaderPage.cssVariables(appearance:textSize:)` writes. The app
/// takes one from SwiftUI's colour scheme (`ReaderAppearance.init(_:)`, in `FRUSTheme.swift`); a host
/// outside the app from its request.
///
/// Version history:
///   1.0 — Session 2026-10-05 (FRUS Explorer Light, S8a): initial implementation
public enum ReaderAppearance: String, CaseIterable, Sendable {
    case light, dark
}

// MARK: - ReaderPage

/// The reader's page: a complete `<!DOCTYPE html>` document around a serializer's fragment, with
/// the theme's CSS variables and the reader's stylesheet in its head, suitable for loading directly
/// into `WKWebView` via `loadHTMLString(_:baseURL:)`, or for a browser.
///
/// ## Structure
/// ```
/// <!DOCTYPE html>
/// <html lang="en">
/// <head>
///   <style>
///     :root { /* cssVariables(appearance:textSize:) */ }
///     /* documentCSS */
///   </style>
///   <!-- head, when a host passes one -->
/// </head>
/// <body>
///   <!-- the serializer's fragment, one line -->
/// </body>
/// </html>
/// ```
///
/// Version history:
///   1.0 — Session 2026-10-05 (FRUS Explorer Light, S8a): the app's `HTMLTemplate` page and
///          stylesheets and `FRUSTheme.cssVariables(colorScheme:textSize:)` moved here, which the app's
///          names forward to with the same bytes, so FRUS Explorer Light serves the app's page. A host
///          passes its own serializer (`FRUSRenderNodeHTMLSerializer.reader(figureURL:)`) and `head`
///   1.1 — Session 2026-10-06 (FRUS Explorer Light, S9b): the page meets WCAG 2.2 AA contrast. The
///          accent, person-name and light secondary colours are at least 4.5:1 against the page and
///          the editorial note's tint in both palettes, and person and cross-reference links are
///          underlined, so they differ from the text around them by more than colour (1.4.1)
///   1.2 — Session 2026-10-08: on paper the person and cross-reference links print without their
///          underline (`@media print`), the owner's answer to the question #1578 left open. The
///          screen is unchanged. The rule reaches the Mac's File ▸ Print, which prints the reader's
///          own web view, and a collection's HTML export when a browser prints it
///   1.3 — Session 2026-10-09: #1602 — two places #1578 left under 4.5:1. Text inside one of the
///          reader's highlights is drawn in `--color-highlight-text`, since a link over a tint was
///          as low as 2.00:1; and the wash behind a footnote a cross-reference arrives at is
///          `--color-accent-wash`, a variable the stylesheet had always named and the palette never
///          defined, now light enough (and in the dark palette blue enough) for every text colour
public enum ReaderPage {

    // MARK: - Page

    /// Builds the reader's page for `model`.
    ///
    /// - Parameters:
    ///   - model: The render model to display.
    ///   - appearance: The palette, `.light` by default.
    ///   - textSize: The body text size, `.medium` by default.
    ///   - serializer: What writes the fragment: `FRUSRenderNodeHTMLSerializer.reader`, the app's, by
    ///     default.
    ///   - head: Markup a host adds at the end of the head, such as its scripts, each line ending in
    ///     a newline. Empty by default, which adds nothing.
    /// - Returns: The page, whose body is the fragment alone between `<body>\n` and `\n</body>`.
    public static func build(
        model: FRUSDocumentRenderModel,
        appearance: ReaderAppearance = .light,
        textSize: TextSizePreference = .medium,
        serializer: FRUSRenderNodeHTMLSerializer = .reader,
        head: String = ""
    ) -> String {
        let fragment = serializer.serialize(model)
        let cssVars  = cssVariables(appearance: appearance, textSize: textSize)
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
        \(head)</head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }

    // MARK: - CSS variables

    /// Returns a CSS `:root { }` block containing all custom properties consumed by
    /// ``documentCSS``.
    ///
    /// Called by ``build(model:appearance:textSize:serializer:head:)``, which the app's
    /// `HTMLTemplate.build(model:colorScheme:textSize:)` calls whenever the model, system
    /// appearance, or user text-size preference changes. Because `WKWebView` is reloaded on each
    /// signature change, no JavaScript injection is required to update the theme at runtime — the
    /// full HTML string is rebuilt with the new variables.
    ///
    /// ## Color palette
    /// Colors are hardcoded RGBA values modelled on the iOS/macOS system appearance
    /// semantics for the given appearance. This avoids the complexity of resolving
    /// SwiftUI `Color` or `NSColor`/`UIColor` semantic colors through the platform
    /// appearance APIs. Every text colour meets WCAG 2.2 AA for small text, 4.5:1, against
    /// `--color-background` and against `--color-editorial-bg` laid over it, in both palettes;
    /// the accent and person-name colours are darker (light) or brighter (dark) than the
    /// system blue and teal they started from for that reason. `ReaderPageTests` computes the
    /// ratios from this block.
    ///
    /// ## Variable inventory
    /// | Variable                    | Usage                                      |
    /// |-----------------------------|--------------------------------------------|
    /// | `--color-primary`           | Body text                                  |
    /// | `--color-secondary`         | Dateline, Footnotes heading, broken refs,  |
    /// |                             | classification chip, supplied and sic text,|
    /// |                             | figure placeholder, attachment rule        |
    /// | `--color-footnote-text`     | Visible footnote-list body text            |
    /// | `--color-accent`            | Links, footnote markers and labels         |
    /// | `--color-background`        | Page background, footnote popover bg       |
    /// | `--color-editorial-border`  | Left border of editorial note blocks       |
    /// | `--color-editorial-bg`      | Background tint of editorial note blocks   |
    /// | `--color-pers-name`         | Person name link color (teal)              |
    /// | `--color-highlight-text`    | All text inside one of the reader's        |
    /// |                             | highlights                                 |
    /// | `--color-accent-wash`       | The wash behind a footnote a               |
    /// |                             | cross-reference arrived at                 |
    /// | `--color-table-border`      | Table cell borders and footnote outlines   |
    /// | `--font-size-body`          | Paragraph text; derived from `textSize`    |
    /// | `--font-size-heading`       | h2.doc-heading (≈ 1.28× body)             |
    /// | `--font-size-dateline`      | p.dateline (≈ 0.86× body)                 |
    /// | `--font-size-footnote`      | aside.footnote content (≈ 0.78× body)     |
    /// | `--font-family`             | System font stack                          |
    ///
    /// - Parameters:
    ///   - appearance:  `.light` or `.dark`; the app passes SwiftUI's colour scheme.
    ///   - textSize:    The user's body-text size preference. Defaults to `.medium`.
    public static func cssVariables(
        appearance: ReaderAppearance,
        textSize: TextSizePreference = .medium
    ) -> String {
        let dark = appearance == .dark

        // ── Colors ────────────────────────────────────────────────────────────
        // WCAG 2.2 AA: the reader's text is small text for WCAG — the body runs from 12px (Small)
        // to 19px (Extra Large), the dateline and the footnotes smaller, and a heading is 18px at
        // weight 600 at Medium — so each text colour must reach 4.5:1 against the page AND against
        // the editorial note's tint laid over it, the lower of the two. An alpha colour is measured
        // as it composites over each. The comments below give the ratios, page then editorial
        // note; `ReaderPageTests` computes them from this block, for every text colour, and fails
        // under 4.5.
        let primary            = dark ? "rgba(255,255,255,0.88)" : "rgba(0,0,0,0.85)"
        // The dateline, the Footnotes heading, broken references and the classification chip.
        // Light, 60% black: 5.74 / 5.51 (it was 50%, 3.98 / 3.87). Dark, 52% white: 5.48 / 5.04.
        let secondary          = dark ? "rgba(255,255,255,0.52)" : "rgba(0,0,0,0.60)"
        // Footnote body text is small (≈0.785× body), so it needs more contrast
        // than ordinary secondary text to stay legible — most noticeably in dark
        // mode, where 52% white at footnote size is hard to read.
        let footnoteText       = dark ? "rgba(255,255,255,0.78)"  : "rgba(0,0,0,0.68)"
        // Links, the footnote markers and the footnote list's numbers. In light mode a darker blue
        // than the system blue it started from, rgb(0,122,255), which was 4.02 / 3.52; in dark mode
        // a lighter one than the dark systemBlue, rgb(10,132,255), which was 4.66 / 3.97. Now
        // 5.57 / 4.87 light and 6.01 / 5.11 dark.
        let accent             = dark ? "rgb(64,156,255)" : "rgb(0,102,204)"
        let background         = dark ? "rgb(28,28,30)"           : "rgb(255,255,255)"
        let editorialBorder    = dark ? "rgba(160,120,230,0.60)"  : "rgba(140,0,140,0.50)"
        let editorialBg        = dark ? "rgba(160,120,230,0.12)"  : "rgba(128,0,128,0.07)"
        // Person-name links: teal, darker in light mode and brighter in dark mode than the one
        // teal both palettes shared, rgb(0,150,136), which was 3.67 / 3.22 light and 4.63 / 3.94
        // dark. Now 5.32 / 4.66 light and 6.45 / 5.49 dark.
        let persName           = dark ? "rgb(0,179,161)" : "rgb(0,121,107)"
        // #1602: text inside one of the reader's highlights, whatever colour it has outside one.
        // The tints (`::highlight(frus-…)` below) are the highlight colours the native views share,
        // and over them a link fell to 3.24 (light, blue) and 2.00 (dark, yellow), secondary text to
        // 2.76 (dark, yellow), and body text itself to 4.35 on a yellow highlight inside an
        // editorial note in the dark palette. Full black and full white are at least 11.79 / 10.77
        // light and 5.67 / 5.08 dark over every tint, on the page and in an editorial note.
        let highlightText      = dark ? "rgb(255,255,255)" : "rgb(0,0,0)"
        // #1602: the wash behind a footnote a cross-reference arrived at (`fn-arrived-flash`). The
        // stylesheet named this variable and no palette defined it, so both palettes drew its
        // fallback, rgba(120,170,255,0.35), over which the note's number and any link in the note
        // were 4.22 light and 2.97 dark, and a person's name 4.03 and 3.19. Every text colour over
        // the wash is now at least 4.63 light and 4.64 dark.
        //
        // The price is a fainter wash, and the arithmetic sets it: for a person's name to keep
        // 4.5:1 a light wash can be no more than 1.18:1 from the page, and for a link to keep it
        // a dark wash no more than 1.34:1. The old wash was 1.32:1 and 2.02:1. The light one is
        // the same blue at half the strength (1.15:1); the dark one is a deeper blue (1.30:1),
        // since blue adds the least luminance for the colour it shows.
        let accentWash         = dark ? "rgba(40,90,255,0.28)" : "rgba(120,170,255,0.18)"
        let tableBorder        = dark ? "rgba(255,255,255,0.20)"  : "rgba(0,0,0,0.18)"

        // ── Typography ────────────────────────────────────────────────────────
        let bodyPt    = textSize.bodyFontSize          // e.g. 14.0
        let headingPt = (bodyPt * 1.28).rounded()      // e.g. 18.0
        let datePt    = (bodyPt * 0.857).rounded()     // e.g. 12.0
        let footPt    = (bodyPt * 0.785).rounded()     // e.g. 11.0
        let fontStack = "-apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif"

        func px(_ v: Double) -> String { "\(Int(v))px" }

        return """
        :root {
          --color-primary:           \(primary);
          --color-secondary:         \(secondary);
          --color-footnote-text:     \(footnoteText);
          --color-accent:            \(accent);
          --color-background:        \(background);
          --color-editorial-border:  \(editorialBorder);
          --color-editorial-bg:      \(editorialBg);
          --color-pers-name:         \(persName);
          --color-highlight-text:    \(highlightText);
          --color-accent-wash:       \(accentWash);
          --color-table-border:      \(tableBorder);
          --font-size-body:          \(px(bodyPt));
          --font-size-heading:       \(px(headingPt));
          --font-size-dateline:      \(px(datePt));
          --font-size-footnote:      \(px(footPt));
          --font-family:             \(fontStack);
        }
        """
    }

    // MARK: - Static CSS
    //
    // The stylesheet could be moved to a resource (`frus-document.css`) if live-editing it during
    // development became a priority; inline keeps the build simple, and the kit reads no bundle.

    /// The rules a figure is drawn by (#1516), part of ``documentCSS`` — so the collection HTML
    /// export and its preview, which embed that stylesheet and draw the same markup, have them too.
    ///
    /// A figure between blocks is a centred block; one inside a line (`in-line`) is an
    /// inline-block, so a shipper's mark sits in its table cell's line and a chart in a sentence
    /// takes a line of its own only when it is wider than what is left of the line. An image
    /// never exceeds its column. The head is above the image and the captions under it, each on
    /// a line of its own, the head in italics as history.state.gov prints one. The placeholder
    /// is hidden until the figure is marked `missing` — the reader's `<img onerror>` — or has no
    /// image element at all, which is how every other caller prints it.
    ///
    /// All of a figure is data-skip, and deliberately not `user-select: none`, for the reason
    /// the list parts give above: kSelectionJS moves an endpoint inside one to the first letter
    /// after it.
    public static let figureCSS = """
    /* ─── Figures (#1516) ───────────────────────────────────────────────────── */
        .frus-figure {
          display: block;
          margin: 1.25em 0;
          text-align: center;
        }
        .frus-figure.in-line {
          display: inline-block;
          margin: 0;
          max-width: 100%;
          vertical-align: middle;
        }
        /* A figure the TEI puts between two list items stands between them. */
        .list-aside > .frus-figure.in-line,
        .list-trailing > .frus-figure.in-line {
          display: block;
          margin: 0.5em 0;
        }
        /* White behind the image whatever the theme: the corpus's figures are scans and line
           drawings made for a white page, and one with a transparent ground would lose its black
           lines on the dark theme's background. */
        .frus-figure img.figure-image {
          display: block;
          max-width: 100%;
          height: auto;
          margin: 0 auto;
          background-color: #fff;
        }
        .frus-figure .figure-head,
        .frus-figure .figure-caption {
          display: block;
          font-size: 0.92em;
        }
        .frus-figure .figure-head { font-style: italic; margin-bottom: 0.4em; }
        .frus-figure figcaption,
        .frus-figure.in-line .figure-caption { margin-top: 0.4em; }
        .frus-figure .figure-missing { color: var(--color-secondary, #666); }
        .frus-figure img.figure-image + .figure-missing { display: none; }
        .frus-figure.missing img.figure-image { display: none; }
        .frus-figure.missing img.figure-image + .figure-missing { display: inline; }
    """

    /// Layout and typography CSS that references CSS custom properties set by
    /// ``cssVariables(appearance:textSize:)``.  All color and size values use `var(--...)` so
    /// the stylesheet works correctly in both light and dark mode and at every
    /// user text-size preference without modification.
    public static let documentCSS = """
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

    /* ─── Emphasis ──────────────────────────────────────────────────────────── */
    /* `<hi rend="strong">` reaches here as <strong> (#1323). Pin the weight: WebKit's UA
       default is `bolder`, which is RELATIVE, so inside the 600-weight headings above it
       resolves to 900 — and OH wraps 1,004 whole attachment heads in `strong` (820
       documents), which would then print visibly heavier than the same head in a volume
       that does not wrap it. 700 everywhere, inherited inside a heading. */
    strong { font-weight: 700; }
    h2.doc-heading strong,
    h3.attachment-heading strong { font-weight: inherit; }

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

    /* #1495: the caption the volume printed above a table — its title, often its units
       (Millions of Dollars). Above the table, in italics, from its left edge, as
       history.state.gov prints a table's head (its tei-head2 rule); <caption> centres by
       default. data-skip, like a list's heading, so kSelectionJS moves an endpoint inside it
       to the first cell's first letter (ListLabelSelectionTests). */
    .frus-table > caption.table-caption {
      caption-side: top;
      text-align: left;
      font-style: italic;
      padding: 0 0 0.35em;
    }

    \(figureCSS)

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

    /* #1371: a list's own heading (SUBJECT, PARTICIPANTS:) and the label the volume printed
       beside each item ((1), 2., a.). The label goes where the bullet went, so a labelled list
       has no bullet. It FLOATS into the list's left padding rather than sitting inline, because
       11,343 labelled items open with a <p>: an inline label would take a line of its own above
       the paragraph. A label wider than the padding pushes the item's first line right instead
       of overlapping it. */
    .list-heading {
      font-weight: 600;
      margin: 0.875em 0 0.25em;
    }
    .list-heading + .frus-list { margin-top: 0; }

    .frus-list.labelled {
      list-style: none;
      padding-left: 2.4em;
    }

    .frus-list.labelled > li > .list-label {
      float: left;
      min-width: 2.4em;
      margin-left: -2.4em;
      padding-right: 0.35em;
    }

    /* All four parts are data-skip, and deliberately NOT user-select: none. An endpoint inside
       one has no flat-text offset; kSelectionJS moves it to the item's first letter instead
       (ListLabelSelectionTests). user-select: none was measured first and fixed nothing —
       caretRangeFromPoint still placed the caret inside the label — while it dropped the labels
       from the selection's own text (getSelection().toString(), which Look Up receives). */

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
    /* Each link is marked by more than its colour (WCAG 1.4.1): against the body text around it
       none reaches the 3:1 that colour alone would need. Person and cross-reference links carry a
       quiet underline, the font's own thickness set a little below the baseline, which thickens
       on hover; a gloss keeps its dotted rule, which turns solid. */
    a.pers-name {
      color: var(--color-pers-name);
      text-decoration: underline;
      text-decoration-thickness: from-font;
      text-underline-offset: 0.15em;
      cursor: pointer;
    }
    a.pers-name:hover { text-decoration-thickness: 0.125em; }

    a.gloss {
      color: var(--color-accent);
      text-decoration: none;
      border-bottom: 1px dotted var(--color-accent);
      cursor: pointer;
    }
    a.gloss:hover { border-bottom-style: solid; }

    a.cross-ref {
      color: var(--color-accent);
      text-decoration: underline;
      text-decoration-thickness: from-font;
      text-underline-offset: 0.15em;
      cursor: pointer;
    }
    a.cross-ref:hover { text-decoration-thickness: 0.125em; }

    /* On paper there is nothing to follow, and an underline in a printed document reads as the
       writer's own emphasis, so the two links print without theirs. They keep their colour. */
    @media print {
      a.pers-name, a.cross-ref { text-decoration: none; }
    }

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
       the endnote list is a wall of similar-looking entries. The wash is the palette's
       --color-accent-wash (#1602), under which every text colour keeps 4.5:1; the fallback is
       the light palette's. */
    .fn-list-item {
      scroll-margin-block: 30vh;
    }

    .fn-list-item.fn-arrived {
      animation: fn-arrived-flash 2.4s ease-out;
      border-radius: 4px;
    }

    @keyframes fn-arrived-flash {
      0%   { background-color: var(--color-accent-wash, rgba(120, 170, 255, 0.18)); }
      70%  { background-color: var(--color-accent-wash, rgba(120, 170, 255, 0.18)); }
      100% { background-color: transparent; }
    }

    /* The wash is the affordance; the motion is not. Under Reduce Motion the class still lands
       and still tints, it just does not animate. The SCROLL is gated separately, in the script
       that adds this class — an explicit `behavior` argument overrides `scroll-behavior`, so a
       CSS-only guard here would leave the larger motion running. */
    @media (prefers-reduced-motion: reduce) {
      .fn-list-item.fn-arrived {
        animation: none;
        background-color: var(--color-accent-wash, rgba(120, 170, 255, 0.18));
      }
    }

    .fn-list-item {
      margin-bottom: 0.5em;
      line-height: 1.55;
      /* room for the label, which now hangs in the margin like a printed footnote */
      padding-left: 2.2em;
      text-indent: -2.2em;
    }

    /* #1386: the hang belongs to the ITEM's first line and to nothing inside it. `text-indent`
       is inherited and applies to the first line of every block container — an inline-block is
       one — so each child drew its own first line 2.2em left of its box. The classification chip
       ran its text out past its left border ("Top" outside the capsule in frus1961-63v14/d201),
       and a list inside a note pulled every item's first line into the number column; #1386's
       scan counts 518 notes in 173 volumes that hold one. #985 reset its label alone (below).
       Resetting every direct child stops the inheritance one level down, so a list passes 0 to
       its items. FootnoteListIndentRenderTests measures this in a web view. */
    .fn-list-item > * { text-indent: 0; }

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
    /* #1602: all text inside a highlight is drawn in --color-highlight-text. A link's own colour
       over these tints was as low as 2.00:1, and a link keeps what marks it besides colour: its
       underline, a gloss's dotted rule, a footnote number's raised position. */
    ::highlight(frus-yellow) { background-color: rgba(255, 214,   0, 0.40); color: var(--color-highlight-text); }
    ::highlight(frus-green)  { background-color: rgba(  0, 200,  83, 0.40); color: var(--color-highlight-text); }
    ::highlight(frus-blue)   { background-color: rgba(  0, 122, 255, 0.40); color: var(--color-highlight-text); }
    ::highlight(frus-pink)   { background-color: rgba(255,  45,  85, 0.40); color: var(--color-highlight-text); }
    ::highlight(frus-stale)  { background-color: rgba(255, 149,   0, 0.30); color: var(--color-highlight-text); }
    """
}
