// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import PDFKit

// MARK: - DecimalClassLabelRunner

/// Builds `decimal-class-labels.json` from NARA's published classification manuals (#828).
///
/// ## The sources stay local, and that is deliberate
/// The manuals are public-domain NARA publications of a few megabytes each. They are read from
/// paths given in the environment rather than committed, the same convention `VOLUMES_DIR` and
/// `HARVEST_DIR` already follow: the artifact is the reproducible product, the scans are the
/// input. Every emitted vocabulary carries the title of the document it came from, so a reader
/// checking a label knows which publication to open even though the repo does not hold it.
///
/// ## It throws rather than emitting a thin table
/// A label table that silently lost the country column would render every decimal class as a bare
/// number again — the exact state #828 exists to end — while the build exited 0. Each schedule
/// must reach floors the parse has actually been measured against.
public enum DecimalClassLabelRunner {

    /// A parse that could not meet its own floor.
    public struct GenerationError: Error, CustomStringConvertible {
        /// What went wrong.
        public let description: String
    }

    /// One era's inputs.
    private struct Source {
        let id: String
        let start: Int
        let end: Int
        /// Which column of the country table this era reads (0-based).
        let countryColumn: Int
        let manualPath: String
        let title: String
        /// Floors, measured on the shipped scans.
        let minClasses: Int
        let minSubjects: Int
    }

    /// Runs the generator.
    ///
    /// - Parameter environment: Process environment.
    /// - Throws: ``GenerationError`` when a parse misses a measured floor.
    public static func run(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        func path(_ key: String, _ fallback: String) -> String { environment[key] ?? fallback }
        let downloads = path("SCHEDULE_DIR", NSHomeDirectory() + "/Downloads")
        let countryPath = path("COUNTRY_NUMBERS", downloads + "/country-numbers-list.pdf")
        let output = path("OUTPUT", "FRUSExplorer/Resources/decimal-class-labels.json")

        let sources = [
            Source(id: "1910-1949", start: 1910, end: 1949, countryColumn: 0,
                   manualPath: path("MANUAL_1910_49", downloads + "/manual-1910-49.pdf"),
                   title: "RG 59 Department of State Classification of Correspondence, "
                        + "August 1910 – December 1949 (National Archives and Records Administration)",
                   minClasses: 10, minSubjects: 60),
            Source(id: "1950-1959", start: 1950, end: 1959, countryColumn: 1,
                   manualPath: path("MANUAL_1950_59", downloads + "/manual-1950-59.pdf"),
                   title: "Records Codification Manual, Department of State "
                        + "(adopted 1 January 1950) (National Archives and Records Administration)",
                   minClasses: 10, minSubjects: 20),
            Source(id: "1960-1963", start: 1960, end: 1963, countryColumn: 2,
                   manualPath: path("MANUAL_1960_63", downloads + "/manual-1960-63.pdf"),
                   title: "Records Classification Handbook, Department of State (1960–1963) "
                        + "(National Archives and Records Administration)",
                   minClasses: 10, minSubjects: 20),
        ]

        let countryTitle = "Department of State 1910–1963 Central Decimal File Country Numbers "
            + "(National Archives and Records Administration)"
        let countries = try parseCountries(at: countryPath)
        print("[DecimalClassLabels] country table: \(countries.count) rows")

        var schedules: [DecimalClassLabels.Schedule] = []
        for source in sources {
            let text = try plainText(of: source.manualPath)
            let classes = parseClasses(text)
            let subjects = parseSubjects(text)
            let era = countries.compactMapValues { $0.codes[source.countryColumn] }
            var byCode: [String: String] = [:]
            for (name, code) in era where byCode[code.lowercased()] == nil {
                byCode[code.lowercased()] = name
            }

            guard classes.count >= source.minClasses else {
                throw GenerationError(description:
                    "\(source.id): parsed \(classes.count) class headings, floor \(source.minClasses). "
                    + "The manual's summary block did not parse — a table without class names "
                    + "renders every key as a bare number, which is the state this artifact ends.")
            }
            let subjectCount = subjects.values.reduce(0) { $0 + $1.count }
            guard subjectCount >= source.minSubjects else {
                throw GenerationError(description:
                    "\(source.id): parsed \(subjectCount) subject suffixes, floor \(source.minSubjects).")
            }
            guard byCode.count >= 100 else {
                throw GenerationError(description:
                    "\(source.id): only \(byCode.count) country codes. The three-column table did "
                    + "not split; every relations key would lose one of its two parties.")
            }

            print("[DecimalClassLabels] \(source.id): \(classes.count) classes, "
                + "\(byCode.count) countries, \(subjectCount) subject suffixes")
            schedules.append(DecimalClassLabels.Schedule(
                id: source.id, startYear: source.start, endYear: source.end, source: source.title,
                classes: classes,
                countryArrangedClasses: countryArranged(for: source.id),
                countries: byCode, subjects: subjects,
                sources: .init(schedule: source.title, countries: countryTitle)))
        }

        let table = DecimalClassLabels(
            schemaVersion: 1,
            generated: environment["GENERATED_DATE"] ?? Self.today(),
            provenance: "Parsed from NARA's published classification manuals and the 1910–1963 "
                + "country-number table. The manuals are not redistributed here; every vocabulary "
                + "carries the title of the document it was read from. The classification was "
                + "RENUMBERED in 1950 — class 7 is Political Relations of States before that date "
                + "and Internal Political and National Defense Affairs after it — so a key resolves "
                + "only against the schedule governing its own era.",
            schedules: schedules)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(table)
        try data.write(to: URL(fileURLWithPath: output))
        print("[DecimalClassLabels] wrote \(output) (\(data.count) bytes)")
    }

