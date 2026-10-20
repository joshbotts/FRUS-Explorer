// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CrossRefKit
import FRUSCoreKit
import Foundation
import Testing

// MARK: - CrossRefGrammarAppParityTests

/// `CrossRefKit`'s twin of the reader's grammar, held to the app's own function (#1693).
///
/// `CrossRefGrammarTests` pins the twin to a hard-coded table and never calls the app, so the twin
/// drifted on three branches without a test failing: a footnote anchor (#988), a whole volume
/// (#1603) and a `mailto:` address. This target links FRUSCoreKit for the generator's section
/// rows, so it can call `FRUSURLScheme.resolveCrossRefTarget` itself. A new case on the app's
/// enum stops ``mirrored(_:)`` compiling; a changed branch fails the table here.
///
/// Version history:
///   1.0 — #1693
@Suite("Cross-reference grammar — the twin and the app's function")
struct CrossRefGrammarAppParityTests {

    /// The app's destination as the twin's enum spells it. Exhaustive, so a case the app adds
    /// fails the build of this target until the twin has it too.
    private func mirrored(_ destination: CrossRefDestination) -> RefDestination {
        switch destination {
        case .document(let volumeId, let documentId):
            return .document(volumeId: volumeId, documentId: documentId)
        case .footnote(let volumeId, let documentId, let anchor):
            return .footnote(volumeId: volumeId, documentId: documentId, anchor: anchor)
        case .page(let volumeId, let page):
            return .page(volumeId: volumeId, page: page)
        case .volume(let volumeId):
            return .volume(volumeId: volumeId)
        case .external(let url):
            return .external(url)
        case .unresolved:
            return .unresolved
        }
    }

    /// Anchors of every shape the grammar branches on, the corpus's own spellings among them.
    private static let anchors = [
        "d80", "d6B", "d100fn2", "d6Bfn3", "d80fn", "d12fn5a", "d705fn-sym1", "cr_d6fn4",
        "es_d2fn1", "appendix-fn", "fnord", "fn2", "note3", "fig1", "tbl4", "FN1",
        "pg_313", "pg313", "page42", "Page7", "pg_XIII", "pg_", "pg_313a", "pg-seq-3",
        "in14", "t_NSC1", "about-the-digital-edition", "ch1", "comp3", "p_HK1", "",
    ]

    /// Targets with no `#`, which the grammar reads as a whole volume, an address or an anchor.
    private static let bareTargets = [
        "frus1961-63v05", "frus1958-60v15-16mSupp1", "frus1861", "frus1969-76v41",
        "frus", "frusAppendix", "frus-1961", "pg_1602", "d12", "d12fn3",
        "http://example.com", "https://history.state.gov/historicaldocuments",
        "mailto:history@state.gov", "mailto:", "http://", "", "   ",
    ]

    @Test("The twin answers as the app's resolveCrossRefTarget, branch for branch")
    func twinMatchesTheApp() {
        var targets: [String] = Self.bareTargets
        for prefix in ["", "frus1964-68v20", "frus1901", "frus1958-60v05mSupp"] {
            for anchor in Self.anchors { targets.append("\(prefix)#\(anchor)") }
        }
        targets += targets.map { "  \($0)  " }

        var compared = 0
        var branches = Set<String>()
        for target in targets {
            for volumeId in [nil, "frus1913", "frus1945Berlinv02"] as [String?] {
                let app = mirrored(FRUSURLScheme.resolveCrossRefTarget(target, volumeId: volumeId))
                let twin = CrossRefGrammar.resolveDestination(target, volumeId: volumeId)
                #expect(twin == app, """
                    resolveDestination(\"\(target)\", \(volumeId ?? "nil")) is \(twin); the app's \
                    resolveCrossRefTarget reads \(app).
                    """)
                compared += 1
                branches.insert(String(describing: app).prefix { $0 != "(" }.description)
            }
        }
        #expect(compared > 500, "only \(compared) targets compared")
        #expect(branches == ["document", "footnote", "page", "volume", "external", "unresolved"],
                "the table reaches only \(branches.sorted()) of the app's six cases")
    }

    @Test("The twin's cited document is the one the app's index stores a reference under")
    func citedDocumentIsTheStoredTarget() throws {
        // A note's reference is stored as one to its document (#1613); a page, a whole volume,
        // an address and nothing are no document.
        let note = try #require(CrossRefGrammar.resolveDestination("frus1955-57v09#d12fn3",
                                                                   volumeId: nil).citedDocument)
        #expect(note.volumeId == "frus1955-57v09")
        #expect(note.documentId == "d12")
        let document = try #require(CrossRefGrammar.resolveDestination("#d12",
                                                                       volumeId: "frus1913").citedDocument)
        #expect(document.volumeId == "frus1913")
        #expect(document.documentId == "d12")
        for target in ["#pg_313", "frus1961-63v05", "mailto:history@state.gov", "#fn2", ""] {
            #expect(CrossRefGrammar.resolveDestination(target, volumeId: "frus1913")
                        .citedDocument == nil, "\(target) cites no document")
        }
    }
}
