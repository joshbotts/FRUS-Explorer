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
                   // 693 subject suffixes parse: 62 stems plus 631 nested subdivisions. The floor
                   // sits just under that rather than at the old 60, because 60 is met by the
                   // stem pass ALONE — a nested pass that silently stopped matching would leave a
                   // table that still passes, still ships, and still labels `812.6363` "Mexico".
                   minClasses: 9, minSubjects: 650),
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
            var subjects = parseSubjects(text)
            // The stem pass runs FIRST so the 62 entries it already ships keep their values
            // exactly, and the nested pass adds only suffixes it left unclaimed.
            //
            // 1910–49 ONLY. The nested idiom is a property of a manual's typography, not of the
            // decimal file, and the two later manuals have neither been read nor measured — run
            // blind against them this pass yields 507 and 311 further suffixes, numbers that mean
            // nothing until someone has looked at what they say. Those schedules are skipped
            // below for unrelated reasons, so admitting the pass would cost nothing today and
            // ship silently the moment either one starts parsing.
            if source.id == "1910-1949" {
                for (suffix, gloss) in nestedSubjects(text, ofClass: "8")
                where subjects["8"]?[suffix] == nil {
                    subjects["8", default: [:]][suffix] = gloss
                }
            }
            let era = countries.compactMapValues { $0.codes[source.countryColumn] }
            // Several names legitimately share one code — 65 is both `Italy` and `Rhodes Island`,
            // because Italy held the Dodecanese for the period this schedule covers. First-wins
            // over a Dictionary resolved that by hash order, which is how the table came to gloss
            // 65 as "Rhodes Island". The shortest name wins instead, ties broken alphabetically:
            // deterministic, and it prefers the sovereign state over the territory filed under it.
            var byCode: [String: String] = [:]
            var shared = 0
            // Sorted by the NAME's length — `lhs.key` — not the code's. Sorting on `value`
            // ordered by code length, which is nearly constant, so the tie-break never ran and
            // 51 came back as "Corsica" rather than "France".
            for (name, code) in era.sorted(by: { lhs, rhs in
                lhs.key.count != rhs.key.count ? lhs.key.count < rhs.key.count : lhs.key < rhs.key
            }).map({ ($0.key, $0.value) }) {
                let key = code.lowercased()
                if byCode[key] == nil { byCode[key] = name } else { shared += 1 }
            }
            var corrected = 0
            for (code, entry) in Self.corrections[source.id] ?? [:] where byCode[code] == nil {
                byCode[code] = entry.name
                corrected += 1
            }
            if corrected > 0 {
                print("[DecimalClassLabels] \(source.id): \(corrected) curated corrections "
                    + "applied for codes this scan mangles")
            }
            if shared > 0 {
                print("[DecimalClassLabels] \(source.id): \(shared) further names share a code "
                    + "already taken (territories filed under the power holding them)")
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
                + "only against the schedule governing its own era. Class 8's subject suffixes run "
                + "the manual's full subdivision tree (`.6363 Petroleum` beneath `.636 Carbon. "
                + "Graphite` beneath `.63 Mines. Mining`); classes 6 and 7 carry only the stems "
                + "they state outright, because their own subdivisions name a second country and "
                + "are compound keys this table does not express. A gloss is the manual's wording "
                + "and is not unique — `.711` and `.731` are both Laws and regulations, of postal "
                + "and of cable service — so it supplements the key rather than replacing it.",
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

    /// `"8"` → (`"72"` → `"Telegraph"`), from the manual's `N**.NN` STEM entries.
    ///
    /// Every entry this pass finds spells its class out, which is how the manual writes the top of
    /// each subdivision and nothing else — the tree beneath a stem drops the class and is read by
    /// ``nestedSubjects(_:ofClass:)`` instead. The two are kept apart because this one scans the
    /// whole document (it is the only route to class 6's single stem, stated outside any class
    /// body) while the nested pass is bounded to one class and cannot be.
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

    /// The subdivisions a class body writes WITHOUT repeating the class — `.421 Academic.`
    /// beneath `8**.42 Education.` — added to `subjects` under `digit`.
    ///
    /// ## Why the class has to be carried forward
    /// ``parseSubjects`` demands a literal `8**.` on every entry, which is how the manual writes a
    /// stem and how it writes nothing else. The tree below each stem drops the class and the
    /// country and prints the suffix alone, so a pattern requiring the prefix sees 61 entries
    /// where the class has several hundred. Carrying the class digit forward from the last stem is
    /// the whole of the fix.
    ///
    /// ## The scan is LINE-ANCHORED, and that is what makes it safe
    /// The manual writes cross-references mid-entry — "For apprenticeship, see 8**.605", "…are
    /// carried in 8**.46" — and an earlier attempt at this split the text at every suffix
    /// occurrence, which turned each pointer into a fragment whose remainder was the *next* entry's
    /// prose: `8**.42` came back as "Division of Trade Agreements". Measured over the class-8 body,
    /// **not one** of its 755 subdivision lines is a cross-reference and **not one** cross-reference
    /// begins a line, so anchoring at the line start removes the entire failure mode rather than
    /// guarding against it. Only four lines in the body carry anything before a suffix-shaped
    /// token, and three of them are exactly that kind of prose (`For armament control, United
    /// States, see 711.00111 Armament control.`); the fourth is `]8**.77 Railway.`, an OCR bracket,
    /// which is why one leading mark is tolerated and a leading *word* is not.
    ///
    /// ## Class 8 only, and the reason is in the other two classes' grammar
    /// Classes 6 and 7 are country-arranged too, but neither writes a general bare suffix:
    /// - Class 7's bare children belong to the *whole numbers* that head them — `.01 Right of
    ///   residence` sits under `701 Diplomatic representation`, meaning `701.01`, not "suffix .01
    ///   of any country". Filed as a class-7 subject it would gloss `761.01` as the Soviet Union's
    ///   right of residence, which the manual does not say. Its genuinely general subdivisions all
    ///   carry the second-country marker (`.††11 War. Peace. Friendship.`) and so are compound
    ///   keys this table's one-suffix lookup cannot express.
    /// - Class 6's subdivisions are `††`-marked throughout, importing country against exporting.
    ///
    /// So the nested idiom is class 8's, and running the pass anywhere else would invent readings.
    ///
    /// - Parameters:
    ///   - text: The whole manual.
    ///   - digit: The class whose body to walk.
    /// - Returns: `suffix` → gloss for every subdivision the body states in its own right.
    static func nestedSubjects(_ text: String, ofClass digit: String) -> [String: String] {
        guard let body = classBody(text, ofClass: digit) else { return [:] }
        // One optional leading mark for the OCR bracket; a `**` stem, a country-scoped stem, or a
        // bare child. The suffix is digits-then-alphanumerics so `.00B` and `.77A` survive while
        // `.††62` and `.58**` — compound keys naming a second country — do not.
        let lead = #"^[^\p{L}\p{N}\s.]?\s*"#
        guard let stem = try? NSRegularExpression(
                pattern: lead + #"(\d)\.?\*\*\.\s*(\d[0-9A-Za-z]*)\s+(\S.*)$"#),
              let scoped = try? NSRegularExpression(pattern: lead + #"\d{2,3}\.\s*\d"#),
              let child = try? NSRegularExpression(
                pattern: lead + #"\.\s*(\d[0-9A-Za-z]*)\s+(\S.*)$"#)
        else { return [:] }

        var result: [String: String] = [:]
        // `nil` while a country-scoped block is open. The body carries exactly one — `800.88
        // Foreign carrying trade.` with eight route termini under it (`.8810 North America.`) —
        // and those are subdivisions of country 00, The World, not of every country. Inherited by
        // the class they would gloss `862.8810` as Germany's North America, a reading the manual
        // does not make. The block ends at the next `8**.` stem.
        var current: String?
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        for (index, line) in lines.enumerated() where !line.isEmpty {
            let range = NSRange(line.startIndex..., in: line)
            func group(_ match: NSTextCheckingResult, _ index: Int) -> String {
                Range(match.range(at: index), in: line).map { String(line[$0]) } ?? ""
            }
            // A wrapped entry's tail, when there is one. The manual ends every finished entry with
            // a full stop, so an entry lacking one ran past its line — and a WRAPPED PHRASE
            // RESUMES IN LOWER CASE (`use therein.`, `philanthropic organizations.`) where a
            // sub-descriptor of the entry above starts a new capitalised sentence (`Processing
            // tax.`). Joining on that test recovers five truncated entries and refuses the one
            // case where the following line belongs to a second column instead
            // (`.796104 Inspection. ** Country of regulation,` / `Airworthiness certificates.
            // Wireless. not nationality of aircraft.`).
            let next = index + 1 < lines.count ? lines[index + 1] : ""
            let continuation = next.first?.isLowercase == true
                && child.firstMatch(in: next, range: NSRange(next.startIndex..., in: next)) == nil
                ? next : nil

            if let match = stem.firstMatch(in: line, range: range) {
                current = group(match, 1)
                file(suffix: group(match, 2), gloss: group(match, 3), continuation: continuation,
                     under: current, digit: digit, into: &result)
            } else if scoped.firstMatch(in: line, range: range) != nil {
                current = nil
            } else if let match = child.firstMatch(in: line, range: range) {
                file(suffix: group(match, 1), gloss: group(match, 2), continuation: continuation,
                     under: current, digit: digit, into: &result)
            }
        }
        return result
    }

    /// Files one subdivision, or drops it when the entry is not a definition this table can state.
    ///
    /// ## An entry the manual did not finish is not a label
    /// Every finished entry ends in a full stop. One that does not either wrapped — in which case
    /// `continuation` carries its tail — or ran into the facing column, and the two are not
    /// distinguishable from the fragment alone. So an entry still unterminated after the join is
    /// **dropped**, which is what stops these four from shipping:
    /// ```
    /// .541 Industrial property. ** Country in which protection
    /// .542 Patents is sought. For treaties, conventions,
    /// .543 Trade-marks. Trade names. arrangements, ect., add country number ††,
    /// .796104 Inspection. ** Country of regulation,
    /// ```
    /// Every one of those is a left-column entry with a right-column note welded to it, and
    /// "Patents is sought" is the kind of confident nonsense this table exists not to print. The
    /// same rule costs four entries the manual states perfectly well but forgot to punctuate
    /// (`.512 Taxation`, `.4511 Dress`, `.61345 Soya beans`, `.2222F Foreign Nationals`); their
    /// keys render bare, which is the designed outcome for anything uncertain.
    ///
    /// ## Where the bleed survives punctuation, it is cut
    /// `.544 Copyrights. using smaller number of country for **.` ends in a full stop and is still
    /// two columns. A sentence that resumes in LOWER CASE is the second column starting, and so is
    /// a `**`/`††` marker followed by a capital — while `country **` mid-phrase, which the manual
    /// writes constantly for the subject country, is followed by a lower-case word and is left
    /// alone.
    ///
    /// ## The gloss must begin with a letter
    /// The scan puts a space inside some numbers — `.42 31 Engineering` where the manual prints
    /// `.4231` — and without this rule the suffix `42` is filed with the gloss "31 Engineering",
    /// overwriting `Education` with a fragment. There is no way to tell which of the two numbers
    /// is the real suffix, so the line is dropped.
    private static func file(suffix: String, gloss: String, continuation: String?,
                             under classDigit: String?, digit: String,
                             into result: inout [String: String]) {
        guard classDigit == digit, result[suffix] == nil else { return }
        var text = gloss.trimmingCharacters(in: .whitespaces)
        if !isFinished(text), let continuation { text += " " + continuation }
        guard isFinished(text) else { return }
        let cleaned = trimGloss(despace(columnCut(text)))
        guard let first = cleaned.first, first.isLetter, first.isUppercase,
              cleaned.count >= 3, cleaned.count <= 90
        else { return }
        result[suffix] = cleaned
    }

    /// Whether an entry's text ends where the manual ends one — a full stop, possibly inside a
    /// closing bracket (`Socialism. … (I.W.W.)`, `Corn (maize.)`).
    private static func isFinished(_ text: String) -> Bool {
        var tail = text.trimmingCharacters(in: .whitespaces)
        while tail.hasSuffix(")") { tail.removeLast() }
        return tail.hasSuffix(".")
    }

    /// Cuts a gloss where the facing column's text was welded onto it.
    private static func columnCut(_ text: String) -> String {
        var gloss = text
        for pattern in [#"\s(?:\*\*|††)\s+\p{Lu}"#, #"\.\s+\p{Ll}"#] {
            if let range = gloss.range(of: pattern, options: .regularExpression) {
                gloss = String(gloss[..<range.lowerBound])
            }
        }
        return gloss
    }

    /// The text of one class's division, from its heading to the next class's or the country list.
    ///
    /// Bounded because the manual reuses the shape everywhere else: its own country list prints
    /// `51 France.` and its prose prints `Class 6. Commercial treaties…`, so the heading pattern is
    /// the bare form (`Class 8`, `Class 0.`) on a line of its own, and the body stops at whichever
    /// comes first of the next heading and the `Country Numbers` table that closes the volume.
    static func classBody(_ text: String, ofClass digit: String) -> Substring? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        func heading(_ line: Substring) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.range(of: #"^Class \d\.?$"#, options: .regularExpression) != nil,
                  let value = trimmed.dropFirst(6).first
            else { return nil }
            return String(value)
        }
        guard let start = lines.firstIndex(where: { heading($0) == digit }) else { return nil }
        let end = lines[lines.index(after: start)...].firstIndex {
            let trimmed = $0.trimmingCharacters(in: .whitespaces)
            return (heading($0).map { $0 != digit } ?? false) || trimmed == "Country Numbers"
        } ?? lines.endIndex
        return lines[lines.index(after: start)..<end].joined(separator: "\n")[...]
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
            } else {
                // The `Discontinued ⇒ left-align` rule is GONE, and its removal is a correctness
                // fix rather than a tidy-up. `Arctic 01 Discontinued 1955. See 03.` does not mean
                // 01 is a 1910–49 code — the row is annotated from the perspective of the column
                // it actually occupies, which the text does not name. Left-aligned, `01` entered
                // the 1910–49 table and glossed **4,513 documents** as "Arctic", among them
                // `501.BB` (1,628), which is a United Nations key and names no country at all.
                // `11h` (Alaska) arrived the same way.
                //
                // `Beginning`/`Established` is kept because it is directional in the other sense:
                // a code that BEGINS mid-period cannot be in the earliest column, so right-
                // alignment removes possibilities rather than inventing one.
                ambiguous += 1
                return
            }
            let name = row.name
            // A country name is a noun phrase. These reject note prose that the row builder let
            // through: `52` shipped as `Africa."` — the tail of *Formerly "German Southwest
            // Africa."* — and glossed 1,761 documents with it.
            guard !name.contains("\""), !name.hasSuffix("."), !name.hasSuffix(","),
                  name.split(separator: " ").count <= 6,
                  name.count >= 3,
                  name.range(of: #"^[A-Z]"#, options: .regularExpression) != nil,
                  !name.lowercased().hasPrefix("country"),
                  !name.lowercased().contains("number")
            else { return }
            if result[name] == nil { result[name] = (placed, note.isEmpty ? nil : note) }
        }

        /// Whether a code-less line continues the previous row's note rather than starting a name.
        ///
        /// Notes are sentences and cross-references; names are noun phrases. The table's own
        /// vocabulary does the work — `Discontinued`, `Established`, `Beginning`, `See`, `Prior
        /// to`, `Generally not used` — plus the ordinary marks of running prose.
        func looksLikeNote(_ line: String) -> Bool {
            if line.hasSuffix(".") { return true }
            if let first = line.first, first.isLowercase || first.isNumber { return true }
            return ["Discontinued", "Established", "Beginning", "Restored", "See", "Prior to",
                    "Generally not used"].contains { line.contains($0) }
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            // The column headers repeat on every page, and a row straddling a page break has them
            // injected between its name and its codes — which is how `Germany` lost its 62.
            // Skipped without disturbing the pending name, so the row closes across the break.
            if Self.pageFurniture.contains(line) { continue }
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
            } else if open != nil, looksLikeNote(line) {
                // A note continuation for the row still open.
                open?.note += " " + line
                if line.hasSuffix(".") { close() }
            } else {
                // Not a note: it is the START OF THE NEXT NAME, so the open row ends here.
                // Without this test every line after a code row was swallowed as note text, and
                // a name that wraps — `Union of Soviet Socialist Republics` runs to three lines
                // before its codes — was consumed by the row above it. That is why 61 and 62,
                // the Soviet Union and Germany, were missing from a 429-row table.
                close()
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

    /// One hand-verified row, with the evidence for it.
    struct Correction {
        /// The country as the table names it.
        let name: String
        /// What in the source establishes the pairing. Not decoration: D-2 requires every row to
        /// carry its source, and these rows did not come from the parser.
        let evidence: String
    }

    /// Codes the scan mangles beyond recovery, supplied by curation (#828 is curation-led).
    ///
    /// ## Why a hand list exists at all
    /// A few of the country table's pages have a text layer that interleaves columns: `Germany`'s
    /// name is stranded twenty lines above its `62 62 62`, with a reprinted page header between
    /// them. Three parsing strategies were measured against those pages — reading order, x
    /// geometry, and ordered pairing of orphan names to orphan codes — and none recovers them
    /// (the geometry disagrees with the text layer's ordering; ordered pairing fails because a
    /// wrapped name contributes several lines, so names outnumber code lines on every affected
    /// page).
    ///
    /// ## The rule for adding a row
    /// **Every entry is established by the source document, never by outside knowledge**, and
    /// carries the quotation that establishes it. A code whose pairing the document does not
    /// settle is left out — the table stays silent rather than becoming confidently wrong, which
    /// is the same standard the parser is held to.
    ///
    /// This list is deliberately short. It is not a place to make the coverage number look
    /// better; 124 further codes remain unresolved and are reported as such.
    static let corrections: [String: [String: Correction]] = [
        "1910-1949": [
            "62": Correction(
                name: "Germany",
                evidence: "The orphaned line `62 62 62` carries no name because the page's text "
                    + "layer interleaves. The parent is fixed by the table's own entries under the "
                    + "convention the NARA hints sheet states — a colony or successor takes the "
                    + "parent's number plus a letter: `West Germany 62a 62a`, `Federal Republic of "
                    + "Germany 62a 62a`, `East Germany 62b 62b`, `Administration Germany. Russian "
                    + "Zone 62b 62b`."),
            "52": Correction(
                name: "Spain",
                evidence: "Stranded on the same interleaved page as Germany — the line reads "
                    + "`Spain Spanish Guinea Spanish` with the column headers following it. The "
                    + "parent is fixed by the table's own dependants under the parent-plus-letter "
                    + "convention the NARA hints sheet states: `Adrar 52c`, `Annobon 52e`, "
                    + "`Alhucemas 52f`, `Zaffarin Islands 52f` are all Spanish possessions. Until "
                    + "this entry, 52 was taken by `Africa.\"` — the tail of the note *Formerly "
                    + "\"German Southwest Africa.\"* — which glossed 1,761 documents."),
            "15": Correction(name: "Honduras",
                             evidence: "`Honduras 15 15 15`, a complete three-column row."),
            "83": Correction(
                name: "Egypt",
                evidence: "`Egypt 83 74* 74*  *See 86b. Use after October 1961.` — 83 is the "
                    + "1910–49 column; the starred 74 belongs to the later schedules."),
            "96": Correction(
                name: "Philippines",
                evidence: "`Philippines 96 96 96 Beginning July 1946`, beside the superseded "
                    + "`Philippines 11b Discontinued July 1946. See 96.`"),
            "10": Correction(
                name: "America. Pan-America",
                evidence: "The name wraps as `America. Pan-` / `America` with `10` on the "
                    + "following line."),
        ],
    ]

    /// The column headers reprinted on every page of the country table.
    ///
    /// Not content: a row that straddles a page break has these lines dropped into the middle of
    /// it, and treating them as name fragments or note text severed the name from its codes.
    private static let pageFurniture: Set<String> = [
        "Country", "Number", "Notes", "1910-1949", "1950-1959", "1960-1963",
    ]

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
