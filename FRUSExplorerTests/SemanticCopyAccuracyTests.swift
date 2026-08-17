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

/// User-facing sentences that make a factual claim about the vector artifacts must be true of the
/// artifacts actually bundled.
///
/// ## The bug this exists for
/// The semantic slice's caveat read "from 256-bit signatures". #933 doubled the shipping width to
/// 512 and shipped, the build stayed green, every test stayed green, and the app told every reader a
/// false thing about its own arithmetic for a whole generation. Nothing could have caught it: the
/// number was a literal in a localized string, and no test read that string.
///
/// The lesson generalises past this one sentence. **A number about the artifact, written by hand
/// into copy, is a claim with no owner.** So there are two tests: one that the slice caveat agrees
/// with the bundled provenance whatever it says, and one that forbids the pattern outright, so the
/// next person to write "512-bit" into a string is told to derive it instead.
///
/// Version history:
///   1.0 — build 42: after the 256/512 drift was found during release prep
@Suite("Semantic copy states the artifact's real numbers")
struct SemanticCopyAccuracyTests {

    // MARK: - The slice caveat agrees with the artifact

    @MainActor
    @Test("The slice caveat reports the bundled shipping width, not a literal")
    func sliceCaveatMatchesProvenance() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index,
                                 "no bundled vector index — cannot check what the copy claims")
        let dims = index.provenance.shippingDims
        let sentence = SemanticMapSpikeView.sliceCaveat(from: "frus1861", to: "frus1969-76v01")

        #expect(sentence.contains("\(dims)-bit"), """
            The slice caveat does not state the bundled shipping width of \(dims). It reads:

            \(sentence)

            This is the #933 defect exactly: the artifact's width changed and a user-facing sentence \
            about it did not. Derive the number from BundledSemanticVectors rather than typing it.
            """)
        // The poles must survive into the sentence, or the reader cannot tell which end is which.
        #expect(sentence.contains("frus1861") && sentence.contains("frus1969-76v01"),
                "the caveat dropped a pole label, so it no longer says what the axis runs between")
        // And it must still disclose the y-axis substitution, which is the part most likely to be
        // misread as a document date.
        #expect(sentence.lowercased().contains("coverage midpoint"), """
            The caveat no longer says the vertical axis is the VOLUME's coverage midpoint rather \
            than each document's own date. A reader who misses that will read the slice as a \
            timeline of documents.
            """)
    }

    /// A width the artifact does not have must fail, or the test above is satisfied by any number
    /// that happens to appear in the sentence.
    @MainActor
    @Test("A width the artifact does not carry would be caught")
    func aWrongWidthWouldFail() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let dims = index.provenance.shippingDims
        let sentence = SemanticMapSpikeView.sliceCaveat(from: "a", to: "b")
        // The stale literal, and the other plausible confusions: the native width and the byte count.
        for wrong in [256, index.provenance.nativeDims, dims / 8] where wrong != dims {
            #expect(!sentence.contains("\(wrong)-bit"), """
                The caveat states \(wrong)-bit, which is not the bundled shipping width (\(dims)). \
                256 is the width this sentence wrongly claimed for a whole generation; \
                \(index.provenance.nativeDims) is the model's native width, which is not what ships; \
                \(dims / 8) is the byte count, not the bit count.
                """)
        }
    }

    // MARK: - No hand-written widths anywhere in user-facing copy

    @Test("No localized string hardcodes a bit or dimension width")
    func noHardcodedWidthsInCopy() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        // Only `defaultValue:` payloads — the strings a reader sees. Doc comments may name a width
        // when they are describing a specific historical measurement, and often must.
        let payload = try Regex(#"defaultValue:\s*"((?:[^"\\]|\\.)*)""#)
        let multiline = try Regex(#"(?s)defaultValue:\s*"""(.*?)""""#)
        let width = try Regex(#"\b(\d{2,4})[- ](bit|bits|dimension|dimensions|dimensional)\b"#)

        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in text.matches(of: payload) + text.matches(of: multiline) {
                let body = String(match.output[1].substring ?? "")
                if let hit = body.firstMatch(of: width) {
                    offenders.append("\(file.lastPathComponent): “\(hit.output[0].substring ?? "")”"
                                     + " in “\(body.prefix(90))…”")
                }
            }
        }
        #expect(offenders.isEmpty, """
            \(offenders.count) user-facing string(s) hardcode a width:

            \(offenders.joined(separator: "\n"))

            A width typed into copy is a claim nothing owns — it was "256-bit signatures" that \
            survived the move to 512 and told every reader something false. Read the number from \
            BundledSemanticVectors.index?.provenance instead, as the slice caveat now does.
            """)
    }
}
