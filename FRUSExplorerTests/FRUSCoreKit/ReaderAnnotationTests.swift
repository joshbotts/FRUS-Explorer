// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
import SwiftData
@testable import FRUSExplorer
#endif
// SHA-256 is CryptoKit's on Apple platforms; on Linux the web edition supplies swift-crypto's Crypto.
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - ReaderAnnotationScriptTests

/// The reader's three annotation scripts (`ReaderAnnotationScripts.swift`), which the app's web view
/// injects and FRUS Explorer Light's reader frame serves.
///
/// `FRUSOffsetEngineTests` and `SelectionScriptParityTests` run them in WebKit, in Xcode alone; this
/// suite holds what both hosts rely on, and runs in the package too.
///
/// Version history:
///   1.0 — Session 2026-10-24 (FRUS Explorer Light, S15a): initial implementation, with the scripts'
///          move into the kit
///   1.1 — Session 2026-10-24 (FRUS Explorer Light, S15c's follow-up): `kHighlightsJS`'s pin
///          re-taken, and `rangeEndsAfterALineBreak`, when `buildRanges` came to end a range that
///          ends on a `<br>` after the element
///   1.2 — Session 2026-10-25: `kHighlightsJS`'s pin re-taken, and
///          `aHighlightThatCannotBeBuiltIsSkippedAlone`, when `buildRanges` came to build no range
///          from a negative start and `render` to skip a highlight whose range throws
@Suite("The reader's annotation scripts, as both hosts load them")
struct ReaderAnnotationScriptTests {

