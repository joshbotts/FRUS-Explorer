// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import WebKit

// MARK: - CrossRefDestination

/// Classified destination of a tapped in-document `<ref>` target (Session 162).
///
/// FRUS TEI ref targets come in several flavours that previously all funnelled
/// into "treat the anchor as a document ID":
/// `#d80` · `frus1964-68v20#d104` · `#d100fn2` (footnote of another document) ·
/// `#pg_313` / `frus1955-57v17#pg_313` (printed page) · `http://…`.
enum CrossRefDestination: Equatable {
    /// A FRUS document (footnote-suffixed ids are normalised to the base doc).
    case document(volumeId: String?, documentId: String)
    /// A printed page in a volume; resolve to its containing document via
    /// `PageRangeStore.document(forPage:inVolume:)`.
    case page(volumeId: String?, page: Int)
    /// A non-FRUS absolute URL — open in the browser.
    case external(URL)
    /// Nothing navigable: same-document footnote/figure/table anchors, roman-
    /// numeral page anchors, or an empty target.
    case unresolved
}

// MARK: - FRUSURLSchemeHandler

/// `WKURLSchemeHandler` that dispatches `frusexplorer://` navigations to Swift callbacks.
///
/// `FRUSRenderNodeHTMLSerializer` emits three URL patterns:
///
/// | URL pattern                              | Dispatches to   |
/// |------------------------------------------|-----------------|
/// | `frusexplorer://person/{ref}`            | `onPersonTap`   |
/// | `frusexplorer://gloss/{ref}`             | `onGlossTap`    |
/// | `frusexplorer://doc/{target}[/{vol}]`    | `onCrossRefTap` |
///
/// All three respond with an empty 200-OK so WebKit never surfaces a navigation
/// error. The handler silently ignores any scheme task that arrives after `.cancel`
/// from `decidePolicyFor` (belt-and-suspenders guard).
///
/// ## Person and gloss resolution
/// `onPersonTap` and `onGlossTap` receive the fully resolved `PersonEntry?` /
/// `GlossEntry?` rather than a raw ref string. Call `register(model:)` after each
/// `loadHTMLString` so the internal ref→entry lookup tables are current.  If a ref
/// is not found (e.g. front-matter-only entries), `nil` is passed — callers can
/// choose to ignore it or show a bare-name fallback.
///
/// ## Thread safety
/// All `WKURLSchemeHandler` delegate methods are called on the main thread by
/// WebKit. The class is `@unchecked Sendable` because it is always accessed on the
/// main thread; its properties are never mutated from a background thread.
///
/// ## Session history
///   1.0 — Session 142: initial implementation; replaces `StubFRUSURLSchemeHandler`
///   1.1 — Session 160: dispatch moved into `dispatch(url:)`, called from the
///          navigation delegate's `decidePolicyFor`. `webView(_:start:)` no longer
///          dispatches — cancelling the navigation there suppresses the scheme task
///          on macOS, which is why in-document person/term links never fired.
final class FRUSURLSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {

    // MARK: - Callbacks

    /// Called with the resolved `PersonEntry` (or `nil`) when a persName link is tapped.
    var onPersonTap:   ((PersonEntry?) -> Void)?

    /// Called with the resolved `GlossEntry` (or `nil`) when a gloss link is tapped.
    var onGlossTap:    ((GlossEntry?) -> Void)?

    /// Called with the target document ID and optional source volume ID.
    var onCrossRefTap: ((String, String?) -> Void)?

    /// Called with the broken-ref detail (or `nil`) when an unresolvable `<ref>` is tapped.
    var onBrokenRefTap: ((BrokenRefInfo?) -> Void)?

    // MARK: - Ref lookup tables

    private var personsByRef: [String: PersonEntry] = [:]
    private var glossByRef:   [String: GlossEntry]  = [:]
    /// Broken-ref detail keyed by the verbatim `target` (the value the serializer percent-encodes
    /// into the `brokenref` href, decoded back on dispatch).
    private var brokenByRef:  [String: BrokenRefInfo] = [:]

    // MARK: - Registration

