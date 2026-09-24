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

/// The display-time repair for double-numbered rows and leaked source notes (UI review X-2).
///
/// #1391 adds the numbered-row split: a row that prints the document number in a column of its own
/// beside the stored header takes both from ``DocumentHeaderDisplay/numberedRow(header:number:)``.
/// The unit tests below pin the rule, and `numberedRowsDrawTheSplit` pins, by reading the source,
/// that each of the four such rows draws what the rule returns — so the unit tests cover what the
/// reader sees.
///
/// Version history:
///   1.0 — UI review wave 1 (CW-2): initial implementation
///   1.1 — #1391: the numbered-row split, and the four rows that draw it
@Suite("Document header display")
struct DocumentHeaderDisplayTests {

    @Test("A header opening with its own number makes the chip a duplicate")
    func repeatDetection() {
        #expect(DocumentHeaderDisplay.headerRepeatsNumber("251. Memorandum From…", number: "251"))
        #expect(DocumentHeaderDisplay.headerRepeatsNumber("372a. Letter From…", number: "372a"))
        #expect(DocumentHeaderDisplay.headerRepeatsNumber(" 251. Memo", number: "251"))
        // Exactness: "2510." does not repeat "251", and an unnumbered row never suppresses.
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("2510. Memo", number: "251"))
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("Memorandum 251", number: "251"))
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("251. Memo", number: nil))
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("251. Memo", number: ""))
    }

    @Test("A leaked source note is cut from the title, and a legitimate one is left alone")
    func sourceTrim() {
        #expect(DocumentHeaderDisplay.trimmedHeader(
            "376. Letter From Secretary Rogers Source: National Archives, RG 59, Central Files")
            == "376. Letter From Secretary Rogers")
        // Only a mid-string leak is cut: a header BEGINNING with the marker is content.
        let front = "Source: Abbreviations Used in This Volume"
        #expect(DocumentHeaderDisplay.trimmedHeader(front) == front)
        // No marker, no change.
        #expect(DocumentHeaderDisplay.trimmedHeader("134. Memorandum for the President")
            == "134. Memorandum for the President")
    }

    // MARK: - #1391: the numbered-row split

    @Test("A head that opens with its own number and a period loses it; the number keeps its column")
    func numberedRowStripsItsOwnNumber() {
        // frus1945-50Intel: `<head>256. Department of State Briefing Memorandum<note …>`.
        #expect(DocumentHeaderDisplay.numberedRow(
            header: "256. Department of State Briefing Memorandum", number: "256")
            == .init(number: "256", title: "Department of State Briefing Memorandum"))
        // A letter-suffixed number is the document's own number too.
        #expect(DocumentHeaderDisplay.numberedRow(header: "372a. Letter From the Ambassador",
                                                  number: "372a")
            == .init(number: "372a", title: "Letter From the Ambassador"))
    }

    @Test("No space after the period is still the head's own number, so the strip does not depend on the join")
    func numberedRowStripsWithoutASpace() {
        // frus1882 d61 is encoded `61.<lb/>Mr. Trescot…`: whether the stored header joins the two
        // with a space (#1375's `joinPrinted`, index v55) or not, the row reads the same.
        let expected = DocumentHeaderDisplay.NumberedRow(
            number: "61", title: "Mr. Trescot to Mr. Frelinghuysen.")
        #expect(DocumentHeaderDisplay.numberedRow(
            header: "61.Mr. Trescot to Mr. Frelinghuysen.", number: "61") == expected)
        #expect(DocumentHeaderDisplay.numberedRow(
            header: "61. Mr. Trescot to Mr. Frelinghuysen.", number: "61") == expected)
    }

    @Test("A head that prints no number is left whole")
    func numberedRowLeavesAnUnnumberedHead() {
        // frus1952-54v02p1 prints the number only in `@n`: the column is the only place it appears.
        let head = "Report to the National Security Council by the Executive Secretary"
        #expect(DocumentHeaderDisplay.numberedRow(header: head, number: "41")
            == .init(number: "41", title: head))
    }

    @Test("A head opening with a number that is not its own is left whole")
    func numberedRowLeavesAnotherNumber() {
        // A different number entirely.
        #expect(DocumentHeaderDisplay.numberedRow(header: "255. Memorandum for the Record",
                                                  number: "256")
            == .init(number: "256", title: "255. Memorandum for the Record"))
        // A longer number that merely starts with this one: "2560." is not "256.".
        #expect(DocumentHeaderDisplay.numberedRow(header: "2560. Memorandum for the Record",
                                                  number: "256")
            == .init(number: "256", title: "2560. Memorandum for the Record"))
        // The number followed by a space and no period: the rule is the number AND a period, so a
        // head that opens "41 Senators…" is not read as numbered (`headerRepeatsNumber`, which
        // decides whether a search row's chip is a duplicate, is wider and is not this rule).
        #expect(DocumentHeaderDisplay.numberedRow(header: "41 Senators to the President",
                                                  number: "41")
            == .init(number: "41", title: "41 Senators to the President"))
    }

    @Test("No number, an empty number, or nothing after the period leaves the head whole")
    func numberedRowGuards() {
        // No number: nothing to strip, and no column.
        #expect(DocumentHeaderDisplay.numberedRow(header: "256. Memorandum", number: nil)
            == .init(number: nil, title: "256. Memorandum"))
        // An empty number: without its own guard, "" + "." would strip any head opening with a
        // full stop.
        #expect(DocumentHeaderDisplay.numberedRow(header: ". . . and the reply", number: "")
            == .init(number: "", title: ". . . and the reply"))
        // A head that is only the number: stripping it would leave the row with no title.
        #expect(DocumentHeaderDisplay.numberedRow(header: "256.", number: "256")
            == .init(number: "256", title: "256."))
        #expect(DocumentHeaderDisplay.numberedRow(header: "256.  ", number: "256")
            == .init(number: "256", title: "256.  "))
        // Leading whitespace before the number does not hide it.
        #expect(DocumentHeaderDisplay.numberedRow(header: " 256. Memorandum", number: "256")
            == .init(number: "256", title: "Memorandum"))
    }

    // MARK: - #1391: the four rows draw the split

    /// One row that prints the number beside the stored header: its file, the declaration that
    /// draws it, and the two stored fields it must hand to the rule rather than draw.
    private struct NumberedRowSite {
        /// Repository-relative path of the view file.
        let file: String
        /// The declaration's signature, up to and including its opening brace.
        let signature: String
        /// The expression holding the stored header.
        let header: String
        /// The expression holding the document number.
        let number: String
    }

    /// The four rows #1391 names — the two Source Explorer twins, the macOS graph window's
    /// document picker and the graph's shared reference list.
    private static let numberedRowSites: [NumberedRowSite] = [
        .init(file: "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift",
              signature: "private func macRelatedDocumentRow(_ doc: IndexingPipeline.RelatedDocument) -> some View {",
              header: "doc.header", number: "doc.documentNumber"),
        .init(file: "FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
              signature: "private func relatedDocumentRow(_ doc: IndexingPipeline.RelatedDocument) -> some View {",
              header: "doc.header", number: "doc.documentNumber"),
        .init(file: "FRUSExplorer/CrossReference/CrossReferenceGraphWindowView.swift",
              signature: "private func documentPickerList(_ docs: [DocumentBrowserEntry]) -> some View {",
              header: "doc.header", number: "doc.documentNumber"),
        .init(file: "FRUSExplorer/CrossReference/ReferenceListPanel.swift",
              signature: "private func rowContent(node: DisplayNode, edge: DisplayEdge?) -> some View {",
              header: "node.metadata?.header", number: "node.metadata?.documentNumber"),
    ]

    @Test("Each numbered row hands its stored header and number to the rule and draws only what it returns")
    func numberedRowsDrawTheSplit() throws {
        let call = "DocumentHeaderDisplay.numberedRow("
        var scanned = 0
        for site in Self.numberedRowSites {
            let source = try Self.source(site.file)
            let declaration = try Self.declaration(site.signature, in: source, file: site.file)
            #expect(!declaration.isEmpty, "\(site.file): empty slice for \(site.signature)")
            scanned += 1
            guard let arguments = Self.arguments(of: call, in: declaration) else {
                Issue.record("\(site.file): the row draws the stored header itself — no \(call)…) in \(site.signature)")
                continue
            }
            #expect(arguments.contains("header: \(site.header)"),
                    "\(site.file): the rule is not given \(site.header): \(arguments)")
            #expect(arguments.contains("number: \(site.number)"),
                    "\(site.file): the rule is not given \(site.number): \(arguments)")
            // Outside the call, the row may not read either stored field: it draws the rule's output.
            let outside = declaration.replacingOccurrences(of: arguments, with: "()")
            #expect(!outside.contains(site.header),
                    "\(site.file): \(site.signature) still draws \(site.header) outside the rule")
            #expect(!outside.contains(site.number),
                    "\(site.file): \(site.signature) still draws \(site.number) outside the rule")
        }
        #expect(scanned == Self.numberedRowSites.count)
        #expect(scanned == 4)
    }

    @Test("The slicers return one bounded declaration and one call's arguments")
    func numberedRowSlicersAreSound() throws {
        let fixture = """
        private func row(_ doc: Doc) -> some View {
            let r = Rule.split(header: doc.header, number: f(doc.number))
            Text(r.title)
        }
        private func next() { doc.header }
        """
        let declaration = try Self.declaration("private func row(_ doc: Doc) -> some View {",
                                               in: fixture, file: "fixture")
        #expect(declaration.hasSuffix("Text(r.title)\n}"))
        #expect(!declaration.contains("next()"))
        #expect(Self.arguments(of: "Rule.split(", in: declaration)
            == "(header: doc.header, number: f(doc.number))")
        #expect(Self.arguments(of: "Absent.call(", in: declaration) == nil)
    }

    // MARK: - Source reading

    /// The contents of a repository file, by its path from the repository root.
    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// The declaration beginning at `signature`, from its first brace to the brace that closes it.
    private static func declaration(_ signature: String, in source: String,
                                    file: String) throws -> String {
        let start = try #require(source.range(of: signature), "\(file): no declaration \(signature)")
        var depth = 0
        var cursor = start.lowerBound
        while cursor < source.endIndex {
            let character = source[cursor]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(source[start.lowerBound...cursor]) }
            }
            cursor = source.index(after: cursor)
        }
        Issue.record("\(file): unbalanced braces after \(signature)")
        return ""
    }

    /// The argument list of the first `call` in `scope`, from its `(` to the `)` that closes it, or
    /// `nil` when `scope` makes no such call.
    private static func arguments(of call: String, in scope: String) -> String? {
        guard let range = scope.range(of: call),
              let open = scope[range].lastIndex(of: "(") else { return nil }
        var depth = 0
        var cursor = open
        while cursor < scope.endIndex {
            if scope[cursor] == "(" { depth += 1 }
            if scope[cursor] == ")" {
                depth -= 1
                if depth == 0 { return String(scope[open...cursor]) }
            }
            cursor = scope.index(after: cursor)
        }
        return nil
    }
}
