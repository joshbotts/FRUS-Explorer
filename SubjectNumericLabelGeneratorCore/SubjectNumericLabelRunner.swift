// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import PDFKit

// MARK: - GenerationError

/// A refusal to write, carrying the measurement that caused it.
struct GenerationError: Error, CustomStringConvertible {
    /// What went wrong, in words a maintainer can act on.
    let description: String
}

// MARK: - SubjectNumericLabelRunner

/// Builds `subject-numeric-labels.json` from the Department's own filing handbooks (#1211).
///
/// The subject-numeric system replaced the decimal file and the app has no label table for it at
/// all, so every key renders bare. This reads the two handbooks the owner supplied.
///
/// ## Two editions, and they are not interchangeable
/// The 1965 handbook renumbers subdivisions inside the categories the corpus leans on hardest.
/// Measured: `POL 24` is **SUBVERSION. ESPIONAGE.** in the 1963 outline and **SANCTIONS** in the
/// 1965 one, with subversion moved to `POL 23-7`. POL alone carries 66% of the corpus's
/// subject-numeric documents, so a single merged table would mislabel the most-cited category in
/// the vocabulary. This is the 1950 decimal renumbering again, and it is handled the same way: two
/// schedules, and a coverage span that straddles them is refused rather than guessed.
///
/// Version history:
///   1.0 — #1211: initial implementation
public enum SubjectNumericLabelRunner {

    // MARK: Sources

    /// One handbook edition.
    struct Source {
        /// Schedule id, also the artifact key.
        let id: String
        /// The years this edition's arrangement governs.
        let start: Int
        let end: Int
        /// File name under `SCHEDULE_DIR`.
        let fileName: String
        /// The title to credit in the artifact.
        let title: String
        /// Where this edition prints its instruction text.
        let layout: OutlinePageLayout.Layout
    }

    /// The two editions, in force order.
    ///
    /// The spans are the arrangement's, not the printing's, and neither manual states them —
    /// so both are sourced and the sourcing is carried into the artifact rather than left in a
    /// commit message. 1963 opens on the handbook's own effective date ("The new file system
    /// became effective in the Department's central file on February 1, 1963"). The 1965 edition
    /// takes 1964 from NARA's published guidance that its arrangement went into effect in January
    /// 1964, which the handbook's own transmittal corroborates: its POL/CSM/INT/SCI renumbering was
    /// issued by circular CA-6685 of 7 January 1964 and only INCORPORATED here.
    static let sources: [Source] = [
        Source(id: "1963", start: 1963, end: 1963,
               fileName: "records-classification-handbook-1963.pdf",
               title: "Records Classification Handbook (Department of State, March 1963)",
               layout: .rightColumn),
        Source(id: "1964-1973", start: 1964, end: 1973,
               fileName: "dos-records-classification-handbook-1965-1973.pdf",
               title: "Records Classification Handbook (Department of State, 1965)",
               layout: .indent),
    ]

    // MARK: Run

    /// Runs the generator.
    ///
    /// - Parameter environment: Process environment.
    /// - Throws: ``GenerationError`` when a parse misses a measured floor.
    public static func run(environment: [String: String]) throws {
        let scheduleDir = environment["SCHEDULE_DIR"]
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads").path
        let diagnose = environment["DIAGNOSE"] == "1"

        var schedules: [Schedule] = []
        for source in sources {
            let path = "\(scheduleDir)/\(source.fileName)"
            guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
                throw GenerationError(description: "cannot open \(path)")
            }
            let outlines = readOutlines(document, layout: source.layout)
            let names = readCategoryNames(document)
            let organizations = readAdministrativeSubjects(document, layout: source.layout)
            let abbreviations = readAbbreviations(document)
            let areaPairs = CountryAbbreviationReader.pairs(in: document)
            let areas = CountryAbbreviationReader.canonicalNames(from: areaPairs)
            let total = outlines.values.reduce(0) { $0 + $1.count }
            print("[SubjectNumericLabels] \(source.id): \(outlines.count) categories, "
                  + "\(names.count) named, \(total) designators, "
                  + "\(organizations.count) organization subjects, "
                  + "\(abbreviations.count) abbreviations, "
                  + "\(areas.count) areas from \(areaPairs.count) rows")
            schedules.append(Schedule(id: source.id, startYear: source.start,
                                      endYear: source.end, source: source.title,
                                      categories: names, subjects: outlines,
                                      organizationSubjects: organizations,
                                      abbreviations: abbreviations, areas: areas))
            if diagnose {
                for code in outlines.keys.sorted() {
                    let entries = outlines[code] ?? [:]
                    print("    \(code): \(entries.count)")
                }
                for code in ["POL", "DEF", "CON"] {
                    guard let entries = outlines[code] else { continue }
                    print("  --- \(code) ---")
                    for key in entries.keys.sorted(by: designatorOrder) {
                        print("    \(key)  \(entries[key] ?? "")")
                    }
                }
            }
        }
        let usagePath = environment["COLLECTION_USAGE_INDEX"]
            ?? "FRUSExplorer/Resources/collection-usage-index.json"
        let measurements = try measure(schedules, usagePath: usagePath)

