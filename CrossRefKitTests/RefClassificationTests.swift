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

/// Validation-classifier coverage: shape detection, candidate generation, and the deliberate
/// divergences from navigation (mailto → external, footnote/page fallbacks).
struct RefClassificationTests {

    // MARK: - Shape & routing

    @Test("Same-volume document anchor classifies as a generic anchor with a literal candidate")
    func sameVolumeDocument() {
        let c = CrossRefGrammar.classifyForValidation("#d42", sourceVolumeId: "frus1901")
        #expect(c == .anchor(volumeId: nil, anchor: "d42", candidates: ["d42"], shape: .generic))
    }

    @Test("Cross-volume prefix is captured as the target volume")
    func crossVolume() {
        let c = CrossRefGrammar.classifyForValidation("frus1877#pg_1077", sourceVolumeId: "frus1901")
        #expect(c == .anchor(volumeId: "frus1877", anchor: "pg_1077",
                             candidates: ["pg_1077"], shape: .page))
    }

    @Test("http, https, and mailto all classify as external (validator recognises mailto)")
    func externals() {
        #expect(CrossRefGrammar.classifyForValidation("http://x.com", sourceVolumeId: "v") == .external)
        #expect(CrossRefGrammar.classifyForValidation("https://x.com", sourceVolumeId: "v") == .external)
        #expect(CrossRefGrammar.classifyForValidation("mailto:a@b.gov", sourceVolumeId: "v") == .external)
    }

    @Test("Empty targets and empty anchors classify as empty")
    func empties() {
        #expect(CrossRefGrammar.classifyForValidation("", sourceVolumeId: "v") == .empty)
        #expect(CrossRefGrammar.classifyForValidation("   ", sourceVolumeId: "v") == .empty)
        #expect(CrossRefGrammar.classifyForValidation("#", sourceVolumeId: "v") == .empty)
        #expect(CrossRefGrammar.classifyForValidation("frus1901#", sourceVolumeId: "v") == .empty)
    }

    @Test("A bare token with no '#' is whole-volume-or-malformed for the caller to disambiguate")
    func bareToken() {
        #expect(CrossRefGrammar.classifyForValidation("frus1865p1", sourceVolumeId: "v")
                == .wholeVolumeOrMalformed(token: "frus1865p1"))
        // A page anchor written without its '#' is the malformed case the caller catches.
        #expect(CrossRefGrammar.classifyForValidation("pg_1602", sourceVolumeId: "v")
                == .wholeVolumeOrMalformed(token: "pg_1602"))
    }

    // MARK: - Candidate generation

    @Test("A footnote anchor offers both the literal footnote id and the base document")
    func footnoteCandidates() {
        #expect(CrossRefGrammar.anchorCandidates("d100fn2") == ["d100fn2", "d100"])
        #expect(CrossRefGrammar.anchorCandidates("d6Bfn3") == ["d6Bfn3", "d6B"])
    }

    @Test("A page anchor without the canonical underscore offers pg_<n> as a fallback")
    func pageCandidates() {
        #expect(CrossRefGrammar.anchorCandidates("page313") == ["page313", "pg_313"])
        #expect(CrossRefGrammar.anchorCandidates("pg313") == ["pg313", "pg_313"])
        // The canonical form is already literal — no duplicate.
        #expect(CrossRefGrammar.anchorCandidates("pg_313") == ["pg_313"])
    }

    @Test("A generic anchor has only its literal candidate")
    func genericCandidates() {
        #expect(CrossRefGrammar.anchorCandidates("in14") == ["in14"])
        #expect(CrossRefGrammar.anchorCandidates("t_NSC1") == ["t_NSC1"])
        // Roman-numeral page: page-shaped but no arabic digits → literal only (case-sensitive).
        #expect(CrossRefGrammar.anchorCandidates("pg_XVIII") == ["pg_XVIII"])
        #expect(CrossRefGrammar.anchorCandidates("pg_xviii") == ["pg_xviii"])
    }
}
