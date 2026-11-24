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
// SemanticVectorsKit is a module of its own in a package; Xcode compiles its sources into the app
// target (project.yml), where its types are already in this module and the import is compiled out.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

/// The map's other layout: the corpus laid along a semantic axis, with time up the side.
///
/// The rules `SemanticMapModel.setSlice(axis:yearForVolume:reapplyLens:)` lays a slice out by, and the
/// scale, the ticks and the caveat `SemanticMapSpikeView` labels it with, out of the app, so that a host
/// that draws the slice elsewhere lays it out and labels it as the app does.
///
/// **x is the projection, y is the volume's coverage year** — the design's "drive the x-axis with it
/// while y stays date". The date is the *volume's* coverage midpoint, not the document's, because that
/// is what the bundle knows for all 553 volumes; a per-document date exists only for volumes a device
/// has indexed, and a y-axis that meant one thing for some rows and another for the rest would be worse
/// than a coarse one that means the same thing everywhere. ``SemanticMapVolumes/coverageYear(of:)`` is
/// that year.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a — out of `SemanticMapModel` (the layout, its scale,
///          the gutter and a year's place) and `SemanticMapSpikeView` (the ticks and the caveat), which
///          call it
public enum SemanticMapSlice {

    /// The year range a slice's vertical axis spans, and how many documents fell outside it.
    ///
    /// **This is what makes the slice a labelled chart** (UI review X-5 / MR-13): the ticks, the
    /// gutter note and the caveat all read these rather than re-deriving them, so the scale on
    /// screen is the scale the layout used — the same one-source rule the scope mask follows.
    public struct Scale: Equatable, Sendable {
        /// The earliest coverage-midpoint year among dated volumes.
        public let minYear: Int
        /// The latest.
        public let maxYear: Int
        /// Documents whose volume has no parseable coverage year, laid out in the gutter.
        public let undatedCount: Int

        /// Creates a scale.
        /// - Parameters:
        ///   - minYear: The earliest coverage-midpoint year among dated volumes.
        ///   - maxYear: The latest.
        ///   - undatedCount: Documents whose volume has no parseable coverage year.
        public init(minYear: Int, maxYear: Int, undatedCount: Int) {
            self.minYear = minYear
            self.maxYear = maxYear
            self.undatedCount = undatedCount
        }
    }

    /// A slice, laid out: where each row goes, and the scale that put it there.
    public struct Layout: Equatable, Sendable {
        /// Each row's grid position, in row order: x the projection, y the year.
        public let positions: [SIMD2<Int16>]
        /// The scale the positions were laid out at.
        public let scale: Scale
    }

    /// The gutter's normalised y for undated volumes: below every dated year, with a visible gap.
    public static let gutterY: Float = -0.96

    /// Where a dated year lands on the slice's normalised vertical axis.
    ///
    /// One function shared by the tick overlay and the tests, so the ticks cannot drift from the
    /// points they label; the layout places a row by the same arithmetic.
    /// - Parameters:
    ///   - year: The coverage-midpoint year.
    ///   - scale: The slice's recorded scale.
    /// - Returns: Normalised y in the dated band [-0.82, 1].
    public static func y(forYear year: Int, scale: Scale) -> Float {
        let span = Float(max(1, scale.maxYear - scale.minYear))
        return -0.82 + (Float(year - scale.minYear) / span) * 1.82
    }

