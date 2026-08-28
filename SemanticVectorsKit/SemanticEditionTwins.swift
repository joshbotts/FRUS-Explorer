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

/// The edition-twin rule every semantic neighbor surface owes (V-3 requirement, recorded in
/// `Phase3-Store-Assessment.md` §5): 27 of the corpus's 30 highest-cosine cross-volume pairs are
/// EDITION TWINS — `frus1951-54Iran` vs `frus1951-54IranEd2`, same document id, cosine 1.0 —
/// because a second edition reprints the first's documents verbatim. A ranked list that does not
/// fold them shows the same document twice in adjacent slots, and on a corpus-wide surface the
/// twins occupy top-1 positions at full strength (the 2026-08-27 evaluation report shows
/// `frus1951-54Iran/d166` and `frus1951-54IranEd2/d166` adjacent in one result list).
///
/// The rule is deliberately a STRING rule on the volume id, not a similarity threshold: the
/// assessment specifies "a volume-pair rule, cheap, enumerable from the manifest" — an
/// `Ed2`-suffixed volume id names its twin by construction, and a cosine cutoff would also fold
/// genuine reprints the reprint-detection non-goal (design §7.8) explicitly leaves alone.
public enum SemanticEditionTwins {

    /// The twin-folding key: a volume id with any trailing `Ed2` marker removed.
    ///
    /// `frus1951-54IranEd2` → `frus1951-54Iran`; ids without the marker return unchanged. Paired
    /// with a document id this keys "the same printed document, whichever edition" — two results
    /// sharing a `(baseVolumeID, documentID)` pair are one document twice.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The base id both editions share.
    public static func baseVolumeID(_ volumeID: String) -> String {
        volumeID.hasSuffix("Ed2") ? String(volumeID.dropLast(3)) : volumeID
    }

    /// Whether two volume ids are the same volume or an edition pair.
    public static func areTwins(_ first: String, _ second: String) -> Bool {
        baseVolumeID(first) == baseVolumeID(second)
    }

    /// The key two results share exactly when they are the same printed document, whichever
    /// edition — the one definition `foldingTwins` and any streaming fold both dedup on.
    public static func foldKey(volumeID: String, documentID: String) -> String {
        "\(baseVolumeID(volumeID))/\(documentID)"
    }

    /// Folds edition twins out of a ranked list, keeping each document's FIRST occurrence.
    ///
    /// First-wins is the whole rule: the list arrives ranked (score descending), so the kept
    /// edition is the better-scored one, and callers that prefer a particular edition (say, the
    /// one the reader has downloaded) should order the list before folding rather than teach this
    /// function preferences it cannot verify.
    ///
    /// - Parameters:
    ///   - results: Ranked elements, best first.
    ///   - key: Extracts `(volumeID, documentID)` from an element.
    /// - Returns: The list with later twins removed, order preserved.
    public static func foldingTwins<Element>(
        _ results: [Element],
        key: (Element) -> (volumeID: String, documentID: String)
    ) -> [Element] {
        var seen = Set<String>()
        var folded: [Element] = []
        folded.reserveCapacity(results.count)
        for element in results {
            let identity = key(element)
            let fold = foldKey(volumeID: identity.volumeID, documentID: identity.documentID)
            guard seen.insert(fold).inserted else { continue }
            folded.append(element)
        }
        return folded
    }
}