        // FLOORS. Both are read off this build and set below it, because the failure they exist to
        // catch is a parse that quietly stops working — a corner-mark rule that no longer matches,
        // a column cut that lands inside a label — and every such failure shows up as a COLLAPSE in
        // reach, not as an error. A schedule that read a third of the corpus would still encode and
        // still ship.
        for measurement in measurements {
            guard measurement.namedKeys >= minimumNamedKeys else {
                throw GenerationError(description:
                    "\(measurement.scheduleId) names only \(measurement.namedKeys) of "
                    + "\(measurement.corpusKeys) corpus keys (floor \(minimumNamedKeys)) — "
                    + "the outline parse has regressed; do not ship a table this thin")
            }
        }

        let unnamed = measurements.flatMap(\.unnamed).reduce(into: Set<String>()) { $0.insert($1) }
        let artifact = SubjectNumericLabels(
            schemaVersion: 1,
            generated: environment["GENERATED_DATE"] ?? Self.today(),
            provenance: provenanceNote,
            schedules: schedules.sorted { $0.startYear < $1.startYear },
            coverage: .init(
                systemOpensIn: 1963,
                glossableYears: schedules.map {
                    .init(scheduleId: $0.id, startYear: $0.startYear, endYear: $0.endYear)
                },
                keyOutsideGlossableYears: "no-gloss",
                unnamedCategories: unnamed.sorted(),
                measured: measurements.map {
                    .init(scheduleId: $0.scheduleId, corpusKeys: $0.corpusKeys,
                          namedKeys: $0.namedKeys, corpusDocuments: $0.corpusDocuments,
                          namedDocuments: $0.namedDocuments)
                },
                note: coverageNote))

