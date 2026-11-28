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

    // The user's preference, `CitationStyle.current`, reads the app's settings, so it stays in the
    // app: `FRUSExplorer/Citation/CitationStyle+Preference.swift`.
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
/// The heading and the dateline open a Chicago or Turabian note (``FRUSNoteHead``, L43); the
/// history.state.gov style reads neither.
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

    /// The metadata an in-app citation of `entry` carries: its number through
    /// `CitableDocumentNumber.resolve`, the rule every export already applies (#1491).
    ///
    /// The reader's Copy Citation and its share, BibTeX, RIS and Zotero rows, the Mac citation and
    /// share popovers, and the Research-notes Markdown export build their citations here. Until
    /// #1491 they passed the stored number to the formatter as it was, so a document
    /// `frus1945Berlinv02` prints without a number was cited "…, Document [Unnumbered document
    /// following Document 710 (#1)]." in the app and with no number in an export — and the in-app
    /// form, pasted into Citation Lookup, read as document 710.
    ///
    /// It is the only initializer that starts from an entry. The one that passed
    /// `entry.documentNumber` through unresolved — the route #1491 retired, and the shorter call a
    /// new caller would reach for — is gone (#1491 review round 1), so no citation is built from an
    /// entry without the rule.
    ///
    /// - Parameters:
    ///   - entry: The document cited.
    ///   - printedNumber: The number the caller holds for it — the entry's, the index's or the
    ///     parse's, in the caller's own order of preference — or `nil` when it holds none.
    public init(citing entry: DocumentBrowserEntry, printedNumber: String?) {
        self.init(
            documentId: entry.documentId,
            documentNumber: CitableDocumentNumber.resolve(printed: printedNumber, documentId: entry.documentId),
            header: entry.header,
            dateline: entry.dateline
        )
    }
}

// MARK: - CitableDocumentNumber

/// The document number an exported citation names, for the sites that start from a document's
/// id — the one rule they all call (#1406). Since #1491 every in-app citation calls it too,
/// through `FRUSDocumentMetadata.init(citing:printedNumber:)`, so the app cites a document the
/// way its exports do. The captions that name a document by its number — the Mac reader's header,
/// previous and next buttons and toolbar centre, the citation popover, the Mac Search row and the
/// breadcrumb — call it as well (#1491 review round 1): they name a document the volume prints
/// without a number "Unnumbered (d710a-1)" (``unnumberedLabel(documentId:volumeId:)``, the owner's
/// decision D5 — the one label the Mac collection row and a generated block's list token read
/// too), never by its bracketed `@n` (``captionLabel(printed:documentId:)``,
/// ``headerLabel(printed:documentId:)``).
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
///    clause, exactly as an editorial note without a number is; the id is never substituted in a
///    citation, because `d710a-1` is not a locator anyone printed. Where a LIST names it — a
///    generated block's list token and the Mac collection row — it reads "Unnumbered (d710a-1)"
///    (``unnumberedLabel(documentId:volumeId:)``, #1493, the owner's decision D5): the id is the
///    document's history.state.gov locator, so it identifies the document, and "Unnumbered" says
///    why no number stands there. Before #1493 those two places printed the id as though it were
///    the number — "Document d710a-1", and the bare id. The captions that name a document by its
///    number read the same label through the same function (#1491).
/// 3. When the index stores nothing — the document's volume is not indexed on this device — the
///    id stands in only where it is the number: `d12` → `12`, `d373a` → `373a` (right for all 83
///    lettered ids measured). Any other shape stays number-less until its volume is indexed, and is
///    named by its id — bare on the Mac row, "Document d710a-1" in a block's list: with nothing
///    stored, nothing the app has read says the volume prints no number (`eta_d1` prints ETA–1),
///    so it calls none unnumbered, and it does not infer it from the id's shape. That shape would
///    be right on today's corpus — every document id like `d710a-1` is one of
///    `frus1945Berlinv02`'s 217 unnumbered documents (the only other `xml:id`s of that shape are
///    434 facsimile page anchors in the two 1961–63 microfiche supplements; measured at corpus
///    8e5da08c1) — but it is the encoders' convention, not a printed fact. So #1493's defect
///    remains on a Potsdam document whose volume this device has not indexed.
///
/// Version history:
///   1.0 — #1406: initial implementation
///   1.1 — #1493: ``isUnnumbered(printed:)`` and ``unnumberedLabel(documentId:volumeId:)``; the row label reads
///         "Unnumbered (id)" for a document the volume prints without a number
///   1.2 — #1491: ``captionLabel(printed:documentId:)`` and ``headerLabel(printed:documentId:)``, so
///         the Mac reader's captions, the citation popover, the Mac Search row and the breadcrumb
///         name an unnumbered document through the same ``unnumberedLabel(documentId:volumeId:)``
///   1.3 — FRUSCoreKit, part 1: moved to `FRUSCoreKit/Citation/` with this file, and public, with
///         every member, so FRUS Explorer Light's reader and Cite name a document by the number its
///         citation prints
public enum CitableDocumentNumber {

