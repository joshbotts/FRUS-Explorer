// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CrossRefDestination

/// Classified destination of a tapped in-document `<ref>` target (Session 162).
///
/// FRUS TEI ref targets come in several flavours that previously all funnelled
/// into "treat the anchor as a document ID":
/// `#d80` · `frus1964-68v20#d104` · `#d100fn2` (footnote of another document) ·
/// `#pg_313` / `frus1955-57v17#pg_313` (printed page) · `http://…`.
public enum CrossRefDestination: Equatable, Sendable {
    /// A FRUS document.
    case document(volumeId: String?, documentId: String)
    /// A specific footnote inside a FRUS document (#988). `anchor` is the note's TEI `xml:id`
    /// (`d748fn3`); `documentId` is the document containing it. Navigate to the document, then
    /// reveal the note — see `DocumentBrowserEntry.footnoteAnchor`.
    case footnote(volumeId: String?, documentId: String, anchor: String)
    /// A printed page in a volume; resolve to the document that begins on it (#1503) via
    /// `PageRangeStore.document(forPage:inVolume:)`.
    case page(volumeId: String?, page: Int)
    /// A non-FRUS absolute URL — open in the browser.
    case external(URL)
    /// Nothing navigable: same-document footnote/figure/table anchors, roman-
    /// numeral page anchors, or an empty target.
    case unresolved
}

// MARK: - ReaderLink

/// What a link in the reader's page names: one of the four `frusexplorer://` links
/// `FRUSRenderNodeHTMLSerializer` writes, read back by ``FRUSURLScheme/readerLink(from:)``.
public enum ReaderLink: Equatable, Sendable {
    /// `frusexplorer://person/{ref}`: a person's `ref` as the render node carries it, without a
    /// leading `#` (`p_HK1`, or a split set's `frus1918Supp01v01#p_LR1`). The app looks it up among
    /// the document's persons, and says the person was not found when none has it.
    case person(ref: String)
    /// `frusexplorer://gloss/{ref}`: a glossary term's `ref`, without a leading `#` (`t_USSR1`).
    case gloss(ref: String)
    /// `frusexplorer://doc/{target}[/{volumeId}][?no=…&day=…]`: a `<ref>`'s verbatim `target`
    /// (`#d1`, `frus1961-63v14#pg_387`, `#d16fn2`, an `http(s)` or `mailto:` address, or a
    /// figure's video page), the `volumeId` its render node carries (the volume the target names
    /// before its `#`), and what the footnote around a page link names (#1509), or `nil` when the
    /// query names nothing. ``FRUSURLScheme/resolveCrossRefTarget(_:volumeId:)`` says where it goes.
    case crossReference(target: String, volumeId: String?, citing: PageCitationHint?)
    /// `frusexplorer://brokenref/{target}`: a dead cross-reference's verbatim `target` (#240), the
    /// key its `BrokenRefInfo` is registered under. It never navigates.
    case brokenReference(target: String)
}

// MARK: - FRUSURLScheme

/// The grammar of the reader's `frusexplorer://` links that the render pipeline writes and reads:
/// what each link names, what a TEI `<ref target>` points at, and the address of a figure's image.
/// Pure string work, so it lives in FRUSCoreKit; `FRUSURLSchemeHandler`, the WebKit side, and
/// `FigureImageLibrary` forward to it under their old names.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: moved from `FRUSURLSchemeHandler` (`resolveCrossRefTarget`,
///          `figureHost`, `figureURL(for:)`) and `FigureImageLibrary` (`isSafeComponent`).
///          `CrossRefDestination`, this type and `resolveCrossRefTarget` are public, for FRUS
///          Explorer Light's reader
///   1.1 — Session 2026-10-05 (FRUS Explorer Light, S8a): `figureHost`, `figureURL(for:)` and
///          `isSafeComponent(_:)` are public, for its figure route
///   1.2 — Session 2026-10-06 (FRUS Explorer Light, S9b): `readerLink(from:)` and `ReaderLink`, the
///          parse of the reader's links that `FRUSURLSchemeHandler.dispatch(url:)` did in the app,
///          moved here verbatim, so a host outside the app reads each link as the app does
public enum FRUSURLScheme {

