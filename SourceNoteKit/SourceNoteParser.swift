// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ParsedSourceNote

/// The result of parsing a FRUS source note string.
///
/// Cases map to the full range of archival citation patterns observed across the
/// FRUS corpus from 1905 to the present (~322,000 source notes analysed).
///
/// ## Era map
/// | Era | Volume range | Format | Example |
/// |-----|-------------|--------|---------|
/// | File No. | 1907–1920s | `File No. 3767/5.` | State Dept. bare file number |
/// | Decimal | 1910–early 1950s | `740.001121/10-1646` | Central decimal file |
/// | Subject-numeric | 1963–1973 | `Source: …, Central Files 1963–66, POL 14` | Subject-numeric files |
/// | CFPF | 1973–1979 | `Source: …, Central Foreign Policy File, P840114–1808` | P/D/N-Reel |
/// | Narrative | 1950s–present | `Source: REPO, RG N, …` | Fully structured |
///
/// ## NARA queryability
/// - `.naraCollection` — queryable by `description.recordGroupNumber` + lot/series
/// - `.lotFile` — queryable by free-text lot number search (RG 59 or RG 84)
/// - `.presidentialLibrary` — queryable by library name + collection keywords
/// - `.centralFiles` — use static URL path (no API key needed)
/// - `.cfpfFile` — link to CFPF FAQ PDF + AAD Electronic Telegrams database
/// - `.ciaCollection` — not in NARA catalog
/// - `.previouslyPublished`, `.foreignGovernmentArchive`, `.unrecognized` — no query
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 118: `tryDecimalFile()` uses only regex-matched range
///   1.2 — Session 130: added `.naraCollection`, `.ciaCollection`; enriched `.lotFile`
///          with `recordGroup`; fixed era-1/2/3 pattern gaps; RG extraction from all
///          narrative notes; front-matter support via `ParsedVolumeSources`
///   1.3 — Session 151: added `.cfpfFile`; fixed lot file regex to handle F-designator
///          (RG 84 post records); expanded period routing to pre-1906, 1906–1910,
///          1963–1973; added AAD Electronic Telegrams detection
///   1.4 — Source Explorer Phase 2 (Session 2026-07-03): relocated unchanged to the
///          `SourceNoteKit` shared target so the SPM eval harness
///          (`SourceNoteEvalGenerator`) and both app targets compile the same parser
///   1.5 — Source Explorer Phase 2 step 2 (Session 2026-07-03): added
///          `.namedFileSeries` for named office-file series and manuscript
///          collections cited without a lot number or repository
///          (`IO Files: US(P)/A/351`, `Conference files, CF 292`,
///          `Roosevelt Papers: Telegram`, `J. C. S. Files`) — the audit §2.2
///          "named file series" class. Stored as `citation_era='named_series'`;
///          no archival-neighbor key yet (the Phase 3 matcher work wires it)
public enum ParsedSourceNote: Sendable, Equatable {

    /// State Department central files identified by a decimal file number
    /// (e.g. `740.001121/10-1646`) or a bare "File No." number.
    /// Used in volumes from 1789–early 1963.
    case centralFiles(recordGroup: String, fileIdentifier: String?)

    /// State Department Central Foreign Policy Files (CFPF), 1973–1979.
    /// Records are on P-Reels, D-Reels, and N-Reels, and in the AAD
    /// Electronic Telegrams database.
    case cfpfFile(fileIdentifier: String?)

    /// State Department lot file. Includes the RG number when it can be extracted.
    /// D-designator lot files belong to RG 59; F-designator lot files belong to RG 84.
    case lotFile(recordGroup: String?, lotNumber: String, fileIdentifier: String?)

    /// Presidential library collection (Kennedy, Johnson, Nixon, Ford, Carter,
    /// Reagan, Bush, Clinton, Hoover Institution, etc.).
    case presidentialLibrary(library: String, collection: String, fileIdentifier: String?)

    /// National Archives or Washington National Records Center record with an
    /// extractable record group number. The most queryable case via NARA API v2.
    case naraCollection(
        recordGroup: String,      // e.g. "59", "330", "306"
        series: String?,          // e.g. "Central Decimal File 1910–1929"
        lotFile: String?,         // e.g. "64 D 199"
        box: String?              // e.g. "736"
    )

    /// CIA accession-based citation using "Job" numbers (e.g. `Job 80-01795R`).
    /// CIA records are not in the public NARA catalog.
    case ciaCollection(jobNumber: String?, box: String?, description: String)

    /// A named file series or manuscript collection cited without a lot number and
    /// without an extractable repository: State Department office files
    /// (`IO Files: US(P)/A/351`, `Conference files, CF 292`, `CFM Files`),
    /// agency series (`JCS Records, CCS 092 Asia`), and personal-paper collections
    /// (`Roosevelt Papers: Telegram`, `Collins Papers, Vietnam File`). The series
    /// name is the match key the Phase 3/4 collection-authority work resolves to a
    /// repository; no repository is asserted at parse time.
    case namedFileSeries(seriesName: String, fileIdentifier: String?)

    /// A foreign government archive. Raw description is preserved for display.
    case foreignGovernmentArchive(description: String)

    /// A previously published source (books, journals, other FRUS volumes).
    case previouslyPublished(citation: String)

    /// No known pattern matched. Raw text is preserved.
    case unrecognized(rawText: String)

    // MARK: - Archival neighbor matching

    /// Whether the "Documents from This Collection" query
    /// (`IndexingPipeline.relatedDocuments(for:)`) can match other documents on this
    /// note's archival key. Mirrors the matching switch in that method, so the Source
    /// Explorer can explain *why* the section is empty rather than silently hiding it.
    public var supportsArchivalNeighbors: Bool {
        archivalNeighborKey != nil
    }

    /// A short human-readable description of the archival key the related-documents query
    /// matches on (a lot number, decimal-file base, or library/collection), or `nil` when
    /// this note type isn't matched.
    public var archivalNeighborKey: String? {
        switch self {
        case .lotFile(_, let lot, _):
            return "Lot \(lot)"
        case .naraCollection(_, _, let lot?, _):
            return "Lot \(lot)"
        case .presidentialLibrary(let library, let collection, _):
            return "\(library): \(collection)"
        case .centralFiles(_, let fileId?) where fileId.contains("."):
            return fileId.components(separatedBy: "/").first?
                .trimmingCharacters(in: .whitespaces) ?? fileId
        default:
            return nil
        }
    }
}

// MARK: - ParsedVolumeSources

/// Structured data extracted from a FRUS volume's front-matter sources list.
///
/// The front matter (`<div type="sources">` or similar) lists every archive and
/// collection cited in the volume. Parsing it at index time provides context that
/// enriches terse source notes (e.g. a bare "Lot 64 D 199" can be resolved to
/// its full repository and series name from the volume source list).
///
/// Version history:
///   1.0 — Session 130: initial implementation
public struct ParsedVolumeSources: Sendable {
    /// One entry from the front-matter sources list.
    public struct Entry: Sendable {
        public let repository: String?    // e.g. "National Archives and Records Administration"
        public let recordGroup: String?   // e.g. "59"
        public let lotFile: String?       // e.g. "64 D 199"
        public let seriesName: String?    // e.g. "Central Files"
        public let rawText: String
    }
    public let volumeId: String
    public let entries: [Entry]
}

// MARK: - ArchiveCitation (embedded in footnotes)

/// A structured archival citation extracted from editorial note prose.
///
/// Footnotes frequently embed citations like:
/// "…documentation is in National Archives, RG 59, Central Decimal File 1910–1929, Box 736…"
///
/// Version history:
///   1.0 — Session 130: initial implementation
public struct ArchiveCitation: Sendable {
    public let repository: String?
    public let recordGroup: String?
    public let seriesName: String?
    public let lotFile: String?
    public let box: String?
    public let rawText: String
}

// MARK: - SourceNoteParser

