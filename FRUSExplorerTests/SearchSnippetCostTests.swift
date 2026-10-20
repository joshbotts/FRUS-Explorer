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

import Testing
import Foundation
@testable import FRUSExplorer

/// The search snippet builder's cost, and the invariant the fix rests on.
///
/// ## What was wrong
/// `SearchService.makeContextSnippet` scanned a document's whole body, and for **every
/// word** allocated three Strings and ran the full Porter stemmer. On a corpus search that
/// runs to completion for every row that has no body match — which is not exotic: it fires
/// whenever the hit was in a header, dateline, source note, summary or note, a fallback the
/// code documents at its own call site.
///
/// Measured against the real 316,839-document index: the macOS window's 7,500-row fetch
/// spent **41 seconds** stemming roughly six million words and then threw every result away
/// to fall back to the header. iOS's 1,000-row fetch spent 6.2 s doing the same. Both are
/// on top of the SQL, which is itself 6–12 s for a common term.
///
/// ## The fix, and its one assumption
/// A word is now rejected on its first character before anything is allocated. That is only
/// sound because **the Porter stemmer never alters a word's first character** — every rule
/// is suffix-anchored. `stemmingPreservesTheFirstCharacter` is that assumption written down
/// and checked against real vocabulary, because if it is ever false the snippet silently
/// stops highlighting matches and nothing else would notice.
///
/// ## What the fix did NOT do, measured (#1019)
/// The old assertion's comment said "the whole pass must stay well under a second" for a 7,500-row
/// macOS fetch, and the test passed. Both cannot be true: the per-body cost it was passing at is
/// **877 µs**, which across 7,500 rows is **6.6 seconds**. The budget expressed nothing like its
/// stated goal, and nobody noticed because the number it compared against was arbitrary.
///
/// The real story is 41 s → 6.6 s for the worst case — a 25x improvement in the per-word work,
/// which is a genuine fix and not a complete one. That worst case is a keyword search where NO row
/// matches in its body (the hit was in a header, dateline, source note, summary or note), so the
/// scan runs to the end of every body. It does not apply to a filter-only browse, which since
/// #1046 has no query terms and never calls the snippet builder at all.
///
/// Version history:
///   1.0 — after the P-2 map measured search latency against the owner's own database
///   1.1 — Session 2026-08-21: #1019, the cost guard becomes a ratio against the naive
///         implementation rather than a wall-clock budget with 10% headroom
///   1.2 — A10b (plan of record decision 74): the reference copy cuts the window A10b cuts — from
///         where the prose starts, a lead back to a space and a far side of its own — and the sweep
///         runs over those, with a body of the stemmer's suffix rewrites; the cost guard also times a
///         keyword row whose word is only in its heading, which now scans its whole prose; and the
///         scan's second gate, a stem's opening, has its invariant written down as the first gate's is
@Suite("Search — snippet cost")
struct SearchSnippetCostTests {

    // MARK: - The load-bearing invariant