        let output = environment["OUTPUT"]
            ?? "FRUSExplorer/Resources/subject-numeric-labels.json"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(artifact).write(to: URL(fileURLWithPath: output))
        print("[SubjectNumericLabels] wrote \(output)")
    }

    /// The floor each schedule's corpus reach must clear.
    static let minimumNamedKeys = 800

    /// What the artifact says about itself.
    static let provenanceNote = """
        Parsed from the Department of State's own Records Classification Handbooks (March 1963 \
        and 1965), which stay local by owner decision. Category names and subject headings are \
        reproduced with the manuals' own capitalisation. The two editions are NOT \
        interchangeable: the 1965 edition renumbers subdivisions inside the categories the \
        corpus cites most, so POL 24 is SUBVERSION. ESPIONAGE. in 1963 and SANCTIONS in 1965.
        """

    /// The caveat every surface reading this table owes a reader.
    static let coverageNote = """
        A key outside every span yields no gloss, and a coverage span that straddles two \
        schedules yields none either — the same rule the decimal table applies across the 1950 \
        renumbering, and for the same reason. An ORGANIZATION file (UN, NATO, CENTO) is not a \
        primary subject: it is read from the international-organizations instruction's LIST OF \
        ADMINISTRATIVE SUBJECTS, under the name the handbook's abbreviations appendix gives the \
        prefix. A prefix absent from that appendix is REFUSED rather than read from the list, \
        because it would fit: three of the categories in unnamedCategories (NSSD, FG, PSL) are \
        not central-file classes at all. This table names the GROUP only. Measured, 90.4% of the \
        corpus's subject-numeric keys carry a trailing country or party string (VIET S, ARAB- \
        ISR) drawn from the handbooks' country-abbreviations appendix, which this build does not \
        read — so a surface showing POL 27 VIET S as MILITARY OPERATIONS and stopping there has \
        named half the key and must show the rest as printed.
        """

    /// Today, in the artifact's date format.
    static func today() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: Measurement

    /// Reports what the parsed tables would actually read, against the corpus that has to be read.
    ///
    /// The manuals' own counts are the wrong denominator. What matters is the share of the keys
    /// FRUS's editors cited, and those are not distributed like the handbook: fifteen of the fifty
    /// category tokens in the corpus are not primary subjects at all, and the ones that are lean
    /// overwhelmingly on POL and DEF.
    ///
    /// - Parameters:
    ///   - schedules: The parsed schedules.
    ///   - usagePath: Path to `collection-usage-index.json`.
    /// - Throws: When the usage index cannot be read.
    static func measure(_ schedules: [Schedule], usagePath: String) throws -> [Reach] {
        let data = try Data(contentsOf: URL(fileURLWithPath: usagePath))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = object["classKeys"] as? [String],
              let rows = object["classes"] as? [[String: Any]]
        else { throw GenerationError(description: "cannot read \(usagePath)") }
        // `v` is the volume index and `n` the document count. The letters read the other way round
        // and a swapped sum is plausible rather than absurd, so the mapping is stated here.
        var documents: [String: Int] = [:]
        for row in rows {
            guard let index = row["k"] as? Int, index < keys.count,
                  let counts = row["n"] as? [Int] else { continue }
            documents[keys[index], default: 0] += counts.reduce(0, +)
        }
        var out: [Reach] = []
        for schedule in schedules {
            var namedGroups = 0, namedDocuments = 0, groups = 0, total = 0
            var missingCategories: Set<String> = []
            for (key, count) in documents {
                guard let (category, designator) = splitSubjectNumeric(key) else { continue }
                groups += 1
                total += count
                if schedule.subject(category: category, designator: designator) != nil {
                    namedGroups += 1
                    namedDocuments += count
                } else if schedule.categories[category] == nil,
                          schedule.subjects[category] == nil,
                          schedule.abbreviations[category] == nil {
                    missingCategories.insert(category)
                }
            }
            // TAIL COVERAGE, measured separately: it is a different question from whether the
            // subject is named, and averaging the two would hide whichever is worse.
            var tails = 0, namedTails = 0, tailDocuments = 0, namedTailDocuments = 0
            var unresolvedTails: [String: Int] = [:]
            for (key, count) in documents {
                guard let tail = Self.tail(of: key), !tail.isEmpty else { continue }
                tails += 1
                tailDocuments += count
                let code = CountryAbbreviationReader.normalizedCode(tail)
                let reversed = code.split(separator: " ").reversed().joined(separator: " ")
                if schedule.areas[code] != nil {
                    namedTails += 1
                    namedTailDocuments += count
                } else if schedule.areas[reversed] != nil {
                    namedTails += 1
                    namedTailDocuments += count
                } else {
                    unresolvedTails[tail, default: 0] += count
                }
            }
            print(String(format: "    tails: %d of %d keys named, %d of %d documents (%.1f%%)",
                         namedTails, tails, namedTailDocuments, tailDocuments,
                         tailDocuments == 0 ? 0
                             : Double(namedTailDocuments) / Double(tailDocuments) * 100))
            let worst = unresolvedTails.sorted { $0.value > $1.value }.prefix(15)
            print("    heaviest unresolved tails: "
                  + worst.map { "\($0.key)(\($0.value))" }.joined(separator: " "))
            let share = total == 0 ? 0 : Double(namedDocuments) / Double(total) * 100
            print(String(format: "[SubjectNumericLabels] %@ reads %d of %d corpus keys, "
                         + "%d of %d documents (%.1f%%)",
                         schedule.id, namedGroups, groups, namedDocuments, total, share))
            print("    categories the corpus cites and this schedule cannot name: "
                  + missingCategories.sorted().joined(separator: " "))
            out.append(Reach(scheduleId: schedule.id, corpusKeys: groups, namedKeys: namedGroups,
                             corpusDocuments: total, namedDocuments: namedDocuments,
                             unnamed: missingCategories.sorted()))
        }
        return out
    }

    /// One schedule's measured reach over the shipped corpus.
    struct Reach {
        let scheduleId: String
        let corpusKeys: Int
        let namedKeys: Int
        let corpusDocuments: Int
        let namedDocuments: Int
        let unnamed: [String]
    }

    /// Splits a corpus class key into its category and designator, or `nil` when it is not
    /// subject-numeric.
    ///
    /// Mirrors `CollectionKeying.subjectNumericGroup`'s anchored match, then divides the group at
    /// the space. The group is a LITERAL prefix of the key by that rule, so `DEF1-1` divides to
    /// (`DEF`, `1-1`) and looks the same table row up as `DEF 1-1` without the fold having to
    /// rewrite the key — which #841 forbids.
    ///
    /// - Parameter key: A class key as a source note wrote it.
    /// - Returns: `("POL", "27")`, or `nil`.
    static func splitSubjectNumeric(_ key: String) -> (String, String)? {
        guard let match = groupRegex.firstMatch(
                in: key, range: NSRange(key.startIndex..., in: key)),
              let category = Range(match.range(at: 1), in: key),
              let number = Range(match.range(at: 2), in: key)
        else { return nil }
        return (String(key[category]).uppercased(),
                String(key[number]).replacingOccurrences(
                    of: #"\s"#, with: "", options: .regularExpression))
    }

    /// Whatever follows a key's group — the country or organization the file is arranged under.
    ///
    /// - Parameter key: A class key as a source note wrote it.
    /// - Returns: The tail, or `nil` when the key is not subject-numeric.
    static func tail(of key: String) -> String? {
        guard let match = groupRegex.firstMatch(
                in: key, range: NSRange(key.startIndex..., in: key)),
              let whole = Range(match.range, in: key)
        else { return nil }
        return String(key[whole.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    /// Category letters, an optional parenthesised agency qualifier, then the number.
    private static let groupRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^([A-Z]{1,6})(?:\s*\([^)]*\))?\s*(\d+(?:-\d+)*)"#)
    }()

    // MARK: Category names

    /// Each category's own name, taken from the running heads that name it.
    ///
    /// A category is printed across many pages and the scan damages different heads differently, so
    /// the name kept is the one printed MOST OFTEN — a majority vote over the book rather than
    /// whichever page happened to be read first.
    ///
    /// - Parameter document: An open handbook.
    /// - Returns: `code -> name`.
    static func readCategoryNames(_ document: PDFDocument) -> [String: String] {
        var votes: [String: [String: Int]] = [:]
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let head = OutlinePageReader.runningHead(of: page) else { continue }
            let label = OutlineEntryParser.tidy(head.label)
            guard !label.isEmpty else { continue }
            votes[head.code.uppercased(), default: [:]][label, default: 0] += 1
        }
        return votes.compactMapValues { tally in
            // Ties break toward the longer name: the scan drops characters far more often than it
            // invents them, so the fuller reading is the likelier printing.
            tally.max { ($0.value, $0.key.count) < ($1.value, $1.key.count) }?.key
        }
    }

    // MARK: Outlines

    /// Every category's designator table, keyed by category code.
    ///
    /// Pages are attributed to a category by the corner mark (`POL (p. 7)`) rather than by the
    /// running head: measured over the 1963 handbook, the corner survives on 233 of 266 outline
    /// pages against 143 for the head, and three categories — `V`, `OS`, `SOC` — have no surviving
    /// head anywhere in the book.
    ///
    /// - Parameter document: An open handbook.
    /// - Returns: `code -> designator -> label`.
    static func readOutlines(_ document: PDFDocument,
                             layout: OutlinePageLayout.Layout) -> [String: [String: String]] {
        // PASS ONE establishes the vocabulary from the pages whose corner mark or running head
        // survived; PASS TWO uses it to attribute the pages where both were destroyed. The order is
        // the safety argument — a code is only ever carried to a page that names it.
        var codes: [Int: String] = [:]
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let corner = OutlinePageReader.cornerCode(of: page) else { continue }
            let code = corner.code.uppercased()
            guard code != "INDEX", code != "INTROD" else { continue }
            codes[index] = code
        }
        let known = Set(codes.values)
        for index in 0..<document.pageCount where codes[index] == nil {
            guard let page = document.page(at: index),
                  let code = OutlinePageReader.vocabularyCode(of: page, known: known)
            else { continue }
            codes[index] = code
        }

        var out: [String: [String: String]] = [:]
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let code = codes[index] else { continue }
            let all = OutlinePageReader.lines(of: page, maxX: .greatestFiniteMagnitude)
            for column in OutlinePageLayout.columns(of: page, layout: layout) {
                // Two points inside the measured indent. The margin is small on purpose: the 1965
                // edition's entry and instruction columns are sixteen points apart, so a generous
                // one would take the instructions with the labels.
                let lines = all.filter { $0.x >= column.minX && $0.x < column.instructionX - 2 }
                let parsed = OutlineEntryParser.parse(lines, footerFloor: 100)
                for entry in parsed.entries where out[code]?[entry.designator] == nil {
                    out[code, default: [:]][entry.designator] = entry.label
                }
            }
        }
        return out
    }

    // MARK: International organizations

    /// The `LIST OF ADMINISTRATIVE SUBJECTS` from the handbooks' international-organizations
    /// special instruction.
    ///
    /// ## Why this is a SEPARATE table and not fifteen more categories
    /// Measured on the shipped corpus, fifteen of the fifty category tokens FRUS cites are not
    /// primary subjects at all — `UN`, `NATO`, `OAS`, `EEC`, `SEATO`, `OECD`, `CENTO` and their
    /// kin. Looking for them among the 55 finds nothing, and the temptation is to record them as a
    /// gap. They are not a gap: the handbooks schedule an organization's file by a list of its
    /// own, so `UN 6` is `6 MEMBERSHIP. ASSOCIATION.` from this list rather than a `UN` outline
    /// that was never printed. Measured, the list answers **every** organization key the corpus
    /// carries.
    ///
    /// The section is found by its heading and followed while the pages carry the instruction's
    /// numeric corner, because it is typeset exactly like an outline — same three columns, same
    /// wrapped labels — and is therefore read by the same parser.
    ///
    /// - Parameters:
    ///   - document: An open handbook.
    ///   - layout: Where this edition prints its instruction text.
    /// - Returns: `designator -> subject`.
    static func readAdministrativeSubjects(_ document: PDFDocument,
                                           layout: OutlinePageLayout.Layout) -> [String: String] {
        var start: Int?
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let text = page.string,
                  text.contains("LIST OF ADMINISTRATIVE SUBJECTS")
            else { continue }
            start = index
            break
        }
        guard let start, let first = document.page(at: start),
              let corner = OutlinePageReader.numericCorner(of: first)
        else { return [:] }

        var out: [String: String] = [:]
        var index = start
        while index < document.pageCount, let page = document.page(at: index) {
            // The section ends where the instruction's own numbering does. Reading on until the
            // next heading would take the following instruction's entries into this list, and its
            // designators would overwrite these ones silently — they are small integers too.
            guard OutlinePageReader.numericCorner(of: page)?.instruction == corner.instruction
            else { break }
            let all = OutlinePageReader.lines(of: page, maxX: .greatestFiniteMagnitude)
            for column in OutlinePageLayout.columns(of: page, layout: layout) {
                let lines = all.filter { $0.x >= column.minX && $0.x < column.instructionX - 2 }
                for entry in OutlineEntryParser.parse(lines, footerFloor: 100).entries
                where out[entry.designator] == nil {
                    out[entry.designator] = entry.label
                }
            }
            index += 1
        }
        return out
    }

    /// The handbooks' COMMON ABBREVIATIONS appendix.
    ///
    /// ## The table that decides what an organization file IS
    /// The international-organizations instruction never names the organizations it governs — it
    /// says papers are arranged "under the name of the organization" and gives `UNESCO` and
    /// `ECOSOC` as examples. So the prefix in `UN 6` is the organization's own abbreviated title,
    /// and this appendix is where the handbook writes those titles down. An organization file is
    /// therefore a prefix that appears HERE and NOT among the primary subjects.
    ///
    /// That test is what stops the administrative-subject list from being applied to everything it
    /// would fit. `PSL 27 VIET S` is a one-character corruption of `POL 27 VIET S` and `NSSD 05-82`
    /// is a National Security Study Directive; both would take a subject from that list without
    /// complaint, and neither is in this appendix.
    ///
    /// ## The case of the label is the discriminator, and it is the same trap read the other way
    /// An appendix line and a category running head have the same shape — `NATO - North Atlantic
    /// Treaty Organization` beside `POL - POLITICAL AFFAIRS & RELATIONS` — which is why the
    /// category pass must exclude these pages. Here the pages are the point, and the ALL-CAPS test
    /// runs in reverse: an entry is kept only when its expansion contains a lower-case letter.
    ///
    /// - Parameter document: An open handbook.
    /// - Returns: `code -> expansion`.
    static func readAbbreviations(_ document: PDFDocument) -> [String: String] {
        var out: [String: String] = [:]
        // THE SPAN, NOT THE MATCHING PAGES. The corner mark is damaged on several appendix pages,
        // and reading only the pages that carry it intact drops whole letters of the alphabet
        // without any sign that it has: measured, `UN`, `EEC` and `OECD` were all absent while
        // `NATO` and `OAS` were present, which reads as a thin table rather than as a broken scan.
        // The appendix is contiguous, so its first and last legible pages bound it.
        let marked = (0..<document.pageCount).filter {
            document.page(at: $0).map(isAbbreviationPage) == true
        }
        guard let first = marked.first, let last = marked.last else { return [:] }
        for index in first...last {
            guard let page = document.page(at: index) else { continue }
            let lines = OutlinePageReader.lines(of: page, maxX: .greatestFiniteMagnitude)
                .filter { $0.y > 100 && !OutlineEntryParser.isFurniture($0.text) }
            // THE APPENDIX IS SET IN TWO COLUMNS, and rows are grouped by `y`, so reading the page
            // whole glues a left-column entry to whatever stands beside it: `SEATO` shipped
            // carrying `TAC` and a third entry after that. The columns are found the same way the
            // outlines' are — by the gap between the positions that OPEN an entry.
            let openers = lines.filter { leadingAbbreviation($0.text) != nil }.map(\.x).sorted()
            let starts = OutlinePageLayout.columnStarts(openers)
            guard !starts.isEmpty else { continue }

            for (position, start) in starts.enumerated() {
                let end = position + 1 < starts.count ? starts[position + 1] - 5 : Double.infinity
                let column = lines.filter { $0.x >= start - 5 && $0.x < end }
                var current: (code: String, parts: [String])?

                func close() {
                    guard let open = current else { return }
                    let label = OutlineEntryParser.tidy(open.parts.joined(separator: " "))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "- "))
                    // Lower case somewhere in the expansion is what separates an abbreviation from
                    // a primary subject's running head. Measured over both appendices, not one
                    // entry has an ALL-CAPS expansion.
                    if label.count > 2, label.contains(where: \.isLowercase),
                       !isMergedExpansion(label), out[open.code] == nil {
                        out[open.code] = curatedOrganizationNames[open.code] ?? label
                    }
                    current = nil
                }

                // THE CODE COLUMN, NOT THE DASH, IS WHAT OPENS AN ENTRY. The scan loses the dash on
                // a good fraction of the appendix — `SACLANT` / `Supreme Allied Command of the
                // Atlantic` and `SC` / `Security Council (UN)` both arrive without one — so a
                // dash-required rule reads those rows as continuations and folds them into the
                // entry above.
                for row in rowsWithX(column) {
                    if row.x <= start + 8, let (code, rest) = leadingAbbreviation(row.text) {
                        close()
                        current = (code, rest.isEmpty ? [] : [rest])
                    } else if current != nil {
                        current?.parts.append(row.text)
                    }
                }
                close()
            }
        }
        return out
    }

    /// Table rows that keep the left edge of their first piece.
    ///
    /// ``OutlineEntryParser/rows(_:)`` discards it, which is right for an outline — a designator is
    /// recognised by its shape. Here the shape is not enough, so the geometry has to survive.
    ///
    /// - Parameter lines: Geometry-ordered lines.
    /// - Returns: One row per line group, with its leftmost x.
    static func rowsWithX(_ lines: [PageLine]) -> [(text: String, x: Double)] {
        var out: [(text: String, x: Double)] = []
        var bucket: [PageLine] = []

        func flush() {
            guard !bucket.isEmpty else { return }
            let sorted = bucket.sorted { $0.x < $1.x }
            out.append((sorted.map(\.text).joined(separator: " "), sorted[0].x))
            bucket = []
        }

        for line in lines {
            if let first = bucket.first, abs(first.y - line.y) > 5 { flush() }
            bucket.append(line)
        }
        flush()
        return out
    }

    /// An abbreviation row's code and the expansion following it.
    ///
    /// The dash is optional for the reason the caller gives; what is required is that the code look
    /// like one — short, opening with a letter — and that something follow it.
    ///
    /// - Parameter text: A joined row.
    /// - Returns: `("NATO", "North Atlantic Treaty Organization")`, or `nil`.
    static func leadingAbbreviation(_ text: String) -> (String, String)? {
        guard let match = abbreviationRegex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text)),
              let code = Range(match.range(at: 1), in: text),
              let rest = Range(match.range(at: 2), in: text)
        else { return nil }
        return (String(text[code]).uppercased(),
                String(text[rest]).trimmingCharacters(in: CharacterSet(charactersIn: "- ")))
    }

    /// Whether an expansion is really two or more entries glued together.
    ///
    /// ## The refusal that keeps this table honest
    /// Column detection recovers most of the appendix, and on the 1965 edition it does not recover
    /// all of it: `UN` came out as *General Assembly - Department Telegram - Distant Early Warning
    /// System*, which is three entries in a row. Shipping that would be the mistake the decimal
    /// generator's refused subject layer exists to remember — a table that decodes cleanly and
    /// says something false.
    ///
    /// The signature is an EMBEDDED dash-space-dash: an appendix entry's own expansion never
    /// carries one, while a glued pair always does, because the dash that opened the next entry
    /// survives inside it. Measured against the entries this rule keeps, the long ones are long
    /// because the handbook is discursive (`CENTO` names its members and its headquarters) and not
    /// one of them contains the separator.
    ///
    /// - Parameter label: A parsed expansion.
    /// - Returns: `true` when the expansion swallowed a following entry.
    static func isMergedExpansion(_ label: String) -> Bool {
        label.contains(" - ")
    }

    /// Organization names the scan damaged, corrected by hand against the manual.
    ///
    /// Curated rather than ruled, for the reason the decimal generator gives about its own
    /// corrections: these are OCR damage in a NAME, and no rule can repair a wrong letter without
    /// licensing rewrites the source does not support. Each is checked against the printed page.
    static let curatedOrganizationNames: [String: String] = [
        // h1963 Com. Abbrev.: the scan reads the initial U of "United" as "Uh".
        "UN": "United Nations",
    ]

    /// Whether a page belongs to the COMMON ABBREVIATIONS appendix, by its own corner mark.
    ///
    /// - Parameter page: The page to test.
    /// - Returns: `true` when the page is part of the appendix.
    static func isAbbreviationPage(_ page: PDFPage) -> Bool {
        let bounds = page.bounds(for: .mediaBox)
        let strip = CGRect(x: bounds.minX, y: bounds.maxY - 60, width: bounds.width, height: 60)
        let text = (page.selection(for: strip)?.string ?? "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        return text.contains("Com.Abbrev")
    }

    /// `MAAG - Military Assistance Advisory Group`, the code being short and the dash required.
    private static let abbreviationRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^([A-Za-z][A-Za-z0-9/.]{0,7})\s*-?\s+(\S.*)$"#)
    }()

    /// Sorts designators numerically rather than lexically, so `9` precedes `10`.
    ///
    /// - Parameters:
    ///   - lhs: A designator.
    ///   - rhs: Another.
    /// - Returns: Whether `lhs` sorts first.
    static func designatorOrder(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.split(separator: "-").map { Int($0) ?? 0 }
        let right = rhs.split(separator: "-").map { Int($0) ?? 0 }
        for (a, b) in zip(left, right) where a != b { return a < b }
        return left.count < right.count
    }
}
