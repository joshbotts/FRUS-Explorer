// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CrossRefKit

/// Fixtures for `CrossRefGrammar.resolveDestination`, drawn from the app's
/// `FRUSURLScheme.resolveCrossRefTarget` (FRUSCoreKit), and for `parseVolumePrefix`, drawn from
/// `FRUSDocumentParser.parseRefTarget`. They are hard-coded and never call the app, so a change to
/// the app's copy fails nothing here: the mirror drifted on three branches (#988's footnote,
/// #1603's whole volume and `mailto:`) until #1693. `CrossRefGrammarAppParityTests`, in
/// `ResolvedEdgeIndexGeneratorTests`, holds the mirror to the app's function itself, through
/// FRUSCoreKit, which this target does not link.
///
/// Version history:
///   1.0 — Session 6 (#240A)
///   1.1 — #1693: the footnote, whole-volume and `mailto:` branches, as the app reads them
struct CrossRefGrammarTests {

    private static func url(_ s: String) -> URL { URL(string: s)! }

    // MARK: - resolveDestination navigation parity

    @Test("resolveDestination mirrors the app grammar branch-for-branch")
    func resolveDestinationParity() {
        // (rawTarget, sourceVolumeId, expected) — drawn from the app's documented cases
        // (`CrossRefDestination`'s doc comment) plus one case per grammar branch.
        let cases: [(String, String?, RefDestination)] = [
            // Same-volume document.
            ("#d80", nil, .document(volumeId: nil, documentId: "d80")),
            ("#d80", "frus1958-60v01", .document(volumeId: "frus1958-60v01", documentId: "d80")),
            // Cross-volume document — prefix overrides the source volume.
            ("frus1964-68v20#d104", nil, .document(volumeId: "frus1964-68v20", documentId: "d104")),
            ("frus1964-68v20#d104", "frus1900", .document(volumeId: "frus1964-68v20", documentId: "d104")),
            // A footnote anchor names its note and the document holding it (#988).
            ("#d100fn2", nil, .footnote(volumeId: nil, documentId: "d100", anchor: "d100fn2")),
            ("#d6Bfn3", nil, .footnote(volumeId: nil, documentId: "d6B", anchor: "d6Bfn3")),
            ("frus1955-57v09#d12fn3", "frus1958-60v01",
             .footnote(volumeId: "frus1955-57v09", documentId: "d12", anchor: "d12fn3")),
            // The widened pattern: a section-prefixed or symbol-suffixed note id, and a suffix with
            // no digit, each name the document before `fn` (the 33 corpus references #988 found).
            ("#cr_d6fn4", "frus1958-60v05mSupp",
             .footnote(volumeId: "frus1958-60v05mSupp", documentId: "cr_d6", anchor: "cr_d6fn4")),
            ("#d705fn-sym1", nil, .footnote(volumeId: nil, documentId: "d705", anchor: "d705fn-sym1")),
            ("#d12fn5a", nil, .footnote(volumeId: nil, documentId: "d12", anchor: "d12fn5a")),
            ("#d80fn", nil, .footnote(volumeId: nil, documentId: "d80", anchor: "d80fn")),
            // An id holding "fn" with no `d` and digits before it is a document, not a note.
            ("#appendix-fn", nil, .document(volumeId: nil, documentId: "appendix-fn")),
            // Printed pages (arabic).
            ("#pg_313", "frus1901", .page(volumeId: "frus1901", page: 313)),
            ("frus1955-57v17#pg_313", nil, .page(volumeId: "frus1955-57v17", page: 313)),
            ("#page42", nil, .page(volumeId: nil, page: 42)),
            // Roman-numeral / non-arabic pages are unresolved.
            ("#pg_XIII", nil, .unresolved),
            ("#pg_", nil, .unresolved),
            ("#pg_313a", nil, .unresolved),
            // Same-document anchors are unresolved.
            ("#fn2", nil, .unresolved),
            ("#note3", nil, .unresolved),
            ("#fig1", nil, .unresolved),
            ("#tbl4", nil, .unresolved),
            // Editorial / term / index anchors fall through to literal document.
            ("#in14", nil, .document(volumeId: nil, documentId: "in14")),
            ("#t_NSC1", nil, .document(volumeId: nil, documentId: "t_NSC1")),
            ("#about-the-digital-edition", nil, .document(volumeId: nil, documentId: "about-the-digital-edition")),
            // External URLs.
            ("http://example.com", nil, .external(Self.url("http://example.com"))),
            ("https://history.state.gov/foo", nil, .external(Self.url("https://history.state.gov/foo"))),
            // A mail address is external, as a web address is.
            ("mailto:history@state.gov", nil, .external(Self.url("mailto:history@state.gov"))),
            // A whole volume: a target with no `#` that is a volume's id (#1603), whatever volume
            // the reference sits in, and whether or not the catalogue holds it.
            ("frus1961-63v05", "frus1964-68v20", .volume(volumeId: "frus1961-63v05")),
            ("frus1958-60v15-16mSupp1", nil, .volume(volumeId: "frus1958-60v15-16mSupp1")),
            ("frus1861", nil, .volume(volumeId: "frus1861")),
            // Any other target with no `#` is an anchor in the volume being read: a page printed
            // without its `#`, or a token that only begins like a volume.
            ("pg_1602", "frus1913", .page(volumeId: "frus1913", page: 1602)),
            ("frusAppendix", "frus1913", .document(volumeId: "frus1913", documentId: "frusAppendix")),
            ("frus", nil, .document(volumeId: nil, documentId: "frus")),
            // Empty anchors.
            ("", nil, .unresolved),
            ("#", nil, .unresolved),
            ("frus1901#", "frus1900", .unresolved),
            // Leading/trailing whitespace is trimmed.
            ("  #d5  ", nil, .document(volumeId: nil, documentId: "d5")),
        ]
        for (raw, vol, expected) in cases {
            #expect(CrossRefGrammar.resolveDestination(raw, volumeId: vol) == expected,
                    "resolveDestination(\(raw), \(vol ?? "nil"))")
        }
    }

    // MARK: - parseVolumePrefix parity

    @Test("parseVolumePrefix mirrors parseRefTarget's volume split")
    func parseVolumePrefixParity() {
        let cases: [(String, String?)] = [
            ("#d42", nil),
            ("frus1969-76v01#d42", "frus1969-76v01"),
            ("frus1901#", "frus1901"),
            ("https://history.state.gov", nil),
            ("http://example.com", nil),
            ("frus1865p1", nil),          // bare whole-volume ref: no '#', no split
        ]
        for (raw, expectedVol) in cases {
            let parsed = CrossRefGrammar.parseVolumePrefix(raw)
            #expect(parsed.target == raw)
            #expect(parsed.volumeId == expectedVol, "parseVolumePrefix(\(raw))")
        }
    }
}
