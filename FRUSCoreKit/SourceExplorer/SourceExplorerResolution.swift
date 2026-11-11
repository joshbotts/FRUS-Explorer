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

// MARK: - SourceExplorerResolution

/// What Source Explorer resolves for one document before it asks the NARA Catalog anything, as one value:
/// the parsed note, the collection authority's record, the pre-1906 country series, the document's day, the
/// classification marking the index stores, the unprinted pointers, the related documents and the bundled
/// presidential-library catalogue's answer.
///
/// ## Why one value
/// `SourceExplorerView` and `MacSourceExplorerView` are hand-maintained twins, and each ran this sequence in
/// its own `load()`, step for step. The steps' rules were extracted from them one at a time so that the two
/// could not drift (`CentralFilesClassifier.evaluate`, `UnprintedPointer.list`,
/// `SourceExplorerDocumentContext.documentDay`); the sequence was still written twice. It is written once
/// here: both views call ``resolved(route:pipeline:dependencies:update:)`` and draw from the value it gives
/// them, and FRUS Explorer Light's server will compute the same value over the same index and the same bundled
/// files.
///
/// ## What stays the views'
/// The NARA Catalog API key gate and the live calls behind it, with what they find: they need the Keychain
/// and the network. The live calls run once this value is complete; the Mac view reads its key first.
///
/// ## The order
/// The steps run in the order the views ran them, and `resolved` hands its host the value after each, so a
/// view draws each panel as its step completes, as it did when each step wrote the view's state:
/// 1. the parse, at once (``init(rawSourceNote:)``);
/// 2. the authority record, which reads no year and so goes before the evaluation, which may parse the
///    volume for the document's enclosures;
/// 3. the country series (`CentralFilesClassifier.evaluate`), which also reads a year the route did not
///    pass, so it runs before every step that reads the year;
/// 4. the document's day, before the related documents, so that the line above them does not change band
///    once they land (#1407 review);
/// 5. the classification marking the index stores (index version 72);
/// 6. the unprinted pointers, each carrying the note this value parsed (#1390);
/// 7. the related documents: the widened, anchor-excluding archival neighbours (#217), with a value saying
///    they are being searched handed to the host first;
/// 8. the presidential-library catalogue's answer, which needs neither a key nor the network (#681).
///
/// Version history:
///   1.0 — 2026-11-10 (FRUS Explorer Light, S22b): initial implementation, the sequence both views'
///         `load()` ran, with the twins' `loadUnprintedPointers(sourceNote:)`, `resolveCountrySeries()` and
///         `loadRelatedDocuments(for:)`, and `resolvingAgain()` for a load of the document a view already
///         shows; `UnprintedPointer` and its render-time join, `resolve(_:authority:)`, from `SourceExplorerView`
public struct SourceExplorerResolution: Sendable {

    /// The source note as the host passed it: blank for a document that prints none.
    public let rawSourceNote: String

    /// The note, parsed (step 1).
    public let parsed: ParsedSourceNote

    /// The bundled cross-volume authority's record for the note (step 2, Phase 4), or `nil` when the note's
    /// keys land in no tracked collection, and for a blank note.
    public internal(set) var authorityRecord: AuthorityCollectionRecord? = nil

    /// The document with the route's gaps filled from the index: header, dateline, year and serial (step 3).
    /// `nil` until the step has run.
    public internal(set) var documentContext: SourceExplorerDocumentContext? = nil

    /// What the pre-1906 section knows (step 3): `.loading` until the step has run.
    public internal(set) var countrySeries: CountrySeriesOutcome = .loading

    /// The document's own day from the index (step 4, #1407 review), or `nil`: before the step, and for a
    /// document the index does not date to the day.
    public internal(set) var documentDay: DecimalFileSegment.DocumentDay? = nil

    /// The classification marking the index stores for the document (step 5, index version 72), or `nil`.
    public internal(set) var storedClassification: String? = nil

    /// The document's footnote pointers at material FRUS did not print, in reading order (step 6, #829a).
    public internal(set) var unprintedPointers: [UnprintedPointer] = []

    /// The documents from the same archival collection (step 7): `.notRun` until the step, and when there
    /// is no index.
    public internal(set) var relatedDocuments: RelatedDocumentsLookup = .notRun