    /// Rebuilds the person and gloss ref→entry lookup tables from the model's
    /// body nodes **and** its footnotes.
    ///
    /// Footnote bodies live in `model.footnotes`, not `model.bodyNodes` — the
    /// converter hoists them out and leaves only markers in the body. Scanning
    /// only the body (the pre–Session 162 behaviour) meant every person and term
    /// link inside a footnote resolved to `nil` and surfaced as "not found",
    /// even though the entries were correctly indexed.
    ///
    /// Call this whenever a new document is loaded (before `loadHTMLString`) so
    /// tapped links can be resolved to their full entry objects.
    func register(model: FRUSDocumentRenderModel) {
        var persons: [String: PersonEntry] = [:]
        var gloss:   [String: GlossEntry]  = [:]
        var broken:  [String: BrokenRefInfo] = [:]
        Self.scan(nodes: model.bodyNodes, persons: &persons, gloss: &gloss, broken: &broken)
        Self.scan(nodes: model.footnotes, persons: &persons, gloss: &gloss, broken: &broken)
        personsByRef = persons
        glossByRef   = gloss
        brokenByRef  = broken

        #if DEBUG
        print("[FRUSURLSchemeHandler] registered model \(model.documentId): "
              + "\(persons.count) persons, \(gloss.count) gloss entries, \(broken.count) broken refs")
        #endif
    }

    // MARK: - Dispatch

    /// Resolves a `frusexplorer://` URL to its `PersonEntry` / `GlossEntry` /
    /// cross-reference target and invokes the matching callback.
    ///
    /// This is called from the navigation delegate
    /// (`_FRUSWebViewCoordinator.webView(_:decidePolicyFor:)`) when an interactive
    /// link is tapped — **not** from `webView(_:start:)`. The navigation delegate
    /// cancels `frusexplorer://` navigations so the scheme handler's empty response
    /// can never replace the document, but cancelling also prevents
    /// `webView(_:start:)` from running (notably on macOS). Dispatching here, in a
    /// single place, keeps person/gloss/cross-ref taps working deterministically on
    /// both platforms without any double dispatch.
    @MainActor
    func dispatch(url: URL) {
        // Path components with leading "/" filtered out; values are percent-decoded.
        let parts = url.pathComponents
            .filter { $0 != "/" }
            .map { $0.removingPercentEncoding ?? $0 }

        switch url.host {

        case "person":
            let ref = parts.first ?? ""
            onPersonTap?(personsByRef[ref])

        case "gloss":
            let ref = parts.first ?? ""
            onGlossTap?(glossByRef[ref])

        case "doc":
            // URL: frusexplorer://doc/{target}  or  frusexplorer://doc/{target}/{volumeId}
            guard let target = parts.first else { return }
            let volumeId: String? = parts.count >= 2 ? parts[1] : nil
            onCrossRefTap?(target, volumeId)

        case "brokenref":
            // URL: frusexplorer://brokenref/{target}[/{volumeId}] — a dead cross-reference.
            // Never navigates; presents the explanation sheet with the registered detail.
            guard let target = parts.first else { return }
            onBrokenRefTap?(brokenByRef[target])

        default:
            break
        }
    }

    // MARK: - Target resolution

