// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationFormatter Protocol

/// Generates a formatted citation string for a FRUS document.
///
/// Implement this protocol to add a new citation style. Register the style
/// as a `CitationStyle` enum case — no call-site changes are required
/// because the formatter is resolved via `CitationStyle.makeFormatter()`.
///
/// Current styles: `.historyAtState`, `.chicago`, `.turabian`
public protocol CitationFormatter: Sendable {
    func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String
}

// MARK: - CitationStyle

/// Enumerates available citation styles.
///
/// Additional styles are added by appending a case and implementing
/// `makeFormatter()` — no existing code changes required.
public enum CitationStyle: String, CaseIterable, Identifiable, Sendable {
    case historyAtState
    case chicago
    case turabian

    public var id: String { rawValue }

    public func makeFormatter() -> any CitationFormatter {
        switch self {
        case .historyAtState: return HistoryAtStateCitationFormatter()
        case .chicago: return ChicagoCitationFormatter()
        case .turabian: return TurabianCitationFormatter()
        }
    }

    public var displayName: String {
        switch self {
        case .historyAtState:
            return String(localized: "citation.style.historyAtState",
                          defaultValue: "History at State (Recommended)")
        case .chicago:
            return String(localized: "citation.style.chicago",
                          defaultValue: "Chicago")
        case .turabian:
            return String(localized: "citation.style.turabian",
                          defaultValue: "Turabian")
        }
    }

    /// A compact label suitable for a segmented control (e.g. the macOS
    /// citation popover's per-presentation style switcher).
    public var shortDisplayName: String {
        switch self {
        case .historyAtState:
            return String(localized: "citation.style.short.historyAtState",
                          defaultValue: "history.state.gov")
        case .chicago:
            return String(localized: "citation.style.short.chicago",
                          defaultValue: "Chicago")
        case .turabian:
            return String(localized: "citation.style.short.turabian",
                          defaultValue: "Turabian")
        }
    }

    /// The user's persisted citation style preference
    /// (`SettingsKeys.citationStyle`), defaulting to `.historyAtState`
    /// when unset or unrecognized. Drives `DocumentViewModel.formattedCitation`
    /// and friends, the iOS `CitationSheetView`, and the macOS citation
    /// popover's initial selection.
    public static var current: CitationStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.citationStyle),
                  let style = CitationStyle(rawValue: raw) else { return .historyAtState }
            return style
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: SettingsKeys.citationStyle)
        }
    }
}

// MARK: - Shared Formatting Helpers

/// Joins names as "Name", "Name1 and Name2", or "Name1, Name2, and Name3"
/// (Oxford comma) — used by the Chicago/Turabian styles, which prefix the
/// list with "edited by"/"Edited by" regardless of editor count (unlike the
/// history.state.gov "ed./eds." convention).
private func joinedNameList(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    case 2: return "\(names[0]) and \(names[1])"
    default:
        return names.dropLast().joined(separator: ", ") + ", and \(names.last!)"
    }
}

/// Extracts a display year from `dateString`, falling back to "n.d." when empty
/// or no 4-digit year can be found.
private func publicationYearString(from dateString: String) -> String {
    if let year = FRUSVolumeMetadata.firstYear(in: dateString) {
        return String(year)
    }
    return dateString.isEmpty ? "n.d." : dateString
}

// MARK: - FRUSDocumentMetadata

/// Lightweight metadata for a single FRUS document, used by citation formatters.
///
/// Constructed from a `DocumentBrowserEntry` when the user requests a citation.
/// Dateline is carried for future citation styles; the history.state.gov style
/// does not include the dateline in the formatted output.
public struct FRUSDocumentMetadata: Sendable {
    public let documentId: String
    public let documentNumber: String?
    public let header: String
    public let dateline: String?

    public init(documentId: String, documentNumber: String?,
                header: String, dateline: String?) {
        self.documentId = documentId
        self.documentNumber = documentNumber
        self.header = header
        self.dateline = dateline
    }

