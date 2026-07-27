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
import SwiftUI
@testable import FRUSExplorer

/// Does the drift canvas actually draw anything?
///
/// ## Why this is a separate suite from the motion tests
/// `WordCloudDriftFieldTests` proves the arithmetic. It would pass in full while the screen
/// stayed completely empty, because it never renders.
///
/// And empty is the realistic failure. `Canvas`'s symbol lookup keys on the tag's **static
/// type** as well as its value: tag a view `.tag(0)` as an `Int` and ask for it with an
/// enum whose raw value is 0, and `resolveSymbol(id:)` returns nil — for every particle,
/// with no crash, no warning and no log. Behind an indexing banner's `.bar` material, a
/// cloud that draws nothing looks exactly like a cloud that has not loaded yet. Nobody
/// would file that as a bug; it would just quietly never work.
///
/// So these render real frames off-screen and count pixels.
///
/// Version history:
///   1.0 — P-1: initial implementation
@Suite("Word cloud — drift rendering")
@MainActor
struct WordCloudDriftRenderTests {

    private let size = CGSize(width: 400, height: 140)

    /// A snapshot with two lenses of real-looking words.
    private func makeSnapshot() -> WordCloudDriftCanvas.Snapshot {
        func layer(_ lens: WordCloudLens, terms: [String]) -> WordCloudDriftCanvas.Snapshot.Layer {
            let placed = terms.enumerated().map { rank, term in
                PlacedWord(term: term, count: 500 - rank * 20,
                           center: CGPoint(x: 60 + CGFloat(rank % 3) * 130,
                                           y: 35 + CGFloat(rank / 3) * 40),
                           fontSize: 30 - CGFloat(rank) * 2,
                           colorIndex: rank, rotationDegrees: 0)
            }
            let field = WordCloudDriftField(placed: placed, rankCeiling: 25)
            var colors: [String: Color] = [:]
            var sizes: [String: CGFloat] = [:]
            for word in placed {
                colors[word.term] = .primary
                sizes[word.term] = word.fontSize * WordCloudDriftField.maximumScale
            }
            return .init(lens: lens, field: field, colors: colors, symbolFontSizes: sizes)
        }
        return .init(layers: [layer(.concepts, terms: ["policy", "treaty", "aid", "trade", "security", "talks"]),
                              layer(.topics, terms: ["berlin", "cuba", "vietnam", "cairo", "moscow", "paris"])],
                     size: size)
    }

