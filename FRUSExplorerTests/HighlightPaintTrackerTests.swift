//
//  Copyright 2026 Josh Botts
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Testing
@testable import FRUSExplorer

/// Pins `HighlightPaintTracker` — the flat-text partitioner the PDF and DOCX exporters
/// paint inline highlights through.
///
/// **It had no tests at all**, and no test reached it indirectly either: every
/// `PDFCollectionExporter`/`DocxCollectionExporter` call in the tree passes documents whose
/// `highlights` array is empty, so the highlight-painting path was untested end to end.
/// That is the other half of why the unit bug below survived — the one suite that does
/// drive a flat-text walker (`HighlightInjectionTests`) minted its offsets in the walker's
/// own wrong unit, and this path had nothing at all.
///
/// The invariant under test: `DocumentHighlight.startOffset`/`endOffset` are **UTF-16
/// code-unit** positions (the JS `charToNode` map holds one entry per code unit), so the
/// tracker's counter and its slicing must both be UTF-16. They counted Swift `Character`
/// — grapheme clusters — which made `hl.startOffset - chunkStart` a UTF-16 number minus a
/// grapheme-space one.
///
/// Fixture counts, verified: `"𝐀 target here"` is 13 Characters / 13 scalars / **14
/// UTF-16 units**, and `"target"` sits at UTF-16 `(3,9)` against Character `(2,8)`.
/// `"Café note"` (`e` + U+0301) is 9 Characters / 10 scalars / **10 UTF-16 units**, with
/// `"note"` at `(6,10)` against `(5,9)`. Both are needed: the astral case also catches a
/// *unicodeScalar*-counting walker, since scalars and Characters agree there, while the
/// combining case separates Character from scalar.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation, from the #1262 comment sweep
@Suite("HighlightPaintTracker — flat-text offsets are UTF-16 units")
struct HighlightPaintTrackerTests {

    private func coloured(_ tracker: HighlightPaintTracker, _ text: String)
        -> [(text: String, color: DocumentHighlight.Color?)] {
        tracker.partition(text).map { (String(text[$0.range]), $0.color) }
    }

    // MARK: - The unit

    @Test("A chunk with an astral character colours exactly the highlighted UTF-16 span")
    func astralCharacterInOneChunk() {
        let text = "\u{1D400} target here"     // 13 Characters, 14 UTF-16 units
        let tracker = HighlightPaintTracker([
            ExportHighlight(startOffset: 3, endOffset: 9, color: .yellow)
        ])
        let painted = coloured(tracker, text).filter { $0.color != nil }.map(\.text)
        // Counting Characters sliced "arget " — one early, and one short at the end.
        #expect(painted == ["target"])
    }

    @Test("A chunk with a combining sequence colours exactly the highlighted UTF-16 span")
    func combiningSequenceInOneChunk() {
        let text = "Cafe\u{0301} note"         // 9 Characters, 10 UTF-16 units
        let tracker = HighlightPaintTracker([
            ExportHighlight(startOffset: 6, endOffset: 10, color: .green)
        ])
        let painted = coloured(tracker, text).filter { $0.color != nil }.map(\.text)
        #expect(painted == ["note"])
    }

    @Test("The counter advances in UTF-16 units ACROSS chunks")
    func counterAdvancesInUTF16AcrossChunks() {
        // The exporters call `partition(_:)` once per flat-text leaf, so the counter
        // carrying the wrong unit forward between chunks is the real shape of the bug:
        // it does not merely mis-slice one chunk, it drifts for the rest of the document.
        let tracker = HighlightPaintTracker([
            ExportHighlight(startOffset: 2, endOffset: 8, color: .yellow)
        ])
        _ = tracker.partition("\u{1D400}")     // 1 Character, 2 UTF-16 units
        let second = "target here"
        let painted = coloured(tracker, second).filter { $0.color != nil }.map(\.text)
        #expect(painted == ["target"])
    }

    // MARK: - The contract the exporters rely on

    @Test("Spans concatenate to cover the whole chunk, astral characters included")
    func spansCoverTheWholeChunk() {
        let text = "pre \u{1D400}mark post"
        let tracker = HighlightPaintTracker([
            ExportHighlight(startOffset: 4, endOffset: 10, color: .blue)
        ])
        let spans = tracker.partition(text)
        #expect(spans.map { String(text[$0.range]) }.joined() == text)
        #expect(spans.filter { $0.color != nil }.map { String(text[$0.range]) } == ["\u{1D400}mark"])
    }

    @Test("An inactive tracker returns the whole chunk unpainted and still counts it")
    func inactiveTrackerStillCounts() {
        let tracker = HighlightPaintTracker([])
        #expect(!tracker.isActive)
        let spans = tracker.partition("\u{1D400} anything")
        #expect(spans.count == 1)
        #expect(spans[0].color == nil)
    }

    @Test("ASCII behaviour is unchanged — the two units coincide there")
    func asciiIsUnchanged() {
        let text = "Hello world"
        let tracker = HighlightPaintTracker([
            ExportHighlight(startOffset: 6, endOffset: 11, color: .pink)
        ])
        let spans = coloured(tracker, text)
        #expect(spans.map(\.text) == ["Hello ", "world"])
        #expect(spans.map(\.color) == [nil, .pink])
    }
}
