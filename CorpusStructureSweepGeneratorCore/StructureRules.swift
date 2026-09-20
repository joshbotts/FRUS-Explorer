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

/// The level tests that find a `<div>` sitting at the wrong depth.
///
/// **Every rule here is a LEVEL TEST — an independent statement that a div belongs beside its
/// parent rather than inside it — and that is the whole design.** The obvious detector is the
/// shape #1309's own evidence describes: the absorbed divs form a trailing run and close together
/// with their parent. Measured over the corpus, that shape holds for **16,757 of 16,813**
/// structural (parent, child-suffix) pairs — 99.7%. It is the shape of every well-formed last
/// child, and it discriminates nothing.
///
/// The second obvious detector is worse. A displaced tag does NOT carry stale indentation: the
/// corpus is pretty-printed to the structure it asserts, so at `frus1945Malta`'s ch8/ch9 boundary
/// the closes ladder 24 → 20 → 16 → 12 spaces perfectly. Zero signal.
///
/// **The defect is a DISPLACED tag, never a missing one.** Every file in the corpus is well-formed
/// and every `</div>` count balances — the parent's closing tag simply sits after the absorbed run
/// instead of before it. No XML validator, no TEI schema and no ODD can catch any of this, which is
/// why it has shipped for years, and why every correction this tool states is a *move*.
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public enum StructureRules {

    /// Structural rank: a chapter may hold a subchapter, never another chapter.
    static func rank(of type: String) -> Int? {
        switch type {
        case "compilation": return 0
        case "chapter": return 1
        case "subchapter": return 2
        default: return nil
        }
    }

    // MARK: - R1: a structural rank violation

    /// A div whose nearest structural ancestor is of equal or higher rank.
    ///
    /// **Two exclusions are load-bearing, and both were measured rather than assumed.**
    /// `subchapter`-in-`subchapter` occurs 915 times corpus-wide — it is the corpus's own recursive
    /// sub-sub-section idiom, not a defect — and `compilation`-in-`section` twice, both deliberate
    /// part-title pages in `frus1873p1v2`. Without them the rule reports 937 hits at 97.7% noise,
    /// which is the naive Schematron an outsider would propose and must not be sent to OH.
    ///
    /// Each absorbed RUN collapses to its maximal member: a run of N absorbed siblings satisfies
    /// the rule at every suffix, and only the longest is a distinct thing to fix.
    public static func rankViolations(in nodes: [DivNode]) -> [Int] {
        // A mistyped container is reported by R1b as ONE retype; its children are correctly
        // nested and must not also be reported as misplaced.
        let mistyped = Set(mistypedContainers(in: nodes))
        var flagged: [Int] = []
        for node in nodes where node.isStructural {
            guard let childRank = rank(of: node.type),
                  let parentIndex = nearestStructuralAncestor(of: node, in: nodes) else { continue }
            let parent = nodes[parentIndex]
            guard let parentRank = rank(of: parent.type), parentRank >= childRank else { continue }
            // The corpus's own idioms, excluded by name.
            if parent.type == "subchapter", node.type == "subchapter" { continue }
            if parent.type == "section", node.type == "compilation" { continue }
            if mistyped.contains(parentIndex) { continue }
            flagged.append(node.index)
        }
        return maximalRuns(flagged, in: nodes)
    }

    // MARK: - R2: a conference day inside another conference day

    /// A day heading — `Monday, February 5, 1945` — whose structural parent is also a day.
    ///
    /// The head is matched with `<note>` subtrees already stripped (`DivScanner` does it), because
    /// a day heading often carries an editorial note and an anchored match would miss every one.
    /// That single omission hid a whole volume in the first measurement pass.
    public static func dayInDay(in nodes: [DivNode]) -> [Int] {
        let days = Set(nodes.filter { $0.isStructural && isDayHeading($0.headText) }.map(\.index))
        return nodes.filter { node in
            days.contains(node.index)
                && nearestStructuralAncestor(of: node, in: nodes).map { days.contains($0) } == true
        }.map(\.index)
    }

    /// Whether a heading is a conference day, as FRUS prints one.
    public static func isDayHeading(_ head: String) -> Bool {
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let months = ["January", "February", "March", "April", "May", "June", "July", "August",
                      "September", "October", "November", "December"]
        let parts = head.split(separator: " ").map(String.init)
        guard parts.count == 4 else { return false }
        guard weekdays.contains(parts[0].trimmingCharacters(in: CharacterSet(charactersIn: ","))),
              parts[0].hasSuffix(","), months.contains(parts[1]) else { return false }
        guard parts[2].hasSuffix(","), Int(parts[2].dropLast()) != nil else { return false }
        return parts[3].count == 4 && Int(parts[3]) != nil
    }

    // MARK: - R3: a conference session inside another session

    /// A timed session whose structural parent is also a timed session, inside a day.
    ///
    /// Scoped to STRUCTURAL divs: a `document` carrying a time in its head is an ordinary printed
    /// paper, not a container, and flagging those was measured at 60% false.
    public static func sessionInSession(in nodes: [DivNode]) -> [Int] {
        let timed = Set(nodes.filter { $0.isStructural && hasClockTime($0.headText) }.map(\.index))
        return nodes.filter { node in
            timed.contains(node.index)
                && nearestStructuralAncestor(of: node, in: nodes).map { timed.contains($0) } == true
        }.map(\.index)
    }

    /// Whether a heading names a time of day, in the forms the conference volumes print.
    public static func hasClockTime(_ head: String) -> Bool {
        let lowered = head.lowercased()
        if lowered.contains("noon") { return true }
        for part in ["morning", "afternoon", "evening"] where lowered.contains(", \(part)") {
            return true
        }
        // 4 p.m. / 4:15 p.m. / 11 a. m.
        var characters = Array(lowered)
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else { index += 1; continue }
            var cursor = index
            while cursor < characters.count, characters[cursor].isNumber { cursor += 1 }
            if cursor < characters.count, characters[cursor] == ":" {
                cursor += 1
                while cursor < characters.count, characters[cursor].isNumber { cursor += 1 }
            }
            let tail = String(characters[cursor...].prefix(8))
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ".", with: "")
            if tail.hasPrefix("am") || tail.hasPrefix("pm") { return true }
            index = cursor + 1
        }
        return false
    }

    // MARK: - R4: a chapter inside a historical document

    /// A `chapter` whose parent is `section[@subtype="historical-document"]`.
    ///
    /// Naming the subtype is load-bearing: widening to any `section` takes the rule from 4 rows at
    /// 100% precision to 11 at 36%, because `frus1873p2v3`'s `subtype="appendix"` deliberately
    /// holds seven chapters.
    public static func chapterInHistoricalDocument(in nodes: [DivNode]) -> [Int] {
        nodes.filter { node in
            guard node.type == "chapter", let parentIndex = node.parent, parentIndex >= 0 else {
                return false
            }
            let parent = nodes[parentIndex]
            return parent.type == "section" && parent.subtype == "historical-document"
        }.map(\.index)
    }

    // MARK: - R5: apparatus that has left the volume root

    /// A sources section holding divs, or a persons/terms/abbreviations index below the root.
    ///
    /// **Must be run over `<front>` and `<back>` as well as `<body>`**: two of the three real
    /// findings live in front matter, and a body-scoped scan sees one of them.
    public static func displacedApparatus(in nodes: [DivNode]) -> [Int] {
        var flagged: [Int] = []
        for node in nodes where node.type == "section" {
            if node.subtype == "sources", !node.children.isEmpty {
                flagged.append(node.index)
            }
            if node.subtype == "index", let id = node.id,
               ["persons", "terms", "abbreviations"].contains(id), node.depth > 0 {
                flagged.append(node.index)
            }
        }
        return maximalRuns(flagged, in: nodes)
    }

    // MARK: - R6: the volume's own id grammar puts the div one level up

    /// A `chNsubsubchM` whose parent is not the matching `chNsubchK`.
    ///
    /// **The LEVEL assertion is reliable; the NUMBER is not.** Strengthening this to compare the
    /// chapter number would mint 27 false rows across four volumes, each a stale id-minting counter
    /// with a constant per-file offset (`frus1914`'s `ch93subch1–3` sit correctly inside `ch96`).
    /// So this compares only the SHAPE of the parent's id, never its digits.
    public static func idLevelViolations(in nodes: [DivNode]) -> [Int] {
        nodes.filter { node in
            guard let id = node.id, subsubchapterChapter(of: id) != nil else { return false }
            guard let parentIndex = node.parent, parentIndex >= 0,
                  let parentId = nodes[parentIndex].id else { return true }
            // SHAPE only. Comparing the chapter NUMBER here would mint 27 false rows across four
            // volumes, each a stale id-minting counter with a constant per-file offset
            // (`frus1914`'s `ch93subch1–3` sit correctly inside `ch96`). The level assertion is
            // reliable; the number is not.
            return !isSubchapterId(parentId)
        }.map(\.index)
    }

    /// `ch12subsubch23` → `ch12`, or `nil` when the id is not a sub-subchapter.
    static func subsubchapterChapter(of id: String) -> String? {
        guard let range = id.range(of: "subsubch") else { return nil }
        let head = String(id[id.startIndex..<range.lowerBound])
        let tail = String(id[range.upperBound...])
        guard head.hasPrefix("ch"), Int(head.dropFirst(2)) != nil else { return nil }
        let digits = tail.prefix { $0.isNumber }
        guard !digits.isEmpty, tail.dropFirst(digits.count).allSatisfy({ $0.isLetter }) else {
            return nil
        }
        return head
    }

    /// Whether `id` has the SHAPE of a subchapter id — `ch<N>subch<M>` — whatever its numbers.
    static func isSubchapterId(_ id: String) -> Bool {
        guard id.hasPrefix("ch"), let range = id.range(of: "subch") else { return false }
        let chapterDigits = id[id.index(id.startIndex, offsetBy: 2)..<range.lowerBound]
        guard !chapterDigits.isEmpty, chapterDigits.allSatisfy(\.isNumber) else { return false }
        let tail = id[range.upperBound...]
        guard !tail.hasPrefix("subch") else { return false }   // subsubch is not a subchapter
        let digits = tail.prefix { $0.isNumber }
        return !digits.isEmpty && tail.dropFirst(digits.count).allSatisfy(\.isLetter)
    }

    // MARK: - R7: a subchapter expelled from every chapter

    /// A `type="subchapter"` whose id names a chapter and which has no chapter ancestor at all.
    ///
    /// The id-prefix half of this probe is useless alone — 41 rows in 7 files, 6 of them false,
    /// because `frus1945Malta` legitimately nests meetings under days. Conjoined with "no chapter
    /// ancestor" it reduces to one volume and nothing else.
    public static func expelledSubchapters(in nodes: [DivNode]) -> [Int] {
        var flagged: [Int] = []
        for node in nodes where node.type == "subchapter" {
            guard let id = node.id, id.hasPrefix("ch"), id.contains("subch") else { continue }
            var ancestor = node.parent
            var hasChapter = false
            while let index = ancestor, index >= 0 {
                if nodes[index].type == "chapter" { hasChapter = true; break }
                ancestor = nodes[index].parent
            }
            if !hasChapter { flagged.append(node.index) }
        }
        return maximalRuns(flagged, in: nodes)
    }

    // MARK: - R8: an editorial note holding a document

    /// A document inside an `editorial-note` document.
    ///
    /// Naming `editorial-note` on the PARENT is load-bearing: any-document-in-document takes the
    /// rule from 1 row at 100% to 4 at 25%, because `frus1902app1`'s EXHIBIT I and II are
    /// legitimately nested historical documents. Base rate: 1 of 8,467 editorial notes.
    public static func documentInEditorialNote(in nodes: [DivNode]) -> [Int] {
        nodes.filter { node in
            guard node.type == "document", let parentIndex = node.parent, parentIndex >= 0 else {
                return false
            }
            let parent = nodes[parentIndex]
            return parent.type == "document" && parent.subtype == "editorial-note"
        }.map(\.index)
    }

    // MARK: - Shared helpers

    /// The nearest ancestor that is a structural div, skipping documents and anything else.
    static func nearestStructuralAncestor(of node: DivNode, in nodes: [DivNode]) -> Int? {
        var index = node.parent
        while let current = index, current >= 0 {
            if nodes[current].isStructural { return current }
            index = nodes[current].parent
        }
        return nil
    }

    /// Reduces a flagged set to the FIX SITES an editor would act on.
    ///
    /// Two collapses, and both were measured rather than assumed:
    /// 1. A flagged div's flagged DESCENDANTS are not separate things to fix — one displaced tag
    ///    puts a whole subtree at the wrong level.
    /// 2. A contiguous run of flagged SIBLINGS under one parent is one displaced tag, not N.
    ///    Without this, `frus1947v03` reports ten sites where it has two, and the report would
    ///    ask an editor to make the same edit ten times.
    static func maximalRuns(_ flagged: [Int], in nodes: [DivNode]) -> [Int] {
        let flaggedSet = Set(flagged)
        let outermost = flagged.filter { index in
            var ancestor = nodes[index].parent
            while let current = ancestor, current >= 0 {
                if flaggedSet.contains(current) { return false }
                ancestor = nodes[current].parent
            }
            return true
        }.sorted()

        // Keep the first of each contiguous sibling run.
        let kept = Set(outermost)
        return outermost.filter { index in
            guard let parentIndex = nodes[index].parent, parentIndex >= 0 else { return true }
            let siblings = nodes[parentIndex].children
            guard let position = siblings.firstIndex(of: index), position > 0 else { return true }
            return !kept.contains(siblings[position - 1])
        }
    }

    /// How many contiguous flagged siblings this fix site covers, including itself.
    public static func runLength(from index: Int, flagged: Set<Int>, in nodes: [DivNode]) -> Int {
        guard let parentIndex = nodes[index].parent, parentIndex >= 0 else { return 1 }
        let siblings = nodes[parentIndex].children
        guard var position = siblings.firstIndex(of: index) else { return 1 }
        var count = 0
        while position < siblings.count, flagged.contains(siblings[position]) {
            count += 1
            position += 1
        }
        return max(1, count)
    }

    // MARK: - R1b: a container whose @type contradicts its own xml:id

    /// A div typed `chapter` whose `xml:id` says `comp…` and which holds chapters.
    ///
    /// **The nesting here is CORRECT and only the `@type` is wrong**, so this must not be reported
    /// as N misplaced children: an OH reviewer opening the first of ten such rows would find
    /// nothing wrong at that location, and the whole report would lose its reader. The live site
    /// already renders `frus1868p1` correctly. One row, naming the retype.
    public static func mistypedContainers(in nodes: [DivNode]) -> [Int] {
        nodes.filter { node in
            guard node.type == "chapter", let id = node.id, id.hasPrefix("comp"),
                  Int(id.dropFirst(4)) != nil else { return false }
            return node.children.contains { nodes[$0].type == "chapter" }
        }.map(\.index)
    }
}
