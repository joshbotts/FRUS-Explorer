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
import WordCloudKit
@testable import CloudVectorsGeneratorCore

/// Extraction of `<div type="document">` body text from TEI.
///
/// Version history:
///   1.0 — O-1: initial implementation
@Suite("CloudVectors — TEI body-text extraction")
struct TEIBodyTextExtractorTests {

    @Test("Extracts each document div's text, in order, keyed by xml:id")
    func extractsDocumentsInOrder() {
        let xml = """
        <TEI><text><body>
          <div type="section"><head>Not a document</head>
            <div type="document" xml:id="d1"><head>First</head><p>Alpha beta.</p></div>
            <div type="document" xml:id="d2"><p>Gamma delta.</p></div>
          </div>
        </body></text></TEI>
        """
        let docs = TEIBodyTextExtractor.documents(in: xml)
        #expect(docs.map(\.documentId) == ["d1", "d2"])
        #expect(docs[0].bodyText == "First Alpha beta.")
        #expect(docs[1].bodyText == "Gamma delta.")
    }

    @Test("Nested divs do not close the document early")
    func handlesNestedDivs() {
        let xml = """
        <div type="document" xml:id="d1"><p>Before.</p>
          <div type="sub"><p>Inside.</p></div>
          <p>After.</p></div>
        """
        let docs = TEIBodyTextExtractor.documents(in: xml)
        #expect(docs.count == 1)
        #expect(docs[0].bodyText == "Before. Inside. After.")
    }

    @Test("Footnote text is INCLUDED — the app's plainText includes footnote subtrees")
    func includesFootnotes() {
        // Not an oversight: `FRUSASTNode.plainText` returns footnote children, and
        // `extractBodyText` uses it. `plainTextExcludingFootnotes` exists separately and is
        // used only for headers. Excluding them here would diverge from what the app counts.
        let xml = #"<div type="document" xml:id="d1"><p>Treaty signed<note n="1"><p>Telegram 42.</p></note> in Geneva.</p></div>"#
        let docs = TEIBodyTextExtractor.documents(in: xml)
        #expect(docs[0].bodyText.contains("Telegram 42."))
        #expect(docs[0].bodyText.contains("Geneva"))
    }

    @Test("subtype= does not masquerade as type=")
    func doesNotConfuseSubtypeForType() {
        // The corpus carries `subtype="editorial-note"` on many document divs; a prefix
        // match on "type" would read the subtype and mis-identify the element.
        let notADocument = #"<div subtype="document" xml:id="x"><p>No.</p></div>"#
        #expect(TEIBodyTextExtractor.documents(in: notADocument).isEmpty)

        let realOne = #"<div frus:doc-dateTime-min="1946-11-04T00:00:00-05:00" n="1" subtype="editorial-note" type="document" xml:id="d1"><p>Yes.</p></div>"#
        let docs = TEIBodyTextExtractor.documents(in: realOne)
        #expect(docs.map(\.documentId) == ["d1"])
        #expect(docs[0].bodyText == "Yes.")
    }

    @Test("A <div type=\"document\" inside a comment or CDATA opens nothing")
    func ignoresNonMarkup() {
        let xml = """
        <body>
          <!-- <div type="document" xml:id="ghost"><p>Phantom.</p></div> -->
          <![CDATA[ <div type="document" xml:id="ghost2"><p>Phantom.</p></div> ]]>
          <div type="document" xml:id="d1"><p>Real.</p></div>
        </body>
        """
        let docs = TEIBodyTextExtractor.documents(in: xml)
        #expect(docs.map(\.documentId) == ["d1"])
    }

    @Test("Tag boundaries separate words; entities decode")
    func normalisesTextLikeTheApp() {
        let xml = #"<div type="document" xml:id="d1"><p><hi>treaty</hi>signed &amp; sealed &#8212; done</p></div>"#
        let text = TEIBodyTextExtractor.documents(in: xml)[0].bodyText
        // "<hi>treaty</hi>signed" must not tokenise as "treatysigned".
        #expect(text.contains("treaty signed"))
        #expect(text.contains("&"))
        #expect(text.contains("\u{2014}"))
        // Whitespace runs collapse, matching `String.normalizedWhitespace`.
        #expect(!text.contains("  "))
    }

    @Test("A > inside an attribute value does not end the tag")
    func handlesQuotedAngleBrackets() {
        let xml = #"<div type="document" xml:id="d1" n="a>b"><p>Kept.</p></div>"#
        let docs = TEIBodyTextExtractor.documents(in: xml)
        #expect(docs.count == 1)
        #expect(docs[0].bodyText == "Kept.")
    }

