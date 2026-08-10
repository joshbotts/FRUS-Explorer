// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FootnoteArchivalCitation

/// One archival unit a FRUS editorial footnote points at — material the volume did **not** print.
///
/// This is a third body of archival evidence, distinct from the two the app already stores: a
/// document's own source note (`document_sources`, where the printed document came from) and a
/// cross-reference between two printed documents (`cross_references`). A footnote citation says
/// *there is another document, we did not print it, and here is where it lives*.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
public struct FootnoteArchivalCitation: Sendable, Equatable {

    /// Which self-identifying phrase opened the citation.
    public enum Anchor: String, Sendable, Equatable {
        /// `… Executive Secretariat Files, Lot 66–D95 …`
        case lotFile
        /// `… Johnson Library, National Security File, Country File, Vietnam …`
        case presidentialLibrary
    }

    /// The anchor that matched.
    public let anchor: Anchor

    /// The citation in the shape `SourceNoteParser` produces for the *same* archival unit, so
    /// `CollectionKeying.identity(of:note:)` and the collection-authority lookup apply unchanged.
    /// This is the whole reason the harvest can join the rest of the archival substrate.
    public let parsed: ParsedSourceNote

    /// The clause the anchor was found in — the text the authority lookup is given, and what a
    /// reader is shown. Never the whole footnote: the clause **is** the citation.
    public let citation: String

    /// `true` when the unit came from an `Ibid.` rather than from a phrase in this clause.
    public let inherited: Bool

    /// Creates a citation record.
    public init(anchor: Anchor, parsed: ParsedSourceNote, citation: String, inherited: Bool) {
        self.anchor = anchor
        self.parsed = parsed
        self.citation = citation
        self.inherited = inherited
    }
}

// MARK: - FootnoteCitationScanner

/// The anchor-first grammar for archival citations in editorial-footnote prose, plus the
/// document-ordered `Ibid.` state it needs (#784).
///
/// ## Why this is a separate entry point and not `SourceNoteParser.parse`
/// `SourceNoteParser` reads a *source note* — one citation, sentence-bounded, describing one
/// document's provenance. Footnote prose is unbounded narrative that may contain no citation, one,
/// or several, interleaved with page references and cross-references. The parser's own comment at
/// `SourceNoteParser.swift:425-427` records the consequence: a bare `PRC nn` candidate "is already
/// unreachable from citation scans, which are sentence-bounded". **That exclusion list is
/// calibrated to the sentence bound.** Routing footnote prose through `decimalClassLocation` would
/// remove the bound and void the calibration — which is why decimal classes and subject-numeric
/// designators are out of scope here, and why this file never calls into that path.
///
/// ## Anchor-first, and only two anchors
/// A citation is recognised by a **self-identifying repository phrase** and only then by an
/// identifier — the shape `extractCitations` already uses. #784 measured the three candidate units
/// separately: lot files and presidential libraries had **0 false positives in 80 read samples**;
/// decimal classes were 56% the citing document's *own* class; subject-numeric designators were
/// **87.2% out of vocabulary** at the strictest gate (`A10` is a newspaper page, `CF 341` a
/// Conference-File folder, `NSDD 104` a directive). Only the clean two are harvested.
///
/// ## Four things this refuses to do, each measured
/// 1. **Absence claims are not citations.** `frus1952-54v01p2/d140` footnote 2 reads, in full,
///    *"Not found in Department of State files or at the Truman Library."* Harvesting that asserts
///    the opposite of what the editor wrote. The guard is applied **per clause**, so the
///    parenthetical citation in `"Not printed. (Truman Library, Papers of Clark M. Clifford)"`
///    still lands — the absence clause and the citation clause are different clauses.
/// 2. **A head-nested footnote is the printed document's own provenance, not an external one.**
///    Not enforced here (the caller chooses which notes to feed) but enforced by every caller —
///    see ``FootnoteCitationScanner/scan(note:)``'s note on the extractor contract.
/// 3. **`Ibid.` never inherits across a publication citation.** In the 19th-century volumes the
///    overwhelmingly common `Ibid.` refers to a *book or a page*, not an archive: of 13,432
///    measured `(Ibid., …)` occurrences the largest class is page/volume references. A state
///    machine that inherited "the last archive named" would attribute `(Ibid., p. 68.)` in
///    `frus1872p2v2` to whatever archive appeared three footnotes earlier.
/// 4. **`Ibid.` is not seeded from the document's own source note.** A bare `Ibid.` in footnote 1
///    would then resolve to the unit the printed document came from — true, but a self-reference,
///    and the whole point of the harvest is what lies *outside* the printed record.
///
/// ## What the `Ibid.` machinery is actually worth
/// #784 lists it as a non-negotiable and sizes it at "12,482 notes inherit their repository". At
/// this feature's declared scope that figure does not survive: of 13,432 `(Ibid., …)` occurrences
/// measured over the shippable corpus, 4,209 are decimal classes and 1,471 subject-numeric (both
/// out of scope), 5,863 are page/volume references to publications, 769 name a lot (which the
/// anchor grammar reads without any state at all) and 6 name a library. The inheritance is still
/// implemented — the pass is document-ordered anyway, so it is nearly free — but it is worth
/// roughly a tenth of the direct harvest, not the bulk of it.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
public struct FootnoteCitationScanner: Sendable {

