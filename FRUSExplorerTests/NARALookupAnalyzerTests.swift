// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - NARALookupAnalyzerTests

/// Pins `NARALookupAnalyzer` — the candidate reading, routing and offline resolution behind #235.
///
/// ## What was wrong before
/// Selecting text in a document body opened the NARA lookup on a hardcoded `.keywordRG59` with an
/// empty candidate list, because detection ran only over a `blockContext` the in-document path
/// never supplied. A reader who selected `Lot 60 D 224` — a lot the app has shipped a NARA record
/// for since #352 — was shown six radio buttons and a search field, and needed an API key before
/// anything appeared at all.
///
/// ## Why these tests can be strict about NAIDs
/// The resolutions come from the **real bundled indexes**, through `ArchivalResolver`, which is the
/// same path Source Explorer and the Collections export use. Pinning an actual NAID is therefore a
/// cross-artifact assertion, not a fixture: if the analyzer ever grows its own lookup, or the
/// bundle stops answering a lot it used to, these fail. The two lots below are load-bearing for
/// different reasons — `60 D 224` came from the original keyed harvest, `80 D 135` from #372 item
/// 1b's offline supplement, so between them they prove both halves of the bundle are reachable.
///
/// Version history:
///   1.0 — Session 2026-08-20: #235
@Suite("NARA lookup — candidate analysis")
struct NARALookupAnalyzerTests {

    /// A source note in the shape FRUS prints, naming a lot the bundle resolves.
    private let lotNote = "Department of State, Conference Files: Lot 60 D 224, CF 1626."
    /// A lot admitted by #372 item 1b's offline supplement.
    private let supplementedNote = "Department of State, S/S Files: Lot 80 D 135, Box 4."

    private func candidates(_ selection: String, context: String? = nil)
        -> [NARALookupCandidate] {
        NARALookupAnalyzer.candidates(selection: selection, context: context)
    }

    // MARK: - The point of the issue

