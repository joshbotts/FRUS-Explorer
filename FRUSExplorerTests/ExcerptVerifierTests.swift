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
import Testing
@testable import FRUSExplorer

// MARK: - ExcerptVerifierTests

/// The normalisation policy, from both sides.
///
/// Every test here is one of two shapes: a correct quotation that must **not** be rejected over
/// presentation, or a wrong one that must **not** be accepted. A check that only ever passes is
/// worse than no check, because it certifies.
///
/// Version history:
///   1.0 — M-3: initial implementation
@Suite("Excerpt verification")
struct ExcerptVerifierTests {

    /// A passage in the register these quotations actually come from, with the typography a TEI
    /// body carries: curly quotes, an em dash, a line break mid-sentence.
    private let body = """
    The Soviet Union, unlike previous aspirants to hegemony, is animated by a new fanatic faith,
    antithetical to our own, and seeks to impose its absolute authority over the rest of the
    world. Conflict has, in fact, become endemic — and the “free society” is at a
    disadvantage which it must overcome by the “integrity and vitality of its system.”
    """

    // MARK: - The plan's four cases

    @Test("A correct quotation passes")
    func correctQuotation() {
        #expect(ExcerptVerifier.verify("animated by a new fanatic faith", against: body) == .verified)
    }

    @Test("A whitespace-mangled quotation passes")
    func whitespaceMangled() {
        // Copied across a line break and re-wrapped: the words are identical.
        let mangled = "is animated by a new fanatic\n\n   faith,\tantithetical to our own"
        #expect(ExcerptVerifier.verify(mangled, against: body) == .verified)
    }

    @Test("A smart-quote variant passes")
    func smartQuoteVariant() {
        // The researcher's notes carry straight quotes; the body carries curly ones.
        #expect(ExcerptVerifier.verify("the \"free society\" is at a", against: body) == .verified)
        // And the other direction, since normalisation runs on both sides.
        #expect(ExcerptVerifier.verify("the “integrity and vitality of its system.”",
                                       against: body) == .verified)
    }

    /// The case that gives the whole feature its point. The reports' third rejected passage
    /// "matched for its first sixty characters and then diverged into paraphrase".
    @Test("A paraphrase fails")
    func paraphraseFails() {
        let paraphrase = "The Soviet Union, unlike previous aspirants to hegemony, is driven by "
            + "a fervent new ideology hostile to our own"
        #expect(ExcerptVerifier.verify(paraphrase, against: body) == .notFound)
    }

    // MARK: - Normalisation, rule by rule

    @Test("A soft hyphen is invisible and does not fail a quotation")
    func softHyphen() {
        #expect(ExcerptVerifier.verify("fa\u{00AD}natic faith", against: body) == .verified)
    }

    @Test("Dash styles interconvert")
    func dashes() {
        #expect(ExcerptVerifier.verify("become endemic - and the", against: body) == .verified)
        #expect(ExcerptVerifier.verify("become endemic – and the", against: body) == .verified)
    }

    @Test("Case folds, because a mid-sentence quote is routinely capitalised")
    func caseFolds() {
        #expect(ExcerptVerifier.verify("Antithetical to our own", against: body) == .verified)
    }

    /// The line the policy must not cross: it normalises presentation, never vocabulary. If any
    /// rule folded words, this would pass.
    @Test("One wrong word fails")
    func oneWrongWordFails() {
        #expect(ExcerptVerifier.verify("animated by a new fanatical faith",
                                       against: body) == .notFound)
        #expect(ExcerptVerifier.verify("animated by a new faith", against: body) == .notFound)
    }

    // MARK: - Elision

    @Test("An elided quotation passes when its fragments appear in order")
    func elisionInOrder() {
        for marker in ["…", "...", "[...]"] {
            #expect(ExcerptVerifier.verify(
                "animated by a new fanatic faith \(marker) Conflict has, in fact, become endemic",
                against: body) == .verified,
                    "marker \(marker) was not recognised")
        }
    }

    /// Order is what stops this being a bag-of-phrases match. Two real phrases in the wrong order
    /// are not a quotation of this passage.
    @Test("An elided quotation fails when its fragments are out of order")
    func elisionOutOfOrder() {
        #expect(ExcerptVerifier.verify(
            "Conflict has, in fact, become endemic … animated by a new fanatic faith",
            against: body) == .notFound)
    }

    @Test("A leading or trailing ellipsis does not create an empty fragment")
    func edgeEllipsis() {
        #expect(ExcerptVerifier.verify("… animated by a new fanatic faith …",
                                       against: body) == .verified)
    }

    /// The residual risk elision opens: `"the" … "of"` matches nearly any document. Reporting
    /// "cannot verify" is honest; reporting "verified" on evidence that weak is not.
    @Test("A too-short fragment makes the whole check inconclusive, not verified")
    func shortFragmentIsInconclusive() {
        #expect(ExcerptVerifier.verify("the … of", against: body) == .inconclusive)
        // The weakest link governs — a long fragment does not rescue a short one, because a
        // reader takes "verified" to cover the whole quotation.
        #expect(ExcerptVerifier.verify("animated by a new fanatic faith … the",
                                       against: body) == .inconclusive)
        #expect(ExcerptVerifier.verify("", against: body) == .inconclusive)
        #expect(ExcerptVerifier.verify("   \n  ", against: body) == .inconclusive)
    }

    // MARK: - Not indexed

    /// A researcher who freed up disk space must not be told their quotations are wrong.
    @Test("An unindexed document is not a failure")
    func unindexedIsNotAFailure() {
        let outcome = ExcerptVerifier.verify("animated by a new fanatic faith", against: nil)
        #expect(outcome == .documentNotIndexed)
        #expect(!outcome.isFailure)
        #expect(ExcerptVerifier.Outcome.inconclusive.isFailure == false)
        #expect(ExcerptVerifier.Outcome.notFound.isFailure)
    }

    // MARK: - Batch

    @Test("A batch attributes each outcome to its own document")
    func batchAttribution() {
        let good = ExcerptVerifier.Request(volumeId: "v1", documentId: "d1",
                                           text: "animated by a new fanatic faith")
        // The same true quotation, attributed to a document that does not contain it. This is the
        // failure mode that matters most: a real phrase filed under the wrong citation.
        let misfiled = ExcerptVerifier.Request(volumeId: "v1", documentId: "d2",
                                               text: "animated by a new fanatic faith")
        let missing = ExcerptVerifier.Request(volumeId: "v9", documentId: "d1",
                                              text: "animated by a new fanatic faith")
        let outcomes = ExcerptVerifier.verify([good, misfiled, missing],
                                              bodyTexts: ["v1/d1": body,
                                                          "v1/d2": "An unrelated document body."])
        #expect(outcomes[good] == .verified)
        #expect(outcomes[misfiled] == .notFound)
        #expect(outcomes[missing] == .documentNotIndexed)
    }
}

