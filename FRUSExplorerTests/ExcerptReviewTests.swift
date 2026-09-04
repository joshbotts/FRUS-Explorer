// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - ExcerptReviewTests

/// What the review sheet says about a stored quotation after a volume update (R-5 P3b-4,
/// design Q-7).
///
/// Two things are pinned here that the view cannot pin for itself: the four capture states —
/// including the one an optional field makes real and a highlight's non-optional one does not —
/// and the rule that only a genuine miss reads as a problem.
///
/// Version history:
///   1.0 — R-5 P3b-4: initial implementation
@Suite("Excerpt review — the capture state and the sentence per verdict")
struct ExcerptReviewTests {

    // MARK: - Capture

    /// `nil` and "no current version" are DIFFERENT answers, and folding them would tell a
    /// footnote quotation — which routinely carries no version, because a footnote selection
    /// reports text without offsets — that this device has no record to compare it against.
    @Test("capture separates a missing stored version from a missing current one")
    func captureStates() {
        #expect(ExcerptReview.capture(storedVersion: "abc", currentVersion: "abc") == .current)
        #expect(ExcerptReview.capture(storedVersion: "abc", currentVersion: "def") == .earlier)
        #expect(ExcerptReview.capture(storedVersion: nil, currentVersion: "def") == .unversioned)
        #expect(ExcerptReview.capture(storedVersion: "abc", currentVersion: nil) == .unverifiable)
        #expect(ExcerptReview.capture(storedVersion: nil, currentVersion: nil) == .unverifiable)
    }

    /// An empty string is the same fact as nil on both sides. `excerptRenderingVersion` is written
    /// as `renderingVersion.isEmpty ? nil : …` on one path but copied verbatim on the importer's,
    /// so an empty value can reach here.
    @Test("An empty version is treated as an absent one, on either side")
    func emptyVersionsAreAbsences() {
        #expect(ExcerptReview.capture(storedVersion: "", currentVersion: "def") == .unversioned)
        #expect(ExcerptReview.capture(storedVersion: "abc", currentVersion: "") == .unverifiable)
        // The current version is checked FIRST: with neither known, the answer is that there is
        // nothing to compare against, not that the quotation lacks a version.
        #expect(ExcerptReview.capture(storedVersion: "", currentVersion: "") == .unverifiable)
    }

    // MARK: - Sentences

    /// Every outcome gets a line, no two lines are the same, and none of them tells the reader
    /// their quotation is wrong.
    @Test("findingLine covers all five outcomes with distinct sentences")
    func findingLines() {
        let outcomes: [ExcerptVerifier.Outcome] =
            [.verified, .notFound, .documentVanished, .documentNotIndexed, .inconclusive]
        let lines = outcomes.map(ExcerptReview.findingLine)
        #expect(Set(lines).count == outcomes.count)
        #expect(lines.allSatisfy { !$0.isEmpty })

        #expect(ExcerptReview.findingLine(.verified).contains("still in the document"))
        // Both causes, and neither asserted: about half of real corrections RENUMBER, so a miss
        // often means this id now names a different document.
        let miss = ExcerptReview.findingLine(.notFound)
        #expect(miss.contains("corrected") && miss.contains("renumbered"))
        #expect(!miss.lowercased().contains("wrong"))
        // The P3b-1 misreport, on the new surface: a vanished document must not be described as a
        // volume the reader failed to download.
        let vanished = ExcerptReview.findingLine(.documentVanished)
        #expect(vanished.contains("no longer in the volume"))
        #expect(!vanished.contains("on this device"))
        // Reworded in review: "this volume is not downloaded" is the usual cause but not the only
        // one, and on the banner route the reader is looking at the document while the row speaks.
        let notIndexed = ExcerptReview.findingLine(.documentNotIndexed)
        #expect(notIndexed.contains("no indexed text for this document on this device"))
        #expect(!notIndexed.contains("volume is not"))
        #expect(ExcerptReview.findingLine(.inconclusive).contains("too many documents"))
    }