    @Test("A lot in the selection resolves from the bundle, with no API key and no network")
    func lotResolvesOffline() throws {
        let out = candidates(lotNote)
        let top = try #require(out.first, "a printed lot citation must yield a candidate")
        #expect(top.resolution?.naId == "592873",
                "the bundled record for Lot 60 D 224 — the answer the reader needed a key for before")
        #expect(top.strategy == .lotFileRG59)
        #expect(top.origin == .selection)
        #expect(top.resolution?.title.isEmpty == false, "the row must be able to name the series")
    }

    /// The supplement's lots are reachable too — otherwise #372 item 1b's 87 rows would be
    /// invisible on the one surface a reader most often reaches them from.
    @Test("A lot added by the offline supplement resolves here as well")
    func supplementedLotResolves() throws {
        let top = try #require(candidates(supplementedNote).first)
        #expect(top.resolution?.naId == "236748619")
    }

    /// A decimal file number never routed anywhere before: `ArchiveCitation` carries no decimal
    /// field, so `applyCitation`'s `else` branch left the reader on the picker. `.centralURL` is
    /// also the one strategy that opens a catalog URL with no API key.
    @Test("A decimal file number routes to the keyless central-file URL")
    func decimalRoutesToCentralURL() throws {
        let out = candidates("Department of State, Central Files, 763.72/1476")
        let decimal = try #require(out.first { $0.strategy == .centralURL },
                                   "a decimal citation must produce a central-file route")
        #expect(decimal.query.contains("763.72"))
    }

    @Test("An F-designator lot routes to RG 84, not RG 59")
    func fDesignatorRoutesToRG84() throws {
        let out = candidates("Kabul Embassy Files: Lot 66 F 89, Top Secret Subject Files.")
        let lot = try #require(out.first { $0.strategy == .lotFileRG84 || $0.strategy == .lotFileRG59 })
        #expect(lot.strategy == .lotFileRG84,
                "an F lot is a diplomatic-post record; routing it to RG 59 searches the wrong group")
    }

    // MARK: - Ranking

    /// **A caveat about the unresolvable fixtures below.** `Lot 99 D 999` and `Lot 98 D 998` are
    /// invented lot numbers, chosen because the bundle answers neither, which is what makes them
    /// usable as the "unresolved" side of a ranking comparison. That is a property of today's
    /// artifact, not a fact about NARA: if a future harvest ever resolves one, the test it appears
    /// in stops testing the rank it was written for and starts passing for the wrong reason.
    /// Deliberately not hidden behind a helper — a reader of these tests should see the assumption.


    /// The ranking is an argument about a reader who may have no key: an answer already in hand
    /// beats a route that needs one, whichever text it came from.
    @Test("A resolved candidate outranks an unresolved one found in the selection itself")
    func resolutionOutranksOrigin() throws {
        // Selection names a lot the bundle cannot answer; context names one it can.
        let out = candidates("Lot 99 D 999", context: lotNote)
        let top = try #require(out.first)
        #expect(top.resolution != nil,
                "an offline answer is worth more to a keyless reader than a search term they chose")
    }

    /// The keyless route outranks an unresolved lot, which is the rank a reader without an API
    /// key feels: `.centralURL` opens a real catalog page, while an unresolved lot can only
    /// pre-fill a search they cannot run.
    @Test("A keyless central-file route outranks an unresolved lot")
    func centralURLOutranksUnresolvedLot() throws {
        let out = candidates("763.72/1476 and Lot 99 D 999")
        // NOT `guard … else { return }`. The first version of this test did exactly that, and a
        // mutation dropping the keyless-route rank SURVIVED: with too few candidates the guard
        // returned and the test passed without comparing anything. A fixture that stops producing
        // what the test needs must fail, not excuse itself.
        #expect(out.count >= 2,
                "fixture guard: this text must yield both a decimal route and an unresolved lot")
        #expect(out.first?.strategy == .centralURL,
                "a route that works without a key beats one that needs one")
    }

    /// The `.centralURL` rank key's only discriminating case, and the one that killed the mutant.
    ///
    /// Within one passage the decimal is read before any lot, so discovery order alone produces
    /// the right answer and the key proves nothing. Split them across selection and context and
    /// the two preferences OPPOSE: read order favours the selection's lot, the rank favours the
    /// keyless route. The rank must win.
    @Test("A keyless route in the context outranks an unresolved lot in the selection")
    func centralURLInContextOutranksLotInSelection() throws {
        let out = candidates("Lot 99 D 999", context: "763.72/1476")
        #expect(out.count >= 2, "fixture guard: both a lot and a decimal must be read")
        #expect(out.first?.strategy == .centralURL, """
            a decimal opens a real catalog page without a key; an unresolved lot can only \
            pre-fill a search the reader cannot run — so it wins even from the context
            """)
    }

    /// The selection-first preference is real but is enforced by READ ORDER, not by a rank key —
    /// see `NARALookupAnalyzer.rank`. This pins the behaviour; the analyzer's doc says where it
    /// actually lives, so nobody re-adds a rank key believing this test covers one.
    @Test("Between two unresolved candidates, the selected one comes first")
    func selectionOutranksContext() throws {
        // Two lots the bundle cannot answer, so neither wins on resolution and origin decides.
        let out = candidates("Lot 99 D 999", context: "Lot 98 D 998")
        #expect(out.count >= 2, "fixture guard: both lots must be read, or the ordering is untested")
        #expect(out.allSatisfy { $0.resolution == nil },
                "fixture guard: if the bundle learns either lot, this stops testing origin")
        #expect(out.first?.origin == .selection,
                "the reader pointed at the selection; context is what the app volunteered")
    }

    // MARK: - Shape

    @Test("The same citation in selection and context is offered once")
    func duplicatesCollapse() {
        let out = candidates(lotNote, context: lotNote)
        #expect(out.filter { $0.query.contains("60") }.count <= 1,
                "one citation, one row — a duplicate row is a second answer that is the same answer")
    }

    @Test("Unrecognisable text yields nothing, which is when the manual field is the answer")
    func nothingRecognisableYieldsNoCandidates() {
        #expect(candidates("the quick brown fox").isEmpty)
        #expect(candidates("").isEmpty)
        #expect(candidates("   ", context: nil).isEmpty)
    }

    /// Deliberate: the issue asks to keep the present interface as a fallback, so producing no
    /// candidate must be an ordinary outcome rather than a failure.
    @Test("A nil context is not an error")
    func nilContextIsFine() {
        #expect(!candidates(lotNote, context: nil).isEmpty)
    }

    @Test("Ordering is stable across repeated calls")
    func orderingIsStable() {
        let a = candidates(lotNote, context: supplementedNote).map(\.id)
        let b = candidates(lotNote, context: supplementedNote).map(\.id)
        #expect(a == b)
        #expect(!a.isEmpty)
    }

    /// Identity has to include the strategy: the same lot number is a meaningful row under two
    /// different routes, and collapsing on query alone would silently drop one.
    @Test("Candidate identity distinguishes two routes to the same query")
    func identityIncludesStrategy() {
        let lot = NARALookupCandidate(label: "x", query: "60 D 224", strategy: .lotFileRG59,
                                      origin: .selection, resolution: nil)
        let other = NARALookupCandidate(label: "x", query: "60 D 224", strategy: .keyword,
                                        origin: .selection, resolution: nil)
        #expect(lot.id != other.id)
    }

    // MARK: - Agreement with the rest of the app

    /// The analyzer must not grow a second lookup. If it ever stops delegating, this fails — which
    /// is the only cheap way to notice, since a private copy would still return plausible NAIDs.
    @Test("The resolution is exactly what ArchivalResolver answers for the same lot")
    func resolutionAgreesWithArchivalResolver() throws {
        let top = try #require(candidates(lotNote).first)
        let direct = ArchivalResolver.documentResolution(lotFile: "60 D 224")
        #expect(top.resolution?.naId == direct?.naId)
        #expect(top.resolution?.title == direct?.title)
        #expect(top.resolution?.catalogURL == direct?.catalogURL)
    }

    /// The window is asymmetric because a source note's archival clause normally PRECEDES the
    /// phrase a reader selects. A symmetric window would spend half its reach on text that
    /// rarely carries the citation.
    @Test("The context window reaches further back than forward")
    func contextWindowIsAsymmetric() {
        #expect(NARALookupAnalyzer.contextBefore > NARALookupAnalyzer.contextAfter)
        #expect(NARALookupAnalyzer.contextBefore > 0)
    }
}
