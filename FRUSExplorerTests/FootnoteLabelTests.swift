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

// MARK: - FootnoteLabelTests

/// Tests for #985: footnote display labels and the DOM key that pairs a marker with its body.
///
/// **Every test here drives the real emitter** — `FRUSDocumentParser` → `ASTToRenderNodeConverter`
/// → `FRUSRenderNodeHTMLSerializer` — from TEI text. That is deliberate and is the reason the bug
/// survived: the existing serializer suite hand-builds `FRUSRenderNode` values, so its fixtures
/// carried labels the converter cannot actually produce (`displayLabel: "Source"`), and its
/// "Marker popovertarget matches footnote aside id" test passed throughout because its model held
/// exactly one footnote, making a duplicate id structurally impossible in the fixture.
///
/// The shape under test is the one that shipped: a `<note type="source">` carries no `@n`, so the
/// converter's old `printedNumber ?? "\(sequentialNumber)"` labelled it "1" beside the real
/// footnote `n="1"`, the serializer built `id="fn-\(label)"` from that, and `popovertarget`
/// resolved to whichever matching id came first in the DOM — the source note.
@Suite("Footnote labels and DOM keys (#985)")
struct FootnoteLabelTests {

    // MARK: - Helpers

    private func makeFixture(body: String) throws -> URL {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
          <text><body>\(body)</body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-fn-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Parses TEI and serializes it exactly as the reading view does.
    private func render(_ body: String) async throws -> (html: String, model: FRUSDocumentRenderModel) {
        let url = try makeFixture(body: body)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(docs[0])
        let html = FRUSRenderNodeHTMLSerializer(annotateSourceClassification: true).serialize(model)
        return (html, model)
    }

    /// Every `id="..."` in the emitted HTML, in document order.
    private func emittedIDs(_ html: String) -> [String] {
        let pattern = /id="([^"]*)"/
        return html.matches(of: pattern).map { String($0.1) }
    }

    /// Every `popovertarget="..."` in the emitted HTML, in document order.
    private func popoverTargets(_ html: String) -> [String] {
        let pattern = /popovertarget="([^"]*)"/
        return html.matches(of: pattern).map { String($0.1) }
    }

    /// The real shape from `frus1950v05/d748` — an unnumbered source note ahead of `n="1"`.
    private static let sourceNotePlusNumbered = """
    <div type="document" xml:id="d748">
      <note rend="inline" type="source">782.022/5–350</note>
      <p>Body text<note n="1" xml:id="d748fn1">Not printed.</note> continues<note n="2" xml:id="d748fn2">Ante, p. 1260.</note>.</p>
    </div>
    """

    // MARK: - The regression pin

    /// Fails on the pre-#985 emitter: it produced `id="fn-1"` twice.
    @Test("A source note ahead of footnote 1 does not duplicate a DOM id")
    func sourceNoteDoesNotCollideWithFootnoteOne() async throws {
        let (html, model) = try await render(Self.sourceNotePlusNumbered)

        #expect(model.footnotes.count == 3, "source note + two body notes")

        let ids = emittedIDs(html)
        let duplicates = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }
        #expect(duplicates.isEmpty,
                "duplicate element ids: \(duplicates.keys.sorted()) — a popovertarget resolves to the first match, so the second note becomes unreachable")
    }

    /// The behavioural half of the same bug: the marker for footnote 1 must point at footnote 1.
    @Test("Each marker's popovertarget resolves to its own aside")
    func markerTargetsItsOwnNote() async throws {
        let (html, _) = try await render(Self.sourceNotePlusNumbered)

        let targets = popoverTargets(html)
        #expect(targets.count == 3, "one marker per note")
        #expect(Set(targets).count == 3, "markers must not share a target: \(targets)")

        // Each target must name exactly one aside. (The endnote entry carries the same key under
        // the `fnote-` prefix, so it is not matched by this substring.)
        for target in targets {
            let asideID = "id=\"\(target)\""
            let count = html.components(separatedBy: asideID).count - 1
            #expect(count == 1, "\(target) should identify exactly one aside, found \(count)")
        }

        // The note whose printed number is 1 must be reachable from the marker labelled 1.
        #expect(html.contains("popovertarget=\"fn-x-d748fn1\""),
                "footnote 1's marker must target footnote 1's xml:id, not the source note")
        #expect(html.contains("id=\"fn-x-d748fn1\""))
    }

    // MARK: - Labels

    @Test("A note with @n keeps the number the volume printed")
    func printedNumberIsPreserved() async throws {
        let (html, model) = try await render(Self.sourceNotePlusNumbered)

        var labels: [String?] = []
        for node in model.footnotes {
            guard case .footnoteBody(_, _, _, _, let label, _) = node else { continue }
            labels.append(label)
        }
        #expect(labels.count == 3)
        #expect(labels[0] == nil, "the source note carries no @n and must not be given one")
        #expect(labels[1] == "1")
        #expect(labels[2] == "2")

        #expect(html.contains(">1</button>"), "the marker shows the printed number")
        #expect(html.contains(">2</button>"))
    }

    /// The volumes whose footnotes run continuously across a printed page — 44.2% of documents
    /// with numbered notes start above 1, and `frus1915` runs to `n="99"`. The reader must see the
    /// number a citation would name, not a position in a list.
    @Test("Footnote numbers that do not start at 1 are shown as printed")
    func continuousNumberingIsShownAsPrinted() async throws {
        let (html, _) = try await render("""
        <div type="document" xml:id="d12">
          <p>Text<note n="47" xml:id="d12fn47">Note 47.</note> more<note n="48" xml:id="d12fn48">Note 48.</note>.</p>
        </div>
        """)
        #expect(html.contains(">47</button>"))
        #expect(html.contains(">48</button>"))
        #expect(html.contains("<span class=\"fn-list-label\">47</span>"),
                "the endnote list must print 47, not the positional counter 1")
        #expect(html.contains("<span class=\"fn-list-label\">48</span>"))
    }

    /// `@n` is copied verbatim from the TEI. One note corpus-wide carries `n=""`
    /// (`frus1969-76v25` d146) and six carry a leading space — a bare non-nil test admits both,
    /// and the empty one reintroduces exactly the unlabelled-marker defect #985 removes.
    @Test("An empty or whitespace-only @n counts as no number")
    func blankPrintedNumberIsTreatedAsAbsent() async throws {
        let (html, model) = try await render("""
        <div type="document" xml:id="d1">
          <p>A<note n="" xml:id="d1fn1">Blank n.</note> B<note n=" 3 " xml:id="d1fn2">Padded n.</note></p>
        </div>
        """)

        guard case .footnoteBody(_, _, _, _, let blank, _) = model.footnotes[0] else {
            Issue.record("expected a footnote body"); return
        }
        #expect(blank == nil, "n=\"\" is not a printed number")

        guard case .footnoteBody(_, _, _, _, let padded, _) = model.footnotes[1] else {
            Issue.record("expected a footnote body"); return
        }
        #expect(padded == "3", "a padded @n is trimmed, not discarded")

        #expect(!html.contains("id=\"fn-\""), "an empty label must never become an empty id")
        #expect(!html.contains("popovertarget=\"fn-\""))
    }

    // MARK: - The affordance

    @Test("An unnumbered source note gets the archival mark, not a number")
    func unnumberedSourceNoteShowsArchivalMark() async throws {
        let (html, _) = try await render(Self.sourceNotePlusNumbered)

        #expect(html.contains("fn-marker-unnumbered"), "the source note's marker is the unnumbered variant")
        #expect(html.contains("class=\"fn-glyph\""), "it carries the archival glyph")
        #expect(html.contains("aria-label=\"Source note\""),
                "VoiceOver must name it rather than announcing \"Footnote \"")
    }

    /// Keyed on `type`, not on the absence of a label. An archival mark on a note that is not a
    /// provenance statement would assert something untrue.
    @Test("An unnumbered non-source note gets a neutral mark, not the archival one")
    func unnumberedNonSourceNoteIsNeutral() async throws {
        let (html, _) = try await render("""
        <div type="document" xml:id="d1">
          <p>Text<note>Bare note, no type and no number.</note>.</p>
        </div>
        """)
        #expect(html.contains("fn-marker-unnumbered"))
        #expect(html.contains("\u{2022}"), "a bullet stands in for the missing number")
        #expect(!html.contains("class=\"fn-glyph\""),
                "a note that is not a source note must not claim archival provenance")
    }

    // MARK: - The key itself

    @Test("The DOM key prefers xml:id and falls back without colliding")
    func domKeyBranchesAreDisjoint() {
        #expect(FRUSRenderNode.footnoteDOMKey(id: "d748fn3", sequentialNumber: 4) == "x-d748fn3")
        #expect(FRUSRenderNode.footnoteDOMKey(id: nil, sequentialNumber: 4) == "n-4")
        #expect(FRUSRenderNode.footnoteDOMKey(id: "", sequentialNumber: 4) == "n-4")

        // Whitespace inside an id would silently truncate the HTML attribute.
        #expect(FRUSRenderNode.footnoteDOMKey(id: "d1 fn2", sequentialNumber: 9) == "n-9")

        // The branches are separated by a discriminator that precedes any corpus text, so a
        // future TEI drop cannot mint an xml:id that collides with a synthesised key.
        let synthesised = FRUSRenderNode.footnoteDOMKey(id: nil, sequentialNumber: 7)
        let fromID = FRUSRenderNode.footnoteDOMKey(id: "n-7", sequentialNumber: 99)
        #expect(synthesised != fromID, "an xml:id of \"n-7\" must not collide with the 7th note's fallback key")
    }

    /// Two id-less notes in one document both take the synthesised branch; the counter is what
    /// keeps them apart. 2,128 corpus documents have two or more such notes, one has 28.
    @Test("Several id-less notes in one document stay distinct")
    func multipleIDLessNotesRemainDistinct() async throws {
        let (html, model) = try await render("""
        <div type="document" xml:id="d1">
          <note rend="inline" type="source">Lot 55 D 128</note>
          <p>A<note>First bare.</note> B<note>Second bare.</note></p>
        </div>
        """)
        #expect(model.footnotes.count == 3)

        let targets = popoverTargets(html)
        #expect(Set(targets).count == 3, "three id-less notes must produce three distinct keys: \(targets)")
    }
}
