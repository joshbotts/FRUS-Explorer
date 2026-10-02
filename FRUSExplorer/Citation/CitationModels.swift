// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationInput

/// The structured representation of a parsed or manually entered FRUS citation.
///
/// All fields are optional — the matcher uses whatever is available.
/// Raw text is preserved alongside parsed fields for display and debugging.
///
/// Version history:
///   1.0 — Session 30: initial implementation
///   1.1 — #1474: `partNumber` (a multi-part volume's `pt. 2` / `Part II`, which no field could
///          carry, so Structured Entry could not name part 2 at all) and `exactReference` (a
///          history.state.gov link's volume and document ids, which are exact, and which a
///          letter-suffixed id such as `d373a` cannot pass through the numeric Document field)
public struct CitationInput: Sendable {

    /// Original pasted string; `nil` if the user typed fields directly.
    public let rawText: String?

    /// Chronological subseries identifier, e.g. `"1969-76"`.
    /// Normalized: hyphens and en dashes unified, both-year variants collapsed.
    public let subseries: String?

    /// Volume number string, e.g. `"I"`, `"1"`, `"01"`.
    /// Normalized to uppercase Roman if parseable; raw otherwise.
    public let volumeNumber: String?

    /// The part of a multi-part volume the citation names — `pt. 2`, `Part 2` and `Part II` are
    /// all `2` — or `nil` when it names none (#1474). The matcher reads it against the volume id's
    /// `pN` alone; the title's "Part N" agrees with that id for all 98 part volumes in the bundled
    /// manifest, so the title is not consulted.
    public let partNumber: Int?

    /// Parsed document number.
    public let documentNumber: Int?

    /// Parsed page number.
    public let pageNumber: Int?

    /// Partial title text for volume disambiguation.
    public let titleFragment: String?

    /// The volume, and usually the document, the citation names by TEI identifier — set when the
    /// text carries a history.state.gov link (#1474). The volume id is exact, so the matcher
    /// resolves this reference directly instead of searching for a volume that fits the other
    /// fields; when the link names no document the volume's index holds, `documentNumber` and
    /// `pageNumber` are looked up in that volume alone.
    public let exactReference: CitationExactReference?

    /// Confidence in the automatic parsing outcome.
    public let parserConfidence: ParserConfidence

    public init(
        rawText: String? = nil,
        subseries: String? = nil,
        volumeNumber: String? = nil,
        partNumber: Int? = nil,
        documentNumber: Int? = nil,
        pageNumber: Int? = nil,
        titleFragment: String? = nil,
        exactReference: CitationExactReference? = nil,
        parserConfidence: ParserConfidence = .structured
    ) {
        self.rawText = rawText
        self.subseries = subseries
        self.volumeNumber = volumeNumber
        self.partNumber = partNumber
        self.documentNumber = documentNumber
        self.pageNumber = pageNumber
        self.titleFragment = titleFragment
        self.exactReference = exactReference
        self.parserConfidence = parserConfidence
    }

    /// Returns `true` when enough data is present to attempt a match.
    /// At minimum one of (documentNumber, pageNumber, volumeNumber) is required — or an exact
    /// reference, since a link to a document whose id carries a letter (`d373a`) has no number.
    public var isActionable: Bool {
        documentNumber != nil || pageNumber != nil || volumeNumber != nil || exactReference != nil
    }
}

// MARK: - CitationExactReference

/// A FRUS volume, and optionally one of its documents, named by TEI identifier (#1474).
///
/// history.state.gov's document addresses ARE the TEI identifiers
/// (`/historicaldocuments/frus1961-63v05/d84`), and the app hands that address out itself, in its
/// share menu and its BibTeX, RIS and Zotero exports (`FRUSCanonicalURL`). So a pasted link needs
/// no resolution: the volume id is kept as written, mixed case included (`frus1919Parisv01`), and
/// so is the segment after it, whatever its shape — `d373a`, `d550A`, `d710a-1`, `eta_d1` and
/// `appA` are all document ids in the corpus (866 of its 314,571 document ids are not `d` plus
/// digits and letters), and nothing in the address tells one of them from a section such as
/// `ch3`. The matcher looks the segment up and learns which it is.
///
/// Version history:
///   1.0 — #1474: initial implementation
///   1.1 — #1474 review round 1: every segment but a page is a candidate document id, kept as
///          written — `d550A` was lower-cased, and `d710a-1`, `eta_d1` and `appA` were dropped
///   1.2 — #1474 review round 2: `prose`, the volume fields the text beside an address names when
///          the address names no document, so a document that text chooses is checked against them
///   1.3 — #1474 review round 5: `prose` says how its subseries was read, and only a year read
///          after the series' name is checked
///   1.4 — #1507: a range the parser reads by its fallback is checked too (documentation only;
///          the type is unchanged)
public struct CitationExactReference: Sendable, Equatable {

