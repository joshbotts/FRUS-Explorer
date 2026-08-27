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
import CoreGraphics

// MARK: - SemanticMapFrameSequence

/// The frame-sequence harness (W-3 / #1007, design §6 Phase 3): a deterministic sequence of
/// offscreen map frames stepping the corpus chronologically, one volume per frame.
///
/// ## What a sequence is
/// `renderOffscreen` plus the existing scope machinery is already an animation renderer:
/// frame *N* scopes the map to the first *N* volumes in coverage order — the reader watches
/// the published record accumulate across the semantic plane — and a closing frame lifts the
/// scope entirely. Deterministic because scope and camera are explicit state, not a clock:
/// the same artifact renders the same bytes, frame for frame.
///
/// ## One definition, throughout
/// The mask is `SemanticMapColouring.scopeMask` through `SemanticMapModel.setScope` — the
/// same pass the on-screen chip runs — and the frame is `renderOffscreen`, the same path the
/// figure export uses. This harness owns ONLY the ordering, the loop, and the sidecar files;
/// a sequence produced by private variants of any of those would be an animation of a nearby
/// program.
///
/// ## The honesty requirement travels with the frames
/// A scope is a set of **volumes**: each frame lights every document in the volumes covered
/// so far, never the documents *about* anything — on a chart that distinction hides inside a
/// bar, and on the map the reader watches those documents land in regions the subject never
/// touched. ``animationGrainSentence`` states it, ``provenanceText`` leads with it, and the
/// generator test writes it beside the frames — a video assembled from the directory has the
/// sentence sitting next to its sources.
///
/// ## Cost, measured rather than assumed
/// The design flags `setScopeFlags` — a CPU loop writing one byte per document — as the cost
/// to know before driving it per frame. Each ``FrameRecord`` carries its measured wall-clock
/// milliseconds (mask + upload + render + readback), so the answer ships with every run
/// instead of going stale in a comment.
///
/// ## Hosting
/// Driven by `SemanticMapFrameSequenceTests` in the app test target — the harness needs the
/// bundled artifacts and a `@MainActor` Metal renderer, which is the same reason the design
/// gives for the word-cloud harness ("this cannot be a plain `swift run` SPM generator").
/// The full-corpus render is gated behind `RENDER_MAP_FRAMES_DIR`; the suite's ordinary runs
/// cover ordering, determinism, and the sidecars over a handful of volumes.
///
/// Version history:
///   1.0 — W-3 (#1007) §6 Phase 3: initial implementation
@MainActor
enum SemanticMapFrameSequence {

    /// One frame's facts, for the `frames.csv` sidecar — everything a subtitle or a caption
    /// needs, in frame order.
    struct FrameRecord: Equatable {
        /// Zero-based frame index; also the frame filename stem.
        let index: Int
        /// The volume this frame adds, or `""` for the closing unscoped frame.
        let volumeID: String
        /// The volume's title, or the closing frame's label.
        let volumeTitle: String
        /// The volume's coverage start (`dateRange.earliest`), or `""`.
        let coverageStart: String
        /// Volumes in scope after this frame.
        let cumulativeVolumes: Int
        /// Documents lit after this frame (the mask's own count; the whole corpus for the
        /// closing frame).
        let cumulativeDocuments: Int
        /// Measured wall-clock cost of this frame — mask, upload, render, readback.
        let renderMilliseconds: Double
    }

    /// The scope-grain sentence any published sequence must carry (design §6 Phase 3).
    static let animationGrainSentence = String(localized: "semanticMap.frames.grain",
        defaultValue: "Each frame lights every document in the volumes published so far — a scope is a set of volumes, so a frame shows where those volumes' documents sit, never the documents about any particular subject.")

    // MARK: - Ordering

    /// The frame order: covered volumes ascending by coverage start, volume id as the total
    /// tiebreak — a deterministic order, testable without a GPU.
    ///
    /// - Parameters:
    ///   - entries: The manifest entries (the published series).
    ///   - isCovered: Whether the map artifact carries rows for a volume; an uncovered
    ///     volume would add a frame identical to its predecessor.
    /// - Returns: The entries that will each get a frame, in order.
    nonisolated static func chronological(_ entries: [VolumeManifestEntry],
                                          isCovered: (String) -> Bool) -> [VolumeManifestEntry] {
        entries
            .filter { isCovered($0.volumeId) }
            .sorted {
                let l = $0.dateRange.earliest ?? "9999"
                let r = $1.dateRange.earliest ?? "9999"
                if l != r { return l < r }
                return $0.volumeId < $1.volumeId
            }
    }