    /// How many body footnotes back an `Ibid.` may reach for the unit it inherits.
    ///
    /// `Ibid.` on the printed page means *the source last cited*, with no distance limit. The cap
    /// exists because this scanner cannot see everything a reader can: a footnote may cite a
    /// document by cross-reference (`see Document 45`) or by an idiom this grammar does not read,
    /// and an unbounded reach would silently attribute the `Ibid.` to an archive named much
    /// earlier. Three is the printed page's neighbourhood.
    public static let ibidReach = 3

    /// The most recent archival citation in this document, and which body footnote carried it.
    private var lastArchival: (citation: FootnoteArchivalCitation, ordinal: Int)?

    /// Position of the note being scanned among this document's body footnotes.
    private var ordinal = -1

    /// Clauses that named a lot or a library inside an absence claim, so a caller can report how
    /// much the guard removed rather than leaving it invisible.
    public private(set) var absenceBlockedCount = 0

    /// Creates a scanner positioned before any document.
    public init() {}

    /// Resets the `Ibid.` state at a document boundary.
    ///
    /// Deliberately takes no source note: see refusal 4 in the type documentation.
    public mutating func beginDocument() {
        lastArchival = nil
        ordinal = -1
    }

    /// Scans one **body** footnote and returns the archival units it points at, in reading order.
    ///
    /// The caller's contract — enforced by `DocumentFootnoteExtractor` on the generator side and
    /// by `IndexingPipeline.collectFootnoteCitations` in the app — is that `note` is a footnote
    /// from the document's *body*: not a `<note type="source">`, and not a note nested in the
    /// document's `<head>`. A head-nested note carries the printed document's own provenance
    /// (`Photostatic copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N. Y.`),
    /// which `document_sources` already records; harvesting it here would report the editors
    /// pointing *outside* the printed record when they were describing the printed record itself.
    /// Measured over the shippable corpus: 258 head-nested notes carry an anchor.
    public mutating func scan(note: String) -> [FootnoteArchivalCitation] {
        ordinal += 1
        var found: [FootnoteArchivalCitation] = []
        var sawPublicationCitation = false

        for clause in Self.clauses(of: note) {
            if Self.isAbsenceClaim(clause) {
                if Self.hasAnyAnchor(clause) { absenceBlockedCount += 1 }
                continue
            }
            let direct = Self.citations(inClause: clause)
            if !direct.isEmpty {
                found.append(contentsOf: direct)
                if let last = direct.last { lastArchival = (last, ordinal) }
                continue
            }
            if Self.namesAPublication(clause) {
                sawPublicationCitation = true
                continue
            }
            if let inherited = inheritedCitation(inClause: clause) {
                found.append(inherited)
                lastArchival = (inherited, ordinal)
            }
        }

        // Refusal 3: a note whose only citation was to a publication invalidates the archival
        // state, so the next `Ibid.` cannot reach past it. Applied per *note* rather than per
        // clause because a note that both cites an archive and names a publication has already
        // set the state from the archive above, in clause order.
        if found.isEmpty, sawPublicationCitation { lastArchival = nil }
        return found
    }

