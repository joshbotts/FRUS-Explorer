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

// MARK: - HeaderSourceNoteLeakTests

/// #888's acceptance criterion, pinned: **an indexed header never contains a source-note tail.**
///
/// The defect the issue describes is a header stored as
///
/// > 376. Letter From Secretary of State Rogers to Secretary of Commerce Stans **Source: National
/// > Archives, RG 59, Central Files 1970–73, ORG 1 COM–STATE. No classification marking.**
///
/// which pollutes citations, window titles and exports, because the leak is in what the *index
/// stores* rather than in what a search row draws.
///
/// **The index-time repair already exists** — it shipped with index version 14, whose note in
/// `IndexingPipeline` records it: "`extractHeader` excludes footnote children of `<head>` (headers
/// no longer embed the full source-note or head-footnote text)". `plainTextExcludingFootnotes`
/// returns `""` for a `.footnote` node, and a `<note type="source">` becomes one — the parser's
/// `isTransparent` refuses to inline a `type="source"` note even when it carries `rend="inline"`.
///
/// What did not exist is anything holding that in place. These tests drive the **real** chain
/// (`FRUSDocumentParser` → `IndexingPipeline.extractHeader`) over the encodings the corpus actually
/// uses, so a future change to either the parser's note handling or the header extractor fails here
/// rather than silently re-polluting 300,000 stored headers and everything derived from them.
///
/// A corpus scan of all 552 shippable volumes found 0 of 314,478 documents with a `<head>` whose
/// extracted header retains a `Source:` tail — but that scan was a Python approximation of the
/// extractor, and this repo has been misled by exactly that kind of proxy before. These tests run
/// the shipped code.
@Suite("Indexed headers carry no source-note tail (#888)")
struct HeaderSourceNoteLeakTests {

    private func header(fromBody body: String) async throws -> String {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
          <text><body>\(body)</body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-hdr-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        return IndexingPipeline.extractHeader(from: docs[0].nodes)
    }

    /// The encoding every volume from 1955 on uses, transcribed from `frus1969-76ve10` d501.
    @Test("A head-nested type=\"source\" note is excluded from the header")
    func headNestedSourceNoteExcluded() async throws {
        let h = try await header(fromBody: """
        <div type="document" xml:id="d501">
          <head>501. Memorandum From the President's Assistant for National Security Affairs (Kissinger) to President Nixon<note n="1" type="source" xml:id="d501fn1">Source: National Archives, Nixon Presidential Materials, NSC Files, Box 790, Country Files, Latin America, Nicaragua, Vol. I (1969–1974). Confidential. Sent for action.</note> <note n="2" type="summary" xml:id="d501fn2">Kissinger forwarded a report from Secretary of Commerce Stans.</note></head>
          <p>Body text.</p>
        </div>
        """)
        #expect(!h.contains("Source:"), "header leaked its source note: \(h)")
        #expect(!h.contains("Nixon Presidential Materials"))
        #expect(h.hasPrefix("501. Memorandum From the President's Assistant"))
        // The summary note is a footnote too, and equally must not land in the title.
        #expect(!h.contains("Kissinger forwarded a report"))
    }

    /// The issue's own example shape — a source note whose text begins mid-title.
    @Test("The header stops at the title even when a source note follows immediately")
    func issueTypeCase() async throws {
        let h = try await header(fromBody: """
        <div type="document" xml:id="d376">
          <head>376. Letter From Secretary of State Rogers to Secretary of Commerce Stans<note n="1" type="source" xml:id="d376fn1">Source: National Archives, RG 59, Central Files 1970–73, ORG 1 COM–STATE. No classification marking.</note></head>
          <p>Body.</p>
        </div>
        """)
        #expect(h == "376. Letter From Secretary of State Rogers to Secretary of Commerce Stans",
                "got: \(h)")
    }

    /// `rend="inline"` normally hoists a note's children into the surrounding text. A
    /// `type="source"` note is the documented exception, and the header depends on that exception
    /// holding — otherwise the provenance text becomes ordinary character data inside the `<head>`
    /// and no footnote filter can remove it.
    @Test("An inline-rendered source note is still treated as a footnote, not hoisted into the title")
    func inlineRenderedSourceNoteStillExcluded() async throws {
        let h = try await header(fromBody: """
        <div type="document" xml:id="d12">
          <head>12. Telegram From the Embassy in Iran to the Department of State<note rend="inline" type="source">[Source: Central Intelligence Agency, DDO Files. Secret.]</note></head>
          <p>Body.</p>
        </div>
        """)
        #expect(!h.contains("Source:"), "an inline source note leaked into the header: \(h)")
        #expect(h == "12. Telegram From the Embassy in Iran to the Department of State", "got: \(h)")
    }

    /// A head carrying no note at all must pass through untouched — the wave-1 display helper
    /// `DocumentHeaderDisplay.trimmedHeader` makes the same promise, and this is the extractor's
    /// half of it.
    @Test("A clean header is unchanged")
    func cleanHeaderUnchanged() async throws {
        let h = try await header(fromBody: """
        <div type="document" xml:id="d1">
          <head>1. Memorandum of Conversation</head>
          <p>Body.</p>
        </div>
        """)
        #expect(h == "1. Memorandum of Conversation")
    }
}