    // MARK: - Rendering

    /// Renders the sequence: one cumulative-scope frame per ordered volume, then one closing
    /// unscoped frame. The model must already be `prepare(...)`d.
    ///
    /// - Parameters:
    ///   - model: The map model owning the renderer — the harness drives `setScope`, so the
    ///     model is left UNSCOPED afterwards (the closing frame's state).
    ///   - ordered: The volumes in frame order (from ``chronological(_:isCovered:)``).
    ///   - pixelSize: Each frame's final pixel size.
    ///   - supersample: The oversampling factor handed to `renderOffscreen`.
    ///   - writeFrame: Called once per frame, in order, with the frame index and image.
    /// - Returns: One record per frame, in order — empty when the renderer is missing.
    static func render(model: SemanticMapModel,
                       ordered: [VolumeManifestEntry],
                       pixelSize: CGSize,
                       supersample: Int = 2,
                       writeFrame: (Int, CGImage) throws -> Void) rethrows -> [FrameRecord] {
        guard let renderer = model.renderer else { return [] }
        var records: [FrameRecord] = []
        var cumulative = Set<String>()

        for (index, entry) in ordered.enumerated() {
            let started = Date()
            cumulative.insert(entry.volumeId)
            model.setScope(volumeIDs: cumulative)
            guard let image = renderer.renderOffscreen(pixelSize: pixelSize,
                                                       supersample: supersample) else { continue }
            try writeFrame(index, image)
            records.append(FrameRecord(
                index: index,
                volumeID: entry.volumeId,
                volumeTitle: entry.title,
                coverageStart: entry.dateRange.earliest ?? "",
                cumulativeVolumes: model.scope?.volumeCount ?? cumulative.count,
                cumulativeDocuments: model.scope?.documentCount ?? 0,
                renderMilliseconds: Date().timeIntervalSince(started) * 1000))
        }

        // The closing frame: the scope lifted, every document in its lens colour — the
        // sequence ends on the map the reader knows.
        let started = Date()
        model.setScope(volumeIDs: nil)
        if let image = renderer.renderOffscreen(pixelSize: pixelSize, supersample: supersample) {
            let index = records.count
            try writeFrame(index, image)
            records.append(FrameRecord(
                index: index,
                volumeID: "",
                volumeTitle: String(localized: "semanticMap.frames.closing",
                                    defaultValue: "Complete series"),
                coverageStart: "",
                cumulativeVolumes: ordered.count,
                cumulativeDocuments: renderer.uploadedPointCount,
                renderMilliseconds: Date().timeIntervalSince(started) * 1000))
        }
        return records
    }

    // MARK: - Sidecars

    /// The `provenance.txt` written beside the frames: the map's own methods block — the
    /// same `AnalyticsProvenance` the CSV and the figure carry — led by the animation's
    /// grain sentence and the frame spec.
    static func provenanceText(index: SemanticMapArtifacts.MapIndex,
                               lensLabel: String,
                               frameCount: Int,
                               indexedVolumeCount: Int) -> String {
        let provenance = SemanticMapExport.provenance(
            index: index, scopeLabel: nil, scopedDocumentCount: nil,
            lensLabel: lensLabel, indexedVolumeCount: indexedVolumeCount,
            figureTitle: String(localized: "semanticMap.frames.title",
                                defaultValue: "Semantic map frame sequence"))
        var lines: [String] = []
        lines.append("# \(animationGrainSentence)")
        lines.append("# " + String(localized: "semanticMap.frames.spec",
            defaultValue: "\(frameCount.formatted()) frames: one volume added per frame in coverage order, plus a closing unscoped frame. Out-of-scope documents are ghosted, never removed."))
        lines.append("#")
        lines.append(contentsOf: provenance.csvPreambleLines)
        return lines.joined(separator: "\n") + "\n"
    }

    /// The `frames.csv` sidecar — RFC-4180, quoted fields, one row per frame.
    nonisolated static func framesCSV(_ records: [FrameRecord]) -> String {
        func quote(_ field: String) -> String {
            "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var rows = ["frame,volume_id,volume_title,coverage_start,cumulative_volumes,cumulative_documents,render_ms"]
        for r in records {
            rows.append([String(r.index), quote(r.volumeID), quote(r.volumeTitle),
                         quote(r.coverageStart), String(r.cumulativeVolumes),
                         String(r.cumulativeDocuments),
                         String(format: "%.1f", r.renderMilliseconds)].joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }
}
