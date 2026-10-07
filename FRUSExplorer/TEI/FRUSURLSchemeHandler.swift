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
/// | `frusexplorer://doc/{target}[/{vol}][?no=…&day=…]` | `onCrossRefTap` |
///
/// All three respond with an empty 200-OK so WebKit never surfaces a navigation
/// error. The handler silently ignores any scheme task that arrives after `.cancel`
/// from `decidePolicyFor` (belt-and-suspenders guard).
///
/// A fourth pattern is not a link but an image the page loads (#1516):
/// `frusexplorer://figure/{volumeId}/{fileName}` is answered with the figure image's bytes from
/// the device's figure store (`FigureImageStore`), or with a failure when it is not there.
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
///   1.2 — #1509: `onCrossRefTap` also receives what a page link's footnote names
///          (`PageCitationHint`), read back from the link's query.
///   1.3 — #1516: `frusexplorer://figure/…` requests are answered with the figure's image, and
///          the links in a figure's head and captions are registered.
///   1.4 — #1516 review, round 1: an image fetched after the page asked for it brings a revealed
///          footnote back into view once it has loaded (`figureRetryScript`).
///   1.5 — FRUSCoreKit, part 1: `CrossRefDestination`, `resolveCrossRefTarget`, `figureHost` and
///          `figureURL(for:)` moved to FRUSCoreKit's `FRUSURLScheme`, and the handler forwards to
///          it under the old names
///   1.6 — Session 2026-10-06 (FRUS Explorer Light, S9b): `dispatch(url:)` reads each link with
///          the kit's `FRUSURLScheme.readerLink(from:)`, its parse moved there verbatim; the lookups
///          and the callbacks stay here
final class FRUSURLSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {

    // MARK: - Callbacks

    /// Called with the resolved `PersonEntry` (or `nil`) when a persName link is tapped.
    var onPersonTap:   ((PersonEntry?) -> Void)?

    /// Called with the resolved `GlossEntry` (or `nil`) when a gloss link is tapped.
    var onGlossTap:    ((GlossEntry?) -> Void)?

    /// Called with the target document ID, the optional source volume ID and, for a page link inside
    /// a footnote, what the footnote names (#1509) — read back from the link's query.
    var onCrossRefTap: ((String, String?, PageCitationHint?) -> Void)?

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
    ///
    /// The link is read by the kit's `FRUSURLScheme.readerLink(from:)` (FRUSCoreKit), which says
    /// how each link's path is decoded. The navigation delegate passes only `frusexplorer` URLs;
    /// anything the kit does not read as a link is ignored.
    @MainActor
    func dispatch(url: URL) {
        switch FRUSURLScheme.readerLink(from: url) {

        case .person(let ref):
            onPersonTap?(personsByRef[ref])

        case .gloss(let ref):
            onGlossTap?(glossByRef[ref])

        case .crossReference(let target, let volumeId, let citing):
            // frusexplorer://doc/{target}[/{volumeId}], and for a page link in a footnote a query
            // naming what the footnote names (#1509).
            onCrossRefTap?(target, volumeId, citing)

        case .brokenReference(let target):
            // A dead cross-reference. Never navigates; presents the explanation sheet with the
            // registered detail, keyed by the verbatim target.
            onBrokenRefTap?(brokenByRef[target])

        case nil:
            break
        }
    }

    // MARK: - Target resolution

