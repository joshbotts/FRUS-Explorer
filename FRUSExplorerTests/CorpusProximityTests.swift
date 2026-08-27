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

// MARK: - CorpusProximityTests

/// The #562 corpus-proximity axis: `ProximityMath.narrowing`, `ProximityMath.printAdjacency`, and
/// the `VolumeArrangement` that feeds them.
///
/// The scorer itself needs a live index, so what is pinned here is the arithmetic and the tree
/// flattening — which is where every decision that took measurement to reach actually lives. Each
/// suite below names the corpus fact that forced its shape, because the numbers are the argument
/// and a later reader will otherwise reasonably assume they were chosen for tidiness.
///
/// Version history:
///   1.0 — #562: initial implementation
@Suite("Corpus proximity")
struct CorpusProximityTests {

    // MARK: - narrowing

    @Suite("Containment")
    struct NarrowingTests {

        /// The two ends of the range, exactly. `ln(n / 2)` as the denominator — rather than `ln(n)`
        /// — is the whole reason the top end is reachable: a container holds at least two things,
        /// so `ln(n)` caps the measure near 0.89 and the axis never uses its last tenth. An
        /// implementation that divides by `ln(n)` passes a "roughly 1" test and fails this one.
        @Test("A whole-volume container scores 0; a two-unit container scores exactly 1")
        func endpoints() {
            #expect(ProximityMath.narrowing(totalUnits: 480, containerUnits: 480) == 0)
            #expect(ProximityMath.narrowing(totalUnits: 480, containerUnits: 2) == 1)
            #expect(ProximityMath.narrowing(totalUnits: 2099, containerUnits: 2) == 1)
        }

        /// Every consecutive pair, not just the endpoints — a function that is right at both ends and
        /// wrong in between is exactly what an endpoints-only test certifies.
        @Test("Strictly decreasing as the shared container widens")
        func monotone() {
            let total = 511   // the median volume, measured across the 552 indexed volumes
            var previous = Double.infinity
            for units in 2...total {
                let score = ProximityMath.narrowing(totalUnits: total, containerUnits: units)
                #expect(score < previous, "narrowing was not strictly decreasing at \(units) units")
                #expect(score >= 0 && score <= 1, "narrowing left [0, 1] at \(units) units")
                previous = score
            }
        }

        @Test("Degenerate inputs clamp instead of escaping the range")
        func clamping() {
            // A container cannot really hold fewer than two things; if one claims to, it is the
            // narrowest possible container, not an out-of-range score.
            #expect(ProximityMath.narrowing(totalUnits: 480, containerUnits: 1) == 1)
            #expect(ProximityMath.narrowing(totalUnits: 480, containerUnits: 0) == 1)
            #expect(ProximityMath.narrowing(totalUnits: 480, containerUnits: -5) == 1)
            // A container wider than the volume is the volume.
            #expect(ProximityMath.narrowing(totalUnits: 480, containerUnits: 9_000) == 0)
        }

        /// `ln(n / 2)` is 0 at `n == 2`, so without the guard this divides by zero and returns NaN
        /// or infinity — which would propagate into a persisted, CloudKit-mirrored lead score.
        @Test("A volume too small to narrow returns 0, never NaN or infinity")
        func tinyVolumes() {
            for total in [0, 1, 2] {
                for units in [0, 1, 2, 3] {
                    let score = ProximityMath.narrowing(totalUnits: total, containerUnits: units)
                    #expect(score == 0, "totalUnits \(total), containerUnits \(units) gave \(score)")
                    #expect(score.isFinite)
                }
            }
            // Three units is the smallest volume with any room to narrow.
            #expect(ProximityMath.narrowing(totalUnits: 3, containerUnits: 2) == 1)
            #expect(ProximityMath.narrowing(totalUnits: 3, containerUnits: 3) == 0)
        }
    }

    // MARK: - printAdjacency

    @Suite("Print adjacency")
    struct PrintAdjacencyTests {