    public init(_ entry: DocumentBrowserEntry) {
        self.init(
            documentId: entry.documentId,
            documentNumber: entry.documentNumber,
            header: entry.header,
            dateline: entry.dateline
        )
    }
}

// MARK: - CitableDocumentNumber

/// The document number an exported citation names, for the sites that start from a document's
/// id — the one rule they all call (#1406).
///
/// ## Why not the id
/// Six sites — the trip packet's citations (`TripPacketDataSource`), a collection export's
/// document heading, excerpt source line and "See also" line (`CollectionContentResolver`), its
/// generated blocks' document tokens (`CollectionGeneratedBlocks`), the inspector's citation
/// placeholder (`CollectionEntryInspector`) and the Mac collection row (`MacCollectionManagerView`)
/// — each parsed the number out of the id and gave up on anything but `d` + an integer. Measured
/// over the 553 shipped volumes, **949 of 314,571** document divs have another id shape, and every
/// one of them was cited with no document number at all:
/// - **83** `d373a`-style ids (`d550A` among them), whose `@n` is the id's tail (`373a`) in every case;
/// - **628** microfiche-supplement ids in `frus1958-60v05mSupp` (`eta_d1`, `@n` `ETA–1`);
/// - **217** `frus1945Berlinv02` ids (`d710a-1`) whose `@n` is the editors' bracketed description,
///   `[Unnumbered document following Document 710 (#1)]`;
/// - **19** appendix ids in five 1981–88 volumes (`appA`, `@n` `331` or `A`);
/// - **2** with no `@n` (`frus1902app1`'s `s05sub04` and `s12`).
///
/// For the other 313,622 ids the `@n` IS the id's integer (three carry a trailing space), so
/// preferring the stored number changes no existing citation.
///
/// ## The rule
/// 1. The number the index stores (`document_cache.document_number`, the div's `@n`, trimmed) is
///    cited as printed — `373a`, `ETA–1`, `331`.
/// 2. **Except a bracketed `@n`**, which is the editors' description of a document the volume
///    prints WITHOUT a number — the 217 Potsdam documents, the only bracketed `@n` in the corpus.
///    Such a document is cited in the formatter's number-less form, ending at the publication
///    clause, exactly as an editorial note without a number is; the id is never substituted,
///    because `d710a-1` is not a locator anyone printed.
/// 3. When the index stores nothing — the document's volume is not indexed on this device — the
///    id stands in only where it is the number: `d12` → `12`, `d373a` → `373a` (right for all 83
///    lettered ids measured). Any other shape stays number-less until its volume is indexed.
enum CitableDocumentNumber {

    /// The number to cite for a document.
    ///
    /// - Parameters:
    ///   - printed: What the index stores for it (`document_cache.document_number`), or `nil` when
    ///     the document is not indexed. An empty value counts as none.
    ///   - documentId: The document's `xml:id`, used only under rule 3 of the type's note.
    /// - Returns: The number to print after "Document", or `nil` for the number-less form.
    static func resolve(printed: String?, documentId: String) -> String? {
        if let stored = printed?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
            return isEditorialDescription(stored) ? nil : stored
        }
        return fromDocumentId(documentId)
    }

    /// Whether a stored `@n` is the editors' bracketed description of an unnumbered document
    /// (`[Unnumbered document following Document 710 (#1)]`) rather than a number.
    static func isEditorialDescription(_ printed: String) -> Bool {
        printed.hasPrefix("[")
    }

    /// The number an id spells, for a document the index does not hold: `d` + digits, with at
    /// most one trailing letter (`d12` → `12`, `d0012` → `12`, `d373a` → `373a`). `nil` for every
    /// other shape (`eta_d1`, `d710a-1`, `appA`), whose number only the volume knows.
    static func fromDocumentId(_ documentId: String) -> String? {
        guard documentId.hasPrefix("d") else { return nil }
        let body = documentId.dropFirst()
        let digits = body.prefix(while: { $0.isASCII && $0.isWholeNumber })
        guard let number = Int(digits) else { return nil }
        let suffix = body.dropFirst(digits.count)
        guard suffix.count <= 1, suffix.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return String(number) + suffix
    }

    /// A document row's label where a list names documents by number — the Mac collection
    /// manager's rows: "Document 373a" when there is a number to cite, else the document's id,
    /// which is what the row showed for every such document before (and what the iOS row's caption
    /// shows for all of them).
    static func rowLabel(printed: String?, documentId: String) -> String {
        guard let number = resolve(printed: printed, documentId: documentId) else { return documentId }
        return String(format: String(localized: "collection.entry.documentLabel %@",
                                     defaultValue: "Document %@"), number)
    }
}

