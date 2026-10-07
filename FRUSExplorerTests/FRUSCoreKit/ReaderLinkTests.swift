// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - ReaderLinkTests

/// The reader's `frusexplorer://` links read back by the kit (`FRUSURLScheme.readerLink(from:)`),
/// as the app's `FRUSURLSchemeHandler.dispatch(url:)` has always read them, so FRUS Explorer Light
/// follows every link the serializer writes with the app's own parse.
///
/// Version history:
///   1.0 — Session 2026-10-06 (FRUS Explorer Light, S9b): initial implementation
@Suite("FRUSCoreKit — the reader's links read back")
struct ReaderLinkTests {

    /// A page link's hint: the document numbers and the days (month, day, year) its footnote names.
    private static func hint(_ numbers: [String], _ days: [(Int, Int, Int?)] = []) -> PageCitationHint {
        PageCitationHint(documentNumbers: numbers, days: days.map { .init(month: $0.0, day: $0.1, year: $0.2) })
    }

    /// The figure video's page, in `FigureFixtures.appendix1`'s volume.
    private static let videoPage = "https://history.state.gov/historicaldocuments/frus1917-72PubDipv06/appendix-1"

    /// Hrefs as the serializer writes them (a query's `&amp;` is the page's markup; the URL has
    /// `&`), with what each names. The person, gloss and doc hrefs encode with `.urlPathAllowed`
    /// (a doc component with `/` and `:` too), the brokenref hrefs with `.alphanumerics`.
    static let table: [(href: String, link: ReaderLink?)] = [
        ("frusexplorer://person/p_HK1", .person(ref: "p_HK1")),
        // A split set's person: its ref names the volume that lists it.
        ("frusexplorer://person/frus1918Supp01v01%23p_LR1", .person(ref: "frus1918Supp01v01#p_LR1")),
        ("frusexplorer://gloss/t_USSR1", .gloss(ref: "t_USSR1")),
        ("frusexplorer://doc/%23d1", .crossReference(target: "#d1", volumeId: nil, citing: nil)),
        ("frusexplorer://doc/d42/frus1969-76v02",
         .crossReference(target: "d42", volumeId: "frus1969-76v02", citing: nil)),
        ("frusexplorer://doc/%23d16fn2", .crossReference(target: "#d16fn2", volumeId: nil, citing: nil)),
        ("frusexplorer://doc/frus1961-63v14%23pg_387/frus1961-63v14?day=8-17-1888",
         .crossReference(target: "frus1961-63v14#pg_387", volumeId: "frus1961-63v14",
                         citing: hint([], [(8, 17, 1888)]))),
        ("frusexplorer://doc/%23pg_683?no=497&day=8-17-1888",
         .crossReference(target: "#pg_683", volumeId: nil, citing: hint(["497"], [(8, 17, 1888)]))),
        // A query that names nothing is no hint: nil, as `PageCitationHint(queryItems:)` returns.
        ("frusexplorer://doc/%23pg_683?retry=1", .crossReference(target: "#pg_683", volumeId: nil, citing: nil)),
        ("frusexplorer://doc/%23pg_683?no=&day=13", .crossReference(target: "#pg_683", volumeId: nil, citing: nil)),
        // An external target, and a figure's video page: one component, its '/' and ':' encoded.
        ("frusexplorer://doc/http%3A%2F%2Fwould.be", .crossReference(target: "http://would.be", volumeId: nil, citing: nil)),
        ("frusexplorer://doc/mailto%3Ahistory@state.gov",
         .crossReference(target: "mailto:history@state.gov", volumeId: nil, citing: nil)),
        ("frusexplorer://doc/https%3A%2F%2Fhistory.state.gov%2Fhistoricaldocuments%2Ffrus1917-72PubDipv06%2Fappendix-1",
         .crossReference(target: videoPage, volumeId: nil, citing: nil)),
        // A third component is ignored, as dispatch ignored it.
        ("frusexplorer://doc/d42/frus1969-76v02/d43",
         .crossReference(target: "d42", volumeId: "frus1969-76v02", citing: nil)),
        // A dead reference: `.alphanumerics` encodes '#' and '_' alike; both spellings read the same.
        ("frusexplorer://brokenref/%23pg%5F700", .brokenReference(target: "#pg_700")),
        ("frusexplorer://brokenref/%23pg_700", .brokenReference(target: "#pg_700")),
        ("frusexplorer://brokenref/frus1877%23pg%5F1077", .brokenReference(target: "frus1877#pg_1077")),
        // `%25` in a ref: a person, gloss or doc component is decoded twice, a brokenref once.
        ("frusexplorer://person/p%2541", .person(ref: "pA")),
        ("frusexplorer://gloss/t%25", .gloss(ref: "t%")),
        ("frusexplorer://doc/%2523d1", .crossReference(target: "#d1", volumeId: nil, citing: nil)),
        ("frusexplorer://brokenref/p%2541", .brokenReference(target: "p%41")),
        // No path: a person or gloss link names the empty ref; a doc or brokenref link names nothing.
        ("frusexplorer://person/", .person(ref: "")),
        ("frusexplorer://gloss", .gloss(ref: "")),
        ("frusexplorer://doc/", nil),
        ("frusexplorer://doc?no=497", nil),
        ("frusexplorer://brokenref/", nil),
        // Not a link: a figure's image, an unknown host, another scheme.
        ("frusexplorer://figure/frus1946v01/figure_1162.png", nil),
        ("frusexplorer://noop", nil),
        ("frusexplorer://volume/frus1969-76v02", nil),
        ("https://history.state.gov/historicaldocuments/frus1969-76v02/d42", nil),
        ("http://person/p_HK1", nil),
    ]