    /// Resolves an `Ibid.` clause against the state, or returns `nil` when nothing may be
    /// inherited.
    private func inheritedCitation(inClause clause: String) -> FootnoteArchivalCitation? {
        guard Self.isIbidClause(clause),
              Self.ibidStandsAlone(clause),
              let (previous, previousOrdinal) = lastArchival,
              ordinal - previousOrdinal <= Self.ibidReach
        else { return nil }
        // The tail of `(Ibid., Box 47)` is a finer location inside the inherited unit, never a
        // different unit — a clause naming a different unit would have matched an anchor above.
        let identifier = Self.boxOrFolder(in: clause)
        let parsed: ParsedSourceNote
        switch previous.parsed {
        case .lotFile(let rg, let lot, let existing):
            parsed = .lotFile(recordGroup: rg, lotNumber: lot, fileIdentifier: identifier ?? existing)
        case .presidentialLibrary(let library, let collection, let existing):
            parsed = .presidentialLibrary(library: library, collection: collection,
                                          fileIdentifier: identifier ?? existing)
        default:
            return nil
        }
        return FootnoteArchivalCitation(anchor: previous.anchor, parsed: parsed,
                                        citation: clause, inherited: true)
    }

    // MARK: - The two anchors

    /// Every archival citation anchored in one clause, lots before libraries.
    static func citations(inClause clause: String) -> [FootnoteArchivalCitation] {
        lotCitations(inClause: clause) + libraryCitations(inClause: clause)
    }

    /// Whether a clause carries either anchor — used only to count what a guard removed.
    static func hasAnyAnchor(_ clause: String) -> Bool {
        !lotCitations(inClause: clause).isEmpty || !libraryCitations(inClause: clause).isEmpty
    }

    /// Whether a whole note would yield at least one archival citation on its own — no `Ibid.`
    /// state, no side effects.
    ///
    /// This exists so a caller can **measure what an exclusion cost**: the generator runs it over
    /// the notes `DocumentFootnoteExtractor` refuses (head-nested, `type="source"`) and reports
    /// the count in the artifact's coverage block. A guard whose cost is never measured is a guard
    /// nobody can argue with.
    public static func carriesArchivalAnchor(_ note: String) -> Bool {
        clauses(of: note).contains { !isAbsenceClaim($0) && hasAnyAnchor($0) }
    }

