// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import WebKit

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
final class FRUSURLSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {

    // MARK: - Callbacks

    /// Called with the resolved `PersonEntry` (or `nil`) when a persName link is tapped.
    var onPersonTap:   ((PersonEntry?) -> Void)?

    /// Called with the resolved `GlossEntry` (or `nil`) when a gloss link is tapped.
    var onGlossTap:    ((GlossEntry?) -> Void)?

    /// Called with the target document ID and optional source volume ID.
    var onCrossRefTap: ((String, String?) -> Void)?

    // MARK: - Ref lookup tables

    private var personsByRef: [String: PersonEntry] = [:]
    private var glossByRef:   [String: GlossEntry]  = [:]

    // MARK: - Registration

    /// Rebuilds the person and gloss ref→entry lookup tables from `model.bodyNodes`.
    ///
    /// Call this whenever a new document is loaded (before `loadHTMLString`) so
    /// tapped links can be resolved to their full entry objects.
    func register(model: FRUSDocumentRenderModel) {
        var persons: [String: PersonEntry] = [:]
        var gloss:   [String: GlossEntry]  = [:]
        Self.scan(nodes: model.bodyNodes, persons: &persons, gloss: &gloss)
        personsByRef = persons
        glossByRef   = gloss

        #if DEBUG
        print("[FRUSURLSchemeHandler] registered model \(model.documentId): "
              + "\(persons.count) persons, \(gloss.count) gloss entries")
        #endif
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        // Always respond so WebKit does not report a load error.
        defer { respond(to: urlSchemeTask) }

        guard let url = urlSchemeTask.request.url else { return }

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

        default:
            break
        }
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
        gloss: inout [String: GlossEntry]
    ) {
        for node in nodes {
            switch node {

            case .persNameLink(let ref, let children, let person):
                if let r = ref, let p = person {
                    let key = r.hasPrefix("#") ? String(r.dropFirst()) : r
                    persons[key] = p
                }
                scan(nodes: children, persons: &persons, gloss: &gloss)

            case .glossLink(let ref, let children, let entry):
                if let r = ref, let e = entry {
                    let key = r.hasPrefix("#") ? String(r.dropFirst()) : r
                    gloss[key] = e
                }
                scan(nodes: children, persons: &persons, gloss: &gloss)

            // Container nodes — recurse into children
            case .heading(let cs), .dateline(let cs), .paragraph(let cs),
                 .letterOpener(let cs), .letterCloser(let cs), .salutation(let cs),
                 .boldText(let cs), .italicText(let cs), .smallCapsText(let cs),
                 .underlineText(let cs), .termText(let cs), .suppliedText(let cs),
                 .sicText(let cs), .corrText(let cs), .editorialNoteBlock(let cs),
                 .titlePageBlock(let cs), .attachmentHeading(let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss)

            case .crossRefLink(_, _, let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss)

            case .attachmentBlock(_, let cs), .unknown(_, let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss)

            case .footnoteBody(_, _, _, _, _, let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss)

            case .tableBlock(let rows):
                for row in rows {
                    for cell in row {
                        scan(nodes: cell.children, persons: &persons, gloss: &gloss)
                    }
                }

            case .listBlock(_, let items):
                for item in items {
                    scan(nodes: item, persons: &persons, gloss: &gloss)
                }

            default:
                // Leaf nodes: plainText, formulaText, lineBreak, pageBreak,
                // footnoteMarker, figureBlock — no refs to collect.
                break
            }
        }
    }
}
