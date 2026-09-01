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

import Foundation
import Metal
import Testing
import CoreGraphics
import SwiftUI
@testable import FRUSExplorer

/// Whether this host has a GPU at all — the suite is *disabled* rather than failed without one,
/// the same posture `SemanticMapSurfaceTests` states: a machine without Metal is a real
/// condition, and a red suite there would say something false about the export.
private let offscreenHasMetal = MTLCreateSystemDefaultDevice() != nil

/// The offscreen figure path (W-3 / #1007) — the design's §6 Phase-1 table, one test per trap.
///
/// Every trap here fails SILENTLY into an image that looks like a map, which is why each is a
/// pixel-level assertion over a real render rather than an arithmetic check: the design notes
/// that the arithmetic suite "would pass in full while the screen stayed black."
///
/// Version history:
///   1.0 — W-3 (#1007): initial implementation
@Suite("Semantic map offscreen export", .serialized)
struct SemanticMapOffscreenTests {

    // MARK: - Fixtures

    /// A renderer with a small known point set framed by the camera. Bright, fully opaque
    /// palette slot 0 so lit pixels are unmistakable against any background.
    @MainActor
    private func makeRenderer(points: [SemanticMapRenderer.MapPoint],
                              extent: Float = 100) -> SemanticMapRenderer? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = SemanticMapRenderer(device: device) else { return nil }
        renderer.setPalette([SIMD4<Float>(1, 1, 1, 1)])
        renderer.setPoints(points)
        renderer.frameAll(extent: extent)
        return renderer
    }

    private func point(_ x: Int16, _ y: Int16) -> SemanticMapRenderer.MapPoint {
        SemanticMapRenderer.MapPoint(position: SIMD2<Int16>(x, y), colourIndex: 0, flags: 0)
    }

    /// Reads a `CGImage` back as RGBA8 rows for pixel assertions.
    private func pixels(of image: CGImage) -> (data: [UInt8], width: Int, height: Int)? {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (data, width, height)
    }

    /// Pixels meaningfully brighter than the dark map background.
    private func litPixels(of image: CGImage) -> [(x: Int, y: Int)] {
        guard let (data, width, height) = pixels(of: image) else { return [] }
        var lit: [(Int, Int)] = []
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                if data[i] > 90 || data[i + 1] > 90 || data[i + 2] > 90 {
                    lit.append((x, y))
                }
            }
        }
        return lit
    }

    // MARK: - The six traps

    @Test("A known point set renders lit pixels — the blank-plate failure",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func rendersNonBackgroundPixels() throws {
        let renderer = try #require(makeRenderer(points: [point(0, 0), point(50, 50),
                                                          point(-50, -50)]))
        renderer.pointSize = 6
        let image = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 400, height: 300), supersample: 1))
        #expect(image.width == 400 && image.height == 300)
        #expect(!litPixels(of: image).isEmpty)
    }

    @Test("Trap 1: the dot subtends the same fraction of the frame at every plate size",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func pointSizeScalesWithPlate() throws {
        let renderer = try #require(makeRenderer(points: [point(0, 0)]))
        renderer.pointSize = 6
        let small = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 200, height: 200), supersample: 1))
        let large = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 400, height: 400), supersample: 1))
        let smallArea = litPixels(of: small).count
        let largeArea = litPixels(of: large).count
        #expect(smallArea > 0)
        // Twice the plate → ~4× the dot's pixel area. Without the height-ratio scaling the
        // sprite stays at its on-screen pixel size and this ratio collapses toward 1 — the
        // "dramatically sparser but perfectly plausible" figure the design warns about.
        let ratio = Double(largeArea) / Double(max(1, smallArea))
        #expect(ratio > 2.5 && ratio < 6.0, "area ratio \(ratio)")
    }

    @Test("Trap 2: aspect comes from the export texture — a grid square stays square",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func aspectFromTexture() throws {
        // Four points at the corners of a grid square. If the export reused the stored
        // view aspect (1.0) for a 600×300 plate, the square would render 2× as wide as tall.
        let renderer = try #require(makeRenderer(
            points: [point(-40, -40), point(40, -40), point(-40, 40), point(40, 40)]))
        renderer.pointSize = 6
        let image = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 600, height: 300), supersample: 1))
        let lit = litPixels(of: image)
        let xs = lit.map(\.x), ys = lit.map(\.y)
        let width = Double((xs.max() ?? 0) - (xs.min() ?? 0))
        let height = Double((ys.max() ?? 0) - (ys.min() ?? 0))
        #expect(height > 0)
        let squareness = width / max(1, height)
        #expect(squareness > 0.85 && squareness < 1.15, "bounding box ratio \(squareness)")
    }

    @Test("Trap 3: the shader path and the label layer agree at export geometry",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func labelLayerAgreesWithShader() throws {
        // One off-centre point; its lit centroid must land where the label layer projects
        // the same grid coordinate at the same export rectangle. This is the design's
        // "single highest-value test": on screen the two layers measure one shared rectangle
        // and their agreement is a construction — in export it is only this test.
        let grid = SIMD2<Float>(37, -21)
        let renderer = try #require(makeRenderer(
            points: [point(Int16(grid.x), Int16(grid.y))]))
        renderer.pointSize = 6
        let plate = CGSize(width: 500, height: 400)
        let image = try #require(renderer.renderOffscreen(pixelSize: plate, supersample: 1))
        let lit = litPixels(of: image)
        let centroid = CGPoint(
            x: CGFloat(lit.map(\.x).reduce(0, +)) / CGFloat(max(1, lit.count)),
            y: CGFloat(lit.map(\.y).reduce(0, +)) / CGFloat(max(1, lit.count)))
        let projected = SemanticMapLabelLayout.project(grid, camera: renderer.camera, size: plate)
        #expect(abs(centroid.x - projected.x) <= 2, "x: \(centroid.x) vs \(projected.x)")
        #expect(abs(centroid.y - projected.y) <= 2, "y: \(centroid.y) vs \(projected.y)")
    }

    @Test("Trap 4: readback preserves channel order — red clears as red",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func readbackChannelOrder() throws {
        let renderer = try #require(makeRenderer(points: []))
        let image = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 40, height: 40), supersample: 1,
            clearColor: MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)))
        let (data, width, _) = try #require(pixels(of: image))
        let centre = (20 * width + 20) * 4
        // A BGRA/RGBA swap here yields a fully plausible map with red and blue exchanged —
        // which "reads as a different lens rather than as a bug."
        #expect(data[centre] > 200, "red channel: \(data[centre])")
        #expect(data[centre + 2] < 50, "blue channel: \(data[centre + 2])")
    }

    /// **An opaque ground stays opaque, whatever is drawn over it.**
    ///
    /// This is the invariant `sourceAlphaBlendFactor` broke. Source-over wants the source's own
    /// coverage for alpha (`.one`); the pipeline used `.sourceAlpha`, squaring it, so a
    /// half-transparent dot over the opaque background yielded 0.75 rather than 1. The readback is
    /// *declared* premultiplied, so composited onto the white figure canvas the brightest dots
    /// clamped to pure white instead of lightening.
    ///
    /// **It needs a SEMI-TRANSPARENT palette entry and that is the whole reason it did not exist
    /// before.** Every other fixture here uses alpha 1, where `.sourceAlpha` and `.one` are
    /// arithmetically identical — the defect was invisible to the suite by construction, not by
    /// oversight. Asserting over every pixel rather than a chosen one also makes the test
    /// independent of what the shader does to alpha internally.
    @Test("An opaque background stays opaque under a transparent point",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func renderedAlphaIsOpaque() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = SemanticMapRenderer(device: device) else { return }
        renderer.setPalette([SIMD4<Float>(1, 1, 1, 0.5)])
        renderer.setPoints([point(0, 0)])
        renderer.frameAll(extent: 100)
        // pointSize 6 on a 200 pt plate, matching the idiom the other pixel tests use. The default
        // 2.0 on a 40x40 plate draws NOTHING — which is how the first version of this test passed
        // against the very defect it was written for. A vacuous pixel assertion over an untouched
        // background is indistinguishable from a correct one; the mutation is what told them apart.
        renderer.pointSize = 6
        let image = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 200, height: 200), supersample: 1))
        #expect(!litPixels(of: image).isEmpty, "precondition: the point must actually be drawn")
        let (data, width, height) = try #require(pixels(of: image))
        var minimum = 255
        for y in 0..<height {
            for x in 0..<width { minimum = min(minimum, Int(data[(y * width + x) * 4 + 3])) }
        }
        #expect(minimum == 255, "least-opaque pixel had alpha \(minimum); the ground is opaque")
    }

    /// A figure that leaves this app for a journal or a printer meets a colour-managed consumer.
    /// `CGColorSpaceCreateDeviceRGB()` is untagged, so that consumer may read the bytes in the
    /// display's space instead of the one they were written in.
    @Test("An exported readback is tagged sRGB, not device RGB",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func readbackIsTaggedSRGB() throws {
        let renderer = try #require(makeRenderer(points: [point(0, 0)]))
        for supersample in [1, 2] {   // the downsampled path builds its own context
            let image = try #require(renderer.renderOffscreen(
                pixelSize: CGSize(width: 40, height: 40), supersample: supersample))
            #expect(image.colorSpace?.name == CGColorSpace.sRGB,
                    "supersample \(supersample): \(String(describing: image.colorSpace?.name))")
        }
    }

    @Test("The on-screen view state is untouched by an export",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func exportLeavesViewStateAlone() throws {
        let renderer = try #require(makeRenderer(points: [point(0, 0)]))
        renderer.pointSize = 3.5
        let aspectBefore = renderer.aspect
        let pointSizeBefore = renderer.pointSize
        let cameraBefore = renderer.camera
        _ = renderer.renderOffscreen(pixelSize: CGSize(width: 640, height: 360), supersample: 2)
        #expect(renderer.aspect == aspectBefore)
        #expect(renderer.pointSize == pointSizeBefore)
        #expect(renderer.camera == cameraBefore)
    }

    @Test("Supersampling downsamples to the requested plate size",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func supersampleDownsamples() throws {
        let renderer = try #require(makeRenderer(points: [point(0, 0)]))
        let image = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 320, height: 240), supersample: 2))
        #expect(image.width == 320 && image.height == 240)
    }

    // MARK: - Phase 2: the figure composite

    @Test("The slice description leads the figure provenance's caveats")
    @MainActor
    func sliceDescriptionInProvenance() async throws {
        await BundledSemanticMap.prepare()
        let index = try #require(BundledSemanticMap.index)
        let provenance = SemanticMapExport.provenance(
            index: index, scopeLabel: nil, scopedDocumentCount: nil,
            lens: .era, indexedVolumeCount: 1,
            figureTitle: "Semantic map",
            sliceDescription: "This figure shows a SLICE — test sentence.")
        #expect(provenance.figureTitle == "Semantic map")
        #expect(provenance.extraCaveats.first == "This figure shows a SLICE — test sentence.")
        // Without a slice, the caveats are unchanged and the regions title survives for the CSV.
        let plain = SemanticMapExport.provenance(
            index: index, scopeLabel: nil, scopedDocumentCount: nil,
            lens: .era, indexedVolumeCount: 1)
        #expect(plain.figureTitle == "Semantic map regions")
        #expect(plain.extraCaveats.first?.contains("How to read position") == true)
    }

    @Test("The composed figure renders to PNG data through the analytics canvas",
          .enabled(if: offscreenHasMetal))
    @MainActor
    func figureCanvasRendersPNG() async throws {
        await BundledSemanticMap.prepare()
        let renderer = try #require(makeRenderer(points: [point(0, 0), point(30, 30)]))
        let index = try #require(BundledSemanticMap.index)
        let plate = try #require(renderer.renderOffscreen(
            pixelSize: CGSize(width: 400, height: 300), supersample: 1))
        let provenance = SemanticMapExport.provenance(
            index: index, scopeLabel: nil, scopedDocumentCount: nil,
            lens: .era, indexedVolumeCount: 0, figureTitle: "Semantic map")
        let canvas = AnalyticsFigureCanvas(provenance: provenance, chartHeight: 150) {
            Image(decorative: plate, scale: 2)
        }
        let png = AnalyticsFigureExporter.render(canvas, format: .png)
        #expect(png != nil && (png?.count ?? 0) > 1000)
    }
}