    /// The bundled catalogue's answer for a presidential-library citation (step 8, #681); `.none` for every
    /// other note.
    public internal(set) var presidentialLibrary: PresidentialLibraryOutcome = .none

    /// The value with the note parsed and nothing else resolved: what a view shows the moment a load of
    /// another document starts, before any await, so that no part of the previous document's answer stays on
    /// screen; and where a host starts.
    public init(rawSourceNote: String) {
        self.rawSourceNote = rawSourceNote
        self.parsed = SourceNoteParser().parse(rawSourceNote)
    }

    /// This value, to be resolved again for the same document: what a view shows when it loads the document
    /// it already shows — shown again after a page pushed over it, refreshed, or reloaded as the index comes
    /// up. Each part stays on screen until its step replaces it, as each did when the steps wrote the view's
    /// state one by one, but for the pre-1906 section and what reads the year: the country series goes back
    /// to `.loading` and the hydrated document, the day and the stored marking to `nil`, the reset the iOS
    /// view made before each load, so that "not checked yet" does not outlive an index that has come up.
    public func resolvingAgain() -> SourceExplorerResolution {
        var again = self
        again.documentContext = nil
        again.countrySeries = .loading
        again.documentDay = nil
        again.storedClassification = nil
        return again
    }

    /// Whether the document carries a source note at all. A blank note is not an unrecognized one: chiefly
    /// a pre-1906 document, which carries none.
    public var hasSourceNote: Bool {
        !rawSourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - The sequence

    /// Runs the sequence for this value's document and returns the value resolved, handing `update` the value
    /// after each step, in the order the type's documentation gives. Each step writes its own parts and
    /// leaves the others as they are, so a value from ``init(rawSourceNote:)`` fills in from nothing, and one
    /// from ``resolvingAgain()`` keeps what it holds until each step replaces it.
    ///
    /// Nonisolated, so its reads and decodes run off the main actor under the package's and the app's Swift 6
    /// settings, where the views ran the authority's, the pointers' and the library's in detached tasks and
    /// read the central-files index on the main actor: the authority (about 2 MB) and the central-files index
    /// (about 3.6 MB), each read through `dependencies` where its step reads it, the register only once both
    /// of the country series' gates have passed, and the presidential-library catalogue (about 3 MB) only for
    /// a library citation.
    ///
    /// - Parameters:
    ///   - route: What the opening route passed about the document.
    ///   - pipeline: The index, or `nil` while it starts: then nothing that reads the index runs, and the
    ///     country series says why.
    ///   - dependencies: The bundled files and the parsed documents the steps read.
    ///   - update: Called on the main actor with the value after each step, for a view to draw it as it comes;
    ///     `nil` for a host that wants only the result. The call runs in the caller's task, so a view's
    ///     `Task.isCancelled` there is its load's, and a view that writes only while it is false writes
    ///     nothing from a load its key has replaced.
    /// - Returns: The value after the last step.
    public func resolved(route: CountrySeriesRoute, pipeline: IndexingPipeline?, dependencies: Dependencies,
                         update: (@MainActor @Sendable (SourceExplorerResolution) -> Void)? = nil)
        async -> SourceExplorerResolution {
        var resolution = self
        let rawSourceNote = self.rawSourceNote
        let note = parsed
        // The authority is read once, where a step first needs it: a host's provider may decode it.
        var authorityRead: CollectionAuthorityIndex??
        func authority() -> CollectionAuthorityIndex? {
            if let authorityRead { return authorityRead }
            let read = dependencies.collectionAuthority()
            authorityRead = .some(read)
            return read
        }

        // 2. The cross-volume authority (Phase 4), for a document that carries a note.
        if resolution.hasSourceNote {
            resolution.authorityRecord = authority()?.record(forParsed: note, note: rawSourceNote)
        }
        await update?(resolution)

        // 3. The pre-1906 country series, with the header, dateline and year a route did not pass, read from
        // the index.
        let evaluated = await CentralFilesClassifier.evaluate(
            route: route, pipeline: pipeline, index: dependencies.centralFiles(),
            roster: dependencies.chiefsOfMission(), astCache: dependencies.parsedDocuments,
            volumeURL: dependencies.volumeURL)
        resolution.documentContext = evaluated.context
        resolution.countrySeries = evaluated.outcome
        await update?(resolution)

        // 4. The document's day, which a date-form file year is checked against.
        resolution.documentDay = await SourceExplorerDocumentContext.documentDay(
            pipeline: pipeline, volumeId: route.volumeId, documentId: route.documentId)
        await update?(resolution)

        // 5. The marking the index stores, for the chip beside the note.
        resolution.storedClassification = await SourceExplorerDocumentContext.storedClassification(
            pipeline: pipeline, volumeId: route.volumeId, documentId: route.documentId)
        await update?(resolution)

        // 6. The footnote pointers, whether or not the document has a note: a document printed without a
        // provenance can still point at unprinted files.
        resolution.unprintedPointers = await Self.unprintedPointers(
            sourceNote: note, route: route, pipeline: pipeline, authority: authority())
        await update?(resolution)

        // 7. The related documents, which need no API key.
        if let pipeline {
            resolution.relatedDocuments = .searching
            await update?(resolution)
            resolution.relatedDocuments = await Self.relatedDocuments(
                for: note, rawSourceNote: rawSourceNote, route: route,
                documentYear: resolution.documentContext?.year ?? route.year, pipeline: pipeline)
            await update?(resolution)
        }

        // 8. The bundled library catalogue, which needs neither a key nor the network: withheld behind one,
        // the offline answer would be withheld from exactly the users who have no other (#681).
        if case .presidentialLibrary(let library, let collection, _) = note {
            resolution.presidentialLibrary = PresidentialLibraryOutcome.resolve(
                repository: library, collection: collection, note: rawSourceNote,
                index: dependencies.presidentialLibraries(), curated: dependencies.curatedLibraries())
            await update?(resolution)
        }
        return resolution
    }

    /// Step 6: this document's footnote pointers, each joined to the authority.
    ///
    /// Every pointer carries the note this value parsed (#1390), so a row's same-lot marker is decided
    /// against the note of the resolution that built the row, and `UnprintedPointer.list` is the one
    /// builder, so the repeat numbers are fixed here too.
    ///
    /// - Parameter authority: Read only when the document has pointers.
    static func unprintedPointers(sourceNote: ParsedSourceNote, route: CountrySeriesRoute,
                                  pipeline: IndexingPipeline?,
                                  authority: @autoclosure () -> CollectionAuthorityIndex?) async -> [UnprintedPointer] {
        guard let pipeline, let volumeId = route.volumeId, let documentId = route.documentId else { return [] }
        let rows = (try? await pipeline.externalCitations(volumeId: volumeId, documentId: documentId)) ?? []
        guard !rows.isEmpty else { return [] }
        let authority = authority()
        return UnprintedPointer.list(rows, sourceNote: sourceNote) { citation in
            authority.flatMap { UnprintedPointer.resolve(citation, authority: $0) }
        }
    }

    /// Step 7: the documents from the same archival collection.
    ///
    /// Anchored to an indexed document, through the widened, anchor-excluding
    /// `archivalNeighbors(forVolumeId:documentId:documentYear:)` entry point the dedicated Archival Neighbors
    /// surfaces use, so that this list is the identical set of other documents (the #217 "same set
    /// regardless of trigger" guarantee); at the all-indexed default scope, since the scope picker lives on
    /// those surfaces. A note explored with no indexed document behind it takes the note-keyed query, with
    /// nothing to exclude, and the class a central-files citation is matched on read from the note.
    static func relatedDocuments(for note: ParsedSourceNote, rawSourceNote: String, route: CountrySeriesRoute,
                                 documentYear: Int?, pipeline: IndexingPipeline) async -> RelatedDocumentsLookup {
        do {
            if let volumeId = route.volumeId, let documentId = route.documentId {
                let found = try await pipeline.archivalNeighbors(
                    forVolumeId: volumeId, documentId: documentId, documentYear: documentYear)
                return .found(found.documents, totalCount: found.totalCount)
            }
            let found = try await pipeline.relatedDocuments(
                for: note, limit: 30, documentYear: documentYear, rawCitation: rawSourceNote)
            return .found(found.documents, totalCount: found.totalCount)
        } catch {
            #if DEBUG
            print("[SourceExplorer] Related documents query failed: \(error)")
            #endif
            return .failed
        }
    }
}

// MARK: - Dependencies

extension SourceExplorerResolution {