    /// The classes a schedule arranges by country.
    ///
    /// Read off the manuals' own summaries rather than inferred: 1910–49 arranges classes 6, 7 and
    /// 8 by country ("Arranged by countries" in its summary block), while the 1950 renumbering
    /// splits 3–6 as international relations and 7–9 as internal affairs, all country-arranged.
    private static func countryArranged(for id: String) -> [String] {
        id == "1910-1949" ? ["6", "7", "8"] : ["3", "4", "5", "6", "7", "8", "9"]
    }

    // MARK: - Parsing

    /// Flattens a PDF's text layer, normalising the letter-spacing the 1950s scans carry.
    private static func plainText(of path: String) throws -> String {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
            throw GenerationError(description: "cannot open \(path)")
        }
        var text = ""
        for index in 0..<document.pageCount {
            text += document.page(at: index)?.string ?? ""
            text += "\n"
        }
        guard !text.isEmpty else {
            throw GenerationError(description: "\(path) has no text layer to parse")
        }
        return text
    }

    /// `"7"` → `"Political Relations of States"`, from a manual's summary block.
    private static func parseClasses(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        // The 1950s scans render "Class 7" as "Clas s 7" and space every word, so the digit is
        // matched with tolerant spacing and the gloss is de-spaced afterwards.
        let pattern = #"Clas\s*s\s+(\d)\s+([A-Z][^\n]{4,90})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let digit = Range(match.range(at: 1), in: text).map({ String(text[$0]) }),
                  let gloss = Range(match.range(at: 2), in: text).map({ String(text[$0]) })
            else { continue }
            let cleaned = despace(gloss)
            if result[digit] == nil, cleaned.count >= 5 { result[digit] = cleaned }
        }
        return result
    }

    /// `"8"` → (`"72"` → `"Telegraph"`), from the manual's `N**.NN` subdivision entries.
    private static func parseSubjects(_ text: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        let pattern = #"(\d)\s*\*\s*\*\s*\.\s*(\d{2,5})\s+([A-Z][^\n]{3,80})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let digit = Range(match.range(at: 1), in: text).map({ String(text[$0]) }),
                  let suffix = Range(match.range(at: 2), in: text).map({ String(text[$0]) }),
                  let gloss = Range(match.range(at: 3), in: text).map({ String(text[$0]) })
            else { continue }
            let cleaned = trimGloss(despace(gloss))
            guard cleaned.count >= 3 else { continue }
            if result[digit]?[suffix] == nil { result[digit, default: [:]][suffix] = cleaned }
        }
        return result
    }

    /// One positioned token from a page's text layer.
    private struct Token {
        let text: String
        /// Horizontal midpoint, which is what places a code in its column.
        let x: Double
        /// Vertical midpoint, used only to group tokens into lines.
        let y: Double
    }

    /// The three-era country table: name → the codes for 1910–49, 1950–59, 1960–63.
    ///
    /// ## Why this reads geometry rather than reading order
    /// The table has three code columns and a notes column, and many rows fill only some of them:
    /// `Arctic 01 Discontinued 1955` carries a 1910–49 code alone, while `Arctic 03 03 Beginning
    /// 1955` carries the two later ones. **In reading order those are both "a name and some
    /// numbers"** — nothing says which column a lone code sits in. Placing one by guess would file
    /// a country under another era's number and gloss a citation with the wrong nation, an error
    /// no reader could detect because the output still looks like an answer.
    ///
    /// Dropping every partial row instead is honest but expensive: measured, it yields 176 of the
    /// 353 codes in the 1910–49 column and resolves 80.0% of classed documents against 98.1% for
    /// the full table — it throws away eighteen points of coverage to avoid a guess it does not
    /// have to make.
    ///
    /// So the columns are **calibrated from the rows that are certain**. Lines carrying exactly
    /// three codes fix the three column centres (measured on the shipped scan: x ≈ 125 / 224 /
    /// 293, from 140 sample rows each); every other code is then placed by its own measured
    /// position, and a code further than `columnTolerance` from every centre is dropped rather
    /// than forced. The uncertainty is resolved by measurement, not by assumption.
    private static let columnTolerance = 40.0

    private static func parseCountries(at path: String)
        throws -> [String: (codes: [String?], note: String?)]
    {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
            throw GenerationError(description: "cannot open \(path)")
        }
        guard let codeRegex = try? NSRegularExpression(pattern: #"^\d{1,3}[a-z]?$"#) else {
            throw GenerationError(description: "country-code pattern failed to compile")
        }
        func isCode(_ text: String) -> Bool {
            codeRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }

        // Pass 1: every line of every page, tokens ordered left to right.
        var lines: [[Token]] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var byRow: [Double: [Token]] = [:]
            for token in Self.tokens(of: page) {
                // 4pt rounding merges a row's tokens without merging adjacent rows.
                byRow[(token.y / 4).rounded() * 4, default: []].append(token)
            }
            for (_, row) in byRow { lines.append(row.sorted { $0.x < $1.x }) }
        }
        guard !lines.isEmpty else {
            throw GenerationError(description: "\(path) has no text layer to parse")
        }

        // Pass 2: calibrate the column centres from the unambiguous rows.
        var samples: [[Double]] = [[], [], []]
        for line in lines {
            let codes = line.filter { isCode($0.text) }
            guard codes.count == 3 else { continue }
            for (column, token) in codes.enumerated() { samples[column].append(token.x) }
        }
        guard samples.allSatisfy({ $0.count >= 20 }) else {
            throw GenerationError(description:
                "only \(samples.map(\.count)) rows carried three codes, too few to calibrate the "
                + "column positions. Without centres every partial row would have to be guessed "
                + "or dropped, and neither is acceptable for a table that names countries.")
        }
        let centres = samples.map { $0.sorted()[$0.count / 2] }
        print("[DecimalClassLabels] country columns calibrated at "
            + "\(centres.map { String(format: "%.0f", $0) }) from \(samples.map(\.count)) rows")

        // Pass 3: read the rows, placing each code in the column it physically occupies.
        var result: [String: (codes: [String?], note: String?)] = [:]
        var unplaced = 0
        var pending: [String] = []
        for line in lines {
            let codes = line.filter { isCode($0.text) }
            let words = line.filter { !isCode($0.text) }.map(\.text)
            if codes.isEmpty {
                // A name fragment (long names wrap) or a note. Notes are sentences; names are not.
                let fragment = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !fragment.isEmpty, fragment.count < 60, !fragment.hasSuffix(".") {
                    pending.append(fragment)
                    if pending.count > 3 { pending.removeFirst(pending.count - 3) }
                } else {
                    pending = []
                }
                continue
            }
            var placed: [String?] = [nil, nil, nil]
            for token in codes {
                let distances = centres.map { abs($0 - token.x) }
                guard let best = distances.firstIndex(of: distances.min()!),
                      distances[best] <= columnTolerance
                else { unplaced += 1; continue }
                if placed[best] == nil { placed[best] = token.text }
            }
            // The name is whatever precedes the first code on this line, plus any wrapped lines.
            let inline = line.prefix { !isCode($0.text) }.map(\.text).joined(separator: " ")
            let name = (pending + [inline])
                .joined(separator: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            pending = []
            guard name.count >= 3,
                  name.range(of: #"^[A-Z]"#, options: .regularExpression) != nil,
                  !name.lowercased().hasPrefix("country"),
                  !name.lowercased().contains("number"),
                  placed.contains(where: { $0 != nil })
            else { continue }
            if result[name] == nil { result[name] = (placed, nil) }
        }
        print("[DecimalClassLabels] country rows: \(result.count); "
            + "\(unplaced) code tokens dropped as unplaceable (notes-column years and the like)")
        guard result.count >= 400 else {
            throw GenerationError(description:
                "country table parsed \(result.count) rows, expected 400+. The shipped table has "
                + "roughly 700 entries across three eras; a short parse silently narrows every "
                + "label the artifact can compose.")
        }
        return result
    }

    /// A page's tokens with their measured positions.
    ///
    /// Indexed in **UTF-16**, not in `Character`s. `PDFPage.characterBounds(at:)` takes a UTF-16
    /// offset into the page's own string, and these pages contain non-ASCII (the header's en
    /// dashes among them), so a `Character`-offset walk drifts further out of step with every
    /// multi-unit scalar it passes. The drift is invisible in aggregate — the calibration medians
    /// still cluster — and fatal per token: it scattered 853 of the table's codes beyond every
    /// column and cut the parse to 176 rows.
    private static func tokens(of page: PDFPage) -> [Token] {
        guard let string = page.string else { return [] }
        let text = string as NSString
        var result: [Token] = []
        var start = -1
        func flush(_ end: Int) {
            guard start >= 0, end > start else { start = -1; return }
            let token = text.substring(with: NSRange(location: start, length: end - start))
            let first = page.characterBounds(at: start)
            let last = page.characterBounds(at: end - 1)
            result.append(Token(text: token,
                                x: Double((first.midX + last.midX) / 2),
                                y: Double(first.midY)))
            start = -1
        }
        for index in 0..<text.length {
            let unit = text.character(at: index)
            let scalar = Unicode.Scalar(unit).map { Character($0) }
            if scalar?.isWhitespace ?? false {
                flush(index)
            } else if start < 0 {
                start = index
            }
        }
        flush(text.length)
        return result
    }

    /// Collapses the letter-spacing NARA's 1950s scans carry (`"Clas s 0"` → `"Class 0"`).
    private static func despace(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: #"(?<=\b\w) (?=\w\b)"#, with: "",
                                                  options: .regularExpression)
        return collapsed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Trims a gloss at the first sentence-ending or cross-reference, so a label stays a label.
    private static func trimGloss(_ text: String) -> String {
        var gloss = text
        for marker in [". For ", ". See ", ". Divided as ", ". Use "] {
            if let range = gloss.range(of: marker) { gloss = String(gloss[..<range.lowerBound]) }
        }
        return gloss.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
    }

    /// Today, as `yyyy-MM-dd`.
    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
