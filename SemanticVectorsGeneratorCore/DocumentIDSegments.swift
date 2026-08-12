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

/// Run-length encoding of a volume's document ids, and the reason the artifact stores ids at all.
///
/// ## Why this exists
///
/// The design (`Planning/Vector-Embeddings-Semantic-Design.md` §4.1) proposed keying documents
/// *implicitly* — "volumes in manifest order, docs by ordinal, `idExceptions` side table (~18 KB)
/// for the 0.30%" — on the understanding that a document at ordinal *i* is `d{i+1}` except for the
/// 949 letter-suffixed ids. **Measured 2026-08-12, that is false for 15,097 documents (4.8%), not
/// 949 (0.3%).** The cause is a cascade rather than a scattering: one suffixed id (`frus1865p1`'s
/// `d373a` at ordinal 373) shifts every later document in the volume by one, so a single exception
/// mis-keys the whole tail behind it. A running-counter variant of the rule was tried and fails
/// outright in 23 of 552 volumes.
///
/// A wrong key here is the worst failure this artifact can have: every vector still resolves, every
/// score is still plausible, and the neighbours shown belong to different documents than the ones
/// named. So identity is **stored, never derived** — and stored in the form that makes storage
/// nearly free.
///
/// ## The encoding
///
/// A segment is a starting id plus a run length; within a run, each id is the previous id's numeric
/// part plus one. Measured over the corpus, **1,605 segments carry all 314,483 documents** — 7.5 KB
/// of id literals, 48 KB once encoded as JSON objects (66% of the bundled index, and still two
/// orders of magnitude below storing every id) — because the ids really are sequential; they just do
/// not start where the ordinal says.
///
/// Decoding is exact by construction **because a run only ever forms over ids whose spelling is
/// recoverable from their value**: `numericPart` refuses a multi-digit leading zero, so `d006` can
/// only be a segment start (stored literally) and never a re-minted interior id. Without that
/// refusal the encoding would be exact only where the corpus happened to cooperate, and a future
/// volume numbered `d006, d007, …` would abort a 552-volume pack on the round-trip guard rather than
/// encode correctly. The generator round-trips every volume regardless, so an encoding that does not
/// reproduce its own input can never ship.
public enum DocumentIDSegments {

    /// One run of consecutive document ids.
    public struct Segment: Codable, Equatable, Sendable {
        /// Row index of the run's first document, relative to the volume's first row.
        public let start: Int
        /// The first document's id, stored literally.
        public let id: String
        /// How many documents the run covers, including the first.
        public let count: Int

        /// Creates a segment.
        /// - Parameters:
        ///   - start: Row index of the first document within its volume.
        ///   - id: The first document's literal id.
        ///   - count: Documents in the run.
        public init(start: Int, id: String, count: Int) {
            self.start = start
            self.id = id
            self.count = count
        }

        private enum CodingKeys: String, CodingKey {
            case start = "s"
            case id = "i"
            case count = "n"
        }
    }

    /// Splits `dN` into its numeric part, or `nil` for any other shape (`d373a`, `appA`,
    /// `s05sub04`).
    ///
    /// **A multi-digit leading zero returns `nil` on purpose.** This function reports a *value*
    /// while `decode(_:)` re-mints interior ids from that value, so admitting `d006` would let a run
    /// form whose members decode as `d7`, `d8` — the same documents under different names. Refusing
    /// it makes such an id a literal single-document segment, which costs one segment and keeps the
    /// round trip exact. (The corpus contains no such id today: measured, 0 of 314,483 match
    /// `^d0[0-9]+$`. This is about the next corpus, not this one.)
    ///
    /// Two neighbouring hazards need no special handling and are noted so a reader does not add it:
    /// non-ASCII digits satisfy `Character.isNumber` but `Int()` rejects them, and a digit string
    /// beyond `Int.max` also returns `nil` — both become literal segments.
    ///
    /// - Parameter id: A document id.
    /// - Returns: The numeric part when the id is exactly `d` followed by digits with no redundant
    ///   leading zero.
    public static func numericPart(of id: String) -> Int? {
        guard id.hasPrefix("d") else { return nil }
        let digits = id.dropFirst()
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        guard digits.count == 1 || digits.first != "0" else { return nil }
        return Int(digits)
    }

    /// Encodes a volume's document ids, in row order, as runs.
    ///
    /// - Parameter ids: The volume's ids in row order.
    /// - Returns: Segments covering every id exactly once.
    public static func encode(_ ids: [String]) -> [Segment] {
        var segments: [Segment] = []
        var index = 0
        while index < ids.count {
            let start = index
            var previous = numericPart(of: ids[index])
            index += 1
            // A non-numeric id can only ever be a run of one: nothing follows from `appA`.
            while previous != nil, index < ids.count,
                  let next = numericPart(of: ids[index]), next == previous! + 1 {
                previous = next
                index += 1
            }
            segments.append(Segment(start: start, id: ids[start], count: index - start))
        }
        return segments
    }

    /// Decodes segments back into ids in row order.
    ///
    /// - Parameter segments: Segments as produced by `encode(_:)`.
    /// - Returns: The document ids, or `nil` when a segment claims a multi-document run from a
    ///   non-numeric id — a shape `encode(_:)` never emits and a hand-edited artifact might.
    public static func decode(_ segments: [Segment]) -> [String]? {
        var ids: [String] = []
        for segment in segments {
            guard segment.count >= 1 else { return nil }
            guard segment.start == ids.count else { return nil }
            ids.append(segment.id)
            guard segment.count > 1 else { continue }
            guard let base = numericPart(of: segment.id) else { return nil }
            for step in 1..<segment.count { ids.append("d\(base + step)") }
        }
        return ids
    }
}