// MARK: - FRUSVolumeMetadata

/// Metadata for a FRUS volume, used by citation formatters.
///
/// Constructed from a `VolumeManifestEntry`. The `title` field stores the
/// full TEI title with normalized whitespace (the raw TEI value may contain
/// embedded newlines from XML pretty-printing).
///
/// Publisher is inferred from the publication year:
/// - pre-2014: "Government Printing Office"
/// - 2014+: "United States Government Publishing Office"
/// (GPO was renamed by Congress in December 2014.)
public struct FRUSVolumeMetadata: Sendable {
    /// Full volume title from the TEI `<titleStmt>`, whitespace-normalized.
    /// e.g., "Foreign Relations of the United States, 1969–1976, Volume I,
    ///        Foundations of Foreign Policy, 1969–1972"
    public let title: String
    public let editors: [String]
    public let generalEditor: String?
    /// Free-form date from the TEI `<publicationStmt>`, typically a year.
    public let publicationDate: String
    public let publicationPlace: String
    public let publisher: String

    public init(title: String, editors: [String], generalEditor: String?,
                publicationDate: String, publicationPlace: String, publisher: String) {
        self.title = title
        self.editors = editors
        self.generalEditor = generalEditor
        self.publicationDate = publicationDate
        self.publicationPlace = publicationPlace
        self.publisher = publisher
    }

    public init(_ entry: VolumeManifestEntry) {
        // Normalize whitespace: TEI titles often have embedded newlines.
        title = entry.title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        editors = entry.editors
        generalEditor = entry.generalEditor
        publicationDate = entry.publicationDate ?? ""
        publicationPlace = "Washington, D.C."
        let year = Self.firstYear(in: entry.publicationDate) ?? 0
        publisher = Self.publisher(forYear: year)
    }

    /// Returns a copy of this metadata with the publication year overridden by
    /// a value extracted live from the volume's TEI `<publicationStmt><date>`.
    ///
    /// The bundled manifest's `publicationDate` may hold a coverage range
    /// (e.g. "1969–1976") rather than the volume's actual print year, while the
    /// live XML's `@when` attribute is always the authoritative ISO publication
    /// date — see `firstYear(in:)` and the Session 2026-06-07 citation fix.
    /// `publisher` is recomputed from the overriding year per the GPO/USGPO rule.
    public func overridingPublicationYear(_ year: String) -> FRUSVolumeMetadata {
        FRUSVolumeMetadata(
            title: title,
            editors: editors,
            generalEditor: generalEditor,
            publicationDate: year,
            publicationPlace: publicationPlace,
            publisher: Self.publisher(forYear: Int(year) ?? 0)
        )
    }

    /// Extracts the first 4-digit year from a free-form date string.
    static func firstYear(in dateString: String?) -> Int? {
        guard let str = dateString, !str.isEmpty else { return nil }
        let digits = str.components(separatedBy: .init(charactersIn: "0123456789").inverted)
        return digits.first(where: { $0.count == 4 }).flatMap { Int($0) }
    }