/// Parses plain-text FRUS source notes into structured `ParsedSourceNote` values.
///
/// ## Pattern strategy (most-specific to most-general)
///
/// 1. `File No.` variants (era 1) — bare inline file number → `.centralFiles`
/// 2. Inline lot file (`XYZ Files: Lot …`) → `.lotFile`
/// 3. Decimal file number (`862S.01/10-1646`) → `.centralFiles`
/// 4. Bare file number variant (`5727/248.`) → `.centralFiles`
/// 5. AAD Electronic Telegrams reference → `.cfpfFile`
/// 6. Full narrative beginning with "Source:":
///    - CIA Job number → `.ciaCollection`
///    - CFPF / P-Reel / D-Reel / N-Reel → `.cfpfFile`
///    - National Archives + RG number → `.naraCollection`
///    - Lot file phrase → `.lotFile`
///    - Presidential library name → `.presidentialLibrary`
///    - State Dept. central files → `.centralFiles`
///    - Foreign archive → `.foreignGovernmentArchive`
///    - Previously published → `.previouslyPublished`
/// 7. Fallback → `.unrecognized`
///
/// ## Footnote citation extraction
/// `extractCitations(from:)` finds embedded archival citations in editorial note prose.
///
/// ## Lot file designators
/// - **D-designator** (e.g. `63D135`, `68 D 277`): RG 59 — State Dept. lot files
/// - **F-designator** (e.g. `55F44`, `56 F 28`): RG 84 — diplomatic post records
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 118: `tryDecimalFile()` extracts only regex-matched range
///   1.2 — Session 130: added NARA/CIA cases; fixed era-1/2/3 patterns; RG extraction;
///          added `extractCitations(from:)` for footnote prose
///   1.3 — Session 151: fixed `lotFileRegex` to handle F-designator (RG 84);
///          added `lotFileRecordGroup(_:)` helper; added `.cfpfFile` routing for
///          Central Foreign Policy Files and AAD Electronic Telegrams;
///          moved CFPF check before tryNARACollection so CFPF notes are correctly
///          classified rather than falling into `.naraCollection`
///   1.4 — Source Explorer Phase 1 (Session 2026-07-03): `classificationMarking(fromSourceNote:)`
///          added — the frus-sources sentence model splits a source note into
///          sentence 1 = archival citation, sentence 2 = classification markings
///          ("Secret; Nodis"), remainder = remarks; the marking sentence is extracted
///          conservatively (marking vocabulary + shape gate, nil rather than junk) and
///          stored in `document_sources.classification`
///   1.5 — Source Explorer Phase 1 adversarial-review fixes (Session 2026-07-03):
///          `classificationMarking` fragment gate hardened — fragments containing an
///          interior `.` (abbreviation splits like "Dissemination to U.S", missing-space
///          run-ons like "Priority.Drafted by Dulles") or starting with a remark verb
///          (`Drafted`/`Sent`/`Received`/`Repeated`) now return nil, closing the
///          ~0.01% junk-value residue found by the full-corpus replay
///   1.6 — Source Explorer Phase 2 (Session 2026-07-03): relocated unchanged into the
///          `SourceNoteKit` shared target (compiled directly into both app targets per
///          the FTS5Store pattern, and consumed as an SPM target by
///          `SourceNoteEvalGenerator`). Grammar untouched; the per-call `#if DEBUG`
///          parse print was removed — it emitted one line per note and would flood the
///          eval harness's 267k-note corpus runs
///   1.7 — Source Explorer Phase 2 step 2 (Session 2026-07-03): era-aware grammar v2,
///          driven by the citations.csv eval harness (audit §2.2 classes):
///          decimal refs with word/office infixes (`893.51 Manchuria/49`,
///          `740.00112 European War 1939/6363`, `396.1 GE/7–854`, `123M431/163`),
///          space-after-dot classes (`501. BC Indonesia/12–248`) and ½-suffix tails;
///          Paris Peace Conference decimal prefixes (`Paris Peace Conf. 185.001/28`
///          → RG 256); `File No.` punctuation/typo variants (`File. No.`, `File No,`,
///          `FileNo.`, `File Not`, `File Nos.`); loose lot styles (lowercase
///          `…files, lot 60 D 665`, lot-leading `Lot 71–D 440, Box 19232`, en/em-dash
///          and run-together designators); presidential-library lead notes without the
///          `Source:` prefix (`Eisenhower Library, Dulles papers, …`); lead-gated
///          manuscript repositories (`Library of Congress`, `Center of Military
///          History`, universities, historical societies); named file series →
///          `.namedFileSeries`; abstract notes with trailing citations
///          (`… Top Secret. 2 pp. Kennedy Library, NSF, …` — the 1961–1963
///          supplement encoding); `Public Papers`/`The Presidential Campaign`
///          previously-published prefixes; `lotFileNorm(_:)` canonical compact
///          lot key (`64D199`) written to `document_sources.lot_file_norm`
///   1.8 — Source Explorer Phase 2 adversarial-review fixes (Session 2026-07-03):
///          (1) colon-styled inline lots cut at the first `:` and trailing `)`
///          stripped in `splitLotAndBox` — `lotFileNorm` hardened the same way —
///          so `C.F.M. Files: Lot M–88: Box 2063` keys as `M88`, not
///          `M88:BOX2063:…` (1,024 corpus rows); (2) `tryAbstractCitationTail`
///          moved BEFORE `tryNamedFileSeries` and leading classification
///          sentences stripped from tails, so abstracts whose summary fits the
///          named-series shape route to the concrete CIA/NARA citation in the
///          tail; lead-anchored `NARA` acronym accepted as a NARA gate;
///          (3) FRC record-group derivation reads outside parentheses only, and
///          "Nixon Presidential Materials" short-circuits to its own
///          `.presidentialLibrary` identity before the FRC fallback (a
///          parenthetical secondary-copy accession can no longer misattribute
///          RG 330 to the NSC H-Files); en/em-dash box numbers (`Box H–115`)
///          extracted; (4) `tryFileNo` bare-`File` pattern keeps dotted
///          decimals intact (`File 093.11141/21.` → `093.11141/21`, not `093`)
public struct SourceNoteParser {

    public init() {}

    // MARK: - Public API

    /// Parses `sourceNote` and returns the best-matched `ParsedSourceNote`.
    public func parse(_ sourceNote: String) -> ParsedSourceNote {
        let trimmed = sourceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unrecognized(rawText: sourceNote) }

        // Era 1 — "File No." variants (bare inline file number)
        if let result = tryFileNo(trimmed) { return result }

        // Era 3b — "XYZ Files: Lot XX D XXX, Box Y" (inline lot file)
        if let result = tryInlineLotFile(trimmed) { return result }

        // Paris Peace Conference decimal file (RG 256, 1919–1931 volumes)
        if let result = tryParisPeaceConference(trimmed) { return result }

        // Era 2 — decimal file number (e.g. "862S.01/10-1646")
        if let result = tryDecimalFile(trimmed) { return result }

        // Era 2 variant — decimal class with word/office infix ("893.51 Manchuria/49")
        if let result = tryDecimalInfixFile(trimmed) { return result }

        // Era 1 variant — bare "File N/N" or bare decimal without letters
        if let result = tryBareFileNumber(trimmed) { return result }

        // Personnel decimal file without an item number ("123 Ward, Angus I.: Telegram")
        if let result = tryPersonnelFile(trimmed) { return result }

        // Decimal class without an item slash ("102.8951: Telegram")
        if let result = tryDecimalNoItem(trimmed) { return result }

        // AAD Electronic Telegrams reference (does not start with "Source:")
        if let result = tryAADTelegrams(trimmed) { return result }

        // Full narrative beginning with "Source:"
        if trimmed.hasPrefix("Source:") {
            return parseNarrative(trimmed)
        }

        // Presidential-library / manuscript-repository lead without "Source:" prefix
        // ("Eisenhower Library, Dulles papers, …" — 1952–1954 encoding)
        if let result = tryLibraryLeadNote(trimmed) { return result }