// MARK: - ExcerptVerificationReportTests

/// What the export sheet says, and what it refuses to say.
///
/// Version history:
///   1.0 — M-3: initial implementation
@Suite("Excerpt verification report")
struct ExcerptVerificationReportTests {

    private func request(_ id: String) -> ExcerptVerifier.Request {
        ExcerptVerifier.Request(volumeId: "v1", documentId: id, text: "some quoted text here")
    }

    @Test("A clean collection says nothing")
    func cleanSaysNothing() {
        let report = ExcerptVerificationReport(outcomes: [request("d1"): .verified,
                                                          request("d2"): .verified])
        #expect(report.isClean)
        #expect(report.summary == nil, "a passing check must not add a line to the sheet")
        #expect(report.verifiedCount == 2)
        #expect(!report.hasFailures)
    }

    @Test("A failure leads the summary")
    func failureLeads() {
        let report = ExcerptVerificationReport(outcomes: [request("d1"): .notFound,
                                                          request("d2"): .documentNotIndexed])
        let summary = try? #require(report.summary)
        #expect(report.hasFailures)
        #expect(summary?.hasPrefix("One quotation was not found") == true, "got: \(summary ?? "nil")")
        #expect(summary?.contains("not downloaded") == true,
                "the uncheckable ones are stated too, after")
    }

    /// The two non-failure categories must not make `hasFailures` true, or the sheet turns orange
    /// and warns about quotations that are fine.
    @Test("Uncheckable is not a failure")
    func uncheckableIsNotAFailure() {
        let report = ExcerptVerificationReport(outcomes: [request("d1"): .documentNotIndexed,
                                                          request("d2"): .inconclusive])
        #expect(!report.hasFailures)
        #expect(!report.isClean, "there is still something to say")
        #expect(report.summary?.contains("not found") != true)
    }

    /// The lists drive a rendered warning, and a dictionary's iteration order would reshuffle it
    /// on every body pass.
    @Test("The lists are stably ordered")
    func stableOrder() {
        let outcomes: [ExcerptVerifier.Request: ExcerptVerifier.Outcome] = [
            request("d3"): .notFound, request("d1"): .notFound, request("d2"): .notFound
        ]
        let first = ExcerptVerificationReport(outcomes: outcomes).failures.map(\.documentId)
        #expect(first == ["d1", "d2", "d3"])
        for _ in 0..<5 {
            #expect(ExcerptVerificationReport(outcomes: outcomes).failures.map(\.documentId) == first)
        }
    }

    /// Plural agreement, spelled out — there is no String Catalog, so "1 quotations" would ship.
    @Test("One failure reads as one")
    func pluralAgreement() {
        let one = ExcerptVerificationReport(outcomes: [request("d1"): .notFound])
        #expect(one.summary?.contains("One quotation was") == true)
        #expect(one.summary?.contains("1 quotations") != true)
        let two = ExcerptVerificationReport(outcomes: [request("d1"): .notFound,
                                                       request("d2"): .notFound])
        #expect(two.summary?.contains("2 quotations were") == true)
    }
}

// MARK: - ExcerptVerificationWiringTests