    /// Derives the publisher name from a publication year.
    ///
    /// GPO (Government Printing Office) was renamed by Congress to USGPO
    /// (United States Government Publishing Office) in December 2014.
    static func publisher(forYear year: Int) -> String {
        year >= 2014
            ? "United States Government Publishing Office"
            : "Government Printing Office"
    }
}

// MARK: - HistoryAtStateCitationFormatter

/// Formats FRUS citations per the history.state.gov recommended style.
///
/// ## Format
/// ```
/// _Series Title_, [rest of volume title], [eds./ed. Names]
/// ([Place]: [Publisher], [Year]), Document [N].
/// ```
///
/// If no document number is available (editorial notes, pre-1955 volumes):
/// ```
/// _Series Title_, [rest of volume title], [eds. Names]
/// ([Place]: [Publisher], [Year]).
/// ```
///
/// The series title ("Foreign Relations of the United States" or historical
/// variants) is wrapped in underscores to indicate italics in Markdown.
///
/// ## Editor Formatting
/// - 1 editor: `ed. Name`
/// - 2 editors: `eds. Name1 and Name2`
/// - 3+ editors: `eds. Name1, Name2, and Name3` (Oxford comma)
///
/// ## Source
/// Confirmed against https://history.state.gov/historicaldocuments/citing-frus
/// at Session 13 (2026-05-15).
///
/// Version history:
///   1.0 — Session 13: initial implementation
///   1.1 — Session 2026-06-09: removed the `documentId` fallback introduced in
///          commit f886282. Documents without a printed number (editorial notes,
///          pre-1955 volumes) again end the citation after the publication
///          parenthetical instead of leaking the TEI `xml:id` (e.g. "edn-01")
///          into the formatted text.
public struct HistoryAtStateCitationFormatter: CitationFormatter {

    private static let knownSeriesNames: [String] = [
        "Foreign Relations of the United States",
        "Papers Relating to the Foreign Relations of the United States",
    ]

    public init() {}

    public func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String {
        var result = italicizedTitle(volume.title)

        if !volume.editors.isEmpty {
            result += ", " + editorString(volume.editors)
        }

        let year = publicationYear(from: volume.publicationDate)
        result += " (\(volume.publicationPlace): \(volume.publisher), \(year))"

        // Append "Document N" only when a printed document number exists. When nil
        // — editorial notes, cross-reference navigation entries, pre-1955 volumes
        // whose headers carry no numeric prefix — the citation ends after the
        // publication parenthetical, per the history.state.gov style documented
        // above. The TEI `xml:id` (e.g. "d217", "edn-01") is an internal
        // identifier, not a recognised citation locator, and must never leak into
        // the formatted text; document-level linking is served by the canonical
        // history.state.gov URL that the share flows append separately.
        if let number = document.documentNumber {
            result += ", Document \(number)."
        } else {
            result += "."
        }

        return result
    }

    // MARK: - Helpers

    private func italicizedTitle(_ fullTitle: String) -> String {
        for prefix in Self.knownSeriesNames where fullTitle.hasPrefix(prefix) {
            let suffix = String(fullTitle.dropFirst(prefix.count))
            return "_\(prefix)_\(suffix)"
        }
        return fullTitle
    }

    private func editorString(_ editors: [String]) -> String {
        switch editors.count {
        case 0:
            return ""
        case 1:
            return "ed. \(editors[0])"
        case 2:
            return "eds. \(editors[0]) and \(editors[1])"
        default:
            let head = editors.dropLast().joined(separator: ", ")
            return "eds. \(head), and \(editors.last!)"
        }
    }

    private func publicationYear(from dateString: String) -> String {
        if let year = FRUSVolumeMetadata.firstYear(in: dateString) {
            return String(year)
        }
        return dateString.isEmpty ? "n.d." : dateString
    }
}

// MARK: - ChicagoCitationFormatter

