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
import ImageIO
import UniformTypeIdentifiers
@testable import FRUSExplorer

/// Whether this host has a GPU — the render cases are disabled rather than failed without one,
/// the map suites' standing posture.
private let frameSequenceHasMetal = MTLCreateSystemDefaultDevice() != nil

/// The frame-sequence harness (W-3 / #1007 §6 Phase 3): ordering, sidecars, determinism —
/// and, behind `RENDER_MAP_FRAMES_DIR`, the full-corpus generator run.
///
/// Version history:
///   1.0 — W-3 §6 Phase 3: initial implementation
@Suite("Semantic map frame sequence", .serialized)
struct SemanticMapFrameSequenceTests {

    // MARK: - Fixtures

    /// Decodes a minimal manifest entry — through `Codable`, so the fixture cannot drift
    /// from the real decoding path.
    private func entry(_ id: String, earliest: String?, title: String = "T") throws -> VolumeManifestEntry {
        let json = """
        {"volumeId":"\(id)","filename":"\(id).xml","subseries":"s","title":"\(title)",
         "dateRange":{"earliest":\(earliest.map { "\"\($0)\"" } ?? "null"),"latest":null},
         "status":"published","editors":[],"documentCount":1,"sizeBytes":1,"tags":[]}
        """
        return try JSONDecoder().decode(VolumeManifestEntry.self, from: Data(json.utf8))
    }

    /// A prepared model over the bundled artifacts, or `nil` when the map is unavailable.
    /// The vector index loads first — `SemanticMapModel.prepare` reads it but does not load it
    /// (at app start `AppState` does; in a test host nothing has).
    @MainActor
    private func preparedModel() async -> SemanticMapModel? {
        await BundledSemanticVectors.prepare()
        let model = SemanticMapModel()
        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        return model.placedCount > 0 ? model : nil
    }

    /// The chronological covered order over the real manifest — what a generator run renders.
    @MainActor
    private func coveredOrder() async -> [VolumeManifestEntry] {
        await BundledSemanticVectors.prepare()
        let entries = ManifestStore().bundledEntries
        return SemanticMapFrameSequence.chronological(entries) {
            BundledSemanticVectors.index?.rows(forVolume: $0) != nil
        }
    }

    // MARK: - Ordering

    @Test("Frames run in coverage order, id-tiebroken, uncovered volumes dropped")
    func chronologicalOrdering() throws {
        let entries = [
            try entry("frus-late", earliest: "1950-01-01"),
            try entry("frus-b", earliest: "1900-01-01"),
            try entry("frus-a", earliest: "1900-01-01"),   // ties with -b on date; id breaks it
            try entry("frus-undated", earliest: nil),      // sorts last, not first
            try entry("frus-uncovered", earliest: "1861-01-01"),
        ]
        let ordered = SemanticMapFrameSequence.chronological(entries) { $0 != "frus-uncovered" }
        #expect(ordered.map(\.volumeId) == ["frus-a", "frus-b", "frus-late", "frus-undated"])
    }

    // MARK: - Sidecars

    @Test("frames.csv quotes titles and carries every column")
    func framesCSVQuoting() {
        let records = [SemanticMapFrameSequence.FrameRecord(
            index: 0, volumeID: "frus1861",
            volumeTitle: #"Foreign Relations, 1861, "Part I""#,
            coverageStart: "1861-03-04", cumulativeVolumes: 1,
            cumulativeDocuments: 312, renderMilliseconds: 12.34)]
        let csv = SemanticMapFrameSequence.framesCSV(records)
        let lines = csv.split(separator: "\n")
        #expect(lines[0] == "frame,volume_id,volume_title,coverage_start,cumulative_volumes,cumulative_documents,render_ms")
        #expect(lines[1] == #"0,"frus1861","Foreign Relations, 1861, ""Part I""","1861-03-04",1,312,12.3"#)
    }