    @Test("Each href the serializer writes names the link the app's handler has always read from it, and anything else names none")
    func eachHrefNamesItsLink() throws {
        for (href, expected) in Self.table {
            let url = try #require(URL(string: href), "\(href) is not a URL")
            #expect(FRUSURLScheme.readerLink(from: url) == expected, "\(href)")
        }
    }

    // MARK: - Round trip

    /// The page's markup for `nodes`, written by the reader's serializer.
    private func page(_ nodes: [FRUSRenderNode]) -> String {
        FRUSRenderNodeHTMLSerializer.reader.serialize(
            FRUSDocumentRenderModel(documentId: "d1", bodyNodes: nodes, footnotes: []))
    }

    /// Every `frusexplorer://` href in `html`, its markup unescaped, as a URL, in order. A figure's
    /// image (`frusexplorer://figure/…`) is a `src`, not an `href`, and is not among them.
    private func links(in html: String) throws -> [URL] {
        try html.matches(of: /href="(frusexplorer:\/\/[^"]+)"/).map { match in
            let href = String(match.1)
                .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&amp;", with: "&")
            return try #require(URL(string: href), "\(href) is not a URL")
        }
    }

    @Test("Every link the reader's serializer writes reads back to the ref or target it was written from")
    func linksReadBackToWhatWasWritten() throws {
        let page683 = Self.hint(["497"], [(8, 17, 1888)])
        let dead = { (target: String) in
            BrokenRefInfo(target: target, reason: "unknownPage", resolvedVolume: nil, resolvedAnchor: nil)
        }
        let text: [FRUSRenderNode] = [.plainText("link")]
        let cases: [(node: FRUSRenderNode, link: ReaderLink)] = [
            (.persNameLink(ref: "#p_HK1", children: text, person: nil), .person(ref: "p_HK1")),
            (.persNameLink(ref: "p_HK1", children: text, person: nil), .person(ref: "p_HK1")),
            (.persNameLink(ref: "frus1918Supp01v01#p_LR1", children: text, person: nil),
             .person(ref: "frus1918Supp01v01#p_LR1")),
            (.glossLink(ref: "#t_USSR1", children: text, entry: nil), .gloss(ref: "t_USSR1")),
            (.crossRefLink(target: "#d1", volumeId: nil, broken: nil, children: text),
             .crossReference(target: "#d1", volumeId: nil, citing: nil)),
            (.crossRefLink(target: "frus1969-76v02#d42", volumeId: "frus1969-76v02", broken: nil, children: text),
             .crossReference(target: "frus1969-76v02#d42", volumeId: "frus1969-76v02", citing: nil)),
            (.crossRefLink(target: "#d16fn2", volumeId: nil, broken: nil, children: text),
             .crossReference(target: "#d16fn2", volumeId: nil, citing: nil)),
            (.crossRefLink(target: "#pg_683", volumeId: nil, broken: nil, citing: page683, children: text),
             .crossReference(target: "#pg_683", volumeId: nil, citing: page683)),
            (.crossRefLink(target: "frus1961-63v14#pg_387", volumeId: "frus1961-63v14", broken: nil,
                           citing: Self.hint([], [(8, 17, 1888)]), children: text),
             .crossReference(target: "frus1961-63v14#pg_387", volumeId: "frus1961-63v14",
                             citing: Self.hint([], [(8, 17, 1888)]))),
            (.crossRefLink(target: "https://history.state.gov/historicaldocuments", volumeId: nil, broken: nil,
                           children: text),
             .crossReference(target: "https://history.state.gov/historicaldocuments", volumeId: nil, citing: nil)),
            (.crossRefLink(target: "mailto:history@state.gov", volumeId: nil, broken: nil, children: text),
             .crossReference(target: "mailto:history@state.gov", volumeId: nil, citing: nil)),
            (.crossRefLink(target: "#pg_700", volumeId: nil, broken: dead("#pg_700"), children: text),
             .brokenReference(target: "#pg_700")),
            // A dead target's '/', space and '%' survive: it is decoded once.
            (.crossRefLink(target: "frus1877#pg_1077/a b%41", volumeId: nil, broken: dead("frus1877#pg_1077/a b%41"),
                           children: text),
             .brokenReference(target: "frus1877#pg_1077/a b%41")),
            (.figureBlock(FigureBlock(head: [.plainText("Reel 1")], videoURL: URL(string: Self.videoPage),
                                      isVideo: true)),
             .crossReference(target: Self.videoPage, volumeId: nil, citing: nil)),
        ]
        for (node, expected) in cases {
            let urls = try links(in: page([node]))
            #expect(urls.count == 1, "\(node) wrote \(urls)")
            for url in urls {
                #expect(FRUSURLScheme.readerLink(from: url) == expected, "\(url.absoluteString)")
            }
        }
    }

    @Test("A person's, a term's or a target's own % escape is decoded again, as the app has always read it, and a dead target's is not")
    func anEscapeInARefIsDecodedTwice() throws {
        let text: [FRUSRenderNode] = [.plainText("link")]
        let person = try #require(try links(in: page([.persNameLink(ref: "#p_%41", children: text, person: nil)])).first)
        #expect(person.absoluteString == "frusexplorer://person/p_%2541")
        #expect(FRUSURLScheme.readerLink(from: person) == .person(ref: "p_A"))
        let doc = try #require(try links(in: page([.crossRefLink(target: "#d%31", volumeId: nil, broken: nil,
                                                                 children: text)])).first)
        #expect(FRUSURLScheme.readerLink(from: doc) == .crossReference(target: "#d1", volumeId: nil, citing: nil))
        let info = BrokenRefInfo(target: "#d%31", reason: "unknownAnchor", resolvedVolume: nil, resolvedAnchor: nil)
        let broken = try #require(try links(in: page([.crossRefLink(target: "#d%31", volumeId: nil, broken: info,
                                                                    children: text)])).first)
        #expect(FRUSURLScheme.readerLink(from: broken) == .brokenReference(target: "#d%31"))
    }
}

