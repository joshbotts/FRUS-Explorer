// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - Copy scans (#1374, #1382, #1385)

/// Three scans over the app's user-facing string literals, designed together because two of them
/// hold opposite rules for the same shape of code.
///
/// - **Counts group and singularise** (#1374). A `%lld` or an interpolation placed before a
///   countable noun prints "1 volumes", and the `%lld` form prints "17606 docs" as well. Such a
///   literal must go through `CountCopy`, whose forms carry the count as a `%@`. On `v2` as last
///   merged (`a281f089`) the scan flags 380 entries (file plus string key; 383 literals) in 115
///   files. 75 were routed through `CountCopy` — the 43 that #1374, #1382 and #1422 name and the two
///   umbrella caveats beside them, 26 more in review, and the four Subseries-tile captions #1364
///   brought to the merge — two are not counts and are exempted with their reasons, and the other
///   303, in 99 files, are pinned in `countCopyBaseline`, which may only shrink.
/// - **Years never group** (#1382). `String(localized:)` formats an interpolated `Int` for the
///   locale, so a bare year reads "1,940". A year must be wrapped in `String(_:)` or given a
///   `format:`. This scan has no allowlist: on `v2` it found exactly the five sites #1382 names.
/// - **A parenthesis hugs its text** (#1385): "(of 25+ )" shipped with a space before the `)`.
///
/// ## What each scan reads
/// Every Swift file under `FRUSExplorer/`, through `LexedSource`, which records each string
/// literal with the call it sits in. A literal is in scope when it is a `defaultValue:` argument,
/// or when the innermost call around it is a SwiftUI initialiser or modifier that takes a
/// `LocalizedStringKey` — `Text`, `Label`, `Button`, `.help`, `.accessibilityLabel` and the rest of
/// `keyTakingViews` / `keyTakingModifiers`. That second half is what reaches #1374's bare
/// `Text("\(n) sections")`, which has no `defaultValue:` at all, and a ternary inside `Text`, whose
/// two branches are both the `Text`'s own literals. Measured on `v2` under the first rule,
/// `defaultValue:` alone gave 345 of the scan's 356 entries, bare `Text` ten more, and the other
/// key-taking calls one — an `.accessibilityLabel("\(notes.count) research notes from other
/// projects")` in `DocumentView`. All three shapes are in scope, so a new count literal in any of
/// them is read. A count built as a plain Swift `String` and handed to a view later is outside
/// every scan here: the Mac status bar's `"\(meta.totalDocuments) docs"` (`SupportingViews.swift`)
/// is one, and nothing but review sees it.
///
/// ## The count scan's rule, and what it deliberately does not see
/// A placeholder — `%lld`, `%N$lld` (or `%ld` / `%d`), or any interpolation — followed by one of:
/// - at most one lower-case word and then a noun from `countNouns`. The one-word window is what
///   reaches "59973 **source** notes", the site #1374 leads with; on `v2` it added 51 of the first
///   rule's 356 entries.
/// - at most one lower-case word and then any word hedged with `(s)` — "%lld document(s)",
///   "%lld cross-reference(s)". A hedge is a count's noun by construction, whatever the noun.
/// - a runtime noun, `%N$@` — "draw on %3$lld %4$@", where the noun is the unit lens's plural. The
///   first rule needed a literal noun, so it could not see this shape, which is how the umbrella
///   caveat #1374 named and the ranking caption above it were missed.
/// - `of them` — "%2$lld of them", a count whose noun is the sentence's subject.
///
/// The first rule was the first item alone. Review, round 1 added the other three and eight nouns
/// (`others` among them: "and 1 others" had shipped on every two-claimant class code); on the same
/// `v2` that added 22 entries and lost none.
///
/// What it still does not see:
/// - `%@` is not a placeholder: it is `CountCopy`'s own form, and measured over the tree it also
///   carries band titles and era labels ("the 1948–1960 volumes"), which are not counts. So a
///   hand-written `"%@ documents"` fed `n.formatted()` groups but does not singularise.
/// - An interpolation followed by another interpolation is not read as a count with a runtime noun:
///   all four such literals in the tree are prose — a prefix and a question, a concordance line, a
///   byte size — and none is a count.
/// - A count followed by a word that is not a noun — "%lld more", "%lld total in full corpus",
///   "%lld in scope" — reads right at one, so only its grouping can be wrong, and a noun list cannot
///   find it. The ones #1374 and #1422 name have emitter tests instead (`CountCopySiteTests`).
/// - A noun missing from `countNouns`. The list is a heuristic; `countScanRules` pins what it
///   reaches, not what it misses.
///
/// Version history:
///   1.0 — 2026-09-25: #1374, #1382 and #1385
///   1.1 — 2026-09-25: #1374 review, round 1 — the count rule reads `(s)` hedges, a runtime `%@`
///         noun and `of them`, and eight more nouns; the year scan's format fixture names a year
///   1.2 — 2026-09-25: #1380 — a fourth scan over the same literals, in its own section below:
///         no text the Mac compiles tells the reader to tap
///   1.3 — 2026-09-25: #1380 review, round 1 — the tap scan reads the Research Guide's prose, and
///         each of its exceptions carries a check that its reason still holds
extension CodingStandardsAuditTests {

    // MARK: - The tree

    /// `FRUSExplorer/`, from this file's location.
    static let copyScanSourceRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer")

