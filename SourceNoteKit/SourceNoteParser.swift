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
///   1.6 — Source Explorer Phase 3 adversarial-review fixes (Session 2026-07-03):
///          shared lot grammar accepts a plural lead (`Lots 64 D 563 and …`) and a
///          spaced letter suffix (`Lot 61 D 282 A` — norm parity with the legacy
///          doc-side captures); the class gate rejects run-together record-group /
///          records-center forms (`RG59`, `NYFRC 84-84-002`) and numbered-issuance
///          identifiers (NSDM/NSSM/NSAM/NSC/NIE/SNIE/PL, PRC accessions); the
///          citation class scan (`decimalClassLocation`) is bounded to the citation
///          sentence so remark sentences can never contribute a class key
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
///   1.9 — Source Explorer Phase 3 step 1 (Session 2026-07-03): the loose-lot
///          grammar extracted into the public `firstLotReference(in:)` helper so the
///          front-matter side (`SourcesParserDelegate`) recognizes exactly the same
///          lot grammar as the document side — one designator-agnostic shape for
///          both. The shared pattern additionally skips a `File`/`Files` infix
///          (`Lot File 57 D 577`, `Lot Files 74 D 131` — the audit §2.3 greedy-prefix
///          pollution, which previously keyed `lot="Files 74 D 131"` on the
///          front-matter side and missed entirely on the document side)
///   1.10 — Source Explorer Phase 3 verification fixes (Session 2026-07-03): shared
///          decimal / subject-numeric class grammar — `decimalClassKey(_:)` (the
///          anchored shape gate + canonical form: collapsed whitespace, Unicode
///          dashes → ASCII hyphen, bridging TEI front matter's en-dash against the
///          hyphen document notes use) and `decimalClassLocation(inCitation:)`
///          (comma-segment scan with `/`-suffix and sentence-tail cuts) — so the
///          front-matter class leaves and the citing documents write the identical
///          key. Verification found the class path dead end-to-end without this:
///          0 of 2,850 audit class leaves keyed, and no doc-side column to match.
///          Same pass: the shared lot grammar accepts a single trailing letter
///          suffix (`Lot 61 D 282A` — the two sides' norms diverged, `61D282` vs
///          `61D282A`), and the subject-numeric class shape accepts a parenthesized
///          agency qualifier (`AID (US) 15-4 UAR`)
///   1.11 — Source Explorer Phase 4 step 1 (Session 2026-07-03): `citationSentence(of:)`
///          made public (grammar unchanged) so the collection-authority generator
///          (`CollectionAuthorityGeneratorCore`) tokenizes exactly the sentence the
///          class scan is bounded to when deriving leading-segment authority keys
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

    // MARK: - Decimal / subject-numeric class keys (shared grammar)

    /// Subject-numeric class-leaf shape (`POL 27 ARAB-ISR`, `DEF 6 MLF`, `E 12 IRAN`),
    /// anchored to the whole candidate, with an optional parenthesized agency
    /// qualifier after the class letters (`AID (US) 15-4 UAR` — the P.L. 480 /
    /// assistance classes, frequent in the 1964–1976 volumes). Applied AFTER dash
    /// canonicalization, so only the ASCII hyphen needs to match.
    ///
    /// The leading negative lookahead excludes identifier families that fit the
    /// letters-then-digits shape but are never citable file classes:
    /// - **record-group / records-center forms** — `RG 59`, and the run-together
    ///   `RG59` the TEI actually writes (a bare `\b` cannot fire between a letter
    ///   and a digit, so the original `RG\b` let `RG59` through, storing it as a
    ///   junk class AND masking the genuine class later in the citation);
    ///   `FRC 330-78-0011`, `NYFRC 84-84-002` accessions;
    /// - **numbered issuances** — `NSDM 93`, `NSSM 114`, `NSAM 55`, `NSC 5412`,
    ///   `NIE 11-8`, `SNIE 100-5`, `PL 480` (public-law / program numbers);
    /// - **FRC-style accessions under other prefixes** — `PRC 64 A 2382`
    ///   (digits-A-digits accession shape only; a plain `PRC nn` candidate is
    ///   already unreachable from citation scans, which are sentence-bounded).
    private static let subjectNumericClassRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?!(?:RG|FRC|NYFRC)[\s\d-]|(?:NSDM|NSSM|NSAM|NSC|NIE|SNIE|PL)\b|PRC\s?\d{1,3}\s?A\s?\d)[A-Z]{1,5}(?:\s?\([A-Z0-9]{1,4}\))?\s?\d{1,3}(?:-\d{1,3})*(?:\s[A-Z0-9]{1,6}(?:-[A-Z0-9]{1,6})*)*$"#,
        options: [])

    /// Dotted decimal class-leaf shape (`711.11`, `611.61`, `500.A15A4`): the central
    /// decimal file classification, anchored to the whole candidate.
    ///
    /// The optional trailing `-ALPHA` group admits the dash-suffixed classes the decimal file
    /// uses for programmes and country pairs — `751G.5-MSP` (Mutual Security Program),
    /// `396.1-GE` (Geneva), `711.11-EI` (Eisenhower). Measured: **1,165 documents across 162
    /// such classes** were refused without it, because the suffix survives the `/` cut and then
    /// fails the anchored shape (#353 / N-1). By the time this runs, `decimalClassKey` has
    /// already mapped en/em dashes to the ASCII hyphen, so only `-` needs matching.
    private static let dottedDecimalClassRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\d{2,3}[A-Za-z]{0,2}(?:\.[0-9A-Za-z]+)+(?:-[A-Z]{1,6})?$"#,
        options: [])

    /// A **dotless** three-digit decimal class (`032`, `330`, `362`).
    ///
    /// The decimal file's top-level classes are used directly, without an extension — 1,565
    /// documents across 46 such codes cite one. They cannot join `dottedDecimalClassRegex`,
    /// which requires a dot precisely so a bare number is never mistaken for a class: the
    /// pre-1910 **Numerical File** case numbers (`File No. 3767/5`) look identical otherwise.
    ///
    /// Safe only under `bareClassCandidate(_:)`'s context test, which is why it is separate
    /// rather than an alternation inside the shape above. Anything reaching this regex has
    /// already been shown to sit where a class sits.
    private static let bareDecimalClassRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\d{3}$"#, options: [])

    /// Validates and canonicalizes one decimal / subject-numeric class-leaf candidate.
    ///
    /// This is the single class-shape gate for **both** citation sides — the
    /// front-matter Sources outline (`SourcesParserDelegate.classLeafKey`) and
    /// document source notes (`decimalClassLocation(inCitation:)`) — so a class keyed
    /// from front matter and the same class keyed from a citing document always reduce
    /// to the identical stored form, and the archival-neighbor matcher stays a plain
    /// indexed equality/prefix lookup.
    ///
    /// **Canonical form:** whitespace collapsed to single spaces, trailing periods
    /// stripped, and every Unicode dash (en/em) mapped to the ASCII hyphen. The dash
    /// mapping is load-bearing: TEI front matter writes the class with an en-dash
    /// (`POL 27 ARAB–ISR`) while the same file cited in document source notes uses
    /// the ASCII hyphen (`POL 27 ARAB-ISR`) — verbatim storage on either side can
    /// never match the other. Case is preserved (classes are uppercase by vocabulary;
    /// mixed-case tokens fail the anchored shapes).
    ///
    /// - Parameter candidate: One candidate string (a colon/semicolon segment of a
    ///   front-matter item, or a comma segment of a citation).
    /// - Returns: The canonical class key, or `nil` when the candidate is not a
    ///   class-leaf shape.
    public static func decimalClassKey(_ candidate: String) -> String? {
        var s = candidate
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        while s.hasSuffix(".") { s = String(s.dropLast()) }
        s = s.trimmingCharacters(in: .whitespaces)
        guard s.count >= 3, s.count <= 60 else { return nil }
        s = unifyingSpacedClassSuffix(s)
        let ns = NSRange(s.startIndex..., in: s)
        let isSubjectNumeric = subjectNumericClassRegex?.firstMatch(in: s, range: ns) != nil
        let isDottedDecimal = dottedDecimalClassRegex?.firstMatch(in: s, range: ns) != nil
        guard isSubjectNumeric || isDottedDecimal else { return nil }
        return s
    }

    /// Removes the two spacings FRUS uses inside a class that mean nothing (#353 / N-1b).
    ///
    /// - **after the class dot** — `501. BC` is the class stored elsewhere as `501.BC`, whose
    ///   sibling `501.BB` already carries 1,331 documents, so this joins an established class
    ///   rather than inventing one. 891 documents.
    /// - **after a suffix dash** — `751G.5– MSP` is the third spelling of the suffix #688
    ///   unified, and removing the dash lets the space rule finish the job. 796 documents.
    ///
    /// Applied to the whole candidate before any rule runs, so the tokenising rules see the
    /// same string the whole-candidate gate does — a first draft collapsed only inside
    /// `decimalClassKey` and `501. BC Indonesia/…` still failed, because `leadingClassKey`
    /// split the *uncollapsed* text into `501.` / `BC` / `Indonesia`.
    static func collapsingClassPunctuation(_ raw: String) -> String {
        var s = raw
        if let re = classDotSpaceRegex {
            // Join with `.` when the class has no extension yet (`501. BC` → `501.BC`, the
            // form its sibling `501.BB` is stored in) and with `-` when it already has one
            // (`840.50. UNRRA` → `840.50-UNRRA`, matching the 145 notes that spell the same
            // class `840.50 UNRRA`). A single template gets one of the two wrong, and the
            // corpus check found it: `840.50.UNRRA` would have been a third key for one class.
            let ns = s as NSString
            var out = ""
            var cursor = 0
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                out += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
                let headEnd = m.range(at: 1).location + m.range(at: 1).length
                let alreadyExtended = ns.substring(to: headEnd).contains(".")
                out += ns.substring(with: m.range(at: 1))
                out += alreadyExtended ? "-" : "."
                out += ns.substring(with: m.range(at: 2))
                cursor = m.range.location + m.range.length
            }
            out += ns.substring(from: cursor)
            s = out
        }
        if let dash = s.firstIndex(where: { $0 == "-" || $0 == "–" || $0 == "—" }),
           s.index(after: dash) < s.endIndex, s[s.index(after: dash)] == " " {
            s.remove(at: dash)
        }
        return s
    }

    /// A class dot followed by space and a short **all-caps** token — `501. BC`.
    ///
    /// Three constraints, each paying for itself:
    /// - a **digit** before the dot, so ordinary abbreviations (`Dept. of State`) are untouched;
    /// - **two or more** capitals, and
    /// - no lowercase after them.
    ///
    /// The last two are what keep this off a sentence boundary. A first version matched a
    /// single capital and rewrote `Central Files, POL 29. Secret` into `POL 29.Secret`,
    /// destroying the boundary the parse depends on — **158 subject-numeric classes were lost**
    /// (`POL 29`, `DEF 18-6`, `DEF 18-4`) before the corpus check caught it.
    private static let classDotSpaceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(\d)\.\s+([A-Z]{2,6})(?![a-z])"#, options: [])

    /// Rewrites a **space**-separated class suffix to the dash form, so `751G.5 MSP` and
    /// `751G.5–MSP` reduce to the same stored key.
    ///
    /// The decimal file writes programme and country suffixes both ways, and the space form is
    /// the more common: **4,851 notes across 277 classes**, against 2,029 across 260 for the
    /// dash. **126 classes appear in both spellings**, so leaving them unreconciled splits those
    /// classes in two — and, worse, the space form used to fall through to the leading-token
    /// rule and be stored as the *bare* class, silently merging `751G.5 MSP` with the unrelated
    /// unsuffixed `751G.5`. Reported on `frus1952-54v13p1/d416`
    /// (`751G.5 MSP /10–553: Telegram`), which is why this is narrow rather than clever.
    ///
    /// The suffix must be **the entire remainder** and short all-caps. That is what keeps
    /// `740.00119 EW (39)`, `740.00119 EW (Peace)` and `740.00119 European War 1939` out of it:
    /// each carries its own qualifier, they are distinct subdivisions of one decimal class, and
    /// deciding whether `EW` and `European War` are the same file is an archival judgement this
    /// parser is not equipped to make. They keep falling to the bare class — identically for
    /// both spellings, which is the property that actually matters.
    static func unifyingSpacedClassSuffix(_ candidate: String) -> String {
        let candidate = collapsingClassPunctuation(candidate)
        guard let space = candidate.firstIndex(of: " ") else { return candidate }
        let head = String(candidate[..<space])
        let tail = String(candidate[candidate.index(after: space)...])
        // The head must be a **dotted decimal**. That is the whole guard, and it is genuinely
        // load-bearing: the subject-numeric classes are legitimately space-separated
        // (`POL 27 ARAB-ISR`), and rewriting one to `POL-27 ARAB-ISR` fails the subject-numeric
        // shape outright — a valid class would be lost, not merely mis-keyed.
        //
        // Deliberately no shape test on `tail`. `decimalClassKey` re-gates the joined string
        // through `dottedDecimalClassRegex`, whose `-[A-Z]{1,6}` group already decides what a
        // suffix may be; a duplicate test here was unobservable under mutation. One definition
        // of the shape, in the regex.
        guard !tail.isEmpty,
              dottedDecimalClassRegex?.firstMatch(
                in: head, range: NSRange(head.startIndex..., in: head)) != nil
        else { return candidate }
        return head + "-" + tail
    }

    /// Extracts the decimal / subject-numeric class **location** from a central-files
    /// document citation, in the canonical form of `decimalClassKey(_:)`.
    ///
    /// The scan is **bounded to the citation sentence**: a note's remark sentences
    /// routinely cite numbered issuances and secondary copies ("… Secret. For the
    /// full text of NSDM 91, see …"), and an unbounded first-passing-segment scan
    /// stored those identifiers as the row's class whenever the citation sentence
    /// itself had no class-shaped segment. The citation sentence is the **first
    /// sentence naming the central files** ("Central Files", "Central Foreign
    /// Policy", or the `CF` abbreviation) — not blindly sentence 1, because the
    /// 1961–1963 abstract notes put the citation in the *tail* ("Discussion of
    /// import restrictions. Confidential. 13 pp. Department of State, Central
    /// Files, 100.4/7–2762."). When no sentence names them, sentence 1 stands in
    /// (the bare decimal-leading notes: "611.41/3–553. Foreign Service despatch.").
    /// A remark's "ibid., 033.84A11/10–158" secondary reference is never reached:
    /// either the citation sentence already named the central files (the remark
    /// sentence is not the first) or the note has none and only sentence 1 is
    /// scanned.
    ///
    /// Within that sentence, comma segments are scanned in order and the first that
    /// passes the class gate wins, after cutting an item suffix at the first `/`
    /// (`788.5/9–1361` → `788.5`, `POL 27-14 ARAB-ISR/SANDSTORM` → `POL 27-14 ARAB-ISR`)
    /// and, failing that, a trailing sentence at the first `". "`
    /// (`POL 27 ARAB-ISR. Secret; Immediate…` → `POL 27 ARAB-ISR`). The `". "` cut is
    /// tried second so dotted decimals (`788.5`) are never split on their own dot.
    ///
    /// Callers gate by classification: only central-files-shaped notes
    /// (`.centralFiles`, `.cfpfFile`, and `.naraCollection` whose series names the
    /// central files) should be scanned, so box numbers or council-document ids in
    /// other repositories' citations can never masquerade as a class.
    ///
    /// - Parameter text: The raw citation text (wrapper already stripped).
    /// - Returns: The canonical class location, or `nil` when no segment is a class leaf.
    public static func decimalClassLocation(inCitation text: String) -> String? {
        // Collapse `501. BC` **before** the sentence split, not after. The sentence-boundary
        // regex ends a sentence at a period followed by whitespace and a capital, so
        // `501. BC Indonesia/1–2045` is cut to the citation sentence `"501. "` and the class
        // is gone before any rule here runs. Collapsing first is why this is not simply a
        // segment-level fix — 891 documents.
        let citation = citationSentence(of: collapsingClassPunctuation(text))
        for segment in citation.components(separatedBy: ",") {
            var candidate = segment
            if let slash = candidate.firstIndex(of: "/") {
                candidate = String(candidate[..<slash])
            }
            // The early volumes label the class rather than leading with it: "File No.
            // 861.00/1234" is 21,960 documents over 1,064 classes, every one refused because
            // the label rides in the segment and `File No. 861.00` is not class-shaped.
            let stripped = strippingFileNumberLabel(candidate)
            // A labelled segment can never yield a *dotless* class: `File No. 376/5` is a
            // Numerical File case number, and accepting `376` from it fabricates a class out
            // of a filing sequence. The dot requirement used to carry this distinction on its
            // own; now that dotless classes are admitted, the label has to.
            let wasLabelled = stripped != candidate
            candidate = collapsingClassPunctuation(stripped)
            if let key = decimalClassKey(candidate) { return key }
            if let tail = candidate.range(of: ". "),
               let key = decimalClassKey(String(candidate[..<tail.lowerBound])) {
                return key
            }
            // A class followed by prose inside one segment: "740.0011 European War 1939/12345"
            // (2,837 documents). The `/` cut leaves "740.0011 European War 1939", which the
            // whole-candidate gate rejects, and there is no ". " to cut at.
            if let key = leadingClassKey(candidate) { return key }
            if !wasLabelled, let key = bareClassCandidate(candidate) { return key }
        }
        return nil
    }

    /// A dotless three-digit class, accepted only where a class belongs.
    ///
    /// The segment must be **exactly** three digits after the `/` cut — no label, no prose.
    /// That is what separates `Central Files, 032/1–2855` (a class) from the Numerical File's
    /// `File No. 3767/5` (a case number, four digits and label-prefixed) and from a bare
    /// number appearing anywhere else in a citation. The `/` that preceded the cut is itself
    /// part of the evidence: a class is what stands to the left of the item suffix.
    static func bareClassCandidate(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespaces)
        let ns = NSRange(trimmed.startIndex..., in: trimmed)
        guard bareDecimalClassRegex?.firstMatch(in: trimmed, range: ns) != nil else { return nil }
        return trimmed
    }

    /// Strips an early-volume `File No.` label from a class candidate.
    ///
    /// The 1906–1930s volumes cite the decimal file as `File No. 861.00/1234` rather than
    /// naming the central files, so the citation-sentence anchor falls through to sentence 1
    /// and the segment still carries the label. Matching is anchored and tolerant of the
    /// missing period and of case (`File No`, `file no.`), and returns the input unchanged
    /// when the label is absent.
    static func strippingFileNumberLabel(_ candidate: String) -> String {
        let trimmed = candidate.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        for label in ["file no.", "file no", "file number"] where lowered.hasPrefix(label) {
            return String(trimmed.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
        }
        return candidate
    }

    /// The class when a candidate **begins** with one and continues into prose.
    ///
    /// Only the first whitespace-separated token is offered to the gate, so this cannot reach
    /// past a leading class into the rest of the segment — `Central Files` yields `Central`,
    /// which the gate rejects, and `File No. 861.00` yields `File`, which is why the label
    /// strip above has to run first.
    static func leadingClassKey(_ candidate: String) -> String? {
        let tokens = candidate.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count > 1, let head = decimalClassKey(tokens[0]) else { return nil }
        // Carry a short all-caps second token as the suffix, so the space spelling reaches the
        // same key as the dash spelling when a qualifier follows: `740.00119 EW (39)` and
        // `740.00119–EW (39)` both give `740.00119-EW`. Without this the dash form absorbed
        // the suffix (it rides in token 0) while the space form dropped it — the same
        // split-key defect as #687's, in mirror image.
        // No shape test on `tokens[1]` here on purpose: `decimalClassKey` re-gates the joined
        // string, and mutation testing showed a duplicate test is unobservable — every
        // candidate it would reject (`740.00119-European`, `740.00119-EUROPEANLONG`,
        // `740.00119-Msp`) the gate already returns nil for. One place decides the shape.
        if !head.contains("-"), let suffixed = decimalClassKey(head + "-" + tokens[1]) {
            return suffixed
        }
        return head
    }

    /// Central-files anchor phrases that mark a sentence as the archival citation
    /// for the class scan. The scoped-case-insensitive group covers the spelled
    /// forms; `\bCF\b` stays case-sensitive — the abbreviation in
    /// `"DOS, CF, 033.1161/1–963"` is always capitals, while a lowercase `cf.` is
    /// a cross-reference.
    private static let centralFilesAnchorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i:central\s+files|central\s+foreign\s+policy)|\bCF\b"#,
        options: [])

    /// The citation sentence of a source note for the class scan: the **first
    /// sentence naming the central files**, else sentence 1 (see
    /// `decimalClassLocation(inCitation:)` for the rationale and shapes).
    ///
    /// Public since Phase 4: the collection-authority generator tokenizes the same
    /// citation sentence on `", "` (the frus-sources `merge.xq` segment model), so its
    /// leading-segment keys are bounded to the citation exactly as the class scan is.
    public static func citationSentence(of text: String) -> String {
        guard let anchor = centralFilesAnchorRegex else { return text }
        let sentences = self.sentences(of: text)
        guard sentences.count > 1 else { return text }
        for sentence in sentences {
            let range = NSRange(sentence.startIndex..., in: sentence)
            if anchor.firstMatch(in: sentence, range: range) != nil { return sentence }
        }
        return sentences[0]
    }

    /// Sentence 1 of a source note — the archival citation, per the frus-sources sentence model
    /// (citation, then classification markings, then remarks).
    ///
    /// Distinct from `citationSentence(of:)`, which returns the first sentence **naming the
    /// central files** and only falls back to sentence 1. That anchoring is right for the class
    /// scan and for the collection-authority keying, and wrong for anything reading a
    /// presidential-library citation: a note whose remarks cross-reference the White House
    /// Central Files — very common in the Nixon volumes — makes the anchor match the *remarks*,
    /// so the citation itself is never examined. Measured, that is 4,672 Nixon documents whose
    /// sub-collection was being read out of an editor's commentary instead of the citation.
    ///
    /// The two must stay separate rather than one being "fixed" into the other:
    /// `citationSentence` is what keys `collection-authority.json`, so changing it would
    /// invalidate every stored key in a shipped artifact.
    public static func firstSentence(of text: String) -> String {
        sentences(of: text).first ?? text
    }

    /// Splits a source note on sentence boundaries, keeping each terminator with its sentence.
    private static func sentences(of text: String) -> [String] {
        guard let boundary = sentenceBoundaryRegex else { return [text] }
        let ns = text as NSString
        var sentences: [String] = []
        var start = 0
        for match in boundary.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let end = match.range.location + match.range.length
            sentences.append(ns.substring(with: NSRange(location: start, length: end - start)))
            start = end
        }
        if start < ns.length { sentences.append(ns.substring(from: start)) }
        return sentences.isEmpty ? [text] : sentences
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
        // #353 §3.5: this runs second in `parse()`, ahead of every decimal rule, so an
        // `Ibid., Conference Files: Lot 65 D 533` in a *remark* used to outrank the decimal
        // citation the note actually leads with. 429 documents — the largest of the three
        // channels, and the one the owner hit in #675. See `lotClaimScope(_:)`.
        let scope = Self.lotClaimScope(text)
        guard let lotRange = scope.range(of: #"\bFiles?:\s*Lot\s+"#,
                                        options: .regularExpression) else { return nil }
        let afterLot = String(scope[lotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
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
        let scope = Self.lotClaimScope(body)
        guard let lotKeyRange = scope.range(of: #"\bLot\s+"#, options: .regularExpression) else { return nil }
        let afterLot = String(scope[lotKeyRange.upperBound...])
        let (lotNumber, box) = splitLotAndBox(afterLot)
        guard !lotNumber.isEmpty else { return nil }
        // Determine RG from lot file letter designator:
        // F-designator → RG 84 (post records); D-designator and others → RG 59
        let rg = lotFileRecordGroup(lotNumber)
        return .lotFile(recordGroup: rg, lotNumber: lotNumber, fileIdentifier: box)
    }

    /// The span of a note within which a `Lot` token speaks for **this** document
    /// (#353 §3.5).
    ///
    /// ## The defect
    /// Both lot strategies used to scan the whole note and take the first `Lot` they found.
    /// FRUS routinely names a *second* archive in a later sentence — where another copy of
    /// the document lives, or where a document the remark cites lives — and those two shapes
    /// were flipping the note onto the lot route:
    ///
    /// ```
    /// Source: Carter Library, National Security Affairs, Brzezinski Material, … Box 102, …
    ///         [later sentence names a lot]                    → filed under the wrong archive
    /// Source: Department of State, Central Files, TEL 9.
    ///         (E Bureau Staff Minutes, March 15; … E/CBA/REP Files: Lot 72 A 6248)
    ///                                                          → the lot is the *footnote's*
    /// ```
    ///
    /// Measured: **554 documents** — 243 whose leading sentence names a presidential library
    /// and 311 whose leading sentence names the central files. The owner reached 229 and 275
    /// for the same two shapes by a different route, from the live index.
    ///
    /// ## Why the leading sentence, and not simply "outside parentheses"
    /// Because the 1961–1963 abstract notes are genuinely lot files and put their citation in
    /// the **tail**: `"Anatomy of the revolution in Ecuador. Secret. 2 pp. WNRC, RG 59, S/P
    /// Files: Lot 67 D 548, Ecuador."` A rule that refused any lot outside sentence 1 would
    /// break **1,006** correct classifications — measured, and more than the defect is worth.
    /// So the scope narrows only when the leading sentence has *already named a competing
    /// repository*; otherwise it is the whole body, exactly as before.
    ///
    /// This is the same principle `strippingParentheticals(_:)` states for FRC accessions —
    /// a secondary copy is not the cited original — applied to the lot channel.
    /// ## Why the parentheticals are stripped too
    /// Narrowing to the leading sentence is not enough on its own. The sentence splitter ends
    /// a sentence at a period followed by whitespace **and a capital**, and a trailing
    /// parenthetical opens with `(` — so `"… Central Files, TEL 9. (E Bureau Staff Minutes,
    /// March 15; … E/CBA/REP Files: Lot 72 A 6248)"` is *one* sentence to the splitter and the
    /// lot rides along inside it. `strippingParentheticals(_:)` already states the principle
    /// for FRC accessions — a parenthesised archive describes a secondary copy, never the
    /// cited original — so the same call finishes the job here.
    static func lotClaimScope(_ body: String) -> String {
        let lead = firstSentence(of: body)
        guard namesCompetingRepository(lead) else { return body }
        return strippingParentheticals(lead)
    }

    /// Whether a sentence already names a repository that is not a lot file, and so has
    /// claimed the document before any later `Lot` token can.
    ///
    /// Reuses `centralFilesAnchorRegex` rather than `matchesCentralFiles(_:)`: the latter
    /// admits a bare `"Department of State"`, which the abstract lot notes above also carry
    /// (`"… 3 pp. Department of State, S/P Files: Lot 67 D 548"`), so using it here would
    /// discard the very classifications this rule is scoped to protect.
    /// ## Why the central-files *anchor*, and not `matchesCentralFiles(_:)`
    /// Measured, swapping the anchor for that predicate's bare `"Department of State"` test
    /// changes **373 documents**, and the change is a net loss: **61 of them fall back out of a
    /// specific repository into `lotFile`** (36 `naraCollection`, 23 `cfpfFile`, 1
    /// `centralFiles`) and 2 fall to `unrecognized`.
    ///
    /// The reason is a shape the bare test cannot see. `"Source: National Archives and Records
    /// Administration, RG 59, Central Files 1960–63, 110.10/5–1062."` names the central files
    /// and never names the Department, so `"Department of State"` does not fire, the scope
    /// stays the whole note, and a lot mentioned later captures a National Archives citation.
    /// The anchor matches `Central Files 1960–63` and the note keeps its own classification.
    ///
    /// ## Why the manuscript repositories are included
    /// The Library of Congress leads are the same defect: `"Source: Library of Congress,
    /// Manuscript Division, Harriman Papers, …"` filed under a State Department lot named
    /// later in the note. Only 4 documents, but each is a wrong archive on a named personal
    /// collection — and both keyword sets are read, never written, here.
    private static func namesCompetingRepository(_ sentence: String) -> Bool {
        let range = NSRange(sentence.startIndex..., in: sentence)
        if centralFilesAnchorRegex?.firstMatch(in: sentence, range: range) != nil { return true }
        return (libraryKeywords + manuscriptRepositoryKeywords).contains {
            sentence.range(of: $0, options: .caseInsensitive) != nil
        }
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

    /// The corpus-wide lot-reference grammar, shared by the document side
    /// (`tryLooseLotFile`) and the front-matter side (`SourcesParserDelegate`), so both
    /// write keys the same way. Matches a lot number in any observed style:
    /// - lowercase `lot`, comma-separated (`…files, lot 60 D 665, "…"`);
    /// - lot-leading (`Lot 71–D 440, Box 19232`);
    /// - all designator letters (`D` RG 59, `F` RG 84 post records, `W`, `M`, …) —
    ///   the digits-designator-digits shape is the validator, so the English word
    ///   "lot" can never match on its own;
    /// - letter-first designators (`lot M 88`, `Lot W 130`) via the optional leading
    ///   digits — a single letter followed by digits cannot occur in prose after "lot";
    /// - en/em-dash separators and run-together designators (`Lot 54–D270`);
    /// - run-together trailing text (`Lot 90 D 313Records…` — the digits terminate
    ///   the match, no trailing word boundary is required);
    /// - a `File`/`Files` infix (`Lot File 57 D 577`, `Lot Files 74 D 131`), skipped
    ///   before the capture so the key is the bare number, never `"Files 74 D 131"`;
    /// - a plural lead (`Lots 64 D 563 and 65 D 101`, `Lots 76D186 and 78D184` —
    ///   83 front-matter rows corpus-wide) — the first lot keys the row, matching
    ///   the parser-wide first-reference rule for multi-lot notes;
    /// - a single trailing letter suffix, run-together or spaced (`Lot 61 D 282A`,
    ///   `Lot 61 D 282a`, `Lot 61 D 282 A`) — a real lot-series form the narrative
    ///   doc-side extractor already captured, so the shared grammar must too or the
    ///   two sides' `lotFileNorm` keys diverge (`61D282` vs `61D282A` — found by the
    ///   Phase 3 verification bucket run; the spaced form by the adversarial-review
    ///   norm-parity sweep). The negative lookahead keeps run-together prose
    ///   (`313Records…`) and following words (`563 and…`) out of the key.
    private static let looseLotRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bLots?\s+(?:Files?\s+)?((?:\d{2,3}\s*[–—\-]?\s*)?[A-Za-z]\s*[–—\-]?\s*\d+(?:\s?[A-Za-z](?![A-Za-z]))?)"#,
        options: .caseInsensitive
    )

    /// Finds the first lot-file reference in `text` using the shared corpus-wide lot
    /// grammar (see `looseLotRegex`).
    ///
    /// This is the single lot-recognition entry point for **both** citation sides:
    /// `SourceNoteParser` uses it for loose-style document source notes, and
    /// `SourcesParserDelegate` (front-matter Sources outline) uses it at parse time —
    /// so a lot keyed from a volume's front matter and the same lot keyed from a
    /// document's source note always reduce to the identical `lotFileNorm(_:)` key.
    ///
    /// - Parameter text: Any citation or front-matter item text.
    /// - Returns: The raw lot number (whitespace-trimmed, formatting preserved) and
    ///   the range of the full `Lot …` match in `text`, or `nil` when no lot shape
    ///   follows the word "Lot".
    public static func firstLotReference(
        in text: String
    ) -> (lotNumber: String, matchRange: Range<String.Index>)? {
        guard let regex = looseLotRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let lotRange = Range(match.range(at: 1), in: text),
              let fullRange = Range(match.range, in: text) else { return nil }
        let lotNumber = String(text[lotRange]).trimmingCharacters(in: .whitespaces)
        guard !lotNumber.isEmpty else { return nil }
        return (lotNumber, fullRange)
    }

    private func tryLooseLotFile(_ text: String) -> ParsedSourceNote? {
        let scope = Self.lotClaimScope(text)
        guard let (lotNumber, fullRange) = Self.firstLotReference(in: scope) else { return nil }
        let remainder = String(scope[fullRange.upperBound...])
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