        // Loose lot styles: lowercase/comma ("PPS files, lot 64 D 563, …") and
        // lot-leading ("Lot 71–D 440, Box 19232") notes
        if let result = tryLooseLotFile(trimmed) { return result }

        // Abstract notes with a trailing citation after a page count
        // ("… Top Secret. 2 pp. Kennedy Library, NSF, …" — 1961–1963 supplements).
        // Checked BEFORE tryNamedFileSeries: an abstract's summary+classification can
        // accidentally fit the named-series shape ("Military production facilities.
        // Secret. 2 pp. CIA Files, Job 80B01285A"), which would swallow the concrete
        // queryable citation in the tail behind a junk series name.
        if let result = tryAbstractCitationTail(trimmed) { return result }

        // Named file series / named collection ("IO Files: US(P)/A/351",
        // "Conference files, CF 292", "Roosevelt Papers: Telegram", "J. C. S. Files")
        if let result = tryNamedFileSeries(trimmed) { return result }

        // Paris Peace Conference council-document series ("HD–46", "BC–29", "WCP–1133")
        if let result = tryCouncilDocumentSeries(trimmed) { return result }

        // Treaty Series print citation ("Treaty Series No. 762")
        if trimmed.hasPrefix("Treaty Series") {
            return .previouslyPublished(citation: trimmed)
        }

