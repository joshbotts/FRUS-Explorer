// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

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
///   1.1 — index version 69: a key is divided by `CollectionKeying.subjectNumericParts(of:)`,
///          so a file with no subject number gives its country to the measurement
///   1.2 — #1644: reads ``Handbook`` pages (the content stream, not PDFKit); one edition's cited
///          categories are lent to the other and an index page is no category's; the country
///          codes are one printed list for both schedules; subject labels the capture damaged
///          are curated, and a label holding its unread mark stops the run; the artifact
///          carries the abbreviations the corpus cites, counts its areas, and names the usage
///          index it was measured against; `REVIEW_OUTPUT` writes each label's place on the scan
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

        let usagePath = environment["COLLECTION_USAGE_INDEX"]
            ?? "FRUSExplorer/Resources/collection-usage-index.json"
        var schedules: [Schedule] = []
        var review: [ReviewRow] = []
        var documents: [Handbook] = []
        for source in sources {
            let path = "\(scheduleDir)/\(source.fileName)"
            documents.append(try Handbook(contentsOf: URL(fileURLWithPath: path)))
        }
        // Each edition is read twice: once by its own marks alone, to learn which categories it
        // prints an outline for, and then with the other edition's lent to it. Only a category
        // the corpus cites is lent: every label of a newly attributed outline has to be read
        // against the page before it ships, and one no key will ever ask for is not worth that.
        let cited = citedCategories(usagePath: usagePath)
        let vocabulary = zip(sources, documents).reduce(into: Set<String>()) { codes, pair in
            codes.formUnion(readOutlines(pair.1, layout: pair.0.layout).keys)
        }.intersection(cited)
        // THE COUNTRY CODES ARE ONE LIST FOR BOTH SCHEDULES. The 1963 handbook prints it ("a list
        // of standard country abbreviations … for use in coding papers relating to specific
        // countries"); the 1965 edition says of the same list that it was "eliminated but can be
        // obtained from the Division of Records Management, upon request". So the appendix of
        // whichever edition prints one is read for both, where the 1964–1973 schedule used to be
        // left with the decimal tables' names alone and no Cambodia, Libya or Saudi Arabia.
        let countryRows = documents.flatMap { CountryAbbreviationReader.pairs(in: $0) }
        let decimalNames = decimalCountryNames(environment)
        let countryCodes = CountryAbbreviationReader.codeNames(from: countryRows,
                                                               verified: decimalNames)
        // TWO NAME SOURCES, because neither is complete. The decimal schedules' country tables
        // already ship and are already verified, but they are the 1910–63 vocabulary; the
        // handbook's own appendix carries the rest and is a rougher scan. Their union is what
        // the resolver reads a tail against when the appendix does not print it as a code.
        let areaNames = Array(Set(countryRows.map { CountryAbbreviationReader.trimmedName($0.name) })
            .union(countryCodes.values).union(decimalNames)).sorted()
        // What each edition prints, read whole before either schedule is put together: the
        // common abbreviations of one are lent to the other below.
        var readings: [Reading] = []
        for (source, document) in zip(sources, documents) {
            var outlines = readOutlines(document, layout: source.layout, vocabulary: vocabulary)
            try curate(&outlines, schedule: source.id)
            var administrative = readAdministrativeSubjects(document, layout: source.layout)
            try curate(organizationSubjects: &administrative, schedule: source.id)
            readings.append(Reading(
                outlines: outlines, names: readCategoryNames(document),
                organizationSubjects: administrative,
                abbreviations: readAbbreviations(document)))
        }
        for (index, source) in sources.enumerated() {
            let reading = readings[index]
            // AN ABBREVIATION MEANS ONE THING IN BOTH EDITIONS. The 1965 appendix is the 1963
            // one "revised and updated", and each scan loses entries the other keeps: `SC`
            // (Security Council) and `GATT` are legible only in the first, `OPEC` and `OAU` are
            // only in the second. An edition's own entry is preferred and the other's fills in.
            var organizations = reading.abbreviations.mapValues(\.label)
            for (other, lent) in readings.enumerated() where other != index {
                organizations.merge(lent.abbreviations.mapValues(\.label)) { own, _ in own }
            }
            // THE ARTIFACT CARRIES THE ABBREVIATIONS THE CORPUS READS, as it carries the areas
            // the corpus writes. The app asks this table one question: what an ORGANIZATION
            // file's prefix stands for. The appendices print some four hundred entries each, a
            // rough scan nobody has read against the page; shipping them whole shipped *FM —
            // Prime Minister RCA*, and gave `AID` a piece of another entry for a name.
            let shipped = organizations.filter { code, _ in
                cited.contains(code) && reading.outlines[code] == nil
            }
            let total = reading.outlines.values.reduce(0) { $0 + $1.count }
            print("[SubjectNumericLabels] \(source.id): \(reading.outlines.count) categories, "
                  + "\(reading.names.count) named, \(total) designators, "
                  + "\(reading.organizationSubjects.count) organization subjects, "
                  + "\(reading.abbreviations.count) abbreviations read and \(shipped.count) "
                  + "shipped, \(countryCodes.count) country codes and \(areaNames.count) area "
                  + "names from \(countryRows.count) rows")
            schedules.append(Schedule(id: source.id, startYear: source.start,
                                      endYear: source.end, source: source.title,
                                      categories: reading.names,
                                      subjects: reading.outlines.mapValues {
                                          $0.mapValues(\.label)
                                      },
                                      organizationSubjects: reading.organizationSubjects
                                          .mapValues(\.label),
                                      abbreviations: shipped,
                                      areas: resolveTails(names: areaNames,
                                                          organizations: organizations,
                                                          codes: countryCodes,
                                                          usagePath: usagePath)))
            for (category, entries) in reading.outlines {
                for (designator, found) in entries {
                    review.append(ReviewRow(schedule: source.id, table: "subjects",
                                            key: "\(category) \(designator)", source: found))
                }
            }
            for (designator, found) in reading.organizationSubjects {
                review.append(ReviewRow(schedule: source.id, table: "organizationSubjects",
                                        key: designator, source: found))
            }
            for (code, found) in reading.abbreviations {
                review.append(ReviewRow(schedule: source.id, table: "abbreviations", key: code,
                                        source: found))
            }
            if diagnose {
                for code in reading.outlines.keys.sorted() {
                    let entries = reading.outlines[code] ?? [:]
                    print("    \(code): \(entries.count)")
                }
                for code in ["POL", "DEF", "CON"] {
                    guard let entries = reading.outlines[code] else { continue }
                    print("  --- \(code) ---")
                    for key in entries.keys.sorted(by: designatorOrder) {
                        print("    \(key)  \(entries[key]?.label ?? "")")
                    }
                }
            }
        }
        if let reviewPath = environment["REVIEW_OUTPUT"] {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let rows = review.sorted {
                ($0.schedule, $0.table, $0.key) < ($1.schedule, $1.table, $1.key)
            }
            try encoder.encode(rows).write(to: URL(fileURLWithPath: reviewPath))
            print("[SubjectNumericLabels] wrote \(rows.count) label sources to \(reviewPath)")
        }
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
                          namedDocuments: $0.namedDocuments, areaKeys: $0.areaKeys,
                          namedAreaKeys: $0.namedAreaKeys, areaDocuments: $0.areaDocuments,
                          namedAreaDocuments: $0.namedAreaDocuments)
                },
                measuredAgainst: usageStamp(usagePath: usagePath),
                note: coverageNote))

        let output = environment["OUTPUT"]
            ?? "FRUSExplorer/Resources/subject-numeric-labels.json"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(artifact).write(to: URL(fileURLWithPath: output))
        print("[SubjectNumericLabels] wrote \(output)")
    }

    /// What one handbook prints, as read.
    struct Reading {
        /// `code -> designator -> label and source`.
        var outlines: [String: [String: LabelSource]]
        /// `code -> name`, from the running heads.
        let names: [String: String]
        /// The list of administrative subjects an organization's file is arranged by.
        let organizationSubjects: [String: LabelSource]
        /// The common abbreviations appendix.
        let abbreviations: [String: LabelSource]
    }

    /// The category letters the corpus's subject-numeric keys open with.
    ///
    /// - Parameter usagePath: Path to `collection-usage-index.json`.
    /// - Returns: The categories, upper-cased; empty when the index cannot be read.
    static func citedCategories(usagePath: String) -> Set<String> {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: usagePath)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = object["classKeys"] as? [String]
        else { return [] }
        return Set(keys.compactMap {
            CollectionKeying.subjectNumericParts(of: $0)?.category.uppercased()
        })
    }

    // MARK: Curation

    /// Applies the hand-checked readings to one schedule's outlines, and refuses what is left
    /// of the capture's damage.
    ///
    /// - Parameters:
    ///   - outlines: The schedule's outlines, as read.
    ///   - schedule: The schedule's id.
    /// - Throws: ``GenerationError`` when a label still holds the capture's mark for a character
    ///   it could not read (see ``unreadMark``).
    static func curate(_ outlines: inout [String: [String: LabelSource]],
                       schedule: String) throws {
        for (key, label) in curatedSubjects[schedule] ?? [:] {
            let parts = key.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let read = outlines[parts[0]]?[parts[1]]
            if let label {
                // A reading that is not on any row the parse opened keeps the page of its
                // category's first entry, which is where a reviewer would begin looking.
                let page = read?.page
                    ?? outlines[parts[0]]?.values.map(\.page).min() ?? 0
                outlines[parts[0], default: [:]][parts[1]] =
                    LabelSource(label: label, page: page, y: read?.y ?? 0)
            } else {
                outlines[parts[0]]?[parts[1]] = nil
            }
        }
        let marked = outlines.flatMap { category, entries in
            entries.filter { $0.value.label.contains(unreadMark) }
                .map { "\(category) \($0.key): \($0.value.label)" }
        }.sorted()
        guard marked.isEmpty else {
            throw GenerationError(description: "\(schedule): \(marked.count) labels hold the "
                + "capture's mark for a character it could not read. Read each on the page and "
                + "add it to curatedSubjects, corrected or refused:\n  "
                + marked.joined(separator: "\n  "))
        }
    }

    /// Applies the hand-checked readings to one schedule's list of administrative subjects.
    ///
    /// - Parameters:
    ///   - subjects: The list as read, by designator.
    ///   - schedule: The schedule's id.
    /// - Throws: ``GenerationError`` when an entry still holds the capture's unread mark.
    static func curate(organizationSubjects subjects: inout [String: LabelSource],
                       schedule: String) throws {
        for (designator, label) in curatedOrganizationSubjects[schedule] ?? [:] {
            let read = subjects[designator]
            if let label {
                subjects[designator] = LabelSource(
                    label: label, page: read?.page ?? subjects.values.map(\.page).min() ?? 0,
                    y: read?.y ?? 0)
            } else {
                subjects[designator] = nil
            }
        }
        let marked = subjects.filter { $0.value.label.contains(unreadMark) }
            .map { "\($0.key): \($0.value.label)" }.sorted()
        guard marked.isEmpty else {
            throw GenerationError(description: "\(schedule): \(marked.count) administrative "
                + "subjects hold the capture's mark for a character it could not read. Read each "
                + "on the page and add it to curatedOrganizationSubjects:\n  "
                + marked.joined(separator: "\n  "))
        }
    }

    /// Entries of the list of administrative subjects corrected by hand against the printed
    /// page, by schedule and then by designator. A `nil` refuses the entry.
    static let curatedOrganizationSubjects: [String: [String: String?]] = [
        "1963": [
            // A speck before a designator (`- 8-4`, `.16-6`) left its row to the entry above:
            // `8-3` read *Secretariat - 8-4 Committees. Working Groups.* over fourteen documents.
            "8-3": "Secretariat",
            "8-4": "Committees. Working Groups.",
            "16-5": "Public Inquiries & Opinion",
            "16-6": "Nongovernmental Liaison",
        ],
    ]

    /// The capture's mark for a character it could not read.
    ///
    /// Acrobat set a word it was unsure of in a hidden font of its own, with a tilde where a
    /// character would not resolve (`BUDG~T`, `Agre~ments`). PDFKit returned those words for
    /// the 1965 handbook and dropped them for the 1963 one, so the shipped 1963 table reads
    /// `BUD 10` as *PRESIDENT'S*, the word *BUDGET* gone, and the 1964–1973 one reads `PPT 5`
    /// as *LAWS & REGULATIO~S*. Read from the content stream they are all there, and the tilde
    /// says which labels the scan damaged: none ships with one.
    static let unreadMark: Character = "~"

    /// Subject labels corrected by hand against the printed page, by schedule and then by key
    /// (`BUD 10`). A `nil` refuses the entry: what was read under that designator is not a
    /// subject.
    ///
    /// Curated rather than ruled, for the reason ``curatedOrganizationNames`` gives: this is
    /// damage to a WORD, and no rule repairs a wrong letter without licensing rewrites the page
    /// does not support.
    static let curatedSubjects: [String: [String: String?]] = [
        "1963": [
            // A designator the capture could not read ends the entry above it in the parse's
            // eyes: `11-~` and `l4~3` were taken for more of the labels of `11` and `14-2`.
            "AE 11": "RESEARCH & DEVELOPMENT",
            "AE 11-1": "Isotopes Development",
            "BUD 14-2": "Annual Authorizations",
            "BUD 14-3": "Allocations (Transfers Out)",
            // Words the capture set in its hidden font, a character short.
            "BUD 10": "PRESIDENT'S BUDGET",
            "POL 15-6": "National Symbols. Anthem.",
            "PER 11-4": "Final Salary Clearance",
            // The outline's own row. The reading came from a worked example on the page of
            // instructions before it (a folder label, `PPT 13 Marriage of Citizens Abroad`), and
            // ran on into the examples that follow.
            "PPT 13": "MARRIAGE OF CITIZENS ABROAD",
            // A word the capture broke into four, and a label that wraps onto a second line.
            "AID 12": "NON-AGRICULTURAL EXCESS PROPERTY",
            "V 31-8": "Temporary Workers and Trainees (H)",
            // The last line of the instruction beside it, set a little left of its column:
            // *ELECTIONS government and foreign interference. Sub*, over the 85 documents that
            // cite it.
            "POL 14": "ELECTIONS",
        ],
        "1964-1973": [
            // Words the capture set in its hidden font, a character short.
            "IT 11-4": "Agreements (Wwy)",
            "PPT 5": "LAWS & REGULATIONS",
            // A designator the capture misread (`l-3`, `?`) leaves its row to the entry above.
            "DEF 1-2": "Stockpiling of Strategic & Critical Materials",
            "DEF 1-3": "Military Capabilities",
            "SP 1-1": "International Cooperation",
            "SP 2": "GENERAL REPORTS & STATISTICS",
            // Labels with a word, or part of one, missing from the text layer.
            "DEF 6-8": "Mobilization. Demobilization.",
            "DEF 6-9": "Schools. Academies.",
            "DEF 9-3": "Morale. Discipline.",
            "DEF 10-1": "Agreements (Military Information Exchange)",
            "DEF 15-9": "Infrastructure",
            "PPT 9-3": "Birth Abroad of U.S. Citizen Parent(s)",
            "PPT 9-12": "Evidence Supporting Acquisition or Loss of Nationality",
            "POL 33-8": "Law of the Sea",
            "E 8-1": "Prices & Cost of Living",
            "PPT 14-3": "Prejudicial Activities (Foreign Relations)",
            // Not subjects: a run of numbers the handbook reserves, and a name from a worked
            // example (`Brown, John J.`).
            "SCI 44-49": nil,
            "PS 1": nil,

            // LABELS THE CORPUS CITES THAT SAID ANOTHER ENTRY'S WORDS, found by reading every
            // label a document cites under both schedules (#1644). None had changed since
            // #1211, so no comparison of old with new would have shown them.
            // The capture read the `1` of `DEF 1` as no number and the `7` of *VISITS.
            // MISSIONS.* as `1`, so 61 documents filed under policy, plans and readiness read
            // *VISITS. MISSIONS. S EXHIBITIONS. SHOWS. PARADES.*, and 7, 8 and 11 had no entry.
            "DEF 1": "POLICY. PLANS. READINESS.",
            "DEF 7": "VISITS. MISSIONS.",
            "DEF 8": "EXHIBITIONS. SHOWS. PARADES.",
            "DEF 11": "RESEARCH & DEVELOPMENT",
            // A first subdivision read `15-l`, `14-l`, `5-l`, `31-l` is no designator, and its
            // row went to the entry above: `DEF 15` read *BASES. IMST ALLATIOMS. 15-l Policy.
            // Plans. Background.* over 86 documents, and `SOC 14-1` had no entry for its 68.
            "DEF 15": "BASES. INSTALLATIONS.",
            "DEF 15-1": "Policy. Plans. Background.",
            "SOC 14": "HUMAN RIGHTS. RACE RELATIONS.",
            "SOC 14-1": "General Policy.",
            "POL 5": "LAW",
            "POL 5-1": "Domestic",
            "POL 31": "AIR SPACE. BOUNDARIES.",
            "POL 31-1": "Air Disputes. Violations.",
            // Two columns on one baseline (`8 … REORGANIZATION.` and `11 INSPECTIONS`), and a
            // footer that stands above the line the footer is cut at (`4/1/65`).
            "ORG 8": "ESTABLISHMENT. FUNCTIONS. REORGANIZATION.",
            "ORG 10": "MANAGEMENT IMPROVEMENT",
            "ORG 11": "INSPECTIONS",
            // A label that wraps. Its second line is set at the instructions' indent and was
            // cut with them: `POL 32-1`, 209 documents, lost *Incidents.*
            "POL 27-7": "Prisoners of War. Hostages. Civilian Internees.",
            "POL 32-1": "Territory & Boundary Disputes. Violations. Incidents.",
            "STR 4": "ECONOMIC DEFENSE ADVISORY COMMITTEE (EDAC)",
            // A note set across the whole page, read as more of the last entry above it.
            "SCI 11-1": "Area Research Programs",
            // A word the capture broke in three.
            "DEF 17": "MILITARY TRANSPORTATION",

            // THE OUTLINES THIS SCHEDULE DID NOT HAVE BEFORE #1644, read whole against the page.
            // `AID` (pp. 2–3 of its outline; the scan holds no first page, so 1 to 6 are unread).
            "AID 14-1": "PC - Policy. Plans. Coordination.",
            "AID 14-2": "PC - Reports & Statistics",
            "AID 14-3": "PC - Organizations & Conferences",
            "AID 14-4": "PC - Agreements",
            "AID 14-5": "PC - Laws & Regulations",
            "AID 14-6": "PC - Volunteers",
            "AID 14-7": "PC - Incidents",
            // The last row of its page, which stands below the line the footer is cut at.
            "AID 15-1": "PL 480 - Policy. Plans. Coordination.",
            "AID 15-2": "PL 480 - Reports & Statistics",
            "AID 15-3": "PL 480 - Organizations & Conferences",
            "AID 15-4": "PL 480 - Agreements",
            "AID 15-5": "PL 480 - Laws & Regulations",
            "AID 15-7": "PL 480 - Program Transactions",
            "AID 15-8": "Commodity Sales for Foreign Currency (Title I)",
            "AID 15-10": "Barter. Charity Uses. Voluntary Agencies. (Title III)",
            "AID 16": "COMMODITY AID",
            // `PET`.
            "PET 1": "GENERAL POLICY. PLANS.",
            "PET 10-2": "Exploration & Development",
            "PET 12-1": "Research & Technology",
            // `INT`.
            "INT 1": "GENERAL POLICY. COORDINATION.",
            "INT 2-1": "Intelligence Notes & Summaries",
            "INT 2-3": "National Intelligence Surveys (NIS)",
            "INT 3": "INTELLIGENCE ORGANIZATIONS",
            "INT 5": "LAWS & REGULATIONS",
            "INT 6": "COLLECTION OF INTELLIGENCE",
            "INT 9": "COUNTERINTELLIGENCE",
            "INT 11": "RESEARCH",
            // `CON`. Its 7 is a reserved number the capture read too roughly to be known for one.
            "CON 1": "GENERAL POLICY. PLANS.",
            "CON 2": "REPORTS & STATISTICS",
            "CON 2-1": "Consular Services Report",
            "CON 6": "FEE COLLECTION & CONTROL",
            "CON 7": nil,
            "CON 9": "TRAINING",
            // `EP`. The capture read the 7 of five designators as 1, so the outline's 7 stood
            // under 1 and four of its subdivisions under numbers the handbook does not print.
            "EP 1": "GENERAL POLICY. PLANS. COORDINATION.",
            "EP 1-1": nil,
            "EP 1-5": nil,
            "EP 1-6": nil,
            "EP 1-9": nil,
            "EP 5": "LAWS & REGULATIONS",
            "EP 6-3": "Liaison Groups",
            "EP 7": "EMERGENCY RELOCATION PROGRAM",
            "EP 7-1": "Policy. Plans. Guidelines.",
            "EP 7-5": "Emergency Action Documents (EAD)",
            "EP 7-6": "Emergency Assignments (Cadre)",
            "EP 7-7": "Executive Reserve Program",
            "EP 7-9": "Relocation Tests. Exercises.",
            "EP 8": "VITAL RECORDS PROGRAM",
            // `INCO`, the pages the scan's corner mark reads `NCO` on.
            "INCO 1": "GENERAL POLICY. PLANS.",
            "INCO 3": "ORGANIZATIONS & CONFERENCES",
            "INCO 11-1": "Inventions & Patents",
            "INCO 11-2": "Trademarks & Tradenames",
        ],
    ]

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
        prefix, and abbreviations holds the prefixes the corpus cites. A prefix absent from \
        that appendix is REFUSED rather than read from the list, because it would fit: two of \
        the categories in unnamedCategories (FG, PSL) are not central-file classes at all. The \
        country, region or organization a file is arranged under (VIET S, ARAB-ISR) is \
        read from areas, which holds the tails the corpus writes and is the same for both \
        schedules: the 1963 handbook prints the Department's list of standard country \
        abbreviations, and the 1965 edition leaves it out of print and refers to it. A tail \
        areas does not hold is shown as printed. measured counts both readings against the \
        usage index named in measuredAgainst.
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

    /// Resolves every tail the corpus writes against the names the handbook prints.
    ///
    /// Corpus-scoped, like every other index here: the artifact answers the vocabulary FRUS
    /// actually cites, and is regenerated when that changes. Shipping the whole name list and
    /// matching on device would answer tails nobody has written, at the cost of running the
    /// cover test inside a render pass.
    ///
    /// - Parameters:
    ///   - names: Every name the handbooks print.
    ///   - organizations: The common-abbreviation table.
    ///   - codes: The handbook's printed country codes.
    ///   - usagePath: Path to `collection-usage-index.json`.
    /// - Returns: `tail -> name` for the tails that resolve.
    static func resolveTails(names: [String], organizations: [String: String],
                             codes: [String: String], usagePath: String) -> [String: String] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: usagePath)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = object["classKeys"] as? [String]
        else { return [:] }
        var out: [String: String] = [:]
        for key in keys {
            guard let tail = tail(of: key), !tail.isEmpty else { continue }
            let code = AreaResolver.normalized(tail)
            guard out[code] == nil,
                  let name = AreaResolver.resolve(tail, names: names,
                                                  organizations: organizations,
                                                  curated: curatedAreas, codes: codes,
                                                  refused: refusedAreas)
            else { continue }
            out[code] = name
        }
        return out
    }

    /// Readings no rule reaches, each checked against the handbook or the record itself.
    ///
    /// Curated rather than ruled for the reason the decimal generator gives about its own
    /// corrections: these are blends and collectives, not truncations, so no rule over names can
    /// produce them without licensing readings the sources do not support. `ARAB-ISR` is the case
    /// that forced the table — left to the rules it resolved to *Arabia and Israel*, naming a
    /// country for what is a conflict between a bloc and a state, over 313 documents.
    static let curatedAreas: [String: String] = [
        "ARAB-ISR": "Arab–Israeli",
        // The 1963 country appendix prints this expansion against the code.
        "CHICOM": "China (Communist)",
        "CHINAT": "China (Nationalist)",
        // The decimal country tables carry this name; the tail drops `Republic of`, which no
        // full-cover rule may restore without also licensing partial covers everywhere.
        "THE CONGO": "Congo, Republic of the",
        // The two Vietnams, in the form the heaviest tail of the corpus has always read
        // (`VIET S`, 830 documents at #1254). The 1963 appendix prints *South Viet-Nam* and
        // *North Viet-Nam*, and its row for the first is cut in two by the scan; read by the
        // rules, the South took its name from the compass rule and the North, until #1644,
        // read *Vietnam* alone. Keyed with the qualifier first, which is how a code's key
        // orders its tokens, so both spellings of each are one entry.
        "S VIET": "Vietnam, South",
        "N VIET": "Vietnam, North",
        "N NOR VIET": "Vietnam, North",
        // The appendix's row for this code reads `WEUR`, so the code is not found and the
        // name-first table's inverted form (*Europe, Western*) would stand beside *Eastern
        // Europe*. The code-first table prints *Western Europe*.
        "EUR W": "Western Europe",
        // `LA` is not a printed code (Latin America is `LAT AM`), and by its first letters it
        // is Laos. Its two files are an arms-control volume's Latin American nuclear-free zone
        // (`DEF 18-9 LA`) and the American Republics volume's `POL LA`.
        "LA": "Latin America",
        // Portuguese Guinea, which the appendix prints `PORT GUIN`. Written with a hyphen in
        // the Africa volume that cites it, it read as two parties, Portugal and a Guinea.
        "PORT-GUIN": "Portuguese Guinea",
        // `ETH-SOM`, one document's shorter spelling of `ETH-SOMALI` (19): by its first
        // letters `SOM` is *Somaliland*, the shorter name.
        "SOM": "Somali Republic",
        // The appendix prints `NEW GUIN New Guinea`; the scan reads that row's code `NEW`, and
        // the decimal tables' inverted *Guinea, New* answered instead.
        "GUIN NEW": "New Guinea",
        // `ORG 7 AF`, the one file with this tail: field trips by the Department's officers for
        // Africa, whose bureau's symbol it is. Two of the three Africa volumes that cite it
        // gloss it, "Visits of U.S. officials to the region" and "visits, Africa", and the
        // table has always read it so. The common abbreviations' `AF` is the Air Force, which
        // the sources' new order would have put on a telegram to the embassy in South Africa
        // about an officer's transit visa.
        "AF": "Africa",
        // `IND` is the Indian Ocean, and India is `INDIA`. Its three files (`DEF 1 IND`,
        // `DEF 15 IND-US` in two spellings) are all in the Near East volume of 1964–1968,
        // whose own list of sources glosses them "defense policy, Indian Ocean" and "bases and
        // installations, Indian Ocean-U.S."; by its first letters it read *India*, over nine
        // documents on the bases there.
        "IND": "Indian Ocean",
    ]

    /// Tails that are left unread, because every reading the sources offer is another thing's.
    /// A wrong name is worse than a bare code.
    ///
    /// `EA` in `ORG 7 EA`. `ORG 7` is *VISITS*, "field trips by agency officials" in the 1963
    /// outline's words, and its files are named for whoever travelled: an agency (`ORG 7 JCS`,
    /// `ORG 7 OSD`, which the appendix names and the table reads) or one of the Department's
    /// own offices by its symbol (`S`, `U`, `D`, `AF`, `NEA`), which neither appendix prints.
    /// `ORG 7 EA` is a telegram of 1972 from Bangkok on a Deputy Assistant Secretary's call,
    /// so `EA` is the Bureau of East Asian and Pacific Affairs; by its initials it is *East
    /// Africa*.
    ///
    /// `FAA` is two things. In `ORG 7 FAA` it is the Federal Aviation Agency (one document,
    /// its Administrator's trip to Moscow in 1963), and in `POL 19 FAA`, *government of
    /// dependencies*, it is the Federation of Arab Amirates (four telegrams from the central
    /// files of 1970–73, in the Arabian Peninsula volume, whose index lists both). One tail
    /// has one reading in this table, so neither file takes one.
    ///
    /// `IA` in `POL 3 IA` (organizations and conferences, in the South and Central America
    /// volume, which glosses it "Inter-American organizations and alignments") is
    /// Inter-American, which neither appendix prints; by its initials it took the name of a
    /// row of the country list, *Iran (Azerbaijan)*.
    ///
    /// `IS` in `POL IS-US` is one document's spelling of Israel; the appendix's `IS` is the
    /// International Staff of NATO.
    ///
    /// `TR` was refused here while #1644 was being written, and is read again: the appendix
    /// prints `TR - Travel Request` in both editions, and the one volume that cites
    /// `ORG 7 TR` glosses it "visits, travel requests".
    static let refusedAreas: Set<String> = ["EA", "FAA", "IA", "IS"]

    /// Country names from the decimal schedules that already ship beside this one.
    ///
    /// - Parameter environment: Process environment, for `DECIMAL_LABELS`.
    /// - Returns: Every country name the decimal tables carry.
    static func decimalCountryNames(_ environment: [String: String]) -> Set<String> {
        let path = environment["DECIMAL_LABELS"]
            ?? "FRUSExplorer/Resources/decimal-class-labels.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schedules = object["schedules"] as? [[String: Any]]
        else { return [] }
        var out: Set<String> = []
        for schedule in schedules {
            guard let countries = schedule["countries"] as? [String: String] else { continue }
            out.formUnion(countries.values)
        }
        return out
    }

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
                if schedule.areas[AreaResolver.normalized(tail)] != nil {
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
                             areaKeys: tails, namedAreaKeys: namedTails,
                             areaDocuments: tailDocuments, namedAreaDocuments: namedTailDocuments,
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
        /// Keys that carry a country, region or organization element, and how many `areas` names.
        let areaKeys: Int
        let namedAreaKeys: Int
        /// The documents behind those keys.
        let areaDocuments: Int
        let namedAreaDocuments: Int
        let unnamed: [String]
    }

    /// The usage index a run was measured against, by its own build stamp.
    ///
    /// - Parameter usagePath: Path to `collection-usage-index.json`.
    /// - Returns: `"collection-usage-index.json generated 2026-10-11"`, or the file's name alone
    ///   when it carries no stamp.
    static func usageStamp(usagePath: String) -> String {
        let name = URL(fileURLWithPath: usagePath).lastPathComponent
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: usagePath)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let generated = object["generated"] as? String
        else { return name }
        return "\(name) generated \(generated)"
    }

    /// Splits a corpus class key into its category and designator, or `nil` when it is not
    /// subject-numeric or has no number.
    ///
    /// The division is `CollectionKeying.subjectNumericParts(of:)`, the one the app's fold and its
    /// label lookup make (a copy of its pattern stood here until index version 69). The group is
    /// a LITERAL prefix of the key by that rule, so `DEF1-1` divides to (`DEF`, `1-1`) and looks
    /// the same table row up as `DEF 1-1` without the fold having to rewrite the key — which #841
    /// forbids. A key with no number is a file under the primary subject alone (`POL US-USSR`):
    /// no outline has a subject for it, so it is not counted among the keys a schedule reads.
    ///
    /// - Parameter key: A class key as a source note wrote it.
    /// - Returns: `("POL", "27")`, or `nil`.
    static func splitSubjectNumeric(_ key: String) -> (String, String)? {
        guard let parts = CollectionKeying.subjectNumericParts(of: key),
              let number = parts.number else { return nil }
        return (parts.category.uppercased(), number)
    }

    /// Whatever follows a key's group — the country or organization the file is arranged under —
    /// without a post.
    ///
    /// A key with no number has a tail too since index version 69 (`US-USSR` of `POL US-USSR`),
    /// and it is the whole of what the app can say about such a file. A post in parentheses is
    /// left off (`USSR` of `DEF 18-3 USSR (MO)`): it names a city inside the country, and read
    /// with it the tail is two parties, so `SWITZ (GE)` would resolve to Switzerland and Germany.
    ///
    /// - Parameter key: A class key as a source note wrote it.
    /// - Returns: The tail, or `nil` when the key is not subject-numeric.
    static func tail(of key: String) -> String? {
        CollectionKeying.subjectNumericParts(of: key)?.area
    }

    // MARK: Category names

    /// Each category's own name, taken from the running heads that name it.
    ///
    /// A category is printed across many pages and the scan damages different heads differently, so
    /// the name kept is the one printed MOST OFTEN — a majority vote over the book rather than
    /// whichever page happened to be read first.
    ///
    /// - Parameter document: An open handbook.
    /// - Returns: `code -> name`.
    static func readCategoryNames(_ document: Handbook) -> [String: String] {
        var votes: [String: [String: Int]] = [:]
        for page in document.pages {
            guard let head = OutlinePageReader.runningHead(of: page) else { continue }
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

    /// One label, and where on the scan it was read (#1644).
    ///
    /// The scans stay local, so a reviewer cannot be pointed at them from the repository. The
    /// page and the height are what lets one be found again: `REVIEW_OUTPUT` writes them beside
    /// every label, and that file is what a changed label is read against the handbook from.
    struct LabelSource: Encodable, Sendable, Equatable {
        /// The label as the artifact carries it.
        let label: String
        /// The page it was read from, counted from zero in the file's own order.
        let page: Int
        /// The top of the row that opened it, in points from the page's bottom.
        let y: Double
    }

    /// One row of the review file: a label of the artifact and where it was read.
    struct ReviewRow: Encodable, Sendable {
        /// The schedule the label belongs to.
        let schedule: String
        /// Which of the schedule's tables holds it.
        let table: String
        /// Its key in that table (`POL 27`, `13-1`, `NATO`).
        let key: String
        /// The label and its place on the scan.
        let source: LabelSource
    }

    /// Which category each outline page belongs to.
    ///
    /// Pages are attributed to a category by the corner mark (`POL (p. 7)`) rather than by the
    /// running head: measured over the 1963 handbook, the corner survives on 233 of 266 outline
    /// pages against 143 for the head, and three categories — `V`, `OS`, `SOC` — have no surviving
    /// head anywhere in the book.
    ///
    /// ## Why one edition's categories are lent to the other
    /// A page whose corner mark and running head are both lost is attributed by a KNOWN code in
    /// its top strip, and "known" used to mean known from the same handbook. The 1965 scan
    /// carries no legible mark for `AID` on any page: its outline's corner reads `AID` with the
    /// page number gone, and its head `AID` with the name gone. So the code was never
    /// established there, its pages were never attributed, and the 1964–1973 schedule had no
    /// outline for `AID` at all — every numbered `AID` key of that era was then read as an
    /// ORGANIZATION file, under whatever the abbreviations appendix said `AID` was. `PET`,
    /// `CON`, `EP` and `INT`, which the corpus cites too, were lost the same way.
    ///
    /// The two editions file under the same primary subjects but for a handful, so each is read
    /// with the categories the other prints an outline for beside its own. A category with an
    /// outline is lent, never a bare code: a corner mark the scan damaged yields a code of its
    /// own (`T`, from a page of `FT`), and lent on it would be found in any strip that holds the
    /// letter. The guard on the second pass is unchanged: a strip that names two different
    /// categories is refused.
    ///
    /// - Parameters:
    ///   - document: An open handbook.
    ///   - vocabulary: Categories known from elsewhere, which the second pass may also carry to
    ///     a page that names one.
    /// - Returns: `page index -> category code`, for the pages a category could be read for.
    static func pageCodes(_ document: Handbook, vocabulary: Set<String> = []) -> [Int: String] {
        // PASS ONE establishes the vocabulary from the pages whose corner mark or running head
        // survived; PASS TWO uses it to attribute the pages where both were destroyed. The order is
        // the safety argument — a code is only ever carried to a page that names it.
        var codes: [Int: String] = [:]
        // A page of the alphabetical index, or one whose corner names the introduction, is no
        // category's, and is kept out of BOTH passes. It used to be skipped in the first and left
        // to the second, which gave an index page to whichever category its first entry cites.
        var excluded: Set<Int> = []
        for (index, page) in document.pages.enumerated() {
            guard !OutlinePageReader.isIndexPage(page) else {
                excluded.insert(index)
                continue
            }
            guard let corner = OutlinePageReader.cornerCode(of: page) else { continue }
            let code = OutlinePageReader.correctedCode(corner.code.uppercased())
            guard code != "INDEX", code != "INTROD" else {
                excluded.insert(index)
                continue
            }
            codes[index] = code
        }
        let known = Set(codes.values).union(vocabulary)
        for (index, page) in document.pages.enumerated()
        where codes[index] == nil && !excluded.contains(index) {
            guard let code = OutlinePageReader.vocabularyCode(of: page, known: known)
            else { continue }
            codes[index] = code
        }
        return codes
    }

    /// Every category's designator table, keyed by category code, each label with its place on
    /// the scan.
    ///
    /// - Parameters:
    ///   - document: An open handbook.
    ///   - layout: Where this edition prints its instruction text.
    ///   - vocabulary: Categories known from elsewhere, for the pages this handbook's own marks
    ///     leave unattributed (see ``pageCodes(_:vocabulary:)``).
    /// - Returns: `code -> designator -> label and source`.
    static func readOutlines(_ document: Handbook, layout: OutlinePageLayout.Layout,
                             vocabulary: Set<String> = []) -> [String: [String: LabelSource]] {
        let codes = pageCodes(document, vocabulary: vocabulary)
        var out: [String: [String: LabelSource]] = [:]
        for (index, page) in document.pages.enumerated() {
            guard let code = codes[index] else { continue }
            for column in OutlinePageLayout.columns(of: page, layout: layout) {
                let lines = OutlinePageLayout.entryLines(page.lines, in: column)
                let parsed = OutlineEntryParser.parse(lines, footerFloor: 100)
                for (entry, top) in zip(parsed.entries, parsed.tops)
                where out[code]?[entry.designator] == nil {
                    out[code, default: [:]][entry.designator] =
                        LabelSource(label: entry.label, page: index, y: top)
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
    static func readAdministrativeSubjects(_ document: Handbook,
                                           layout: OutlinePageLayout.Layout) -> [String: LabelSource] {
        guard let start = document.pages.firstIndex(where: { page in
            page.lines.contains { $0.text.contains("LIST OF ADMINISTRATIVE SUBJECTS") }
        }), let corner = OutlinePageReader.numericCorner(of: document.pages[start])
        else { return [:] }

        var out: [String: LabelSource] = [:]
        for (index, page) in document.pages.enumerated().dropFirst(start) {
            // The section ends where the instruction's own numbering does. Reading on until the
            // next heading would take the following instruction's entries into this list, and its
            // designators would overwrite these ones silently — they are small integers too.
            guard OutlinePageReader.numericCorner(of: page)?.instruction == corner.instruction
            else { break }
            for column in OutlinePageLayout.columns(of: page, layout: layout) {
                let lines = OutlinePageLayout.entryLines(page.lines, in: column)
                let parsed = OutlineEntryParser.parse(lines, footerFloor: 100)
                for (entry, top) in zip(parsed.entries, parsed.tops)
                where out[entry.designator] == nil {
                    out[entry.designator] = LabelSource(label: entry.label, page: index, y: top)
                }
            }
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
    /// - Returns: `code -> expansion`, each with its place on the scan.
    static func readAbbreviations(_ document: Handbook) -> [String: LabelSource] {
        var out: [String: LabelSource] = [:]
        // THE SPAN, NOT THE MATCHING PAGES. The corner mark is damaged on several appendix pages,
        // and reading only the pages that carry it intact drops whole letters of the alphabet
        // without any sign that it has: measured, `UN`, `EEC` and `OECD` were all absent while
        // `NATO` and `OAS` were present, which reads as a thin table rather than as a broken scan.
        // The appendix is contiguous, so its first and last legible pages bound it.
        let marked = document.pages.indices.filter { isAbbreviationPage(document.pages[$0]) }
        guard let first = marked.first, let last = marked.last else { return [:] }
        for (index, page) in document.pages.enumerated().dropFirst(first).prefix(last - first + 1) {
            let lines = page.lines.filter {
                $0.y > 100 && !OutlineEntryParser.isFurniture($0.text) && !isSectionLetter($0)
            }
            // THE APPENDIX IS SET IN TWO COLUMNS, and rows are grouped by `y`, so reading the page
            // whole glues a left-column entry to whatever stands beside it: `SEATO` shipped
            // carrying `TAC` and a third entry after that.
            let starts = abbreviationColumnStarts(lines)
            guard !starts.isEmpty else { continue }

            for (position, start) in starts.enumerated() {
                let end = position + 1 < starts.count ? starts[position + 1] - 5 : Double.infinity
                let column = lines.filter { $0.x >= start - 5 && $0.x < end }
                var current: (code: String, parts: [String], y: Double)?

                func close() {
                    guard let open = current else { return }
                    let label = OutlineEntryParser.tidy(open.parts.joined(separator: " "))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "- "))
                    // Lower case somewhere in the expansion is what separates an abbreviation from
                    // a primary subject's running head. Measured over both appendices, not one
                    // entry has an ALL-CAPS expansion.
                    if label.count > 2, label.contains(where: \.isLowercase),
                       !isMergedExpansion(label), out[open.code] == nil,
                       !misreadAbbreviations.contains(open.code) {
                        out[open.code] = LabelSource(
                            label: curatedOrganizationNames[open.code]
                                ?? organizationName(label),
                            page: index, y: open.y)
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
                        current = (code, rest.isEmpty ? [] : [rest], row.y)
                    } else if current != nil {
                        current?.parts.append(row.text)
                    }
                }
                close()
            }
        }
        return out
    }

    /// Where the appendix's columns of codes begin on one page.
    ///
    /// ## A column is where lines begin again and again, not wherever one begins
    /// The columns used to be found by the gaps between every position at which a line opened
    /// with a short word: more than 150 points between two of them began a new column. That
    /// leans on how the lines happen to be cut. A code set apart from its dash is a line of its
    /// own and does not open with a word and more (`FSPH`, then `- Foreign Service Procurement`
    /// 26 points on), so on a page where the capture divided most of them the right-hand column
    /// had no opener but its wrapped expansions, and was taken to begin at their indent; and a
    /// single line beginning mid-column closes the gap that finds a column at all.
    ///
    /// So a column is a position at which TWO OR MORE code-shaped lines begin, within four
    /// points of one another. The codes of a column are set flush, so every page gives its
    /// columns at least that (the last page of the 1963 appendix has two entries in its right
    /// column, `XMB` and `Zebra`), and a stray beginning has no second.
    ///
    /// - Parameter lines: The page's lines, furniture removed.
    /// - Returns: Each column's left edge, left to right.
    static func abbreviationColumnStarts(_ lines: [PageLine]) -> [Double] {
        let positions = lines.filter { opensWithCode($0.text) }.map(\.x).sorted()
        var supported: [Double] = []
        var cluster: [Double] = []
        func close() {
            if cluster.count >= 2 { supported.append(cluster[0]) }
            cluster = []
        }
        for x in positions {
            if let last = cluster.last, x - last > 4 { close() }
            cluster.append(x)
        }
        close()
        return OutlinePageLayout.columnStarts(supported)
    }

    /// Whether a line begins as an appendix entry does: with a code, alone or followed by more.
    ///
    /// - Parameter text: A line's text.
    /// - Returns: `true` when the line opens with a code-shaped word.
    static func opensWithCode(_ text: String) -> Bool {
        guard let first = text.split(separator: " ").first else { return false }
        return first.range(of: #"^[A-Za-z][A-Za-z0-9/.]{0,7}$"#, options: .regularExpression) != nil
    }

    /// Whether a line is one of the appendix's section letters: a single letter, set large, at
    /// the head of each letter of the alphabet.
    ///
    /// Left in, it is read as the last word of the entry above it: the shipped table has
    /// `FON` as *Foreign Office Note H*.
    ///
    /// - Parameter line: A line of an appendix page.
    /// - Returns: `true` for a section letter.
    static func isSectionLetter(_ line: PageLine) -> Bool {
        line.text.count == 1 && line.height >= sectionLetterHeight
    }

    /// The least type size of a section letter. The appendix's text is set at nine to ten
    /// points and its section letters at fifteen and over.
    static let sectionLetterHeight = 13.0

    /// Table rows that keep the left edge of their first piece, and their height on the page.
    ///
    /// ``OutlineEntryParser/rows(_:)`` discards the edge, which is right for an outline — a
    /// designator is recognised by its shape. Here the shape is not enough, so the geometry has to
    /// survive.
    ///
    /// - Parameter lines: Geometry-ordered lines.
    /// - Returns: One row per line group, with its leftmost x and its first line's y.
    static func rowsWithX(_ lines: [PageLine]) -> [(text: String, x: Double, y: Double)] {
        OutlineEntryParser.rowGroups(lines).map { group in
            let sorted = group.sorted { $0.x < $1.x }
            return (sorted.map(\.text).joined(separator: " "), sorted[0].x, group[0].y)
        }
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

    /// An organization's name, from its appendix entry.
    ///
    /// The appendix glosses many of its entries: CENTO's runs to its members and its
    /// headquarters, OPEC's to the conference that founded it. The app shows the name before a
    /// file's country and subject, where a gloss of a hundred and eighty characters buries
    /// both, so the name is the entry up to its gloss: a parenthesis longer than a short
    /// qualifier (`(UN)` and `(U.S.)` are kept), or a second sentence.
    ///
    /// - Parameter entry: An appendix expansion, tidied.
    /// - Returns: The name.
    static func organizationName(_ entry: String) -> String {
        var name = entry
        if let sentence = name.range(of: #"(?<=[a-z\)])\. +(?=[A-Z])"#,
                                     options: .regularExpression) {
            name = String(name[..<sentence.lowerBound])
        }
        if let open = name.range(of: " ("),
           name[open.upperBound...].prefix(while: { $0 != ")" }).count > shortQualifier {
            name = String(name[..<open.lowerBound])
        }
        // The scan spaces and cases the United States' qualifier four ways.
        name = name.replacingOccurrences(of: #"\((?:U|u)\. ?(?:S|s)\. ?\)"#, with: "(U.S.)",
                                         options: .regularExpression)
        return name.trimmingCharacters(in: CharacterSet(charactersIn: " .,;-"))
    }

    /// The longest parenthesis that is part of a name and not a gloss on it.
    static let shortQualifier = 6

    /// Organization names the scan damaged, corrected by hand against the manual.
    ///
    /// Curated rather than ruled, for the reason the decimal generator gives about its own
    /// corrections: these are OCR damage in a NAME, and no rule can repair a wrong letter without
    /// licensing rewrites the source does not support. Each is checked against the printed page.
    static let curatedOrganizationNames: [String: String] = [
        // h1963 Com. Abbrev.: the scan reads the initial U of "United" as "Uh".
        "UN": "United Nations",
        "USSR": "Union of Soviet Socialist Republics",
        // Read on the page for #1644; each is cited by the corpus as a file's area.
        "ANZUS": "Australia, New Zealand, U.S. Treaty",
        "ECE": "Economic Commission for Europe (UN)",
        "JCS": "Joint Chiefs of Staff",
        // As printed, in both editions: the entry sets "Agency" and "Administration" together.
        "NASA": "National Aeronautics and Space Agency Administration (U.S.)",
        // The scan loses the word that ends the first line of the entry.
        "OECD": "Organization for Economic Cooperation and Development",
    ]

    /// Codes the appendix does not print, read by the scan from another entry's.
    ///
    /// `FM` is `PM`, Prime Minister. The corpus has one key that opens with `FM` (`FM 10-1`, in
    /// a volume on foreign assistance and trade), and left in, it would be read as a file of
    /// the Prime Minister's, arranged by the list of administrative subjects.
    static let misreadAbbreviations: Set<String> = ["FM"]

    /// Whether a page belongs to the COMMON ABBREVIATIONS appendix, by its own corner mark.
    ///
    /// ## The mark reads `Corn. Abbrev.` on the appendix's first page in both handbooks
    /// The capture took the `m` of `Com.` for `rn` on five of the 1963 appendix's thirteen pages
    /// and on the first two of the 1965 one's. A test for `Com.` alone therefore found the 1963
    /// appendix from its second page and the 1965 one from its third, and the span between the
    /// first and last marked page never held the first: no code under A or B was read in
    /// 1963, and none before `CINCEUR` in 1965, where `CENTO` stands. Each handbook's own
    /// entry for `AID` (*Agency for International Development*) is on its first page; the table
    /// had instead a piece of a wrapped expansion from a later one.
    ///
    /// - Parameter page: The page to test.
    /// - Returns: `true` when the page is part of the appendix.
    static func isAbbreviationPage(_ page: HandbookPage) -> Bool {
        let text = page.text(inTop: 60)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        return text.contains("Com.Abbrev") || text.contains("Corn.Abbrev")
    }

    /// `MAAG - Military Assistance Advisory Group`, the code being short and the dash optional.
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