    /// The volume id, e.g. `"frus1961-63v05"`.
    public let volumeId: String

    /// The path segment after the volume, as written — a document id (`"d84"`, `"d373a"`,
    /// `"d710a-1"`) or a section (`"ch3"`), which the matcher tells apart by looking it up; `nil`
    /// for a link to the volume itself or to a page (`pg_50`, which the parser carries as the page
    /// number).
    public let documentId: String?

    /// The subseries, volume and part the text beside the address names, when the address names
    /// no document of its own and that text names any of them (#1474 review round 2); `nil`
    /// otherwise.
    ///
    /// The address still decides the volume — its id is exact — but a document found through the
    /// text's document number or page is the text's choice, and the text may name a different
    /// volume: `FRUS, 1961–1963, vol. XIV, doc. 84, https://…/frus1961-63v05` finds Volume V's
    /// document 84, which the matcher then reports as a best guess naming the cited volume XIV
    /// rather than as an exact match. The text's subseries is checked when it follows the
    /// series' name (`CitationVolumeFields.subseriesReading`, #1474 review round 5), or when it is
    /// a range of years the parser read by its fallback — the text naming no series, or naming it
    /// with another number before the year (#1507).
    public let prose: CitationVolumeFields?

    /// Creates a reference to `volumeId`, and to `documentId` within it when one is given, with the
    /// volume fields `prose` beside it names.
    public init(volumeId: String, documentId: String?, prose: CitationVolumeFields? = nil) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.prose = prose
    }
}

// MARK: - CitationVolumeFields

/// A subseries, volume and part as a citation's text names them (#1474 review round 2) — the three
/// fields that choose a volume, carried apart from `CitationInput`'s when a history.state.gov
/// address has already chosen it — with how the subseries was read (#1474 review round 5).
///
/// Version history:
///   1.0 — #1474 review round 2: initial implementation
///   1.1 — #1474 review round 5: `subseriesReading`, so the matcher checks a year the text reads
///          after the series' name and not the date a note opens with
///   1.2 — #1507: the two readings as the parser now takes them (a year after the name with no
///          number between; otherwise a range before a bare year), and the matcher checks a
///          `.firstYear` range too (documentation only; the type is unchanged)
public struct CitationVolumeFields: Sendable, Equatable {

    /// How the parser read a subseries (`CitationParser.extractSubseries`, #1474 review round 5).
    public enum SubseriesReading: Sendable, Equatable {
        /// The first year or range after the series' name — "FRUS", "Foreign Relations of the
        /// United States", or the bare "Foreign Relations" — with no other number between them, as
        /// in `FRUS, 1961–1963, vol. V`: the text naming a volume of the series. Since #1507 a year
        /// after a number is not this reading — `FRUS, vol. V, doc. 84, Memorandum, May 5, 1962`
        /// names no year at all.
        case afterSeriesName
        /// The first range in the text, or with none its first year, read because the text names
        /// the series nowhere, or names it with no year following it as above. Beside a
        /// history.state.gov link, where the link is often the note's only "frus", a single year
        /// read this way is the date the note opens with — the document's date, not a volume's
        /// (`Memorandum of Conversation, Moscow, May 5, 1962, vol. V, doc. 84`); a range is a
        /// subseries (`1964–68, vol. V, doc. 84`), and is read before any single year (#1507).
        case firstYear
    }

    /// The subseries, normalised as `CitationInput.subseries` is, e.g. `"1961-63"`.
    public let subseries: String?

    /// How `subseries` was read; `nil` exactly when `subseries` is.
    ///
    /// The matcher checks a subseries read `.afterSeriesName` against the linked volume, and one
    /// read `.firstYear` only when it is a range (`CitationMatchingEngine.namesSubseries`, #1507):
    /// a single year the text does not give as the series' is read as a date, and the link has
    /// named the volume.
    public let subseriesReading: SubseriesReading?

    /// The volume, as `CitationInput.volumeNumber` carries it, e.g. `"XIV"`.
    public let volumeNumber: String?

    /// The part, as `CitationInput.partNumber` carries it.
    public let partNumber: Int?