    /// Lot-file citations in one clause.
    ///
    /// Two designator shapes, both taken from `SourceNoteParser` rather than re-invented:
    /// - the **D/F designator** (`Lot 66–D95`, `Lot 57 D 155`, `Lot 55F44`), read with the
    ///   parser's own `lotFileRegex`, which is why a lot harvested here normalises to exactly the
    ///   `lot_file_norm` a source note would produce;
    /// - the **bare number behind a `Files: Lot` anchor** (`S/S Files: Lot 122`, `FE Files, Lot
    ///   244`), which is the pre-1950 form and is only accepted behind that anchor — the same
    ///   restriction `SourceNoteParser.tryInlineLotFile` applies, and the reason a bare `Lot 5` in
    ///   running prose cannot mint a citation.
    static func lotCitations(inClause clause: String) -> [FootnoteArchivalCitation] {
        var results: [FootnoteArchivalCitation] = []
        var claimedRanges: [Range<String.Index>] = []

        if let regex = SourceNoteParser.lotFileRegex {
            let ns = NSRange(clause.startIndex..., in: clause)
            for match in regex.matches(in: clause, range: ns) {
                guard let whole = Range(match.range, in: clause),
                      let captured = Range(match.range(at: 1), in: clause) else { continue }
                claimedRanges.append(whole)
                let lot = String(clause[captured]).trimmingCharacters(in: .whitespaces)
                results.append(FootnoteArchivalCitation(
                    anchor: .lotFile,
                    parsed: .lotFile(recordGroup: SourceNoteParser.lotFileRecordGroup(lot),
                                     lotNumber: lot,
                                     fileIdentifier: boxOrFolder(in: clause)),
                    citation: clause, inherited: false))
            }
        }

        if let regex = Self.anchoredBareLotRegex {
            let ns = NSRange(clause.startIndex..., in: clause)
            for match in regex.matches(in: clause, range: ns) {
                guard let whole = Range(match.range, in: clause),
                      let captured = Range(match.range(at: 1), in: clause) else { continue }
                // A designator match already covers this text (`Files: Lot 57 D 155` matches
                // both); the designator reading is the specific one and wins.
                if claimedRanges.contains(where: { $0.overlaps(whole) }) { continue }
                let lot = String(clause[captured]).trimmingCharacters(in: .whitespaces)
                results.append(FootnoteArchivalCitation(
                    anchor: .lotFile,
                    parsed: .lotFile(recordGroup: SourceNoteParser.lotFileRecordGroup(lot),
                                     lotNumber: lot,
                                     fileIdentifier: boxOrFolder(in: clause)),
                    citation: clause, inherited: false))
            }
        }
        return results
    }

    /// Presidential-library and manuscript-repository citations in one clause.
    ///
    /// The repository phrase is the anchor; the collection is the comma segment that follows it.
    /// `CollectionKeying.identity` then applies its own `isLibraryRepositoryName` gate and
    /// `leadingMergeSegment` reduction, so a segment that is really a place (`Franklin D.
    /// Roosevelt Library, Hyde Park, N. Y.`) reaches the authority as `hyde park` and resolves to
    /// nothing rather than to the wrong collection.
    static func libraryCitations(inClause clause: String) -> [FootnoteArchivalCitation] {
        guard let regex = Self.libraryRegex else { return [] }
        let ns = NSRange(clause.startIndex..., in: clause)
        var results: [FootnoteArchivalCitation] = []
        for match in regex.matches(in: clause, range: ns) {
            guard let libraryRange = Range(match.range(at: 1), in: clause),
                  let whole = Range(match.range, in: clause) else { continue }
            let library = String(clause[libraryRange]).trimmingCharacters(in: .whitespaces)
            let collection = Self.firstSegment(after: whole.upperBound, in: clause)
            guard !collection.isEmpty else { continue }
            results.append(FootnoteArchivalCitation(
                anchor: .presidentialLibrary,
                parsed: .presidentialLibrary(library: library, collection: collection,
                                             fileIdentifier: boxOrFolder(in: clause)),
                citation: clause, inherited: false))
        }
        return results
    }

    /// The comma segment beginning at `index`, trimmed, bounded by the next `,` `;` `:` or end.
    static func firstSegment(after index: String.Index, in clause: String) -> String {
        var rest = String(clause[index...])
        rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:"))
        let stop = rest.firstIndex { $0 == "," || $0 == ";" || $0 == ":" }
        let segment = stop.map { String(rest[..<$0]) } ?? rest
        return segment.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Clause splitting

    /// Splits a footnote into the clauses the anchors are read inside.
    ///
    /// Parentheses are boundaries — the parenthetical citation is the corpus's commonest form
    /// (`… approved the conclusions in this report (NSC Action 173, Executive Secretariat Files,
    /// Lot 66–D95).`) — as are `;` and a **sentence-ending** period.
    ///
    /// "Sentence-ending" is doing real work. A naive split on `. ` cuts `Franklin D. Roosevelt
    /// Library` into `Franklin D` and `Roosevelt Library, Hyde Park, N` and `Y.`, destroying the
    /// anchor it was supposed to bound. A period therefore ends a clause only when the word
    /// before it is neither a single letter (`D.`, `N.`, `Y.`) nor a known abbreviation.
    static func clauses(of text: String) -> [String] {
        var clauses: [String] = []
        var current = ""
        var index = text.startIndex
        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { clauses.append(trimmed) }
            current = ""
        }
        while index < text.endIndex {
            let character = text[index]
            switch character {
            case "(", ")", ";":
                flush()
            case ".":
                let next = text.index(after: index)
                let followedByBreak = next >= text.endIndex || text[next].isWhitespace
                if followedByBreak, Self.endsSentence(current) {
                    flush()
                } else {
                    current.append(character)
                }
            default:
                current.append(character)
            }
            index = text.index(after: index)
        }
        flush()
        return clauses
    }

