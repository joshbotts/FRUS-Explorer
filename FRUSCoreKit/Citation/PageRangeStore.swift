// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
#if canImport(FTS5Store)
import FTS5Store
#endif

private let SQLITE_TRANSIENT_PRS = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - PageRangeStore

/// Reads the `page_ranges` SQLite table to say which documents a printed page is, and which pages a
/// document is printed on.
///
/// ## What the index stores
/// `IndexingPipeline` writes, per document, one row per `<pb>` INSIDE the document's div, and — since
/// #1503 — one more, flagged `is_start = 1`, for the page the document begins on: the page of the
/// last `<pb>` before its first printed text, wherever that break sits (between documents, inside
/// the previous document, or inside this one ahead of its heading). Rows are written in source
/// order, the start row first — for a document or an editorial note only, never a prose section the
/// parser promotes to a quasi-document, whose own breaks are rows all the same (#1503 review round
/// 1). `section_id` is the document's own `xml:id` on every row, as it has been since the table was
/// built: nothing groups documents into sections, and a volume whose page numbers restart is read
/// as one run of documents, several of which then begin on — or are printed on — the same page
/// number. A volume where at least one in four of the documents with a start restarts them is
/// read as numbering its pages per document (`PageSpanResolver.numbersPagesPerDocument`).
///
/// ## What it answers
/// Both questions go through ``PageSpanResolver``, which the indexing-time page-reference resolver
/// (`IndexingPipeline.resolvePageBasedCrossReferences`) calls too:
/// - ``documents(forPage:inVolume:)`` — the documents that begin on a page, or when none does, the
///   documents printed on it; in a volume numbering its pages per document, every document printed
///   on a page of that number. Several is an ambiguous answer, and so is any answer in such a
///   volume, and Citation Lookup says so.
/// - ``printedPages(forDocument:inVolume:)`` — the pages a document may be printed on, which
///   Citation Lookup checks a cited page against. It reads the whole volume, because whether the
///   volume numbers its pages per document decides whether a document's start places it.
/// - ``document(forPage:inVolume:citing:)`` — the one document a page link opens: of several, the one
///   its footnote names (#1509), through the tie-break the indexer stores the link's edge by.
///
/// ## Log prefix
/// `[PageRangeStore]`
///
/// Version history:
///   1.0 — Session 30: initial implementation (table built in Session 09)
///   1.1 — Session 32: database opened with `SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX`
///          directly in `init` (previously delegated to a private `openDatabase()` helper)
///   1.2 — Session 2026-07-05: the private `span(containing:in:)` now delegates to the
///          shared `PageSpanResolver.documentContaining(page:in:)` (extracted verbatim,
///          Session-162 max-page behaviour preserved) so the reader and the indexing-time
///          page-reference resolver (`IndexingPipeline.resolvePageBasedCrossReferences`)
///          share one algorithm and can never diverge. No behavioural change to this path.
///   1.3 — #1474 review round 2: `printedPages(forDocument:inVolume:)`, the pages a document may
///          be printed on — the rule Citation Lookup checks a cited page against, including for a
///          document with no page break of its own, which `pageRange(forDocument:inVolume:)` cannot
///          answer. It reads `document_cache` beside `page_ranges` (the two share one database)
///          for the order of the volume's documents.
///   1.4 — #1474 review round 3: `printedPages` never starts below page 1 — a document whose first
///          break is page 1 read "0–N"
///   1.5 — #1503: both questions read the page each document begins on (`is_start`).
///          `documents(forPage:inVolume:)` returns every document the page is, in source order,
///          where `document(forPage:inVolume:)` returned one — the document owning the last break
///          at or before the page, which was the document before the one that begins there, or
///          none, and in a volume numbering its pages per document whichever a Swift Dictionary
///          reached first. `printedPages` is the pages a document is printed on from the page it
///          begins on, and no longer bounds a document with no break of its own by its
///          neighbours' breaks in `document_cache` order — the order a republication that inserts
///          documents gets wrong. `pageRange(forDocument:inVolume:)` is gone: its one caller labels
///          a page match from the pages the document is printed on.
///   1.6 — #1503 review round 1: `printedPages` reads the whole volume's rows, since in a volume
///          numbering its pages per document a start other than page 1 places no document
///          (`PageSpanResolver.numbersPagesPerDocument`); `documents(forPage:)` there answers
///          `.numberedPerDocument`, every document printed on a page of that number.
///   1.7 — #1509: `document(forPage:inVolume:citing:)` opens the document a page link's footnote
///          names among several the page names (`PageSpanResolver.citedDocument`), reading each
///          one's number and day through `PageSpanResolver.citedDocumentFactsSQL`; the page rows are
///          read through `PageSpanResolver.arabicPageRowsSQL`, the indexer's query. Review round 1:
///          the facts are read only when the page names several and the link carries a hint.
///   1.8 — FRUSCoreKit, part 2: moved into the kit. It binds text with `SQLITE_TRANSIENT`, so
///          SQLite keeps its own copy, where it bound a temporary `NSString`'s buffer and relied on
///          Apple's autorelease pool to keep it alive
///   1.9 — Session 2026-10-06 (FRUS Explorer Light, S9b): `init(readingDatabaseAt:)` opens an index
///          read-only and immutable (`isImmutable`), for a host that reads an index another program
///          built. `init(databaseURL:)` opens as before; a failed open of either closes the handle
///          SQLite allocates, which it left open, and the unused private `openDatabase()` is gone
public actor PageRangeStore {

    // MARK: - State

    private let databaseURL: URL
    private nonisolated(unsafe) var db: OpaquePointer?

    /// Whether the file was opened immutable (`init(readingDatabaseAt:)`), so SQLite takes no lock
    /// on it and makes no journal or shared-memory file beside it. Either open is read-only.
    nonisolated public let isImmutable: Bool

    // MARK: - Init

    /// Opens the shared index at `databaseURL` read-only, as the app does, beside the indexing
    /// pipeline that writes it.
    public init(databaseURL: URL) throws {
        try self.init(databaseURL: databaseURL, immutable: false)
    }

    /// Opens the index at `databaseURL` read-only and immutable, to read an index another program
    /// built: FRUS Explorer Light's server opens the Mac's exported index this way. The app never
    /// calls it.
    ///
    /// The file is opened with `?mode=ro&immutable=1` (`FTS5Store.immutableURI(for:)`), so SQLite
    /// takes no lock, writes nothing beside the file and refuses every write. Nothing may write the
    /// file while it is open. Only the busy timeout is set, as `init(databaseURL:)` sets it. It
    /// throws `PageRangeStoreError.databaseOpenFailed` when the file cannot be opened, a missing
    /// file included, which it does not create.
    ///
    /// - Parameter databaseURL: File URL of an existing index.
    public init(readingDatabaseAt databaseURL: URL) throws {
        try self.init(databaseURL: databaseURL, immutable: true)
    }

    /// The initialisers' shared body: the file opened read-only, at its path or, immutable, at its
    /// immutable URI.
    private init(databaseURL: URL, immutable: Bool) throws {
        self.databaseURL = databaseURL
        self.isImmutable = immutable
        var dbPtr: OpaquePointer?
        let rc = immutable
            ? sqlite3_open_v2(FTS5Store.immutableURI(for: databaseURL), &dbPtr,
                              SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil)
            : sqlite3_open_v2(databaseURL.path, &dbPtr, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard rc == SQLITE_OK else {
            sqlite3_close(dbPtr)
            throw PageRangeStoreError.databaseOpenFailed(code: rc)
        }
        // Wait up to 5 s instead of failing instantly with SQLITE_BUSY when a WAL
        // checkpoint or recovery briefly locks the file.
        sqlite3_busy_timeout(dbPtr, 5000)
        self.db = dbPtr
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Public API

    /// The documents page `pageNumber` of `volumeId` is — those that begin on it, or when none does,
    /// those printed on it — in source order, or `nil` when no document is (the volume has no arabic
    /// page data, or the page lies outside every document).
    ///
    /// More than one is an ambiguous answer: several short documents begin on one page. So is
    /// every answer in a volume that numbers its pages per document — fourteen of the E-volumes and
    /// `frus1981-88v16` — which prints a page number in many of its documents, where the answer is
    /// every document printed on a page of that number (`.numberedPerDocument`, #1503 review round
    /// 1), one or many. A microfiche supplement's facsimile page numbers restart with every
    /// document too, but its breaks are not a printed volume's pages, and Citation Lookup does not
    /// ask about one (`CitationMatchingEngine.isMicroficheSupplement`).
    public func documents(forPage pageNumber: Int, inVolume volumeId: String) throws -> PageSpanResolver.PageClaimants? {
        let documents = volumePages(volumeId)
        if documents.isEmpty {
            #if DEBUG
            print("[PageRangeStore] no arabic page data for volume \(volumeId)")
            #endif
            return nil
        }
        return PageSpanResolver.documents(onPage: pageNumber, in: documents)
    }

    /// The document a page reference means, or `nil` when the page names none — what a page link in
    /// the reader opens (#1509). Where the page names several documents, whatever the claim — several
    /// begin on it, where none does several are printed on it, or, in a volume that numbers its pages
    /// per document, several print a page of that number — the one the reference's footnote names by
    /// its number or its day, else the first in source order:
    /// ``PageSpanResolver/citedDocument(among:facts:citing:)``, the tie-break the index stored the
    /// reference's edge by, over the same page rows and the same facts
    /// (``PageSpanResolver/citedDocumentFactsSQL``), so a tap opens the document the cited-by count
    /// credits. The facts are read only when they can decide: when the page names several and the
    /// link carries a hint.
    ///
    /// - Parameter citing: What the link's footnote names (`PageCitationHint`, carried on the link by
    ///   `FRUSRenderNodeHTMLSerializer`), or `nil` for a reference outside every footnote.
    public func document(forPage pageNumber: Int, inVolume volumeId: String,
                         citing: PageCitationHint? = nil) throws -> String? {
        guard let claimants = try documents(forPage: pageNumber, inVolume: volumeId) else { return nil }
        // The facts query reads the whole volume; with one claimant or no hint it cannot change the answer.
        let facts = claimants.documents.count > 1 && citing != nil ? citedDocumentFacts(volumeId) : [:]
        return PageSpanResolver.citedDocument(among: claimants, facts: facts, citing: citing)
    }

    /// The pages `documentId` of `volumeId` may be printed on, or `nil` when the index cannot tell
    /// (#1474 review round 2, and #1503). Citation Lookup checks a cited page against it.
    ///
    /// From the page the document begins on — where its first printed text is, the commonest page
    /// to cite — through its last page break, so a document with no break of its own is printed on
    /// the one page it begins on. That page is recorded at index time wherever its break sits,
    /// between documents included, which the index recorded nowhere before #1503; the rule then
    /// bounded such a document by the breaks its neighbours record, in the order documents entered
    /// `document_cache` — an order a republication that inserts documents gets wrong, since each
    /// surviving document keeps its row and an inserted one sorts last.
    ///
    /// Without a start that places it (``PageSpanResolver/DocumentPages/placingStart``: none
    /// recorded, a start that is not arabic, one its own breaks run below, or — in a volume that
    /// numbers its pages per document — one other than page 1), the page before its first arabic
    /// break through its last, never from page 0. `nil` when neither places it — its breaks are none
    /// of them arabic and no start places it — or when the index does not hold the document.
    ///
    /// It reads the whole volume's rows (#1503 review round 1): whether the volume numbers its
    /// pages per document is a property of all of them. Reading the document's alone placed 349
    /// documents with no break of their own in those volumes on the page the one before them ended
    /// on, in its numbering (`rules_f.py` in `tools/page-citations/`) — `ve05p1`'s d239 on d238's p. 2.
    public func printedPages(forDocument documentId: String,
                             inVolume volumeId: String) throws -> ClosedRange<Int>? {
        guard let pages = volumePages(volumeId).first(where: { $0.documentId == documentId })?.possiblePages else {
            #if DEBUG
            print("[PageRangeStore] \(volumeId)/\(documentId) has no arabic page the index can place it on")
            #endif
            return nil
        }
        return pages
    }

    // MARK: - Private Helpers

    /// Each document of `volumeId`'s printed number and day, by id (#1509), through the query the
    /// indexer's page resolver runs.
    private func citedDocumentFacts(_ volumeId: String) -> [String: CitedDocumentFacts] {
        guard let db, let stmt = prepare(PageSpanResolver.citedDocumentFactsSQL, db: db) else { return [:] }
        defer { sqlite3_finalize(stmt) }
        bind(text: volumeId, at: 1, stmt: stmt)
        var facts: [String: CitedDocumentFacts] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            facts[string(at: 0, stmt: stmt)] = CitedDocumentFacts(
                printedNumber: optionalString(at: 1, stmt: stmt),
                dateISO: optionalString(at: 2, stmt: stmt),
                precision: optionalString(at: 3, stmt: stmt))
        }
        return facts
    }

    /// Every document of `volumeId` with an arabic page recorded, in source order.
    private func volumePages(_ volumeId: String) -> [PageSpanResolver.DocumentPages] {
        guard let db else { return [] }
        guard let stmt = prepare(PageSpanResolver.arabicPageRowsSQL, db: db) else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(text: volumeId, at: 1, stmt: stmt)
        var rows: [(documentId: String, isStart: Bool, pageInt: Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append((string(at: 0, stmt: stmt), sqlite3_column_int(stmt, 1) != 0,
                         Int(sqlite3_column_int(stmt, 2))))
        }
        return PageSpanResolver.documentPages(fromRows: rows)
    }

    /// SQLite's result code for `sql` run on this store's connection, so a test can show that the
    /// connection refuses a write (`SQLITE_READONLY`): the store has no method that writes.
    func resultCode(executing sql: String) -> Int32 {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func prepare(_ sql: String, db: OpaquePointer) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        return stmt
    }

    private func bind(text: String, at index: Int32, stmt: OpaquePointer) {
        sqlite3_bind_text(stmt, index, text, -1, SQLITE_TRANSIENT_PRS)
    }

    private func string(at column: Int32, stmt: OpaquePointer) -> String {
        guard let ptr = sqlite3_column_text(stmt, column) else { return "" }
        return String(cString: ptr)
    }

    private func optionalString(at column: Int32, stmt: OpaquePointer) -> String? {
        guard let ptr = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: ptr)
    }
}

// MARK: - PageRangeStoreError

public enum PageRangeStoreError: Error, Sendable {
    case databaseOpenFailed(code: Int32)
    case queryFailed(description: String)
}