    /// Lays the corpus out along a semantic axis.
    ///
    /// Each row's x is its sign bits' projection onto the axis, scaled to the band the corpus actually
    /// spans, and its y its volume's coverage year, with undated volumes in a gutter below every dated
    /// year. The grid is ``SemanticAxis/sliceExtent`` on each side.
    ///
    /// - Parameters:
    ///   - axis: The axis to slice along.
    ///   - map: The mapped placements, for the row count.
    ///   - index: The vector index, for each volume's rows.
    ///   - corpus: The bundled corpus tier, whose sign bits are projected.
    ///   - yearForVolume: A volume's coverage midpoint year, as ``SemanticMapVolumes/coverageYear(of:)``
    ///     gives it.
    /// - Returns: One position per row, and the scale.
    public static func layout(along axis: SemanticAxis, map: SemanticMapVectors,
                              index: SemanticVectorIndex, corpus vectors: SemanticCorpusVectors,
                              yearForVolume: (String) -> Int?) -> Layout {
        // Year per ROW, resolved once per volume rather than once per document: 553 lookups instead
        // of 314,616.
        var yearByRow = [Int16](repeating: 0, count: map.documentCount)
        var minYear = Int.max, maxYear = Int.min
        for volume in index.volumes {
            guard let rows = index.rows(forVolume: volume.volumeID),
                  let year = yearForVolume(volume.volumeID) else { continue }
            minYear = min(minYear, year); maxYear = max(maxYear, year)
            for row in rows where row < yearByRow.count { yearByRow[row] = Int16(clamping: year) }
        }
        let yearSpan = Float(max(1, maxYear - minYear))

        let extent = Float(SemanticAxis.sliceExtent)

        // Project first, then scale to what was actually observed. A sign-bit cosine against a
        // difference-of-centroids axis concentrates near zero — most of the corpus is unrelated to
        // both poles — so the true range is a narrow band and an unscaled slice is a vertical smear.
        // The ORDER along the axis is the content; the absolute magnitude of a sign-bit cosine is not
        // interpretable on its own, so filling the width costs no meaning. The caveat says it.
        var projections = [Float](repeating: 0, count: map.documentCount)
        var lowest = Float.greatestFiniteMagnitude
        var highest = -Float.greatestFiniteMagnitude
        vectors.withSignBits { base, count in
            for row in 0..<min(count, map.documentCount) {
                let value = axis.project(signBitsAt: base, row: row,
                                         bytesPerRow: vectors.bytesPerRow)
                projections[row] = value
                lowest = min(lowest, value)
                highest = max(highest, value)
            }
        }
        let spread = max(1e-6, highest - lowest)

        var positions = [SIMD2<Int16>]()
        positions.reserveCapacity(map.documentCount)
        // Dated years occupy the upper band; undated volumes go to a GUTTER below it, separated by
        // a gap no dated year can occupy. The first version plotted them at the exact vertical
        // centre — an unknown date drawn *as* a mid-century date, on the surface whose header
        // exists to say what is and is not a measurement (UI review X-5, filed independently on
        // all three platforms).
        var undated = 0
        for row in 0..<map.documentCount {
            let x = ((projections[row] - lowest) / spread) * 2 - 1
            let year = Int(yearByRow[row])
            let normalisedYear: Float
            if year == 0 {
                undated += 1
                normalisedYear = gutterY
            } else {
                // Dated band: [-0.82, 1], leaving [-1, -0.9] to the gutter.
                let t = Float(year - minYear) / yearSpan
                normalisedYear = -0.82 + t * 1.82
            }
            positions.append(SIMD2<Int16>(Int16(clamping: Int(x * extent)),
                                          Int16(clamping: Int(normalisedYear * extent))))
        }
        return Layout(positions: positions,
                      scale: Scale(minYear: minYear == Int.max ? 0 : minYear,
                                   maxYear: maxYear == Int.min ? 0 : maxYear,
                                   undatedCount: undated))
    }

    /// At most five round tick years spanning the observed range.
    /// - Parameters:
    ///   - min: Earliest dated year.
    ///   - max: Latest.
    /// - Returns: Rounded tick years within the range, ascending.
    public static func tickYears(min: Int, max: Int) -> [Int] {
        guard max > min else { return [min] }
        let span = max - min
        // A step that yields <= 5 ticks, rounded to decades where the span allows.
        let rough = Swift.max(1, span / 4)
        let step = rough <= 5 ? 5 : rough <= 10 ? 10 : rough <= 20 ? 20 : rough <= 25 ? 25 : 50
        let first = ((min + step - 1) / step) * step
        return Array(stride(from: first, through: max, by: step))
    }

    /// The caveat a slice carries.
    ///
    /// **This sentence said "256-bit signatures" for as long as 512 shipped.** The width was written
    /// as a literal, #933 doubled it, and nothing failed — a user-facing claim about the artifact
    /// went quietly wrong and stayed wrong. It is now read from the artifact itself, so it cannot
    /// disagree with what the app is actually using, whatever the next width turns out to be.
    ///
    /// The number is also no longer the point of the sentence. "From 512-bit signatures" tells a
    /// historian nothing; what they need is that a position is approximate, so small left–right
    /// differences are not evidence. The bit width stays, parenthesised, for the reader who wants it.
    ///
    /// - Parameters:
    ///   - negative: The low-end pole.
    ///   - positive: The high-end pole.
    ///   - shippingDims: The bundled index's shipping width (its provenance's `shippingDims`), or `nil`
    ///     when no index is loaded, which the sentence then leaves out.
    /// - Returns: The sentence.
    public static func caveat(from negative: String, to positive: String, shippingDims: Int?) -> String {
        let bits = shippingDims
        let position = bits.map {
            String(format: String(
                localized: "semanticMap.caveat.slice.position.v2 %@ %@ %lld",
                defaultValue: """
                    Left to right is how far each document leans from %1$@ toward %2$@. The reading \
                    is approximate — it comes from a compact %3$lld-bit summary of each document — \
                    so treat a clear side as meaningful and a small gap as noise.
                    """), negative, positive, Int64($0))
        } ?? String(format: String(
            localized: "semanticMap.caveat.slice.position.nobits.v2 %@ %@",
            defaultValue: """
                Left to right is how far each document leans from %1$@ toward %2$@. The reading is \
                approximate, so treat a clear side as meaningful and a small gap as noise.
                """), negative, positive)
        let vertical = String(localized: "semanticMap.caveat.slice.vertical.v2",
                              defaultValue: "Up and down is the volume’s coverage midpoint, not each document’s own date.")
        return position + " " + vertical
    }
}