    /// Creates the fields; any of them may be absent. `subseriesReading` defaults to
    /// `.afterSeriesName`, the reading the matcher checks, so fields built without saying how
    /// their year was read never loosen the check; it is dropped when there is no `subseries`.
    public init(subseries: String? = nil, subseriesReading: SubseriesReading = .afterSeriesName,
                volumeNumber: String? = nil, partNumber: Int? = nil) {
        self.subseries = subseries
        self.subseriesReading = subseries == nil ? nil : subseriesReading
        self.volumeNumber = volumeNumber
        self.partNumber = partNumber
    }

    /// Whether the text named none of the three.
    public var isEmpty: Bool { subseries == nil && volumeNumber == nil && partNumber == nil }
}

// MARK: - CitationNumerals

/// The one reading of volume and part numerals that the parser and the matcher share (#1474).
///
/// A volume id states its numerals outright — `frus1952-54v02p1` is Volume 2, Part 1 — so the
/// matcher reads a cited numeral, or part, from the id alone and never from the title. Measured
/// over the 553 volumes of the bundled manifest: no id carries more than one `v<digits>` group,
/// every one of the 432 volumes whose title prints "Volume <numeral>" carries that number in its
/// id, every one of the 98 ids with a `p<digits>` part agrees with its title's "Part N", and no
/// title names a part its id lacks. An id with no `v<digits>` — a pre-1906 part volume, a
/// single-volume year — therefore matches no numeral, and no title would have supplied one. The
/// title is consulted only for a volume that is not a numeral: the E-volumes (`E–5`).
///
/// Version history:
///   1.0 — #1474: initial implementation
///   1.1 — #1474 review round 1: `volumeDesignation(inVolumeId:)`, so a link to an E-volume fills
///          the Volume field (`E-5`) as a link to any other volume does
enum CitationNumerals {

