// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import SwiftUI
import Foundation
@testable import FRUSExplorer

// MARK: - ProvenanceChipTests

/// The chip that says where a value came from (PV-2).
///
/// **The headline test is `meaningSurvivesTheLossOfColour`.** Everything else here supports it: the
/// wave's whole claim is that a reader can tell a FRUS fact from a joined one from a computed one,
/// and a chip that made that distinction in hue alone would be making it for some readers only.
///
/// Version history:
///   1.0 — PV-2: initial implementation
@Suite("Provenance chip")
struct ProvenanceChipTests {

    // MARK: - The property the whole wave rests on

    /// Strip the colour channel and the tier is still readable — in shape, and in words.
    ///
    /// Stated as one test rather than three because it is one claim: under
    /// `accessibilityDifferentiateWithoutColor` every tier shares a foreground (the hue is gone)
    /// while every tier keeps its own glyph and every source keeps its own label (the meaning is
    /// not).
    @Test("Meaning survives the loss of colour")
    func meaningSurvivesTheLossOfColour() {
        let tiers = ProvenanceTier.allCases
        #expect(tiers.count == 3)

        // The hue is gone: one foreground for all three.
        for tier in tiers {
            #expect(ProvenanceChip.foreground(for: tier, differentiateWithoutColor: true)
                    == Color.primary)
        }

        // The shape is not: three tiers, three glyphs.
        #expect(Set(tiers.map { ProvenanceChip.glyph(for: $0) }).count == tiers.count)