    /// Each script's SHA-256 and UTF-8 length, taken when the scripts moved into the kit from
    /// `FRUSWebViewConfiguration.swift`, where the app injected them, at `v2` `02521d01`: the move
    /// changed no byte. A web host serves these bytes as files and the app injects them, so a change
    /// to a script is a change to both readers: re-take the pin from the failure message, and say
    /// why here.
    ///
    /// `kHighlightsJS`'s was re-taken on 2026-10-24, from 3,045 bytes to 3,344, when `buildRanges`
    /// came to end a range that ends on a `<br>` after the element, where `setEnd(br, 1)` threw and
    /// the reader drew none of the document's highlights (`rangeEndsAfterALineBreak`). It was
    /// re-taken again on 2026-10-25, to 3,557 bytes, when `buildRanges` came to build no range from
    /// a negative start and `render` to skip a highlight whose range throws, where one such
    /// highlight left the reader drawing none of the document's (`aHighlightThatCannotBeBuiltIsSkippedAlone`).
    static let pins: [(name: String, script: String, sha256: String, bytes: Int)] = [
        ("kOffsetEngineJS", kOffsetEngineJS,
         "a5899b4968614a86cc50b8faf3e5d1ddcf7a9f93f1c21f6b87a861fc23f0ef3b", 805),
        ("kHighlightsJS", kHighlightsJS,
         "21c2f36e9b9652904cee90177897387e0cd6c7e4dc5ad35bb429dc7915e083de", 3_557),
        ("kSelectionJS", kSelectionJS,
         "0b99ea2a17a4f24f84465f5967acd4a14a968bbb753d5accc3aeb42e42477012", 8_549),
    ]

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    @Test("Each script is the bytes both readers load, as pinned")
    func scriptsArePinned() {
        for pin in Self.pins {
            let digest = Self.sha256(pin.script)
            #expect(digest == pin.sha256 && pin.script.utf8.count == pin.bytes,
                    "\(pin.name) is \(pin.script.utf8.count) bytes with SHA-256 \(digest), not its pin")
        }
    }

    /// Every handler the scripts post to, which a host registers or stands in for: the app's
    /// `frusExplorerConfiguration` adds these three, and a web host defines them.
    @Test("The scripts post to selectionChanged, selectionScrolled and highlightTapped, and no other handler")
    func messageHandlers() throws {
        let pattern = try NSRegularExpression(pattern: #"webkit\.messageHandlers\.(\w+)\.postMessage"#)
        var names = Set<String>()
        for pin in Self.pins {
            let script = pin.script
            for match in pattern.matches(in: script, range: NSRange(script.startIndex..., in: script)) {
                if let range = Range(match.range(at: 1), in: script) { names.insert(String(script[range])) }
            }
        }
        #expect(names == ["selectionChanged", "selectionScrolled", "highlightTapped"])
    }

    /// The offset engine's walk is the flat text `buildFlatText(from:)` makes: `.frus-document`'s
    /// text, skipping `data-skip`, with `<br>` as one newline. Its newline is the two characters `\n`
    /// inside a JavaScript literal, which the Swift literal writes as `\\n`.
    @Test("The offset engine maps .frus-document, skips data-skip and reads a <br> as one newline")
    func offsetEngine() {
        #expect(kOffsetEngineJS.hasPrefix("window.FRUSOffsets = (() => {"))
        #expect(kOffsetEngineJS.contains("document.querySelector('.frus-document')"))
        #expect(kOffsetEngineJS.contains("node.dataset.skip === '1'"))
        #expect(kOffsetEngineJS.contains("flatText += '\\n';"))
        #expect(!kOffsetEngineJS.contains("flatText += '\n"), "a raw newline would end the JavaScript string")
        #expect(kOffsetEngineJS.hasSuffix("return Object.freeze({ flatText, charToNode });\n})();"))
    }

    /// The renderer reads the offset engine's map, so it must come after it, and it reads the fields
    /// `ReaderHighlight` encodes.
    @Test("The renderer paints by colour or as stale, from the offset engine's map")
    func highlightsRenderer() {
        #expect(kHighlightsJS.contains("window.FRUSHighlights = {"))
        #expect(kHighlightsJS.contains("const map = window.FRUSOffsets.charToNode;"))
        #expect(kHighlightsJS.contains("const key = h.isStale ? 'frus-stale' : ('frus-' + h.color);"))
        #expect(kHighlightsJS.contains(
            "h => !h.isStale && tapOffset >= h.startOffset && tapOffset < h.endOffset"),
                "a tap never lands on a stale highlight")
        #expect(!kOffsetEngineJS.contains("FRUSHighlights"), "the engine does not need the renderer")
    }

    /// The offset engine maps a `<br>` as one character with no text of its own, `{node: BR,
    /// localOffset: 0}`, and a `<br>` has no children, so a range cannot end at offset 1 inside it.
    /// A drag that ends at the start of the line after a `<br>` makes such a highlight, and
    /// `setEnd(br, 1)` threw `IndexSizeError` after `render()` had cleared the page's highlights, so
    /// the reader drew none of them. `HighlightLineBreakRenderTests` draws one in WebKit, in Xcode.
    @Test("The renderer ends a range that ends on a line break after the <br>, the engine's entry with no text")
    func rangeEndsAfterALineBreak() {
        #expect(kOffsetEngineJS.contains(
            "    if (node.tagName === 'BR') {\n      charToNode.push({ node: node, localOffset: 0 });"))
        #expect(kHighlightsJS.contains("  if (endEntry.node.tagName === 'BR') range.setEndAfter(endEntry.node);\n"
                                       + "  else range.setEnd(endEntry.node, endEntry.localOffset + 1);"))
        #expect(kHighlightsJS.components(separatedBy: "range.setEnd(").count == 2,
                "the renderer ends a range at an offset in one place, the guarded line")
    }

    /// `render()` clears the page's highlights before it builds any, and the app's `renderHighlights(on:)` drops a
    /// thrown error (`try?`), so a throw from one highlight's range left the reader drawing none of the document's.
    /// A highlight stored with a `startOffset` below 0 threw one: `map[-1]` is undefined, and reading its node is a
    /// `TypeError`. `buildRanges` now builds no range from a negative start, as from any other offset outside the
    /// map, and `render` skips a highlight whose range throws for any other reason. `HighlightSkipRenderTests` draws
    /// such highlights in WebKit, in Xcode.
    @Test("The renderer builds no range from a negative start, and skips a highlight whose range throws")
    func aHighlightThatCannotBeBuiltIsSkippedAlone() {
        #expect(kHighlightsJS.contains(
            "  if (start < 0 || start >= map.length || end > map.length || start >= end) return [];\n"))
        #expect(kHighlightsJS.contains(
            "      try { ranges = buildRanges(h.startOffset, h.endOffset); } catch (_) { continue; }\n"
            + "      if (!ranges.length) continue;"))
        #expect(kHighlightsJS.components(separatedBy: "buildRanges(").count == 3,
                "the renderer builds a highlight's range in one place, inside the try")
    }

    @Test("The selection bridge reports offsets in the engine's map, and -1 for a footnote")
    func selectionBridge() {
        #expect(kSelectionJS.contains("const map = window.FRUSOffsets.charToNode;"))
        #expect(kSelectionJS.contains("postMessage({ start, end, text, rect: geom.rect, scale: geom.scale })"))
        #expect(kSelectionJS.contains(
            "postMessage({ start: -1, end: -1, text, blockText, rect: geom.rect, scale: geom.scale })"))
        #expect(kSelectionJS.contains("document.addEventListener('selectionchange', () => {"))
    }
}

// MARK: - ReaderHighlightTests

/// The shape `FRUSHighlights.render` reads (`ReaderHighlight`, the app's
/// `DocumentHighlight.HighlightDTO`), with its stale rule, and the highlight colours.
///
/// Version history:
///   1.0 — Session 2026-10-24 (FRUS Explorer Light, S15a): initial implementation, with the shape's
///          move into the kit
@Suite("A highlight as the reader's renderer reads it")
struct ReaderHighlightTests {