/// The two ends of a slice's axis, and the three ways a pair of them is refused.
///
/// The rule `SemanticMapModel.setPole(volumeID:isPositive:yearForVolume:reapplyLens:)` applies, out of
/// the model, so that a host offering poles refuses them as the app does and in its words. Poles are
/// volumes, not the documents tapped: an axis runs between two volume centroids from the bundled tier
/// (``SemanticAxis/centroid(forVolume:index:corpus:)``).
///
/// **Refusing silently is what the app used to do, and it read as a broken button.** An axis needs two
/// volumes, so two documents from the same volume have no direction between them and drawing one would
/// be rounding error. That is a real constraint and worth stating, but the surface said nothing at all
/// — the reader chose "…to here" and the map simply did not change. The refusal stands; it explains
/// itself. And **two causes, two messages**: a volume the artifact carries no summary for was once
/// reported as two volumes being "too alike", a confident diagnosis of the wrong thing. A missing
/// centroid is a property of the build; a cancelling difference is a property of the two volumes.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a — out of `SemanticMapModel.setPole`, which applies it
public enum SemanticMapPoles {

    /// Why a pair of poles drew no slice.
    public enum Refusal: String, CaseIterable, Sendable {
        /// Both ends are in one volume.
        case sameVolume
        /// The build carries no centroid for one of the two volumes.
        case noSummary
        /// The two volumes' centroids cancel, so there is no direction between them.
        case tooAlike

        /// What the reader is told, naming the cause and what to do.
        public var notice: String {
            switch self {
            case .sameVolume:
                return String(
                    localized: "semanticMap.axis.sameVolume",
                    defaultValue: "An axis runs between two volumes, and both of these documents are in the same one. Pick a document from a different volume as the second end.")
            case .noSummary:
                return String(
                    localized: "semanticMap.axis.noSummary",
                    defaultValue: "This version of the app has no language summary for one of these volumes, so it cannot place an axis between them. Try a different volume as that end.")
            case .tooAlike:
                return String(
                    localized: "semanticMap.axis.tooAlike",
                    defaultValue: "These two volumes were measured as so similar that there is no direction between them to lay the corpus along. Try two volumes you expect to differ.")
            }
        }
    }

    /// What a pair of poles comes to.
    public enum Resolution: Equatable, Sendable {
        /// One end or neither is set: a normal intermediate state, not a failure.
        case incomplete
        /// The pair is refused, for the reason given.
        case refused(Refusal)
        /// The pair is complete but the artifact is not loaded yet, so a centroid is missing because
        /// nothing has loaded and every refusal would name a cause it cannot know: remember the pair
        /// and ask again once the artifact is ready (W-2).
        case deferred(negative: String, positive: String)
        /// The axis to slice along.
        case axis(SemanticAxis)
    }

    /// Resolves a pair of poles.
    ///
    /// The same-volume refusal comes before the readiness gate on purpose: it is index-independent,
    /// and deferring it would swallow the one refusal a reader can meet before the load ends.
    ///
    /// - Parameters:
    ///   - negative: The low end's volume, if set.
    ///   - positive: The high end's volume, if set.
    ///   - isReady: Whether the bundled tier is loaded.
    ///   - centroid: A volume's centroid, as ``SemanticAxis/centroid(forVolume:index:corpus:)`` gives it.
    /// - Returns: What the pair comes to. A caller that set one end clears that end on a refusal, so the
    ///   reader's earlier choice survives.
    public static func resolve(negative: String?, positive: String?, isReady: Bool,
                               centroid: (String) -> [Float]?) -> Resolution {
        guard let negativeID = negative, let positiveID = positive else { return .incomplete }
        guard negativeID != positiveID else { return .refused(.sameVolume) }
        guard isReady else { return .deferred(negative: negativeID, positive: positiveID) }
        guard let negativeVector = centroid(negativeID),
              let positiveVector = centroid(positiveID) else { return .refused(.noSummary) }
        guard let axis = SemanticAxis.between(
            negative: negativeVector, negativeLabel: negativeID,
            positive: positiveVector, positiveLabel: positiveID) else { return .refused(.tooAlike) }
        return .axis(axis)
    }
}