    /// The quiet cases are quiet. A row that shows a capture line is saying something real.
    @Test("captureLine speaks only when it has something to add")
    func captureLines() throws {
        #expect(ExcerptReview.captureLine(.current) == nil)
        #expect(ExcerptReview.captureLine(.unverifiable) == nil)
        let earlier = try #require(ExcerptReview.captureLine(.earlier))
        let unversioned = try #require(ExcerptReview.captureLine(.unversioned))
        #expect(earlier != unversioned)
        #expect(ExcerptReview.captureLine(.earlier)?.contains("earlier version") == true)
        // Absence of a version is a fact about how the quotation was TAKEN. Wording it as
        // staleness would report an alarm about a copy that cannot have moved.
        let none = ExcerptReview.captureLine(.unversioned) ?? ""
        #expect(none.contains("without a record"))
        #expect(!none.contains("earlier"))
    }

    /// Only a genuine miss is a problem. `ExcerptVerifier`'s own overview argues that dressing the
    /// other outcomes as failures is how a warning gets ignored, and `.inconclusive` — anything
    /// under twelve normalised characters, or an elided quotation — is the one most likely to
    /// fire on a perfectly good quotation.
    @Test("Only notFound reads as a warning, and it agrees with the verifier's own rule")
    func warningVocabulary() {
        #expect(ExcerptReview.isWarning(.notFound))
        for outcome: ExcerptVerifier.Outcome in [.verified, .documentVanished, .documentNotIndexed, .inconclusive] {
            #expect(!ExcerptReview.isWarning(outcome), "\(outcome) is a limit on the check, not a problem")
            #expect(ExcerptReview.isWarning(outcome) == outcome.isFailure)
        }
        #expect(ExcerptReview.isWarning(.notFound) == ExcerptVerifier.Outcome.notFound.isFailure)
    }

    // MARK: - The composed row

    /// The two sentences are independently correct and can still contradict each other, which is
    /// the whole reason `lines` exists. On a vanished document `body_hash` SURVIVES the vanish
    /// mark by design, so the version comparison has a comparand and would print "captured from an
    /// earlier version" directly under "there is nothing to check it against".
    @Test("A vanished document prints no capture line, whatever the versions say")
    func vanishedSuppressesTheCaptureLine() {
        for stored in [nil, "", "0123456789abcdef", "fedcba9876543210"] {
            let row = ExcerptReview.lines(outcome: .documentVanished,
                                          storedVersion: stored,
                                          currentVersion: "fedcba9876543210")
            #expect(row.capture == nil, "stored=\(stored ?? "nil") must print no capture line")
            #expect(row.finding.contains("no longer in the volume"))
        }
        // The primitive still answers the version question on its own — the suppression belongs to
        // the composition, not to `capture`, which is about versions and nothing else.
        #expect(ExcerptReview.capture(storedVersion: "abc", currentVersion: "def") == .earlier)
    }