/// The export sheet runs the check, on both platforms, and never blocks on it.
///
/// A source audit because the sheet needs an `AppState` and a live pipeline. The thing being
/// guarded is the one that has bitten this codebase repeatedly: a feature mounted on one platform
/// body and not the other.
///
/// Version history:
///   1.0 — M-3: initial implementation
@Suite("Excerpt verification wiring")
struct ExcerptVerificationWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    @Test("The check is mounted once, above both platform bodies")
    func mountedOnce() throws {
        let sheet = try Self.source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        #expect(sheet.contains(".task { await verifyExcerpts() }"))
        // Mounted on the shared `body`, not inside a platform branch — which is the whole point.
        let bodyRange = try #require(sheet.range(of: "var body: some View {"))
        let macRange = try #require(sheet.range(of: "private var macExportBody"))
        #expect(sheet.range(of: ".task { await verifyExcerpts() }",
                            range: bodyRange.upperBound..<macRange.lowerBound) != nil,
                "the check must be mounted before the platform bodies diverge")
    }

    /// Decision M-3-1: warn and annotate, never block. An export button disabled by a check the
    /// researcher cannot satisfy — because a volume is off the device — is a dead end.
    @Test("The check never disables the export button")
    func neverBlocks() throws {
        let sheet = try Self.source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        for disabled in sheet.components(separatedBy: ".disabled(").dropFirst() {
            let clause = disabled.prefix(120)
            #expect(!clause.contains("verification"),
                    "M-3-1: a quotation warning must not gate the export — found: \(clause)")
        }
    }

    @Test("A read failure reports as uncheckable, never as wrong")
    func readFailureIsNotAVerdict() throws {
        let sheet = try Self.source("FRUSExplorer/Collections/CollectionExportSheet.swift")
        #expect(sheet.contains("documentBodyTextsByKey(forKeys: Array(keys))) ?? [:]"),
                "a thrown read must degrade to an empty map, which reports as not-indexed")
        #expect(sheet.contains("ExcerptVerifier.Outcome.documentNotIndexed"),
                "a missing pipeline must report uncheckable rather than skipping the check")
    }

    /// R-5 P3b-1 (design Q-7 g): a document an update removed is named as such, not as "volume
    /// not downloaded"; the report is not clean while one is present; one and many read as English.
    @Test("A vanished document's quotation is its own bucket, with a one-form and a many-form")
    func vanishedBucket() {
        let a = ExcerptVerifier.Request(volumeId: "v1", documentId: "d1", text: "some quoted words here")
        let b = ExcerptVerifier.Request(volumeId: "v1", documentId: "d3", text: "more quoted words here")
        let unindexed = ExcerptVerifier.Request(volumeId: "v1", documentId: "d2", text: "other quoted words here")
        let one = ExcerptVerificationReport(outcomes: [a: .documentVanished, unindexed: .documentNotIndexed])
        #expect(one.vanished == [a])
        #expect(one.unindexed == [unindexed])
        #expect(!one.isClean && !one.hasFailures)
        #expect((one.summary ?? "").contains("One quotation cites a document that an update removed from its volume."))
        #expect((one.summary ?? "").contains("1 could not be checked"))
        let many = ExcerptVerificationReport(outcomes: [a: .documentVanished, b: .documentVanished])
        #expect((many.summary ?? "").contains("2 quotations cite documents that an update removed from their volumes."))
    }

    /// The rule that turns a verifier miss into the vanished bucket: only a `documentNotIndexed`
    /// miss, and only for a kind that is exactly `"vanished"`. A freed volume's documents carry
    /// revision rows too, so `"body"`, `"apparatus"`, `""` and an absent key must all leave the
    /// miss alone — the mutation sweep on the first version found `row != nil` indistinguishable.
    @Test("upgradingVanished touches only documentNotIndexed misses whose kind is exactly vanished")
    func upgradingVanished() {
        func req(_ d: String) -> ExcerptVerifier.Request { .init(volumeId: "v1", documentId: d, text: "quoted words long enough") }
        let outcomes: [ExcerptVerifier.Request: ExcerptVerifier.Outcome] = [
            req("gone"): .documentNotIndexed, req("freed"): .documentNotIndexed, req("edited"): .documentNotIndexed,
            req("unknown"): .documentNotIndexed, req("lost"): .notFound, req("ok"): .verified,
        ]
        let kinds = ["v1/gone": "vanished", "v1/freed": "", "v1/edited": "body", "v1/lost": "vanished", "v1/ok": "vanished"]
        let upgraded = ExcerptVerifier.upgradingVanished(outcomes, changeKinds: kinds)
        #expect(upgraded[req("gone")] == .documentVanished)
        #expect(upgraded[req("freed")] == .documentNotIndexed)
        #expect(upgraded[req("edited")] == .documentNotIndexed)
        #expect(upgraded[req("unknown")] == .documentNotIndexed)
        #expect(upgraded[req("lost")] == .notFound, "a real miss is never relabelled")
        #expect(upgraded[req("ok")] == .verified)
        #expect(upgraded.count == outcomes.count)
    }
}