    @Test("A document div with no xml:id gets a stable synthesised id")
    func synthesisesMissingIds() {
        let xml = "<div type=\"document\"><p>One.</p></div><div type=\"document\"><p>Two.</p></div>"
        #expect(TEIBodyTextExtractor.documents(in: xml).map(\.documentId) == ["d1", "d2"])
    }
}

/// Roll-up and packing.
///
/// Version history:
///   1.0 — O-1: initial implementation
@Suite("CloudVectors — aggregation and packing")
struct CloudVectorsAggregatorTests {

    private let lexicons = WordCloudLexiconSet(payload: .init(
        concepts: ["sovereignty", "security"],
        sentimentPositive: ["peace"],
        sentimentNegative: ["crisis"]
    ))

    private func aggregator() -> CloudVectorsAggregator {
        CloudVectorsAggregator(lexicons: lexicons)
    }

    private func volume(_ id: String, _ subseries: String,
                        _ counts: [WordCloudLens: [String: Int]]) -> CloudVectorsAggregator.VolumeCounts {
        .init(volumeId: id, subseries: subseries, documentCount: 10, counts: counts)
    }

    /// Resolves a packed list back to `term → count`.
    private func terms(_ file: CloudVectorsFile, _ scope: String, _ lens: WordCloudLens) -> [String: Int] {
        guard let list = file.scopes[scope]?.lists[lens.rawValue] else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.entries.map { (file.vocabulary[$0.term], $0.count) })
    }

    @Test("Subseries and corpus are the term-wise SUM of their volumes")
    func rollsUpBySummingRawCounts() {
        let out = aggregator().pack(volumes: [
            volume("v1", "1969-76", [.topics: ["treaty": 10, "missile": 4]]),
            volume("v2", "1969-76", [.topics: ["treaty": 5, "summit": 3]]),
            volume("v3", "1977-80", [.topics: ["treaty": 1]]),
        ], generated: "2026-07-27", tuning: .standard)

        #expect(terms(out.core, "1969-76", .topics) == ["treaty": 15, "missile": 4, "summit": 3])
        #expect(terms(out.core, "1977-80", .topics) == ["treaty": 1])
        #expect(terms(out.core, CloudVectorsAggregator.corpusScopeKey, .topics)
                == ["treaty": 16, "missile": 4, "summit": 3])
    }

    @Test("Aggregation happens BEFORE truncation")
    func aggregatesBeforeTruncating() {
        // A term ranked below the cut in every volume but large in aggregate must survive.
        // Rolling up already-truncated top-50 lists would lose it, which is the bug this
        // pins: 60 volumes each with 50 loud one-off terms plus a steady quiet one.
        var volumes: [CloudVectorsAggregator.VolumeCounts] = []
        for v in 0..<60 {
            var counts: [String: Int] = ["steady": 5]
            for k in 0..<CloudVectorsAggregator.topTermsPerList { counts["loud\(v)-\(k)"] = 50 }
            volumes.append(volume("v\(v)", "era", [.topics: counts]))
        }
        let out = aggregator().pack(volumes: volumes, generated: "d", tuning: .standard)
        // 60 x 5 = 300, above every one-off's 50.
        #expect(terms(out.core, "era", .topics)["steady"] == 300)
    }

    @Test("Entries are ranked descending, and ties break deterministically on the term")
    func ranksDeterministically() {
        let counts = ["delta": 7, "alpha": 7, "charlie": 9, "bravo": 7]
        let out = aggregator().pack(volumes: [volume("v1", "e", [.topics: counts])],
                                    generated: "d", tuning: .standard)
        let list = out.volumes.scopes["v1"]!.lists[WordCloudLens.topics.rawValue]!
        #expect(list.entries.map { out.volumes.vocabulary[$0.term] }
                == ["charlie", "alpha", "bravo", "delta"])
    }

    @Test("Packing is deterministic — same input, byte-identical output")
    func packingIsDeterministic() throws {
        // Dictionary iteration order varies per process AND per instance, so a single
        // comparison can pass by luck; repeat, and compare encoded bytes rather than values.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var baseline: Data?
        for _ in 0..<12 {
            let out = aggregator().pack(volumes: [
                volume("v1", "1969-76", [.topics: ["treaty": 10, "summit": 10, "missile": 4],
                                         .concepts: ["security": 6]]),
                volume("v2", "1969-76", [.topics: ["treaty": 2], .concepts: ["sovereignty": 6]]),
            ], generated: "2026-07-27", tuning: .standard)
            let data = try encoder.encode(out.core)
            if let baseline { #expect(data == baseline) } else { baseline = data }
        }
    }

    @Test("The vocabulary round-trips, and the two files are independently decodable")
    func vocabularyRoundTrips() throws {
        let out = aggregator().pack(volumes: [
            volume("v1", "e", [.topics: ["treaty": 3], .concepts: ["security": 2]]),
        ], generated: "d", tuning: .standard)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for file in [out.core, out.volumes] {
            let decoded = try JSONDecoder().decode(CloudVectorsFile.self, from: encoder.encode(file))
            #expect(decoded == file)
            // Every entry must index a real vocabulary slot — an off-by-one here would
            // render the wrong words with no error anywhere.
            for scope in decoded.scopes.values {
                for list in scope.lists.values {
                    for entry in list.entries {
                        #expect(entry.term >= 0 && entry.term < decoded.vocabulary.count)
                    }
                }
            }
        }
    }

    @Test("Sentiment entries carry polarity; other lenses carry none")
    func sentimentCarriesPolarity() {
        let out = aggregator().pack(volumes: [
            volume("v1", "e", [.sentiment: ["peace": 9, "crisis": 4],
                               .topics: ["treaty": 5]]),
        ], generated: "d", tuning: .standard)

        let sentiment = out.volumes.scopes["v1"]!.lists[WordCloudLens.sentiment.rawValue]!
        let byTerm = Dictionary(uniqueKeysWithValues:
            sentiment.entries.map { (out.volumes.vocabulary[$0.term], $0.polarity) })
        #expect(byTerm["peace"] == 1)
        #expect(byTerm["crisis"] == -1)

        let topics = out.volumes.scopes["v1"]!.lists[WordCloudLens.topics.rawValue]!
        #expect(topics.entries.allSatisfy { $0.polarity == nil })
    }

    @Test("A thin list is MARKED below-signal, not dropped")
    func thinListsAreMarkedNotHidden() {
        // Decision O-4-2. The hand-off specifies a silent fallback to the era's list; a
        // user reading a volume's cloud to decide whether to download it would then be
        // reading its era's vocabulary and attributing it to the volume. The generator
        // emits the thin list plus the flag so the chip can say "(era)".
        let out = aggregator().pack(volumes: [
            volume("v1", "e", [.concepts: ["security": 2]]),          // 1 term, threshold 4
            volume("v2", "e", [.topics: ["treaty": 9, "summit": 2]]), // topics has no threshold
        ], generated: "d", tuning: .standard)

        let thin = out.volumes.scopes["v1"]!.lists[WordCloudLens.concepts.rawValue]!
        #expect(thin.belowSignalThreshold)
        #expect(thin.entries.count == 1, "the terms are kept, not suppressed")

        let topics = out.volumes.scopes["v2"]!.lists[WordCloudLens.topics.rawValue]!
        #expect(!topics.belowSignalThreshold, "topics is not signal-dependent")
    }

    @Test("`total` counts everything, including terms cut by truncation")
    func totalIncludesTruncatedTerms() {
        var counts: [String: Int] = [:]
        for k in 0..<(CloudVectorsAggregator.topTermsPerList + 25) { counts["t\(k)"] = k + 1 }
        let expected = counts.values.reduce(0, +)

        let out = aggregator().pack(volumes: [volume("v1", "e", [.topics: counts])],
                                    generated: "d", tuning: .standard)
        let list = out.volumes.scopes["v1"]!.lists[WordCloudLens.topics.rawValue]!
        #expect(list.entries.count == CloudVectorsAggregator.topTermsPerList)
        #expect(list.total == expected, "total must precede truncation, or it cannot weight a scope")
        #expect(list.total > list.entries.reduce(0) { $0 + $1.count })
    }

    @Test("Provenance records the tuning the artifact was built under")
    func provenanceRecordsTuning() {
        let out = aggregator().pack(volumes: [volume("v1", "e", [.topics: ["treaty": 1]])],
                                    generated: "2026-07-27", tuning: .standard)
        #expect(out.core.provenance.tuning == WordCloudTuning.standard)
        #expect(out.core.provenance.volumeCount == 1)
        #expect(out.core.provenance.documentCount == 10)
        #expect(out.core.generated == "2026-07-27")
        #expect(out.core.lenses == WordCloudLens.bundledCloudLenses.map(\.rawValue))
    }

    @Test("Core carries corpus + subseries; volumes carries volumes")
    func filesAreSplitByScope() {
        let out = aggregator().pack(volumes: [
            volume("v1", "1969-76", [.topics: ["a": 1]]),
            volume("v2", "1977-80", [.topics: ["b": 1]]),
        ], generated: "d", tuning: .standard)

        #expect(Set(out.core.scopes.keys) == ["corpus", "1969-76", "1977-80"])
        #expect(Set(out.volumes.scopes.keys) == ["v1", "v2"])
    }
}