    /// What `url` names when it is a link in the reader's page, or `nil` when it is not one: a
    /// scheme other than `frusexplorer`, a host other than `person`, `gloss`, `doc` and `brokenref`
    /// (a `figure` URL is an image the page loads, not a link), or a `doc` or `brokenref` link with
    /// no path. A `person` or `gloss` link with no path names the empty ref, which no entry has, so
    /// the app answers it as a person or term not found, as it always has.
    ///
    /// **Decoding, exactly as the app's handler has always done it.** Foundation's `pathComponents`
    /// percent-decodes each path component once. A `person`, `gloss` or `doc` component is then
    /// decoded a second time (`removingPercentEncoding`, keeping the once-decoded value where that
    /// fails), so `%2541` reads as `A`. The serializer encodes those once, so only a ref or target
    /// that itself holds a `%` escape reads back other than as it was written. A `brokenref`
    /// component is decoded once only: the serializer encodes its target with `.alphanumerics`, and
    /// the verbatim target, `%` included, is the key its detail is registered under.
    ///
    /// A `doc` link's second component is the volume; any further one is ignored. Its query's `no`
    /// and `day` items are read by `PageCitationHint(queryItems:)`, which is `nil` when they name
    /// nothing.
    ///
    /// `nonisolated`: a pure string transformation, callable from any context.
    public nonisolated static func readerLink(from url: URL) -> ReaderLink? {
        guard url.scheme == "frusexplorer" else { return nil }
        // Decoded once, by Foundation, with the leading "/" dropped.
        let components = url.pathComponents.filter { $0 != "/" }
        // Decoded twice, as the person, gloss and doc links have always been read.
        let parts = components.map { $0.removingPercentEncoding ?? $0 }
        switch url.host {
        case "person":
            return .person(ref: parts.first ?? "")
        case "gloss":
            return .gloss(ref: parts.first ?? "")
        case "doc":
            guard let target = parts.first else { return nil }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return .crossReference(target: target, volumeId: parts.count >= 2 ? parts[1] : nil,
                                   citing: PageCitationHint(queryItems: query))
        case "brokenref":
            guard let target = components.first else { return nil }
            return .brokenReference(target: target)
        default:
            return nil
        }
    }

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
    public nonisolated static func resolveCrossRefTarget(
        _ rawTarget: String,
        volumeId: String?
    ) -> CrossRefDestination {
        let target = rawTarget.trimmingCharacters(in: .whitespaces)
        // `mailto:` alongside http(s): the corpus carries 16 of them (e.g. the front matter's
        // "mailto:history@state.gov"). Without this they fell through to the document branch and
        // were looked up as a document id, so the contact link did nothing at all.
        if target.hasPrefix("http://") || target.hasPrefix("https://")
            || target.hasPrefix("mailto:") {
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
        // #988: a footnote anchor names the note, not just its document. 16,921 corpus references
        // target a note's xml:id and 90.8% of them point into a DIFFERENT document, so dropping
        // the suffix landed the reader at the head of a document they had not been reading with no
        // indication which note was meant.
        //
        // The prefix is widened from the old `d\d+[A-Za-z]?` to `.*d\d+[A-Za-z]?`, and the suffix
        // from `fn\d+` to `fn[\w-]*`, because 33 corpus references carry a section-prefixed or
        // symbol-suffixed note id — `cr_d6fn4`, `es_d2fn1`, `ni_d4fn4`, `d705fn-sym1`. Those missed
        // the old pattern, fell through to the bare `.document(documentId: anchor)` below, and made
        // the app try to open a document named after a footnote. Measured: the widened rule routes
        // all 33 to a document id that exists in the same volume (`cr_d6`, `d705`, …).
        //
        // Anchored on `d\d+` rather than on any `fn` so a document id that merely contains "fn"
        // cannot be split — measured over every document `xml:id` in the shippable corpus, this
        // pattern captures 0 of 314,571.
        if let match = anchor.wholeMatch(of: /(.*d\d+[A-Za-z]?)fn[\w-]*/) {
            return .footnote(volumeId: vol, documentId: String(match.1), anchor: anchor)
        }
        return .document(volumeId: vol, documentId: anchor)
    }

    /// The host of a figure image's URL: `frusexplorer://figure/{volumeId}/{fileName}`.
    nonisolated public static let figureHost = "figure"

    /// The URL the reader's page names `image` by, or `nil` when its volume is unknown or its
    /// name is no file name — in which case the page prints the placeholder.
    nonisolated public static func figureURL(for image: FigureImageName) -> URL? {
        guard let volumeId = image.volumeId, let fileName = image.fileName,
              isSafeComponent(volumeId) else { return nil }
        var components = URLComponents()
        components.scheme = "frusexplorer"
        components.host = figureHost
        components.path = "/\(volumeId)/\(fileName)"
        return components.url
    }

    /// Whether `component` can be one path component: a volume id or an image's file name. A
    /// value holding a separator, or naming the folder itself or its parent, is refused, so
    /// neither a volume's markup nor a `frusexplorer://figure/` URL can reach outside the folder.
    nonisolated public static func isSafeComponent(_ component: String) -> Bool {
        !component.isEmpty && component != "." && component != ".."
            && !component.contains("/") && !component.contains("\\") && !component.contains("\0")
    }
}