    /// Renders one frame and returns the fraction of pixels that are not transparent.
    private func inkFraction(at date: Date, reduceMotion: Bool = false) throws -> (ink: Double, image: CGImage) {
        let view = WordCloudDriftCanvasFrame(snapshot: makeSnapshot(), dim: 1.0,
                                             reduceMotion: reduceMotion, date: date)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "ImageRenderer produced no image at all")

        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var inked = 0
        for index in stride(from: 3, to: pixels.count, by: 4) where pixels[index] > 8 { inked += 1 }
        return (Double(inked) / Double(width * height), image)
    }

    // MARK: - Tests

    @Test("The canvas draws words — a symbol-key mismatch would render nothing at all")
    func canvasIsNotBlank() throws {
        let (ink, _) = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 100))
        #expect(ink > 0.01,
                "only \(String(format: "%.3f%%", ink * 100)) of pixels were inked — if this is ~0, resolveSymbol is returning nil for every particle")
        #expect(ink < 0.95, "and it must not be a solid fill either")
    }

    /// The exact A/B counterpart of `reduceMotionFreezesDrift`: identical instants, opposite
    /// expectations. That pairing is the oracle — one of them must fail for any change that
    /// freezes or unfreezes the drift.
    ///
    /// The first version sampled t=100 and t=102 and claimed they were "well inside one lens
    /// hold". They are not: with cadence 4.2 the boundary falls at t=100.8, so the two
    /// frames held *disjoint word sets* and differed enormously for reasons having nothing
    /// to do with motion. It would have passed against a completely dead motion model.
    @Test("Successive instants render differently — the field is actually moving")
    func framesDifferOverTime() throws {
        let (early, late) = Self.twoInstantsInOneHold
        let a = try inkFraction(at: Date(timeIntervalSinceReferenceDate: early)).image
        let b = try inkFraction(at: Date(timeIntervalSinceReferenceDate: late)).image
        #expect(try differingPixelFraction(a, b) > 0.005,
                "two instants inside one lens hold produced near-identical frames — the drift is not animating")
    }

    /// Guards the guard: if the cadence is ever re-tuned, these two instants could drift
    /// across a lens boundary again and silently turn `framesDifferOverTime` back into a
    /// test of nothing.
    @Test("The A/B instants really are inside one settled lens hold")
    func abInstantsShareALensHold() {
        let (early, late) = Self.twoInstantsInOneHold
        let a = WordCloudDriftCanvas.cycle(at: early, layerCount: 2)
        let b = WordCloudDriftCanvas.cycle(at: late, layerCount: 2)
        #expect(a.incoming == b.incoming, "the sampled instants straddle a lens change")
        #expect(a.progress == 1 && b.progress == 1, "and both must be past the crossfade")
    }

    /// Both inside hold 24 (100.8...105.0) and past its crossfade (ends 101.95).
    private static let twoInstantsInOneHold: (Double, Double) = (102.5, 104.5)

    /// Two claims, and they pull in opposite directions — which is why the first draft got
    /// this wrong by conflating them. Reduce Motion must freeze the *drift* while leaving
    /// the *lens rotation* running: the house rule is to simplify a transition, not to
    /// delete it, and the static renderer keeps cycling lenses under Reduce Motion too.
    @Test("Reduce Motion freezes the drift within a lens hold")
    func reduceMotionFreezesDrift() throws {
        // Both instants sit inside the settled part of the same hold: cadence 4.2 puts
        // hold 24 at 100.8...105.0, and its crossfade ends at 100.8 + 1.15 = 101.95.
        let a = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 102.5), reduceMotion: true).image
        let b = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 104.5), reduceMotion: true).image
        #expect(try differingPixelFraction(a, b) < 0.0005,
                "particles must be pinned, not merely paused — a paused schedule freezes an arbitrary mid-drift pose")
    }

    @Test("...but Reduce Motion still rotates through the lenses")
    func reduceMotionStillRotatesLenses() throws {
        // Settled inside two consecutive holds, which show different lenses.
        let a = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 102.5), reduceMotion: true).image
        let b = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 106.7), reduceMotion: true).image
        #expect(try differingPixelFraction(a, b) > 0.01,
                "pinning both clocks together left a Reduce Motion user looking at one lens of four, forever")
    }

    @Test("Motion is genuinely frozen — not merely slow — under Reduce Motion")
    func reduceMotionIsNotJustSlow() throws {
        // Same phase within two holds four cadences apart: same lens, so any difference is
        // drift that failed to freeze.
        let cadence = FRUSTheme.cloudLensCadence
        let a = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 102.5), reduceMotion: true).image
        let b = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 102.5 + cadence * 4), reduceMotion: true).image
        #expect(try differingPixelFraction(a, b) < 0.0005)
    }

    /// Renamed from `inkStaysWithinBounds`, which is not what it did. Its comment claimed
    /// that an escaping word would "saturate the edge columns", but nothing in it inspected
    /// edge columns or any spatial distribution — the single assertion was total ink, a
    /// weaker restatement of `canvasIsNotBlank` at twelve instants instead of one. Clipping
    /// is subtractive anyway, so an escaped word *lowers* ink rather than saturating
    /// anything. Bounds are covered where they can actually be measured: in the model, by
    /// `particlesStayInsideTheCanvas` and `rotatedWordExtentsAreSwapped`.
    ///
    /// What it does check is still worth having — that no instant of the cycle, including
    /// mid-crossfade, renders an empty or near-empty frame.
    @Test("Every instant of the cycle renders something")
    func everyInstantRendersSomething() throws {
        for offset in stride(from: 0.0, to: 40.0, by: 3.5) {
            let (ink, _) = try inkFraction(at: Date(timeIntervalSinceReferenceDate: 100 + offset))
            #expect(ink > 0.005, "frame at +\(offset)s rendered almost nothing")
        }
    }

    // MARK: - Helpers

    private func differingPixelFraction(_ a: CGImage, _ b: CGImage) throws -> Double {
        #expect(a.width == b.width && a.height == b.height)
        func bytes(_ image: CGImage) throws -> [UInt8] {
            var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try #require(CGContext(
                data: &buffer, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return buffer
        }
        let (x, y) = (try bytes(a), try bytes(b))
        var differing = 0
        for index in stride(from: 0, to: x.count, by: 4) where abs(Int(x[index + 3]) - Int(y[index + 3])) > 8 {
            differing += 1
        }
        return Double(differing) / Double(a.width * a.height)
    }
}