        return .unrecognized(rawText: trimmed)
    }

    // MARK: - Lot file normalization

    /// Canonical compact form of a lot-file number for exact-match keying:
    /// uppercase, with all whitespace and hyphen/en-dash/em-dash separators removed
    /// (`"64 D 199"`, `"64-D-199"`, `"71–D 440"` → `"64D199"`, `"71D440"`).
    ///
    /// Written to `document_sources.lot_file_norm` at index time alongside the raw
    /// `lot_file`; Phase 3 writes the same normal form from `volume_sources` so the
    /// archival-neighbor matcher becomes a single indexed equality instead of a
    /// formatting-variant fan-out.
    ///
    /// Defensive against colon-chained tails and parenthesis residue that older
    /// parses (or the Phase 3 front-matter side) may carry in a raw lot value:
    /// the value is cut at the first `:`, `(`, or `)` before compaction
    /// (`"M–88: Box 2063"` → `"M88"`, `"68 F 8) Received at 9"` → `"68F8"`), so
    /// the key always reduces to the audit's compact form.
    ///
    /// - Parameter raw: A lot number in any observed formatting (spacing, ASCII
    ///   hyphen, en/em-dash, lowercase designator).
    /// - Returns: The compact uppercase key.
    public static func lotFileNorm(_ raw: String) -> String {
        let head = raw.components(separatedBy: CharacterSet(charactersIn: ":()")).first ?? raw
        return head.uppercased().filter {
            !$0.isWhitespace && $0 != "-" && $0 != "–" && $0 != "—"
        }
    }

    // MARK: - Classification markings (frus-sources sentence model)

    /// Sentence-boundary regex: a terminal `.`/`!`/`?` followed by whitespace and an
    /// uppercase letter, `[`, or `“`/`"` opener. The lookahead avoids splitting decimal
    /// file numbers (`711.00/11–552`) and lowercase abbreviations mid-citation.
    private static let sentenceBoundaryRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[.!?]\s+(?=[A-Z\[“"])"#,
        options: []
    )

    /// First-fragment gate: the classification sentence must open with a recognised
    /// classification level (or the editors' explicit "no marking" statement).
    private static let classificationLevelRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:Top Secret|Secret|Confidential|Unclassified|Limited Official Use|Official Use Only|Restricted|No classification marking)\b"#,
        options: []
    )

    /// Extracts the classification-markings sentence from a source note, per the
    /// frus-sources sentence model (`import/import.xq`): sentence 1 is the archival
    /// citation, sentence 2 is classification markings (a short, semicolon-separated
    /// marking vocabulary — "Secret; Nodis", "Top Secret; Sensitive; Exclusively Eyes
    /// Only", "No classification marking"), and the remainder is remarks.
    ///
    /// Deliberately conservative — returns `nil` rather than junk when sentence 2 does
    /// not look like markings. Gates applied to the candidate sentence:
    /// - ≤ 100 characters and contains no digits (dates/times/box numbers are remarks);
    /// - the first semicolon-separated fragment begins with a classification level
    ///   (`Top Secret`, `Secret`, `Confidential`, `Unclassified`, `Limited Official
    ///   Use`, `Official Use Only`, `Restricted`) or `No classification marking`;
    /// - every fragment is capitalized and at most 4 words (handling caveats such as
    ///   `Nodis`, `Exdis`, `Eyes Only`, `Sensitive`, `Priority`, `Niact`, `Cherokee`);
    /// - no fragment contains an interior `.` — the simple sentence-boundary regex has
    ///   no abbreviation model, so a `.` inside a fragment means the boundary split a
    ///   citation mid-abbreviation (`Dissemination to U.S[. Government …]`) or the TEI
    ///   lacked a space after the terminal period (`Priority.Drafted by Dulles`);
    /// - no fragment starts with a remark verb (`Drafted`/`Sent`/`Received`/`Repeated`),
    ///   which rejects short capitalized remarks like `Drafted by Seward (FE/CA/RA)`
    ///   that otherwise pass the shape gate.
    ///
    /// - Parameter note: The stored source-note text (wrapper already normalised).
    /// - Returns: The marking sentence with the trailing period stripped and fragments
    ///   rejoined with `"; "`, or `nil` when no confident marking sentence exists.
    public static func classificationMarking(fromSourceNote note: String) -> String? {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let boundary = sentenceBoundaryRegex else { return nil }

        // Split into sentences on terminal punctuation followed by a capitalized word.
        let ns = text as NSString
        var sentences: [String] = []
        var start = 0
        for match in boundary.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let end = match.range.location + match.range.length
            sentences.append(ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines))
            start = end
        }
        if start < ns.length {
            sentences.append(ns.substring(from: start).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard sentences.count >= 2 else { return nil }

        // Sentence 2 is the classification candidate (sentence 1 is the citation).
        var candidate = sentences[1]
        while candidate.hasSuffix(".") { candidate = String(candidate.dropLast()) }
        candidate = candidate.trimmingCharacters(in: .whitespaces)
        guard !candidate.isEmpty, candidate.count <= 100,
              !candidate.contains(where: { $0.isNumber }) else { return nil }

        let fragments = candidate.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = fragments.first, !first.isEmpty,
              let levelRegex = classificationLevelRegex,
              levelRegex.firstMatch(in: first, range: NSRange(first.startIndex..., in: first)) != nil
        else { return nil }
        for fragment in fragments {
            guard !fragment.isEmpty,
                  fragment.first?.isUppercase == true,
                  fragment.split(separator: " ").count <= 4,
                  !fragment.contains("."),
                  fragment.range(of: #"^(?:Drafted|Sent|Received|Repeated)\b"#,
                                 options: .regularExpression) == nil
            else { return nil }
        }
        return fragments.joined(separator: "; ")
    }

    /// Extracts embedded archival citations from editorial note body text.
    ///
    /// Returns an array because a single editorial note may reference multiple
    /// archival locations.  Returns an empty array when no recognizable patterns
    /// are found.
    public func extractCitations(from text: String) -> [ArchiveCitation] {
        var results: [ArchiveCitation] = []

        // Pattern 1: "National Archives[/WNRC], RG N, Series…"
        let naPattern = #"(?:National Archives(?:\s+and\s+Records\s+Administration)?|Washington\s+National\s+Records\s+Center),?\s*RG\s+(\d+\w*),?\s*([^.;,\(]{5,60}?)(?=[.,;\(]|$)"#
        if let regex = try? NSRegularExpression(pattern: naPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let rg = match.range(at: 1).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 1)) : nil
                let series = match.range(at: 2).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces) : nil
                let rawRange = Range(match.range, in: text)
                let raw = rawRange.map { String(text[$0]) } ?? ""
                let lot = Self.lotFileRegex.flatMap { r in
                    let m = r.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw))
                    return m.flatMap { Range($0.range(at: 1), in: raw).map { String(raw[$0]) } }
                }
                let box = extractBoxNumber(from: raw)
                results.append(ArchiveCitation(
                    repository: "National Archives",
                    recordGroup: rg,
                    seriesName: series,
                    lotFile: lot,
                    box: box,
                    rawText: raw
                ))
            }
        }

        // Pattern 2: "Presidential Library, Collection name…"
        let libPattern = #"((?:[A-Z]\w+\s+)?(?:Kennedy|Johnson|Nixon|Ford|Carter|Reagan|Bush|Clinton|Obama|Eisenhower|Truman|Roosevelt|Hoover)\s+(?:Library|Presidential\s+Library|Institution))[,\s]+([^.;]{5,80}?)(?=[.,;]|$)"#
        if let regex = try? NSRegularExpression(pattern: libPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let library = match.range(at: 1).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 1)) : ""
                let collection = match.range(at: 2).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces) : ""
                let rawRange = Range(match.range, in: text)
                let raw = rawRange.map { String(text[$0]) } ?? ""
                guard !library.isEmpty else { continue }
                results.append(ArchiveCitation(
                    repository: library,
                    recordGroup: nil,
                    seriesName: collection.isEmpty ? nil : collection,
                    lotFile: nil,
                    box: extractBoxNumber(from: raw),
                    rawText: raw
                ))
            }
        }

        return results
    }

    // MARK: - Era 1: Bare File Number Variants

    /// Handles: "File No. 3767/5.", "File No 1271", "Filed No. 774/245B",
    /// "File Not 7523" (typo), "File 4478/2–3", plus the punctuation/spacing
    /// variants observed in the eval corpus: "File. No. 9254/5–7.", "File No, 352/8.",
    /// "FileNo.812.415A/125.", "File Nos. 817.00/1593, …".
    private func tryFileNo(_ text: String) -> ParsedSourceNote? {
        // Ordered from most-specific to least-specific. The first capture must start
        // with a digit so "File Nothing…" prose can never match.
        let patterns: [(String, NSRegularExpression.Options)] = [
            // File No. / Filed No. / File. No. / File No, / FileNo. / File Not / File Nos.
            (#"^File[d]?\s*[.,]?\s*Nos?[.,t]?\s*[.,]?\s*(\d[0-9A-Za-z./½–—\-]*)"#, .caseInsensitive),
            // Bare "File <number>" — same capture class as the "File No." form, so
            // dotted decimals keep their class and item ("File 093.11141/21." must
            // store "093.11141/21", not the truncated "093").
            (#"^File\s+(\d[0-9A-Za-z./½–—\-]*)"#, .caseInsensitive),      // File 774/42
        ]
        for (pat, opts) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pat, options: opts) else { continue }
            let ns = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: ns),
               let r = Range(match.range(at: 1), in: text) {
                // Prefer the decimal grammars on the text from the identifier start:
                // they keep dotted classes, office infixes, and the /item tail intact
                // ("File 312.112 B61/50." → "312.112 B61/50"), where the bare capture
                // class would stop at the first space. The infix grammar runs first —
                // its item tail keeps filing-letter suffixes ("793.94/521b") that the
                // strict digits-only tail would drop.
                let rest = String(text[r.lowerBound...])
                if let decimal = tryDecimalInfixFile(rest) ?? tryDecimalFile(rest),
                   case .centralFiles(_, let fid?) = decimal {
                    return .centralFiles(recordGroup: "RG-59", fileIdentifier: fid)
                }
                let raw = String(text[r]).trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
                return .centralFiles(recordGroup: "RG-59", fileIdentifier: raw.isEmpty ? nil : raw)
            }
        }
        return nil
    }

    // MARK: - Era 3b: Inline Lot File

    private func tryInlineLotFile(_ text: String) -> ParsedSourceNote? {
        guard let lotRange = text.range(of: #"\bFiles?:\s*Lot\s+"#,
                                        options: .regularExpression) else { return nil }
        let afterLot = String(text[lotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let (lotNumber, box) = splitLotAndBox(afterLot)
        guard !lotNumber.isEmpty else { return nil }
        let rg = lotFileRecordGroup(lotNumber)
        return .lotFile(recordGroup: rg, lotNumber: lotNumber, fileIdentifier: box)
    }

    // MARK: - Era 2: Decimal File

    private static let decimalFileRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[A-Z0-9]+\.[A-Z0-9]+/[\d–\-]+"#,
        options: .caseInsensitive
    )

    private func tryDecimalFile(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.decimalFileRegex else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let matchRange = Range(match.range, in: text) else { return nil }
        let identifier = String(text[matchRange])
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
    }

    // MARK: - Era 2 variant: Decimal File with Word/Office Infix

    /// Decimal-class citation with a word, office-symbol, or personal-name infix
    /// between the class number and the `/item` tail — the audit §2.2 bulk class.
    ///
    /// Three anchored alternatives (the class-number shape is the anchor; the tail
    /// after `/` must be digit-led — or a single filing letter — which validates the
    /// location):
    /// 1. Dotted class + optional infix: `893.51 Manchuria/49`,
    ///    `740.00112 European War 1939/6363`, `500.A15A4 Naval Armaments/153`,
    ///    `396.1 GE/7–854`, `033.4111MacDonald, Ramsay/141`, `300.115 (39)/452`,
    ///    `501. BC Indonesia/12–248` (space after the dot), `841.857 L 97/137½`.
    /// 2. Personnel/letter class without a dot: `123M431/163`, `123 F 84/16`.
    /// 3. Bare numeric file (Numerical File era, with trailing matter the strict
    ///    `bareNumberRegex` rejects): `195/597: Telegram`, `710/35a: Telegram`.
    ///
    /// The infix may not contain `/`, clause punctuation (`:`, `;`), or quotes, and is
    /// capped at 50 characters, so prose can not be swallowed into a location key. The
    /// bare-numeric alternative rejects four-digit years (`1918/19 annual report…` is
    /// prose, not a Numerical File citation).
    private static let decimalInfixRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:\d{2,3}[A-Za-z]{0,2}(?:\.\s?[0-9A-Za-z()]+)+[^/:;"“”]{0,50}?|\d{3}\s?[A-Za-z][^/:;"“”]{0,50}?|(?!(?:1[6-9]\d\d|20\d\d)\s?/)\d{3,6})\s?/\s?(?:\d[0-9A-Za-z½–—\-]*|[A-Za-z]\b)"#,
        options: []
    )

    private func tryDecimalInfixFile(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.decimalInfixRegex else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let matchRange = Range(match.range, in: text) else { return nil }
        let identifier = String(text[matchRange])
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
    }

    // MARK: - Paris Peace Conference Files (RG 256)

    /// Decimal citation prefixed with the Paris Peace Conference file designation
    /// (`Paris Peace Conf. 185.001/28`, `Paris Peace Conference 861 L.00/40`).
    /// These are RG 256 (American Commission to Negotiate Peace), not RG 59.
    /// The prefix is canonicalized to `Paris Peace Conf.` so location keys group
    /// across the spelling variants.
    private static let parisPeaceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^Paris\s+Peace\s+Conf(?:erence|\.)?\s+"#,
        options: .caseInsensitive
    )

    private func tryParisPeaceConference(_ text: String) -> ParsedSourceNote? {
        guard let prefixRegex = Self.parisPeaceRegex else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let prefixMatch = prefixRegex.firstMatch(in: text, range: nsRange),
              let prefixRange = Range(prefixMatch.range, in: text) else { return nil }
        let remainder = String(text[prefixRange.upperBound...])
        // The remainder must itself be a decimal citation (strict, then infix form).
        let decimal: ParsedSourceNote? = tryDecimalFile(remainder) ?? tryDecimalInfixFile(remainder)
        guard case .centralFiles(_, let fileId?) = decimal else { return nil }
        return .centralFiles(recordGroup: "RG-256", fileIdentifier: "Paris Peace Conf. \(fileId)")
    }

    // MARK: - Era 1 Variant: Bare Decimal/File Numbers

    /// Handles bare decimal-like numbers: "5727/248.", "No. 8130/11."
    private static let bareNumberRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:No\.\s+)?(\d{3,6}/[\d–\-]+)\s*\.?\s*$"#,
        options: []
    )

    private func tryBareFileNumber(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.bareNumberRegex else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: String(text[r]))
    }

    // MARK: - Personnel Decimal File without Item Number

    /// Personnel-class decimal citation without an item slash — the whole note is
    /// `class surname, given names` with an optional `: Telegram` suffix
    /// (`123 Ward, Angus I.: Telegram`, `130 Howe, Audrey Marie`). Anchored to the
    /// full note so prose can never match.
    private static let personnelFileRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(\d{3}\s+[A-Z][^,/:;]{1,30},[^/:;]{1,40}?)[.\s]*(?::\s*Telegram)?[.\s]*$"#,
        options: []
    )

    private func tryPersonnelFile(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.personnelFileRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let identifier = String(text[r]).trimmingCharacters(in: .whitespaces)
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
    }

    // MARK: - Decimal Class without Item Slash

    /// A dotted decimal class cited without an `/item` tail — the whole note is the
    /// class with an optional `: Telegram` suffix (`102.8951: Telegram`,
    /// `103.9151: Telegram`). Anchored to the full note.
    private static let decimalNoItemRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(\d{2,3}[A-Za-z]{0,2}\.\d[\dA-Za-z.]*?)\.?\s*(?::\s*Telegram)?\.?\s*$"#,
        options: []
    )

    private func tryDecimalNoItem(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.decimalNoItemRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: String(text[r]))
    }

    // MARK: - Paris Peace Conference Council Series

    /// Council-document designations used by the 1919 Paris Peace Conference
    /// volumes: a 2–4 letter series code, a dash, and a document number
    /// (`HD–46`, `BC–29`, `CF–42`, `WCP–1133`, `IC–175D`). The whole note is the
    /// designation, so prose can never match.
    private static let councilSeriesRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^([A-Z]{2,4})[–—\-]\d+[A-Z]?$"#,
        options: []
    )

    private func tryCouncilDocumentSeries(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.councilSeriesRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return .namedFileSeries(seriesName: String(text[r]), fileIdentifier: text)
    }

    // MARK: - AAD Electronic Telegrams (CFPF)

    /// Handles source notes referencing the Access to Archival Databases (AAD)
    /// Electronic Telegrams database, which covers CFPF records from 1973–1979.
    /// These notes do not start with "Source:" and would otherwise fall through
    /// to `.unrecognized`.
    ///
    /// Examples:
    /// - "Part of the on-line Access to Archival Databases: Electronic Telegrams, P-Reel I…"
    /// - "Part of the on-line Access to Archive Databases (http://aad.archives.gov): …"
    private func tryAADTelegrams(_ text: String) -> ParsedSourceNote? {
        guard text.range(of: "Access to Archiv", options: .caseInsensitive) != nil
                || text.contains("aad.archives.gov") else { return nil }
        return .cfpfFile(fileIdentifier: extractCFPFIdentifier(from: text))
    }

    // MARK: - Full Narrative (Era 3c / Era 4)

    private static let rgRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bRG\s+(\d+\w*)\b|\bRecord Group\s+(\d+)\b"#,
        options: .caseInsensitive
    )

    /// Matches lot file numbers with D- or F-designator across all whitespace variants.
    ///
    /// Handles:
    /// - D-designator (RG 59): `63D135`, `68 D 277`, `72D316`
    /// - F-designator (RG 84): `55F44`, `56 F 28`, `53 F 11`, `56F 158`
    private static let lotFileRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bLot\s+(\d{2,3}\s*[A-Za-z]\s*\d+)\b"#,
        options: .caseInsensitive
    )

    /// CIA Job numbers use en-dashes as often as hyphens (`Job 80–R01386R`), so the
    /// capture includes the dash variants.
    private static let jobRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bJob\s+([\w–—\-\/]+)"#,
        options: .caseInsensitive
    )

    /// Extracts the record group number from a text string.
    private func extractRG(from text: String) -> String? {
        guard let regex = Self.rgRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns) else { return nil }
        if match.range(at: 1).location != NSNotFound,
           let r = Range(match.range(at: 1), in: text) { return String(text[r]) }
        if match.range(at: 2).location != NSNotFound,
           let r = Range(match.range(at: 2), in: text) { return String(text[r]) }
        return nil
    }

    /// Extracts the lot file number from a text string.
    private func extractLotFile(from text: String) -> String? {
        guard let regex = Self.lotFileRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespaces)
    }

    private func extractBoxNumber(from text: String) -> String? {
        // En/em-dash box designations ("Box H–115", the Nixon H-Files) are as
        // common as hyphens in modern volumes, so the capture includes them.
        let pat = #"\bBox\s+([\w\-–—\.]+\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// Extracts a CFPF record identifier (P/D/N reel number) from text.
    ///
    /// Examples: `P840114–1808`, `D740218–0840`, `N760031–0012`
    private func extractCFPFIdentifier(from text: String) -> String? {
        let pattern = #"\b([PDN]\d{6}[–\-]\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// Determines the record group for a lot file based on its letter designator.
    ///
    /// - D-designator → RG 59 (State Dept. central files lot series)
    /// - F-designator → RG 84 (State Dept. diplomatic post records)
    /// - Other → RG 59 (conservative default)
    private func lotFileRecordGroup(_ lotNumber: String) -> String {
        // Digits (or the string start, for letter-first designators) + optional
        // dash/space separators + F + optional separators + digits. En/em-dash
        // separators ("57–F103") are as common as spaces in the stored corpus.
        let fPattern = #"(?:\d|^)\s*[–—\-]?\s*[Ff]\s*[–—\-]?\s*\d"#
        if lotNumber.range(of: fPattern, options: .regularExpression) != nil {
            return "RG-84"
        }
        return "RG-59"
    }

    private func parseNarrative(_ text: String) -> ParsedSourceNote {
        let body = String(text.dropFirst("Source:".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return parseNarrativeBody(body) ?? .unrecognized(rawText: text)
    }

    /// The narrative grammar, shared by `Source:`-prefixed notes and the trailing
    /// citation of abstract notes (`tryAbstractCitationTail`). Returns `nil` when no
    /// narrative pattern matches (callers decide the fallback).
    ///
    /// - Parameter body: The citation text with any `Source:` prefix removed.
    private func parseNarrativeBody(_ body: String) -> ParsedSourceNote? {
        // Previously published
        if matchesPreviouslyPublished(body) {
            return .previouslyPublished(citation: body)
        }

        // CIA Job number → .ciaCollection
        if let jobResult = tryCIACollection(body) { return jobResult }

        // Central Foreign Policy Files / P-Reel / D-Reel / N-Reel → .cfpfFile
        // (checked BEFORE tryNARACollection because CFPF notes include "RG 59"
        //  and would otherwise be misclassified as .naraCollection)
        if let cfpfResult = tryCFPFCollection(body) { return cfpfResult }

        // National Archives or WNRC with an RG number → .naraCollection
        if let naraResult = tryNARACollection(body) { return naraResult }

        // Lot file in narrative (State Dept.) → .lotFile
        if let lotResult = tryNarrativeLotFile(body) { return lotResult }

        // Presidential library → .presidentialLibrary
        if let libResult = tryPresidentialLibrary(body) { return libResult }

        // Lead-gated manuscript repository ("Library of Congress, Manuscript
        // Division, Harriman Papers, …") → .presidentialLibrary (repository role)
        if let repoResult = tryManuscriptRepositoryLead(body) { return repoResult }

        // Loose lot styles (lowercase "…files, lot 60 D 665"; en/em-dash lots) —
        // checked BEFORE matchesCentralFiles so a State Dept. lot note yields a lot
        // key instead of a junk decimal identifier
        if let lotResult = tryLooseLotFile(body) { return lotResult }

        // State Dept. central files → .centralFiles
        if matchesCentralFiles(body) {
            let identifier = extractFirstIdentifier(body)
            return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
        }

        // Foreign government archive
        if matchesForeignArchive(body) {
            return .foreignGovernmentArchive(description: body)
        }

        // Named collection lead ("Collins Papers, Vietnam File, …",
        // "JCS Records, CCS 092 Asia (6–25–48)") → .namedFileSeries
        if let seriesResult = tryNarrativeNamedSeries(body) { return seriesResult }

        return nil
    }

    // MARK: - National Archives / WNRC

    /// Derives the record group from a modern FRC accession number when the note
    /// lacks an explicit `RG N`: the RG leads the accession in
    /// `FRC 330–78–0011`, `FRC 330 70 A 1266`, and `FRC 56 79 15`. The old
    /// year-first style (`FRC 62 A 1698`) carries no RG and yields `nil`.
    private static let frcRecordGroupRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bFRC:?\s+(\d{2,3})\s*(?:[–—\-]\s*\d{2}\s*[–—\-]|\s\d{2}\s+(?:A\s+)?\d)"#,
        options: []
    )

    /// Extracts the FRC-accession-derived record group, or `nil` for the year-first
    /// accession style.
    private func extractFRCRecordGroup(from body: String) -> String? {
        guard let regex = Self.frcRecordGroupRegex else { return nil }
        let ns = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: ns),
              let r = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[r])
    }

    /// Removes parenthesized spans from a citation body. FRC accessions (and box
    /// numbers) inside parentheses describe a *secondary copy* of the document
    /// ("… WSAG Minutes … (Washington National Records Center, OSD Files,
    /// FRC 330 76 0197, Box 74, …)"), not the cited original, so identity
    /// derivations must never read them.
    private static func strippingParentheticals(_ body: String) -> String {
        body.replacingOccurrences(of: #"\([^)]*\)"#, with: "",
                                  options: .regularExpression)
    }

    private func tryNARACollection(_ body: String) -> ParsedSourceNote? {
        let naraKeywords = [
            "National Archives and Records Administration",
            "National Archives",
            "Washington National Records Center",
            "Washington National Record Center",
            "Washington Federal Records Center",
            "WNRC",
        ]
        // The bare acronym "NARA" is only trusted as a *lead* (the 1961–1963
        // abstract-tail style "NARA, RG 233, JFK Collection") — case-sensitive and
        // anchored, so prose (or the Japanese city) can never gate.
        let naraAcronymLeads = body.range(of: #"^NARA\b"#, options: .regularExpression) != nil
        guard naraAcronymLeads
                || naraKeywords.contains(where: { body.range(of: $0, options: .caseInsensitive) != nil })
        else {
            return nil
        }
        // Extract record group — required to distinguish from other uses of
        // "National Archives". Modern WNRC citations often omit "RG N" but lead the
        // FRC accession number with it ("OSD Files: FRC 330–78–0011"); that
        // derivation is only trusted when the repository *leads* the citation, so a
        // secondary "copy in WNRC…" mention can never reclassify a library-led note,
        // and only outside parentheses, so a parenthesized secondary-copy remark
        // can never lend its accession to the cited original.
        let repositoryLeads = naraAcronymLeads || naraKeywords.contains {
            body.range(of: $0, options: [.caseInsensitive, .anchored]) != nil
        }
        var rg = extractRG(from: body)
        if rg == nil {
            // Nixon Presidential Materials without an explicit RG is its own
            // collection identity (the NARA-held White House materials, cited as
            // "National Archives, Nixon Presidential Materials, NSC Files, …") —
            // short-circuited BEFORE the FRC fallback so a trailing FRC remark can
            // never misattribute a record group to these notes. Gated on the
            // repository lead and searched outside parentheticals, so a
            // "(copy in …, Nixon Presidential Materials, …)" remark on a
            // differently-led note can never hijack the classification.
            if repositoryLeads,
               let npm = tryNixonPresidentialMaterials(Self.strippingParentheticals(body)) {
                return npm
            }
            if repositoryLeads {
                rg = extractFRCRecordGroup(from: Self.strippingParentheticals(body))
            }
        }
        guard let rg else {
            // No RG number — fall through to let lot file or central files handle it
            return nil
        }
        // Extract optional components
        let lot    = extractLotFile(from: body)
        let box    = extractBoxNumber(from: body)
        let series = extractSeriesName(from: body, afterRG: rg)
        return .naraCollection(recordGroup: rg, series: series, lotFile: lot, box: box)
    }

    /// Classifies a citation of the Nixon Presidential Materials (the NARA-held
    /// White House materials, since moved to the Nixon Library) as a
    /// `.presidentialLibrary` identity: library = "Nixon Presidential Materials",
    /// collection = the first comma segment after the phrase ("NSC Files"). Called
    /// only when the body carries no explicit `RG N`, so an explicitly
    /// record-grouped citation still classifies as `.naraCollection`.
    private func tryNixonPresidentialMaterials(_ body: String) -> ParsedSourceNote? {
        guard let range = body.range(of: #"Nixon Presidential Materials(?:\s+Project)?"#,
                                     options: [.regularExpression, .caseInsensitive])
        else { return nil }
        let remainder = String(body[range.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ",.").union(.whitespaces))
        let collection = remainder.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let fileId = extractBoxOrFileString(from: remainder)
        return .presidentialLibrary(library: "Nixon Presidential Materials",
                                    collection: collection, fileIdentifier: fileId)
    }

    /// Extracts a series name from the body after the RG number.
    private func extractSeriesName(from body: String, afterRG rg: String) -> String? {
        // Look for text immediately following "RG N," — up to the next comma or lot file reference
        let rgPattern = "RG\\s+\(NSRegularExpression.escapedPattern(for: rg))\\s*,\\s*(.{5,60}?)(?:,|\\bLot\\b|$)"
        guard let regex = try? NSRegularExpression(pattern: rgPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              match.range(at: 1).location != NSNotFound,
              let r = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - CIA

    private func tryCIACollection(_ body: String) -> ParsedSourceNote? {
        guard body.range(of: #"\bCentral Intelligence Agency\b|^CIA\b"#,
                         options: .regularExpression) != nil else { return nil }
        let jobNumber: String?
        if let regex = Self.jobRegex {
            let ns = NSRange(body.startIndex..., in: body)
            if let match = regex.firstMatch(in: body, range: ns),
               let r = Range(match.range(at: 1), in: body) {
                jobNumber = String(body[r])
            } else {
                jobNumber = nil
            }
        } else {
            jobNumber = nil
        }
        let box = extractBoxNumber(from: body)
        return .ciaCollection(jobNumber: jobNumber, box: box, description: body)
    }

    // MARK: - CFPF (Central Foreign Policy Files 1973–1979)

    /// Returns true when the body contains CFPF-specific identifiers.
    ///
    /// Patterns detected:
    /// - "Central Foreign Policy File" — literal series name used in FRUS citations
    /// - P-Reel / D-Reel / N-Reel — microfilm reel designations
    /// - P######–#### / D######–#### / N######–#### — specific reel record identifiers
    private func matchesCFPF(_ body: String) -> Bool {
        let literalPatterns = [
            "Central Foreign Policy File",
            "P-Reel",
            "D-Reel",
            "N-Reel",
        ]
        for pat in literalPatterns {
            if body.range(of: pat, options: .caseInsensitive) != nil { return true }
        }
        // Reel identifier: letter + 6 digits + en-dash or hyphen + 4 digits
        if body.range(of: #"\b[PDN]\d{6}[–\-]\d{4}\b"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func tryCFPFCollection(_ body: String) -> ParsedSourceNote? {
        guard matchesCFPF(body) else { return nil }
        return .cfpfFile(fileIdentifier: extractCFPFIdentifier(from: body))
    }

    // MARK: - Lot File (narrative)

    private func tryNarrativeLotFile(_ body: String) -> ParsedSourceNote? {
        guard let lotKeyRange = body.range(of: #"\bLot\s+"#, options: .regularExpression) else { return nil }
        let afterLot = String(body[lotKeyRange.upperBound...])
        let (lotNumber, box) = splitLotAndBox(afterLot)
        guard !lotNumber.isEmpty else { return nil }
        // Determine RG from lot file letter designator:
        // F-designator → RG 84 (post records); D-designator and others → RG 59
        let rg = lotFileRecordGroup(lotNumber)
        return .lotFile(recordGroup: rg, lotNumber: lotNumber, fileIdentifier: box)
    }

    // MARK: - Presidential Library

    /// Presidential-library (and analogous manuscript-repository) keywords matched
    /// anywhere in a narrative body, shared with the lead-note gate
    /// (`tryLibraryLeadNote`).
    private static let libraryKeywords = [
        "Kennedy Library",
        "Johnson Library",
        "Nixon Presidential Library", "Nixon Library",
        "Ford Library",
        "Carter Library",
        "Reagan Library",
        "George H.W. Bush Library", "Bush Library",
        "Clinton Library",
        "Obama Library",
        "Eisenhower Library",
        "Truman Library",
        "Roosevelt Library",
        "Hoover Institution",
        "Presidential Library",
        "National Defense University",
    ]

    private func tryPresidentialLibrary(_ body: String) -> ParsedSourceNote? {
        for keyword in Self.libraryKeywords {
            guard let keyRange = body.range(of: keyword, options: .caseInsensitive) else { continue }
            // Library name = text from start to end of keyword, first segment
            let libraryRaw = String(body[body.startIndex..<keyRange.upperBound])
            let library = libraryRaw.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? keyword

            // Collection = next comma-delimited segment
            let remainder = String(body[keyRange.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: ",").union(.whitespaces))
            let collection = remainder.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? ""

            let fileId = extractBoxOrFileString(from: remainder)
            return .presidentialLibrary(library: library, collection: collection, fileIdentifier: fileId)
        }
        return nil
    }

    /// Presidential-library note without the `Source:` prefix
    /// (`Eisenhower Library, Dulles papers, "Telephone Conversations"` — the
    /// 1952–1954 encoding). The gate is a library-name *lead*: the text before the
    /// keyword must be short (≤ 40 characters) and comma-free, so a library merely
    /// mentioned inside a comma list or later prose never triggers.
    private func tryLibraryLeadNote(_ text: String) -> ParsedSourceNote? {
        for keyword in Self.libraryKeywords {
            guard let range = text.range(of: keyword, options: .caseInsensitive) else { continue }
            let prefix = text[..<range.lowerBound]
            guard prefix.count <= 40, !prefix.contains(",") else { continue }
            return tryPresidentialLibrary(text) ?? tryManuscriptRepositoryLead(text)
        }
        return tryManuscriptRepositoryLead(text)
    }

    // MARK: - Manuscript repositories (lead-gated)

    /// Non-presidential manuscript repositories that FRUS cites in the
    /// `Repository, Collection, …` narrative shape. Matched only when the
    /// repository *leads* the citation (unlike `libraryKeywords`, which match
    /// anywhere), so a passing mention can never reclassify a note.
    private static let manuscriptRepositoryKeywords = [
        "Library of Congress",
        "Center of Military History",
        "Naval Historical Center",
        "National War College",
    ]

    /// University / college / historical-society repository lead
    /// (`University of Montana, Mansfield Papers, …`,
    /// `Minnesota Historical Society, Hubert H. Humphrey Papers, …`).
    private static let institutionLeadRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^((?:[A-Z][A-Za-z.’'\-]*\s+){0,3}(?:University|College)(?:\s+of\s+[A-Z][A-Za-z\-]+)?(?:\s+Librar(?:y|ies))?|[A-Z][A-Za-z.’'\- ]{2,40}Historical Society|(?:U\.?\s?S\.?\s*)?(?:Army\s+)?Military\s+Histor(?:y|ical)\s+Institute|USAMHI)\s*,"#,
        options: []
    )

    /// Classifies a citation that *begins* with a known manuscript repository as a
    /// `.presidentialLibrary` (the repository/collection case): library = the
    /// repository, collection = the next comma segment.
    private func tryManuscriptRepositoryLead(_ body: String) -> ParsedSourceNote? {
        var repoRange: Range<String.Index>? = nil
        for keyword in Self.manuscriptRepositoryKeywords {
            if let r = body.range(of: keyword, options: [.caseInsensitive, .anchored]) {
                repoRange = r
                break
            }
        }
        if repoRange == nil, let regex = Self.institutionLeadRegex {
            let ns = NSRange(body.startIndex..., in: body)
            if let match = regex.firstMatch(in: body, range: ns) {
                repoRange = Range(match.range(at: 1), in: body)
            }
        }
        guard let repoRange else { return nil }
        let repository = String(body[repoRange]).trimmingCharacters(in: .whitespaces)
        let remainder = String(body[repoRange.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ",").union(.whitespaces))
        let collection = remainder.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !collection.isEmpty else { return nil }
        let fileId = extractBoxOrFileString(from: remainder)
        return .presidentialLibrary(library: repository, collection: collection, fileIdentifier: fileId)
    }

    // MARK: - Loose Lot Styles

    /// Lot number in any observed style: lowercase `lot`, comma-separated
    /// (`…files, lot 60 D 665, "…"`), lot-leading (`Lot 71–D 440, Box 19232`),
    /// en/em-dash separators, and run-together designators (`Lot 54–D270`). The
    /// digits-designator-digits shape is the validator, so the English word "lot"
    /// can never match.
    /// The leading digits are optional so letter-first designators
    /// (`lot M 88`, `Lot W 130`) also match; a single letter followed by digits
    /// still cannot occur in English prose after the word "lot".
    private static let looseLotRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bLot\s+((?:\d{2,3}\s*[–—\-]?\s*)?[A-Za-z]\s*[–—\-]?\s*\d+)"#,
        options: .caseInsensitive
    )

    private func tryLooseLotFile(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.looseLotRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let lotRange = Range(match.range(at: 1), in: text),
              let fullRange = Range(match.range, in: text) else { return nil }
        let lotNumber = String(text[lotRange]).trimmingCharacters(in: .whitespaces)
        let remainder = String(text[fullRange.upperBound...])
        let box = extractBoxOrFileString(from: remainder)
        return .lotFile(recordGroup: lotFileRecordGroup(lotNumber),
                        lotNumber: lotNumber, fileIdentifier: box)
    }

    // MARK: - Named File Series

    /// Series-name shape shared by the named-file-series forms: a capitalized name
    /// ending in a collection keyword (`Files`, `files`, `Papers`, `Records`,
    /// `Collection`, `file`).
    private static let seriesNamePattern =
        #"[A-Z][A-Za-z0-9 .,'’&/()\-–—]{0,50}?(?:[Ff]iles?|[Pp]apers|Records|Collection)"#

    /// Colon form: `IO Files: US(P)/A/351`, `War Trade Board Files: Panama Canal, …`.
    private static let namedSeriesColonRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "^(\(seriesNamePattern))\\s*:\\s*(\\S.*)$", options: []
    )

    /// Comma form: `Conference files, CF 292` — the key segment must contain a digit
    /// (a file designation, not prose).
    private static let namedSeriesCommaRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "^(\(seriesNamePattern))\\s*,\\s*([^,.;]{1,40}\\d[^,.;]{0,39})\\s*(?:[,.;]|$)",
        options: []
    )

    /// Whole-note form: the entire note is a collection name, optionally suffixed
    /// `: Telegram` (`J. C. S. Files`, `Roosevelt Papers: Telegram`,
    /// `Bohlen Collection`, `Food Administrator’s File`).
    private static let namedSeriesWholeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "^(\(seriesNamePattern))\\s*(?::\\s*Telegram)?\\.?$", options: []
    )

    /// Recognizes named State Department office-file series, agency series, and
    /// personal-paper collections cited without a lot number (audit §2.2 class 5).
    private func tryNamedFileSeries(_ text: String) -> ParsedSourceNote? {
        let ns = NSRange(text.startIndex..., in: text)
        // Whole-note form first: it is the most-anchored (full-string) match.
        if let regex = Self.namedSeriesWholeRegex,
           let match = regex.firstMatch(in: text, range: ns),
           let nameRange = Range(match.range(at: 1), in: text) {
            return .namedFileSeries(seriesName: String(text[nameRange]), fileIdentifier: nil)
        }
        if let regex = Self.namedSeriesColonRegex,
           let match = regex.firstMatch(in: text, range: ns),
           let nameRange = Range(match.range(at: 1), in: text),
           let keyRange = Range(match.range(at: 2), in: text) {
            let key = String(text[keyRange]).components(separatedBy: ";").first?
                .trimmingCharacters(in: CharacterSet(charactersIn: ". ")) ?? ""
            return .namedFileSeries(seriesName: String(text[nameRange]),
                                    fileIdentifier: key.isEmpty ? nil : String(key.prefix(80)))
        }
        if let regex = Self.namedSeriesCommaRegex,
           let match = regex.firstMatch(in: text, range: ns),
           let nameRange = Range(match.range(at: 1), in: text),
           let keyRange = Range(match.range(at: 2), in: text) {
            return .namedFileSeries(seriesName: String(text[nameRange]),
                                    fileIdentifier: String(text[keyRange])
                                        .trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Narrative fallback for `Source:` bodies (and abstract tails) whose *first
    /// segment* is a named collection: `Collins Papers, Vietnam File, Series VII, Z;
    /// attached…`, `JCS Records, CCS 092 Asia (6–25–48). Top Secret.`,
    /// `JCS Files. Top secret.` Runs last in the narrative grammar, so it only ever
    /// converts previously-unrecognized notes.
    private static let narrativeNamedSeriesRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^([A-Z][A-Za-z0-9 .'’&/()\-–—]{0,50}?(?:[Ff]iles?|[Pp]apers|Records|Collection))\s*(?:([,:])\s*([^.;]{1,80}?)\s*)?(?:[.;]|$)"#,
        options: []
    )

    private func tryNarrativeNamedSeries(_ body: String) -> ParsedSourceNote? {
        guard let regex = Self.narrativeNamedSeriesRegex else { return nil }
        let ns = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: ns),
              let nameRange = Range(match.range(at: 1), in: body) else { return nil }
        let fileId = Range(match.range(at: 3), in: body).map {
            String(body[$0]).trimmingCharacters(in: .whitespaces)
        }
        return .namedFileSeries(seriesName: String(body[nameRange]),
                                fileIdentifier: (fileId?.isEmpty ?? true) ? nil : fileId)
    }

    // MARK: - Abstract Notes with Trailing Citations (1961–1963 supplements)

    /// Page-count marker that separates an abstract's summary from its trailing
    /// citation (`… Top Secret. 2 pp. Kennedy Library, NSF, …`).
    private static let abstractPagesRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,3}\s+pp?\.\s+"#, options: []
    )

    /// Leading classification sentence(s) at the start of an abstract's trailing
    /// citation (`Secret. CIA, DCI Files, …`, `Top Secret; Sensitive. WNRC, …`) —
    /// stripped before the tail is parsed, so the lead-anchored narrative gates
    /// (`^CIA`, repository leads) see the citation itself and library names are
    /// not polluted with the marking.
    private static let leadingClassificationRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:Top Secret|Secret|Confidential|Unclassified|Limited Official Use|Official Use Only|Restricted|No classification marking)(?:;[^.;]{0,40})*\.\s+"#,
        options: []
    )

    /// Microfiche-supplement abstracts (1961–1963 volumes) end with
    /// `<n> pp. <citation>.` — the text after the *last* page count (with any
    /// leading classification sentence stripped) is parsed with the narrative
    /// grammar plus the loose-lot and named-series rules. Runs after the anchored
    /// location grammars but BEFORE `tryNamedFileSeries`, so an abstract whose
    /// summary happens to fit the named-series shape still routes to the concrete
    /// citation in its tail.
    private func tryAbstractCitationTail(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.abstractPagesRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: ns)
        guard let last = matches.last, let range = Range(last.range, in: text) else { return nil }
        var tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        if let strip = Self.leadingClassificationRegex {
            while let m = strip.firstMatch(in: tail, range: NSRange(tail.startIndex..., in: tail)),
                  let r = Range(m.range, in: tail) {
                tail = String(tail[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        guard tail.count >= 8 else { return nil }
        return parseNarrativeBody(tail)
            ?? tryLooseLotFile(tail)
            ?? tryNamedFileSeries(tail)
    }

    // MARK: - Central Files Keywords

    private func matchesCentralFiles(_ body: String) -> Bool {
        let keywords = [
            "Department of State", "Central Foreign Policy File",
            "Central Files", "Record Group 59", "RG 59", "RG-59",
        ]
        if keywords.contains(where: { body.range(of: $0, options: .caseInsensitive) != nil }) {
            return true
        }
        // The 1961–1963 abstract citations abbreviate the Department as "DOS"
        // ("DOS, CF, POL 32–1 MEX–US"). Lead-anchored and case-sensitive: an
        // acronym, not prose.
        return body.range(of: #"^DOS\b"#, options: .regularExpression) != nil
    }

    private func matchesForeignArchive(_ body: String) -> Bool {
        let keywords = [
            "Archivo", "Archiv", "Foreign Ministry", "Quai d'Orsay",
            "Public Record Office", "National Archives of", "Bundesarchiv",
            "Ministère", "Ministry of Foreign Affairs",
        ]
        return keywords.contains { body.range(of: $0, options: .caseInsensitive) != nil }
    }

    private func matchesPreviouslyPublished(_ body: String) -> Bool {
        let keywords = [
            "Foreign Relations of the United States",
            "Department of State Bulletin",
            // Also covers the "Public Papers of the Presidents" long form and the
            // "Public Papers: Carter, 1978, Book I" short form used by 1977+ volumes.
            "Public Papers",
            // GPO campaign-document compilation cited by the Carter volumes.
            "The Presidential Campaign",
            // The GPO Pentagon Papers print ("United States–Vietnam Relations,
            // 1945–1967, Book 10, pp. 937–940").
            "United States–Vietnam Relations",
            "Ibid", "ibid",
        ]
        return keywords.contains { body.hasPrefix($0) }
    }

    // MARK: - Utility

    /// Splits the text after a `Lot ` keyword into the lot number and an optional
    /// box/folder/file fragment. The lot number ends at the first `,`, `.`, `:`,
    /// `(`, or `)` — colon-styled inline lots (`C.F.M. Files: Lot M–88: Box 2063:
    /// US Delegation Minutes`, the 1946–54 CFM/SFM volumes) chain further segments
    /// with `:`, and a parenthesized citation (`(… Lot 68 F 8) Received at 9:32
    /// a.m.`) closes with `)` straight into remark prose — neither may be baked
    /// into the lot key.
    private func splitLotAndBox(_ text: String) -> (lot: String, box: String?) {
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ",.:()"))
        let lot   = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let remainder = parts.dropFirst().joined(separator: ",")
        return (lot: lot, box: extractBoxOrFileString(from: remainder))
    }

    private func extractBoxOrFileString(from text: String) -> String? {
        for keyword in ["Box", "Folder", "File"] {
            if let r = text.range(of: keyword, options: .caseInsensitive) {
                let fragment = String(text[r.lowerBound...])
                    .components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces)
                if let f = fragment, !f.isEmpty { return f }
            }
        }
        return nil
    }

    private func extractFirstIdentifier(_ body: String) -> String? {
        let segments = body.components(separatedBy: ",")
        for segment in segments.dropFirst() {
            let trimmed = segment.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(where: { $0.isNumber }) && trimmed.count < 60 {
                return trimmed
            }
        }
        return nil
    }
}