    /// The number to cite for a document.
    ///
    /// - Parameters:
    ///   - printed: What the index stores for it (`document_cache.document_number`), or `nil` when
    ///     the document is not indexed. An empty value counts as none.
    ///   - documentId: The document's `xml:id`, used only under rule 3 of the type's note.
    /// - Returns: The number to print after "Document", or `nil` for the number-less form.
    public static func resolve(printed: String?, documentId: String) -> String? {
        if let stored = printed?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
            return isEditorialDescription(stored) ? nil : stored
        }
        return fromDocumentId(documentId)
    }

    /// Whether a stored `@n` is the editors' bracketed description of an unnumbered document
    /// (`[Unnumbered document following Document 710 (#1)]`) rather than a number.
    public static func isEditorialDescription(_ printed: String) -> Bool {
        printed.hasPrefix("[")
    }

    /// The number an id spells, for a document the index does not hold: `d` + digits, with at
    /// most one trailing letter (`d12` → `12`, `d0012` → `12`, `d373a` → `373a`). `nil` for every
    /// other shape (`eta_d1`, `d710a-1`, `appA`), whose number only the volume knows.
    public static func fromDocumentId(_ documentId: String) -> String? {
        guard documentId.hasPrefix("d") else { return nil }
        let body = documentId.dropFirst()
        let digits = body.prefix(while: { $0.isASCII && $0.isWholeNumber })
        guard let number = Int(digits) else { return nil }
        let suffix = body.dropFirst(digits.count)
        guard suffix.count <= 1, suffix.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return String(number) + suffix
    }

    /// A document row's label where a list names documents by number — the Mac collection
    /// manager's rows: "Document 373a" when there is a number to cite; "Unnumbered (d710a-1)" for a
    /// document the volume prints without one (#1493); else — a number this device has not read —
    /// the document's id, which is what the row showed for every such document before (and what the
    /// iOS row's caption shows for all of them).
    public static func rowLabel(printed: String?, documentId: String) -> String {
        if let number = resolve(printed: printed, documentId: documentId) {
            return String(format: String(localized: "collection.entry.documentLabel %@",
                                         defaultValue: "Document %@"), number)
        }
        return isUnnumbered(printed: printed) ? unnumberedLabel(documentId: documentId) : documentId
    }

    /// Whether the number the index stores for a document says the volume prints it WITHOUT one: a
    /// bracketed `@n`, the editors' description (rule 2). `false` when nothing is stored — the app
    /// cannot tell an unnumbered document from one whose number it has not read.
    public static func isUnnumbered(printed: String?) -> Bool {
        guard let stored = printed?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty else { return false }
        return isEditorialDescription(stored)
    }

    /// How a list or a caption names a document the volume prints without a number (#1493, the
    /// owner's decision D5): "Unnumbered (d710a-1)" — its id, the history.state.gov locator, in place
    /// of the number it does not have. The one implementation of D5: the Mac collection row, a
    /// generated block's list token, and since #1491 the Mac reader's captions, the citation
    /// popover, the Mac Search row and the breadcrumb all read it. With `volumeId`, for a list spanning volumes, the volume follows the id
    /// inside the parentheses — "Unnumbered (d710a-1, frus1945Berlinv02)" — as a numbered
    /// document's token is followed by its volume ("12 (frus1969-76v01)").
    public static func unnumberedLabel(documentId: String, volumeId: String? = nil) -> String {
        guard let volumeId else {
            return String(format: String(localized: "document.unnumbered.label %@",
                                         defaultValue: "Unnumbered (%@)"), documentId)
        }
        return String(format: String(localized: "document.unnumbered.label.volume %@ %@",
                                     defaultValue: "Unnumbered (%1$@, %2$@)"), documentId, volumeId)
    }

    /// How a caption names a document by its number — "Doc 12" — where the caption has always
    /// fallen back to the id: the Mac reader's previous and next buttons and the position between
    /// them, the citation popover's identity line and the Mac Search row (#1491 review round 1).
    ///
    /// The number is the one a citation of the document prints (``resolve(printed:documentId:)``),
    /// so a caption and the citation beside it agree; a document the volume prints without a
    /// number reads ``unnumberedLabel(documentId:volumeId:)``; and a document whose number neither
    /// the index nor its id gives is named by its id, as each of these captions named it before ("Doc
    /// eta_d1" in a volume this device has not indexed). Until review round 1 each printed the
    /// stored `@n` as it was: "Doc [Unnumbered document following Document 710 (#1)]".
    ///
    /// - Parameters:
    ///   - printed: The number the caller holds for the document, or `nil` when it holds none.
    ///   - documentId: The document's `xml:id`.
    /// - Returns: The caption's text.
    public static func captionLabel(printed: String?, documentId: String) -> String {
        if isUnnumbered(printed: printed) { return unnumberedLabel(documentId: documentId) }
        return String(format: String(localized: "document.caption.number %@", defaultValue: "Doc %@"),
                      resolve(printed: printed, documentId: documentId) ?? documentId)
    }

    /// How the Mac reader's header names a document it holds a number for: "Document 475", or
    /// ``unnumberedLabel(documentId:volumeId:)`` for one the volume prints without a number (#1491
    /// review round 1; until then "Document [Unnumbered document following Document 710 (#1)]").
    ///
    /// - Parameters:
    ///   - printed: The number stored for the document; the header names none when there is none.
    ///   - documentId: The document's `xml:id`, named in place of a number the volume does not print.
    /// - Returns: The header's text.
    public static func headerLabel(printed: String, documentId: String) -> String {
        if isUnnumbered(printed: printed) { return unnumberedLabel(documentId: documentId) }
        return String(format: String(localized: "document.header.number %@", defaultValue: "Document %@"),
                      printed.trimmingCharacters(in: .whitespacesAndNewlines))
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

/// Formats a FRUS document as a note in the *Chicago Manual of Style*'s notes-bibliography style, the form the
/// manual's own answer on citing a FRUS document gives (L43; decision 161, which the owner adopted on 2026-11-27
/// from *Chicago Manual of Style Online*, faq0443, 18th edition, 14.13 and 14.22).
///
/// ## Format
/// ```
/// Sender to Recipient, type, Place, Date, in *Series, Years*, ed. General Editor, vol. N, *Volume Title*,
/// ed. Editors (Publisher, Year), doc. N.
/// ```
/// For `frus1969-76v21` d190 that is "The President’s Assistant for National Security Affairs (Kissinger) to
/// President Nixon, memorandum, Washington, December 18, 1970, in *Foreign Relations of the United States,
/// 1969–1976*, ed. Adam Howard, vol. 21, *Chile, 1969–1973*, ed. James McElveen and James Siekmeier (…, 2014),
/// doc. 190." The FAQ's note names the correspondents in full ("Henry Kissinger to Richard Nixon"); this one names
/// them as the editors' heading does, which is what the app can read (``FRUSNoteHead``).
///
/// - **The document first**, from its heading and dateline (``FRUSNoteHead``); a document whose heading the caller
///   does not have begins at the volume.
/// - **The volume** as ``FRUSVolumeTitle`` divides its title, with the series' general editor and the volume's own
///   editors, each "ed." as the FAQ gives them, every editor named.
/// - **No place of publication**: the 18th edition leaves it out. Turabian keeps it (``TurabianCitationFormatter``).
/// - **The publisher** is `FRUSVolumeMetadata.publisher`, which the app reads from the year. The FAQ's is the one on the
///   title page, and the TEI's `<publisher>` names another for 34 of the 553 volumes (L43's measurement): the Printing
///   Office for 14 of 2014 to 2017, the Department of State or the Office of the Historian for 20 more. The manifest
///   does not carry it; the plan offers the fix to its row L54.
/// - **"doc. N"** with history.state.gov's number (decision 197), and none for a document the volume does not
///   number, as before.
/// - **The address the FAQ ends with is not part of the string**: each caller adds it where it adds it for every
///   style, as the share sheet and an export's address line do.
///
/// Version history:
///   1.0 — Session 153: relocated from the macOS citation popover (`CitationPopoverView`) so the style is
///          available everywhere a citation is formatted
///   2.0 — L43 (decision 161): the FAQ's note in place of "*Full volume title*, edited by Name (City: Publisher,
///          Year), Document N.", which had a note's shape and named no document
public struct ChicagoCitationFormatter: CitationFormatter {

    /// Creates the formatter.
    public init() {}

    /// The note for `document` in `volume`.
    public func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String {
        FRUSNoteCitation.note(document: document, volume: volume, includesPlaceOfPublication: false)
    }
}

// MARK: - TurabianCitationFormatter

/// Formats a FRUS document as a note in Turabian's notes-bibliography style (*A Manual for Writers*, 9th edition):
/// Chicago's note (``ChicagoCitationFormatter``), with the place of publication, which Turabian's 9th edition keeps
/// in every book's note and Chicago's 18th leaves out (L43; decision 161, from Turabian's own quick guide).
///
/// ## Format
/// ```
/// Sender to Recipient, type, Place, Date, in *Series, Years*, ed. General Editor, vol. N, *Volume Title*,
/// ed. Editors (Washington, D.C.: Publisher, Year), doc. N.
/// ```
///
/// Version history:
///   1.0 — Session 153: relocated from the macOS citation popover (`CitationPopoverView`)
///   2.0 — L43 (decision 161): a note, as Chicago's is, in place of "*Full volume title*. Edited by Name. City:
///          Publisher, Year. Document N.", a bibliography entry's shape that ran its sentences together wherever
///          a line joined two citations
public struct TurabianCitationFormatter: CitationFormatter {

    /// Creates the formatter.
    public init() {}

    /// The note for `document` in `volume`.
    public func format(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata) -> String {
        FRUSNoteCitation.note(document: document, volume: volume, includesPlaceOfPublication: true)
    }
}

// MARK: - FRUSNoteCitation

/// The note Chicago and Turabian share (L43): the document, then "in" the volume. See
/// ``ChicagoCitationFormatter`` for the form and its source.
enum FRUSNoteCitation {

    /// The note for `document` in `volume`.
    ///
    /// - Parameters:
    ///   - document: The document cited: its heading and dateline name it, and its number is the locator.
    ///   - volume: The volume it is in.
    ///   - includesPlaceOfPublication: Whether the publication facts name the place, as Turabian's do.
    /// - Returns: The note, with `*…*` around the series and the volume's title, ending in one period.
    static func note(document: FRUSDocumentMetadata, volume: FRUSVolumeMetadata,
                     includesPlaceOfPublication: Bool) -> String {
        let title = FRUSVolumeTitle(title: volume.title)
        var parts = ["*\(title.series)*"]
        if let generalEditor = volume.generalEditor?.trimmingCharacters(in: .whitespacesAndNewlines),
           !generalEditor.isEmpty {
            parts.append("ed. \(generalEditor)")
        }
        if let locator = title.locator { parts.append(locator) }
        if let volumeTitle = title.volumeTitle { parts.append("*\(volumeTitle)*") }
        if !volume.editors.isEmpty { parts.append("ed. \(joinedNameList(volume.editors))") }
        var text = parts.joined(separator: ", ")
        let year = publicationYearString(from: volume.publicationDate)
        let facts = includesPlaceOfPublication
            ? "\(volume.publicationPlace): \(volume.publisher), \(year)"
            : "\(volume.publisher), \(year)"
        text += " (\(facts))"
        if let number = document.documentNumber { text += ", doc. \(number)" }
        text += "."
        guard let head = FRUSNoteHead.head(header: document.header, dateline: document.dateline) else { return text }
        return "\(head), in \(text)"
    }
}

// MARK: - FRUSNoteHead

/// The opening of a note in Chicago or Turabian: the document, named by its correspondents, its type, and its
/// place and date (L43; CMOS 14.13: "letters and other correspondence found in published collections are usually
/// cited by the names of the correspondents (sender first), the date of the correspondence (plus a place if
/// relevant), and the information for the collection").
///
/// It reads what the volume prints, the heading and the dateline, and adds no words of its own:
/// - **A heading of the form "Type From Sender to Recipient"** ("Telegram From the Embassy in Chile to the Department
///   of State") is turned into the FAQ's order: "The Embassy in Chile to the Department of State, telegram". The type
///   is one to four capitalized words before " From " (or " from "), in lower case but for an acronym; the rest must
///   name a recipient after " to " and hold no second " From ", so "Extract From a Letter From X to Y" stays as
///   printed.
/// - **Any other heading reads as printed**: "The Chargé in the Soviet Union (Kennan) to the Secretary of State",
///   which already names sender and recipient in that order, "Memorandum of Conversation", "Editorial Note".
/// - **The volume's own number** before a heading ("1.", "No. 98.") is left out
///   (`DocumentHeadingReading.splitNumber(_:)`), and so is one period ending it ("Mr. White to Mr. Fish.").
/// - **The place and date** are the dateline's words up to its first full date ("Santiago, March 25, 1969" from
///   "Santiago, March 25, 1969, 1700Z."; "Moscow, February 22, 1946" from "Moscow, February 22, 1946—9 p.m.
///   [Received …]"), without a weekday; a dateline with no full date gives none.
///
/// Measured over the 321,749 documents a full library indexes (2026-11-27): 47,925 headings take the FAQ's order,
/// the commonest types "telegram" (20,083), "memorandum" (19,161) and "letter" (3,916); 211,276 already read
/// "Sender to Recipient"; 61,445 read as printed otherwise. 295,614 datelines give a place and date, 5,287 give
/// none (an undated document, "June 1955", a date with no year), and 19,745 documents have no dateline.
///
/// The short form (``FRUSShortCitation``, L49) reads neither line. It names the volume and the document's number,
/// "*FRUS*, 1946, vol. VI, doc. 475", the form the owner chose; the FAQ's later note, by correspondents, place and
/// date, names no volume and is not unique, and was not put to the owner (Wave 6 prep).
///
/// Version history:
///   1.0 — L43 (decision 161): initial implementation
public enum FRUSNoteHead {

    /// The note's opening, "The Embassy in Chile to the Department of State, telegram, Santiago, March 25, 1969",
    /// or `nil` where the heading names nothing.
    ///
    /// - Parameters:
    ///   - header: The document's heading, as the index stores it or as the one reading prints it.
    ///   - dateline: The document's dateline, or `nil`.
    public static func head(header: String, dateline: String?) -> String? {
        guard let description = description(ofHeading: header) else { return nil }
        guard let placeAndDate = placeAndDate(dateline: dateline) else { return description }
        return "\(description), \(placeAndDate)"
    }

    /// What the note calls the document: its heading, in the FAQ's order where the heading reads "Type From Sender
    /// to Recipient", else as printed. `nil` for an empty heading.
    ///
    /// - Parameter header: The document's heading.
    public static func description(ofHeading header: String) -> String? {
        var words = DocumentHeadingReading.splitNumber(header).words
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        // One closing mark comes off, as the note's own comma follows: a colon, a semicolon or a comma always, a
        // period unless it ends an abbreviation with a period inside it ("U.S.").
        if let mark = words.last, ":;,".contains(mark) {
            words.removeLast()
        } else if words.hasSuffix("."), let last = words.split(separator: " ").last,
                  last.filter({ $0 == "." }).count == 1 {
            words.removeLast()
        }
        guard !words.isEmpty else { return nil }
        let range = NSRange(words.startIndex..., in: words)
        if let typed = typedHeading?.firstMatch(in: words, range: range),
           let typeRange = Range(typed.range(at: 1), in: words),
           let restRange = Range(typed.range(at: 2), in: words) {
            let rest = String(words[restRange])
            if !rest.contains(" From ") {
                let type = words[typeRange].split(separator: " ").map { word in
                    word.count > 1 && word.allSatisfy({ $0.isUppercase }) ? String(word) : word.lowercased()
                }.joined(separator: " ")
                return rest.prefix(1).uppercased() + rest.dropFirst() + ", " + type
            }
        }
        return words
    }

    /// The dateline's place and date, up to its first full date: "Santiago, March 25, 1969". `nil` for no dateline,
    /// or one with no full date.
    ///
    /// - Parameter dateline: The document's dateline.
    public static func placeAndDate(dateline: String?) -> String? {
        guard let dateline else { return nil }
        let text = dateline.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let fullDate, let match = fullDate.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let dateRange = Range(match.range, in: text) else { return nil }
        let date = String(text[dateRange])
        var place = String(text[..<dateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        if place.hasSuffix(",") { place.removeLast() }
        if let weekday = weekdays.first(where: { place.hasSuffix($0) }) {
            place = String(place.dropLast(weekday.count)).trimmingCharacters(in: .whitespaces)
            if place.hasSuffix(",") { place.removeLast() }
        }
        if place.hasSuffix(",]") { place = String(place.dropLast(2)) + "]" }
        place = place.trimmingCharacters(in: .whitespaces)
        return place.isEmpty ? date : "\(place), \(date)"
    }

    /// "Type From Sender to Recipient": one to four capitalized words (an acronym among them), " From " or " from ",
    /// then the rest, which names a recipient after " to ".
    private static let typedHeading = try? NSRegularExpression(
        pattern: #"^((?:[A-Z][\p{L}’'\-]*)(?: [A-Z][\p{L}’'\-]*){0,3}) [Ff]rom (.+ to .+)$"#)

    /// A full date, "March 25, 1969", "September 12th, 1873" or "28th January, 1947".
    private static let fullDate = try? NSRegularExpression(pattern: #"""
        (?:(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4})|(?:\d{1,2}(?:st|nd|rd|th)?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December),?\s+\d{4})
        """#)

    /// The weekdays a dateline may name before its date, which a note leaves out.
    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
}

// MARK: - FRUSVolumeTitle

/// A volume's title, divided as a note in Chicago or Turabian cites it (L43, decision 161): the series with its
/// years, in italics; the volume's number, which a note gives in arabic figures ("vol. 21"), with a part ("pt. 1");
/// and the volume's own title, in italics. The *Chicago Manual of Style*'s answer on citing FRUS cites
/// `frus1969-76v21` "in *Foreign Relations of the United States, 1969–1976*, ed. Adam Howard, vol. 21, *Chile,
/// 1969–1973*".
///
/// It reads the one title the manifest carries (`VolumeManifestEntry.title`, the TEI's complete title). The TEI's
/// title statement also holds the parts apart (`<title type="series">`, `"volume-number"`, `"volume"`), which the
/// manifest does not carry, so the title is read by its form:
/// - **The series** is the title's opening series name: "Foreign Relations of the United States" (with "Diplomatic
///   Papers" where the title has it), "Papers Relating to the Foreign Relations of the United States" or "Papers
///   Relating to Foreign Affairs", with the years that follow it ("1969–1976", "1946").
/// - **The volume's number** follows "Volume" or "Volumes": "XXI", "E–1", "VII, VIII, IX", "X/XI/XII", each Roman
///   numeral in arabic figures. "Microfiche Supplement" after it goes with it.
/// - **A part** ("Part 1", "Part II") goes with the number, and in the 1870s titles the words before it go with the
///   series ("…, Transmitted to Congress, With the Annual Message of the President, December 1, 1873").
/// - **The volume's title** is the rest: what follows the number ("Chile, 1969–1973"), or what lies between the
///   years and a number that ends the title ("Eastern Europe, The Soviet Union").
/// - **A title with no volume number is a book of its own**, cited whole, with its part where it ends in one.
///
/// Measured on 2026-11-27 against the TEI's own parts in the corpus clone, for the 553 catalogue volumes: the volume
/// title read here is the TEI's for 515. Of the other 38, 30 titles have no volume number and are cited whole, the
/// 1860s parts and the 1894 and 1902 appendices among them; five are the 1872 Treaty of Washington volumes, whose
/// TEI title does not appear in their complete title; two are Japan, 1931–1941, whose TEI puts "Japan, 1931–1941"
/// in the volume number; and one, `frus1941v03`, capitalizes "The Near East" where its TEI does not.
///
/// Version history:
///   1.0 — L43 (decision 161): initial implementation
///   1.1 — L49: the series names, the forms of the number, the years and the parts, `match` and `arabicList`
///          internal, for the short form (``FRUSShortCitation``)
public struct FRUSVolumeTitle: Sendable, Equatable {

    /// The series with its years, the note's first italic title: "Foreign Relations of the United States,
    /// 1969–1976". The whole title where the title has no volume number.
    public let series: String
    /// The volume's number as a note gives it: "21", "E–1", "7, 8, 9". `nil` where the title has none.
    public let volumeNumber: String?
    /// Whether the title names more than one volume ("Volumes VII, VIII, IX"), which a note gives as "vols.".
    public let isSeveralVolumes: Bool
    /// The part, in arabic figures: "1". `nil` where the title names none.
    public let part: String?
    /// Whether the title names its part before its volume ("Part II, Volume I"), as the 1870s titles do.
    public let partComesFirst: Bool
    /// Whether "Microfiche Supplement" follows the volume's number.
    public let isMicroficheSupplement: Bool
    /// The volume's own title, the note's second italic title: "Chile, 1969–1973". `nil` where it has none.
    public let volumeTitle: String?

    /// The note's locator for the volume: "vol. 21", "vols. 7, 8, 9", "vol. 19, pt. 1", "pt. 2, vol. 1", "vol. 3,
    /// Microfiche Supplement", or "pt. 1" for a book in parts. `nil` where the title names neither.
    public var locator: String? {
        var pieces: [String] = []
        if let volumeNumber { pieces.append((isSeveralVolumes ? "vols. " : "vol. ") + volumeNumber) }
        if let part {
            if partComesFirst { pieces.insert("pt. \(part)", at: 0) } else { pieces.append("pt. \(part)") }
        }
        if isMicroficheSupplement { pieces.append("Microfiche Supplement") }
        return pieces.isEmpty ? nil : pieces.joined(separator: ", ")
    }

    /// Divides `title`, as the type's note says.
    ///
    /// - Parameter title: The volume's complete title.
    public init(title: String) {
        let text = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let prefix = Self.seriesNames.first(where: { text.hasPrefix($0) }) else {
            self.init(series: text)
            return
        }
        let rest = String(text.dropFirst(prefix.count))
        guard let number = Self.volumeNumberPattern?.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
              let matched = Range(number.range, in: rest),
              let wordRange = Range(number.range(at: 1), in: rest),
              let numberRange = Range(number.range(at: 2), in: rest) else {
            // A book of its own: cited whole, with its part where the title ends in one.
            if let part = Self.match(Self.trailingPart, in: text) {
                self.init(series: String(text[..<part.whole.lowerBound]), part: Self.arabic(String(text[part.group])))
            } else {
                self.init(series: text)
            }
            return
        }
        let isSeveral = rest[wordRange] == "Volumes"
        let numbers = Self.arabicList(String(rest[numberRange]))
        var before = String(rest[..<matched.lowerBound])
        var after = String(rest[matched.upperBound...])
        after = after.replacingOccurrences(of: #"^[,:]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        var part: String?
        var partFirst = false
        if let leading = Self.match(Self.leadingPart, in: after) {
            part = Self.arabic(String(after[leading.group]))
            after = String(after[leading.whole.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        var supplement = false
        if after.hasPrefix("Microfiche Supplement") {
            supplement = true
            after = after.replacingOccurrences(of: #"^Microfiche Supplement,?\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        var series = prefix
        if let years = Self.match(Self.leadingYears, in: before) {
            series += ", " + before[years.group]
            before = String(before[years.whole.upperBound...])
        }
        var middle = before.replacingOccurrences(of: #"^,\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if let inner = Self.match(Self.innerPart, in: middle) {
            part = Self.arabic(String(middle[inner.group]))
            partFirst = true
            let lead = middle[..<inner.whole.lowerBound].trimmingCharacters(in: .whitespaces)
            middle = String(middle[inner.whole.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !lead.isEmpty { series += ", " + lead }
        }
        let volumeTitle: String?
        switch (middle.isEmpty, after.isEmpty) {
        case (false, false): volumeTitle = middle + ", " + after
        case (true, false): volumeTitle = after
        case (false, true): volumeTitle = middle
        case (true, true): volumeTitle = nil
        }
        self.init(series: series, volumeNumber: numbers, isSeveralVolumes: isSeveral, part: part,
                  partComesFirst: partFirst, isMicroficheSupplement: supplement, volumeTitle: volumeTitle)
    }

    /// Creates a title from its parts.
    private init(series: String, volumeNumber: String? = nil, isSeveralVolumes: Bool = false, part: String? = nil,
                 partComesFirst: Bool = false, isMicroficheSupplement: Bool = false, volumeTitle: String? = nil) {
        self.series = series
        self.volumeNumber = volumeNumber
        self.isSeveralVolumes = isSeveralVolumes
        self.part = part
        self.partComesFirst = partComesFirst
        self.isMicroficheSupplement = isMicroficheSupplement
        self.volumeTitle = volumeTitle
    }

    // MARK: The forms read

    // The series names, the forms of the number, the years and the parts, `match` and the numerals are the short
    // form's too (``FRUSShortCitation``), which reads a title's series, number and part as the note does.

    /// The series names a title opens with, longest first, so that "…, Diplomatic Papers" is read whole.
    static let seriesNames = [
        "Papers Relating to the Foreign Relations of the United States",
        "Foreign Relations of the United States, Diplomatic Papers",
        "Foreign Relations of the United States",
        "Papers Relating to Foreign Affairs",
    ]

    /// ", Volume XXI", ", Volumes VII, VIII, IX", ", Volume E–1", before a comma, a colon or the end.
    static let volumeNumberPattern = try? NSRegularExpression(
        pattern: #",?\s*(Volumes?)\s+((?:[IVXLC]+|[A-Z]–\d+)(?:(?:, ?|/)[IVXLC]+)*)(?=[,:]|$)"#)

    /// ", Part I" ending a title with no volume number.
    private static let trailingPart = try? NSRegularExpression(pattern: #",\s*Part\s+([IVXLC]+|\d+)$"#)

    /// "Part 1, " opening the words after a volume's number.
    static let leadingPart = try? NSRegularExpression(pattern: #"^Part\s+([IVXLC]+|\d+)(?:,\s*|$)"#)

    /// "Part II" among the words between the series and the number, as the 1870s titles have it.
    static let innerPart = try? NSRegularExpression(pattern: #"(?:^|,\s*)Part\s+([IVXLC]+|\d+)(?:,\s*|$)"#)

    /// ", 1969–1976" or ", 1946" right after the series name.
    static let leadingYears = try? NSRegularExpression(pattern: #"^,\s*(\d{4}(?:–\d{4})?)(?=,|$)"#)

    /// The first match of `pattern` in `text`: its whole range and its first group's.
    static func match(_ pattern: NSRegularExpression?, in text: String)
        -> (whole: Range<String.Index>, group: Range<String.Index>)? {
        guard let pattern, let found = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let whole = Range(found.range, in: text), let group = Range(found.range(at: 1), in: text) else { return nil }
        return (whole, group)
    }

    /// Each Roman numeral of a list ("VII, VIII, IX", "X/XI/XII") in arabic figures, separators kept.
    static func arabicList(_ list: String) -> String {
        var out = ""
        var token = ""
        for character in list {
            if character == "," || character == "/" || character == " " {
                out += arabic(token) + String(character)
                token = ""
            } else {
                token.append(character)
            }
        }
        return out + arabic(token)
    }

    /// `numeral` in arabic figures where it is a Roman numeral ("XXI" → "21"), else as it is ("E–1", "2").
    static func arabic(_ numeral: String) -> String {
        let values: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100]
        guard !numeral.isEmpty, numeral.allSatisfy({ values[$0] != nil }) else { return numeral }
        var total = 0
        let digits = numeral.compactMap { values[$0] }
        for (index, value) in digits.enumerated() {
            if index + 1 < digits.count, value < digits[index + 1] { total -= value } else { total += value }
        }
        return String(total)
    }
}

// MARK: - FRUSShortCitation

/// The short form of a citation (L49; the Collections design's candidate 11, which the owner took in decision 164):
/// "*FRUS*, 1946, vol. VI, doc. 475", in the collection's style, "vol. VI" in History at State and "vol. 6" in
/// Chicago and Turabian, as their notes write a volume's number (the desk check's question 4).
///
/// ## The rule
/// The design's form, the years and the volume's number, names more than one volume for 132 of the manifest's 553,
/// in 60 groups (measured 2026-11-28): the parts of 1864, the appendices of 1894 and 1902, the conferences of 1943,
/// the parts of every divided volume since 1948. So the form adds what the volume's own title names it by, in the
/// title's order, and prints no word the volume does not print:
/// - **The years** the title gives after the series' name ("1946", "1969–1976"). An annual volume of 1861 to 1917,
///   whose title describes the President's message in their place, takes its subseries' year ("1864").
/// - **A topic before the years** is the volume's name, printed whole with its years: "The Paris Peace Conference,
///   1919", "Japan, 1931–1941", "The Conference of Berlin (The Potsdam Conference), 1945", "The Soviet Union,
///   1933–1939".
/// - **A volume with no number** is named by its topic: "1894, Nicaragua (Mosquito Territory)", "1952–1954, Iran,
///   1951–1954", "1945–1950, Emergence of the Intelligence Establishment". An appendix or a supplement is named by
///   that word and its number alone: "1894, Appendix I", "1914, Supplement", "1918, Supplement 2".
/// - **A numbered volume of a run of its own within its years**, which its id names before its number
///   (`frus1918Russiav01`, `frus1917Supp02v01`), is named by the run: "1918, Russia, vol. I", "1917, Supplement 2,
///   vol. I". Every other topic before a number is the volume's subtitle, which the number makes unneeded: "1946, vol.
///   VI", where the title reads "1946, Eastern Europe, The Soviet Union, Volume VI".
/// - **The locator**: "vol." or "vols." with the number, the part ("pt. 1", or "pt. II, vol. I" where the title names
///   its part first), and "Microfiche Supplement".
/// - **The edition** a title ends with: "Second Edition", "Second, Revised Edition". So the two first editions the
///   manifest holds beside their second (`frus1951-54Iran`, `frus1969-76ve15p2`) are told apart.
/// - **Three titles say less than their volumes**, and the id says the rest. `frus1877app`'s title is 1877's own, so it
///   is "1877, Appendix"; `frus1894app2`'s is "Foreign Relations of the United States, 1894" alone, so it is "1894,
///   Appendix II", as its TEI's volume number reads; and `frus1961-63v07-09mSupp`'s does not say that it is a
///   microfiche supplement, which its id and its TEI do.
///
/// The words are the ones the volumes cite each other by (counted 2026-11-28 in the corpus clone at `216cdb764`):
/// "*Foreign Relations*, 1918, Russia, vol." 126 times, "…, The Paris Peace Conference, 1919, vol." 145, "…, Japan,
/// 1931–1941, vol." 1,232, "…, 1917, Supplement 2, vol." 97, "…, 1961–1963, vols. VII, VIII, IX, Microfiche
/// Supplement" 9. Only the locators are abbreviated, as the owner's form abbreviates them; "Supplement" and "Appendix"
/// are written out, as the volumes write them, and their numbers are the volume's own in every style.
///
/// Over the 553 no two forms are alike in any style (`FRUSShortCitationTests.namesOneVolumeEach`); they run to 72
/// characters, median 26, in History at State. A side-loaded volume is read the same way, and nothing holds its form
/// apart from the catalogue's.
///
/// Version history:
///   1.0 — L49: initial implementation
public struct FRUSShortCitation: Sendable, Equatable {

    /// A number as the volume prints it and in arabic figures: "VI" and "6"; "E–15" and "E–15".
    public struct Numeral: Sendable, Equatable {
        /// As the title prints it.
        public let printed: String
        /// In arabic figures, as a Chicago or Turabian note gives it.
        public let arabic: String
    }

    /// What names the volume before its locator, in the title's order: "1946"; "1918" and "Russia"; "The Paris Peace
    /// Conference, 1919"; "1894" and "Appendix II".
    public let names: [String]
    /// The volume's number: "VI", "E–15", "VII, VIII, IX". `nil` where the title names none.
    public let volumeNumber: Numeral?
    /// Whether the title names more than one volume ("Volumes VII, VIII, IX"), which the form gives as "vols.".
    public let isSeveralVolumes: Bool
    /// The part: "1", "II". `nil` where the title names none.
    public let part: Numeral?
    /// Whether the title names its part before its volume ("Part II, Volume I"), as the 1870s titles do.
    public let partComesFirst: Bool
    /// Whether the volume is a microfiche supplement.
    public let isMicroficheSupplement: Bool
    /// The edition the title ends with: "Second Edition", "Second, Revised Edition". `nil` for none.
    public let edition: String?

    /// The short form of `entry`.
    ///
    /// - Parameter entry: The volume, as the manifest describes it.
    public init(_ entry: VolumeManifestEntry) {
        self.init(volumeId: entry.volumeId, subseries: entry.subseries, title: entry.title)
    }

    /// The short form of the volume `volumeId`, read from its title as the type's note says.
    ///
    /// - Parameters:
    ///   - volumeId: The volume's id, `frus1946v06`, which names a run, an appendix or a microfiche supplement where
    ///     the title does not.
    ///   - subseries: The manifest's subseries, `1946`, which gives the years where the title gives none.
    ///   - title: The volume's complete title.
    public init(volumeId: String, subseries: String, title: String) {
        let text = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        // The series' name, which the form abbreviates; 1861's title opens with the President's message instead.
        let series = FRUSVolumeTitle.seriesNames.first { text.hasPrefix($0) }
        var rest = series.map { String(text.dropFirst($0.count)) } ?? ", " + text
        // The edition that ends a title, which the form names last.
        var edition: String?
        if let found = FRUSVolumeTitle.match(Self.trailingEdition, in: rest) {
            edition = String(rest[found.group])
            rest = String(rest[..<found.whole.lowerBound])
        }
        // The years right after the series' name.
        var years: String?
        if let found = FRUSVolumeTitle.match(FRUSVolumeTitle.leadingYears, in: rest) {
            years = String(rest[found.group])
            rest = String(rest[found.whole.upperBound...])
        }
        rest = Self.trimmed(rest)
        // The words before the volume's number, and after it.
        var head = rest
        var tail = ""
        var number: Numeral?
        var several = false
        if let pattern = FRUSVolumeTitle.volumeNumberPattern,
           let found = pattern.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
           let whole = Range(found.range, in: rest), let word = Range(found.range(at: 1), in: rest),
           let digits = Range(found.range(at: 2), in: rest) {
            let printed = String(rest[digits])
            number = Numeral(printed: printed, arabic: FRUSVolumeTitle.arabicList(printed))
            several = rest[word] == "Volumes"
            head = Self.trimmed(String(rest[..<whole.lowerBound]))
            tail = Self.trimmed(String(rest[whole.upperBound...]))
        }
        // The part: after the number ("Volume I, Part 2"), before it ("Part II, Volume I"), or in a title with none.
        var part: Numeral?
        var partFirst = false
        if number != nil, let found = FRUSVolumeTitle.match(FRUSVolumeTitle.leadingPart, in: tail) {
            part = Self.numeral(String(tail[found.group]))
            tail = Self.trimmed(String(tail[found.whole.upperBound...]))
        } else if let found = FRUSVolumeTitle.match(FRUSVolumeTitle.innerPart, in: head) {
            part = Self.numeral(String(head[found.group]))
            partFirst = number != nil
            head = Self.trimmed(String(head[..<found.whole.lowerBound]))
        }
        // What names the volume before its locator.
        let isAnnualVolume = series == nil
            || head.range(of: #"(Message|Address) of the President"#, options: .regularExpression) != nil
        let firstName = head.components(separatedBy: ", ").first ?? ""
        var names: [String] = []
        if isAnnualVolume {
            names.append(years ?? Self.years(fromSubseries: subseries))
        } else if let years {
            names.append(years)
            if number != nil {
                if Self.namesRun(volumeId: volumeId), !firstName.isEmpty { names.append(firstName) }
            } else if firstName.hasPrefix("Appendix") || firstName.hasPrefix("Supplement") {
                names.append(firstName)
            } else if !head.isEmpty {
                names.append(head)
            }
        } else {
            names.append(head.isEmpty ? Self.years(fromSubseries: subseries) : head)
        }
        if !names.contains(where: { $0.hasPrefix("Appendix") }), let appendix = Self.appendix(volumeId: volumeId) {
            names.append(appendix)
        }
        self.names = names
        volumeNumber = number
        isSeveralVolumes = several
        self.part = part
        partComesFirst = partFirst
        isMicroficheSupplement = tail.hasPrefix("Microfiche Supplement") || (number != nil && volumeId.hasSuffix("mSupp"))
        self.edition = edition
    }

    /// The volume in `style`: "_FRUS_, 1946, vol. VI" in History at State, "*FRUS*, 1946, vol. 6" in Chicago and
    /// Turabian, each style's italics as its full citation marks them.
    ///
    /// - Parameter style: The collection's citation style.
    public func volume(in style: CitationStyle) -> String {
        let arabic: Bool
        let series: String
        switch style {
        case .historyAtState: (arabic, series) = (false, "_FRUS_")
        case .chicago, .turabian: (arabic, series) = (true, "*FRUS*")
        }
        func figures(_ numeral: Numeral) -> String { arabic ? numeral.arabic : numeral.printed }
        var locator: [String] = []
        if let volumeNumber { locator.append((isSeveralVolumes ? "vols. " : "vol. ") + figures(volumeNumber)) }
        if let part {
            let text = "pt. " + figures(part)
            if partComesFirst { locator.insert(text, at: 0) } else { locator.append(text) }
        }
        if isMicroficheSupplement { locator.append("Microfiche Supplement") }
        return ([series] + names + locator + [edition].compactMap { $0 }).joined(separator: ", ")
    }

    /// A document of the volume in `style`: "_FRUS_, 1946, vol. VI, doc. 475.", ending in one period as every full
    /// citation does. A document the volume does not number is named by its volume alone, as its full citation is.
    ///
    /// - Parameters:
    ///   - documentNumber: The number to cite (``CitableDocumentNumber/resolve(printed:documentId:)``), or `nil`.
    ///   - style: The collection's citation style.
    public func citation(documentNumber: String?, in style: CitationStyle) -> String {
        var text = volume(in: style)
        if let documentNumber { text += ", doc. \(documentNumber)" }
        return text + "."
    }

    // MARK: The forms read

    /// ", Second Edition" or ", Second, Revised Edition" ending a title.
    private static let trailingEdition = try? NSRegularExpression(pattern: #",\s*((?:[A-Z][a-z]+,?\s)+Edition)$"#)

    /// An id that names a run before its volume's number: `frus1918Russiav01`, `frus1917Supp02v01`.
    private static let runInVolumeId = try? NSRegularExpression(pattern: #"^frus\d{4}(?:-\d{2})?[A-Z][A-Za-z]*\d*v\d"#)

    /// An appendix's id: `frus1877app`, `frus1894app2`.
    private static let appendixVolumeId = try? NSRegularExpression(pattern: #"^frus\d{4}app(\d*)$"#)

    /// `text` without the spaces, commas and colons around it.
    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: " ,:"))
    }

    /// `printed` with its arabic figures.
    private static func numeral(_ printed: String) -> Numeral {
        Numeral(printed: printed, arabic: FRUSVolumeTitle.arabic(printed))
    }

    /// Whether `volumeId` names a run before its volume's number.
    private static func namesRun(volumeId: String) -> Bool {
        runInVolumeId?.firstMatch(in: volumeId, range: NSRange(volumeId.startIndex..., in: volumeId)) != nil
    }

    /// The appendix an appendix's id names, "Appendix" or "Appendix II", or `nil` for another id.
    private static func appendix(volumeId: String) -> String? {
        guard let found = FRUSVolumeTitle.match(appendixVolumeId, in: volumeId) else { return nil }
        guard let number = Int(volumeId[found.group]) else { return "Appendix" }
        return "Appendix \(roman(number))"
    }

    /// `number` in Roman numerals, as the volumes number their appendices: 2 as "II".
    static func roman(_ number: Int) -> String {
        var rest = number
        var out = ""
        for (value, numeral) in [(100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"),
                                 (4, "IV"), (1, "I")] {
            while rest >= value {
                out += numeral
                rest -= value
            }
        }
        return out
    }

    /// A subseries' years as a title writes them: "1861"; "1914-20" as "1914–1920".
    static func years(fromSubseries subseries: String) -> String {
        let pieces = subseries.split(separator: "-")
        guard pieces.count == 2, pieces[0].count == 4, pieces[1].count == 2,
              let start = Int(pieces[0]), let end = Int(pieces[1]) else { return subseries }
        var full = start / 100 * 100 + end
        if full < start { full += 100 }
        return "\(start)–\(full)"
    }
}

// MARK: - CitationItalics

/// A formatted citation's italics as a collection's exporters read them (L43): `_…_`. History at State marks its
/// series name `_…_`, and Chicago and Turabian mark their titles `*…*`, so the assembly that hands exporters a
/// citation in the collection's style hands them one kind of italics (the Collections design's §6).
///
/// Version history:
///   1.0 — L43: initial implementation
public enum CitationItalics {

    /// `citation` with each `*…*` span marked `_…_`.
    public static func underscored(_ citation: String) -> String {
        guard let asterisked else { return citation }
        return asterisked.stringByReplacingMatches(in: citation, range: NSRange(citation.startIndex..., in: citation),
                                                   withTemplate: "_$1_")
    }

    /// A `*…*` span on one line.
    private static let asterisked = try? NSRegularExpression(pattern: #"\*([^*\n]+)\*"#)
}

// MARK: - CitationPlainText

/// A formatted citation as Copy Citation and the share sheet hand it out: the Markdown italic
/// markers the formatters above write around the title (`_…_`, `*…*`) removed.
///
/// `AttributedString.characters` gives the character sequence after Markdown parsing; a string
/// Markdown will not parse has its paired markers stripped instead. `DocumentViewModel`
/// (`plainTextFormattedCitation`, iOS and iPadOS) and `DocumentExportSupport.plainText` (macOS)
/// each carried their own copy of this until #1505 made it one, so the round trip of the app's
/// own citations (`CitationMatchingEngineTests.ownCitationsAreNeverBestGuesses`) runs on the text
/// the reader copies rather than on a copy of how it is made.
public enum CitationPlainText {

    /// `formatted` without its Markdown italic markers.
    public static func plain(_ formatted: String) -> String {
        // Linux's Foundation has no Markdown parsing, so there the markers are stripped below.
        #if canImport(Darwin)
        if let attributed = try? AttributedString(
            markdown: formatted, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return String(attributed.characters)
        }
        #endif
        return formatted
            .replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
    }
}

// MARK: - CitationPunctuation

/// Prepares a formatted citation to be continued rather than stood alone (#1392).
///
/// All three formatters above end every citation they return with a period — "…, Document 41."
/// with a printed number ("…, doc. 41." in a Chicago or Turabian note, since L43), "…, 1984)."
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
public enum CitationPunctuation {

    /// `citation` without its one terminal period.
    ///
    /// Removes exactly one trailing period and nothing else. A string with none comes back
    /// unchanged — which is the `volumeId/documentId` fallback the citation data sources return
    /// when the manifest does not know the volume.
    public static func withoutTerminalPeriod(_ citation: String) -> String {
        citation.hasSuffix(".") ? String(citation.dropLast()) : citation
    }
}
