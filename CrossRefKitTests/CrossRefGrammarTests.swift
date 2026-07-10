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

/// Byte-parity fixtures locking `CrossRefGrammar.resolveDestination` to the app's
/// `FRUSURLSchemeHandler.resolveCrossRefTarget` and `parseVolumePrefix` to
/// `FRUSDocumentParser.parseRefTarget`. If either copy drifts, a case here fails.
struct CrossRefGrammarTests {

    private static func url(_ s: String) -> URL { URL(string: s)! }

    // MARK: - resolveDestination navigation parity

    @Test("resolveDestination mirrors the app grammar branch-for-branch")
    func resolveDestinationParity() {
        // (rawTarget, sourceVolumeId, expected) — drawn from the app's documented cases
        // (FRUSURLSchemeHandler.swift:18-19) plus one case per grammar branch.
        let cases: [(String, String?, RefDestination)] = [
            // Same-volume document.
            ("#d80", nil, .document(volumeId: nil, documentId: "d80")),
            ("#d80", "frus1958-60v01", .document(volumeId: "frus1958-60v01", documentId: "d80")),
            // Cross-volume document — prefix overrides the source volume.
            ("frus1964-68v20#d104", nil, .document(volumeId: "frus1964-68v20", documentId: "d104")),
            ("frus1964-68v20#d104", "frus1900", .document(volumeId: "frus1964-68v20", documentId: "d104")),
            // Footnote-suffixed id normalises to the base document.
            ("#d100fn2", nil, .document(volumeId: nil, documentId: "d100")),
            ("#d6Bfn3", nil, .document(volumeId: nil, documentId: "d6B")),
            // A dNfn with no trailing digit is NOT a footnote match — literal document.
            ("#d80fn", nil, .document(volumeId: nil, documentId: "d80fn")),
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
            // mailto: is NOT external to the app grammar — it falls through to a document anchor.
            ("mailto:history@state.gov", nil, .document(volumeId: nil, documentId: "mailto:history@state.gov")),
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
