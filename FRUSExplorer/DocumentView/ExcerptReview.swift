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

// MARK: - ExcerptReview

/// What the review sheet may say about one stored quotation after a volume update
/// (Volume-Update-Annotation-Integrity design Q-7, R-5 P3b-4).
///
/// ## Why an excerpt is reviewed differently from a highlight
/// A highlight is a *pointer*: two offsets into a rendering, and a correction can move the text
/// out from under them, which is why `HighlightReview` is about position and offers to re-anchor.
/// An excerpt is a *copy*: the passage was frozen into the collection at capture and renders from
/// that copy, so a correction cannot break it on screen and there is nothing to move. What a
/// correction can do is make the copy no longer match the record it cites — and that is a
/// question about words, which is why this type asks the verifier rather than the offsets.
///
/// So the two sources this reads are complementary, and neither substitutes for the other:
///
/// - ``ExcerptVerifier`` answers **do these words still appear in the document**, by the same
///   deterministic comparison the export sheet runs. Reusing it is deliberate: a reader who sees
///   "not found" here and "not found" on the way out is seeing one fact twice, not two checks
///   that might disagree.
/// - `CollectionEntry.excerptRenderingVersion` answers **which version of the text it was taken
///   from**, in the same vocabulary a `DocumentHighlight` uses, so comparing it to the document's
///   current version is exactly the comparison `HighlightReview.status` makes. Design Q-7 (f):
///   before P3b-4 the field was stored by three writers and read by none.
///
///   Where the value comes from differs by path, and the difference is worth stating because it
///   decides what "an earlier version" means on screen. A quotation captured from a live SELECTION
///   stores `ASTToRenderNodeConverter.renderingVersion` of the model then on screen. A quotation
///   made from a stored HIGHLIGHT copies that highlight's own `renderingVersion` — the version
///   when the highlight was made, or when the reader last confirmed or moved it — which is older
///   than the excerpt and is the right answer anyway: it is the version of the text those words
///   were read off. `Collection.duplicate` and the native importer copy whatever the source
///   carried. In every case the field names the text the words came from, never the moment the
///   entry row was written.
///
/// Together they separate two cases a single check confuses. *Found, and captured from an earlier
/// version* means the correction left the quoted words alone — the reassuring case, and the
/// common one, since most corrections touch an apparatus. *Not found, and captured from an earlier
/// version* is the one worth a reader's time.
///
/// ## The two answers read different texts, and the wording has to survive that
/// They are not two views of one string. The verifier searches the INDEX's `body_text`, which
/// includes footnotes; the version hashes `flatText(model.bodyNodes)`, which excludes them —
/// `ASTToRenderNodeConverter.kVersion`'s own note records that no footnote marker has ever
/// contributed a character to the highlight coordinate space. So a quotation taken from a
/// footnote routinely verifies while carrying NO version at all, because the capture paths write
/// `excerptRenderingVersion` only when the selection reported offsets and a footnote selection
/// reports text only.
///
/// That combination is common rather than exceptional, and it is why ``Capture/unversioned`` has
/// its own sentence instead of falling in with ``Capture/earlier``: absence of a version is a
/// fact about how the quotation was taken, never evidence that the text moved. It is also why
/// neither line mentions the other's subject. One says what the words did; the other says which
/// text they were taken from. A row must never read as though the app were contradicting itself.
///
/// ## Which hash tracks which text, because it runs the opposite way to intuition
/// The banner above these rows reports `change_kind`, and that is decided by `body_hash` — the
/// render flat text, footnotes EXCLUDED, the same string `excerptRenderingVersion` belongs to. A
/// correction is `apparatus` exactly when that string did NOT move while `content_hash` did, and
/// `content_hash` covers the header, the dateline, the source note and the index's `body_text`,
/// which INCLUDES footnote prose and is the verifier's haystack.
///
/// So an apparatus-only correction leaves the version equal and changes the haystack. A quotation
/// taken from a footnote can therefore begin failing under a correction the banner describes as
/// touching only the notes, with its capture reading `.current` — and that is not a contradiction
/// but the literal truth about two different strings. The section footer says so, in those terms.
///
/// This is why there is NO special sentence for "not found, and the version is unchanged". A first
/// draft added one, reasoning that version equality disproved a correction and left only a
/// renumbering. It does not: version equality speaks for the body text alone. The general
/// ``findingLine`` sentence, which offers a correction and a renumbering and commits to neither,
/// is the one that survives this asymmetry.
///
/// ## A capture-format artefact this cannot distinguish from a correction
/// The verifier normalises whitespace but never inserts it, and the two strings disagree about
/// block boundaries: the index joins nodes with a space, while the flat text a highlight was
/// sliced from runs blocks together with no separator. A quotation spanning a block seam that was
/// captured before 2026-07-03 — when `selectedText` was a raw slice rather than
/// `flatTextExcerpt` output — therefore reports `notFound` for a formatting reason and not a
/// textual one. This is a property of the shipped export check, unchanged by P3b-4, which is the
/// reason ``findingLine`` hedges `notFound` instead of asserting the words are gone.
///
/// ## What it refuses to say
/// Per the design's §7, nothing here tells the reader their quotation is wrong. `notFound` names
/// two causes and commits to neither, because roughly half the documents a real correction
/// touches are RENUMBERED rather than edited: in those, this document id now names a different
/// document, and the passage is elsewhere rather than gone. Nothing here deletes or rewrites an
/// entry either — an excerpt belongs to a collection, and the collection editor is where it is
/// changed.
///
/// Version history:
///   1.0 — R-5 P3b-4: initial implementation
enum ExcerptReview {