    @Test("provenance.txt leads with the grain sentence and carries the map's methods block")
    @MainActor
    func provenanceLeadsWithGrainSentence() async throws {
        await BundledSemanticMap.prepare()
        let index = try #require(BundledSemanticMap.index)
        let text = SemanticMapFrameSequence.provenanceText(
            index: index, lens: .cluster, frameCount: 553, indexedVolumeCount: 1)
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines.first == "# " + SemanticMapFrameSequence.animationGrainSentence)
        // The methods block is the map's own — one definition of the caveats.
        #expect(text.contains("How to read position"))
        #expect(text.contains("Semantic map frame sequence"))
    }

    // MARK: - The sequence

    @Test("A short sequence is deterministic, cumulative, and leaves the model unscoped",
          .enabled(if: frameSequenceHasMetal))
    @MainActor
    func shortSequenceIsDeterministic() async throws {
        let model = try #require(await preparedModel())
        let ordered = Array(await coveredOrder().prefix(3))
        try #require(ordered.count == 3)
        let size = CGSize(width: 160, height: 120)

        func run() throws -> (records: [SemanticMapFrameSequence.FrameRecord], pixels: [[UInt8]]) {
            var pixels: [[UInt8]] = []
            let records = try SemanticMapFrameSequence.render(
                model: model, ordered: ordered, pixelSize: size, supersample: 1) { _, image in
                pixels.append(rgba(of: image))
            }
            return (records, pixels)
        }

        let first = try run()
        #expect(first.records.count == 4, "3 volume frames + the closing frame")
        // Cumulative: counts never decrease, and the closing frame is the whole corpus.
        let counts = first.records.map(\.cumulativeDocuments)
        #expect(counts == counts.sorted())
        #expect(first.records.last?.cumulativeDocuments == model.renderer?.uploadedPointCount)
        #expect(first.records.last?.volumeID == "")
        // The harness leaves the model unscoped — the closing frame's state.
        #expect(model.scope == nil)

        // Determinism: scope and camera are explicit state, not a clock — a second run
        // renders the same bytes, frame for frame.
        let second = try run()
        #expect(first.pixels == second.pixels)
    }

    // MARK: - Refusal

    /// **A frame that fails must stop the run, not thin it.**
    ///
    /// The loop writes at the LOOP index while the closing frame writes at `records.count`, so a
    /// single skipped render does two things at once: it leaves a hole that stops `ffmpeg` at the
    /// gap, and it makes the closing frame overwrite a real one. The result is a directory that
    /// looks like a finished sequence and is not. The plan's remedy was a manual pre-flight before
    /// assembling; refusing removes the need for one.
    ///
    /// Driven through the real `render`, with `writeFrame` throwing to stand in for a renderer that
    /// returns nil — the only way to reach the failure path without a broken GPU. It proves the
    /// error escapes rather than being swallowed, which is the property that matters: what must
    /// never happen is the run continuing.
    @Test("A failing frame stops the run rather than thinning the sequence",
          .enabled(if: frameSequenceHasMetal))
    @MainActor
    func aFailedFrameRefuses() async throws {
        let model = try #require(await preparedModel())
        let ordered = Array(await coveredOrder().prefix(3))
        try #require(ordered.count == 3)

        // A zero pixel size makes `renderOffscreen` return nil at its first guard — the real
        // failure path, reached without a broken GPU. Throwing from `writeFrame` would NOT do:
        // that closure only runs once an image exists, so a test built on it passes whether the
        // nil case throws or skips. (It did, until the mutation said otherwise.)
        var written = 0
        #expect(throws: FrameSequenceError.self) {
            _ = try SemanticMapFrameSequence.render(
                model: model, ordered: ordered,
                pixelSize: .zero, supersample: 1) { _, _ in written += 1 }
        }
        #expect(written == 0, "nothing should have been written; wrote \(written)")

        // And the happy path still returns every frame plus the closing one.
        var frames = 0
        let records = try SemanticMapFrameSequence.render(
            model: model, ordered: ordered,
            pixelSize: CGSize(width: 64, height: 48), supersample: 1) { _, _ in frames += 1 }
        #expect(records.count == ordered.count + 1)
        #expect(frames == records.count)
    }

    // MARK: - The generator run (gated)

    /// The full-corpus render: every covered volume in coverage order, 1920×1080, plus the
    /// sidecars. Runs ONLY when `RENDER_MAP_FRAMES_DIR` names a directory. The env var must
    /// wear xcodebuild's `TEST_RUNNER_` prefix (a trailing KEY=VALUE argument is a build
    /// setting and never reaches the test process), and the filter must stop at the SUITE
    /// (a function-level `-only-testing` matches zero tests here and reports "passed"):
    ///
    ///     TEST_RUNNER_RENDER_MAP_FRAMES_DIR=/tmp/map-frames xcodebuild test … \
    ///       -only-testing FRUSExplorerTests/SemanticMapFrameSequenceTests
    ///
    /// Measured 2026-08-27 (iPhone 16e simulator, M-series host): 553 frames in 57.6 s —
    /// mean 103.8 ms, worst 123.9 ms per frame — so the design's "measure before driving
    /// `setScopeFlags` per frame" question closes at ~10 fps offline, which a sequence
    /// assembled afterwards does not feel.
    ///
    /// Assemble with e.g. `ffmpeg -framerate 12 -i frame-%04d.png -pix_fmt yuv420p map.mp4`,
    /// and publish `provenance.txt`'s grain sentence with anything made from the frames.
    @Test("Full-corpus generator run (RENDER_MAP_FRAMES_DIR)",
          .enabled(if: frameSequenceHasMetal
                   && ProcessInfo.processInfo.environment["RENDER_MAP_FRAMES_DIR"] != nil))
    @MainActor
    func renderFullSequence() async throws {
        let directory = URL(fileURLWithPath: try #require(
            ProcessInfo.processInfo.environment["RENDER_MAP_FRAMES_DIR"]), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let model = try #require(await preparedModel())
        let ordered = await coveredOrder()
        let records = try SemanticMapFrameSequence.render(
            model: model, ordered: ordered,
            pixelSize: CGSize(width: 1920, height: 1080)) { index, image in
            let url = directory.appending(path: String(format: "frame-%04d.png", index))
            guard let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        #expect(records.count == ordered.count + 1)

        try SemanticMapFrameSequence.framesCSV(records)
            .write(to: directory.appending(path: "frames.csv"), atomically: true, encoding: .utf8)
        let index = try #require(BundledSemanticMap.index)
        try SemanticMapFrameSequence.provenanceText(
            index: index, lens: .cluster, frameCount: records.count,
            indexedVolumeCount: 0)
            .write(to: directory.appending(path: "provenance.txt"),
                   atomically: true, encoding: .utf8)

        let mean = records.map(\.renderMilliseconds).reduce(0, +) / Double(max(1, records.count))
        let worst = records.map(\.renderMilliseconds).max() ?? 0
        print("[SemanticMapFrameSequence] \(records.count) frames → \(directory.path); "
              + String(format: "mean %.1f ms, worst %.1f ms per frame", mean, worst))
    }

    // MARK: - Pixel readback

    private func rgba(of image: CGImage) -> [UInt8] {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }
}