    /// Every Porter rule is suffix-anchored, so the head survives. Checked, not assumed.
    @Test("Porter stemming never changes a word's first character")
    func stemmingPreservesTheFirstCharacter() {
        let words = Self.stemmerWords()
        #expect(words.count > 500, "expected the bundled vocabularies; got \(words.count)")

        for word in words {
            let lowered = word.lowercased()
            guard let head = lowered.first else { continue }
            let stemmed = PorterStemmer.stem(lowered)
            guard let stemmedHead = stemmed.first else {
                Issue.record(Comment(rawValue: "PorterStemmer.stem(\"\(lowered)\") returned an EMPTY string — the first-character pre-filter in makeContextSnippet assumes it never does"))
                continue
            }
            #expect(stemmedHead == head,
                    "stem(\"\(lowered)\") = \"\(stemmed)\" changed the first character — the snippet pre-filter would silently drop this match")
        }
    }

    /// The scan's second gate (A10b): a word can stem to a stem only if it opens with all of the stem
    /// but its last two characters, since every rule rewrites the end and none reaches further back
    /// than that. If a rule ever did, the gate would turn the word away before the stemmer saw it, and
    /// its snippet would silently mark nothing, as the first gate's failure would.
    @Test("Porter stemming keeps a word's opening: all of the stem but its last two characters")
    func stemmingKeepsTheWordsOpening() {
        let words = Self.stemmerWords()
        #expect(words.count > 500, "expected the bundled vocabularies; got \(words.count)")
        var rewritten = 0
        for word in words {
            let lowered = word.lowercased()
            let stemmed = PorterStemmer.stem(lowered)
            let opening = stemmed.prefix(max(1, stemmed.count - 2))
            #expect(lowered.hasPrefix(opening),
                    "stem(\"\(lowered)\") = \"\(stemmed)\" rewrote more than its last two characters — the snippet's second gate would silently drop this match")
            // Anti-vacuity: stems that are rewritten, not only cut ("hoping" → "hope"), so the sweep
            // reaches the rules the gate's two characters allow for.
            if !lowered.hasPrefix(stemmed) { rewritten += 1 }
        }
        #expect(rewritten > 50, "only \(rewritten) stems are rewritten at their end; the sweep does not reach the rules the gate allows for")
    }

    /// The words both invariants are checked against: the app's own bundled vocabularies, real corpus
    /// terms, and a systematic sweep of the suffixes Porter rewrites.
    private static func stemmerWords() -> [String] {
        var words: [String] = []

        // The app's own bundled vocabularies — real corpus terms, not invented ones.
        for resource in ["cloud-vectors-core", "cloud-vectors-volumes"] {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let vocabulary = root["vocabulary"] as? [String] else { continue }
            words.append(contentsOf: vocabulary)
        }
        #expect(words.count > 500, "expected the bundled vocabularies; got \(words.count)")

        // Plus a systematic sweep of the suffixes Porter actually rewrites, since a rule that
        // ate a whole short word, or reached further back than a stem's last two characters, would be
        // the way these invariants break. A10b added the rewrites' own endings (`enci`, `anci`, `abli`,
        // `bility`, `ably`, `ency`, `ancy`, `ivity`, `ality`) and the stems that end in `at`, `bl` and
        // `iz`, which step 1b gives an `e`.
        let stems = ["a", "be", "re", "y", "s", "ss", "ie", "cat", "happi", "relation", "nation",
                     "operate", "feed", "agree", "plaster", "motor", "sky", "troubl",
                     "possi", "communic", "conflat", "hop", "fil", "trembl", "organiz", "formal", "valen"]
        let suffixes = ["", "s", "es", "ies", "sses", "ed", "eed", "ing", "y", "ational",
                        "tional", "ization", "ation", "ator", "alism", "iveness", "fulness",
                        "ousness", "aliti", "iviti", "biliti", "icate", "ative", "alize",
                        "iciti", "ical", "ful", "ness", "ement", "ment", "ent", "ion", "ou",
                        "ism", "ate", "iti", "ous", "ive", "ize", "al", "er", "ic",
                        "enci", "anci", "abli", "bility", "ably", "ency", "ancy", "ivity", "ality",
                        "ating", "ated", "bling", "izing", "izer", "alli", "entli", "eli", "ousli"]
        for stem in stems {
            for suffix in suffixes { words.append(stem + suffix) }
        }
        return words
    }

    // MARK: - Parity with the naive implementation

    /// The reference implementation: the scan verbatim from before the optimisation, which stems
    /// every word, and the window A10b cuts (a lead `before` the match that goes back to a space and
    /// never before `start`, and `after` characters behind it).
    ///
    /// Carried here rather than described, so parity is checked against code rather than
    /// against a memory of what the code did.
    private static func naiveSnippet(body: String, stemmedTerms: [String], from start: Int = 0,
                                     before: Int, after: Int) -> String? {
        guard !body.isEmpty, !stemmedTerms.isEmpty else { return nil }
        let stems = Set(stemmedTerms)
        let scalars = Array(body)
        var i = start
        let n = scalars.count
        while i < n {
            while i < n, !scalars[i].isLetter { i += 1 }
            guard i < n else { break }
            let wordStart = i
            while i < n, scalars[i].isLetter || scalars[i] == "'" || scalars[i] == "-" { i += 1 }
            let wordEnd = i
            let word = String(scalars[wordStart..<wordEnd])
            let alpha = word.filter { $0.isLetter }
            let stem = alpha.isEmpty ? word.lowercased() : PorterStemmer.stem(alpha.lowercased())
            if stems.contains(stem) {
                var snapLow = max(start, wordStart - before)
                while snapLow > start, !scalars[snapLow - 1].isWhitespace { snapLow -= 1 }
                var snapHigh = min(n, wordEnd + after)
                while snapHigh < n, scalars[snapHigh].isLetter { snapHigh += 1 }
                var out = ""
                if snapLow > start { out += "… " }
                out += String(scalars[snapLow..<wordStart])
                out += "<b>" + String(scalars[wordStart..<wordEnd]) + "</b>"
                out += String(scalars[wordEnd..<snapHigh])
                if snapHigh < n { out += " …" }
                return out
            }
        }
        return nil
    }

    private static let bodies: [String] = [
        "The Ambassador reported that negotiations with the Soviet delegation had reached an impasse over Berlin.",
        "Memorandum of Conversation. The Secretary emphasised that economic assistance would continue.",
        "No relevant content whatsoever in this document about unrelated matters entirely.",
        "Telegram 1247. Chargé d'Affaires ad interim reports well-founded concern re: the blockade.",
        "Running, runs, ran — the delegation was running out of time; negotiating positions hardened.",
        "",
        "aid",
        "Aid. AID? aid-related aid's aided aiding aids.",
        "Ünïcödé and combining marks: café, chargé, naïve, résumé — plus a match on treaty here.",
        String(repeating: "filler words with nothing of interest here at all. ", count: 200)
            + "and finally the treaty appears near the end.",
        // A10b's case for the lead's snap to a space: thirty characters before "Berlin" fall on the
        // "s" of "Bonn’s", after an apostrophe that is not a letter.
        "Re Bonn’s 3463 to Department repeated Berlin 428, London 690, Paris 942, Moscow 190.",
        // And for the scan's second gate: words whose stems the stemmer rewrites at their end, beside
        // words that open as those stems do and stem to something else, in both cases.
        "The POSSIBILITY was possible; Communicating, they communicate. Conflated, hoping, Hope, filing, "
            + "trembling, organizing, Formality, formal, valency, possessive, communal, hopeless, fillet.",
    ]

    private static let queries: [[String]] = [
        ["negoti"], ["soviet"], ["treati"], ["aid"], ["run"], ["berlin", "blockad"],
        ["econom", "assist"], ["zzzznotpresent"], ["chargé"], ["café"], ["a"],
        // The second gate's stems, each the stem of a word in the body above.
        ["possibl"], ["commun"], ["conflat"], ["hope"], ["file"], ["trembl"], ["organ"], ["formal"], ["valenc"],
    ]

    @Test("The optimised snippet is byte-identical to the naive one")
    func parityWithNaiveImplementation() {
        var comparisons = 0
        var matched = 0
        for body in Self.bodies {
            // From the body's start, from inside its first words, and from its middle, as a keyword
            // row starts its window where the prose does.
            for start in Set([0, 5, body.count / 2]) {
                for terms in Self.queries {
                    for (before, after) in [(SearchService.keywordLead, SearchService.keywordTrail), (20, 200),
                                            (1000, 1000)] {
                        let fast = SearchService.makeContextSnippet(
                            body: body, stemmedTerms: terms, from: start, before: before, after: after)
                        let slow = Self.naiveSnippet(
                            body: body, stemmedTerms: terms, from: start, before: before, after: after)
                        #expect(fast == slow, """
                            mismatch for terms \(terms) from \(start), \(before) before and \(after) after:
                              fast: \(fast ?? "nil")
                              slow: \(slow ?? "nil")
                            """)
                        comparisons += 1
                        if fast != nil { matched += 1 }
                    }
                }
            }
        }
        #expect(comparisons > 300, "the parity sweep must actually be broad")
        #expect(matched > 100, "the sweep must cut windows as well as refuse them: \(matched)")
    }

    @Test("An empty stemmed term does not disable matching for the others")
    func emptyTermIsHarmless() {
        // Defensive: `firstLetters` is built with compactMap-like semantics, so an empty term
        // contributes no letter. It must not therefore suppress the real terms.
        let body = "The treaty was signed."
        let fast = SearchService.makeContextSnippet(
            body: body, stemmedTerms: ["", "treati"], before: 50, after: 50)
        let slow = Self.naiveSnippet(
            body: body, stemmedTerms: ["", "treati"], before: 50, after: 50)
        #expect(fast == slow)
        #expect(fast?.contains("<b>treaty</b>") == true)
    }

    // MARK: - The cost itself

    /// A no-match body is the expensive case: the scan runs to the end and returns nil.
    /// This is the shape that cost 41 s across a macOS result set.
    ///
    /// ## Measured against the naive implementation, not against the clock (#1019)
    /// This assertion used to be `perBody < .milliseconds(1)` against a measured ~900 µs — **10%
    /// headroom**. Under the full suite's parallel load it failed at 1,002 µs: two microseconds
    /// over, on a budget that was really measuring how busy the machine was. A wall-clock budget
    /// with no headroom does not test the code, and a suite that goes red at random teaches people
    /// to re-run rather than to read.
    ///
    /// The fix is to compare against `naiveSnippet`, which IS the pre-#548 implementation — the one
    /// that stemmed every word — measured in the same process under the same load. Both sides move
    /// together when the machine is busy, so the ratio is stable where a stopwatch is not, and it
    /// states the thing actually worth protecting: that the first-character rejection still avoids
    /// the stemmer.
    ///
    /// Measured on an iPhone 17 simulator: **866 µs against 21,717 µs — 25.1x**. The guard is set
    /// at 10x, so it has 2.5x of headroom and still fails long before the improvement is lost.
    ///
    /// ## A keyword row's whole snippet (A10b)
    /// Since A10b a row's snippet is `keywordSnippet`: the strip of the row's own heading, source note
    /// and dateline, then the scan from where the prose starts and, when that fails, over the stripped
    /// opening, so a failed match still reads every word once. It is held to the same 10x, against the
    /// same naive scan, so that the strip, which runs for every row a search lists, cannot quietly cost
    /// what the first-character rejection saves.
    @Test("A failed match over a large body is fast")
    func failedMatchIsCheap() {
        // ~5 KB, the doc-comment average body size, with no query term anywhere.
        let body = String(repeating:
            "The delegation met to discuss matters of mutual concern and adjourned. ", count: 70)
        #expect(body.count > 4_500)
        // The same body behind a heading, source note and dateline the strip takes.
        let header = "Memorandum of Conversation"
        let sourceNote = "Source: Department of State, Central Files, 611.61/5–462. Secret."
        let dateline = "Washington, May 4, 1962"
        let row = header + " " + sourceNote + " " + dateline + " " + body

        func perCall(_ iterations: Int, _ work: () -> Void) -> Duration {
            let start = ContinuousClock.now
            for _ in 0..<iterations { work() }
            return (ContinuousClock.now - start) / iterations
        }
        // A word only in the heading: the row's snippet is its opening prose, which it reaches only after
        // scanning the whole prose for a match, where the scan before A10b stopped at the heading's.
        let headingWord = PorterStemmer.stem("memorandum")
        func whole() -> String? {
            SearchService.keywordSnippet(body: row, header: header, dateline: dateline, sourceNote: sourceNote,
                                         stemmedTerms: [headingWord])
        }
        // Warm every path before timing any, so first-call costs land on none of them.
        _ = perCall(20) {
            _ = SearchService.makeContextSnippet(body: body, stemmedTerms: ["zanzibar"])
        }
        _ = perCall(20) { _ = whole() }
        _ = perCall(20) {
            _ = Self.naiveSnippet(body: body, stemmedTerms: ["zanzibar"], before: 30, after: 2_000)
        }

        var returnedNil = true
        let fast = perCall(200) {
            if SearchService.makeContextSnippet(body: body, stemmedTerms: ["zanzibar"]) != nil {
                returnedNil = false
            }
        }
        var openedOnTheProse = true
        let keyword = perCall(200) {
            if whole().map({ $0.contains("<b>") || !$0.hasPrefix("The delegation met") }) ?? true { openedOnTheProse = false }
        }
        let naive = perCall(200) {
            _ = Self.naiveSnippet(body: body, stemmedTerms: ["zanzibar"], before: 30, after: 2_000)
        }
        #expect(returnedNil, "the fixture must not match, or this times the early-exit path instead")
        #expect(openedOnTheProse, "the row must open on its prose, unmarked, or this times another path: \(whole() ?? "nil")")

        // THE GUARD. Ratio, not stopwatch: both sides feel the same machine.
        #expect(naive > fast * 10, """
            The fast path is \(fast) against the naive \(naive) — under 10x. It measured 25.1x when \
            this guard was written, so losing two thirds of the improvement means the \
            first-character rejection has stopped avoiding the Porter stemmer.
            """)
        #expect(naive > keyword * 10, """
            A keyword row whose word is only in its heading takes \(keyword) against the naive scan's \
            \(naive) — under 10x, where the scan alone is \(fast). Its whole-prose scan, or the strip of \
            its heading, source note and dateline, costs what the scan's gates save.
            """)

        // A BACKSTOP for the case a ratio cannot see: both paths regressing together. Deliberately
        // loose — 4x the measured 877 µs — so it fires on a catastrophe and never on load.
        #expect(fast < .milliseconds(4), """
            \(fast) per body. Across a 7,500-row macOS fetch that is \(fast * 7500). This is the \
            absolute backstop, not the real guard; it is set with 4x headroom precisely so that a \
            busy machine cannot trip it.
            """)
    }
}
