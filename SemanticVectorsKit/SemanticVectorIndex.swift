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

/// Row keying for the semantic tiers: the map between a `(volume, document)` pair and its row in the
/// corpus-wide vector block.
///
/// Wraps the decoded `semantic-vectors-index.json` and answers the two questions every retrieval path
/// asks — *which row is this document* and *which document is this row* — **without ever expanding
/// the id table**. Expanding it would cost 314,483 Swift strings (~20 MB resident) to answer lookups
/// that resolve in a handful of comparisons: a volume averages three run segments, so both directions
/// are a short linear walk over that volume's segments.
///
/// The forward direction is the one that must never be approximated. V-1 measured the design's
/// proposed ordinal rule (`d{ordinal+1}`) wrong for 15,097 documents, and a wrong row here does not
/// fail — it returns a real vector for a different document, scores it plausibly, and shows it under
/// the wrong title. Both directions are therefore derived from the same stored segments, and
/// `SemanticVectorsKitTests` pins them against each other.
public struct SemanticVectorIndex: Sendable {

    /// The decoded artifact.
    public let file: SemanticVectorsArtifacts.Index

    /// Volume row blocks, by volume id, for O(1) volume lookup.
    private let byVolume: [String: SemanticVectorsArtifacts.VolumeEntry]

    /// Volume entries ordered by row offset, for the reverse walk.
    private let volumesByRow: [SemanticVectorsArtifacts.VolumeEntry]

    /// For each entry in `volumesByRow`, its position in `file.volumes` — so a row lookup can hand
    /// back an index into a caller's parallel array instead of a volume id to hash.
    private let orderedSlots: [Int]

    /// Wraps a decoded index.
    ///
    /// - Parameter file: The decoded `semantic-vectors-index.json`.
    public init(file: SemanticVectorsArtifacts.Index) {
        self.file = file
        self.byVolume = Dictionary(
            file.volumes.map { ($0.volumeID, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = file.volumes.enumerated().sorted { $0.element.rowOffset < $1.element.rowOffset }
        self.volumesByRow = ordered.map(\.element)
        self.orderedSlots = ordered.map(\.offset)
    }

    /// Volume row blocks, in artifact order. A caller building a parallel array of shards indexes it
    /// with the slot from `volumeSlot(containing:)`.
    public var volumes: [SemanticVectorsArtifacts.VolumeEntry] { file.volumes }

    /// Total documents with a vector.
    public var documentCount: Int { file.documentCount }

    /// The provenance every tier must agree on.
    public var provenance: SemanticVectorsArtifacts.Provenance { file.provenance }

    /// Shipping vector width.
    public var dims: Int { file.provenance.shippingDims }

    /// The volume row block for a volume id, or `nil` when the artifact does not cover it.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The entry, if present.
    public func volume(_ volumeID: String) -> SemanticVectorsArtifacts.VolumeEntry? {
        byVolume[volumeID]
    }

    /// The corpus row for a document, or `nil` when the artifact has no vector for it.
    ///
    /// A `nil` here is ordinary, not an error: 2,356 of the app's 316,839 display rows are chapter
    /// divs, front matter, and appendix structure that the harvest never embedded (measured,
    /// `Phase3-Store-Assessment.md` §2). Callers must render that as *unavailable*, never as a
    /// similarity of zero.
    ///
    /// - Parameters:
    ///   - documentID: The document's TEI `xml:id`.
    ///   - volumeID: Manifest `volumeId`.
    /// - Returns: The corpus-wide row index, if the document has a vector.
    public func row(documentID: String, volumeID: String) -> Int? {
        guard let entry = byVolume[volumeID] else { return nil }
        let target = DocumentIDSegments.numericPart(of: documentID)
        for segment in entry.idSegments {
            if segment.id == documentID { return entry.rowOffset + segment.start }
            // A run only ever forms over ids whose spelling is recoverable from their value, so a
            // numeric target can be tested arithmetically against the run it would fall in.
            guard segment.count > 1, let target,
                  let base = DocumentIDSegments.numericPart(of: segment.id),
                  target > base, target < base + segment.count
            else { continue }
            return entry.rowOffset + segment.start + (target - base)
        }
        return nil
    }

    /// The position in `volumes` of the volume owning a corpus row, and the row's offset within it.
    ///
    /// **This is the hot path**, and it exists because the obvious call — `document(at:)` — is not.
    /// The rerank stage resolves 800 rows per query, and `document(at:)` builds a document-id
    /// `String` for each, which the caller then hashes against a dictionary of shards. Measured over
    /// 600 corpus queries: **4.78 ms** per query that way, **2.44 ms** with this — the string and its
    /// hash cost roughly as much as the entire corpus-wide Hamming scan they sit beside. A slot index
    /// is a binary search over 552 entries returning something a caller indexes a parallel array
    /// with, so no id is built for a candidate that is only ever scored.
    ///
    /// - Parameter row: A corpus-wide row index.
    /// - Returns: The volume's position in `volumes` and the row's offset within that volume, or
    ///   `nil` when the row is out of range.
    public func volumeSlot(containing row: Int) -> (slot: Int, localRow: Int)? {
        guard row >= 0, row < file.documentCount else { return nil }
        var low = 0
        var high = orderedSlots.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let entry = volumesByRow[mid]
            if row < entry.rowOffset {
                high = mid - 1
            } else if row >= entry.rowOffset + entry.documentCount {
                low = mid + 1
            } else {
                return (orderedSlots[mid], row - entry.rowOffset)
            }
        }
        return nil
    }

    /// The document a corpus row belongs to.
    ///
    /// Builds a `String`; on a per-candidate path prefer `volumeSlot(containing:)`.
    ///
    /// - Parameter row: A corpus-wide row index.
    /// - Returns: The volume and document ids, or `nil` when the row is out of range.
    public func document(at row: Int) -> (volumeID: String, documentID: String)? {
        guard row >= 0, row < file.documentCount else { return nil }
        // Binary search the row blocks: 552 volumes, so this is ~9 comparisons.
        var low = 0
        var high = volumesByRow.count - 1
        var found: SemanticVectorsArtifacts.VolumeEntry?
        while low <= high {
            let mid = (low + high) / 2
            let entry = volumesByRow[mid]
            if row < entry.rowOffset {
                high = mid - 1
            } else if row >= entry.rowOffset + entry.documentCount {
                low = mid + 1
            } else {
                found = entry
                break
            }
        }
        guard let entry = found else { return nil }
        let local = row - entry.rowOffset
        for segment in entry.idSegments {
            guard local >= segment.start, local < segment.start + segment.count else { continue }
            if local == segment.start { return (entry.volumeID, segment.id) }
            guard let base = DocumentIDSegments.numericPart(of: segment.id) else { return nil }
            return (entry.volumeID, "d\(base + (local - segment.start))")
        }
        return nil
    }

    /// The rows a volume occupies, as a half-open range.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The row range, or `nil` when the artifact does not cover the volume.
    public func rows(forVolume volumeID: String) -> Range<Int>? {
        guard let entry = byVolume[volumeID] else { return nil }
        return entry.rowOffset..<(entry.rowOffset + entry.documentCount)
    }

    /// Every document id in a volume, in row order.
    ///
    /// Materialises the ids for one volume, which is what a per-volume surface wants; the corpus-wide
    /// expansion this deliberately avoids is what would cost 20 MB.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The ids in row order, or `nil` when the artifact does not cover the volume.
    public func documentIDs(forVolume volumeID: String) -> [String]? {
        guard let entry = byVolume[volumeID] else { return nil }
        return DocumentIDSegments.decode(entry.idSegments)
    }
}
