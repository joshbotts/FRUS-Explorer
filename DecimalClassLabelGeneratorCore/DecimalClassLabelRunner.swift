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
                   // NINE, not ten: the 1910–49 schedule HAS no class 9. Its summary runs 000
                   // through 800 and the string "900" appears nowhere in the manual — the class
                   // arrives with the 1950 renumbering, as "Other Internal Affairs". A floor of
                   // ten here would reject a complete parse of a complete source.
                   minClasses: 9, minSubjects: 60),
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

            // A schedule that does not parse COMPLETELY is omitted rather than shipped thin.
            // Half a class table is worse than none: the keys it does not name render as bare
            // numbers indistinguishable from the ones it cannot reach, so a reader cannot tell
            // an unlabelled class from an unlabellable one. The omission is printed, and the
            // artifact says which eras it covers, so nothing about it is silent.
            let subjectCount = subjects.values.reduce(0) { $0 + $1.count }
            guard classes.count >= source.minClasses,
                  subjectCount >= source.minSubjects,
                  byCode.count >= 100
            else {
                print("[DecimalClassLabels] SKIPPING \(source.id): \(classes.count) classes "
                    + "(floor \(source.minClasses)), \(subjectCount) subjects "
                    + "(floor \(source.minSubjects)), \(byCode.count) countries (floor 100). "
                    + "This scan needs a pass of its own — its text layer letter-spaces every "
                    + "word, and a partially-named class table would mislabel rather than label.")
                continue
            }

            print("[DecimalClassLabels] \(source.id): \(classes.count) classes, "
                + "\(byCode.count) countries, \(subjectCount) subject suffixes")
            schedules.append(DecimalClassLabels.Schedule(
                id: source.id, startYear: source.start, endYear: source.end, source: source.title,
                classes: classes,
                countryArrangedClasses: countryArranged(for: source.id),
                relationsClasses: relationsClasses(for: source.id),
                countries: byCode, subjects: subjects,
                sources: .init(schedule: source.title, countries: countryTitle)))
        }

        // The 1910–49 schedule is the one #828 exists for — before 1948 the class lens IS the
        // named archival record (3.9% named-collection coverage against 93–98% class-key
        // coverage), and it is the era rendering as bare numbers today. Shipping without it
        // would be shipping the feature's premise unmet.
        guard schedules.contains(where: { $0.id == "1910-1949" }) else {
            throw GenerationError(description:
                "the 1910–1949 schedule did not parse. It is the era this artifact exists to "
                + "label; the later schedules are additions, not substitutes.")
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

    /// The classes whose suffix is a second country rather than a subject.
    ///
    /// In 1910–49 that is class 7 alone — "Political Relations of States", read country-to-country
    /// — while class 8, "Internal Affairs of States", is one country and a subject and class 6,
    /// "Commerce", is one country and a commodity or agreement. The three are all arranged by
    /// country and their keys are identically shaped, so the reading cannot be inferred from the
    /// key: treating class 8 as relations turned `893.51` into "China and France" when it means
    /// China's internal affairs, subject .51.
    ///
    /// The 1950 renumbering moves international relations to classes 3–6; those schedules are not
    /// yet parsed, so their entry here is provisional and unused.
    private static func relationsClasses(for id: String) -> [String] {
        id == "1910-1949" ? ["7"] : ["6"]
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

    /// `"7"` → `"Political Relations of States"`, from a manual's own headings.
    ///
    /// Two shapes, because the manuals differ. The 1950s handbooks head each division `Class 7`
    /// (rendered `Clas s 7` by their scan's letter-spacing); the 1910–49 manual states its classes
    /// in a SUMMARY block as round hundreds — `700 Political Relations of States`.
    ///
    /// The round-hundred pattern is confined to that summary block, because the manual goes on to
    /// use the same shape in running prose: matched over the whole document it captured "Wireless
    /// Telegraphy has the number 8**…" as the gloss for class 8. A label table that mislabels is
    /// worse than one that omits, so the search window is bounded to the block that is a list of
    /// classes by construction.
    private static func parseClasses(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        // The SUMMARY block runs FIRST because it is authoritative: it is a list of classes by
        // construction. The `Class N` headings are the fallback, and left first they lose — the
        // manual's prose contains "...substantially as Class 8..." mid-sentence, which claimed
        // class 8 for "Wireless Telegraphy has the number 8**.74" before the summary's own
        // "800 Internal Affairs of States" could be read.
        //
        // The summary block: from the heading to the first class body that follows it.
        if let summary = text.range(of: "SUMMARY"),
           let regex = try? NSRegularExpression(pattern: #"(?:^|\s)(\d)00\s+([A-Z][^\n]{4,90})"#) {
            let end = text.range(of: "Class 0", range: summary.upperBound..<text.endIndex)?.lowerBound
                ?? text.index(summary.upperBound, offsetBy: 4000, limitedBy: text.endIndex)
                ?? text.endIndex
            collect(regex, in: String(text[summary.upperBound..<end]), into: &result)
        }
        if let regex = try? NSRegularExpression(pattern: #"Clas\s*s\s+(\d)\s+([A-Z][^\n]{4,90})"#) {
            collect(regex, in: text, into: &result)
        }
        return result
    }

    /// Files every match of `regex` that names a class not already known.
    private static func collect(_ regex: NSRegularExpression, in text: String,
                                into result: inout [String: String]) {
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let digit = Range(match.range(at: 1), in: text).map({ String(text[$0]) }),
                  let gloss = Range(match.range(at: 2), in: text).map({ String(text[$0]) })
            else { continue }
            let cleaned = trimGloss(despace(gloss))
            if result[digit] == nil, cleaned.count >= 5 { result[digit] = cleaned }
        }
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

    /// The three-era country table: name → the codes for 1910–49, 1950–59, 1960–63.
    ///
    /// ## The problem: a partial row does not say which column it fills
    /// The table has three code columns, and many rows fill only some. `Arctic 01 Discontinued
    /// 1955` carries one code; `Arctic 03 03 Beginning 1955` carries two. In the PDF's text layer
    /// both are just "a name and some numbers" — **nothing in reading order says which era a lone
    /// code belongs to**, and placing one by guess would file a country under another era's number
    /// and gloss a citation with the wrong nation, an error no reader could catch because the
    /// output still looks like an answer.
    ///
    /// Two routes were measured and rejected before this one:
    /// - **Drop every partial row.** Honest, and expensive: 176 of the 353 codes in the 1910–49
    ///   column, resolving 80.0% of classed documents against the 98.1% a full table reaches.
    /// - **Place codes by their x position.** The column centres calibrate cleanly (x ≈ 125 / 224 /
    ///   293), but `PDFPage.characterBounds(at:)` does not agree with `PDFPage.string`'s ordering
    ///   on these files — names come back at wildly inconsistent x — so the positions cannot be
    ///   trusted to belong to the tokens they are read for.
    ///
    /// ## The rule: read NARA's own annotations
    /// The notes column says which end of the period a partial row occupies — 135 rows carry
    /// `Discontinued`, 66 `Established`, 40 `Beginning`. So a partial row is **left-aligned when
    /// it was discontinued** (the code ran from the start of the table until it lapsed) and
    /// **right-aligned when it began or was established** (the code appears only after). A partial
    /// row with no annotation is genuinely ambiguous and is dropped, counted, and reported.
    ///
    /// This is reading the source rather than inferring from layout, which is why it is the rule
    /// that ships.
    private static func parseCountries(at path: String)
        throws -> [String: (codes: [String?], note: String?)]
    {
        let text = try plainText(of: path)
        let code = #"\d{1,3}[a-z]?"#
        guard let codeRegex = try? NSRegularExpression(pattern: "^\(code)$"),
              let leadRegex = try? NSRegularExpression(pattern: "^(.*?)((?:\\s*\(code))+)\\s*(.*)$")
        else { throw GenerationError(description: "country-table patterns failed to compile") }
        func isCode(_ token: String) -> Bool {
            codeRegex.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)) != nil
        }

        var result: [String: (codes: [String?], note: String?)] = [:]
        var ambiguous = 0
        var pendingName: [String] = []
        var open: (name: String, codes: [String], note: String)?

        /// Files whatever row is open, once its note has been gathered.
        func close() {
            guard let row = open else { return }
            open = nil
            let note = row.note
            var placed: [String?] = [nil, nil, nil]
            if row.codes.count >= 3 {
                for index in 0..<3 { placed[index] = row.codes[index] }
            } else if note.contains("Beginning") || note.contains("Established") {
                // The code appears only in the later part of the period, so it is right-aligned.
                for (offset, value) in row.codes.enumerated() {
                    placed[3 - row.codes.count + offset] = value
                }
            } else if note.contains("Discontinued") || note.contains("Generally not used") {
                for (offset, value) in row.codes.enumerated() { placed[offset] = value }
            } else {
                ambiguous += 1
                return
            }
            let name = row.name
            guard name.count >= 3,
                  name.range(of: #"^[A-Z]"#, options: .regularExpression) != nil,
                  !name.lowercased().hasPrefix("country"),
                  !name.lowercased().contains("number")
            else { return }
            if result[name] == nil { result[name] = (placed, note.isEmpty ? nil : note) }
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let range = NSRange(line.startIndex..., in: line)
            let tokens = line.split(separator: " ").map(String.init)
            let hasCode = tokens.contains(where: isCode)

            if hasCode, let match = leadRegex.firstMatch(in: line, range: range) {
                func group(_ index: Int) -> String {
                    Range(match.range(at: index), in: line).map { String(line[$0]) } ?? ""
                }
                close()
                let inline = group(1).trimmingCharacters(in: .whitespaces)
                let name = (pendingName + [inline])
                    .joined(separator: " ")
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                pendingName = []
                open = (name: name,
                        codes: group(2).split(separator: " ").map(String.init).filter(isCode),
                        note: group(3).trimmingCharacters(in: .whitespaces))
            } else if open != nil {
                // A note continuation for the row still open.
                open?.note += " " + line
                if line.hasSuffix(".") { close() }
            } else {
                // A wrapped name fragment. Notes are sentences; names are not.
                if line.count < 60, !line.hasSuffix(".") {
                    pendingName.append(line)
                    if pendingName.count > 3 { pendingName.removeFirst(pendingName.count - 3) }
                } else {
                    pendingName = []
                }
            }
        }
        close()

        print("[DecimalClassLabels] country rows: \(result.count) placed; "
            + "\(ambiguous) partial rows dropped as unannotated and therefore unplaceable")
        guard result.count >= 400 else {
            throw GenerationError(description:
                "country table parsed \(result.count) rows, expected 400+. The shipped table has "
                + "roughly 700 entries across three eras; a short parse silently narrows every "
                + "label the artifact can compose.")
        }
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