        // Nor are the words: eight sources, and no two share a label.
        let labels = ProvenanceSource.allCases.map(\.label)
        #expect(labels.count == 8)
        #expect(Set(labels).count == labels.count)
    }

    // MARK: - The shape channel

    /// The glyph does **not** switch on the environment key, unlike `WordCloudView`'s dots.
    ///
    /// There the shape is meaningless until the key is set; here it always carries the tier, so a
    /// swap would be theatre — and, worse, would imply the unswitched chip needed colour.
    @Test("The glyph is unconditional")
    func glyphDoesNotDependOnTheEnvironment() {
        // The signature is the assertion: a glyph that varied with the reader's settings could not
        // be produced by a function that never sees them.
        for tier in ProvenanceTier.allCases {
            #expect(!ProvenanceChip.glyph(for: tier).isEmpty)
        }
        #expect(ProvenanceChip.glyph(for: .frusOnly) == "square.fill")
        #expect(ProvenanceChip.glyph(for: .joined) == "triangle.fill")
        #expect(ProvenanceChip.glyph(for: .computed) == "circle.fill")
    }

    // MARK: - The colour channel

    /// With no accessibility request in play, each tier keeps its own hue.
    @Test("Each tier has its own tint when colour is available")
    func tintsAreDistinct() {
        let tints = ProvenanceTier.allCases.map { ProvenanceChip.tint(for: $0) }
        #expect(tints[0] != tints[1])
        #expect(tints[1] != tints[2])
        #expect(tints[0] != tints[2])
        for tier in ProvenanceTier.allCases {
            #expect(ProvenanceChip.foreground(for: tier, differentiateWithoutColor: false)
                    == ProvenanceChip.tint(for: tier))
        }
    }

    /// The key reaches the wash and the hairline too, not only the label.
    ///
    /// A chip that neutralised its text but kept a tinted capsule would still be asking a reader to
    /// read three hues.
    @Test("The environment key reaches the fill and the border")
    func fillAndBorderFollowTheKey() {
        for tier in ProvenanceTier.allCases {
            #expect(ProvenanceChip.fill(for: tier, differentiateWithoutColor: true)
                    != ProvenanceChip.fill(for: tier, differentiateWithoutColor: false))
            #expect(ProvenanceChip.border(for: tier, differentiateWithoutColor: true)
                    != ProvenanceChip.border(for: tier, differentiateWithoutColor: false))
        }
        // And once neutralised, the three tiers are indistinguishable by capsule — which is the
        // point: the distinction has moved entirely to the glyph and the label.
        let fills = ProvenanceTier.allCases.map {
            ProvenanceChip.fill(for: $0, differentiateWithoutColor: true)
        }
        #expect(fills[0] == fills[1])
        #expect(fills[1] == fills[2])
    }

    // MARK: - The VoiceOver channel

    /// Every source says something, and no source says nothing.
    @Test("Every source has a spoken sentence")
    func everySourceSpeaks() {
        var seen = 0
        for source in ProvenanceSource.allCases {
            let spoken = ProvenanceChip.accessibilityLabel(for: source)
            #expect(!spoken.isEmpty)
            #expect(spoken.hasPrefix("Source: "))
            #expect(!spoken.contains("%@"), "unsubstituted format in \(source.rawValue)")
            seen += 1
        }
        #expect(seen == 8)
    }

    /// A joined chip names what it was joined to, because that is the half of the sentence the
    /// reader is about to write.
    @Test("A joined chip names its partner")
    func joinedChipsNameThePartner() {
        let joined: [ProvenanceSource] = [.naraCatalog, .ohPeopleRegister, .ohSubjects,
                                          .stateDeptSchedule]
        for source in joined {
            let spoken = ProvenanceChip.accessibilityLabel(for: source)
            #expect(spoken.contains(source.partnerName), "\(source.rawValue) dropped its partner")
            #expect(spoken.contains("joined to"))
        }
        // Four partners, four distinct sentences — a shared one would tell a reader they had joined
        // to something the value never touched.
        #expect(Set(joined.map { ProvenanceChip.accessibilityLabel(for: $0) }).count == 4)
    }

    /// The reader's own work is never described as the app's output.
    ///
    /// `yourReading` sits in the computed tier while being deliberately outside the provenance
    /// family, so a per-*tier* sentence — which is what the plan specified — would read "computed by
    /// this app" over somebody's own highlight.
    @Test("Your own reading is not called a computation")
    func yourReadingIsNotAttributedToTheApp() {
        let mine = ProvenanceChip.accessibilityLabel(for: .yourReading)
        let computed = ProvenanceChip.accessibilityLabel(for: .appModel)
        #expect(mine != computed)
        #expect(!mine.lowercased().contains("computed"))
        #expect(!mine.lowercased().contains("this app"))
        #expect(mine.lowercased().contains("your own"))
        // The tier really is shared — this test would be vacuous if it were not.
        #expect(ProvenanceSource.yourReading.tier == ProvenanceSource.appModel.tier)
    }

    /// The two computed sources share a sentence on purpose: a reader cites both the same way.
    @Test("The two computed sources share one sentence")
    func computedSourcesShareASentence() {
        #expect(ProvenanceChip.accessibilityLabel(for: .appWordLists)
                == ProvenanceChip.accessibilityLabel(for: .appModel))
    }

    // MARK: - Wiring

    /// The body must render the shared rules rather than spelling its own.
    ///
    /// A narrow scan of the two calls, not of the file: this exists because every rule above is a
    /// static function, which a `body` could ignore entirely while the suite stayed green.
    @Test("The body renders through the shared rules")
    func bodyCallsTheSharedRules() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Provenance/ProvenanceChip.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        guard let body = source.range(of: "var body: some View {") else {
            Issue.record("ProvenanceChip has no body")
            return
        }
        let rendered = String(source[body.lowerBound...])
        for call in ["Self.glyph(for: source.tier)",
                     "Self.accessibilityLabel(for: source)",
                     "Self.foreground(for: source.tier,",
                     "Self.fill(for: source.tier,",
                     "Self.border(for: source.tier,"] {
            #expect(rendered.contains(call), "body does not call \(call)")
        }
        // The environment key is read once, in the property, and never re-derived in the body.
        #expect(source.contains("@Environment(\\.accessibilityDifferentiateWithoutColor)"))

        // **`.ignore` is what makes the spoken sentence reachable at all, and it must come first.**
        // The chip's glyph is an `Image(systemName:)`, which is itself an accessibility element and
        // speaks its SF Symbol name — so without this modifier VoiceOver reads "square fill, FRUS
        // text" and the sentence below never applies. `.combine` would not do either, for the same
        // reason; `LensChip` gets away with `.combine` only because its glyph is a bare `Circle()`,
        // a Shape that contributes nothing. And the order is semantic rather than stylistic:
        // `.ignore` discards the inner content's accessibility, so a label applied ahead of it is
        // dropped.
        let ignore = "accessibilityElement(children: .ignore)"
        guard let ignoreAt = rendered.range(of: ignore),
              let labelAt = rendered.range(of: "accessibilityLabel(Self.accessibilityLabel") else {
            Issue.record("the chip does not collapse its children before labelling them")
            return
        }
        #expect(ignoreAt.lowerBound < labelAt.lowerBound,
                "the label is applied before the children are ignored, so it is discarded")
    }
}
