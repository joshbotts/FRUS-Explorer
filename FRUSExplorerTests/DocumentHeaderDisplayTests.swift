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
/// #1391 adds the numbered-row split: a row that prints the document number beside the stored
/// header takes both from ``DocumentHeaderDisplay/numberedRow(header:number:)``. The unit tests
/// below pin the rule, and `numberedRowsDrawTheSplit` pins, by reading the source, that each of the
/// four such rows hands its stored header and number to the rule, draws the rule's `number` and
/// `title` in a `Text`, and reads neither stored field anywhere else — so the unit tests cover what
/// the reader sees, as far as a source scan can: it reads each row's own declaration, not the
/// helpers it calls. `numberedRowScanCatchesEachShape` pins the scan itself against each way a row
/// could stop drawing the rule's output.
///
/// Version history:
///   1.0 — UI review wave 1 (CW-2): initial implementation
///   1.1 — #1391: the numbered-row split, and the four rows that draw it
///   1.2 — #1391 review: a capital letter suffix is the head's own number, the no-space fixtures are
///          the two heads that print none, and the scan proves each row draws the rule's output
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

    @Test("A letter suffix the head prints in capitals still makes the chip a duplicate")
    func repeatDetectionIgnoresTheSuffixCase() {
        // frus1961-63v10-12mSupp d278a: `@n` is "278a" and the head prints "278A." (#1391's review).
        #expect(DocumentHeaderDisplay.headerRepeatsNumber(
            "278A. Memorandum from CIA Inspector General Kirkpatrick to CIA Director Dulles, November 24",
            number: "278a"))
        // Case is the only thing it forgives: another suffix is another document's number.
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("278B. Memorandum", number: "278a"))
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

    @Test("A letter suffix the head prints in capitals is still the head's own number")
    func numberedRowStripsACapitalSuffix() {
        // frus1961-63v10-12mSupp d278a: `<div n="278a" …><head>278A. Memorandum from <gloss>CIA</gloss>
        // Inspector General…`. The stored number is `@n` as encoded — trimmed, never case-folded — so
        // a case-sensitive rule left this row reading "278a  278A. Memorandum…"; 14 heads in the two
        // mSupp volumes print their suffix this way. The column keeps `@n`'s spelling.
        #expect(DocumentHeaderDisplay.numberedRow(
            header: "278A. Memorandum from CIA Inspector General Kirkpatrick to CIA Director Dulles, November 24",
            number: "278a")
            == .init(number: "278a",
                     title: "Memorandum from CIA Inspector General Kirkpatrick to CIA Director Dulles, November 24"))
        // Case is the only thing the rule forgives: another suffix is another document's number.
        #expect(DocumentHeaderDisplay.numberedRow(header: "278B. Memorandum", number: "278a")
            == .init(number: "278a", title: "278B. Memorandum"))
    }

    @Test("No space after the period is still the head's own number")
    func numberedRowStripsWithoutASpace() {
        // frus1961-63v14 d44 and frus1964-68v26 d247 print no space after the stop
        // (`<head>44.Memorandum From…`), so their stored headers have none: the strip requires none.
        #expect(DocumentHeaderDisplay.numberedRow(
            header: "44.Memorandum From the Chief of Naval Operations (Burke) to Secretary of State Rusk",
            number: "44")
            == .init(number: "44",
                     title: "Memorandum From the Chief of Naval Operations (Burke) to Secretary of State Rusk"))
        #expect(DocumentHeaderDisplay.numberedRow(
            header: "247.Telegram From the Embassy in Indonesia to the Department of State", number: "247")
            == .init(number: "247", title: "Telegram From the Embassy in Indonesia to the Department of State"))
        // frus1882 d61 is encoded `61.<lb/>Mr. Trescot…`: its stored header has a space there only
        // because the line break reads as one.
        #expect(DocumentHeaderDisplay.numberedRow(
            header: "61. Mr. Trescot to Mr. Frelinghuysen.", number: "61")
            == .init(number: "61", title: "Mr. Trescot to Mr. Frelinghuysen."))
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

    @Test("Each numbered row hands its stored fields to the rule, draws the number and title it returns, and reads neither field elsewhere")
    func numberedRowsDrawTheSplit() throws {
        var scanned = 0
        for site in Self.numberedRowSites {
            let source = try Self.source(site.file)
            let declaration = try Self.declaration(site.signature, in: source, file: site.file)
            #expect(!declaration.isEmpty, "\(site.file): empty slice for \(site.signature)")
            scanned += 1
            for problem in try Self.numberedRowProblems(in: declaration, header: site.header,
                                                        number: site.number) {
                Issue.record("\(site.file): \(site.signature) \(problem)")
            }
        }
        #expect(scanned == Self.numberedRowSites.count)
        #expect(scanned == 4)
    }

    @Test("The scan reports each way a row can stop drawing the rule's output")
    func numberedRowScanCatchesEachShape() throws {
        func problems(_ declaration: String) throws -> [RowScanProblem] {
            try Self.numberedRowProblems(in: declaration, header: "doc.header",
                                         number: "doc.documentNumber")
        }
        // The Source Explorer twins' shape, and the graph rows' inline "N." number.
        #expect(try problems(Self.rowFixture()) == [])
        #expect(try problems(Self.rowFixture(number: #"if let num = row.number { Text("\(num).") }"#)) == [])
        // The number column dropped (the Browse-style fix the rule's doc comment rejects), bound to
        // something else, or drawing something else.
        #expect(try problems(Self.rowFixture(number: "")) == [.numberNotDrawn("row")])
        #expect(try problems(Self.rowFixture(number: "if let num = Optional<String>.none { Text(num) }"))
            == [.numberNotDrawn("row")])
        #expect(try problems(Self.rowFixture(number: "if let num = row.number { Text(doc.documentId) }"))
            == [.numberNotDrawn("row")])
        // The title replaced, or the number drawn where the title belongs.
        #expect(try problems(Self.rowFixture(title: "Text(doc.documentId)")) == [.titleNotDrawn("row")])
        #expect(try problems(Self.rowFixture(title: #"Text(row.number ?? "")"#)) == [.titleNotDrawn("row")])
        // A stored field read outside the rule, by each spelling the rows use or could.
        #expect(try problems(Self.rowFixture(extra: "Text(doc.header)")) == [.readsStoredField("header")])
        #expect(try problems(Self.rowFixture(extra: "if let meta = node.metadata { Text(meta.header) }"))
            == [.readsStoredField("header")])
        #expect(try problems(Self.rowFixture(extra: #"Text(node.metadata!.documentNumber ?? "")"#))
            == [.readsStoredField("documentNumber")])
        #expect(try problems(Self.rowFixture(extra: "Text(node.metadata?.header ?? node.id)"))
            == [.readsStoredField("header")])
        // The rule given the wrong field, its output never bound, or never called at all.
        #expect(try problems(Self.rowFixture(
            call: "let row = DocumentHeaderDisplay.numberedRow(header: doc.volumeId, number: doc.documentNumber)"))
            == [.headerNotPassed("doc.header")])
        #expect(try problems(Self.rowFixture(
            call: "", number: "",
            title: "Text(DocumentHeaderDisplay.numberedRow(header: doc.header, number: doc.documentNumber).title)"))
            == [.outputNotBound])
        #expect(try problems(Self.rowFixture(call: "", number: "", title: "Text(doc.volumeId)"))
            == [.noRuleCall])
    }

    @Test("The slicers return one bounded declaration, one call's arguments, and every call of a name")
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
        // Every call of a name, and only calls of that name: `RichText(` is not `Text(`.
        #expect(Self.calls(of: "Text", in: #"RichText(a) Text(b) Text(verbatim: "\(c).")"#)
            == ["(b)", #"(verbatim: "\(c).")"#])
    }

    // MARK: - The numbered-row scan

    /// What the source scan finds wrong with a numbered row's declaration.
    enum RowScanProblem: Equatable, CustomStringConvertible {
        /// The row never calls the rule, so it draws the stored header itself.
        case noRuleCall
        /// The rule is not given this stored-header expression.
        case headerNotPassed(String)
        /// The rule is not given this stored-number expression.
        case numberNotPassed(String)
        /// The rule's output is not bound with `let <name> = …`, so what the row draws of it
        /// cannot be checked.
        case outputNotBound
        /// The row reads this stored field outside the rule's arguments.
        case readsStoredField(String)
        /// No `Text` draws the rule's `number` (bound to this name).
        case numberNotDrawn(String)
        /// No `Text` draws the rule's `title` (bound to this name).
        case titleNotDrawn(String)

        /// The problem as the scan reports it, after the row's file and signature.
        var description: String {
            switch self {
            case .noRuleCall: "draws the stored header itself — no \(DocumentHeaderDisplayTests.ruleCall)…)"
            case .headerNotPassed(let expression): "does not give the rule \(expression)"
            case .numberNotPassed(let expression): "does not give the rule \(expression)"
            case .outputNotBound: "does not bind the rule's output, so the scan cannot see what it draws"
            case .readsStoredField(let field): "reads .\(field) outside the rule"
            case .numberNotDrawn(let binding): "never draws \(binding).number in a Text"
            case .titleNotDrawn(let binding): "never draws \(binding).title in a Text"
            }
        }
    }

    /// The call every numbered row makes.
    static let ruleCall = "DocumentHeaderDisplay.numberedRow("

    /// The two stored fields a numbered row may read only as the rule's arguments.
    private static let storedFields = ["header", "documentNumber"]

    /// Everything wrong with how `declaration` draws the numbered-row split; empty when it hands
    /// `header` and `number` to the rule, draws the rule's `number` and `title` in a `Text`, and
    /// reads neither stored field anywhere else.
    ///
    /// The stored-field check is on the MEMBER NAME (`.header`, `.documentNumber`), not on the
    /// expression the rule was given: a row can reach the same field as `node.metadata!.header`, as
    /// a bound `meta.header` or through a key path, and none of those contains the argument's
    /// spelling. It reads comments too, so a comment naming `doc.header` in a row fails the scan —
    /// a false alarm a rewording fixes, where skipping comments could hide real code.
    private static func numberedRowProblems(in declaration: String, header: String,
                                            number: String) throws -> [RowScanProblem] {
        guard let arguments = arguments(of: ruleCall, in: declaration) else { return [.noRuleCall] }
        var problems: [RowScanProblem] = []
        if !arguments.contains("header: \(header)") { problems.append(.headerNotPassed(header)) }
        if !arguments.contains("number: \(number)") { problems.append(.numberNotPassed(number)) }
        let outside = declaration.replacingOccurrences(of: arguments, with: "()")
        for field in storedFields {
            if try Regex(#"\.\s*"# + field + #"\b"#).firstMatch(in: outside) != nil {
                problems.append(.readsStoredField(field))
            }
        }
        guard let binding = try firstCapture(#"let\s+(\w+)\s*=\s*DocumentHeaderDisplay\.numberedRow\("#,
                                             in: declaration) else {
            problems.append(.outputNotBound)
            return problems
        }
        let texts = calls(of: "Text", in: outside)
        if try !texts.contains(where: { try refers($0, to: binding, member: "title") }) {
            problems.append(.titleNotDrawn(binding))
        }
        if try !drawsNumber(of: binding, texts: texts, in: outside) {
            problems.append(.numberNotDrawn(binding))
        }
        return problems
    }

    /// Whether `scope` draws `<binding>.number`: a `Text` reads it directly, or an
    /// `if let <name> = <binding>.number` block holds a `Text` that reads `<name>`.
    private static func drawsNumber(of binding: String, texts: [String], in scope: String) throws -> Bool {
        if try texts.contains(where: { try refers($0, to: binding, member: "number") }) { return true }
        for match in scope.matches(of: try Regex(#"if\s+let\s+(\w+)\s*=\s*"# + binding + #"\.number\b"#)) {
            guard let name = match.output[1].substring,
                  let brace = scope[match.range.upperBound...].firstIndex(of: "{"),
                  let block = balanced(from: brace, open: "{", close: "}", in: scope) else { continue }
            if try calls(of: "Text", in: block).contains(where: { try refers($0, to: String(name)) }) {
                return true
            }
        }
        return false
    }

    /// Whether `text` reads the identifier `name` (or its `member`) as a whole word.
    private static func refers(_ text: String, to name: String, member: String? = nil) throws -> Bool {
        let pattern = #"\b"# + name + (member.map { #"\."# + $0 } ?? "") + #"\b"#
        return try Regex(pattern).firstMatch(in: text) != nil
    }

    /// The first capture group of `pattern` in `text`, or `nil` when it does not match.
    private static func firstCapture(_ pattern: String, in text: String) throws -> String? {
        guard let match = try Regex(pattern).firstMatch(in: text),
              let capture = match.output[1].substring else { return nil }
        return String(capture)
    }

    /// A numbered row's declaration, correct by default, with one part replaced to model a mutant.
    private static func rowFixture(
        call: String = "let row = DocumentHeaderDisplay.numberedRow(header: doc.header, number: doc.documentNumber)",
        number: String = "if let num = row.number { Text(num) }",
        title: String = "Text(row.title.isEmpty ? doc.documentId : row.title)",
        extra: String = ""
    ) -> String {
        """
        private func row(_ doc: RelatedDocument) -> some View {
            \(call)
            HStack {
                \(number)
                \(title)
                \(extra)
            }
        }
        """
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
        guard let brace = source[start.lowerBound...].firstIndex(of: "{"),
              let body = balanced(from: brace, open: "{", close: "}", in: source) else {
            Issue.record("\(file): unbalanced braces after \(signature)")
            return ""
        }
        return String(source[start.lowerBound..<brace]) + body
    }

    /// The argument list of the first `call` in `scope`, from its `(` to the `)` that closes it, or
    /// `nil` when `scope` makes no such call.
    private static func arguments(of call: String, in scope: String) -> String? {
        guard let range = scope.range(of: call),
              let open = scope[range].lastIndex(of: "(") else { return nil }
        return balanced(from: open, open: "(", close: ")", in: scope)
    }

    /// The argument list of every call of `name` in `scope`, in order. A call counts only when
    /// `name` is not the tail of a longer identifier, so `RichText(` is not a call of `Text`.
    private static func calls(of name: String, in scope: String) -> [String] {
        var found: [String] = []
        var searchStart = scope.startIndex
        while let range = scope.range(of: name + "(", range: searchStart..<scope.endIndex) {
            searchStart = range.upperBound
            if range.lowerBound > scope.startIndex {
                let before = scope[scope.index(before: range.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" { continue }
            }
            if let list = balanced(from: scope.index(before: range.upperBound), open: "(", close: ")",
                                   in: scope) {
                found.append(list)
            }
        }
        return found
    }

    /// The text from the `open` character at `start` to the `close` that balances it, or `nil`
    /// when nothing does.
    private static func balanced(from start: String.Index, open: Character, close: Character,
                                 in scope: String) -> String? {
        var depth = 0
        var cursor = start
        while cursor < scope.endIndex {
            if scope[cursor] == open { depth += 1 }
            if scope[cursor] == close {
                depth -= 1
                if depth == 0 { return String(scope[start...cursor]) }
            }
            cursor = scope.index(after: cursor)
        }
        return nil
    }
}