#if !SWIFT_PACKAGE // FRUSURLSchemeHandler is the app's
extension ReaderLinkTests {

    /// A call the handler made: the callback and its arguments, an entry by its ref.
    enum Call: Equatable {
        case person(String?)
        case gloss(String?)
        case crossReference(String, String?, PageCitationHint?)
        case brokenReference(String?)
    }

    /// `FRUSURLSchemeHandler.dispatch(url:)` as it was on `v2` at `101e17d7`, before it read links
    /// with the kit: the call it made for `url`, given its lookups.
    private static func callBeforeTheMove(
        _ url: URL, persons: [String: PersonEntry], gloss: [String: GlossEntry], broken: [String: BrokenRefInfo]
    ) -> Call? {
        let parts = url.pathComponents
            .filter { $0 != "/" }
            .map { $0.removingPercentEncoding ?? $0 }
        switch url.host {
        case "person":
            let ref = parts.first ?? ""
            return .person(persons[ref]?.ref)
        case "gloss":
            let ref = parts.first ?? ""
            return .gloss(gloss[ref]?.ref)
        case "doc":
            guard let target = parts.first else { return nil }
            let volumeId: String? = parts.count >= 2 ? parts[1] : nil
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return .crossReference(target, volumeId, PageCitationHint(queryItems: query))
        case "brokenref":
            guard let target = url.pathComponents.filter({ $0 != "/" }).first else { return nil }
            return .brokenReference(broken[target]?.target)
        default:
            return nil
        }
    }