    /// Whether a period closing `text` ends a sentence rather than an abbreviation.
    static func endsSentence(_ text: String) -> Bool {
        let word = text.split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? ""
        let bare = word.trimmingCharacters(in: CharacterSet(charactersIn: "([\"“‘")).lowercased()
        if bare.count <= 1 { return false }
        return !Self.abbreviations.contains(bare)
    }

    /// Words whose trailing period is an abbreviation mark, not a sentence end.
    ///
    /// Every entry is one that appears immediately before an archival citation somewhere in the
    /// corpus, so cutting there would split a citation from its anchor.
    static let abbreviations: Set<String> = [
        "vol", "vols", "no", "nos", "pp", "p", "pt", "ch", "n", "ed", "eds", "esp", "cf", "ca",
        "mr", "mrs", "ms", "dr", "jr", "sr", "st", "mt", "ft", "gen", "lt", "col", "capt", "adm",
        "maj", "sen", "rep", "gov", "amb", "asst", "assoc", "dept", "govt", "univ", "inc", "co",
        "corp", "u.s", "u.k", "u.n", "d.c", "n.y", "washington.", "jan", "feb", "mar", "apr",
        "jun", "jul", "aug", "sept", "sep", "oct", "nov", "dec",
    ]

    // MARK: - The three refusals

    /// Whether the clause claims material was **not** found.
    ///
    /// Scoped to the clause, never the note: `"Not printed. (Truman Library, Papers of Clark M.
    /// Clifford)"` has an absence-shaped first clause and a real citation in its second, and both
    /// readings are correct.
    static func isAbsenceClaim(_ clause: String) -> Bool {
        guard let regex = Self.absenceRegex else { return false }
        let ns = NSRange(clause.startIndex..., in: clause)
        return regex.firstMatch(in: clause, range: ns) != nil
    }

    /// Whether the clause cites a **publication** — a page, a volume, another FRUS volume, the
    /// *Bulletin*. Such a clause invalidates the `Ibid.` state (refusal 3).
    static func namesAPublication(_ clause: String) -> Bool {
        guard let regex = Self.publicationRegex else { return false }
        let ns = NSRange(clause.startIndex..., in: clause)
        return regex.firstMatch(in: clause, range: ns) != nil
    }