    /// What the steps read besides the index: the bundled files, each read where its step reads it, and the
    /// host's parsed documents with the volume's file, for the enclosures of a pre-1906 document.
    ///
    /// Each file is a provider rather than a value, so a host that decodes its files lazily, as the app's
    /// stores do, decodes each only where its step reads it, off the main actor, and the presidential-library
    /// catalogue only for a library citation. A host that keeps its files decoded passes them. The app
    /// builds its own from its stores and its `AppState` (`SourceExplorerResolution+App.swift`).
    public struct Dependencies: Sendable {

        /// `collection-authority.json`: the authority record (step 2) and the pointers' join (step 6).
        let collectionAuthority: @Sendable () -> CollectionAuthorityIndex?
        /// `central-files-index.json`: the country series' rolls (step 3).
        let centralFiles: @Sendable () -> CentralFilesIndex?
        /// The chiefs of mission the addressee rule reads (step 3), read only once both gates have passed.
        let chiefsOfMission: @Sendable () -> ChiefsOfMissionRoster
        /// `presidential-library-catalog.json` (step 8).
        let presidentialLibraries: @Sendable () -> PresidentialLibraryIndex?
        /// `curated-library-resolutions.json` (step 8).
        let curatedLibraries: @Sendable () -> CuratedLibraryResolutions?
        /// The documents the host has parsed, read before the volume is parsed again for an enclosure.
        let parsedDocuments: any DocumentASTSource
        /// The volume's file, parsed when `parsedDocuments` does not hold the document; `nil` when the host
        /// has none, and then an enclosure that is not held is not read.
        let volumeURL: URL?

