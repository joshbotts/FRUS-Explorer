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

// MARK: - ExcerptVerifier

/// Checks a stored quotation against the indexed document it claims to come from (M-3).
///
/// ## Why a substring check earns its keep
/// Both fabricated NSC 68 quotations in the reports behind this wave were caught by a
/// deterministic substring check — not by a model. That is the whole argument for this file: the
/// cheapest available method, run at the moment a quotation is about to leave the app.
///
/// `CollectionEntry` describes its excerpts as *frozen verbatim quotations*, and until now nothing
/// re-checked them. A volume can be re-indexed, deleted and re-downloaded, or corrected upstream
/// between the day a quotation is captured and the day it is exported.
///
/// ## The normalisation policy, and why each rule is safe
/// The hazard runs both ways. Too strict and a curly apostrophe fails a correct quotation, which
/// trains the researcher to ignore the warning. Too loose and a paraphrase passes, which is worse
/// than no check at all. Each rule below has to be one that cannot admit a paraphrase:
///
/// - **Whitespace runs collapse to one space**, and the result is trimmed. A quotation copied
///   across a line break or a page boundary differs from the body only in whitespace.
/// - **Quotation marks and apostrophes fold to their straight forms**, and dashes fold to one
///   hyphen. These are typographic substitutions the transcription pipeline itself makes.
/// - **Soft hyphens and zero-width characters are dropped.** They are invisible and carry no
///   textual meaning; a quotation containing one differs only in bytes.
/// - **Case folds.** A researcher quoting mid-sentence routinely capitalises the first letter. No
///   paraphrase is a case variant of its source, so this admits nothing.
///
/// None of these changes a *word*. That is the line: the policy normalises presentation and never
/// vocabulary, so a passage that "matched for its first sixty characters and then diverged into
/// paraphrase" — the third rejected passage in the reports — cannot pass.
///
/// ## Elision
/// Scholarly quotation elides, and an elided quotation is not a substring of anything. So a
/// quotation containing an elision marker (`…`, `...`, `[...]`) is split on it, and every fragment
/// must appear **in order**: fragment two is searched only in the text after fragment one ends.
/// Order is what keeps this from becoming a bag-of-phrases match that a rearrangement would pass.
///
/// Short fragments are the residual risk — `"the" … "of"` would match nearly any document — so a
/// fragment under ``minimumFragmentLength`` normalised characters makes the whole check
/// ``Outcome/inconclusive`` rather than passing it. Reporting "cannot verify" is honest; reporting
/// "verified" on evidence that weak is not.
///
/// Version history:
///   1.0 — M-3: initial implementation
enum ExcerptVerifier {

    /// The shortest fragment this will accept as evidence, in normalised characters.
    ///
    /// Below this a fragment matches too much of any document to mean anything. Applies per
    /// fragment, so a long quotation with one two-word fragment is inconclusive rather than
    /// verified — the weakest link governs, because a reader takes "verified" to cover the whole.
    static let minimumFragmentLength = 12

    /// What a check concluded.
    enum Outcome: Equatable, Sendable {
        /// Found, in order, in the indexed body text.
        case verified
        /// Not found. The quotation does not appear in the document it names.
        case notFound
        /// The volume is not on this device, so there was nothing to check against. **Not** a
        /// failure: a researcher who freed up space must not be told their quotation is wrong.
        case documentNotIndexed
        /// Too little to go on — an empty quotation, or a fragment shorter than
        /// ``minimumFragmentLength``.
        case inconclusive

        /// Whether this outcome should be surfaced as a problem with the quotation itself.
        ///
        /// Only ``notFound`` is. The other two non-verified cases are statements about what could
        /// be checked, and dressing them as failures is how a warning gets ignored.
        var isFailure: Bool { self == .notFound }
    }

    /// One quotation to check.
    struct Request: Hashable, Sendable {
        /// FRUS volume identifier.
        var volumeId: String
        /// Document identifier within the volume.
        var documentId: String
        /// The stored quotation, exactly as it will be exported.
        var text: String
    }

    // MARK: - Checking

    /// Checks one quotation against a document's body text.
    ///
    /// - Parameters:
    ///   - excerpt: the stored quotation.
    ///   - bodyText: the indexed body text, or `nil` when the document is not in the cache.
    /// - Returns: the outcome.
    static func verify(_ excerpt: String, against bodyText: String?) -> Outcome {
        guard let bodyText else { return .documentNotIndexed }
        let fragments = self.fragments(of: excerpt)
        guard !fragments.isEmpty else { return .inconclusive }
        guard fragments.allSatisfy({ $0.count >= minimumFragmentLength }) else { return .inconclusive }

        let haystack = normalize(bodyText)
        var searchFrom = haystack.startIndex
        for fragment in fragments {
            guard let found = haystack.range(of: fragment,
                                             range: searchFrom..<haystack.endIndex) else {
                return .notFound
            }
            // In order, not merely present: the next fragment starts after this one ends.
            searchFrom = found.upperBound
        }
        return .verified
    }

    /// Checks many quotations in one pass.
    ///
    /// - Parameters:
    ///   - requests: the quotations, in any order.
    ///   - bodyTexts: indexed body text by `"volumeId/documentId"` — the shape
    ///     `IndexingPipeline.documentBodyTextsByKey(forKeys:)` returns. A key it omits is a
    ///     document that is not indexed, which is why the miss is `.documentNotIndexed` rather
    ///     than an error.
    /// - Returns: one outcome per request.
    static func verify(_ requests: [Request],
                       bodyTexts: [String: String]) -> [Request: Outcome] {
        var results: [Request: Outcome] = [:]
        for request in requests {
            results[request] = verify(request.text,
                                      against: bodyTexts["\(request.volumeId)/\(request.documentId)"])
        }
        return results
    }