    /// Whether the clause is an `Ibid.` reference carrying no anchor of its own.
    static func isIbidClause(_ clause: String) -> Bool {
        clause.range(of: #"\bibid\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Whether an `Ibid.` **stands for the whole previous citation** rather than for only part of
    /// it.
    ///
    /// This is the difference between two readings that look alike and mean different things:
    ///
    /// | clause | reading |
    /// |---|---|
    /// | `(Ibid.)`, `Ibid., Box 53` | *the same unit* — inherit |
    /// | `Ibid., National Security File, Country File, Vietnam` | *the same **library**, a
    ///   different collection* — the clause names its own unit, and it is not the previous one |
    /// | `Ibid., Central Files, 684A.86/8–956` | *the same repository, a decimal file* — a unit
    ///   this grammar deliberately does not read |
    ///
    /// The first corpus run inherited all three, and produced exactly the wrong answers the second
    /// and third rows describe: a footnote naming the Johnson Library's *National Security File*
    /// was recorded against *Recordings and Transcripts*, and one naming a Central Files decimal
    /// number was recorded against a Conference-Files lot. Both were found by reading the sample
    /// file, which is why the generator writes one.
    ///
    /// So: everything after the `Ibid.` must be a **finer location inside the same unit** — a box,
    /// a folder, a date — and nothing else. Anything alphanumeric that survives the strip is the
    /// clause naming something of its own, and inheritance is refused.
    static func ibidStandsAlone(_ clause: String) -> Bool {
        guard let ibid = clause.range(of: #"\bibid\b\.?"#,
                                      options: [.regularExpression, .caseInsensitive,
                                                .backwards]) else { return false }
        var rest = String(clause[ibid.upperBound...])
        for regex in [Self.boxRegex, Self.dateTailRegex] {
            guard let regex else { continue }
            rest = regex.stringByReplacingMatches(
                in: rest, range: NSRange(rest.startIndex..., in: rest), withTemplate: " ")
        }
        return !rest.contains { $0.isLetter || $0.isNumber }
    }

    /// The box or folder designation in a clause, if it names one.
    static func boxOrFolder(in clause: String) -> String? {
        guard let regex = Self.boxRegex else { return nil }
        let ns = NSRange(clause.startIndex..., in: clause)
        guard let match = regex.firstMatch(in: clause, range: ns),
              let range = Range(match.range, in: clause) else { return nil }
        return String(clause[range]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Compiled expressions

    /// `Files: Lot 122`, `FE Files, Lot 244` — the pre-1950 bare-number form, only behind the
    /// `Files` anchor. Mirrors `SourceNoteParser.tryInlineLotFile`'s own requirement.
    static let anchoredBareLotRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bFiles?\s*[:,]?\s*Lot\s+(\d{1,4})\b"#, options: .caseInsensitive)

    /// A presidential library, the Hoover Institution, or the Nixon Presidential Materials, with
    /// up to three leading name words so `Franklin D. Roosevelt Library` and `Dwight D. Eisenhower
    /// Library` are captured whole. The surname list is `CollectionKeying`'s.
    static let libraryRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"((?:[A-Z][\w.]*\s+){0,3}(?:Roosevelt|Truman|Eisenhower|Kennedy|Johnson|Nixon|Ford|Carter|Reagan|Bush|Clinton)\s+(?:Presidential\s+)?(?:Librar(?:y|ies)|Presidential\s+Materials))|(Hoover\s+Institution)"#,
        options: [])

    /// The absence vocabulary, calibrated on the corpus's own phrasing.
    static let absenceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:not|no|never|nor)\b[^,;]{0,60}?\b(?:found|locate[d]?|identified|retained|present|extant)\b|\b(?:has|have|was|were|could)\s+not\s+been\s+(?:found|located|identified)\b|\bno\s+(?:record|copy|text|trace|indication)\b"#,
        options: .caseInsensitive)

    /// Publication-citation cues (refusal 3).
    static let publicationRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:pp?\.\s*\d|vol(?:ume)?s?\.?\s+[ivxlcdm\d]|op\.\s*cit|Foreign\s+Relations\b|Department\s+of\s+State\s+Bulletin|Public\s+Papers\b|Congressional\s+Record\b)"#,
        options: .caseInsensitive)

    /// `Box 47`, `Box H–115` (the Nixon H-Files), `Folder 3`.
    static let boxRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:Box|Folder)e?s?\s+[A-Za-z]?[–—\-]?\d+[A-Za-z]?(?:\s*[–—\-]\s*\d+)?"#,
        options: .caseInsensitive)

    /// The date shapes that appear as the tail of an `Ibid.` — `10/27/65`, `February 14, 1965`,
    /// `Feb. 14`, a bare year. Stripped before ``ibidStandsAlone(_:)`` decides, because a date is
    /// a finer location inside a folder, not a different unit.
    static let dateTailRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,2}/\d{1,2}/\d{2,4}\b|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:\s*[–—\-]\s*\d{1,2})?(?:,\s*\d{4})?|\b(?:18|19|20)\d{2}\b"#,
        options: .caseInsensitive)
}