        /// What a resolution reads, each file read where its step reads it.
        public init(collectionAuthority: @autoclosure @escaping @Sendable () -> CollectionAuthorityIndex?,
                    centralFiles: @autoclosure @escaping @Sendable () -> CentralFilesIndex?,
                    chiefsOfMission: @autoclosure @escaping @Sendable () -> ChiefsOfMissionRoster,
                    presidentialLibraries: @autoclosure @escaping @Sendable () -> PresidentialLibraryIndex?,
                    curatedLibraries: @autoclosure @escaping @Sendable () -> CuratedLibraryResolutions?,
                    parsedDocuments: any DocumentASTSource,
                    volumeURL: URL?) {
            self.collectionAuthority = collectionAuthority
            self.centralFiles = centralFiles
            self.chiefsOfMission = chiefsOfMission
            self.presidentialLibraries = presidentialLibraries
            self.curatedLibraries = curatedLibraries
            self.parsedDocuments = parsedDocuments
            self.volumeURL = volumeURL
        }
    }
}

// MARK: - RelatedDocumentsLookup

extension SourceExplorerResolution {

    /// Where step 7 stands, and what it found.
    public enum RelatedDocumentsLookup: Sendable {
        /// The step has not run: before it, and when there is no index.
        case notRun
        /// The query is running.
        case searching
        /// The documents, at most the query's limit, and how many matched in all.
        case found([IndexingPipeline.RelatedDocument], totalCount: Int)
        /// The query threw. The section shows what it shows for no match, as it did.
        case failed

        /// The documents found, or none.
        public var documents: [IndexingPipeline.RelatedDocument] {
            if case .found(let documents, _) = self { return documents }
            return []
        }

        /// How many documents matched, which may exceed `documents.count`; `0` unless found.
        public var totalCount: Int {
            if case .found(_, let totalCount) = self { return totalCount }
            return 0
        }

        /// Whether the query is running.
        public var isSearching: Bool {
            if case .searching = self { return true }
            return false
        }
    }
}

// MARK: - Unprinted Material (#829a)

extension SourceExplorerResolution {

