// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
import CoreGraphics
@testable import FRUSExplorer

/// The shipped Word Cloud must not move when the onboarding backdrop extends the layout
/// engine.
///
/// O-2 adds `exclusionZones`, `yCompression` and `sizeExponent` to `WordCloudLayout.place`.
/// The workstream guardrail is that every one of them defaults to the shipped behaviour —
/// this suite is how that is enforced rather than asserted. The Word Cloud is a feature
/// researchers already use and compare across scopes; a silently reshuffled cloud would be
/// a regression nobody reported because nobody could prove it.
///
/// Placements are compared exactly, not approximately. The packer is deterministic
/// geometry, so "close enough" would let a real drift through.
///
/// Version history:
///   1.0 — O-2: initial implementation
@Suite("Word Cloud — layout regression across the O-2 extension")
struct WordCloudLayoutRegressionTests {

    /// A term set with the shape the packer actually meets: a steep head, a long flat
    /// tail, mixed word lengths, and enough entries to force both rotation and give-up.
    private var terms: [TermCount] {
        let head = [("negotiation", 940), ("treaty", 812), ("soviet", 733), ("missile", 690),
                    ("president", 612), ("agreement", 588), ("security", 502), ("policy", 466)]
        let tail = (0..<70).map { ("term\($0)", max(1, 120 - $0)) }
        return (head + tail).map { TermCount(term: $0.0, count: $0.1) }
    }

    private let canvases: [CGSize] = [
        CGSize(width: 390, height: 640),    // iPhone portrait
        CGSize(width: 834, height: 520),    // iPad / mac card
        CGSize(width: 320, height: 320),    // small square — forces give-ups
    ]

    // MARK: - Defaults preserve the shipped behaviour

    @Test("New parameters at their defaults place identically to omitting them")
    func defaultsMatchOmittingTheParameters() {
        for size in canvases {
            let omitted = WordCloudLayout.place(terms: terms, in: size)
            let explicit = WordCloudLayout.place(
                terms: terms, in: size,
                exclusionZones: [], yCompression: 1, sizeExponent: nil
            )
            #expect(omitted.count == explicit.count)
            for (a, b) in zip(omitted, explicit) {
                #expect(a.term == b.term)
                #expect(a.center == b.center)
                #expect(a.fontSize == b.fontSize)
                #expect(a.rotationDegrees == b.rotationDegrees)
                #expect(a.colorIndex == b.colorIndex)
            }
        }
    }

    @Test("sizeExponent: nil is the square-root scale, bit for bit")
    func nilExponentIsExactlySqrt() {
        // `pow(t, 0.5)` and `sqrt(t)` are mathematically equal but can differ in the last
        // bit, and a one-ulp font size can move a word to a different spiral slot. That is
        // why the parameter is `CGFloat?` rather than defaulting to `0.5` — this pins it.
        for count in stride(from: 1, through: 1000, by: 7) {
            let shipped = WordCloudLayout.fontSize(for: count, minCount: 1, maxCount: 1000,
                                                   minFontSize: 13, maxFontSize: 64)
            let t = max(0, min(1, CGFloat(count - 1) / CGFloat(999)))
            #expect(shipped == 13 + (64 - 13) * sqrt(t))
        }
    }

    @Test("Placement is deterministic run to run")
    func placementIsDeterministic() {
        for size in canvases {
            let first = WordCloudLayout.place(terms: terms, in: size)
            for _ in 0..<5 {
                let again = WordCloudLayout.place(terms: terms, in: size)
                #expect(first.map(\.term) == again.map(\.term))
                #expect(first.map(\.center) == again.map(\.center))
            }
        }
    }

    @Test("The fixture actually exercises the packer")
    func fixtureIsNotVacuous() {
        // Every assertion above compares two placement arrays; two empty arrays are equal.
        let placed = WordCloudLayout.place(terms: terms, in: canvases[0])
        #expect(placed.count > 20, "too few placements to be a meaningful regression fixture")
        #expect(placed.contains { $0.rotationDegrees == 90 }, "no rotated words — the rotation path is untested")
        #expect(Set(placed.map(\.fontSize)).count > 5, "font sizes barely vary — the size curve is untested")
    }

    // MARK: - The new parameters do something

    @Test("Exclusion zones are respected, and only they change")
    func exclusionZonesKeepWordsOut() {
        let size = canvases[1]
        // The shape the splash needs: a centre block for the identity stack.
        let zone = CGRect(x: size.width / 2 - 140, y: size.height / 2 - 90, width: 280, height: 180)
        let placed = WordCloudLayout.place(terms: terms, in: size, exclusionZones: [zone])

        #expect(!placed.isEmpty)
        for word in placed {
            // Reconstruct the word's box from its centre and estimated extent. The packer
            // places on estimated boxes, so this is the same geometry it tested.
            let height = word.fontSize * 1.25
            let width = CGFloat(word.term.count) * word.fontSize * 0.54 + word.fontSize * 0.4
            let box = CGRect(x: word.center.x - (word.rotationDegrees == 90 ? height : width) / 2,
                             y: word.center.y - (word.rotationDegrees == 90 ? width : height) / 2,
                             width: word.rotationDegrees == 90 ? height : width,
                             height: word.rotationDegrees == 90 ? width : height)
            #expect(!box.intersects(zone), "\(word.term) overlaps the exclusion zone")
        }
    }

    @Test("yCompression flattens the field")
    func yCompressionFlattensTheField() {
        let size = canvases[1]
        let normal = WordCloudLayout.place(terms: terms, in: size)
        let flat = WordCloudLayout.place(terms: terms, in: size, yCompression: 0.62)

        func verticalSpread(_ words: [PlacedWord]) -> CGFloat {
            guard let lo = words.map(\.center.y).min(), let hi = words.map(\.center.y).max() else { return 0 }
            return hi - lo
        }
        #expect(verticalSpread(flat) < verticalSpread(normal))
        #expect(!flat.isEmpty)
    }

    @Test("sizeExponent 1.45 suppresses the tail relative to sqrt")
    func steeperExponentSuppressesTheTail() {
        // The hand-off's curve is steeper than sqrt, so a mid-ranked term must come out
        // SMALLER, letting a few head terms dominate a full-bleed field.
        let mid = WordCloudLayout.fontSize(for: 500, minCount: 1, maxCount: 1000,
                                           minFontSize: 12, maxFontSize: 42)
        let steep = WordCloudLayout.fontSize(for: 500, minCount: 1, maxCount: 1000,
                                             minFontSize: 12, maxFontSize: 42, sizeExponent: 1.45)
        #expect(steep < mid)
        // The endpoints must still pin to the range, whatever the curve.
        #expect(WordCloudLayout.fontSize(for: 1000, minCount: 1, maxCount: 1000,
                                         minFontSize: 12, maxFontSize: 42, sizeExponent: 1.45) == 42)
        #expect(WordCloudLayout.fontSize(for: 1, minCount: 1, maxCount: 1000,
                                         minFontSize: 12, maxFontSize: 42, sizeExponent: 1.45) == 12)
    }
}