        @Test("A three-position ramp, and nothing beyond it")
        func ramp() {
            #expect(ProximityMath.printAdjacency(ordinalGap: 0) == 0)     // the document itself
            #expect(ProximityMath.printAdjacency(ordinalGap: 1) == 1.0)
            #expect(ProximityMath.printAdjacency(ordinalGap: 2) == 2.0 / 3)
            #expect(ProximityMath.printAdjacency(ordinalGap: 3) == 1.0 / 3)
            #expect(ProximityMath.printAdjacency(ordinalGap: 4) == 0)
            #expect(ProximityMath.printAdjacency(ordinalGap: 500) == 0)
        }

        /// The scorer subtracts two ordinals without ordering them, so a signed result reaches here
        /// routinely. An unsigned subtraction bug is invisible until the anchor happens to come
        /// second.
        @Test("The sign of the gap is ignored")
        func symmetry() {
            for gap in 1...5 {
                #expect(ProximityMath.printAdjacency(ordinalGap: gap)
                        == ProximityMath.printAdjacency(ordinalGap: -gap))
            }
        }
    }

    // MARK: - VolumeArrangement

    @Suite("Volume arrangement")
    struct ArrangementTests {

        /// Builds a section. `documentIds` and `subsections` are the only fields the arrangement
        /// reads; the rest are filled with values it must ignore.
        static func section(_ id: String, docs: [String] = [],
                            subs: [VolumeSection] = [],
                            divType: String = "compilation") -> VolumeSection {
            VolumeSection(sectionId: id, divType: divType, title: "Section \(id)",
                          documentIds: docs, subsections: subs)
        }

        static func structure(_ sections: [VolumeSection]) -> VolumeStructure {
            VolumeStructure(volumeId: "test", sections: sections)
        }

        /// The `frus1919Parisv13` guard, and the single most important test here.
        ///
        /// That volume — the Paris Peace Conference treaty texts — has **2** `<div type="document">`
        /// elements and 176 sections, against 170 rows in `document_cache`: the app presents whole
        /// prose sections as readable documents. Counting documents alone makes the denominator 2,
        /// every log ratio collapses, and all 170 of its documents score a flat 1.0 against each
        /// other — a silent revert to the behaviour this axis exists to replace, in a real volume.
        @Test("Units count sections as well as documents")
        func sectionsAreUnits() {
            var sections: [VolumeSection] = [Self.section("ch1", docs: ["d1"])]
            for index in 2...176 { sections.append(Self.section("ch\(index)")) }
            sections[1] = Self.section("ch2", docs: ["d2"])

            let arrangement = VolumeArrangement(Self.structure(sections))
            #expect(arrangement.totalUnits == 178, "176 sections + 2 documents")
            #expect(arrangement.totalUnits != 2, "a document-only denominator collapses this volume")

            // Two documents in different top-level sections share nothing below the volume.
            let anchor = try! #require(arrangement.section(holding: "d1"))
            let candidate = try! #require(arrangement.section(holding: "d2"))
            #expect(ProximityMath.narrowing(totalUnits: arrangement.totalUnits,
                                            containerUnits: arrangement.containerUnits(anchor, candidate)) == 0)

            // The population that matters here is the 168 *quasi*-documents — whole sections the
            // app presents as readable. They carry no reading-order position, so containment is the
            // only term in play, and two unrelated ones must land on the floor. Measured on the
            // real volume, ch1 against ch14 scores exactly 0.6000.
            #expect(pairScore(arrangement, "ch1", "ch14") == 0.6)
            #expect(pairScore(arrangement, "ch1", "ch14") != 1.0,
                    "the flat-1.0 regression a document-only denominator would reproduce here")

            // The volume's two *real* documents are the whole reading sequence, so they are
            // adjacent to each other by construction — correct, and not what this test is about.
            #expect(pairScore(arrangement, "d1", "d2") == 1.0)
        }

        /// The design decision the measurement forced, stated as an assertion.
        ///
        /// 13–14% of corpus documents sit under a compilation that holds one chapter and nothing
        /// else — 39.8% of documents in 1950s-coverage volumes. Under a depth ratio those documents
        /// score a whole level differently from identically-arranged documents in a volume that
        /// skipped the wrapper. Under a volume-relative measure the wrapper contributes one unit.
        @Test("A single-child wrapper barely changes the score")
        func wrapperInvariance() {
            let docs = (1...10).map { "d\($0)" }
            let flat = VolumeArrangement(Self.structure([Self.section("comp1", docs: docs)]))
            let wrapped = VolumeArrangement(Self.structure([
                Self.section("comp1", subs: [Self.section("ch1", docs: docs, divType: "chapter")])
            ]))

            #expect(flat.totalUnits == 11)
            #expect(wrapped.totalUnits == 12)   // exactly one more unit, not one more level

            let flatScore = pairScore(flat, "d1", "d7")
            let wrappedScore = pairScore(wrapped, "d1", "d7")
            #expect(abs(flatScore - wrappedScore) < 0.02,
                    """
                    A single-child wrapper moved the score from \(flatScore) to \(wrappedScore). \
                    A depth ratio would differ by a whole level here, which is what makes it \
                    unusable across a series whose nesting practice changed over 70 years.
                    """)
        }

        /// A volume with one section holding hundreds of documents is 4.92% of the corpus, and it is
        /// the case where containment has nothing to say. Adjacency is the only signal left, and it
        /// is why the axis does not simply collapse back to a constant for those volumes.
        @Test("A flat volume falls to the floor except where documents are printed together")
        func flatVolume() {
            let docs = (1...500).map { "d\($0)" }
            // A real volume always has front matter, so the big compilation is *nearly* the whole
            // volume rather than exactly it. That distinction matters: a fixture with one section
            // and nothing else makes the container identical to the volume and the score exactly
            // the floor, which would pin a stronger claim than the corpus supports.
            let arrangement = VolumeArrangement(Self.structure([
                Self.section("front", divType: "front"),
                Self.section("comp1", docs: docs)
            ]))

            #expect(pairScore(arrangement, "d1", "d400") < 0.605)
            #expect(pairScore(arrangement, "d1", "d400") > 0.6)
            #expect(pairScore(arrangement, "d1", "d2") == 1.0, "adjacency is what rescues the volume")
            // A flat "same leaf section" rule would put this entire volume — and 57.96% of a real
            // candidate pool — into one bucket.
            for far in [100, 200, 300, 400] {
                #expect(pairScore(arrangement, "d1", "d\(far)") != 0.9)
            }
        }

        /// `max`, not a sum and not a product. A pair that is both tightly contained and adjacent
        /// makes one claim as strongly as it can make it, and cannot exceed the range.
        @Test("The two terms compose by max")
        func maxNotSum() {
            // Tight container AND adjacent: one claim, made as strongly as it can be made.
            let tight = VolumeArrangement(Self.structure([
                Self.section("comp1", subs: [Self.section("ch1", docs: ["d1", "d2"], divType: "chapter")]),
                Self.section("comp2", docs: (3...50).map { "d\($0)" })
            ]))
            #expect(pairScore(tight, "d1", "d2") == 1.0)

            // A strong container (≈0.85) with a weaker adjacency (2/3, two positions apart). The
            // container must win outright — a sum would land at ≈1.21, outside the range entirely.
            let both = VolumeArrangement(Self.structure([
                Self.section("ch1", docs: ["d1", "filler", "d2"], divType: "chapter"),
                Self.section("comp2", docs: (3...197).map { "d\($0)" })
            ]))
            #expect(both.totalUnits == 200)
            let containment = ProximityMath.narrowing(totalUnits: 200, containerUnits: 4)
            #expect(containment > 2.0 / 3, "the fixture must make containment the stronger term")
            #expect(abs(pairScore(both, "d1", "d2") - (0.6 + 0.4 * containment)) < 1e-12)
            #expect(pairScore(both, "d1", "d2") <= 1.0)
        }

        /// Two documents printed consecutively are neighbours in the book even when a chapter
        /// heading falls between them. Reading order is computed over the whole volume precisely so
        /// that population is not lost — it is about 2% of adjacent pairs, small but free.
        @Test("Adjacency crosses section boundaries")
        func adjacencyAcrossBoundaries() {
            let arrangement = VolumeArrangement(Self.structure([
                Self.section("ch1", docs: ["d1", "d2"], divType: "chapter"),
                Self.section("ch2", docs: ["d3", "d4"], divType: "chapter")
            ]))
            #expect(arrangement.ordinal(of: "d2") == 1)
            #expect(arrangement.ordinal(of: "d3") == 2)
            #expect(pairScore(arrangement, "d2", "d3") == 1.0,
                    "a within-section adjacency rule would structurally miss this pair")
        }

        /// 2,356 rows of `document_cache` (0.74%) are container quasi-documents whose id is a section
        /// id. Mapping section ids alongside document ids lifts placement coverage from 99.26% to
        /// 99.9987%; without it, every one of those documents would silently take the floor.
        @Test("Container quasi-documents resolve through their section id")
        func containerQuasiDocuments() {
            let arrangement = VolumeArrangement(Self.structure([
                // ch11 holds nothing but ch11subch1 — two units, the narrowest container there is.
                Self.section("ch11", subs: [Self.section("ch11subch1", divType: "subchapter")]),
                Self.section("ch12", docs: (2...40).map { "d\($0)" })
            ]))
            #expect(arrangement.section(holding: "ch11") != nil)
            #expect(arrangement.section(holding: "ch11subch1") != nil)
            // Containers are not entries in the reading sequence, so they earn no adjacency.
            #expect(arrangement.ordinal(of: "ch11") == nil)
            #expect(pairScore(arrangement, "ch11", "ch11subch1") == 1.0)
        }

        /// No such collision exists in the corpus today (0 across all 552 volumes). The tie-break is
        /// pinned so that if one ever appears, the real document wins its own id.
        @Test("A document id colliding with a section id resolves to the document")
        func collisionPrefersTheDocument() {
            let arrangement = VolumeArrangement(Self.structure([
                Self.section("ch1", docs: ["d1"], divType: "chapter"),
                Self.section("ch2", docs: ["ch1", "d2"], divType: "chapter")
            ]))
            let holder = try! #require(arrangement.section(holding: "ch1"))
            let sibling = try! #require(arrangement.section(holding: "d2"))
            #expect(holder == sibling, "the id must resolve to the document in ch2, not the section")
            #expect(arrangement.ordinal(of: "ch1") != nil, "a real document has a reading position")
        }

        /// The arrangement must never read `divType` or `title`. The live corpus carries 47 distinct
        /// `divType` values, and `VolumeSection.frontMatterKinds` contains `"section"` — which is
        /// also a body div type in nine volumes — so any kind-keyed filter misclassifies real
        /// content. Feeding the same tree twice under different names proves the measure ignores
        /// them.
        @Test("Scores do not depend on divType or title")
        func kindAgnostic() {
            let docs = (1...20).map { "d\($0)" }
            let plausible = VolumeArrangement(Self.structure([
                Self.section("a", subs: [Self.section("b", docs: docs, divType: "chapter")],
                             divType: "compilation")
            ]))
            let strange = VolumeArrangement(Self.structure([
                Self.section("a", subs: [Self.section("b", docs: docs, divType: "front")],
                             divType: "translation-of-the-memorandum")
            ]))
            #expect(plausible.totalUnits == strange.totalUnits)
            #expect(pairScore(plausible, "d1", "d15") == pairScore(strange, "d1", "d15"))
        }

        /// A parent always spans at least what its child spans. Verified exhaustively against the
        /// live corpus (19,877 child/parent pairs, zero violations), so a failure here means the
        /// builder is wrong rather than the data being odd.
        @Test("Containment grows monotonically toward the root")
        func containmentMonotonicity() {
            // Every section carries several documents so the chosen pairs are never within the
            // three-position adjacency window. A denser fixture makes every pair adjacent, and
            // adjacency then pins all four scores at 1.0 — masking the term under test.
            let arrangement = VolumeArrangement(Self.structure([
                Self.section("c1", docs: (1...5).map { "x\($0)" }, subs: [
                    Self.section("c1a", docs: (6...10).map { "x\($0)" }, subs: [
                        Self.section("c1a1", docs: (11...16).map { "x\($0)" }, divType: "subchapter")
                    ], divType: "chapter")
                ]),
                Self.section("c2", docs: (20...50).map { "x\($0)" })
            ]))
            // Siblings inside the deepest section, then progressively wider common ancestors.
            let deepest = pairScore(arrangement, "x11", "x16")
            let oneUp = pairScore(arrangement, "x11", "x6")
            let twoUp = pairScore(arrangement, "x11", "x1")
            let root = pairScore(arrangement, "x11", "x20")
            #expect(deepest > oneUp)
            #expect(oneUp > twoUp)
            #expect(twoUp > root)
            #expect(root == 0.6, "no shared section below the volume is the floor exactly")
        }

        /// The value the whole degradation story rests on. Both wrong answers are asserted by name,
        /// because a bare `== 0.6` reads as satisfied without saying which regression it guards.
        @Test("An unplaceable document takes the floor, not 1.0 and not 0")
        func unplaceableTakesTheFloor() {
            let arrangement = VolumeArrangement(Self.structure([
                Self.section("ch1", docs: ["d1", "d2"], divType: "chapter")
            ]))
            #expect(arrangement.section(holding: "d999") == nil)

            // What the scorer actually computes for a candidate it cannot place — in all three
            // ways placement can fail: no structure at all, and either side missing from one.
            #expect(pairScore(nil, "d1", "d2") == 0.6)
            #expect(pairScore(arrangement, "d1", "d999") == 0.6)
            #expect(pairScore(arrangement, "d999", "d1") == 0.6)
            let degraded = pairScore(arrangement, "d1", "d999")
            #expect(degraded == 0.6)
            #expect(degraded != 1.0, "1.0 would silently restore the pre-#562 flat behaviour")
            #expect(degraded != 0.0, "0 would strip the row's chip and drop it below the subseries tier")
            #expect(degraded > 0.5, "and it must still outrank a different volume in the same subseries")
        }

        @Test("An empty structure produces no placements and a zero unit count")
        func emptyStructure() {
            let arrangement = VolumeArrangement(Self.structure([]))
            #expect(arrangement.totalUnits == 0)
            #expect(arrangement.section(holding: "d1") == nil)
            // And the arithmetic downstream of it stays finite.
            #expect(ProximityMath.narrowing(totalUnits: 0, containerUnits: 0) == 0)
        }

        // MARK: Helpers

        /// The production rule itself — **not** a reimplementation of it.
        ///
        /// An earlier draft mirrored the composition here, and a mutation swapping the scorer's
        /// `max` for a `+` passed the whole suite: the tests were checking a copy. Calling
        /// `SubseriesScorer.sameVolumeScore` is what makes every assertion below binding.
        static func pairScore(_ arrangement: VolumeArrangement?, _ lhs: String, _ rhs: String) -> Double {
            SubseriesScorer.sameVolumeScore(anchorId: lhs, candidateId: rhs, arrangement: arrangement)
        }

        func pairScore(_ arrangement: VolumeArrangement?, _ lhs: String, _ rhs: String) -> Double {
            Self.pairScore(arrangement, lhs, rhs)
        }
    }

    // MARK: - Band separation and support parity

    @Suite("Bands")
    struct BandTests {

        /// The property that makes the whole change monotone-safe: the same-volume band lies
        /// entirely above the subseries tier, so no candidate can cross from one to the other.
        @Test("Same-volume never falls to or below the subseries tier")
        func bandsDoNotOverlap() {
            // Four volume shapes spanning what the corpus actually contains: flat, one deep, two
            // deep, and a wrapper chain. Every pair in every one of them, plus the degraded case.
            let shapes: [VolumeArrangement?] = [
                nil,                                                    // structure unreadable
                VolumeArrangement(ArrangementTests.structure([])),       // structure empty
                VolumeArrangement(ArrangementTests.structure([
                    ArrangementTests.section("c1", docs: (1...30).map { "d\($0)" })])),
                VolumeArrangement(ArrangementTests.structure([
                    ArrangementTests.section("c1", docs: ["d1"], subs: [
                        ArrangementTests.section("c1a", docs: (2...12).map { "d\($0)" },
                                                 divType: "chapter")]),
                    ArrangementTests.section("c2", docs: (13...30).map { "d\($0)" })]))
            ]
            let ids = (1...30).map { "d\($0)" } + ["c1", "c1a", "missing"]
            for shape in shapes {
                for lhs in ids {
                    for rhs in ids {
                        let score = ArrangementTests.pairScore(shape, lhs, rhs)
                        #expect(score >= 0.6, "same-volume dropped to \(score) for \(lhs)/\(rhs)")
                        #expect(score <= 1.0, "same-volume exceeded 1 at \(score) for \(lhs)/\(rhs)")
                        #expect(score > 0.5, "same-volume reached the subseries tier at \(score)")
                    }
                }
            }
        }

        /// The score must not depend on which document is the anchor. An anchor-relative
        /// denominator — the shape the original plan proposed — fails this immediately, and it
        /// matters because Project Leads sums this axis across many anchors.
        @Test("The score is symmetric in its two documents")
        func symmetry() {
            let arrangement = VolumeArrangement(ArrangementTests.structure([
                ArrangementTests.section("c1", docs: ["d1"], subs: [
                    ArrangementTests.section("c1a", docs: (2...12).map { "d\($0)" },
                                             divType: "chapter")]),
                ArrangementTests.section("c2", docs: (13...40).map { "d\($0)" })
            ]))
            for lhs in (1...40).map({ "d\($0)" }) {
                for rhs in (1...40).map({ "d\($0)" }) {
                    #expect(ArrangementTests.pairScore(arrangement, lhs, rhs)
                            == ArrangementTests.pairScore(arrangement, rhs, lhs),
                            "asymmetric for \(lhs)/\(rhs)")
                }
            }
        }

        /// Support parity. The branch *predicates* are untouched, so the set of candidates scoring
        /// above 0 is identical to before — and the ranker's only thresholds are `score > 0` and
        /// `total > 0`. That is what proves no row enters or leaves the result list and no "why
        /// related" chip appears or disappears; only the ordering within the same-volume group can
        /// change.
        @Test("Every candidate that scored above 0 before still does")
        func supportParity() {
            // The old rule, reimplemented literally.
            func old(sameVolume: Bool, sameSubseries: Bool) -> Double {
                if sameVolume { return 1.0 }
                if sameSubseries { return 0.5 }
                return 0
            }
            for sameVolume in [true, false] {
                for sameSubseries in [true, false] {
                    let before = old(sameVolume: sameVolume, sameSubseries: sameSubseries)
                    // The worst case a same-volume candidate can reach: unplaceable entirely.
                    let after: Double = sameVolume
                        ? ArrangementTests.pairScore(nil, "d1", "d2")
                        : (sameSubseries ? 0.5 : 0)
                    #expect((before > 0) == (after > 0),
                            "support changed for sameVolume=\(sameVolume) sameSubseries=\(sameSubseries)")
                    #expect(after <= before, "the change must be one-sided; \(after) > \(before)")
                }
            }
        }
    }

    // MARK: - Persistence format

    @Suite("Persistence")
    struct PersistenceTests {

        /// `SimilarityAxis`'s rawValues are a storage format, not an implementation detail, and
        /// nothing else pins them: the existing suite asserts `allCases.count == 6` and round-trips
        /// `rawValue` against itself, both of which a rename passes.
        ///
        /// The tokens appear in the UserDefaults axis-weight string, in the CloudKit-mirrored
        /// `Project.leadAxisWeights`, and in the `Hashable` identity of a find-related window.
        /// `AxisWeights.init?(rawValue:)` skips tokens it does not recognise and no read path merges
        /// defaults — so renaming a case ships as a silent weight of 0 for every user who has moved
        /// the slider, compiles clean, and leaves the suite green. #562 renamed the axis's
        /// *display name* for exactly this reason.
        @Test("The axis rawValues are frozen")
        func rawValuesAreFrozen() {
            #expect(SimilarityAxis.allCases.map(\.rawValue) == [
                "archivalProvenance", "crossReference", "dateProximity",
                "subseries", "sharedPersons", "sharedSubjects",
                // V-3. APPENDED, never inserted: `allCases` order is this list's order, and a
                // reordering would read here as a rename — which is the one thing the test exists
                // to catch, because a renamed token ships as a silent zero weight.
                "semanticSimilarity",
                // W-17 session 2, appended under the same rule.
                "lexicalSimilarity",
            ])
        }

        /// The rename this change *did* make. The display name is presentational at all three call
        /// sites, so it is the safe half of the pair.
        @Test("The axis presents as corpus proximity")
        func displayName() {
            #expect(SimilarityAxis.subseries.displayName == "Corpus proximity")
            #expect(SimilarityAxis.subseries.rawValue == "subseries")
        }
    }

    // MARK: - Scorer wiring

    /// The parts of `SubseriesScorer` a pure-math test cannot reach.
    ///
    /// Scoring a real candidate needs a live index, so the fetch discipline and the degradation
    /// value — the two places where a plausible-looking edit does the most damage — have no runtime
    /// oracle in this bundle. A source audit is the cheap mechanical answer, in the same style as
    /// `ProjectLeadSnippetTests`.
    @Suite("Scorer wiring")
    struct WiringTests {

        static func source(_ path: String) throws -> String {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
            return text
        }

        /// One fetch per call, for the anchor's volume, outside the candidate loop.
        ///
        /// Every same-volume candidate is by construction in the anchor's volume, so a structure
        /// fetch inside the loop would be a redundant primary-key hit and JSON decode per candidate
        /// — up to 240 of them per call, 40 times per Project Leads recompute. It would still be
        /// *correct*, which is why no assertion about scores would ever catch it.
        /// `SubseriesScorer`'s own executable lines, with comments stripped.
        ///
        /// Both narrowings are necessary: the file holds four scorers that each loop over
        /// `candidates`, and the doc comments deliberately *name* `cachedVolumeStructure` several
        /// times to explain the fetch discipline. A whole-file substring search reads those
        /// explanations as call sites and the other scorers' loops as this one's.
        static func scorerCode() throws -> String {
            let file = try Self.source("FRUSExplorer/RelatedDocuments/SimilarityScorers.swift")
            let start = try #require(file.range(of: "struct SubseriesScorer")).lowerBound
            let rest = file[start...]
            let end = rest.range(of: "\n// MARK: -")?.lowerBound ?? rest.endIndex
            return rest[..<end]
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
        }

        @Test("The structure is fetched once, for the anchor's volume, outside the loop")
        func fetchDiscipline() throws {
            let code = try Self.scorerCode()
            let calls = code.components(separatedBy: "cachedVolumeStructure").count - 1
            #expect(calls == 1, "expected exactly one cachedVolumeStructure call site, found \(calls)")
            #expect(code.contains("forVolumeId: anchor.volumeId"),
                    "the fetch must name the anchor's volume, never a candidate's")

            // The call must precede the loop that consumes it.
            let fetchIndex = try #require(code.range(of: "cachedVolumeStructure")).lowerBound
            let loopIndex = try #require(code.range(of: "for candidate in candidates")).lowerBound
            #expect(fetchIndex < loopIndex, "the structure fetch moved inside the candidate loop")
        }

        /// A throw escaping the scorer is the worst available outcome and the hardest to notice:
        /// `RelatedDocumentsEngine` coalesces it to `[:]`, so the axis silently contributes nothing
        /// for *every* candidate and the panel simply looks a little different.
        @Test("The structure fetch cannot throw out of the scorer")
        func fetchCannotThrow() throws {
            let scorer = try Self.scorerCode()
            #expect(scorer.contains("try? await pipeline.cachedVolumeStructure"),
                    "the fetch must be `try?` — the engine coalesces a throw to no contribution")

            let engine = try Self.source("FRUSExplorer/RelatedDocuments/RelatedDocumentsEngine.swift")
            #expect(engine.contains("(try? await scorer.scores("),
                    "the premise above changed: the engine no longer swallows a scorer throw")
        }

        /// The degradation value, asserted where it is actually written. `sameVolumeFloor` being
        /// 0.6 is pinned by the pure-math suite; that the *unplaceable* branch uses it is not
        /// visible from anywhere else.
        /// The degradation *value* is asserted for real by `unplaceableTakesTheFloor`, which calls
        /// `sameVolumeScore` directly. This only guards the one thing that test cannot see: that
        /// the scorer still routes same-volume candidates through that function rather than
        /// recomputing the rule inline, where it would drift out from under every assertion.
        @Test("The scorer delegates the same-volume rule rather than recomputing it")
        func delegatesTheRule() throws {
            let code = try Self.scorerCode()
            #expect(code.contains("Self.sameVolumeScore("),
                    "the same-volume branch must go through the pure, tested function")
            #expect(!code.contains("scores[candidate] = 1.0"),
                    "no same-volume candidate may be scored a flat 1.0 any more")
        }
    }
}