    /// One footnote pointer, with whatever the render-time join could make of it.
    ///
    /// **Declared once for both twins** — the Mac view draws this same type, and
    /// `SourceExplorerResolution` builds it for both — and, since #1390, **it carries every fact
    /// `rowText` prints**, the lot the document's own source note
    /// names and the row's place among rows worded alike included. Both are fixed by the load that
    /// built the pointer rather than read from the view's state at draw time, so a pointer and the
    /// note and list it is compared with always come from the same load, whichever twin draws it
    /// and however the view is re-keyed.
    public struct UnprintedPointer: Identifiable, Equatable, Sendable {
        /// The stored citation.
        public let citation: ExternalCitation
        /// The authority record it resolved to, when it did.
        public let record: AuthorityCollectionRecord?
        /// The canonical lot key (`SourceNoteParser.lotFileNorm`) of the lot the document's own
        /// source note names, or `nil` when the note names none.
        public let sourceNoteLotNorm: String?
        /// Where this row stands among the document's rows that would otherwise print the same
        /// thing, or `nil` when no other row does. Only `list(_:sourceNote:resolve:)` sets it,
        /// because only the whole list can say which rows those are.
        public private(set) var repeatPosition: RepeatPosition?

        /// Creates a pointer, outside any list — so with no `repeatPosition`.
        ///
        /// `sourceNote` has no default on purpose: a default of `nil` would compile at every
        /// construction site and mark no row, which is indistinguishable on screen from a document
        /// whose footnotes never cite its own lot. An explicit `nil` still compiles; the rows are built
        /// through `list(_:sourceNote:resolve:)`, by `SourceExplorerResolution.resolved`, which a test pins.
        ///
        /// - Parameters:
        ///   - citation: The stored citation.
        ///   - record: The authority record it resolved to, when it did.
        ///   - sourceNote: The document's parsed source note, from the same load.
        public init(citation: ExternalCitation, record: AuthorityCollectionRecord?,
             sourceNote: ParsedSourceNote?) {
            self.citation = citation
            self.record = record
            self.sourceNoteLotNorm = Self.lotNorm(ofSourceNote: sourceNote)
            self.repeatPosition = nil
        }

        /// The citation's id, unique within the document since #1390 (see `ExternalCitation.id`).
        ///
        /// The rows are keyed on it. Before #1390 two citations of one lot in one note shared it,
        /// which the Mac's `VStack` drew twice and the iOS `Form` may draw once.
        public var id: String { citation.id }

        /// A row's place in a run of rows worded alike, in reading order.
        public struct RepeatPosition: Equatable, Sendable {
            /// Which of them this row is, from one.
            public let ordinal: Int
            /// How many rows print those words.
            public let count: Int
        }

        /// A document's Unprinted Material rows — the one way they are built, for both twins (#1390).
        ///
        /// Every pointer carries the loaded source note, and every row that would print exactly
        /// what another row of the list prints is numbered among them, in the order given — which
        /// is reading order, since both index readers sort by `note_ordinal, citation_index`. The
        /// printed footnote and the clause do not always tell rows apart: `frus1952-54v04` d90's
        /// footnote 1 follows two different memoranda with the same "(S/S–OCB files, lot 62 D 430,
        /// “Rio Conference”)", and `frus1913` d707 prints two footnotes "1" that both read "File
        /// No. 311.651T15/12." Those rows say "1 of 2 citations worded alike" and "2 of 2", a
        /// number the reader can check against the page. The number is never assigned to a row
        /// nothing repeats: it would be noise on every other row of the list.
        ///
        /// - Parameters:
        ///   - citations: The document's citations, in reading order.
        ///   - sourceNote: The document's parsed source note, from the same load.
        ///   - resolve: The render-time authority join, `nil` for a row that resolves to nothing.
        /// - Returns: One pointer per citation, in the same order.
        public static func list(_ citations: [ExternalCitation], sourceNote: ParsedSourceNote?,
                         resolve: (ExternalCitation) -> AuthorityCollectionRecord?) -> [UnprintedPointer] {
            var pointers = citations.map {
                UnprintedPointer(citation: $0, record: resolve($0), sourceNote: sourceNote)
            }
            let keys = pointers.map(\.printedKey)
            var totals: [PrintedKey: Int] = [:]
            for key in keys { totals[key, default: 0] += 1 }
            var seen: [PrintedKey: Int] = [:]
            for index in pointers.indices {
                let key = keys[index]
                guard let total = totals[key], total > 1 else { continue }
                let ordinal = seen[key, default: 0] + 1
                seen[key] = ordinal
                pointers[index].repeatPosition = RepeatPosition(ordinal: ordinal, count: total)
            }
            return pointers
        }