    /// Splits a raw TEI ref target into a navigable destination, normalising the
    /// quirks found across the corpus (Session 162 link audit):
    ///
    /// - `vol#anchor` prefixes override `volumeId`; bare `#anchor` keeps it.
    /// - `dNNNfnM` footnote-suffixed ids resolve to the base document `dNNN`.
    /// - `pg_313` / `pg313` / `page313` anchors resolve to a page number;
    ///   roman-numeral pages (`pg_XIII`, front matter) are `.unresolved`.
    /// - Bare `fn…`/`note…`/`fig…`/`tbl…` anchors point within the current
    ///   document and are `.unresolved` (footnote popovers already cover them).
    /// - Absolute `http(s)` URLs are `.external`.
    ///
    /// `nonisolated`: a pure string transformation, callable from any context
    /// (the default-MainActor inference otherwise traps when tests call it off
    /// the main actor).
    nonisolated static func resolveCrossRefTarget(
        _ rawTarget: String,
        volumeId: String?
    ) -> CrossRefDestination {
        let target = rawTarget.trimmingCharacters(in: .whitespaces)
        if target.hasPrefix("http://") || target.hasPrefix("https://") {
            return URL(string: target).map { .external($0) } ?? .unresolved
        }

        var vol = volumeId
        var anchor = target
        if let hash = target.firstIndex(of: "#") {
            let prefix = String(target[..<hash])
            if !prefix.isEmpty { vol = prefix }
            anchor = String(target[target.index(after: hash)...])
        }
        guard !anchor.isEmpty else { return .unresolved }

        let lower = anchor.lowercased()
        if lower.hasPrefix("pg") || lower.hasPrefix("page") {
            let digits = anchor.drop { !$0.isNumber }
            if !digits.isEmpty, digits.allSatisfy(\.isNumber), let page = Int(digits) {
                return .page(volumeId: vol, page: page)
            }
            return .unresolved
        }
        if lower.hasPrefix("fn") || lower.hasPrefix("note")
            || lower.hasPrefix("fig") || lower.hasPrefix("tbl") {
            return .unresolved
        }
        if let match = anchor.wholeMatch(of: /(d\d+[A-Za-z]?)fn\d+/) {
            return .document(volumeId: vol, documentId: String(match.1))
        }
        return .document(volumeId: vol, documentId: anchor)
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        // Respond with an empty 200 so WebKit never reports a load error if it ever
        // does start this task. The actual tap dispatch happens in the navigation
        // delegate's decidePolicyFor (see `dispatch(url:)`), because cancelling the
        // navigation there prevents this method from running on macOS.
        respond(to: urlSchemeTask)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    // MARK: - Private helpers

    private func respond(to task: any WKURLSchemeTask) {
        let url = task.request.url ?? URL(string: "frusexplorer://noop")!
        let response = URLResponse(
            url: url,
            mimeType: "text/plain",
            expectedContentLength: 0,
            textEncodingName: nil
        )
        task.didReceive(response)
        task.didReceive(Data())
        task.didFinish()
    }

    /// DFS scan of `nodes` that collects `persNameLink` and `glossLink` entries
    /// into the supplied dictionaries. Ref strings have their leading `#` stripped
    /// to match the URL-encoded form produced by `FRUSRenderNodeHTMLSerializer`.
    private static func scan(
        nodes: [FRUSRenderNode],
        persons: inout [String: PersonEntry],
        gloss: inout [String: GlossEntry],
        broken: inout [String: BrokenRefInfo]
    ) {
        for node in nodes {
            switch node {

            case .persNameLink(let ref, let children, let person):
                if let r = ref, let p = person {
                    let key = r.hasPrefix("#") ? String(r.dropFirst()) : r
                    persons[key] = p
                }
                scan(nodes: children, persons: &persons, gloss: &gloss, broken: &broken)

            case .glossLink(let ref, let children, let entry):
                if let r = ref, let e = entry {
                    let key = r.hasPrefix("#") ? String(r.dropFirst()) : r
                    gloss[key] = e
                }
                scan(nodes: children, persons: &persons, gloss: &gloss, broken: &broken)

            // Container nodes — recurse into children
            case .heading(let cs), .dateline(let cs), .paragraph(let cs),
                 .letterOpener(let cs), .letterCloser(let cs), .salutation(let cs),
                 .boldText(let cs), .italicText(let cs), .smallCapsText(let cs),
                 .underlineText(let cs), .termText(let cs), .suppliedText(let cs),
                 .sicText(let cs), .corrText(let cs), .editorialNoteBlock(let cs),
                 .titlePageBlock(let cs), .attachmentHeading(let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss, broken: &broken)

            case .crossRefLink(_, _, let brokenInfo, let cs):
                if let brokenInfo { broken[brokenInfo.target] = brokenInfo }
                scan(nodes: cs, persons: &persons, gloss: &gloss, broken: &broken)

            case .attachmentBlock(_, let cs), .unknown(_, let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss, broken: &broken)

            case .footnoteBody(_, _, _, _, _, let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss, broken: &broken)

            case .tableBlock(let rows):
                for row in rows {
                    for cell in row {
                        scan(nodes: cell.children, persons: &persons, gloss: &gloss, broken: &broken)
                    }
                }

            case .listBlock(_, let items):
                for item in items {
                    scan(nodes: item, persons: &persons, gloss: &gloss, broken: &broken)
                }

            default:
                // Leaf nodes: plainText, formulaText, lineBreak, pageBreak,
                // footnoteMarker, figureBlock — no refs to collect.
                break
            }
        }
    }
}