    /// Which version of the text a stored quotation was taken from, relative to the text now.
    enum Capture: Equatable, Sendable {
        /// Captured from the text as it currently reads: the correction did not reach this
        /// document, or reached it after the capture.
        case current
        /// Captured from an earlier version — the document has been corrected since.
        case earlier
        /// The entry carries no version. Either it predates the anchor fields, or the capture
        /// path had no offsets to report (a footnote selection returns text only).
        case unversioned
        /// Nothing to compare against: this device has neither an open rendering nor a revision
        /// row for the document.
        case unverifiable
    }

    /// Where the quotation came from, against the version the sheet is judging by.
    ///
    /// - Parameters:
    ///   - storedVersion: the entry's `excerptRenderingVersion`.
    ///   - currentVersion: the document's current `renderingVersion`, or the revision row's
    ///     `bodyHash` — the sheet's `effectiveVersion`, the same input `HighlightReview.status`
    ///     takes.
    static func capture(storedVersion: String?, currentVersion: String?) -> Capture {
        guard let currentVersion, !currentVersion.isEmpty else { return .unverifiable }
        guard let storedVersion, !storedVersion.isEmpty else { return .unversioned }
        return storedVersion == currentVersion ? .current : .earlier
    }

    /// What an exact search of the current text found — one line per verifier outcome.
    ///
    /// `documentVanished` is reachable here only because the caller applied
    /// `ExcerptVerifier.upgradingVanished`; the verifier itself reads a vanished document and a
    /// freed volume alike.
    static func findingLine(_ outcome: ExcerptVerifier.Outcome) -> String {
        switch outcome {
        case .verified:
            return String(localized: "document.review.excerpt.verified",
                          defaultValue: "These words are still in the document as it reads now.")
        case .notFound:
            return String(localized: "document.review.excerpt.notFound",
                          defaultValue: "These words are not in the document as it reads now. The passage may have been corrected, or this document may have been renumbered and this one may not be the same document.")
        case .documentVanished:
            return String(localized: "document.review.excerpt.vanished",
                          defaultValue: "The document is no longer in the volume, so there is nothing to check the quotation against.")
        case .documentNotIndexed:
            // Deliberately not "this volume is not downloaded". That is the usual cause but not the
            // only one — a nil pipeline and a swallowed read failure land here too — and on the
            // banner route the reader is looking at the document while the row speaks.
            return String(localized: "document.review.excerpt.notIndexed.v2",
                          defaultValue: "There is no indexed text for this document on this device, so the quotation could not be checked.")
        case .inconclusive:
            return String(localized: "document.review.excerpt.inconclusive",
                          defaultValue: "Too short, or too heavily elided, to check: a fragment this brief appears in too many documents to prove anything.")
        }
    }

    /// What the stored version says, or `nil` where it would add nothing.
    ///
    /// `.current` and `.unverifiable` both return nil, for opposite reasons: the first has nothing
    /// to report, and the second has nothing to report it FROM — the sheet's own change section
    /// already says the device holds no record to compare against, and repeating it per row would
    /// read as a fact about the quotation.
    static func captureLine(_ capture: Capture) -> String? {
        switch capture {
        case .current, .unverifiable:
            return nil
        case .earlier:
            return String(localized: "document.review.excerpt.capturedEarlier",
                          defaultValue: "Captured from an earlier version of the text.")
        case .unversioned:
            return String(localized: "document.review.excerpt.capturedUnversioned",
                          defaultValue: "Captured without a record of which version of the text it came from.")
        }
    }

    /// The whole row, composed — the ONE entry point a view should use.
    ///
    /// Composing here rather than in the view is not tidiness. Two independently correct sentences
    /// can still contradict each other on one row, and both ways of doing it were shipped in a
    /// draft of this file and caught in review:
    ///
    /// - On a **vanished** document the finding says there is nothing to check against, while the
    ///   version comparison still had a comparand — `body_hash` survives the vanish mark by design
    ///   — and printed "Captured from an earlier version of the text" underneath it. There is no
    ///   current text for a removed document to have been captured from, so the capture is
    ///   ``Capture/unverifiable`` whatever the hashes say.
    /// A second special case was drafted and WITHDRAWN, and the reason belongs here so it is not
    /// re-derived: a quotation that is not found while its capture reads `.current` looks like a
    /// case where version equality has ruled out a correction and left only a renumbering. It has
    /// not. The version speaks for the render flat text; the verifier reads the footnote-including
    /// body text; and an apparatus correction moves the second while leaving the first. A sentence
    /// asserting the words never matched would be false for the commonest correction there is.
    ///
    /// - Returns: the finding, always; and the capture line, only where it adds something true.
    static func lines(outcome: ExcerptVerifier.Outcome,
                      storedVersion: String?,
                      currentVersion: String?) -> (finding: String, capture: String?) {
        let capture = outcome == .documentVanished
            ? Capture.unverifiable
            : self.capture(storedVersion: storedVersion, currentVersion: currentVersion)
        return (findingLine(outcome), captureLine(capture))
    }

    /// Whether the row should read as a warning rather than as a statement.
    ///
    /// Only `notFound` does, matching `ExcerptVerifier.Outcome.isFailure`: the other outcomes are
    /// statements about what could be checked, and colouring them as problems is how a warning
    /// gets ignored. A capture from an earlier version is NOT a warning on its own — it is the
    /// ordinary state of every quotation taken before a correction, including the ones the
    /// correction left untouched.
    static func isWarning(_ outcome: ExcerptVerifier.Outcome) -> Bool { outcome.isFailure }
}