    @Test("A highlight is stale when the version it stored is not the page's")
    func staleRule() {
        #expect(!ReaderHighlight.isStale(renderingVersion: "0123456789abcdef", currentVersion: "0123456789abcdef"))
        #expect(ReaderHighlight.isStale(renderingVersion: "0123456789abcdef", currentVersion: "fedcba9876543210"))
        #expect(ReaderHighlight.isStale(renderingVersion: "", currentVersion: "fedcba9876543210"))
        #expect(!ReaderHighlight.isStale(renderingVersion: "", currentVersion: ""))

        let fresh = ReaderHighlight(startOffset: 3, endOffset: 9, color: "green",
                                    renderingVersion: "a", currentVersion: "a")
        let stale = ReaderHighlight(startOffset: 3, endOffset: 9, color: "green",
                                    renderingVersion: "a", currentVersion: "b")
        #expect(!fresh.isStale && stale.isStale)
        #expect(fresh.startOffset == 3 && fresh.endOffset == 9 && fresh.color == "green")
    }

    /// The colour is passed through as it is stored, as the app passed `colorTag`: the renderer
    /// names its class from it.
    @Test("The colour tag is passed through as stored")
    func colourPassesThrough() {
        let odd = ReaderHighlight(startOffset: 0, endOffset: 1, color: "teal",
                                  renderingVersion: "a", currentVersion: "a")
        #expect(odd.color == "teal")
    }

    /// Each field the JSON carries is one `kHighlightsJS` reads from each highlight, and the four are
    /// all it reads.
    @Test("The JSON carries the four fields the renderer reads")
    func jsonFields() throws {
        let highlight = ReaderHighlight(startOffset: 12, endOffset: 40, color: "pink",
                                        renderingVersion: "a", currentVersion: "b")
        let data = try JSONEncoder().encode([highlight])
        let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let object = try #require(decoded.first)
        #expect(Set(object.keys) == ["startOffset", "endOffset", "color", "isStale"])
        #expect(object["startOffset"] as? Int == 12)
        #expect(object["endOffset"] as? Int == 40)
        #expect(object["color"] as? String == "pink")
        #expect(object["isStale"] as? Bool == true)
        for key in object.keys {
            #expect(kHighlightsJS.contains("h.\(key)"), "the renderer reads \(key)")
        }
    }

    @Test("The four colours, in order, by the names a highlight stores")
    func colours() {
        #expect(HighlightColor.allCases.map(\.rawValue) == ["yellow", "green", "blue", "pink"])
    }

    #if !SWIFT_PACKAGE // DocumentHighlight is the app's SwiftData model
    @Test("The app's HighlightDTO is the kit's, built from a DocumentHighlight's values")
    @MainActor
    func appInitialiser() throws {
        let container = try ModelContainer(
            for: DocumentHighlight.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let highlight = DocumentHighlight(volumeId: "v1", documentId: "d1", startOffset: 10,
                                          endOffset: 20, colorTag: "blue", renderingVersion: "old")
        container.mainContext.insert(highlight)

        let stale = DocumentHighlight.HighlightDTO(highlight, currentVersion: "new")
        #expect(stale.startOffset == 10 && stale.endOffset == 20 && stale.color == "blue" && stale.isStale)
        let fresh = DocumentHighlight.HighlightDTO(highlight, currentVersion: "old")
        #expect(!fresh.isStale)
        let kit = ReaderHighlight(startOffset: 10, endOffset: 20, color: "blue",
                                  renderingVersion: "old", currentVersion: "new")
        // Sorted, since an encoder without `.sortedKeys` need not write one value's keys in the same
        // order twice; the renderer reads them by name.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(stale) == encoder.encode(kit))
    }
    #endif
}

// MARK: - SelectionVerbTests

/// The reader's actions on a selection, in the order both of the app's surfaces offer them, and the
/// rule that keeps the colours and Excerpt off a footnote (`SelectionVerb.needsDocumentOffsets`).
///
/// Version history:
///   1.0 — Session 2026-10-24 (FRUS Explorer Light, S15a): initial implementation, with the verbs'
///          move into the kit
@Suite("The verbs a selection offers, and those a footnote selection does not")
struct SelectionVerbTests {

    @Test("The four colours, then Excerpt, Look Up in NARA and Note")
    func order() {
        #expect(SelectionVerb.allInOrder == [.highlight(.yellow), .highlight(.green), .highlight(.blue),
                                             .highlight(.pink), .excerpt, .lookUpInNARA, .note])
    }

    /// A footnote selection has no offsets in the document's flat text, so it cannot be highlighted
    /// or excerpted.
    @Test("A footnote selection offers Look Up in NARA and Note alone")
    func footnoteSelection() {
        #expect(SelectionVerb.allInOrder.filter { !$0.needsDocumentOffsets } == [.lookUpInNARA, .note])
        #expect(SelectionVerb.allInOrder.filter(\.needsDocumentOffsets)
                == HighlightColor.allCases.map(SelectionVerb.highlight) + [.excerpt])
    }
}