/// Formats FRUS citations per the Chicago Manual of Style (notes-bibliography),
/// using the full volume title.
///
/// ## Format
/// ```
/// *Full volume title*, edited by Name (City: Publisher, Year), Document N.
/// ```
///
/// If no document number is available (editorial notes, pre-1955 volumes), the
/// citation ends after the publication parenthetical instead of leaking the TEI
/// `xml:id` — mirrors `HistoryAtStateCitationFormatter`'s no-document-number
/// handling (Session 2026-06-09 fix).
///
/// Relocated from the macOS citation popover (`CitationPopoverView`) in
/// Session 153 so the style is available everywhere a citation is formatted.
public struct ChicagoCitationFormatter: CitationFormatter {

    public init() {}

    public func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String {
        var result = "*\(volume.title)*"

        if !volume.editors.isEmpty {
            result += ", edited by \(joinedNameList(volume.editors))"
        }

        let year = publicationYearString(from: volume.publicationDate)
        result += " (\(volume.publicationPlace): \(volume.publisher), \(year))"

        if let number = document.documentNumber {
            result += ", Document \(number)."
        } else {
            result += "."
        }

        return result
    }
}

// MARK: - TurabianCitationFormatter

/// Formats FRUS citations per Turabian (student edition of Chicago), using the
/// full volume title.
///
/// ## Format
/// ```
/// *Full volume title*. Edited by Name. City: Publisher, Year. Document N.
/// ```
///
/// If no document number is available (editorial notes, pre-1955 volumes), the
/// citation ends after the publication sentence instead of leaking the TEI
/// `xml:id` — mirrors `HistoryAtStateCitationFormatter`'s no-document-number
/// handling (Session 2026-06-09 fix).
///
/// Relocated from the macOS citation popover (`CitationPopoverView`) in
/// Session 153 so the style is available everywhere a citation is formatted.
public struct TurabianCitationFormatter: CitationFormatter {

    public init() {}

    public func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String {
        var result = "*\(volume.title)*"

        if !volume.editors.isEmpty {
            result += ". Edited by \(joinedNameList(volume.editors))"
        }

        let year = publicationYearString(from: volume.publicationDate)
        result += ". \(volume.publicationPlace): \(volume.publisher), \(year)"

        if let number = document.documentNumber {
            result += ". Document \(number)."
        } else {
            result += "."
        }

        return result
    }
}

// MARK: - CitationPunctuation

/// Prepares a formatted citation to be continued rather than stood alone (#1392).
///
/// All three formatters above end every citation they return with a period — "…, Document 41."
/// with a printed number (". Document 41." in Turabian), "…, 1984)." (or "…, 1984." in Turabian)
/// without one — which is right for a citation standing on its own, and `CitationFormatterTests`
/// pins it. A caller that CONTINUES the line has to take that period off and supply its own
/// punctuation, or it prints "Document 41., footnote 3". Its callers:
///
/// - `TripPacketExporter.footnoteLine(for:)` — the Archives Visit "Pointed at" line, in the
///   exported packet and in the plan editor ("…, Document 41, footnote 3.");
/// - `TripPacketExporter.drawnFromLine(for:)` — the packet's drawn-from line when it names a
///   file ("…, Document 41 — file 611.93/12–854."), which also takes the period off the file
///   designation, because a designation lifted from a source note can end in the note's own
///   (a library note's "files under 741.6111/10–1144.");
/// - the "See also:" line of the PDF, DOCX and HTML collection exporters, which joins several
///   citations with "; " ("…, Document 3; …, Document 7.").
///
/// The period comes off here rather than by giving the formatter a locator argument because the
/// drawn-from line continues with a file designation, which is not a locator; each caller ends
/// its line with its own period.
enum CitationPunctuation {

    /// `citation` without its one terminal period.
    ///
    /// Removes exactly one trailing period and nothing else. A string with none comes back
    /// unchanged — which is the `volumeId/documentId` fallback the citation data sources return
    /// when the manifest does not know the volume.
    static func withoutTerminalPeriod(_ citation: String) -> String {
        citation.hasSuffix(".") ? String(citation.dropLast()) : citation
    }
}