    /// The kit's `FRUSURLScheme.resolveCrossRefTarget(_:volumeId:)` (FRUSCoreKit), under the name
    /// the reader's hosts and the index call it by. The grammar and its corpus notes live there.
    nonisolated static func resolveCrossRefTarget(
        _ rawTarget: String,
        volumeId: String?
    ) -> CrossRefDestination {
        FRUSURLScheme.resolveCrossRefTarget(rawTarget, volumeId: volumeId)
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        // #1516: a figure's image is a subresource of the page, not a navigation, so it does
        // start here — and is answered with the image's bytes, or with a failure.
        if let url = urlSchemeTask.request.url, url.host == Self.figureHost {
            respondWithFigure(at: url, to: urlSchemeTask, in: webView)
            return
        }
        // Respond with an empty 200 so WebKit never reports a load error if it ever
        // does start this task. The actual tap dispatch happens in the navigation
        // delegate's decidePolicyFor (see `dispatch(url:)`), because cancelling the
        // navigation there prevents this method from running on macOS.
        respond(to: urlSchemeTask)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    // MARK: - Figure images (#1516)

    /// The host of a figure image's URL: `frusexplorer://figure/{volumeId}/{fileName}`
    /// (`FRUSURLScheme.figureHost`, FRUSCoreKit).
    nonisolated static let figureHost = FRUSURLScheme.figureHost

    /// Where the reader's figure images come from. The app's store by default; a test sets its own.
    var figureImages: FigureImageStore = .shared

    /// The URL the reader's page names `image` by: the kit's `FRUSURLScheme.figureURL(for:)`
    /// (FRUSCoreKit), which the serializer calls.
    nonisolated static func figureURL(for image: FigureImageName) -> URL? {
        FRUSURLScheme.figureURL(for: image)
    }

    /// The volume and file name a figure URL names, or `nil` when `url` is not one. The query is
    /// ignored: a retry adds one so the page asks again.
    nonisolated static func figureImage(from url: URL) -> (volumeId: String, fileName: String)? {
        guard url.scheme == "frusexplorer", url.host == figureHost else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2,
              FigureImageLibrary.isSafeComponent(parts[0]),
              FigureImageLibrary.isSafeComponent(parts[1]) else { return nil }
        return (parts[0], parts[1])
    }

    /// The page's global holding the `id` of the footnote entry the reader was last brought to
    /// (`_FRUSWebViewCoordinator.revealFootnote`), or `null` once the reader has scrolled, tapped
    /// or typed for themselves. ``figureRetryScript(for:)`` reads it.
    nonisolated static let revealedFootnoteGlobal = "FRUSRevealedFootnote"

    /// The script that makes the page ask again for the image at `url`, once it has been fetched:
    /// every `<img>` naming it drops its figure's `missing` mark and reloads.
    ///
    /// An image that arrives this way is laid out after the page was, and pushes everything
    /// below it down by its height — a map's, where the placeholder was one line. If the reader
    /// was brought to a footnote (#988) and has not moved since, the footnote is brought back
    /// into view when the image has loaded: the reveal's own scroll ran before the image had a
    /// size, and its `scroll-margin-block` is no match for a map.
    nonisolated static func figureRetryScript(for url: URL) -> String {
        var base = URLComponents(url: url, resolvingAgainstBaseURL: false)
        base?.query = nil
        let address = base?.url?.absoluteString ?? url.absoluteString
        let literal = (try? JSONEncoder().encode(address)).map { String(decoding: $0, as: UTF8.self) } ?? "\"\""
        return "(function(){var u=\(literal);"
            + "document.querySelectorAll('img.figure-image').forEach(function(i){"
            + "if(i.getAttribute('src').split('?')[0]===u){"
            + "i.addEventListener('load',function(){"
            + "var id=window.\(revealedFootnoteGlobal);var li=id&&document.getElementById(id);"
            + "if(li){li.scrollIntoView({block:'center',behavior:'auto'});}},{once:true});"
            + "i.parentNode.classList.remove('missing');i.src=u+'?retry=1';}});return true;})()"
    }

    /// Answers a figure image's request: with its bytes when it is on the device, and otherwise
    /// with a failure — so the page shows the placeholder at once — while the image is fetched;
    /// when that fetch succeeds, the page is told to ask again.
    ///
    /// The request is never held open for the network: the page's `load` event waits for its
    /// images, and the reader paints highlights and reveals a footnote on it.
    private func respondWithFigure(at url: URL, to task: any WKURLSchemeTask, in webView: WKWebView) {
        guard let (volumeId, fileName) = Self.figureImage(from: url) else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        let store = figureImages
        if let data = store.data(volumeId: volumeId, fileName: fileName) {
            task.didReceive(URLResponse(url: url, mimeType: "image/png",
                                        expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data)
            task.didFinish()
            return
        }
        task.didFailWithError(URLError(.fileDoesNotExist))
        // Only the first request for an image fetches it: the retry's own request, should the
        // file have vanished again, must not start a loop.
        guard url.query == nil else { return }
        let script = Self.figureRetryScript(for: url)
        Task { @MainActor [weak webView] in
            guard await store.fetchIfAbsent(volumeId: volumeId, fileName: fileName) else { return }
            _ = try? await webView?.evaluateJavaScript(script)
        }
    }

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

            case .crossRefLink(_, _, let brokenInfo, _, let cs):
                if let brokenInfo { broken[brokenInfo.target] = brokenInfo }
                scan(nodes: cs, persons: &persons, gloss: &gloss, broken: &broken)

            case .attachmentBlock(_, let cs), .unknown(_, let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss, broken: &broken)

            case .footnoteBody(_, _, _, _, _, let cs):
                scan(nodes: cs, persons: &persons, gloss: &gloss, broken: &broken)

            case .tableBlock(let caption, let rows):
                // #1495: a table's caption carries links too — 41 terms and 1 person are linked in
                // captions outside their notes — and a link the reader draws must resolve when tapped.
                scan(nodes: caption ?? [], persons: &persons, gloss: &gloss, broken: &broken)
                for row in rows {
                    for cell in row {
                        scan(nodes: cell.children, persons: &persons, gloss: &gloss, broken: &broken)
                    }
                }

            case .listBlock(_, let heading, let items, let trailing):
                // #1371: a list's heading and labels carry links too — 1,946 glosses sit in list
                // heads — and a link the reader draws must resolve when it is tapped.
                scan(nodes: heading ?? [], persons: &persons, gloss: &gloss, broken: &broken)
                for item in items {
                    scan(nodes: Self.nodes(in: item.lead), persons: &persons, gloss: &gloss, broken: &broken)
                    scan(nodes: item.children, persons: &persons, gloss: &gloss, broken: &broken)
                }
                scan(nodes: Self.nodes(in: trailing), persons: &persons, gloss: &gloss, broken: &broken)

            case .figureBlock(let figure):
                // #1516: a figure's head and captions carry links too — `frus1951v03p1` d289
                // captions each photograph with a linked name — and a link the reader draws must
                // resolve when it is tapped.
                scan(nodes: figure.head ?? [], persons: &persons, gloss: &gloss, broken: &broken)
                for caption in figure.captions {
                    scan(nodes: caption, persons: &persons, gloss: &gloss, broken: &broken)
                }

            default:
                // Leaf nodes: plainText, formulaText, lineBreak, pageBreak,
                // footnoteMarker, elementSpace — no refs to collect.
                break
            }
        }
    }

    /// The render nodes a list's labels and other non-item children hold, in order (#1371).
    private static func nodes(in lead: [ListLead]) -> [FRUSRenderNode] {
        lead.flatMap { part -> [FRUSRenderNode] in
            switch part {
            case .label(let children), .other(let children): return children
            }
        }
    }
}
