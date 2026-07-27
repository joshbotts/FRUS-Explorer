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
/// Version history:
///   1.0 — after the P-2 map measured search latency against the owner's own database
@Suite("Search — snippet cost")
struct SearchSnippetCostTests {

    // MARK: - The load-bearing invariant

    /// Every Porter rule is suffix-anchored, so the head survives. Checked, not assumed.
    @Test("Porter stemming never changes a word's first character")
    func stemmingPreservesTheFirstCharacter() {
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
        // ate a whole short word would be the way this invariant breaks.
        let stems = ["a", "be", "re", "y", "s", "ss", "ie", "cat", "happi", "relation", "nation",
                     "operate", "feed", "agree", "plaster", "motor", "sky", "troubl"]
        let suffixes = ["", "s", "es", "ies", "sses", "ed", "eed", "ing", "y", "ational",
                        "tional", "ization", "ation", "ator", "alism", "iveness", "fulness",
                        "ousness", "aliti", "iviti", "biliti", "icate", "ative", "alize",
                        "iciti", "ical", "ful", "ness", "ement", "ment", "ent", "ion", "ou",
                        "ism", "ate", "iti", "ous", "ive", "ize", "al", "er", "ic"]
        for stem in stems {
            for suffix in suffixes { words.append(stem + suffix) }
        }

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

    // MARK: - Parity with the naive implementation

    /// The reference implementation, verbatim from before the optimisation.
    ///
    /// Carried here rather than described, so parity is checked against code rather than
    /// against a memory of what the code did.
    private static func naiveSnippet(body: String, stemmedTerms: [String],
                                     contextRadius: Int) -> String? {
        guard !body.isEmpty, !stemmedTerms.isEmpty else { return nil }
        let stems = Set(stemmedTerms)
        let scalars = Array(body)
        var i = 0
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
                let lowerBound = max(0, wordStart - contextRadius)
                let upperBound = min(n, wordEnd + contextRadius)
                var snapLow = lowerBound
                while snapLow > 0, scalars[snapLow - 1].isLetter { snapLow -= 1 }
                var snapHigh = upperBound
                while snapHigh < n, scalars[snapHigh].isLetter { snapHigh += 1 }
                var out = ""
                if snapLow > 0 { out += "… " }
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
    ]

    private static let queries: [[String]] = [
        ["negoti"], ["soviet"], ["treati"], ["aid"], ["run"], ["berlin", "blockad"],
        ["econom", "assist"], ["zzzznotpresent"], ["chargé"], ["café"], ["a"],
    ]

    @Test("The optimised snippet is byte-identical to the naive one")
    func parityWithNaiveImplementation() {
        var comparisons = 0
        for body in Self.bodies {
            for terms in Self.queries {
                for radius in [20, 200, 1000] {
                    let fast = SearchService.makeContextSnippet(
                        body: body, stemmedTerms: terms, contextRadius: radius)
                    let slow = Self.naiveSnippet(
                        body: body, stemmedTerms: terms, contextRadius: radius)
                    #expect(fast == slow,
                            "mismatch for terms \(terms) radius \(radius):\n  fast: \(fast ?? "nil")\n  slow: \(slow ?? "nil")")
                    comparisons += 1
                }
            }
        }
        #expect(comparisons > 300, "the parity sweep must actually be broad")
    }

    @Test("An empty stemmed term does not disable matching for the others")
    func emptyTermIsHarmless() {
        // Defensive: `firstLetters` is built with compactMap-like semantics, so an empty term
        // contributes no letter. It must not therefore suppress the real terms.
        let body = "The treaty was signed."
        let fast = SearchService.makeContextSnippet(
            body: body, stemmedTerms: ["", "treati"], contextRadius: 50)
        let slow = Self.naiveSnippet(
            body: body, stemmedTerms: ["", "treati"], contextRadius: 50)
        #expect(fast == slow)
        #expect(fast?.contains("<b>treaty</b>") == true)
    }

    // MARK: - The cost itself

    /// A no-match body is the expensive case: the scan runs to the end and returns nil.
    /// This is the shape that cost 41 s across a macOS result set.
    @Test("A failed match over a large body is fast")
    func failedMatchIsCheap() {
        // ~5 KB, the doc-comment average body size, with no query term anywhere.
        let body = String(repeating:
            "The delegation met to discuss matters of mutual concern and adjourned. ", count: 70)
        #expect(body.count > 4_500)

        let start = ContinuousClock.now
        for _ in 0..<200 {
            #expect(SearchService.makeContextSnippet(
                body: body, stemmedTerms: ["zanzibar"], contextRadius: 1000) == nil)
        }
        let perBody = (ContinuousClock.now - start) / 200

        // 7,500 rows is the macOS fetch. The whole pass must stay well under a second.
        #expect(perBody < .milliseconds(1),
                "\(perBody) per body — across a 7,500-row macOS fetch that is \(perBody * 7500)")
    }
}