        /// Everything a row prints apart from its repeat number: the words `rowText` supplies, and
        /// the four things each twin still draws itself — the box or folder, the Ibid. label, the
        /// provenance chip, and whether the row opens a collection. Two rows that differ in any of
        /// them already read differently and are not numbered.
        private struct PrintedKey: Hashable {
            let title: String
            let clause: String?
            let sameLotNote: String?
            let fileId: String?
            let inherited: Bool
            let provenance: ProvenanceSource
            let opensCollection: Bool
        }

        /// This row's `PrintedKey`.
        private var printedKey: PrintedKey {
            let text = rowText
            let fileId = citation.fileId.flatMap { $0.isEmpty ? nil : $0 }
            return PrintedKey(title: text.title, clause: text.clause, sameLotNote: text.sameLotNote,
                              fileId: fileId, inherited: citation.inherited,
                              provenance: SourceExplorerProvenance.unprintedPointerSource(for: citation),
                              opensCollection: record != nil)
        }

        /// The words of one Unprinted Material row that both twins take from `rowText` (#1390).
        ///
        /// Not the whole row: the box or folder, the Ibid. label, the provenance chip and the Mac's
        /// View Collection button are still drawn by each twin from the citation and the record.
        public struct RowText: Equatable, Sendable {
            /// The first line: the footnote the volume printed, then the unit — "fn 2 · Lot 66 D 95".
            /// The unit alone when no printed number is recorded.
            public let title: String
            /// `title` as VoiceOver says it — "Footnote 2, Lot 66 D 95" — because "fn" is read as
            /// two letters.
            public let spokenTitle: String
            /// The clause the citation was read from, trimmed; `nil` when it is empty or would only
            /// repeat the unit.
            public let clause: String?
            /// "Same lot as the source note" when the row's lot is the one the document's source
            /// note names; `nil` otherwise.
            public let sameLotNote: String?
            /// "1 of 2 citations worded alike" when another row of the list prints exactly what this
            /// one prints; `nil` otherwise.
            public let repeatNote: String?
        }

        /// The words of this pointer's row — the one function both Source Explorer twins draw them
        /// from (#1390).
        ///
        /// `frus1952-54v02p1` d41 printed five rows reading "Lot 66 D 95" twice and "Lot 63 D 351"
        /// three times, and every one of them was right. Four facts tell such rows apart; d41 needs
        /// the first three:
        /// - **The printed footnote number** (`noteLabel`, #1322) separates footnotes 3, 4 and 5,
        ///   whose clauses are word for word the same. It is never derived: `noteOrdinal + 1` is the
        ///   wrong number for most notes. When `noteLabel` is nil — a row written before index v53,
        ///   or one of the handful of notes a volume printed without a number — the title claims no
        ///   number at all, the rule the packet's `TripPacketExporter.footnoteLine(for:)` follows.
        /// - **The clause** separates two citations in one note when their words differ: footnote 2
        ///   cites lot 66 D 95 once for its "Record of Actions" and once for its "NSC Record of
        ///   Actions".
        /// - **The same-lot marker** says what the old footer denied: that a footnote can point into
        ///   the very lot the source note names. It marks the row and never hides it. The two stay
        ///   separate claims (#783): a footnote pointing at memoranda FRUS did not print is still a
        ///   pointer at unprinted material, whichever lot holds them. It covers **lots only**: a
        ///   class row naming the source note's own central-file class, or a library row naming its
        ///   collection, is not marked.
        /// - **The repeat number**, for rows the first three leave identical — see
        ///   `list(_:sourceNote:resolve:)`.
        public var rowText: RowText {
            let unit = citation.displayLabel
            let title: String
            let spokenTitle: String
            if let label = citation.noteLabel, !label.isEmpty {
                title = String(format: String(
                    localized: "source.explorer.unprinted.row.title %@ %@",
                    defaultValue: "fn %1$@ · %2$@"), label, unit)
                spokenTitle = String(format: String(
                    localized: "source.explorer.unprinted.row.spokenTitle %@ %@",
                    defaultValue: "Footnote %1$@, %2$@"), label, unit)
            } else {
                title = unit
                spokenTitle = unit
            }
            let clause = citation.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let repeatsUnit = clause == unit.trimmingCharacters(in: .whitespacesAndNewlines)
            let sameLot: String?
            if let sourceLot = sourceNoteLotNorm, citation.lotFileNorm == sourceLot {
                sameLot = String(localized: "source.explorer.unprinted.row.sameLot",
                                 defaultValue: "Same lot as the source note")
            } else {
                sameLot = nil
            }
            let repeatNote = repeatPosition.map {
                String(format: String(
                    localized: "source.explorer.unprinted.row.repeat %lld %lld",
                    defaultValue: "%1$lld of %2$lld citations worded alike"),
                       Int64($0.ordinal), Int64($0.count))
            }
            return RowText(title: title, spokenTitle: spokenTitle,
                           clause: clause.isEmpty || repeatsUnit ? nil : clause,
                           sameLotNote: sameLot, repeatNote: repeatNote)
        }