    /// Every Swift file under `FRUSExplorer/`, lexed, keyed by its path relative to that folder.
    static func lexedAppSources() throws -> [(path: String, source: LexedSource)] {
        try FileManager.default.subpathsOfDirectory(atPath: copyScanSourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { path in
                let text = try String(contentsOf: copyScanSourceRoot.appendingPathComponent(path),
                                      encoding: .utf8)
                return (path, LexedSource(text))
            }
    }

    // MARK: - Counts go through CountCopy

    /// Every literal the count rule matches is either routed through `CountCopy` or listed in
    /// `countCopyBaseline`, and the baseline lists nothing the tree no longer holds. That is every
    /// count literal the rule can see, not every count in the tree: the file header lists the
    /// shapes it cannot, and the fixed ones among them are held by `CountCopySiteTests` instead.
    ///
    /// Three ways to fail that matter, each naming what to do: a flagged literal that is not listed
    /// (a new count string — route it through `CountCopy`, never list it); a listed one no longer
    /// flagged (fixed, renamed or moved — delete its entry and lower the ceiling); and a baseline
    /// whose size is not `countCopyBaselineCeiling`, which is what makes an added entry a visible
    /// edit to two numbers rather than one quiet line. `baselineViolations` also reports a
    /// duplicate, an entry both listed and exempted, and the exemptions' own staleness and pinned
    /// count; `baselineComparisonRules` holds one fixture for each. Entries are keyed by file and
    /// string key, never by line, so an unrelated edit above a site does not move it.
    @Test("CodingStandardsAudit: every count before a noun goes through CountCopy, against a baseline that only shrinks")
    func countsGoThroughCountCopy() throws {
        let files = try Self.lexedAppSources()
        var inScope = 0
        var flagged: [String: [Int]] = [:]
        for (path, lexed) in files {
            for literal in lexed.literals where CopyScan.isInScope(literal) {
                inScope += 1
                guard CopyScan.countsBeforeANoun(literal) else { continue }
                flagged["\(path) | \(lexed.key(of: literal))", default: []].append(literal.line)
            }
        }

        // A moved root or a lexer that stopped recording literals would make every check below
        // vacuous. Measured when the scan was written: 483 Swift files, 23,033 string literals, and
        // 7,280 of them in scope (23,099 and 7,308 after review, round 1 and #1364's merge). The
        // floors sit below that so that ordinary churn does not trip them.
        #expect(files.count >= 450, "Read only \(files.count) Swift file(s): the scan is broken, not the tree clean.")
        #expect(inScope >= 6_500, "Only \(inScope) literal(s) in scope: the scan is broken, not the tree clean.")

        let violations = Self.baselineViolations(
            flagged: Set(flagged.keys), baseline: Self.countCopyBaseline,
            exempt: Self.countScanFalsePositives.keys.sorted(),
            ceiling: Self.countCopyBaselineCeiling, exemptionCeiling: Self.countScanFalsePositivesCeiling)
        #expect(violations.isEmpty, """
            \(violations.map { Self.describe($0, lines: flagged) }.joined(separator: "\n\n"))
            """)
    }

    /// One way the tree's count literals and the shrink-only baseline disagree.
    enum BaselineViolation: Equatable, Sendable {
        /// Listed twice in `countCopyBaseline`.
        case duplicate(String)
        /// Both baselined and exempted.
        case overlap(String)
        /// Flagged and listed nowhere: a new count string.
        case new(String)
        /// Baselined but no longer flagged: fixed, re-keyed or moved.
        case stale(String)
        /// Exempted but no longer flagged.
        case staleExemption(String)
        /// The baseline's size is not its pinned ceiling.
        case ceiling(count: Int, ceiling: Int)
        /// The exemptions' size is not their pinned ceiling.
        case exemptionCeiling(count: Int, ceiling: Int)
    }

    /// Every disagreement between what the scan `flagged` and what the baseline and exemptions
    /// list, in a fixed order: duplicates, overlaps, new, stale, stale exemptions, then the two
    /// ceilings. The tree test reports these; `baselineComparisonRules` pins each kind.
    ///
    /// - Parameters:
    ///   - flagged: The entries (file plus string key) the scan flagged.
    ///   - baseline: `countCopyBaseline`, as written, so a duplicate can be seen.
    ///   - exempt: The keys of `countScanFalsePositives`.
    ///   - ceiling: `countCopyBaselineCeiling`.
    ///   - exemptionCeiling: `countScanFalsePositivesCeiling`.
    /// - Returns: The violations; empty when the tree and the lists agree.
    static func baselineViolations(flagged: Set<String>, baseline: [String], exempt: [String],
                                   ceiling: Int, exemptionCeiling: Int) -> [BaselineViolation] {
        var result: [BaselineViolation] = []
        var seen = Set<String>()
        for entry in baseline where !seen.insert(entry).inserted { result.append(.duplicate(entry)) }
        let listed = Set(baseline), exempted = Set(exempt)
        result += listed.intersection(exempted).sorted().map(BaselineViolation.overlap)
        result += flagged.subtracting(listed).subtracting(exempted).sorted().map(BaselineViolation.new)
        result += listed.subtracting(flagged).sorted().map(BaselineViolation.stale)
        result += exempted.subtracting(flagged).sorted().map(BaselineViolation.staleExemption)
        if baseline.count != ceiling { result.append(.ceiling(count: baseline.count, ceiling: ceiling)) }
        if exempt.count != exemptionCeiling {
            result.append(.exemptionCeiling(count: exempt.count, ceiling: exemptionCeiling))
        }
        return result
    }

    /// `violation` as the tree test reports it, with what to do about it.
    static func describe(_ violation: BaselineViolation, lines: [String: [Int]]) -> String {
        switch violation {
        case .duplicate(let entry):
            return "countCopyBaseline lists \(entry) twice. Delete one and lower countCopyBaselineCeiling."
        case .overlap(let entry):
            return "\(entry) is both baselined and exempted. It is one or the other."
        case .new(let entry):
            let at = (lines[entry] ?? []).map(String.init).joined(separator: ", ")
            return """
                New count string — a number before a countable noun prints "1 volumes", and a \
                `%lld` prints "12067" ungrouped. Route it through `CountCopy.phrase(_:one:many:)` \
                (#1374); do not add it to countCopyBaseline, which may only shrink: \(entry) (line \(at))
                """
        case .stale(let entry):
            return """
                countCopyBaseline lists an entry the scan no longer flags — fixed, re-keyed or \
                moved. Delete it and lower countCopyBaselineCeiling to match: \(entry)
                """
        case .staleExemption(let entry):
            return "countScanFalsePositives lists an entry the scan no longer flags. Delete it: \(entry)"
        case .ceiling(let count, let ceiling):
            return """
                countCopyBaseline holds \(count) entries against a ceiling of \(ceiling). The baseline \
                only shrinks: after deleting fixed entries, lower the ceiling to the new count. \
                Raising it is adding a count string the scan refuses.
                """
        case .exemptionCeiling(let count, let ceiling):
            return """
                countScanFalsePositives holds \(count) entries against its pinned \(ceiling). A new \
                one needs the evidence the others carry — the interpolation is not a count — and \
                countScanFalsePositivesCeiling raised with it.
                """
        }
    }

    /// One fixture for the baseline comparison.
    struct BaselineFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the case's name.
        let name: String
        /// What the scan flagged.
        let flagged: Set<String>
        /// The baseline as written.
        let baseline: [String]
        /// The exemptions.
        let exempt: [String]
        /// The baseline's pinned size.
        let ceiling: Int
        /// The exemptions' pinned size.
        let exemptionCeiling: Int
        /// The violations the comparison must report, in its order.
        let expected: [BaselineViolation]
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// One fixture per way the baseline can disagree with the tree, and one where it agrees.
    static let baselineFixtures: [BaselineFixture] = [
        BaselineFixture(name: "a tree matching its lists passes",
                        flagged: ["a", "b", "x"], baseline: ["a", "b"], exempt: ["x"],
                        ceiling: 2, exemptionCeiling: 1, expected: []),
        BaselineFixture(name: "a new count string is refused, not absorbed",
                        flagged: ["a", "b", "c", "x"], baseline: ["a", "b"], exempt: ["x"],
                        ceiling: 2, exemptionCeiling: 1, expected: [.new("c")]),
        BaselineFixture(name: "a new count string listed without raising the ceiling is over it",
                        flagged: ["a", "b", "c", "x"], baseline: ["a", "b", "c"], exempt: ["x"],
                        ceiling: 2, exemptionCeiling: 1, expected: [.ceiling(count: 3, ceiling: 2)]),
        BaselineFixture(name: "a fixed site left listed is stale",
                        flagged: ["a", "x"], baseline: ["a", "b"], exempt: ["x"],
                        ceiling: 2, exemptionCeiling: 1, expected: [.stale("b")]),
        BaselineFixture(name: "a deleted entry with the ceiling not lowered fails",
                        flagged: ["a", "x"], baseline: ["a"], exempt: ["x"],
                        ceiling: 2, exemptionCeiling: 1, expected: [.ceiling(count: 1, ceiling: 2)]),
        BaselineFixture(name: "an exemption the scan no longer flags is stale",
                        flagged: ["a", "b"], baseline: ["a", "b"], exempt: ["x"],
                        ceiling: 2, exemptionCeiling: 1, expected: [.staleExemption("x")]),
        BaselineFixture(name: "an entry listed twice is reported",
                        flagged: ["a", "b", "x"], baseline: ["a", "b", "a"], exempt: ["x"],
                        ceiling: 3, exemptionCeiling: 1, expected: [.duplicate("a")]),
        BaselineFixture(name: "an entry both baselined and exempted is reported",
                        flagged: ["a", "b", "x"], baseline: ["a", "b", "x"], exempt: ["x"],
                        ceiling: 3, exemptionCeiling: 1, expected: [.overlap("x")]),
        BaselineFixture(name: "a new exemption over its pinned count fails",
                        flagged: ["a", "b", "x", "y"], baseline: ["a", "b"], exempt: ["x", "y"],
                        ceiling: 2, exemptionCeiling: 1, expected: [.exemptionCeiling(count: 2, ceiling: 1)]),
    ]

    /// The comparison reports exactly what each fixture states.
    @Test("CodingStandardsAudit: the count baseline's comparison rules", arguments: baselineFixtures)
    func baselineComparisonRules(_ fixture: BaselineFixture) {
        #expect(Self.baselineViolations(flagged: fixture.flagged, baseline: fixture.baseline,
                                        exempt: fixture.exempt, ceiling: fixture.ceiling,
                                        exemptionCeiling: fixture.exemptionCeiling) == fixture.expected)
    }

    /// One fixture for the count scan: a snippet and the keys it must flag.
    struct CountScanFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the case's name.
        let name: String
        /// The Swift source the scan reads.
        let source: String
        /// The string keys the scan must flag, in source order.
        let keys: [String]
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// The count scan's rules, one fixture each.
    static let countScanFixtures: [CountScanFixture] = [
        CountScanFixture(
            name: "a %lld before a noun in a defaultValue is flagged under its key",
            source: """
                String(format: String(localized: "k %lld", defaultValue: "%lld documents"), n)
                """,
            keys: ["k %lld"]),
        CountScanFixture(
            name: "a positional %2$lld before an abbreviated noun is flagged",
            source: """
                String(localized: "k2", defaultValue: "%1$lld docs · %2$lld vols")
                """,
            keys: ["k2"]),
        CountScanFixture(
            name: "an interpolation before a noun is flagged",
            source: """
                String(localized: "k3", defaultValue: "\\(n) volumes")
                """,
            keys: ["k3"]),
        CountScanFixture(
            name: "one word between the count and the noun is still a count",
            source: """
                String(localized: "k4", defaultValue: "%1$lld source notes in %2$@.")
                """,
            keys: ["k4"]),
        CountScanFixture(
            name: "two words between them are not",
            source: """
                String(localized: "k5", defaultValue: "%lld of the volumes")
                """,
            keys: []),
        CountScanFixture(
            name: "CountCopy's %@ forms pass",
            source: """
                CountCopy.phrase(n, one: String(localized: "k6.one", defaultValue: "%@ document"),
                                 many: String(localized: "k6.many", defaultValue: "%@ documents"))
                """,
            keys: []),
        CountScanFixture(
            name: "a count before something that is not a countable noun passes",
            source: """
                String(localized: "k7", defaultValue: "%lld more")
                """,
            keys: []),
        CountScanFixture(
            name: "a singular noun inflected by hand is not the plural the scan looks for",
            source: """
                String(localized: "k8", defaultValue: "\\(n) volume\\(n == 1 ? "" : "s")")
                """,
            keys: []),
        CountScanFixture(
            name: "a bare Text interpolation is flagged under its own text",
            source: """
                Text("\\(section.subsections.count) sections")
                """,
            keys: ["\\(section.subsections.count) sections"]),
        CountScanFixture(
            name: "both branches of a ternary inside Text are read, and only the counting one flagged",
            source: """
                Text(dl > 0 ? "\\(dl)/\\(vols.count) downloaded" : "\\(vols.count) volumes")
                """,
            keys: ["\\(vols.count) volumes"]),
        CountScanFixture(
            name: "Text(verbatim:) is read too",
            source: """
                Text(verbatim: "\\(model.placedCount) documents")
                """,
            keys: ["\\(model.placedCount) documents"]),
        CountScanFixture(
            name: "SwiftUI.Text and a key-taking modifier are read",
            source: """
                SwiftUI.Text("\\(a) docs").accessibilityLabel("\\(b) links")
                """,
            keys: ["\\(a) docs", "\\(b) links"]),
        CountScanFixture(
            name: "another view's initialiser is read",
            source: """
                Label("\\(n) volumes", systemImage: "books.vertical")
                """,
            keys: ["\\(n) volumes"]),
        CountScanFixture(
            name: "a free function named like a modifier is not a modifier",
            source: """
                help("\\(n) volumes")
                """,
            keys: []),
        CountScanFixture(
            name: "a view whose name only ends in Text is not Text",
            source: """
                RichText("\\(n) volumes")
                """,
            keys: []),
        CountScanFixture(
            name: "a log line is not user-facing copy",
            source: """
                print("[X] Loaded \\(n) documents")
                """,
            keys: []),
        CountScanFixture(
            name: "a defaultValue with no string key is keyed by its own text",
            source: """
                String(localized: keyName, defaultValue: "\\(n) docs")
                """,
            keys: ["\\(n) docs"]),
        CountScanFixture(
            name: "a raw string's interpolation is \\#( and its \\( is text",
            source: """
                String(localized: "k9", defaultValue: #"\\#(n) documents"#)
                String(localized: "k10", defaultValue: #"\\(n) documents"#)
                """,
            keys: ["k9"]),
        CountScanFixture(
            name: "a multi-line defaultValue is read whole",
            source: #"""
                String(localized: "k11", defaultValue: """
                    Across the era, \(n)
                    documents.
                    """)
                """#,
            keys: ["k11"]),
        CountScanFixture(
            name: "a count before others is flagged — the gloss's \"and 1 others\"",
            source: """
                String(localized: "k12 %lld", defaultValue: "and %lld others")
                """,
            keys: ["k12 %lld"]),
        CountScanFixture(
            name: "a (s)-hedged noun is flagged, after one word too",
            source: """
                String(localized: "k13", defaultValue: "the %lld document(s) in this scope")
                String(localized: "k14", defaultValue: "%lld cross-reference(s) are excluded")
                String(localized: "k15", defaultValue: "shorter than %lld long word(s)")
                """,
            keys: ["k13", "k14", "k15"]),
        CountScanFixture(
            name: "a count before a runtime %@ noun is flagged — the ranking caption",
            source: """
                String(localized: "k16", defaultValue: "draw on %3$lld %4$@.")
                """,
            keys: ["k16"]),
        CountScanFixture(
            name: "a count before of them is flagged",
            source: """
                String(localized: "k17", defaultValue: "Volumes covering %1$@ — %2$lld of them — draw")
                """,
            keys: ["k17"]),
        CountScanFixture(
            name: "an interpolation before another interpolation is prose, not a count",
            source: """
                Text("\\(prefix) \\(question)")
                """,
            keys: []),
    ]

    /// The count scan flags exactly what each fixture states, so a clean tree means a clean tree
    /// rather than a scan that stopped reading.
    @Test("CodingStandardsAudit: the count scan's rules", arguments: countScanFixtures)
    func countScanRules(_ fixture: CountScanFixture) {
        let lexed = LexedSource(fixture.source)
        let keys = lexed.literals
            .filter { CopyScan.isInScope($0) && CopyScan.countsBeforeANoun($0) }
            .map { lexed.key(of: $0) }
        #expect(keys == fixture.keys)
    }

    // MARK: - Years never group

    /// No `defaultValue:` or key-taking literal interpolates a bare year.
    ///
    /// Measured on `v2` before #1382 it found exactly its five sites — the Person Analytics caption
    /// (`yearRange.lowerBound`/`upperBound`), the two Series Production VoiceOver values
    /// (`point.coverageEndYear`, `point.printYear`, `step.year`) and the two `startYear`s that were
    /// already Strings — so it carries no allowlist: a String held under a year's name is wrapped
    /// too, because the scan reads the spelling and not the type. It cannot see a year held under
    /// another name, which is why `PersonAnalyticsCopy.rankingSubtitle` has an emitter test as well.
    @Test("CodingStandardsAudit: no user-facing literal interpolates a bare year")
    func yearsAreNeverGrouped() throws {
        let files = try Self.lexedAppSources()
        var interpolations = 0
        var sites: [String] = []
        for (path, lexed) in files {
            for literal in lexed.literals where CopyScan.isInScope(literal) {
                interpolations += literal.segments.filter {
                    if case .interpolation = $0 { return true } else { return false }
                }.count
                for code in CopyScan.bareYears(literal) {
                    sites.append("\(path):\(literal.line) \\(\(code))")
                }
            }
        }
        #expect(files.count >= 450, "Read only \(files.count) Swift file(s): the scan is broken, not the tree clean.")
        // 889 interpolations in scope when measured; the floor sits below it.
        #expect(interpolations >= 750, """
            Only \(interpolations) interpolation(s) in scope: the scan is broken, not the tree clean.
            """)
        #expect(sites.isEmpty, """
            A year interpolated bare into a localized string prints grouped ("1,940"). Wrap it in \
            String(_:) or give it a format (#1382):
            \(sites.joined(separator: "\n"))
            """)
    }

    /// One fixture for the year scan: a snippet and the interpolations it must flag.
    struct YearScanFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the case's name.
        let name: String
        /// The Swift source the scan reads.
        let source: String
        /// The interpolated code the scan must flag, in source order.
        let flagged: [String]
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// The year scan's rules, one fixture each.
    static let yearScanFixtures: [YearScanFixture] = [
        YearScanFixture(
            name: "the Person Analytics caption as v2 wrote it",
            source: """
                Text(String(localized: "c", defaultValue: "…documents, \\(yearRange.lowerBound)–\\(yearRange.upperBound). Tap…"))
                """,
            flagged: ["yearRange.lowerBound", "yearRange.upperBound"]),
        YearScanFixture(
            name: "a member ending Year, and a bare year",
            source: """
                String(localized: "d", defaultValue: "Covers through \\(point.coverageEndYear), from \\(year)")
                """,
            flagged: ["point.coverageEndYear", "year"]),
        YearScanFixture(
            name: "an optional chain is still a bare path",
            source: """
                String(localized: "e", defaultValue: "From \\(step?.year)")
                """,
            flagged: ["step?.year"]),
        YearScanFixture(
            name: "a year wrapped in String(_:) passes",
            source: """
                String(localized: "f", defaultValue: "\\(String(startYear))–present")
                """,
            flagged: []),
        YearScanFixture(
            name: "a year given a format passes",
            source: """
                String(localized: "g", defaultValue: "From \\(startYear, format: plain) to \\(endYear.formatted(.number.grouping(.never)))")
                """,
            flagged: []),
        YearScanFixture(
            name: "a duration named for years is a count, not a year",
            source: """
                String(localized: "h", defaultValue: "lag \\(point.lagYears)")
                """,
            flagged: []),
        YearScanFixture(
            name: "a bare Text interpolation groups too",
            source: """
                Text("Since \\(year)")
                """,
            flagged: ["year"]),
        YearScanFixture(
            name: "Text(verbatim:) does not format, so it passes",
            source: """
                Text(verbatim: "\\(year)")
                """,
            flagged: []),
        YearScanFixture(
            name: "a plain Swift string does not format, so it passes",
            source: """
                let span = "\\(startYear)–\\(endYear)"
                """,
            flagged: []),
    ]

    /// The year scan flags exactly what each fixture states.
    @Test("CodingStandardsAudit: the year scan's rules", arguments: yearScanFixtures)
    func yearScanRules(_ fixture: YearScanFixture) {
        let lexed = LexedSource(fixture.source)
        let flagged = lexed.literals.flatMap { CopyScan.bareYears($0) }
        #expect(flagged == fixture.flagged)
    }

    // MARK: - Parentheses hug their text

    /// No `defaultValue:` or key-taking literal puts a space just inside a parenthesis.
    ///
    /// "(of 25+ )" shipped in the co-mention network's footer (#1385); A4 took the space out, so
    /// on `v2` this scan finds nothing and needs no allowlist. Only literal text is read: the
    /// parentheses of an interpolation are code.
    @Test("CodingStandardsAudit: no user-facing literal puts a space just inside a parenthesis")
    func parenthesesHugTheirText() throws {
        let files = try Self.lexedAppSources()
        var withParentheses = 0
        var sites: [String] = []
        for (path, lexed) in files {
            for literal in lexed.literals where CopyScan.isInScope(literal) {
                if literal.segments.contains(where: {
                    if case .text(let text) = $0 { return text.contains("(") } else { return false }
                }) { withParentheses += 1 }
                if CopyScan.spacedParentheses(literal) { sites.append("\(path):\(literal.line)") }
            }
        }
        // 209 in-scope literals with a parenthesis when measured; the floor sits below it.
        #expect(withParentheses >= 180, """
            Only \(withParentheses) in-scope literal(s) carry a parenthesis: the scan is broken, \
            not the tree clean.
            """)
        #expect(sites.isEmpty, """
            A space just inside a parenthesis — "(of 25+ )" (#1385): \(sites.joined(separator: ", "))
            """)
    }

    /// One fixture for the parenthesis scan.
    struct ParenthesisScanFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the case's name.
        let name: String
        /// The Swift source the scan reads.
        let source: String
        /// Whether the scan must flag it.
        let flagged: Bool
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// The parenthesis scan's rules, one fixture each.
    static let parenthesisScanFixtures: [ParenthesisScanFixture] = [
        ParenthesisScanFixture(
            name: "#1385's footer as it shipped",
            source: """
                String(localized: "p", defaultValue: "Showing the top \\(n) co-mentioned people (of \\(total)+ ) by shared-document count.")
                """,
            flagged: true),
        ParenthesisScanFixture(
            name: "#1385's footer as A4 fixed it",
            source: """
                String(localized: "p", defaultValue: "Showing the top \\(n) co-mentioned people (of \\(total)+) by shared-document count.")
                """,
            flagged: false),
        ParenthesisScanFixture(
            name: "a space after an opening parenthesis",
            source: """
                Text("Documents ( all)")
                """,
            flagged: true),
        ParenthesisScanFixture(
            name: "an interpolation's own parentheses are code, not text",
            source: """
                String(localized: "q", defaultValue: "\\(f( x )) documents")
                """,
            flagged: false),
        ParenthesisScanFixture(
            name: "a literal outside any user-facing call is not read",
            source: """
                print("[X] ( debug )")
                """,
            flagged: false),
    ]

    /// The parenthesis scan flags exactly what each fixture states.
    @Test("CodingStandardsAudit: the parenthesis scan's rules", arguments: parenthesisScanFixtures)
    func parenthesisScanRules(_ fixture: ParenthesisScanFixture) {
        let lexed = LexedSource(fixture.source)
        #expect(lexed.literals.contains { CopyScan.spacedParentheses($0) } == fixture.flagged)
    }

    // MARK: - The rules

    /// The three scans' rules over one lexed literal.
    enum CopyScan {

        /// SwiftUI initialisers whose string-literal argument is a `LocalizedStringKey`, which
        /// formats an interpolated number for the locale and never singularises the noun after it.
        static let keyTakingViews: Set<String> = [
            "Text", "Label", "Button", "Section", "Toggle", "LabeledContent", "Link", "Menu",
            "Picker", "NavigationLink",
        ]

        /// SwiftUI modifiers that take a `LocalizedStringKey` the same way.
        static let keyTakingModifiers: Set<String> = [
            "navigationTitle", "navigationSubtitle", "accessibilityLabel", "accessibilityValue",
            "accessibilityHint", "help",
        ]

        /// Plural nouns a count can stand before, each with a singular a count of one needs.
        /// Invariant nouns ("series", "subseries") are left out: they cannot disagree with one.
        static let countNouns: [String] = [
            "documents", "docs", "volumes", "vols", "notes", "references", "cross-references",
            "matches", "results", "collections", "tags", "terms", "summaries", "citations",
            "occurrences", "targets", "footnotes", "persons", "people", "mentions", "searches",
            "units", "scopes", "errors", "links", "records", "sessions", "lines", "rows",
            "regions", "repositories", "quotations", "pairs", "words", "entries", "highlights",
            "candidates", "neighbors", "topics", "lots", "sections", "items", "pages", "subjects",
            "files", "folders", "boxes", "excerpts", "headings", "projects", "visits", "plans",
            "chapters", "compilations", "editors", "clusters", "partners", "spellings", "values",
            "fields", "events", "days", "years", "times", "hours", "minutes", "seconds",
            "characters", "queries", "passages",
            // Review, round 1: each found a live count the first list passed — "and 1 others" on
            // every two-claimant class code, "1 other definitions", "all 1 destinations".
            "others", "places", "definitions", "images", "destinations", "origins", "nodes", "eras",
        ]

        /// Stands in for an interpolation when a literal is matched as text.
        static let interpolationMark = "\u{E000}"

        /// A count placeholder, then what makes it a count: at most one lower-case word and a
        /// countable noun or a `(s)`-hedged word; a runtime `%N$@` noun; or `of them`.
        static let countPattern: NSRegularExpression = {
            let nouns = countNouns.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            return try! NSRegularExpression(pattern:
                #"(?:%(?:\d+\$)?(?:lld|ld|d)|\#(interpolationMark))"#
                + #"(?:(?:\s+[a-z][a-z-]*)?\s+(?:(?:\#(nouns))\b|[a-z][a-z-]*\(s\))"#
                + #"|\s+%(?:\d+\$)?@|\s+of\s+them\b)"#)
        }()

        /// An interpolation that is an identifier path and nothing else — `year`, `a.b?.year`.
        static let barePath: NSRegularExpression = {
            try! NSRegularExpression(pattern: #"^[A-Za-z_][A-Za-z0-9_]*(?:\??\.[A-Za-z_][A-Za-z0-9_]*)*$"#)
        }()

        /// A path component naming a year or a range's bound.
        static let yearName: NSRegularExpression = {
            try! NSRegularExpression(pattern: #"(?:year|Year|lowerBound|upperBound)$"#)
        }()

        /// A space or tab just inside a parenthesis.
        static let spacedParenthesis: NSRegularExpression = {
            try! NSRegularExpression(pattern: #"\([ \t]|[ \t]\)"#)
        }()

        /// Whether `callee` is a key-taking SwiftUI initialiser (`Text`, `SwiftUI.Text`) or modifier
        /// (`.help`, `x.accessibilityLabel`) — a modifier only as a member call, a view only by its
        /// own name.
        static func isKeyTakingCall(_ callee: String?) -> Bool {
            guard let callee, !callee.isEmpty else { return false }
            let parts = callee.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard let name = parts.last else { return false }
            if keyTakingViews.contains(name) {
                return parts.count == 1 || (parts.count == 2 && parts[0] == "SwiftUI")
            }
            return parts.count >= 2 && keyTakingModifiers.contains(name)
        }

        /// Whether the scans read `literal` at all: a `defaultValue:`, or a key-taking call's own.
        static func isInScope(_ literal: LexedSource.Literal) -> Bool {
            literal.isDefaultValue || isKeyTakingCall(literal.callee)
        }

        /// `literal`'s text with every interpolation replaced by `interpolationMark`.
        static func placeholderText(_ literal: LexedSource.Literal) -> String {
            literal.segments.map { segment -> String in
                switch segment {
                case .text(let text): return text
                case .interpolation: return interpolationMark
                }
            }.joined()
        }

        /// Whether an in-scope `literal` places a count before a countable noun.
        static func countsBeforeANoun(_ literal: LexedSource.Literal) -> Bool {
            guard isInScope(literal) else { return false }
            let text = placeholderText(literal)
            return countPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }

        /// The bare year paths an in-scope `literal` interpolates. `Text(verbatim:)` is exempt:
        /// it does not format what it interpolates.
        static func bareYears(_ literal: LexedSource.Literal) -> [String] {
            guard literal.isDefaultValue
                    || (isKeyTakingCall(literal.callee) && !literal.calleeIsVerbatim) else { return [] }
            var found: [String] = []
            for case .interpolation(let raw) in literal.segments {
                let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard barePath.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil,
                      let last = code.components(separatedBy: ".").last,
                      yearName.firstMatch(in: last, range: NSRange(last.startIndex..., in: last)) != nil
                else { continue }
                found.append(code)
            }
            return found
        }

        /// Whether an in-scope `literal`'s text puts a space just inside a parenthesis.
        static func spacedParentheses(_ literal: LexedSource.Literal) -> Bool {
            guard isInScope(literal) else { return false }
            return literal.segments.contains { segment in
                guard case .text(let text) = segment else { return false }
                return spacedParenthesis.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
            }
        }
    }

    // MARK: - The baseline

    /// Entries in `countCopyBaseline`. Equal to its size, so a PR that adds an entry must also
    /// raise this, in plain sight. Lower it with every entry deleted.
    static let countCopyBaselineCeiling = 302

    /// Entries in `countScanFalsePositives`, pinned like the baseline's ceiling.
    static let countScanFalsePositivesCeiling = 2

    /// The two flagged literals whose interpolation is not a count, each with the reason.
    static let countScanFalsePositives: [String: String] = [
        "Search/QueryInspectorView.swift | search.empty.oneEmpty":
            #"the interpolation is a search term and "matches" is its verb: "\(text) matches no document""#,
        "Browser/SubjectIndexView.swift | subjects.detail.browseArea":
            #"the interpolation is a topic area's name: "All \(subject.subcategory) topics""#,
    ]

    /// Count literals the tree held when the scan was written, less the ones #1374, #1382 and
    /// #1422 name, which were routed through `CountCopy` in the same change. Keyed by file (under
    /// `FRUSExplorer/`) and string key — a bare `Text`'s key is its own text — never by line.
    ///
    /// **This list only shrinks.** Route an entry through `CountCopy`, delete it here and lower
    /// `countCopyBaselineCeiling`. Never add one for a new string. The one exception is the rule
    /// itself learning to see more: review, round 1 widened it and listed three literals it found
    /// that need new copy rather than a second form, each with its reason beside it, while fixing
    /// the other 19 it found and five listed entries — so the ceiling still went down, 311 to 309.
    /// Merging #1364 took it to 307: that change moved two listed Subseries-tile captions out of
    /// `CorpusView` and added two more, and all four were routed rather than re-listed. An iPad pass
    /// over the fixed screens took it to 303: the Archival all-units button and sheet header, and the
    /// Archives Visit coverage lines, sat beside strings the round had fixed. #1467 took it to 302:
    /// the Archival network's partner sentence was rewritten as four `CountCopy` sentences.
    static let countCopyBaseline: [String] = [
        #"Analytics/AnalyticsView.swift | analytics.chart.source.legend.a11y %@ %lld"#,
        #"Analytics/AnalyticsView.swift | analytics.compare.cap %lld"#,
        #"Analytics/AnalyticsView.swift | analytics.dispersion.volumes"#,
        #"Analytics/AnalyticsView.swift | analytics.figure.legend.docs"#,
        #"Analytics/AnalyticsView.swift | analytics.figure.legend.occurrences"#,
        #"Analytics/ArchivalAnalyticsAxes.swift | archival.measure.detail.documents %lld"#,
        #"Analytics/ArchivalAnalyticsAxes.swift | archival.measure.detail.volumes %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.flows.classes %lld %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.flows.coverage %lld %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.flows.sameUnit %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.flows.unprinted.claim %lld %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.flows.unprinted.scope %lld %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.library %lld %lld %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.network.scope %lld %lld %lld"#,
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.scope %lld %lld"#,
        // Listed by review, round 1, when the rule learned `eras`: with one era the sentence's
        // claim — the eras "run contiguously … so an interior gap is a real gap" — has nothing to
        // say, so a singular needs new copy rather than a second form. The count is the timeline's
        // buckets, one per subseries at most, so it never reaches the grouping threshold.
        #"Analytics/ArchivalAnalyticsExport.swift | archival.export.caveat.timeline %lld"#,
        #"Analytics/ArchivalAnalyticsView.swift | archival.library.collections.caption %lld %lld"#,
        #"Analytics/ArchivalAnalyticsView.swift | archival.library.collections.count %lld"#,
        #"Analytics/ArchivalAnalyticsView.swift | archival.library.composition.a11y %lld %@"#,
        #"Analytics/ArchivalAnalyticsView.swift | archival.library.footer %lld %lld"#,
        #"Analytics/ArchivalAnalyticsView.swift | archival.library.footer.detail %lld %lld"#,
        #"Analytics/ArchivalAnalyticsView.swift | archival.library.intro %lld %lld"#,
        #"Analytics/ArchivalFlowsData.swift | archival.flows.remainder %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.block.a11y %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.caption.incoming %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.caption.outgoing %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.caption.unprinted.incoming %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.caption.unprinted.outgoing %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.card.detail.incoming %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.card.detail.outgoing %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.caveats.body.v3 %lld %lld %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.caveats.unprinted.scope.v2 %lld %lld %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.focusBlock %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.none.detail %@ %lld %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.picker.caption %@ %lld"#,
        #"Analytics/ArchivalFlowsView.swift | archival.flows.top.a11y %@ %@ %lld"#,
        #"Analytics/ArchivalNetworkView.swift | archival.network.dock.grain %lld"#,
        // Listed by review, round 1, when the rule learned `nodes`: the verb "are drawn" agrees
        // with the FIRST count — the drawn nodes, six per custodian at most — and not the one
        // before the noun, so a singular is a sentence of its own. The second count, the nodes
        // above the threshold, is not capped and prints ungrouped past 999.
        #"Analytics/ArchivalNetworkView.swift | archival.network.dock.summary.v2 %lld %lld %@"#,
        #"Analytics/ArchivalNetworkView.swift | archival.network.group.detail %lld %lld %@ %@ %lld"#,
        #"Analytics/ArchivalNetworkView.swift | archival.network.picker.caption %@ %lld"#,
        #"Analytics/CrossReferenceAnalyticsView.swift | crossRefAnalytics.axis.inDegreeValue"#,
        #"Analytics/CrossReferenceAnalyticsView.swift | crossRefAnalytics.excludedBrokenCaption"#,
        #"Analytics/CrossReferenceAnalyticsView.swift | crossRefAnalytics.export.caveat.matrixLimit %lld"#,
        #"Analytics/CrossReferenceAnalyticsView.swift | crossRefAnalytics.matrix.cell.axLabel"#,
        #"Analytics/CrossReferenceAnalyticsView.swift | crossRefAnalytics.matrix.cell.help"#,
        #"Analytics/CrossReferenceAnalyticsView.swift | crossRefAnalytics.matrix.subtitle"#,
        #"Analytics/PersonAnalyticsView.swift | personAnalytics.axis.mentionsValue"#,
        #"Analytics/PersonAnalyticsView.swift | personAnalytics.comparison.empty"#,
        #"Analytics/PersonAnalyticsView.swift | personAnalytics.search.cap"#,
        #"Analytics/PersonCoMentionGraphView.swift | personCoMention.cap.all"#,
        #"Analytics/PersonCoMentionGraphView.swift | personCoMention.cap.disclosed"#,
        #"Analytics/PersonCoMentionGraphView.swift | personCoMention.node.a11yValue"#,
        #"Analytics/WordCloud/WordCloudBench.swift | settings.wordcloud.bench.keeps %lld %lld"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.export.caveat.keyness %lld %lld %@"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.export.caveat.keyness.complete %lld"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.export.caveat.keyness.cutoff %lld"#,
        // Listed by review, round 1, when the rule learned `(s)` hedges: two counts share one
        // verb ("… and %lld from your list … were removed"), and the hedge already reads right at
        // one; both count a reader's own stop lists, which run to tens of words, not thousands.
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.export.caveat.stopLists %lld %lld %@"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.filter.showHidden %lld"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.keyness.caveat.complete %lld"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.keyness.caveat.reference %lld"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.keyness.unavailable.floor %lld"#,
        #"Analytics/WordCloud/WordCloudView.swift | wordcloud.occurrences %lld"#,
        #"App/IndexingBannerView.swift | indexing.banner.meta.docs"#,
        #"App/IndexingBannerView.swift | indexing.banner.meta.docsAndNotes"#,
        #"App/IndexingBannerView.swift | indexing.banner.meta.links"#,
        #"App/IndexingBannerView.swift | indexing.banner.meta.persons"#,
        #"App/IndexingContextCard.swift | indexing.context.crossRefs"#,
        #"App/IndexingContextCard.swift | indexing.context.series"#,
        #"App/IndexingContextCard.swift | indexing.context.series.withDownloads"#,
        #"App/IndexingSummaryCard.swift | indexing.summary.docs"#,
        #"App/IndexingSummaryCard.swift | indexing.summary.links"#,
        #"App/IndexingSummaryCard.swift | indexing.summary.persons"#,
        #"App/IndexingSummaryCard.swift | indexing.summary.queue.title"#,
        #"App/MacCorpusBrowserWindow.swift | browser.scopes.capture.prefill"#,
        #"App/MacSearchViewModel.swift | search.filter.tags.count"#,
        #"App/MacSearchViewModel.swift | search.filter.years.count %lld"#,
        #"App/SearchSheet.swift | Showing \(loaded) of \($0) matches"#,
        #"App/SearchSheet.swift | Showing the first \(loaded) matches — the total is unavailable"#,
        #"App/SearchSheet.swift | search.cap.tooltip"#,
        #"App/SearchSheet.swift | search.cap.tooltip.unknownTotal"#,
        #"App/SupportingViews.swift | document.share.zotero.result %lld %lld"#,
        #"App/SupportingViews.swift | indexing.queue.mac.docs"#,
        #"App/SupportingViews.swift | indexing.queue.mac.finalizing.detail"#,
        #"Browser/AdministrationIndexView.swift | browser.administrations.accessory"#,
        #"Browser/AdministrationIndexView.swift | browser.administrations.accessory.noShare"#,
        #"Browser/AdministrationIndexView.swift | browser.administrations.coverage"#,
        #"Browser/AdministrationIndexView.swift | browser.administrations.drill.caption"#,
        #"Browser/AdministrationIndexView.swift | browser.administrations.row.a11y"#,
        #"Browser/AdministrationIndexView.swift | browser.administrations.row.docs"#,
        #"Browser/AdministrationIndexView.swift | browser.administrations.row.volumes"#,
        #"Browser/ArchivesBrowseView.swift | browser.archives.accessory"#,
        #"Browser/ArchivesBrowseView.swift | browser.archives.accessory.plain"#,
        #"Browser/ArchivesBrowseView.swift | browser.archives.classes.count"#,
        #"Browser/ArchivesBrowseView.swift | browser.archives.coverage"#,
        #"Browser/ArchivesBrowseView.swift | browser.archives.drill.caption"#,
        #"Browser/ArchivesClassAxis.swift | browser.archives.accessory"#,
        #"Browser/ArchivesClassAxis.swift | browser.archives.accessory.plain"#,
        #"Browser/ClustersBrowseView.swift | browser.clusters.caption"#,
        #"Browser/ClustersBrowseView.swift | browser.clusters.paging"#,
        #"Browser/ClustersBrowseView.swift | browser.clusters.row.a11y"#,
        #"Browser/ClustersBrowseView.swift | browser.clusters.row.count"#,
        #"Browser/ClustersBrowseView.swift | browser.clusters.saved.truncated"#,
        #"Browser/CorpusBrowseView.swift | browser.corpora.row.a11y"#,
        #"Browser/CorpusBrowseView.swift | browser.corpora.row.count"#,
        #"Browser/CorpusBrowseView.swift | browser.corpora.truncated"#,
        #"Browser/CorpusView.swift | browser.corpus.search.prompt"#,
        #"Browser/EditorIndexView.swift | browser.editors.coverage"#,
        #"Browser/EditorIndexView.swift | browser.editors.variants"#,
        #"Browser/PersonIndexView.swift | people.row.mentionCount.a11y %lld"#,
        #"Browser/PersonIndexView.swift | people.row.volumeCount"#,
        #"Browser/ScopeBrowseView.swift | browser.scopes.drill.caption"#,
        #"Browser/ScopeBrowseView.swift | browser.scopes.row.a11y"#,
        #"Browser/ScopeBrowseView.swift | browser.scopes.row.caption"#,
        #"Browser/ScopeBrowseView.swift | browser.scopes.row.caption.plain"#,
        #"Browser/SubjectIndexView.swift | subjects.detail.volumes.all"#,
        #"Browser/SubjectIndexView.swift | subjects.index.coverage.v2 %lld %lld"#,
        #"Browser/SubseriesDirectoryView.swift | \(documentCount) docs"#,
        #"Browser/SubseriesDirectoryView.swift | browser.corpus.subseries.a11y"#,
        #"Browser/SubseriesView.swift | \(documentCount) docs"#,
        #"Browser/SubseriesView.swift | indexing.capsule.meta.persons"#,
        #"Browser/VolumeCatalogueView.swift | browser.catalogue.coverage"#,
        #"Browser/VolumeListView.swift | browser.scopes.capture.prefill"#,
        #"Browser/VolumeSourcesView.swift | browser.sources.archivalNeighbors.count.accessibility %lld"#,
        #"Browser/VolumeSourcesView.swift | browser.sources.collection"#,
        #"Browser/VolumeSourcesView.swift | browser.sources.crossVolume"#,
        #"Browser/VolumeSubjectsView.swift | browser.volume.subjectVolumes.archival.footer %lld"#,
        #"Browser/VolumeSubjectsView.swift | browser.volume.subjectVolumes.header.all.many %lld"#,
        #"Browser/VolumeSubjectsView.swift | browser.volume.subjectVolumes.header.many %lld"#,
        #"Chronology/ChronologyViewModel.swift | chronology.overflow.chip.a11y.many"#,
        #"Chronology/ChronologyViewModel.swift | chronology.overflow.chip.many"#,
        #"Chronology/ChronologyViewModel.swift | chronology.spanning.chip.a11y.many"#,
        #"Chronology/ChronologyViewModel.swift | chronology.spanning.chip.many"#,
        #"Citation/CitationLookupView.swift | citation.batch.ambiguous %lld"#,
        #"Citation/CitationLookupView.swift | citation.batch.summary %lld %lld %lld %lld"#,
        #"Citation/CitationLookupView.swift | citation.results.count.a11y"#,
        #"Collections/CollectionAddDocumentsSheet.swift | collection.addDocs.addedToast %lld"#,
        #"Collections/CollectionAddDocumentsSheet.swift | collection.addDocs.citations.topOf"#,
        #"Collections/CollectionEntryInspector.swift | collection.inspector.crossRef.many"#,
        #"Collections/CollectionEntryInspector.swift | collection.inspector.highlight.many"#,
        #"Collections/CollectionEntryRows.swift | collection.entry.chip.notes.other %lld"#,
        #"Collections/CollectionEntryRows.swift | collection.section.delete.confirm.message %lld"#,
        #"Collections/CollectionExportSheet.swift | export.zotero.result %lld %lld"#,
        #"Collections/CollectionPreviewView.swift | collection.preview.capNotice"#,
        #"CrossReference/CrossReferenceGraphView.swift | graph.banner.undownloaded.v2 %lld %lld"#,
        #"CrossReference/CrossReferenceGraphView.swift | graph.edge.refCount %lld"#,
        #"CrossReference/CrossReferenceGraphView.swift | graph.node.cluster.docsLabel %lld"#,
        #"CrossReference/CrossReferenceGraphView.swift | graph.node.dateCluster.label %lld %@"#,
        #"CrossReference/CrossReferenceGraphViewModel.swift | graph.a11y.clusterInbound %lld %@"#,
        #"CrossReference/CrossReferenceGraphViewModel.swift | graph.a11y.clusterOutbound %lld %@"#,
        #"CrossReference/CrossReferenceGraphViewModel.swift | graph.a11y.dateCluster %lld %@"#,
        #"CrossReference/ReferenceListPanel.swift | graph.edge.refCount %lld"#,
        #"DocumentView/DocumentChangeReviewSheet.swift | document.review.other.collections %lld"#,
        #"DocumentView/DocumentChangeReviewSheet.swift | document.review.other.notes %lld"#,
        #"DocumentView/DocumentChangeReviewSheet.swift | document.review.other.summaries %lld"#,
        #"DocumentView/DocumentChangeReviewSheet.swift | document.review.other.tags %lld"#,
        #"DocumentView/DocumentChangeReviewSheet.swift | document.review.search.ambiguous %lld"#,
        #"DocumentView/DocumentView.swift | \(notes.count) notes from other projects"#,
        #"DocumentView/DocumentView.swift | \(notes.count) research notes from other projects"#,
        #"DocumentView/DocumentView.swift | document.share.zotero.result %lld %lld"#,
        #"Export/ExcerptVerifier.swift | excerpt.verify.failures.many %lld"#,
        #"Export/ExcerptVerifier.swift | excerpt.verify.vanished.many %lld"#,
        #"Export/QueryMethodAppendix.swift | appendix.caveat.floor.many %lld"#,
        #"Export/QueryMethodAppendix.swift | appendix.caveat.semantic.many %lld"#,
        #"Export/QueryMethodAppendix.swift | appendix.caveat.unrecorded.many %lld"#,
        #"Export/QueryMethodAppendix.swift | appendix.line.indexed %lld"#,
        #"Export/QueryMethodAppendix.swift | appendix.line.results %@"#,
        #"Export/ResearchDataExportView.swift | settings.export.includeSummaries.footer"#,
        #"History/HistoryView.swift | history.exports.documentCount"#,
        #"History/HistoryView.swift | history.searches.resultCount"#,
        #"Models/ResearchSessionsSummary.swift | settings.sessions.count.atLeast.many %lld"#,
        #"Models/ResearchSessionsSummary.swift | settings.sessions.count.many %lld"#,
        #"Models/ResearchSessionsSummary.swift | settings.sessions.events.many %lld"#,
        #"Models/WorkingCorpusResolver.swift | workingCorpus.coverage %lld %lld"#,
        #"ProjectContext/GlobalContextView.swift | global.context.summary.totalDocs.a11y"#,
        #"ProjectContext/ProjectFocusSubjectsEditor.swift | project.focus.volumeCount.other"#,
        #"ProjectContext/ProjectHomeView.swift | project.collections.manage.docCount.other"#,
        #"ProjectContext/ProjectHomeView.swift | project.home.search.results"#,
        #"ProjectContext/ProjectHomeView.swift | project.reach.caption %lld %lld"#,
        #"ProjectContext/ProjectHomeView.swift | project.reach.volumeDetail %lld %lld"#,
        #"ProjectContext/SessionLogView.swift | sessionLog.documents.many %lld"#,
        #"ProjectContext/SessionLogView.swift | sessionLog.results.many %lld"#,
        #"RelatedDocuments/RelatedDocumentsView.swift | related.offIndex.caption %lld %lld"#,
        #"RelatedDocuments/RelatedDocumentsView.swift | related.offIndex.caption.capped %lld %lld"#,
        #"RelatedDocuments/RelatedDocumentsView.swift | related.offIndex.moreVolumes %lld"#,
        #"RelatedDocuments/RelatedDocumentsView.swift | related.offIndex.volumeCount %lld"#,
        #"RelatedDocuments/RelatedDocumentsView.swift | related.poolCut %lld %lld"#,
        #"Research/ResearchView.swift | research.row.noteCount %lld"#,
        #"Research/ResearchView.swift | research.row.summaries %lld"#,
        #"Search/CollocationView.swift | search.collocation.caveat.bounded.v2 %lld %lld"#,
        #"Search/CollocationView.swift | search.collocation.caveat.perDocument %lld"#,
        #"Search/CollocationView.swift | search.collocation.caveat.scope.v2 %lld %lld"#,
        #"Search/CollocationView.swift | search.collocation.caveat.unpriced %lld"#,
        #"Search/CollocationView.swift | search.collocation.unavailable.floor %lld"#,
        #"Search/CollocationView.swift | search.collocation.window %lld"#,
        #"Search/ConcordanceView.swift | search.kwic.omitted"#,
        #"Search/ConcordanceView.swift | search.kwic.unaligned"#,
        #"Search/FacetPanelView.swift | facets.bound"#,
        #"Search/FacetPanelView.swift | facets.filter.prompt"#,
        #"Search/FacetPanelView.swift | facets.preamble"#,
        #"Search/FacetPanelView.swift | facets.provenance.coverage"#,
        #"Search/FacetPanelView.swift | facets.provenance.openProfile.detail %lld"#,
        #"Search/FacetPanelView.swift | facets.subjects.coverage"#,
        #"Search/FacetPanelView.swift | facets.undated"#,
        #"Search/QueryInspectorView.swift | search.empty.denominator"#,
        #"Search/QueryInspectorView.swift | search.inspector.corpusOccurrences"#,
        #"Search/QueryInspectorView.swift | search.inspector.denominator"#,
        #"Search/ResultSetScope.swift | search.kwic.count.paged %@ %lld"#,
        #"Search/SearchFilterView.swift | search.projectscope.focus.manual.other"#,
        #"Search/SearchFilterView.swift | search.projectscope.focus.subjects.other"#,
        #"Search/SearchFilterView.swift | search.projectscope.footer.history.other"#,
        #"Search/SearchFilterView.swift | search.scope.custom.indexed %lld %lld"#,
        #"Search/SearchFilterView.swift | search.scope.volumeCount %lld"#,
        #"Search/SearchFilterView.swift | search.subject.facet.reach %lld"#,
        #"Search/SearchFilterView.swift | search.usertags.a11y"#,
        #"Search/SearchModels.swift | settings.search.snippet.nLines %lld"#,
        #"Search/SearchScopeSignature.swift | appendix.scope.documents %lld"#,
        #"Search/SearchScopeSignature.swift | appendix.scope.excludedDocuments %lld"#,
        #"Search/SearchScopeSignature.swift | appendix.scope.subjectTags %lld"#,
        #"Search/SearchScopeSignature.swift | appendix.scope.volumes %lld"#,
        #"Search/SearchView.swift | search.volumeScope.multiple %lld"#,
        #"Search/SearchViewModel.swift | search.narrowing.tags"#,
        #"Search/SearchViewModel.swift | search.narrowing.volumes"#,
        #"Search/SearchViewModel.swift | search.narrowing.years %lld"#,
        #"Search/SemanticMeaningModeViews.swift | search.meaning.strip.filtered %lld"#,
        #"Search/SemanticMeaningModeViews.swift | search.semantic.empty.warming %lld"#,
        #"Search/SemanticMeaningModeViews.swift | search.semantic.results.unscored %lld %lld"#,
        #"Search/SemanticSearchFallbackView.swift | search.semantic.empty.warming %lld"#,
        #"Search/SemanticSearchFallbackView.swift | search.semantic.results.unscored %lld %lld"#,
        #"Semantic/Map/SemanticMapExport.swift | semanticMap.export.caveat.corpus.whole %lld"#,
        #"Semantic/Map/SemanticMapExport.swift | semanticMap.export.caveat.frame.span %lld %lld"#,
        #"Semantic/Map/SemanticMapExport.swift | semanticMap.export.caveat.unclustered %lld %lld %lld"#,
        #"Semantic/Map/SemanticMapSpikeView.swift | \(model.placedCount) documents"#,
        #"Semantic/Map/SemanticMapSpikeView.swift | semanticMap.a11y.summary %lld %lld %lld"#,
        #"SeriesAnalytics/AdministrationProfilesDashboard.swift | series.admin.caveats.body.v2 %lld"#,
        #"SeriesAnalytics/AdministrationProfilesDashboard.swift | series.admin.docs.pointPlusRange"#,
        #"SeriesAnalytics/AdministrationProfilesDashboard.swift | series.admin.volumes.docCount"#,
        #"SeriesAnalytics/SeriesAnalyticsExport.swift | series.export.caveat.corpus %lld"#,
        #"SeriesAnalytics/SeriesGeographyDashboard.swift | series.geography.caveats.body.v2 %lld %lld"#,
        #"SeriesAnalytics/SeriesProductionDashboard.swift | series.caveats.body.v2 %lld"#,
        #"SeriesAnalytics/SeriesProductionDashboard.swift | series.chart.cumulative.caption.v2 %lld"#,
        #"SeriesAnalytics/SeriesScopeBar.swift | series.scope.customScope %@ %lld"#,
        #"SeriesAnalytics/SourceProvenanceDashboard.swift | series.provenance.caveats.body.v2 %lld %lld"#,
        #"SeriesAnalytics/TopCollectionsCard.swift | series.provenance.topCollections.coverage %lld %lld %@ %@"#,
        #"SeriesAnalytics/TopCollectionsCard.swift | series.provenance.topCollections.coverage.noShare %lld %lld %@"#,
        #"SeriesAnalytics/TopCollectionsCard.swift | series.provenance.topCollections.method.v3 %lld %lld"#,
        #"Settings/CustomScopesView.swift | settings.scopes.editor.footer %lld %lld"#,
        #"Settings/CustomScopesView.swift | settings.scopes.facet.coverage.add %lld"#,
        #"Settings/CustomScopesView.swift | settings.scopes.facet.subject.row %@ %lld"#,
        #"Settings/CustomScopesView.swift | settings.scopes.facet.tag.row %lld"#,
        #"Settings/CustomScopesView.swift | settings.scopes.row.indexed %lld %lld"#,
        #"Settings/CustomScopesView.swift | settings.scopes.row.noneIndexed %lld"#,
        #"Settings/DataRecoverySummary.swift | settings.dataRecovery.sync.manyErrors %lld"#,
        #"Settings/DataRecoverySummary.swift | settings.dataRecovery.sync.manyErrorsSomeNoDetail %lld %lld"#,
        #"Settings/DataRecoveryView.swift | settings.dataRecovery.schema.recordTypes.detail"#,
        #"Settings/FRUSSettingsView.swift | settings.projects.related.scopes.many %lld"#,
        #"Settings/FRUSSettingsView.swift | settings.projects.related.tags.many %lld"#,
        #"Settings/FRUSSettingsView.swift | settings.scopes.row.indexed %lld %lld"#,
        #"Settings/FRUSSettingsView.swift | settings.scopes.row.noneIndexed %lld"#,
        #"Settings/MacVolumesStorageHub.swift | settings.storage.indexing.docCount"#,
        #"Settings/MacVolumesStorageHub.swift | settings.storage.rebuilding.all"#,
        #"Settings/SemanticStorageSection.swift | settings.vectors.download.detail.v3 %lld %@"#,
        #"Settings/SemanticStorageSection.swift | settings.vectors.downloadAll.detail %lld %@"#,
        #"Settings/SettingsView.swift | settings.projects.related.scopes.many %lld"#,
        #"Settings/SettingsView.swift | settings.projects.related.tags.many %lld"#,
        #"Settings/VolumeUpdateReviewSection.swift | settings.updateReview.markVolume.title %lld"#,
        #"Settings/VolumeUpdateReviewSection.swift | settings.updateReview.more %lld"#,
        #"Settings/VolumeUpdateReviewSection.swift | settings.updateReview.summary.detail %lld %lld %lld"#,
        #"Settings/VolumeUpdateReviewSection.swift | settings.updateReview.volume.lead %lld %lld"#,
        #"Settings/VolumesStorageHubView.swift | settings.storage.indexing.docCount"#,
        #"Settings/VolumesStorageHubView.swift | settings.storage.rebuilding.all"#,
        #"Settings/WorkingCorporaView.swift | corpora.againstVolumes %lld"#,
        #"SourceExplorer/ArchivalNeighborsSheet.swift | archiveVisit.basis.neighbors %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | archiveVisit.basis.unit.partial %lld %lld %@"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.addToVisit %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.child.volumes %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.divided.footer %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.local.counts %lld %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.related.shared %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.related.showAll %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.unprinted.counts %lld %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.unprinted.showAll %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.volumes.header %lld"#,
        #"SourceExplorer/CollectionDetailView.swift | collection.detail.volumes.showAll %lld"#,
        #"SourceExplorer/MacSourceExplorerView.swift | source.explorer.collection.cited %lld"#,
        #"SourceExplorer/MacSourceExplorerView.swift | source.explorer.related.overflow"#,
        #"SourceExplorer/SourceExplorerView.swift | source.explorer.collection.cited %lld"#,
        #"SourceExplorer/SourceExplorerView.swift | source.explorer.related.overflow"#,
        #"SourceExplorer/SourceExplorerView.swift | source.explorer.unprinted.row.repeat %lld %lld"#,
        #"Summarization/BackgroundSummarizationService.swift | background.summarizer.notification.body.succeeded"#,
        #"Summarization/BackgroundSummarizationService.swift | bg.summarizer.failed.allFailed"#,
        #"Summarization/BackgroundSummarizationService.swift | bg.summarizer.failed.unavailable"#,
        #"Summarization/BackgroundSummarizationSettingsView.swift | bg.summarizer.scope.customScope.downloaded %lld %lld"#,
        #"Summarization/PromptsListView.swift | prompts.list.row.summaryCount.plural"#,
        #"Summarization/SummarizationPaneModel.swift | settings.summarization.lastRun.doc.many %lld"#,
        #"Summarization/SummarizationPaneModel.swift | settings.summarization.prompt.count.many %lld"#,
        #"TripPacket/ArchiveVisitEditorView.swift | archiveVisit.claim.drawnFrom.header %lld"#,
        #"TripPacket/ArchiveVisitEditorView.swift | archiveVisit.claim.pointedAt.header %lld"#,
        #"TripPacket/ArchiveVisitEditorView.swift | archiveVisit.info.sparsity.measured.v2"#,
        #"TripPacket/ArchiveVisitEditorView.swift | archiveVisit.row.drawnFrom.other"#,
        #"TripPacket/ArchiveVisitEditorView.swift | archiveVisit.row.pointedAt.other"#,
        #"TripPacket/ArchiveVisitEditorView.swift | archiveVisit.tiers.delete.message %lld"#,
        #"TripPacket/ArchiveVisitEditorView.swift | archiveVisit.tiers.members %lld"#,
    ]
}

// MARK: - The Mac never says tap (#1380)

/// No text the Mac compiles tells the reader to tap (#1380).
///
/// On the Mac the reader clicks, but Archival, Person, Cross-Reference, Semantic and Corpus
/// Analytics, Chronology, Source Explorer, Saved Searches and the graph windows told them to "tap":
/// each was one `defaultValue` both platforms show, or — in two cases — a string only the Mac
/// compiles. A sentence that reads right on both platforms now says "select"; where a button is
/// named ("click Search", "click Show") the Mac branch has a key of its own, because two
/// `String(localized:)` calls sharing a key with different default values collide; and the
/// `hand.tap` glyph beside a chart's hint is `FRUSTheme.selectGlyph`, a clicking pointer on the Mac.
///
/// ## How it reads
/// Every Swift file under `FRUSExplorer/`, through `LexedSource`, with each literal's line decided
/// by ``CompilationBranches`` as the Mac compiles it — the walk the segmented-picker and Mac sheet
/// audits read through `MaskedSwift.compiled(for:)`. `os(iOS)` and `canImport(UIKit)` are iOS-only;
/// `os(macOS)`, `!os(iOS)`, `canImport(AppKit)` and ungated code compile for the Mac; `#else`
/// flips; blocks nest; and a gate around a whole file, like `SupportingViews.swift`'s, counts. A
/// condition it cannot decide (`DEBUG`) is read as compiled, because a Mac build can ship it.
///
/// A literal is read when `CopyScan.isInScope` reads it — a `defaultValue:`, or a key-taking
/// SwiftUI call's own literal such as `Text("…")` or `.accessibilityHint("…")` — whether written
/// on one line or as a `"""` block, and it is matched whole, by the call's balanced parentheses,
/// never by a window of lines. An SF Symbol's name (`systemImage:`, `systemName:`) is not text. A
/// literal fails when its text says `tap`, `taps`, `tapped` or `tapping` as a word, in any case,
/// and no clause of it that says so also says "click": "Tap or click a bar" covers both platforms,
/// while "Tap to see details; right-click or long-press for actions" still told a Mac VoiceOver
/// user to tap for details, which is why the rule is the clause and not the literal #1380 first
/// proposed — that hint is one of the sites #1380 lists, and the literal rule passed it.
///
/// The Research Guide is read too, though none of it is in `CopyScan`'s scope: its prose is a table
/// of plain literals — a page's title and subtitle, a section's heading, paragraphs and bullets, all
/// arguments of `EducationPage(…)` or `EducationSection(…)` — which the Mac shows in its Help ▸ FRUS
/// Research Guide window. A literal whose innermost call is one of those two is read, except an
/// `id:`, which is a name and not text. Review, round 1 added this: the guide's "Most of those
/// become a filter with one tap" had passed a scan that could not see it.
///
/// Separately, no literal the Mac compiles names `hand.tap` or a variant of it, in scope or not:
/// `Image(systemName:)` is not a key-taking call, and the co-mention dock drew the glyph through it.
///
/// ## The exceptions, and why each holds
/// A string the Mac compiles but never shows says "tap" harmlessly, and ``macTapExceptions`` lists
/// each with its reason. Every reason is a fact the tree test checks (``MacTapGuard``), so wiring an
/// excused view into the Mac fails it rather than leaving the Mac showing "tap": no code the Mac
/// compiles constructs the view or tip, the text is drawn only inside `if <flag> {` whose Mac branch
/// is `false`, or each clause saying tap names the Mac's own gesture too.
///
/// ## What it cannot see
/// - A string built as a plain Swift `String` and handed to a view later, outside `defaultValue:`,
///   the key-taking calls and the guide's two initialisers — the same limit the count scan states
///   above.
/// - A view constructed other than by its name — `.init(…)` against an inferred type, or a factory
///   that returns it — which the construction check does not count.
/// - What a rendered Mac window says. This is a source scan, so it gives the same result on every
///   test destination, iPhone and iPad alike, and it fails when the SOURCE regains a Mac "tap";
///   the proof that a window reads "click" is the window opened on a Mac, the owner's check.
///
/// Version history:
///   1.0 — 2026-09-25: #1380
///   1.1 — 2026-09-25: #1380 review, round 1 — the scan reads the Research Guide's prose, and each
///         exception carries a ``MacTapGuard`` the tree test checks
extension CodingStandardsAuditTests {

    // MARK: Tree tests

    /// No literal the Mac compiles tells the reader to tap, and none names the `hand.tap` glyph,
    /// except the ones ``macTapExceptions`` lists, each of whose reasons is checked here.
    ///
    /// Measured on `v2` at `1a4506c9`, before the fix: 483 files, 6,710 in-scope literals of which
    /// 6,200 compile for the Mac, 30 flagged literals and three `hand.tap` glyphs. The 30 are the 22
    /// sites #1380 lists as wrong (the hint at the old `CrossReferenceGraphView.swift:742`
    /// included), the one it names as right for both platforms, and seven it did not find; the fix
    /// took 23 of them, and ``macTapExceptions`` holds the other seven. The Research Guide, read
    /// from review round 1, adds 105 literals, and flagged one more: the facet sentence.
    @Test("CodingStandardsAudit: no text the Mac compiles tells the reader to tap (#1380)")
    func macTextNeverSaysTap() throws {
        let files = try Self.lexedAppSources()
        var total = MacTapScan.FileResult()
        var flagged: [String: [String]] = [:]
        var sitesByKey: [String: [(path: String, site: MacTapScan.Site)]] = [:]
        var glyphs: [String] = []
        for (path, lexed) in files {
            let result = MacTapScan.scan(lexed)
            total.literalsRead += result.literalsRead
            total.literalsCompiled += result.literalsCompiled
            total.guideLiteralsRead += result.guideLiteralsRead
            total.literalEvents.merge(result.literalEvents, uniquingKeysWith: +)
            total.lineEvents.merge(result.lineEvents, uniquingKeysWith: +)
            for site in result.sites {
                flagged["\(path) | \(site.key)", default: []].append("\(path):\(site.line) — \(site.text)")
                sitesByKey["\(path) | \(site.key)", default: []].append((path, site))
            }
            glyphs += result.glyphs.map { "\(path):\($0)" }
        }

        // A moved root, a lexer that stopped recording literals, or a tracker that decided every
        // line one way would make the checks below vacuous. Measured when the scan was written:
        // 483 files, 6,710 literals read, 6,200 compiled for the Mac and 510 not; and, from review
        // round 1, 105 Research Guide literals.
        #expect(files.count >= 450, "Read only \(files.count) Swift file(s): the scan is broken, not the tree clean.")
        #expect(total.literalsRead >= 6_000, "Read only \(total.literalsRead) in-scope literal(s).")
        #expect(total.guideLiteralsRead >= 90, """
            Read only \(total.guideLiteralsRead) Research Guide literal(s): the scan has stopped \
            reading EducationPage and EducationSection, whose prose the Mac shows in its own window.
            """)
        #expect(total.literalsCompiled >= 5_500,
                "Only \(total.literalsCompiled) literal(s) compile for the Mac: the tracker is dropping code.")
        #expect(total.literalsRead - total.literalsCompiled >= 300, """
            Only \(total.literalsRead - total.literalsCompiled) literal(s) are iOS-only: the tracker \
            is keeping code the Mac does not compile.
            """)
        // Every gate kind, entered: a tracker that stopped recognising one reads its code as
        // `other` (or as ungated), and that kind's count falls to zero here rather than passing.
        for gate in MacTapScan.Gate.required {
            #expect(total.lineEvents[gate, default: 0] > 0, """
                No line of code under \(gate) was decided. Either the tracker stopped recognising \
                it, or the tree no longer holds such a gate — only then drop it from Gate.required.
                """)
        }
        // And every kind the tap decision turns on holds literals: read ungated and under a Mac
        // gate, skipped under an iOS one and under the `#else` of a Mac one, read inside a
        // file-wide gate. (`canImport(UIKit)` and `canImport(AppKit)` guard no in-scope literal
        // today, so they are held by their lines above and by `compilationBranchRules`.)
        for gate in [MacTapScan.Gate.ungated, .iOS, .macOS, .elseOfMacOS, .fileWide] {
            #expect(total.literalEvents[gate, default: 0] > 0, "No in-scope literal was read under \(gate).")
        }

        let exempt = Set(Self.macTapExceptions.keys)
        let new = Set(flagged.keys).subtracting(exempt).sorted()
        let stale = exempt.subtracting(flagged.keys).sorted()
        #expect(new.isEmpty, """
            Text the Mac compiles tells the reader to tap (#1380). Use one wording that reads on \
            both platforms ("Select a bar …"); where a control is named, branch with #if os(macOS) \
            and give the Mac text a key of its own (a shared key with two default values collides):
            \(new.flatMap { flagged[$0] ?? [] }.joined(separator: "\n"))
            """)
        #expect(stale.isEmpty, """
            macTapExceptions lists text the scan no longer flags — fixed, re-keyed or moved. \
            Delete it: \(stale.joined(separator: ", "))
            """)
        #expect(glyphs.isEmpty, """
            The Mac compiles the hand.tap glyph (#1380). Use FRUSTheme.selectGlyph, a clicking \
            pointer on the Mac: \(glyphs.joined(separator: ", "))
            """)

        // Each exception's reason, checked (review, round 1). An exception whose reason stopped
        // holding would excuse text the Mac now shows, so each is a failure naming the reason.
        let types = Set(Self.macTapExceptions.values.compactMap(\.holds.constructedType))
        let constructions = MacTapScan.constructionSites(of: types, in: files)
        let lexedByPath = Dictionary(files.map { ($0.path, $0.source) }, uniquingKeysWith: { first, _ in first })
        var checked = 0
        for key in Set(flagged.keys).intersection(exempt).sorted() {
            guard let exception = Self.macTapExceptions[key] else { continue }
            for (path, site) in sitesByKey[key] ?? [] {
                guard let lexed = lexedByPath[path] else { continue }
                checked += 1
                let failure = MacTapScan.failure(of: exception.holds, site: site, path: path,
                                                 in: lexed, constructions: constructions)
                #expect(failure == nil, """
                    macTapExceptions excuses "\(key)" because \(exception.reason) — which no longer \
                    holds, so the Mac may show it: \(failure ?? "")
                    """)
            }
        }
        // Each exception's check ran on at least one site, and the construction matcher found the
        // excused types where they are built: measured in review round 1, seven sites — CorpusView
        // four times in BrowserView, EdgeTapNavigationTip twice in DocumentView and once in the
        // registry's allTips, PromptsListView nowhere.
        #expect(checked >= Self.macTapExceptions.count,
                "Checked \(checked) exception site(s) for \(Self.macTapExceptions.count) exceptions.")
        #expect(constructions.values.joined().count > 0, """
            No construction of \(types.sorted().joined(separator: ", ")) was found anywhere: the \
            construction matcher is broken, not the tree clean.
            """)
    }

    /// Strings compiled for the Mac that say "tap" and are never shown there, each with the reason
    /// and the check that the reason still holds. Keyed by file (under `FRUSExplorer/`) and string
    /// key. An entry the scan stops flagging fails the tree test, so the list cannot outlive the
    /// strings it excuses, and an entry whose check fails fails it too, so it cannot outlive its
    /// reason.
    static let macTapExceptions: [String: MacTapException] = [
        "App/DiscoveryTips.swift | tip.edgeTap.title": MacTapException(
            reason: "no code the Mac compiles constructs EdgeTapNavigationTip but the registry's "
                + "allTips, which re-arms it and draws nothing — its one anchor is the iOS-only "
                + "DocumentView.swift — and an edge tap is a touch gesture",
            holds: .neverConstructedOnMac("EdgeTapNavigationTip", except: "App/DiscoveryTips.swift")),
        "App/DiscoveryTips.swift | tip.edgeTap.message": MacTapException(
            reason: "it is the same tip's message",
            holds: .neverConstructedOnMac("EdgeTapNavigationTip", except: "App/DiscoveryTips.swift")),
        "Browser/CorpusView.swift | browser.corpus.people.help": MacTapException(
            reason: "no code the Mac compiles constructs CorpusView — BrowserView, #if os(iOS) "
                + "whole, is its only constructor",
            holds: .neverConstructedOnMac("CorpusView")),
        "Browser/CorpusView.swift | browser.corpus.subjects.help": MacTapException(
            reason: "it is the same view's other tooltip",
            holds: .neverConstructedOnMac("CorpusView")),
        "Settings/SettingsView.swift | settings.display.reading.footer.iphone": MacTapException(
            reason: "it is drawn only inside `if isPhone {`, and isPhone's Mac branch is `false`",
            holds: .drawnOnlyWhen("isPhone")),
        "Summarization/PromptsListView.swift | prompts.list.user.empty": MacTapException(
            reason: "no code the Mac compiles constructs PromptsListView — nothing constructs it",
            holds: .neverConstructedOnMac("PromptsListView")),
        "CrossReference/CrossReferenceGraphView.swift | graph.info.edges.body": MacTapException(
            reason: "\"Hover over or tap the middle of a line\" names the Mac's gesture beside the "
                + "touch one, so it reads right on both (#1380 says so)",
            holds: .namesMacGesture("hover")),
    ]

    /// One string the Mac compiles and never shows, and the fact that keeps it off the Mac.
    struct MacTapException: Sendable {
        /// Why the Mac never shows it, as the failure message quotes it.
        let reason: String
        /// The same reason, in a form the tree test checks.
        let holds: MacTapGuard
    }

    /// The facts an exception rests on, each checkable by a source scan.
    enum MacTapGuard: Sendable, Equatable {
        /// No line the Mac compiles constructs the type — its name directly followed by `(` in
        /// code — outside the named file, whose constructions are not displays.
        case neverConstructedOnMac(String, except: String? = nil)
        /// The literal's innermost block opens `if <flag> {`, and the flag, declared in the same
        /// file as `var <flag>: Bool { … }`, has `false` as its whole body on the Mac.
        case drawnOnlyWhen(String)
        /// Every clause of the literal that says tap also names this word, the Mac's own gesture.
        case namesMacGesture(String)

        /// The type a construction check reads, if this is one.
        var constructedType: String? {
            if case .neverConstructedOnMac(let type, _) = self { return type }
            return nil
        }
    }

    /// The Mac branches #1380 added where a control is named, each with the iOS text it must not
    /// change: the iOS key keeps its text on iOS, the Mac key never compiles there, and on the Mac
    /// the Mac key compiles once and the iOS key not at all.
    @Test("CodingStandardsAudit: #1380's Mac wording never reaches iOS, and iOS keeps its own")
    func macClickVariantsStayOffIOS() throws {
        var read = 0
        for variant in Self.macClickVariants {
            let url = Self.copyScanSourceRoot.appendingPathComponent(variant.file)
            let lexed = LexedSource(try String(contentsOf: url, encoding: .utf8))
            func compiled(_ key: String, on platform: CompilationBranches.Platform) -> [LexedSource.Literal] {
                let branches = CompilationBranches(masked: lexed.masked, platform: platform)
                return lexed.literals.filter {
                    $0.isDefaultValue && lexed.key(of: $0) == key && branches.line($0.line)?.compiled != false
                }
            }
            let iOSText = compiled(variant.iOSKey, on: .iOS)
            read += iOSText.count
            #expect(iOSText.map(\.sourceText) == [variant.iOSText],
                    "\(variant.file): iOS must keep \(variant.iOSKey) as it was, once")
            #expect(compiled(variant.macKey, on: .iOS).isEmpty,
                    "\(variant.file): \(variant.macKey) compiles for iOS — the Mac wording leaks")
            #expect(compiled(variant.macKey, on: .macOS).count == 1,
                    "\(variant.file): the Mac must compile \(variant.macKey) once")
            #expect(compiled(variant.iOSKey, on: .macOS).isEmpty,
                    "\(variant.file): the Mac still compiles \(variant.iOSKey), the iOS wording")
        }
        #expect(read == Self.macClickVariants.count, "Read \(read) iOS strings for \(Self.macClickVariants.count) variants.")
    }

    /// One control-naming sentence with a Mac branch of its own.
    struct MacClickVariant: Sendable {
        /// The file, under `FRUSExplorer/`.
        let file: String
        /// The key iOS keeps.
        let iOSKey: String
        /// The Mac branch's own key.
        let macKey: String
        /// iOS's text, unchanged by #1380, as the source spells it.
        let iOSText: String
    }

    /// The sentences that name a control, and so read "tap" on iOS and "click" on the Mac.
    static let macClickVariants: [MacClickVariant] = [
        MacClickVariant(file: "Analytics/AnalyticsView.swift",
                        iOSKey: "analytics.prompt.detail", macKey: "analytics.prompt.detail.mac",
                        iOSText: "Type a keyword and tap Search to chart its frequency across the FRUS corpus."),
        MacClickVariant(file: "Chronology/ChronologyView.swift",
                        iOSKey: "chronology.prompt.detail", macKey: "chronology.prompt.detail.mac",
                        iOSText: "Pick a start and end date, then tap Show to browse every corpus document from that period."),
        MacClickVariant(file: "Search/SavedSearchesView.swift",
                        iOSKey: "savedSearches.empty.detail", macKey: "savedSearches.empty.detail.mac",
                        iOSText: "Tap the bookmark button in Search to save a search for quick access later."),
    ]

    // MARK: Fixtures — the conditional-compilation tracker

    /// One fixture for ``CompilationBranches``: a snippet whose line holding `probe` is decided.
    struct CompilationFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the case's name.
        let name: String
        /// The Swift source; exactly one line holds `probe`.
        let source: String
        /// Whether the Mac compiles the probe line (`nil`: undecidable, kept).
        let mac: Bool?
        /// Whether iOS compiles it.
        let iOS: Bool?
        /// The gate kinds the scan counts the line under, as the Mac reads it.
        let gates: [MacTapScan.Gate]
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// One fixture per gate kind, and one per conjunct of a compound condition.
    static let compilationFixtures: [CompilationFixture] = [
        CompilationFixture(name: "ungated code compiles for both",
                           source: "let probe = 1", mac: true, iOS: true, gates: [.ungated]),
        CompilationFixture(name: "os(iOS) is iOS-only",
                           source: "let a = 0\n#if os(iOS)\nlet probe = 1\n#endif", mac: false, iOS: true, gates: [.iOS]),
        CompilationFixture(name: "canImport(UIKit) is iOS-only",
                           source: "let a = 0\n#if canImport(UIKit)\nlet probe = 1\n#endif", mac: false, iOS: true, gates: [.uiKit]),
        CompilationFixture(name: "os(macOS) is the Mac's",
                           source: "let a = 0\n#if os(macOS)\nlet probe = 1\n#endif", mac: true, iOS: false, gates: [.macOS]),
        CompilationFixture(name: "!os(iOS) is the Mac's",
                           source: "let a = 0\n#if !os(iOS)\nlet probe = 1\n#endif", mac: true, iOS: false, gates: [.notIOS]),
        CompilationFixture(name: "canImport(AppKit) is the Mac's",
                           source: "let a = 0\n#if canImport(AppKit)\nlet probe = 1\n#endif", mac: true, iOS: false, gates: [.appKit]),
        CompilationFixture(name: "#else flips an iOS branch to the Mac",
                           source: "let a = 0\n#if os(iOS)\nlet a = 1\n#else\nlet probe = 1\n#endif",
                           mac: true, iOS: false, gates: [.elseOfIOS]),
        CompilationFixture(name: "#else flips a Mac branch to iOS",
                           source: "let a = 0\n#if os(macOS)\nlet a = 1\n#else\nlet probe = 1\n#endif",
                           mac: false, iOS: true, gates: [.elseOfMacOS]),
        CompilationFixture(name: "#elseif canImport(AppKit) after canImport(UIKit) is the Mac's",
                           source: "let a = 0\n#if canImport(UIKit)\nlet a = 1\n#elseif canImport(AppKit)\nlet probe = 1\n#endif",
                           mac: true, iOS: false, gates: [.appKit]),
        CompilationFixture(name: "a Mac gate nested in an iOS one compiles nowhere",
                           source: "let a = 0\n#if os(iOS)\n    #if os(macOS)\n    let probe = 1\n    #endif\n#endif",
                           mac: false, iOS: false, gates: [.macOS, .nested]),
        CompilationFixture(name: "DEBUG nested in a Mac gate is undecided on the Mac, off on iOS",
                           source: "let a = 0\n#if os(macOS)\n#if DEBUG\nlet probe = 1\n#endif\n#endif",
                           mac: nil, iOS: false, gates: [.other, .nested]),
        CompilationFixture(name: "a gate around all but the imports is file-wide",
                           source: "import SwiftUI\n\n#if os(macOS)\nlet probe = 1\n#endif // os(macOS)\n",
                           mac: true, iOS: false, gates: [.macOS, .fileWide]),
        CompilationFixture(name: "a gate with code after it is not file-wide",
                           source: "import SwiftUI\n#if os(macOS)\nlet probe = 1\n#endif\nlet b = 2",
                           mac: true, iOS: false, gates: [.macOS]),
        CompilationFixture(name: "os(iOS) && DEBUG — the first conjunct decides the Mac",
                           source: "let a = 0\n#if os(iOS) && DEBUG\nlet probe = 1\n#endif", mac: false, iOS: nil, gates: [.other]),
        CompilationFixture(name: "DEBUG && os(iOS) — the second conjunct decides the Mac",
                           source: "let a = 0\n#if DEBUG && os(iOS)\nlet probe = 1\n#endif", mac: false, iOS: nil, gates: [.other]),
        CompilationFixture(name: "os(macOS) || DEBUG — one disjunct decides the Mac",
                           source: "let a = 0\n#if os(macOS) || DEBUG\nlet probe = 1\n#endif", mac: true, iOS: nil, gates: [.other]),
        CompilationFixture(name: "!os(macOS) is iOS's",
                           source: "let a = 0\n#if !os(macOS)\nlet probe = 1\n#endif", mac: false, iOS: true, gates: [.other]),
        CompilationFixture(name: "a #if in a comment or a string is not a directive",
                           source: "// #if os(iOS)\nlet s = \"\"\"\n#if os(iOS)\n\"\"\"\nlet probe = 1",
                           mac: true, iOS: true, gates: [.ungated]),
    ]

    /// ``CompilationBranches`` decides each fixture's probe line as stated, on both platforms, and
    /// the scan files it under the stated gate kinds.
    @Test("CodingStandardsAudit: the conditional-compilation tracker's rules", arguments: compilationFixtures)
    func compilationBranchRules(_ fixture: CompilationFixture) throws {
        let lexed = LexedSource(fixture.source)
        let probe = try #require(fixture.source.split(separator: "\n", omittingEmptySubsequences: false)
            .firstIndex { $0.contains("probe") }) + 1
        let mac = CompilationBranches(masked: lexed.masked, platform: .macOS)
        let iOS = CompilationBranches(masked: lexed.masked, platform: .iOS)
        let macLine = try #require(mac.line(probe))
        #expect(macLine.compiled == fixture.mac, "the Mac")
        #expect(try #require(iOS.line(probe)).compiled == fixture.iOS, "iOS")
        #expect(MacTapScan.gates(of: macLine.branches, fileWide: mac.fileWideBlock != nil) == fixture.gates)
    }

    // MARK: Fixtures — the tap rule

    /// One fixture for the tap rule: a snippet, the keys it must flag, and its `hand.tap` glyphs.
    struct MacTapFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the case's name.
        let name: String
        /// The Swift source the scan reads.
        let source: String
        /// The string keys it must flag, in source order.
        let keys: [String]
        /// How many `hand.tap` literals the Mac compiles in it.
        var glyphs = 0
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// The tap rule's conjuncts and forms, one fixture each.
    static let macTapFixtures: [MacTapFixture] = [
        MacTapFixture(name: "an ungated defaultValue saying tap is flagged",
                      source: #"String(localized: "k1", defaultValue: "Tap a bar to open it.")"#, keys: ["k1"]),
        MacTapFixture(name: "the same under os(iOS) is not — the Mac does not compile it",
                      source: "#if os(iOS)\n" + #"String(localized: "k2", defaultValue: "Tap a bar.")"# + "\n#endif",
                      keys: []),
        MacTapFixture(name: "under the #else of an iOS gate it is",
                      source: "#if os(iOS)\nlet a = 1\n#else\n" + #"String(localized: "k3", defaultValue: "Tap a bar.")"#
                        + "\n#endif", keys: ["k3"]),
        MacTapFixture(name: "under a condition it cannot decide it is read — a Mac debug build ships it",
                      source: "#if DEBUG\n" + #"String(localized: "k3a", defaultValue: "Tap a bar.")"# + "\n#endif",
                      keys: ["k3a"]),
        MacTapFixture(name: "text that does not say tap passes",
                      source: #"String(localized: "k4.tap.hint", defaultValue: "Select a bar to open it.")"#, keys: []),
        MacTapFixture(name: "tap and click in one clause cover both platforms",
                      source: #"String(localized: "k5", defaultValue: "Tap or click a bar to open it.")"#, keys: []),
        MacTapFixture(name: "a click in another clause does not excuse the tap — the graph node hint",
                      source: #"String(localized: "k6", defaultValue: "Tap to see details; right-click or long-press for actions")"#,
                      keys: ["k6"]),
        MacTapFixture(name: "every form of the word, in any case, is flagged",
                      source: #"""
                          String(localized: "k7", defaultValue: "Tapping a word")
                          String(localized: "k8", defaultValue: "Once tapped, it opens.")
                          String(localized: "k9", defaultValue: "Edge-Tap Page Turn")
                          """#, keys: ["k7", "k8", "k9"]),
        MacTapFixture(name: "a word that only contains tap is not the word",
                      source: #"String(localized: "k10", defaultValue: "An untapped tapestry of sources.")"#, keys: []),
        MacTapFixture(name: "a bare Text and an accessibility hint are read",
                      source: #"Text("Tap here").accessibilityHint("Tap to expand")"#, keys: ["Tap here", "Tap to expand"]),
        MacTapFixture(name: "a multi-line defaultValue is read whole",
                      source: #"""
                          String(localized: "k11", defaultValue: """
                              Every document placed by its language. \
                              Tap a document to open it.
                              """)
                          """#, keys: ["k11"]),
        MacTapFixture(name: "a log line is not user-facing copy",
                      source: #"print("[X] Cross-ref tap → \(id)")"#, keys: []),
        MacTapFixture(name: "tap inside an interpolation's code is not text",
                      source: #"String(localized: "k12", defaultValue: "\(tapCount) found")"#, keys: []),
        MacTapFixture(name: "a symbol name is a glyph, not text",
                      source: #"Label(String(localized: "k13", defaultValue: "Select a bar."), systemImage: "hand.tap")"#,
                      keys: [], glyphs: 1),
        MacTapFixture(name: "an Image(systemName:) glyph variant under a Mac gate is flagged",
                      source: "#if os(macOS)\n" + #"Image(systemName: "hand.tap.fill")"# + "\n#endif", keys: [], glyphs: 1),
        MacTapFixture(name: "the glyph under the #else of a Mac gate is iOS's",
                      source: "#if os(macOS)\n" + #"let g = "cursorarrow.click""# + "\n#else\n" + #"let g = "hand.tap""#
                        + "\n#endif", keys: [], glyphs: 0),
        MacTapFixture(name: "a Research Guide paragraph or bullet is read, though no key-taking call holds it",
                      source: #"""
                          EducationSection(heading: "Facets", paragraphs: ["Most become a filter with one tap."],
                                           bullets: ["Tapping a row narrows the search."])
                          """#, keys: ["Most become a filter with one tap.", "Tapping a row narrows the search."]),
        MacTapFixture(name: "a Research Guide page's title is read",
                      source: #"EducationPage(id: "p", title: "Tap to Begin", subtitle: nil, sections: [])"#,
                      keys: ["Tap to Begin"]),
        MacTapFixture(name: "a guide section's id is a name, not text",
                      source: #"EducationSection(id: "tap-targets", paragraphs: ["Select a facet."])"#, keys: []),
        MacTapFixture(name: "a plain array in any other call is still not read",
                      source: #"Checklist(items: ["Tap here first."])"#, keys: []),
    ]

    /// The tap rule flags exactly what each fixture states.
    @Test("CodingStandardsAudit: the Mac tap scan's rules", arguments: macTapFixtures)
    func macTapScanRules(_ fixture: MacTapFixture) {
        let lexed = LexedSource(fixture.source)
        let result = MacTapScan.scan(lexed)
        #expect(result.sites.map(\.key) == fixture.keys)
        #expect(result.glyphs.count == fixture.glyphs)
    }

    // MARK: Fixtures — the exceptions' checks

    /// One fixture for a ``MacTapGuard``: a file whose first flagged literal the guard is checked
    /// against, and whether it holds.
    struct MacTapGuardFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the case's name.
        let name: String
        /// The file's path under `FRUSExplorer/`, which an `except:` names.
        var path = "Feature/Probe.swift"
        /// The Swift source; its first literal the tap rule flags is the excused one.
        let source: String
        /// The guard checked.
        let holds: MacTapGuard
        /// Whether it holds.
        let expected: Bool
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// A flag declared the way `SettingsView.isPhone` is, with `macValue` as its Mac branch.
    static func phoneFlag(macValue: String) -> String {
        """
        private var isPhone: Bool {
            #if os(iOS)
            UIDevice.current.userInterfaceIdiom == .phone
            #else
            \(macValue)
            #endif
        }
        """
    }

    /// One fixture per conjunct of each guard.
    static let macTapGuardFixtures: [MacTapGuardFixture] = [
        MacTapGuardFixture(name: "a construction the Mac compiles breaks neverConstructedOnMac",
                           source: "Text(\"Tap a name\")\nlet v = CorpusView(vm: vm)",
                           holds: .neverConstructedOnMac("CorpusView"), expected: false),
        MacTapGuardFixture(name: "a construction only iOS compiles keeps it",
                           source: "Text(\"Tap a name\")\n#if os(iOS)\nlet v = CorpusView(vm: vm)\n#endif",
                           holds: .neverConstructedOnMac("CorpusView"), expected: true),
        MacTapGuardFixture(name: "the name in a comment or a string is not a construction",
                           source: "Text(\"Tap a name\")\n// CorpusView(vm: vm)\nlet s = \"CorpusView(vm: vm)\"",
                           holds: .neverConstructedOnMac("CorpusView"), expected: true),
        MacTapGuardFixture(name: "a longer name is another type, and a declaration is not a construction",
                           source: "Text(\"Tap a name\")\nstruct CorpusView: View {}\nlet a = MyCorpusView()\nlet b = CorpusViewModel()",
                           holds: .neverConstructedOnMac("CorpusView"), expected: true),
        MacTapGuardFixture(name: "the excepted file may construct it",
                           path: "App/DiscoveryTips.swift",
                           source: "Text(\"Tap the edge\")\nlet t = EdgeTapNavigationTip()",
                           holds: .neverConstructedOnMac("EdgeTapNavigationTip", except: "App/DiscoveryTips.swift"),
                           expected: true),
        MacTapGuardFixture(name: "the exception covers only its own file",
                           source: "Text(\"Tap the edge\")\nlet t = EdgeTapNavigationTip()",
                           holds: .neverConstructedOnMac("EdgeTapNavigationTip", except: "App/DiscoveryTips.swift"),
                           expected: false),
        MacTapGuardFixture(name: "text inside if isPhone, whose Mac branch is false, holds",
                           source: phoneFlag(macValue: "false")
                            + "\nvar footer: some View {\n    if isPhone {\n        Text(\"Tap Research\")\n    }\n}",
                           holds: .drawnOnlyWhen("isPhone"), expected: true),
        MacTapGuardFixture(name: "text in the else of if isPhone is drawn on the Mac",
                           source: phoneFlag(macValue: "false")
                            + "\nvar footer: some View {\n    if isPhone {\n        Text(\"Select\")\n    } else {\n"
                            + "        Text(\"Tap Research\")\n    }\n}",
                           holds: .drawnOnlyWhen("isPhone"), expected: false),
        MacTapGuardFixture(name: "a flag the Mac reads as true does not hide it",
                           source: phoneFlag(macValue: "true")
                            + "\nvar footer: some View {\n    if isPhone {\n        Text(\"Tap Research\")\n    }\n}",
                           holds: .drawnOnlyWhen("isPhone"), expected: false),
        MacTapGuardFixture(name: "a flag the file does not declare does not hide it",
                           source: "var footer: some View {\n    if isPhone {\n        Text(\"Tap Research\")\n    }\n}",
                           holds: .drawnOnlyWhen("isPhone"), expected: false),
        MacTapGuardFixture(name: "a clause naming hover beside tap holds",
                           source: "Text(\"Hover over or tap the middle of a line to read it.\")",
                           holds: .namesMacGesture("hover"), expected: true),
        MacTapGuardFixture(name: "hover in another clause does not cover the tap",
                           source: "Text(\"Tap the middle of a line; hover to preview it.\")",
                           holds: .namesMacGesture("hover"), expected: false),
    ]

    /// Each guard holds or fails exactly as its fixture states.
    @Test("CodingStandardsAudit: the Mac tap exceptions' checks", arguments: macTapGuardFixtures)
    func macTapGuardRules(_ fixture: MacTapGuardFixture) throws {
        let lexed = LexedSource(fixture.source)
        let site = try #require(MacTapScan.scan(lexed).sites.first, "the fixture must hold a flagged literal")
        let constructions = MacTapScan.constructionSites(of: Set([fixture.holds.constructedType].compactMap { $0 }),
                                                         in: [(fixture.path, lexed)])
        let failure = MacTapScan.failure(of: fixture.holds, site: site, path: fixture.path, in: lexed,
                                         constructions: constructions)
        #expect((failure == nil) == fixture.expected, "\(failure ?? "held")")
    }

    // MARK: The rule

    /// The Mac tap-copy scan's rules over one lexed file.
    enum MacTapScan {

        /// "tap", "taps", "tapped" or "tapping", in any case, as a word — so "Edge-Tap" is one and
        /// "untapped" is not.
        static let tapWord: NSRegularExpression = {
            try! NSRegularExpression(pattern: #"\btap(?:s|ped|ping)?\b"#, options: [.caseInsensitive])
        }()

        /// "click" in any form — "click", "Clicking", "right-click".
        static let clickWord: NSRegularExpression = {
            try! NSRegularExpression(pattern: #"click"#, options: [.caseInsensitive])
        }()

        /// What ends a clause: a sentence stop, a semicolon, a dash or a line break, as the source
        /// spells them (`\u{2014}` and `\n` included).
        static let clauseBreak: NSRegularExpression = {
            try! NSRegularExpression(pattern: #"[.;!?—\n]|\\u\{2014\}|\\n"#)
        }()

        /// The argument labels whose literal is an SF Symbol's name, never text.
        static let symbolLabels = ["systemImage:", "systemName:"]

        /// The initialisers whose literals are the Research Guide's prose — a page's title and
        /// subtitle, a section's heading, paragraphs and bullets. Plain literals, so neither a
        /// `defaultValue:` nor a key-taking call marks them as text.
        static let guideInitialisers: Set<String> = ["EducationPage", "EducationSection"]

        /// The argument label whose literal, in a guide initialiser, is a name and not text.
        static let guideIdentifierLabels = ["id:"]

        /// The SF Symbol that drew a tapping hand beside a chart's hint.
        static let tapGlyph = "hand.tap"

        /// How a line is gated, as the Mac compiles it. A line counts toward every kind that
        /// describes it: its innermost branch's, and `nested` and `fileWide` besides.
        enum Gate: String, CaseIterable, Sendable, CustomStringConvertible {
            /// No `#if` encloses it: compiled for the Mac.
            case ungated
            /// Innermost branch `os(iOS)`: not compiled for the Mac.
            case iOS = "os(iOS)"
            /// Innermost branch `canImport(UIKit)`: not compiled for the Mac.
            case uiKit = "canImport(UIKit)"
            /// Innermost branch `os(macOS)`: compiled for the Mac.
            case macOS = "os(macOS)"
            /// Innermost branch `!os(iOS)`: compiled for the Mac.
            case notIOS = "!os(iOS)"
            /// Innermost branch `canImport(AppKit)`: compiled for the Mac.
            case appKit = "canImport(AppKit)"
            /// Innermost branch the `#else` of an iOS-only condition: compiled for the Mac.
            case elseOfIOS = "#else of an iOS-only branch"
            /// Innermost branch the `#else` of a Mac-only condition: not compiled for the Mac.
            case elseOfMacOS = "#else of a Mac-only branch"
            /// Two or more branches enclose it.
            case nested
            /// A block holding all of the file's code but its imports encloses it.
            case fileWide = "file-wide gate"
            /// Any other innermost condition — `DEBUG`, `canImport(Accessibility)`, `!os(macOS)`.
            case other

            /// The kind as the tree test names it.
            var description: String { rawValue }

            /// The kinds a tree scan must enter, or it has stopped reading one.
            static let required: [Gate] = allCases.filter { $0 != .other }
        }

        /// One literal the Mac compiles that tells the reader to tap.
        struct Site: Equatable, Sendable {
            /// The 1-based line the literal opens on.
            let line: Int
            /// Its string key (a bare `Text`'s key, or a guide literal's, is its own text).
            let key: String
            /// Its text as the source spells it.
            let text: String
            /// The byte offset of its opening delimiter, which a ``MacTapGuard/drawnOnlyWhen(_:)``
            /// check walks back from.
            var offset = 0
        }

        /// What one file's scan found.
        struct FileResult: Sendable {
            /// Literals the Mac compiles that say tap in a clause that does not say click.
            var sites: [Site] = []
            /// Lines of literals the Mac compiles that name the `hand.tap` symbol.
            var glyphs: [Int] = []
            /// In-scope text literals read, whether or not the Mac compiles them.
            var literalsRead = 0
            /// In-scope text literals the Mac compiles.
            var literalsCompiled = 0
            /// Research Guide literals read — outside `CopyScan`'s scope, so counted apart.
            var guideLiteralsRead = 0
            /// In-scope text literals read under each gate kind.
            var literalEvents: [Gate: Int] = [:]
            /// Non-blank code lines decided under each gate kind.
            var lineEvents: [Gate: Int] = [:]
        }

        /// The gate kinds that describe a line enclosed by `branches`, in a file whose code is all
        /// inside one gate when `fileWide`.
        static func gates(of branches: [CompilationBranches.Branch], fileWide: Bool) -> [Gate] {
            let iOSOnly: Set<String> = ["os(iOS)", "canImport(UIKit)"]
            let macOnly: Set<String> = ["os(macOS)", "canImport(AppKit)"]
            var kinds: [Gate] = []
            if let innermost = branches.last {
                if innermost.keyword == "else" {
                    if !innermost.earlier.isEmpty, innermost.earlier.allSatisfy(iOSOnly.contains) {
                        kinds.append(.elseOfIOS)
                    } else if !innermost.earlier.isEmpty, innermost.earlier.allSatisfy(macOnly.contains) {
                        kinds.append(.elseOfMacOS)
                    } else {
                        kinds.append(.other)
                    }
                } else {
                    switch innermost.condition {
                    case "os(iOS)": kinds.append(.iOS)
                    case "canImport(UIKit)": kinds.append(.uiKit)
                    case "os(macOS)": kinds.append(.macOS)
                    case "!os(iOS)": kinds.append(.notIOS)
                    case "canImport(AppKit)": kinds.append(.appKit)
                    default: kinds.append(.other)
                    }
                }
            } else {
                kinds.append(.ungated)
            }
            if branches.count >= 2 { kinds.append(.nested) }
            if fileWide { kinds.append(.fileWide) }
            return kinds
        }

        /// Whether `literal` is the argument of a label naming an SF Symbol (`systemImage:`).
        static func isSymbolName(_ literal: LexedSource.Literal, in lexed: LexedSource) -> Bool {
            isArgument(literal, labelledOneOf: symbolLabels, in: lexed)
        }

        /// Whether `literal` is Research Guide prose: a literal whose innermost call is a guide
        /// initialiser — directly, or as an element of one of its arrays — other than an `id:`.
        static func isGuideProse(_ literal: LexedSource.Literal, in lexed: LexedSource) -> Bool {
            guard let callee = literal.callee, guideInitialisers.contains(callee) else { return false }
            return !isArgument(literal, labelledOneOf: guideIdentifierLabels, in: lexed)
        }

        /// Whether the code right before `literal`, less whitespace, is one of `labels` as a whole
        /// word (`systemImage:`, but not `mySystemImage:`).
        static func isArgument(_ literal: LexedSource.Literal, labelledOneOf labels: [String],
                               in lexed: LexedSource) -> Bool {
            var end = literal.range.lowerBound - 1
            while end >= 0, [0x20, 0x09, 0x0A, 0x0D].contains(lexed.masked[end]) { end -= 1 }
            return labels.contains { label in
                let bytes = Array(label.utf8)
                let start = end - bytes.count + 1
                guard start >= 0, Array(lexed.masked[start...end]) == bytes else { return false }
                guard start > 0 else { return true }
                let before = lexed.masked[start - 1]
                let isName = (before >= 0x30 && before <= 0x39) || (before >= 0x41 && before <= 0x5A)
                    || (before >= 0x61 && before <= 0x7A) || before == 0x5F || before == 0x2E
                return !isName
            }
        }

        /// `literal`'s text with each interpolation's code left out, so "tap" in code is not text.
        static func text(of literal: LexedSource.Literal) -> String {
            literal.segments.map { segment -> String in
                switch segment {
                case .text(let text): return text
                case .interpolation: return " "
                }
            }.joined()
        }

        /// `text`'s clauses: split at each `clauseBreak`.
        static func clauses(of text: String) -> [String] {
            let whole = NSRange(text.startIndex..., in: text)
            var clauses: [String] = []
            var start = text.startIndex
            for stop in clauseBreak.matches(in: text, range: whole) {
                guard let range = Range(stop.range, in: text) else { continue }
                clauses.append(String(text[start..<range.lowerBound]))
                start = range.upperBound
            }
            clauses.append(String(text[start...]))
            return clauses
        }

        /// Whether `clause` says tap, in any of `tapWord`'s forms.
        static func saysTap(_ clause: String) -> Bool {
            tapWord.firstMatch(in: clause, range: NSRange(clause.startIndex..., in: clause)) != nil
        }

        /// Whether a clause of `text` says tap without saying click.
        static func saysTapNotClick(_ text: String) -> Bool {
            clauses(of: text).contains { clause in
                saysTap(clause)
                    && clickWord.firstMatch(in: clause, range: NSRange(clause.startIndex..., in: clause)) == nil
            }
        }

        /// Scans one lexed file as the Mac compiles it.
        static func scan(_ lexed: LexedSource) -> FileResult {
            let branches = CompilationBranches(masked: lexed.masked, platform: .macOS)
            let fileWide = branches.fileWideBlock != nil
            var result = FileResult()
            for (index, line) in branches.lines.enumerated() where !line.isDirective {
                let code = lexed.masked[branches.lineRanges[index]]
                guard code.contains(where: { $0 != 0x20 && $0 != 0x09 && $0 != 0x0D }) else { continue }
                for gate in gates(of: line.branches, fileWide: fileWide) {
                    result.lineEvents[gate, default: 0] += 1
                }
            }
            for literal in lexed.literals {
                let line = branches.line(literal.line)
                // `nil` is a condition this reading cannot decide, such as `DEBUG`: a Mac build can
                // ship it, so it is read as compiled.
                let compiled = line?.compiled != false
                let symbol = isSymbolName(literal, in: lexed)
                if compiled, literal.sourceText == tapGlyph || literal.sourceText.hasPrefix(tapGlyph + ".") {
                    result.glyphs.append(literal.line)
                }
                let inScope = CopyScan.isInScope(literal)
                let guide = !inScope && isGuideProse(literal, in: lexed)
                guard inScope || guide, !symbol else { continue }
                if guide {
                    result.guideLiteralsRead += 1
                } else {
                    result.literalsRead += 1
                    for gate in gates(of: line?.branches ?? [], fileWide: fileWide) {
                        result.literalEvents[gate, default: 0] += 1
                    }
                }
                guard compiled else { continue }
                if !guide { result.literalsCompiled += 1 }
                if saysTapNotClick(text(of: literal)) {
                    result.sites.append(Site(line: literal.line, key: lexed.key(of: literal),
                                             text: literal.sourceText, offset: literal.range.lowerBound))
                }
            }
            return result
        }

        // MARK: The exceptions' checks

        /// One place a type is constructed.
        struct ConstructionSite: Sendable {
            /// The file, under `FRUSExplorer/`.
            let path: String
            /// The 1-based line.
            let line: Int
            /// Whether the Mac compiles that line (`nil`: a condition it cannot decide).
            let compiledOnMac: Bool?
        }

        /// Every construction of each of `types` in `files`: the type's name, not preceded by an
        /// identifier character, followed by `(` on the same line of code — comments and strings
        /// blanked first, so a name in either is not one.
        static func constructionSites(of types: Set<String>,
                                      in files: [(path: String, source: LexedSource)]) -> [String: [ConstructionSite]] {
            let patterns = types.compactMap { type -> (String, NSRegularExpression)? in
                let escaped = NSRegularExpression.escapedPattern(for: type)
                guard let regex = try? NSRegularExpression(pattern: #"(?<![A-Za-z0-9_])"# + escaped + #"\s*\("#)
                else { return nil }
                return (type, regex)
            }
            var found: [String: [ConstructionSite]] = [:]
            for type in types { found[type] = [] }
            for (path, lexed) in files {
                let code = String(decoding: lexed.masked, as: UTF8.self)
                let candidates = patterns.filter { code.contains($0.0) }
                guard !candidates.isEmpty else { continue }
                let branches = CompilationBranches(masked: lexed.masked, platform: .macOS)
                for (index, line) in code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    let text = String(line)
                    for (type, regex) in candidates
                    where regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                        found[type, default: []].append(ConstructionSite(
                            path: path, line: index + 1, compiledOnMac: branches.line(index + 1)?.compiled))
                    }
                }
            }
            return found
        }

        /// Why `holds` does not hold for `site` in the file `lexed` at `path`, or `nil` when it does.
        /// A construction check reads `constructions` (from ``constructionSites(of:in:)`` over the
        /// tree); the other two read the file and the site.
        static func failure(of holds: MacTapGuard, site: Site, path: String, in lexed: LexedSource,
                            constructions: [String: [ConstructionSite]]) -> String? {
            switch holds {
            case .neverConstructedOnMac(let type, let except):
                let onMac = (constructions[type] ?? []).filter { $0.path != except && $0.compiledOnMac != false }
                guard !onMac.isEmpty else { return nil }
                return "the Mac compiles a construction of \(type) at "
                    + onMac.map { "\($0.path):\($0.line)" }.joined(separator: ", ")
            case .drawnOnlyWhen(let flag):
                guard opensIf(flag, around: site.offset, in: lexed) else {
                    return "the literal at line \(site.line) is not directly inside `if \(flag) {`"
                }
                let value = macBody(ofFlag: flag, in: lexed)
                guard value == "false" else {
                    return "`\(flag)` reads \(value.map { "`\($0)`" } ?? "nothing this file declares") on the Mac, not `false`"
                }
                return nil
            case .namesMacGesture(let word):
                let tapping = clauses(of: site.text).filter(saysTap)
                guard !tapping.isEmpty, tapping.allSatisfy({ $0.lowercased().contains(word) }) else {
                    return "a clause says tap without naming \(word): \(tapping.joined(separator: " / "))"
                }
                return nil
            }
        }

        /// Whether the innermost `{` enclosing `offset` opens `if <flag> {`.
        static func opensIf(_ flag: String, around offset: Int, in lexed: LexedSource) -> Bool {
            let open = UInt8(ascii: "{"), close = UInt8(ascii: "}")
            var depth = 0, k = offset - 1
            while k >= 0 {
                if lexed.masked[k] == close {
                    depth += 1
                } else if lexed.masked[k] == open {
                    if depth == 0 { break }
                    depth -= 1
                }
                k -= 1
            }
            guard k >= 0 else { return false }
            let before = String(decoding: lexed.masked[..<k], as: UTF8.self)
            let pattern = #"(?:^|[^A-Za-z0-9_])if\s+"# + NSRegularExpression.escapedPattern(for: flag) + #"\s*$"#
            return before.range(of: pattern, options: .regularExpression) != nil
        }

        /// The code of `var <flag>: Bool { … }`'s body in `lexed` as the Mac compiles it, its lines
        /// trimmed and joined by spaces — `false` for `SettingsView.isPhone` — or `nil` when the
        /// file declares no such property.
        static func macBody(ofFlag flag: String, in lexed: LexedSource) -> String? {
            let code = String(decoding: lexed.masked, as: UTF8.self)
            let pattern = #"(?<![A-Za-z0-9_])var\s+"# + NSRegularExpression.escapedPattern(for: flag)
                + #"\s*:\s*Bool\s*\{"#
            guard let match = code.range(of: pattern, options: .regularExpression) else { return nil }
            // `masked` is `code`'s bytes, so a UTF-8 offset into one is an index into the other.
            let bodyStart = code.utf8.distance(from: code.startIndex, to: match.upperBound)
            var depth = 1, end = bodyStart
            while end < lexed.masked.count {
                if lexed.masked[end] == UInt8(ascii: "{") { depth += 1 }
                if lexed.masked[end] == UInt8(ascii: "}") {
                    depth -= 1
                    if depth == 0 { break }
                }
                end += 1
            }
            let branches = CompilationBranches(masked: lexed.masked, platform: .macOS)
            var parts: [String] = []
            for (index, range) in branches.lineRanges.enumerated() {
                let lower = max(range.lowerBound, bodyStart), upper = min(range.upperBound, end)
                guard lower < upper, !branches.lines[index].isDirective,
                      branches.lines[index].compiled != false else { continue }
                let part = String(decoding: lexed.masked[lower..<upper], as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !part.isEmpty { parts.append(part) }
            }
            return parts.joined(separator: " ")
        }
    }
}

// MARK: - LexedSource

extension CodingStandardsAuditTests {

    /// One Swift source file as the audit scans read it: every comment and string literal's
    /// contents blanked in `masked`, and every string literal recorded with the call it sits in.
    ///
    /// `maskedCode(_:)` is this type's `masked`. Before the two were one, the hover scan's lexer
    /// and this one were compared over the whole app tree — 479 files, byte-identical masks —
    /// so the hover scan's fixtures and its tree-wide balance check now pin both scans' reading
    /// of comments, strings, raw strings and interpolations.
    struct LexedSource {

        /// One piece of a string literal.
        enum Segment: Equatable {
            /// Literal text exactly as the source spells it, escapes included.
            case text(String)
            /// The code inside a `\( … )`.
            case interpolation(String)
        }

        /// One string literal and where it sits.
        struct Literal {
            /// From the opening delimiter's first byte (its `#`s included) to one past the closing one.
            var range: Range<Int>
            /// The 1-based line of the opening delimiter.
            var line: Int
            /// The literal's pieces, in order.
            var segments: [Segment]
            /// Whether the code before it, less whitespace, ends `defaultValue:`.
            var isDefaultValue: Bool
            /// The dotted name spelled directly before the innermost `(` enclosing the literal in
            /// its own code — `Text`, `String`, `CountCopy.phrase`, `.help` — or `nil` outside any
            /// call. Braces do not count, so a literal in a closure inside `Text(…)` is `Text`'s.
            var callee: String?
            /// Whether that call's argument list opens with `verbatim:`.
            var calleeIsVerbatim: Bool
            /// The index in `literals` of the first literal directly inside that call, when that is
            /// not this one — for a `defaultValue:`, its `String(localized:)` key.
            var keyIndex: Int?

            /// The literal's contents as the source spells them: text as written, each
            /// interpolation as `\(code)`.
            var sourceText: String {
                segments.map { segment -> String in
                    switch segment {
                    case .text(let text): return text
                    case .interpolation(let code): return "\\(" + code + ")"
                    }
                }.joined()
            }
        }

        /// The file with every comment and string literal's contents replaced by spaces (newlines
        /// kept), and the `\(` and `)` around each interpolation blanked with them.
        let masked: [UInt8]
        /// Every string literal in the file, in the order they open.
        let literals: [Literal]

        /// The string key `literal` is filed under: its call's first literal when it is a
        /// `defaultValue:` with one, and otherwise its own text.
        func key(of literal: Literal) -> String {
            if literal.isDefaultValue, let index = literal.keyIndex {
                return literals[index].sourceText
            }
            return literal.sourceText
        }

        /// Lexes `source`.
        init(_ source: String) {
            enum Context {
                case code(frames: [Frame])
                case string(hashes: Int, multiline: Bool, literal: Int)
            }
            struct Frame {
                var callee: String?
                var verbatim: Bool
                var firstLiteral: Int?
            }
            let bytes = Array(source.utf8)
            var out = bytes
            var literals: [Literal] = []
            var lineStarts = [0]
            for (k, b) in bytes.enumerated() where b == 0x0A { lineStarts.append(k + 1) }
            func line(of offset: Int) -> Int {
                var lo = 0, hi = lineStarts.count - 1
                while lo < hi {
                    let mid = (lo + hi + 1) / 2
                    if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
                }
                return lo + 1
            }
            var stack: [Context] = [.code(frames: [])]
            // Where each open interpolation's code began, innermost last.
            var interpolationStarts: [Int] = []
            // The text being collected for each open literal, innermost last.
            var pendingText: [[UInt8]] = []
            var i = 0
            func blank(_ range: Range<Int>) {
                for k in range where k < out.count && out[k] != 0x0A { out[k] = 0x20 }
            }
            func byte(_ k: Int) -> UInt8? { k < bytes.count ? bytes[k] : nil }
            func isNameByte(_ b: UInt8) -> Bool {
                (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
                    || b == 0x5F || b == 0x2E
            }
            func isSpace(_ b: UInt8) -> Bool { b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D }
            func flushText(into literal: Int) {
                guard let text = pendingText.last, !text.isEmpty else { return }
                literals[literal].segments.append(.text(String(decoding: text, as: UTF8.self)))
                pendingText[pendingText.count - 1] = []
            }
            let slash = UInt8(ascii: "/"), star = UInt8(ascii: "*"), quote = UInt8(ascii: "\"")
            let hash = UInt8(ascii: "#"), backslash = UInt8(ascii: "\\")
            let open = UInt8(ascii: "("), close = UInt8(ascii: ")")
            let defaultValueLabel = Array("defaultValue:".utf8), verbatimLabel = Array("verbatim:".utf8)
            while i < bytes.count {
                guard let context = stack.last else { break }
                switch context {
                case .code(var frames):
                    let c = bytes[i]
                    if c == slash, byte(i + 1) == slash {
                        var end = i
                        while end < bytes.count, bytes[end] != 0x0A { end += 1 }
                        blank(i..<end)
                        i = end
                    } else if c == slash, byte(i + 1) == star {
                        var depth = 0, end = i
                        while end < bytes.count {
                            if bytes[end] == slash, byte(end + 1) == star { depth += 1; end += 2 }
                            else if bytes[end] == star, byte(end + 1) == slash {
                                depth -= 1; end += 2
                                if depth == 0 { break }
                            } else { end += 1 }
                        }
                        blank(i..<end)
                        i = end
                    } else if c == hash || c == quote {
                        var j = i, hashes = 0
                        while byte(j) == hash { hashes += 1; j += 1 }
                        guard byte(j) == quote else { i = j; continue }   // `#if`, `#available`
                        let multiline = byte(j + 1) == quote && byte(j + 2) == quote
                        // What sits before the literal: the label it answers.
                        var p = i - 1
                        while p >= 0, isSpace(bytes[p]) { p -= 1 }
                        let labelStart = p - defaultValueLabel.count + 1
                        let isDefault = labelStart >= 0
                            && Array(bytes[labelStart...p]) == defaultValueLabel
                            && (labelStart == 0 || !isNameByte(bytes[labelStart - 1]))
                        let index = literals.count
                        literals.append(Literal(range: i..<i, line: line(of: i), segments: [],
                                                isDefaultValue: isDefault,
                                                callee: frames.last?.callee,
                                                calleeIsVerbatim: frames.last?.verbatim ?? false,
                                                keyIndex: frames.last?.firstLiteral))
                        if !frames.isEmpty, frames[frames.count - 1].firstLiteral == nil {
                            frames[frames.count - 1].firstLiteral = index
                            stack[stack.count - 1] = .code(frames: frames)
                        }
                        pendingText.append([])
                        i = j + (multiline ? 3 : 1)
                        stack.append(.string(hashes: hashes, multiline: multiline, literal: index))
                    } else if c == open {
                        // The call this parenthesis opens: the dotted name spelled right before it.
                        var n = i
                        while n > 0, isNameByte(bytes[n - 1]) { n -= 1 }
                        var a = i + 1
                        while a < bytes.count, isSpace(bytes[a]) { a += 1 }
                        let verbatim = a + verbatimLabel.count <= bytes.count
                            && Array(bytes[a..<a + verbatimLabel.count]) == verbatimLabel
                        frames.append(Frame(callee: n < i ? String(decoding: bytes[n..<i], as: UTF8.self) : nil,
                                            verbatim: verbatim, firstLiteral: nil))
                        stack[stack.count - 1] = .code(frames: frames)
                        i += 1
                    } else if c == close {
                        if frames.isEmpty, stack.count > 1 {
                            // The `)` that closes an interpolation: blanked with its `\(`, so the
                            // masked copy's parentheses stay balanced.
                            blank(i..<i + 1)
                            stack.removeLast()
                            let start = interpolationStarts.removeLast()
                            if case .string(_, _, let literal) = stack.last {
                                literals[literal].segments.append(
                                    .interpolation(String(decoding: bytes[start..<i], as: UTF8.self)))
                            }
                        } else {
                            if !frames.isEmpty { frames.removeLast() }
                            stack[stack.count - 1] = .code(frames: frames)
                        }
                        i += 1
                    } else {
                        i += 1
                    }
                case .string(let hashes, let multiline, let literal):
                    let c = bytes[i]
                    if c == backslash {
                        var j = i + 1, seen = 0
                        while seen < hashes, byte(j) == hash { seen += 1; j += 1 }
                        if seen == hashes, byte(j) == open {
                            blank(i..<j + 1)
                            flushText(into: literal)
                            i = j + 1
                            interpolationStarts.append(i)
                            stack.append(.code(frames: []))
                        } else if hashes == 0 {
                            blank(i..<i + 2)   // an escape: `\"` must not close the string
                            pendingText[pendingText.count - 1] += bytes[i..<min(i + 2, bytes.count)]
                            i += 2
                        } else {
                            blank(i..<i + 1)
                            pendingText[pendingText.count - 1].append(c)
                            i += 1
                        }
                    } else if c == quote,
                              !multiline || (byte(i + 1) == quote && byte(i + 2) == quote) {
                        let quoteEnd = i + (multiline ? 3 : 1)
                        var j = quoteEnd, seen = 0
                        while seen < hashes, byte(j) == hash { seen += 1; j += 1 }
                        if seen == hashes {
                            flushText(into: literal)
                            pendingText.removeLast()
                            literals[literal].range = literals[literal].range.lowerBound..<j
                            stack.removeLast()
                            i = j
                        } else {
                            blank(i..<i + 1)
                            pendingText[pendingText.count - 1].append(c)
                            i += 1
                        }
                    } else {
                        blank(i..<i + 1)
                        pendingText[pendingText.count - 1].append(c)
                        i += 1
                    }
                }
            }
            self.masked = out
            self.literals = literals
        }
    }
}
