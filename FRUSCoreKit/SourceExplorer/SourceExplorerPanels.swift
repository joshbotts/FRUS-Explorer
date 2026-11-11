// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(SourceNoteKit)
import SourceNoteKit
#endif

// MARK: - SourceExplorerPanels

/// The rules both Source Explorer views read while they draw their panels: the scans' caveat, the
/// central files' filing periods, the Subject-Numeric reading of a citation, and the Archival
/// Neighbors list's basis, key and empty sentence.
///
/// Each is Foundation and SourceNoteKit alone, and each sat in `SourceExplorerView`, a SwiftUI file,
/// where `MacSourceExplorerView` read it as `SourceExplorerView.<name>`; it moved here line for line,
/// with `public` on what a host reads, so that a host draws what the app draws. The view keeps each
/// name, forwarding here, so no call site in the app changes.
///
/// Version history:
///   1.0 — FRUS Explorer Light's S22c: out of `SourceExplorerView.swift` into FRUSCoreKit, with
///          `FilingManualLink` and `FilingPeriod` from the same file
public enum SourceExplorerPanels {

    /// The honesty line that rides with every resolved scan. The index places the citation in a
    /// *file range*; it cannot place it on a page.
    public static let scanCaveat = String(
        localized: "source.explorer.scans.caveat",
        defaultValue: """
        This is the scan of the file range the citation falls in, not of this document. \
        The document is somewhere inside it.
        """)