        /// The canonical lot key a parsed source note names.
        ///
        /// Read from exactly the cases `IndexingPipeline.baseDocumentSourceRow` writes
        /// `document_sources.lot_file_norm` for — a lot file, and a National Archives citation that
        /// names a lot — through the same `SourceNoteParser.lotFileNorm`, so the marker agrees with
        /// the lot the index stores for the note. `nil` for every other note.
        ///
        /// Also `nil` when the lot normalises to nothing. `lotFileNorm` keeps only what precedes
        /// the first `:`, `(` or `)`, so a lot printed as "(62 D 430)" has an empty key, and an
        /// empty key names no lot: two lots that both normalise to "" are not the same lot. The
        /// index stores that "" as it is, so this is the one case where the marker's key and the
        /// stored one differ, deliberately. A citation WITHOUT a lot is not what this guards
        /// against — its `lotFileNorm` is `nil`, which never equals a string — and no citation the
        /// footnote grammar harvests today has an empty lot key, so the guard is defensive.
        ///
        /// - Parameter note: The document's parsed source note.
        /// - Returns: The compact lot key (`63D351`), or `nil`.
        static func lotNorm(ofSourceNote note: ParsedSourceNote?) -> String? {
            let lot: String?
            switch note {
            case .lotFile(_, let number, _)?:
                lot = number
            case .naraCollection(_, _, let number?, _)?:
                lot = number
            default:
                lot = nil
            }
            guard let lot else { return nil }
            let norm = SourceNoteParser.lotFileNorm(lot)
            return norm.isEmpty ? nil : norm
        }

        /// The Unprinted Material section's footer, declared once for both twins (#1390).
        ///
        /// It used to call the section "separate from the source note above" while listing the
        /// source note's own lot — three of d41's five rows. The CLAIMS are separate: a footnote
        /// pointing at a file is not the document having been drawn from it, and the two are never
        /// added together (#783). The UNITS need not be. A row says so when the shared unit is a
        /// lot; a class or library row naming the source note's own unit carries no marker, which
        /// is why the footer states the rule for every row rather than leaving it to the marker.
        public static var sectionFooter: String {
            String(localized: "source.explorer.unprinted.footer.v2",
                   defaultValue: "Archival units this document’s footnotes cite for material FRUS did not print. Each is a separate claim from the source note above, which records where this document itself was drawn from, even when the two name the same unit.")
        }
    }
}

// MARK: - The render-time join

extension SourceExplorerResolution.UnprintedPointer {

    /// Resolves one stored citation to an authority record.
    ///
    /// **The rows carry no authority id**, so this is the render-time join #829 specifies: the lot
    /// key first, else the repository plus the collection's leading segment — composed exactly as
    /// `ArchivalLibraryProfile.resolve` does, **including the #351 library→lot domain guard**, which
    /// stops a presidential-library citation from matching a lot-file record that happens to share a
    /// leading word.
    ///
    /// - Parameters:
    ///   - citation: The stored row.
    ///   - authority: The bundled authority.
    /// - Returns: The record, or `nil` when nothing matches under the guard.
    public static func resolve(_ citation: ExternalCitation,
                               authority: CollectionAuthorityIndex) -> AuthorityCollectionRecord? {
        ExternalCitationAuthorityJoin.record(lotFileNorm: citation.lotFileNorm,
                                             collectionName: citation.collection,
                                             repository: citation.repository,
                                             authority: authority)
    }
}