    /// Roman digit values, uppercase.
    private static let romanDigits: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100]

    /// The value of a Roman numeral (`"XIV"` → 14, case-insensitive), or `nil` when `text` holds
    /// anything but Roman digits up to C.
    static func romanValue(_ text: String) -> Int? {
        let upper = text.uppercased()
        guard !upper.isEmpty else { return nil }
        var total = 0
        var previous = 0
        for character in upper.reversed() {
            guard let value = romanDigits[character] else { return nil }
            total += value < previous ? -value : value
            previous = max(previous, value)
        }
        return total > 0 ? total : nil
    }

    /// The uppercase Roman numeral for `value` (1–399), e.g. `41` → `"XLI"`.
    static func roman(_ value: Int) -> String {
        let table: [(Int, String)] = [(100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                                      (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var remaining = value
        var result = ""
        for (amount, numeral) in table {
            while remaining >= amount {
                result += numeral
                remaining -= amount
            }
        }
        return result
    }

    /// A volume or part numeral as typed or printed — Arabic (`"2"`) or Roman (`"II"`) — as a
    /// positive integer, or `nil` for anything else (`"E-5"`, `"0"`, `""`).
    static func value(of numeral: String) -> Int? {
        let trimmed = numeral.trimmingCharacters(in: .whitespaces)
        if let arabic = Int(trimmed) { return arabic > 0 ? arabic : nil }
        return romanValue(trimmed)
    }

    /// The volume number a volume id carries: `frus1961-63v05` → 5, `frus1952-54v02p1` → 2,
    /// `frus1872p2v1` → 1. `nil` for an id with no `v<digits>` — an E-volume (`ve05p1`) or a
    /// single-volume year (`frus1913`) — and for a RANGE (`frus1961-63v07-09mSupp`): a microfiche
    /// supplement to Volumes VII–IX is not Volume VIII, and counting a range as the volumes it
    /// spans put the supplement `frus1961-63v10-12mSupp` ahead of the printed Volume XII for the
    /// app's own citation of `frus1961-63v12`.
    static func volumeNumber(inVolumeId volumeId: String) -> Int? {
        guard let match = firstMatch(#"v(\d+)(?![-\d])"#, in: volumeId) else { return nil }
        return Int(match[0])
    }

    /// The volume as a citation names it, read from a volume id: a Roman numeral for a numbered
    /// volume (`frus1961-63v05` → `"V"`), `"E-5"` for an E-volume (`frus1969-76ve05p1`, whose title
    /// prints "Volume E–5"), and `nil` for an id that names neither (`frus1913`, a range).
    ///
    /// All 22 E-volume ids in the bundled manifest are `ve<digits>`, and each title prints the same
    /// `E–N`; the matcher folds the title's en dash, so the hyphen here matches it.
    static func volumeDesignation(inVolumeId volumeId: String) -> String? {
        if let number = volumeNumber(inVolumeId: volumeId) { return roman(number) }
        guard let match = firstMatch(#"ve(\d+)"#, in: volumeId), let number = Int(match[0]) else {
            return nil
        }
        return "E-\(number)"
    }

    /// The part a volume id carries: `frus1952-54v02p1` → 1, `frus1863p2` → 2, `frus1872p2v1` → 2.
    /// A `p` inside a word is not a part, so `frus1917Supp01v01` → `nil`.
    static func partNumber(inVolumeId volumeId: String) -> Int? {
        guard let match = firstMatch(#"(?<![A-Za-z])p(\d+)"#, in: volumeId) else { return nil }
        return Int(match[0])
    }

    /// The capture groups of `pattern`'s first match in `text` (unmatched optional groups omitted).
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}

// MARK: - ParserConfidence

/// How well a raw citation string was parsed.
public enum ParserConfidence: Sendable, Equatable {
    /// All key fields extracted unambiguously.
    case high
    /// Some fields ambiguous or inferred.
    case medium
    /// Minimal fields extracted; much uncertainty.
    case low
    /// User entered fields directly; no parsing confidence issue.
    case structured
}

// MARK: - CitationMatch

/// A single candidate match from the citation lookup engine.
///
/// Always displayed using the standard `SearchResultRow` view component.
/// `confidenceLabel` provides an explicit human-readable explanation
/// of how the match was made and any corrections or assumptions applied.
///
/// Version history:
///   1.0 — Session 30: initial implementation
///   1.1 — #1503 review round 1: `sharedPageTotal`
///   1.2 — #1522: `awaitingIndex`
///   1.3 — #1506 review round 1: `volumeIsBestGuess` and `isBestGuess`
public struct CitationMatch: Sendable, Identifiable {

    public let documentId: String
    public let volumeId: String
    /// 1 = most likely
    public let rank: Int
    public let matchStrategy: MatchStrategy
    /// Explicit, plain-language label shown in UI above the result card.
    public let confidenceLabel: String
    /// Explanation shown below the result card when a correction was applied.
    public let correctionNote: String?
    /// `true` when the volume is not in the local downloaded corpus.
    public let requiresDownload: Bool
    /// `true` on the one row a downloaded volume gives when the index cannot yet say what it holds
    /// and nothing the citation names — a document, or a page the volume's pages are searched for —
    /// was found in it (#1522); a citation of the volume alone gives no such row, since no pass
    /// would change its answer (#1522 review round 1). The volume was never indexed — it is
    /// waiting after its download, or Settings' Rebuild Index has not reached it — or its indexing
    /// is running or was cut short. The row names the volume only, with `documentId` empty and the
    /// label `ConfidenceLabels.notYetIndexed`, or a best guess's label with that one in its note.
    /// Add Documents adds a link's numbered document from such a row by the link's id, as it does
    /// from a volume not downloaded, since the entry resolves once the volume is indexed.
    public let awaitingIndex: Bool
    /// Populated for `requiresDownload == true` results so the UI can show
    /// volume metadata before the user confirms a download, and for the other rows that name a
    /// volume but no document (`awaitingIndex`, and a link's volume that holds nothing it names).
    public let volumeManifestEntry: VolumeManifestEntry?
    /// For one of the documents a cited page names when the page cannot choose between them
    /// (`MatchStrategy.sharedPage`), how many it names, counting any the lookup does not list
    /// (#1503 review round 1). It stays when a best guess replaces the strategy, which then no
    /// longer says — so Batch counts every document on the page, and Add Documents gives one
    /// count. `nil` for every other match.
    public let sharedPageTotal: Int?
    /// `true` on a volume row — a volume offered for download, or one not yet indexed — whose
    /// volume does not carry a field the citation names, which the engine labels a best guess
    /// (`ConfidenceLabels.bestGuess`) while it keeps the row's `.manifestOnly` strategy, since the
    /// row names no document to guess at (#1506 review round 1). The strategy alone could not say
    /// so, and Batch counted such a row as ambiguous beside its own "Best guess — …" label.
    /// `false` for every other match; read it through `isBestGuess`.
    public let volumeIsBestGuess: Bool

    public var id: String { "\(volumeId)/\(documentId)/\(rank)" }

    /// Whether the engine labels this match a best guess: a document under `MatchStrategy.bestGuess`
    /// — from a volume that does not carry a cited field, or not on the cited page — the
    /// `.bestGuess` row a citation whose subseries no volume has gets, and a volume row whose
    /// volume does not carry a cited field (`volumeIsBestGuess`). Batch counts a lone one in its
    /// own bucket (`BatchCitationOutcome.bestGuess`, owner decision D17), so its summary and the
    /// row's "Best guess — …" label agree.
    public var isBestGuess: Bool {
        if case .bestGuess = matchStrategy { return true }
        return volumeIsBestGuess
    }

    public init(
        documentId: String,
        volumeId: String,
        rank: Int,
        matchStrategy: MatchStrategy,
        confidenceLabel: String,
        correctionNote: String? = nil,
        requiresDownload: Bool = false,
        awaitingIndex: Bool = false,
        volumeManifestEntry: VolumeManifestEntry? = nil,
        sharedPageTotal: Int? = nil,
        volumeIsBestGuess: Bool = false
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.rank = rank
        self.matchStrategy = matchStrategy
        self.confidenceLabel = confidenceLabel
        self.correctionNote = correctionNote
        self.requiresDownload = requiresDownload
        self.awaitingIndex = awaitingIndex
        self.volumeManifestEntry = volumeManifestEntry
        self.sharedPageTotal = sharedPageTotal
        self.volumeIsBestGuess = volumeIsBestGuess
    }
}

// MARK: - MatchStrategy

/// How the match was made.
///
/// `.sharedPage` (#1503) answers one cited page with several documents of one volume, by design —
/// or, in a volume that numbers its pages per document, with every document carrying that page
/// number, even one (review round 1); every surface that decides whether a result is confident —
/// Batch's triage (`BatchCitationOutcome`), Add Documents (`CollectionCitationLineResolver`) —
/// treats it as not.
///
/// A nearest-document case (`fuzzyDocumentNumber(nearest:)`) was deleted with the strategy that
/// made it (#1504): it read the manifest's `documentCount`, 0 in every row, so no lookup ever
/// returned one.
public enum MatchStrategy: Sendable, Equatable {
    /// Subseries + volume + doc number → direct hit (post-1955–57), in a volume that meets every
    /// cited field; or a history.state.gov link naming the document, in any era (#1474).
    case exactDocumentNumber
    /// Subseries + volume + page → the one document that begins on that page, or when none does,
    /// the one printed on it (#1503).
    case pageRange
    /// Subseries + volume + page → one of several documents the page names: several begin on it,
    /// or — when none does — several are printed on it (#1503); or one of the documents printed on
    /// a page of that number in a volume that numbers its pages per document, where a page number
    /// names no document however many carry it, one included (#1503 review round 1). `documents`
    /// is how many; Citation Lookup lists the first `CitationMatchingEngine.sharedPageListLimit`
    /// in source order and vouches for none of them.
    case sharedPage(documents: Int)
    /// Pre-1955–57 volume; doc number editorially assigned during digitization.
    case superimposedDocumentNumber
    /// Volume resolved via title fragment; doc/page then matched.
    case titleFragmentMatch
    /// Volume metadata only: the volume is not downloaded, or (#1474) a history.state.gov link
    /// names a downloaded volume but no document its index holds, and the citation names no
    /// document or page found in it either, or (#1522) the volume is downloaded and nothing the
    /// citation names was found while its index cannot yet say what it holds
    /// (`CitationMatch.awaitingIndex`).
    case manifestOnly
    /// Multiple corrections applied; explanation is in `correctionNote`. Also any document found
    /// in a volume that does not carry a field the citation names, or whose pages do not include
    /// the cited page (#1474).
    case bestGuess(explanation: String)
}

// MARK: - CitationLookupMode

/// The two input modes in the Citation Lookup view.
public enum CitationLookupMode: Sendable, CaseIterable, Equatable {
    case paste
    case structured
    /// A pasted block of footnotes, triaged as a table (#263).
    case batch

    /// Whether the mode reads the Parsed Fields, and so shows them (#1506): Paste fills them from
    /// the pasted citation and Structured Entry is them, while Batch parses each pasted note on
    /// its own and never reads them. Until #1506 Batch showed them anyway, holding the last paste's
    /// values, and a reader who edited one saw no effect on the batch.
    public var showsParsedFields: Bool { self != .batch }

    public var label: String {
        switch self {
        case .paste:
            return String(localized: "citation.mode.paste", defaultValue: "Paste Citation")
        case .batch:
            return String(localized: "citation.mode.batch", defaultValue: "Batch")
        case .structured:
            return String(localized: "citation.mode.structured", defaultValue: "Structured Entry")
        }
    }
}