    @Test("The app's handler makes the call it made before it read links with the kit, for every frusexplorer href")
    @MainActor
    func theHandlerCallsAsBefore() throws {
        let text: [FRUSRenderNode] = [.plainText("link")]
        let kissinger = PersonEntry(ref: "p_HK1", name: "Kissinger, Henry A.")
        let lansing = PersonEntry(ref: "frus1918Supp01v01#p_LR1", name: "Lansing, Robert")
        let ussr = GlossEntry(ref: "t_USSR1", term: "USSR", definition: "Union of Soviet Socialist Republics")
        let deadPage = BrokenRefInfo(target: "#pg_700", reason: "unknownPage", resolvedVolume: nil, resolvedAnchor: "pg_700")
        let deadEscape = BrokenRefInfo(target: "p%41", reason: "unknownAnchor", resolvedVolume: nil, resolvedAnchor: nil)
        let handler = FRUSURLSchemeHandler()
        handler.register(model: FRUSDocumentRenderModel(documentId: "d1", bodyNodes: [.paragraph([
            .persNameLink(ref: "#p_HK1", children: text, person: kissinger),
            .persNameLink(ref: "frus1918Supp01v01#p_LR1", children: text, person: lansing),
            .glossLink(ref: "#t_USSR1", children: text, entry: ussr),
            .crossRefLink(target: "#pg_700", volumeId: nil, broken: deadPage, children: text),
            .crossRefLink(target: "p%41", volumeId: nil, broken: deadEscape, children: text),
        ])], footnotes: []))
        // `register(model:)`'s keys: the ref without its '#', and the dead reference's verbatim target.
        let persons = ["p_HK1": kissinger, "frus1918Supp01v01#p_LR1": lansing]
        let gloss = ["t_USSR1": ussr]
        let broken = ["#pg_700": deadPage, "p%41": deadEscape]

        var calls: [Call] = []
        handler.onPersonTap = { calls.append(.person($0?.ref)) }
        handler.onGlossTap = { calls.append(.gloss($0?.ref)) }
        handler.onCrossRefTap = { calls.append(.crossReference($0, $1, $2)) }
        handler.onBrokenRefTap = { calls.append(.brokenReference($0?.target)) }

        // The navigation delegate dispatches only frusexplorer URLs, so only they are compared.
        let urls = try Self.table.map(\.href).filter { $0.hasPrefix("frusexplorer:") }
            .map { try #require(URL(string: $0)) }
        var answered = 0
        for url in urls {
            calls.removeAll()
            handler.dispatch(url: url)
            let before = Self.callBeforeTheMove(url, persons: persons, gloss: gloss, broken: broken)
            #expect(calls == (before.map { [$0] } ?? []), "\(url.absoluteString)")
            if case .person(.some) = before { answered += 1 }
            if case .gloss(.some) = before { answered += 1 }
            if case .brokenReference(.some) = before { answered += 1 }
        }
        // The lookups were reached, not only the misses: p_HK1, the split set's person, t_USSR1,
        // and three dead references (#pg_700 in two spellings, and p%41).
        #expect(answered == 6, "\(answered) lookups found their entry")
    }
}
#endif