    /// All State Dept. central-file filing periods, shown when document year is unknown.
    /// Public, so the views (through `SourceExplorerView`'s name for it, which `MacSourceExplorerView` and
    /// `NARACatalogLookupView` read) and a host offer the same list.
    ///
    /// NARA's five eras (#1543): 1789–1906, 1906–1910, the decimal file's seven blocks, the
    /// Subject-Numeric File of February 1963–1973, and the Central Foreign Policy File of
    /// 1973–1979. The table ended at the fourth, and called it "subject-numeric files".
    ///
    /// ## URL notes (verified 2026-06-04)
    /// - The seven 1910-1963 sub-period pages (`/1910-1963/1910-1929` etc.) all return 404.
    ///   NARA consolidated them onto one parent page; all seven now link to `/1910-1963`.
    /// - The 1789-1906 and 1906-1910 pages load correctly.
    /// - The 1963-1973 page loads correctly.
    /// - The 1973-1979 page is the one NARA's index of the five eras links (read 2026-10-02).
    /// - All filing manual PDFs are verified present.
    public static let allFilingPeriods: [FilingPeriod] = {
        let base     = "https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files"
        // A DIRECTORY PREFIX, NOT A PAGE — see the note on `NARACatalogClient.filingManualURL`.
        // The bare path 404s (archives.gov serves no listing) while all six PDFs beneath it answer
        // 200; a 2026-08-22 audit flagged it as a dead link, and replacing it would have broken
        // every manual link below.
        let manBase  = "https://www.archives.gov/files/research/foreign-policy/state-dept/finding-aids"
        let parent   = "\(base)/1910-1963"  // sub-period pages 404; parent is canonical

        func man(_ file: String, _ label: String) -> FilingManualLink {
            FilingManualLink(url: URL(string: "\(manBase)/\(file)")!, label: label)
        }
        let m1910 = man("manual-1910-49.pdf",                         "Filing Manual 1910–49 (PDF)")
        let m1950 = man("manual-1950-59.pdf",                         "Filing Manual 1950–59 (PDF)")
        let m1955 = man("manual-1955.pdf",                            "Filing Manual 1955 (PDF)")
        let m1960 = man("manual-1960-63.pdf",                         "Filing Manual 1960–63 (PDF)")
        let m1963 = man("records-classification-handbook-1963.pdf",   "Classification Handbook 1963 (PDF)")
        let m1965 = man("dos-records-classification-handbook-1965-1973.pdf",
                                                                      "Classification Handbook 1965–73 (PDF)")

        return [
            FilingPeriod(id: "1789-1906", label: "1789–1906",
                         url: URL(string: "\(base)/1789-1906")!),

            FilingPeriod(id: "1906-1910", label: "1906–1910",
                         url: URL(string: "\(base)/1906-1910")!),

            FilingPeriod(id: "1910-1929", label: "1910–1929 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1930-1939", label: "1930–1939 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1940-1944", label: "1940–1944 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1945-1949", label: "1945–1949 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1950-1954", label: "1950–1954 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1950]),

            FilingPeriod(id: "1955-1959", label: "1955–1959 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1955]),

            FilingPeriod(id: "1960-1963", label: "1960–January 1963 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1960]),

            // 1963-1973: two handbooks, in this order — the 1963 one for February–December 1963
            // and the 1965 one, in effect from January 1964, for 1964–1973.
            // `subjectNumericCitation` takes the first for the 1963 block and the second after.
            FilingPeriod(id: "1963-1973", label: "February 1963–1973 (Subject-Numeric File)",
                         url: URL(string: "\(base)/1963-1973")!,
                         filingManuals: [m1963, m1965]),

            // 1973-1979: phased in from July 1973. NARA publishes no filing manual for it.
            FilingPeriod(id: "1973-1979", label: "1973–1979 (Central Foreign Policy File)",
                         url: URL(string: "\(base)/1973-1979")!),
        ]
    }()

    /// What Source Explorer shows for a Subject-Numeric citation (#1543): the file designation,
    /// the block of years it was filed in, and NARA's page and handbooks for the era.
    public struct SubjectNumericCitation: Equatable, Sendable {
        /// The file designation (`POL 27 VIET S`), or `nil` when the citation gives only its block.
        public let designation: String?
        /// NARA's block of years: `1963`, `1964–66`, `1967–69` or `1970–73`. `nil` when the note
        /// prints none of NARA's blocks and the document's date is unknown or outside the file's
        /// years.
        public let block: String?
        /// The handbook for the block, or both handbooks when the block is `nil`.
        public let handbooks: [FilingManualLink]
        /// NARA's finding-aid page for the Subject-Numeric File.
        public let pageURL: URL
    }

    /// The Subject-Numeric reading of a note, or `nil` when the note does not cite that file
    /// (`CollectionKeying.centralFilesReading(parsed:note:)` decides, from the citation's form).
    ///
    /// - **The designation** is the one the rule read: the stored identifier, the class key, or
    ///   the segment that opened with a Subject-Numeric lead.
    /// - **The block** is the one the note prints when that is one of NARA's three (`1964–66`,
    ///   `1967–69`, `1970–73`). The corpus also prints `1960–63` over 70 Subject-Numeric files of
    ///   1963 and `1964–67` over 4, and NARA has no block of either name, so for those — and for
    ///   a note that prints no range — the block is the one the document's own day falls in
    ///   (`subjectNumericBlock(for:)`).
    /// - **The handbook** follows the block: the 1963 handbook for 1963, the 1965 one for the
    ///   later blocks, and both when no block is known. They and the page are the `1963-1973`
    ///   row's in `allFilingPeriods`, so the panel and the no-year table offer the same links.
    public static func subjectNumericCitation(parsed: ParsedSourceNote?, note: String,
                                       documentDay: DecimalFileSegment.DocumentDay?) -> SubjectNumericCitation? {
        guard let parsed,
              let reading = CollectionKeying.centralFilesReading(parsed: parsed, note: note),
              reading.form == .subjectNumeric,
              let period = allFilingPeriods.first(where: { $0.id == "1963-1973" }) else { return nil }
        let block = CollectionKeying.printedSubjectNumericBlock(inCitation: note)
            ?? subjectNumericBlock(for: documentDay)
        let handbooks: [FilingManualLink]
        switch block {
        case "1963"?: handbooks = Array(period.filingManuals.prefix(1))
        case nil: handbooks = period.filingManuals
        default: handbooks = Array(period.filingManuals.suffix(1))
        }
        return SubjectNumericCitation(designation: reading.designation, block: block,
                                      handbooks: handbooks, pageURL: period.url)
    }

    /// The segment of the Subject-Numeric File a day falls in, as NARA divides it: February–December
    /// 1963, 1964–66, 1967–69, 1970–73. `nil` for no day and for a day outside February
    /// 1963–December 1973 — two corpus notes give a designation on a document dated before the
    /// file opened, and the panel names no block for them rather than a wrong one.
    public static func subjectNumericBlock(for day: DecimalFileSegment.DocumentDay?) -> String? {
        guard let day else { return nil }
        switch (day.year, day.month) {
        case (1963, 2...12): return "1963"
        case (1964...1966, _): return "1964–66"
        case (1967...1969, _): return "1967–69"
        case (1970...1973, _): return "1970–73"
        default: return nil
        }
    }

    /// The basis line for a parsed note — the body of `SourceExplorerView`'s `archivalNeighborBasis`, static so a test
    /// drives the line the section draws rather than a copy of it.
    ///
    /// A decimal file's band is the FILE's filing period: `DecimalFileSegment.segment(for:
    /// fallbackYear:documentDay:)` reads the year from a date-form item (`023.1/9–1454` →
    /// 1950–1954, on a document of 27 July 1945) and falls back to `documentYear` for a sequential
    /// item, which carries no year, and for an item that is `documentDay` under another year — a
    /// misprinted year digit (`740.0011 EW/8–2045` on frus1943/d394, dated 20 August 1943, stays
    /// 1940–1944). Before #1407 an en-dash item carried no year at all, so every one of them was
    /// labelled by its document's year.
    ///
    /// A note matched on its CLASS names that class (index version 69). The route asks
    /// `CollectionKeying.matchesOnClass(parsed:note:)` before anything else, and so does this
    /// line, so the sentence is about the list under it:
    /// - a Subject-Numeric file, in either wording, reads "Same Subject-Numeric file — POL 27 VIET
    ///   S", and one with no subject number "… — POL US-USSR". Until version 69 only a citation
    ///   worded through the National Archives whose stored series named the central files had
    ///   the line (#1543): a Department-led designator was matched on its stored file number and
    ///   found Department-led siblings only, so it had none, and `RG 59, Records of the
    ///   Department of State, Central Files, 1964–66, AV 12–7 US` was matched on that series and
    ///   read "Same collection — RG 59, Records of the Department of State" (181 notes, and 36
    ///   that cite a decimal number under the same words);
    /// - a decimal number worded through the National Archives reads "Same decimal file —
    ///   399.731". Its list was the class's documents before version 69 too, under "Same
    ///   collection — RG 59, Central Files 1960–63", which #1543 recorded and left (356 notes).
    ///   No filing period is named: the class route does not divide by period.
    ///
    /// A Department-led Subject-Numeric designator the class grammar does not read has no line.
    /// Its route matches the stored file number, which finds the documents that print the
    /// designation the same way, and the decimal arm below would caption it "Same decimal file"
    /// when it holds a stop (`U.S.`).
    ///
    /// This is the iOS view's line. `MacSourceExplorerView` draws no basis line.
    public static func archivalNeighborBasis(for parsed: ParsedSourceNote?, note: String, documentYear: Int?,
                                      documentDay: DecimalFileSegment.DocumentDay?) -> String? {
        if let parsed, let classKey = CollectionKeying.matchesOnClass(parsed: parsed, note: note) {
            if CollectionKeying.isSubjectNumericClass(classKey) {
                return String(localized: "source.explorer.related.basis.subjectNumeric",
                              defaultValue: "Same Subject-Numeric file — \(classKey)")
            }
            return String(localized: "source.explorer.related.basis.decimal",
                          defaultValue: "Same decimal file — \(classKey)")
        }
        if let parsed, case .centralFiles = parsed,
           CollectionKeying.isSubjectNumericCitation(parsed: parsed, note: note) {
            return nil
        }
        switch parsed {
        case .lotFile(_, let lot, _):
            return String(localized: "source.explorer.related.basis.lot",
                          defaultValue: "Same lot file — \(lot)")
        case .naraCollection(let rg, let series?, let lot, _):
            if let lot {
                return String(localized: "source.explorer.related.basis.lot",
                              defaultValue: "Same lot file — \(lot)")
            }
            return String(localized: "source.explorer.related.basis.collection",
                          defaultValue: "Same collection — RG \(rg), \(series)")
        case .centralFiles(_, let fileId?) where fileId.contains("."):
            let location = DecimalFileSegment.location(from: fileId)
            if let segment = DecimalFileSegment.segment(for: fileId, fallbackYear: documentYear,
                                                        documentDay: documentDay) {
                return String(localized: "source.explorer.related.basis.decimalSegment",
                              defaultValue: "Same decimal file — \(location), \(segment)")
            }
            return String(localized: "source.explorer.related.basis.decimal",
                          defaultValue: "Same decimal file — \(location)")
        case .presidentialLibrary(let library, _, _):
            return String(localized: "source.explorer.related.basis.library",
                          defaultValue: "Same collection — \(library)")
        default:
            return nil
        }
    }

    /// What the "Matching archival source" line under Archival Neighbors names, or `nil` when the
    /// neighbour query has no key for the note. Static so `MacSourceExplorerView` prints the same.
    ///
    /// `CollectionKeying.archivalNeighborBasis(parsed:note:)`: the class a citation worded through
    /// the National Archives gives, which is what its list is matched on, and else the parse's
    /// own key. Until index version 69 both views read the parse's key alone, which has none for
    /// such a citation, and names the record group for one worded `RG 59, Records of the
    /// Department of State, Central Files …`.
    public static func relatedMatchKey(for parsed: ParsedSourceNote?, note: String) -> String? {
        parsed.flatMap { CollectionKeying.archivalNeighborBasis(parsed: $0, note: note) }
    }

    /// Why an Archival Neighbors list is empty — which of its sentences both Source Explorer views
    /// print under the heading (`relatedEmptyState(for:note:)`).
    public enum RelatedEmptyState: Equatable, Sendable {
        /// The note has a key the neighbour query matches on, and no other indexed document has it.
        case noNeighbors
        /// A Subject-Numeric citation whose neighbours are matched on its file — the stored
        /// designation or the class key — with none found.
        case subjectNumericNoNeighbors
        /// A Subject-Numeric citation the neighbour query has no key for.
        case subjectNumericUnkeyed
        /// Any other note the neighbour query has no key for.
        case unmatched
    }

    /// Which empty state a note's Archival Neighbors list is in, static so a test drives the rule
    /// both views ask rather than a copy of it. `MacSourceExplorerView` calls it too.
    ///
    /// A Subject-Numeric citation used to fall to `.unmatched` whenever its parse has no neighbour
    /// key, and so read "This source note doesn’t cite a recognized lot file, central file, or
    /// presidential library" under the panel that names its central file (#1543). It has two states
    /// of its own, because the list is empty for two reasons. Counted by this rule over the 9,443
    /// documents that cite the file, on a full index at version 68 read with the version 69 rules
    /// (the 553 catalogue volumes at corpus `99d851c79`):
    ///
    /// - **Matched on its file, and nothing found** (`.subjectNumericNoNeighbors`), 9,390 documents:
    ///   - matched on its class key, in either wording (9,381: 5,536 worded through the National
    ///     Archives, 3,824 through the Department, 21 parsed as the Central Foreign Policy File).
    ///     `IndexingPipeline.relatedDocuments` takes this route before any other for a citation
    ///     `CollectionKeying.matchesOnClass` reads a class from, so one file has one list. 948 of
    ///     them cite a class no other document stores, and the rest reach the state only while
    ///     the volumes that share the class are not indexed. Until index version 69 the
    ///     Department's wording was matched on its stored file number, which found the documents
    ///     that print the designation the same way and none worded through the National Archives
    ///     (264 files are cited both ways); 2,613 documents stored no class at all, and 1,518 had
    ///     nothing to match on;
    ///   - worded through the Department with no class and a designation the parse stored (9:
    ///     `PS 7-1 US- USSR Barghoorn`, `UN 6 ChiCom`, a stray bracket). `relatedByDecimal`
    ///     matches the stored file number whole.
    /// - **Nothing to match on** (`.subjectNumericUnkeyed`): 52 documents. A designation the class
    ///   grammar still refuses, in either wording (45: a word no handbook area code is, with no
    ///   subject number before it — `POL Nigeria-US`, `PPT Ashe`, `POL Nodis` — or prose after the
    ///   number), and 7 that give only their block of years. `relatedDocuments` has no arm for any
    ///   of them.
    ///
    /// One has a key that is **not its file**, and is `.noNeighbors`, the sentence every keyed
    /// note has: a note parsed as the Central Foreign Policy File whose remark carries a film
    /// number (`relatedByCFPFFilm`) and whose designation is not a class. "No other indexed
    /// document was matched to the same file" would be untrue of it: the query did not ask about
    /// the file. Until version 69 this was also the state of 182 notes worded `RG 59, Records of
    /// the Department of State, Central Files, …`, which were matched on that series; they are
    /// matched on their class now.
    ///
    /// A decimal number cited through the National Archives is matched on its class too, and its
    /// empty list reads `.noNeighbors`; until version 69 it read `.unmatched`, though a query ran.
    ///
    /// A central-files citation's list is empty exactly when its direct route finds nothing: the
    /// collection authority's alias fallback does not serve one
    /// (`IndexingPipeline.aliasFallbackServes`, landing round 2), so no list here is filled with
    /// documents matched by the central files' name.
    public static func relatedEmptyState(for parsed: ParsedSourceNote?, note: String) -> RelatedEmptyState {
        guard let parsed else { return .unmatched }
        let citesTheFile = CollectionKeying.isSubjectNumericCitation(parsed: parsed, note: note)
        // `relatedDocuments`' class arm, which it takes before the parse's own key: a citation
        // matched on the class it gives (`CollectionKeying.matchesOnClass`, index version 69).
        if CollectionKeying.matchesOnClass(parsed: parsed, note: note) != nil {
            return citesTheFile ? .subjectNumericNoNeighbors : .noNeighbors
        }
        if parsed.supportsArchivalNeighbors {
            // A Department-led designation: its key is the stored file number, which is the file.
            // The other two keyed shapes are keyed by a series and by a film number.
            if citesTheFile, case .centralFiles = parsed { return .subjectNumericNoNeighbors }
            return .noNeighbors
        }
        return citesTheFile ? .subjectNumericUnkeyed : .unmatched
    }
}

// MARK: - FilingManualLink

/// A NARA filing manual PDF paired with a display label.
public struct FilingManualLink: Sendable, Equatable {
    public let url: URL
    public let label: String
}

// MARK: - FilingPeriod

/// A named NARA filing period for State Dept. central files, used in the
/// period-selection table shown when document year is unknown.
public struct FilingPeriod: Sendable {
    public let id: String
    public let label: String
    public let url: URL
    /// Filing manual PDFs that apply to this period. Empty for pre-1910 periods
    /// and other periods where NARA has not published a relevant manual.
    public let filingManuals: [FilingManualLink]

    public init(id: String, label: String, url: URL, filingManuals: [FilingManualLink] = []) {
        self.id = id
        self.label = label
        self.url = url
        self.filingManuals = filingManuals
    }
}