    // MARK: - Normalisation

    /// The elision markers a quotation may contain, longest first so `[...]` is not consumed as
    /// `...` leaving stray brackets behind.
    private static let elisionMarkers = ["[...]", "[…]", "...", "…"]

    /// Splits `excerpt` on elision markers and normalises each fragment, dropping empties.
    ///
    /// Empties are dropped so a quotation that opens or closes with an ellipsis — the ordinary way
    /// to mark a mid-sentence start — does not fail on a zero-length fragment.
    static func fragments(of excerpt: String) -> [String] {
        var pieces = [excerpt]
        for marker in elisionMarkers {
            pieces = pieces.flatMap { $0.components(separatedBy: marker) }
        }
        return pieces.map(normalize).filter { !$0.isEmpty }
    }

    /// Applies the normalisation policy described in this type's overview.
    ///
    /// - Parameter text: any string.
    /// - Returns: the comparable form. Both sides of every comparison go through this, so the
    ///   policy cannot be applied asymmetrically.
    static func normalize(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var lastWasSpace = false
        for scalar in text.unicodeScalars {
            switch scalar {
            // Invisible: soft hyphen, zero-width space/non-joiner/joiner, BOM.
            case "\u{00AD}", "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}":
                continue
            // Curly quotes and apostrophes, and the prime characters that stand in for them.
            case "\u{2018}", "\u{2019}", "\u{201A}", "\u{201B}", "\u{2032}":
                result.append("'"); lastWasSpace = false
            case "\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}", "\u{2033}":
                result.append("\""); lastWasSpace = false
            // En dash, em dash, minus, non-breaking hyphen, figure dash → hyphen.
            case "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}", "\u{2212}":
                result.append("-"); lastWasSpace = false
            default:
                if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    if !lastWasSpace, !result.isEmpty { result.append(" ") }
                    lastWasSpace = true
                } else {
                    result.unicodeScalars.append(scalar)
                    lastWasSpace = false
                }
            }
        }
        // Trailing space can only be the one appended above, so a single drop suffices.
        if result.hasSuffix(" ") { result.removeLast() }
        return result.lowercased()
    }
}

// MARK: - ExcerptVerificationReport

/// The result of checking every quotation in a collection before it is exported (M-3).
///
/// **Decision M-3-1: warn and annotate, never block.** A document dropped from the index is a
/// false alarm the researcher must be able to export past, and an export button that refuses to
/// work with no way through is how a tool gets abandoned mid-deadline. So this type carries what
/// to say, and the export proceeds regardless.
///
/// Version history:
///   1.0 — M-3: initial implementation
struct ExcerptVerificationReport: Equatable, Sendable {

    /// Quotations that were not found in the document they name.
    var failures: [ExcerptVerifier.Request]

    /// Quotations that could not be checked because their volume is not on this device.
    var unindexed: [ExcerptVerifier.Request]

    /// Quotations too short — or too heavily elided — to check.
    var inconclusive: [ExcerptVerifier.Request]

    /// How many were checked and found.
    var verifiedCount: Int

    /// Builds a report from a batch result.
    ///
    /// - Parameter outcomes: the result of ``ExcerptVerifier/verify(_:bodyTexts:)``.
    init(outcomes: [ExcerptVerifier.Request: ExcerptVerifier.Outcome]) {
        // Sorted, so the same collection reports the same order twice running — a dictionary's
        // iteration order would reshuffle the warning on every render.
        func sorted(_ outcome: ExcerptVerifier.Outcome) -> [ExcerptVerifier.Request] {
            outcomes.filter { $0.value == outcome }.keys
                .sorted { ($0.volumeId, $0.documentId, $0.text) < ($1.volumeId, $1.documentId, $1.text) }
        }
        failures = sorted(.notFound)
        unindexed = sorted(.documentNotIndexed)
        inconclusive = sorted(.inconclusive)
        verifiedCount = outcomes.values.filter { $0 == .verified }.count
    }

    /// `true` when at least one quotation does not appear in its source.
    var hasFailures: Bool { !failures.isEmpty }

    /// `true` when there is nothing at all to say — every quotation checked out.
    var isClean: Bool { failures.isEmpty && unindexed.isEmpty && inconclusive.isEmpty }

    /// The sentence shown above the export button, or `nil` when there is nothing to report.
    ///
    /// Failures lead, because they are the only category that says something is wrong with the
    /// work. The other two are stated after, and stated as limits on the check rather than as
    /// problems with the quotations.
    var summary: String? {
        guard !isClean else { return nil }
        var parts: [String] = []
        if !failures.isEmpty {
            parts.append(failures.count == 1
                ? String(localized: "excerpt.verify.failures.one",
                         defaultValue: "One quotation was not found in the document it cites.")
                : String(localized: "excerpt.verify.failures.many %lld",
                         defaultValue: "\(failures.count) quotations were not found in the documents they cite."))
        }
        if !unindexed.isEmpty {
            parts.append(String(localized: "excerpt.verify.unindexed %lld",
                                defaultValue: "\(unindexed.count) could not be checked — their volumes are not downloaded."))
        }
        if !inconclusive.isEmpty {
            parts.append(String(localized: "excerpt.verify.inconclusive %lld",
                                defaultValue: "\(inconclusive.count) were too short to check."))
        }
        return parts.joined(separator: " ")
    }
}
