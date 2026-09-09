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
        /// Whether this manual's subject-suffix layer is trustworthy enough to ship (#1210).
        ///
        /// The 1910–49 manual states its subdivisions in a subdivision TREE, which
        /// ``parseSubjects`` reads cleanly: 693 suffixes, of which 6 carry a `**` — and those six
        /// are the manual's own placeholder for a country ("Naval and coaling stations of country
        /// ** in country ††"), not parse noise.
        ///
        /// The 1950–59 and 1960–63 handbooks also carry an **alphabetical index**, which pairs a
        /// subject NAME with a class reference (`Silk 8**.355`). The same pattern reads those
        /// backwards, filing a class-8 subject under whatever digit precedes it: measured, **399 of
        /// 507** entries for 1950–59 and **205 of 311** for 1960–63 carry a stray class reference,
        /// and the damage is not cosmetic — `795.00` glossed as *Korea — Amusements 8\*\*.45*.
        ///
        /// So the layer is refused wholesale rather than shipped mislabelling. The class, country
        /// and relations layers are verified and DO ship, which is what makes `611.93` read
        /// *United States and China*. A future pass that bounds the scan to the subdivision tables
        /// can turn this back on; until then a suffix simply does not narrow a post-1950 gloss.
        let shipsSubjects: Bool
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
                   minClasses: 9, minSubjects: 650, shipsSubjects: true),
            Source(id: "1950-1959", start: 1950, end: 1959, countryColumn: 1,
                   manualPath: path("MANUAL_1950_59", downloads + "/manual-1950-59.pdf"),
                   title: "Records Codification Manual, Department of State "
                        + "(adopted 1 January 1950) (National Archives and Records Administration)",
                   minClasses: 10, minSubjects: 0, shipsSubjects: false),
            Source(id: "1960-1963", start: 1960, end: 1963, countryColumn: 2,
                   manualPath: path("MANUAL_1960_63", downloads + "/manual-1960-63.pdf"),
                   title: "Records Classification Handbook, Department of State (1960–1963) "
                        + "(National Archives and Records Administration)",
                   minClasses: 10, minSubjects: 0, shipsSubjects: false),
        ]

        let countryTitle = "Department of State 1910–1963 Central Decimal File Country Numbers "
            + "(National Archives and Records Administration)"
        let countries = try parseCountries(at: countryPath)
        print("[DecimalClassLabels] country table: \(countries.count) rows")

        var schedules: [DecimalClassLabels.Schedule] = []
        // #1204: the refusals are recorded, not merely printed. A consumer asking "is there a
        // 1958 schedule?" gets `no, and here is how short it fell` rather than a silence
        // indistinguishable from an era nobody attempted.
        var omissions: [DecimalClassLabels.Coverage.Omission] = []
        for source in sources {
            let text = try plainText(of: source.manualPath)
            var classes = parseClasses(text)
            // #1210: when the flattened text layer cannot pair a label with its gloss, read the
            // block off the PAGE instead. Only when the text pass came up short, so a manual that
            // parses cleanly is never re-read by a geometry pass that could only agree with it.
            if classes.count < source.minClasses,
               let byGeometry = classesByGeometry(of: source.manualPath),
               byGeometry.count > classes.count {
                print("[DecimalClassLabels] \(source.id): text layer gave \(classes.count) classes, "
                      + "page geometry gave \(byGeometry.count)")
                classes = byGeometry
            }
            // Curated class glosses override the parse, the same precedence the country table uses:
            // a hand-checked reading beats OCR damage, and each override is printed for review.
            var glossed = classes
            for (digit, entry) in Self.classCorrections[source.id] ?? [:] {
                if glossed[digit] != entry.name {
                    print("[DecimalClassLabels] \(source.id) class \(digit) corrected: "
                          + "\(glossed[digit] ?? "(absent)") -> \(entry.name)")
                }
                glossed[digit] = entry.name
            }
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
            // The COLUMN SPAN of each claim — how many eras this row holds this code across.
            // A head entry keeps its number as the file is reissued; a redirect row takes it in
            // one era only. That is the document distinguishing them, and it is the signal the
            // tie-break below reads first.
            let era: [(name: String, code: String, span: Int)] = countries.compactMap { row in
                guard let code = row.codes[source.countryColumn] else { return nil }
                let span = row.codes.filter { $0?.lowercased() == code.lowercased() }.count
                return (name: row.name, code: code, span: span)
            }
            // Several names legitimately share one code — 65 is both `Italy` and `Rhodes Island`,
            // because Italy held the Dodecanese for the period this schedule covers. First-wins
            // over a Dictionary resolved that by hash order, which is how the table came to gloss
            // 65 as "Rhodes Island".
            //
            // **THE COLUMN SPAN IS TRIED BEFORE THE NAME LENGTH, and reading the columns is what
            // made that necessary.** Shortest-name alone prefers the sovereign state over the
            // territory filed under it often enough to look like a rule — `France` over `Corsica`
            // — but it is a proxy, and once #1256 stopped inventing columns the proxy started
            // losing: `75` gained its redirect rows and came back as `Galla` (5 letters) rather
            // than `Ethiopia` (8), and `51f` as `Mahe` rather than `French India`. The span says
            // the same thing the length was standing in for, and says it from the document:
            // Ethiopia holds 75 in two eras where Galla holds it in one.
            //
            // Length remains the second key and alphabetical order the third, so the result is
            // still total and deterministic.
            var byCode: [String: String] = [:]
            var displaced: [String: [String]] = [:]
            var shared = 0
            // Sorted by the NAME's length — `lhs.key` — not the code's. Sorting on `value`
            // ordered by code length, which is nearly constant, so the tie-break never ran and
            // 51 came back as "Corsica" rather than "France".
            for (name, code, _) in era.sorted(by: { lhs, rhs in
                if lhs.span != rhs.span { return lhs.span > rhs.span }
                if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
                return lhs.name < rhs.name
            }) {
                let key = code.lowercased()
                if byCode[key] == nil {
                    byCode[key] = name
                } else {
                    shared += 1
                    // **Which names lost, not just how many.** The count alone said 190 names
                    // shared a taken code and named none of them, so a wrong winner — `60f` as
                    // "Ruthenia" over "Czechoslovakia", 82 documents — was invisible in the log
                    // and had to be found by reading the artifact. #1201.
                    displaced[key, default: []].append(name)
                }
            }
            // **A curated row overrides the heuristic, it does not merely fill a gap.**
            // `where byCode[code] == nil` meant a code the shortest-name rule had already answered
            // wrongly could not be corrected at all — `60f` came back as "Ruthenia" over
            // "Czechoslovakia" and the curated entry beside it was silently inert. The tie-break is
            // a heuristic; an entry here is hand-verified against the source and carries the
            // quotation that establishes it, so it is the better evidence and wins.
            var corrected = 0
            var overrode = 0
            for (code, entry) in Self.corrections[source.id] ?? [:] {
                if let sitting = byCode[code] {
                    guard sitting != entry.name else { continue }
                    overrode += 1
                } else {
                    corrected += 1
                }
                byCode[code] = entry.name
            }
            if corrected > 0 || overrode > 0 {
                print("[DecimalClassLabels] \(source.id): \(corrected) curated corrections "
                    + "applied for codes this scan mangles, \(overrode) overriding a parsed name")
            }
            if shared > 0 {
                print("[DecimalClassLabels] \(source.id): \(shared) further names share a code "
                    + "already taken (territories filed under the power holding them)")
                // The contested codes, so a wrong winner can be seen rather than discovered later
                // in the artifact. Sorted for a reproducible log.
                for key in displaced.keys.sorted() where byCode[key] != nil {
                    print("[DecimalClassLabels]   \(key) = \(byCode[key]!) "
                        + "(also: \(displaced[key]!.sorted().joined(separator: ", ")))")
                }
            }

            // A schedule that does not parse COMPLETELY is omitted rather than shipped thin.
            // Half a class table is worse than none: the keys it does not name render as bare
            // numbers indistinguishable from the ones it cannot reach, so a reader cannot tell
            // an unlabelled class from an unlabellable one. The omission is printed, and
            // `coverage.notShipped` records it with these counts, so nothing about it is silent.
            //
            // #1204 found the floor is sound for a REASON THIS COMMENT DID NOT STATE, and the
            // difference matters to anyone tempted to lower it. `DecimalClassLabelTable.gloss`
            // never reads `classes` at all — it needs a governing schedule,
            // `countryArrangedClasses` and `countries`, and its last line returns a BARE COUNTRY
            // NAME, shaped exactly like a complete gloss. The country table comes from a
            // different, born-digital PDF that parses cleanly for all three eras (200 and 215
            // codes here, both over the floor). So lowering `minClasses` would not yield a table
            // that stays mostly silent; it would yield one that glosses nearly every post-1950
            // country-arranged key, most of them down to that bare-country fallback. The
            // thinness measured is not the thinness that gates display.
            // Refused layers are emptied BEFORE the floor is measured, so the count that gates
            // and the table that ships are the same object — a floor reported over rows nobody
            // will read is the kind of number that looks like verification and is not.
            let shippableSubjects = source.shipsSubjects ? subjects : [:]
            let subjectCount = shippableSubjects.values.reduce(0) { $0 + $1.count }
            // `classes`, NOT `glossed`: the floor measures what the PARSER achieved. Counting the
            // curated map instead would let a hand list buy its way past a floor that exists to say
            // the scan was not read well enough — and the floor would then be measuring curation
            // effort rather than parse quality. Both current corrections repair a gloss the parser
            // already found, so the two counts agree today; the distinction is for the day they
            // would not.
            guard classes.count >= source.minClasses,
                  subjectCount >= source.minSubjects,
                  byCode.count >= Self.minCountries
            else {
                let reason = "This scan needs a pass of its own — its text layer letter-spaces "
                    + "every word, and a partially-named class table would mislabel rather than "
                    + "label."
                print("[DecimalClassLabels] SKIPPING \(source.id): \(classes.count) classes "
                    + "(floor \(source.minClasses)), \(subjectCount) subjects "
                    + "(floor \(source.minSubjects)), \(byCode.count) countries "
                    + "(floor \(Self.minCountries)). " + reason)
                omissions.append(.init(
                    scheduleId: source.id, startYear: source.start, endYear: source.end,
                    source: source.title, reason: reason,
                    parsed: .init(classes: classes.count, subjects: subjectCount,
                                  countries: byCode.count),
                    floors: .init(classes: source.minClasses, subjects: source.minSubjects,
                                  countries: Self.minCountries)))
                continue
            }

            print("[DecimalClassLabels] \(source.id): \(classes.count) classes, "
                + "\(byCode.count) countries, \(subjectCount) subject suffixes")
            schedules.append(DecimalClassLabels.Schedule(
                id: source.id, startYear: source.start, endYear: source.end, source: source.title,
                classes: glossed,
                countryArrangedClasses: countryArranged(for: source.id),
                relationsClasses: relationsClasses(for: source.id),
                countries: byCode, subjects: shippableSubjects,
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

        // #1204: the era contract, built from the schedules that actually shipped rather than
        // asserted, so it cannot drift from them. `renumberedAt` is the one constant — it is a
        // fact about the classification, not about this build.
        let coverage = DecimalClassLabels.Coverage(
            renumberedAt: Self.renumberedAt,
            decimalFileOpensIn: Self.decimalFileOpensIn,
            glossableYears: schedules.map {
                .init(scheduleId: $0.id, startYear: $0.startYear, endYear: $0.endYear)
            },
            keyOutsideGlossableYears: "no-gloss",
            notShipped: omissions,
            note: "A key is glossable only when the document's own date falls inside one of "
                + "`glossableYears`. Outside them this file has NO gloss — do not compose one "
                + "from a schedule that does not govern the key's era. The classification was "
                + "renumbered in \(Self.renumberedAt), so composing across that year returns a "
                + "plausible WRONG reading rather than a miss: `411` reads as Claims under the "
                + "1910–1949 schedule where the editors gloss `411.48` as Poland, and `48` reads "
                + "as British Africa — and `48` is live in TWO of this schedule's vocabularies "
                + "at once (country `British Africa`, class-8 subject `Calamities. Disasters`), "
                + "so a hand-composed reading has more than one way to be wrong. For years "
                + "listed in `notShipped`, gloss from `volume_sources` instead. This governs "
                + "GLOSSING only: whether a key is well-formed is a separate, deliberately "
                + "era-blind test, so a post-1950 key composing against these vocabularies is "
                + "expected and is not a licence to gloss it. If you are gating a whole VOLUME's "
                + "coverage span rather than a document's date, clamp the span's lower bound to "
                + "`decimalFileOpensIn` before testing containment — a volume covering 1861–1947 "
                + "holds no pre-1910 decimal keys to mislabel, and literal containment would "
                + "silence it.")

        let table = DecimalClassLabels(
            schemaVersion: 2,
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
            schedules: schedules,
            coverage: coverage)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(table)
        try data.write(to: URL(fileURLWithPath: output))
        print("[DecimalClassLabels] wrote \(output) (\(data.count) bytes)")
    }

    /// The floor a schedule's country table must clear to ship.
    ///
    /// Named rather than inline because `coverage.notShipped` publishes it: a floor a reader can
    /// see beside the count that missed it is a measurement, where a bare `100` in a guard is not.
    static let minCountries = 100

    /// The year the classification was renumbered, after which the same digits mean other things.
    static let renumberedAt = 1950

    /// The year the central decimal file opens. Published so `glossableYears` is reproducible
    /// against a span-gating consumer as well as a document-gating one — see `Coverage`.
    static let decimalFileOpensIn = 1910

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
    static func parseClasses(_ text: String) -> [String: String] {
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
        // BEFORE the line-bounded fallback, for the reason the SUMMARY pass runs before it too: the
        // block is a list of classes by construction, and the fallback stops at end-of-line. Left
        // second, the fallback claimed class 3 as "International Conferences, Congresses, Meetings
        // and" — a gloss ending on the word "and" — and this pass then skipped it as already known.
        collectFromRecordsBlock(text, into: &result)
        if let regex = try? NSRegularExpression(pattern: #"Clas\s*s\s+(\d)\s+([A-Z][^\n]{4,90})"#) {
            collect(regex, in: text, into: &result)
        }
        return result
    }

    /// The post-1950 manuals' `CLASSES OF RECORDS` block, whose glosses WRAP and whose word
    /// "Class" is itself letter-spaced on some rows (#1210).
    ///
    /// ## Two things the `Clas s N` fallback cannot do here
    /// **The word is spaced through, not just once.** The 1960–63 handbook heads most rows `Class 4`
    /// but two of them `C l a s s 4` — measured, exactly classes 4 and 5 — so a pattern that tolerates
    /// one interior space finds eight of ten and reports a schedule that misses precisely
    /// *International Trade and Commerce* and *International Informational and Educational Relations*.
    ///
    /// **The gloss runs past the line.** Class 3's is `International Conferences, Congresses,
    /// Meetings and` / `Organizations.` / `United Nations. Multilateral Treaties.` — a line-bounded
    /// capture ends it on the word "and". Every gloss in the shipped 1910–49 schedule is a complete
    /// phrase, so a truncated one is not a thin label but a wrong one.
    ///
    /// So this pass runs to the NEXT heading rather than to end-of-line, and is bounded to the block
    /// that is a list of classes by construction — the same reasoning the SUMMARY window above rests
    /// on, and for the same reason: matched over the whole document, `Class 3` also catches
    /// `Pacific Salmon Fisheries Commission 611.4261` out of the index.
    ///
    /// Runs AFTER the 1910–49 summary window, so it can never displace it — that manual has no such
    /// block and this pass finds nothing in it — and BEFORE the line-bounded `Clas s N` fallback, which
    /// would otherwise claim class 3 with a gloss ending on the word "and" and leave this pass nothing
    /// to correct.
    static func collectFromRecordsBlock(_ text: String, into result: inout [String: String]) {
        // The block heading is letter-spaced too: `C L A S S E S  O F  R E C O R D S`.
        guard let headingRegex = try? NSRegularExpression(
                pattern: #"C\s*L\s*A\s*S\s*S\s*E\s*S\s+O\s*F\s+R\s*E\s*C\s*O\s*R\s*D\s*S"#),
              let start = headingRegex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text)),
              let startRange = Range(start.range, in: text)
        else { return }
        // The block ends at the manual's own note beneath it, or after a bounded window — never at
        // end of document, or class 9's gloss would swallow the rest of the manual.
        let afterHeading = startRange.upperBound
        let cap = text.index(afterHeading, offsetBy: 3_000, limitedBy: text.endIndex) ?? text.endIndex
        let end = text.range(of: "Note:", range: afterHeading..<cap)?.lowerBound ?? cap
        let block = String(text[afterHeading..<end])

        guard let classRegex = try? NSRegularExpression(
                pattern: #"C\s*l\s*a\s*s\s*s\s+(\d)\b"#) else { return }
        let matches = classRegex.matches(in: block, range: NSRange(block.startIndex..., in: block))
        for (index, match) in matches.enumerated() {
            guard let digit = Range(match.range(at: 1), in: block).map({ String(block[$0]) }),
                  let headEnd = Range(match.range, in: block)?.upperBound else { continue }
            let glossEnd = index + 1 < matches.count
                ? (Range(matches[index + 1].range, in: block)?.lowerBound ?? block.endIndex)
                : block.endIndex
            guard headEnd < glossEnd else { continue }
            let cleaned = trimGloss(tightenPunctuation(despace(String(block[headEnd..<glossEnd]))))
            // A run-together label column ("Class 1 Class 2 …") yields an empty or tiny gloss here,
            // because the next heading follows immediately — which is exactly how the 1950–59
            // manual's flattened block declines to be read, rather than being read wrongly.
            if result[digit] == nil, cleaned.count >= 5 { result[digit] = cleaned }
        }
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

    /// The country-number table, read by the document's own column geometry (#1256).
    ///
    /// ## The columns are READ, not inferred, and that is the whole change
    /// This table is one document with three code columns, one per era, and every label the
    /// artifact composes depends on knowing which column a code sits in. The text layer discards
    /// that, so the parse this replaces INFERRED it — three codes filled the columns in order, a
    /// partial row was left-aligned when its note said `Discontinued` and right-aligned when it
    /// said `Beginning` or `Established`. `CountryTableGeometry` reads the position instead. The
    /// defects that motivated it, each measured against the source, are documented there.
    ///
    /// The NAME guards below are kept verbatim from the text parse, because they are about OCR
    /// damage rather than about layout and geometry does not make them unnecessary.
    ///
    /// - Parameter path: The country-number PDF.
    /// - Returns: One row per printed entry, its codes placed by column.
    /// - Throws: ``GenerationError`` when the table cannot be opened or parses short.
    private static func parseCountries(at path: String)
        throws -> [(name: String, codes: [String?], note: String?)]
    {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
            throw GenerationError(description: "cannot open \(path)")
        }
        guard let codeRegex = try? NSRegularExpression(pattern: #"^\d{1,3}[a-z]?$"#) else {
            throw GenerationError(description: "country-table patterns failed to compile")
        }
        func isCode(_ token: String) -> Bool {
            let bare = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            return codeRegex.firstMatch(
                in: bare, range: NSRange(bare.startIndex..., in: bare)) != nil
        }

        var result: [(name: String, codes: [String?], note: String?)] = []
        var refused = 0
        for row in CountryTableGeometry.rows(in: document, isCode: isCode) {
            let name = row.name
            // A country name is a noun phrase. These reject note prose that the row builder let
            // through: `52` shipped as `Africa."` — the tail of *Formerly "German Southwest
            // Africa."* — and glossed 1,761 documents with it.
            // A hyphen left dangling before a space is a wrap the text layer broke across two
            // column entries — `Transcaucasia-` / `Vitanvalia` are not one country.
            guard !name.contains("\""), !name.contains("- "),
                  !name.hasSuffix("."), !name.hasSuffix(","),
                  name.split(separator: " ").count <= 6,
                  name.count >= 3,
                  name.range(of: #"^[A-Z]"#, options: .regularExpression) != nil,
                  !name.lowercased().hasPrefix("country"),
                  !name.lowercased().contains("number")
            else { refused += 1; continue }
            result.append((name: name, codes: row.codes,
                           note: row.note.isEmpty ? nil : row.note))
        }

        print("[DecimalClassLabels] country rows: \(result.count) placed by column geometry; "
            + "\(refused) refused by the name guards")
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
            "60f": Correction(
                name: "Czechoslovakia",
                evidence: "Three names carry 60f in the table and two of them are the state: "
                    + "`Czechoslovakia 60f 49 49`, `Czecho-Slovak Republic 60f`, and `Ruthenia 60f "
                    + "49 49`. The shortest-name tie-break took Ruthenia — a region filed under the "
                    + "state's own number, which is what the table's parent-plus-letter convention "
                    + "produces when 60 is a REGION (`Eastern Continental Europe`) and its letters "
                    + "are the states within it. FRUS files 82 documents on `611.60F31`, US–"
                    + "Czechoslovak commerce."),
            "10": Correction(
                name: "America. Pan-America",
                evidence: "The name wraps as `America. Pan-` / `America` with `10` on the "
                    + "following line."),
        ],
        "1960-1963": [
            "51j": Correction(
                name: "Laos",
                evidence: "The born-digital country table prints this row's name twice, so the "
                    + "parse reads `Laos Laos`. Not repaired by a rule: a name whose words repeat "
                    + "is not by itself an error — Pago Pago and Walla Walla are real places — so "
                    + "collapsing repeats mechanically would license a rewrite the source does not "
                    + "support. The 1950–59 column of the same table reads `Laos` once."),
        ],
    ]

    /// The column headers reprinted on every page of the country table.
    ///
    /// Not content: a row that straddles a page break has these lines dropped into the middle of
    /// it, and treating them as name fragments or note text severed the name from its codes.
    private static let pageFurniture: Set<String> = [
        "Country", "Number", "Notes", "1910-1949", "1950-1959", "1960-1963",
    ]

    /// The last year each schedule column covers, in column order.
    static let columnSpans: [(start: Int, end: Int)] = [(1910, 1949), (1950, 1959), (1960, 1963)]

    /// The year a `Discontinued …` note names, or `nil` when it names none.
    ///
    /// Only `Discontinued` is read. `Established`/`Beginning` are handled by the right-alignment
    /// rule above and mean the opposite thing — a code that starts mid-period cannot be in the
    /// earliest column, where one that ENDS mid-period must be.
    static func discontinuedYear(in note: String) -> Int? {
        guard note.contains("Discontinued") else { return nil }
        guard let match = note.range(of: #"Discontinued[^.]*?(19\d\d)"#,
                                     options: .regularExpression) else { return nil }
        return Int(note[match].suffix(4))
    }

    /// Whether a line is nothing but reprinted column headers, however they were glued together.
    ///
    /// **`Country Country` is the whole of a bug worth more than the one-line fix suggests**
    /// (#1201). The header block is emitted once per page, and on nineteen of them the text layer
    /// runs two header cells into a single line. `pageFurniture` held only the single words, so
    /// that line fell through to the name builder, was kept as a name fragment, and the NEXT row's
    /// name became `Country Country <Name>` — which `close()` then rejected by its own
    /// `hasPrefix("country")` guard.
    ///
    /// Measured against the shipped table, that silently dropped **Switzerland (54), Newfoundland
    /// (43), Estonia, Jordan, Palestine, Principe, Les Saintes, Abaco Island and Marianne
    /// Islands** — and `Honduras (15)`, which had been hand-curated as unrecoverable when it is a
    /// complete three-column row the parser was throwing away.
    ///
    /// Tested by composition rather than by listing the glued forms: any line made only of header
    /// words is furniture, so a future scan that runs three of them together is already handled.
    static func isPageFurniture(_ line: String) -> Bool {
        let tokens = line.split(separator: " ")
        guard !tokens.isEmpty else { return false }
        return tokens.allSatisfy { pageFurniture.contains(String($0)) }
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

    /// Class glosses the scan mangles beyond mechanical recovery, supplied by curation (#1210).
    ///
    /// The same posture as ``corrections`` for countries, and for the same reason: these rows did
    /// not come from the parser, so each carries the evidence that establishes it. Both entries are
    /// single-word OCR damage in the 1960–63 handbook's `CLASSES OF RECORDS` block — the parse is
    /// otherwise complete and correct, and neither could be repaired by a rule without licensing a
    /// rule that rewrites words, which is how a label table starts inventing readings.
    ///
    /// Deliberately NOT applied to 1910–49: that manual's glosses parse clean, and an empty table
    /// for it is the honest statement that nothing there needed a hand.
    static let classCorrections: [String: [String: Correction]] = [
        "1960-1963": [
            "1": Correction(
                name: "Administration of the United States Government",
                evidence: "The scan renders the final word `Governinenl`; the 1950–59 manual's "
                    + "same block reads `Administration of the United States Government,` and the "
                    + "1910–49 schedule's class 1 is `Administrations, United States Government`."),
            "5": Correction(
                name: "International Informational and Educational Relations. Cultural Affairs. "
                    + "Psychological Warfare",
                evidence: "The scan splits the first word as `Inte rnational`; the 1950–59 manual's "
                    + "same block reads `International Informational and Educational Relations,`."),
        ],
    ]

    /// The `CLASSES OF RECORDS` block read off the PAGE, for a scan whose text layer flattens it.
    ///
    /// ## Why geometry is needed at all
    /// The 1950–59 manual sets this block in two columns, and `PDFPage.string` flattens them into a
    /// single run: the nine labels arrive together as `Class 1 Class 2 … Class 9` followed by nine
    /// unlabelled glosses. No pattern over that string can pair a class with its own gloss — matched
    /// anyway, `Class 3` binds to `Pacific Salmon Fisheries Commission 611.4261` out of the index.
    ///
    /// ## Why `characterBounds(at:)` alone does NOT work, which this file warned about
    /// The index that `string` uses and the index that `characterBounds` uses **disagree** on this
    /// page. Pairing the i-th character with the i-th box reconstructs lines like `s 1 Clas` — the
    /// letters of "Class 1" redistributed across columns. Verified before this was written.
    ///
    /// What *is* reliable is `selection(for:)`: ask the page for the text inside a RECTANGLE and it
    /// answers correctly. So this reads bands rather than characters — the label strip down the left
    /// to find each `Class N` and its y, then the full-width band from that y to the next label's,
    /// which captures a wrapped gloss without needing to guess where one ends.
    ///
    /// The strip is a FRACTION of the page's own width, never a fixed coordinate, so a differently
    /// sized scan is read on its own terms.
    ///
    /// - Parameter path: the manual.
    /// - Returns: digit → gloss, or `nil` when the page holding the block cannot be found.
    static func classesByGeometry(of path: String) -> [String: String]? {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else { return nil }
        // The block's own page, found on the letter-spacing-tolerant heading.
        guard let headingRegex = try? NSRegularExpression(
                pattern: #"C\s*L\s*A\s*S\s*S\s*E\s*S\s+O\s*F\s+R\s*E\s*C\s*O\s*R\s*D\s*S"#)
        else { return nil }
        var page: PDFPage?
        for index in 0..<document.pageCount {
            guard let candidate = document.page(at: index) else { continue }
            let text = candidate.string ?? ""
            if headingRegex.firstMatch(in: text,
                                       range: NSRange(text.startIndex..., in: text)) != nil {
                page = candidate
                break
            }
        }
        guard let page else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        let labelStripWidth = bounds.width * 0.35
        func read(_ rect: CGRect) -> String {
            (page.selection(for: rect)?.string ?? "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }
        guard let labelRegex = try? NSRegularExpression(pattern: #"Class\s+(\d)"#) else { return nil }

        // Walk the page in 1-point bands, recording where each class label first appears.
        var rows: [(digit: String, y: CGFloat)] = []
        var y = bounds.maxY
        while y > bounds.minY {
            let strip = read(CGRect(x: bounds.minX, y: y - 2, width: labelStripWidth, height: 11))
            let ns = strip as NSString
            if let match = labelRegex.firstMatch(in: strip,
                                                 range: NSRange(location: 0, length: ns.length)) {
                let digit = ns.substring(with: match.range(at: 1))
                if !rows.contains(where: { $0.digit == digit }) { rows.append((digit, y)) }
            }
            y -= 1
        }
        guard rows.count >= 2 else { return nil }
        rows.sort { $0.y > $1.y }

        var result: [String: String] = [:]
        for (index, row) in rows.enumerated() {
            // Down to just above the next label, so a wrapped gloss is included whole.
            let bottom = index + 1 < rows.count ? rows[index + 1].y + 9 : max(row.y - 60, bounds.minY)
            guard row.y + 11 > bottom else { continue }
            let band = read(CGRect(x: bounds.minX, y: bottom,
                                   width: bounds.width, height: row.y + 11 - bottom))
            // Drop the label itself; the column boundary can split a word, so this cuts after the
            // matched `Class N` rather than at a fixed offset.
            var gloss = band
            let ns = band as NSString
            if let match = labelRegex.firstMatch(in: band,
                                                 range: NSRange(location: 0, length: ns.length)) {
                gloss = ns.substring(from: match.range.location + match.range.length)
            }
            let cleaned = trimGloss(tightenPunctuation(despace(gloss)))
            if cleaned.count >= 5 { result[row.digit] = cleaned }
        }
        return result.isEmpty ? nil : result
    }

    /// Removes the space a letter-spaced scan leaves before punctuation.
    ///
    /// `despace` rejoins letters split inside a word, but the 1960–63 scan also spaces the mark
    /// itself: `Commerce . Trade`, `Economic , Industrial`, `Affairs .`. The shipped 1910–49 glosses
    /// carry no such spacing, so leaving it would make the two schedules read as different kinds of
    /// data rather than the same field from two manuals.
    ///
    /// Punctuation only — it never joins words, so it cannot invent a reading.
    static func tightenPunctuation(_ text: String) -> String {
        var out = text
        for mark in [".", ",", ";", ":"] {
            out = out.replacingOccurrences(of: " \(mark)", with: mark)
        }
        return out.replacingOccurrences(of: "  ", with: " ")
    }

    /// Today, as `yyyy-MM-dd`.
    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