    /// The asymmetry that decides the copy, pinned so nobody re-derives the withdrawn shortcut.
    ///
    /// A first draft gave "not found while the version is unchanged" its own sentence, reasoning
    /// that version equality ruled out a correction and left only a renumbering. It does not. The
    /// version belongs to the render flat text, which excludes footnotes; the verifier reads the
    /// index's body text, which includes them; and an APPARATUS correction is precisely one that
    /// moves the second and not the first. So a quoted footnote can begin failing with its version
    /// still equal, and a sentence claiming the words never matched would be false for the
    /// commonest correction there is.
    @Test("Not found keeps the hedged sentence even when the stored version still matches")
    func notFoundAgainstUnchangedVersion() {
        let unchanged = ExcerptReview.lines(outcome: .notFound,
                                            storedVersion: "0123456789abcdef",
                                            currentVersion: "0123456789abcdef")
        #expect(unchanged.finding == ExcerptReview.findingLine(.notFound))
        #expect(unchanged.finding.contains("corrected") && unchanged.finding.contains("renumbered"))
        #expect(unchanged.capture == nil, "an unchanged version has nothing to add")
        #expect(!unchanged.finding.contains("did not match"),
                "the app must not claim the words never matched: an apparatus correction changes the text it searches")
        let moved = ExcerptReview.lines(outcome: .notFound,
                                        storedVersion: "0123456789abcdef",
                                        currentVersion: "fedcba9876543210")
        #expect(moved.finding == unchanged.finding, "one sentence, whatever the version says")
        #expect(moved.capture?.contains("earlier version") == true)
    }

    /// Every other pairing goes through unchanged, so the vanished suppression is the ONLY place
    /// the composition departs from its parts.
    @Test("lines otherwise returns exactly findingLine and captureLine")
    func compositionIsOtherwiseTransparent() {
        let outcomes: [ExcerptVerifier.Outcome] = [.verified, .notFound, .documentNotIndexed, .inconclusive]
        let versions: [(String?, String?)] = [("a", "a"), ("a", "b"), (nil, "b"), ("a", nil), (nil, nil)]
        for outcome in outcomes {
            for (stored, current) in versions {
                let capture = ExcerptReview.capture(storedVersion: stored, currentVersion: current)
                let row = ExcerptReview.lines(outcome: outcome, storedVersion: stored, currentVersion: current)
                #expect(row.finding == ExcerptReview.findingLine(outcome))
                #expect(row.capture == ExcerptReview.captureLine(capture))
            }
        }
    }

    // MARK: - Through the real verifier

    /// The whole path the sheet runs, with no view: verify against the indexed body text, upgrade
    /// the miss on a vanished document, then say it. Written through the shipped rules rather than
    /// re-stating them, because the row's honesty depends on `upgradingVanished` being called —
    /// omit it and every quotation on a removed document reads "this volume is not on this device".
    @Test("A vanished document's quotation reads as removed, not as an undownloaded volume")
    func vanishedPathEndToEnd() {
        let request = ExcerptVerifier.Request(volumeId: "frus1969v01", documentId: "d12",
                                              text: "the Secretary observed that the situation had deteriorated")
        // No body text: the document is not in the cache, which is what a vanished document and a
        // freed volume look like alike.
        let raw = ExcerptVerifier.verify([request], bodyTexts: [:])
        #expect(raw[request] == .documentNotIndexed)
        #expect(ExcerptReview.findingLine(raw[request] ?? .inconclusive).contains("no indexed text"))

        let upgraded = ExcerptVerifier.upgradingVanished(raw, changeKinds: ["frus1969v01/d12": "vanished"])
        #expect(upgraded[request] == .documentVanished)
        let line = ExcerptReview.findingLine(upgraded[request] ?? .inconclusive)
        #expect(line.contains("no longer in the volume"))
        #expect(!line.contains("on this device"))
    }

    /// A quotation whose words survive a correction is the common case, and the pair of lines has
    /// to read as one coherent statement: the words are there, and they were taken from the text
    /// as it stood before. Neither line mentions the other's subject.
    @Test("Found words plus an earlier capture read as reassurance, not as a conflict")
    func foundButCapturedEarlier() {
        let body = "The Ambassador reported that the delegation would arrive on Tuesday."
        let outcome = ExcerptVerifier.verify("the delegation would arrive on Tuesday", against: body)
        #expect(outcome == .verified)
        let finding = ExcerptReview.findingLine(outcome)
        let capture = ExcerptReview.captureLine(
            ExcerptReview.capture(storedVersion: "0123456789abcdef", currentVersion: "fedcba9876543210"))
        #expect(!ExcerptReview.isWarning(outcome))
        #expect(finding.contains("still in the document"))
        #expect(capture?.contains("earlier version") == true)
        // The finding never mentions a version and the capture never mentions the words, so the
        // two cannot be read as contradicting each other.
        #expect(!finding.lowercased().contains("version"))
        #expect(capture?.lowercased().contains("found") == false)
    }
}
